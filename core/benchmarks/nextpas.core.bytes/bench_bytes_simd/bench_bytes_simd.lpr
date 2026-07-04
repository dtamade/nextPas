program bench_bytes_simd;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.base, nextpas.core.bytes.base, nextpas.core.bytes.ops;
const BUF_SIZE = 4096;
var bufA, bufB: array[0..BUF_SIZE-1] of Byte; spanA, spanB: TByteSpan; GDummy: Boolean; GDummyIdx: SizeInt;
procedure InitData;
var LI: Integer;
begin
  for LI := 0 to BUF_SIZE-1 do begin bufA[LI] := Byte(LI mod 256); bufB[LI] := Byte(LI mod 256); end;
  spanA.Data := @bufA[0]; spanA.Len := BUF_SIZE; spanB.Data := @bufB[0]; spanB.Len := BUF_SIZE;
end;
procedure BenchSpanEqual(const ACtx: IBenchContext);
begin GDummy := SpanEqual(spanA, spanB); ACtx.SetBytes(BUF_SIZE); end;
procedure BenchSpanIndexOf(const ACtx: IBenchContext);
begin GDummyIdx := SpanIndexOf(spanA, $AA); ACtx.SetBytes(BUF_SIZE); end;
procedure BenchSpanStartsWith(const ACtx: IBenchContext);
var LPrefix: TByteSpan;
begin LPrefix.Data := @bufB[0]; LPrefix.Len := 256; GDummy := SpanStartsWith(spanA, LPrefix); ACtx.SetBytes(256); end;
procedure BenchSpanCopy(const ACtx: IBenchContext);
var LDst: array[0..BUF_SIZE-1] of Byte; LDstSpan: TByteSpan;
begin LDstSpan.Data := @LDst[0]; LDstSpan.Len := BUF_SIZE; SpanCopy(spanA, LDstSpan); ACtx.SetBytes(BUF_SIZE); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('bytes-simd');
  LSuite.Add('SpanEqual/4KB', @BenchSpanEqual).Add('SpanIndexOf/4KB', @BenchSpanIndexOf)
    .Add('SpanStartsWith/256B', @BenchSpanStartsWith).Add('SpanCopy/4KB', @BenchSpanCopy);
  WriteLn(LSuite.Run.PrintToConsole);
end.
