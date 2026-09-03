program test_lockfree_versionvector;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.exception,
  nextpas.core.lockfree.versionvector,
  nextpas.core.test;

type
  PVVIncrementCtx = ^TVVIncrementCtx;
  TVVIncrementCtx = record
    Vector: TVersionVector;
    NodeId: Int32;
    Iterations: Int32;
  end;

function VVIncrementProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PVVIncrementCtx;
  LI: Int32;
begin
  LCtx := PVVIncrementCtx(AArg);
  for LI := 1 to LCtx^.Iterations do
    LCtx^.Vector.Increment(LCtx^.NodeId);
  Result := nil;
end;

procedure TestBasicIncrement;
var
  LVV: TVersionVector;
begin
  LVV := TVersionVector.Create;
  try
    CheckEqual(Int32(0), LVV.GetCount, 'Empty vector count');

    LVV.Increment(1);
    CheckEqual(Int64(1), LVV.GetCounter(1), 'Counter after first increment');
    CheckEqual(Int32(1), LVV.GetCount, 'Count after increment');

    LVV.Increment(1);
    CheckEqual(Int64(2), LVV.GetCounter(1), 'Counter after second increment');

    CheckEqual(Int64(0), LVV.GetCounter(2), 'Non-existent node returns 0');
  finally
    LVV.Free;
  end;
end;

procedure TestMultipleNodes;
var
  LVV: TVersionVector;
begin
  LVV := TVersionVector.Create;
  try
    LVV.Increment(1);
    LVV.Increment(2);
    LVV.Increment(3);

    CheckEqual(Int32(3), LVV.GetCount, 'Three nodes');
    CheckEqual(Int64(1), LVV.GetCounter(1), 'Node 1 counter');
    CheckEqual(Int64(1), LVV.GetCounter(2), 'Node 2 counter');
    CheckEqual(Int64(1), LVV.GetCounter(3), 'Node 3 counter');
  finally
    LVV.Free;
  end;
end;

procedure TestSetCounter;
var
  LVV: TVersionVector;
begin
  LVV := TVersionVector.Create;
  try
    LVV.SetCounter(1, 42);
    CheckEqual(Int64(42), LVV.GetCounter(1), 'Set counter');

    LVV.SetCounter(1, 10);
    CheckEqual(Int64(10), LVV.GetCounter(1), 'Overwrite counter');

    LVV.SetCounter(5, 100);
    CheckEqual(Int64(100), LVV.GetCounter(5), 'New node via SetCounter');
    CheckEqual(Int32(2), LVV.GetCount, 'Two nodes');
  finally
    LVV.Free;
  end;
end;

procedure TestCompareEqual;
var
  LA, LB: TVersionVector;
begin
  LA := TVersionVector.Create;
  LB := TVersionVector.Create;
  try
    LA.Increment(1);
    LB.Increment(1);

    Check(LA.Compare(LB) = vvEqual, 'Equal vectors');
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestCompareBefore;
var
  LA, LB: TVersionVector;
begin
  LA := TVersionVector.Create;
  LB := TVersionVector.Create;
  try
    LA.Increment(1);
    LB.Increment(1);
    LB.Increment(1);

    Check(LA.Compare(LB) = vvBefore, 'A before B');
    Check(LB.Compare(LA) = vvAfter, 'B after A');
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestCompareConcurrent;
var
  LA, LB: TVersionVector;
begin
  LA := TVersionVector.Create;
  LB := TVersionVector.Create;
  try
    LA.Increment(1);
    LB.Increment(2);

    Check(LA.Compare(LB) = vvConcurrent, 'Concurrent (different nodes)');
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestMerge;
var
  LA, LB: TVersionVector;
begin
  LA := TVersionVector.Create;
  LB := TVersionVector.Create;
  try
    LA.Increment(1);
    LA.Increment(1);
    LB.Increment(2);
    LB.Increment(2);
    LB.Increment(2);

    LA.Merge(LB);
    CheckEqual(Int64(2), LA.GetCounter(1), 'Merged node 1');
    CheckEqual(Int64(3), LA.GetCounter(2), 'Merged node 2');
    CheckEqual(Int32(2), LA.GetCount, 'Merged count');
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestMergeCapacityFailureIsExplicit;
var
  LA, LB: TVersionVector;
  LI: Int32;
  LRaised: Boolean;
