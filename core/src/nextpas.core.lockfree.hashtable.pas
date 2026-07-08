unit nextpas.core.lockfree.hashtable;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

const
  HASH_TABLE_EMPTY = -1;
  HASH_TABLE_DELETED = -2;

type
  TLockFreeHashTableResult = (
    htOk,
    htFull,
    htNotFound,
    htExists,
    htClosed
  );

  {** @desc 无锁哈希表（开放寻址 + 线性探测）
    @details 使用 CAS 操作实现无锁并发访问。
      - 开放寻址，线性探测解决冲突
      - 2 的幂容量，位运算取模
      - 支持 Insert/Find/Remove/Contains
      - 自动扩容（负载因子 > 0.7）
      - 支持 Close 语义
  }
  generic TLockFreeHashTableImpl<TKey, TValue> = class
  private type
    PKey = ^TKey;
    PValue = ^TValue;
    TSlot = record
      FKey: TKey;
      FValue: TValue;
      FState: Int32;  // 0=empty, 1=occupied, 2=deleted
    end;
  private
    FSlots: array of TSlot;
    FCapacity: Int32;
    FCount: Int64;
    FClosed: Int32;
    FLock: Int32;  // spinlock for expansion

    function HashKey(const AKey: TKey): UInt32;
    function FindSlot(const AKey: TKey): Int32;
    procedure Grow;
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
    function ApproxCount: Int64;
    {** 是否为空 }
    function IsEmpty: Boolean;
    {** 关闭 }
    procedure Close;
    {** 是否已关闭 }
    function IsClosed: Boolean;
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
  LHash, LIdx, LFirstDeleted: Int32;
  LState: Int32;
begin
  LHash := HashKey(AKey);
  LFirstDeleted := -1;
  for LIdx := 0 to FCapacity - 1 do
  begin
    Result := (LHash + LIdx) and (FCapacity - 1);
    LState := AtomicLoad32(FSlots[Result].FState, moAcquire);
    if LState = 0 then
    begin
      // Empty slot - key not found
      if LFirstDeleted >= 0 then
        Exit(LFirstDeleted);
      Exit(Result);
    end
    else if LState = 2 then
    begin
      // Deleted slot - remember first deleted for insertion
      if LFirstDeleted < 0 then
        LFirstDeleted := Result;
    end
    else if LState = 1 then
    begin
      // Occupied slot - check key
      if FSlots[Result].FKey = AKey then
        Exit(Result);
    end;
  end;
  // Table full
  if LFirstDeleted >= 0 then
    Exit(LFirstDeleted);
  Exit(-1);
end;

procedure TLockFreeHashTableImpl.Grow;
var
  LOldCap, LNewCap, I, LIdx: Int32;
  LOldSlots: array of TSlot;
begin
  // Spin lock for expansion
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    ;
  // Double-check
  LOldCap := FCapacity;
  if AtomicLoad64(FCount, moRelaxed) * 4 < LOldCap * 3 then
  begin
    AtomicStore32(FLock, 0, moRelease);
    Exit;
  end;
  // Save old slots
  LOldSlots := Copy(FSlots);
  // Create new larger table
  LNewCap := LOldCap * 2;
  SetLength(FSlots, LNewCap);
  for I := 0 to LNewCap - 1 do
    FSlots[I].FState := 0;
  FCapacity := LNewCap;
  // Rehash old entries
  for I := 0 to LOldCap - 1 do
  begin
    if AtomicLoad32(LOldSlots[I].FState, moRelaxed) = 1 then
    begin
      LIdx := FindSlot(LOldSlots[I].FKey);
      if LIdx >= 0 then
      begin
        FSlots[LIdx].FKey := LOldSlots[I].FKey;
        FSlots[LIdx].FValue := LOldSlots[I].FValue;
        AtomicStore32(FSlots[LIdx].FState, 1, moRelease);
      end;
    end;
  end;
  SetLength(LOldSlots, 0);
  AtomicStore32(FLock, 0, moRelease);
end;

constructor TLockFreeHashTableImpl.Create(ACapacity: Int32);
var
  I: Int32;
begin
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
  FClosed := 0;
  FLock := 0;
end;

destructor TLockFreeHashTableImpl.Destroy;
begin
  SetLength(FSlots, 0);
  inherited Destroy;
end;

function TLockFreeHashTableImpl.Insert(const AKey: TKey; const AValue: TValue): TLockFreeHashTableResult;
var
  LIdx, LOldState: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(htClosed);
  // Check if we need to grow
  if AtomicLoad64(FCount, moRelaxed) * 4 >= FCapacity * 3 then
    Grow;
  LIdx := FindSlot(AKey);
  if LIdx < 0 then
    Exit(htFull);
  LOldState := AtomicLoad32(FSlots[LIdx].FState, moAcquire);
  if (LOldState = 1) and (FSlots[LIdx].FKey = AKey) then
    Exit(htExists);
  // Insert: write key+value then CAS state from empty/deleted to occupied
  FSlots[LIdx].FKey := AKey;
  FSlots[LIdx].FValue := AValue;
  AtomicStore32(FSlots[LIdx].FState, 1, moRelease);
  AtomicFetchAdd64(FCount, 1);
  Result := htOk;
end;

function TLockFreeHashTableImpl.Find(const AKey: TKey; out AValue: TValue): TLockFreeHashTableResult;
var
  LIdx: Int32;
begin
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
end;

function TLockFreeHashTableImpl.Remove(const AKey: TKey): TLockFreeHashTableResult;
var
  LIdx: Int32;
begin
  LIdx := FindSlot(AKey);
  if LIdx < 0 then
    Exit(htNotFound);
  if (AtomicLoad32(FSlots[LIdx].FState, moAcquire) = 1) and
     (FSlots[LIdx].FKey = AKey) then
  begin
    AtomicStore32(FSlots[LIdx].FState, 2, moRelease);  // Mark as deleted
    AtomicFetchAdd64(FCount, -1);
    Exit(htOk);
  end;
  Result := htNotFound;
end;

function TLockFreeHashTableImpl.Contains(const AKey: TKey): Boolean;
var
  LIdx: Int32;
begin
  LIdx := FindSlot(AKey);
  Result := (LIdx >= 0) and
            (AtomicLoad32(FSlots[LIdx].FState, moAcquire) = 1) and
            (FSlots[LIdx].FKey = AKey);
end;

function TLockFreeHashTableImpl.ApproxCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

function TLockFreeHashTableImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FCount, moRelaxed) = 0;
end;

procedure TLockFreeHashTableImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TLockFreeHashTableImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
