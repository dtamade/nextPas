{
  test_async_combinators.lpr — WhenAll/WhenAny 组合器测试
}
program test_async_combinators;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.taskgroup,
  nextpas.core.async.combinators,
  nextpas.core.async.retry,
  nextpas.core.async.cancellation;

var
  GLoop: TAsyncLoop;
  GCompletedCount: Integer;
  GWhenAllDone: Boolean;
  GWhenAnyDone: Boolean;

{ ==================== 测试回调 ==================== }

procedure SimpleCallback(AContext: Pointer);
var
  LIdx: PInteger;
begin
  LIdx := PInteger(AContext);
  Inc(LIdx^);
end;

procedure WhenAllCompleteCallback(AContext: Pointer);
begin
  GWhenAllDone := True;
end;

procedure WhenAnyCompleteCallback(AContext: Pointer);
begin
  GWhenAnyDone := True;
end;

{ ==================== WhenAll 测试 ==================== }

procedure TestWhenAllCloseDiscardsWraps;
var
  LLoop: TAsyncLoop;
  LCallbacks: array[0..2] of TAsyncCallback;
  LContexts: array[0..2] of Pointer;
  LCounters: array[0..2] of Integer;
  I: Integer;
begin
  LLoop := TAsyncLoop.Create;
  for I := 0 to 2 do
  begin
    LCounters[I] := 0;
    LCallbacks[I] := @SimpleCallback;
    LContexts[I] := @LCounters[I];
  end;
  WhenAll(LCallbacks, LContexts, 3, @WhenAllCompleteCallback, nil,
    DefaultCombinatorOptions, LLoop);
  LLoop.Free;
  WriteLn('  PASS: WhenAllCloseDiscardsWraps');
end;

procedure TestRetryCloseDiscardsState;
var
  LLoop: TAsyncLoop;
begin
  LLoop := TAsyncLoop.Create;
  RetryWithBackoff(@SimpleCallback, nil, nil, nil, nil, nil, DefaultRetryOptions, LLoop);
  LLoop.Free;
  WriteLn('  PASS: RetryCloseDiscardsState');
end;

procedure TestWhenAllEmpty;
begin
  GWhenAllDone := False;
  WhenAll([], [], 0, @WhenAllCompleteCallback, nil, DefaultCombinatorOptions, GLoop);
  Check(GWhenAllDone, 'WhenAll empty should complete immediately');
  WriteLn('  PASS: WhenAllEmpty');
end;

procedure TestWhenAllSingle;
var
  LCallbacks: array[0..0] of TAsyncCallback;
  LContexts: array[0..0] of Pointer;
  LCounter: Integer;
  I: Integer;
begin
  GWhenAllDone := False;
  LCounter := 0;
  LCallbacks[0] := @SimpleCallback;
  LContexts[0] := @LCounter;

  WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, DefaultCombinatorOptions, GLoop);

  for I := 0 to 10 do
    GLoop.Poll;
  Check(GWhenAllDone, 'WhenAll single should complete');
  Check(LCounter = 1, 'Callback should be called once');
  WriteLn('  PASS: WhenAllSingle');
end;

procedure TestWhenAllMultiple;
var
  LCallbacks: array[0..2] of TAsyncCallback;
  LContexts: array[0..2] of Pointer;
  LCounters: array[0..2] of Integer;
  I: Integer;
begin
  GWhenAllDone := False;
  for I := 0 to 2 do
  begin
    LCounters[I] := 0;
    LCallbacks[I] := @SimpleCallback;
    LContexts[I] := @LCounters[I];
  end;

  WhenAll(LCallbacks, LContexts, 3, @WhenAllCompleteCallback, nil, DefaultCombinatorOptions, GLoop);

  // 多次 Poll 确保所有任务完成
  for I := 0 to 10 do
    GLoop.Poll;

  Check(GWhenAllDone, 'WhenAll multiple should complete');
  for I := 0 to 2 do
    Check(LCounters[I] = 1, 'Each callback should be called once');
  WriteLn('  PASS: WhenAllMultiple');
end;

{ ==================== WhenAny 测试 ==================== }

procedure TestWhenAnyEmpty;
begin
  GWhenAnyDone := False;
  WhenAny([], [], 0, @WhenAnyCompleteCallback, nil, DefaultCombinatorOptions, GLoop);
  Check(GWhenAnyDone, 'WhenAny empty should complete immediately');
  WriteLn('  PASS: WhenAnyEmpty');
