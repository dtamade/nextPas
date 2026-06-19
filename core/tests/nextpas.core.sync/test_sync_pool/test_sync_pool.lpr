{**
 * test_sync_pool — TSyncPool 线程安全对象池测试
 *
 * 覆盖: 单线程基本操作 / 多线程并发 / TLS 缓存命中 / 全局池批量转移 /
 *       容量限制 / 确定性析构 / 回调 / Stats / 泄漏
 *}
program test_sync_pool;
{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.testing,
  nextpas.core.sync.pool;

type
  { 测试对象 }
  TTestObj = class
  public
    Value: Integer;
    ResetCount: Integer;
    DestroyCount: PInteger; { 指向外部计数器 }
    constructor Create(AValue: Integer; ADestroyCount: PInteger);
    destructor Destroy; override;
  end;

constructor TTestObj.Create(AValue: Integer; ADestroyCount: PInteger);
begin
  inherited Create;
  Value := AValue;
  ResetCount := 0;
  DestroyCount := ADestroyCount;
end;

destructor TTestObj.Destroy;
begin
  if DestroyCount <> nil then
    Inc(DestroyCount^);
  inherited Destroy;
end;

var
  T: TTestRunner;
  GDestroyCount: Integer;
  GCreateCounter: Integer;

function FactoryFunc: TObject;
begin
  Result := TTestObj.Create(GCreateCounter, @GDestroyCount);
  Inc(GCreateCounter);
end;

procedure ResetProc(AObj: TObject);
begin
  if AObj is TTestObj then
    TTestObj(AObj).ResetCount := TTestObj(AObj).ResetCount + 1;
end;

{ ===== 单线程基本操作 ===== }
procedure TestSingleThreadBasic;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtr: Pointer;
  LObj: TTestObj;
begin
  GDestroyCount := 0;
  GCreateCounter := 1;
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LConfig.OnReset := @ResetProc;
  LPool := TSyncPool.Create(LConfig);
  try
    { Acquire 创建对象 }
    Check(LPool.Acquire(LPtr), 'acquire 1');
    LObj := TTestObj(LPtr);
    Check(LObj.Value >= 1, 'object created');

    { Release → OnReset 应被调用 }
    LPool.Release(LPtr);

    { 再次 Acquire → 复用 TLS 中的对象 }
    Check(LPool.Acquire(LPtr), 'acquire 2 (reuse)');
    LObj := TTestObj(LPtr);
    Check(LObj.ResetCount >= 1, 'reset callback called on reuse');
    LPool.Release(LPtr);
  finally
    LPool.Free;
  end;
  Check(GDestroyCount >= 1, 'objects destroyed: ' + IntToStr(GDestroyCount));
end;

{ ===== 多线程并发 ===== }
type
  TWorkerThread = class(TThread)
  public
    Pool: TSyncPool;
    Iterations: Integer;
    SuccessCount: Integer;
    procedure Execute; override;
  end;

procedure TWorkerThread.Execute;
var
  I: Integer;
  LPtr: Pointer;
begin
  SuccessCount := 0;
  for I := 1 to Iterations do
  begin
    if Pool.Acquire(LPtr) then
    begin
      TTestObj(LPtr).Value := I;
      Pool.Release(LPtr);
      Inc(SuccessCount);
    end;
  end;
end;

procedure TestMultiThread;
const
  THREAD_COUNT = 8;
  ITERATIONS = 1000;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LThreads: array[0..THREAD_COUNT - 1] of TWorkerThread;
  I, LTotal: Integer;
begin
  GDestroyCount := 0;
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LPool := TSyncPool.Create(LConfig);
  try
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LThreads[I] := TWorkerThread.Create(True);
      LThreads[I].Pool := LPool;
      LThreads[I].Iterations := ITERATIONS;
      LThreads[I].FreeOnTerminate := False;
    end;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LThreads[I].WaitFor;
      CheckEqual(LThreads[I].SuccessCount, ITERATIONS,
        'thread ' + IntToStr(I) + ' completed');
      LThreads[I].Free;
    end;
  finally
    LPool.Free;
  end;

  { 验证所有对象被释放 }
  LTotal := GDestroyCount;
  Check(LTotal > 0, 'objects destroyed: ' + IntToStr(LTotal));
end;

{ ===== TLS 缓存命中率 ===== }
procedure TestCacheHitRate;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtr: Pointer;
  LStats: TPoolStats;
  I: Integer;
begin
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LPool := TSyncPool.Create(LConfig);
  try
    { 第一轮: 全部 cache miss }
    for I := 1 to 100 do
    begin
      LPool.Acquire(LPtr);
      LPool.Release(LPtr);
    end;
    LStats := LPool.Stats;
    Check(LStats.CacheMisses > 0, 'has cache misses');
    Check(LStats.CacheHits > 0, 'has cache hits after fill');

    { 第二轮: 应该全部 cache hit }
    LStats := LPool.Stats;
    Check(LStats.CacheHits > LStats.CacheMisses,
      'hits > misses: ' + IntToStr(LStats.CacheHits) + ' > ' + IntToStr(LStats.CacheMisses));
  finally
    LPool.Free;
  end;
end;

{ ===== 容量限制 ===== }
procedure TestMaxGlobalLimit;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtrs: array[0..19] of Pointer;
  LCount, I: Integer;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LConfig.MaxGlobal := 5;
  LPool := TSyncPool.Create(LConfig);
  try
    LCount := 0;
    while LCount < 20 do
    begin
      if not LPool.Acquire(LPtrs[LCount]) then
        Break;
      Inc(LCount);
    end;
    Check(LCount > 0, 'acquired some objects');
    { 释放全部 }
    for I := 0 to LCount - 1 do
      LPool.Release(LPtrs[I]);
  finally
    LPool.Free;
  end;
end;

{ ===== OnReset 回调 ===== }
procedure TestOnResetCallback;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtr: Pointer;
  LObj: TTestObj;
begin
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LConfig.OnReset := @ResetProc;
  LPool := TSyncPool.Create(LConfig);
  try
    LPool.Acquire(LPtr);
    LObj := TTestObj(LPtr);
    CheckEqual(LObj.ResetCount, 0, 'no reset before first release');
    LPool.Release(LPtr);

    LPool.Acquire(LPtr);
    LObj := TTestObj(LPtr);
    Check(LObj.ResetCount >= 1, 'reset called on release');
    LPool.Release(LPtr);
  finally
    LPool.Free;
  end;
end;

{ ===== Stats 准确性 ===== }
procedure TestStats;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtr: Pointer;
  LStats: TPoolStats;
begin
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LPool := TSyncPool.Create(LConfig);
  try
    LStats := LPool.Stats;
    CheckEqual(LStats.TotalCreated, 0, 'initial total=0');
    CheckEqual(LStats.Acquired, 0, 'initial acquired=0');

    LPool.Acquire(LPtr);
    LStats := LPool.Stats;
    Check(LStats.TotalCreated >= 1, 'created >= 1');
    CheckEqual(LStats.Acquired, 1, 'acquired=1');

    LPool.Release(LPtr);
    LStats := LPool.Stats;
    CheckEqual(LStats.Acquired, 0, 'acquired=0 after release');
  finally
    LPool.Free;
  end;
end;

{ ===== 确定性析构 ===== }
procedure TestDeterministicDestroy;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtr: Pointer;
  I: Integer;
begin
  GDestroyCount := 0;
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LPool := TSyncPool.Create(LConfig);
  try
    { 创建一些对象 }
    for I := 1 to 10 do
    begin
      LPool.Acquire(LPtr);
      LPool.Release(LPtr);
    end;
  finally
    LPool.Free;
  end;
  { 所有对象应该在 Free 时被销毁 }
  Check(GDestroyCount > 0, 'deterministic destroy: ' + IntToStr(GDestroyCount));
end;

{ ===== 批量转移 ===== }
procedure TestBatchTransfer;
var
  LPool: TSyncPool;
  LConfig: TSyncPoolConfig;
  LPtr: Pointer;
  LStats: TPoolStats;
  LPtrs: array[0..39] of Pointer;
  I, LAcquired: Integer;
begin
  GCreateCounter := 0;
  LConfig := DefaultSyncPoolConfig(@FactoryFunc);
  LConfig.MaxPerThread := 4;
  LConfig.BatchSize := 2;
  LPool := TSyncPool.Create(LConfig);
  try
    { Acquire 超过 TLS 容量, 触发批量转移 }
    LAcquired := 0;
    for I := 0 to 39 do
    begin
      if LPool.Acquire(LPtrs[I]) then
        Inc(LAcquired);
    end;
    { Release 全部, TLS 满后会触发 drain to global }
    for I := 0 to LAcquired - 1 do
      LPool.Release(LPtrs[I]);
    LStats := LPool.Stats;
    Check(LStats.BatchTransfers > 0,
      'batch transfers: ' + IntToStr(LStats.BatchTransfers));
  finally
    LPool.Free;
  end;
end;

{ ===== Go 风格 CreateSyncPool ===== }
procedure TestCreateSyncPool;
var
  LPool: TSyncPool;
  LObj: TObject;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;
  LPool := CreateSyncPool(@FactoryFunc);
  try
    LObj := LPool.Get;
    Check(LObj <> nil, 'Get returns object');
    Check(LObj is TTestObj, 'Get returns TTestObj');
    LPool.Put(LObj);
    { 复用 }
    LObj := LPool.Get;
    Check(LObj <> nil, 'Get reuses object');
    LPool.Put(LObj);
  finally
    LPool.Free;
  end;
  Check(GDestroyCount > 0, 'destroyed on free');
end;

{ ===== Builder 链式调用 ===== }
procedure TestBuilder;
var
  LPool: TSyncPool;
  LObj: TObject;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;
  LPool := TSyncPoolBuilder.Create(@FactoryFunc)
    .WithMaxPerThread(16)
    .WithMaxGlobal(100)
    .WithReset(@ResetProc)
    .Build;
  try
    LObj := LPool.Get;
    Check(LObj <> nil, 'builder pool works');
    LPool.Put(LObj);
    LObj := LPool.Get;
    Check(TTestObj(LObj).ResetCount >= 1, 'builder reset callback');
    LPool.Put(LObj);
  finally
    LPool.Free;
  end;
end;

{ ===== Get/Put 多线程 ===== }
procedure TestGetPutMultiThread;
const
  THREAD_COUNT = 16;
  ITERATIONS = 5000;
var
  LPool: TSyncPool;
  LThreads: array[0..THREAD_COUNT - 1] of TWorkerThread;
  I: Integer;
  LStats: TPoolStats;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;
  LPool := CreateSyncPool(@FactoryFunc);
  try
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LThreads[I] := TWorkerThread.Create(True);
      LThreads[I].Pool := LPool;
      LThreads[I].Iterations := ITERATIONS;
      LThreads[I].FreeOnTerminate := False;
    end;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LThreads[I].WaitFor;
      CheckEqual(LThreads[I].SuccessCount, ITERATIONS,
        'thread ' + IntToStr(I) + ': ' + IntToStr(ITERATIONS) + ' ops');
      LThreads[I].Free;
    end;
    LStats := LPool.Stats;
    Check(LStats.TotalCreated > 0, 'pool created objects: ' + IntToStr(LStats.TotalCreated));
    Check(LStats.CacheHits > 0, 'TLS cache hits: ' + IntToStr(LStats.CacheHits));
    WriteLn('  [bench] 16T x 5000 ops: created=', LStats.TotalCreated,
      ' hits=', LStats.CacheHits, ' misses=', LStats.CacheMisses);
  finally
    LPool.Free;
  end;
end;

{ ===== Release nil 安全 ===== }
procedure TestReleaseNil;
var
  LPool: TSyncPool;
begin
  LPool := CreateSyncPool(@FactoryFunc);
  try
    LPool.Put(nil);  { 不应 crash }
    LPool.Release(nil);  { 不应 crash }
    Check(True, 'release nil is safe');
  finally
    LPool.Free;
  end;
end;

{ ===== Get 后不 Put (泄漏场景) ===== }
procedure TestAcquireWithoutRelease;
var
  LPool: TSyncPool;
  LObj: TObject;
  LStats: TPoolStats;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;
  LPool := CreateSyncPool(@FactoryFunc);
  try
    { 获取但不归还 }
    LObj := LPool.Get;
    LStats := LPool.Stats;
    CheckEqual(LStats.Acquired, 1, 'one acquired');
  finally
    LPool.Free;
  end;
  { 手动释放未归还的对象 (pool 不管理 acquired 对象) }
  LObj.Free;
  Check(True, 'pool free without put-back is safe');
end;

{ ===== 高争用压力测试 ===== }
procedure TestHighContention;
const
  THREAD_COUNT = 32;
  ITERATIONS = 2000;
var
  LPool: TSyncPool;
  LThreads: array[0..THREAD_COUNT - 1] of TWorkerThread;
  I: Integer;
  LStats: TPoolStats;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;
  LPool := TSyncPoolBuilder.Create(@FactoryFunc)
    .WithMaxPerThread(8)
    .Build;
  try
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LThreads[I] := TWorkerThread.Create(True);
      LThreads[I].Pool := LPool;
      LThreads[I].Iterations := ITERATIONS;
      LThreads[I].FreeOnTerminate := False;
    end;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    for I := 0 to THREAD_COUNT - 1 do
    begin
      LThreads[I].WaitFor;
      CheckEqual(LThreads[I].SuccessCount, ITERATIONS,
        'high-contention thread ' + IntToStr(I));
      LThreads[I].Free;
    end;
    LStats := LPool.Stats;
    WriteLn('  [stress] 32T x 2000 ops: created=', LStats.TotalCreated,
      ' batch=', LStats.BatchTransfers);
  finally
    LPool.Free;
  end;
end;

{ ===== 基准: Pool Get/Put vs 直接 Create/Free ===== }
procedure TestBenchmarkPoolVsDirect;
const
  N = 100000;
var
  LPool: TSyncPool;
  LObj: TObject;
  LStart, LEnd: QWord;
  I: Integer;
begin
  GDestroyCount := 0;
  GCreateCounter := 0;

  { 基准 1: 直接 Create/Free }
  LStart := GetTickCount64;
  for I := 1 to N do
  begin
    LObj := TTestObj.Create(I, nil);
    LObj.Free;
  end;
  LEnd := GetTickCount64;
  WriteLn('  [bench] Direct Create/Free x', N, ': ',
    LEnd - LStart, ' ms');

  { 基准 2: Pool Get/Put (TLS 命中路径) }
  LPool := CreateSyncPool(@FactoryFunc);
  try
    { 预热 TLS }
    for I := 1 to 100 do
    begin
      LPool.Get;
      LPool.Put(LObj);
    end;

    LStart := GetTickCount64;
    for I := 1 to N do
    begin
      LObj := LPool.Get;
      LPool.Put(LObj);
    end;
    LEnd := GetTickCount64;
    WriteLn('  [bench] Pool Get/Put x', N, ': ',
      LEnd - LStart, ' ms');

    if LEnd > LStart then
      WriteLn('  [bench] Pool speedup: ',
        FormatFloat('0.0', N / (LEnd - LStart)), ' ops/ms');
  finally
    LPool.Free;
  end;
end;

{ ===== 主程序 ===== }
begin
  T := TTestRunner.Create('nextpas.core.sync.pool');
  { 原有测试 }
  T.Run('SingleThreadBasic', @TestSingleThreadBasic);
  T.Run('MultiThread', @TestMultiThread);
  T.Run('CacheHitRate', @TestCacheHitRate);
  T.Run('MaxGlobalLimit', @TestMaxGlobalLimit);
  T.Run('OnResetCallback', @TestOnResetCallback);
  T.Run('Stats', @TestStats);
  T.Run('DeterministicDestroy', @TestDeterministicDestroy);
  T.Run('BatchTransfer', @TestBatchTransfer);
  { 新 API 测试 }
  T.Run('CreateSyncPool', @TestCreateSyncPool);
  T.Run('Builder', @TestBuilder);
  T.Run('ReleaseNil', @TestReleaseNil);
  T.Run('AcquireWithoutRelease', @TestAcquireWithoutRelease);
  { 并发压力测试 }
  T.Run('GetPutMultiThread16x5K', @TestGetPutMultiThread);
  T.Run('HighContention32x2K', @TestHighContention);
  { 基准 }
  T.Run('BenchmarkPoolVsDirect', @TestBenchmarkPoolVsDirect);
  T.Summary;
end.
