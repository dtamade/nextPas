program bench_bytes_ops;
{$mode objfpc}{$H+}
uses
  SysUtils, Unix, BaseUnix,
  nextpas.core.base,
  nextpas.core.bytes.ops;

function GetTimeNs: Int64;
var LTs: TTimeVal;
begin
  fpgettimeofday(@LTs, nil);
  Result := Int64(LTs.tv_sec) * 1000000000 + Int64(LTs.tv_usec) * 1000;
end;

const
  BUF_SIZE = 4096;
  ITERS = 200000;
var
  bufA, bufB: array[0..BUF_SIZE-1] of Byte;
  spanA, spanB: TByteSpan;
  i, j: Integer;
  t0, t1: Int64;
  dummy: Boolean;
  dummyIdx: SizeInt;
begin
  for i := 0 to BUF_SIZE-1 do
  begin
    bufA[i] := Byte(i mod 256);
    bufB[i] := Byte(i mod 256);
  end;
  spanA.Data := @bufA[0]; spanA.Len := BUF_SIZE;
  spanB.Data := @bufB[0]; spanB.Len := BUF_SIZE;

  // Warmup
  for j := 0 to 99 do dummy := SpanEqual(spanA, spanB);

  // SpanEqual
  t0 := GetTimeNs;
  for j := 0 to ITERS-1 do
    dummy := SpanEqual(spanA, spanB);
  t1 := GetTimeNs;
  WriteLn(Format('SpanEqual %d bytes: %.0f ns/call (%.2f GB/s)',
    [BUF_SIZE, (t1-t0)/ITERS, BUF_SIZE / ((t1-t0)/ITERS)]));

  // SpanIndexOf (needle at end)
  bufA[BUF_SIZE-1] := $AA;
  spanA.Data := @bufA[0]; spanA.Len := BUF_SIZE;
  t0 := GetTimeNs;
  for j := 0 to ITERS-1 do
    dummyIdx := SpanIndexOf(spanA, $AA);
  t1 := GetTimeNs;
  WriteLn(Format('SpanIndexOf %d bytes (needle at end): %.0f ns/call (%.2f GB/s)',
    [BUF_SIZE, (t1-t0)/ITERS, BUF_SIZE / ((t1-t0)/ITERS)]));
  bufA[BUF_SIZE-1] := Byte((BUF_SIZE-1) mod 256);

  // SpanStartsWith (256 byte prefix)
  t0 := GetTimeNs;
  spanB.Len := 256;
  for j := 0 to ITERS-1 do
    dummy := SpanStartsWith(spanA, spanB);
  t1 := GetTimeNs;
  WriteLn(Format('SpanStartsWith 256-byte prefix: %.0f ns/call',
    [(t1-t0)/ITERS]));

  // SpanReverse
  t0 := GetTimeNs;
  for j := 0 to ITERS-1 do
    SpanReverse(spanA);
  t1 := GetTimeNs;
  WriteLn(Format('SpanReverse %d bytes: %.0f ns/call (%.2f GB/s)',
    [BUF_SIZE, (t1-t0)/ITERS, BUF_SIZE / ((t1-t0)/ITERS)]));

  WriteLn;
  WriteLn('Correctness: ', dummy, ' idx=', dummyIdx);
end.
