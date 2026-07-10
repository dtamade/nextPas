program test_lockfree_workstealing;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.workstealing,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

const
  CONCURRENT_PRODUCER_COUNT = 4;
  CONCURRENT_OPS_PER_PRODUCER = 2000;

type
  PSubmitArgs = ^TSubmitArgs;
  TSubmitArgs = record
    Pool: TWorkStealingPool;
    Start: PInt32;
    Done: PInt32;
    Submitted: PInt64;
  end;

function SubmitThread(AData: Pointer): PtrInt;
var
  LArgs: PSubmitArgs;
  LI: Integer;
begin
  LArgs := PSubmitArgs(AData);
  while AtomicLoad32(LArgs^.Start^, moAcquire) = 0 do
    CpuPause;
  for LI := 1 to CONCURRENT_OPS_PER_PRODUCER do
  begin
    while not LArgs^.Pool.Submit(nil, Pointer(PtrUInt(LI))) do
      CpuPause;
    AtomicFetchAdd64(LArgs^.Submitted^, 1, moRelaxed);
  end;
  AtomicFetchAdd32(LArgs^.Done^, 1, moRelease);
  Result := 0;
end;

procedure TestWorkStealingBasic;
var
  LPool: TWorkStealingPool;
begin
  LPool := TWorkStealingPool.Create(4);
  try
    Check(not LPool.IsClosed, 'Should not be closed');
    CheckEqual(Int64(4), LPool.GetWorkerCount, 'Worker count should be 4');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingSubmit;
var
  LPool: TWorkStealingPool;
begin
  LPool := TWorkStealingPool.Create(2);
  try
    Check(LPool.Submit(nil, nil), 'Should submit');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingSteal;
var
  LPool: TWorkStealingPool;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LResult: TLockFreeWorkStealingResult;
begin
  LPool := TWorkStealingPool.Create(2);
  try
    LResult := LPool.Steal(LTask, LData);
    Check(wsEmpty = LResult, 'Should be empty');
  finally
    LPool.Free;
  end;
end;

var
  GWorkStealingObserved: Pointer;

procedure CaptureTask(AData: Pointer);
begin
  GWorkStealingObserved := AData;
end;

procedure TestWorkStealingStealsSubmittedTask;
var
  LPool: TWorkStealingPool;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LResult: TLockFreeWorkStealingResult;
begin
  LPool := TWorkStealingPool.Create(2);
  GWorkStealingObserved := nil;
  try
    Check(LPool.Submit(@CaptureTask, Pointer(PtrUInt(1234))), 'Should submit concrete task');
    LResult := LPool.Steal(LTask, LData);
    Check(wsStolen = LResult, 'Steal should return a submitted task');
    Check(Assigned(LTask), 'Stolen task should be assigned');
    Check(Pointer(PtrUInt(1234)) = LData, 'Payload should round-trip through queue');
    LTask(LData);
    Check(Pointer(PtrUInt(1234)) = GWorkStealingObserved, 'Stolen task should execute with original payload');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingClose;
var
  LPool: TWorkStealingPool;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LResult: TLockFreeWorkStealingResult;
begin
  LPool := TWorkStealingPool.Create(2);
  try
    LPool.Close;
    Check(LPool.IsClosed, 'Should be closed');

    Check(not LPool.Submit(nil, nil), 'Should not submit');

    LResult := LPool.Steal(LTask, LData);
    Check(wsClosed = LResult, 'Should return closed');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkStealingConcurrentSubmitPreservesTasks;
var
  LPool: TWorkStealingPool;
  LArgs: array[0..CONCURRENT_PRODUCER_COUNT - 1] of TSubmitArgs;
  LThreads: array[0..CONCURRENT_PRODUCER_COUNT - 1] of TThreadID;
  LStart: Int32;
  LDone: Int32;
  LSubmitted: Int64;
  LConsumed: Int64;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LResult: TLockFreeWorkStealingResult;
  LI: Integer;
begin
  LPool := TWorkStealingPool.Create(1);
  LStart := 0;
  LDone := 0;
  LSubmitted := 0;
  LConsumed := 0;
  try
    for LI := 0 to CONCURRENT_PRODUCER_COUNT - 1 do
    begin
      LArgs[LI].Pool := LPool;
      LArgs[LI].Start := @LStart;
      LArgs[LI].Done := @LDone;
      LArgs[LI].Submitted := @LSubmitted;
      LThreads[LI] := BeginThread(@SubmitThread, @LArgs[LI]);
    end;
    AtomicStore32(LStart, 1, moRelease);

    while AtomicLoad32(LDone, moAcquire) < CONCURRENT_PRODUCER_COUNT do
    begin
      LResult := LPool.Steal(LTask, LData);
      if LResult = wsStolen then
        Inc(LConsumed)
      else
        CpuPause;
    end;
    repeat
      LResult := LPool.Steal(LTask, LData);
      if LResult = wsStolen then
        Inc(LConsumed);
    until LResult = wsEmpty;

    for LI := 0 to CONCURRENT_PRODUCER_COUNT - 1 do
      WaitForThreadTerminate(LThreads[LI], 5000);

    CheckEqual(Int64(CONCURRENT_PRODUCER_COUNT * CONCURRENT_OPS_PER_PRODUCER),
      AtomicLoad64(LSubmitted, moAcquire), 'All producer submissions must complete');
    CheckEqual(AtomicLoad64(LSubmitted, moAcquire), LConsumed,
      'Concurrent submissions must not overwrite tasks in the single-owner deque');
  finally
    LPool.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_workstealing ===');
  WriteLn;

  TestWorkStealingBasic;
  WriteLn('  + Basic state');

  TestWorkStealingSubmit;
  WriteLn('  + Submit');

  TestWorkStealingSteal;
  WriteLn('  + Steal');

  TestWorkStealingStealsSubmittedTask;
  WriteLn('  + Steal submitted task');

  TestWorkStealingClose;
  WriteLn('  + Close semantics');

  TestWorkStealingConcurrentSubmitPreservesTasks;
  WriteLn('  + Concurrent submit preserves tasks');

  WriteLn;
  WriteLn('All work stealing pool tests passed!');
end.
