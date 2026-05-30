program test_worksteal;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool.worksteal,
  nextpas.core.atomic;

var
  GPass: Integer = 0;
  GFail: Integer = 0;
  GCounter: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure IncrementTask;
begin
  AtomicIncrement(GCounter);
end;

procedure TestCreateAndShutdown;
var
  LPool: IThreadPool;
begin
  WriteLn('--- TestCreateAndShutdown ---');
  LPool := CreateWorkStealingPool(2);
  Check('Created', LPool <> nil);
  Check('WorkerCount=2', LPool.WorkerCount = 2);
  LPool.Shutdown;
  Check('Shutdown OK', True);
end;

procedure TestSubmitSingle;
var
  LPool: IThreadPool;
begin
  WriteLn('--- TestSubmitSingle ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(2);
  LPool.Submit(@IncrementTask);
  LPool.WaitAll;
  Check('Counter=1', GCounter = 1);
  LPool.Shutdown;
end;

procedure TestSubmitMany;
var
  LPool: IThreadPool;
  LI: Integer;
begin
  WriteLn('--- TestSubmitMany ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(4);
  for LI := 0 to 999 do
    LPool.Submit(@IncrementTask);
  LPool.WaitAll;
  Check('Counter=1000', GCounter = 1000);
  LPool.Shutdown;
end;

procedure TestWorkStealing;
var
  LPool: IThreadPool;
  LI: Integer;
begin
  WriteLn('--- TestWorkStealing ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(4);
  for LI := 0 to 9999 do
    LPool.Submit(@IncrementTask);
  LPool.WaitAll;
  Check('All 10000 completed', GCounter = 10000);
  LPool.Shutdown;
end;

procedure TestWaitAllEmpty;
var
  LPool: IThreadPool;
begin
  WriteLn('--- TestWaitAllEmpty ---');
  LPool := CreateWorkStealingPool(2);
  LPool.WaitAll;
  Check('WaitAll on empty OK', True);
  LPool.Shutdown;
end;

procedure TestShutdownWithPending;
var
  LPool: IThreadPool;
  LI: Integer;
begin
  WriteLn('--- TestShutdownWithPending ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(2);
  for LI := 0 to 99 do
    LPool.Submit(@IncrementTask);
  LPool.Shutdown;
  Check('Shutdown with pending no hang', True);
end;

begin
  WriteLn('=== nextpas.core.thread.pool.worksteal tests ===');
  WriteLn;
  TestCreateAndShutdown;
  TestSubmitSingle;
  TestSubmitMany;
  TestWorkStealing;
  TestWaitAllEmpty;
  TestShutdownWithPending;
  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
