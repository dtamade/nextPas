program test_async_advanced;
{$I nextpas.core.settings.inc}
{$H+}

uses
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.task,
  nextpas.core.async.taskgroup,
  nextpas.core.async.shutdown,
  nextpas.core.async.cancellation;

var
  T: TTestSuite;
  GLoopRef: ^TAsyncLoop;
  GCallCount: UInt32;

procedure StopLoopCallback(AContext: Pointer);
begin
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure IncrementCallback(AContext: Pointer);
begin
  Inc(GCallCount);
end;

{ ==================== Task Group 非阻塞测试 ==================== }

procedure TestTaskGroupCreate;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  LGroup := CreateTaskGroup(LLoop);
  Check(LGroup.State = agsIdle, 'Initial state idle');
  Check(LGroup.TotalCount = 0, 'Initial total 0');
  Check(LGroup.ActiveCount = 0, 'Initial active 0');
  Check(LGroup.CompletedCount = 0, 'Initial completed 0');
  LGroup := nil;

  LLoop.Free;

end;

procedure TestTaskGroupRunTask;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  LGroup := CreateTaskGroup(LLoop);
  LGroup.RunTask(nil, nil);
  Check(LGroup.TotalCount = 1, 'TotalCount 1');
  Check(LGroup.ActiveCount = 1, 'ActiveCount 1');
  Check(LGroup.State = agsRunning, 'State running');
  LGroup := nil;

  LLoop.Free;

end;

procedure TestTaskGroupMultiple;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  LGroup := CreateTaskGroup(LLoop);
  LGroup.RunTask(nil, nil);
  LGroup.RunTask(nil, nil);
  LGroup.RunTask(nil, nil);
  Check(LGroup.TotalCount = 3, 'TotalCount 3');
  Check(LGroup.ActiveCount = 3, 'ActiveCount 3');
  LGroup := nil;

  LLoop.Free;

end;

procedure TestTaskGroupCancelAll;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  LGroup := CreateTaskGroup(LLoop);
  LGroup.RunTask(nil, nil);
  LGroup.RunTask(nil, nil);
  LGroup.CancelAll;
  Check(LGroup.State = agsCancelled, 'State cancelled');
  LGroup := nil;

  LLoop.Free;

end;

procedure TestTaskGroupTokenCancel;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
  LToken: IAsyncCancellationToken;
begin
  LLoop := TAsyncLoop.Create;
  LToken := CreateCancellationToken;
  LGroup := CreateTaskGroup(LLoop, [], LToken);
  LGroup.RunTask(nil, nil);
  LToken.Cancel;
  Check(LGroup.State = agsCancelled, 'token cancel maps to CancelAll');
  LGroup := nil;
  LToken := nil;
  LLoop.Free;
end;

procedure TestTaskGroupDrain;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  LGroup := CreateTaskGroup(LLoop);
  LGroup.RunTask(nil, nil);
  LGroup.Drain;
  Check(LGroup.State = agsDraining, 'State draining');
  LGroup.RunTask(nil, nil); { should be ignored }
  Check(LGroup.TotalCount = 1, 'TotalCount still 1 after drain');
  LGroup := nil;

  LLoop.Free;

end;

procedure TestTaskGroupOptions;
var
  LLoop: TAsyncLoop;
  LGroup1, LGroup2: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  LGroup1 := CreateTaskGroup(LLoop, []);
  LGroup2 := CreateTaskGroup(LLoop, [agoFailFast, agoCancelOnTimeout]);
  Check(LGroup1.State = agsIdle, 'Default idle');
  Check(LGroup2.State = agsIdle, 'Options idle');
  LGroup1 := nil;
  LGroup2 := nil;
  LLoop.Free;
end;

{ ==================== Task Group + Loop 测试 ==================== }

procedure TestTaskGroupWithLoop;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  GLoopRef := @LLoop;
  GCallCount := 0;
  LGroup := CreateTaskGroup(LLoop);
  LGroup.RunTask(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(50), @StopLoopCallback, nil);
  LLoop.Run;
  Check(GCallCount = 1, 'Task executed');
  Check(LGroup.CompletedCount = 1, 'Completed 1');
  Check(LGroup.ActiveCount = 0, 'Active 0');
  GLoopRef := nil;
  LGroup := nil;

  LLoop.Free;

end;

procedure TestMultipleTasksWithLoop;
var
  LLoop: TAsyncLoop;
  LGroup: IAsyncTaskGroup;
