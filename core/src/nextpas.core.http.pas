unit nextpas.core.http;
{**
 * @desc HTTP umbrella — pure re-export, cohesive exempt `design-conventions.md:170`
 *       (~1914 >800 soft but pure aggregate: 13 aliases + 40+ `inline` thin forwards, no loops/routing/SIMD/`Move`/`FillChar` body).
 *       `bytes.ops:25/89` single source in owners, zero-copy views; resources via owners (`try/finally`/`Close`/`PoolClear`, `heaptrc 0` per domain).
 *       Cognition via five subfacades: `minimal`(~201)/`messages`(~351)/`transports`(~332)/`extensions`(~370)/`middlewares`(~500)
 *       — thin `uses nextpas.core.http.<sub>` preferred, umbrella is frozen aggregate.
 *       `uses` = base/intf + five facades + minimal L0 seams (io/thread/vfs/json/log + router.group)分流认知; CONTRACT truth, missing → back-feed owner.
 *       Guard: new helpers → subfacade, never back to umbrella (守五子不回聚).
 *       Sections: A Types/Consts B Minimal C Messages D Middlewares E Transports F Extensions G Mem/Arena — see impl markers.
 *       I-Cache/Perf: umbrella `inline` = single `Result:=SubFacade.Func` jump, no body copy; loops/SIMD/路由体 out-of-line in owners, `bytes.ops` 单源零拷贝直通; 认知奢华已分流至五子facade按需 `uses`.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.thread.intf,
  nextpas.core.vfs.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router.group,
  nextpas.core.json,
  nextpas.core.log.intf,
  nextpas.core.log,
  nextpas.core.http.minimal,
  nextpas.core.http.messages,
  nextpas.core.http.transports,
  nextpas.core.http.extensions,
  nextpas.core.http.middlewares;

type
  { Re-export base types }
  THttpVersion = nextpas.core.http.base.THttpVersion;
  THttpMethod = nextpas.core.http.base.THttpMethod;
  THttpStatus = nextpas.core.http.base.THttpStatus;
  TTcpServerBackend = nextpas.core.http.base.TTcpServerBackend;
  TUrl = nextpas.core.http.base.TUrl;
  THttpErrorKind = nextpas.core.http.base.THttpErrorKind;
  EHttpError = nextpas.core.http.base.EHttpError;
  IHttpCancelToken = nextpas.core.http.base.IHttpCancelToken;
  THttpRequestOptions = nextpas.core.http.base.THttpRequestOptions;

  { Re-export interfaces }
  IHttpHeaders = nextpas.core.http.intf.IHttpHeaders;
  IHttpRequest = nextpas.core.http.intf.IHttpRequest;
  IHttpRequestWithOptions = nextpas.core.http.intf.IHttpRequestWithOptions;
  IHttpRequestWithContext = nextpas.core.http.intf.IHttpRequestWithContext;
  IHttpRequestWithArena = nextpas.core.http.intf.IHttpRequestWithArena;
  IHttpResponse = nextpas.core.http.intf.IHttpResponse;
  IHttpResponseWriter = nextpas.core.http.intf.IHttpResponseWriter;
  IHttpHandler = nextpas.core.http.intf.IHttpHandler;
  IHttpMiddleware = nextpas.core.http.intf.IHttpMiddleware;
  IHttpRouter = nextpas.core.http.intf.IHttpRouter;
  IHttpServer = nextpas.core.http.intf.IHttpServer;
  IHttpClient = nextpas.core.http.intf.IHttpClient;
  IHttpTransport = nextpas.core.http.intf.IHttpTransport;
  IHttpTransportMultiplex = nextpas.core.http.intf.IHttpTransportMultiplex;
  IHttpTransportIdleConnections = nextpas.core.http.intf.IHttpTransportIdleConnections;
  THttpResponseArray = nextpas.core.http.intf.THttpResponseArray;
  THttpRequestArray = nextpas.core.http.intf.THttpRequestArray;
  IHttpServerTransport = nextpas.core.http.intf.IHttpServerTransport;
  ITcpServerSession = nextpas.core.http.intf.ITcpServerSession;
  ITcpServerSessionContext = nextpas.core.http.intf.ITcpServerSessionContext;
  IHttpServerSessionFactory = nextpas.core.http.intf.IHttpServerSessionFactory;
  IHttpServerSessionFactoryWithContext = nextpas.core.http.intf.IHttpServerSessionFactoryWithContext;
  IH2StreamControl = nextpas.core.http.intf.IH2StreamControl;
  IHttpHijacker = nextpas.core.http.intf.IHttpHijacker;
  IHttpResponseBodyBytes = nextpas.core.http.intf.IHttpResponseBodyBytes;
  IHttpContext = nextpas.core.http.intf.IHttpContext;
  IWebSocket = nextpas.core.http.extensions.IWebSocket;
  TTcpServerConnOwnership = nextpas.core.http.intf.TTcpServerConnOwnership;
  { Request-scoped mem types (see http.mem / RequestArenaMiddleware) }
  IArena = nextpas.core.http.middlewares.IArena;
  IAllocator = nextpas.core.http.middlewares.IAllocator;
  TGrowingAllocator = nextpas.core.http.middlewares.TGrowingAllocator;

  { Re-export callback types }
  THttpHandlerFunc = nextpas.core.http.intf.THttpHandlerFunc;
  THttpHandlerMethod = nextpas.core.http.intf.THttpHandlerMethod;
  THttpHandlerProc = nextpas.core.http.intf.THttpHandlerProc;
  TStringArray = nextpas.core.http.intf.TStringArray;
  THeaderIterator = nextpas.core.http.intf.THeaderIterator;
  TMiddlewareWrapFunc = nextpas.core.http.middlewares.TMiddlewareWrapFunc;
  TRequestPredicate = nextpas.core.http.middlewares.TRequestPredicate;
  TRecoveryCallback = nextpas.core.http.middlewares.TRecoveryCallback;
  TRateLimitOptions = nextpas.core.http.middlewares.TRateLimitOptions;
  TAuthOptions = nextpas.core.http.middlewares.TAuthOptions;
  TAuthValidatorFunc = nextpas.core.http.middlewares.TAuthValidatorFunc;
  TAuthCredentialKind = nextpas.core.http.middlewares.TAuthCredentialKind;
  TRequestIdGenerator = nextpas.core.http.middlewares.TRequestIdGenerator;
  TCorsOptions = nextpas.core.http.middlewares.TCorsOptions;
  THttpMetrics = nextpas.core.http.middlewares.THttpMetrics;
  IHttpMetricsCollector = nextpas.core.http.middlewares.IHttpMetricsCollector;
  THttpMetricsCallback = nextpas.core.http.middlewares.THttpMetricsCallback;
  THttpMetricsFieldsCallback = nextpas.core.http.middlewares.THttpMetricsFieldsCallback;
  TWebSocketOptions = nextpas.core.http.extensions.TWebSocketOptions;
  TWebSocketOriginCheck = nextpas.core.http.extensions.TWebSocketOriginCheck;
  TWebSocketOpcode = nextpas.core.http.extensions.TWebSocketOpcode;
  TWebSocketFrame = nextpas.core.http.extensions.TWebSocketFrame;
  IWebSocketRoom = nextpas.core.http.extensions.IWebSocketRoom;
  TWebSocketRoomManager = nextpas.core.http.extensions.TWebSocketRoomManager;

  { Re-export HSTS types }
  THstsOptions = nextpas.core.http.middlewares.THstsOptions;

  { Re-export SSE types }
  TSSEvent = nextpas.core.http.extensions.TSSEvent;
  ISSEEventWriter = nextpas.core.http.extensions.ISSEEventWriter;

  { Re-export cookie types }
  TSameSite = nextpas.core.http.extensions.TSameSite;
  TRequestCookies = nextpas.core.http.extensions.TRequestCookies;
  TSetCookie = nextpas.core.http.extensions.TSetCookie;
  IHttpCookieJar = nextpas.core.http.intf.IHttpCookieJar;

  { Re-export server/client types }
  THttpServer = nextpas.core.http.transports.THttpServer;
  THttpServerOptions = nextpas.core.http.base.THttpServerOptions;
  THttpClient = nextpas.core.http.transports.THttpClient;
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;
  THttpDialFunc = nextpas.core.http.base.THttpDialFunc;
  THttpRequestBuilder = nextpas.core.http.messages.THttpRequestBuilder;
  THttpRouterGroup = nextpas.core.http.router.group.THttpRouterGroup;

  { Re-export JSON types }
  IJsonDocument = nextpas.core.json.IJsonDocument;

  { Re-export log types (L0 seam) }
  ILogger = nextpas.core.log.intf.ILogger;
  TLogger = nextpas.core.log.TLogger;
  TLogLevel = nextpas.core.log.intf.TLogLevel;

  { Re-export URL types }
  TQueryParam = nextpas.core.http.extensions.TQueryParam;
  TQueryParams = nextpas.core.http.extensions.TQueryParams;

  { Re-export form types }
  TFormField = nextpas.core.http.extensions.TFormField;
  TFormFieldArray = nextpas.core.http.extensions.TFormFieldArray;
  THttpFile = nextpas.core.http.extensions.THttpFile;
  THttpFileArray = nextpas.core.http.extensions.THttpFileArray;
  TMultipartFormData = nextpas.core.http.extensions.TMultipartFormData;
  TMultipartParseOptions = nextpas.core.http.extensions.TMultipartParseOptions;

{ Status constants - re-export }
const
  { 1xx Informational }
  HTTP_STATUS_CONTINUE = nextpas.core.http.base.HTTP_STATUS_CONTINUE;
  HTTP_STATUS_SWITCHING_PROTOCOLS = nextpas.core.http.base.HTTP_STATUS_SWITCHING_PROTOCOLS;
  HTTP_STATUS_EARLY_HINTS = nextpas.core.http.base.HTTP_STATUS_EARLY_HINTS;

  { 2xx Success }
  HTTP_STATUS_OK = nextpas.core.http.base.HTTP_STATUS_OK;
  HTTP_STATUS_CREATED = nextpas.core.http.base.HTTP_STATUS_CREATED;
  HTTP_STATUS_ACCEPTED = nextpas.core.http.base.HTTP_STATUS_ACCEPTED;
  HTTP_STATUS_NO_CONTENT = nextpas.core.http.base.HTTP_STATUS_NO_CONTENT;
  HTTP_STATUS_RESET_CONTENT = nextpas.core.http.base.HTTP_STATUS_RESET_CONTENT;
  HTTP_STATUS_PARTIAL_CONTENT = nextpas.core.http.base.HTTP_STATUS_PARTIAL_CONTENT;

  { 3xx Redirection }
  HTTP_STATUS_MOVED_PERMANENTLY = nextpas.core.http.base.HTTP_STATUS_MOVED_PERMANENTLY;
  HTTP_STATUS_FOUND = nextpas.core.http.base.HTTP_STATUS_FOUND;
  HTTP_STATUS_SEE_OTHER = nextpas.core.http.base.HTTP_STATUS_SEE_OTHER;
  HTTP_STATUS_NOT_MODIFIED = nextpas.core.http.base.HTTP_STATUS_NOT_MODIFIED;
  HTTP_STATUS_TEMPORARY_REDIRECT = nextpas.core.http.base.HTTP_STATUS_TEMPORARY_REDIRECT;
  HTTP_STATUS_PERMANENT_REDIRECT = nextpas.core.http.base.HTTP_STATUS_PERMANENT_REDIRECT;

  { 4xx Client Error }
  HTTP_STATUS_BAD_REQUEST = nextpas.core.http.base.HTTP_STATUS_BAD_REQUEST;
  HTTP_STATUS_UNAUTHORIZED = nextpas.core.http.base.HTTP_STATUS_UNAUTHORIZED;
  HTTP_STATUS_PAYMENT_REQUIRED = nextpas.core.http.base.HTTP_STATUS_PAYMENT_REQUIRED;
  HTTP_STATUS_FORBIDDEN = nextpas.core.http.base.HTTP_STATUS_FORBIDDEN;
  HTTP_STATUS_NOT_FOUND = nextpas.core.http.base.HTTP_STATUS_NOT_FOUND;
  HTTP_STATUS_METHOD_NOT_ALLOWED = nextpas.core.http.base.HTTP_STATUS_METHOD_NOT_ALLOWED;
  HTTP_STATUS_NOT_ACCEPTABLE = nextpas.core.http.base.HTTP_STATUS_NOT_ACCEPTABLE;
  HTTP_STATUS_REQUEST_TIMEOUT = nextpas.core.http.base.HTTP_STATUS_REQUEST_TIMEOUT;
  HTTP_STATUS_CONFLICT = nextpas.core.http.base.HTTP_STATUS_CONFLICT;
  HTTP_STATUS_GONE = nextpas.core.http.base.HTTP_STATUS_GONE;
  HTTP_STATUS_PAYLOAD_TOO_LARGE = nextpas.core.http.base.HTTP_STATUS_PAYLOAD_TOO_LARGE;
  HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE = nextpas.core.http.base.HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE;
  HTTP_STATUS_LENGTH_REQUIRED = nextpas.core.http.base.HTTP_STATUS_LENGTH_REQUIRED;
  HTTP_STATUS_URI_TOO_LONG = nextpas.core.http.base.HTTP_STATUS_URI_TOO_LONG;
  HTTP_STATUS_EXPECTATION_FAILED = nextpas.core.http.base.HTTP_STATUS_EXPECTATION_FAILED;
  HTTP_STATUS_UNPROCESSABLE_ENTITY = nextpas.core.http.base.HTTP_STATUS_UNPROCESSABLE_ENTITY;
  HTTP_STATUS_RANGE_NOT_SATISFIABLE = nextpas.core.http.base.HTTP_STATUS_RANGE_NOT_SATISFIABLE;
  HTTP_STATUS_TOO_MANY_REQUESTS = nextpas.core.http.base.HTTP_STATUS_TOO_MANY_REQUESTS;
  HTTP_STATUS_HEADER_TOO_LARGE = nextpas.core.http.base.HTTP_STATUS_HEADER_TOO_LARGE;

  { 5xx Server Error }
  HTTP_STATUS_INTERNAL_SERVER_ERROR = nextpas.core.http.base.HTTP_STATUS_INTERNAL_SERVER_ERROR;
  HTTP_STATUS_NOT_IMPLEMENTED = nextpas.core.http.base.HTTP_STATUS_NOT_IMPLEMENTED;
  HTTP_STATUS_BAD_GATEWAY = nextpas.core.http.base.HTTP_STATUS_BAD_GATEWAY;
  HTTP_STATUS_SERVICE_UNAVAILABLE = nextpas.core.http.base.HTTP_STATUS_SERVICE_UNAVAILABLE;
  HTTP_STATUS_GATEWAY_TIMEOUT = nextpas.core.http.base.HTTP_STATUS_GATEWAY_TIMEOUT;

  { WebSocket opcodes }
  wsOpContinuation = nextpas.core.http.extensions.wsOpContinuation;
  wsOpText = nextpas.core.http.extensions.wsOpText;
  wsOpBinary = nextpas.core.http.extensions.wsOpBinary;
  wsOpClose = nextpas.core.http.extensions.wsOpClose;
  wsOpPing = nextpas.core.http.extensions.wsOpPing;
  wsOpPong = nextpas.core.http.extensions.wsOpPong;
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = nextpas.core.http.extensions.WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = nextpas.core.http.extensions.WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;
  WEBSOCKET_ROOM_DEFAULT_MAX = nextpas.core.http.extensions.WEBSOCKET_ROOM_DEFAULT_MAX;

  { TCP server backends }
  TCP_SERVER_BACKEND_THREADED = nextpas.core.http.base.TCP_SERVER_BACKEND_THREADED;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.http.base.TCP_SERVER_BACKEND_EPOLL;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.http.base.TCP_SERVER_BACKEND_KQUEUE;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.http.base.TCP_SERVER_BACKEND_IOCP;
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_SERVER;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_HANDLER;

{ === Section B: Minimal — backend & method/status/version/cancel (→ minimal/base) === }
{** @desc 返回本平台默认 TCP 后端 (epoll/kqueue/IOCP else threaded). *}
function DefaultTcpServerBackend: TTcpServerBackend;

{** @desc 返回 TCP 后端的可读名称（threaded/epoll/kqueue/iocp），
    用于启动 banner 与日志展示。 *}
function TcpServerBackendName(const ABackend: TTcpServerBackend): string;

{ Thin forwards — one owner call; bodies/loops/SIMD stay in owners }
{** @desc Convert HTTP method enum to/from string }
function HttpMethodToStr(const AMethod: THttpMethod): string; inline;
function HttpStrToMethod(const AStr: string): THttpMethod; inline;
{** @desc Get reason phrase for status code; returns IntToStr for unknown codes }
function HttpStatusText(const ACode: THttpStatus): string; inline;
{** @desc Status code classification predicates (1xx/2xx/3xx/4xx/5xx) }
function HttpStatusIsInformational(const ACode: THttpStatus): Boolean; inline;
function HttpStatusIsSuccess(const ACode: THttpStatus): Boolean; inline;
function HttpStatusIsRedirect(const ACode: THttpStatus): Boolean; inline;
function HttpStatusIsClientError(const ACode: THttpStatus): Boolean; inline;
function HttpStatusIsServerError(const ACode: THttpStatus): Boolean; inline;
{** @desc Convert HTTP version enum to string (e.g. hvHttp11 → "HTTP/1.1") }
function HttpVersionToStr(const AVersion: THttpVersion): string; inline;
{** @desc True if E is EHttpError(hekTimeout) or bare ETimeoutError. }
function HttpErrorIsTimeout(const E: Exception): Boolean; inline;
{** @desc True for timeout/connect failures suitable for client retry. }
function HttpErrorIsRetryable(const E: Exception): Boolean; inline;
{** @desc True for caller-side errors (hekArgument / hekCanceled). }
function HttpErrorIsUserError(const E: Exception): Boolean; inline;
{** @desc Create a cooperative cancel token for client requests. }
function NewHttpCancelToken: IHttpCancelToken; inline;
{** @desc Raise hekCanceled when token is non-nil and canceled. }
procedure HttpThrowIfCanceled(const AToken: IHttpCancelToken); inline;
{** @desc True for GET/HEAD/OPTIONS/TRACE. }
function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
{** @desc True if request has Idempotency-Key or X-Idempotency-Key. }
function HttpHasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
{** @desc True when WithRetry / pool reconnect may re-issue the request. }
function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;

{ === Section F: Extensions — headers/url/ETag/static/ws/sse/stream/cookie/form (→ extensions) === }
{** @desc Create empty mutable headers container }
function NewHeaders: IHttpHeaders; inline;
{** @desc Set Basic/Digest Authorization header (base64-encoded user:pass) }
procedure SetBasicAuth(const AHeaders: IHttpHeaders;
  const AUsername, APassword: string); inline;
{** @desc Set Bearer Authorization header }
procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string); inline;
{** @desc Parse server-side Authorization header (Bearer scheme, see http.headers) }
function TryParseBearerToken(const AAuthHeader: string;
  out AToken: string): Boolean; inline;

