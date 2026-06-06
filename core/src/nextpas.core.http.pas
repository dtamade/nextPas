unit nextpas.core.http;
{**
 * @desc HTTP module facade. Provides unified access to HTTP types, interfaces,
 *       headers, URL utilities, router, middleware, and message factories.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.url,
  nextpas.core.http.router,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.http.static,
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

  { Re-export interfaces }
  IHttpHeaders = nextpas.core.http.intf.IHttpHeaders;
  IHttpRequest = nextpas.core.http.intf.IHttpRequest;
  IHttpResponse = nextpas.core.http.intf.IHttpResponse;
  IHttpResponseWriter = nextpas.core.http.intf.IHttpResponseWriter;
  IHttpHandler = nextpas.core.http.intf.IHttpHandler;
  IHttpMiddleware = nextpas.core.http.intf.IHttpMiddleware;
  IHttpRouter = nextpas.core.http.intf.IHttpRouter;
  IHttpServer = nextpas.core.http.intf.IHttpServer;
  IHttpClient = nextpas.core.http.intf.IHttpClient;
  IHttpTransport = nextpas.core.http.intf.IHttpTransport;
  IHttpServerTransport = nextpas.core.http.intf.IHttpServerTransport;
  ITcpServerSession = nextpas.core.http.intf.ITcpServerSession;
  ITcpServerSessionContext = nextpas.core.http.intf.ITcpServerSessionContext;
  IHttpServerSessionFactory = nextpas.core.http.intf.IHttpServerSessionFactory;
  IHttpServerSessionFactoryWithContext = nextpas.core.http.intf.IHttpServerSessionFactoryWithContext;
  IHttpHijacker = nextpas.core.http.intf.IHttpHijacker;
  IWebSocket = nextpas.core.http.websocket.IWebSocket;
  TTcpServerConnOwnership = nextpas.core.http.intf.TTcpServerConnOwnership;

  { Re-export callback types }
  THttpHandlerFunc = nextpas.core.http.intf.THttpHandlerFunc;
  THttpHandlerMethod = nextpas.core.http.intf.THttpHandlerMethod;
  THttpHandlerProc = nextpas.core.http.intf.THttpHandlerProc;
  THeaderIterator = nextpas.core.http.intf.THeaderIterator;
  TWebSocketOptions = nextpas.core.http.websocket.TWebSocketOptions;
  TWebSocketOpcode = nextpas.core.http.websocket.TWebSocketOpcode;
  TWebSocketFrame = nextpas.core.http.websocket.TWebSocketFrame;

  { Re-export server/client types }
  THttpServer = nextpas.core.http.server.THttpServer;
  THttpServerOptions = nextpas.core.http.base.THttpServerOptions;
  THttpClient = nextpas.core.http.client.THttpClient;
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;

  { Re-export URL types }
  TQueryParam = nextpas.core.http.url.TQueryParam;
  TQueryParams = nextpas.core.http.url.TQueryParams;

{ Status constants - re-export }
const
  HTTP_STATUS_CONTINUE = nextpas.core.http.base.HTTP_STATUS_CONTINUE;
  HTTP_STATUS_EARLY_HINTS = nextpas.core.http.base.HTTP_STATUS_EARLY_HINTS;
  HTTP_STATUS_SWITCHING_PROTOCOLS = nextpas.core.http.base.HTTP_STATUS_SWITCHING_PROTOCOLS;
  HTTP_STATUS_OK = nextpas.core.http.base.HTTP_STATUS_OK;
  HTTP_STATUS_CREATED = nextpas.core.http.base.HTTP_STATUS_CREATED;
  HTTP_STATUS_NO_CONTENT = nextpas.core.http.base.HTTP_STATUS_NO_CONTENT;
  HTTP_STATUS_MOVED_PERMANENTLY = nextpas.core.http.base.HTTP_STATUS_MOVED_PERMANENTLY;
  HTTP_STATUS_FOUND = nextpas.core.http.base.HTTP_STATUS_FOUND;
  HTTP_STATUS_SEE_OTHER = nextpas.core.http.base.HTTP_STATUS_SEE_OTHER;
  HTTP_STATUS_NOT_MODIFIED = nextpas.core.http.base.HTTP_STATUS_NOT_MODIFIED;
  HTTP_STATUS_BAD_REQUEST = nextpas.core.http.base.HTTP_STATUS_BAD_REQUEST;
  HTTP_STATUS_UNAUTHORIZED = nextpas.core.http.base.HTTP_STATUS_UNAUTHORIZED;
  HTTP_STATUS_FORBIDDEN = nextpas.core.http.base.HTTP_STATUS_FORBIDDEN;
  HTTP_STATUS_NOT_FOUND = nextpas.core.http.base.HTTP_STATUS_NOT_FOUND;
  HTTP_STATUS_METHOD_NOT_ALLOWED = nextpas.core.http.base.HTTP_STATUS_METHOD_NOT_ALLOWED;
  HTTP_STATUS_PAYLOAD_TOO_LARGE = nextpas.core.http.base.HTTP_STATUS_PAYLOAD_TOO_LARGE;
  HTTP_STATUS_EXPECTATION_FAILED = nextpas.core.http.base.HTTP_STATUS_EXPECTATION_FAILED;
  HTTP_STATUS_HEADER_TOO_LARGE = nextpas.core.http.base.HTTP_STATUS_HEADER_TOO_LARGE;
  HTTP_STATUS_INTERNAL_SERVER_ERROR = nextpas.core.http.base.HTTP_STATUS_INTERNAL_SERVER_ERROR;
  HTTP_STATUS_NOT_IMPLEMENTED = nextpas.core.http.base.HTTP_STATUS_NOT_IMPLEMENTED;
  HTTP_STATUS_BAD_GATEWAY = nextpas.core.http.base.HTTP_STATUS_BAD_GATEWAY;
  HTTP_STATUS_SERVICE_UNAVAILABLE = nextpas.core.http.base.HTTP_STATUS_SERVICE_UNAVAILABLE;
  wsOpContinuation = nextpas.core.http.websocket.wsOpContinuation;
  wsOpText = nextpas.core.http.websocket.wsOpText;
  wsOpBinary = nextpas.core.http.websocket.wsOpBinary;
  wsOpClose = nextpas.core.http.websocket.wsOpClose;
  wsOpPing = nextpas.core.http.websocket.wsOpPing;
  wsOpPong = nextpas.core.http.websocket.wsOpPong;
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;
  TCP_SERVER_BACKEND_THREADED = nextpas.core.http.base.TCP_SERVER_BACKEND_THREADED;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.http.base.TCP_SERVER_BACKEND_EPOLL;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.http.base.TCP_SERVER_BACKEND_KQUEUE;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.http.base.TCP_SERVER_BACKEND_IOCP;
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_SERVER;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_HANDLER;

{ Forwarding functions }
function HttpMethodToStr(const AMethod: THttpMethod): string; inline;
function HttpStrToMethod(const AStr: string): THttpMethod; inline;
function HttpStatusText(const ACode: THttpStatus): string; inline;
function HttpVersionToStr(const AVersion: THttpVersion): string; inline;

{ Headers factory }
function NewHeaders: IHttpHeaders; inline;

{ URL utilities }
function UrlEncode(const AStr: string): string; inline;
function UrlDecode(const AStr: string): string; inline;
function ParseQueryString(const AQuery: string): TQueryParams; inline;
function EncodeQueryString(const AParams: TQueryParams): string; inline;

{ Router factory }
function NewRouter: IHttpRouter; inline;

{ Handler/Middleware helpers }
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler; overload; inline;
function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler; overload; inline;
function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler; overload; inline;
function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;

{ Message factories }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload; inline;
function NewGetRequest(const APath: string): IHttpRequest; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse; inline;

{ Static helpers }
function ServeFile(const APath: string): THttpHandlerFunc; inline;
function ServeDir(const ARoot: string): THttpHandlerFunc; inline;

{ WebSocket helper }
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket; overload; inline;
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
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
function HttpReadResponseBodyString(const AResp: IHttpResponse): string; inline;

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

function HttpVersionToStr(const AVersion: THttpVersion): string;
begin
  Result := nextpas.core.http.base.HttpVersionToStr(AVersion);
end;

function NewHeaders: IHttpHeaders;
begin
  Result := nextpas.core.http.headers.NewHttpHeaders;
end;

function UrlEncode(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlEncode(AStr);
end;

function UrlDecode(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecode(AStr);
end;

function ParseQueryString(const AQuery: string): TQueryParams;
begin
  Result := nextpas.core.http.url.ParseQueryString(AQuery);
end;

function EncodeQueryString(const AParams: TQueryParams): string;
begin
  Result := nextpas.core.http.url.EncodeQueryString(AParams);
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

function NewGetRequest(const APath: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewGetRequest(APath);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABody);
end;

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFile(APath);
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeDir(ARoot);
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

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyString(AResp);
end;

end.
