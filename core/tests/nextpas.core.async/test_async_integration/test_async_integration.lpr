{
  test_async_integration.lpr — 异步集成测试

  测试异步模式的集成：
  - WhenAll + 回调链
  - RetryWithBackoff + 条件逻辑
  - 多个异步组件协作
}
program test_async_integration;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.combinators,
  nextpas.core.async.retry;

var
  GLoop: TAsyncLoop;
  GStep: Integer;
  GWhenAllDone: Boolean;
  GRetryDone: Boolean;
  GRetryCount: Integer;
  GChainDone: Boolean;

{ ==================== 测试回调 ==================== }

{ 步骤回调 }
procedure StepCallback(AContext: Pointer);
var
  LStep: Integer;
begin
  LStep := SizeInt(AContext);
  Inc(GStep);
  WriteLn('  Step ', LStep, ' completed');
end;

{ WhenAll 完成回调 }
procedure OnWhenAllComplete(AContext: Pointer);
begin
  GWhenAllDone := True;
  WriteLn('  WhenAll: All steps completed');
end;

{ 重试回调 }
procedure RetryCallback(AContext: Pointer);
begin
  Inc(GRetryCount);
  WriteLn('  Retry attempt: ', GRetryCount);
end;

{ 重试错误检查 —— 前两次失败 }
procedure RetryError(AContext: Pointer);
begin
  if GRetryCount < 3 then
    WriteLn('  Retry error check: failed (attempt ', GRetryCount, ')')
  else
    WriteLn('  Retry error check: success (attempt ', GRetryCount, ')');
end;

{ 重试完成回调 }
procedure OnRetryComplete(AContext: Pointer);
begin
  GRetryDone := True;
  WriteLn('  Retry completed after ', GRetryCount, ' attempts');
end;

{ 链式回调 —— 第一步 }
procedure ChainStep1(AContext: Pointer);
begin
  Inc(GStep);
  WriteLn('  Chain step 1');
  // 调度下一步
  GLoop.Schedule(TDuration.FromMilliseconds(10), @StepCallback, Pointer(SizeInt(2)));
end;

{ 链式回调 —— 第二步 }
procedure ChainStep2(AContext: Pointer);
begin
  Inc(GStep);
  WriteLn('  Chain step 2');
  GChainDone := True;
end;

{ ==================== 集成测试 ==================== }

procedure TestWhenAllMultipleSteps;
var
  LCallbacks: array[0..2] of TAsyncCallback;
  LContexts: array[0..2] of Pointer;
  I: Integer;
begin
  WriteLn('--- TestWhenAllMultipleSteps ---');
  GWhenAllDone := False;
  GStep := 0;

  // 设置多个步骤
  for I := 0 to 2 do
  begin
    LCallbacks[I] := @StepCallback;
    LContexts[I] := Pointer(SizeInt(I + 1));
  end;

  // 使用 WhenAll 等待所有步骤
  WhenAll(LCallbacks, LContexts, 3, @OnWhenAllComplete, nil,
    DefaultCombinatorOptions, GLoop);

  // 运行循环
  for I := 0 to 10 do
    GLoop.Poll;

  Assert(GWhenAllDone, 'WhenAll should complete');
  Assert(GStep = 3, 'Should complete 3 steps');
  WriteLn('  PASS: WhenAllMultipleSteps');
end;

procedure TestRetryConditional;
var
  LOptions: TAsyncRetryOptions;
  I: Integer;
begin
  WriteLn('--- TestRetryConditional ---');
  GRetryDone := False;
  GRetryCount := 0;

  LOptions.MaxRetries := 5;
  LOptions.BaseDelayMs := 10;
  LOptions.MaxDelayMs := 100;
  LOptions.BackoffFactor := 2;

  // 使用重试机制
  RetryWithBackoff(
    @RetryCallback, nil,
    @RetryError, nil,
    @OnRetryComplete, nil,
    LOptions, GLoop
  );

  // 运行循环
  for I := 0 to 100 do
    GLoop.Poll;

  Assert(GRetryDone, 'Retry should complete');
  Assert(GRetryCount = 3, 'Should retry 3 times');
  WriteLn('  PASS: RetryConditional');
end;

procedure TestCallbackChain;
var
  I: Integer;
begin
  WriteLn('--- TestCallbackChain ---');
  GChainDone := False;
  GStep := 0;

  // 启动链式回调
  GLoop.Post(@ChainStep1, nil);

  // 运行循环
  for I := 0 to 10 do
    GLoop.Poll;

  Assert(GChainDone, 'Chain should complete');
  Assert(GStep = 2, 'Should complete 2 steps');
  WriteLn('  PASS: CallbackChain');
end;

procedure TestWhenAllWithRetry;
var
  LCallbacks: array[0..1] of TAsyncCallback;
  LContexts: array[0..1] of Pointer;
  LRetryOptions: TAsyncRetryOptions;
  I: Integer;
begin
  WriteLn('--- TestWhenAllWithRetry ---');
  GWhenAllDone := False;
  GRetryDone := False;
  GRetryCount := 0;
  GStep := 0;

  // 第一个回调：普通步骤
  LCallbacks[0] := @StepCallback;
  LContexts[0] := Pointer(SizeInt(1));

  // 第二个回调：重试
  LCallbacks[1] := @RetryCallback;
  LContexts[1] := nil;

  // 使用 WhenAll 等待
  WhenAll(LCallbacks, LContexts, 2, @OnWhenAllComplete, nil,
    DefaultCombinatorOptions, GLoop);

  // 同时启动重试
  LRetryOptions.MaxRetries := 3;
  LRetryOptions.BaseDelayMs := 10;
  LRetryOptions.MaxDelayMs := 100;
  LRetryOptions.BackoffFactor := 2;

  RetryWithBackoff(
    @RetryCallback, nil,
    @RetryError, nil,
    @OnRetryComplete, nil,
    LRetryOptions, GLoop
  );

  // 运行循环
  for I := 0 to 100 do
    GLoop.Poll;

  Assert(GWhenAllDone, 'WhenAll should complete');
  Assert(GRetryDone, 'Retry should complete');
  WriteLn('  PASS: WhenAllWithRetry');
end;

{ ==================== 主测试套件 ==================== }

procedure RunAllTests;
begin
  WriteLn('=== test_async_integration ===');

  GLoop := TAsyncLoop.Create;

  { 集成测试 }
  WriteLn('--- Integration Tests ---');
  TestWhenAllMultipleSteps;
  TestRetryConditional;
  TestCallbackChain;
  TestWhenAllWithRetry;

  GLoop.Close;
  GLoop.Free;

  WriteLn('=== All integration tests passed ===');
end;

begin
  RunAllTests;
end.
