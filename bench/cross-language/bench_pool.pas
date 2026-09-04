{**
 * bench_pool.pas — nextPas TSyncPool 跨语言基准
 *
 * 与 Go sync.Pool 和 Rust SyncPool 同场景对比
 *}
program bench_pool;
{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}nextpas.core.thread.init,{$ENDIF}
  nextpas.core.time.base,
  nextpas.core.sync.pool,
  nextpas.core.platform.thread;

const
  N = 1000000;

type
  TTestObj = class(TPoolItem)
  public
    Value: Integer;
  end;

  PWorkerCtx = ^TWorkerCtx;
  TWorkerCtx = record
    Pool: TSyncPool;
    Iterations: Integer;
    InternalMs: QWord; { 内部计时, 排除线程创建/销毁开销 }
  end;

var
  GCreateCounter: Integer = 0;

function FactoryFunc: Pointer;
var LObj: TTestObj;
begin
  LObj := TTestObj.Create;
  LObj.Value := GCreateCounter;
  Inc(GCreateCounter);
  Result := LObj;
end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PWorkerCtx;
  I: Integer;
  LObj: TTestObj;
  T0, T1: TInstant;
begin
  LCtx := PWorkerCtx(AArg);
  { warmup: 填充 TLS }
  for I := 1 to 1000 do begin
    LObj := TTestObj(LCtx^.Pool.Get);
    LObj.Value := I;
    LCtx^.Pool.Put(LObj);
  end;
  { 计时: 仅测量 get/put 循环 }
  T0 := TInstant.Now;
  for I := 1 to LCtx^.Iterations do begin
    LObj := TTestObj(LCtx^.Pool.Get);
    LObj.Value := I;
    LCtx^.Pool.Put(LObj);
  end;
  T1 := TInstant.Now;
  LCtx^.InternalMs := T1.DurationSince(T0).AsMilliseconds;
  Result := nil;
end;

procedure BenchDirectAlloc;
var
  T0, T1: TInstant;
  I: Integer;
  LObj: TTestObj;
begin
  T0 := TInstant.Now;
  for I := 1 to N do
  begin
    LObj := TTestObj.Create;
    LObj.Value := I;
    LObj.Free;
  end;
  T1 := TInstant.Now;
  WriteLn('Direct alloc x', N, ': ', T1.DurationSince(T0).AsMilliseconds, ' ms');
end;

procedure BenchPoolSingleThread;
var
  LPool: TSyncPool;
  T0, T1: TInstant;
  I: Integer;
  LObj: TTestObj;
begin
  LPool := CreateSyncPool(@FactoryFunc);
  try
    { warmup }
    for I := 1 to 1000 do
    begin
      LObj := TTestObj(LPool.Get);
      LObj.Value := I;
      LPool.Put(LObj);
    end;

    T0 := TInstant.Now;
    for I := 1 to N do
    begin
      LObj := TTestObj(LPool.Get);
      LObj.Value := I;
      LPool.Put(LObj);
    end;
    T1 := TInstant.Now;
    WriteLn('Pool get/put x', N, ': ', T1.DurationSince(T0).AsMilliseconds, ' ms');
  finally
    LPool.Free;
  end;
end;

procedure BenchPoolConcurrent(AThreadCount: Integer);
var
  LPool: TSyncPool;
  LPerThread: Integer;
  LStart: QWord;
  I: Integer;
  LObj: TTestObj;
  LThreads: array of TPlatformThreadRecord;
  LCtxs: array of PWorkerCtx;
begin
  LPerThread := N div AThreadCount;
  LPool := CreateSyncPool(@FactoryFunc);
  try
    { warmup — 通过 Get/Put 填充 TLS }
    for I := 1 to 1000 do
    begin
      LObj := TTestObj(LPool.Get);
      LObj.Value := I;
      LPool.Put(LObj);
    end;

    SetLength(LThreads, AThreadCount);
    SetLength(LCtxs, AThreadCount);
    for I := 0 to AThreadCount - 1 do
    begin
      New(LCtxs[I]);
      LCtxs[I]^.Pool := LPool;
      LCtxs[I]^.Iterations := LPerThread;
      LCtxs[I]^.InternalMs := 0;
      if platform_thread_spawn(LThreads[I], @WorkerProc, LCtxs[I]) <> 0 then
      begin
        WriteLn('thread spawn failed');
        Halt(1);
      end;
    end;

    { 等待所有线程 }
    for I := 0 to AThreadCount - 1 do
      platform_thread_wait(LThreads[I]);

    { 取最长内部计时 (排除线程创建/销毁开销) }
    LStart := 0;
    for I := 0 to AThreadCount - 1 do begin
      if LCtxs[I]^.InternalMs > LStart then
        LStart := LCtxs[I]^.InternalMs;
      Dispose(LCtxs[I]);
    end;

    WriteLn('Pool ', AThreadCount:2, 'T x ', LPerThread * AThreadCount:7,
      ' ops: ', LStart, ' ms (internal)');
  finally
    LPool.Free;
  end;
end;

begin
  WriteLn('=== nextPas TSyncPool Benchmark ===');
  WriteLn('FPC ', {$I %FPCVERSION%}, ' / ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
  WriteLn;

  BenchDirectAlloc;

  WriteLn;
  BenchPoolSingleThread;

  WriteLn;
  BenchPoolConcurrent(1);
  BenchPoolConcurrent(2);
  BenchPoolConcurrent(4);
  BenchPoolConcurrent(8);
  BenchPoolConcurrent(16);
  BenchPoolConcurrent(32);
end.
