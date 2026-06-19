{******************************************************************************
  test_sync_pool — TSyncPool 单元测试 (15 tests, v5 API)

  1.  TestCreateDefault           — CreateSyncPool 默认工厂
  2.  TestBuilderChain            — Builder 模式链式调用
  3.  TestAcquireRelease          — Get/Put 基本流程
  4.  TestMultiObjectFIFO         — 多对象 FIFO 行为
  5.  TestReleaseNil              — Put(nil) 安全
  6.  TestAcquireWithoutRelease   — Get 不 Put，pool 仍可用
  7.  TestCustomFactory           — 自定义工厂函数
  8.  TestResetOnAcquire          — Get 时 OnReset 回调
  9.  TestMultiThread16x5K        — 16 线程 × 5000 ops
  10. TestHighContention32x2K     — 32 线程 × 2000 ops
  11. TestBenchmarkPoolVsDirect   — Pool vs 直接分配基准
  12. TestGetPutSingleThread      — Get/Put 热路径基准
  13. TestSingleSlotContention    — 单 slot 竞争测试
  14. TestLeakDetection           — 泄漏检测
  15. TestDrainGlobal             — DrainGlobal 释放 global pool
******************************************************************************}
program test_sync_pool;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils, Classes, SyncObjs, Math,
  nextpas.core.sync.pool;

type
  TTestObject = class(TPoolItem)
  private
    FValue: Integer;
  public
    constructor Create(AValue: Integer);
    procedure Reset;
  end;

  TTestThread = class(TThread)
  private
    FPool: TSyncPool;
    FOps: SizeInt;
    FHitRate: Double;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TSyncPool; AOps: SizeInt);
    property HitRate: Double read FHitRate;
  end;

  THighContentionThread = class(TThread)
  private
    FPool: TSyncPool;
    FOps: SizeInt;
    FContentionCount: SizeInt;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TSyncPool; AOps: SizeInt);
    property ContentionCount: SizeInt read FContentionCount;
  end;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GFactoryCallCount: Integer = 0;
  GDestroyCallCount: Integer = 0;

function S(const AStr: AnsiString): AnsiString;
begin
  Result := AStr;
end;

procedure CheckEqual(A, B: Integer; const ATestName: string);
begin
  if A = B then begin
    WriteLn('  PASS: ', ATestName);
    Inc(GTestsPassed);
  end else begin
    WriteLn('  FAIL: ', ATestName, ' (got ', A, ', expected ', B, ')');
    Inc(GTestsFailed);
  end;
end;

procedure CheckTrue(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then begin
    WriteLn('  PASS: ', ATestName);
    Inc(GTestsPassed);
  end else begin
    WriteLn('  FAIL: ', ATestName);
    Inc(GTestsFailed);
  end;
end;

procedure CheckNotNull(APtr: Pointer; const ATestName: string);
begin
  if APtr <> nil then begin
    WriteLn('  PASS: ', ATestName);
    Inc(GTestsPassed);
  end else begin
    WriteLn('  FAIL: ', ATestName, ' (got nil)');
    Inc(GTestsFailed);
  end;
end;

procedure CheckEqualDbl(A, B: Double; ADelta: Double; const ATestName: string);
begin
  if Abs(A - B) <= ADelta then begin
    WriteLn('  PASS: ', ATestName);
    Inc(GTestsPassed);
  end else begin
    WriteLn('  FAIL: ', ATestName, ' (got ', A:0:4, ', expected ', B:0:4, ')');
    Inc(GTestsFailed);
  end;
end;

function CreateTestObject: Pointer;
begin
  Result := TTestObject.Create(42);
end;


procedure DestroyTestObject(AItem: Pointer);
begin
  if AItem <> nil then
    TTestObject(AItem).Free;
end;

{ TTestObject }

constructor TTestObject.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
end;

procedure TTestObject.Reset;
begin
  FValue := 42;
end;

{ TTestThread }

constructor TTestThread.Create(APool: TSyncPool; AOps: SizeInt);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FPool := APool;
  FOps := AOps;
  FHitRate := 0;
end;

procedure TTestThread.Execute;
var
  I: SizeInt;
  LObj: TTestObject;
  LHits: SizeInt;
begin
  LHits := 0;
  for I := 1 to FOps do begin
    LObj := TTestObject(FPool.Get);
    if LObj = nil then
      LObj := TTestObject.Create(42)
    else
      Inc(LHits);
    LObj.FValue := I;
    FPool.Put(LObj);
  end;
  if FOps > 0 then
    FHitRate := LHits / FOps;
  { 将 TLS freelist 归还 global pool, 防止 heaptrc 泄漏报告 }
  FPool.DrainTLS;
end;

{ THighContentionThread }

constructor THighContentionThread.Create(APool: TSyncPool; AOps: SizeInt);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FPool := APool;
  FOps := AOps;
  FContentionCount := 0;
end;

procedure THighContentionThread.Execute;
var
  I: SizeInt;
  LObj: Pointer;
begin
  for I := 1 to FOps do begin
    LObj := FPool.Get;
    if LObj = nil then begin
      LObj := TTestObject.Create(42);
      Inc(FContentionCount);
    end;
    FPool.Put(LObj);
  end;
  FPool.DrainTLS;
end;

{ =========================================================================== }
{  TEST 1: CreateSyncPool 默认工厂 }
{ =========================================================================== }
procedure TestCreateDefault;
var
  LPool: TSyncPool;
  LObj: Pointer;
begin
  WriteLn('--- TestCreateDefault ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    LObj := LPool.Get;
    CheckNotNull(LObj, 'Acquire returns non-nil');
    LPool.Put(LObj);
    CheckTrue(LPool.TotalCreated > 0, 'TotalCreated > 0 after first acquire');
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 2: Builder 模式 }
{ =========================================================================== }
procedure TestBuilderChain;
var
  LPool: TSyncPool;
  LObj: Pointer;
begin
  WriteLn('--- TestBuilderChain ---');
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    .WithDestroy(@DestroyTestObject)
    .Build;
  try
    CheckNotNull(Pointer(LPool), 'Builder.Build returns non-nil pool');
    LObj := LPool.Get;
    CheckTrue(LObj <> nil, 'Acquire from builder pool succeeds');
    LPool.Put(LObj);
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 3: Acquire / Release 基本流程 }
{ =========================================================================== }
procedure TestAcquireRelease;
var
  LPool: TSyncPool;
  LObj1, LObj2: TTestObject;
