unit nextpas.core.lockfree.hashtable;
{**
 * @desc Lock-free Hash Table with open addressing and linear probing.
 *
 * @details Active-reader gate for lock-free reads, writer spin lock for writes:
 *   - Open addressing with linear probing for collision resolution
 *   - Power-of-2 capacity with bit-mask modulo
 *   - Insert/Find/Remove/Contains operations
 *   - Dynamic resize support
 *
 * @concurrency Thread-safe for multiple readers and writers:
 *   - Find/Contains: lock-free reads via active-reader gate
 *   - Insert/Remove: exclusive writer lock
 *   - Resize: coordinated with active readers
 *
 * @see Open Addressing — collision resolution strategy
 * @see Linear Probing — cache-friendly probing sequence
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.lockfree.base;

const
  HASH_TABLE_EMPTY = -1;
  HASH_TABLE_DELETED = -2;
  HASH_TABLE_RESERVED = 3;

type
  TLockFreeHashTableResult = (
    htOk,
    htFull,
    htNotFound,
    htExists,
    htClosed
  );

  {** @desc 并发哈希表（开放寻址 + 线性探测）
    @details 读路径使用 active-reader gate，写入和扩容由 writer spin lock 串行化。
      - 开放寻址，线性探测解决冲突
      - 2 的幂容量，位运算取模
      - 支持 Insert/Find/Remove/Contains
      - 自动扩容（负载因子 > 0.7）
      - 支持 Close 语义
  }
  generic TLockFreeHashTableImpl<TKey, TValue> = class
  private type
    TSlot = record
      FKey: TKey;
      FValue: TValue;
      FState: Int32;  // 0=empty, 1=occupied, 2=deleted
    end;
  private
    FSlots: array of TSlot;
    FCapacity: Int32;
    FCount: Int64;
    FUsedCount: Int64;
    FClosed: Int32;
    FLock: Int32;       // writer/grow spin lock
    FGrowing: Int32;    // 1=table publication in progress
    FActiveReaders: Int32;

    function HashKey(const AKey: TKey): UInt32;
    function FindSlot(const AKey: TKey): Int32;
    procedure EnterRead;
    procedure LeaveRead;
    procedure LockWriter;
    procedure UnlockWriter;
    function GrowLocked: Boolean;
  public
    constructor Create(ACapacity: Int32 = 64);
    destructor Destroy; override;

    {** 插入键值对 }
    function Insert(const AKey: TKey; const AValue: TValue): TLockFreeHashTableResult;
    {** 查找值 }
    function Find(const AKey: TKey; out AValue: TValue): TLockFreeHashTableResult;
    {** 删除键值对 }
    function Remove(const AKey: TKey): TLockFreeHashTableResult;
    {** 是否包含键 }
    function Contains(const AKey: TKey): Boolean;
    {** 大致数量 }
    function ApproxCount: Int64; inline;
    {** 是否为空 }
    function IsEmpty: Boolean; inline;
    {** 关闭 }
    procedure Close;
    {** 清空所有键值对 }
    procedure Clear;
    {** 是否已关闭 }
    function IsClosed: Boolean; inline;
  end;

implementation

function TLockFreeHashTableImpl.HashKey(const AKey: TKey): UInt32;
var
  LBytes: PByte;
  I, LSize: Integer;
begin
  // FNV-1a hash
  Result := 2166136261;
  LSize := SizeOf(TKey);
  LBytes := PByte(@AKey);
  for I := 0 to LSize - 1 do
  begin
    Result := Result xor LBytes[I];
    Result := Result * 16777619;
  end;
end;

function TLockFreeHashTableImpl.FindSlot(const AKey: TKey): Int32;
var
  LHash, LIdx: Int32;
  LState: Int32;
begin
  LHash := HashKey(AKey);
  for LIdx := 0 to FCapacity - 1 do
  begin
    Result := (LHash + LIdx) and (FCapacity - 1);
    LState := AtomicLoad32(FSlots[Result].FState, moAcquire);
    if LState = 0 then
      Exit(Result);
    if LState = 1 then
    begin
      if FSlots[Result].FKey = AKey then
        Exit(Result);
    end;
  end;
  Result := -1;
end;

procedure TLockFreeHashTableImpl.EnterRead;
begin
  repeat
    while AtomicLoad32(FGrowing, moAcquire) <> 0 do
      CpuPause;
    AtomicFetchAdd32(FActiveReaders, 1, moAcqRel);
    if AtomicLoad32(FGrowing, moAcquire) = 0 then
      Exit;
    AtomicFetchSub32(FActiveReaders, 1, moAcqRel);
  until False;
end;

procedure TLockFreeHashTableImpl.LeaveRead;
begin
  AtomicFetchSub32(FActiveReaders, 1, moRelease);
end;

procedure TLockFreeHashTableImpl.LockWriter;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 0, 1, moAcquire) <> 0 do
  begin
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
end;