end;

procedure TestWhenAnySingle;
var
  LCallbacks: array[0..0] of TAsyncCallback;
  LContexts: array[0..0] of Pointer;
  LCounter: Integer;
  I: Integer;
begin
  GWhenAnyDone := False;
  LCounter := 0;
  LCallbacks[0] := @SimpleCallback;
  LContexts[0] := @LCounter;

  WhenAny(LCallbacks, LContexts, 1, @WhenAnyCompleteCallback, nil, DefaultCombinatorOptions, GLoop);

  for I := 0 to 10 do
    GLoop.Poll;
  Check(GWhenAnyDone, 'WhenAny single should complete');
  Check(LCounter = 1, 'Callback should be called once');
  WriteLn('  PASS: WhenAnySingle');
end;

procedure TestWhenAnyMultiple;
var
  LCallbacks: array[0..2] of TAsyncCallback;
  LContexts: array[0..2] of Pointer;
  LCounters: array[0..2] of Integer;
  I: Integer;
begin
  GWhenAnyDone := False;
  for I := 0 to 2 do
  begin
    LCounters[I] := 0;
    LCallbacks[I] := @SimpleCallback;
    LContexts[I] := @LCounters[I];
  end;

  WhenAny(LCallbacks, LContexts, 3, @WhenAnyCompleteCallback, nil, DefaultCombinatorOptions, GLoop);

  for I := 0 to 10 do
    GLoop.Poll;
  Check(GWhenAnyDone, 'WhenAny multiple should complete');
  // 至少一个回调被调用
  Check((LCounters[0] + LCounters[1] + LCounters[2]) >= 1, 'At least one callback should be called');
  WriteLn('  PASS: WhenAnyMultiple');
end;

{ ==================== 选项测试 ==================== }

procedure TestWhenAllWithTimeout;
var
  LCallbacks: array[0..0] of TAsyncCallback;
  LContexts: array[0..0] of Pointer;
  LCounter: Integer;
  LOptions: TCombinatorOptions;
  I: Integer;
begin
  GWhenAllDone := False;
  LCounter := 0;
  LCallbacks[0] := @SimpleCallback;
  LContexts[0] := @LCounter;

  LOptions.TimeoutMs := 1000;
  LOptions.CancelOnError := False;

  WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, LOptions, GLoop);

  for I := 0 to 10 do
    GLoop.Poll;
  Check(GWhenAllDone, 'WhenAll with timeout should complete');
  WriteLn('  PASS: WhenAllWithTimeout');
end;

procedure NeverRunsCallback(AContext: Pointer);
begin
  Inc(PInteger(AContext)^);
end;

procedure TestWhenAllTokenCancel;
var
  LCallbacks: array[0..0] of TAsyncCallback;
  LContexts: array[0..0] of Pointer;
  LOptions: TCombinatorOptions;
  LToken: IAsyncCancellationToken;
  LCounter: Integer;
  I: Integer;
begin
  LCounter := 0;
  GWhenAllDone := False;
  LCallbacks[0] := @NeverRunsCallback;
  LContexts[0] := @LCounter;
  LOptions := DefaultCombinatorOptions;
  LToken := CreateCancellationToken;
  LOptions.Token := LToken;

  WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, LOptions, GLoop);
  LToken.Cancel;
  for I := 0 to 30 do
    GLoop.Poll;
  Check(GWhenAllDone, 'WhenAll token cancel should complete once');
  WriteLn('  PASS: WhenAllTokenCancel');
end;

procedure TestWhenAllTokenCancelSoak100;
var
  LCallbacks: array[0..0] of TAsyncCallback;
  LContexts: array[0..0] of Pointer;
  LOptions: TCombinatorOptions;
  LToken: IAsyncCancellationToken;
  LCounter: Integer;
  LI, LJ: Integer;
begin
  LCallbacks[0] := @NeverRunsCallback;
  LContexts[0] := @LCounter;
  for LI := 1 to 100 do
  begin
    LCounter := 0;
    GWhenAllDone := False;
    LOptions := DefaultCombinatorOptions;
    LToken := CreateCancellationToken;
    LOptions.Token := LToken;
    WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, LOptions, GLoop);
    LToken.Cancel;
    for LJ := 0 to 40 do
      GLoop.Poll;
    Check(GWhenAllDone, 'soak WhenAll token complete once #' + IntToStr(LI));
    LToken := nil;
  end;
  WriteLn('  PASS: WhenAllTokenCancelSoak100');
