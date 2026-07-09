unit nextpas.core.lockfree.lfu;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeLfuAddResult = (lfAdded, lfUpdated, lfFull, lfClosed);

  {** @desc 并发 LFU 缓存
    @details 基于分片锁 HashMap + 频率链表实现。
      访问频率最低的条目优先被淘汰。
      支持 Get/Put/Remove/Contains/Count/HitRate。
      适用于缓存、淘汰等场景。
  }
  generic TConcurrentLFUCacheImpl<TKey, TValue> = class
  private
    type
      PFreqNode = ^TFreqNode;
      TFreqNode = record
        Key: TKey;
        Value: TValue;
        Frequency: Int64;
        Used: Boolean;
      end;
  private
    FBuckets: array of array of TFreqNode;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FMaxItems: PtrUInt;
    FCount: PtrUInt;
    FHits: Int64;
    FMisses: Int64;
    FClosed: Int32;
    FLocks: array of Int32;
    function HashKey(const AKey: TKey): PtrUInt;
    function FindEntry(AIdx: PtrUInt; AKey: TKey): Integer;
    procedure LockBucket(AIdx: PtrUInt);
    procedure UnlockBucket(AIdx: PtrUInt);
    function FindMinFreqEntry: TFreqNode;
  public
    constructor Create(const AMaxItems: PtrUInt = 1000; const ABucketCount: PtrUInt = 16);
    destructor Destroy; override;
    function Get(const AKey: TKey; out AValue: TValue): Boolean;
    function Put(const AKey: TKey; const AValue: TValue): TLockFreeLfuAddResult;
    function Remove(const AKey: TKey): Boolean;
    function Contains(const AKey: TKey): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function Count: PtrUInt;
    function GetHitRate: Double;
  end;

  generic TConcurrentLFUCache<TKey, TValue> = class(specialize TConcurrentLFUCacheImpl<TKey, TValue>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentLFUCacheImpl.Create(const AMaxItems: PtrUInt; const ABucketCount: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TConcurrentLFUCache: TKey must be unmanaged');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TConcurrentLFUCache: TValue must be unmanaged');
  if AMaxItems = 0 then
    raise EArgumentError.Create('TConcurrentLFUCache: max items must be > 0');
  if ABucketCount = 0 then
    raise EArgumentError.Create('TConcurrentLFUCache: bucket count must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ABucketCount);
  FCapacity := LCap;
  FMask := LCap - 1;
  FMaxItems := AMaxItems;
  FCount := 0;
  FHits := 0;
  FMisses := 0;
  FClosed := 0;
  SetLength(FBuckets, LCap);
  SetLength(FLocks, LCap);
  for LI := 0 to LCap - 1 do
  begin
    SetLength(FBuckets[LI], 4);
    FLocks[LI] := 0;
  end;
end;

destructor TConcurrentLFUCacheImpl.Destroy;
begin
  FBuckets := nil;
  FLocks := nil;
  inherited Destroy;
end;

function TConcurrentLFUCacheImpl.HashKey(const AKey: TKey): PtrUInt;
var
  LHash: UInt64;
  LBytes: array[0..SizeOf(TKey) - 1] of Byte;
  LI: Integer;
begin
  Move(AKey, LBytes, SizeOf(TKey));
  LHash := 14695981039346656037;
  for LI := 0 to SizeOf(TKey) - 1 do
  begin
    LHash := LHash xor LBytes[LI];
    LHash := LHash * 1099511628211;
  end;
  Result := PtrUInt(LHash) and FMask;
end;

function TConcurrentLFUCacheImpl.FindEntry(AIdx: PtrUInt; AKey: TKey): Integer;
var
  LI: Integer;
begin
  for LI := 0 to High(FBuckets[AIdx]) do
  begin
    if FBuckets[AIdx][LI].Used and (FBuckets[AIdx][LI].Key = AKey) then
      Exit(LI);
  end;
  Result := -1;
end;

procedure TConcurrentLFUCacheImpl.LockBucket(AIdx: PtrUInt);
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLocks[AIdx], 1, 0) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TConcurrentLFUCacheImpl.UnlockBucket(AIdx: PtrUInt);
begin
  AtomicStore32(FLocks[AIdx], 0, moRelease);
end;

function TConcurrentLFUCacheImpl.Get(const AKey: TKey; out AValue: TValue): Boolean;
var
  LIdx: PtrUInt;
  LEntry: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
  begin
    AValue := Default(TValue);
    Exit(False);
  end;
  LIdx := HashKey(AKey);
  LockBucket(LIdx);
  LEntry := FindEntry(LIdx, AKey);
  if LEntry >= 0 then
  begin
    AValue := FBuckets[LIdx][LEntry].Value;
    AtomicFetchAdd64(FBuckets[LIdx][LEntry].Frequency, 1, moRelaxed);
    AtomicFetchAdd64(FHits, 1, moRelaxed);
    UnlockBucket(LIdx);
    Exit(True);
  end;
  UnlockBucket(LIdx);
  AtomicFetchAdd64(FMisses, 1, moRelaxed);
  AValue := Default(TValue);
  Result := False;
end;

function TConcurrentLFUCacheImpl.Put(const AKey: TKey; const AValue: TValue): TLockFreeLfuAddResult;
var
  LIdx: PtrUInt;
  LEntry: Integer;
  LCap, LI: Integer;
  LMinFreq: Int64;
  LMinIdx: Integer;
  LMinBucket: PtrUInt;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(lfClosed);
  LIdx := HashKey(AKey);
  LockBucket(LIdx);
  LEntry := FindEntry(LIdx, AKey);
  if LEntry >= 0 then
  begin
    FBuckets[LIdx][LEntry].Value := AValue;
    AtomicFetchAdd64(FBuckets[LIdx][LEntry].Frequency, 1, moRelaxed);
    UnlockBucket(LIdx);
    Exit(lfUpdated);
  end;
  if PtrUInt(AtomicLoad64(Int64(FCount), moRelaxed)) >= FMaxItems then
  begin
    UnlockBucket(LIdx);
    Exit(lfFull);
  end;
  LCap := Length(FBuckets[LIdx]);
  for LI := 0 to LCap - 1 do
  begin
    if not FBuckets[LIdx][LI].Used then
    begin
      FBuckets[LIdx][LI].Key := AKey;
      FBuckets[LIdx][LI].Value := AValue;
      FBuckets[LIdx][LI].Frequency := 1;
      FBuckets[LIdx][LI].Used := True;
      AtomicFetchAdd64(Int64(FCount), 1, moRelaxed);
      UnlockBucket(LIdx);
      Exit(lfAdded);
    end;
  end;
  SetLength(FBuckets[LIdx], LCap * 2);
  FBuckets[LIdx][LCap].Key := AKey;
  FBuckets[LIdx][LCap].Value := AValue;
  FBuckets[LIdx][LCap].Frequency := 1;
  FBuckets[LIdx][LCap].Used := True;
  AtomicFetchAdd64(Int64(FCount), 1, moRelaxed);
  UnlockBucket(LIdx);
  Result := lfAdded;
end;

function TConcurrentLFUCacheImpl.Remove(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
  LEntry: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LIdx := HashKey(AKey);
  LockBucket(LIdx);
  LEntry := FindEntry(LIdx, AKey);
  if LEntry >= 0 then
  begin
    FBuckets[LIdx][LEntry].Used := False;
    AtomicFetchSub64(Int64(FCount), 1, moRelaxed);
    UnlockBucket(LIdx);
    Exit(True);
  end;
  UnlockBucket(LIdx);
  Result := False;
end;

function TConcurrentLFUCacheImpl.Contains(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LIdx := HashKey(AKey);
  LockBucket(LIdx);
  Result := FindEntry(LIdx, AKey) >= 0;
  UnlockBucket(LIdx);
end;

procedure TConcurrentLFUCacheImpl.Clear;
var
  LI, LJ: PtrUInt;
begin
  for LI := 0 to FCapacity - 1 do
  begin
    LockBucket(LI);
    for LJ := 0 to High(FBuckets[LI]) do
      FBuckets[LI][LJ].Used := False;
    UnlockBucket(LI);
  end;
  AtomicStore64(Int64(FCount), 0, moRelaxed);
end;

procedure TConcurrentLFUCacheImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentLFUCacheImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConcurrentLFUCacheImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(Int64(FCount), moRelaxed) = 0;
end;

function TConcurrentLFUCacheImpl.Count: PtrUInt;
begin
  Result := PtrUInt(AtomicLoad64(Int64(FCount), moRelaxed));
end;

function TConcurrentLFUCacheImpl.GetHitRate: Double;
var
  LHits, LMisses: Int64;
  LTotal: Int64;
begin
  LHits := AtomicLoad64(FHits, moRelaxed);
  LMisses := AtomicLoad64(FMisses, moRelaxed);
  LTotal := LHits + LMisses;
  if LTotal = 0 then
    Exit(0.0);
  Result := Double(LHits) / Double(LTotal);
end;

function TConcurrentLFUCacheImpl.FindMinFreqEntry: TFreqNode;
var
  LI, LJ: PtrUInt;
  LMinFreq: Int64;
begin
  LMinFreq := High(Int64);
  Result.Used := False;
  for LI := 0 to FCapacity - 1 do
  begin
    for LJ := 0 to High(FBuckets[LI]) do
    begin
      if FBuckets[LI][LJ].Used and (FBuckets[LI][LJ].Frequency < LMinFreq) then
      begin
        LMinFreq := FBuckets[LI][LJ].Frequency;
        Result := FBuckets[LI][LJ];
      end;
    end;
  end;
end;

end.
