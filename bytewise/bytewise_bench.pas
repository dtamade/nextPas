{$mode ObjFPC}{$H+}
program bytearray_bench;
uses
  nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf;
const
  N = 100000;
  SZ = 4096;
type TBuf = array[0..SZ-1] of Byte;
var
  GA, GB, GC: TBuf;
procedure InitData;
var I: Integer;
begin
  for I := 0 to SZ-1 do begin
    GA[I] := Byte(I * 7 + 13);
    GB[I] := Byte(I * 3 + 29);
  end;
end;
procedure BenchMemZero(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 1 to N do
    FillChar(GC, SZ, 0);
end;
procedure BenchBufferXor(const ACtx: IBenchContext);
var I, J: Integer;
begin
  for I := 1 to N do
    for J := 0 to SZ-1 do
      GC[J] := GA[J] xor GB[J];
end;
procedure BenchWordCount(const ACtx: IBenchContext);
const
  TEXT_LEN = 1024 * 100; // 100 KB
  NUM_ITERS = 1000;
type TTextBuf = array[0..TEXT_LEN-1] of Byte;
var
  LTextBuf: TTextBuf;
  I, J, Count: Integer;
begin
  for J := 0 to TEXT_LEN-1 do
    if (J mod 6 = 0) then LTextBuf[J] := 32
    else if (J mod 50 = 0) then LTextBuf[J] := 10
    else LTextBuf[J] := Byte(65 + (J mod 26));
  for I := 1 to NUM_ITERS do begin
    Count := 0;
    for J := 0 to TEXT_LEN-1 do
      if LTextBuf[J] = 32 then Inc(Count);
  end;
end;
procedure BenchBufferAnd(const ACtx: IBenchContext);
var I, J: Integer;
begin
  for I := 1 to N do
    for J := 0 to SZ-1 do
      GC[J] := GA[J] and GB[J];
end;
procedure BenchBufferNot(const ACtx: IBenchContext);
var I, J: Integer;
begin
  for I := 1 to N do
    for J := 0 to SZ-1 do
      GC[J] := not GA[J];
end;
var LSuite: IBenchSuite; LResults: IBenchResults;
begin
  InitData;
  LSuite := TBenchSuite.Create('ByteWise');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('MemZero/4KB×100K', @BenchMemZero);
  LSuite.Add('BufferXor/4KB×100K', @BenchBufferXor);
  LSuite.Add('WordCount/100KB×1K', @BenchWordCount);
  LSuite.Add('BufferAnd/4KB×100K', @BenchBufferAnd);
  LSuite.Add('BufferNot/4KB×100K', @BenchBufferNot);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
