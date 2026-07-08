unit nextpas.core.http;
{**
 * @desc HTTP module facade. Provides unified access to HTTP types, interfaces,
 *       headers, URL utilities, router, middleware, and message factories.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.url,
  nextpas.core.http.router,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.cors,
  nextpas.core.http.middleware.recovery,
  nextpas.core.http.middleware.timeout,
  nextpas.core.http.middleware.bodylimit,
  nextpas.core.http.middleware.contenttype,
  nextpas.core.http.middleware.logger,
  nextpas.core.http.middleware.requestid,
  nextpas.core.http.message,
  nextpas.core.json,
  nextpas.core.log,
  nextpas.core.http.static,
  nextpas.core.http.form,
  nextpas.core.http.websocket,
  nextpas.core.http.server,
  nextpas.core.http.client;

type
  { Re-export base types }
  THttpVersion = nextpas.core.http.base.THttpVersion;
  THttpMethod = nextpas.core.http.base.THttpMethod;
  THttpStatus = nextpas.core.http.base.THttpStatus;
  TTcpServerBackend = nextpas.core.http.base.TTcpServerBackend;
  TUrl = nextpas.core.http.base.TUrl;
  EHttpError = nextpas.core.http.base.EHttpError;
  THttpRequestOptions = nextpas.core.http.base.THttpRequestOptions;

  { Re-export interfaces }
  IHttpHeaders = nextpas.core.http.intf.IHttpHeaders;
  IHttpRequest = nextpas.core.http.intf.IHttpRequest;
  IHttpRequestWithOptions = nextpas.core.http.intf.IHttpRequestWithOptions;
  IHttpResponse = nextpas.core.http.intf.IHttpResponse;
  IHttpResponseWriter = nextpas.core.http.intf.IHttpResponseWriter;
  IHttpHandler = nextpas.core.http.intf.IHttpHandler;
  IHttpMiddleware = nextpas.core.http.intf.IHttpMiddleware;
  IHttpRouter = nextpas.core.http.intf.IHttpRouter;
  IHttpServer = nextpas.core.http.intf.IHttpServer;
  IHttpClient = nextpas.core.http.intf.IHttpClient;
  IHttpTransport = nextpas.core.http.intf.IHttpTransport;
  IHttpTransportIdleConnections = nextpas.core.http.intf.IHttpTransportIdleConnections;
  IHttpServerTransport = nextpas.core.http.intf.IHttpServerTransport;
  ITcpServerSession = nextpas.core.http.intf.ITcpServerSession;
  ITcpServerSessionContext = nextpas.core.http.intf.ITcpServerSessionContext;
  IHttpServerSessionFactory = nextpas.core.http.intf.IHttpServerSessionFactory;
  IHttpServerSessionFactoryWithContext = nextpas.core.http.intf.IHttpServerSessionFactoryWithContext;
  IH2StreamControl = nextpas.core.http.intf.IH2StreamControl;
  IHttpHijacker = nextpas.core.http.intf.IHttpHijacker;
  IWebSocket = nextpas.core.http.websocket.IWebSocket;
  TTcpServerConnOwnership = nextpas.core.http.intf.TTcpServerConnOwnership;

  { Re-export callback types }
  THttpHandlerFunc = nextpas.core.http.intf.THttpHandlerFunc;
  THttpHandlerMethod = nextpas.core.http.intf.THttpHandlerMethod;
  THttpHandlerProc = nextpas.core.http.intf.THttpHandlerProc;
  TStringArray = nextpas.core.http.intf.TStringArray;
  THeaderIterator = nextpas.core.http.intf.THeaderIterator;
  TMiddlewareWrapFunc = nextpas.core.http.middleware.TMiddlewareWrapFunc;
  TCorsOptions = nextpas.core.http.middleware.cors.TCorsOptions;
  TWebSocketOptions = nextpas.core.http.websocket.TWebSocketOptions;
  TWebSocketOpcode = nextpas.core.http.websocket.TWebSocketOpcode;
  TWebSocketFrame = nextpas.core.http.websocket.TWebSocketFrame;

  { Re-export server/client types }
  THttpServer = nextpas.core.http.server.THttpServer;
  THttpServerOptions = nextpas.core.http.base.THttpServerOptions;
  THttpClient = nextpas.core.http.client.THttpClient;
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;
  THttpRequestBuilder = nextpas.core.http.message.THttpRequestBuilder;

  { Re-export JSON types }
  IJsonDocument = nextpas.core.json.IJsonDocument;

  { Re-export log types }
  TLogger = nextpas.core.log.TLogger;

  { Re-export URL types }
  TQueryParam = nextpas.core.http.url.TQueryParam;
  TQueryParams = nextpas.core.http.url.TQueryParams;

  { Re-export form types }
  TFormField = nextpas.core.http.form.TFormField;
  TFormFieldArray = nextpas.core.http.form.TFormFieldArray;
  THttpFile = nextpas.core.http.form.THttpFile;
  THttpFileArray = nextpas.core.http.form.THttpFileArray;
  TMultipartFormData = nextpas.core.http.form.TMultipartFormData;

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
  HTTP_STATUS_FORBIDDEN = nextpas.core.http.base.HTTP_STATUS_FORBIDDEN;
  HTTP_STATUS_NOT_FOUND = nextpas.core.http.base.HTTP_STATUS_NOT_FOUND;
  HTTP_STATUS_METHOD_NOT_ALLOWED = nextpas.core.http.base.HTTP_STATUS_METHOD_NOT_ALLOWED;
  HTTP_STATUS_NOT_ACCEPTABLE = nextpas.core.http.base.HTTP_STATUS_NOT_ACCEPTABLE;
  HTTP_STATUS_REQUEST_TIMEOUT = nextpas.core.http.base.HTTP_STATUS_REQUEST_TIMEOUT;
  HTTP_STATUS_CONFLICT = nextpas.core.http.base.HTTP_STATUS_CONFLICT;
  HTTP_STATUS_GONE = nextpas.core.http.base.HTTP_STATUS_GONE;
  HTTP_STATUS_PAYLOAD_TOO_LARGE = nextpas.core.http.base.HTTP_STATUS_PAYLOAD_TOO_LARGE;
  HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE = nextpas.core.http.base.HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE;
  HTTP_STATUS_EXPECTATION_FAILED = nextpas.core.http.base.HTTP_STATUS_EXPECTATION_FAILED;
  HTTP_STATUS_UNPROCESSABLE_ENTITY = nextpas.core.http.base.HTTP_STATUS_UNPROCESSABLE_ENTITY;
  HTTP_STATUS_TOO_MANY_REQUESTS = nextpas.core.http.base.HTTP_STATUS_TOO_MANY_REQUESTS;
  HTTP_STATUS_HEADER_TOO_LARGE = nextpas.core.http.base.HTTP_STATUS_HEADER_TOO_LARGE;

  { 5xx Server Error }
  HTTP_STATUS_INTERNAL_SERVER_ERROR = nextpas.core.http.base.HTTP_STATUS_INTERNAL_SERVER_ERROR;
  HTTP_STATUS_NOT_IMPLEMENTED = nextpas.core.http.base.HTTP_STATUS_NOT_IMPLEMENTED;
  HTTP_STATUS_BAD_GATEWAY = nextpas.core.http.base.HTTP_STATUS_BAD_GATEWAY;
  HTTP_STATUS_SERVICE_UNAVAILABLE = nextpas.core.http.base.HTTP_STATUS_SERVICE_UNAVAILABLE;

  { WebSocket opcodes }
  wsOpContinuation = nextpas.core.http.websocket.wsOpContinuation;
  wsOpText = nextpas.core.http.websocket.wsOpText;
  wsOpBinary = nextpas.core.http.websocket.wsOpBinary;
  wsOpClose = nextpas.core.http.websocket.wsOpClose;
  wsOpPing = nextpas.core.http.websocket.wsOpPing;
  wsOpPong = nextpas.core.http.websocket.wsOpPong;
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;

  { TCP server backends }
  TCP_SERVER_BACKEND_THREADED = nextpas.core.http.base.TCP_SERVER_BACKEND_THREADED;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.http.base.TCP_SERVER_BACKEND_EPOLL;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.http.base.TCP_SERVER_BACKEND_KQUEUE;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.http.base.TCP_SERVER_BACKEND_IOCP;
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_SERVER;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_HANDLER;

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

{** @desc Create empty mutable headers container }
function NewHeaders: IHttpHeaders; inline;
{** @desc Set Basic/Digest Authorization header (base64-encoded user:pass) }
procedure SetBasicAuth(const AHeaders: IHttpHeaders;
  const AUsername, APassword: string); inline;
{** @desc Set Bearer Authorization header }
procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string); inline;

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

