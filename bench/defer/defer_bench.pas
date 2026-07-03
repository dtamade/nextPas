program defer_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

var
  GData: array[0..N-1] of Integer;
  GSink: Integer;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GData[I] := I;
end;

procedure BenchNoTry(const ACtx: IBenchContext);
var
  I, LSum: Integer;
begin
  LSum := 0;
  for I := 0 to N-1 do
    LSum += GData[I];
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchTryFinally(const ACtx: IBenchContext);
var
  I, LSum: Integer;
begin
  LSum := 0;
  for I := 0 to N-1 do
    try
      LSum += GData[I];
    finally
    end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchTryFinallyOuter(const ACtx: IBenchContext);
var
  I, LSum: Integer;
begin
  LSum := 0;
  try
    for I := 0 to N-1 do
      LSum += GData[I];
  finally
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchTryExcept(const ACtx: IBenchContext);
var
  I, LSum: Integer;
begin
  LSum := 0;
  for I := 0 to N-1 do
    try
      LSum += GData[I];
    except
      LSum := 0;
    end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

function GetValue(const I: Integer): Integer;
begin
  Result := GData[I];
end;

procedure BenchCallWithTryFinally(const ACtx: IBenchContext);
var
  I, LSum: Integer;
begin
  LSum := 0;
  for I := 0 to N-1 do
    try
      LSum += GetValue(I);
    finally
    end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('defer');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('NoTry/100K', @BenchNoTry);
  LSuite.Add('TryFinally/100K', @BenchTryFinally);
  LSuite.Add('TryFinallyOuter/100K', @BenchTryFinallyOuter);
  LSuite.Add('TryExcept/100K', @BenchTryExcept);
  LSuite.Add('CallTryFinally/100K', @BenchCallWithTryFinally);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
