program bench_readbyte;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.base,
  nextpas.core.io.intf, nextpas.core.io.memory, nextpas.core.io.buffer;

const
  PAYLOAD_LEN = 256 * 1024;

var
  GPayload: TBytes;

procedure InitData;
var
  I: Integer;
begin
  SetLength(GPayload, PAYLOAD_LEN);
  for I := 0 to PAYLOAD_LEN - 1 do
    GPayload[I] := Byte(I * 7 + $5A);
end;

{ 基线一:无缓冲——每字节一次虚接口派发 Read }
procedure BenchUnbufferedReader(const ACtx: IBenchContext);
var
  LStream: IReader;
  LB: Byte;
  I: Integer;
begin
  LStream := CreateBytesStreamFrom(GPayload);
  for I := 0 to PAYLOAD_LEN - 1 do
    if LStream.Read(LB, 1) = 1 then
      LB := LB + 1;
  ACtx.SetBytes(PAYLOAD_LEN);
end;

{ 主角:缓冲读 + FBufPos<FBufLen 直读快路径 }
procedure BenchBufferedReadByte(const ACtx: IBenchContext);
var
  LStream: IStream;
  LBuf: IReader;
  LByteView: IByteReader;
  LSum: Cardinal;
  I: Integer;
begin
  LStream := CreateBytesStreamFrom(GPayload);
  LBuf := CreateBufferedReader(LStream);
  LByteView := LBuf as IByteReader;
  LSum := 0;
  for I := 0 to PAYLOAD_LEN - 1 do
    Inc(LSum, LByteView.ReadByte);
  ACtx.SetBytes(PAYLOAD_LEN);
end;

{ 理论下限:裸动态数组索引,零派发 }
procedure BenchArrayFloor(const ACtx: IBenchContext);
var
  LSum: Cardinal;
  I: Integer;
begin
  LSum := 0;
  for I := 0 to PAYLOAD_LEN - 1 do
    Inc(LSum, GPayload[I]);
  ACtx.SetBytes(PAYLOAD_LEN);
end;

var
  LResults: IBenchResults;
begin
  InitData;
  LResults := TBenchSuite.Create('io.buffer.readbyte')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('readbyte/unbuffered', @BenchUnbufferedReader)
    .Add('readbyte/buffered', @BenchBufferedReadByte)
    .Add('readbyte/array-floor', @BenchArrayFloor)
    .Run;
  WriteLn(LResults.PrintToConsole);
end.