{** @desc Create a new HTTP router (path-pattern → handler mapping) }
function NewRouter: IHttpRouter; inline;

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
{** @desc Ensure X-Request-Id header on every response (preserves existing, generates UUID if missing). }
function RequestIdMiddleware: IHttpMiddleware; inline;
{** @desc Request ID middleware with custom header name. }
function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware; inline;
{** @desc Chain handler through middleware stack (first middleware = outermost wrapper) }
function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;

{** @desc Create IHttpRequest value type with method, URL, headers, body }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ANilBody: Pointer): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ANilBody: Pointer): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType, ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyBytes: TBytes): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyBytes: TBytes): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest; overload; inline;
function NewGetRequest(const APath: string): IHttpRequest; inline;
function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
  overload; inline;
function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
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
{** @desc Read request body as TBytes. Returns nil if body is nil. Raises on nil request. }
function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes; inline;
{** @desc Read request body as string. Returns '' if body is nil. Raises on nil request. }
function HttpReadRequestBodyString(const AReq: IHttpRequest): string; inline;
{** @desc Read request body and parse as JSON document. Raises on nil request or invalid JSON. }
function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument; inline;
{** @desc Write a redirect response with Location header and HTML body. }
procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string); inline;

{ Static helpers }
function ServeFile(const APath: string): THttpHandlerFunc; inline;
function ServeDir(const ARoot: string): THttpHandlerFunc; inline;
function ServeFileDownload(const APath: string): THttpHandlerFunc; overload; inline;
function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc; overload; inline;

