{******************************************************************************
  nextpas.core.lockfree.versionvector

  Version Vector — distributed causality tracking.

  Design:
  - Map<NodeId, Counter> for tracking causal dependencies
  - Compare: A < B if all A[i] <= B[i] and at least one strict
  - Merge: element-wise max (join operation)
  - Increment: bump counter for specific node
  - Concurrent-safe: CAS spin lock protects mutations
  - Compact fixed-size array (no heap allocation)

  Use cases: distributed systems, CRDT companion, event ordering.

  2026-07-06  Phase 10
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.versionvector;

interface

uses
  nextpas.core.lockfree.base;

const
  VV_MAX_NODES = 32;

type
  TVVCompareResult = (vvBefore, vvAfter, vvConcurrent, vvEqual);

  TVVEntry = record
    NodeId: Int32;
    Counter: Int64;
  end;

  {** @desc 分布式因果跟踪版本向量
    @details 每个节点维护一个递增计数器。
      Compare 判断两个向量的因果关系（happens-before）。
      Merge 取各节点计数器的最大值（join）。
      线程安全：CAS 自旋锁保护所有变更操作。 }
  TVersionVector = class
  private
    FEntries: array[0..VV_MAX_NODES - 1] of TVVEntry;
    FCount: Int32;
    FLock: Int32;
    procedure Lock; inline;
    procedure Unlock; inline;
    function FindNode(AId: Int32): Int32;
    procedure ValidateCounter(ACounter: Int64);
    procedure Snapshot(out AEntries: array of TVVEntry; out ACount: Int32);
  public
    constructor Create;
    procedure Increment(AId: Int32);
    procedure SetCounter(AId: Int32; ACounter: Int64);
    function GetCounter(AId: Int32): Int64;
    function Compare(AOther: TVersionVector): TVVCompareResult;
    procedure Merge(AOther: TVersionVector);
    function GetCount: Int32;
    procedure CopyTo(out AEntries: array of TVVEntry; out ACount: Int32);
    procedure Clear;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TVersionVector.Create;
var
  LI: Int32;
begin
  inherited Create;
  FCount := 0;
  FLock := 0;
  for LI := 0 to VV_MAX_NODES - 1 do
  begin
    FEntries[LI].NodeId := -1;
    FEntries[LI].Counter := 0;
  end;
end;

procedure TVersionVector.Lock;
var
  LJ, LSpin: Int32;
  LCasExpected: Int32;
begin
  for LJ := 0 to LOCKFREE_SPIN_COUNT do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Exit;
  end;
  { Spin-wait }
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

procedure TVersionVector.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TVersionVector.FindNode(AId: Int32): Int32;
var
  LI: Int32;
begin
  for LI := 0 to FCount - 1 do
    if FEntries[LI].NodeId = AId then
      Exit(LI);
  Result := -1;
end;

procedure TVersionVector.ValidateCounter(ACounter: Int64);
begin
  if ACounter < 0 then
    raise EArgumentError.Create('TVersionVector: counter must be non-negative');
end;

procedure TVersionVector.Snapshot(out AEntries: array of TVVEntry; out ACount: Int32);
var
  LI: Int32;
begin
  Lock;
  try
    if Length(AEntries) < FCount then
      raise EArgumentError.Create('TVersionVector: destination is too small');
    ACount := FCount;
    for LI := 0 to FCount - 1 do
      AEntries[LI] := FEntries[LI];
  finally
    Unlock;
  end;
end;

procedure TVersionVector.Increment(AId: Int32);
var
  LIdx: Int32;
begin
  Lock;
  try
    LIdx := FindNode(AId);
    if LIdx >= 0 then
    begin
      if FEntries[LIdx].Counter = High(Int64) then
        raise EArgumentError.Create('TVersionVector: counter overflow');
      Inc(FEntries[LIdx].Counter)
    end
    else if FCount < VV_MAX_NODES then
    begin
      FEntries[FCount].NodeId := AId;
      FEntries[FCount].Counter := 1;
      Inc(FCount);
    end
    else
      raise EArgumentError.Create('TVersionVector: max nodes reached');
  finally
    Unlock;
  end;
end;

procedure TVersionVector.SetCounter(AId: Int32; ACounter: Int64);
var
  LIdx: Int32;
begin
  ValidateCounter(ACounter);
  Lock;
  try
    LIdx := FindNode(AId);
    if LIdx >= 0 then
      FEntries[LIdx].Counter := ACounter
    else if FCount < VV_MAX_NODES then
    begin
      FEntries[FCount].NodeId := AId;
      FEntries[FCount].Counter := ACounter;
      Inc(FCount);
    end
    else
      raise EArgumentError.Create('TVersionVector: max nodes reached');
  finally
    Unlock;
  end;
end;

function TVersionVector.GetCounter(AId: Int32): Int64;
var
  LIdx: Int32;
begin
  Lock;
  try
    LIdx := FindNode(AId);
    if LIdx >= 0 then
      Result := FEntries[LIdx].Counter
    else
      Result := 0;
  finally
    Unlock;
  end;
end;

function TVersionVector.Compare(AOther: TVersionVector): TVVCompareResult;
var
  LSelfEntries: array[0..VV_MAX_NODES - 1] of TVVEntry;
  LOtherEntries: array[0..VV_MAX_NODES - 1] of TVVEntry;
  LSelfCount, LOtherCount: Int32;
  LSelfLess, LAOtherLess: Boolean;
  LI, LIdx: Int32;
  function FindInSnapshot(const AEntries: array of TVVEntry; ACount, AId: Int32): Int32;
  var
    LJ: Int32;
  begin
    for LJ := 0 to ACount - 1 do
      if AEntries[LJ].NodeId = AId then
        Exit(LJ);
    Result := -1;
  end;
begin
  { FPC does not track Snapshot() filling this out-param; zero it up front. }
  for LI := 0 to VV_MAX_NODES - 1 do
    LOtherEntries[LI] := Default(TVVEntry);
  Snapshot(LSelfEntries, LSelfCount);
  if AOther <> nil then
    AOther.Snapshot(LOtherEntries, LOtherCount)
  else
    LOtherCount := 0;
  LSelfLess := False;
  LAOtherLess := False;
  for LI := 0 to LSelfCount - 1 do
  begin
    LIdx := FindInSnapshot(LOtherEntries, LOtherCount, LSelfEntries[LI].NodeId);
    if LIdx >= 0 then
    begin
      if LSelfEntries[LI].Counter < LOtherEntries[LIdx].Counter then
        LSelfLess := True;
      if LSelfEntries[LI].Counter > LOtherEntries[LIdx].Counter then
        LAOtherLess := True;
    end
    else if LSelfEntries[LI].Counter > 0 then
      LAOtherLess := True;
  end;
  for LI := 0 to LOtherCount - 1 do
  begin
    LIdx := FindInSnapshot(LSelfEntries, LSelfCount, LOtherEntries[LI].NodeId);
    if (LIdx < 0) and (LOtherEntries[LI].Counter > 0) then
      LSelfLess := True;
  end;
  { Determine result }
  if LSelfLess and LAOtherLess then
    Result := vvConcurrent
  else if LSelfLess then
    Result := vvBefore
  else if LAOtherLess then
    Result := vvAfter
  else
    Result := vvEqual;
end;

procedure TVersionVector.Merge(AOther: TVersionVector);
var
  LOtherEntries: array[0..VV_MAX_NODES - 1] of TVVEntry;
  LOtherCount: Int32;
  LI, LJ, LIdx, LNewCount: Int32;
  LKnown: Boolean;
begin
  if AOther = nil then
    Exit;
  AOther.Snapshot(LOtherEntries, LOtherCount);
  Lock;
  try
    LNewCount := 0;
    for LI := 0 to LOtherCount - 1 do
    begin
      LKnown := FindNode(LOtherEntries[LI].NodeId) >= 0;
      if not LKnown then
      begin
        for LJ := 0 to LI - 1 do
          if LOtherEntries[LJ].NodeId = LOtherEntries[LI].NodeId then
          begin
            LKnown := True;
            Break;
          end;
        if not LKnown then
          Inc(LNewCount);
      end;
    end;
    if LNewCount > VV_MAX_NODES - FCount then
      raise EArgumentError.Create('TVersionVector: max nodes reached during merge');

    for LI := 0 to LOtherCount - 1 do
    begin
      LIdx := FindNode(LOtherEntries[LI].NodeId);
      if LIdx >= 0 then
      begin
        if LOtherEntries[LI].Counter > FEntries[LIdx].Counter then
          FEntries[LIdx].Counter := LOtherEntries[LI].Counter;
      end
      else
      begin
        FEntries[FCount].NodeId := LOtherEntries[LI].NodeId;
        FEntries[FCount].Counter := LOtherEntries[LI].Counter;
        Inc(FCount);
      end;
    end;
  finally
    Unlock;
  end;
end;

function TVersionVector.GetCount: Int32;
begin
  Lock;
  try
    Result := FCount;
  finally
    Unlock;
  end;
end;

procedure TVersionVector.CopyTo(out AEntries: array of TVVEntry; out ACount: Int32);
begin
  Snapshot(AEntries, ACount);
end;

procedure TVersionVector.Clear;
var
  LI: Int32;
begin
  Lock;
  try
    for LI := 0 to FCount - 1 do
    begin
      FEntries[LI].NodeId := -1;
      FEntries[LI].Counter := 0;
    end;
    FCount := 0;
  finally
    Unlock;
  end;
end;

end.
