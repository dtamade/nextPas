program bench_bytes;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.base, nextpas.core.bytes.base, nextpas.core.bytes.ops,
  nextpas.core.bytes.binary, nextpas.core.bytes.builder;
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
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('bytes');
  LSuite.Add('SpanEqual/1KB', @BenchSpanEqual1KB).Add('SpanIndexOf/4KB', @BenchSpanIndexOf4KB)
    .Add('SwapUInt64', @BenchSwapUInt64).Add('ReadUInt32LE', @BenchReadUInt32LE)
    .Add('Builder/Append1MB', @BenchBuilderAppend1MB).Add('Builder/AppendByte/64KB', @BenchBuilderAppendByte64KB)
    .Add('TryReadCursor/4KB', @BenchTryReadCursor4KB);
  WriteLn(LSuite.Run.PrintToConsole);
end.