procedure TLockFreeHashTableImpl.UnlockWriter;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TLockFreeHashTableImpl.GrowLocked: Boolean;
var
  LOldCap, LNewCap, LI, LProbe, LIdx: Int32;
  LNewSlots: array of TSlot;
  LLiveCount: Int64;
begin
  LOldCap := FCapacity;
  if FUsedCount * 4 < Int64(LOldCap) * 3 then
    Exit(True);

  LLiveCount := AtomicLoad64(FCount, moRelaxed);
  if LLiveCount * 2 < LOldCap then
    LNewCap := LOldCap
  else
  begin
    if LOldCap > High(Int32) div 2 then
      Exit(False);
    LNewCap := LOldCap * 2;
  end;

  AtomicStore32(FGrowing, 1, moRelease);
  try
    while AtomicLoad32(FActiveReaders, moAcquire) <> 0 do
      CpuPause;

    SetLength(LNewSlots, LNewCap);
    for LI := 0 to LNewCap - 1 do
      LNewSlots[LI].FState := 0;

    for LI := 0 to LOldCap - 1 do
    begin
      if FSlots[LI].FState <> 1 then
        Continue;
      LIdx := Int32(HashKey(FSlots[LI].FKey) and UInt32(LNewCap - 1));
      for LProbe := 0 to LNewCap - 1 do
      begin
        if LNewSlots[LIdx].FState = 0 then
          Break;
        LIdx := (LIdx + 1) and (LNewCap - 1);
      end;
      LNewSlots[LIdx].FKey := FSlots[LI].FKey;
      LNewSlots[LIdx].FValue := FSlots[LI].FValue;
      LNewSlots[LIdx].FState := 1;
    end;

    FSlots := LNewSlots;
    FCapacity := LNewCap;
    FUsedCount := LLiveCount;
    Result := True;
  finally
    AtomicStore32(FGrowing, 0, moRelease);
  end;
end;

constructor TLockFreeHashTableImpl.Create(ACapacity: Int32);
var
  I: Int32;
begin
  if IsManagedType(TKey) or IsManagedType(TValue) then
    raise EArgumentError.Create('TLockFreeHashTable: TKey and TValue must be unmanaged');
  inherited Create;
  if ACapacity < 16 then
    ACapacity := 16;
  // Round up to power of 2
  ACapacity := LockFreeNextPow2(ACapacity);
  SetLength(FSlots, ACapacity);
  for I := 0 to ACapacity - 1 do
    FSlots[I].FState := 0;
  FCapacity := ACapacity;
  FCount := 0;
  FUsedCount := 0;
  FClosed := 0;
  FLock := 0;
  FGrowing := 0;
  FActiveReaders := 0;
end;

destructor TLockFreeHashTableImpl.Destroy;
begin
  SetLength(FSlots, 0);
  inherited Destroy;
end;

