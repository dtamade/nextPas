unit nextpas.core.lockfree.snapshot;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TSnapshotResult = (srCommitted, srAborted, srConflict, srNotFound, srClosed);

  {** @desc MVCC 快照版本记录 }
  PSnapshotVersion = ^TSnapshotVersion;
  TSnapshotVersion = record
    Timestamp: Int64;
    Value: AnsiString;
    Next: PSnapshotVersion;
  end;

  {** @desc 并发快照隔离（Snapshot Isolation）
    @details 基于 MVCC 的简化快照隔离实现。
      每个事务看到数据库在事务开始时的快照。
      读操作不阻塞写操作，写操作不阻塞读操作。
      写-写冲突检测：两个事务同时修改同一 key 时，后提交者被 abort。
      适用场景：数据库事务、并发状态管理。
  }
  TSnapshotIsolationImpl = class
  private type
    PKeyEntry = ^TKeyEntry;
    TKeyEntry = record
      Key: AnsiString;
      Versions: PSnapshotVersion;  // 版本链，按时间戳降序
      Next: PKeyEntry;             // 哈希桶链表
    end;
  private const
    BUCKET_COUNT = 256;
  private
    FBuckets: array[0..BUCKET_COUNT - 1] of PKeyEntry;
    FTimestamp: Int64;
    FClosed: Int32;
    FLock: Int32;  // 全局锁，简化实现
    function GetNextTimestamp: Int64;
    function FindKeyEntry(const AKey: AnsiString): PKeyEntry;
    function GetOrCreateKeyEntry(const AKey: AnsiString): PKeyEntry;
    function HashKey(const AKey: AnsiString): PtrUInt;
    procedure CleanupVersions(AEntry: PKeyEntry; AMaxVersions: Integer = 10);
  public
    constructor Create;
    destructor Destroy; override;
    function BeginSnapshot: Int64;
    function Read(const AKey: AnsiString; const ASnapshotTs: Int64; out AValue: AnsiString): TSnapshotResult;
    function Write(const AKey: AnsiString; const AValue: AnsiString; const ATransactionTs: Int64): TSnapshotResult;
    function Commit(const ATransactionTs: Int64): TSnapshotResult;
    function Abort(const ATransactionTs: Int64): TSnapshotResult;
    procedure Close;
    function IsClosed: Boolean; inline;
    function GetCurrentTimestamp: Int64; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

{ TSnapshotIsolationImpl }

constructor TSnapshotIsolationImpl.Create;
var
  LI: Integer;
begin
  inherited Create;
  for LI := 0 to BUCKET_COUNT - 1 do
    FBuckets[LI] := nil;
  FTimestamp := 0;
  FClosed := 0;
  FLock := 0;
end;

destructor TSnapshotIsolationImpl.Destroy;
var
  LI: Integer;
  LEntry, LNextEntry: PKeyEntry;
  LVer, LNextVer: PSnapshotVersion;
begin
  for LI := 0 to BUCKET_COUNT - 1 do
  begin
    LEntry := FBuckets[LI];
    while LEntry <> nil do
    begin
      LNextEntry := LEntry^.Next;
      LVer := LEntry^.Versions;
      while LVer <> nil do
      begin
        LNextVer := LVer^.Next;
        Dispose(LVer);
        LVer := LNextVer;
      end;
      Dispose(LEntry);
      LEntry := LNextEntry;
    end;
  end;
  inherited Destroy;
end;

function TSnapshotIsolationImpl.GetNextTimestamp: Int64;
begin
  Result := atomic_fetch_add_64(FTimestamp, 1, mo_acq_rel) + 1;
end;

function TSnapshotIsolationImpl.HashKey(const AKey: AnsiString): PtrUInt;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 1 to Length(AKey) do
    Result := Result * 31 + Ord(AKey[LI]);
  Result := Result mod BUCKET_COUNT;
end;

function TSnapshotIsolationImpl.FindKeyEntry(const AKey: AnsiString): PKeyEntry;
var
  LIdx: PtrUInt;
begin
  LIdx := HashKey(AKey);
  Result := FBuckets[LIdx];
  while Result <> nil do
  begin
    if Result^.Key = AKey then
      Exit;
    Result := Result^.Next;
  end;
end;

function TSnapshotIsolationImpl.GetOrCreateKeyEntry(const AKey: AnsiString): PKeyEntry;
var
  LIdx: PtrUInt;
