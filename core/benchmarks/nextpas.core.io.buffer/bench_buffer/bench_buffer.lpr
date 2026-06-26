program bench_buffer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.io.intf,
  nextpas.core.io.buffer,
  nextpas.core.io.memory;

var
  LResults: IBenchResults;
  GSink: SizeUInt;

type
  TZeroReader = class(TInterfacedObject, IReader)
  public
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TNullWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TZeroReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  FillChar(ABuf, ACount, 0);
  Result := ACount;
end;

function TNullWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

procedure BenchBufferedRead_1Byte(aIters: Int64);
var
  LIt: Int64;
  LReader: IReader;
  LBuf: Byte;
begin
  LReader := CreateBufferedReader(TZeroReader.Create as IReader, 4096);
  for LIt := 1 to aIters do
    GSink := LReader.Read(LBuf, 1);
end;

procedure BenchBufferedRead_64(aIters: Int64);
var
  LIt: Int64;
  LReader: IReader;
  LBuf: array[0..63] of Byte;
begin
  LReader := CreateBufferedReader(TZeroReader.Create as IReader, 4096);
  for LIt := 1 to aIters do
    GSink := LReader.Read(LBuf[0], 64);
end;

procedure BenchBufferedRead_4K(aIters: Int64);
var
  LIt: Int64;
  LReader: IReader;
  LBuf: array[0..4095] of Byte;
begin
  LReader := CreateBufferedReader(TZeroReader.Create as IReader, 4096);
  for LIt := 1 to aIters do
    GSink := LReader.Read(LBuf[0], 4096);
end;

procedure BenchBufferedWrite_1Byte(aIters: Int64);
var
  LIt: Int64;
  LWriter: IWriter;
  LBuf: Byte;
begin
  LBuf := $AA;
  LWriter := CreateBufferedWriter(TNullWriter.Create as IWriter, 4096);
  for LIt := 1 to aIters do
    GSink := LWriter.Write(LBuf, 1);
end;

procedure BenchBufferedWrite_64(aIters: Int64);
var
  LIt: Int64;
  LWriter: IWriter;
  LBuf: array[0..63] of Byte;
begin
  FillChar(LBuf[0], 64, $BB);
  LWriter := CreateBufferedWriter(TNullWriter.Create as IWriter, 4096);
  for LIt := 1 to aIters do
    GSink := LWriter.Write(LBuf[0], 64);
end;

procedure BenchBufferedWrite_4K(aIters: Int64);
var
  LIt: Int64;
  LWriter: IWriter;
  LBuf: array[0..4095] of Byte;
begin
  FillChar(LBuf[0], 4096, $CC);
  LWriter := CreateBufferedWriter(TNullWriter.Create as IWriter, 4096);
  for LIt := 1 to aIters do
    GSink := LWriter.Write(LBuf[0], 4096);
end;

procedure BenchUnbufferedRead_1Byte(aIters: Int64);
var
  LIt: Int64;
  LReader: IReader;
  LBuf: Byte;
begin
  LReader := TZeroReader.Create as IReader;
  for LIt := 1 to aIters do
    GSink := LReader.Read(LBuf, 1);
end;

begin
  WriteLn('=== nextpas.core.io.buffer benchmark ===');
  WriteLn;
  LResults := TBenchSuite.Create('BufferedRead 1 byte')
    .AddLoop('BufferedRead 1 byte', @BenchBufferedRead_1Byte)
    .AddLoop('BufferedRead 64 bytes', @BenchBufferedRead_64)
    .AddLoop('BufferedRead 4KB', @BenchBufferedRead_4K)
    .AddLoop('BufferedWrite 1 byte', @BenchBufferedWrite_1Byte)
    .AddLoop('BufferedWrite 64 bytes', @BenchBufferedWrite_64)
    .AddLoop('BufferedWrite 4KB', @BenchBufferedWrite_4K)
    .AddLoop('Unbuffered Read 1 byte (baseline)', @BenchUnbufferedRead_1Byte)
    .Run;
  WriteLn(LResults.PrintToConsole);
end.
