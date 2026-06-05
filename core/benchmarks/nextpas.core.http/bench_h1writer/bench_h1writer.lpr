program bench_h1writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h1.writer;

type
  TFixedMemoryWriter = class(TInterfacedObject, IWriter)
  private
    FBuffer: array[0..8191] of Byte;
    FSize: SizeUInt;
  public
    procedure Reset;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Size: SizeUInt;
  end;

var
  B: TBenchRunner;
  GBytesWritten: SizeUInt;

procedure TFixedMemoryWriter.Reset;
begin
  FSize := 0;
end;

function TFixedMemoryWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LAvailable: SizeUInt;
begin
  LAvailable := SizeUInt(Length(FBuffer)) - FSize;
  Result := ACount;
  if Result > LAvailable then
    Result := LAvailable;
  if Result > 0 then
  begin
    Move(ABuf, FBuffer[FSize], Result);
    Inc(FSize, Result);
  end;
end;

function TFixedMemoryWriter.Size: SizeUInt;
begin
  Result := FSize;
end;

procedure BenchHeadersOnly200(aIters: Int64);
var
  LIt: Int64;
  LSink: TFixedMemoryWriter;
  LSinkWriter: IWriter;
  LWriter: TH1ResponseWriter;
begin
  LSink := TFixedMemoryWriter.Create;
  LSinkWriter := LSink as IWriter;
  try
    for LIt := 1 to aIters do
    begin
      LSink.Reset;
      LWriter := TH1ResponseWriter.Create(LSinkWriter);
      try
        LWriter.Headers.Set_('content-type', 'text/plain');
        LWriter.Headers.Set_('content-length', '0');
        LWriter.WriteHeader(HTTP_STATUS_OK);
        LWriter.Flush;
        Inc(GBytesWritten, LSink.Size);
      finally
        LWriter.Free;
      end;
    end;
  finally
    LSinkWriter := nil;
  end;
end;

procedure BenchHeadersBlock200_6Headers(aIters: Int64);
var
  LIt: Int64;
  LSink: TFixedMemoryWriter;
  LSinkWriter: IWriter;
  LWriter: TH1ResponseWriter;
begin
  LSink := TFixedMemoryWriter.Create;
  LSinkWriter := LSink as IWriter;
  try
    for LIt := 1 to aIters do
    begin
      LSink.Reset;
      LWriter := TH1ResponseWriter.Create(LSinkWriter);
      try
        LWriter.Headers.Set_('date', 'Sat, 06 Jun 2026 00:00:00 GMT');
        LWriter.Headers.Set_('server', 'nextpas');
        LWriter.Headers.Set_('content-type', 'text/plain');
        LWriter.Headers.Set_('content-length', '0');
        LWriter.Headers.Set_('cache-control', 'no-store');
        LWriter.Headers.Set_('x-request-id', '0123456789abcdef');
        LWriter.WriteHeader(HTTP_STATUS_OK);
        LWriter.Flush;
        Inc(GBytesWritten, LSink.Size);
      finally
        LWriter.Free;
      end;
    end;
  finally
    LSinkWriter := nil;
  end;
end;

procedure BenchFixed200_13B(aIters: Int64);
const
  RESPONSE_BODY: AnsiString = 'Hello, World!';
var
  LIt: Int64;
  LSink: TFixedMemoryWriter;
  LSinkWriter: IWriter;
  LWriter: TH1ResponseWriter;
begin
  LSink := TFixedMemoryWriter.Create;
  LSinkWriter := LSink as IWriter;
  try
    for LIt := 1 to aIters do
    begin
      LSink.Reset;
      LWriter := TH1ResponseWriter.Create(LSinkWriter);
      try
        LWriter.Headers.Set_('content-type', 'text/plain');
        LWriter.Headers.Set_('content-length', '13');
        LWriter.WriteHeader(HTTP_STATUS_OK);
        LWriter.Write(RESPONSE_BODY[1], SizeUInt(Length(RESPONSE_BODY)));
        LWriter.Flush;
        Inc(GBytesWritten, LSink.Size);
      finally
        LWriter.Free;
      end;
    end;
  finally
    LSinkWriter := nil;
  end;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http.h1writer benchmark ===');
  WriteLn('operation=http.h1writer.serialize');
  WriteLn;
  B.Run('headers only 200', @BenchHeadersOnly200);
  B.Run('headers block 200 6 headers', @BenchHeadersBlock200_6Headers);
  B.Run('fixed 200 13B', @BenchFixed200_13B);
  WriteLn;
  B.Summary;
  B.Free;
end.
