program bench_bytes;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base, nextpas.core.bytes.base, nextpas.core.bytes.ops,
  nextpas.core.bytes.binary, nextpas.core.bytes.builder,
  nextpas.core.fs;
const SIZE_1MB = 1024 * 1024;
var GSpanData: TBytes; GSwapVal: UInt64; GReadBuf: array[0..1023] of Byte;
procedure InitData;
var LI: Integer;
begin
  SetLength(GSpanData, 4096);
  for LI := 0 to 4095 do GSpanData[LI] := Byte(LI and $FF);
  GSpanData[4095] := $FE; GSwapVal := $0102030405060708;
  for LI := 0 to 1023 do GReadBuf[LI] := Byte(LI);
end;
procedure BenchSpanEqual1KB(const ACtx: IBenchContext);
var LA, LB: TBytes; LSA, LSB: TByteSpan; LDummy: Boolean;
begin
  SetLength(LA, 1024); SetLength(LB, 1024);
  LSA := TByteSpan.FromBytes(LA); LSB := TByteSpan.FromBytes(LB);
  LDummy := SpanEqual(LSA, LSB); ACtx.SetBytes(1024);
end;
procedure BenchSpanIndexOf4KB(const ACtx: IBenchContext);
var LSA: TByteSpan; LDummy: SizeInt;
begin LSA := TByteSpan.FromBytes(GSpanData); LDummy := SpanIndexOf(LSA, $FE); ACtx.SetBytes(4096); end;
procedure BenchSwapUInt64(const ACtx: IBenchContext);
begin GSwapVal := SwapUInt64(GSwapVal); end;
procedure BenchReadUInt32LE(const ACtx: IBenchContext);
var LDummy: UInt32;
begin LDummy := ReadUInt32LE(@GReadBuf[0]); end;
procedure BenchBuilderAppend1MB(const ACtx: IBenchContext);
var LB: IBytesBuilder; LData: array[0..4095] of Byte; LI: Integer;
begin
  for LI := 0 to 4095 do LData[LI] := Byte(LI and $FF);
  LB := CreateBytesBuilder(SIZE_1MB);
  while LB.Length < SIZE_1MB do LB.AppendBytes(@LData[0], 4096);
  ACtx.SetBytes(SIZE_1MB);
end;
procedure BenchBuilderAppendByte64KB(const ACtx: IBenchContext);
var LB: IBytesBuilder; LJ: Integer;
begin LB := CreateBytesBuilder(65536); for LJ := 0 to 65535 do LB.AppendByte(Byte(LJ)); ACtx.SetBytes(65536); end;
procedure BenchTryReadCursor4KB(const ACtx: IBenchContext);
var LS: TByteSpan; LVal: UInt32;
begin LS := TByteSpan.FromBytes(GSpanData); while TryReadUInt32LE(LS, LVal) do { }; ACtx.SetBytes(4096); end;
var LResults: IBenchResults;
begin
  InitData;
  LResults := TBenchSuite.Create('bytes')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('bytes/SpanEqual/1KB', @BenchSpanEqual1KB)
    .Add('bytes/SpanIndexOf/4KB', @BenchSpanIndexOf4KB)
    .Add('bytes/SwapUInt64', @BenchSwapUInt64)
    .Add('bytes/ReadUInt32LE', @BenchReadUInt32LE)
    .Add('bytes/Builder/Append1MB', @BenchBuilderAppend1MB)
    .Add('bytes/Builder/AppendByte/64KB', @BenchBuilderAppendByte64KB)
    .Add('bytes/TryReadCursor/4KB', @BenchTryReadCursor4KB)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-bytes.json');
end.
