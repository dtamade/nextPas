program test_lockfree_versionvector;

{$mode objfpc}{$H+}

uses
  cthreads,
  Classes,
  SysUtils,
  nextpas.core.lockfree.versionvector,
  nextpas.core.test;

type
  TVVIncrementThread = class(TThread)
  private
    FVector: TVersionVector;
    FNodeId: Int32;
    FIterations: Int32;
  protected
    procedure Execute; override;
  public
    constructor Create(AVector: TVersionVector; ANodeId, AIterations: Int32);
  end;

constructor TVVIncrementThread.Create(AVector: TVersionVector; ANodeId, AIterations: Int32);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FVector := AVector;
  FNodeId := ANodeId;
  FIterations := AIterations;
end;

procedure TVVIncrementThread.Execute;
var
  LI: Int32;
begin
  for LI := 1 to FIterations do
    FVector.Increment(FNodeId);
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
  LThreads: array[0..THREAD_COUNT - 1] of TVVIncrementThread;
  LI: Int32;
begin
  LVV := TVersionVector.Create;
  try
    for LI := 0 to High(LThreads) do
      LThreads[LI] := TVVIncrementThread.Create(LVV, 7, ITERATIONS);
    for LI := 0 to High(LThreads) do
    begin
      LThreads[LI].WaitFor;
      LThreads[LI].Free;
    end;
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

  TestClear;
  WriteLn('  + Clear');

  TestConcurrentIncrement;
  WriteLn('  + Concurrent increment');

  WriteLn;
  WriteLn('All version vector tests passed!');
end.
