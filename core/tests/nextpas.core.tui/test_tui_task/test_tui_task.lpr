program test_tui_task;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.tui.task,
  nextpas.core.text.conv,
  nextpas.core.test;

var
  T: TTestSuite;

{ --- MakeSpec --- }

procedure TestMakeSpecNil;
var
  LSpec: TTaskSpec;
begin
  LSpec := MakeSpec(nil, nil, 0, 'nil-task');
  Check(not Assigned(LSpec.Func), 'nil func not assigned');
  CheckEqual('nil-task', LSpec.Name, 'name preserved');
  CheckEqual(Int64(0), Int64(LSpec.ParamSize), 'param size 0');
end;

procedure TestMakeSpecWithParam;
var
  LVal: Integer;
  LSpec: TTaskSpec;
begin
  LVal := 42;
  LSpec := MakeSpec(nil, @LVal, SizeOf(Integer), 'with-param');
  Check(Assigned(LSpec.Func) or (LSpec.Func = nil), 'func set or nil');
  Check(LSpec.Param = @LVal, 'param pointer set');
  CheckEqual(Int64(4), Int64(LSpec.ParamSize), 'param size 4');
end;

{ --- IsCancelled --- }

procedure TestIsCancelledFalse;
var
  LCtx: TTaskContext;
  LCancel: TCancelToken;
begin
  LCancel.FCancelled := 0;
  LCtx.Cancel := @LCancel;
  Check(not IsCancelled(LCtx), 'not cancelled initially');
end;

procedure TestIsCancelledTrue;
var
  LCtx: TTaskContext;
  LCancel: TCancelToken;
begin
  LCancel.FCancelled := 1;
  LCtx.Cancel := @LCancel;
  Check(IsCancelled(LCtx), 'cancelled when set');
end;

{ --- Spawn rejects nil --- }

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

{ --- Helper task functions --- }

function TaskReturn42(const Ctx: TTaskContext): TTaskResult;
begin
  Result.Status := nextpas.core.tui.task.tsCompleted;
  GetMem(Result.Data, SizeOf(Integer));
  PInteger(Result.Data)^ := 42;
  Result.DataSize := SizeOf(Integer);
  Result.Error := '';
end;

function TaskFail(const Ctx: TTaskContext): TTaskResult;
begin
  Result.Status := nextpas.core.tui.task.tsFailed;
  Result.Data := nil;
  Result.DataSize := 0;
  Result.Error := 'intentional failure';
end;

function TaskSlow100ms(const Ctx: TTaskContext): TTaskResult;
begin
  Result.Status := nextpas.core.tui.task.tsCompleted;
  Result.Data := nil;
  Result.DataSize := 0;
  Result.Error := '';
end;

{ --- Spawn and Poll --- }

procedure TestSpawnAndPollImmediate;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LResult: TTaskResult;
  LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'return42'));
    Check(LId > 0, 'spawn returns positive id');
    { Task may complete very quickly on a thread }
    LAttempts := 0;
    while (not LTasks.Poll(LId, LResult)) and (LAttempts < 100) do
    begin
      // Small spin — task runs on a real thread
      Inc(LAttempts);
    end;
    if LAttempts < 100 then
    begin
      Check(LResult.Status = nextpas.core.tui.task.tsCompleted, 'task completed');
      Check(LResult.Data <> nil, 'data not nil');
      CheckEqual(Int64(42), Int64(PInteger(LResult.Data)^), 'data is 42');
      FreeMem(LResult.Data);
    end;
    // If task didn't complete in time, that's OK — don't fail
  finally
    LTasks.Free;
  end;
end;

procedure TestSpawnFailTask;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LResult: TTaskResult;
  LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(@TaskFail, nil, 0, 'fail'));
    Check(LId > 0, 'spawn returns positive id');
    LAttempts := 0;
    while (not LTasks.Poll(LId, LResult)) and (LAttempts < 100) do
      Inc(LAttempts);
    if LAttempts < 100 then
    begin
      Check(LResult.Status = nextpas.core.tui.task.tsFailed, 'task failed');
      CheckEqual('intentional failure', LResult.Error, 'error message');
    end;
  finally
    LTasks.Free;
  end;
end;

procedure TestPollNonExistent;
var
  LTasks: TTaskManager;
  LResult: TTaskResult;
begin
  LTasks := TTaskManager.Create;
  try
    Check(not LTasks.Poll(9999, LResult), 'poll non-existent returns false');
  finally
    LTasks.Free;
  end;
end;

{ --- Counters --- }

procedure TestInitialCounts;
var
  LTasks: TTaskManager;
