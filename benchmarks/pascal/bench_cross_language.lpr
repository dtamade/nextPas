program bench_cross_language;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.text.format;

var
  GBenchStart: TInstant;

type
  TBenchResult = record
    Name: string;
    N: Integer;
    TotalNs: Int64;
    MeanNs: Double;
    MinNs: Int64;
    MaxNs: Int64;
    MedianNs: Double;
    StdDevNs: Double;
    OpsPerSec: Double;
  end;

function GetMicroTime: Int64;
begin
  Result := TInstant.Now.DurationSince(GBenchStart).AsMicroseconds;
end;

function RunBenchmark(const AName: string; N: Integer; AProc: TProcedure): TBenchResult;
var
  Times: array of Int64;
  I, J: Integer;
  Start, Stop: Int64;
  Total: Int64;
  Mean, Variance, StdDev, Median, Diff: Double;
  Tmp: Int64;
begin
  SetLength(Times, N);

  for I := 0 to N - 1 do
  begin
    Start := GetMicroTime;
    AProc;
    Stop := GetMicroTime;
    Times[I] := (Stop - Start) * 1000; // Convert us to ns
  end;

  // Sort - bubble sort for small arrays
  for I := 0 to N - 2 do
    for J := 0 to N - I - 2 do
      if Times[J] > Times[J + 1] then
      begin
        Tmp := Times[J];
        Times[J] := Times[J + 1];
        Times[J + 1] := Tmp;
      end;

  Total := 0;
  for I := 0 to N - 1 do
    Total := Total + Times[I];
  Mean := Total / N;

  Variance := 0;
  for I := 0 to N - 1 do
  begin
    Diff := Times[I] - Mean;
    Variance := Variance + Diff * Diff;
  end;
  Variance := Variance / N;
  StdDev := Sqrt(Variance);

  if N mod 2 = 0 then
    Median := (Times[N div 2 - 1] + Times[N div 2]) / 2.0
  else
    Median := Times[N div 2];

  Result.Name := AName;
  Result.N := N;
  Result.TotalNs := Total;
  Result.MeanNs := Mean;
  Result.MinNs := Times[0];
  Result.MaxNs := Times[N - 1];
  Result.MedianNs := Median;
  Result.StdDevNs := StdDev;
  if Mean > 0 then
    Result.OpsPerSec := 1e9 / Mean
  else
    Result.OpsPerSec := 0;
end;

// Fibonacci
function Fib(X: Integer): Integer;
begin
  if X <= 1 then
    Exit(X);
  Result := Fib(X - 1) + Fib(X - 2);
end;

procedure BenchFibonacci;
var
  R: Integer;
begin
  R := Fib(20);
end;

// Sorting
procedure BenchSorting;
var
  Data: array[0..999] of Integer;
  I, J, Tmp: Integer;
begin
  for I := 0 to 999 do
    Data[I] := Random(10000);

  // Simple bubble sort
  for I := 0 to 998 do
    for J := 0 to 998 - I do
      if Data[J] > Data[J + 1] then
      begin
        Tmp := Data[J];
        Data[J] := Data[J + 1];
        Data[J + 1] := Tmp;
      end;
end;

// String concatenation
procedure BenchStringConcat;
var
  S: string;
  I: Integer;
begin
  S := '';
  for I := 1 to 100 do
    S := S + 'a';
end;

// Memory allocation
procedure BenchMemoryAlloc;
var
  Data: TBytes;
  I: Integer;
begin
  SetLength(Data, 100);
  for I := 0 to 99 do
    Data[I] := Byte(I mod 256);
end;

var
  Results: array[0..3] of TBenchResult;
  I: Integer;
  N: Integer;
begin
  GBenchStart := TInstant.Now;
  N := 1000;

  WriteLn('=== Pascal Benchmark Results ===');
  WriteLn;

  Results[0] := RunBenchmark('Fibonacci(20)', N, @BenchFibonacci);
  Results[1] := RunBenchmark('Sorting(1000)', N, @BenchSorting);
  Results[2] := RunBenchmark('StringConcat(100)', N, @BenchStringConcat);
  Results[3] := RunBenchmark('MemoryAlloc(100)', N, @BenchMemoryAlloc);

  for I := 0 to 3 do
  begin
    WriteLn(TextFormat('%-20s: N=%d, Mean=%.0f ns, Min=%d ns, Max=%d ns, Median=%.0f ns, StdDev=%.0f ns, Ops/sec=%.0f',
      [Results[I].Name, Results[I].N, Results[I].MeanNs, Results[I].MinNs, Results[I].MaxNs,
       Results[I].MedianNs, Results[I].StdDevNs, Results[I].OpsPerSec]));
  end;

  WriteLn;
  WriteLn('=== End of Pascal Benchmarks ===');
end.
