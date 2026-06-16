unit nextpas.core.lockfree.hashmap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic;

const
  HASHMAP_DEFAULT_SHARD_COUNT = 16;
  HASHMAP_DEFAULT_CAPACITY = 16;
  HASHMAP_LOAD_FACTOR_NUM = 3;
  HASHMAP_LOAD_FACTOR_DEN = 4;

type
  generic TLockFreeHashMapImpl<TKey, TValue> = class
  private type
    TEntryState = (esEmpty, esOccupied, esDeleted);
    TEntry = record
      Key: TKey;
      Value: TValue;
      State: TEntryState;
    end;
    PShard = ^TShard;
    TShard = record
      Lock: Int32;
      Entries: array of TEntry;
      Count: PtrUInt;
      Capacity: PtrUInt;
      Mask: PtrUInt;
    end;
  private
    FShards: array of TShard;
    FShardCount: PtrUInt;
    function HashKey(const AKey: TKey): PtrUInt;
    function ShardIndex(const AKey: TKey): PtrUInt;
    procedure ShardLock(var AShard: TShard);
    procedure ShardUnlock(var AShard: TShard);
    procedure ShardInit(var AShard: TShard; const ACapacity: PtrUInt);
    procedure ShardResize(var AShard: TShard);
    function ShardFind(const AShard: TShard; const AKey: TKey; out AIdx: PtrUInt): Boolean;
  public
    {** @desc 创建分片锁 HashMap }
    constructor Create(const AInitialCapacity: PtrUInt = HASHMAP_DEFAULT_CAPACITY);
    destructor Destroy; override;

    {** @desc 插入或覆盖键值对 }
    procedure Insert(const AKey: TKey; const AValue: TValue);
    {** @desc 查找键；成功返回 True 并设置 AValue }
    function Find(const AKey: TKey; out AValue: TValue): Boolean;
    {** @desc 删除键 }
    function Remove(const AKey: TKey): Boolean;
    {** @desc 检查键是否存在 }
    function Contains(const AKey: TKey): Boolean;
    {** @desc 总元素数（近似值） }
    function Count: PtrUInt;
  end;

  generic TLockFreeHashMap<TKey, TValue> = class(specialize TLockFreeHashMapImpl<TKey, TValue>)
  end;

implementation

function TLockFreeHashMapImpl.HashKey(const AKey: TKey): PtrUInt;
var
  LPtr: PByte;
  LI: PtrUInt;
  LH: PtrUInt;
begin
  LPtr := @AKey;
  LH := 14695981039346656037;
  for LI := 0 to SizeOf(TKey) - 1 do
  begin
    LH := LH xor PtrUInt(LPtr[LI]);
    LH := LH * 1099511628211;
  end;
  Result := LH;
end;

function TLockFreeHashMapImpl.ShardIndex(const AKey: TKey): PtrUInt;
begin
  Result := HashKey(AKey) mod FShardCount;
end;

procedure TLockFreeHashMapImpl.ShardLock(var AShard: TShard);
begin
  while AtomicExchange32(AShard.Lock, 1, moAcquire) <> 0 do
    CpuPause;
end;

procedure TLockFreeHashMapImpl.ShardUnlock(var AShard: TShard);
begin
  AtomicStore32(AShard.Lock, 0, moRelease);
end;

procedure TLockFreeHashMapImpl.ShardInit(var AShard: TShard; const ACapacity: PtrUInt);
var
  LI: PtrUInt;
begin
  AShard.Lock := 0;
  AShard.Capacity := ACapacity;
  AShard.Mask := ACapacity - 1;
  AShard.Count := 0;
  SetLength(AShard.Entries, ACapacity);
  for LI := 0 to ACapacity - 1 do
    AShard.Entries[LI].State := esEmpty;
end;

procedure TLockFreeHashMapImpl.ShardResize(var AShard: TShard);
var
  LOldEntries: array of TEntry;
  LOldCapacity: PtrUInt;
  LOldMask: PtrUInt;
  LI: PtrUInt;
  LIdx: PtrUInt;
  LNewCapacity: PtrUInt;
begin
  LOldEntries := AShard.Entries;
  LOldCapacity := AShard.Capacity;
  LOldMask := AShard.Mask;
  LNewCapacity := LOldCapacity * 2;
  AShard.Capacity := LNewCapacity;
  AShard.Mask := LNewCapacity - 1;
  AShard.Count := 0;
  SetLength(AShard.Entries, LNewCapacity);
  for LI := 0 to LNewCapacity - 1 do
    AShard.Entries[LI].State := esEmpty;
  for LI := 0 to LOldCapacity - 1 do
  begin
    if LOldEntries[LI].State <> esOccupied then
      Continue;
    LIdx := PtrUInt(HashKey(LOldEntries[LI].Key)) and AShard.Mask;
    while AShard.Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and AShard.Mask;
    AShard.Entries[LIdx] := LOldEntries[LI];
    Inc(AShard.Count);
  end;
