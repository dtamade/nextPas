program test_http_stream;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.stream;


type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter, IHttpResponseBodyBytes)
  private
    FStatus: THttpStatus;
    FBody: string;
    FBodyBytes: TBytes;
    FHeaders: IHttpHeaders;
    FBodyBytesWritten: Int64;
    FMaxWriteSize: SizeUInt;
    FRaiseOnWrite: Boolean;
    FWriteHeaderCount: Int32;
    FFlushCount: Int32;
  public
    constructor Create;
    procedure SetMaxWriteSize(const AValue: SizeUInt);
    procedure SetRaiseOnWrite(const AValue: Boolean);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function GetBodyBytesWritten: Int64;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
    property BodyBytes: TBytes read FBodyBytes;
    property WriteHeaderCount: Int32 read FWriteHeaderCount;
    property FlushCount: Int32 read FFlushCount;
  end;

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FBody := '';
  FBodyBytes := nil;
  FHeaders := NewHttpHeaders;
  FBodyBytesWritten := 0;
  FMaxWriteSize := High(SizeUInt);
  FRaiseOnWrite := False;
  FWriteHeaderCount := 0;
  FFlushCount := 0;
end;

procedure TMockResponseWriter.SetMaxWriteSize(const AValue: SizeUInt);
begin
  FMaxWriteSize := AValue;
end;

procedure TMockResponseWriter.SetRaiseOnWrite(const AValue: Boolean);
begin
  FRaiseOnWrite := AValue;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  Inc(FWriteHeaderCount);
  FStatus := AStatus;
end;

function TMockResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TMockResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LStr: string;
  LOldLen: SizeUInt;
  LWriteCount: SizeUInt;
begin
  if FRaiseOnWrite then
    raise EIOError.Create('mock response write failed');
  LWriteCount := ACount;
  if LWriteCount > FMaxWriteSize then
    LWriteCount := FMaxWriteSize;
  SetLength(LStr, LWriteCount);
  if LWriteCount > 0 then
    Move(ABuf, LStr[1], LWriteCount);
  FBody := FBody + LStr;
  LOldLen := SizeUInt(Length(FBodyBytes));
  SetLength(FBodyBytes, LOldLen + LWriteCount);
  if LWriteCount > 0 then
    Move(ABuf, FBodyBytes[LOldLen], LWriteCount);
  Inc(FBodyBytesWritten, Int64(LWriteCount));
  Result := LWriteCount;
end;

procedure TMockResponseWriter.Flush;
begin
  Inc(FFlushCount);
end;

function TMockResponseWriter.GetBodyBytesWritten: Int64;
begin
  Result := FBodyBytesWritten;
end;


{ Mock reader for stream tests }
type
  TMockReader = class(TInterfacedObject, IReader)
  private
    FData: TBytes;
    FPos: Int64;
  public
    constructor Create(const AData: TBytes);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TMockReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
  FPos := 0;
end;

function TMockReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: Int64;
begin
  LRemaining := Int64(Length(FData)) - FPos;
  if LRemaining <= 0 then
    Exit(0);
  if Int64(ACount) > LRemaining then
    Result := SizeUInt(LRemaining)
  else
    Result := ACount;
  if Result > 0 then
  begin
    Move(FData[FPos], ABuf, Result);
    Inc(FPos, Int64(Result));
  end;
end;

{ Stream tests }
procedure TestHttpWriteStreamCopiesData;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReader: TMockReader;
  LData: TBytes;
  LN: Int64;
  I: Integer;
begin
  SetLength(LData, 100);
  for I := 0 to 99 do
    LData[I] := Byte(I);
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LReader := TMockReader.Create(LData);
  LN := HttpWriteStream(LW, LReader as IReader, 32);
  CheckEqual(100, LN, 'stream copies all bytes');
  CheckEqual(100, Int64(Length(LWObj.BodyBytes)), 'stream writes to writer');
end;

procedure TestHttpWriteStreamEmptyReader;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReader: TMockReader;
  LData: TBytes;
  LN: Int64;
begin
  SetLength(LData, 0);
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LReader := TMockReader.Create(LData);
  LN := HttpWriteStream(LW, LReader as IReader);
  CheckEqual(0, LN, 'empty stream writes zero bytes');
end;

procedure TestHttpWriteStreamWithLengthSetsHeader;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReader: TMockReader;
  LData: TBytes;
  LN: Int64;
begin
  SetLength(LData, 50);
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LReader := TMockReader.Create(LData);
  LN := HttpWriteStreamWithLength(LW, 50, LReader as IReader, 16);
  CheckEqual(50, LN, 'stream with length copies all bytes');
  CheckEqual('50', LWObj.GetHeaders.Get('content-length'),
    'stream with length sets content-length header');
end;

procedure TestHttpWriteStreamHandlesShortWrites;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReader: TMockReader;
  LData: TBytes;
  LN: Int64;
  I: Integer;
begin
  SetLength(LData, 100);
  for I := 0 to High(LData) do
    LData[I] := Byte(I);
  LWObj := TMockResponseWriter.Create;
  LWObj.SetMaxWriteSize(3);
  LW := LWObj;
  LReader := TMockReader.Create(LData);
  LN := HttpWriteStream(LW, LReader as IReader, 32);
  CheckEqual(Int64(100), LN, 'short writes still copy all bytes');
  CheckEqual(Int64(100), Int64(Length(LWObj.BodyBytes)),
    'short writes do not truncate response');
