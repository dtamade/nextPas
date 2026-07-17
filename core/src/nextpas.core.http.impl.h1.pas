unit nextpas.core.http.impl.h1;
{**
 * @desc Default HTTP/1.x transport implementations for client and server.
 *       Owns single-request round trips, connection reuse, and per-connection
 *       request/response handling for the shared HTTP facade layer.
 *}

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.io.intf, nextpas.core.net.intf, nextpas.core.net.server.intf, nextpas.core.net.server.base, nextpas.core.platform.io.base, nextpas.core.tls.base, nextpas.core.http.base, nextpas.core.http.intf;

type
  TH1ClientTransportOptions = record
    Timeout: Int64;
    { OS dial + post-dial first-write budget for newly opened sockets (ms).
      0 = dial uses Timeout when Timeout > 0; post-dial first-write uses Timeout. }
    ConnectTimeout: Int64;
    { Max idle connections retained per pool authority key (host/port, with
      scheme/proxy variants encoded in the host key). Not a global pool cap. }
    MaxPoolSize: Int32;
    { Plain HTTP forward proxy URL (http://[user:pass@]host:port). Empty = direct.
      For https targets, client dials proxy and opens a CONNECT tunnel, then
      TLS-wraps the tunneled stream (SNI = origin host). Plain http targets
      keep absolute-form forwarding (no CONNECT). When UserInfo is present,
      injects Proxy-Authorization: Basic (raw userinfo, no percent-decode)
      on CONNECT and on absolute-form when the request lacks that header.
      Wave I freeze: Basic only — no Digest/NTLM/Negotiate challenge retry. }
    ProxyUrl: string;
    { Optional client TLS context for direct H1 https and https-over-CONNECT.
      Nil uses TSSLQuick.SecureClient. }
    TLSContext: ISSLContext;
  end;

  TH1ServerTransportOptions = record
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
    MaxRequestsPerConnection: Int32;
    { Connection-scoped LocalArena: Reset per request, attach for handlers. }
    RequestArena: Boolean;
    RequestArenaCapacity: SizeUInt;
  end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;

implementation

uses
  nextpas.core.base, nextpas.core.base.utils, nextpas.core.errors,
  nextpas.core.io.base, nextpas.core.io.buffer, nextpas.core.net,
  nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.http.headers, nextpas.core.http.message,
  nextpas.core.http.impl.h1.outbound, nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.parser, nextpas.core.http.impl.h1.writer,
  nextpas.core.http.impl.h1.chunked,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.quick,
  nextpas.core.sync,
  nextpas.core.mem.arena.intf,
  nextpas.core.http.mem,
  nextpas.core.http.middleware.requestarena;

type
  TPoolEntry = record
    Host: string;
    Port: UInt16;
    Conn: ITcpStream;
  end;

  TReadPrependTcpStream = class(TInterfacedObject, IReader, IWriter, ITcpStream)
  private
    FInner: ITcpStream;
    FPrefix: string;
    FPrefixPos: SizeInt;
  public
    constructor Create(const AInner: ITcpStream; const APrefix: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
  end;

  TH1FastRequestSnapshot = class(TInterfacedObject, IH1Parser)
  private
    FMethod: THttpMethod;
    FUrl: string;
    FVersion: THttpVersion;
    FHeaders: IHttpHeaders;
    FBodySize: Int64;
    FComplete: Boolean;
    FRequestMetadata: TH1RequestMetadata;
  public
    constructor Create(const AResult: TFastParseResult);
    function Execute(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeUInt;
    procedure Finish;
    function GetMethod: THttpMethod;
    function GetStatusCode: THttpStatus;
    function GetHttpVersion: THttpVersion;
    function GetUrl: string;
    function GetHeaders: IHttpHeaders;
    function GetBody: string;
    function GetBodySize: Int64;
    function NewBodyReader: IReader;
    function HeadersComplete: Boolean;
    function IsComplete: Boolean;
    function ShouldKeepAlive: Boolean;
    function GetTrailerBytes: Int64;
    function GetRequestMetadata: TH1RequestMetadata;
    function HasError: Boolean;
    function ErrorMessage: string;
    function ErrorKind: TH1ParserErrorKind;
    procedure Reset;
  end;

  TH1ClientTransport = class(TInterfacedObject, IHttpTransport,
    IHttpTransportIdleConnections)
  private
    FOptions: TH1ClientTransportOptions;
    FPoolLock: IMutex;
    FPool: array of TPoolEntry;
    FPoolCount: Int32;
    FPending: string;
    FDefaultTLSContext: ISSLContext;
    function PooledConnectionIsReusable(const AConn: ITcpStream): Boolean;
    function PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
    procedure PoolPut(const AHost: string; const APort: UInt16; const AConn: ITcpStream);
    procedure PoolClear;
    function SecureClientContext: ISSLContext;
    function WriteRequest(const AWriter: IWriter; const AReq: IHttpRequest;
      const AAutoHost: string; const AAbsoluteForm: Boolean;
      const AProxyAuthorization: string): Boolean;
    function ReadResponse(const AReader: IReader;
      const ARequestMethod: THttpMethod; out AKeepAlive: Boolean;
      out AResponseStarted: Boolean): IHttpResponse;
    procedure EstablishHttpsConnectTunnel(var AConn: ITcpStream;
      const ATargetHost: string; const ATargetPort: UInt16;
      const AProxyAuthorization: string);
  public
    constructor Create(const AOptions: TH1ClientTransportOptions);
    destructor Destroy; override;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
  end;

  TH1ServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FOptions: TH1ServerTransportOptions;
    procedure ValidateInputs(const AConn: ITcpStream; const AHandler: IHttpHandler);
    function HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler): Boolean;
  public
    constructor Create(const AOptions: TH1ServerTransportOptions);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

  TH1ServerConnectionState = class;

  TH1PollRunWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
  end;

  TH1PollRequestWork = class(TInterfacedObject, ITcpServerWork)
  private
    FState: TH1ServerConnectionState;
    FOutbound: IH1OutboundBuffer;
    FCloseAfterDrain: Boolean;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    function Execute: TTcpServerConnOwnership;
    property Outbound: IH1OutboundBuffer read FOutbound;
    property CloseAfterDrain: Boolean read FCloseAfterDrain;
  end;

  TH1PollRunCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
  public
    constructor Create(const AState: TH1ServerConnectionState);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TH1PollRequestCompletion = class(TInterfacedObject, ITcpServerWorkCompletion)
  private
    FState: TH1ServerConnectionState;
    FWorkRef: ITcpServerWork;
    FWork: TH1PollRequestWork;
  public
    constructor Create(const AState: TH1ServerConnectionState;
      const AWork: TH1PollRequestWork);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  // Connection state stays protocol-owned so future runtimes can drive
  // the same H1 logic without keeping it welded to a thread entrypoint.
  TH1ServerConnectionState = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline)
  private
    FOptions: TH1ServerTransportOptions;
    FConn: ITcpStream;
    FHandler: IHttpHandler;
    FSessionContext: ITcpServerSessionContext;
    FSocketRuntime: ITcpSocketRuntime;
    FStreamRuntime: ITcpStreamRuntime;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FParser: IH1Parser;
    FPending: string;
    FKeepAlive: Boolean;
    FReadMs: Int64;
    FIdleMs: Int64;
    FBuf: array[0..16383] of Byte;
    FPollSubmitted: Boolean;
    FPollWorkerPending: Boolean;
    FPollCompletionReady: Boolean;
    FPollCompletionOwnership: TTcpServerConnOwnership;
    FPollNeedRequestReset: Boolean;
    FParseTotalRead: SizeUInt;
    FParseHeadersDone: Boolean;
    FContinueSent: Boolean;
    FPollOutbound: IH1OutboundBuffer;
    FPollResponsePending: Boolean;
    FPollCloseAfterDrain: Boolean;
    FPollQueuedOutbound: IH1OutboundBuffer;
    FPollQueuedResponsePending: Boolean;
    FPollQueuedCloseAfterDrain: Boolean;
    FPollReadDeadline: TDeadline;
    FPollReadDeadlineIsIdle: Boolean;
    FPollWriteDeadline: TDeadline;
    FParserIsSnapshot: Boolean;
    FRequestCount: Int32;
    FRequestArena: IArena;
    procedure InvokeHandler(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter);
    procedure ArmPollReadDeadline(const ATimeoutMs: Int64;
      const AIsIdle: Boolean);
    procedure ArmPollRequestReadDeadline;
    procedure ClearPollReadDeadline;
    procedure ResetRequestParser;
    function TryUseFastRequestParser(const ABuf: PAnsiChar; const ALen: SizeUInt;
      out AConsumed: SizeUInt): Boolean;
    procedure ResetPollRequestStateWithDeadline(const ATimeoutMs: Int64;
      const AIsIdle: Boolean);
    procedure ResetPollRequestState;
    procedure PreparePollRequestParse;
    procedure PreparePollKeepAliveRequestParse;
    procedure ResetPollResponseState;
    procedure PromoteQueuedPollResponse;
    function EnqueuePollResponse(const AOutbound: IH1OutboundBuffer;
      const ACloseAfterDrain: Boolean): Boolean;
    function CanParseBufferedPollRequestWhileDraining: Boolean;
    function ShouldWaitForWritableInsteadOfEagerDrain(
      const AEvents: TPlatformPollEvents): Boolean;
    function QueuePollErrorResponse(const AStatus: THttpStatus): Boolean;
    procedure ApplyPollRequestResult(const AWork: TH1PollRequestWork);
    procedure ArmPollWriteDeadline;
    procedure ArmDirectWriteDeadline;
    function UsePollOwnedResponseDrain: Boolean;
    function ExecuteCurrentRequest: TTcpServerConnOwnership;
    function ExecuteCurrentPollRequest(out AOutbound: IH1OutboundBuffer;
      out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
    function AdvanceWholeRunBridge(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function SubmitCurrentPollRequest(out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function ContinueAfterPollCompletion(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function AdvancePollResponseDrain(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function AdvancePollRequestParse(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  public
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH1ServerTransportOptions); overload;
    constructor Create(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AOptions: TH1ServerTransportOptions;
      const AContext: ITcpServerSessionContext); overload;
    function Run: TTcpServerConnOwnership;
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    function WakeDeadline: TDeadline;
  end;

function ShouldKeepAlive(const AParser: IH1Parser): Boolean; inline;
var
  LMetadata: TH1RequestMetadata;
begin
  LMetadata := AParser.GetRequestMetadata;
  if AParser.GetHttpVersion = hvHttp10 then
    Result := LMetadata.ConnectionKeepAlive
  else
    Result := not LMetadata.ConnectionClose;
end;

function LowerTrim(const AValue: string): string; inline;
begin
  Result := LowerCase(Trim(AValue));
end;

function HeaderValueHasToken(const AValue, AToken: string): Boolean;
var
  LStart: SizeInt;
  LPos: SizeInt;
begin
  Result := False;
  if AValue = '' then
    Exit;

  LStart := 1;
  while LStart <= Length(AValue) do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    if LowerTrim(Copy(AValue, LStart, LPos - LStart)) = AToken then
      Exit(True);
    LStart := LPos + 1;
  end;
end;

procedure ValidateWireHeaderValue(const AValue: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(AValue) do
    if (((AValue[LI] < #32) and (AValue[LI] <> #9)) or
        (AValue[LI] = #127)) then
      raise EHttpError.Create(hekParse, 'invalid header value character');
end;

procedure ValidateWireRequestTarget(const ATarget: string);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(ATarget) do
    if (ATarget[LI] <= #32) or (ATarget[LI] = #127) then
      raise EHttpError.Create(hekParse, 'invalid request target character');
end;

procedure ValidateWireHeaderName(const AName: string);
var
  LI: SizeInt;
begin
  if AName = '' then
    raise EHttpError.Create(hekProtocol, 'empty header name');
  for LI := 1 to Length(AName) do
    if not IsHttpHeaderNameChar(AnsiChar(AName[LI])) then
      raise EHttpError.Create(hekParse, 'invalid header name character');
end;

procedure ValidatePlainHttpClientUrlScheme(const AUrl: TUrl);
var
  LScheme: string;
begin
  LScheme := LowerCase(AUrl.Scheme);
  if LScheme = '' then
    Exit;
  if (LScheme = 'http') or (LScheme = 'https') then
    Exit;
  raise EHttpError.CreateOp(hekProtocol, 'transport',
    'unsupported HTTP client URL scheme: ' + AUrl.Scheme);
end;

function ProxyBasicAuthorizationValue(const AUserInfo: string): string;
begin
  if AUserInfo = '' then
    Exit('');
  { Wave I product freeze: proxy authentication is Basic only.
    Raw UserInfo from TUrl.Parse (no percent-decode). Same encoding path as
    THttpRequestBuilder.BasicAuth. Digest / NTLM / Negotiate are not
    implemented and must not be added as silent half-implementations. }
  Result := 'Basic ' + Base64Encode(StringToUTF8Bytes(AUserInfo));
end;

function ConnectAuthority(const AHost: string; const APort: UInt16): string;
var
  LHost: string;
begin
  if (AHost <> '') and (AHost[1] <> '[') and (Pos(':', AHost) > 0) then
    LHost := '[' + AHost + ']'
  else
    LHost := AHost;
  Result := LHost + ':' + IntToStr(Int64(APort));
end;

function DefaultPortForHttpScheme(const AScheme: string): UInt16;
var
  LScheme: string;
begin
  LScheme := LowerCase(AScheme);
  if LScheme = 'https' then
    Result := 443
  else
    Result := 80;
end;

function CanonicalPoolHostKey(const AHost: string): string; inline;
begin
  Result := LowerCase(AHost);
end;

function HeadersHaveConnectionCloseToken(const AHeaders: IHttpHeaders): Boolean;
var
  LValues: TStringArray;
  LI: SizeInt;
begin
  Result := False;
  if AHeaders = nil then
    Exit;

  LValues := AHeaders.GetAll('connection');
  for LI := Low(LValues) to High(LValues) do
    if HeaderValueHasToken(LValues[LI], 'close') then
      Exit(True);
end;

function ParserErrorStatus(const AParser: IH1Parser): THttpStatus; inline;
begin
  case AParser.ErrorKind of
    pekNone:
      Result := HTTP_STATUS_BAD_REQUEST;
    pekUnsupportedTransferCoding:
      Result := HTTP_STATUS_NOT_IMPLEMENTED;
  else
    Result := HTTP_STATUS_BAD_REQUEST;
  end;
end;

function IsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
begin
  Result := HttpIsRetryableMethod(AMethod);
end;

function HasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpHasRetryIdempotencyKey(AReq);
end;

function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
begin
  Result := HttpIsRetrySafeRequest(AReq);
end;

function IsSkippableInformationalResponse(const AStatus: THttpStatus): Boolean; inline;
begin
  Result := HttpStatusIsInformational(AStatus) and
    (AStatus <> HTTP_STATUS_SWITCHING_PROTOCOLS);
end;

function CaptureRetryBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
begin
  ABodyStream := nil;
  AStartPosition := 0;
  { ContentLength = 0 means no body bytes; < 0 is chunked unknown-length. }
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit(True);
  Result := Supports(AReq.Body, IStream, ABodyStream);
  if Result then
    AStartPosition := ABodyStream.Position;
end;

procedure RewindRetryBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
begin
  if (AReq = nil) or (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit;
  if ABodyStream = nil then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'pooled retry request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

function ClientRequestDeadline(const ATimeoutMs: Int64): TDeadline;
begin
  if ATimeoutMs > 0 then
    Result := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs))
  else
    Result := TDeadline.Infinite;
end;

procedure ApplyClientDeadline(const AConn: ITcpStream;
  const ADeadline: TDeadline);
begin
  if ADeadline.IsInfinite then
    Exit;
  AConn.SetReadDeadline(ADeadline);
  AConn.SetWriteDeadline(ADeadline);
end;

type
  { Bridge IHttpCancelToken → INetCancelToken for mid-read/write cancel slices. }
  THttpNetCancelAdapter = class(TInterfacedObject, INetCancelToken)
  private
    FToken: IHttpCancelToken;
  public
    constructor Create(const AToken: IHttpCancelToken);
    function IsCanceled: Boolean;
  end;

constructor THttpNetCancelAdapter.Create(const AToken: IHttpCancelToken);
begin
  inherited Create;
  FToken := AToken;
end;

function THttpNetCancelAdapter.IsCanceled: Boolean;
begin
  Result := (FToken <> nil) and FToken.IsCanceled;
end;

procedure ApplyClientCancelToken(const AConn: ITcpStream;
  const AToken: IHttpCancelToken);
begin
  if AConn = nil then
    Exit;
  if AToken = nil then
    AConn.SetCancelToken(nil)
  else
    AConn.SetCancelToken(THttpNetCancelAdapter.Create(AToken));
end;

function H1ClientDial(const AHost: string; const APort: UInt16;
  const AConnectTimeoutMs, ATimeoutMs: Int64): ITcpStream;
var
  LDialMs: Int64;
begin
  if AConnectTimeoutMs > 0 then
    LDialMs := AConnectTimeoutMs
  else
    LDialMs := ATimeoutMs;
  if LDialMs > 0 then
    Result := TcpConnect(AHost, APort, LDialMs)
  else
    Result := TcpConnect(AHost, APort);
end;

function RequestMetadata(const AParser: IH1Parser): TH1RequestMetadata; inline;
begin
  if AParser = nil then
    Exit(Default(TH1RequestMetadata));
  Result := AParser.GetRequestMetadata;
end;

function HasHttp11HostPolicyError(const AParser: IH1Parser): Boolean; inline;
var
  LMetadata: TH1RequestMetadata;
begin
  Result := False;
  if (AParser = nil) or (AParser.GetHttpVersion <> hvHttp11) then
    Exit;
  LMetadata := RequestMetadata(AParser);
  Result := (not LMetadata.HasHost) or LMetadata.HasDuplicateHost;
end;

function ShouldSendContinueResponse(const AParser: IH1Parser;
  const AHeadersDone, AContinueSent: Boolean): Boolean; inline;
var
  LMetadata: TH1RequestMetadata;
begin
  LMetadata := RequestMetadata(AParser);
  Result := AHeadersDone and (not AContinueSent) and (AParser <> nil) and
    (not AParser.IsComplete) and LMetadata.ExpectsContinue and
    LMetadata.RequestDeclaresBody;
end;

function HeaderPolicyErrorStatus(const AParser: IH1Parser;
  const AOptions: TH1ServerTransportOptions;
  const ATotalRead: SizeUInt; const AFastSnapshot: Boolean): THttpStatus;
var
  LMetadata: TH1RequestMetadata;
begin
  Result := 0;
  if AParser = nil then
    Exit;

  LMetadata := RequestMetadata(AParser);

  if (AOptions.MaxHeaderSize > 0) and
     (Int64(ATotalRead) - AParser.GetBodySize >
      Int64(AOptions.MaxHeaderSize)) then
    Exit(HTTP_STATUS_HEADER_TOO_LARGE);

  if AParser.HasError then
    Exit(ParserErrorStatus(AParser));

  if HasHttp11HostPolicyError(AParser) then
    Exit(HTTP_STATUS_BAD_REQUEST);

  if AFastSnapshot then
    Exit(0);

  if LMetadata.HasUnsupportedExpect then
    Exit(HTTP_STATUS_EXPECTATION_FAILED);

  if LMetadata.HasInvalidContentLength then
    Exit(HTTP_STATUS_BAD_REQUEST);

  if (AOptions.MaxBodySize > 0) and LMetadata.HasContentLength and
     (LMetadata.DeclaredContentLength > AOptions.MaxBodySize) then
    Exit(HTTP_STATUS_PAYLOAD_TOO_LARGE);
end;

function IsRequestReadFailure(const E: Exception): Boolean;
begin
  Result := False;
  if E = nil then
    Exit(False);
  Result := HttpErrorIsTimeout(E) or (E is ENetworkError) or
    ((E is EHttpError) and (EHttpError(E).Kind = hekConnect));
end;

{ TReadPrependTcpStream }

constructor TReadPrependTcpStream.Create(const AInner: ITcpStream; const APrefix: string);
begin
  inherited Create;
  FInner := AInner;
  FPrefix := APrefix;
  FPrefixPos := 1;
end;

function TReadPrependTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LPtr: PByte;
  LCopy: SizeUInt;
begin
  Result := 0;
  if ACount = 0 then
    Exit(0);

  LPtr := @ABuf;
  if (FPrefixPos > 0) and (FPrefixPos <= Length(FPrefix)) then
  begin
    LCopy := SizeUInt(Length(FPrefix) - FPrefixPos + 1);
    if LCopy > ACount then
      LCopy := ACount;
    Move(FPrefix[FPrefixPos], LPtr^, LCopy);
    Inc(FPrefixPos, SizeInt(LCopy));
    Inc(Result, LCopy);
    Inc(LPtr, LCopy);
    if FPrefixPos > Length(FPrefix) then
      FPrefix := '';
  end;

  if Result < ACount then
    Inc(Result, FInner.Read(LPtr^, ACount - Result));
end;

function TReadPrependTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FInner.Write(ABuf, ACount);
end;

procedure TReadPrependTcpStream.Close;
begin
  FInner.Close;
end;

function TReadPrependTcpStream.LocalAddr: TNetAddress;
begin
  Result := FInner.LocalAddr;
end;

function TReadPrependTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FInner.RemoteAddr;
end;

procedure TReadPrependTcpStream.Shutdown;
begin
  FInner.Shutdown;
end;

procedure TReadPrependTcpStream.SetNoDelay(const AValue: Boolean);
begin
  FInner.SetNoDelay(AValue);
end;

procedure TReadPrependTcpStream.SetKeepAlive(const AValue: Boolean);
begin
  FInner.SetKeepAlive(AValue);
end;

procedure TReadPrependTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FInner.SetReadDeadline(ADeadline);
end;

procedure TReadPrependTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FInner.SetWriteDeadline(ADeadline);
end;

procedure TReadPrependTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
  FInner.SetCancelToken(AToken);
end;

{ TH1FastRequestSnapshot }

constructor TH1FastRequestSnapshot.Create(const AResult: TFastParseResult);
begin
  inherited Create;
  FMethod := AResult.Method;
  FUrl := AResult.Path;
  FVersion := AResult.Version;
  FHeaders := AResult.Headers;
  FBodySize := AResult.ContentLength;
  FComplete := True;
  FRequestMetadata := Default(TH1RequestMetadata);
  FRequestMetadata.HasHost := AResult.HasHost;
  FRequestMetadata.HasDuplicateHost := AResult.HostRepeated;
  FRequestMetadata.HasTransferEncoding := AResult.HasTransferEncoding;
  FRequestMetadata.HasContentLength := AResult.HasContentLength;
  FRequestMetadata.DeclaredContentLength := AResult.ContentLength;
  FRequestMetadata.RequestDeclaresBody := AResult.ContentLength > 0;
  FRequestMetadata.ExpectsContinue := False;
  FRequestMetadata.HasUnsupportedExpect := False;
  FRequestMetadata.ConnectionClose := AResult.ConnectionClose;
  FRequestMetadata.ConnectionKeepAlive := AResult.ConnectionKeepAlive;
end;

function TH1FastRequestSnapshot.Execute(const ABuf: PAnsiChar;
  const ALen: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

procedure TH1FastRequestSnapshot.Finish;
begin
end;

function TH1FastRequestSnapshot.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TH1FastRequestSnapshot.GetStatusCode: THttpStatus;
begin
  Result := 0;
end;

function TH1FastRequestSnapshot.GetHttpVersion: THttpVersion;
begin
  Result := FVersion;
end;

function TH1FastRequestSnapshot.GetUrl: string;
begin
  Result := FUrl;
end;

function TH1FastRequestSnapshot.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TH1FastRequestSnapshot.GetBody: string;
begin
  Result := '';
end;

function TH1FastRequestSnapshot.GetBodySize: Int64;
begin
  Result := FBodySize;
end;

function TH1FastRequestSnapshot.NewBodyReader: IReader;
begin
  Result := nil;
end;

function TH1FastRequestSnapshot.HeadersComplete: Boolean;
begin
  Result := FComplete;
end;

function TH1FastRequestSnapshot.IsComplete: Boolean;
begin
  Result := FComplete;
end;

function TH1FastRequestSnapshot.ShouldKeepAlive: Boolean;
begin
  if FVersion = hvHttp10 then
    Result := FRequestMetadata.ConnectionKeepAlive
  else
    Result := not FRequestMetadata.ConnectionClose;
end;

function TH1FastRequestSnapshot.GetTrailerBytes: Int64;
begin
  Result := 0;
end;

function TH1FastRequestSnapshot.GetRequestMetadata: TH1RequestMetadata;
begin
  Result := FRequestMetadata;
end;

function TH1FastRequestSnapshot.HasError: Boolean;
begin
  Result := False;
end;

function TH1FastRequestSnapshot.ErrorMessage: string;
begin
  Result := '';
end;

function TH1FastRequestSnapshot.ErrorKind: TH1ParserErrorKind;
begin
  Result := pekNone;
end;

procedure TH1FastRequestSnapshot.Reset;
begin
  FComplete := False;
  FHeaders := NewHttpHeaders;
  FUrl := '';
  FBodySize := 0;
  FRequestMetadata := Default(TH1RequestMetadata);
end;

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus;
  const AWriteTimeoutMs: Int64 = 0);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  try
    if AWriteTimeoutMs > 0 then
      AConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(AWriteTimeoutMs)));
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LBody := HttpStatusText(AStatus);
    LW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    LW.GetHeaders.SetHeader('connection', 'close');
    LW.WriteHeader(AStatus);
    if Length(LBody) > 0 then
      LW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    { Ignore secondary write failures while sending an error response. }
  end;
end;

procedure WriteErrorResponseToWriter(const AWriter: IWriter;
  const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LBody := HttpStatusText(AStatus);
  LW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
  LW.GetHeaders.SetHeader('connection', 'close');
  LW.WriteHeader(AStatus);
  if Length(LBody) > 0 then
    LW.Write(LBody[1], SizeUInt(Length(LBody)));
end;

function TryWriteContinueResponse(const AConn: ITcpStream;
  const AWriteTimeoutMs: Int64 = 0): Boolean;
var
  LW: IHttpResponseWriter;
begin
  Result := False;
  try
    if AWriteTimeoutMs > 0 then
      AConn.SetWriteDeadline(TDeadline.After(
        TDuration.FromMilliseconds(AWriteTimeoutMs)));
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LW.WriteHeader(HTTP_STATUS_CONTINUE);
    Result := True;
  except
    Result := False;
  end;
end;

procedure WriteContinueResponseToWriter(const AWriter: IWriter);
var
  LW: IHttpResponseWriter;
begin
  LW := TH1ResponseWriter.Create(AWriter);
  LW.WriteHeader(HTTP_STATUS_CONTINUE);
end;

{ TH1PollRunWork }

constructor TH1PollRunWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRunWork.Execute: TTcpServerConnOwnership;
begin
  Result := FState.Run;
end;

{ TH1PollRequestWork }

constructor TH1PollRequestWork.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

function TH1PollRequestWork.Execute: TTcpServerConnOwnership;
begin
  if FState.UsePollOwnedResponseDrain then
    Result := FState.ExecuteCurrentPollRequest(FOutbound, FCloseAfterDrain)
  else
    Result := FState.ExecuteCurrentRequest;
end;

{ TH1PollRunCompletion }

constructor TH1PollRunCompletion.Create(const AState: TH1ServerConnectionState);
begin
  inherited Create;
  FState := AState;
end;

procedure TH1PollRunCompletion.Complete(const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
      FState.FPollCompletionOwnership := AOwnership
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FState := nil;
end;

{ TH1PollRequestCompletion }

constructor TH1PollRequestCompletion.Create(const AState: TH1ServerConnectionState;
  const AWork: TH1PollRequestWork);
begin
  inherited Create;
  FState := AState;
  FWorkRef := AWork as ITcpServerWork;
  FWork := AWork;
end;

procedure TH1PollRequestCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FState <> nil then
  begin
    if AOutcome = tswoCompleted then
    begin
      if AOwnership = tscoServer then
        FState.ApplyPollRequestResult(FWork);
      FState.FPollCompletionOwnership := AOwnership;
    end
    else
    begin
      FState.FPollCompletionOwnership := tscoServer;
      FState.FKeepAlive := False;
    end;
    FState.FPollCompletionReady := True;
  end;
  FWorkRef := nil;
  FWork := nil;
  FState := nil;
end;

{ TH1ServerConnectionState }

constructor TH1ServerConnectionState.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH1ServerTransportOptions);
begin
  Create(AConn, AHandler, AOptions, nil);
end;

constructor TH1ServerConnectionState.Create(const AConn: ITcpStream;
  const AHandler: IHttpHandler; const AOptions: TH1ServerTransportOptions;
  const AContext: ITcpServerSessionContext);
begin
  inherited Create;
  FOptions := AOptions;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := AContext;
  Supports(AConn, ITcpSocketRuntime, FSocketRuntime);
  Supports(AConn, ITcpStreamRuntime, FStreamRuntime);
  if AContext <> nil then
    FWorkerHandoff := AContext.WorkerHandoff
  else
    FWorkerHandoff := nil;
  FParser := NewH1RequestParser;
  FPending := '';
  FKeepAlive := True;
  { Connection-scoped request arena: one LocalArena, Reset per request. }
  if AOptions.RequestArena then
    FRequestArena := HttpCreateRequestArena(AOptions.RequestArenaCapacity)
  else
    FRequestArena := nil;
  if FOptions.IdleTimeout > 0 then
    FIdleMs := FOptions.IdleTimeout
  else
    FIdleMs := 30000;
  if FOptions.ReadTimeout > 0 then
    FReadMs := FOptions.ReadTimeout
  else
    FReadMs := FIdleMs;
  FPollSubmitted := False;
  FPollWorkerPending := False;
  FPollCompletionReady := False;
  FPollCompletionOwnership := tscoServer;
  FPollNeedRequestReset := False;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FContinueSent := False;
  FPollOutbound := nil;
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollReadDeadline := TDeadline.Infinite;
  FPollReadDeadlineIsIdle := False;
  FPollWriteDeadline := TDeadline.Infinite;
  FParserIsSnapshot := False;
  FRequestCount := 0;
  if FStreamRuntime <> nil then
    ArmPollRequestReadDeadline;
end;

procedure TH1ServerConnectionState.InvokeHandler(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
begin
  if FRequestArena = nil then
  begin
    FHandler.ServeHTTP(AReq, AW);
    Exit;
  end;
  { Connection-scoped LocalArena: Reset → attach → ServeHTTP → detach → Reset. }
  FRequestArena.Reset;
  HttpAttachRequestArena(AReq, FRequestArena);
  try
    FHandler.ServeHTTP(AReq, AW);
  finally
    HttpDetachRequestArena(AReq);
    FRequestArena.Reset;
  end;
end;

procedure TH1ServerConnectionState.ArmPollReadDeadline(const ATimeoutMs: Int64;
  const AIsIdle: Boolean);
begin
  if FStreamRuntime = nil then
    Exit;
  FPollReadDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs));
  FPollReadDeadlineIsIdle := AIsIdle;
  FConn.SetReadDeadline(FPollReadDeadline);
end;

procedure TH1ServerConnectionState.ArmPollRequestReadDeadline;
begin
  ArmPollReadDeadline(FReadMs, False);
end;

procedure TH1ServerConnectionState.ClearPollReadDeadline;
begin
  FPollReadDeadline := TDeadline.Infinite;
  FPollReadDeadlineIsIdle := False;
  if FStreamRuntime <> nil then
    FConn.SetReadDeadline(TDeadline.Infinite);
end;

procedure TH1ServerConnectionState.ResetRequestParser;
begin
  if (FParser = nil) or FParserIsSnapshot then
  begin
    FParser := NewH1RequestParser;
    FParserIsSnapshot := False;
  end
  else
    FParser.Reset;
end;

function TH1ServerConnectionState.TryUseFastRequestParser(const ABuf: PAnsiChar;
  const ALen: SizeUInt; out AConsumed: SizeUInt): Boolean;
var
  LFast: TFastParseResult;
begin
  Result := False;
  AConsumed := 0;
  try
    LFast := FastParseRequest(ABuf, ALen);
  except
    Exit(False);
  end;

  if (not LFast.Success) or (LFast.Consumed = 0) or
     (LFast.Consumed > ALen) then
    Exit(False);

  if (LFast.Version <> hvHttp11) or
     (LFast.ContentLength <> 0) or
     (not LFast.HasHost) or
     LFast.HostRepeated or
     LFast.HasExpect or
     LFast.HasTransferEncoding then
    Exit(False);

  if LFast.HasConnection and
     ((not LFast.ConnectionKeepAlive) or
      LFast.ConnectionClose or
      LFast.ConnectionUnsupported) then
    Exit(False);

  FParser := TH1FastRequestSnapshot.Create(LFast);
  FParserIsSnapshot := True;
  AConsumed := LFast.Consumed;
  Result := True;
end;

procedure TH1ServerConnectionState.ResetPollRequestStateWithDeadline(
  const ATimeoutMs: Int64; const AIsIdle: Boolean);
begin
  ResetRequestParser;
  FParseTotalRead := 0;
  FParseHeadersDone := False;
  FContinueSent := False;
  FPollNeedRequestReset := False;
  ArmPollReadDeadline(ATimeoutMs, AIsIdle);
end;

procedure TH1ServerConnectionState.ResetPollRequestState;
begin
  ResetPollRequestStateWithDeadline(FReadMs, False);
end;

procedure TH1ServerConnectionState.PreparePollRequestParse;
begin
  if FPollNeedRequestReset then
    ResetPollRequestState;
end;

procedure TH1ServerConnectionState.PreparePollKeepAliveRequestParse;
begin
  if not FPollNeedRequestReset then
    Exit;
  if FPending = '' then
    ResetPollRequestStateWithDeadline(FIdleMs, True)
  else
    ResetPollRequestState;
end;

procedure TH1ServerConnectionState.ResetPollResponseState;
begin
  FPollOutbound := nil;
  FPollResponsePending := False;
  FPollCloseAfterDrain := False;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.PromoteQueuedPollResponse;
begin
  if not FPollQueuedResponsePending then
    Exit;

  FPollOutbound := FPollQueuedOutbound;
  FPollResponsePending := (FPollOutbound <> nil) and (not FPollOutbound.IsEmpty);
  FPollCloseAfterDrain := FPollQueuedCloseAfterDrain;
  FPollQueuedOutbound := nil;
  FPollQueuedResponsePending := False;
  FPollQueuedCloseAfterDrain := False;
  FPollWriteDeadline := TDeadline.Infinite;
end;

function TH1ServerConnectionState.EnqueuePollResponse(
  const AOutbound: IH1OutboundBuffer; const ACloseAfterDrain: Boolean): Boolean;
begin
  if (AOutbound = nil) or AOutbound.IsEmpty then
    Exit(True);

  if not FPollResponsePending then
  begin
    FPollOutbound := AOutbound;
    FPollResponsePending := True;
    FPollCloseAfterDrain := ACloseAfterDrain;
    Exit(True);
  end;

  if not FPollQueuedResponsePending then
  begin
    FPollQueuedOutbound := AOutbound;
    FPollQueuedResponsePending := True;
    FPollQueuedCloseAfterDrain := ACloseAfterDrain;
    Exit(True);
  end;

  Result := False;
end;

function TH1ServerConnectionState.CanParseBufferedPollRequestWhileDraining: Boolean;
begin
  Result := (FOptions.WriteTimeout <= 0) and FKeepAlive and (FPending <> '') and
    FPollResponsePending and
    (not FPollCloseAfterDrain) and (not FPollQueuedResponsePending);
end;

function TH1ServerConnectionState.ShouldWaitForWritableInsteadOfEagerDrain(
  const AEvents: TPlatformPollEvents): Boolean;
begin
  Result := (FPending <> '') and FPollResponsePending and
    FPollQueuedResponsePending and (not (peWritable in AEvents));
end;

function TH1ServerConnectionState.QueuePollErrorResponse(
  const AStatus: THttpStatus): Boolean;
var
  LOutbound: IH1OutboundBuffer;
begin
  LOutbound := NewH1OutboundBuffer;
  WriteErrorResponseToWriter(LOutbound as IWriter, AStatus);
  Result := EnqueuePollResponse(LOutbound, True);
end;

procedure TH1ServerConnectionState.ApplyPollRequestResult(
  const AWork: TH1PollRequestWork);
begin
  if (AWork = nil) then
    Exit;

  if not EnqueuePollResponse(AWork.Outbound, AWork.CloseAfterDrain) then
    FKeepAlive := False;
end;

procedure TH1ServerConnectionState.ArmPollWriteDeadline;
begin
  if FOptions.WriteTimeout > 0 then
  begin
    FPollWriteDeadline := TDeadline.After(
      TDuration.FromMilliseconds(FOptions.WriteTimeout));
    FConn.SetWriteDeadline(FPollWriteDeadline);
  end
  else
    FPollWriteDeadline := TDeadline.Infinite;
end;

procedure TH1ServerConnectionState.ArmDirectWriteDeadline;
begin
  if FOptions.WriteTimeout > 0 then
    FConn.SetWriteDeadline(TDeadline.After(
      TDuration.FromMilliseconds(FOptions.WriteTimeout)));
end;

function TH1ServerConnectionState.UsePollOwnedResponseDrain: Boolean;
begin
  Result := FStreamRuntime <> nil;
end;

function TH1ServerConnectionState.ExecuteCurrentRequest: TTcpServerConnOwnership;
var
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LBodyReader: IReader;
  LContentLen: Int64;
  LHijackConn: ITcpStream;
  LOutbound: IH1OutboundBuffer;
  LResponseWriter: IWriter;
  LDrainStarted: Boolean;
  LKeepAlive: Boolean;
begin
  Result := tscoServer;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  LDrainStarted := False;
  try
    if FParserIsSnapshot then
      LKeepAlive := True
    else
      LKeepAlive := ShouldKeepAlive(FParser);

    { Enforce MaxRequestsPerConnection before writing response headers }
    Inc(FRequestCount);
    if (FOptions.MaxRequestsPerConnection > 0) and
       (FRequestCount >= FOptions.MaxRequestsPerConnection) then
      LKeepAlive := False;
    FKeepAlive := LKeepAlive;

    if HasHttp11HostPolicyError(FParser) then
    begin
      WriteErrorResponse(FConn, HTTP_STATUS_BAD_REQUEST, FOptions.WriteTimeout);
      FKeepAlive := False;
      Exit(tscoServer);
    end;

    LContentLen := FParser.GetBodySize;
    LBodyReader := FParser.NewBodyReader;
    if LBodyReader <> nil then
    begin
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders,
        LBodyReader, LContentLen);
    end
    else
    begin
      LContentLen := 0;
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders, nil,
        LContentLen);
    end;

    (LReq as THttpRequest).SetRemoteNetAddr(FConn.RemoteAddr);

    if FPending <> '' then
      LHijackConn := TReadPrependTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := NewH1OutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
    if LKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.SetHeader('connection', 'keep-alive');
    if not LKeepAlive then
      LW.GetHeaders.SetHeader('connection', 'close');

    InvokeHandler(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      FConn.SetReadDeadline(TDeadline.Infinite);
      Exit;
    end;

    LW.Flush;
    LDrainStarted := True;
    ArmDirectWriteDeadline;
    LOutbound.DrainAllTo(FConn as IWriter);

  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
        Result := tscoHandler
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
        WriteErrorResponse(FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR,
          FOptions.WriteTimeout);
      if (LW <> nil) and (not (LW as TH1ResponseWriter).IsHijacked) and
         (LW as TH1ResponseWriter).HasCommitted and (not LDrainStarted) then
      begin
        try
          if (LOutbound <> nil) and (not LOutbound.IsEmpty) then
          begin
            ArmDirectWriteDeadline;
            LOutbound.DrainAllTo(FConn as IWriter);
          end;
        except
        end;
      end;
      FKeepAlive := False;
    end;
  end;
end;

function TH1ServerConnectionState.ExecuteCurrentPollRequest(
  out AOutbound: IH1OutboundBuffer; out ACloseAfterDrain: Boolean): TTcpServerConnOwnership;
var
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
  LBodyReader: IReader;
  LContentLen: Int64;
  LHijackConn: ITcpStream;
  LOutbound: IH1OutboundBuffer;
  LResponseWriter: IWriter;
  LKeepAlive: Boolean;
begin
  Result := tscoServer;
  AOutbound := nil;
  ACloseAfterDrain := False;
  LW := nil;
  LOutbound := nil;
  LResponseWriter := nil;
  try
    if FParserIsSnapshot then
      LKeepAlive := True
    else
      LKeepAlive := ShouldKeepAlive(FParser);

    { Enforce MaxRequestsPerConnection before writing response headers }
    Inc(FRequestCount);
    if (FOptions.MaxRequestsPerConnection > 0) and
       (FRequestCount >= FOptions.MaxRequestsPerConnection) then
      LKeepAlive := False;
    FKeepAlive := LKeepAlive;

    if HasHttp11HostPolicyError(FParser) then
    begin
      LOutbound := NewH1OutboundBuffer;
      WriteErrorResponseToWriter(LOutbound as IWriter, HTTP_STATUS_BAD_REQUEST);
      AOutbound := LOutbound;
      ACloseAfterDrain := True;
      Exit(tscoServer);
    end;

    LContentLen := FParser.GetBodySize;
    LBodyReader := FParser.NewBodyReader;
    if LBodyReader <> nil then
    begin
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders,
        LBodyReader, LContentLen);
    end
    else
    begin
      LContentLen := 0;
      LReq := THttpRequest.CreateFromRequestTarget(FParser.GetMethod,
        FParser.GetUrl, FParser.GetHttpVersion, FParser.GetHeaders, nil,
        LContentLen);
    end;

    (LReq as THttpRequest).SetRemoteNetAddr(FConn.RemoteAddr);

    if FPending <> '' then
      LHijackConn := TReadPrependTcpStream.Create(FConn, FPending)
    else
      LHijackConn := FConn;
    LOutbound := NewH1OutboundBuffer;
    LResponseWriter := LOutbound as IWriter;
    LW := TH1ResponseWriter.Create(LResponseWriter, LHijackConn,
      LReq.Method = hmHead);
    if LKeepAlive and (FParser.GetHttpVersion = hvHttp10) then
      LW.GetHeaders.SetHeader('connection', 'keep-alive');
    if not LKeepAlive then
      LW.GetHeaders.SetHeader('connection', 'close');

    InvokeHandler(LReq, LW);

    if (LW as TH1ResponseWriter).IsHijacked then
    begin
      Result := tscoHandler;
      FKeepAlive := False;
      Exit;
    end;

    LW.Flush;

    ACloseAfterDrain := not LKeepAlive;
    AOutbound := LOutbound;
  except
    on E: Exception do
    begin
      if (LW <> nil) and (LW as TH1ResponseWriter).IsHijacked then
        Result := tscoHandler
      else if (LW = nil) or (not (LW as TH1ResponseWriter).HasCommitted) then
      begin
        if LOutbound = nil then
        begin
          LOutbound := NewH1OutboundBuffer;
          LResponseWriter := LOutbound as IWriter;
        end;
        try
          WriteErrorResponseToWriter(LOutbound as IWriter,
            HTTP_STATUS_INTERNAL_SERVER_ERROR);
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        except
          AOutbound := nil;
          ACloseAfterDrain := False;
        end;
      end
      else
      begin
        if (LOutbound <> nil) and (not LOutbound.IsEmpty) then
        begin
          AOutbound := LOutbound;
          ACloseAfterDrain := True;
        end
      end;
    end;
  end;
end;

function TH1ServerConnectionState.Run: TTcpServerConnOwnership;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LTotalRead: SizeUInt;
  LHeadersDone: Boolean;
  LRejected: Boolean;
  LHeaderStatus: THttpStatus;
  LIdleBeforeNextRequest: Boolean;
  LUsingIdleDeadline: Boolean;
begin
  Result := tscoServer;
  LIdleBeforeNextRequest := False;
  while FKeepAlive do
  begin
    try
      LUsingIdleDeadline := LIdleBeforeNextRequest and (FPending = '');
      if LUsingIdleDeadline then
        FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FIdleMs)))
      else
        FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FReadMs)));
      LIdleBeforeNextRequest := False;

      ResetRequestParser;
      LTotalRead := 0;
      LHeadersDone := False;
      FContinueSent := False;
      LRejected := False;
      { INV-12 keep-alive request-tail:
        parser only consumes the current framed request; any remainder stays in
        FPending for the next loop. Partial follow-up bytes are not rejected
        early; conclusively malformed / EOF-truncated follow-ups become the
        next request's 400 after the prior response. }
      repeat
        if FPending <> '' then
        begin
          LN := SizeUInt(Length(FPending));
          if not ((LTotalRead = 0) and
             TryUseFastRequestParser(PAnsiChar(FPending), LN, LConsumed)) then
            LConsumed := FParser.Execute(PAnsiChar(FPending), LN);
          if LConsumed < LN then
            FPending := Copy(FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
          else
            FPending := '';
        end
        else
        begin
          LN := FConn.Read(FBuf[0], 16384);
          if LN = 0 then
          begin
            FKeepAlive := False;
            if (LTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            Break;
          end;
          if LUsingIdleDeadline then
          begin
            FConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(FReadMs)));
            LUsingIdleDeadline := False;
          end;
          if not ((LTotalRead = 0) and
             TryUseFastRequestParser(@FBuf[0], LN, LConsumed)) then
            LConsumed := FParser.Execute(@FBuf[0], LN);
          if LConsumed < LN then
          begin
            SetLength(FPending, Int32(LN - LConsumed));
            Move(FBuf[LConsumed], FPending[1], LN - LConsumed);
          end;
        end;
        Inc(LTotalRead, LConsumed);
        if (not LHeadersDone) and FParser.HeadersComplete then
        begin
          LHeadersDone := True;
          LHeaderStatus := HeaderPolicyErrorStatus(FParser, FOptions,
            LTotalRead, FParserIsSnapshot);
          if LHeaderStatus <> 0 then
          begin
            WriteErrorResponse(FConn, LHeaderStatus, FOptions.WriteTimeout);
            LRejected := True;
            FKeepAlive := False;
            Break;
          end;
          if ShouldSendContinueResponse(FParser, LHeadersDone, FContinueSent) then
          begin
            if not TryWriteContinueResponse(FConn, FOptions.WriteTimeout) then
            begin
              FKeepAlive := False;
              Break;
            end;
            FContinueSent := True;
          end;
        end;
        if LHeadersDone and (FOptions.MaxHeaderSize > 0) and
           (FParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_HEADER_TOO_LARGE,
            FOptions.WriteTimeout);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
        if (FOptions.MaxBodySize > 0) and
           (FParser.GetBodySize > FOptions.MaxBodySize) then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE,
            FOptions.WriteTimeout);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
        if FParser.HasError then
        begin
          WriteErrorResponse(FConn, ParserErrorStatus(FParser),
            FOptions.WriteTimeout);
          LRejected := True;
          FKeepAlive := False;
          Break;
        end;
      until FParser.IsComplete or FParser.HasError;

      if LRejected then
        Break;

      if FParser.HasError then
      begin
        WriteErrorResponse(FConn, ParserErrorStatus(FParser),
          FOptions.WriteTimeout);
        Break;
      end;

      if not FParser.IsComplete then
        Break;

      if FOptions.MaxBodySize > 0 then
      begin
        if FParser.GetBodySize > FOptions.MaxBodySize then
        begin
          WriteErrorResponse(FConn, HTTP_STATUS_PAYLOAD_TOO_LARGE,
            FOptions.WriteTimeout);
          FKeepAlive := False;
          Continue;
        end;
      end;

      Result := ExecuteCurrentRequest;
      if Result <> tscoServer then
        Continue;
      LIdleBeforeNextRequest := FKeepAlive and (FPending = '');
    except
      on E: Exception do
      begin
        if not IsRequestReadFailure(E) then
          WriteErrorResponse(FConn, HTTP_STATUS_INTERNAL_SERVER_ERROR,
            FOptions.WriteTimeout);
        FKeepAlive := False;
      end;
    end;
  end;
end;

function TH1ServerConnectionState.AdvanceWholeRunBridge(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
begin
  AOwnership := tscoServer;

  if not FPollSubmitted then
  begin
    if not (peReadable in AEvents) then
    begin
      ANextEvents := [peReadable];
      Exit(tsprWait);
    end;

    if FWorkerHandoff = nil then
    begin
      ANextEvents := [];
      AOwnership := Run;
      Exit(tsprDone);
    end;

    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(True);

    LWork := TH1PollRunWork.Create(Self);
    LCompletion := TH1PollRunCompletion.Create(Self);
    LHandoffResult := FWorkerHandoff.Submit(LWork, LCompletion);
    if LHandoffResult <> tshrAccepted then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;

    FPollSubmitted := True;
    ANextEvents := [];
    Exit(tsprWait);
  end;

  if not FPollCompletionReady then
  begin
    ANextEvents := [];
    Exit(tsprWait);
  end;

  ANextEvents := [];
  AOwnership := FPollCompletionOwnership;
  Result := tsprDone;
end;

function TH1ServerConnectionState.SubmitCurrentPollRequest(
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWorkRef: TH1PollRequestWork;
  LWork: ITcpServerWork;
  LCompletion: ITcpServerWorkCompletion;
  LHandoffResult: TTcpServerHandoffResult;
  LOutbound: IH1OutboundBuffer;
  LCloseAfterDrain: Boolean;
begin
  AOwnership := tscoServer;
  ClearPollReadDeadline;

  if FWorkerHandoff = nil then
  begin
    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(True);
    FPollNeedRequestReset := True;
    if UsePollOwnedResponseDrain then
      AOwnership := ExecuteCurrentPollRequest(LOutbound, LCloseAfterDrain)
    else
      AOwnership := ExecuteCurrentRequest;
    if AOwnership <> tscoServer then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    if UsePollOwnedResponseDrain then
      EnqueuePollResponse(LOutbound, LCloseAfterDrain);
    if FSocketRuntime <> nil then
      FSocketRuntime.SetBlocking(False);
    if CanParseBufferedPollRequestWhileDraining then
    begin
      PreparePollRequestParse;
      Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
    end;
    if FPollResponsePending then
    begin
      if ShouldWaitForWritableInsteadOfEagerDrain([]) then
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
      Exit(AdvancePollResponseDrain([], ANextEvents, AOwnership));
    end;
    if not FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    PreparePollKeepAliveRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;

  if FSocketRuntime <> nil then
    FSocketRuntime.SetBlocking(True);

  FPollNeedRequestReset := True;
  FPollWorkerPending := True;
  FPollCompletionReady := False;
  LWorkRef := TH1PollRequestWork.Create(Self);
  LWork := LWorkRef;
  LCompletion := TH1PollRequestCompletion.Create(Self, LWorkRef);
  LHandoffResult := FWorkerHandoff.Submit(LWork, LCompletion);
  if LHandoffResult <> tshrAccepted then
  begin
    FPollWorkerPending := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  ANextEvents := [];
  Result := tsprWait;
end;

function TH1ServerConnectionState.ContinueAfterPollCompletion(
  const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  FPollWorkerPending := False;
  FPollCompletionReady := False;
  AOwnership := FPollCompletionOwnership;

  if AOwnership <> tscoServer then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FSocketRuntime <> nil then
    FSocketRuntime.SetBlocking(False);
  if CanParseBufferedPollRequestWhileDraining then
  begin
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;
  if FPollResponsePending then
  begin
    if ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
  end;
  if not FKeepAlive then
  begin
    ANextEvents := [];
    Exit(tsprDone);
  end;
  PreparePollKeepAliveRequestParse;
  Result := AdvancePollRequestParse([], ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.AdvancePollResponseDrain(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LWritten: SizeUInt;
  LWriteResult: TTcpStreamIOResult;
  LCloseAfterDrain: Boolean;
begin
  AOwnership := tscoServer;

  if (not FPollResponsePending) or (FPollOutbound = nil) or FPollOutbound.IsEmpty then
  begin
    PromoteQueuedPollResponse;
    if (not FPollResponsePending) or (FPollOutbound = nil) or FPollOutbound.IsEmpty then
      ResetPollResponseState;
    if not FKeepAlive then
    begin
      ANextEvents := [];
      Exit(tsprDone);
    end;
    PreparePollKeepAliveRequestParse;
    Exit(AdvancePollRequestParse(AEvents, ANextEvents, AOwnership));
  end;

  if (not FPollWriteDeadline.IsInfinite) and FPollWriteDeadline.IsExpired then
  begin
    ResetPollResponseState;
    FKeepAlive := False;
    ANextEvents := [];
    Exit(tsprDone);
  end;

  if FPollWriteDeadline.IsInfinite then
    ArmPollWriteDeadline;

  LWriteResult := FPollOutbound.TryDrainTo(FStreamRuntime, LWritten);
  case LWriteResult of
    tsiorOk:
      begin
        if FPollOutbound.IsEmpty then
        begin
          LCloseAfterDrain := FPollCloseAfterDrain;
          FPollOutbound := nil;
          FPollResponsePending := False;
          FPollCloseAfterDrain := False;
          FPollWriteDeadline := TDeadline.Infinite;
          if LCloseAfterDrain then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          if FPollQueuedResponsePending then
          begin
            PromoteQueuedPollResponse;
            if (FPending <> '') and (not FPollCloseAfterDrain) then
            begin
              ANextEvents := [peWritable];
              Exit(tsprWait);
            end;
            Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
          end;
          if not FKeepAlive then
          begin
            ANextEvents := [];
            Exit(tsprDone);
          end;
          PreparePollKeepAliveRequestParse;
          Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
        end;
        if LWritten > 0 then
          ArmPollWriteDeadline;
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
    tsiorWouldBlock:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  else
    begin
      ResetPollResponseState;
      FKeepAlive := False;
      ANextEvents := [];
      Exit(tsprDone);
    end;
  end;
end;

function TH1ServerConnectionState.AdvancePollRequestParse(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
var
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LReadResult: TTcpStreamIOResult;
  LContinueOutbound: IH1OutboundBuffer;
  LHeaderStatus: THttpStatus;
  function FinishPollParseError(const AStatus: THttpStatus): TTcpServerPollResult;
  begin
    ClearPollReadDeadline;
    if QueuePollErrorResponse(AStatus) then
    begin
      FKeepAlive := False;
      Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
    end;

    WriteErrorResponse(FConn, AStatus, FOptions.WriteTimeout);
    FKeepAlive := False;
    ANextEvents := [];
    Result := tsprDone;
  end;
begin
  AOwnership := tscoServer;

  while True do
  begin
    if FPending <> '' then
    begin
      LN := SizeUInt(Length(FPending));
      if not ((FParseTotalRead = 0) and
         TryUseFastRequestParser(PAnsiChar(FPending), LN, LConsumed)) then
        LConsumed := FParser.Execute(PAnsiChar(FPending), LN);
      if LConsumed < LN then
        FPending := Copy(FPending, Int32(LConsumed) + 1, Int32(LN - LConsumed))
      else
        FPending := '';
    end
    else
    begin
      if FStreamRuntime = nil then
        Exit(AdvanceWholeRunBridge(AEvents, ANextEvents, AOwnership));
      if not (peReadable in AEvents) then
      begin
        if FPollReadDeadline.IsExpired then
        begin
          ClearPollReadDeadline;
          FKeepAlive := False;
          ANextEvents := [];
          Exit(tsprDone);
        end;
        if FPollResponsePending then
          Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
        ANextEvents := [peReadable];
        Exit(tsprWait);
      end;

      LReadResult := FStreamRuntime.TryRead(FBuf[0], SizeUInt(SizeOf(FBuf)), LN);
      case LReadResult of
        tsiorWouldBlock:
          begin
            if FPollReadDeadline.IsExpired then
            begin
              ClearPollReadDeadline;
              FKeepAlive := False;
              ANextEvents := [];
              Exit(tsprDone);
            end;
            ANextEvents := [peReadable];
            Exit(tsprWait);
          end;
        tsiorClosed:
          begin
            ClearPollReadDeadline;
            FKeepAlive := False;
            if (FParseTotalRead > 0) and (not FParser.IsComplete) and
               (not FParser.HasError) then
              FParser.Finish;
            if FParser.HasError then
              Exit(FinishPollParseError(ParserErrorStatus(FParser)));
            ANextEvents := [];
            Exit(tsprDone);
          end;
      else
      begin
        if FPollReadDeadlineIsIdle then
          ArmPollRequestReadDeadline;
        if not ((FParseTotalRead = 0) and
           TryUseFastRequestParser(@FBuf[0], LN, LConsumed)) then
          LConsumed := FParser.Execute(@FBuf[0], LN);
        if LConsumed < LN then
        begin
          SetLength(FPending, Int32(LN - LConsumed));
          Move(FBuf[LConsumed], FPending[1], LN - LConsumed);
        end;
      end;
      end;
    end;

    Inc(FParseTotalRead, LConsumed);
    if (not FParseHeadersDone) and FParser.HeadersComplete then
    begin
      FParseHeadersDone := True;
      LHeaderStatus := HeaderPolicyErrorStatus(FParser, FOptions,
        FParseTotalRead, FParserIsSnapshot);
      if LHeaderStatus <> 0 then
        Exit(FinishPollParseError(LHeaderStatus));
      if ShouldSendContinueResponse(FParser, FParseHeadersDone, FContinueSent) then
      begin
        LContinueOutbound := NewH1OutboundBuffer;
        WriteContinueResponseToWriter(LContinueOutbound as IWriter);
        if not EnqueuePollResponse(LContinueOutbound, False) then
        begin
          FKeepAlive := False;
          ANextEvents := [];
          Exit(tsprDone);
        end;
        FContinueSent := True;
        Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
      end;
    end;

    if FParseHeadersDone and (FOptions.MaxHeaderSize > 0) and
       (FParser.GetTrailerBytes > Int64(FOptions.MaxHeaderSize)) then
      Exit(FinishPollParseError(HTTP_STATUS_HEADER_TOO_LARGE));

    if (FOptions.MaxBodySize > 0) and
       (FParser.GetBodySize > FOptions.MaxBodySize) then
      Exit(FinishPollParseError(HTTP_STATUS_PAYLOAD_TOO_LARGE));

    if FParser.HasError then
      Exit(FinishPollParseError(ParserErrorStatus(FParser)));

    if FParser.IsComplete then
      Exit(SubmitCurrentPollRequest(ANextEvents, AOwnership));
  end;
end;

function TH1ServerConnectionState.PollEvents: TPlatformPollEvents;
begin
  Result := [peReadable];
end;

function TH1ServerConnectionState.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;

  if FStreamRuntime = nil then
    Exit(AdvanceWholeRunBridge(AEvents, ANextEvents, AOwnership));

  if FPollWorkerPending then
  begin
    if not FPollCompletionReady then
    begin
      ANextEvents := [];
      Exit(tsprWait);
    end;
    Exit(ContinueAfterPollCompletion(AEvents, ANextEvents, AOwnership));
  end;

  if CanParseBufferedPollRequestWhileDraining then
  begin
    PreparePollRequestParse;
    Exit(AdvancePollRequestParse([], ANextEvents, AOwnership));
  end;
  if FPollResponsePending then
  begin
    if ShouldWaitForWritableInsteadOfEagerDrain(AEvents) then
    begin
      ANextEvents := [peWritable];
      Exit(tsprWait);
    end;
    Exit(AdvancePollResponseDrain(AEvents, ANextEvents, AOwnership));
  end;

  Result := AdvancePollRequestParse(AEvents, ANextEvents, AOwnership);
end;

function TH1ServerConnectionState.WakeDeadline: TDeadline;
begin
  Result := TDeadline.Min(FPollReadDeadline, FPollWriteDeadline);
end;

{ TH1ClientTransport }

constructor TH1ClientTransport.Create(const AOptions: TH1ClientTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
  if FOptions.MaxPoolSize <= 0 then
    FOptions.MaxPoolSize := 64;
  FPoolLock := Mutex;
  FPoolCount := 0;
  FDefaultTLSContext := nil;
end;

destructor TH1ClientTransport.Destroy;
begin
  PoolClear;
  FPoolLock := nil;
  FDefaultTLSContext := nil;
  inherited Destroy;
end;

function TH1ClientTransport.SecureClientContext: ISSLContext;
begin
  if FOptions.TLSContext <> nil then
    Exit(FOptions.TLSContext);
  if FDefaultTLSContext = nil then
    FDefaultTLSContext := TSSLQuick.SecureClient;
  Result := FDefaultTLSContext;
end;

procedure TH1ClientTransport.EstablishHttpsConnectTunnel(var AConn: ITcpStream;
  const ATargetHost: string; const ATargetPort: UInt16;
  const AProxyAuthorization: string);
const
  CRLF: AnsiString = #13#10;
var
  LAuthority: string;
  LRequest: string;
  LResp: IHttpResponse;
  LKeepAlive: Boolean;
  LResponseStarted: Boolean;
  LBody: IReader;
  LTmp: array[0..255] of Byte;
  LN: SizeUInt;
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'proxy CONNECT requires connection');
  if ATargetHost = '' then
    raise EHttpError.Create(hekArgument, 'proxy CONNECT target host is empty');

  LAuthority := ConnectAuthority(ATargetHost, ATargetPort);
  ValidateWireRequestTarget(LAuthority);
  ValidateWireHeaderValue(LAuthority);
  if AProxyAuthorization <> '' then
    ValidateWireHeaderValue(AProxyAuthorization);

  LRequest := 'CONNECT ' + LAuthority + ' HTTP/1.1' + CRLF +
    'Host: ' + LAuthority + CRLF +
    'Proxy-Connection: keep-alive' + CRLF;
  if AProxyAuthorization <> '' then
    LRequest := LRequest +
      'Proxy-Authorization: ' + AProxyAuthorization + CRLF;
  LRequest := LRequest + CRLF;
  AConn.Write(LRequest[1], SizeUInt(Length(LRequest)));

  { CONNECT responses have no payload; any leftover bytes belong to the tunnel. }
  FPending := '';
  LResp := ReadResponse(AConn as IReader, hmHead, LKeepAlive, LResponseStarted);
  if (LResp.StatusCode < 200) or (LResp.StatusCode > 299) then
  begin
    { 407 is not auto-retried with Digest/NTLM. Supported path is preemptive
      Basic from ProxyUrl UserInfo only (Wave I freeze). }
    if LResp.StatusCode = HTTP_STATUS_PROXY_AUTH_REQUIRED then
      raise EHttpError.CreateOp(hekConnect, 'connect',
        'proxy CONNECT failed: HTTP 407 Proxy Authentication Required ' +
        '(supported: ProxyUrl UserInfo → Proxy-Authorization Basic only)')
    else
      raise EHttpError.CreateOp(hekConnect, 'connect',
        'proxy CONNECT failed: HTTP ' + IntToStr(Int64(LResp.StatusCode)));
  end;

  LBody := LResp.Body;
  if LBody <> nil then
  begin
    repeat
      LN := LBody.Read(LTmp[0], SizeUInt(SizeOf(LTmp)));
    until LN = 0;
  end;

  if FPending <> '' then
  begin
    AConn := TReadPrependTcpStream.Create(AConn, FPending);
    FPending := '';
  end;
end;

function TH1ClientTransport.PooledConnectionIsReusable(
  const AConn: ITcpStream): Boolean;
var
  LRuntime: ITcpStreamRuntime;
  LByte: Byte;
  LRead: SizeUInt;
begin
  Result := False;
  if AConn = nil then
    Exit;
  if not Supports(AConn, ITcpStreamRuntime, LRuntime) then
    Exit;

  try
    LRuntime.SetBlocking(False);
    try
      Result := LRuntime.TryRead(LByte, 1, LRead) = tsiorWouldBlock;
    finally
      LRuntime.SetBlocking(True);
    end;
  except
    Result := False;
  end;
end;

function TH1ClientTransport.PoolGet(const AHost: string; const APort: UInt16): ITcpStream;
var
  LI: Int32;
begin
  Result := nil;
  FPoolLock.Acquire;
  try
    for LI := 0 to FPoolCount - 1 do
      if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) then
      begin
        Result := FPool[LI].Conn;
        FPool[LI] := FPool[FPoolCount - 1];
        Dec(FPoolCount);
        if PooledConnectionIsReusable(Result) then
          Exit;
        Result.Close;
        Result := nil;
        Exit;
      end;
  finally
    FPoolLock.Release;
  end;
end;

procedure TH1ClientTransport.PoolPut(const AHost: string; const APort: UInt16;
  const AConn: ITcpStream);
var
  LI: Int32;
  LAuthorityIdle: Int32;
begin
  FPoolLock.Acquire;
  try
    if FOptions.MaxPoolSize > 0 then
    begin
      LAuthorityIdle := 0;
      for LI := 0 to FPoolCount - 1 do
        if (FPool[LI].Host = AHost) and (FPool[LI].Port = APort) then
          Inc(LAuthorityIdle);
      if LAuthorityIdle >= FOptions.MaxPoolSize then
      begin
        AConn.Close;
        Exit;
      end;
    end;
    AConn.SetReadDeadline(TDeadline.Infinite);
    AConn.SetWriteDeadline(TDeadline.Infinite);
    if FPoolCount >= Length(FPool) then
      SetLength(FPool, FPoolCount + 4);
    FPool[FPoolCount].Host := AHost;
    FPool[FPoolCount].Port := APort;
    FPool[FPoolCount].Conn := AConn;
    Inc(FPoolCount);
  finally
    FPoolLock.Release;
  end;
end;

procedure TH1ClientTransport.PoolClear;
var
  LI: Int32;
begin
  FPoolLock.Acquire;
  try
    for LI := 0 to FPoolCount - 1 do
      if FPool[LI].Conn <> nil then
        FPool[LI].Conn.Close;
    FPoolCount := 0;
    SetLength(FPool, 0);
  finally
    FPoolLock.Release;
  end;
end;

function TH1ClientTransport.WriteRequest(const AWriter: IWriter;
  const AReq: IHttpRequest; const AAutoHost: string;
  const AAbsoluteForm: Boolean; const AProxyAuthorization: string): Boolean;
const
  CRLF: AnsiString = #13#10;
var
  LPath: string;
  LUrl: TUrl;
  LBuf: IWriter;
  LChunked: IWriter;
  LChunkedFlusher: IFlusher;
  LFlusher: IFlusher;
  LN: SizeUInt;
  LRemaining: Int64;
  LReadSize: SizeUInt;
  LTmp: array[0..4095] of Byte;
  LStr: string;
  LUseChunked: Boolean;
begin
  Result := True;
  if not (AReq.Version in [hvHttp10, hvHttp11]) then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'h1 transport only supports HTTP/1.x requests');

  LUrl := AReq.Url;
  if AAbsoluteForm then
  begin
    { Proxy absolute-form request-target: scheme://host[:port]/path[?query] }
    LPath := LUrl.ToString;
    if LUrl.Fragment <> '' then
    begin
      { Fragment is never sent on the wire. }
      if Pos('#', LPath) > 0 then
        LPath := System.Copy(LPath, 1, Pos('#', LPath) - 1);
    end;
  end
  else
  begin
    LPath := AReq.Path;
    if LPath = '' then
      LPath := '/';
    if AReq.RawQuery <> '' then
      LPath := LPath + '?' + AReq.RawQuery;
  end;
  ValidateWireRequestTarget(LPath);

  LBuf := CreateBufferedWriter(AWriter, 4096);

  LStr := HttpMethodToStr(AReq.Method);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(PAnsiChar(' ')^, 1);
  LBuf.Write(LPath[1], SizeUInt(Length(LPath)));

  LStr := ' ' + HttpVersionToStr(AReq.Version);
  LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
  LBuf.Write(CRLF[1], 2);

  AReq.Headers.ForEach(procedure(const AName, AValue: string)
  var
    LHeader: string;
  begin
    ValidateWireHeaderName(AName);
    ValidateWireHeaderValue(AValue);
    LHeader := AName + ': ' + AValue;
    LBuf.Write(LHeader[1], SizeUInt(Length(LHeader)));
    LBuf.Write(CRLF[1], 2);
  end);

  LUseChunked := (AReq.Body <> nil) and (AReq.ContentLength < 0);

  if (AReq.ContentLength > 0) and (not AReq.Headers.Has('content-length')) then
  begin
    LStr := 'content-length: ' + IntToStr(AReq.ContentLength);
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  if LUseChunked and (not AReq.Headers.Has('transfer-encoding')) then
  begin
    LStr := 'transfer-encoding: chunked';
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  if (AAutoHost <> '') and (not AReq.Headers.Has('host')) then
  begin
    LStr := 'host: ' + AAutoHost;
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  if not AReq.Headers.Has('user-agent') then
  begin
    LStr := 'user-agent: nextpas-http/1.0';
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  { Absolute-form proxy only: inject Basic from ProxyUrl UserInfo when the
    request did not already set Proxy-Authorization. }
  if AAbsoluteForm and (AProxyAuthorization <> '') and
     (not AReq.Headers.Has('proxy-authorization')) then
  begin
    ValidateWireHeaderValue(AProxyAuthorization);
    LStr := 'proxy-authorization: ' + AProxyAuthorization;
    LBuf.Write(LStr[1], SizeUInt(Length(LStr)));
    LBuf.Write(CRLF[1], 2);
  end;

  LBuf.Write(CRLF[1], 2);

  if (AReq.Body <> nil) and (AReq.ContentLength > 0) then
  begin
    LRemaining := AReq.ContentLength;
    while LRemaining > 0 do
    begin
      LReadSize := SizeUInt(SizeOf(LTmp));
      if LRemaining < Int64(LReadSize) then
        LReadSize := SizeUInt(LRemaining);
      try
        LN := AReq.Body.Read(LTmp[0], LReadSize);
      except
        on E: Exception do
        begin
          if E is ETimeoutError then
            raise EHttpError.CreateOp(hekTimeout, 'transport',
              'HTTP request body read failed: ' + E.Message);
          if E is EHttpError then
            raise;
          raise EHttpError.CreateOp(hekProtocol, 'transport',
            'HTTP request body read failed: ' + E.Message);
        end;
      end;
      if LN > 0 then
      begin
        if Int64(LN) > LRemaining then
          LN := SizeUInt(LRemaining);
        LBuf.Write(LTmp[0], LN);
        Dec(LRemaining, Int64(LN));
      end;
      if LN = 0 then
      begin
        if Supports(LBuf, IFlusher, LFlusher) then
          LFlusher.Flush;
        raise EHttpError.CreateOp(hekBody, 'transport',
          'HTTP request body shorter than declared content-length');
      end;
    end;
  end
  else if LUseChunked then
  begin
    LChunked := TChunkedWriter.Create(LBuf);
    while True do
    begin
      try
        LN := AReq.Body.Read(LTmp[0], SizeUInt(SizeOf(LTmp)));
      except
        on E: Exception do
        begin
          if E is ETimeoutError then
            raise EHttpError.CreateOp(hekTimeout, 'transport',
              'HTTP request body read failed: ' + E.Message);
          if E is EHttpError then
            raise;
          raise EHttpError.CreateOp(hekProtocol, 'transport',
            'HTTP request body read failed: ' + E.Message);
        end;
      end;
      if LN = 0 then
        Break;
      LChunked.Write(LTmp[0], LN);
    end;
    if Supports(LChunked, IFlusher, LChunkedFlusher) then
      LChunkedFlusher.Flush;
  end;

  if Supports(LBuf, IFlusher, LFlusher) then
    LFlusher.Flush;
end;

function TH1ClientTransport.ReadResponse(const AReader: IReader;
  const ARequestMethod: THttpMethod; out AKeepAlive: Boolean;
  out AResponseStarted: Boolean): IHttpResponse;
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LConsumed: SizeUInt;
  LPending: string;
  LHasResponseTail: Boolean;
  LBodyReader: IReader;
  LSkippedInformational: Boolean;
  LCurrentResponseStarted: Boolean;
begin
  AResponseStarted := False;
  LHasResponseTail := False;
  LSkippedInformational := False;
  LCurrentResponseStarted := False;
  LPending := FPending;
  FPending := '';
  LParser := NewH1ResponseParser(ARequestMethod = hmHead);
  repeat
    if LPending <> '' then
    begin
      LN := SizeUInt(Length(LPending));
      LCurrentResponseStarted := True;
      LConsumed := LParser.Execute(PAnsiChar(LPending), LN);
      if LConsumed < LN then
        LPending := System.Copy(LPending, SizeInt(LConsumed) + 1,
          SizeInt(LN - LConsumed))
      else
        LPending := '';
    end
    else
    begin
      LN := AReader.Read(LBuf[0], 4096);
      if LN = 0 then
        Break;
      AResponseStarted := True;
      LCurrentResponseStarted := True;
      LConsumed := LParser.Execute(@LBuf[0], LN);
      if LConsumed < LN then
      begin
        SetLength(LPending, Int32(LN - LConsumed));
        Move(LBuf[Int32(LConsumed)], LPending[1], LN - LConsumed);
      end;
    end;

    if LParser.IsComplete and
      IsSkippableInformationalResponse(LParser.GetStatusCode) then
    begin
      LSkippedInformational := True;
      LCurrentResponseStarted := False;
      LParser := NewH1ResponseParser(ARequestMethod = hmHead);
      Continue;
    end;
  until LParser.IsComplete or LParser.HasError;

  if (not LParser.IsComplete) and (not LParser.HasError) then
    LParser.Finish;

  if LParser.IsComplete and
    IsSkippableInformationalResponse(LParser.GetStatusCode) then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'HTTP response incomplete: missing final response');

  if LSkippedInformational and (not LCurrentResponseStarted) then
    raise EHttpError.CreateOp(hekProtocol, 'transport',
      'HTTP response incomplete: missing final response');

  if LParser.HasError then
    raise EHttpError.CreateOp(hekParse, 'transport',
      'HTTP parse error: ' + LParser.ErrorMessage);
  if not LParser.IsComplete then
    raise EHttpError.CreateOp(hekConnect, 'transport',
      'HTTP response incomplete: connection closed');

  FPending := LPending;
  LHasResponseTail := FPending <> '';
  AKeepAlive := LParser.ShouldKeepAlive and (not LHasResponseTail) and
    (LParser.GetStatusCode <> HTTP_STATUS_SWITCHING_PROTOCOLS);

  LBodyReader := LParser.NewBodyReader;
  if LBodyReader <> nil then
  begin
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders,
      LBodyReader, LParser.GetHttpVersion);
  end
  else
    Result := THttpResponse.Create(LParser.GetStatusCode, LParser.GetHeaders, nil,
      LParser.GetHttpVersion);
end;

function TH1ClientTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LUrl: TUrl;
  LHost: string;
  LPoolHostKey: string;
  LAutoHost: string;
  LPort: UInt16;
  LConnectHost: string;
  LConnectPort: UInt16;
  LProxyUrl: TUrl;
  LProxyAuthorization: string;
  LUseAbsoluteForm: Boolean;
  LUseConnectTunnel: Boolean;
  LSecure: Boolean;
  LConn: ITcpStream;
  LResp: IHttpResponse;
  LPooled: Boolean;
  LKeepAlive: Boolean;
  LRequestClose: Boolean;
  LResponseStarted: Boolean;
  LRequestWriteComplete: Boolean;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
  LRequestDeadline: TDeadline;
  LTimeoutMs: Int64;
  LReqOpts: IHttpRequestWithOptions;
  LWrapped: Exception;

  procedure WrapConnectionWithTls;
  begin
    { Bound TLS handshake I/O with ConnectTimeout when set. }
    if FOptions.ConnectTimeout > 0 then
      ApplyClientDeadline(LConn, ClientRequestDeadline(FOptions.ConnectTimeout))
    else
      ApplyClientDeadline(LConn, LRequestDeadline);
    LConn := NewTlsClientTcpStream(LConn, SecureClientContext, LHost,
      'http/1.1');
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      ApplyClientCancelToken(LConn,
        LReqOpts.RequestOptions.EffectiveCancelToken)
    else
      ApplyClientCancelToken(LConn, nil);
  end;

  procedure PrepareFreshConnection;
  begin
    { ConnectTimeout (or Timeout when ConnectTimeout=0) bounds OS dial. }
    LConn := H1ClientDial(LConnectHost, LConnectPort, FOptions.ConnectTimeout,
      LTimeoutMs);
    { New dial: ConnectTimeout also bounds post-dial first write / CONNECT. }
    if FOptions.ConnectTimeout > 0 then
      ApplyClientDeadline(LConn, ClientRequestDeadline(FOptions.ConnectTimeout))
    else
      ApplyClientDeadline(LConn, LRequestDeadline);
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      ApplyClientCancelToken(LConn, LReqOpts.RequestOptions.EffectiveCancelToken)
    else
      ApplyClientCancelToken(LConn, nil);

    if LUseConnectTunnel then
    begin
      EstablishHttpsConnectTunnel(LConn, LHost, LPort, LProxyAuthorization);
      WrapConnectionWithTls;
    end
    else if LSecure then
      { Direct https: TLS-wrap the origin socket (SNI = origin host). }
      WrapConnectionWithTls;
  end;

begin
  if AReq = nil then
    raise EHttpError.Create(hekArgument, 'h1 client transport requires request');
  if AReq.Headers = nil then
    raise EHttpError.Create(hekArgument, 'h1 client transport requires request headers');

  // Per-request timeout override: check request options first, fall back to transport default
  LTimeoutMs := FOptions.Timeout;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
  begin
    LTimeoutMs := LReqOpts.RequestOptions.EffectiveTimeout(FOptions.Timeout);
    HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
  end;

  LUrl := AReq.Url;
  ValidatePlainHttpClientUrlScheme(LUrl);
  LHost := LUrl.Host;
  LSecure := LowerCase(LUrl.Scheme) = 'https';
  LAutoHost := '';
  if not AReq.Headers.Has('host') then
  begin
    LAutoHost := LUrl.HostPort;
    ValidateWireHeaderValue(LAutoHost);
  end;
  LRequestClose := HeadersHaveConnectionCloseToken(AReq.Headers);
  LPort := LUrl.Port;
  if LPort = 0 then
    LPort := DefaultPortForHttpScheme(LUrl.Scheme);

  LUseAbsoluteForm := False;
  LUseConnectTunnel := False;
  LProxyAuthorization := '';
  LConnectHost := LHost;
  LConnectPort := LPort;
  LPoolHostKey := CanonicalPoolHostKey(LHost);
  if LSecure then
    { Keep plain and TLS idle sockets in separate pools. }
    LPoolHostKey := 'https|' + LPoolHostKey;
  if FOptions.ProxyUrl <> '' then
  begin
    LProxyUrl := TUrl.Parse(FOptions.ProxyUrl);
    if LowerCase(LProxyUrl.Scheme) <> 'http' then
      raise EHttpError.Create(hekArgument,
        'HTTP client proxy must use http:// scheme');
    if LProxyUrl.Host = '' then
      raise EHttpError.Create(hekArgument, 'HTTP client proxy host is empty');
    LProxyAuthorization := ProxyBasicAuthorizationValue(LProxyUrl.UserInfo);
    LConnectHost := LProxyUrl.Host;
    LConnectPort := LProxyUrl.Port;
    if LConnectPort = 0 then
      LConnectPort := 80;
    if LSecure then
    begin
      { https through plain HTTP proxy: CONNECT host:port, then TLS. }
      LUseConnectTunnel := True;
      LUseAbsoluteForm := False;
      LPoolHostKey := 'connect|' + CanonicalPoolHostKey(LConnectHost) + '|' +
        CanonicalPoolHostKey(LHost) + ':' + IntToStr(Int64(LPort));
    end
    else
    begin
      LUseAbsoluteForm := True;
      { Pool by proxy + target so different targets do not share a proxy socket. }
      LPoolHostKey := CanonicalPoolHostKey(LConnectHost) + '|' +
        CanonicalPoolHostKey(LHost) + ':' + IntToStr(Int64(LPort));
    end;
  end;

  CaptureRetryBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LRequestDeadline := ClientRequestDeadline(LTimeoutMs);
  FPending := '';
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
  LConn := PoolGet(LPoolHostKey, LConnectPort);
  LPooled := LConn <> nil;
  if not LPooled then
    PrepareFreshConnection
  else
  begin
    ApplyClientDeadline(LConn, LRequestDeadline);
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      ApplyClientCancelToken(LConn, LReqOpts.RequestOptions.EffectiveCancelToken)
    else
      ApplyClientCancelToken(LConn, nil);
  end;

  LResponseStarted := False;
  LRequestWriteComplete := False;
  try
    WriteRequest(LConn as IWriter, AReq, LAutoHost, LUseAbsoluteForm,
      LProxyAuthorization);
    LRequestWriteComplete := True;
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
      HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
    { Re-arm request deadline for response read (after connect-write budget). }
    ApplyClientDeadline(LConn, LRequestDeadline);
    LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive,
      LResponseStarted);
  except
    on E: Exception do
    begin
      if LPooled then
      begin
        LConn.Close;
        if (not LRequestWriteComplete) or LResponseStarted or
           (not IsRetrySafeRequest(AReq)) or
           ((AReq.Body <> nil) and (AReq.ContentLength <> 0) and
            (LBodyStream = nil)) then
        begin
          LWrapped := HttpWrapTransportException(E);
          if LWrapped <> nil then
            raise LWrapped;
          raise;
        end;
        RewindRetryBody(AReq, LBodyStream, LBodyStartPosition);
        if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
          HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
        try
          PrepareFreshConnection;
          LRequestWriteComplete := False;
          WriteRequest(LConn as IWriter, AReq, LAutoHost, LUseAbsoluteForm,
            LProxyAuthorization);
          LRequestWriteComplete := True;
          if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
            HttpThrowIfCanceled(LReqOpts.RequestOptions.EffectiveCancelToken);
          ApplyClientDeadline(LConn, LRequestDeadline);
          LResp := ReadResponse(LConn as IReader, AReq.Method, LKeepAlive,
            LResponseStarted);
        except
          on E2: Exception do
          begin
            LConn.Close;
            LWrapped := HttpWrapTransportException(E2);
            if LWrapped <> nil then
              raise LWrapped;
            raise;
          end;
        end;
      end
      else
      begin
        LConn.Close;
        LWrapped := HttpWrapTransportException(E);
        if LWrapped <> nil then
          raise LWrapped;
        raise;
      end;
    end;
  end;

  if LKeepAlive and (not LRequestClose) then
    PoolPut(LPoolHostKey, LConnectPort, LConn)
  else
    LConn.Close;

  Result := LResp;
end;

procedure TH1ClientTransport.CloseIdleConnections;
begin
  PoolClear;
end;

{ TH1ServerTransport }

constructor TH1ServerTransport.Create(const AOptions: TH1ServerTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

procedure TH1ServerTransport.ValidateInputs(const AConn: ITcpStream;
  const AHandler: IHttpHandler);
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'h1 server transport requires connection');
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'h1 server transport requires handler');
end;

function TH1ServerTransport.HandleConnection(const AConn: ITcpStream;
  const AHandler: IHttpHandler): Boolean;
var
  LState: TH1ServerConnectionState;
begin
  ValidateInputs(AConn, AHandler);
  LState := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
  try
    Result := LState.Run = tscoServer;
  finally
    LState.Free;
  end;
end;

function TH1ServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  if HandleConnection(AConn, AHandler) then
    Result := tscoServer
  else
    Result := tscoHandler;
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions, AContext);
end;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := TH1ClientTransport.Create(AOptions);
end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH1ServerTransport.Create(AOptions);
end;

end.
