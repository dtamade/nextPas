unit nextpas.core.http.impl.h1.writer;
{**
 * @desc HTTP/1.1 response writer (IHttpResponseWriter implementation).
 *       Manages status line, headers, chunked/Content-Length framing,
 *       and connection hijacking for WebSocket upgrade.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.platform.socket.base,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  TH1ResponseWriter = class(TInterfacedObject, IHttpResponseWriter, IHttpHijacker,
    IHttpResponseBodyBytes, IHttpResponseWriterCommitState, IHttpConnContext,
    IHttpPeerProbe, nextpas.core.platform.sendfile.base.ISendfileSocketHandle)
  private
    FWriter: IWriter;
    FHeaders: IHttpHeaders;
    FHeadersSent: Boolean;
    FStatus: THttpStatus;
    FChunkedWriter: IWriter;
    FConn: ITcpStream;
    FSessionContext: ITcpServerSessionContext;
    FHijacked: Boolean;
    FFinalized: Boolean;
    FNoBodyAllowed: Boolean;
    FSuppressBody: Boolean;
    FHasDeclaredContentLength: Boolean;
    FDeclaredContentLength: Int64;
    FContentLengthWritten: Int64;
    FBodyBytesWritten: Int64;
    FWriteTimeoutMs: Int64;
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
    constructor Create(const AWriter: IWriter; const AConn: ITcpStream;
      const ASuppressBody: Boolean; const AWriteTimeoutMs: Int64); overload;
    { 绑定承载本连接的 poll session 上下文（IHttpConnContext 支持，非阻塞升级用） }
    procedure AttachSessionContext(const AContext: ITcpServerSessionContext);
    function HostSessionContext: ITcpServerSessionContext;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    { FinalizeResponse: write the terminal chunk (chunked) or validate the
      declared content-length (fixed), then mark the response finalized.
      The server conn loop calls this once after the handler returns;
      handlers must not call it (Flush stays non-terminating so streaming
      protocols such as SSE can Flush between frames). }
    procedure FinalizeResponse;
    function Hijack: ITcpStream;
    function HasCommitted: Boolean;
    function HeadersCommitted: Boolean;
    function IsHijacked: Boolean;
    { IHttpPeerProbe：委托底层连接的 ITcpPeerProbe；连接不支持（如
      包装流）或无连接时恒 True（保守，绝不误报断连）。 }
    function PeerAlive: Boolean;
    function GetBodyBytesWritten: Int64;
    function GetSocketHandle: TPlatformSocket;
    property Headers: IHttpHeaders read GetHeaders;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.net.intf,
  nextpas.core.platform.socket.base,
  nextpas.core.platform.sendfile.base,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.chunked,
  nextpas.core.http.impl.h1.outbound;

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
    raise EHttpError.Create(hekProtocol, 'response content-length is invalid');

  Result := 0;
  for LI := 1 to Length(AValue) do
  begin
    if (AValue[LI] < '0') or (AValue[LI] > '9') then
      raise EHttpError.Create(hekProtocol, 'response content-length is invalid');
    LDigit := Ord(AValue[LI]) - Ord('0');
    if Result > ((High(Int64) - LDigit) div 10) then
      raise EHttpError.Create(hekProtocol, 'response content-length is too large');
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
  Create(AWriter, AConn, ASuppressBody, 0);
end;

constructor TH1ResponseWriter.Create(const AWriter: IWriter; const AConn: ITcpStream;
  const ASuppressBody: Boolean; const AWriteTimeoutMs: Int64);
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
  FBodyBytesWritten := 0;
  FWriteTimeoutMs := AWriteTimeoutMs;
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
    WriteAllHeaders;
end;

function TH1ResponseWriter.TryWriteSmallHeaderBlock: Boolean;
const
  HEADER_BLOCK_STACK_LIMIT = 2048;
  HEADER_SEPARATOR: AnsiString = ': ';
  CRLF: AnsiString = #13#10;
var
  LBuilder: TBufStringBuilder;
  LExceeds: Boolean;
  LP: PAnsiChar;
  LNeed: SizeUInt;
begin
  // perf: single allocation via TBufStringBuilder (L1 owner text.builder) reusing bytes.ops.BytesGrowCapacity single source geometric growth (BYTES_BUILDER_MIN_GROW) amortized O(1), zero-copy via bytes.ops.BytesCopy inline + Reserve+Tail+AdvanceLen single buffer batch; eliminates per-header SetLength allocations and multiple Moves; stability via try/finally Done; inline Reserve/Tail/AdvanceLen
  LExceeds := False;
  LBuilder.Init(HEADER_BLOCK_STACK_LIMIT);
  try
    FHeaders.ForEach(procedure(const AName, AValue: string)
    var
      LNameLen, LValueLen: SizeUInt;
    begin
      if LExceeds then
        Exit;
      LNameLen := SizeUInt(Length(AName));
      LValueLen := SizeUInt(Length(AValue));
      LNeed := LNameLen + 2 + LValueLen + 2;
      if LBuilder.Len + LNeed + 2 > HEADER_BLOCK_STACK_LIMIT then
      begin
        LExceeds := True;
        Exit;
      end;
      LBuilder.Reserve(LNeed);
      LP := LBuilder.Tail;
      // perf: zero-copy single Move via bytes.ops BytesCopy inline (single source INV-5), Reserve+Tail+AdvanceLen evidence
      if LNameLen > 0 then
      begin
        BytesCopy(LP, PAnsiChar(AName), LNameLen);
        Inc(LP, LNameLen);
      end;
      BytesCopy(LP, PAnsiChar(HEADER_SEPARATOR), 2);
      Inc(LP, 2);
      if LValueLen > 0 then
      begin
        BytesCopy(LP, PAnsiChar(AValue), LValueLen);
        Inc(LP, LValueLen);
      end;
      BytesCopy(LP, PAnsiChar(CRLF), 2);
      LBuilder.AdvanceLen(LNeed);
    end);
    if LExceeds then
      Exit(False);
    LBuilder.Reserve(2);
    LP := LBuilder.Tail;
    BytesCopy(LP, PAnsiChar(CRLF), 2);
    LBuilder.AdvanceLen(2);
    if LBuilder.Len > 0 then
      WriteAllOrRaise(FWriter, LBuilder.AsView.Data^, LBuilder.Len);
    Result := True;
  finally
    LBuilder.Done;
  end;
end;

procedure TH1ResponseWriter.WriteAllHeaders;
const
  HEADER_SEPARATOR: AnsiString = ': ';
  CRLF: AnsiString = #13#10;
var
  LBuilder: TBufStringBuilder;
  LP: PAnsiChar;
  LNeed: SizeUInt;
begin
  // perf: single buffer batch via TBufStringBuilder (text.builder L1 owner) Reserve+Tail+AdvanceLen zero-copy via bytes.ops.BytesCopy single source; eliminates per-header SetLength allocations and per-header Moves/512-stack fallback, amortized O(1) growth via BytesGrowCapacity (BYTES_BUILDER_MIN_GROW), single WriteAllOrRaise for whole block + terminal CRLF; stability via try/finally Done; inline Reserve/Tail/AdvanceLen
  LBuilder.Init(1024);
  try
    FHeaders.ForEach(procedure(const AName, AValue: string)
    var
      LNameLen, LValueLen: SizeUInt;
    begin
      LNameLen := SizeUInt(Length(AName));
      LValueLen := SizeUInt(Length(AValue));
      LNeed := LNameLen + 2 + LValueLen + 2;
      LBuilder.Reserve(LNeed);
      LP := LBuilder.Tail;
      // perf: zero-copy single Move via bytes.ops BytesCopy inline
      if LNameLen > 0 then
      begin
        BytesCopy(LP, PAnsiChar(AName), LNameLen);
        Inc(LP, LNameLen);
      end;
      BytesCopy(LP, PAnsiChar(HEADER_SEPARATOR), 2);
      Inc(LP, 2);
      if LValueLen > 0 then
      begin
        BytesCopy(LP, PAnsiChar(AValue), LValueLen);
        Inc(LP, LValueLen);
      end;
      BytesCopy(LP, PAnsiChar(CRLF), 2);
      LBuilder.AdvanceLen(LNeed);
    end);
    LBuilder.Reserve(2);
    LP := LBuilder.Tail;
    BytesCopy(LP, PAnsiChar(CRLF), 2);
    LBuilder.AdvanceLen(2);
    if LBuilder.Len > 0 then
      WriteAllOrRaise(FWriter, LBuilder.AsView.Data^, LBuilder.Len);
  finally
    LBuilder.Done;
  end;
end;

function TH1ResponseWriter.ResponseMustNotHaveBody: Boolean;
begin
  Result := (FStatus = HTTP_STATUS_NO_CONTENT) or
            (FStatus = HTTP_STATUS_NOT_MODIFIED) or
            (FStatus = HTTP_STATUS_RESET_CONTENT) or
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
    raise EHttpError.Create(hekProtocol, 'response content-length is duplicated');
  if Length(LContentLengths) = 1 then
  begin
    FDeclaredContentLength := ParseContentLengthValue(LContentLengths[0]);
    FHasDeclaredContentLength := True;
  end;
  if (Length(LContentLengths) > 0) and FHeaders.Has('transfer-encoding') then
    raise EHttpError.Create(hekProtocol,
      'response cannot include both content-length and transfer-encoding');
end;

procedure TH1ResponseWriter.TrackFixedLengthWrite(const ACount: SizeUInt);
begin
  if not FHasDeclaredContentLength then
    Exit;
  if ACount > SizeUInt(High(Int64)) then
    raise EHttpError.Create(hekProtocol, 'response body exceeds declared content-length');
  if Int64(ACount) > FDeclaredContentLength - FContentLengthWritten then
    raise EHttpError.Create(hekProtocol, 'response body exceeds declared content-length');
  Inc(FContentLengthWritten, Int64(ACount));
end;

procedure TH1ResponseWriter.ValidateFixedLengthComplete;
begin
  if (not FSuppressBody) and
     FHasDeclaredContentLength and
     (FContentLengthWritten <> FDeclaredContentLength) then
    raise EHttpError.Create(hekProtocol, 'response body shorter than declared content-length');
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
    FHeaders.SetHeader('transfer-encoding', 'chunked');
  WriteStatusLine;
  WriteHeaderBlock;
  FHeadersSent := True;
  { Check if chunked encoding is present (case-insensitive, may have multiple codings) }
  if Pos('chunked', LowerCase(FHeaders.Get('transfer-encoding'))) > 0 then
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
    raise EHttpError.Create(hekProtocol, 'response already finalized');
  if not FHeadersSent then
    WriteHeader(HTTP_STATUS_OK);
  if FNoBodyAllowed then
    raise EHttpError.Create(hekProtocol, 'response status must not include a body');
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
  Inc(FBodyBytesWritten, Int64(Result));
end;

procedure TH1ResponseWriter.Flush;
var
  LFlusher: IFlusher;
  LOutbound: IH1OutboundBuffer;
begin
  LOutbound := nil;
  { Flush is non-terminating: SSE and other streaming protocols Flush between
    frames; only the conn loop's FinalizeResponse writes the terminal chunk. }
  if FFinalized then
    Exit;
  if (not FHeadersSent) and (not FHijacked) then
    WriteHeader(HTTP_STATUS_OK);
  { Handler-level Flush must push buffered bytes to the peer immediately.
    On the server path FWriter is an IH1OutboundBuffer which has no IFlusher,
    so without this direct drain a per-frame Flush is a no-op until the conn
    loop drains after the handler returns (first token then arrives at
    whole-stream latency). The drain runs on the handler thread; both the
    poll worker-handoff and reactor-inline paths set the socket blocking and
    wait for handler completion, so the write needs no extra lock. Hijacked
    connections are owned by the handler and must not be drained here. }
  if (not FHijacked) and (FConn <> nil) and
     Supports(FWriter, IH1OutboundBuffer, LOutbound) and (not LOutbound.IsEmpty) then
  begin
    if FWriteTimeoutMs > 0 then
      FConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(FWriteTimeoutMs)));
    LOutbound.DrainAllTo(FConn as IWriter);
  end;
  if Supports(FWriter, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

procedure TH1ResponseWriter.FinalizeResponse;
var
  LFlusher: IFlusher;
begin
  if FFinalized then
    Exit;
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
    raise EHttpError.Create(hekProtocol, 'Connection not available for hijack');
  FHijacked := True;
  Result := FConn;
end;

procedure TH1ResponseWriter.AttachSessionContext(
  const AContext: ITcpServerSessionContext);
begin
  FSessionContext := AContext;
end;

function TH1ResponseWriter.HostSessionContext: ITcpServerSessionContext;
begin
  Result := FSessionContext;
end;

function TH1ResponseWriter.HasCommitted: Boolean;
begin
  Result := FHeadersSent;
end;

function TH1ResponseWriter.HeadersCommitted: Boolean;
begin
  Result := FHeadersSent;
end;

function TH1ResponseWriter.IsHijacked: Boolean;
begin
  Result := FHijacked;
end;

function TH1ResponseWriter.PeerAlive: Boolean;
var
  LProbe: ITcpPeerProbe;
begin
  Result := True;
  if (FConn = nil) or FHijacked then
    Exit;
  if FConn.QueryInterface(ITcpPeerProbe, LProbe) <> 0 then
    Exit;                        { 包装流不支持探测：保守 True }
  Result := LProbe.PeerAlive;
end;

function TH1ResponseWriter.GetBodyBytesWritten: Int64;
begin
  Result := FBodyBytesWritten;
end;

function TH1ResponseWriter.GetSocketHandle: TPlatformSocket;
var
  LSock: nextpas.core.platform.sendfile.base.ISendfileSocketHandle;
begin
  Result := PLATFORM_INVALID_SOCKET;
  if (FConn = nil) or FHijacked then
    Exit;
  if Supports(FConn, nextpas.core.platform.sendfile.base.ISendfileSocketHandle, LSock) then
    Result := LSock.GetSocketHandle
  else if Supports(FConn, ITcpSocketRuntime) then
    Result.Value := PtrUInt((FConn as ITcpSocketRuntime).NativeSocketHandle);
end;

end.