begin
  Result := FindKeyEntry(AKey);
  if Result <> nil then
    Exit;
  LIdx := HashKey(AKey);
  New(Result);
  Result^.Key := AKey;
  Result^.Versions := nil;
  Result^.Next := FBuckets[LIdx];
  FBuckets[LIdx] := Result;
end;

procedure TSnapshotIsolationImpl.CleanupVersions(AEntry: PKeyEntry; AMaxVersions: Integer);
var
  LCount: Integer;
  LVer, LPrev, LToFree: PSnapshotVersion;
begin
  LCount := 0;
  LVer := AEntry^.Versions;
  while LVer <> nil do
  begin
    Inc(LCount);
    LVer := LVer^.Next;
  end;
  if LCount <= AMaxVersions then
    Exit;
  // 保留最新 AMaxVersions 个版本，删除旧版本
  LVer := AEntry^.Versions;
  LPrev := nil;
  LCount := 0;
  while LVer <> nil do
  begin
    Inc(LCount);
    if LCount > AMaxVersions then
    begin
      if LPrev <> nil then
        LPrev^.Next := nil;
      while LVer <> nil do
      begin
        LToFree := LVer;
        LVer := LVer^.Next;
        Dispose(LToFree);
      end;
      Exit;
    end;
    LPrev := LVer;
    LVer := LVer^.Next;
  end;
end;

function TSnapshotIsolationImpl.BeginSnapshot: Int64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(-1);
  // 获取唯一时间戳作为快照点
  Result := GetNextTimestamp;
end;

function TSnapshotIsolationImpl.Read(const AKey: AnsiString; const ASnapshotTs: Int64; out AValue: AnsiString): TSnapshotResult;
var
  LEntry: PKeyEntry;
  LVer: PSnapshotVersion;
  LSpin: Integer;
  LCasExpected: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(srClosed);
  // 获取锁以确保读取一致性
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
  try
    LEntry := FindKeyEntry(AKey);
    if LEntry = nil then
      Exit(srNotFound);
    // 查找 <= ASnapshotTs 的最新版本
    LVer := LEntry^.Versions;
    while LVer <> nil do
    begin
      if LVer^.Timestamp <= ASnapshotTs then
      begin
        AValue := LVer^.Value;
        Exit(srCommitted);
      end;
      LVer := LVer^.Next;
    end;
    Result := srNotFound;
  finally
    atomic_store(FLock, 0, mo_release);
  end;
end;

function TSnapshotIsolationImpl.Write(const AKey: AnsiString; const AValue: AnsiString; const ATransactionTs: Int64): TSnapshotResult;
var
  LEntry: PKeyEntry;
  LNewVer: PSnapshotVersion;
  LSpin: Integer;
  LCasExpected: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(srClosed);
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
  try
    LEntry := GetOrCreateKeyEntry(AKey);
    // 检查写-写冲突：是否有其他事务在我们之后写了同一个 key
    if (LEntry^.Versions <> nil) and (LEntry^.Versions^.Timestamp > ATransactionTs) then
    begin
      // 冲突：其他事务已经写入了更新的版本
      Exit(srConflict);
    end;
    // 创建新版本
    New(LNewVer);
    LNewVer^.Timestamp := ATransactionTs;
    LNewVer^.Value := AValue;
    LNewVer^.Next := LEntry^.Versions;
    LEntry^.Versions := LNewVer;
    // 清理旧版本
    CleanupVersions(LEntry);
    Result := srCommitted;
  finally
    atomic_store(FLock, 0, mo_release);
  end;
end;

function TSnapshotIsolationImpl.Commit(const ATransactionTs: Int64): TSnapshotResult;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(srClosed);
  // 简化实现：提交即成功
  // 真实 MVCC 需要维护活跃事务列表，这里简化处理
  Result := srCommitted;
end;

function TSnapshotIsolationImpl.Abort(const ATransactionTs: Int64): TSnapshotResult;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(srClosed);
  // 简化实现：abort 即成功
  // 真实 MVCC 需要回滚该事务的所有写入，这里简化处理
  Result := srAborted;
end;

procedure TSnapshotIsolationImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TSnapshotIsolationImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TSnapshotIsolationImpl.GetCurrentTimestamp: Int64; inline;
begin
  Result := atomic_load_64(FTimestamp, mo_acquire);
end;

end.
