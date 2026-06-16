unit nextpas.core.http.impl.h1.writer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ResponseWriter = class(TInterfacedObject, IHttpResponseWriter, IHttpHijacker)
  private
    FWriter: IWriter;
    FHeaders: IHttpHeaders;
    FHeadersSent: Boolean;
    FStatus: THttpStatus;
    FChunkedWriter: IWriter;
    FConn: ITcpStream;
    FHijacked: Boolean;
    FFinalized: Boolean;
    FNoBodyAllowed: Boolean;
    FSuppressBody: Boolean;
    FHasDeclaredContentLength: Boolean;
    FDeclaredContentLength: Int64;
    FContentLengthWritten: Int64;
    procedure WriteStatusLine;
    procedure WriteInformationalHeader(const AStatus: THttpStatus);
    procedure WriteHeaderBlock;
    procedure WriteAllHeaders;
    procedure WriteCRLF;
    procedure WriteStr(const AStr: string);
    procedure ValidateResponseFramingHeaders;
    procedure TrackFixedLengthWrite(const ACount: SizeUInt);
    procedure ValidateFixedLengthComplete;
    function TryWriteKnownStatusLine: Boolean;
    function TryWriteSmallHeaderBlock: Boolean;
    function ResponseMustNotHaveBody: Boolean;
  public
    constructor Create(const AWriter: IWriter); overload;
    constructor Create(const AWriter: IWriter; const AConn: ITcpStream); overload;
    constructor Create(const AWriter: IWriter; const AConn: ITcpStream;
      const ASuppressBody: Boolean); overload;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function Hijack: ITcpStream;
    function HasCommitted: Boolean;
    function IsHijacked: Boolean;
    property Headers: IHttpHeaders read GetHeaders;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.chunked;

procedure WriteAllOrRaise(const AWriter: IWriter; const ABuf;
  const ACount: SizeUInt);
var
  LWritten: SizeUInt;
  LTotal: SizeUInt;
  LPtr: PByte;