{** @desc Percent-encode/decode URL components (RFC 3986) }
function UrlEncode(const AStr: string): string; inline;
function UrlDecode(const AStr: string): string; inline;
{** @desc Decode query string (+ → space, %XX → byte) }
function UrlDecodeQuery(const AStr: string): string; inline;
{** @desc Decode URL path (%XX → byte, preserve /) }
function UrlDecodePath(const AStr: string): string; inline;
{** @desc Parse "key=value&key2=value2" into TQueryParams array }
function ParseQueryString(const AQuery: string): TQueryParams; inline;
{** @desc Encode TQueryParams back to query string }
function EncodeQueryString(const AParams: TQueryParams): string; inline;
{** @desc Lookup query parameter value by name (empty string if missing) }
function QueryParamValue(const AParams: TQueryParams; const AName: string): string; inline;
{** @desc Check if query parameter exists }
function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean; inline;
{** @desc Clamp integer query param to 1..AMax (missing/invalid/<=0 → ADefault) }
function QueryLimitClamped(const AReq: IHttpRequest; const AName: string;
  ADefault, AMax: Integer): Integer; inline;
{** @desc Clamp integer query param to >=0 (missing/invalid/negative → ADefault) }
function QueryOffsetClamped(const AReq: IHttpRequest; const AName: string;
  ADefault: Integer = 0): Integer; inline;

