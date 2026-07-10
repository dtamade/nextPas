unit nextpas.core.lockfree.multimap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeMultiMapAddResult = (mmAdded, mmKeyExists, mmFull, mmClosed);

  {** @desc 自旋锁保护的并发 MultiMap（一个键可以有多个值）
    @details 单个 map 锁串行化访问，每个键对应一个值列表。
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
    FLock: Int32;
    function HashKey(const AKey: TKey): PtrUInt;
    function FindBucketIndex(const AKey: TKey; out AIdx: PtrUInt): Boolean;
    procedure InsertPairIntoBuckets(APair: PPair);
    procedure RehashClusterFrom(AStartIdx: PtrUInt);
    procedure LockMap;
    procedure UnlockMap;
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
  for LI := 0 to LCap - 1 do
    FBuckets[LI] := nil;
  FCount := 0;
  FClosed := 0;
  FLock := 0;
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

function TLockFreeMultiMapImpl.FindBucketIndex(const AKey: TKey; out AIdx: PtrUInt): Boolean;
var
  LStart: PtrUInt;
begin
  LStart := HashKey(AKey) and FMask;
  AIdx := LStart;
  repeat
    if FBuckets[AIdx] = nil then
      Exit(False);
    if FBuckets[AIdx]^.Key = AKey then
      Exit(True);
    AIdx := (AIdx + 1) and FMask;
  until AIdx = LStart;
  AIdx := FCapacity;
  Result := False;
end;

procedure TLockFreeMultiMapImpl.InsertPairIntoBuckets(APair: PPair);
var
  LIdx: PtrUInt;
begin
  LIdx := HashKey(APair^.Key) and FMask;
  while FBuckets[LIdx] <> nil do
    LIdx := (LIdx + 1) and FMask;
  FBuckets[LIdx] := APair;
end;

procedure TLockFreeMultiMapImpl.RehashClusterFrom(AStartIdx: PtrUInt);
var
  LIdx: PtrUInt;
  LPair: PPair;
begin
  LIdx := AStartIdx;
  while FBuckets[LIdx] <> nil do
  begin
    LPair := FBuckets[LIdx];
    FBuckets[LIdx] := nil;
    InsertPairIntoBuckets(LPair);
    LIdx := (LIdx + 1) and FMask;
  end;
end;

procedure TLockFreeMultiMapImpl.LockMap;
begin
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
    CpuPause;
end;

procedure TLockFreeMultiMapImpl.UnlockMap;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

function TLockFreeMultiMapImpl.Add(const AKey: TKey; const AValue: TValue): TLockFreeMultiMapAddResult;
var
  LIdx: PtrUInt;
  LPair: PPair;
  LLen: Integer;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(mmClosed);
  LockMap;
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(mmClosed);
    if FindBucketIndex(AKey, LIdx) then
    begin
      LPair := FBuckets[LIdx];
      LLen := LPair^.Count;
      if LLen >= Length(LPair^.Values) then
        SetLength(LPair^.Values, LLen * 2);
      LPair^.Values[LLen] := AValue;
      LPair^.Count := LLen + 1;
      AtomicFetchAdd64(FCount, 1, moRelaxed);
      Exit(mmAdded);
    end;
    if LIdx >= FCapacity then
      Exit(mmFull);
    if FBuckets[LIdx] = nil then
    begin
      New(LPair);
      LPair^.Key := AKey;
      SetLength(LPair^.Values, 4);
      LPair^.Values[0] := AValue;
      LPair^.Count := 1;
      FBuckets[LIdx] := LPair;
      AtomicFetchAdd64(FCount, 1, moRelaxed);
      Exit(mmAdded);
    end;
    Exit(mmFull);
  finally
    UnlockMap;
  end;
end;

function TLockFreeMultiMapImpl.Find(const AKey: TKey; out AValues: array of TValue): Integer;
var
  LIdx: PtrUInt;
  LPair: PPair;
  LCount: Integer;
  LI: Integer;
begin
  LockMap;
  try
    if not FindBucketIndex(AKey, LIdx) then
      Exit(0);
    LPair := FBuckets[LIdx];
    LCount := LPair^.Count;
    for LI := 0 to Min(LCount, Length(AValues)) - 1 do
      AValues[LI] := LPair^.Values[LI];
    Result := LCount;
  finally
    UnlockMap;
  end;
end;

function TLockFreeMultiMapImpl.Contains(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
begin
  LockMap;
  try
    Result := FindBucketIndex(AKey, LIdx);
  finally
    UnlockMap;
  end;
end;

function TLockFreeMultiMapImpl.Remove(const AKey: TKey): Boolean;
var
  LIdx: PtrUInt;
  LPair: PPair;
begin
  LockMap;
  try
    if not FindBucketIndex(AKey, LIdx) then
      Exit(False);
    LPair := FBuckets[LIdx];
    AtomicFetchSub64(FCount, LPair^.Count, moRelaxed);
    SetLength(LPair^.Values, 0);
    Dispose(LPair);
    FBuckets[LIdx] := nil;
    RehashClusterFrom((LIdx + 1) and FMask);
    Result := True;
  finally
    UnlockMap;
  end;
end;

function TLockFreeMultiMapImpl.RemoveValue(const AKey: TKey; const AValue: TValue): Boolean;
var
  LIdx: PtrUInt;
  LPair: PPair;
  LI, LCount: Integer;
begin
  LockMap;
  try
    if not FindBucketIndex(AKey, LIdx) then
      Exit(False);
    LPair := FBuckets[LIdx];
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
        if LPair^.Count = 0 then
        begin
          SetLength(LPair^.Values, 0);
          Dispose(LPair);
          FBuckets[LIdx] := nil;
          RehashClusterFrom((LIdx + 1) and FMask);
        end;
        Exit(True);
      end;
    end;
    Result := False;
  finally
    UnlockMap;
  end;
end;

procedure TLockFreeMultiMapImpl.Clear;
var
  LI: PtrUInt;
  LPair: PPair;
begin
  LockMap;
  try
    for LI := 0 to FCapacity - 1 do
    begin
      LPair := FBuckets[LI];
      if LPair <> nil then
      begin
        AtomicFetchSub64(FCount, LPair^.Count, moRelaxed);
        SetLength(LPair^.Values, 0);
        Dispose(LPair);
        FBuckets[LI] := nil;
      end;
    end;
  finally
    UnlockMap;
  end;
end;

procedure TLockFreeMultiMapImpl.Close;
begin
  LockMap;
  try
    AtomicStore32(FClosed, 1, moRelease);
  finally
    UnlockMap;
  end;
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
  LockMap;
  try
    LCount := 0;
    for LI := 0 to FCapacity - 1 do
      if FBuckets[LI] <> nil then
        Inc(LCount);
    Result := LCount;
  finally
    UnlockMap;
  end;
end;

end.