{ WebSocket helper }
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

{ Server/Client factories }
function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer; overload; inline;
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
{** @desc Raise EHttpError if response status is not 2xx (200-299). Returns AResp for chaining. }
function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse; inline;
{** @desc GET url, ensure 2xx, return body as string. Raises on non-2xx. }
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string; inline;
{** @desc GET url, ensure 2xx, return body as TBytes. Raises on non-2xx. }
function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes; inline;
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
function ExtractCharsetFromContentType(const AContentType: string): string; inline;
function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string; inline;
function EncodeMultipartFormData(const AFields: TFormFieldArray;
  const AFiles: THttpFileArray; const ABoundary: string = ''): string; inline;

implementation

function HttpMethodToStr(const AMethod: THttpMethod): string;
begin
  Result := nextpas.core.http.base.HttpMethodToStr(AMethod);
end;

function HttpStrToMethod(const AStr: string): THttpMethod;
begin
  Result := nextpas.core.http.base.HttpStrToMethod(AStr);
end;

function HttpStatusText(const ACode: THttpStatus): string;
begin
  Result := nextpas.core.http.base.HttpStatusText(ACode);
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

function NewHeaders: IHttpHeaders;
begin
  Result := nextpas.core.http.headers.NewHttpHeaders;
end;

procedure SetBasicAuth(const AHeaders: IHttpHeaders;
  const AUsername, APassword: string);
begin
  nextpas.core.http.headers.SetBasicAuth(AHeaders, AUsername, APassword);
end;

procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string);
begin
  nextpas.core.http.headers.SetBearerAuth(AHeaders, AToken);
end;

function UrlEncode(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlEncode(AStr);
end;

function UrlDecode(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecode(AStr);
end;

function UrlDecodeQuery(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecodeQuery(AStr);
end;

function UrlDecodePath(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecodePath(AStr);
end;

function ParseQueryString(const AQuery: string): TQueryParams;
begin
  Result := nextpas.core.http.url.ParseQueryString(AQuery);
end;

function EncodeQueryString(const AParams: TQueryParams): string;
begin
  Result := nextpas.core.http.url.EncodeQueryString(AParams);
end;

function QueryParamValue(const AParams: TQueryParams; const AName: string): string;
begin
  Result := nextpas.core.http.url.QueryParamValue(AParams, AName);
end;

function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean;
begin
  Result := nextpas.core.http.url.QueryParamHas(AParams, AName);
end;

function NewRouter: IHttpRouter;
begin
  Result := nextpas.core.http.router.NewRouter;
end;

function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.HandlerFunc(AFunc);
end;

function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.HandlerFunc(AMethod);
end;

function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.HandlerFunc(AProc);
end;

function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.MiddlewareFunc(AWrapFunc);
end;

function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.cors.CorsMiddleware(AOptions);
end;

function RecoveryMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.recovery.RecoveryMiddleware;
end;

function ResponseTimeMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.timeout.ResponseTimeMiddleware;
end;

function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.bodylimit.BodyLimitMiddleware(AMaxBytes);
end;

function ContentTypeMiddleware(
  const AAccepted: array of string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.contenttype.ContentTypeMiddleware(AAccepted);
end;

function LoggerMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.logger.LoggerMiddleware;
end;

function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.logger.LoggerMiddlewareWith(ALogger);
end;

function RequestIdMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestid.RequestIdMiddleware;
end;

function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestid.RequestIdMiddlewareWith(AHeaderName);
end;

function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.Chain(AHandler, AMiddlewares);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ANilBody: Pointer): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ANilBody);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ANilBody: Pointer): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ANilBody);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AContentType,
    ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AContentType,
    ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders,
    ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders,
    ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyText: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyText: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType, ABodyText: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AContentType,
    ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABodyText: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AContentType,
    ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders,
    ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders,
    ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AContentType,
    ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AContentType,
    ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders,
    ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl, AHeaders,
    ABodyBytes);
