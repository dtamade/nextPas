{
  test_async_retry.lpr — 异步重试机制测试
}
program test_async_retry;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.retry;

var
  GLoop: TAsyncLoop;
  GRetryCount: Integer;
  GCompleted: Boolean;
  GFailed: Boolean;
  GFailUntil: Integer;

{ ==================== 测试回调 ==================== }

{ 会失败的回调 }
procedure FailingCallback(AContext: Pointer);
begin
  Inc(GRetryCount);
  // 总是失败
end;

{ 错误检查回调 —— 总是返回失败 }
procedure AlwaysFailError(AContext: Pointer);
begin
  // 标记为失败
  GFailed := True;
end;

{ 成功回调 }
procedure SuccessCallback(AContext: Pointer);
begin
  Inc(GRetryCount);
  // 成功
end;

{ 错误检查回调 —— 返回成功 }
procedure AlwaysSuccessError(AContext: Pointer);
begin
  GFailed := False;
end;

{ 完成回调 }
procedure CompleteCallback(AContext: Pointer);
begin
  GCompleted := True;
end;

{ 条件失败回调 —— 前 N 次失败，之后成功 }
procedure ConditionalCallback(AContext: Pointer);
begin
  Inc(GRetryCount);
end;

procedure ConditionalError(AContext: Pointer);
begin
  if GRetryCount < GFailUntil then
    GFailed := True
  else
    GFailed := False;
end;

{ ==================== 重试测试 ==================== }

procedure TestRetrySuccess;
begin
  GRetryCount := 0;
  GCompleted := False;
  GFailed := False;

  RetryWithBackoff(
    @SuccessCallback, nil,
    @AlwaysSuccessError, nil,
    @CompleteCallback, nil,
    DefaultRetryOptions, GLoop
  );

  GLoop.Poll;
  Assert(GCompleted, 'Retry should complete');
  Assert(GRetryCount = 1, 'Should execute once');
  WriteLn('  PASS: RetrySuccess');
end;

procedure TestRetryMaxRetries;
var
  LOptions: TAsyncRetryOptions;
  I: Integer;
begin
  GRetryCount := 0;
  GCompleted := False;
  GFailed := False;

  LOptions.MaxRetries := 3;
  LOptions.BaseDelayMs := 10;
  LOptions.MaxDelayMs := 100;
  LOptions.BackoffFactor := 2;

  RetryWithBackoff(
    @FailingCallback, nil,
    @AlwaysFailError, nil,
    @CompleteCallback, nil,
    LOptions, GLoop
  );

  // 多次 Poll 确保所有重试完成
  for I := 0 to 100 do
    GLoop.Poll;

  Assert(GCompleted, 'Retry should complete after max retries');
  Assert(GRetryCount = 4, 'Should execute 4 times (1 initial + 3 retries)');
  WriteLn('  PASS: RetryMaxRetries');
end;

procedure TestRetryConditional;
var
  LOptions: TAsyncRetryOptions;
  I: Integer;
begin
  GRetryCount := 0;
  GCompleted := False;
  GFailed := False;
  GFailUntil := 3;

  LOptions.MaxRetries := 5;
  LOptions.BaseDelayMs := 10;
  LOptions.MaxDelayMs := 100;
  LOptions.BackoffFactor := 2;

  RetryWithBackoff(
    @ConditionalCallback, nil,
    @ConditionalError, nil,
    @CompleteCallback, nil,
    LOptions, GLoop
  );

  // 多次 Poll 确保所有重试完成
  for I := 0 to 100 do
    GLoop.Poll;

  Assert(GCompleted, 'Retry should complete');
  Assert(GRetryCount = 3, 'Should execute 3 times (fail until 3)');
  WriteLn('  PASS: RetryConditional');
end;

procedure TestRetryFixedDelay;
var
  I: Integer;
begin
  GRetryCount := 0;
  GCompleted := False;
  GFailed := False;

  RetryWithFixedDelay(
    @FailingCallback, nil,
    @AlwaysFailError, nil,
    @CompleteCallback, nil,
    2, 10, GLoop
  );

  // 多次 Poll 确保所有重试完成
  for I := 0 to 100 do
    GLoop.Poll;

  Assert(GCompleted, 'Retry should complete');
  Assert(GRetryCount = 3, 'Should execute 3 times (1 initial + 2 retries)');
  WriteLn('  PASS: RetryFixedDelay');
end;

procedure TestRetryZeroMaxRetries;
var
  I: Integer;
begin
  GRetryCount := 0;
  GCompleted := False;
  GFailed := False;

  RetryWithBackoff(
    @FailingCallback, nil,
    @AlwaysFailError, nil,
    @CompleteCallback, nil,
    DefaultRetryOptions, GLoop
  );

  // 多次 Poll 确保所有重试完成
  for I := 0 to 100 do
    GLoop.Poll;

  Assert(GCompleted, 'Retry should complete');
  Assert(GRetryCount = 4, 'Should execute 4 times (1 initial + 3 retries)');
  WriteLn('  PASS: RetryZeroMaxRetries');
end;

{ ==================== 主测试套件 ==================== }

procedure RunAllTests;
begin
  WriteLn('=== test_async_retry ===');

  GLoop := TAsyncLoop.Create;

  { 重试测试 }
  WriteLn('--- Retry Tests ---');
  TestRetrySuccess;
  TestRetryMaxRetries;
  TestRetryConditional;
  TestRetryFixedDelay;
  TestRetryZeroMaxRetries;

  GLoop.Close;
  GLoop.Free;

  WriteLn('=== All tests passed ===');
end;

begin
  RunAllTests;
end.
