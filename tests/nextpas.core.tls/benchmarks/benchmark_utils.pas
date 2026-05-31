unit benchmark_utils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math;

type
  { Benchmark timing and statistics }
  TBenchmark = class
  private
    FName: string;
    FStartTime: QWord;
    FEndTime: QWord;
    FIterations: Int64;
    FDataSize: Int64;  // For throughput calculations
  public
    constructor Create(const AName: string);
    procedure Start;
    procedure Stop;
    procedure SetIterations(ACount: Int64);
    procedure SetDataSize(ABytes: Int64);
    
    function ElapsedMs: Double;
    function OpsPerSecond: Double;
    function ThroughputMBps: Double;
    
    procedure Report;
    procedure ReportThroughput;
    
    property Name: string read FName;
  end;

  { Statistical utilities }
  TStats = class
  public
    class function Mean(const AValues: array of Double): Double;
    class function Median(const AValues: array of Double): Double;
    class function Percentile(const AValues: array of Double; P: Double): Double;
    class function StdDev(const AValues: array of Double): Double;
  end;

  { Console output formatting }
  procedure PrintHeader(const AText: string);
  procedure PrintResult(const AName: string; AValue: Double; const AUnit: string);
  procedure PrintSeparator;

implementation

{ TBenchmark }

constructor TBenchmark.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FIterations := 0;
  FDataSize := 0;
end;

procedure TBenchmark.Start;
begin
  FStartTime := GetTickCount64;
end;

procedure TBenchmark.Stop;
begin
  FEndTime := GetTickCount64;
end;

procedure TBenchmark.SetIterations(ACount: Int64);
begin
  FIterations := ACount;
end;

procedure TBenchmark.SetDataSize(ABytes: Int64);
begin
  FDataSize := ABytes;
end;

function TBenchmark.ElapsedMs: Double;
begin
  Result := FEndTime - FStartTime;
end;

function TBenchmark.OpsPerSecond: Double;
var
  Seconds: Double;
begin
  Seconds := ElapsedMs / 1000.0;
  if Seconds > 0 then
    Result := FIterations / Seconds
  else
    Result := 0;
end;

function TBenchmark.ThroughputMBps: Double;
var
  Seconds: Double;
begin
  Seconds := ElapsedMs / 1000.0;
  if Seconds > 0 then
    Result := (FDataSize / 1024.0 / 1024.0) / Seconds
  else
    Result := 0;
end;

procedure TBenchmark.Report;
begin
  WriteLn(Format('%-40s: %8.2f ms  (%10.0f ops/sec)', 
    [FName, ElapsedMs, OpsPerSecond]));
end;

procedure TBenchmark.ReportThroughput;
begin
  WriteLn(Format('%-40s: %8.2f ms  (%10.2f MB/s)', 
    [FName, ElapsedMs, ThroughputMBps]));
end;

{ TStats }

class function TStats.Mean(const AValues: array of Double): Double;
var
  I: Integer;
  Sum: Double;
begin
  Sum := 0;
  for I := Low(AValues) to High(AValues) do
    Sum := Sum + AValues[I];
  Result := Sum / Length(AValues);
end;

class function TStats.Median(const AValues: array of Double): Double;
var
  Sorted: array of Double;
  I, Mid: Integer;
begin
  SetLength(Sorted, Length(AValues));
  for I := 0 to High(AValues) do
    Sorted[I] := AValues[I];
    
  // Simple bubble sort (fine for small arrays)
  for I := 0 to High(Sorted) - 1 do
    for Mid := I + 1 to High(Sorted) do
      if Sorted[I] > Sorted[Mid] then
      begin
        Result := Sorted[I];
        Sorted[I] := Sorted[Mid];
        Sorted[Mid] := Result;
      end;
      
  Mid := Length(Sorted) div 2;
  if Length(Sorted) mod 2 = 0 then
    Result := (Sorted[Mid - 1] + Sorted[Mid]) / 2
  else
    Result := Sorted[Mid];
end;

class function TStats.Percentile(const AValues: array of Double; P: Double): Double;
var
  Sorted: array of Double;
  I, Idx: Integer;
  Temp: Double;
begin
  SetLength(Sorted, Length(AValues));
  for I := 0 to High(AValues) do
    Sorted[I] := AValues[I];
    
  // Bubble sort
  for I := 0 to High(Sorted) - 1 do
    for Idx := I + 1 to High(Sorted) do
      if Sorted[I] > Sorted[Idx] then
      begin
        Temp := Sorted[I];
        Sorted[I] := Sorted[Idx];
        Sorted[Idx] := Temp;
      end;
      
  Idx := Trunc(P * Length(Sorted));
  if Idx >= Length(Sorted) then
    Idx := High(Sorted);
  Result := Sorted[Idx];
end;

class function TStats.StdDev(const AValues: array of Double): Double;
var
  I: Integer;
  Avg, Sum: Double;
begin
  Avg := Mean(AValues);
  Sum := 0;
  for I := Low(AValues) to High(AValues) do
    Sum := Sum + Sqr(AValues[I] - Avg);
  Result := Sqrt(Sum / Length(AValues));
end;

{ Console formatting }

procedure PrintHeader(const AText: string);
begin
  WriteLn;
  WriteLn('=' + StringOfChar('=', Length(AText) + 2) + '=');
  WriteLn('  ' + AText);
  WriteLn('=' + StringOfChar('=', Length(AText) + 2) + '=');
  WriteLn;
end;

procedure PrintResult(const AName: string; AValue: Double; const AUnit: string);
begin
  WriteLn(Format('  %-35s: %12.2f %s', [AName, AValue, AUnit]));
end;

procedure PrintSeparator;
begin
  WriteLn(StringOfChar('-', 70));
end;

end.
