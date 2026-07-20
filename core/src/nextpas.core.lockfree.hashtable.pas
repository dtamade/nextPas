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

uses
  nextpas.core.errors;

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
    LState := atomic_load(FSlots[Result].FState, mo_acquire);
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
    while atomic_load(FGrowing, mo_acquire) <> 0 do
      CpuPause;
    atomic_fetch_add(FActiveReaders, 1, mo_acq_rel);
    if atomic_load(FGrowing, mo_acquire) = 0 then
      Exit;
    atomic_fetch_sub(FActiveReaders, 1, mo_acq_rel);
  until False;
end;

procedure TLockFreeHashTableImpl.LeaveRead;
begin
  atomic_fetch_sub(FActiveReaders, 1, mo_release);
end;

procedure TLockFreeHashTableImpl.LockWriter;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acquire, mo_relaxed) then
      Exit;
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
  atomic_store(FLock, 0, mo_release);
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

  LLiveCount := atomic_load_64(FCount, mo_relaxed);
  if LLiveCount * 2 < LOldCap then
    LNewCap := LOldCap
  else
  begin
    if LOldCap > High(Int32) div 2 then
      Exit(False);
    LNewCap := LOldCap * 2;
  end;

  atomic_store(FGrowing, 1, mo_release);
  try
    while atomic_load(FActiveReaders, mo_acquire) <> 0 do
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
    atomic_store(FGrowing, 0, mo_release);
  end;
end;

constructor TLockFreeHashTableImpl.Create(ACapacity: Int32);
var
  I: Int32;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TLockFreeHashTable: TKey must be unmanaged (no string/interface/dynarray)');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TLockFreeHashTable: TValue must be unmanaged (no string/interface/dynarray)');
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
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(htClosed);
  LockWriter;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
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

    atomic_store(FSlots[LIdx].FState, HASH_TABLE_RESERVED, mo_release);
    try
      FSlots[LIdx].FKey := AKey;
      FSlots[LIdx].FValue := AValue;
    except
      FSlots[LIdx].FKey := Default(TKey);
      FSlots[LIdx].FValue := Default(TValue);
      atomic_store(FSlots[LIdx].FState, 0, mo_release);
      raise;
    end;
    atomic_store(FSlots[LIdx].FState, 1, mo_release);
    Inc(FUsedCount);
    atomic_fetch_add_64(FCount, 1, mo_relaxed);
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
    if (atomic_load(FSlots[LIdx].FState, mo_acquire) = 1) and
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
      atomic_store(FSlots[LIdx].FState, 2, mo_release);
      atomic_fetch_sub_64(FCount, 1, mo_relaxed);
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
              (atomic_load(FSlots[LIdx].FState, mo_acquire) = 1) and
              (FSlots[LIdx].FKey = AKey);
  finally
    LeaveRead;
  end;
end;

function TLockFreeHashTableImpl.ApproxCount: Int64; inline;
begin
  Result := atomic_load_64(FCount, mo_relaxed);
end;

function TLockFreeHashTableImpl.IsEmpty: Boolean; inline;
begin
  Result := atomic_load_64(FCount, mo_relaxed) = 0;
end;

procedure TLockFreeHashTableImpl.Close;
begin
  LockWriter;
  try
    atomic_store(FClosed, 1, mo_release);
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
        atomic_store(FSlots[LI].FState, 0, mo_release);
      end;
    end;
    atomic_store_64(FCount, 0, mo_relaxed);
    FUsedCount := 0;
  finally
    UnlockWriter;
  end;
end;

function TLockFreeHashTableImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