begin
  LA := TVersionVector.Create;
  LB := TVersionVector.Create;
  try
    for LI := 0 to VV_MAX_NODES - 1 do
      LA.SetCounter(LI, 1);
    LB.SetCounter(1000, 1);

    LRaised := False;
    try
      LA.Merge(LB);
    except
      on Exception do
        LRaised := True;
    end;
    Check(LRaised, 'Merge must not silently drop a causal component');
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestCounterDomainValidation;
var
  LVV: TVersionVector;
  LRaised: Boolean;
begin
  LVV := TVersionVector.Create;
  try
    LRaised := False;
    try
      LVV.SetCounter(1, -1);
    except
      on Exception do
        LRaised := True;
    end;
    Check(LRaised, 'Negative version counters are rejected');

    LVV.SetCounter(1, High(Int64));
    LRaised := False;
    try
      LVV.Increment(1);
    except
      on Exception do
        LRaised := True;
    end;
    Check(LRaised, 'Version counter overflow is rejected');
    CheckEqual(High(Int64), LVV.GetCounter(1),
      'Rejected overflow preserves the prior counter');
  finally
    LVV.Free;
  end;
end;

procedure TestPartialOrderWithMissingZeroEntry;
var
  LA, LB: TVersionVector;
begin
  LA := TVersionVector.Create;
  LB := TVersionVector.Create;
  try
    LB.SetCounter(7, 0);
    Check(LA.Compare(LB) = vvEqual,
      'Missing component is equivalent to explicit zero');
    Check(LB.Compare(LA) = vvEqual,
      'Zero equivalence is symmetric');

    LA.Increment(1);
    LB.Increment(2);
    Check(LA.Compare(LB) = vvConcurrent,
      'Independent positive components are concurrent');
    Check(LB.Compare(LA) = vvConcurrent,
      'Concurrent relation is symmetric');
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TestClear;
var
  LVV: TVersionVector;
begin
  LVV := TVersionVector.Create;
  try
    LVV.Increment(1);
    LVV.Increment(2);
    CheckEqual(Int32(2), LVV.GetCount, 'Before clear');

    LVV.Clear;
    CheckEqual(Int32(0), LVV.GetCount, 'After clear');
    CheckEqual(Int64(0), LVV.GetCounter(1), 'Cleared counter');
  finally
    LVV.Free;
  end;
end;

procedure TestConcurrentIncrement;
const
  THREAD_COUNT = 4;
  ITERATIONS = 2000;
var
  LVV: TVersionVector;
  LRecs: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LCtxs: array[0..THREAD_COUNT - 1] of TVVIncrementCtx;
  LI: Int32;
begin
  LVV := TVersionVector.Create;
  try
    for LI := 0 to High(LCtxs) do
    begin
      LCtxs[LI].Vector := LVV;
      LCtxs[LI].NodeId := 7;
      LCtxs[LI].Iterations := ITERATIONS;
      Check(platform_thread_spawn(LRecs[LI], @VVIncrementProc,
        @LCtxs[LI]) = 0, 'spawn increment worker');
    end;
    for LI := 0 to High(LRecs) do
      Check(platform_thread_wait(LRecs[LI]) = 0, 'join increment worker');
    CheckEqual(Int64(THREAD_COUNT * ITERATIONS), LVV.GetCounter(7), 'Concurrent increments preserve all updates');
  finally
    LVV.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_versionvector ===');
  WriteLn;

  TestBasicIncrement;
  WriteLn('  + Basic increment');

  TestMultipleNodes;
  WriteLn('  + Multiple nodes');

  TestSetCounter;
  WriteLn('  + Set counter');

  TestCompareEqual;
  WriteLn('  + Compare equal');

  TestCompareBefore;
  WriteLn('  + Compare before/after');

  TestCompareConcurrent;
  WriteLn('  + Compare concurrent');

  TestMerge;
  WriteLn('  + Merge');

  TestMergeCapacityFailureIsExplicit;
  WriteLn('  + Merge capacity failure');

  TestCounterDomainValidation;
  WriteLn('  + Counter domain validation');

  TestPartialOrderWithMissingZeroEntry;
  WriteLn('  + Partial order missing/zero entries');

  TestClear;
  WriteLn('  + Clear');

  TestConcurrentIncrement;
  WriteLn('  + Concurrent increment');

  WriteLn;
  WriteLn('All version vector tests passed!');
end.