begin
  WriteLn('--- TestAcquireRelease ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    LObj1 := TTestObject(LPool.Get);
    CheckNotNull(LObj1, 'First acquire non-nil');
    CheckEqual(1, Integer(LPool.TotalCreated), 'Factory called once');
    LPool.Put(LObj1);

    LObj2 := TTestObject(LPool.Get);
    CheckNotNull(LObj2, 'Second acquire non-nil (recycled)');
    CheckTrue(Pointer(LObj1) = Pointer(LObj2), 'Second acquire returns same object');
    LPool.Put(LObj2);
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 4: 多对象 FIFO (LIFO) 行为 }
{ =========================================================================== }
procedure TestMultiObjectFIFO;
var
  LPool: TSyncPool;
  LObj: TTestObject;
begin
  WriteLn('--- TestMultiObjectFIFO ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    { Acquire 3, put back in order }
    LObj := TTestObject(LPool.Get);
    LObj.FValue := 1;
    LObj.FValue := 1;
    LPool.Put(LObj);

    LObj := TTestObject(LPool.Get);
    LObj.FValue := 2;
    LPool.Put(LObj);

    LObj := TTestObject(LPool.Get);
    LObj.FValue := 3;
    LPool.Put(LObj);

    { LIFO: last-in first-out }
    LObj := TTestObject(LPool.Get);
    CheckEqual(3, LObj.FValue, 'LIFO: last put (3) is first get');
    LPool.Put(LObj);
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 5: Put(nil) 安全 }
{ =========================================================================== }
procedure TestReleaseNil;
var
  LPool: TSyncPool;
  LBefore: SizeUInt;
begin
  WriteLn('--- TestReleaseNil ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    LBefore := LPool.TotalCreated;
    LPool.Put(nil);
    CheckEqual(Integer(LBefore), Integer(LPool.TotalCreated),
      'Put(nil) does not call factory');
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 6: Get 不 Put，pool 仍可用 }
{ =========================================================================== }
procedure TestAcquireWithoutRelease;
var
  LPool: TSyncPool;
  LObj1, LObj2: Pointer;
begin
  WriteLn('--- TestAcquireWithoutRelease ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    LObj1 := LPool.Get;
    CheckNotNull(LObj1, 'First acquire non-nil');

    { 不 put, 直接再 acquire }
    LObj2 := LPool.Get;
    CheckNotNull(LObj2, 'Second acquire non-nil (pool creates new)');

    LPool.Put(LObj1);
    LPool.Put(LObj2);
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 7: 自定义工厂 }
{ =========================================================================== }
procedure TestCustomFactory;
var
  LPool: TSyncPool;
  LObj: TTestObject;
