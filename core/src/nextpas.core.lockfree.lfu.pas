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
    FCount: Int64;
    FHits: Int64;
    FMisses: Int64;
    FClosed: Int32;
    FMutationLock: Int32;
    FLocks: array of Int32;
    function HashKey(const AKey: TKey): PtrUInt;
    function FindEntry(AIdx: PtrUInt; AKey: TKey): Integer;
    procedure LockMutation;
    procedure UnlockMutation;
    procedure LockBucket(AIdx: PtrUInt);
    procedure UnlockBucket(AIdx: PtrUInt);
    function FindMinFreqEntry(out ABucket: PtrUInt; out AEntry: Integer): Boolean;
  public
    constructor Create(const AMaxItems: PtrUInt = 1000; const ABucketCount: PtrUInt = 16);
    destructor Destroy; override;
    function Get(const AKey: TKey; out AValue: TValue): Boolean;
    function Put(const AKey: TKey; const AValue: TValue): TLockFreeLfuAddResult;
    function Remove(const AKey: TKey): Boolean;
    function Contains(const AKey: TKey): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean; inline;
    function IsEmpty: Boolean; inline;
    function Count: PtrUInt; inline;
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
  FMutationLock := 0;
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

procedure TConcurrentLFUCacheImpl.LockMutation;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FMutationLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Exit;
    CpuPause;
  end;
end;

procedure TConcurrentLFUCacheImpl.UnlockMutation;
begin
  atomic_store(FMutationLock, 0, mo_release);
end;

procedure TConcurrentLFUCacheImpl.LockBucket(AIdx: PtrUInt);
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLocks[AIdx], LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Exit;
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
  atomic_store(FLocks[AIdx], 0, mo_release);
end;

function TConcurrentLFUCacheImpl.Get(const AKey: TKey; out AValue: TValue): Boolean;
var
  LIdx: PtrUInt;
  LEntry: Integer;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
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
    atomic_fetch_add_64(FBuckets[LIdx][LEntry].Frequency, 1, mo_relaxed);
    atomic_fetch_add_64(FHits, 1, mo_relaxed);
    UnlockBucket(LIdx);
    Exit(True);
  end;
  UnlockBucket(LIdx);
  atomic_fetch_add_64(FMisses, 1, mo_relaxed);
  AValue := Default(TValue);
  Result := False;
end;

function TConcurrentLFUCacheImpl.Put(const AKey: TKey; const AValue: TValue): TLockFreeLfuAddResult;
var
  LIdx: PtrUInt;
  LEntry: Integer;
  LCap, LI: Integer;
  LMinBucket: PtrUInt;
  LMinEntry: Integer;
begin
  LockMutation;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(lfClosed);

    LIdx := HashKey(AKey);
    LockBucket(LIdx);
    try
      LEntry := FindEntry(LIdx, AKey);
      if LEntry >= 0 then
      begin
        FBuckets[LIdx][LEntry].Value := AValue;
        atomic_fetch_add_64(FBuckets[LIdx][LEntry].Frequency, 1, mo_relaxed);
        Exit(lfUpdated);
      end;
    finally
      UnlockBucket(LIdx);
    end;

    if PtrUInt(atomic_load_64(FCount, mo_relaxed)) >= FMaxItems then
    begin
      if not FindMinFreqEntry(LMinBucket, LMinEntry) then
        Exit(lfFull);
      LockBucket(LMinBucket);
      try
        FBuckets[LMinBucket][LMinEntry].Used := False;
        atomic_fetch_sub_64(FCount, 1, mo_relaxed);
      finally
        UnlockBucket(LMinBucket);
      end;
    end;

    if PtrUInt(atomic_load_64(FCount, mo_relaxed)) >= FMaxItems then
      Exit(lfFull);

    LockBucket(LIdx);
    try
      LCap := Length(FBuckets[LIdx]);
      for LI := 0 to LCap - 1 do
      begin
        if not FBuckets[LIdx][LI].Used then
        begin
          FBuckets[LIdx][LI].Key := AKey;
          FBuckets[LIdx][LI].Value := AValue;
          FBuckets[LIdx][LI].Frequency := 1;
          FBuckets[LIdx][LI].Used := True;
          atomic_fetch_add_64(FCount, 1, mo_relaxed);
          Exit(lfAdded);
        end;
      end;
      SetLength(FBuckets[LIdx], LCap * 2);
      FBuckets[LIdx][LCap].Key := AKey;
      FBuckets[LIdx][LCap].Value := AValue;
      FBuckets[LIdx][LCap].Frequency := 1;
      FBuckets[LIdx][LCap].Used := True;
      atomic_fetch_add_64(FCount, 1, mo_relaxed);
      Result := lfAdded;
    finally
      UnlockBucket(LIdx);
    end;
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLFUCacheImpl.Remove(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
  LEntry: Integer;
begin
  LockMutation;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LIdx := HashKey(AKey);
    LockBucket(LIdx);
    try
      LEntry := FindEntry(LIdx, AKey);
      if LEntry < 0 then
        Exit(False);
      FBuckets[LIdx][LEntry].Used := False;
      atomic_fetch_sub_64(FCount, 1, mo_relaxed);
      Result := True;
    finally
      UnlockBucket(LIdx);
    end;
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLFUCacheImpl.Contains(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
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
  LockMutation;
  try
    for LI := 0 to FCapacity - 1 do
    begin
      LockBucket(LI);
      try
        for LJ := 0 to High(FBuckets[LI]) do
          FBuckets[LI][LJ].Used := False;
      finally
        UnlockBucket(LI);
      end;
    end;
    atomic_store_64(FCount, 0, mo_relaxed);
  finally
    UnlockMutation;
  end;
end;

procedure TConcurrentLFUCacheImpl.Close;
begin
  LockMutation;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLFUCacheImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConcurrentLFUCacheImpl.IsEmpty: Boolean; inline;
begin
  Result := atomic_load_64(FCount, mo_relaxed) = 0;
end;

function TConcurrentLFUCacheImpl.Count: PtrUInt; inline;
begin
  Result := PtrUInt(atomic_load_64(FCount, mo_relaxed));
end;

function TConcurrentLFUCacheImpl.GetHitRate: Double;
var
  LHits, LMisses: Int64;
  LTotal: Int64;
begin
  LHits := atomic_load_64(FHits, mo_relaxed);
  LMisses := atomic_load_64(FMisses, mo_relaxed);
  LTotal := LHits + LMisses;
  if LTotal = 0 then
    Exit(0.0);
  Result := Double(LHits) / Double(LTotal);
end;

function TConcurrentLFUCacheImpl.FindMinFreqEntry(out ABucket: PtrUInt; out AEntry: Integer): Boolean;
var
  LI, LJ: PtrUInt;
  LMinFreq: Int64;
  LFound: Boolean;
begin
  LMinFreq := 0;
  LFound := False;
  ABucket := 0;
  AEntry := -1;
  for LI := 0 to FCapacity - 1 do
  begin
    LockBucket(LI);
    try
      for LJ := 0 to High(FBuckets[LI]) do
      begin
        if FBuckets[LI][LJ].Used and
           ((not LFound) or (FBuckets[LI][LJ].Frequency < LMinFreq)) then
        begin
          LFound := True;
          LMinFreq := FBuckets[LI][LJ].Frequency;
          ABucket := LI;
          AEntry := Integer(LJ);
        end;
      end;
    finally
      UnlockBucket(LI);
    end;
  end;
  Result := LFound;
end;

end.
