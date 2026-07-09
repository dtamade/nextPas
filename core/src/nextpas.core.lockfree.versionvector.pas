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
  LJ: Int32;
begin
  for LJ := 0 to LOCKFREE_SPIN_COUNT do
  begin
    if AtomicCompareExchange32(FLock, 1, 0, moAcqRel) = 0 then
      Exit;
  end;
  { Spin-wait }
  while AtomicCompareExchange32(FLock, 1, 0, moAcqRel) <> 0 do
    ThreadSwitch;
end;

procedure TVersionVector.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
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

procedure TVersionVector.Increment(AId: Int32);
var
  LIdx: Int32;
begin
  Lock;
  try
    LIdx := FindNode(AId);
    if LIdx >= 0 then
      Inc(FEntries[LIdx].Counter)
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
  LSelfLess, LAOtherLess: Boolean;
  LI, LIdx: Int32;
begin
  { Snapshot both vectors }
  Lock;
  try
    { Copy self }
    LSelfLess := False;
    LAOtherLess := False;
    { Check self entries against other }
    for LI := 0 to FCount - 1 do
    begin
      LIdx := AOther.FindNode(FEntries[LI].NodeId);
      if LIdx >= 0 then
      begin
        if FEntries[LI].Counter < AOther.FEntries[LIdx].Counter then
          LSelfLess := True;
        if FEntries[LI].Counter > AOther.FEntries[LIdx].Counter then
          LAOtherLess := True;
      end
      else
      begin
        if FEntries[LI].Counter > 0 then
          LAOtherLess := True;
      end;
    end;
    { Check other entries not in self }
    for LI := 0 to AOther.FCount - 1 do
    begin
      LIdx := FindNode(AOther.FEntries[LI].NodeId);
      if LIdx < 0 then
      begin
        if AOther.FEntries[LI].Counter > 0 then
          LSelfLess := True;
      end;
    end;
  finally
    Unlock;
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
  LI, LIdx: Int32;
begin
  Lock;
  try
    for LI := 0 to AOther.FCount - 1 do
    begin
      LIdx := FindNode(AOther.FEntries[LI].NodeId);
      if LIdx >= 0 then
      begin
        if AOther.FEntries[LI].Counter > FEntries[LIdx].Counter then
          FEntries[LIdx].Counter := AOther.FEntries[LI].Counter;
      end
      else if FCount < VV_MAX_NODES then
      begin
        FEntries[FCount].NodeId := AOther.FEntries[LI].NodeId;
        FEntries[FCount].Counter := AOther.FEntries[LI].Counter;
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
var
  LI: Int32;
begin
  Lock;
  try
    ACount := FCount;
    for LI := 0 to FCount - 1 do
      AEntries[LI] := FEntries[LI];
  finally
    Unlock;
  end;
end;

procedure TVersionVector.Clear;
begin
  Lock;
  try
    FCount := 0;
  finally
    Unlock;
  end;
end;

end.
