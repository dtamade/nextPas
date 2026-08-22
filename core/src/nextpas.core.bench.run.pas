{**
 * @desc 线程安全基准执行器
 *
 * TBenchRun 是 TBenchRunner 的线程安全替代品。
 * 使用原子计数器实现无锁结果收集，支持多线程并发提交结果。
 *
 * 设计要点:
 * - TBenchRunResult 通过 GetMem 分配在堆上，避免 managed type 原子操作问题
 * - FResultIdx 原子递增实现无锁槽位分配
 * - Join 后主线程安全读取所有结果指针
 * - 未来可扩展: TEbrDomain 管理结果缓冲区生命周期
 *
 * @see TBenchRunner (非线程安全，单线程场景)
 * @see nextpas.core.lockfree.ebr (QSBR 内存回收)
 *}
unit nextpas.core.bench.run;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.atomic,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.runner,
  nextpas.core.errors,
  nextpas.core.platform.thread;

const
  {** TBenchRun 默认最大并发结果数 }
  BENCH_RUN_DEFAULT_CAPACITY = 1024;

type
  {** 堆分配的基准结果指针 }
  PBenchRunResult = ^TBenchResult;

  {** 工作线程参数 }
  PBenchRunWorkerArgs = ^TBenchRunWorkerArgs;
  TBenchRunWorkerArgs = record
    Runner: TBenchRunner;
    Entry: TBenchEntry;
    Results: Pointer;    { 指向 TBenchRun.FResults (PPBenchRunResult) }
    ResultIdx: PInt32;   { 指向 TBenchRun.FResultIdx }
  end;

  {** 线程安全基准执行器
   *
   *  替代 TBenchRunner 的线程安全版本。
   *  多个工作线程可并发调用 SubmitResult，通过原子计数器无锁分配槽位。
   *
   *  用法:
   *  @precode
   *  var LRun: TBenchRun;
   *  LRun := TBenchRun.Create;
   *  try
   *    LResults := LRun.RunAll([Entry1, Entry2, Entry3], 4);
   *  finally
   *    LRun.Free;
   *  end;
   *  @endcode
   *}
  TBenchRun = class
  private
    FResults: Pointer;  { 实际类型: array of PBenchRunResult }
    FCapacity: Int32;
    FResultIdx: Int32;
    FConfig: TBenchConfig;

    procedure FreeResults;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TBenchConfig); overload;
    destructor Destroy; override;

    {** 无锁提交一个结果到结果数组
     *  @param AResult 堆分配的结果指针（所有权转移给 TBenchRun）
     *  @raises EBenchInvalidParam 结果数组已满 }
    procedure SubmitResult(AResult: PBenchRunResult);

    {** 收集所有已提交的结果
     *  @param out AResults 结果数组副本
     *  @return 已提交的结果数量 }
    function CollectResults(out AResults: TBenchResultArray): Integer;

    {** 使用 N 个工作线程并发运行所有基准
     *  @param AEntries 基准条目数组
     *  @param AThreadCount 工作线程数，0=BENCH_DEFAULT_PARALLEL_THREADS
     *  @return 所有结果 }
    function RunAll(const AEntries: array of TBenchEntry;
      AThreadCount: Integer = 0): TBenchResultArray;

    {** 当前已提交的结果数 }
    function Count: Integer;

    {** 配置访问 }
    property Config: TBenchConfig read FConfig write FConfig;
  end;

{** 在堆上分配 TBenchResult 副本（调用方负责 FreeMem） }
function AllocBenchResult(const AResult: TBenchResult): PBenchRunResult;

{** 释放堆分配的 TBenchResult }
procedure FreeBenchResult(APtr: PBenchRunResult);

implementation

type
  { FPC 不允许同类型块中 ^Type 前向引用，此处定义数组类型用于指针算术 }
  TBenchRunResultSlotArray = array[0..BENCH_RUN_DEFAULT_CAPACITY - 1] of PBenchRunResult;
  PBenchRunResultSlotArray = ^TBenchRunResultSlotArray;

{ --------------------------------------------------------------------- }
{  Helpers }
{ --------------------------------------------------------------------- }

function AllocBenchResult(const AResult: TBenchResult): PBenchRunResult;
begin
  Result := PBenchRunResult(GetMem(SizeOf(TBenchResult)));
  { TBenchResult 包含 managed types (string, TDoubleArray, TCustomMetricArray)。
    FillChar + Initialize 确保引用计数正确，然后赋值拷贝。 }
  FillChar(Result^, SizeOf(TBenchResult), 0);
  Initialize(Result^);
  Result^ := AResult;
end;

procedure FreeBenchResult(APtr: PBenchRunResult);
begin
  if APtr <> nil then
  begin
    { Finalize 释放 managed types (string 引用计数, 动态数组引用计数) }
    Finalize(APtr^);
    FreeMem(APtr);
  end;
end;

{ --------------------------------------------------------------------- }
{  Worker Thread Proc }
{ --------------------------------------------------------------------- }

function BenchRunWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LArgs: PBenchRunWorkerArgs;
  LResult: TBenchResult;
  LPtr: PBenchRunResult;
  LIdx: Int32;
