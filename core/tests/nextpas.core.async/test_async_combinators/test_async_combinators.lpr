{
  test_async_combinators.lpr — WhenAll/WhenAny 组合器测试
}
program test_async_combinators;
{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.taskgroup,
  nextpas.core.async.combinators;

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
begin
  GWhenAllDone := False;
  LCounter := 0;
  LCallbacks[0] := @SimpleCallback;
  LContexts[0] := @LCounter;

  WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, DefaultCombinatorOptions, GLoop);

  // 手动运行一次循环处理任务
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
begin
  GWhenAnyDone := False;
  LCounter := 0;
  LCallbacks[0] := @SimpleCallback;
  LContexts[0] := @LCounter;

  WhenAny(LCallbacks, LContexts, 1, @WhenAnyCompleteCallback, nil, DefaultCombinatorOptions, GLoop);

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
begin
  GWhenAllDone := False;
  LCounter := 0;
  LCallbacks[0] := @SimpleCallback;
  LContexts[0] := @LCounter;

  LOptions.TimeoutMs := 1000;
  LOptions.CancelOnError := False;

  WhenAll(LCallbacks, LContexts, 1, @WhenAllCompleteCallback, nil, LOptions, GLoop);

  GLoop.Poll;
  Check(GWhenAllDone, 'WhenAll with timeout should complete');
  WriteLn('  PASS: WhenAllWithTimeout');
end;

{ ==================== 主测试套件 ==================== }

procedure RunAllTests;
begin
  WriteLn('=== test_async_combinators ===');

  GLoop := TAsyncLoop.Create;

  { WhenAll 测试 }
  WriteLn('--- WhenAll Tests ---');
  TestWhenAllEmpty;
  TestWhenAllSingle;
  TestWhenAllMultiple;
  TestWhenAllWithTimeout;

  { WhenAny 测试 }
  WriteLn('--- WhenAny Tests ---');
  TestWhenAnyEmpty;
  TestWhenAnySingle;
  TestWhenAnyMultiple;

  GLoop.Close;
  GLoop.Close;

  WriteLn('=== All tests passed ===');
end;

begin
  RunAllTests;
end.