end;

function NewGetRequest(const APath: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewGetRequest(APath);
end;

function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewStreamingRequest(AMethod, AUrl,
    ABody, AContentLength);
end;

function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewStreamingRequest(AMethod, AUrl,
    AHeaders, ABody, AContentLength);
end;

function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewStreamingRequest(AMethod, AUrl,
    AContentType, ABody, AContentLength);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ANilBody: Pointer): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ANilBody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyText: string): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABodyText);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyBytes: TBytes): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABodyBytes);
end;

function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseString(AW, AStatus,
    AContentType, ABody);
end;

function HttpWriteResponseJson(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseJson(AW, AStatus, AValue);
end;

function HttpWriteResponseBytes(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType: string;
  const ABody: TBytes): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseBytes(AW, AStatus,
    AContentType, ABody);
end;

function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyBytes(AReq);
end;

function HttpReadRequestBodyString(const AReq: IHttpRequest): string;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyString(AReq);
end;

function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyJson(AReq);
end;

procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirect(AW, AStatus, ALocation);
end;

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFile(APath);
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeDir(ARoot);
end;

function ServeFileDownload(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFileDownload(APath);
end;

function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFileDownload(APath, ADownloadName);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket;
begin
  Result := nextpas.core.http.websocket.UpgradeWebSocket(AReq, AW);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.websocket.UpgradeWebSocket(AReq, AW, AOptions);
end;

function ConnectWebSocket(const AUrl: string): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AUrl);
end;

function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AUrl, AOptions);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AClient, AUrl);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AClient, AUrl, AOptions);
end;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler);
end;

function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, AOptions);
end;

function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, ATransport);
end;

function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, ATransport, AOptions);
end;

function NewHttpClient: IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient;
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(AOptions);
end;

function NewHttpClient(const ATransport: IHttpTransport): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(ATransport);
end;

function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(ATransport, AOptions);
end;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64;
begin
  Result := nextpas.core.http.client.HttpGetToWriter(AClient, AUrl, ADest);
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
begin
  Result := nextpas.core.http.client.HttpGetToFile(AClient, AUrl, ADestPath);
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  nextpas.core.http.client.HttpReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyBytes(AResp);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyString(AResp);
end;

function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyStringAuto(AResp);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpEnsureSuccess(AResp);
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpGetString(AClient, AUrl);
end;

function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
begin
  Result := nextpas.core.http.client.HttpGetBytes(AClient, AUrl);
end;

function HttpPostString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPostString(AClient, AUrl, AContentType, ABody);
end;

function HttpPutString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPutString(AClient, AUrl, AContentType, ABody);
end;

function HttpPatchString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPatchString(AClient, AUrl, AContentType, ABody);
end;

function HttpDeleteString(const AClient: IHttpClient;
  const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpDeleteString(AClient, AUrl);
end;

function ExtractCharsetFromContentType(const AContentType: string): string;
begin
  Result := nextpas.core.http.client.ExtractCharsetFromContentType(AContentType);
end;

function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string;
begin
  Result := nextpas.core.http.form.EncodeUrlEncodedForm(AFields);
end;

function EncodeMultipartFormData(const AFields: TFormFieldArray;
  const AFiles: THttpFileArray; const ABoundary: string): string;
begin
  Result := nextpas.core.http.form.EncodeMultipartFormData(AFields, AFiles, ABoundary);
end;

end.
