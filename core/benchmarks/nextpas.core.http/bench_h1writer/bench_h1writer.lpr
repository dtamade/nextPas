program bench_h1writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h1.writer,
  nextpas.core.http.impl.h1.outbound;

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
  GBody1K: AnsiString;
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

procedure InitBody1K;
begin
  SetLength(GBody1K, 1024);
  FillChar(GBody1K[1], Length(GBody1K), Ord('x'));
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

procedure BenchStatusLinesCommonErrors(aIters: Int64);
var
  LIt: Int64;
  LSink: TFixedMemoryWriter;
  LSinkWriter: IWriter;
  LWriter: TH1ResponseWriter;
  LStatus: THttpStatus;
begin
  LSink := TFixedMemoryWriter.Create;
  LSinkWriter := LSink as IWriter;
  try
    for LIt := 1 to aIters do
    begin
      case LIt mod 7 of
        0: LStatus := HTTP_STATUS_BAD_REQUEST;
        1: LStatus := HTTP_STATUS_NOT_FOUND;
        2: LStatus := HTTP_STATUS_PAYLOAD_TOO_LARGE;
        3: LStatus := HTTP_STATUS_EXPECTATION_FAILED;
        4: LStatus := HTTP_STATUS_HEADER_TOO_LARGE;
        5: LStatus := HTTP_STATUS_INTERNAL_SERVER_ERROR;
      else
        LStatus := HTTP_STATUS_NOT_IMPLEMENTED;
      end;

      LSink.Reset;
      LWriter := TH1ResponseWriter.Create(LSinkWriter);
      try
        LWriter.Headers.Set_('content-length', '0');
        LWriter.WriteHeader(LStatus);
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

procedure BenchOutboundFixed200_1KB(aIters: Int64);
var
  LIt: Int64;
  LSink: TFixedMemoryWriter;
  LSinkWriter: IWriter;
  LOutbound: IH1OutboundBuffer;
  LWriter: TH1ResponseWriter;
begin
  LSink := TFixedMemoryWriter.Create;
  LSinkWriter := LSink as IWriter;
  try
    for LIt := 1 to aIters do
    begin
      LSink.Reset;
      LOutbound := NewH1OutboundBuffer;
      LWriter := TH1ResponseWriter.Create(LOutbound as IWriter);
      try
        LWriter.Headers.Set_('content-type', 'application/octet-stream');
        LWriter.Headers.Set_('content-length', '1024');
        LWriter.WriteHeader(HTTP_STATUS_OK);
        LWriter.Write(GBody1K[1], SizeUInt(Length(GBody1K)));
        LWriter.Flush;
        LOutbound.DrainAllTo(LSinkWriter);
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
  InitBody1K;
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.http.h1writer benchmark ===');
  WriteLn('operation=http.h1writer.serialize');
  WriteLn;
  B.Run('headers only 200', @BenchHeadersOnly200);
  B.Run('headers block 200 6 headers', @BenchHeadersBlock200_6Headers);
  B.Run('status lines common errors', @BenchStatusLinesCommonErrors);
  B.Run('fixed 200 13B', @BenchFixed200_13B);
  B.Run('outbound fixed 200 1KB', @BenchOutboundFixed200_1KB);
  WriteLn;
  B.Summary;
  B.Free;
end.