function TLockFreeHashTableImpl.Insert(const AKey: TKey; const AValue: TValue): TLockFreeHashTableResult;
var
  LIdx: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(htClosed);
  LockWriter;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(htClosed);

    LIdx := FindSlot(AKey);
    if (LIdx >= 0) and (FSlots[LIdx].FState = 1) and
       (FSlots[LIdx].FKey = AKey) then
      Exit(htExists);

    if FUsedCount * 4 >= Int64(FCapacity) * 3 then
    begin
      if not GrowLocked then
        Exit(htFull);
      LIdx := FindSlot(AKey);
    end;
    if LIdx < 0 then
      Exit(htFull);

    AtomicStore32(FSlots[LIdx].FState, HASH_TABLE_RESERVED, moRelease);
    try
      FSlots[LIdx].FKey := AKey;
      FSlots[LIdx].FValue := AValue;
    except
      FSlots[LIdx].FKey := Default(TKey);
      FSlots[LIdx].FValue := Default(TValue);
      AtomicStore32(FSlots[LIdx].FState, 0, moRelease);
      raise;
    end;
    AtomicStore32(FSlots[LIdx].FState, 1, moRelease);
    Inc(FUsedCount);
    AtomicFetchAdd64(FCount, 1, moRelaxed);
    Result := htOk;
  finally
    UnlockWriter;
  end;
end;

function TLockFreeHashTableImpl.Find(const AKey: TKey; out AValue: TValue): TLockFreeHashTableResult;
var
  LIdx: Int32;
begin
  EnterRead;
  try
    LIdx := FindSlot(AKey);
    if LIdx < 0 then
      Exit(htNotFound);
    if (AtomicLoad32(FSlots[LIdx].FState, moAcquire) = 1) and
       (FSlots[LIdx].FKey = AKey) then
    begin
      AValue := FSlots[LIdx].FValue;
      Exit(htOk);
    end;
    Result := htNotFound;
  finally
    LeaveRead;
  end;
end;

function TLockFreeHashTableImpl.Remove(const AKey: TKey): TLockFreeHashTableResult;
var
  LIdx: Int32;
begin
  LockWriter;
  try
    LIdx := FindSlot(AKey);
    if LIdx < 0 then
      Exit(htNotFound);
    if (FSlots[LIdx].FState = 1) and (FSlots[LIdx].FKey = AKey) then
    begin
      AtomicStore32(FSlots[LIdx].FState, 2, moRelease);
      AtomicFetchSub64(FCount, 1, moRelaxed);
      Exit(htOk);
    end;
    Result := htNotFound;
  finally
    UnlockWriter;
  end;
end;

function TLockFreeHashTableImpl.Contains(const AKey: TKey): Boolean;
var
  LIdx: Int32;
begin
  EnterRead;
  try
    LIdx := FindSlot(AKey);
    Result := (LIdx >= 0) and
              (AtomicLoad32(FSlots[LIdx].FState, moAcquire) = 1) and
              (FSlots[LIdx].FKey = AKey);
  finally
    LeaveRead;
  end;
end;

function TLockFreeHashTableImpl.ApproxCount: Int64; inline;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

function TLockFreeHashTableImpl.IsEmpty: Boolean; inline;
begin
  Result := AtomicLoad64(FCount, moRelaxed) = 0;
end;

procedure TLockFreeHashTableImpl.Close;
begin
  LockWriter;
  try
    AtomicStore32(FClosed, 1, moRelease);
  finally
    UnlockWriter;
  end;
end;

procedure TLockFreeHashTableImpl.Clear;
var
  LI: Int32;
begin
  LockWriter;
  try
    for LI := 0 to FCapacity - 1 do
    begin
      if FSlots[LI].FState <> 0 then
      begin
        FSlots[LI].FKey := Default(TKey);
        FSlots[LI].FValue := Default(TValue);
        AtomicStore32(FSlots[LI].FState, 0, moRelease);
      end;
    end;
    AtomicStore64(FCount, 0, moRelaxed);
    FUsedCount := 0;
  finally
    UnlockWriter;
  end;
end;

function TLockFreeHashTableImpl.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
