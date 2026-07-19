program test_worksteal;

{$I nextpas.core.settings.inc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  SysUtils,
  Classes,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool.worksteal,
  nextpas.core.platform.thread,
  nextpas.core.test;

var GCounter: Integer = 0;

function WorkstealPoolSourceUsesT1Deque: Boolean;
var
  LPath: string;
  LSrc: TStringList;
begin
  Result := False;
  LPath := ExpandFileName(
    IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    '../../../../src/nextpas.core.thread.pool.worksteal.pas');
  if not FileExists(LPath) then
    LPath := ExpandFileName('core/src/nextpas.core.thread.pool.worksteal.pas');
  if not FileExists(LPath) then
    Exit(False);
  LSrc := TStringList.Create;
  try
    LSrc.LoadFromFile(LPath);
    Result :=
      (Pos('nextpas.core.lockfree.deque', LSrc.Text) > 0) and
      (Pos('TWorkStealingDequeImpl', LSrc.Text) > 0) and
      (Pos('TDequeSlot', LSrc.Text) > 0);
  finally
    LSrc.Free;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('thread.worksteal');

  LSuite.Test('H3-5 source-contract: uses T1 lockfree.deque', procedure
  begin
    CheckTrue(WorkstealPoolSourceUsesT1Deque,
      'thread.pool.worksteal must use nextpas.core.lockfree.deque T1 deque');
  end);

  LSuite.Test('create and shutdown', procedure
  var LPool: IThreadPool;
  begin
    LPool := CreateWorkStealingPool(2);
    CheckTrue(LPool <> nil);
    CheckTrue(LPool.WorkerCount = 2);
    LPool.Shutdown;
    CheckTrue(True);
  end);

  LSuite.Test('submit single', procedure
  var LPool: IThreadPool;
  begin
    GCounter := 0;
    LPool := CreateWorkStealingPool(2);
    LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
    LPool.WaitAll;
    CheckTrue(InterlockedCompareExchange(GCounter, 0, 0) = 1);
    LPool.Shutdown;
  end);

  LSuite.Test('submit 100', procedure
  var LPool: IThreadPool; LI: Integer;
  begin
    GCounter := 0;
    LPool := CreateWorkStealingPool(4);
    for LI := 1 to 100 do
      LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
    LPool.WaitAll;
    CheckTrue(InterlockedCompareExchange(GCounter, 0, 0) = 100);
    LPool.Shutdown;
  end);

  LSuite.Test('submit 1000', procedure
  var LPool: IThreadPool; LI: Integer;
  begin
    GCounter := 0;
    LPool := CreateWorkStealingPool(4);
    for LI := 1 to 1000 do
      LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
    LPool.WaitAll;
    CheckTrue(InterlockedCompareExchange(GCounter, 0, 0) = 1000);
    LPool.Shutdown;
  end);

  LSuite.Test('submit 10000', procedure
  var LPool: IThreadPool; LI: Integer;
  begin
    GCounter := 0;
    LPool := CreateWorkStealingPool(4);
    for LI := 1 to 10000 do
      LPool.Submit(procedure begin InterlockedIncrement(GCounter); end);
    LPool.WaitAll;
    CheckTrue(InterlockedCompareExchange(GCounter, 0, 0) = 10000);
    LPool.Shutdown;
  end);

  LSuite.Test('WaitAll empty', procedure
  var LPool: IThreadPool;
  begin
    LPool := CreateWorkStealingPool(2);
    LPool.WaitAll;
    CheckTrue(True);
    LPool.Shutdown;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.thread.worksteal');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
