program test_lockfree_forkjoin;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.lockfree.forkjoin;

var
  GTests, GPassed: Integer;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

var
  GSum: Int64;

procedure SumTask(AUserData: Pointer);
begin
  AtomicFetchAdd64(GSum, Int64(PtrInt(AUserData)));
end;

procedure TestBasicForkPop;
var
  LPool: TLockFreeForkJoinPool;
  LTask: TForkJoinTask;
begin
  WriteLn('--- TestBasicForkPop ---');
  LPool := TLockFreeForkJoinPool.Create(2);
  try
    LTask.Proc := @SumTask;
    LTask.UserData := Pointer(PtrInt(42));
    Check(LPool.Fork(LTask) = fjOk, 'fork ok');
    Check(LPool.ApproxPendingCount = 1, 'pending = 1');
    Check(LPool.PopOrSteal(0, LTask), 'pop from worker 0');
    LTask.Proc(LTask.UserData);
    Check(GSum = 42, 'task executed');
    Check(LPool.ApproxCompletedCount = 1, 'completed = 1');
  finally
    LPool.Free;
  end;
end;

procedure TestSteal;
var
  LPool: TLockFreeForkJoinPool;
  LTask: TForkJoinTask;
begin
  WriteLn('--- TestSteal ---');
  GSum := 0;
  LPool := TLockFreeForkJoinPool.Create(2);
  try
    // Submit to worker 0
    LTask.Proc := @SumTask;
    LTask.UserData := Pointer(PtrInt(100));
    LPool.Fork(LTask);
    // Worker 1 should be able to steal from worker 0
    Check(LPool.PopOrSteal(1, LTask), 'steal from worker 0 by worker 1');
    LTask.Proc(LTask.UserData);
    Check(GSum = 100, 'task executed via steal');
  finally
    LPool.Free;
  end;
end;

procedure TestMultipleTasks;
var
  LPool: TLockFreeForkJoinPool;
  LTask: TForkJoinTask;
  I: Int32;
begin
  WriteLn('--- TestMultipleTasks ---');
  GSum := 0;
  LPool := TLockFreeForkJoinPool.Create(4);
  try
    LTask.Proc := @SumTask;
    for I := 1 to 100 do
    begin
      LTask.UserData := Pointer(PtrInt(I));
      Check(LPool.Fork(LTask) = fjOk, 'fork');
    end;
    Check(LPool.ApproxPendingCount = 100, 'pending = 100');
    // Execute all tasks
    while LPool.PopOrSteal(0, LTask) do
      LTask.Proc(LTask.UserData);
    Check(GSum = 5050, 'sum = 5050');
  finally
    LPool.Free;
  end;
end;

procedure TestClose;
var
  LPool: TLockFreeForkJoinPool;
  LTask: TForkJoinTask;
begin
  WriteLn('--- TestClose ---');
  LPool := TLockFreeForkJoinPool.Create(2);
  try
    LTask.Proc := @SumTask;
    LTask.UserData := Pointer(PtrInt(1));
    LPool.Fork(LTask);
    LPool.Close;
    Check(LPool.IsClosed, 'is closed');
    Check(LPool.Fork(LTask) = fjClosed, 'fork after close fails');
  finally
    LPool.Free;
  end;
end;

procedure TestWorkerCount;
var
  LPool: TLockFreeForkJoinPool;
begin
  WriteLn('--- TestWorkerCount ---');
  LPool := TLockFreeForkJoinPool.Create(8);
  try
    Check(LPool.WorkerCount = 8, 'worker count = 8');
  finally
    LPool.Free;
  end;
end;

procedure TestInvalidWorkerId;
var
  LPool: TLockFreeForkJoinPool;
  LTask: TForkJoinTask;
  LRaised: Boolean;
begin
  WriteLn('--- TestInvalidWorkerId ---');
  LPool := TLockFreeForkJoinPool.Create(2);
  try
    LRaised := False;
    try
      LPool.PopOrSteal(-1, LTask);
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'negative worker ID raises');

    LRaised := False;
    try
      LPool.PopOrSteal(LPool.WorkerCount, LTask);
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'worker ID at upper bound raises');
  finally
    LPool.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;
  GSum := 0;

  TestBasicForkPop;
  TestSteal;
  TestMultipleTasks;
  TestClose;
  TestWorkerCount;
  TestInvalidWorkerId;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
