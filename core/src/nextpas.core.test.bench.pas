{**
 * @desc 测试框架与 bench 模块集成
 *
 * 提供在测试中运行基准测试的辅助函数。
 *}
unit nextpas.core.test.bench;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.bench,
  nextpas.core.test.base,
  nextpas.core.time.base;

type
  {** 基准测试配置 }
  TBenchTestConfig = record
    MinDurationMs: Integer;
    MinSamples: Integer;
    MaxIterations: Int64;
    TimeoutMs: Integer;
    ThreadCount: Integer;
  end;

  {** 基准测试条目 }
  TBenchTestEntry = record
    Name: string;
    Func: TBenchFunc;
  end;

  {** 基准测试结果（简化版，用于测试断言） }
  TBenchTestResult = record
    Name: string;
    NsPerOp: Double;
    OpsPerSec: Double;
    Iterations: Int64;
    StdDev: Double;
    Executed: Boolean;
    Skipped: Boolean;
    SkipReason: string;
  end;

  {** 基准测试结果数组 }
  TBenchTestResultArray = array of TBenchTestResult;

{** 默认基准测试配置 }
function DefaultBenchTestConfig: TBenchTestConfig;

{** 运行单个基准测试并返回结果 }
function RunBenchTest(const AName: string; AFunc: TBenchFunc;
  const AConfig: TBenchTestConfig): TBenchTestResult;

{** 运行基准测试套件并返回所有结果 }
function RunBenchSuite(const ASuiteName: string;
  const AEntries: array of TBenchTestEntry;
  const AConfig: TBenchTestConfig): TBenchTestResultArray;

{** 断言基准测试性能在阈值内 }
procedure CheckBenchPerformance(const AResult: TBenchTestResult;
  AMaxNsPerOp: Double; const AMessage: string = '');

{** 断言基准测试吞吐量在阈值内 }
procedure CheckBenchThroughput(const AResult: TBenchTestResult;
  AMinOpsPerSec: Double; const AMessage: string = '');

implementation

uses
  nextpas.core.text.format,
  nextpas.core.test.check;

function DefaultBenchTestConfig: TBenchTestConfig;
begin
  Result.MinDurationMs := 100;
  Result.MinSamples := 5;
  Result.MaxIterations := 0;
  Result.TimeoutMs := 5000;
  Result.ThreadCount := 1;
end;

function RunBenchTest(const AName: string; AFunc: TBenchFunc;
  const AConfig: TBenchTestConfig): TBenchTestResult;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
begin
  LSuite := TBenchSuite.Create(AName)
    .SetMinDuration(TDuration.FromMilliseconds(AConfig.MinDurationMs))
    .SetMinSamples(AConfig.MinSamples);

  if AConfig.MaxIterations > 0 then
    LSuite.SetMaxIterations(AConfig.MaxIterations);

  if AConfig.TimeoutMs > 0 then
    LSuite.SetTimeout(TDuration.FromMilliseconds(AConfig.TimeoutMs));

  LSuite.Add(AName, AFunc);

  if AConfig.ThreadCount > 1 then
    LResults := LSuite.RunParallel(AConfig.ThreadCount)
  else
    LResults := LSuite.Run;

  LAll := LResults.GetAll;
  if Length(LAll) > 0 then
  begin
    Result.Name := LAll[0].Name;
    Result.NsPerOp := LAll[0].NsPerOp;
    Result.OpsPerSec := LAll[0].OpsPerSec;
    Result.Iterations := LAll[0].Iterations;
    Result.StdDev := LAll[0].StdDev;
    Result.Executed := LAll[0].Executed;
    Result.Skipped := LAll[0].Skipped;
    Result.SkipReason := LAll[0].SkipReason;
  end
  else
  begin
    Result.Name := AName;
    Result.NsPerOp := 0;
    Result.OpsPerSec := 0;
    Result.Iterations := 0;
    Result.StdDev := 0;
    Result.Executed := False;
    Result.Skipped := True;
    Result.SkipReason := 'No results';
  end;
end;

function RunBenchSuite(const ASuiteName: string;
  const AEntries: array of TBenchTestEntry;
  const AConfig: TBenchTestConfig): TBenchTestResultArray;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  I: Integer;
begin
  Result := nil;
  LSuite := TBenchSuite.Create(ASuiteName)
    .SetMinDuration(TDuration.FromMilliseconds(AConfig.MinDurationMs))
    .SetMinSamples(AConfig.MinSamples);

  if AConfig.MaxIterations > 0 then
    LSuite.SetMaxIterations(AConfig.MaxIterations);

  if AConfig.TimeoutMs > 0 then
    LSuite.SetTimeout(TDuration.FromMilliseconds(AConfig.TimeoutMs));

  for I := 0 to High(AEntries) do
    LSuite.Add(AEntries[I].Name, AEntries[I].Func);

  if AConfig.ThreadCount > 1 then
    LResults := LSuite.RunParallel(AConfig.ThreadCount)
  else
    LResults := LSuite.Run;

  LAll := LResults.GetAll;
  SetLength(Result, Length(LAll));
  if Length(Result) = 0 then
    Exit;

  for I := 0 to High(LAll) do
  begin
    Result[I].Name := LAll[I].Name;
    Result[I].NsPerOp := LAll[I].NsPerOp;
    Result[I].OpsPerSec := LAll[I].OpsPerSec;
    Result[I].Iterations := LAll[I].Iterations;
    Result[I].StdDev := LAll[I].StdDev;
    Result[I].Executed := LAll[I].Executed;
    Result[I].Skipped := LAll[I].Skipped;
    Result[I].SkipReason := LAll[I].SkipReason;
  end;
end;

procedure CheckBenchPerformance(const AResult: TBenchTestResult;
  AMaxNsPerOp: Double; const AMessage: string);
var
  LMsg: string;
begin
  if AMessage <> '' then
    LMsg := AMessage
  else
    LMsg := TextFormat('Benchmark "%s" performance %.1f ns/op exceeds threshold %.1f ns/op',
      [AResult.Name, AResult.NsPerOp, AMaxNsPerOp]);

  Check(AResult.Executed and (AResult.NsPerOp <= AMaxNsPerOp), LMsg);
end;

procedure CheckBenchThroughput(const AResult: TBenchTestResult;
  AMinOpsPerSec: Double; const AMessage: string);
var
  LMsg: string;
begin
  if AMessage <> '' then
    LMsg := AMessage
  else
    LMsg := TextFormat('Benchmark "%s" throughput %.0f ops/s below threshold %.0f ops/s',
      [AResult.Name, AResult.OpsPerSec, AMinOpsPerSec]);

  Check(AResult.Executed and (AResult.OpsPerSec >= AMinOpsPerSec), LMsg);
end;

end.