end;

function TLockFreeHashMapImpl.ShardFind(const AShard: TShard; const AKey: TKey; out AIdx: PtrUInt): Boolean;
var
  LStart: PtrUInt;
begin
  LStart := PtrUInt(HashKey(AKey)) and AShard.Mask;
  AIdx := LStart;
  while AShard.Entries[AIdx].State <> esEmpty do
  begin
    if (AShard.Entries[AIdx].State = esOccupied) and (CompareByte(AShard.Entries[AIdx].Key, AKey, SizeOf(TKey)) = 0) then
      Exit(True);
    AIdx := (AIdx + 1) and AShard.Mask;
    if AIdx = LStart then
      Break;
  end;
  Result := False;
end;

constructor TLockFreeHashMapImpl.Create(const AInitialCapacity: PtrUInt);
var
  LI: PtrUInt;
  LCap: PtrUInt;
begin
  if IsManagedType(TKey) or IsManagedType(TValue) then
    raise EArgumentError.Create('TLockFreeHashMap: TKey and TValue must be unmanaged');
  inherited Create;
  LCap := AInitialCapacity;
  if LCap < 4 then
    LCap := 4;
  FShardCount := HASHMAP_DEFAULT_SHARD_COUNT;
  SetLength(FShards, FShardCount);
  for LI := 0 to FShardCount - 1 do
    ShardInit(FShards[LI], LCap);
end;

destructor TLockFreeHashMapImpl.Destroy;
var
  LI: PtrUInt;
begin
  for LI := 0 to FShardCount - 1 do
    SetLength(FShards[LI].Entries, 0);
  inherited;
end;

procedure TLockFreeHashMapImpl.Insert(const AKey: TKey; const AValue: TValue);
var
  LIdx: PtrUInt;
  LShardIdx: PtrUInt;
  LFound: Boolean;
  LFoundIdx: PtrUInt;
begin
  LShardIdx := ShardIndex(AKey);
  ShardLock(FShards[LShardIdx]);
  try
    if FShards[LShardIdx].Count * HASHMAP_LOAD_FACTOR_DEN >= FShards[LShardIdx].Capacity * HASHMAP_LOAD_FACTOR_NUM then
      ShardResize(FShards[LShardIdx]);
    LFound := ShardFind(FShards[LShardIdx], AKey, LFoundIdx);
    if LFound then
    begin
      FShards[LShardIdx].Entries[LFoundIdx].Value := AValue;
      Exit;
    end;
    LIdx := PtrUInt(HashKey(AKey)) and FShards[LShardIdx].Mask;
    while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
    FShards[LShardIdx].Entries[LIdx].Key := AKey;
    FShards[LShardIdx].Entries[LIdx].Value := AValue;
    FShards[LShardIdx].Entries[LIdx].State := esOccupied;
    Inc(FShards[LShardIdx].Count);
  finally
    ShardUnlock(FShards[LShardIdx]);
  end;
end;

function TLockFreeHashMapImpl.Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
begin
  LShardIdx := ShardIndex(AKey);
  ShardLock(FShards[LShardIdx]);
  try
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
      AValue := FShards[LShardIdx].Entries[LIdx].Value;
  finally
    ShardUnlock(FShards[LShardIdx]);
  end;
end;

function TLockFreeHashMapImpl.Remove(const AKey: TKey): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
begin
  LShardIdx := ShardIndex(AKey);
  ShardLock(FShards[LShardIdx]);
  try
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
    begin
      FShards[LShardIdx].Entries[LIdx].State := esDeleted;
      FShards[LShardIdx].Entries[LIdx].Key := Default(TKey);
      FShards[LShardIdx].Entries[LIdx].Value := Default(TValue);
      Dec(FShards[LShardIdx].Count);
    end;
  finally
    ShardUnlock(FShards[LShardIdx]);
  end;
end;

function TLockFreeHashMapImpl.Contains(const AKey: TKey): Boolean;
var
  LDummy: TValue;
begin
  Result := Find(AKey, LDummy);
end;

function TLockFreeHashMapImpl.Count: PtrUInt;
var
  LI: PtrUInt;
begin
  Result := 0;
  for LI := 0 to FShardCount - 1 do
  begin
    ShardLock(FShards[LI]);
    Inc(Result, FShards[LI].Count);
    ShardUnlock(FShards[LI]);
  end;
end;

end.