begin
  if ACount = 0 then
    Exit;
  LPtr := @ABuf;
  LTotal := 0;
  while LTotal < ACount do
  begin
    LWritten := AWriter.Write(LPtr[LTotal], ACount - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('h1 response writer: write failed (zero progress)');
    Inc(LTotal, LWritten);
  end;
end;

function ParseContentLengthValue(const AValue: string): Int64;
var
  LI: SizeInt;
  LDigit: Int64;
begin
  if AValue = '' then
    raise EHttpError.Create('response content-length is invalid');

  Result := 0;
  for LI := 1 to Length(AValue) do
  begin
    if (AValue[LI] < '0') or (AValue[LI] > '9') then
      raise EHttpError.Create('response content-length is invalid');
    LDigit := Ord(AValue[LI]) - Ord('0');
    if Result > ((High(Int64) - LDigit) div 10) then
      raise EHttpError.Create('response content-length is too large');
    Result := (Result * 10) + LDigit;
  end;
end;

{ TH1ResponseWriter }

constructor TH1ResponseWriter.Create(const AWriter: IWriter);
begin
  Create(AWriter, nil, False);
end;

constructor TH1ResponseWriter.Create(const AWriter: IWriter; const AConn: ITcpStream);
begin
  Create(AWriter, AConn, False);
end;

constructor TH1ResponseWriter.Create(const AWriter: IWriter; const AConn: ITcpStream;
  const ASuppressBody: Boolean);
begin
  inherited Create;
  FWriter := AWriter;
  FHeaders := NewHttpHeaders;
  FHeadersSent := False;
  FStatus := HTTP_STATUS_OK;
  FConn := AConn;
  FHijacked := False;
  FFinalized := False;
  FNoBodyAllowed := False;
  FSuppressBody := ASuppressBody;
  FHasDeclaredContentLength := False;
  FDeclaredContentLength := 0;
  FContentLengthWritten := 0;
end;

procedure TH1ResponseWriter.WriteStr(const AStr: string);
begin
  if Length(AStr) > 0 then
    WriteAllOrRaise(FWriter, AStr[1], SizeUInt(Length(AStr)));
end;

procedure TH1ResponseWriter.WriteCRLF;
const
  CRLF: AnsiString = #13#10;
begin
  WriteAllOrRaise(FWriter, CRLF[1], 2);
end;

function TH1ResponseWriter.TryWriteKnownStatusLine: Boolean;
const
  STATUS_CONTINUE: AnsiString = 'HTTP/1.1 100 Continue'#13#10;
  STATUS_SWITCHING_PROTOCOLS: AnsiString = 'HTTP/1.1 101 Switching Protocols'#13#10;
  STATUS_EARLY_HINTS: AnsiString = 'HTTP/1.1 103 Early Hints'#13#10;
  STATUS_OK: AnsiString = 'HTTP/1.1 200 OK'#13#10;
  STATUS_CREATED: AnsiString = 'HTTP/1.1 201 Created'#13#10;
  STATUS_NO_CONTENT: AnsiString = 'HTTP/1.1 204 No Content'#13#10;
  STATUS_MOVED_PERMANENTLY: AnsiString = 'HTTP/1.1 301 Moved Permanently'#13#10;
  STATUS_FOUND: AnsiString = 'HTTP/1.1 302 Found'#13#10;
  STATUS_NOT_MODIFIED: AnsiString = 'HTTP/1.1 304 Not Modified'#13#10;
  STATUS_BAD_REQUEST: AnsiString = 'HTTP/1.1 400 Bad Request'#13#10;
  STATUS_UNAUTHORIZED: AnsiString = 'HTTP/1.1 401 Unauthorized'#13#10;
  STATUS_FORBIDDEN: AnsiString = 'HTTP/1.1 403 Forbidden'#13#10;
  STATUS_NOT_FOUND: AnsiString = 'HTTP/1.1 404 Not Found'#13#10;
  STATUS_METHOD_NOT_ALLOWED: AnsiString = 'HTTP/1.1 405 Method Not Allowed'#13#10;
  STATUS_PAYLOAD_TOO_LARGE: AnsiString = 'HTTP/1.1 413 Payload Too Large'#13#10;
  STATUS_EXPECTATION_FAILED: AnsiString = 'HTTP/1.1 417 Expectation Failed'#13#10;
  STATUS_HEADER_TOO_LARGE: AnsiString =
    'HTTP/1.1 431 Request Header Fields Too Large'#13#10;
  STATUS_INTERNAL_SERVER_ERROR: AnsiString =
    'HTTP/1.1 500 Internal Server Error'#13#10;
  STATUS_NOT_IMPLEMENTED: AnsiString = 'HTTP/1.1 501 Not Implemented'#13#10;
  STATUS_BAD_GATEWAY: AnsiString = 'HTTP/1.1 502 Bad Gateway'#13#10;
  STATUS_SERVICE_UNAVAILABLE: AnsiString = 'HTTP/1.1 503 Service Unavailable'#13#10;
  STATUS_ACCEPTED: AnsiString = 'HTTP/1.1 202 Accepted'#13#10;
  STATUS_RESET_CONTENT: AnsiString = 'HTTP/1.1 205 Reset Content'#13#10;
  STATUS_PARTIAL_CONTENT: AnsiString = 'HTTP/1.1 206 Partial Content'#13#10;
  STATUS_SEE_OTHER: AnsiString = 'HTTP/1.1 303 See Other'#13#10;
  STATUS_TEMPORARY_REDIRECT: AnsiString = 'HTTP/1.1 307 Temporary Redirect'#13#10;
  STATUS_PERMANENT_REDIRECT: AnsiString = 'HTTP/1.1 308 Permanent Redirect'#13#10;
  STATUS_NOT_ACCEPTABLE: AnsiString = 'HTTP/1.1 406 Not Acceptable'#13#10;
  STATUS_REQUEST_TIMEOUT: AnsiString = 'HTTP/1.1 408 Request Timeout'#13#10;
  STATUS_CONFLICT: AnsiString = 'HTTP/1.1 409 Conflict'#13#10;
  STATUS_GONE: AnsiString = 'HTTP/1.1 410 Gone'#13#10;
  STATUS_UNPROCESSABLE_ENTITY: AnsiString = 'HTTP/1.1 422 Unprocessable Entity'#13#10;
  STATUS_TOO_MANY_REQUESTS: AnsiString = 'HTTP/1.1 429 Too Many Requests'#13#10;

  procedure WriteLine(const ALine: AnsiString);
  begin
    WriteAllOrRaise(FWriter, ALine[1], SizeUInt(Length(ALine)));
  end;

begin
  Result := True;
  case FStatus of
    HTTP_STATUS_CONTINUE: WriteLine(STATUS_CONTINUE);
    HTTP_STATUS_SWITCHING_PROTOCOLS: WriteLine(STATUS_SWITCHING_PROTOCOLS);
    HTTP_STATUS_EARLY_HINTS: WriteLine(STATUS_EARLY_HINTS);
    HTTP_STATUS_OK: WriteLine(STATUS_OK);
    HTTP_STATUS_CREATED: WriteLine(STATUS_CREATED);
    HTTP_STATUS_NO_CONTENT: WriteLine(STATUS_NO_CONTENT);
    HTTP_STATUS_MOVED_PERMANENTLY: WriteLine(STATUS_MOVED_PERMANENTLY);
    HTTP_STATUS_FOUND: WriteLine(STATUS_FOUND);
    HTTP_STATUS_NOT_MODIFIED: WriteLine(STATUS_NOT_MODIFIED);
    HTTP_STATUS_BAD_REQUEST: WriteLine(STATUS_BAD_REQUEST);
    HTTP_STATUS_UNAUTHORIZED: WriteLine(STATUS_UNAUTHORIZED);
    HTTP_STATUS_FORBIDDEN: WriteLine(STATUS_FORBIDDEN);
    HTTP_STATUS_NOT_FOUND: WriteLine(STATUS_NOT_FOUND);
    HTTP_STATUS_METHOD_NOT_ALLOWED: WriteLine(STATUS_METHOD_NOT_ALLOWED);
    HTTP_STATUS_PAYLOAD_TOO_LARGE: WriteLine(STATUS_PAYLOAD_TOO_LARGE);
    HTTP_STATUS_EXPECTATION_FAILED: WriteLine(STATUS_EXPECTATION_FAILED);
    HTTP_STATUS_HEADER_TOO_LARGE: WriteLine(STATUS_HEADER_TOO_LARGE);
    HTTP_STATUS_INTERNAL_SERVER_ERROR: WriteLine(STATUS_INTERNAL_SERVER_ERROR);
    HTTP_STATUS_NOT_IMPLEMENTED: WriteLine(STATUS_NOT_IMPLEMENTED);
    HTTP_STATUS_BAD_GATEWAY: WriteLine(STATUS_BAD_GATEWAY);
    HTTP_STATUS_SERVICE_UNAVAILABLE: WriteLine(STATUS_SERVICE_UNAVAILABLE);
    HTTP_STATUS_ACCEPTED: WriteLine(STATUS_ACCEPTED);
    HTTP_STATUS_RESET_CONTENT: WriteLine(STATUS_RESET_CONTENT);
    HTTP_STATUS_PARTIAL_CONTENT: WriteLine(STATUS_PARTIAL_CONTENT);
    HTTP_STATUS_SEE_OTHER: WriteLine(STATUS_SEE_OTHER);
    HTTP_STATUS_TEMPORARY_REDIRECT: WriteLine(STATUS_TEMPORARY_REDIRECT);
    HTTP_STATUS_PERMANENT_REDIRECT: WriteLine(STATUS_PERMANENT_REDIRECT);
    HTTP_STATUS_NOT_ACCEPTABLE: WriteLine(STATUS_NOT_ACCEPTABLE);
    HTTP_STATUS_REQUEST_TIMEOUT: WriteLine(STATUS_REQUEST_TIMEOUT);
    HTTP_STATUS_CONFLICT: WriteLine(STATUS_CONFLICT);
    HTTP_STATUS_GONE: WriteLine(STATUS_GONE);
    HTTP_STATUS_UNPROCESSABLE_ENTITY: WriteLine(STATUS_UNPROCESSABLE_ENTITY);
    HTTP_STATUS_TOO_MANY_REQUESTS: WriteLine(STATUS_TOO_MANY_REQUESTS);
  else
    Result := False;
  end;
end;

procedure TH1ResponseWriter.WriteStatusLine;
begin
  if TryWriteKnownStatusLine then
    Exit;

  WriteStr('HTTP/1.1 ');
  WriteStr(IntToStr(Int64(FStatus)));
  WriteStr(' ');
  WriteStr(HttpStatusText(FStatus));
  WriteCRLF;
end;

procedure TH1ResponseWriter.WriteInformationalHeader(const AStatus: THttpStatus);
var
  LFinalStatus: THttpStatus;
begin
  LFinalStatus := FStatus;
  FStatus := AStatus;
  WriteStatusLine;
  WriteHeaderBlock;
  FStatus := LFinalStatus;
end;

procedure TH1ResponseWriter.WriteHeaderBlock;
begin
  if not TryWriteSmallHeaderBlock then
  begin
    WriteAllHeaders;
    WriteCRLF;
  end;
end;

function TH1ResponseWriter.TryWriteSmallHeaderBlock: Boolean;
const
  HEADER_BLOCK_STACK_LIMIT = 2048;
  HEADER_SEPARATOR: AnsiString = ': ';
  CRLF: AnsiString = #13#10;
var
  LBuf: array[0..HEADER_BLOCK_STACK_LIMIT - 1] of AnsiChar;
  LCanFit: Boolean;
  LPos: SizeInt;
begin
  LCanFit := True;
  LPos := 0;

  FHeaders.ForEach(procedure(const AName, AValue: string)
  var
    LLineLen: SizeInt;
    LNameLen: SizeInt;
    LValueLen: SizeInt;
  begin
    if not LCanFit then
      Exit;

    LNameLen := Length(AName);
    LValueLen := Length(AValue);
    LLineLen := LNameLen + 4 + LValueLen;
    if LLineLen > SizeInt(SizeOf(LBuf)) - LPos - 2 then
    begin
      LCanFit := False;
      Exit;
    end;

    if LNameLen > 0 then
    begin
      Move(AName[1], LBuf[LPos], LNameLen);
      Inc(LPos, LNameLen);
    end;
    Move(HEADER_SEPARATOR[1], LBuf[LPos], 2);
    Inc(LPos, 2);
    if LValueLen > 0 then
    begin
      Move(AValue[1], LBuf[LPos], LValueLen);
      Inc(LPos, LValueLen);
    end;
    Move(CRLF[1], LBuf[LPos], 2);
    Inc(LPos, 2);
  end);

  Result := LCanFit;
  if not Result then
    Exit;

  Move(CRLF[1], LBuf[LPos], 2);
  Inc(LPos, 2);
  WriteAllOrRaise(FWriter, LBuf[0], SizeUInt(LPos));
end;

procedure TH1ResponseWriter.WriteAllHeaders;
const
  HEADER_LINE_STACK_LIMIT = 512;
  HEADER_SEPARATOR: AnsiString = ': ';
  CRLF: AnsiString = #13#10;
begin
  FHeaders.ForEach(procedure(const AName, AValue: string)
  var
    LBuf: array[0..HEADER_LINE_STACK_LIMIT - 1] of AnsiChar;
    LLine: string;
    LLineLen: SizeInt;
    LNameLen: SizeInt;
    LValueLen: SizeInt;
    LPos: SizeInt;
  begin
    LNameLen := Length(AName);
    LValueLen := Length(AValue);
    LLineLen := LNameLen + 4 + LValueLen;
    if LLineLen <= SizeInt(SizeOf(LBuf)) then
    begin
      LPos := 0;
      if LNameLen > 0 then
      begin
        Move(AName[1], LBuf[LPos], LNameLen);
        Inc(LPos, LNameLen);
      end;
      Move(HEADER_SEPARATOR[1], LBuf[LPos], 2);
      Inc(LPos, 2);
      if LValueLen > 0 then
      begin
        Move(AValue[1], LBuf[LPos], LValueLen);
        Inc(LPos, LValueLen);
      end;
      Move(CRLF[1], LBuf[LPos], 2);
      WriteAllOrRaise(FWriter, LBuf[0], SizeUInt(LLineLen));
      Exit;
    end;

    SetLength(LLine, LLineLen);
    LPos := 1;
    if LNameLen > 0 then
    begin
      Move(AName[1], LLine[LPos], LNameLen);
      Inc(LPos, LNameLen);
    end;
    Move(HEADER_SEPARATOR[1], LLine[LPos], 2);
    Inc(LPos, 2);
    if LValueLen > 0 then
    begin
      Move(AValue[1], LLine[LPos], LValueLen);
      Inc(LPos, LValueLen);
    end;
    Move(CRLF[1], LLine[LPos], 2);
    WriteStr(LLine);
  end);
end;

function TH1ResponseWriter.ResponseMustNotHaveBody: Boolean;
begin
  Result := (FStatus = HTTP_STATUS_NO_CONTENT) or
            (FStatus = HTTP_STATUS_NOT_MODIFIED) or
            ((FStatus div 100) = 1);
end;

procedure TH1ResponseWriter.ValidateResponseFramingHeaders;
var
  LContentLengths: TStringArray;
begin
  FHasDeclaredContentLength := False;
  FDeclaredContentLength := 0;
  FContentLengthWritten := 0;
  LContentLengths := FHeaders.GetAll('content-length');
  if Length(LContentLengths) > 1 then
    raise EHttpError.Create('response content-length is duplicated');
  if Length(LContentLengths) = 1 then
  begin
    FDeclaredContentLength := ParseContentLengthValue(LContentLengths[0]);
    FHasDeclaredContentLength := True;
  end;
  if (Length(LContentLengths) > 0) and FHeaders.Has('transfer-encoding') then
    raise EHttpError.Create(
      'response cannot include both content-length and transfer-encoding');
end;

procedure TH1ResponseWriter.TrackFixedLengthWrite(const ACount: SizeUInt);
begin
  if not FHasDeclaredContentLength then
    Exit;
  if ACount > SizeUInt(High(Int64)) then
    raise EHttpError.Create('response body exceeds declared content-length');
  if Int64(ACount) > FDeclaredContentLength - FContentLengthWritten then
    raise EHttpError.Create('response body exceeds declared content-length');
  Inc(FContentLengthWritten, Int64(ACount));
end;

procedure TH1ResponseWriter.ValidateFixedLengthComplete;
begin
  if (not FSuppressBody) and
     FHasDeclaredContentLength and
     (FContentLengthWritten <> FDeclaredContentLength) then
    raise EHttpError.Create('response body shorter than declared content-length');
end;

procedure TH1ResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  if FHeadersSent then
    Exit;
  if ((AStatus div 100) = 1) and (AStatus <> HTTP_STATUS_SWITCHING_PROTOCOLS) then
  begin
    WriteInformationalHeader(AStatus);
    Exit;
  end;
  FStatus := AStatus;
  FNoBodyAllowed := ResponseMustNotHaveBody;
  ValidateResponseFramingHeaders;
  if (not FNoBodyAllowed) and
     (not FSuppressBody) and
     (not FHeaders.Has('content-length')) and
     (not FHeaders.Has('transfer-encoding')) then
    FHeaders.Set_('transfer-encoding', 'chunked');
  WriteStatusLine;
  WriteHeaderBlock;
  FHeadersSent := True;
  if FHeaders.Get('transfer-encoding') = 'chunked' then
    FChunkedWriter := TChunkedWriter.Create(FWriter);
end;

function TH1ResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH1ResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TH1ResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if FFinalized then
    raise EHttpError.Create('response already finalized');
  if not FHeadersSent then
    WriteHeader(HTTP_STATUS_OK);
  if FNoBodyAllowed then
    raise EHttpError.Create('response status must not include a body');
  if FSuppressBody then
    Exit(ACount);
  TrackFixedLengthWrite(ACount);
  if FChunkedWriter <> nil then
    Result := FChunkedWriter.Write(ABuf, ACount)
  else
  begin
    WriteAllOrRaise(FWriter, ABuf, ACount);
    Result := ACount;
  end;
end;

procedure TH1ResponseWriter.Flush;
var
  LFlusher: IFlusher;
begin
  if (not FHeadersSent) and (not FHijacked) then
    WriteHeader(HTTP_STATUS_OK);
  if FChunkedWriter <> nil then
  begin
    (FChunkedWriter as IFlusher).Flush;
    FFinalized := True;
  end;
  if FChunkedWriter = nil then
  begin
    ValidateFixedLengthComplete;
    FFinalized := True;
  end;
  if Supports(FWriter, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ResponseWriter.Hijack: ITcpStream;
begin
  if FConn = nil then
    raise EHttpError.Create('Connection not available for hijack');
  FHijacked := True;
  Result := FConn;
end;

function TH1ResponseWriter.HasCommitted: Boolean;
begin
  Result := FHeadersSent;
end;

function TH1ResponseWriter.IsHijacked: Boolean;
begin
  Result := FHijacked;
end;

end.