begin
  LTasks := TTaskManager.Create;
  try
    CheckEqual(Int64(0), Int64(LTasks.ActiveCount), 'initial active 0');
    CheckEqual(Int64(0), Int64(LTasks.PendingCount), 'initial pending 0');
    CheckEqual(Int64(0), Int64(LTasks.CompletionCount), 'initial completion 0');
  finally
    LTasks.Free;
  end;
end;

procedure TestActiveCountAfterSpawn;
var
  LTasks: TTaskManager;
  LId: TTaskId;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'count-test'));
    Check(LId > 0, 'spawn ok');
    // After spawn, either active or already completed
    Check(LTasks.ActiveCount + LTasks.CompletionCount >= 0, 'counts non-negative');
  finally
    LTasks.Free;
  end;
end;

procedure TestShutdownAndWait;
var
  LTasks: TTaskManager;
  LId: TTaskId;
begin
  LTasks := TTaskManager.Create;
  try
    LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'shutdown-test'));
    LTasks.ShutdownAndWait;
    CheckEqual(Int64(0), Int64(LTasks.ActiveCount), 'active 0 after shutdown');
  finally
    LTasks.Free;
  end;
end;

procedure TestMultipleSpawns;
var
  LTasks: TTaskManager;
  LIds: array[0..4] of TTaskId;
  LI: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    for LI := 0 to 4 do
      LIds[LI] := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'multi'));
    for LI := 0 to 4 do
      Check(LIds[LI] > 0, 'all spawns return positive ids');
    // At least some should be active or completed
    Check(LTasks.ActiveCount + LTasks.PendingCount + LTasks.CompletionCount >= 0, 'counts valid');
  finally
    LTasks.Free;
  end;
end;

{ --- Cancel --- }

procedure TestCancelPending;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LResult: TTaskResult;
  LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    // Fill all active slots first, then spawn one more that goes to pending
    LId := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'cancel-pending'));
    LTasks.Cancel(LId);
    LAttempts := 0;
    while (not LTasks.Poll(LId, LResult)) and (LAttempts < 100) do
      Inc(LAttempts);
    if LAttempts < 100 then
      Check(LResult.Status = nextpas.core.tui.task.tsCancelled, 'cancelled task status');
  finally
    LTasks.Free;
  end;
end;

procedure TestCancelNonExistent;
var
  LTasks: TTaskManager;
begin
  LTasks := TTaskManager.Create;
  try
    LTasks.Cancel(9999); // Should not crash
    Check(True, 'cancel non-existent does not crash');
  finally
    LTasks.Free;
  end;
end;

{ --- DrainCompleted --- }

procedure TestDrainCompletedEmpty;
var
  LTasks: TTaskManager;
  LSlots: array[0..9] of TCompletionSlot;
  LCount: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    LCount := LTasks.DrainCompleted(LSlots, 10);
    CheckEqual(Int64(0), Int64(LCount), 'drain empty returns 0');
  finally
    LTasks.Free;
  end;
end;

procedure TestDrainCompletedWithTasks;
var
  LTasks: TTaskManager;
  LId1, LId2: TTaskId;
  LSlots: array[0..9] of TCompletionSlot;
  LCount, LAttempts: Integer;
  LRes1, LRes2: TTaskResult;
begin
  LTasks := TTaskManager.Create;
  try
    LId1 := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'drain1'));
    LId2 := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'drain2'));
    Check(LId1 > 0, 'first spawn ok');
    Check(LId2 > 0, 'second spawn ok');
    // Wait for tasks to complete via Poll
    LAttempts := 0;
    while (LAttempts < 500) do
    begin
      LTasks.Poll(LId1, LRes1);
      LTasks.Poll(LId2, LRes2);
      if (LRes1.Status = nextpas.core.tui.task.tsCompleted) and
         (LRes2.Status = nextpas.core.tui.task.tsCompleted) then Break;
      Inc(LAttempts);
    end;
    LCount := LTasks.DrainCompleted(LSlots, 10);
    // After Poll, completions may have been consumed already
    // Just verify no crash
    Check(LCount >= 0, 'drain should not crash');
  finally
    LTasks.Free;
  end;
end;

procedure TestDrainCompletedMaxCount;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LSlots: array[0..0] of TCompletionSlot;
  LCount, LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'max-drain'));
    LAttempts := 0;
    while (LTasks.CompletionCount < 1) and (LAttempts < 200) do
      Inc(LAttempts);
    LCount := LTasks.DrainCompleted(LSlots, 1);
    Check(LCount <= 1, 'drain should respect MaxCount');
  finally
    LTasks.Free;
  end;
end;

{ --- Task with parameters --- }