{ === Section B: Minimal — router (→ minimal) === }
{** @desc Create a new HTTP router (path-pattern → handler mapping) }
function NewRouter: IHttpRouter; inline;

{ === Section D: Middlewares — chain & product middlewares (→ middlewares) === }
{** @desc Wrap a function/method/proc as IHttpHandler }
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler; overload; inline;
function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler; overload; inline;
function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler; overload; inline;
{** @desc Wrap a middleware function (next handler → wrapped handler) }
function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware; inline;
{** @desc CORS middleware with origin allowlist, credentials, preflight handling }
function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware; inline;
{** @desc Catch exceptions and return 500 }
function RecoveryMiddleware: IHttpMiddleware; inline;
{** @desc Catch exceptions and return 500, calling AOnError for each exception. }
function RecoveryMiddlewareWith(const AOnError: TRecoveryCallback): IHttpMiddleware; inline;
{** @desc Add X-Response-Time header (duration in ms) }
function ResponseTimeMiddleware: IHttpMiddleware; inline;
{** @desc Reject requests with Content-Length > AMaxBytes (returns 413). }
function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware; inline;
{** @desc Reject POST/PUT/PATCH requests with unaccepted Content-Type (returns 415). }
function ContentTypeMiddleware(
  const AAccepted: array of string): IHttpMiddleware; inline;
{** @desc Request logging middleware using structured logger (method, path, status, duration). }
function LoggerMiddleware: IHttpMiddleware; inline;
{** @desc Request logging middleware with custom TLogger instance. }
function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware; inline;
{** @desc Logger middleware with extras provider (post-handler extras). *}
function LoggerMiddlewareWithExtras(
  const AExtras: TLogExtrasProvider): IHttpMiddleware; inline;
{** @desc Logger middleware with extras provider + custom TLogger. }
function LoggerMiddlewareWithExtrasAndLogger(
  const AExtras: TLogExtrasProvider; const ALogger: TLogger): IHttpMiddleware; inline;
{** @desc Ensure X-Request-Id header on every response (preserves existing, generates UUID if missing). }
function RequestIdMiddleware: IHttpMiddleware; inline;
{** @desc Request ID middleware with custom header name. }
function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware; inline;
{** @desc Request ID middleware with custom header name and ID generator callback. }
function RequestIdMiddlewareWithGenerator(const AHeaderName: string;
  const AGenerator: TRequestIdGenerator): IHttpMiddleware; inline;
{** @desc Set Cache-Control header on every response. }
function CacheControlMiddleware(const AValue: string): IHttpMiddleware; inline;
{** @desc Cache-Control: no-cache, no-store, must-revalidate. }
function NoCacheMiddleware: IHttpMiddleware; inline;
{** @desc Cache-Control: public, max-age=N. }
function MaxAgeMiddleware(const ASeconds: Int64): IHttpMiddleware; inline;
{** @desc Rate limit middleware (100 req/60s per IP). }
function RateLimitMiddleware: IHttpMiddleware; inline;
{** @desc Rate limit middleware with custom options. }
function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware; inline;
{** @desc Auth middleware with explicit options (Bearer/X-API-Key, constant-time). *}
function AuthMiddleware(const AOptions: TAuthOptions): IHttpMiddleware; inline;
{** @desc Auth middleware driven by an injected validator (default options:
   realm 'restricted'). }
function AuthMiddlewareWithValidator(const AValidator: TAuthValidatorFunc): IHttpMiddleware; inline;
{** @desc Chain handler through middleware stack (first middleware = outermost wrapper) }
function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
{** @desc Conditional middleware — apply AMiddleware only when APredicate returns True. }
function WhenMiddleware(
  const APredicate: TRequestPredicate;
  const AMiddleware: IHttpMiddleware): IHttpMiddleware;
{** @desc Async middleware — dispatches handler execution to a thread pool. }
function AsyncMiddleware(const APool: IThreadPool): IHttpMiddleware; inline;
{** @desc Health check middleware at /healthz — responds 200 OK with JSON ok-status body. }
function HealthCheckMiddleware: IHttpMiddleware; inline;
{** @desc Health check middleware at custom path — responds 200 OK with JSON ok-status body. }
function HealthCheckMiddlewareAt(const APath: string): IHttpMiddleware; inline;
{** @desc Create a new thread-safe metrics collector. }
function NewHttpMetricsCollector: IHttpMetricsCollector; inline;
{** @desc Metrics middleware — records request counts and durations. }
function MetricsMiddleware(const ACollector: IHttpMetricsCollector): IHttpMiddleware; inline;
{** @desc Metrics middleware with custom callback. }
function MetricsMiddlewareWith(const ACallback: THttpMetricsCallback): IHttpMiddleware; inline;
{** @desc Method guard middleware — rejects disallowed methods with 405. }
function MethodGuardMiddleware(const AAllowed: array of THttpMethod): IHttpMiddleware; inline;
{** @desc Body cache middleware — caches request body for re-reading
   (default max HTTP_DEFAULT_BODY_READ_MAX). }