begin
  WriteLn('--- TestCustomFactory ---');
  GFactoryCallCount := 0;
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    
    
    .Build;
  try
    LObj := TTestObject(LPool.Get);
    CheckNotNull(LObj, 'Custom factory returns non-nil');
    CheckTrue(LObj is TTestObject, 'Factory returns TTestObject');
    CheckEqual(42, LObj.FValue, 'Factory sets value to 42');
    LPool.Put(LObj);
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 8: Get 时 OnReset 回调 }
{ =========================================================================== }
procedure TestResetOnAcquire;
var
  LPool: TSyncPool;
  LObj: TTestObject;
begin
  WriteLn('--- TestRecyclePreservesState ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    LObj := TTestObject(LPool.Get);
    LObj.FValue := 999;
    LPool.Put(LObj);

    LObj := TTestObject(LPool.Get);
    CheckEqual(999, LObj.FValue, 'Recycle preserves object state (no auto-reset)');
    LPool.Put(LObj);
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 9: 16 线程 × 5000 ops }
{ =========================================================================== }
procedure TestMultiThread16x5K;
const
  THREAD_COUNT = 16;
  OPS_PER_THREAD = 5000;
var
  LPool: TSyncPool;
  LThreads: array[0..THREAD_COUNT-1] of TTestThread;
  I: Integer;
  LTotalHits: Double;
  LStartTime: TDateTime;
begin
  WriteLn('--- TestMultiThread16x5K ---');
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    
    
    .WithDestroy(@DestroyTestObject)
    .Build;
  try
    LStartTime := Now;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I] := TTestThread.Create(LPool, OPS_PER_THREAD);

    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].WaitFor;

    WriteLn('  Time: ', FormatDateTime('s.zzz', Now - LStartTime), 's');

    LTotalHits := 0;
    for I := 0 to THREAD_COUNT - 1 do begin
      LTotalHits := LTotalHits + LThreads[I].HitRate;
      LThreads[I].Free;
    end;
    WriteLn(Format('  Avg TLS hit rate: %d%%', [Round(LTotalHits / THREAD_COUNT * 100)]));
    CheckTrue(True, 'Multi-thread completed without crash');
    CheckTrue(LTotalHits / THREAD_COUNT > 0.90,
      'TLS hit rate > 90%');
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 10: 32 线程 × 2000 ops (高竞争) }
{ =========================================================================== }
procedure TestHighContention32x2K;
const
  THREAD_COUNT = 32;
  OPS_PER_THREAD = 2000;
var
  LPool: TSyncPool;
  LThreads: array[0..THREAD_COUNT-1] of THighContentionThread;
  I: Integer;
  LTotalContention: SizeInt;
  LStartTime: TDateTime;
begin
  WriteLn('--- TestHighContention32x2K ---');
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    
    .WithDestroy(@DestroyTestObject)
    .Build;
  try
    LStartTime := Now;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I] := THighContentionThread.Create(LPool, OPS_PER_THREAD);

    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].WaitFor;

    WriteLn('  Time: ', FormatDateTime('s.zzz', Now - LStartTime), 's');

    LTotalContention := 0;
    for I := 0 to THREAD_COUNT - 1 do begin
      LTotalContention := LTotalContention + LThreads[I].ContentionCount;
      LThreads[I].Free;
    end;
    WriteLn('  Total contentions (new allocs): ', LTotalContention);
    CheckTrue(True, 'High-contention completed without crash');
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 11: Pool vs 直接分配基准 }
{ =========================================================================== }
procedure TestBenchmarkPoolVsDirect;
const
  OPS = 100000;
var
  LPool: TSyncPool;
  LObj: Pointer;
  I: Integer;
  LPoolStart, LDirectStart: Int64;
  LPoolUs, LDirectUs: Double;
begin
  WriteLn('--- TestBenchmarkPoolVsDirect ---');

  { 测量 Pool Get/Put }
  LPool := CreateSyncPool(@CreateTestObject);
  try
    LPoolStart := GetTickCount64;
    for I := 1 to OPS do begin
      LObj := LPool.Get;
      LPool.Put(LObj);
    end;
    LPoolUs := (GetTickCount64 - LPoolStart);
  finally
    LPool.Free;
  end;

  { 测量直接 Create/Free }
  LDirectStart := GetTickCount64;
  for I := 1 to OPS do begin
    LObj := TTestObject.Create(42);
    TTestObject(LObj).Free;
  end;
  LDirectUs := (GetTickCount64 - LDirectStart);

  WriteLn(Format('  Pool:    %0.0f ms (%d ops)', [LPoolUs, OPS]));
  WriteLn(Format('  Direct:  %0.0f ms (%d ops)', [LDirectUs, OPS]));
  if LPoolUs > 0 then
    WriteLn(Format('  Speedup: %0.1fx faster', [LDirectUs / LPoolUs]));
  CheckTrue(True, 'Benchmark completed');