end;

procedure TestHttpWriteStreamWithLengthHandlesShortWrites;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReader: TMockReader;
  LData: TBytes;
  LN: Int64;
begin
  SetLength(LData, 50);
  LWObj := TMockResponseWriter.Create;
  LWObj.SetMaxWriteSize(2);
  LW := LWObj;
  LReader := TMockReader.Create(LData);
  LN := HttpWriteStreamWithLength(LW, 50, LReader as IReader, 16);
  CheckEqual(Int64(50), LN, 'length stream handles short writes');
  CheckEqual(Int64(50), Int64(Length(LWObj.BodyBytes)),
    'length stream does not truncate response');
end;

procedure TestHttpStreamRejectsZeroBufferSize;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReader: TMockReader;
  LData: TBytes;
begin
  SetLength(LData, 1);
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;

  LReader := TMockReader.Create(LData);
  try
    HttpWriteStream(LW, LReader as IReader, 0);
    Check(False, 'HttpWriteStream zero buffer must raise');
  except
    on E: EHttpError do Check(True, 'HttpWriteStream zero buffer rejected');
  end;

  LReader := TMockReader.Create(LData);
  try
    HttpWriteStreamWithLength(LW, 1, LReader as IReader, 0);
    Check(False, 'HttpWriteStreamWithLength zero buffer must raise');
  except
    on E: EHttpError do Check(True,
      'HttpWriteStreamWithLength zero buffer rejected');
  end;

  LReader := TMockReader.Create(LData);
  try
    HttpRequestReadChunks(LReader as IReader, 0,
      procedure(const AChunk: TBytes; ACount: SizeUInt)
      begin
      end);
    Check(False, 'HttpRequestReadChunks zero buffer must raise');
  except
    on E: EHttpError do Check(True,
      'HttpRequestReadChunks zero buffer rejected');
  end;

  LReader := TMockReader.Create(LData);
  try
    HttpRequestReadBody(LReader as IReader, 1, 0);
    Check(False, 'HttpRequestReadBody zero buffer must raise');
  except
    on E: EHttpError do Check(True,
      'HttpRequestReadBody zero buffer rejected');
  end;
end;

procedure TestHttpRequestReadChunksCollectsData;
var
  LData: TBytes;
  LReader: TMockReader;
  LN: Int64;
  LChunks: Integer;
  LTotalBytes: Integer;
  I: Integer;
begin
  SetLength(LData, 100);
  for I := 0 to 99 do
    LData[I] := Byte(I);
  LReader := TMockReader.Create(LData);
  LChunks := 0;
  LTotalBytes := 0;
  LN := HttpRequestReadChunks(LReader as IReader, 32,
    procedure(const AChunk: TBytes; ACount: SizeUInt)
    begin
      Inc(LChunks);
      Inc(LTotalBytes, Integer(ACount));
    end);
  CheckEqual(100, LN, 'read chunks returns total bytes');
  CheckEqual(4, LChunks, 'read chunks calls callback 4 times (100/32=4)');
  CheckEqual(100, LTotalBytes, 'read chunks total bytes in callbacks');
end;

procedure TestHttpRequestReadBodyCollectsAll;
var
  LData: TBytes;
  LReader: TMockReader;
  LBody: TBytes;
  I: Integer;
begin
  SetLength(LData, 80);
  for I := 0 to 79 do
    LData[I] := Byte(I + 10);
  LReader := TMockReader.Create(LData);
  LBody := HttpRequestReadBody(LReader as IReader, 1000, 32);
  CheckEqual(80, Length(LBody), 'read body returns all bytes');
  CheckEqual(10, Integer(LBody[0]), 'read body first byte correct');
  CheckEqual(89, Integer(LBody[79]), 'read body last byte correct');
end;

procedure TestHttpRequestReadBodyRespectsMaxBytes;
var
  LData: TBytes;
  LReader: TMockReader;
begin
  SetLength(LData, 100);
  LReader := TMockReader.Create(LData);
  try
    HttpRequestReadBody(LReader as IReader, 50, 32);
    Check(False, 'should have raised');
  except
    on E: EHttpError do
      Check(Pos('exceeds maximum', E.Message) > 0, 'error mentions max size');
  end;
end;


var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.stream');
  T.Test('Stream: copies data', @TestHttpWriteStreamCopiesData);
  T.Test('Stream: empty reader', @TestHttpWriteStreamEmptyReader);
  T.Test('Stream: with length sets header', @TestHttpWriteStreamWithLengthSetsHeader);
  T.Test('Stream: handles short writes', @TestHttpWriteStreamHandlesShortWrites);
  T.Test('Stream: with length handles short writes', @TestHttpWriteStreamWithLengthHandlesShortWrites);
  T.Test('Stream: rejects zero buffer size', @TestHttpStreamRejectsZeroBufferSize);
  T.Test('Stream: read chunks collects data', @TestHttpRequestReadChunksCollectsData);
  T.Test('Stream: read body collects all', @TestHttpRequestReadBodyCollectsAll);
  T.Test('Stream: read body respects max', @TestHttpRequestReadBodyRespectsMaxBytes);
  if not T.Run then Halt(1);
end.
