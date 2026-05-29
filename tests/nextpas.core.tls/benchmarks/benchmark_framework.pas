unit benchmark_framework;

{$mode objfpc}{$H+}

{**
 * Performance Baseline Framework for fafafa.ssl
 *
 * Provides infrastructure for benchmarking security-critical operations:
 * - High-resolution timing
 * - Statistical analysis (mean, stddev, percentiles)
 * - Baseline comparison and regression detection
 * - JSON export for CI integration
 *
 * Usage:
 *   Benchmark := TBenchmark.Create;
 *   Benchmark.RegisterTest('aes_encrypt', @BenchAESEncrypt);
 *   Benchmark.Run(1000);  // 1000 iterations
 *   Benchmark.PrintResults;
 *   Benchmark.SaveBaseline('baseline.json');
 *}

interface

uses
  SysUtils, Classes, DateUtils, StrUtils;

type
  { Benchmark test procedure type }
  TBenchmarkProc = procedure;

  { Statistical results for a benchmark }
  TBenchmarkStats = record
    TestName: string;
    Iterations: Integer;
    TotalTimeMs: Double;
    MeanTimeMs: Double;
    StdDevMs: Double;
    MinTimeMs: Double;
    MaxTimeMs: Double;
    P50Ms: Double;     // Median
    P95Ms: Double;     // 95th percentile
    P99Ms: Double;     // 99th percentile
    OpsPerSecond: Double;
  end;

  { Baseline comparison result }
  TBaselineComparison = record
    TestName: string;
    BaselineMs: Double;
    CurrentMs: Double;
    DeltaPercent: Double;
    IsRegression: Boolean;
  end;

  { Array type for comparisons }
  TBaselineComparisonArray = array of TBaselineComparison;

  { Main benchmark class }
  TBenchmark = class
  private
    FTests: TStringList;
    FResults: array of TBenchmarkStats;
    FWarmupIterations: Integer;
    FRegressionThreshold: Double;  // Percentage (e.g., 0.10 = 10%)

    function GetTestIndex(const AName: string): Integer;
    function CalculateStats(const ATimes: array of Double): TBenchmarkStats;
    procedure QuickSort(var A: array of Double; Lo, Hi: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    { Test registration }
    procedure RegisterTest(const AName: string; AProc: TBenchmarkProc);

    { Execution }
    procedure Run(AIterations: Integer = 1000);
    procedure RunTest(const ATestName: string; AIterations: Integer = 1000);

    { Results }
    function GetStats(const ATestName: string): TBenchmarkStats;
    procedure PrintResults;
    procedure PrintComparison(const ABaseline: array of TBenchmarkStats);

    { Baseline management }
    procedure SaveBaseline(const AFileName: string);
    function LoadBaseline(const AFileName: string): Boolean;
    function CompareWithBaseline(const ABaseline: array of TBenchmarkStats): TBaselineComparisonArray;
    function DetectRegressions(const ABaseline: array of TBenchmarkStats): Boolean;

    { Configuration }
    property WarmupIterations: Integer read FWarmupIterations write FWarmupIterations;
    property RegressionThreshold: Double read FRegressionThreshold write FRegressionThreshold;
  end;

{ High-resolution timer functions }
function GetHighResolutionTime: Double;  // Returns time in milliseconds

implementation

var
  GTimerFrequency: Int64 = 0;
  GStartTime: Int64 = 0;

function GetHighResolutionTime: Double;
begin
  // Use GetTickCount64 which is available in SysUtils for all platforms
  // Returns milliseconds since system boot
  Result := GetTickCount64 - GStartTime;
end;

{ TBenchmark }

constructor TBenchmark.Create;
begin
  inherited Create;
  FTests := TStringList.Create;
  FTests.Sorted := True;
  FTests.Duplicates := dupError;
  FWarmupIterations := 100;
  FRegressionThreshold := 0.10;  // 10% threshold

  {$IFDEF WINDOWS}
  QueryPerformanceFrequency(GTimerFrequency);
  {$ENDIF}
end;

destructor TBenchmark.Destroy;
begin
  FTests.Free;
  inherited Destroy;
end;

function TBenchmark.GetTestIndex(const AName: string): Integer;
begin
  Result := FTests.IndexOf(AName);
end;

procedure TBenchmark.QuickSort(var A: array of Double; Lo, Hi: Integer);
var
  I, J: Integer;
  Pivot, Tmp: Double;
begin
  if Lo < Hi then
  begin
    Pivot := A[(Lo + Hi) div 2];
    I := Lo;
    J := Hi;
    while I <= J do
    begin
      while A[I] < Pivot do Inc(I);
      while A[J] > Pivot do Dec(J);
      if I <= J then
      begin
        Tmp := A[I];
        A[I] := A[J];
        A[J] := Tmp;
        Inc(I);
        Dec(J);
      end;
    end;
    if Lo < J then QuickSort(A, Lo, J);
    if I < Hi then QuickSort(A, I, Hi);
  end;
end;

function TBenchmark.CalculateStats(const ATimes: array of Double): TBenchmarkStats;
var
  I, N: Integer;
  Sum, SumSq, Mean: Double;
  Sorted: array of Double;
begin
  N := Length(ATimes);
  FillChar(Result, SizeOf(Result), 0);

  if N = 0 then Exit;

  // Calculate sum and mean
  Sum := 0;
  for I := 0 to N - 1 do
    Sum := Sum + ATimes[I];
  Mean := Sum / N;

  Result.Iterations := N;
  Result.TotalTimeMs := Sum;
  Result.MeanTimeMs := Mean;

  // Calculate standard deviation
  SumSq := 0;
  for I := 0 to N - 1 do
    SumSq := SumSq + Sqr(ATimes[I] - Mean);
  Result.StdDevMs := Sqrt(SumSq / N);

  // Find min and max
  Result.MinTimeMs := ATimes[0];
  Result.MaxTimeMs := ATimes[0];
  for I := 1 to N - 1 do
  begin
    if ATimes[I] < Result.MinTimeMs then
      Result.MinTimeMs := ATimes[I];
    if ATimes[I] > Result.MaxTimeMs then
      Result.MaxTimeMs := ATimes[I];
  end;

  // Calculate percentiles (need sorted array)
  SetLength(Sorted, N);
  for I := 0 to N - 1 do
    Sorted[I] := ATimes[I];
  QuickSort(Sorted, 0, N - 1);

  Result.P50Ms := Sorted[N div 2];  // Median
  Result.P95Ms := Sorted[(N * 95) div 100];
  Result.P99Ms := Sorted[(N * 99) div 100];

  // Operations per second
  if Mean > 0 then
    Result.OpsPerSecond := 1000.0 / Mean
  else
    Result.OpsPerSecond := 0;
end;

procedure TBenchmark.RegisterTest(const AName: string; AProc: TBenchmarkProc);
begin
  FTests.AddObject(AName, TObject(AProc));
end;

procedure TBenchmark.RunTest(const ATestName: string; AIterations: Integer);
var
  Idx, I: Integer;
  Proc: TBenchmarkProc;
  Times: array of Double;
  StartTime: Double;
  Stats: TBenchmarkStats;
begin
  Idx := GetTestIndex(ATestName);
  if Idx < 0 then
  begin
    WriteLn('Error: Test not found: ', ATestName);
    Exit;
  end;

  Proc := TBenchmarkProc(FTests.Objects[Idx]);

  // Warmup phase
  for I := 1 to FWarmupIterations do
    Proc();

  // Measurement phase
  SetLength(Times, AIterations);
  for I := 0 to AIterations - 1 do
  begin
    StartTime := GetHighResolutionTime;
    Proc();
    Times[I] := GetHighResolutionTime - StartTime;
  end;

  // Calculate statistics
  Stats := CalculateStats(Times);
  Stats.TestName := ATestName;

  // Store results
  SetLength(FResults, Length(FResults) + 1);
  FResults[High(FResults)] := Stats;

  Write(#13, '  ', ATestName, ': ', Stats.MeanTimeMs:0:3, ' ms/op');
  Write(' (stddev: ', Stats.StdDevMs:0:3, ', ops/s: ', Stats.OpsPerSecond:0:1, ')');
  WriteLn;
end;

procedure TBenchmark.Run(AIterations: Integer);
var
  I: Integer;
begin
  WriteLn('=== Performance Benchmark ===');
  WriteLn('Iterations: ', AIterations);
  WriteLn('Warmup: ', FWarmupIterations);
  WriteLn;

  SetLength(FResults, 0);  // Clear previous results

  for I := 0 to FTests.Count - 1 do
    RunTest(FTests[I], AIterations);

  WriteLn;
end;

function TBenchmark.GetStats(const ATestName: string): TBenchmarkStats;
var
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for I := 0 to High(FResults) do
    if FResults[I].TestName = ATestName then
    begin
      Result := FResults[I];
      Exit;
    end;
end;

procedure TBenchmark.PrintResults;
var
  I: Integer;
begin
  WriteLn('=== Benchmark Results ===');
  WriteLn;
  WriteLn(Format('%-25s %12s %12s %12s %12s', ['Test', 'Mean (ms)', 'P95 (ms)', 'P99 (ms)', 'Ops/s']));
  WriteLn(StringOfChar('-', 75));

  for I := 0 to High(FResults) do
  begin
    WriteLn(Format('%-25s %12.3f %12.3f %12.3f %12.1f', [
      FResults[I].TestName,
      FResults[I].MeanTimeMs,
      FResults[I].P95Ms,
      FResults[I].P99Ms,
      FResults[I].OpsPerSecond
    ]));
  end;
  WriteLn;
end;

procedure TBenchmark.PrintComparison(const ABaseline: array of TBenchmarkStats);
var
  Comparisons: TBaselineComparisonArray;
  I: Integer;
begin
  Comparisons := CompareWithBaseline(ABaseline);

  WriteLn('=== Baseline Comparison ===');
  WriteLn;
  WriteLn(Format('%-25s %12s %12s %12s %8s', ['Test', 'Baseline', 'Current', 'Delta', 'Status']));
  WriteLn(StringOfChar('-', 75));

  for I := 0 to High(Comparisons) do
  begin
    WriteLn(Format('%-25s %12.3f %12.3f %11.1f%% %8s', [
      Comparisons[I].TestName,
      Comparisons[I].BaselineMs,
      Comparisons[I].CurrentMs,
      Comparisons[I].DeltaPercent * 100,
      IfThen(Comparisons[I].IsRegression, 'REGRESS', 'OK')
    ]));
  end;
  WriteLn;
end;

procedure TBenchmark.SaveBaseline(const AFileName: string);
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, AFileName);
  Rewrite(F);
  try
    WriteLn(F, '{');
    WriteLn(F, '  "generated": "', DateTimeToStr(Now), '",');
    WriteLn(F, '  "tests": [');

    for I := 0 to High(FResults) do
    begin
      WriteLn(F, '    {');
      WriteLn(F, '      "name": "', FResults[I].TestName, '",');
      WriteLn(F, '      "mean_ms": ', FResults[I].MeanTimeMs:0:6, ',');
      WriteLn(F, '      "stddev_ms": ', FResults[I].StdDevMs:0:6, ',');
      WriteLn(F, '      "min_ms": ', FResults[I].MinTimeMs:0:6, ',');
      WriteLn(F, '      "max_ms": ', FResults[I].MaxTimeMs:0:6, ',');
      WriteLn(F, '      "p50_ms": ', FResults[I].P50Ms:0:6, ',');
      WriteLn(F, '      "p95_ms": ', FResults[I].P95Ms:0:6, ',');
      WriteLn(F, '      "p99_ms": ', FResults[I].P99Ms:0:6, ',');
      WriteLn(F, '      "iterations": ', FResults[I].Iterations);
      if I < High(FResults) then
        WriteLn(F, '    },')
      else
        WriteLn(F, '    }');
    end;

    WriteLn(F, '  ]');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;
end;

function TBenchmark.LoadBaseline(const AFileName: string): Boolean;
var
  LLines: TStringList;
  LLine, LToken, LValue: string;
  LPosColon, LPosFirstQuote, LPosSecondQuote: Integer;
  LEntryCount: Integer;
  LHasName, LHasMean: Boolean;
  LMeanValue: Double;
  LFormatSettings: TFormatSettings;
begin
  Result := False;

  if not FileExists(AFileName) then
    Exit;

  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AFileName);
    LEntryCount := 0;
    LHasName := False;
    LHasMean := False;
    LFormatSettings := DefaultFormatSettings;
    LFormatSettings.DecimalSeparator := '.';

    for LLine in LLines do
    begin
      LToken := Trim(LLine);

      if Pos('"name"', LToken) = 1 then
      begin
        LPosColon := Pos(':', LToken);
        if LPosColon <= 0 then
          Exit;
        LValue := Trim(Copy(LToken, LPosColon + 1, MaxInt));

        LPosFirstQuote := Pos('"', LValue);
        if LPosFirstQuote <= 0 then
          Exit;
        LValue := Copy(LValue, LPosFirstQuote + 1, MaxInt);

        LPosSecondQuote := Pos('"', LValue);
        if LPosSecondQuote <= 0 then
          Exit;
        LValue := Copy(LValue, 1, LPosSecondQuote - 1);

        if LValue = '' then
          Exit;
        LHasName := True;
      end
      else if Pos('"mean_ms"', LToken) = 1 then
      begin
        LPosColon := Pos(':', LToken);
        if LPosColon <= 0 then
          Exit;
        LValue := Trim(Copy(LToken, LPosColon + 1, MaxInt));
        if (LValue <> '') and (LValue[Length(LValue)] = ',') then
          Delete(LValue, Length(LValue), 1);

        if not TryStrToFloat(LValue, LMeanValue, LFormatSettings) then
          Exit;

        LHasMean := True;
      end
      else if (LToken = '},') or (LToken = '}') then
      begin
        if LHasName or LHasMean then
        begin
          if not (LHasName and LHasMean) then
            Exit;
          Inc(LEntryCount);
          LHasName := False;
          LHasMean := False;
        end;
      end;
    end;

    if LHasName or LHasMean then
      Exit;

    Result := LEntryCount > 0;
  finally
    LLines.Free;
  end;