begin
  LLoop := TAsyncLoop.Create;
  GLoopRef := @LLoop;
  GCallCount := 0;
  LGroup := CreateTaskGroup(LLoop);
  LGroup.RunTask(@IncrementCallback, nil);
  LGroup.RunTask(@IncrementCallback, nil);
  LGroup.RunTask(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(50), @StopLoopCallback, nil);
  LLoop.Run;
  Check(GCallCount = 3, 'All tasks executed');
  Check(LGroup.CompletedCount = 3, 'Completed 3');
  Check(LGroup.ActiveCount = 0, 'Active 0');
  GLoopRef := nil;
  LGroup := nil;

  LLoop.Free;

end;

{ ==================== Shutdown 非阻塞测试 ==================== }

procedure TestShutdownCreate;
var
  LLoop: TAsyncLoop;
  LShutdown: IAsyncShutdown;
begin
  LLoop := TAsyncLoop.Create;
  try
    LShutdown := CreateShutdownManager(LLoop, [soGraceful], 100);
    Check(LShutdown.Phase = spRunning, 'Initial running');
    Check(not LShutdown.IsShuttingDown, 'Not shutting down');
    LShutdown := nil;
  finally
    LShutdown := nil;

    LLoop.Free;
  end;
end;

procedure TestShutdownRequest;
var
  LLoop: TAsyncLoop;
  LShutdown: IAsyncShutdown;
begin
  LLoop := TAsyncLoop.Create;
  try
    LShutdown := CreateShutdownManager(LLoop, [soGraceful], 100);
    LShutdown.RequestShutdown;
    Check(LShutdown.Phase = spDraining, 'Draining');
    Check(LShutdown.IsShuttingDown, 'Shutting down');
    LShutdown := nil;
  finally
    LShutdown := nil;

    LLoop.Free;
  end;
end;

procedure TestShutdownOptions;
var
  LLoop: TAsyncLoop;
  LShutdown1, LShutdown2: IAsyncShutdown;
begin
  LLoop := TAsyncLoop.Create;
  try
    LShutdown1 := CreateShutdownManager(LLoop, [soGraceful], 100);
    LShutdown2 := CreateShutdownManager(LLoop, [soGraceful, soAbortOnTimeout], 200);
    Check(LShutdown1.Phase = spRunning, 'Graceful running');
    Check(LShutdown2.Phase = spRunning, 'Abort running');
    LShutdown1 := nil;
    LShutdown2 := nil;
  finally
    LShutdown1 := nil;
    LShutdown2 := nil;
    LLoop.Free;
  end;
end;

procedure TestShutdownCallback;
var
  LLoop: TAsyncLoop;
  LShutdown: IAsyncShutdown;
begin
  LLoop := TAsyncLoop.Create;
  try
    LShutdown := CreateShutdownManager(LLoop, [soGraceful], 100);
    LShutdown.OnShutdown(@IncrementCallback, nil);
    LShutdown.RequestShutdown;
    LShutdown.RequestShutdown; { duplicate ignored }
    Check(LShutdown.Phase = spDraining, 'Still draining');
    LShutdown := nil;
  finally
    LShutdown := nil;

    LLoop.Free;
  end;
end;

{ ==================== Main ==================== }

begin
  T := TTestSuite.Create('nextpas.core.async.advanced');
  T.Test('TaskGroupCreate', @TestTaskGroupCreate);
  T.Test('TaskGroupRunTask', @TestTaskGroupRunTask);
  T.Test('TaskGroupMultiple', @TestTaskGroupMultiple);
  T.Test('TaskGroupCancelAll', @TestTaskGroupCancelAll);
  T.Test('TaskGroupTokenCancel', @TestTaskGroupTokenCancel);
  T.Test('TaskGroupDrain', @TestTaskGroupDrain);
  T.Test('TaskGroupOptions', @TestTaskGroupOptions);
  T.Test('TaskGroupWithLoop', @TestTaskGroupWithLoop);
  T.Test('MultipleTasksWithLoop', @TestMultipleTasksWithLoop);
  T.Test('ShutdownCreate', @TestShutdownCreate);
  T.Test('ShutdownRequest', @TestShutdownRequest);
  T.Test('ShutdownOptions', @TestShutdownOptions);
  T.Test('ShutdownCallback', @TestShutdownCallback);
  T.Run;
end.
