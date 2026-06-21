{**
 * @desc 并行基准执行器
 *
 * 提供并行执行基准测试的功能，
 * 用于测量多线程性能和扩展性。
 *}
unit nextpas.core.bench.parallel;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  nextpas.core.bench.base;

type
  {**
   * 并行基准函数类型
   *}
  TBenchParallelFunc = procedure(AThreadId: Integer; AIterations: Int64);

  {**
   * 并行基准配置
   *}
  TParallelBenchConfig = record
    ThreadCount: Integer;      // 线程数
    IterationsPerThread: Int64; // 每个线程的迭代次数
    WarmupIterations: Int64;   // 预热迭代次数
  end;

  {**
   * 并行基准结果
   *}
  TParallelBenchResult = record
    Config: TParallelBenchConfig;
    TotalNs: UInt64;           // 总耗时（纳秒）
    NsPerOp: Double;           // 每次操作耗时
    OpsPerSec: Double;         // 每秒操作数
    Speedup: Double;           // 加速比
    Efficiency: Double;        // 并行效率
    ThreadResults: array of record
      ThreadId: Integer;
      Iterations: Int64;
      ElapsedNs: UInt64;
      NsPerOp: Double;
    end;
  end;

  {**
   * 并行基准执行器
   *}
  TParallelBenchmark = record
  private
    FConfig: TParallelBenchConfig;
    FFunc: TBenchParallelFunc;
    FResults: TParallelBenchResult;
    procedure RunThread(AThreadId: Integer);
  public
    {**
     * 创建并行基准执行器
     *}
    class function Create(AFunc: TBenchParallelFunc;
                         AThreadCount: Integer = 4;
                         AIterationsPerThread: Int64 = 1000000;
                         AWarmupIterations: Int64 = 1000): TParallelBenchmark; static;

    {**
     * 执行并行基准测试
     *}
    function Execute: TParallelBenchResult;

    {**
     * 获取结果
     *}
    function GetResults: TParallelBenchResult;
  end;

  {**
   * 执行并行基准测试
   *}
  function RunParallelBench(AFunc: TBenchParallelFunc;
                           AThreadCount: Integer = 4;
                           AIterationsPerThread: Int64 = 1000000): TParallelBenchResult;

implementation

uses
  nextpas.core.platform.time;



type
  {**
   * 基准线程
   *}
  TBenchThread = class(TThread)
  private
    FBenchThreadId: Integer;
    FFunc: TBenchParallelFunc;
    FIterations: Int64;
    FElapsedNs: UInt64;
    FStartNs: UInt64;
    FEndNs: UInt64;
  protected
    procedure Execute; override;
  public
    constructor Create(AThreadId: Integer; AFunc: TBenchParallelFunc;
                      AIterations: Int64);
    property BenchThreadId: Integer read FBenchThreadId;
    property Iterations: Int64 read FIterations;
    property ElapsedNs: UInt64 read FElapsedNs;
  end;

{ TBenchThread }

constructor TBenchThread.Create(AThreadId: Integer; AFunc: TBenchParallelFunc;
                                AIterations: Int64);
begin
  inherited Create(True); // Create suspended
  FreeOnTerminate := False;
  FBenchThreadId := AThreadId;
  FFunc := AFunc;
  FIterations := AIterations;
  FElapsedNs := 0;
end;

procedure TBenchThread.Execute;
var
  LStartNs: UInt64;
  LEndNs: UInt64;
begin
  // Record start time using high-precision timer
  LStartNs := platform_monotonic_ns;

  // Execute the benchmark function
  FFunc(FBenchThreadId, FIterations);

  // Record end time
  LEndNs := platform_monotonic_ns;

  // Calculate elapsed time in nanoseconds
  FElapsedNs := LEndNs - LStartNs;
end;

{ TParallelBenchmark }

class function TParallelBenchmark.Create(AFunc: TBenchParallelFunc;
                                         AThreadCount: Integer;
                                         AIterationsPerThread: Int64;
                                         AWarmupIterations: Int64): TParallelBenchmark;
begin
  Result.FConfig.ThreadCount := AThreadCount;
  Result.FConfig.IterationsPerThread := AIterationsPerThread;
  Result.FConfig.WarmupIterations := AWarmupIterations;
  Result.FFunc := AFunc;
  Result.FResults := Default(TParallelBenchResult);