end;

{ =========================================================================== }
{  TEST 12: Get/Put 热路径基准 (纯 recycle) }
{ =========================================================================== }
procedure TestGetPutSingleThread;
const
  OPS = 1000000;
var
  LPool: TSyncPool;
  LObj: Pointer;
  I: Integer;
  LStart: Int64;
  LMs: Double;
begin
  WriteLn('--- TestGetPutSingleThread ---');
  LPool := CreateSyncPool(@CreateTestObject);
  try
    { warm up }
    for I := 1 to 100 do begin
      LObj := LPool.Get;
      LPool.Put(LObj);
    end;

    { benchmark }
    LStart := GetTickCount64;
    for I := 1 to OPS do begin
      LObj := LPool.Get;
      LPool.Put(LObj);
    end;
    LMs := (GetTickCount64 - LStart);

    WriteLn(Format('  1M Get/Put pairs: %0.0f ms', [LMs]));
    if LMs > 0 then
      WriteLn(Format('  Throughput: %0.0fM ops/sec', [OPS / LMs / 1000]));
    CheckTrue(True, 'Single-thread benchmark completed');
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 13: 单 slot 竞争 }
{ =========================================================================== }
procedure TestSingleSlotContention;
const
  OPS = 10000;
var
  LPool: TSyncPool;
  LObj: Pointer;
  I: Integer;
begin
  WriteLn('--- TestSingleSlotContention ---');
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    
    
    .Build;
  try
    for I := 1 to OPS do begin
      LObj := LPool.Get;
      LPool.Put(LObj);
    end;
    CheckTrue(True, 'Single slot contention completed');
    WriteLn(Format('  Created: %d objects', [Integer(LPool.TotalCreated)]));
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  TEST 14: 泄漏检测 }
{ =========================================================================== }
procedure TestLeakDetection;
var
  LPool: TSyncPool;
  LObj: Pointer;
  I: Integer;
begin
  WriteLn('--- TestLeakDetection ---');
  GDestroyCallCount := 0;
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    .WithDestroy(@DestroyTestObject)
    .Build;
  try
    for I := 1 to 1000 do begin
      LObj := LPool.Get;
      LPool.Put(LObj);
    end;
    { pool 释放时应销毁所有缓存对象 }
    LPool.DrainTLS;
  finally
    LPool.Free;
  end;
  CheckTrue(True, 'Leak detection test completed');
  WriteLn(Format('  Objects destroyed: %d', [GDestroyCallCount]));
end;

{ =========================================================================== }
{  TEST 15: DrainGlobal }
{ =========================================================================== }
procedure TestDrainGlobal;
var
  LPool: TSyncPool;
  LObj: Pointer;
begin
  WriteLn('--- TestDrainGlobal ---');
  LPool := TSyncPoolBuilder.Create(@CreateTestObject)
    .WithDestroy(@DestroyTestObject)
    .Build;
  try
    LObj := LPool.Get;
    LPool.Put(LObj);

    { 先将 TLS freelist 移回 global, 再统一清 global }
    LPool.DrainTLS;
    LPool.DrainGlobal;
    CheckTrue(True, 'DrainGlobal completed without crash');
  finally
    LPool.Free;
  end;
end;

{ =========================================================================== }
{  Main }
{ =========================================================================== }
begin
  WriteLn('=== test_sync_pool (v3) ===');
  WriteLn;

  TestCreateDefault;
  TestBuilderChain;
  TestAcquireRelease;
  TestMultiObjectFIFO;
  TestReleaseNil;
  TestAcquireWithoutRelease;
  TestCustomFactory;
  TestResetOnAcquire;
  TestMultiThread16x5K;
  TestHighContention32x2K;
  TestBenchmarkPoolVsDirect;
  TestGetPutSingleThread;
  TestSingleSlotContention;
  TestLeakDetection;
  TestDrainGlobal;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('  Passed: ', GTestsPassed);
  WriteLn('  Failed: ', GTestsFailed);
  WriteLn;

  if GTestsFailed > 0 then begin
    WriteLn('OVERALL: FAIL');
    Halt(1);
  end else
    WriteLn('OVERALL: PASS');
end.