end;

function TBenchmark.CompareWithBaseline(const ABaseline: array of TBenchmarkStats): TBaselineComparisonArray;
var
  I, J: Integer;
  Found: Boolean;
begin
  SetLength(Result, Length(FResults));

  for I := 0 to High(FResults) do
  begin
    Result[I].TestName := FResults[I].TestName;
    Result[I].CurrentMs := FResults[I].MeanTimeMs;
    Result[I].BaselineMs := 0;
    Result[I].DeltaPercent := 0;
    Result[I].IsRegression := False;

    // Find matching baseline
    Found := False;
    for J := 0 to High(ABaseline) do
    begin
      if ABaseline[J].TestName = FResults[I].TestName then
      begin
        Result[I].BaselineMs := ABaseline[J].MeanTimeMs;
        if ABaseline[J].MeanTimeMs > 0 then
        begin
          Result[I].DeltaPercent := (FResults[I].MeanTimeMs - ABaseline[J].MeanTimeMs) / ABaseline[J].MeanTimeMs;
          Result[I].IsRegression := Result[I].DeltaPercent > FRegressionThreshold;
        end;
        Found := True;
        Break;
      end;
    end;
  end;
end;

function TBenchmark.DetectRegressions(const ABaseline: array of TBenchmarkStats): Boolean;
var
  Comparisons: TBaselineComparisonArray;
  I: Integer;
begin
  Result := False;
  Comparisons := CompareWithBaseline(ABaseline);
  for I := 0 to High(Comparisons) do
    if Comparisons[I].IsRegression then
    begin
      Result := True;
      Exit;
    end;
end;

initialization
  GStartTime := GetTickCount64;

end.