end;

function TParallelBenchmark.CreateThreads: TBenchThreadArray;
var
  I: Integer;
begin
  SetLength(Result, FConfig.ThreadCount);
  for I := 0 to FConfig.ThreadCount - 1 do
    Result[I] := TBenchThread.Create(I, FFunc, FConfig.IterationsPerThread);
end;

procedure TParallelBenchmark.RunThread(AThreadId: Integer);
begin
  // This is handled by TBenchThread.Execute
end;

function TParallelBenchmark.Execute: TParallelBenchResult;
var
  LThreads: array of TBenchThread;
  I: Integer;
  LStartNs: UInt64;
  LEndNs: UInt64;
  LTotalIterations: Int64;
  LSequentialNs: Double;
begin
  // Warmup
  if FConfig.WarmupIterations > 0 then
  begin
    for I := 0 to FConfig.ThreadCount - 1 do
      FFunc(I, FConfig.WarmupIterations);
  end;

  // Create threads
  SetLength(LThreads, FConfig.ThreadCount);
  for I := 0 to FConfig.ThreadCount - 1 do
    LThreads[I] := TBenchThread.Create(I, FFunc, FConfig.IterationsPerThread);

  // Record start time using high-precision timer
  LStartNs := platform_monotonic_ns;

  // Start all threads
  for I := 0 to High(LThreads) do
    LThreads[I].Start;

  // Wait for all threads to complete
  for I := 0 to High(LThreads) do
    LThreads[I].WaitFor;

  // Record end time
  LEndNs := platform_monotonic_ns;

  // Collect results
  LTotalIterations := 0;
  SetLength(FResults.ThreadResults, Length(LThreads));

  for I := 0 to High(LThreads) do
  begin
    FResults.ThreadResults[I].ThreadId := LThreads[I].BenchThreadId;
    FResults.ThreadResults[I].Iterations := LThreads[I].Iterations;
    FResults.ThreadResults[I].ElapsedNs := LThreads[I].ElapsedNs;
    if LThreads[I].Iterations > 0 then
      FResults.ThreadResults[I].NsPerOp := LThreads[I].ElapsedNs / LThreads[I].Iterations
    else
      FResults.ThreadResults[I].NsPerOp := 0;
    Inc(LTotalIterations, LThreads[I].Iterations);
  end;

  // Calculate total results
  FResults.Config := FConfig;
  FResults.TotalNs := LEndNs - LStartNs;
  if LTotalIterations > 0 then
    FResults.NsPerOp := FResults.TotalNs / LTotalIterations
  else
    FResults.NsPerOp := 0;

  if FResults.NsPerOp > 0 then
    FResults.OpsPerSec := 1000000000 / FResults.NsPerOp
  else
    FResults.OpsPerSec := 0;

  // Calculate speedup and efficiency
  // Speedup = Sequential time / Parallel time
  // For now, we estimate sequential time as sum of thread times
  LSequentialNs := 0;
  for I := 0 to High(FResults.ThreadResults) do
    LSequentialNs := LSequentialNs + FResults.ThreadResults[I].ElapsedNs;

  if FResults.TotalNs > 0 then
    FResults.Speedup := LSequentialNs / FResults.TotalNs
  else
    FResults.Speedup := 1;

  if FConfig.ThreadCount > 0 then
    FResults.Efficiency := FResults.Speedup / FConfig.ThreadCount
  else
    FResults.Efficiency := 1;

  // Cleanup
  for I := 0 to High(LThreads) do
    LThreads[I].Free;
  SetLength(LThreads, 0);

  Result := FResults;
end;

function TParallelBenchmark.GetResults: TParallelBenchResult;
begin
  Result := FResults;
end;

{ RunParallelBench }

function RunParallelBench(AFunc: TBenchParallelFunc;
                         AThreadCount: Integer;
                         AIterationsPerThread: Int64): TParallelBenchResult;
var
  LBench: TParallelBenchmark;
begin
  LBench := TParallelBenchmark.Create(AFunc, AThreadCount, AIterationsPerThread);
  Result := LBench.Execute;
end;

end.
