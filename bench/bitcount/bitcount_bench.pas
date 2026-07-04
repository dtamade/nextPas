program bitcount_bench;

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
  GSink: QWord;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N-1 do
    GData[I] := UInt64(I * 6364136223846793005 + 1442695040888963407);
end;

procedure BenchPopCnt64(const ACtx: IBenchContext);
var
  I: Integer;
  LVal: QWord;
  LSum: QWord;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := QWord(GData[I]);
    LSum += PopCnt(LVal);
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(UInt64));
end;

procedure BenchPopCntAccum(const ACtx: IBenchContext);
var
  I: Integer;
  LVal: QWord;
  LSum: QWord;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := QWord(GData[I]);
    LSum += PopCnt(LVal);
    LVal := LVal xor $FFFFFFFFFFFFFFFF;
    LSum += PopCnt(LVal);
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(UInt64) * 2);
end;

procedure BenchBitReverse(const ACtx: IBenchContext);
var
  I: Integer;
  LVal, LRev: UInt64;
  LSum: UInt64;
begin
  LSum := 0;
  for I := 0 to N-1 do
  begin
    LVal := GData[I];
    LRev := 0;
    while LVal <> 0 do
    begin
      LRev := (LRev shl 1) or (LVal and 1);
      LVal := LVal shr 1;
    end;
    LSum += LRev;
  end;
  GSink := LSum;
  ACtx.SetBytes(N * SizeOf(UInt64));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('bitcount');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('PopCnt/100K', @BenchPopCnt64);
  LSuite.Add('PopCntAccum/200K', @BenchPopCntAccum);
  LSuite.Add('BitReverse/100K', @BenchBitReverse);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
