program test_worksteal;

{$I nextpas.core.settings.inc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool.worksteal,
  nextpas.core.platform.thread;

var
  GPass: Integer = 0;
  GFail: Integer = 0;
  GCounter: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure TestCreateAndShutdown;
var LPool: IThreadPool;
begin
  WriteLn('--- TestCreateAndShutdown ---');
  LPool := CreateWorkStealingPool(2);
  Check('Created', LPool <> nil);
  Check('WorkerCount=2', LPool.WorkerCount = 2);
  LPool.Shutdown;
  Check('Shutdown OK', True);
end;

procedure TestSubmitSingle;
var LPool: IThreadPool;
begin
  WriteLn('--- TestSubmitSingle ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(2);
  LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
  LPool.WaitAll;
  Check('Counter=1', InterlockedCompareExchange(GCounter, 0, 0) = 1);
  LPool.Shutdown;
end;

procedure TestSubmit100;
var LPool: IThreadPool; LI: Integer;
begin
  WriteLn('--- TestSubmit100 ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(4);
  for LI := 1 to 100 do
    LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
  LPool.WaitAll;
  Check('Counter=100', InterlockedCompareExchange(GCounter, 0, 0) = 100);
  LPool.Shutdown;
end;

procedure TestSubmit1000;
var LPool: IThreadPool; LI: Integer;
begin
  WriteLn('--- TestSubmit1000 ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(4);
  for LI := 1 to 1000 do
    LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
  LPool.WaitAll;
  Check('Counter=1000', InterlockedCompareExchange(GCounter, 0, 0) = 1000);
  LPool.Shutdown;
end;

procedure TestSubmit10000;
var LPool: IThreadPool; LI: Integer;
begin
  WriteLn('--- TestSubmit10000 ---');
  GCounter := 0;
  LPool := CreateWorkStealingPool(4);
  for LI := 1 to 10000 do
    LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
  LPool.WaitAll;
  Check('Counter=10000', InterlockedCompareExchange(GCounter, 0, 0) = 10000);
  LPool.Shutdown;
end;

procedure TestWaitAllEmpty;
var LPool: IThreadPool;
begin
  WriteLn('--- TestWaitAllEmpty ---');
  LPool := CreateWorkStealingPool(2);
  LPool.WaitAll;
  Check('No hang', True);
  LPool.Shutdown;
end;

begin
  WriteLn('=== nextpas.core.thread.pool.worksteal tests ===');
  WriteLn;
  TestCreateAndShutdown;
  TestSubmitSingle;
  TestSubmit100;
  TestSubmit1000;
  TestSubmit10000;
  TestWaitAllEmpty;
  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
