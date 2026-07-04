program test_tui_task;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.tui.task,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestSpawnRejectsNilTaskFunc;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LResult: TTaskResult;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(nil, nil, 0, 'nil'));

    CheckEqual(Int64(0), Int64(LId), 'nil task function returns invalid id');
    CheckEqual(Int64(0), Int64(LTasks.ActiveCount), 'nil task function is not active');
    CheckEqual(Int64(0), Int64(LTasks.PendingCount), 'nil task function is not pending');
    CheckEqual(Int64(0), Int64(LTasks.CompletionCount), 'nil task function does not complete');
    Check(not LTasks.Poll(0, LResult), 'invalid nil task id is not pollable');
  finally
    LTasks.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.task');
  T.Test('spawn rejects nil task function', @TestSpawnRejectsNilTaskFunc);
  if not T.Run then Halt(1);
end.