end;

procedure TestWhenAllTasksWinWithTimeoutArmed;
var
  LCallbacks: array[0..2] of TAsyncCallback;
  LContexts: array[0..2] of Pointer;
  LOptions: TCombinatorOptions;
  LCounter: Integer;
  I: Integer;
begin
  { Timeout armed but tasks complete first — CancelTimer ownership path. }
  LCounter := 0;
  GWhenAllDone := False;
  LOptions := DefaultCombinatorOptions;
  LOptions.TimeoutMs := 5000;
  for I := 0 to 2 do
  begin
    LCallbacks[I] := @SimpleCallback;
    LContexts[I] := @LCounter;
  end;
  WhenAll(LCallbacks, LContexts, 3, @WhenAllCompleteCallback, nil, LOptions, GLoop);
  for I := 0 to 30 do
    GLoop.Poll;
  Check(GWhenAllDone, 'tasks should complete with timeout armed');
  Check(LCounter = 3, 'all three task callbacks ran');
  WriteLn('  PASS: WhenAllTasksWinWithTimeoutArmed');
end;

procedure TestWhenAnyTokenCancel;
var
  LCallbacks: array[0..2] of TAsyncCallback;
  LContexts: array[0..2] of Pointer;
  LOptions: TCombinatorOptions;
  LToken: IAsyncCancellationToken;
  LCounter: Integer;
  I: Integer;
begin
  LCounter := 0;
  GWhenAnyDone := False;
  LOptions := DefaultCombinatorOptions;
  LToken := CreateCancellationToken;
  LOptions.Token := LToken;
  for I := 0 to 2 do
  begin
    LCallbacks[I] := @NeverRunsCallback;
    LContexts[I] := @LCounter;
  end;
  WhenAny(LCallbacks, LContexts, 3, @WhenAnyCompleteCallback, nil, LOptions, GLoop);
  LToken.Cancel;
  for I := 0 to 40 do
    GLoop.Poll;
  Check(GWhenAnyDone, 'WhenAny token cancel should complete once');
  WriteLn('  PASS: WhenAnyTokenCancel');
end;

procedure TestWhenAllTokenAndTimeoutRace;
var
  LCallbacks: array[0..0] of TAsyncCallback;
  LContexts: array[0..0] of Pointer;
  LOptions: TCombinatorOptions;
  LToken: IAsyncCancellationToken;
  LCounter: Integer;
  I: Integer;
begin
  LCounter := 0;
  GWhenAllDone := False;
  LCallbacks[0] := @NeverRunsCallback;
  LContexts[0] := @LCounter;
  LOptions := DefaultCombinatorOptions;
  LOptions.TimeoutMs := 1;
  LToken := CreateCancellationToken;
  LOptions.Token := LToken;
  WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, LOptions, GLoop);
  LToken.Cancel;
  for I := 0 to 50 do
    GLoop.Poll;
  Check(GWhenAllDone, 'token+timeout race still completes once');
  WriteLn('  PASS: WhenAllTokenAndTimeoutRace');
end;

{ ==================== 主测试套件 ==================== }

procedure RunAllTests;
var
  I: Integer;
begin
  WriteLn('=== test_async_combinators ===');

  GLoop := TAsyncLoop.Create;

  { WhenAll 测试 }
  WriteLn('--- WhenAll Tests ---');
  TestWhenAllCloseDiscardsWraps;
  TestRetryCloseDiscardsState;
  TestWhenAllEmpty;
  TestWhenAllSingle;
  TestWhenAllMultiple;
  TestWhenAllWithTimeout;
  TestWhenAllTokenCancel;
  TestWhenAllTokenCancelSoak100;
  TestWhenAllTasksWinWithTimeoutArmed;
  TestWhenAllTokenAndTimeoutRace;

  { WhenAny 测试 }
  WriteLn('--- WhenAny Tests ---');
  TestWhenAnyEmpty;
  TestWhenAnySingle;
  TestWhenAnyMultiple;
  TestWhenAnyTokenCancel;

  for I := 0 to 20 do
    GLoop.Poll;
  GLoop.Free;

  WriteLn('=== All tests passed ===');
end;

begin
  RunAllTests;
end.
