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
  nextpas.core.http.message;

type
  { Re-export base types }
  THttpVersion = nextpas.core.http.base.THttpVersion;
  THttpMethod = nextpas.core.http.base.THttpMethod;
  THttpStatus = nextpas.core.http.base.THttpStatus;
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

  { Re-export callback types }
  THttpHandlerFunc = nextpas.core.http.intf.THttpHandlerFunc;
  THttpHandlerMethod = nextpas.core.http.intf.THttpHandlerMethod;
  THttpHandlerProc = nextpas.core.http.intf.THttpHandlerProc;
  THeaderIterator = nextpas.core.http.intf.THeaderIterator;

  { Re-export URL types }
  TQueryParam = nextpas.core.http.url.TQueryParam;
  TQueryParams = nextpas.core.http.url.TQueryParams;

{ Status constants - re-export }
const
  HTTP_STATUS_OK = nextpas.core.http.base.HTTP_STATUS_OK;
  HTTP_STATUS_CREATED = nextpas.core.http.base.HTTP_STATUS_CREATED;
  HTTP_STATUS_NO_CONTENT = nextpas.core.http.base.HTTP_STATUS_NO_CONTENT;
  HTTP_STATUS_MOVED_PERMANENTLY = nextpas.core.http.base.HTTP_STATUS_MOVED_PERMANENTLY;
  HTTP_STATUS_FOUND = nextpas.core.http.base.HTTP_STATUS_FOUND;
  HTTP_STATUS_NOT_MODIFIED = nextpas.core.http.base.HTTP_STATUS_NOT_MODIFIED;
  HTTP_STATUS_BAD_REQUEST = nextpas.core.http.base.HTTP_STATUS_BAD_REQUEST;
  HTTP_STATUS_UNAUTHORIZED = nextpas.core.http.base.HTTP_STATUS_UNAUTHORIZED;
  HTTP_STATUS_FORBIDDEN = nextpas.core.http.base.HTTP_STATUS_FORBIDDEN;
  HTTP_STATUS_NOT_FOUND = nextpas.core.http.base.HTTP_STATUS_NOT_FOUND;
  HTTP_STATUS_METHOD_NOT_ALLOWED = nextpas.core.http.base.HTTP_STATUS_METHOD_NOT_ALLOWED;
  HTTP_STATUS_INTERNAL_SERVER_ERROR = nextpas.core.http.base.HTTP_STATUS_INTERNAL_SERVER_ERROR;
  HTTP_STATUS_BAD_GATEWAY = nextpas.core.http.base.HTTP_STATUS_BAD_GATEWAY;
  HTTP_STATUS_SERVICE_UNAVAILABLE = nextpas.core.http.base.HTTP_STATUS_SERVICE_UNAVAILABLE;

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
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler; inline;
function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;

{ Message factories }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; inline;
function NewGetRequest(const APath: string): IHttpRequest; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse; inline;

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

function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.Chain(AHandler, AMiddlewares);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl);
end;

function NewGetRequest(const APath: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewGetRequest(APath);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABody);
end;

end.
