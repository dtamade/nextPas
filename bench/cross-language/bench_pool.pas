{**
 * bench_pool.pas — nextPas TSyncPool 跨语言基准
 *
 * 与 Go sync.Pool 和 Rust SyncPool 同场景对比
 *}
program bench_pool;
{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SyncObjs,  { Classes for TThread — cross-language benchmark requires FPC RTL }
  nextpas.core.time.base,
  nextpas.core.sync.pool;

const
  N = 1000000;

type
  TTestObj = class(TPoolItem)
  public
    Value: Integer;
  end;

  TWorkerThread = class(TThread)
  public
    Pool: TSyncPool;
    Iterations: Integer;
    InternalMs: QWord; { 内部计时, 排除线程创建/销毁开销 }
    T0, T1: TInstant;
    procedure Execute; override;
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

procedure TWorkerThread.Execute;
var
  I: Integer;
  LObj: TTestObj;
  LStart: QWord;
begin
  { warmup: 填充 TLS }
  for I := 1 to 1000 do begin
    LObj := TTestObj(Pool.Get);
    LObj.Value := I;
    Pool.Put(LObj);
  end;
  { 计时: 仅测量 get/put 循环 }
  T0 := TInstant.Now;
  for I := 1 to Iterations do begin
    LObj := TTestObj(Pool.Get);
    LObj.Value := I;
    Pool.Put(LObj);
  end;
  T1 := TInstant.Now;
  InternalMs := T1.DurationSince(T0).AsMilliseconds;
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
  LThreads: array of TWorkerThread;
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
    for I := 0 to AThreadCount - 1 do
    begin
      LThreads[I] := TWorkerThread.Create(True);
      LThreads[I].Pool := LPool;
      LThreads[I].Iterations := LPerThread;
      LThreads[I].FreeOnTerminate := False;
    end;

    { 启动所有线程 }
    for I := 0 to AThreadCount - 1 do
      LThreads[I].Start;
    for I := 0 to AThreadCount - 1 do
      LThreads[I].WaitFor;

    { 取最长内部计时 (排除线程创建/销毁开销) }
    LStart := 0;
    for I := 0 to AThreadCount - 1 do begin
      if LThreads[I].InternalMs > LStart then
        LStart := LThreads[I].InternalMs;
      LThreads[I].Free;
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
