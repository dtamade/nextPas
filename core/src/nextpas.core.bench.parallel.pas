{**
 * @desc 并行基准执行器
 *
 * 使用 platform.thread（非 Classes.TThread）驱动多线程测量 (F-01)。
 *}
unit nextpas.core.bench.parallel;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.bench.base;

type
  {**
   * 并行基准函数类型
   *}
  TBenchParallelFunc = procedure(AThreadId: Integer; AIterations: Int64);

  {**
   * 带用户数据的并行函数（runner 桥接用，避免全局 GBridgeRunner）(F-05)
   *}
  TBenchParallelUserDataFunc = procedure(AThreadId: Integer; AIterations: Int64;
    AUserData: Pointer);

  {**
   * 并行基准配置
   *}
  TParallelBenchConfig = record
    ThreadCount: Integer;
    IterationsPerThread: Int64;
    WarmupIterations: Int64;
    SequentialNsPerOp: Double;
  end;

  {**
   * 并行基准结果
   *}
  TParallelBenchResult = record
    Config: TParallelBenchConfig;
    TotalNs: UInt64;
    NsPerOp: Double;
    OpsPerSec: Double;
    Speedup: Double;
    Efficiency: Double;
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
    class function Create(AFunc: TBenchParallelFunc;
                         AThreadCount: Integer = BENCH_DEFAULT_PARALLEL_THREADS;
                         AIterationsPerThread: Int64 = 1000000;
                         AWarmupIterations: Int64 = 1000): TParallelBenchmark; static;
    function Execute: TParallelBenchResult;
    function GetResults: TParallelBenchResult;
  end;

  function RunParallelBench(AFunc: TBenchParallelFunc;
                           AThreadCount: Integer = BENCH_DEFAULT_PARALLEL_THREADS;
                           AIterationsPerThread: Int64 = 1000000): TParallelBenchResult;

  {** Runner bridge: pass Self as AUserData (no process-global runner pointer). }
  function RunParallelBenchWithUserData(AFunc: TBenchParallelUserDataFunc;
                                        AUserData: Pointer;
                                        AThreadCount: Integer;
                                        AIterationsPerThread: Int64;
                                        AWarmupIterations: Int64 = 0): TParallelBenchResult;

implementation

uses
  nextpas.core.platform.time,
  nextpas.core.platform.thread,
  nextpas.core.exception,
  nextpas.core.bench.intf;

type
  PBenchParallelJob = ^TBenchParallelJob;
  TBenchParallelJob = record
    ThreadId: Integer;
    Iterations: Int64;
    Func: TBenchParallelFunc;
    UserFunc: TBenchParallelUserDataFunc;
    UserData: Pointer;
    UseUserData: Boolean;
    ElapsedNs: UInt64;
    ExceptionMessage: string;
  end;

function ParallelJobWorker(AArg: Pointer): Pointer; cdecl;
var
  LJob: PBenchParallelJob;
  LStartNs, LEndNs: UInt64;
begin
  Result := nil;
  LJob := PBenchParallelJob(AArg);
  if LJob = nil then
    Exit;
  try
    LStartNs := platform_monotonic_ns;
    if LJob^.UseUserData then
    begin
      if Assigned(LJob^.UserFunc) then
        LJob^.UserFunc(LJob^.ThreadId, LJob^.Iterations, LJob^.UserData);
    end
    else if Assigned(LJob^.Func) then
      LJob^.Func(LJob^.ThreadId, LJob^.Iterations);
    LEndNs := platform_monotonic_ns;
    LJob^.ElapsedNs := LEndNs - LStartNs;
  except
    on E: Exception do
    begin
      LJob^.ElapsedNs := 0;
      LJob^.ExceptionMessage := E.Message;
    end;
  end;
end;

function ExecuteParallelJobs(var AJobs: array of TBenchParallelJob;
  const AConfig: TParallelBenchConfig): TParallelBenchResult;
var
  LHandles: array of TPlatformThreadHandle;
  I: Integer;
  LStartNs, LEndNs: UInt64;
  LTotalIterations: Int64;
  LRet: Pointer;
  LHandle: TPlatformThreadHandle;
begin
  Result := Default(TParallelBenchResult);
  Result.Config := AConfig;
  SetLength(LHandles, Length(AJobs));
  for I := 0 to High(LHandles) do
    LHandles[I] := nil;

  LStartNs := platform_monotonic_ns;
  try
    for I := 0 to High(AJobs) do
    begin
      if platform_thread_create(LHandle, @ParallelJobWorker, @AJobs[I]) = 0 then
        LHandles[I] := LHandle
      else
        raise EBenchError.CreateFmt('RunParallelBench: platform_thread_create failed for thread %d',
          [AJobs[I].ThreadId]);
    end;

    for I := 0 to High(LHandles) do
      if LHandles[I] <> nil then
        platform_thread_join(LHandles[I], LRet);

    LEndNs := platform_monotonic_ns;
    LTotalIterations := 0;
    SetLength(Result.ThreadResults, Length(AJobs));
    for I := 0 to High(AJobs) do
    begin
      if AJobs[I].ExceptionMessage <> '' then
        raise EBenchError.CreateFmt('Thread %d failed: %s',
          [AJobs[I].ThreadId, AJobs[I].ExceptionMessage]);
      Result.ThreadResults[I].ThreadId := AJobs[I].ThreadId;
      Result.ThreadResults[I].Iterations := AJobs[I].Iterations;
      Result.ThreadResults[I].ElapsedNs := AJobs[I].ElapsedNs;
      if AJobs[I].Iterations > 0 then
        Result.ThreadResults[I].NsPerOp := AJobs[I].ElapsedNs / AJobs[I].Iterations
      else
        Result.ThreadResults[I].NsPerOp := 0;
      Inc(LTotalIterations, AJobs[I].Iterations);
    end;

    Result.TotalNs := LEndNs - LStartNs;
    if LTotalIterations > 0 then
      Result.NsPerOp := Result.TotalNs / LTotalIterations
    else
      Result.NsPerOp := 0;
    if Result.NsPerOp > 0 then
      Result.OpsPerSec := NANOSECONDS_PER_SECOND / Result.NsPerOp
    else
      Result.OpsPerSec := 0;
    if (AConfig.SequentialNsPerOp > 0) and (Result.NsPerOp > 0) then
      Result.Speedup := AConfig.SequentialNsPerOp / Result.NsPerOp
    else
      Result.Speedup := 0;
    if (AConfig.ThreadCount > 0) and (Result.Speedup > 0) then
      Result.Efficiency := Result.Speedup / AConfig.ThreadCount
    else
      Result.Efficiency := 0;
  except
    { join any started threads before re-raise }
    for I := 0 to High(LHandles) do
      if LHandles[I] <> nil then
        platform_thread_join(LHandles[I], LRet);
    raise;
  end;