begin
  Result := nil;
  LArgs := PBenchRunWorkerArgs(AArg);
  LResult := LArgs^.Runner.RunOne(LArgs^.Entry);
  LPtr := AllocBenchResult(LResult);
  { 无锁提交: 原子递增获取槽位，写入指针 }
  LIdx := atomic_fetch_add(LArgs^.ResultIdx^, 1, mo_acq_rel);
  PBenchRunResultSlotArray(LArgs^.Results^)^[LIdx] := LPtr;
end;

{ --------------------------------------------------------------------- }
{  TBenchRun }
{ --------------------------------------------------------------------- }

constructor TBenchRun.Create;
begin
  Create(DefaultBenchConfig);
end;

constructor TBenchRun.Create(const AConfig: TBenchConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FCapacity := BENCH_RUN_DEFAULT_CAPACITY;
  FResultIdx := 0;
  FResults := GetMem(FCapacity * SizeOf(PBenchRunResult));
  FillChar(FResults^, FCapacity * SizeOf(PBenchRunResult), 0);
end;

destructor TBenchRun.Destroy;
begin
  FreeResults;
  if FResults <> nil then
    FreeMem(FResults);
  inherited;
end;

procedure TBenchRun.FreeResults;
var
  I: Integer;
begin
  if FResults = nil then
    Exit;
  for I := 0 to atomic_load(FResultIdx, mo_relaxed) - 1 do
    FreeBenchResult(PBenchRunResultSlotArray(FResults)^[I]);
end;

procedure TBenchRun.SubmitResult(AResult: PBenchRunResult);
var
  LIdx, LExpected: Int32;
begin
  { CAS 循环：只在容量内递增，避免溢出后 FResultIdx 越界 }
  LExpected := atomic_load(FResultIdx, mo_relaxed);
  while True do
  begin
    if LExpected >= FCapacity then
    begin
      FreeBenchResult(AResult);
      raise EBenchInvalidParam.Create('TBenchRun: result capacity exceeded');
    end;
    LIdx := LExpected;
    if atomic_compare_exchange_strong(FResultIdx, LExpected, LExpected + 1, mo_acq_rel, mo_relaxed) then
      Break;
    { LExpected updated to observed value on failure }
  end;
  PBenchRunResultSlotArray(FResults)^[LIdx] := AResult;
end;

function TBenchRun.CollectResults(out AResults: TBenchResultArray): Integer;
var
  I: Integer;
begin
  Result := atomic_load(FResultIdx, mo_acquire);
  SetLength(AResults, Result);
  for I := 0 to Result - 1 do
    AResults[I] := PBenchRunResultSlotArray(FResults)^[I]^;
end;

function TBenchRun.Count: Integer;
begin
  Result := atomic_load(FResultIdx, mo_relaxed);
end;

function TBenchRun.RunAll(const AEntries: array of TBenchEntry;
  AThreadCount: Integer): TBenchResultArray;
var
  LEntryCount, I: Integer;
  LWorkers: array of TBenchRunWorkerArgs;
  LHandles: array of TPlatformThreadHandle;
  LRunners: array of TBenchRunner;
  LRunnerConfig: TBenchConfig;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
begin
  LEntryCount := Length(AEntries);
  if LEntryCount = 0 then
  begin
    Result := nil;
    SetLength(Result, 0);
    Exit;
  end;

  if AThreadCount <= 0 then
    AThreadCount := BENCH_DEFAULT_PARALLEL_THREADS;
  if AThreadCount > LEntryCount then
    AThreadCount := LEntryCount;
  if AThreadCount < 1 then
    AThreadCount := 1;

  { 确保结果数组容量足够 }
  if LEntryCount > FCapacity then
  begin
    FreeResults;
    FreeMem(FResults);
    FCapacity := LEntryCount;
    FResults := GetMem(FCapacity * SizeOf(PBenchRunResult));
  end
  else
    FreeResults;  { 重用时释放已有结果，防止内存泄漏 }
  FResultIdx := 0;
  FillChar(FResults^, FCapacity * SizeOf(PBenchRunResult), 0);

  SetLength(LWorkers, LEntryCount);
  SetLength(LHandles, LEntryCount);
  SetLength(LRunners, LEntryCount);

  { 工作线程禁用内存追踪和静默模式 }
  LRunnerConfig := FConfig;
  LRunnerConfig.EnableMemoryTracking := False;
  LRunnerConfig.Quiet := True;

  for I := 0 to LEntryCount - 1 do
  begin
    LRunners[I] := TBenchRunner.CreateNoEnv;
    LRunners[I].SetConfig(LRunnerConfig);
    LWorkers[I].Runner := LRunners[I];
    LWorkers[I].Entry := AEntries[I];
    LWorkers[I].Results := @FResults;
    LWorkers[I].ResultIdx := @FResultIdx;
    LHandles[I] := nil;
  end;

  { 创建工作线程 }
  for I := 0 to LEntryCount - 1 do
  begin
    if platform_thread_create(LHandle, @BenchRunWorkerProc, @LWorkers[I]) = 0 then
      LHandles[I] := LHandle;
  end;

  { 等待所有线程完成 }
  for I := 0 to LEntryCount - 1 do
  begin
    if LHandles[I] <> nil then
      platform_thread_join(LHandles[I], LRet);
  end;

  { 释放独立的 runner 实例 }
  for I := 0 to LEntryCount - 1 do
    LRunners[I].Free;

  { 收集结果 }
  CollectResults(Result);
end;

end.
