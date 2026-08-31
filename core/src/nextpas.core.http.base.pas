unit nextpas.core.http.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.tls.base;

type
  THttpVersion = (hvHttp10, hvHttp11, hvHttp2, hvHttp3);

  THttpMethod = (
    hmGet, hmHead, hmPost, hmPut, hmDelete,
    hmPatch, hmOptions, hmConnect, hmTrace
  );

  THttpStatus = UInt16;
  TTcpServerBackend = nextpas.core.net.server.base.TTcpServerBackend;

  { Note: NewHttpCancelToken is waitable (INetCancelWaitable) so mid-IO cancel
    wakes blocked socket reads via net poll+socketpair on Unix. }

  { Programmable HTTP error classification (single exception type, Kind field). }
  THttpErrorKind = (
    hekUnknown,
    hekArgument,
    hekTimeout,
    hekConnect,
    hekProtocol,
    hekParse,
    hekRedirect,
    hekBody,
    hekUpgrade,
    hekRegistry,
    hekStatus,
    hekCanceled
  );

  EHttpError = class(ENextPasError)
  private
    FKind: THttpErrorKind;
    FStatus: THttpStatus;
    FOp: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AKind: THttpErrorKind;
      const AMessage: string); overload;
    constructor Create(const AKind: THttpErrorKind; const AMessage: string;
      const AStatus: THttpStatus); overload;
    constructor CreateOp(const AKind: THttpErrorKind; const AOp,
      AMessage: string); overload;
    constructor CreateOp(const AKind: THttpErrorKind; const AOp,
      AMessage: string; const AStatus: THttpStatus); overload;
    property Kind: THttpErrorKind read FKind;
    property Status: THttpStatus read FStatus;
    property Op: string read FOp;
  end;

  TUrl = record
    Scheme: string;
    UserInfo: string;
    Host: string;
    Port: UInt16;
    Path: string;
    RawQuery: string;
    Fragment: string;
    class function Parse(const ARaw: string): TUrl; static;
    class function ParseRequestTarget(const ARaw: string): TUrl; static;
    function ToString: string;
    { scheme://host[:port]；剥 userinfo/path/query/fragment。日志/错误面用。 }
    function Redacted: string;
    function HostPort: string;
    function AddQuery(const AName, AValue: string): TUrl;
    function WithQuery(const ARawQuery: string): TUrl;
    function GetQueryParam(const AName: string): string;
    function HasQueryParam(const AName: string): Boolean;
  end;

  { Cooperative cancel token for in-flight client requests.
     Call Cancel to mark canceled; ThrowIfCanceled raises hekCanceled. }
  IHttpCancelToken = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-4000000000C1}']
    function IsCanceled: Boolean;
    procedure Cancel;
    procedure ThrowIfCanceled;
  end;

  { Streaming response-body sink for client requests (SSE / long-poll).
     Set on THttpRequestOptions.ResponseBodyChunk; H1 transport dispatches each
     parsed body chunk synchronously on its IO thread as it arrives, before the
     request completes. The full body is still buffered (NewBodyReader snapshot
     and PARSER_BODY_MAX_CAPACITY cap apply), the sink is an additional live
     dispatch. Implementations MUST NOT raise: the callback crosses the llhttp
     cdecl boundary. }
  THttpResponseBodyChunkProc = procedure(const AData: PByte;
    ASize: SizeUInt) of object;

  { Response-headers-ready callback for client requests.
     Set on THttpRequestOptions.ResponseStatus; H1 transport invokes it once,
     synchronously on its IO thread, after response headers are parsed (status
     code visible) and before any body chunk is dispatched. Informational
     (1xx) responses are skipped. Unlike THttpResponseBodyChunkProc this
     callback runs in Pascal context (not across the llhttp cdecl boundary),
     so implementations MAY raise; errors propagate through Send normally. }
  THttpResponseStatusProc = procedure(const AStatus: THttpStatus) of object;

  THttpRequestOptions = record
    TimeoutMs: Int64;
    HasTimeout: Boolean;
    MaxRedirects: Int32;
    HasMaxRedirects: Boolean;
    FollowRedirects: Boolean;
    HasFollowRedirects: Boolean;
    CancelToken: IHttpCancelToken;
    HasCancelToken: Boolean;
    { Optional per-request streaming sink; see THttpResponseBodyChunkProc. }
    ResponseBodyChunk: THttpResponseBodyChunkProc;
    { Optional response-headers-ready callback; see THttpResponseStatusProc. }
    ResponseStatus: THttpResponseStatusProc;
    { Skip buffering the response body (H1): parsed body bytes are only
       dispatched to ResponseBodyChunk (if set) and not retained; NewBodyReader
       returns nil and PARSER_BODY_MAX_CAPACITY no longer applies. Intended for
       SSE / long-poll sinks where the full-body snapshot is not needed. }
    SkipBodyBuffer: Boolean;
    function WithTimeout(const ATimeoutMs: Int64): THttpRequestOptions;
    function WithMaxRedirects(const AMaxRedirects: Int32): THttpRequestOptions;
    function WithFollowRedirects(
      const AFollow: Boolean): THttpRequestOptions;
    function WithCancelToken(
      const AToken: IHttpCancelToken): THttpRequestOptions;
    function WithResponseBodyChunk(
      const AChunkProc: THttpResponseBodyChunkProc): THttpRequestOptions;
    function WithResponseStatus(
      const AProc: THttpResponseStatusProc): THttpRequestOptions;
    function WithSkipBodyBuffer: THttpRequestOptions;
    function EffectiveTimeout(const ADefault: Int64): Int64;
    function EffectiveMaxRedirects(const ADefault: Int32): Int32;
    function EffectiveFollowRedirects(const ADefault: Boolean): Boolean;
    function EffectiveCancelToken: IHttpCancelToken;
  end;

  { Custom transport dial for HTTP clients: returns a connected ITcpStream to
    AHost:APort (or raises). Mirrors the H2 test-hook shape but as a public,
    per-client option. Used by nextpas.core.http.impl.h1.client for every fresh
    connection when assigned. Function reference: callers may capture context
    (e.g. proxy endpoint + per-lease credential slot) in a closure. }
  THttpDialFunc = reference to function(const AHost: string; const APort: UInt16;
    const AConnectTimeoutMs, ATimeoutMs: Int64): ITcpStream;

  THttpClientOptions = record
    { Request IO deadline (ms) for read/write after the socket is up. 0 = none.
      With IHttpCancelToken, mid-read/write is polled in short slices and raises
      hekCanceled when canceled (also pair Timeout to bound wait without cancel). }
    Timeout: Int64;
    { OS dial + post-dial first-write budget on newly opened sockets (ms).
      When > 0: bounds OS connect() and first write after dial.
      When 0: OS dial uses Timeout if Timeout > 0, else unbounded; first write
      uses Timeout. }
    ConnectTimeout: Int64;
    MaxRedirects: Int32;
    { Max idle connections retained per pool authority (host/port/scheme key).
      Default 64. Not a global cap across authorities. }
    MaxPoolSize: Int32;
    { Max wall-clock idle time (ms) for a pooled connection before PoolGet
      discards it. Default 90000. 0 = no TTL (only CloseIdleConnections /
      destroy / MaxPoolSize). }
    IdleTTL: Int64;
    FollowRedirects: Boolean;
    Version: THttpVersion;
    UseRegistryVersion: Boolean;
    TLSContext: ISSLContext;
    { Plain HTTP forward proxy (http://[user:pass@]host:port). Empty = direct.
      https targets use CONNECT then TLS over the tunnel; http targets use
      absolute-form request-line. UserInfo injects Proxy-Authorization Basic. }
    ProxyUrl: string;
    { Custom transport dial: when assigned, every fresh connection for this
      client goes through ADial instead of the built-in TcpConnect. The dial
      func MUST raise on failure (callers expect exceptions from the transport
      layer) and MUST NOT return nil. Typical use: tunneling through a
      SOCKS5/SOCKS5h proxy (nextpas.core.net.socks5.Socks5Dial → ITcpStream),
      which the http://-only WithProxyUrl cannot express. Idle connections are
      still pooled by target authority (host/port) — the tunneled socket is a
      plain TCP pipe to the origin once established. Mutually exclusive with
      ProxyUrl: when both are set, ProxyUrl wins. }
    DialFunc: THttpDialFunc;
    class function Default: THttpClientOptions; static;
    function WithTimeout(const ATimeoutMs: Int64): THttpClientOptions;
    function WithConnectTimeout(const ATimeoutMs: Int64): THttpClientOptions;
    function WithMaxRedirects(const AMaxRedirects: Int32): THttpClientOptions;
    function WithFollowRedirects(const AFollow: Boolean): THttpClientOptions;
    function WithMaxPoolSize(const AMaxPoolSize: Int32): THttpClientOptions;
    function WithIdleTTL(const AIdleTTLMs: Int64): THttpClientOptions;
    function WithVersion(const AVersion: THttpVersion): THttpClientOptions;
    function WithProxyUrl(const AProxyUrl: string): THttpClientOptions;
    function WithDialFunc(const ADial: THttpDialFunc): THttpClientOptions;
    function WithTLSContext(const ATLSContext: ISSLContext): THttpClientOptions;
    function EffectiveVersion(
      const ADefaultVersion: THttpVersion): THttpVersion;
    function EffectiveConnectTimeout: Int64;
  end;

  { Read-abort observation sink: invoked when a server connection's request
    read deadline expires mid-request and the session replies with a
    best-effort 408 Request Timeout before closing. Not called for idle
    keep-alive timeouts (no request bytes received). Implementations must be
    thread-safe: callbacks arrive from reactor threads (poll backend) or
    worker/connection threads (threaded backend / poll worker handoff).
    Interface sink, not closure: handlers capture nothing (assembly-time
    injection keeps FPC escape-closure pitfalls out of the IO path). }
  IHttpServerReadAbortSink = interface
    ['{6F1D6F1D-4D7C-4E31-9100-520000000001}']
    procedure OnReadAbort(const ARemoteAddr: string);
  end;

  THttpServerOptions = record
    Backend: TTcpServerBackend;
    ReadTimeout: Int64;
    WriteTimeout: Int64;
    IdleTimeout: Int64;
    MaxHeaderSize: Int32;
    MaxBodySize: Int64;
    { ShutdownTimeout: max milliseconds to wait for in-flight requests during
      graceful shutdown. 0 = wait forever (default for backward compat). }
    ShutdownTimeout: Int64;
    { MaxRequestsPerConnection: max requests on a single keep-alive connection.
      After this many requests, the server sends Connection: close. 0 = unlimited. }
    MaxRequestsPerConnection: Int32;
    Version: THttpVersion;
    UseRegistryVersion: Boolean;
    TLSContext: ISSLContext;
    { RequestArena: when True, enable per-request LocalArena. Default H1/H2
      transport uses connection-scoped arena (Reset per request/stream); custom /
      H3 transport falls back to HttpWithRequestArena middleware. Default False. }
    RequestArena: Boolean;
    { RequestArenaCapacity: 0 = HTTP_DEFAULT_REQUEST_ARENA when RequestArena. }
    RequestArenaCapacity: SizeUInt;
{ PreferPollWorkerHandoff (S1-1): when True, poll-owned (streaming/SSE)
      requests are submitted to the worker pool instead of running inline on
      the readiness reactor. Default False keeps short-request perf (inline
      avoids pool submit + completion wake); set True when handlers block for
      long stretches (e.g. proxying upstream streams) so one slow request
      does not stall the whole reactor. Non-poll (regular) requests always
      run on the worker pool regardless of this flag. }
    PreferPollWorkerHandoff: Boolean;
    { WorkerPoolSize: h1 poll worker handoff（及 readiness conn workers）的
      worker 池规模。0 = auto（= platform_cpu_count，默认，保持既有行为）；
      >0 显式覆盖池规模，用于放开「流式并发上界 = worker 池规模」的伸缩上限
      （token888 已知差距 #2，wiki/testing.md）。0 语义不变。 }
    WorkerPoolSize: Integer;
    { ReadAbortSink: 读截止过期中止观测（可空）。见 IHttpServerReadAbortSink。 }
    ReadAbortSink: IHttpServerReadAbortSink;
    { Default (PD-1B): Read/Write = 30000 ms. Long-poll/SSE/tests that need
      unbounded IO must set WithReadTimeout(0)/WithWriteTimeout(0) explicitly.
      IdleTimeout alone is not a complete production template. }
    class function Default: THttpServerOptions; static;
    { Production: named production template (currently same RW as Default).
      Prefer Production in product code for intent; still chain With*. }
    class function Production: THttpServerOptions; static;
    function WithVersion(const AVersion: THttpVersion): THttpServerOptions;
    function WithReadTimeout(const AMs: Int64): THttpServerOptions;
    function WithWriteTimeout(const AMs: Int64): THttpServerOptions;
    function WithIdleTimeout(const AMs: Int64): THttpServerOptions;
    function WithMaxHeaderSize(const ABytes: Int32): THttpServerOptions;
    function WithMaxBodySize(const ABytes: Int64): THttpServerOptions;
    function WithShutdownTimeout(const AMs: Int64): THttpServerOptions;
    function WithMaxRequestsPerConnection(const AMax: Int32): THttpServerOptions;
    {** Enable per-request LocalArena at the server root (0 capacity = default). }
    function WithRequestArena(ACapacity: SizeUInt = 0): THttpServerOptions;
{** Route poll-owned (streaming/SSE) handlers to the worker pool instead
      of running them inline on the readiness reactor (see field note). }
    function WithPreferPollWorkerHandoff(
      const AValue: Boolean = True): THttpServerOptions;
    {** Override worker pool size (0 = auto = platform_cpu_count, default).
      See WorkerPoolSize field note. }
    function WithWorkerPoolSize(
      const AWorkerCount: Integer = 0): THttpServerOptions;
    {** Observe request read-deadline aborts (408 path). See
      IHttpServerReadAbortSink. }
    function WithReadAbortSink(
      const ASink: IHttpServerReadAbortSink): THttpServerOptions;
    function EffectiveVersion(
      const ADefaultVersion: THttpVersion): THttpVersion;
  end;

const
  { 1xx Informational }
  HTTP_STATUS_CONTINUE              = THttpStatus(100);
  HTTP_STATUS_SWITCHING_PROTOCOLS   = THttpStatus(101);
  HTTP_STATUS_EARLY_HINTS           = THttpStatus(103);

  { 2xx Success }
  HTTP_STATUS_OK                    = THttpStatus(200);
  HTTP_STATUS_CREATED               = THttpStatus(201);
  HTTP_STATUS_ACCEPTED              = THttpStatus(202);
  HTTP_STATUS_NO_CONTENT            = THttpStatus(204);
  HTTP_STATUS_RESET_CONTENT         = THttpStatus(205);
  HTTP_STATUS_PARTIAL_CONTENT       = THttpStatus(206);

  { 3xx Redirection }
  HTTP_STATUS_MOVED_PERMANENTLY     = THttpStatus(301);
  HTTP_STATUS_FOUND                 = THttpStatus(302);
  HTTP_STATUS_SEE_OTHER             = THttpStatus(303);
  HTTP_STATUS_NOT_MODIFIED          = THttpStatus(304);
  HTTP_STATUS_TEMPORARY_REDIRECT    = THttpStatus(307);
  HTTP_STATUS_PERMANENT_REDIRECT    = THttpStatus(308);

  { 4xx Client Error }
  HTTP_STATUS_BAD_REQUEST           = THttpStatus(400);
  HTTP_STATUS_UNAUTHORIZED          = THttpStatus(401);
  HTTP_STATUS_PAYMENT_REQUIRED      = THttpStatus(402);
  HTTP_STATUS_FORBIDDEN             = THttpStatus(403);
  HTTP_STATUS_NOT_FOUND             = THttpStatus(404);
  HTTP_STATUS_METHOD_NOT_ALLOWED    = THttpStatus(405);
  HTTP_STATUS_NOT_ACCEPTABLE        = THttpStatus(406);
  HTTP_STATUS_PROXY_AUTH_REQUIRED   = THttpStatus(407);
  HTTP_STATUS_REQUEST_TIMEOUT       = THttpStatus(408);
  HTTP_STATUS_CONFLICT              = THttpStatus(409);
  HTTP_STATUS_GONE                  = THttpStatus(410);
  HTTP_STATUS_LENGTH_REQUIRED       = THttpStatus(411);
  HTTP_STATUS_PAYLOAD_TOO_LARGE     = THttpStatus(413);
  HTTP_STATUS_URI_TOO_LONG          = THttpStatus(414);
  HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE = THttpStatus(415);
  HTTP_STATUS_RANGE_NOT_SATISFIABLE = THttpStatus(416);
  HTTP_STATUS_EXPECTATION_FAILED    = THttpStatus(417);
  HTTP_STATUS_UNPROCESSABLE_ENTITY  = THttpStatus(422);
  HTTP_STATUS_TOO_MANY_REQUESTS     = THttpStatus(429);
  HTTP_STATUS_HEADER_TOO_LARGE      = THttpStatus(431);

  { 5xx Server Error }
  HTTP_STATUS_INTERNAL_SERVER_ERROR = THttpStatus(500);
  HTTP_STATUS_NOT_IMPLEMENTED       = THttpStatus(501);
  HTTP_STATUS_BAD_GATEWAY           = THttpStatus(502);
  HTTP_STATUS_SERVICE_UNAVAILABLE   = THttpStatus(503);
  HTTP_STATUS_GATEWAY_TIMEOUT       = THttpStatus(504);

  { TCP server backend aliases }
  TCP_SERVER_BACKEND_THREADED = nextpas.core.net.server.base.tsbThreaded;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.net.server.base.tsbEpoll;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.net.server.base.tsbKqueue;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.net.server.base.tsbIocp;

  {** Default max for in-memory request body helpers / BodyCache / Decompress
     (bytes). Aligned with THttpServerOptions.Default.MaxBodySize (4 MiB).
     Explicit 0 on Max overloads means unlimited (tests/tools only). }
  HTTP_DEFAULT_BODY_READ_MAX = Int64(4) * 1024 * 1024;

function HttpMethodToStr(const AMethod: THttpMethod): string;
function HttpStrToMethod(const AStr: string): THttpMethod;
function HttpStatusText(const ACode: THttpStatus): string;
function HttpStatusIsInformational(const ACode: THttpStatus): Boolean;
function HttpStatusIsSuccess(const ACode: THttpStatus): Boolean;
function HttpStatusIsRedirect(const ACode: THttpStatus): Boolean;
function HttpStatusIsClientError(const ACode: THttpStatus): Boolean;
function HttpStatusIsServerError(const ACode: THttpStatus): Boolean;
function HttpVersionToStr(const AVersion: THttpVersion): string;

{** True if E is EHttpError(hekTimeout) or a bare ETimeoutError (pre-boundary). }
function HttpErrorIsTimeout(const E: Exception): Boolean;
{** True for timeout or connect-class failures suitable for client retry. }
function HttpErrorIsRetryable(const E: Exception): Boolean;
{** True for caller-side errors: hekArgument / hekCanceled (not server faults). }
function HttpErrorIsUserError(const E: Exception): Boolean;
{** Map bare transport exceptions to EHttpError with Op=transport:
   ETimeoutError → hekTimeout; ENetworkError → hekConnect.
   Returns nil if caller should bare-re-raise the original exception with `raise`. }
function HttpWrapTransportException(const E: Exception): Exception;
{** Create a fresh cooperative cancel token. }
function NewHttpCancelToken: IHttpCancelToken;
{** Raise hekCanceled when AToken is non-nil and canceled. }
procedure HttpThrowIfCanceled(const AToken: IHttpCancelToken);

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.net.cancel;

{ EHttpError }

function HttpErrorKindToCategory(const AKind: THttpErrorKind): TErrorCategory;
begin
  { 非法强转落网络类默认值，保持定义性；正常路径由 case 全覆盖。 }
  Result := ecNetwork;
  case AKind of
    hekArgument:
      Result := ecInvalidArgument;
    hekTimeout:
      Result := ecTimeout;
    hekCanceled:
      Result := ecCancelled;
    hekParse:
      Result := ecParse;
    hekConnect, hekProtocol, hekRedirect, hekBody, hekUpgrade, hekRegistry,
      hekStatus, hekUnknown:
      Result := ecNetwork;
  end;
end;

constructor EHttpError.Create(const AMessage: string);
begin
  inherited Create(AMessage, ecNetwork);
  FKind := hekUnknown;
  FStatus := 0;
  FOp := '';
end;

constructor EHttpError.Create(const AKind: THttpErrorKind;
  const AMessage: string);
begin
  inherited Create(AMessage, HttpErrorKindToCategory(AKind));
  FKind := AKind;
  FStatus := 0;
  FOp := '';
end;

constructor EHttpError.Create(const AKind: THttpErrorKind;
  const AMessage: string; const AStatus: THttpStatus);
begin
  inherited Create(AMessage, HttpErrorKindToCategory(AKind));
  FKind := AKind;
  FStatus := AStatus;
  FOp := '';
end;

constructor EHttpError.CreateOp(const AKind: THttpErrorKind; const AOp,
  AMessage: string);
begin
  inherited Create(AMessage, HttpErrorKindToCategory(AKind));
  FKind := AKind;
  FStatus := 0;
  FOp := AOp;
end;

constructor EHttpError.CreateOp(const AKind: THttpErrorKind; const AOp,
  AMessage: string; const AStatus: THttpStatus);
begin
  inherited Create(AMessage, HttpErrorKindToCategory(AKind));
  FKind := AKind;
  FStatus := AStatus;
  FOp := AOp;
end;

function HttpErrorIsTimeout(const E: Exception): Boolean;
begin
  if E = nil then
    Exit(False);
  if E is EHttpError then
    Exit(EHttpError(E).Kind = hekTimeout);
  Result := E is ETimeoutError;
end;

function HttpErrorIsRetryable(const E: Exception): Boolean;
begin
  if E = nil then
    Exit(False);
  if HttpErrorIsTimeout(E) then
    Exit(True);
  if E is EHttpError then
    Exit(EHttpError(E).Kind in [hekConnect, hekTimeout]);
  Result := E is ENetworkError;
end;

function HttpErrorIsUserError(const E: Exception): Boolean;
begin
  if E = nil then
    Exit(False);
  if E is EHttpError then
    Exit(EHttpError(E).Kind in [hekArgument, hekCanceled]);
  Result := E is EArgumentError;
end;

function HttpWrapTransportException(const E: Exception): Exception;
begin
  Result := nil;
  if E = nil then
    Exit;
  if E is ETimeoutError then
    Result := EHttpError.CreateOp(hekTimeout, 'transport', E.Message)
  else if E is ECancelledError then
    Result := EHttpError.CreateOp(hekCanceled, 'transport', E.Message)
  else if E is ENetworkError then
    Result := EHttpError.CreateOp(hekConnect, 'transport', E.Message);
end;

type
  { Composes NewNetCancelToken so HTTP cancel is waitable on ITcpStream. }
  THttpCancelToken = class(TInterfacedObject, IHttpCancelToken, INetCancelToken,
    INetCancelWaitable)
  private
    FNet: INetCancelController;
    FWaitable: INetCancelWaitable;
  public
    constructor Create;
    function IsCanceled: Boolean;
    procedure Cancel;
    procedure ThrowIfCanceled;
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

constructor THttpCancelToken.Create;
begin
  inherited Create;
  FNet := NewNetCancelToken;
  FWaitable := nil;
  if (FNet <> nil) and
     (FNet.QueryInterface(INetCancelWaitable, FWaitable) <> 0) then
    FWaitable := nil;
end;

function THttpCancelToken.IsCanceled: Boolean;
begin
  Result := (FNet <> nil) and FNet.IsCanceled;
end;

procedure THttpCancelToken.Cancel;
begin
  if FNet <> nil then
    FNet.Cancel;
end;

procedure THttpCancelToken.ThrowIfCanceled;
begin
  if IsCanceled then
    raise EHttpError.CreateOp(hekCanceled, 'cancel', 'HTTP request canceled');
end;

function THttpCancelToken.WakeHandle: PtrUInt;
begin
  if FWaitable <> nil then
    Result := FWaitable.WakeHandle
  else
    Result := 0;
end;

procedure THttpCancelToken.DrainWake;
begin
  if FWaitable <> nil then
    FWaitable.DrainWake;
end;

function NewHttpCancelToken: IHttpCancelToken;
begin
  Result := THttpCancelToken.Create;
end;

procedure HttpThrowIfCanceled(const AToken: IHttpCancelToken);
begin
  if AToken <> nil then
    AToken.ThrowIfCanceled;
end;

{ Free functions }

function HttpMethodToStr(const AMethod: THttpMethod): string;
begin
  case AMethod of
    hmGet:     Result := 'GET';
    hmHead:    Result := 'HEAD';
    hmPost:    Result := 'POST';
    hmPut:     Result := 'PUT';
    hmDelete:  Result := 'DELETE';
    hmPatch:   Result := 'PATCH';
    hmOptions: Result := 'OPTIONS';
    hmConnect: Result := 'CONNECT';
    hmTrace:   Result := 'TRACE';
  end;
end;

function HttpStrToMethod(const AStr: string): THttpMethod;
var
  LUpper: string;
begin
  LUpper := UpperCase(AStr);
  if LUpper = 'GET' then Result := hmGet
  else if LUpper = 'HEAD' then Result := hmHead
  else if LUpper = 'POST' then Result := hmPost
  else if LUpper = 'PUT' then Result := hmPut
  else if LUpper = 'DELETE' then Result := hmDelete
  else if LUpper = 'PATCH' then Result := hmPatch
  else if LUpper = 'OPTIONS' then Result := hmOptions
  else if LUpper = 'CONNECT' then Result := hmConnect
  else if LUpper = 'TRACE' then Result := hmTrace
  else
    raise EHttpError.Create(hekParse, 'Unknown HTTP method: ' + AStr);
end;

function HttpStatusText(const ACode: THttpStatus): string;
begin
  case ACode of
    { 1xx }
    100: Result := 'Continue';
    101: Result := 'Switching Protocols';
    103: Result := 'Early Hints';
    { 2xx }
    200: Result := 'OK';
    201: Result := 'Created';
    202: Result := 'Accepted';
    204: Result := 'No Content';
    205: Result := 'Reset Content';
    206: Result := 'Partial Content';
    { 3xx }
    301: Result := 'Moved Permanently';
    302: Result := 'Found';
    303: Result := 'See Other';
    304: Result := 'Not Modified';
    307: Result := 'Temporary Redirect';
    308: Result := 'Permanent Redirect';
    { 4xx }
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    406: Result := 'Not Acceptable';
    407: Result := 'Proxy Authentication Required';
    408: Result := 'Request Timeout';
    409: Result := 'Conflict';
    410: Result := 'Gone';
    413: Result := 'Payload Too Large';
    414: Result := 'URI Too Long';
    415: Result := 'Unsupported Media Type';
    416: Result := 'Range Not Satisfiable';
    417: Result := 'Expectation Failed';
    422: Result := 'Unprocessable Entity';
    429: Result := 'Too Many Requests';
    431: Result := 'Request Header Fields Too Large';
    { 5xx }
    500: Result := 'Internal Server Error';
    501: Result := 'Not Implemented';
    502: Result := 'Bad Gateway';
    503: Result := 'Service Unavailable';
    504: Result := 'Gateway Timeout';
  else
    Result := IntToStr(ACode);
  end;
end;

function HttpStatusInRange(const ACode, AMin, AMax: THttpStatus): Boolean;
begin
  Result := (ACode >= AMin) and (ACode <= AMax);
end;

function HttpStatusIsInformational(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 100, 199);
end;

function HttpStatusIsSuccess(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 200, 299);
end;

function HttpStatusIsRedirect(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 300, 399);
end;

function HttpStatusIsClientError(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 400, 499);
end;

function HttpStatusIsServerError(const ACode: THttpStatus): Boolean;
begin
  Result := HttpStatusInRange(ACode, 500, 599);
end;

function HttpVersionToStr(const AVersion: THttpVersion): string;
begin
  case AVersion of
    hvHttp10: Result := 'HTTP/1.0';
    hvHttp11: Result := 'HTTP/1.1';
    hvHttp2:  Result := 'HTTP/2';
    hvHttp3:  Result := 'HTTP/3';
  end;
end;

function ParseUrlPort(const APort: string): UInt16;
var
  LPortVal: Int64;
begin
  if (APort = '') or (not TryStrToInt(APort, LPortVal)) then
    raise EHttpError.Create(hekParse, 'Invalid port: ' + APort);
  if (LPortVal < 0) or (LPortVal > 65535) then
    raise EHttpError.Create(hekParse, 'Port out of range: ' + APort);
  Result := UInt16(LPortVal);
end;

{ TUrl }

class function TUrl.Parse(const ARaw: string): TUrl;
var
  LRest: string;
  LPos: SizeInt;
  LSchemeEnd: SizeInt;
  LAuthority: string;
  LAtPos: SizeInt;
  LColonPos: SizeInt;
  LPortStr: string;
  LI: SizeInt;
begin
  Result := Default(TUrl);
  if ARaw = '' then
    raise EHttpError.Create(hekParse, 'Cannot parse empty URL');

  LRest := ARaw;

  // Check for scheme (contains "://")
  LSchemeEnd := Pos('://', LRest);
  if LSchemeEnd > 0 then
  begin
    Result.Scheme := Copy(LRest, 1, LSchemeEnd - 1);
    Delete(LRest, 1, LSchemeEnd + 2);

    // Extract authority (up to first /, ?, or # -- or end)
    LPos := 0;
    for LI := 1 to Length(LRest) do
      if (LRest[LI] = '/') or (LRest[LI] = '?') or (LRest[LI] = '#') then
      begin
        LPos := LI;
        Break;
      end;
    if LPos > 0 then
    begin
      LAuthority := Copy(LRest, 1, LPos - 1);
      Delete(LRest, 1, LPos - 1);
    end
    else
    begin
      LAuthority := LRest;
      LRest := '';
    end;

    // Check for userinfo (@) — use last @ per RFC 3986
    LAtPos := 0;
    for LI := Length(LAuthority) downto 1 do
      if LAuthority[LI] = '@' then
      begin
        LAtPos := LI;
        Break;
      end;
    if LAtPos > 0 then
    begin
      Result.UserInfo := Copy(LAuthority, 1, LAtPos - 1);
      Delete(LAuthority, 1, LAtPos);
    end;

    // Parse host:port (handle IPv6 brackets)
    if (Length(LAuthority) > 0) and (LAuthority[1] = '[') then
    begin
      LColonPos := Pos(']', LAuthority);
      if LColonPos > 0 then
      begin
        Result.Host := Copy(LAuthority, 2, LColonPos - 2);
        if (LColonPos < Length(LAuthority)) and (LAuthority[LColonPos + 1] = ':') then
        begin
          LPortStr := Copy(LAuthority, LColonPos + 2, Length(LAuthority) - LColonPos - 1);
          Result.Port := ParseUrlPort(LPortStr);
        end;
      end
      else
        Result.Host := LAuthority;
    end
    else
    begin
      LColonPos := Pos(':', LAuthority);
      if LColonPos > 0 then
      begin
        Result.Host := Copy(LAuthority, 1, LColonPos - 1);
        LPortStr := Copy(LAuthority, LColonPos + 1, Length(LAuthority) - LColonPos);
        Result.Port := ParseUrlPort(LPortStr);
      end
      else
      begin
        Result.Host := LAuthority;
        Result.Port := 0;
      end;
    end;
  end;

  // Fragment
  LPos := Pos('#', LRest);
  if LPos > 0 then
  begin
    Result.Fragment := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  // Query
  LPos := Pos('?', LRest);
  if LPos > 0 then
  begin
    Result.RawQuery := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  Result.Path := LRest;
end;

class function TUrl.ParseRequestTarget(const ARaw: string): TUrl;
var
  LRest: string;
  LPos: SizeInt;
begin
  if ARaw = '' then
    raise EHttpError.Create(hekParse, 'Cannot parse empty request-target');

  if (ARaw[1] <> '/') and (ARaw[1] <> '*') and (Pos('://', ARaw) > 0) then
    Exit(TUrl.Parse(ARaw));

  Result := Default(TUrl);
  LRest := ARaw;

  LPos := Pos('#', LRest);
  if LPos > 0 then
  begin
    Result.Fragment := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  LPos := Pos('?', LRest);
  if LPos > 0 then
  begin
    Result.RawQuery := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  Result.Path := LRest;
end;

function TUrl.ToString: string;
var
  LResult: string;
begin
  LResult := '';
  if Scheme <> '' then
  begin
    LResult := Scheme + '://';
    if UserInfo <> '' then
      LResult := LResult + UserInfo + '@';
    if Pos(':', Host) > 0 then
      LResult := LResult + '[' + Host + ']'
    else
      LResult := LResult + Host;
    if Port <> 0 then
      LResult := LResult + ':' + IntToStr(Int64(Port));
  end;
  LResult := LResult + Path;
  if RawQuery <> '' then
    LResult := LResult + '?' + RawQuery;
  if Fragment <> '' then
    LResult := LResult + '#' + Fragment;
  Result := LResult;
end;

function TUrl.Redacted: string;
begin
  if Scheme <> '' then
    Result := Scheme + '://' + HostPort
  else
    Result := HostPort;
end;

function TUrl.HostPort: string;
var
  LHost: string;
begin
  if Pos(':', Host) > 0 then
    LHost := '[' + Host + ']'
  else
    LHost := Host;

  if Port <> 0 then
    Result := LHost + ':' + IntToStr(Int64(Port))
  else
    Result := LHost;
end;

function PercentEncodeQueryValue(const AStr: string): string;
const
  CHexDigits: array[0..15] of Char = '0123456789ABCDEF';
var
  LI, LJ, LLen: SizeInt;
  LByte: Byte;
begin
  LLen := Length(AStr);
  if LLen = 0 then Exit('');
  SetLength(Result, LLen * 3);
  LJ := 1;
  for LI := 1 to LLen do
  begin
    case AStr[LI] of
      'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~':
      begin
        Result[LJ] := AStr[LI];
        Inc(LJ);
      end;
      ' ':
      begin
        Result[LJ] := '+';
        Inc(LJ);
      end;
    else
      begin
        LByte := Byte(Ord(AStr[LI]));
        Result[LJ]     := '%';
        Result[LJ + 1] := CHexDigits[LByte shr 4];
        Result[LJ + 2] := CHexDigits[LByte and $0F];
        Inc(LJ, 3);
      end;
    end;
  end;
  SetLength(Result, LJ - 1);
end;

function TUrl.AddQuery(const AName, AValue: string): TUrl;
var
  LEncoded: string;
begin
  Result := Self;
  LEncoded := PercentEncodeQueryValue(AName) + '=' + PercentEncodeQueryValue(AValue);
  if Result.RawQuery = '' then
    Result.RawQuery := LEncoded
  else
    Result.RawQuery := Result.RawQuery + '&' + LEncoded;
end;

function TUrl.WithQuery(const ARawQuery: string): TUrl;
begin
  Result := Self;
  Result.RawQuery := ARawQuery;
end;

function TUrl.GetQueryParam(const AName: string): string;
var
  LQuery: string;
  LStart, LEnd, LEqPos, LLen: SizeInt;
  LPair: string;
begin
  Result := '';
  LQuery := RawQuery;
  LLen := Length(LQuery);
  if LLen = 0 then Exit;
  LStart := 1;
  while LStart <= LLen do
  begin
    LEnd := LStart;
    while (LEnd <= LLen) and (LQuery[LEnd] <> '&') do
      Inc(LEnd);
    LPair := Copy(LQuery, LStart, LEnd - LStart);
    LEqPos := Pos('=', LPair);
    if LEqPos > 0 then
    begin
      if Copy(LPair, 1, LEqPos - 1) = AName then
      begin
        Result := Copy(LPair, LEqPos + 1, MaxInt);
        Exit;
      end;
    end
    else if LPair = AName then
    begin
      Result := '';
      Exit;
    end;
    LStart := LEnd + 1;
  end;
end;

function TUrl.HasQueryParam(const AName: string): Boolean;
var
  LQuery: string;
  LStart, LEnd, LEqPos, LLen: SizeInt;
  LPair: string;
begin
  Result := False;
  LQuery := RawQuery;
  LLen := Length(LQuery);
  if LLen = 0 then Exit;
  LStart := 1;
  while LStart <= LLen do
  begin
    LEnd := LStart;
    while (LEnd <= LLen) and (LQuery[LEnd] <> '&') do
      Inc(LEnd);
    LPair := Copy(LQuery, LStart, LEnd - LStart);
    LEqPos := Pos('=', LPair);
    if LEqPos > 0 then
    begin
      if Copy(LPair, 1, LEqPos - 1) = AName then
        Exit(True);
    end
    else if LPair = AName then
      Exit(True);
    LStart := LEnd + 1;
  end;
end;

{ THttpRequestOptions }

function THttpRequestOptions.WithTimeout(
  const ATimeoutMs: Int64): THttpRequestOptions;
begin
  Result := Self;
  Result.TimeoutMs := ATimeoutMs;
  Result.HasTimeout := True;
end;

function THttpRequestOptions.WithMaxRedirects(
  const AMaxRedirects: Int32): THttpRequestOptions;
begin
  Result := Self;
  Result.MaxRedirects := AMaxRedirects;
  Result.HasMaxRedirects := True;
end;

function THttpRequestOptions.WithFollowRedirects(
  const AFollow: Boolean): THttpRequestOptions;
begin
  Result := Self;
  Result.FollowRedirects := AFollow;
  Result.HasFollowRedirects := True;
end;

function THttpRequestOptions.WithCancelToken(
  const AToken: IHttpCancelToken): THttpRequestOptions;
begin
  Result := Self;
  Result.CancelToken := AToken;
  Result.HasCancelToken := True;
end;

function THttpRequestOptions.WithResponseBodyChunk(
  const AChunkProc: THttpResponseBodyChunkProc): THttpRequestOptions;
begin
  Result := Self;
  Result.ResponseBodyChunk := AChunkProc;
end;

function THttpRequestOptions.WithResponseStatus(
  const AProc: THttpResponseStatusProc): THttpRequestOptions;
begin
  Result := Self;
  Result.ResponseStatus := AProc;
end;

function THttpRequestOptions.WithSkipBodyBuffer: THttpRequestOptions;
begin
  Result := Self;
  Result.SkipBodyBuffer := True;
end;

function THttpRequestOptions.EffectiveTimeout(const ADefault: Int64): Int64;
begin
  if HasTimeout then
    Result := TimeoutMs
  else
    Result := ADefault;
end;

function THttpRequestOptions.EffectiveMaxRedirects(
  const ADefault: Int32): Int32;
begin
  if HasMaxRedirects then
    Result := MaxRedirects
  else
    Result := ADefault;
end;

function THttpRequestOptions.EffectiveFollowRedirects(
  const ADefault: Boolean): Boolean;
begin
  if HasFollowRedirects then
    Result := FollowRedirects
  else
    Result := ADefault;
end;

function THttpRequestOptions.EffectiveCancelToken: IHttpCancelToken;
begin
  if HasCancelToken then
    Result := CancelToken
  else
    Result := nil;
end;

{ THttpClientOptions }

class function THttpClientOptions.Default: THttpClientOptions;
begin
  Result.Timeout := 30000;
  Result.ConnectTimeout := 0;
  Result.MaxRedirects := 10;
  Result.MaxPoolSize := 64;
  Result.IdleTTL := 90000;
  Result.FollowRedirects := True;
  Result.Version := hvHttp11;
  Result.UseRegistryVersion := True;
  Result.TLSContext := nil;
  Result.ProxyUrl := '';
  Result.DialFunc := nil;
end;

function THttpClientOptions.WithTimeout(const ATimeoutMs: Int64): THttpClientOptions;
begin
  Result := Self;
  Result.Timeout := ATimeoutMs;
end;

function THttpClientOptions.WithConnectTimeout(
  const ATimeoutMs: Int64): THttpClientOptions;
begin
  Result := Self;
  Result.ConnectTimeout := ATimeoutMs;
end;

function THttpClientOptions.EffectiveConnectTimeout: Int64;
begin
  if ConnectTimeout > 0 then
    Result := ConnectTimeout
  else
    Result := Timeout;
end;

function THttpClientOptions.WithMaxRedirects(const AMaxRedirects: Int32): THttpClientOptions;
begin
  Result := Self;
  Result.MaxRedirects := AMaxRedirects;
end;

function THttpClientOptions.WithFollowRedirects(const AFollow: Boolean): THttpClientOptions;
begin
  Result := Self;
  Result.FollowRedirects := AFollow;
end;

function THttpClientOptions.WithMaxPoolSize(const AMaxPoolSize: Int32): THttpClientOptions;
begin
  Result := Self;
  Result.MaxPoolSize := AMaxPoolSize;
end;

function THttpClientOptions.WithIdleTTL(const AIdleTTLMs: Int64): THttpClientOptions;
begin
  Result := Self;
  Result.IdleTTL := AIdleTTLMs;
end;

function THttpClientOptions.WithVersion(
  const AVersion: THttpVersion): THttpClientOptions;
begin
  Result := Self;
  Result.Version := AVersion;
  Result.UseRegistryVersion := False;
end;

function THttpClientOptions.WithProxyUrl(
  const AProxyUrl: string): THttpClientOptions;
begin
  Result := Self;
  Result.ProxyUrl := AProxyUrl;
end;

function THttpClientOptions.WithDialFunc(
  const ADial: THttpDialFunc): THttpClientOptions;
begin
  Result := Self;
  Result.DialFunc := ADial;
end;

function THttpClientOptions.WithTLSContext(
  const ATLSContext: ISSLContext): THttpClientOptions;
begin
  Result := Self;
  Result.TLSContext := ATLSContext;
end;

function THttpClientOptions.EffectiveVersion(
  const ADefaultVersion: THttpVersion): THttpVersion;
begin
  if UseRegistryVersion then
    Result := ADefaultVersion
  else
    Result := Version;
end;

{ THttpServerOptions }

class function THttpServerOptions.Default: THttpServerOptions;
begin
  { PD-1B: finite Read/Write by default (30s). Unbounded needs explicit 0. }
  Result.Backend := tsbThreaded;
  Result.ReadTimeout := 30000;
  Result.WriteTimeout := 30000;
  Result.IdleTimeout := 30000;
  Result.MaxHeaderSize := 8192;
  Result.MaxBodySize := 4194304;
  Result.ShutdownTimeout := 0;
  Result.MaxRequestsPerConnection := 0;
  Result.Version := hvHttp11;
  Result.UseRegistryVersion := True;
  Result.TLSContext := nil;
  Result.RequestArena := False;
  Result.RequestArenaCapacity := 0;
  Result.PreferPollWorkerHandoff := False;
  Result.WorkerPoolSize := 0;
end;

class function THttpServerOptions.Production: THttpServerOptions;
begin
  { Named production template; RW currently matches Default after PD-1B. }
  Result := Default;
  Result.ReadTimeout := 30000;
  Result.WriteTimeout := 30000;
end;

function THttpServerOptions.WithVersion(
  const AVersion: THttpVersion): THttpServerOptions;
begin
  Result := Self;
  Result.Version := AVersion;
  Result.UseRegistryVersion := False;
end;

function THttpServerOptions.WithReadTimeout(const AMs: Int64): THttpServerOptions;
begin
  Result := Self;
  Result.ReadTimeout := AMs;
end;

function THttpServerOptions.WithWriteTimeout(const AMs: Int64): THttpServerOptions;
begin
  Result := Self;
  Result.WriteTimeout := AMs;
end;

function THttpServerOptions.WithIdleTimeout(const AMs: Int64): THttpServerOptions;
begin
  Result := Self;
  Result.IdleTimeout := AMs;
end;

function THttpServerOptions.WithMaxHeaderSize(const ABytes: Int32): THttpServerOptions;
begin
  Result := Self;
  Result.MaxHeaderSize := ABytes;
end;

function THttpServerOptions.WithMaxBodySize(const ABytes: Int64): THttpServerOptions;
begin
  Result := Self;
  Result.MaxBodySize := ABytes;
end;

function THttpServerOptions.WithShutdownTimeout(const AMs: Int64): THttpServerOptions;
begin
  Result := Self;
  Result.ShutdownTimeout := AMs;
end;

function THttpServerOptions.WithMaxRequestsPerConnection(const AMax: Int32): THttpServerOptions;
begin
  Result := Self;
  Result.MaxRequestsPerConnection := AMax;
end;

function THttpServerOptions.WithRequestArena(ACapacity: SizeUInt): THttpServerOptions;
begin
  Result := Self;
  Result.RequestArena := True;
  Result.RequestArenaCapacity := ACapacity;
end;

function THttpServerOptions.WithPreferPollWorkerHandoff(
  const AValue: Boolean): THttpServerOptions;
begin
  Result := Self;
  Result.PreferPollWorkerHandoff := AValue;
end;

function THttpServerOptions.WithWorkerPoolSize(
  const AWorkerCount: Integer): THttpServerOptions;
begin
  Result := Self;
  Result.WorkerPoolSize := AWorkerCount;
end;

function THttpServerOptions.WithReadAbortSink(
  const ASink: IHttpServerReadAbortSink): THttpServerOptions;
begin
  Result := Self;
  Result.ReadAbortSink := ASink;
end;

function THttpServerOptions.EffectiveVersion(
  const ADefaultVersion: THttpVersion): THttpVersion;
begin
  if UseRegistryVersion then
    Result := ADefaultVersion
  else
    Result := Version;
end;

end.