end;

procedure RunWarmupJobs(AFunc: TBenchParallelFunc; AUserFunc: TBenchParallelUserDataFunc;
  AUserData: Pointer; AUseUserData: Boolean; AThreadCount: Integer; AWarmupIters: Int64);
var
  LJobs: array of TBenchParallelJob;
  LConfig: TParallelBenchConfig;
  I: Integer;
begin
  if AWarmupIters <= 0 then
    Exit;
  if AThreadCount <= 1 then
  begin
    if AUseUserData then
    begin
      if Assigned(AUserFunc) then
        AUserFunc(0, AWarmupIters, AUserData);
    end
    else if Assigned(AFunc) then
      AFunc(0, AWarmupIters);
    Exit;
  end;
  SetLength(LJobs, AThreadCount);
  for I := 0 to AThreadCount - 1 do
  begin
    LJobs[I] := Default(TBenchParallelJob);
    LJobs[I].ThreadId := I;
    LJobs[I].Iterations := AWarmupIters;
    LJobs[I].Func := AFunc;
    LJobs[I].UserFunc := AUserFunc;
    LJobs[I].UserData := AUserData;
    LJobs[I].UseUserData := AUseUserData;
  end;
  LConfig := Default(TParallelBenchConfig);
  LConfig.ThreadCount := AThreadCount;
  LConfig.IterationsPerThread := AWarmupIters;
  ExecuteParallelJobs(LJobs, LConfig);
end;

class function TParallelBenchmark.Create(AFunc: TBenchParallelFunc;
                                         AThreadCount: Integer;
                                         AIterationsPerThread: Int64;
                                         AWarmupIterations: Int64): TParallelBenchmark;
begin
  Result.FConfig.ThreadCount := AThreadCount;
  Result.FConfig.IterationsPerThread := AIterationsPerThread;
  Result.FConfig.WarmupIterations := AWarmupIterations;
  Result.FConfig.SequentialNsPerOp := 0;
  Result.FFunc := AFunc;
  Result.FResults := Default(TParallelBenchResult);
end;

function TParallelBenchmark.Execute: TParallelBenchResult;
var
  LJobs: array of TBenchParallelJob;
  I: Integer;
begin
  if FConfig.ThreadCount < 1 then
    FConfig.ThreadCount := 1;

  RunWarmupJobs(FFunc, nil, nil, False, FConfig.ThreadCount, FConfig.WarmupIterations);

  SetLength(LJobs, FConfig.ThreadCount);
  for I := 0 to FConfig.ThreadCount - 1 do
  begin
    LJobs[I] := Default(TBenchParallelJob);
    LJobs[I].ThreadId := I;
    LJobs[I].Iterations := FConfig.IterationsPerThread;
    LJobs[I].Func := FFunc;
    LJobs[I].UseUserData := False;
  end;
  FResults := ExecuteParallelJobs(LJobs, FConfig);
  Result := FResults;
end;

function TParallelBenchmark.GetResults: TParallelBenchResult;
begin
  Result := FResults;
end;

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

function RunParallelBenchWithUserData(AFunc: TBenchParallelUserDataFunc;
                                      AUserData: Pointer;
                                      AThreadCount: Integer;
                                      AIterationsPerThread: Int64;
                                      AWarmupIterations: Int64): TParallelBenchResult;
var
  LJobs: array of TBenchParallelJob;
  LConfig: TParallelBenchConfig;
  I: Integer;
begin
  if AThreadCount < 1 then
    AThreadCount := 1;
  RunWarmupJobs(nil, AFunc, AUserData, True, AThreadCount, AWarmupIterations);

  SetLength(LJobs, AThreadCount);
  for I := 0 to AThreadCount - 1 do
  begin
    LJobs[I] := Default(TBenchParallelJob);
    LJobs[I].ThreadId := I;
    LJobs[I].Iterations := AIterationsPerThread;
    LJobs[I].UserFunc := AFunc;
    LJobs[I].UserData := AUserData;
    LJobs[I].UseUserData := True;
  end;
  LConfig := Default(TParallelBenchConfig);
  LConfig.ThreadCount := AThreadCount;
  LConfig.IterationsPerThread := AIterationsPerThread;
  LConfig.WarmupIterations := AWarmupIterations;
  Result := ExecuteParallelJobs(LJobs, LConfig);
end;

end.
