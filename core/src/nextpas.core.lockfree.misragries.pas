{******************************************************************************
  nextpas.core.lockfree.misragries

  Misra-Gries Frequency Counter — streaming heavy hitter detection.

  Design:
  - Maintains k counters for the k most frequent items
  - On each item: if tracked, increment; if slot free, add; else decrement all
  - Guarantees: all items with frequency > n/(k+1) are found
  - O(1) per operation (amortized)
  - Concurrent-safe: CAS spin lock

  Theory: Misra & Gries "Finding Repeated Elements" (1982)
  Space: O(k) — much less than Count-Min Sketch for exact heavy hitters.

  2026-07-06  Phase 10
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.misragries;

interface

uses
  nextpas.core.lockfree.base;

type
  TMisraGriesResult = (mgAdded, mgUpdated, mgDecremented, mgClosed);

  TMGEntry = record
    Key: UInt64;
    Count: Int64;
  end;

  {** @desc Misra-Gries 频繁项检测器
    @details 流式算法，维护 k 个计数器。
      保证找到频率 > n/(k+1) 的所有项。
      线程安全：CAS 自旋锁。 }
  TMisraGries = class
  private
    FEntries: array of TMGEntry;
    FCapacity: Int32;
    FTotalOps: Int64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock; inline;
    procedure Unlock; inline;
    function FindKey(AKey: UInt64): Int32;
  public
    constructor Create(const ACapacity: Int32);
    destructor Destroy; override;
    function Add(AKey: UInt64): TMisraGriesResult;
    function GetCount(AKey: UInt64): Int64;
    function GetTotalOps: Int64;
    function GetCapacity: Int32;
    procedure GetTopK(out AKeys: array of UInt64; out ACounts: array of Int64; out AFound: Int32);
    procedure Close;
    function IsClosed: Boolean;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TMisraGries.Create(const ACapacity: Int32);
var
  LI: Int32;
begin
  if ACapacity < 1 then
    raise EArgumentError.Create('TMisraGries: capacity must be >= 1');
  inherited Create;
  FCapacity := ACapacity;
  SetLength(FEntries, FCapacity);
  for LI := 0 to FCapacity - 1 do
  begin
    FEntries[LI].Key := 0;
    FEntries[LI].Count := 0;
  end;
  FTotalOps := 0;
  FLock := 0;
  FClosed := 0;
end;

procedure TMisraGries.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
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
end;

procedure TMisraGries.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TMisraGries.FindKey(AKey: UInt64): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FCapacity - 1 do
    if (FEntries[LI].Count > 0) and (FEntries[LI].Key = AKey) then
      Exit(LI);
  Result := -1;
end;

function TMisraGries.Add(AKey: UInt64): TMisraGriesResult;
var
  LIdx: Int32;
  LI: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(mgClosed);
  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(mgClosed);
    if FTotalOps < High(Int64) then
      Inc(FTotalOps);
    { Check if key already tracked }
    LIdx := FindKey(AKey);
    if LIdx >= 0 then
    begin
      if FEntries[LIdx].Count < High(Int64) then
        Inc(FEntries[LIdx].Count);
      Exit(mgUpdated);
    end;
    { Find empty slot }
    for LI := 0 to FCapacity - 1 do
      if FEntries[LI].Count = 0 then
      begin
        FEntries[LI].Key := AKey;
        FEntries[LI].Count := 1;
        Exit(mgAdded);
      end;
    { All slots occupied — decrement all }
    for LI := 0 to FCapacity - 1 do
      Dec(FEntries[LI].Count);
    { Remove any entries that hit zero }
    for LI := 0 to FCapacity - 1 do
      if FEntries[LI].Count <= 0 then
      begin
        FEntries[LI].Count := 0;
        FEntries[LI].Key := 0;
      end;
    Result := mgDecremented;
  finally
    Unlock;
  end;
end;

function TMisraGries.GetCount(AKey: UInt64): Int64;
var
  LIdx: Int32;
begin
  Lock;
  try
    LIdx := FindKey(AKey);
    if LIdx >= 0 then
      Result := FEntries[LIdx].Count
    else
      Result := 0;
  finally
    Unlock;
  end;
end;

function TMisraGries.GetTotalOps: Int64;
begin
  Lock;
  try
    Result := FTotalOps;
  finally
    Unlock;
  end;
end;

function TMisraGries.GetCapacity: Int32;
begin
  Result := FCapacity;
end;

procedure TMisraGries.GetTopK(out AKeys: array of UInt64; out ACounts: array of Int64; out AFound: Int32);
var
  LI, LJ: Int32;
  LKey: UInt64;
  LCount: Int64;
  LSorted: array of TMGEntry;
begin
  Lock;
  try
    AFound := 0;
    SetLength(LSorted, FCapacity);
    for LI := 0 to FCapacity - 1 do
      if FEntries[LI].Count > 0 then
      begin
        LSorted[AFound] := FEntries[LI];
        Inc(AFound);
      end;
    { Simple insertion sort by count descending }
    for LI := 1 to AFound - 1 do
    begin
      LKey := LSorted[LI].Key;
      LCount := LSorted[LI].Count;
      LJ := LI;
      while (LJ > 0) and (LSorted[LJ - 1].Count < LCount) do
      begin
        LSorted[LJ] := LSorted[LJ - 1];
        Dec(LJ);
      end;
      LSorted[LJ].Key := LKey;
      LSorted[LJ].Count := LCount;
    end;
    { Copy to output }
    for LI := 0 to AFound - 1 do
    begin
      if LI < Length(AKeys) then
        AKeys[LI] := LSorted[LI].Key;
      if LI < Length(ACounts) then
        ACounts[LI] := LSorted[LI].Count;
    end;
  finally
    Unlock;
  end;
end;

procedure TMisraGries.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

destructor TMisraGries.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TMisraGries.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

procedure TMisraGries.Clear;
var
  LI: Int32;
begin
  Lock;
  try
    for LI := 0 to FCapacity - 1 do
    begin
      FEntries[LI].Key := 0;
      FEntries[LI].Count := 0;
    end;
    FTotalOps := 0;
  finally
    Unlock;
  end;
end;

end.
