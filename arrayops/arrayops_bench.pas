{$mode ObjFPC}{$H+}
program bytefreq_bench;
uses
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
    First := A[0];
    for J := 0 to ARR_SZ-2 do
      A[J] := A[J+1];
    A[ARR_SZ-1] := First;
  end;
  if A[0] < 0 then WriteLn('');
end;
procedure BenchArraySum(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J: Integer; S: Int64; A: array[0..ARR_SZ-1] of Int64;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I;
  for I := 1 to N do begin
    S := 0;
    for J := 0 to ARR_SZ-1 do
      S := S + A[J];
  end;
  if S < 0 then WriteLn('');
end;
procedure BenchLinearSearch(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J, Found: Integer; A: array[0..ARR_SZ-1] of Integer;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I * 3 + 7;
  for I := 1 to N do begin
    Found := -1;
    for J := 0 to ARR_SZ-1 do
      if A[J] = 29998 then begin Found := J; Break; end;
  end;
  if Found < 0 then WriteLn('');
end;
procedure BenchCountEven(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J, Count: Integer; A: array[0..ARR_SZ-1] of Integer;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I;
  for I := 1 to N do begin
    Count := 0;
    for J := 0 to ARR_SZ-1 do
      if (A[J] and 1) = 0 then Inc(Count);
  end;
  if Count < 0 then WriteLn('');
end;
procedure BenchFloatArraySum(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J: Integer; S: Double; A: array[0..ARR_SZ-1] of Double;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I * 0.5;
  for I := 1 to N do begin
    S := 0.0;
    for J := 0 to ARR_SZ-1 do
      S := S + A[J];
  end;
  if S < 0 then WriteLn('');
end;
procedure BenchFloatArrayDot(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J: Integer; S: Double; A, B: array[0..ARR_SZ-1] of Double;
begin
  for I := 0 to ARR_SZ-1 do begin A[I] := I * 0.5; B[I] := I * 0.3; end;
  for I := 1 to N do begin
    S := 0.0;
    for J := 0 to ARR_SZ-1 do
      S := S + A[J] * B[J];
  end;
  if S < 0 then WriteLn('');
end;
procedure BenchFloatArrayMinMax(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J: Integer; LMin, LMax, V: Double; A: array[0..ARR_SZ-1] of Double;
begin
  for I := 0 to ARR_SZ-1 do A[I] := (I * 17 + 3) mod 1000 - 500;
  for I := 1 to N do begin
    LMin := A[0]; LMax := A[0];
    for J := 1 to ARR_SZ-1 do begin
      V := A[J];
      if V < LMin then LMin := V;
      if V > LMax then LMax := V;
    end;
  end;
  if LMin > LMax then WriteLn('');
end;
procedure BenchIntArrayFilter(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J, Cnt: Integer; A: array[0..ARR_SZ-1] of Integer; R: array[0..ARR_SZ-1] of Integer;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I;
  for I := 1 to N do begin
    Cnt := 0;
    for J := 0 to ARR_SZ-1 do
      if (A[J] and 1) = 0 then begin R[Cnt] := A[J]; Inc(Cnt); end;
  end;
  if Cnt < 0 then WriteLn('');
end;
procedure BenchFloatArrayNorm(const ACtx: IBenchContext);
const ARR_SZ = 10000;
var I, J: Integer; S: Double; A: array[0..ARR_SZ-1] of Double;
begin
  for I := 0 to ARR_SZ-1 do A[I] := I * 0.001;
  for I := 1 to N do begin
    S := 0.0;
    for J := 0 to ARR_SZ-1 do
      S := S + A[J] * A[J];
    S := Sqrt(S);
  end;
  if S < 0 then WriteLn('');
end;
var LSuite: IBenchSuite; LResults: IBenchResults;
begin
  InitData;
  LSuite := TBenchSuite.Create('ArrayOps');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('ByteFrequency/4KB×100K', @BenchByteFrequency);
  LSuite.Add('ArrayReverse/10K×100K', @BenchArrayReverse);
  LSuite.Add('ArrayRotate/10K×100K', @BenchArrayRotate);
  LSuite.Add('ArraySum/10Kx10K', @BenchArraySum);
  LSuite.Add('LinearSearch/10Kx10K', @BenchLinearSearch);
  LSuite.Add('CountEven/10Kx10K', @BenchCountEven);
  LSuite.Add('FloatArraySum/10Kx10K', @BenchFloatArraySum);
  LSuite.Add('FloatArrayDot/10Kx10K', @BenchFloatArrayDot);
  LSuite.Add('FloatArrayMinMax/10Kx10K', @BenchFloatArrayMinMax);
  LSuite.Add('IntArrayFilter/10Kx10K', @BenchIntArrayFilter);
  LSuite.Add('FloatArrayNorm/10Kx10K', @BenchFloatArrayNorm);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
