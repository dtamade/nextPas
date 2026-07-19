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
  nextpas.core.system.classes,
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
    {** 顺序基准 NsPerOp（可选，>0 时用于计算真实加速比） }
    SequentialNsPerOp: Double;
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
  public
    {**
     * 创建并行基准执行器
     *}
    class function Create(AFunc: TBenchParallelFunc;
                         AThreadCount: Integer = BENCH_DEFAULT_PARALLEL_THREADS;
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
                           AThreadCount: Integer = BENCH_DEFAULT_PARALLEL_THREADS;
                           AIterationsPerThread: Int64 = 1000000): TParallelBenchResult;

implementation

uses
  nextpas.core.platform.time,
  nextpas.core.exception,
  nextpas.core.bench.intf;



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
    FExceptionMessage: string; { F-02: capture exception message }
  protected
    procedure Execute; override;
  public
    constructor Create(AThreadId: Integer; AFunc: TBenchParallelFunc;
                      AIterations: Int64);
    property BenchThreadId: Integer read FBenchThreadId;
    property Iterations: Int64 read FIterations;
    property ElapsedNs: UInt64 read FElapsedNs;
    property ExceptionMessage: string read FExceptionMessage;
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
  FExceptionMessage := '';
end;

procedure TBenchThread.Execute;
var
  LStartNs: UInt64;
  LEndNs: UInt64;
begin
  try
    // Record start time using high-precision timer
    LStartNs := platform_monotonic_ns;

    // Execute the benchmark function
    FFunc(FBenchThreadId, FIterations);

    // Record end time
    LEndNs := platform_monotonic_ns;

    // Calculate elapsed time in nanoseconds
    FElapsedNs := LEndNs - LStartNs;
  except
    on E: Exception do
    begin
      FElapsedNs := 0;
      FExceptionMessage := E.Message;
    end;
  end;
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

function TParallelBenchmark.Execute: TParallelBenchResult;
var
  LThreads: array of TBenchThread;
  I: Integer;
  LStartNs: UInt64;
  LEndNs: UInt64;
  LTotalIterations: Int64;
begin
  // F-12: 并行热身 - 如果 ThreadCount > 1，用线程池预热各核心缓存
  if FConfig.WarmupIterations > 0 then
  begin
    if FConfig.ThreadCount > 1 then
    begin
      SetLength(LThreads, FConfig.ThreadCount);
      try
        for I := 0 to FConfig.ThreadCount - 1 do
          LThreads[I] := TBenchThread.Create(I, FFunc, FConfig.WarmupIterations);
        for I := 0 to High(LThreads) do
          LThreads[I].Start;
        for I := 0 to High(LThreads) do
          LThreads[I].WaitFor;
      finally
        for I := 0 to High(LThreads) do
          LThreads[I].Free;
        SetLength(LThreads, 0);
      end;
    end
    else
    begin
      for I := 0 to FConfig.ThreadCount - 1 do
        FFunc(I, FConfig.WarmupIterations);
    end;
  end;

  // Create threads (PF-16: try-finally to prevent thread object leak)
  SetLength(LThreads, FConfig.ThreadCount);
  try
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
      { F-02: check for exceptions in worker threads }
      if LThreads[I].ExceptionMessage <> '' then
        raise EBenchError.CreateFmt('Thread %d failed: %s',
          [LThreads[I].BenchThreadId, LThreads[I].ExceptionMessage]);

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
      FResults.OpsPerSec := NANOSECONDS_PER_SECOND / FResults.NsPerOp
    else
      FResults.OpsPerSec := 0;

    // Calculate speedup and efficiency
    if (FConfig.SequentialNsPerOp > 0) and (FResults.NsPerOp > 0) then
      FResults.Speedup := FConfig.SequentialNsPerOp / FResults.NsPerOp
    else
      FResults.Speedup := 0; { 无顺序基准时标记为 N/A }

    if (FConfig.ThreadCount > 0) and (FResults.Speedup > 0) then
      FResults.Efficiency := FResults.Speedup / FConfig.ThreadCount
    else
      FResults.Efficiency := 0;
  finally
    // Cleanup — always free thread objects (PF-16)
    for I := 0 to High(LThreads) do
      LThreads[I].Free;
    SetLength(LThreads, 0);
  end;

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
  if AThreadCount < 1 then
    AThreadCount := 1;
  LBench := TParallelBenchmark.Create(AFunc, AThreadCount, AIterationsPerThread);
  Result := LBench.Execute;
end;

end.
