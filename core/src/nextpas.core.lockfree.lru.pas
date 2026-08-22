unit nextpas.core.lockfree.lru;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeLruAddResult = (lrAdded, lrUpdated, lrFull, lrClosed);

  {** @desc 并发 LRU 缓存
    @details 基于分片锁 HashMap 实现，使用访问计数器近似 LRU。
      支持 Get/Put/Remove/Clear/Capacity/Count。
      适用于缓存、淘汰等场景。
  }
  generic TConcurrentLruCacheImpl<TKey, TValue> = class
  private
    type
      TEntry = record
        Key: TKey;
        Value: TValue;
        AccessCount: Int64;
        Used: Boolean;
      end;
  private
    FBuckets: array of array of TEntry;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FMaxItems: PtrUInt;
    FCount: PtrUInt;
    FAccessCounter: Int64;
    FClosed: Int32;
    FMutationLock: Int32;
    // Shard locks (one per bucket)
    FLocks: array of Int32;
    function HashKey(const AKey: TKey): PtrUInt;
    function FindEntry(AIdx: PtrUInt; AKey: TKey): Integer;
    procedure LockMutation;
    procedure UnlockMutation;
    procedure LockBucket(AIdx: PtrUInt);
    procedure UnlockBucket(AIdx: PtrUInt);
  public
    constructor Create(const AMaxItems: PtrUInt = 1000; const ABucketCount: PtrUInt = 16);
    destructor Destroy; override;
    function Get(const AKey: TKey; out AValue: TValue): Boolean;
    function Put(const AKey: TKey; const AValue: TValue): TLockFreeLruAddResult;
    function Remove(const AKey: TKey): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean; inline;
    function IsEmpty: Boolean;
    function Count: PtrUInt;
    function Capacity: PtrUInt; inline;
  end;

  generic TConcurrentLruCache<TKey, TValue> = class(specialize TConcurrentLruCacheImpl<TKey, TValue>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentLruCacheImpl.Create(const AMaxItems: PtrUInt; const ABucketCount: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TConcurrentLruCache: TKey must be unmanaged (no string/interface/dynarray)');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TConcurrentLruCache: TValue must be unmanaged (no string/interface/dynarray)');
  if AMaxItems = 0 then
    raise EArgumentError.Create('TConcurrentLruCache: max items must be > 0');
  if ABucketCount = 0 then
    raise EArgumentError.Create('TConcurrentLruCache: bucket count must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ABucketCount);
  FCapacity := LCap;
  FMask := LCap - 1;
  FMaxItems := AMaxItems;
  FCount := 0;
  FAccessCounter := 0;
  FMutationLock := 0;
  SetLength(FBuckets, LCap);
  SetLength(FLocks, LCap);
  for LI := 0 to LCap - 1 do
  begin
    SetLength(FBuckets[LI], 4); // Initial bucket size
    FLocks[LI] := 0;
  end;
  FClosed := 0;
end;

destructor TConcurrentLruCacheImpl.Destroy;
var
  LI: PtrUInt;
begin
  for LI := 0 to FCapacity - 1 do
    SetLength(FBuckets[LI], 0);
  SetLength(FBuckets, 0);
  SetLength(FLocks, 0);
  inherited Destroy;
end;

function TConcurrentLruCacheImpl.HashKey(const AKey: TKey): PtrUInt;
var
  LPtr: PByte;
  LI: PtrUInt;
  LH: PtrUInt;
begin
  LPtr := @AKey;
  LH := 14695981039346656037;
  for LI := 0 to SizeOf(TKey) - 1 do
    LH := (LH xor PtrUInt(LPtr[LI])) * 1099511628211;
  Result := LH;
end;

function TConcurrentLruCacheImpl.FindEntry(AIdx: PtrUInt; AKey: TKey): Integer;
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

procedure TConcurrentLruCacheImpl.LockMutation;
var
  LCasExpected: Int32;
begin
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FMutationLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    CpuPause;
  end;
end;

procedure TConcurrentLruCacheImpl.UnlockMutation;
begin
  atomic_store(FMutationLock, 0, mo_release);
end;

procedure TConcurrentLruCacheImpl.LockBucket(AIdx: PtrUInt);
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLocks[AIdx], LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
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
end;

procedure TConcurrentLruCacheImpl.UnlockBucket(AIdx: PtrUInt);
begin
  atomic_store(FLocks[AIdx], 0, mo_release);
end;

function TConcurrentLruCacheImpl.Get(const AKey: TKey; out AValue: TValue): Boolean;
var
  LIdx: PtrUInt;
  LEntryIdx: Integer;
begin
  LIdx := HashKey(AKey) and FMask;
  LockBucket(LIdx);
  try
    LEntryIdx := FindEntry(LIdx, AKey);
    if LEntryIdx < 0 then
      Exit(False);
    AValue := FBuckets[LIdx][LEntryIdx].Value;
    // Update access count
    atomic_fetch_add_64(FAccessCounter, 1, mo_relaxed);
    FBuckets[LIdx][LEntryIdx].AccessCount := atomic_load_64(FAccessCounter, mo_relaxed);
    Result := True;
  finally
    UnlockBucket(LIdx);
  end;
end;

function TConcurrentLruCacheImpl.Put(const AKey: TKey; const AValue: TValue): TLockFreeLruAddResult;
var
  LIdx: PtrUInt;
  LEntryIdx: Integer;
  LMinBucket: PtrUInt;
  LMinIdx: Integer;
  LMinCount: Int64;
  LFound: Boolean;
  LBucketIdx: PtrUInt;
  LI: Integer;
begin
  LockMutation;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(lrClosed);

    LIdx := HashKey(AKey) and FMask;
    LockBucket(LIdx);
    try
      LEntryIdx := FindEntry(LIdx, AKey);
      if LEntryIdx >= 0 then
      begin
        FBuckets[LIdx][LEntryIdx].Value := AValue;
        atomic_fetch_add_64(FAccessCounter, 1, mo_relaxed);
        FBuckets[LIdx][LEntryIdx].AccessCount := atomic_load_64(FAccessCounter, mo_relaxed);
        Exit(lrUpdated);
      end;
    finally
      UnlockBucket(LIdx);
    end;

    if FCount >= FMaxItems then
    begin
      LFound := False;
      LMinBucket := 0;
      LMinIdx := -1;
      LMinCount := 0;
      for LBucketIdx := 0 to FCapacity - 1 do
      begin
        LockBucket(LBucketIdx);
        try
          for LI := 0 to High(FBuckets[LBucketIdx]) do
          begin
            if FBuckets[LBucketIdx][LI].Used and
               ((not LFound) or (FBuckets[LBucketIdx][LI].AccessCount < LMinCount)) then
            begin
              LFound := True;
              LMinBucket := LBucketIdx;
              LMinCount := FBuckets[LBucketIdx][LI].AccessCount;
              LMinIdx := LI;
            end;
          end;
        finally
          UnlockBucket(LBucketIdx);
        end;
      end;

      if not LFound then
        Exit(lrFull);

      LockBucket(LMinBucket);
      try
        FBuckets[LMinBucket][LMinIdx].Used := False;
        Dec(FCount);
      finally
        UnlockBucket(LMinBucket);
      end;
    end;

    LockBucket(LIdx);
    try
      LEntryIdx := -1;
      for LI := 0 to High(FBuckets[LIdx]) do
      begin
        if not FBuckets[LIdx][LI].Used then
        begin
          LEntryIdx := LI;
          Break;
        end;
      end;

      if LEntryIdx < 0 then
      begin
        LEntryIdx := Length(FBuckets[LIdx]);
        SetLength(FBuckets[LIdx], LEntryIdx + 1);
      end;

      FBuckets[LIdx][LEntryIdx].Key := AKey;
      FBuckets[LIdx][LEntryIdx].Value := AValue;
      atomic_fetch_add_64(FAccessCounter, 1, mo_relaxed);
      FBuckets[LIdx][LEntryIdx].AccessCount := atomic_load_64(FAccessCounter, mo_relaxed);
      FBuckets[LIdx][LEntryIdx].Used := True;
      Inc(FCount);
      Result := lrAdded;
    finally
      UnlockBucket(LIdx);
    end;
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLruCacheImpl.Remove(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
  LEntryIdx: Integer;
begin
  LIdx := HashKey(AKey) and FMask;
  LockMutation;
  try
    LockBucket(LIdx);
    try
      LEntryIdx := FindEntry(LIdx, AKey);
      if LEntryIdx < 0 then
        Exit(False);
      FBuckets[LIdx][LEntryIdx].Used := False;
      Dec(FCount);
      Result := True;
    finally
      UnlockBucket(LIdx);
    end;
  finally
    UnlockMutation;
  end;
end;

procedure TConcurrentLruCacheImpl.Clear;
var
  LI: PtrUInt;
  LJ: Integer;
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
    FCount := 0;
  finally
    UnlockMutation;
  end;
end;

procedure TConcurrentLruCacheImpl.Close;
begin
  LockMutation;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLruCacheImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConcurrentLruCacheImpl.IsEmpty: Boolean;
begin
  LockMutation;
  try
    Result := FCount = 0;
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLruCacheImpl.Count: PtrUInt;
begin
  LockMutation;
  try
    Result := FCount;
  finally
    UnlockMutation;
  end;
end;

function TConcurrentLruCacheImpl.Capacity: PtrUInt; inline;
begin
  Result := FMaxItems;
end;

end.