function BodyCacheMiddleware: IHttpMiddleware; inline;
{** @desc Body cache with explicit max; <=0 unlimited (tests/tools only). }
function BodyCacheMiddlewareWith(const AMaxBytes: Int64): IHttpMiddleware; inline;
{** @desc Body cache unlimited (tests/tools only; name is the escape hatch). }
function BodyCacheMiddlewareUnlimited: IHttpMiddleware; inline;
{** @desc Metrics middleware with structured fields (method, path, status, duration). }
function MetricsMiddlewareWithFields(
  const ACallback: THttpMetricsFieldsCallback): IHttpMiddleware; inline;
{** @desc Add "Server: nextpas" header to every response. }
function ServerHeaderMiddleware: IHttpMiddleware; inline;
{** @desc Add "Server: <ACustomName>" header to every response. }
function ServerHeaderMiddlewareWith(const ACustomName: string): IHttpMiddleware; inline;
{** @desc Context middleware — wraps requests with IHttpContext for data propagation. }
function ContextMiddleware: IHttpMiddleware; inline;
{** @desc Create a fresh request context bag (IHttpContext).
   Attach with IHttpRequestWithContext.SetContext; owning middleware detaches
   it after the handler returns. }
function NewHttpContext: IHttpContext; inline;
{** @desc Get the IHttpContext attached to a request. Returns nil if no context. }
function HttpContextOf(const AReq: IHttpRequest): IHttpContext; inline;
{** @desc Typed context helpers (owned string/Int64 boxes). }
function HttpContextGetString(const ACtx: IHttpContext;
  const AKey: string): string; inline;
procedure HttpContextSetString(const ACtx: IHttpContext;
  const AKey, AValue: string); inline;
function HttpContextGetInt64(const ACtx: IHttpContext;
  const AKey: string): Int64; inline;
procedure HttpContextSetInt64(const ACtx: IHttpContext;
  const AKey: string; const AValue: Int64); inline;
{** @desc Request Arena middleware — LocalArena per request; drop after handler. }
function RequestArenaMiddleware: IHttpMiddleware; inline;
{** @desc Request Arena middleware with custom capacity (0 = HTTP_DEFAULT_REQUEST_ARENA). }
function RequestArenaMiddlewareWith(ACapacity: SizeUInt): IHttpMiddleware; inline;
{** @desc Arena attached by RequestArenaMiddleware. Returns nil if inactive. }
function HttpRequestArenaOf(const AReq: IHttpRequest): IArena; inline;
{** @desc IAllocator over request LocalArena (FreeMem no-op). Nil if inactive. }
function HttpRequestAllocatorOf(const AReq: IHttpRequest): IAllocator; inline;
{** @desc Mount RequestArenaMiddleware on a router (0 capacity = default 256 KiB). }
procedure HttpUseRequestArena(const ARouter: IHttpRouter; ACapacity: SizeUInt = 0); inline;
{** @desc Wrap any IHttpHandler with RequestArenaMiddleware (server-level; 0 = default). }
function HttpWithRequestArena(const AHandler: IHttpHandler;
  ACapacity: SizeUInt = 0): IHttpHandler; inline;
{** @desc Response compression middleware (gzip/deflate). Compresses responses >= 1024 bytes. }
function CompressionMiddleware: IHttpMiddleware; inline;
{** @desc Response compression middleware with custom minimum body size. }
function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware; inline;
{** @desc Request body decompression middleware (gzip/deflate).
   Default max decompressed size = HTTP_DEFAULT_BODY_READ_MAX; 0 = unlimited. }
function DecompressMiddleware(
  const AMaxSize: Int64 = HTTP_DEFAULT_BODY_READ_MAX): IHttpMiddleware; inline;
{** @desc Decompress unlimited (tests/tools only). }
function DecompressMiddlewareUnlimited: IHttpMiddleware; inline;
{** @desc Write 415 Unsupported Media Type JSON error response. }
function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 504 Gateway Timeout JSON error response. }
function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Post-hoc deadline middleware (non-preemptive; Timeout→504, oversize→413). *}
function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware; inline;
{** @desc Post-hoc deadline with explicit response buffer max (0 = unlimited, tests only). }
function DeadlineMiddlewareWith(ATimeoutMs: Int64;
  const AMaxBufferBytes: Int64): IHttpMiddleware; inline;
{** @desc Post-hoc deadline with unlimited buffer (tests/tools only; non-preemptive). }
function DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs: Int64): IHttpMiddleware; inline;
{** @desc HSTS middleware — adds Strict-Transport-Security header (1 year, includeSubDomains). }
function HstsMiddleware: IHttpMiddleware; inline;
{** @desc HSTS middleware with custom options (max-age, includeSubDomains, preload). }
function HstsMiddlewareWith(const AOptions: THstsOptions): IHttpMiddleware; inline;

{ --- Request-scoped memory (nextpas.core.mem product wire; see http.mem) --- }

{ === Section G: Mem/Arena — request-scoped arena (→ middlewares/mem) === }
const
  HTTP_DEFAULT_REQUEST_ARENA = nextpas.core.http.middlewares.HTTP_DEFAULT_REQUEST_ARENA;
  HTTP_DEFAULT_BODY_READ_MAX = nextpas.core.http.base.HTTP_DEFAULT_BODY_READ_MAX;
  { Context key for AuthMiddleware's authenticated subject. }
  AUTH_SUBJECT_KEY = nextpas.core.http.middlewares.AUTH_SUBJECT_KEY;

{** @desc Per-request IArena for handler scratch; drop at request end (no FreeMem). }
function HttpCreateRequestArena(ACapacity: SizeUInt = 0): IArena; inline;
{** @desc Per-request IAllocator (Arena FreeMem no-op) for inject-style handlers. }
function HttpCreateRequestAllocator(ACapacity: SizeUInt = 0): IAllocator; inline;
{** @desc Process DefaultHeap for long-lived server state. }
function HttpProcessHeap: TGrowingAllocator; inline;
{** @desc Process DefaultAllocator plug-in surface. }
function HttpProcessAllocator: IAllocator; inline;
{** @desc Process DefaultHeap one-line snapshot for ops/debug (not hot path). }
function HttpFormatProcessMemStats: string; inline;

{ === Section C: Messages — request/response builders & writers/redirects/errors (→ messages) === }
{** @desc Create IHttpRequest (whitelist: Method+TUrl or Method+string URL).
   Headers/body/auth → THttpRequestBuilder. }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload; inline;
function NewGetRequest(const APath: string): IHttpRequest; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse; overload; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ANilBody: Pointer): IHttpResponse; overload; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyText: string): IHttpResponse; overload; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyBytes: TBytes): IHttpResponse; overload; inline;
function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt; inline;
{** @desc Write JSON response: sets application/json content-type, serializes value, writes body. }
function HttpWriteResponseJson(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt; inline;
{** @desc Write binary response: sets content-type and content-length, writes TBytes body. }
function HttpWriteResponseBytes(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType: string;
  const ABody: TBytes): SizeUInt; inline;
{** @desc Write HTML response: sets text/html content-type, writes string body. }
function HttpWriteResponseHtml(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ABody: string): SizeUInt; inline;
{** @desc Write 204 No Content response. }
procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter); inline;
{** @desc Write 200 OK response with no body. }
procedure HttpWriteResponseOk(const AW: IHttpResponseWriter); inline;
{** @desc Write 201 Created response with no body. }
procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter); inline;
{** @desc Write 202 Accepted response with no body. }
procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter); inline;
{** @desc Write 304 Not Modified response with no body. }
procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter); inline;
{** @desc Write 205 Reset Content response with no body. }
procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter); inline;
{** @desc Write 410 Gone response with no body. }
procedure HttpWriteResponseGone(const AW: IHttpResponseWriter); inline;
{** @desc Read request body as TBytes (default max HTTP_DEFAULT_BODY_READ_MAX). }
function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes; inline;
{** @desc Read request body as TBytes with explicit max (<=0 unlimited, tests only). }
function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest;
  const AMaxBytes: Int64): TBytes; inline;
{** @desc Read request body unlimited (tests/tools only). }
function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes; inline;
{** @desc Read request body as string (default max HTTP_DEFAULT_BODY_READ_MAX). }
function HttpReadRequestBodyString(const AReq: IHttpRequest): string; inline;
{** @desc Read request body and parse as JSON (default max HTTP_DEFAULT_BODY_READ_MAX). }
function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument; inline;
{** @desc Write a redirect response with Location header and HTML body. }
procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string); inline;
{** @desc 301 Moved Permanently redirect. }
procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 302 Found redirect (temporary, method may change to GET). }
procedure HttpRedirectFound(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 303 See Other redirect (always changes method to GET). }
procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 307 Temporary Redirect (preserves method and body). }
procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 308 Permanent Redirect (preserves method and body). }
procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc Write an RFC 7807 Problem Details error response. }
function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string;
  const AInstance: string = ''): SizeUInt; inline;
{** @desc Write 400 Bad Request JSON error response. }
function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 401 Unauthorized JSON error response. }
function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 403 Forbidden JSON error response. }
function HttpWriteErrorForbidden(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 404 Not Found JSON error response. }
function HttpWriteErrorNotFound(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 500 Internal Server Error JSON error response. }
function HttpWriteErrorInternal(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 429 Too Many Requests JSON error response. }
function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 409 Conflict JSON error response. }
function HttpWriteErrorConflict(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 422 Unprocessable Entity JSON error response. }
function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 413 Payload Too Large JSON error response. }
function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;

