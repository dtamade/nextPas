program bitscan_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

var
  GData: array[0..N-1] of UInt64;
  GSink: Integer;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GData[I] := UInt64(I * 6364136223846793005 + 1442695040888963407) or (1 shl (I mod 64));
end;

procedure BenchBsfQWord(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Integer;
  LVal: QWord;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := GData[I];
    if LVal <> 0 then
      LSum += BsfQWord(LVal);
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(UInt64));
end;

procedure BenchBsrQWord(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Integer;
  LVal: QWord;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := GData[I];
    if LVal <> 0 then
      LSum += BsrQWord(LVal);
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(UInt64));
end;

procedure BenchBsfBsr(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Integer;
  LVal: QWord;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := GData[I];
    if LVal <> 0 then
      LSum += BsfQWord(LVal) + BsrQWord(LVal);
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(UInt64));
end;

procedure BenchByteSwap(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: QWord;
  LVal: QWord;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := Swap(GData[I]);
    LSum += LVal;
  end;
  GSink := Integer(LSum);
  ACtx.SetBytes(N * SizeOf(UInt64));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('bitscan');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('BsfQWord/100K', @BenchBsfQWord);
  LSuite.Add('BsrQWord/100K', @BenchBsrQWord);
  LSuite.Add('BsfBsr/100K', @BenchBsfBsr);
  LSuite.Add('ByteSwap/100K', @BenchByteSwap);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
