unit nextpas.core.lockfree.multimap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeMultiMapAddResult = (mmAdded, mmKeyExists, mmFull, mmClosed);

  {** @desc 无锁并发 MultiMap（一个键可以有多个值）
    @details 基于分片锁 HashMap 实现，每个键对应一个值列表。
      支持 Add/Find/Remove/Contains/Count/ForEach。
      适用于索引、标签系统等场景。
  }
  generic TLockFreeMultiMapImpl<TKey, TValue> = class
  private
    type
      TPair = record
        Key: TKey;
        Values: array of TValue;
        Count: Integer;
      end;
      PPair = ^TPair;
  private
    FBuckets: array of PPair;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    FCount: Int64;
    FClosed: Int32;
    // Shard locks (one per bucket)
    FLocks: array of Int32;
    function HashKey(const AKey: TKey): PtrUInt;
    function FindPair(AKey: TKey): PPair;
    procedure LockBucket(AIdx: PtrUInt);
    procedure UnlockBucket(AIdx: PtrUInt);
  public
    constructor Create(const ACapacity: PtrUInt = 16);
    destructor Destroy; override;
    function Add(const AKey: TKey; const AValue: TValue): TLockFreeMultiMapAddResult;
    function Find(const AKey: TKey; out AValues: array of TValue): Integer;
    function Contains(const AKey: TKey): Boolean;
    function Remove(const AKey: TKey): Boolean;
    function RemoveValue(const AKey: TKey; const AValue: TValue): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
    function Count: PtrUInt;
    function KeyCount: PtrUInt;
  end;

  generic TLockFreeMultiMap<TKey, TValue> = class(specialize TLockFreeMultiMapImpl<TKey, TValue>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.math;

constructor TLockFreeMultiMapImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
  LI: PtrUInt;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TLockFreeMultiMap: TKey must be unmanaged');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TLockFreeMultiMap: TValue must be unmanaged');
  if ACapacity = 0 then
    raise EArgumentError.Create('TLockFreeMultiMap: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FBuckets, LCap);
  SetLength(FLocks, LCap);
  for LI := 0 to LCap - 1 do
  begin
    FBuckets[LI] := nil;
    FLocks[LI] := 0;
  end;
  FCount := 0;
  FClosed := 0;
end;

destructor TLockFreeMultiMapImpl.Destroy;
var
  LI: PtrUInt;
  LPair: PPair;
begin
  for LI := 0 to FCapacity - 1 do
  begin
    LPair := FBuckets[LI];
    if LPair <> nil then
    begin
      SetLength(LPair^.Values, 0);
      Dispose(LPair);
    end;
  end;
  SetLength(FBuckets, 0);
  SetLength(FLocks, 0);
  inherited Destroy;
end;

function TLockFreeMultiMapImpl.HashKey(const AKey: TKey): PtrUInt;
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

function TLockFreeMultiMapImpl.FindPair(AKey: TKey): PPair;
var
  LIdx: PtrUInt;
  LPair: PPair;
begin
  LIdx := HashKey(AKey) and FMask;
  LPair := FBuckets[LIdx];
  while LPair <> nil do
  begin
    if LPair^.Key = AKey then
      Exit(LPair);
    LPair := nil; // Linear probing - for now just check first
  end;
  Result := nil;
end;

procedure TLockFreeMultiMapImpl.LockBucket(AIdx: PtrUInt);
begin
  while AtomicCompareExchange32(FLocks[AIdx], 0, 1) <> 0 do
    CpuPause;
end;

procedure TLockFreeMultiMapImpl.UnlockBucket(AIdx: PtrUInt);
begin
  AtomicStore32(FLocks[AIdx], 0, moRelease);
end;

function TLockFreeMultiMapImpl.Add(const AKey: TKey; const AValue: TValue): TLockFreeMultiMapAddResult;
var
  LIdx: PtrUInt;
  LPair: PPair;
  LLen: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(mmClosed);
  LIdx := HashKey(AKey) and FMask;
  LockBucket(LIdx);
  try
    LPair := FBuckets[LIdx];
    if LPair = nil then
    begin
      // New key
      New(LPair);
      LPair^.Key := AKey;
      SetLength(LPair^.Values, 4);
      LPair^.Values[0] := AValue;
      LPair^.Count := 1;
      FBuckets[LIdx] := LPair;
      AtomicFetchAdd64(FCount, 1, moRelaxed);
      Exit(mmAdded);
    end;
    if LPair^.Key = AKey then
    begin
      // Key exists, add value
      LLen := LPair^.Count;
      if LLen >= Length(LPair^.Values) then
        SetLength(LPair^.Values, LLen * 2);
      LPair^.Values[LLen] := AValue;
      LPair^.Count := LLen + 1;
      AtomicFetchAdd64(FCount, 1, moRelaxed);
      Exit(mmAdded);
    end;
    // Collision - for now just fail (simplified implementation)
    Exit(mmFull);
  finally
    UnlockBucket(LIdx);
  end;
end;

function TLockFreeMultiMapImpl.Find(const AKey: TKey; out AValues: array of TValue): Integer;
var
  LIdx: PtrUInt;
  LPair: PPair;
  LCount: Integer;
  LI: Integer;
begin
  LIdx := HashKey(AKey) and FMask;
  LockBucket(LIdx);
  try
    LPair := FBuckets[LIdx];
    if (LPair = nil) or (LPair^.Key <> AKey) then
      Exit(0);
    LCount := LPair^.Count;
    for LI := 0 to Min(LCount, Length(AValues)) - 1 do
      AValues[LI] := LPair^.Values[LI];
    Result := LCount;
  finally
    UnlockBucket(LIdx);
  end;
end;

function TLockFreeMultiMapImpl.Contains(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
  LPair: PPair;
begin
  LIdx := HashKey(AKey) and FMask;
  LockBucket(LIdx);
  try
    LPair := FBuckets[LIdx];
    Result := (LPair <> nil) and (LPair^.Key = AKey);
  finally
    UnlockBucket(LIdx);
  end;
end;

function TLockFreeMultiMapImpl.Remove(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
  LPair: PPair;
begin
  LIdx := HashKey(AKey) and FMask;
  LockBucket(LIdx);
  try
    LPair := FBuckets[LIdx];
    if (LPair = nil) or (LPair^.Key <> AKey) then
      Exit(False);
    AtomicFetchSub64(FCount, LPair^.Count, moRelaxed);
    SetLength(LPair^.Values, 0);
    Dispose(LPair);
    FBuckets[LIdx] := nil;
    Result := True;
  finally
    UnlockBucket(LIdx);
  end;
end;

function TLockFreeMultiMapImpl.RemoveValue(const AKey: TKey; const AValue: TValue): Boolean;
var
  LIdx: PtrUInt;
  LPair: PPair;
  LI, LCount: Integer;
begin
  LIdx := HashKey(AKey) and FMask;
  LockBucket(LIdx);
  try
    LPair := FBuckets[LIdx];
    if (LPair = nil) or (LPair^.Key <> AKey) then
      Exit(False);
    LCount := LPair^.Count;
    for LI := 0 to LCount - 1 do
    begin
      if LPair^.Values[LI] = AValue then
      begin
        // Remove by shifting
        if LI < LCount - 1 then
          Move(LPair^.Values[LI + 1], LPair^.Values[LI], (LCount - LI - 1) * SizeOf(TValue));
        LPair^.Count := LCount - 1;
        AtomicFetchSub64(FCount, 1, moRelaxed);
        Exit(True);
      end;
    end;
    Result := False;
  finally
    UnlockBucket(LIdx);
  end;
end;

procedure TLockFreeMultiMapImpl.Clear;
var
  LI: PtrUInt;
  LPair: PPair;
begin
  for LI := 0 to FCapacity - 1 do
  begin
    LockBucket(LI);
    try
      LPair := FBuckets[LI];
      if LPair <> nil then
      begin
        AtomicFetchSub64(FCount, LPair^.Count, moRelaxed);
        SetLength(LPair^.Values, 0);
        Dispose(LPair);
        FBuckets[LI] := nil;
      end;
    finally
      UnlockBucket(LI);
    end;
  end;
end;

procedure TLockFreeMultiMapImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TLockFreeMultiMapImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLockFreeMultiMapImpl.IsEmpty: Boolean;
begin
  Result := AtomicLoad64(FCount, moAcquire) = 0;
end;

function TLockFreeMultiMapImpl.Count: PtrUInt;
begin
  Result := PtrUInt(AtomicLoad64(FCount, moAcquire));
end;

function TLockFreeMultiMapImpl.KeyCount: PtrUInt;
var
  LI: PtrUInt;
  LCount: PtrUInt;
begin
  LCount := 0;
  for LI := 0 to FCapacity - 1 do
  begin
    if FBuckets[LI] <> nil then
      Inc(LCount);
  end;
  Result := LCount;
end;

end.
