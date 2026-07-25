unit nextpas.core.http.minimal;
{**
 * @desc Thin HTTP facade: types + router + server + client + request factories.
 *       Does NOT pull the middleware product family (cors/recovery/…).
 *       Full stack (all middleware re-exports): uses nextpas.core.http.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.url,
  nextpas.core.http.router,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.http.server,
  nextpas.core.http.client;

type
  THttpVersion = nextpas.core.http.base.THttpVersion;
  THttpMethod = nextpas.core.http.base.THttpMethod;
  THttpStatus = nextpas.core.http.base.THttpStatus;
  TTcpServerBackend = nextpas.core.http.base.TTcpServerBackend;
  TUrl = nextpas.core.http.base.TUrl;
  THttpErrorKind = nextpas.core.http.base.THttpErrorKind;
  EHttpError = nextpas.core.http.base.EHttpError;
  IHttpCancelToken = nextpas.core.http.base.IHttpCancelToken;
  THttpRequestOptions = nextpas.core.http.base.THttpRequestOptions;
  THttpServerOptions = nextpas.core.http.base.THttpServerOptions;
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;

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
  THttpHandlerFunc = nextpas.core.http.intf.THttpHandlerFunc;
  THttpHandlerMethod = nextpas.core.http.intf.THttpHandlerMethod;
  THttpHandlerProc = nextpas.core.http.intf.THttpHandlerProc;
  TMiddlewareWrapFunc = nextpas.core.http.middleware.TMiddlewareWrapFunc;
  THttpRequestBuilder = nextpas.core.http.message.THttpRequestBuilder;
  THttpServer = nextpas.core.http.server.THttpServer;
  THttpClient = nextpas.core.http.client.THttpClient;
  TQueryParams = nextpas.core.http.url.TQueryParams;
  TNetAddress = nextpas.core.net.base.TNetAddress;

const
  HTTP_STATUS_OK = nextpas.core.http.base.HTTP_STATUS_OK;
  HTTP_STATUS_CREATED = nextpas.core.http.base.HTTP_STATUS_CREATED;
  HTTP_STATUS_NO_CONTENT = nextpas.core.http.base.HTTP_STATUS_NO_CONTENT;
  HTTP_STATUS_BAD_REQUEST = nextpas.core.http.base.HTTP_STATUS_BAD_REQUEST;
  HTTP_STATUS_NOT_FOUND = nextpas.core.http.base.HTTP_STATUS_NOT_FOUND;
  HTTP_STATUS_INTERNAL_SERVER_ERROR =
    nextpas.core.http.base.HTTP_STATUS_INTERNAL_SERVER_ERROR;
  TCP_SERVER_BACKEND_THREADED =
    nextpas.core.http.base.TCP_SERVER_BACKEND_THREADED;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.http.base.TCP_SERVER_BACKEND_EPOLL;

function HttpMethodToStr(const AMethod: THttpMethod): string; inline;
function HttpStrToMethod(const AStr: string): THttpMethod; inline;
function HttpStatusText(const ACode: THttpStatus): string; inline;
function NewHttpCancelToken: IHttpCancelToken; inline;
function NewHeaders: IHttpHeaders; inline;
function NewRouter: IHttpRouter; inline;
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler; overload; inline;
function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler; overload; inline;
function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler; overload; inline;
function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware; inline;
function Chain(const AHandler: IHttpHandler;
  const AMiddlewares: array of IHttpMiddleware): IHttpHandler; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload; inline;
function NewGetRequest(const APath: string): IHttpRequest; inline;
function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpClient: IHttpClient; overload; inline;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload; inline;
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string; inline;
function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt; inline;

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

function NewHttpCancelToken: IHttpCancelToken;
begin
  Result := nextpas.core.http.base.NewHttpCancelToken;
end;

function NewHeaders: IHttpHeaders;
begin
  Result := nextpas.core.http.headers.NewHttpHeaders;
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

function Chain(const AHandler: IHttpHandler;
  const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
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

function NewGetRequest(const APath: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewGetRequest(APath);
end;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler);
end;

function NewHttpServer(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, AOptions);
end;

function NewHttpClient: IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient;
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(AOptions);
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpGetString(AClient, AUrl);
end;

function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseString(AW, AStatus,
    AContentType, ABody);
end;

end.