{ === Section F: Extensions — static/ETag/304 (→ extensions) === }
function ServeFile(const APath: string): THttpHandlerFunc; inline;
function ServeDir(const ARoot: string): THttpHandlerFunc; inline;
{** @desc Static serving from read-only IVfs (ETag via ContentHash, 404 dirs). *}
function ServeVfs(const AFs: IVfs): THttpHandlerFunc; inline;
function ServeFileDownload(const APath: string): THttpHandlerFunc; overload; inline;
function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc; overload; inline;
{** @desc Strong ETag from size+mtime. }
function HttpMakeStrongETag(const ASize, AModTime: Int64): string; inline;
{** @desc If-None-Match match helper (`*`, exact, comma list). }
function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean; inline;
{** @desc If-Modified-Since not-modified check. }
function HttpNotModifiedSince(const AIfModifiedSince: string;
  const AModTimeUnix: Int64): Boolean; inline;
{** @desc Conditional GET: write 304 when not modified; True if 304 written. }
function HttpTryWriteNotModified(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AETag, ALastModified: string;
  const AModTimeUnix: Int64): Boolean; inline;

{ === Section F: Extensions — websocket/sse/stream/cookie/form (→ extensions) === }
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket; overload; inline;
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket; overload; inline;

{ WebSocket client }
function ConnectWebSocket(const AUrl: string): IWebSocket; overload; inline;
function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload; inline;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket; overload; inline;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload; inline;

{ SSE (Server-Sent Events) }
function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter; inline;
function MakeSSEvent(const AType, AData, AId: string): TSSEvent; inline;

{ Streaming responses }
function HttpWriteStream(const AW: IHttpResponseWriter;
  const AReader: IReader; const ABufSize: SizeUInt = 32768): Int64; inline;
function HttpWriteStreamWithLength(const AW: IHttpResponseWriter;
  const AContentLength: Int64; const AReader: IReader;
  const ABufSize: SizeUInt = 32768): Int64; inline;

{ Streaming request body }
type
  TChunkCallback = nextpas.core.http.extensions.TChunkCallback;

