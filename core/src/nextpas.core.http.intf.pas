unit nextpas.core.http.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.tls.base,
  nextpas.core.http.base,
  nextpas.core.http.form.base,
  nextpas.core.json.value,
  nextpas.core.json,
  nextpas.core.mem.arena.intf;

type
  TStringArray = nextpas.core.base.TStringArray;
  TFormFieldArray = nextpas.core.http.form.base.TFormFieldArray;
  THttpFileArray = nextpas.core.http.form.base.THttpFileArray;
  TJsonValue = nextpas.core.json.value.TJsonValue;
  IJsonDocument = nextpas.core.json.IJsonDocument;
  TTcpServerConnOwnership = nextpas.core.net.server.base.TTcpServerConnOwnership;
  ITcpServerSession = nextpas.core.net.server.intf.ITcpServerSession;
  ITcpServerSessionContext = nextpas.core.net.server.intf.ITcpServerSessionContext;
  THttpRequestOptions = nextpas.core.http.base.THttpRequestOptions;

  { Header callback for iteration }
  THeaderIterator = reference to procedure(const AName, AValue: string);

  {** Per-request context for middleware-to-handler data propagation.
     Attached to the request via IHttpRequestWithContext (not a process-global map).
     SetValue is non-owning (caller frees). SetOwnedValue is owned by context
     (freed on overwrite/Remove/Destroy). Has reports key existence (nil values ok).
     Typical keys: 'auth_user', 'request_id', 'trace_id', 'session'. }
  IHttpContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000011}']
    procedure SetValue(const AKey: string; const AValue: TObject);
    procedure SetOwnedValue(const AKey: string; const AValue: TObject);
    function GetValue(const AKey: string): TObject;
    function Has(const AKey: string): Boolean;
    procedure Remove(const AKey: string);
  end;

  IHttpHeaders = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000001}']
    procedure SetHeader(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Remove(const AName: string);
    procedure Clear;
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

  IHttpRequest = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000010002}']
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetTrailers: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function GetRemoteIp: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
    property Method: THttpMethod read GetMethod;
    property Url: TUrl read GetUrl;
    property Path: string read GetPath;
    property RawQuery: string read GetRawQuery;
    property Version: THttpVersion read GetVersion;
    property Headers: IHttpHeaders read GetHeaders;
    property Trailers: IHttpHeaders read GetTrailers;
    property Body: IReader read GetBody;
    property ContentLength: Int64 read GetContentLength;
    property RemoteAddr: string read GetRemoteAddr;
    { Peer address without the port: '1.2.3.4' or raw IPv6 like '::1'.
      RemoteAddr renders 'ip:port' ('[ip]:port' for IPv6); RemoteIp is the
      bare address (what rate limiting / login throttling keys need). }
    property RemoteIp: string read GetRemoteIp;
  end;

  { Per-request options that override client defaults when present on a request }
  IHttpRequestWithOptions = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000010010}']
    function GetRequestOptions: THttpRequestOptions;
    procedure SetRequestOptions(const AOptions: THttpRequestOptions);
    property RequestOptions: THttpRequestOptions read GetRequestOptions;
  end;

  { Optional request-scoped context bag (set by ContextMiddleware). }
  IHttpRequestWithContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000010012}']
    function GetContext: IHttpContext;
    procedure SetContext(const ACtx: IHttpContext);
    property Context: IHttpContext read GetContext;
  end;

  {** Optional request-scoped Arena (RequestArenaMiddleware / H1-H2 attach).
     Attached on the request object — not a process-global map. }
  IHttpRequestWithArena = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000010013}']
    function GetArena: IArena;
    procedure SetArena(const AArena: IArena);
    property Arena: IArena read GetArena;
  end;

  IHttpResponse = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000003}']
    function GetStatusCode: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    { URL of the request that produced this response (after redirects when
      FollowRedirects is on). Empty for synthetic/factory responses that never
      went through the client. Does not expose transport handles. }
    function GetFinalUrl: string;
    { Protocol version of the final hop that produced this response.
      H1 from the status-line; H2 is always hvHttp2. Default hvHttp11 for
      synthetic NewResponse helpers. }
    function GetVersion: THttpVersion;
    { Release/drain body ownership. Idempotent. Preferred over relying only on
      helpers; destructor also closes if not already closed. }
    procedure Close;
    property StatusCode: THttpStatus read GetStatusCode;
    property Headers: IHttpHeaders read GetHeaders;
    property Body: IReader read GetBody;
    property FinalUrl: string read GetFinalUrl;
    property Version: THttpVersion read GetVersion;
  end;

  IHttpResponseWriter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000004}']
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Headers: IHttpHeaders read GetHeaders;
  end;

  { Query actual response body bytes written.
    Implemented by response writers that track byte counts.
    Metrics middleware uses this to report accurate ResponseBytes. }
  IHttpResponseBodyBytes = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000D}']
    function GetBodyBytesWritten: Int64;
  end;

  { Hijack the underlying connection from the HTTP server.
    After Hijack, the server loop will not touch the connection. }
  IHttpHijacker = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000C}']
    function Hijack: ITcpStream;
  end;

  { Server 侧对端存活探测（长前置工作期间客户端断连识别）。
    由持有客户端连接的 response writer 实现，委托传输层
    ITcpPeerProbe（net 面）；不支持时恒 True（保守）。可选能力：
    handler 经 Supports/QueryInterface 探测。 }
  IHttpPeerProbe = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000001E}']
    function PeerAlive: Boolean;
  end;

  { 连接级 HTTP 升级上下文：由 H1 响应 writer 实现，非阻塞 WS 升级
    （nextpas.core.http.websocket.UpgradeWebSocketHandoff）经它取得
    承载本连接 poll 注册的 session 上下文，把连接迁移到事件驱动 WS 会话。 }
  IHttpConnContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000001D}']
    function HostSessionContext: ITcpServerSessionContext;
  end;

  { Optional commit probe for response writers.
    RecoveryMiddleware uses this to avoid rewriting a 500 after headers
    are already on the wire (or otherwise committed by the transport). }
  IHttpResponseWriterCommitState = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000E}']
    function HeadersCommitted: Boolean;
  end;

  { Forward declarations for handler types }
  IHttpHandler = interface;

  { Handler — three callback forms }
  THttpHandlerFunc = reference to procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  THttpHandlerMethod = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) of object;
  THttpHandlerProc = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);

  IHttpHandler = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000005}']
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  IHttpMiddleware = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000006}']
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  IHttpRouter = interface(IHttpHandler)
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000007}']
    procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Get(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Head(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Post(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Put(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Delete(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Patch(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Options(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Connect(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Trace(const APattern: string; const AHandler: THttpHandlerFunc);
    { Regex routes — secondary table, consulted when radix tree misses }
    procedure HandleRegex(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure GetRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure PostRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure PutRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure DeleteRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure PatchRegex(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Use(const AMiddleware: IHttpMiddleware);
  end;

  IHttpServer = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000008}']
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

  { Minimal RFC 6265 client cookie store. }
  IHttpCookieJar = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-4000000000C2}']
    procedure StoreFromResponse(const AUrl: TUrl; const AHeaders: IHttpHeaders);
    function CookieHeaderFor(const AUrl: TUrl): string;
    procedure Clear;
  end;

  IHttpClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000009}']
    function Send(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
    function Get(const AUrl: string): IHttpResponse;
    {** GET + ensure 2xx + body as string. Raises EHttpError on non-2xx. }
    function GetString(const AUrl: string): string;
    {** GET + ensure 2xx + body as TBytes. Raises EHttpError on non-2xx. }
    function GetBytes(const AUrl: string): TBytes;
    {** GET + ensure 2xx + parse body as JSON document. Raises on non-2xx or
       invalid JSON (hekProtocol, Op=json). }
    function GetJson(const AUrl: string): IJsonDocument;
    {** POST + ensure 2xx + body as string. Raises EHttpError on non-2xx. }
    function PostString(const AUrl, AContentType, ABody: string): string;
    {** PUT + ensure 2xx + body as string. Raises EHttpError on non-2xx. }
    function PutString(const AUrl, AContentType, ABody: string): string;
    {** PATCH + ensure 2xx + body as string. Raises EHttpError on non-2xx. }
    function PatchString(const AUrl, AContentType, ABody: string): string;
    {** DELETE + ensure 2xx + body as string. Raises EHttpError on non-2xx. }
    function DeleteString(const AUrl: string): string;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Delete(const AUrl: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Head(const AUrl: string): IHttpResponse;
    function Options(const AUrl: string): IHttpResponse;
    function PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse;
    {** multipart/form-data POST (fields + optional files). Boundary is generated. }
    function PostMultipart(const AUrl: string; const AFields: TFormFieldArray;
      const AFiles: THttpFileArray): IHttpResponse;
    function PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    {** Send a streaming request whose body is NOT buffered into memory.
       The body reader is passed directly to the transport. Send takes ownership
       of the body and closes it after the round trip (success or error).
       AContentLength >= 0 publishes Content-Length; AContentLength < 0 selects
       H1 Transfer-Encoding: chunked (H2 rejects unknown-length bodies). }
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    {** Rebuild transport with ConnectTimeout (OS dial + post-dial first-write budget). }
    function WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    {** @desc Returns a decorator that retries failed requests up to AMaxRetries
       extra attempts. Retries on 429, 5xx responses, and HttpErrorIsRetryable
       exceptions (timeout/connect). Delay prefers Retry-After: delta-seconds
       or IMF-fix HTTP-date (both capped at 60s); otherwise exponential backoff
       (100ms base, max 5s). Does NOT retry other 4xx client errors. }
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
    {** Optional cookie jar decorator. Injects Cookie before Send and absorbs
       Set-Cookie after a successful response. }
    function WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
    {** Rebuild transport with plain HTTP forward proxy (http://host:port).
       Decorators re-stack around the new base client. }
    function WithProxyUrl(const AProxyUrl: string): IHttpClient;
    {** Rebuild transport with a custom dial function used instead of the
       built-in TCP connect. The callback must return an established,
       framed stream to AHost:APort or raise EHttpError. DialFunc wins over
       the built-in dial only; WithProxyUrl (if set) still takes precedence
       over both. Connections are pooled per target authority. }
    function WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
    {** Rebuild transport with client TLS context (direct https / CONNECT).
       Nil clears to transport default (SecureClient). }
    function WithTLSContext(const ATLSContext: ISSLContext): IHttpClient;
  end;

  { Transport layer — protocol implementations register these }
  IHttpTransport = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000A}']
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  { Ordered response batch for same-connection multiplex (H2 Wave I3). }
  THttpResponseArray = array of IHttpResponse;
  THttpRequestArray = array of IHttpRequest;

  { Optional transport capability: N requests on one H2 connection (concurrent
    streams). Default IHttpTransport.RoundTrip remains serial one-stream.
    Non-H2 transports do not implement this interface. }
  IHttpTransportMultiplex = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000020}']
    { All requests must share the same authority (scheme/host/port).
      Returns responses in request order. Empty input → empty array. }
    function RoundTripMany(const AReqs: array of IHttpRequest): THttpResponseArray;
  end;

  IHttpTransportIdleConnections = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000F}']
    procedure CloseIdleConnections;
  end;

  IHttpServerTransport = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000B}']
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
  end;

  IHttpServerSessionFactory = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000D}']
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
  end;

  IHttpServerSessionFactoryWithContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000E}']
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  end;

  IH2StreamControl = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000010}']
    procedure Reset(const AErrorCode: UInt32);
    function GetStreamID: UInt32;
    property StreamID: UInt32 read GetStreamID;
  end;

const
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.net.server.base.tscoServer;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.net.server.base.tscoHandler;

implementation

end.