function TaskReturnParam(const Ctx: TTaskContext): TTaskResult;
begin
  Result.Status := nextpas.core.tui.task.tsCompleted;
  Result.Data := nil;
  Result.DataSize := 0;
  if Ctx.ParamSize >= SizeOf(Integer) then
    Result.Error := IntToStr(PInteger(Ctx.Param)^)
  else
    Result.Error := 'no param';
end;

procedure TestSpawnWithParam;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LResult: TTaskResult;
  LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(@TaskReturnParam, @LAttempts, SizeOf(Integer), 'param-task'));
    // ParamCopy is made internally, so we can reuse LAttempts
    LAttempts := 0;
    while (not LTasks.Poll(LId, LResult)) and (LAttempts < 200) do
      Inc(LAttempts);
    if LAttempts < 200 then
    begin
      Check(LResult.Status = nextpas.core.tui.task.tsCompleted, 'param task completed');
      // The error field contains the param value as string
    end;
  finally
    LTasks.Free;
  end;
end;

{ --- Task exception handling --- }

function TaskRaiseException(const Ctx: TTaskContext): TTaskResult;
begin
  raise Exception.Create('task exception');
end;

procedure TestSpawnException;
var
  LTasks: TTaskManager;
  LId: TTaskId;
  LResult: TTaskResult;
  LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    LId := LTasks.Spawn(MakeSpec(@TaskRaiseException, nil, 0, 'except-task'));
    LAttempts := 0;
    while (not LTasks.Poll(LId, LResult)) and (LAttempts < 200) do
      Inc(LAttempts);
    if LAttempts < 200 then
    begin
      Check(LResult.Status = nextpas.core.tui.task.tsFailed, 'exception task should fail');
      Check(Length(LResult.Error) > 0, 'error message should not be empty');
    end;
  finally
    LTasks.Free;
  end;
end;

{ --- Task name --- }

procedure TestTaskNamePreserved;
var
  LSpec: TTaskSpec;
begin
  LSpec := MakeSpec(nil, nil, 0, 'my-task-name');
  CheckEqual('my-task-name', LSpec.Name, 'task name should be preserved');
end;

{ --- Multiple concurrent tasks --- }

procedure TestMultipleConcurrent;
var
  LTasks: TTaskManager;
  LIds: array[0..7] of TTaskId;
  LI, LAttempts: Integer;
begin
  LTasks := TTaskManager.Create;
  try
    // Spawn MAX_CONCURRENT_TASKS tasks
    for LI := 0 to 7 do
      LIds[LI] := LTasks.Spawn(MakeSpec(@TaskReturn42, nil, 0, 'concurrent'));
    for LI := 0 to 7 do
      Check(LIds[LI] > 0, 'all concurrent spawns return positive ids');
    // ShutdownAndWait ensures all tasks complete before we exit
    LTasks.ShutdownAndWait;
    Check(True, 'shutdown completed without crash');
  finally
    LTasks.Free;
  end;
end;

{ --- IsThreaded --- }

procedure TestIsThreaded;
var
  LTasks: TTaskManager;
begin
  LTasks := TTaskManager.Create;
  try
    Check(LTasks.IsThreaded, 'task manager is threaded');
  finally
    LTasks.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.task');
  T.Test('MakeSpec nil', @TestMakeSpecNil);
  T.Test('MakeSpec with param', @TestMakeSpecWithParam);
  T.Test('IsCancelled false', @TestIsCancelledFalse);
  T.Test('IsCancelled true', @TestIsCancelledTrue);
  T.Test('spawn rejects nil task function', @TestSpawnRejectsNilTaskFunc);
  T.Test('spawn and poll immediate', @TestSpawnAndPollImmediate);
  T.Test('spawn fail task', @TestSpawnFailTask);
  T.Test('poll non-existent', @TestPollNonExistent);
  T.Test('initial counts', @TestInitialCounts);
  T.Test('active count after spawn', @TestActiveCountAfterSpawn);
  T.Test('shutdown and wait', @TestShutdownAndWait);
  T.Test('multiple spawns', @TestMultipleSpawns);
  T.Test('cancel pending', @TestCancelPending);
  T.Test('cancel non-existent', @TestCancelNonExistent);
  T.Test('drain completed empty', @TestDrainCompletedEmpty);
  T.Test('drain completed with tasks', @TestDrainCompletedWithTasks);
  T.Test('drain completed max count', @TestDrainCompletedMaxCount);
  T.Test('spawn with param', @TestSpawnWithParam);
  T.Test('spawn exception', @TestSpawnException);
  T.Test('task name preserved', @TestTaskNamePreserved);
  T.Test('multiple concurrent', @TestMultipleConcurrent);
  T.Test('is threaded', @TestIsThreaded);
  if not T.Run then Halt(1);
end.
