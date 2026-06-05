unit nextpas.core.bench;

{$I nextpas.core.settings.inc}

interface

type
  TBenchProc = procedure(aIters: Int64);

  TBenchResult = record
    Name: string;
    Iterations: Int64;
    NsPerOp: Double;
    OpsPerSec: Double;
  end;

  TBenchRunner = class
  private
    FResults: array of TBenchResult;
    FCount: Integer;
    FFilter: string;
    function CalibrateIterations(aProc: TBenchProc): Int64;
    function MeasureNs(aProc: TBenchProc; aIters: Int64): UInt64;
    function ShouldRun(const aName: string): Boolean;
  public
    constructor Create;
    procedure Run(const aName: string; aProc: TBenchProc);
    procedure Summary;
  end;

implementation

uses
  SysUtils,
  nextpas.core.platform.time;

const
  BENCH_MAX_ITERS_ENV = 'NEXTPAS_BENCH_MAX_ITERS';
  BENCH_FILTER_ENV = 'NEXTPAS_BENCH_FILTER';
  TARGET_NS = 50000000;
  WARMUP_ITERS = 5;
  SAMPLES = 3;
  DEFAULT_MAX_ITERS = 100000;

function ConfiguredMaxIterations: Int64;
var
  LValue: string;
begin
  Result := DEFAULT_MAX_ITERS;
  LValue := Trim(GetEnvironmentVariable(BENCH_MAX_ITERS_ENV));
  if (LValue <> '') and TryStrToInt64(LValue, Result) and (Result >= 100) then
    Exit;
  Result := DEFAULT_MAX_ITERS;
end;

constructor TBenchRunner.Create;
begin
  inherited Create;
  FCount := 0;
  FFilter := Trim(GetEnvironmentVariable(BENCH_FILTER_ENV));
  SetLength(FResults, 0);
end;

function TBenchRunner.MeasureNs(aProc: TBenchProc; aIters: Int64): UInt64;
var
  LStart, LEnd: UInt64;
begin
  LStart := platform_monotonic_ns;
  aProc(aIters);
  LEnd := platform_monotonic_ns;
  Result := LEnd - LStart;
end;

function TBenchRunner.ShouldRun(const aName: string): Boolean;
begin
  Result := (FFilter = '') or
    (Pos(LowerCase(FFilter), LowerCase(aName)) > 0);
end;

function TBenchRunner.CalibrateIterations(aProc: TBenchProc): Int64;
var
  LElapsed: UInt64;
  LIters: Int64;
  LMaxIters: Int64;
begin
  aProc(WARMUP_ITERS);

  LMaxIters := ConfiguredMaxIterations;
  LIters := 100;
  while True do
  begin
    LElapsed := MeasureNs(aProc, LIters);
    if LElapsed >= TARGET_NS then
    begin
      Result := LIters;
      Exit;
    end;
    if LElapsed < 1000000 then
      LIters := LIters * 10
    else
      LIters := Int64((Double(LIters) * Double(TARGET_NS)) / Double(LElapsed));
    if LIters < 100 then
      LIters := 100;
    if LIters > LMaxIters then
    begin
      Result := LMaxIters;
      Exit;
    end;
  end;
end;

procedure TBenchRunner.Run(const aName: string; aProc: TBenchProc);
var
  LIters: Int64;
  LSamples: array[0..2] of UInt64;
  i, j: Integer;
  LTmp: UInt64;
  LMedianNs: UInt64;
  LR: TBenchResult;
begin
  if not ShouldRun(aName) then
    Exit;

  LIters := CalibrateIterations(aProc);

  for i := 0 to SAMPLES - 1 do
    LSamples[i] := MeasureNs(aProc, LIters);

  for i := 0 to SAMPLES - 2 do
    for j := i + 1 to SAMPLES - 1 do
      if LSamples[j] < LSamples[i] then
      begin
        LTmp := LSamples[i];
        LSamples[i] := LSamples[j];
        LSamples[j] := LTmp;
      end;

  LMedianNs := LSamples[SAMPLES div 2];

  LR.Name := aName;
  LR.Iterations := LIters;
  LR.NsPerOp := Double(LMedianNs) / Double(LIters);
  if LR.NsPerOp > 0 then
    LR.OpsPerSec := 1000000000.0 / LR.NsPerOp
  else
    LR.OpsPerSec := 0;

  Inc(FCount);
  SetLength(FResults, FCount);
  FResults[FCount - 1] := LR;

  WriteLn('  ', aName:40, LIters:12, ' iters', LR.NsPerOp:10:1, ' ns/op', LR.OpsPerSec:14:0, ' ops/s');
end;

procedure TBenchRunner.Summary;
var
  i: Integer;
begin
  WriteLn;
  WriteLn('=== SUMMARY ===');
  WriteLn('bench_max_iters=', ConfiguredMaxIterations);
  if FFilter <> '' then
    WriteLn('bench_filter=', FFilter);
  WriteLn('  ', 'Benchmark':40, 'ns/op':10, 'ops/s':14);
  WriteLn('  ', '':40, '':10, '':14);
  for i := 0 to FCount - 1 do
    WriteLn('  ', FResults[i].Name:40, FResults[i].NsPerOp:10:1, FResults[i].OpsPerSec:14:0);
end;

end.