function HttpRequestReadChunks(const ABody: IReader;
  const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64; inline;
function HttpRequestReadBody(const ABody: IReader;
  const AMaxBytes: Int64; const ABufSize: SizeUInt = 32768): TBytes; inline;

{ Cookie helpers }
function ParseCookies(const AHeaderValue: string): TRequestCookies; inline;
function BuildSetCookie(const ACookie: TSetCookie): string; inline;
function MakeCookie(const AName, AValue: string): TSetCookie; inline;
function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean; inline;
function NewHttpCookieJar: IHttpCookieJar; inline;
function HttpCookieSiteKey(const AHost: string): string; inline;

{ === Section E: Transports — server/client factories & fetch/decode helpers (→ transports) === }
function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer; overload; inline;
{** @desc NewHttpServer with request LocalArena wired at the handler root. }
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  AArenaCapacity: SizeUInt): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions; AArenaCapacity: SizeUInt): IHttpServer; overload; inline;
function NewHttpClient: IHttpClient; inline;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload; inline;
function NewHttpClient(const ATransport: IHttpTransport): IHttpClient; overload; inline;
function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient; overload; inline;
function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64; inline;
function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64; inline;
procedure HttpReleaseResponseBody(const AResp: IHttpResponse); inline;
function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes; inline;
function HttpReadResponseBodyString(const AResp: IHttpResponse): string; inline;
function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string; inline;
{** @desc Decode body bytes for a single Content-Encoding (gzip/deflate/identity). }
function HttpDecodeContentEncoding(const AEncoding: string;
  const ABody: TBytes; const AMaxSize: Int64 = 0): TBytes; inline;
{** @desc Read wire body then decode via Content-Encoding. }
function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64 = 0): TBytes; inline;
{** @desc Decoded response body as string. }
function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64 = 0): string; inline;
{** @desc Raise EHttpError if response status is not 2xx (200-299). Returns AResp for chaining. }
function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse; overload; inline;
{** @desc Same as HttpEnsureSuccess, with method/URL prefix in error messages. }
function HttpEnsureSuccess(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IHttpResponse; overload; inline;
{** @desc GET url, ensure 2xx, return body as string. Raises on non-2xx. }
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string; inline;
{** @desc GET url, ensure 2xx, return body as TBytes. Raises on non-2xx. }
function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes; inline;
{** @desc Ensure 2xx and parse response body as JSON document. }
function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument; overload; inline;
{** @desc Same as HttpReadResponseJson, with method/URL prefix in error messages. }
function HttpReadResponseJson(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IJsonDocument; overload; inline;
{** @desc GET url, ensure 2xx, parse body as JSON document. Raises on non-2xx or invalid JSON. }
function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument; inline;
{** @desc POST with body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPostString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string; inline;
{** @desc PUT with body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPutString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string; inline;
{** @desc PATCH with body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPatchString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string; inline;
{** @desc DELETE url, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpDeleteString(const AClient: IHttpClient;
  const AUrl: string): string; inline;
{** @desc HEAD url, ensure 2xx, return response (headers only). Raises on non-2xx. }
function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse; inline;
{** @desc OPTIONS url, ensure 2xx, return response. Raises on non-2xx. }
function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse; inline;
{** @desc POST JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPostJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
{** @desc PUT JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPutJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
{** @desc PATCH JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPatchJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
{** @desc DELETE with JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpDeleteJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
{** @desc POST JSON body, ensure 2xx, parse response as JSON document. }
function HttpPostJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
{** @desc PUT JSON body, ensure 2xx, parse response as JSON document. }
function HttpPutJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
{** @desc PATCH JSON body, ensure 2xx, parse response as JSON document. }
function HttpPatchJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function ExtractCharsetFromContentType(const AContentType: string): string; inline;
function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string; inline;
function NewMultipartBoundary: string; inline;
function EncodeMultipartFormData(const AFields: TFormFieldArray;
  const AFiles: THttpFileArray; const ABoundary: string = ''): string; inline;
function MultipartParseOptionsDefault: TMultipartParseOptions; inline;
function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData; inline;
function ParseMultipartFormDataFromReader(const ABody: IReader;
  const ABoundary: string;
  const AOptions: TMultipartParseOptions): TMultipartFormData; inline;

implementation

{ === Impl B: Minimal — backend/method/status/version/cancel → minimal/base (inline thin) === }
function DefaultTcpServerBackend: TTcpServerBackend;
begin
  Result := nextpas.core.http.transports.DefaultTcpServerBackend;
end;

function TcpServerBackendName(const ABackend: TTcpServerBackend): string;
begin
  Result := nextpas.core.http.transports.TcpServerBackendName(ABackend);
end;

function HttpMethodToStr(const AMethod: THttpMethod): string;
begin
  Result := nextpas.core.http.minimal.HttpMethodToStr(AMethod);
end;

function HttpStrToMethod(const AStr: string): THttpMethod;
begin
  Result := nextpas.core.http.minimal.HttpStrToMethod(AStr);
end;

function HttpStatusText(const ACode: THttpStatus): string;
begin
  Result := nextpas.core.http.minimal.HttpStatusText(ACode);
end;

function HttpStatusIsInformational(const ACode: THttpStatus): Boolean;
begin
  Result := nextpas.core.http.base.HttpStatusIsInformational(ACode);
end;

function HttpStatusIsSuccess(const ACode: THttpStatus): Boolean;
begin
  Result := nextpas.core.http.base.HttpStatusIsSuccess(ACode);
end;

function HttpStatusIsRedirect(const ACode: THttpStatus): Boolean;
begin
  Result := nextpas.core.http.base.HttpStatusIsRedirect(ACode);
end;

function HttpStatusIsClientError(const ACode: THttpStatus): Boolean;
begin
  Result := nextpas.core.http.base.HttpStatusIsClientError(ACode);
end;

function HttpStatusIsServerError(const ACode: THttpStatus): Boolean;
begin
  Result := nextpas.core.http.base.HttpStatusIsServerError(ACode);
end;

function HttpVersionToStr(const AVersion: THttpVersion): string;
begin
  Result := nextpas.core.http.base.HttpVersionToStr(AVersion);
end;

function HttpErrorIsTimeout(const E: Exception): Boolean;
begin
  Result := nextpas.core.http.base.HttpErrorIsTimeout(E);
end;

function HttpErrorIsRetryable(const E: Exception): Boolean;
begin
  Result := nextpas.core.http.base.HttpErrorIsRetryable(E);
end;

function HttpErrorIsUserError(const E: Exception): Boolean;
begin
  Result := nextpas.core.http.base.HttpErrorIsUserError(E);
end;

function NewHttpCancelToken: IHttpCancelToken;
begin
  Result := nextpas.core.http.minimal.NewHttpCancelToken;
end;

procedure HttpThrowIfCanceled(const AToken: IHttpCancelToken);
begin
  nextpas.core.http.base.HttpThrowIfCanceled(AToken);
end;

function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean;
begin
  Result := nextpas.core.http.messages.HttpIsRetryableMethod(AMethod);
end;

function HttpHasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean;
begin
  Result := nextpas.core.http.messages.HttpHasRetryIdempotencyKey(AReq);
end;

function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean;
begin
  Result := nextpas.core.http.messages.HttpIsRetrySafeRequest(AReq);
end;

{ === Impl F: Extensions — headers/url (→ extensions) inline thin, Move in bytes.ops === }
function NewHeaders: IHttpHeaders;
begin
  Result := nextpas.core.http.extensions.NewHeaders;
end;

procedure SetBasicAuth(const AHeaders: IHttpHeaders;
  const AUsername, APassword: string);
begin
  nextpas.core.http.extensions.SetBasicAuth(AHeaders, AUsername, APassword);
end;

procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string);
begin
  nextpas.core.http.extensions.SetBearerAuth(AHeaders, AToken);
end;

function TryParseBearerToken(const AAuthHeader: string;
  out AToken: string): Boolean;
begin
  Result := nextpas.core.http.extensions.TryParseBearerToken(AAuthHeader,
    AToken);
end;

function UrlEncode(const AStr: string): string;
begin
  Result := nextpas.core.http.extensions.UrlEncode(AStr);
end;

function UrlDecode(const AStr: string): string;
begin
  Result := nextpas.core.http.extensions.UrlDecode(AStr);
end;

function UrlDecodeQuery(const AStr: string): string;
begin
  Result := nextpas.core.http.extensions.UrlDecodeQuery(AStr);
end;

function UrlDecodePath(const AStr: string): string;
begin
  Result := nextpas.core.http.extensions.UrlDecodePath(AStr);
end;

function ParseQueryString(const AQuery: string): TQueryParams;
begin
  Result := nextpas.core.http.extensions.ParseQueryString(AQuery);
end;

function EncodeQueryString(const AParams: TQueryParams): string;
begin
  Result := nextpas.core.http.extensions.EncodeQueryString(AParams);
end;

function QueryParamValue(const AParams: TQueryParams; const AName: string): string;
begin
  Result := nextpas.core.http.extensions.QueryParamValue(AParams, AName);
end;

function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean;
begin
  Result := nextpas.core.http.extensions.QueryParamHas(AParams, AName);
end;

function QueryLimitClamped(const AReq: IHttpRequest; const AName: string;
  ADefault, AMax: Integer): Integer;
begin
  Result := nextpas.core.http.extensions.QueryLimitClamped(AReq, AName, ADefault, AMax);
end;

function QueryOffsetClamped(const AReq: IHttpRequest; const AName: string;
  ADefault: Integer): Integer;
begin
  Result := nextpas.core.http.extensions.QueryOffsetClamped(AReq, AName, ADefault);
end;

{ === Impl B: Minimal router (→ minimal) === }
function NewRouter: IHttpRouter;
begin
  Result := nextpas.core.http.minimal.NewRouter;
end;

{ === Impl D: Middlewares — chain & product (→ middlewares) inline thin, bytes.ops single source === }
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler;
begin
  Result := nextpas.core.http.middlewares.HandlerFunc(AFunc);
end;

function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler;
begin
  Result := nextpas.core.http.middlewares.HandlerFunc(AMethod);
end;

function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler;
begin
  Result := nextpas.core.http.middlewares.HandlerFunc(AProc);
end;

function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.MiddlewareFunc(AWrapFunc);
end;

function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.CorsMiddleware(AOptions);
end;

function RecoveryMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RecoveryMiddleware;
end;

function RecoveryMiddlewareWith(const AOnError: TRecoveryCallback): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RecoveryMiddlewareWith(AOnError);
end;

function ResponseTimeMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.ResponseTimeMiddleware;
end;

function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.BodyLimitMiddleware(AMaxBytes);
end;

function ContentTypeMiddleware(
  const AAccepted: array of string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.ContentTypeMiddleware(AAccepted);
end;

function LoggerMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.LoggerMiddleware;
end;

function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.LoggerMiddlewareWith(ALogger);
end;

function LoggerMiddlewareWithExtras(
  const AExtras: TLogExtrasProvider): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.LoggerMiddlewareWithExtras(AExtras);
end;

function LoggerMiddlewareWithExtrasAndLogger(
  const AExtras: TLogExtrasProvider; const ALogger: TLogger): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.LoggerMiddlewareWithExtrasAndLogger(AExtras, ALogger);
end;

function RequestIdMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RequestIdMiddleware;
end;

function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RequestIdMiddlewareWith(AHeaderName);
end;

function RequestIdMiddlewareWithGenerator(const AHeaderName: string;
  const AGenerator: TRequestIdGenerator): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RequestIdMiddlewareWithGenerator(AHeaderName, AGenerator);
end;

function CacheControlMiddleware(const AValue: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.CacheControlMiddleware(AValue);
end;

function NoCacheMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.NoCacheMiddleware;
end;

function MaxAgeMiddleware(const ASeconds: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.MaxAgeMiddleware(ASeconds);
end;

function RateLimitMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RateLimitMiddleware;
end;

function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RateLimitMiddlewareWith(AOptions);
end;

function AuthMiddleware(const AOptions: TAuthOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.AuthMiddleware(AOptions);
end;

function AuthMiddlewareWithValidator(const AValidator: TAuthValidatorFunc): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.AuthMiddlewareWithValidator(AValidator);
end;

function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
begin
  Result := nextpas.core.http.middlewares.Chain(AHandler, AMiddlewares);
end;

function WhenMiddleware(
  const APredicate: TRequestPredicate;
  const AMiddleware: IHttpMiddleware): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.WhenMiddleware(APredicate, AMiddleware);
end;

function AsyncMiddleware(const APool: IThreadPool): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.AsyncMiddleware(APool);
end;

function HealthCheckMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.HealthCheckMiddleware;
end;

function HealthCheckMiddlewareAt(const APath: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.HealthCheckMiddlewareAt(APath);
end;

function NewHttpMetricsCollector: IHttpMetricsCollector;
begin
  Result := nextpas.core.http.middlewares.NewHttpMetricsCollector;
end;

function MetricsMiddleware(const ACollector: IHttpMetricsCollector): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.MetricsMiddleware(ACollector);
end;

function MetricsMiddlewareWith(const ACallback: THttpMetricsCallback): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.MetricsMiddlewareWith(ACallback);
end;

function MethodGuardMiddleware(const AAllowed: array of THttpMethod): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.MethodGuardMiddleware(AAllowed);
end;

function BodyCacheMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.BodyCacheMiddleware;
end;

function BodyCacheMiddlewareWith(const AMaxBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.BodyCacheMiddlewareWith(AMaxBytes);
end;

function BodyCacheMiddlewareUnlimited: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.BodyCacheMiddlewareUnlimited;
end;

function MetricsMiddlewareWithFields(
  const ACallback: THttpMetricsFieldsCallback): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.MetricsMiddlewareWithFields(ACallback);
end;

function ServerHeaderMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.ServerHeaderMiddleware;
end;

function ServerHeaderMiddlewareWith(const ACustomName: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.ServerHeaderMiddlewareWith(ACustomName);
end;

function ContextMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.ContextMiddleware;
end;

function NewHttpContext: IHttpContext;
begin
  Result := nextpas.core.http.middlewares.NewHttpContext;
end;

function HttpContextOf(const AReq: IHttpRequest): IHttpContext;
begin
  Result := nextpas.core.http.middlewares.HttpContextOf(AReq);
end;

function HttpContextGetString(const ACtx: IHttpContext;
  const AKey: string): string;
begin
  Result := nextpas.core.http.middlewares.HttpContextGetString(ACtx, AKey);
end;

procedure HttpContextSetString(const ACtx: IHttpContext;
  const AKey, AValue: string);
begin
  nextpas.core.http.middlewares.HttpContextSetString(ACtx, AKey, AValue);
end;

function HttpContextGetInt64(const ACtx: IHttpContext;
  const AKey: string): Int64;
begin
  Result := nextpas.core.http.middlewares.HttpContextGetInt64(ACtx, AKey);
end;

procedure HttpContextSetInt64(const ACtx: IHttpContext;
  const AKey: string; const AValue: Int64);
begin
  nextpas.core.http.middlewares.HttpContextSetInt64(ACtx, AKey, AValue);
end;

function RequestArenaMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RequestArenaMiddleware;
end;

function RequestArenaMiddlewareWith(ACapacity: SizeUInt): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.RequestArenaMiddlewareWith(ACapacity);
end;

function HttpRequestArenaOf(const AReq: IHttpRequest): IArena;
begin
  Result := nextpas.core.http.middlewares.HttpRequestArenaOf(AReq);
end;

function HttpRequestAllocatorOf(const AReq: IHttpRequest): IAllocator;
begin
  Result := nextpas.core.http.middlewares.HttpRequestAllocatorOf(AReq);
end;

procedure HttpUseRequestArena(const ARouter: IHttpRouter; ACapacity: SizeUInt);
begin
  nextpas.core.http.middlewares.HttpUseRequestArena(ARouter, ACapacity);
end;

function HttpWithRequestArena(const AHandler: IHttpHandler;
  ACapacity: SizeUInt): IHttpHandler;
begin
  Result := nextpas.core.http.middlewares.HttpWithRequestArena(AHandler, ACapacity);
end;

function CompressionMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.CompressionMiddleware;
end;

function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.CompressionMiddlewareWith(AMinSize);
end;

function DecompressMiddleware(const AMaxSize: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.DecompressMiddleware(AMaxSize);
end;

function DecompressMiddlewareUnlimited: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.DecompressMiddlewareUnlimited;
end;

function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorUnsupportedMediaType(AW, AMessage);
end;

function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorGatewayTimeout(AW, AMessage);
end;

function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.DeadlineMiddleware(ATimeoutMs);
end;

function DeadlineMiddlewareWith(ATimeoutMs: Int64;
  const AMaxBufferBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.DeadlineMiddlewareWith(
    ATimeoutMs, AMaxBufferBytes);
end;

function DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.DeadlineMiddlewareUnlimitedBuffer(
    ATimeoutMs);
end;

function HstsMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.HstsMiddleware;
end;

function HstsMiddlewareWith(const AOptions: THstsOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middlewares.HstsMiddlewareWith(AOptions);
end;

{ === Impl C: Messages — request/response builders/writers/redirects/errors (→ messages) inline thin, bytes.ops in owner, Close/PoolClear via owner === }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := nextpas.core.http.messages.NewRequest(AMethod, AUrl);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := nextpas.core.http.messages.NewRequest(AMethod, AUrl);
end;

function NewGetRequest(const APath: string): IHttpRequest;
begin
  Result := nextpas.core.http.messages.NewGetRequest(APath);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse;
begin
  Result := nextpas.core.http.messages.NewResponse(AStatus, AHeaders, ABody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ANilBody: Pointer): IHttpResponse;
begin
  Result := nextpas.core.http.messages.NewResponse(AStatus, AHeaders, ANilBody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyText: string): IHttpResponse;
begin
  Result := nextpas.core.http.messages.NewResponse(AStatus, AHeaders, ABodyText);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyBytes: TBytes): IHttpResponse;
begin
  Result := nextpas.core.http.messages.NewResponse(AStatus, AHeaders, ABodyBytes);
end;

function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteResponseString(AW, AStatus,
    AContentType, ABody);
end;

function HttpWriteResponseJson(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteResponseJson(AW, AStatus, AValue);
end;

function HttpWriteResponseBytes(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType: string;
  const ABody: TBytes): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteResponseBytes(AW, AStatus,
    AContentType, ABody);
end;

function HttpWriteResponseHtml(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ABody: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteResponseHtml(AW, AStatus, ABody);
end;

procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseNoContent(AW);
end;

procedure HttpWriteResponseOk(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseOk(AW);
end;

procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseCreated(AW);
end;

procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseAccepted(AW);
end;

procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseNotModified(AW);
end;

procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseResetContent(AW);
end;

procedure HttpWriteResponseGone(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.messages.HttpWriteResponseGone(AW);
end;

function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
begin
  Result := nextpas.core.http.messages.HttpReadRequestBodyBytes(AReq);
end;

function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest;
  const AMaxBytes: Int64): TBytes;
begin
  Result := nextpas.core.http.messages.HttpReadRequestBodyBytesMax(AReq, AMaxBytes);
end;

function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes;
begin
  Result := nextpas.core.http.messages.HttpReadRequestBodyBytesUnlimited(AReq);
end;

function HttpReadRequestBodyString(const AReq: IHttpRequest): string;
begin
  Result := nextpas.core.http.messages.HttpReadRequestBodyString(AReq);
end;

function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument;
begin
  Result := nextpas.core.http.messages.HttpReadRequestBodyJson(AReq);
end;

procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string);
begin
  nextpas.core.http.messages.HttpRedirect(AW, AStatus, ALocation);
end;

procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  nextpas.core.http.messages.HttpRedirectMovedPermanently(AW, ALocation);
end;

procedure HttpRedirectFound(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  nextpas.core.http.messages.HttpRedirectFound(AW, ALocation);
end;

procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  nextpas.core.http.messages.HttpRedirectSeeOther(AW, ALocation);
end;

procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  nextpas.core.http.messages.HttpRedirectTemporaryRedirect(AW, ALocation);
end;

procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  nextpas.core.http.messages.HttpRedirectPermanentRedirect(AW, ALocation);
end;

function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string;
  const AInstance: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorResponse(
    AW, AStatus, ACode, AMessage, AInstance);
end;

function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorBadRequest(AW, AMessage);
end;

function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorUnauthorized(AW, AMessage);
end;

function HttpWriteErrorForbidden(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorForbidden(AW, AMessage);
end;

function HttpWriteErrorNotFound(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorNotFound(AW, AMessage);
end;

function HttpWriteErrorInternal(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorInternal(AW, AMessage);
end;

function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorTooManyRequests(AW, AMessage);
end;

function HttpWriteErrorConflict(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorConflict(AW, AMessage);
end;

function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorUnprocessableEntity(AW, AMessage);
end;

function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.messages.HttpWriteErrorPayloadTooLarge(AW, AMessage);
end;

{ === Impl F: Extensions — static/ETag/304/ws/sse/stream/cookie/form (→ extensions) inline thin, bytes.ops single source, try/finally Close via owner === }
function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.extensions.ServeFile(APath);
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.extensions.ServeDir(ARoot);
end;

function ServeVfs(const AFs: IVfs): THttpHandlerFunc;
begin
  Result := nextpas.core.http.extensions.ServeVfs(AFs);
end;

function ServeFileDownload(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.extensions.ServeFileDownload(APath);
end;

function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.extensions.ServeFileDownload(APath, ADownloadName);
end;

function HttpMakeStrongETag(const ASize, AModTime: Int64): string;
begin
  Result := nextpas.core.http.extensions.HttpMakeStrongETag(ASize, AModTime);
end;

function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean;
begin
  Result := nextpas.core.http.extensions.HttpIfNoneMatchMatches(AIfNoneMatch, AServerETag);
end;

function HttpNotModifiedSince(const AIfModifiedSince: string;
  const AModTimeUnix: Int64): Boolean;
begin
  Result := nextpas.core.http.extensions.HttpNotModifiedSince(
    AIfModifiedSince, AModTimeUnix);
end;

function HttpTryWriteNotModified(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AETag, ALastModified: string;
  const AModTimeUnix: Int64): Boolean;
begin
  Result := nextpas.core.http.extensions.HttpTryWriteNotModified(
    AReq, AW, AETag, ALastModified, AModTimeUnix);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket;
begin
  Result := nextpas.core.http.extensions.UpgradeWebSocket(AReq, AW);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.extensions.UpgradeWebSocket(AReq, AW, AOptions);
end;

function ConnectWebSocket(const AUrl: string): IWebSocket;
begin
  Result := nextpas.core.http.extensions.ConnectWebSocket(AUrl);
end;

function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.extensions.ConnectWebSocket(AUrl, AOptions);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket;
begin
  Result := nextpas.core.http.extensions.ConnectWebSocket(AClient, AUrl);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.extensions.ConnectWebSocket(AClient, AUrl, AOptions);
end;

function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter;
begin
  Result := nextpas.core.http.extensions.StartSSE(AW);
end;

function MakeSSEvent(const AType, AData, AId: string): TSSEvent;
begin
  Result := nextpas.core.http.extensions.MakeSSEvent(AType, AData, AId);
end;

function HttpWriteStream(const AW: IHttpResponseWriter;
  const AReader: IReader; const ABufSize: SizeUInt): Int64;
begin
  Result := nextpas.core.http.extensions.HttpWriteStream(AW, AReader, ABufSize);
end;

function HttpWriteStreamWithLength(const AW: IHttpResponseWriter;
  const AContentLength: Int64; const AReader: IReader;
  const ABufSize: SizeUInt): Int64;
begin
  Result := nextpas.core.http.extensions.HttpWriteStreamWithLength(
    AW, AContentLength, AReader, ABufSize);
end;

function HttpRequestReadChunks(const ABody: IReader;
  const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64;
begin
  Result := nextpas.core.http.extensions.HttpRequestReadChunks(
    ABody, ABufSize, AOnChunk);
end;

function HttpRequestReadBody(const ABody: IReader;
  const AMaxBytes: Int64; const ABufSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.http.extensions.HttpRequestReadBody(
    ABody, AMaxBytes, ABufSize);
end;

function ParseCookies(const AHeaderValue: string): TRequestCookies;
begin
  Result := nextpas.core.http.extensions.ParseCookies(AHeaderValue);
end;

function BuildSetCookie(const ACookie: TSetCookie): string;
begin
  Result := nextpas.core.http.extensions.BuildSetCookie(ACookie);
end;

function MakeCookie(const AName, AValue: string): TSetCookie;
begin
  Result := nextpas.core.http.extensions.MakeCookie(AName, AValue);
end;

function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean;
begin
  Result := nextpas.core.http.extensions.ParseSingleCookie(AStr, AName, AValue);
end;

function NewHttpCookieJar: IHttpCookieJar;
begin
  Result := nextpas.core.http.extensions.NewHttpCookieJar;
end;

function HttpCookieSiteKey(const AHost: string): string;
begin
  Result := nextpas.core.http.extensions.HttpCookieSiteKey(AHost);
end;

{ === Impl E: Transports — server/client factories & fetch/decode (→ transports) inline thin, PoolClear/Close via owner === }
function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServer(AHandler);
end;

function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServer(AHandler, AOptions);
end;

function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServer(AHandler, ATransport);
end;

function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServer(AHandler, ATransport, AOptions);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServerWithRequestArena(AHandler);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServerWithRequestArena(AHandler, AOptions);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  AArenaCapacity: SizeUInt): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServerWithRequestArena(AHandler, AArenaCapacity);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions; AArenaCapacity: SizeUInt): IHttpServer;
begin
  Result := nextpas.core.http.transports.NewHttpServerWithRequestArena(AHandler, AOptions, AArenaCapacity);
end;

function NewHttpClient: IHttpClient;
begin
  Result := nextpas.core.http.transports.NewHttpClient;
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.transports.NewHttpClient(AOptions);
end;

function NewHttpClient(const ATransport: IHttpTransport): IHttpClient;
begin
  Result := nextpas.core.http.transports.NewHttpClient(ATransport);
end;

function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.transports.NewHttpClient(ATransport, AOptions);
end;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64;
begin
  Result := nextpas.core.http.transports.HttpGetToWriter(AClient, AUrl, ADest);
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
begin
  Result := nextpas.core.http.transports.HttpGetToFile(AClient, AUrl, ADestPath);
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  nextpas.core.http.transports.HttpReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
begin
  Result := nextpas.core.http.transports.HttpReadResponseBodyBytes(AResp);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.transports.HttpReadResponseBodyString(AResp);
end;

function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.transports.HttpReadResponseBodyStringAuto(AResp);
end;

function HttpDecodeContentEncoding(const AEncoding: string;
  const ABody: TBytes; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.transports.HttpDecodeContentEncoding(
    AEncoding, ABody, AMaxSize);
end;

function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.transports.HttpReadResponseBodyBytesDecoded(
    AResp, AMaxSize);
end;

function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64): string;
begin
  Result := nextpas.core.http.transports.HttpReadResponseBodyStringDecoded(
    AResp, AMaxSize);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
begin
  Result := nextpas.core.http.transports.HttpEnsureSuccess(AResp);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.transports.HttpEnsureSuccess(AResp, AMethod, AUrl);
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.transports.HttpGetString(AClient, AUrl);
end;

function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
begin
  Result := nextpas.core.http.transports.HttpGetBytes(AClient, AUrl);
end;

function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument;
begin
  Result := nextpas.core.http.transports.HttpReadResponseJson(AResp);
end;

function HttpReadResponseJson(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.transports.HttpReadResponseJson(AResp, AMethod, AUrl);
end;

function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.transports.HttpGetJson(AClient, AUrl);
end;

function HttpPostString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.transports.HttpPostString(AClient, AUrl, AContentType, ABody);
end;

function HttpPutString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.transports.HttpPutString(AClient, AUrl, AContentType, ABody);
end;

function HttpPatchString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.transports.HttpPatchString(AClient, AUrl, AContentType, ABody);
end;

function HttpDeleteString(const AClient: IHttpClient;
  const AUrl: string): string;
begin
  Result := nextpas.core.http.transports.HttpDeleteString(AClient, AUrl);
end;

function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.transports.HttpHead(AClient, AUrl);
end;

function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.transports.HttpOptions(AClient, AUrl);
end;

function HttpPostJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.transports.HttpPostJson(AClient, AUrl, ABody);
end;

function HttpPutJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.transports.HttpPutJson(AClient, AUrl, ABody);
end;

function HttpPatchJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.transports.HttpPatchJson(AClient, AUrl, ABody);
end;

function HttpDeleteJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.transports.HttpDeleteJson(AClient, AUrl, ABody);
end;

function HttpPostJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.transports.HttpPostJsonDocument(AClient, AUrl, ABody);
end;

function HttpPutJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.transports.HttpPutJsonDocument(AClient, AUrl, ABody);
end;

function HttpPatchJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.transports.HttpPatchJsonDocument(AClient, AUrl, ABody);
end;

function ExtractCharsetFromContentType(const AContentType: string): string;
begin
  Result := nextpas.core.http.transports.ExtractCharsetFromContentType(AContentType);
end;

function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string;
begin
  Result := nextpas.core.http.extensions.EncodeUrlEncodedForm(AFields);
end;

function NewMultipartBoundary: string;
begin
  Result := nextpas.core.http.extensions.NewMultipartBoundary;
end;

function EncodeMultipartFormData(const AFields: TFormFieldArray;
  const AFiles: THttpFileArray; const ABoundary: string): string;
begin
  Result := nextpas.core.http.extensions.EncodeMultipartFormData(AFields, AFiles, ABoundary);
end;

function MultipartParseOptionsDefault: TMultipartParseOptions;
begin
  Result := nextpas.core.http.extensions.MultipartParseOptionsDefault;
end;

function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData;
begin
  Result := nextpas.core.http.extensions.ParseMultipartFormData(ABody, ABoundary);
end;

function ParseMultipartFormDataFromReader(const ABody: IReader;
  const ABoundary: string;
  const AOptions: TMultipartParseOptions): TMultipartFormData;
begin
  Result := nextpas.core.http.extensions.ParseMultipartFormDataFromReader(ABody,
    ABoundary, AOptions);
end;

{ === Impl G: Mem/Arena — request arena & process heap (→ middlewares/mem) inline thin, arena drop via owner === }
function HttpCreateRequestArena(ACapacity: SizeUInt): IArena;
begin
  Result := nextpas.core.http.middlewares.HttpCreateRequestArena(ACapacity);
end;

function HttpCreateRequestAllocator(ACapacity: SizeUInt): IAllocator;
begin
  Result := nextpas.core.http.middlewares.HttpCreateRequestAllocator(ACapacity);
end;

function HttpProcessHeap: TGrowingAllocator;
begin
  Result := nextpas.core.http.middlewares.HttpProcessHeap;
end;

function HttpProcessAllocator: IAllocator;
begin
  Result := nextpas.core.http.middlewares.HttpProcessAllocator;
end;

function HttpFormatProcessMemStats: string;
begin
  Result := nextpas.core.http.middlewares.HttpFormatProcessMemStats;
end;

end.
