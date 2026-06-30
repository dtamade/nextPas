{$mode ObjFPC}{$H+}
program bytefreq_bench;
uses SysUtils, Classes,
  nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf;
const
  N = 10000;
  SZ = 4096;
type TBuf = array[0..SZ-1] of Byte;
var GA: TBuf;
procedure InitData;
var I: Integer;
begin
  for I := 0 to SZ-1 do
    GA[I] := Byte((I * 7 + 13) and 255);
end;
procedure BenchByteFrequency(const ACtx: IBenchContext);
var I, J: Integer; Freq: array[0..255] of Integer;
begin
  for I := 1 to N do begin
    FillChar(Freq, SizeOf(Freq), 0);
    for J := 0 to SZ-1 do
      Inc(Freq[GA[J]]);
  end;
  if Freq[0] < 0 then WriteLn('');
end;
procedure BenchArrayReverse(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J, Tmp: Integer; A: array[0..ARR_SZ-1] of Integer;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I;
  for I := 1 to N do begin
    for J := 0 to (ARR_SZ div 2) - 1 do begin
      Tmp := A[J];
      A[J] := A[ARR_SZ - 1 - J];
      A[ARR_SZ - 1 - J] := Tmp;
    end;
  end;
  if A[0] < 0 then WriteLn('');
end;
procedure BenchArrayRotate(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J, First: Integer; A: array[0..ARR_SZ-1] of Integer;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I;
  for I := 1 to N do begin
    // Left rotate by 1
    First := A[0];
    for J := 0 to ARR_SZ-2 do
      A[J] := A[J+1];
    A[ARR_SZ-1] := First;
  end;
  if A[0] < 0 then WriteLn('');
end;
var LSuite: IBenchSuite; LResults: IBenchResults;
begin
  InitData;
  LSuite := TBenchSuite.Create('ArrayOps');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('ByteFrequency/4KB×100K', @BenchByteFrequency);
  LSuite.Add('ArrayReverse/10K×100K', @BenchArrayReverse);
  LSuite.Add('ArrayRotate/10K×100K', @BenchArrayRotate);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
