unit nextpas.core.http.middleware;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.sync.intf,
  nextpas.core.sync.spinlock,
  nextpas.core.thread.intf,
  nextpas.core.mem.arena.intf;

type
  { Function type for creating middleware from a closure }
  TMiddlewareWrapFunc = reference to function(const ANext: IHttpHandler): IHttpHandler;

  { Predicate for conditional middleware — returns True to apply, False to skip }
  TRequestPredicate = reference to function(const AReq: IHttpRequest): Boolean;

  {** Request decorator base. Forwards IHttpRequest and optional extension
     interfaces (context/options/arena) to FInner so middleware wrappers do not
     drop Supports(IHttpRequestWithContext/Options/Arena). Override GetBody/
     GetHeaders/GetContentLength as needed. }
  THttpRequestWrapper = class(TInterfacedObject, IHttpRequest,
    IHttpRequestWithOptions, IHttpRequestWithContext, IHttpRequestWithArena)
  protected
    FInner: IHttpRequest;
    function GetMethod: THttpMethod; virtual;
    function GetUrl: TUrl; virtual;
    function GetPath: string; virtual;
    function GetRawQuery: string; virtual;
    function GetVersion: THttpVersion; virtual;
    function GetHeaders: IHttpHeaders; virtual;
    function GetTrailers: IHttpHeaders; virtual;
    function GetBody: IReader; virtual;
    function GetContentLength: Int64; virtual;
    function GetRemoteAddr: string; virtual;
    function GetRemoteIp: string; virtual;
    function PathParam(const AName: string): string; virtual;
    function QueryParam(const AName: string): string; virtual;
    function GetRequestOptions: THttpRequestOptions; virtual;
    procedure SetRequestOptions(const AOptions: THttpRequestOptions); virtual;
    function GetContext: IHttpContext; virtual;
    procedure SetContext(const ACtx: IHttpContext); virtual;
    function GetArena: IArena; virtual;
    procedure SetArena(const AArena: IArena); virtual;
  public
    constructor Create(const AInner: IHttpRequest);
  end;

  { Wraps a THttpHandlerFunc into IHttpHandler }
  TFuncHandler = class(TInterfacedObject, IHttpHandler)
  private
    FFunc: THttpHandlerFunc;
  public
    constructor Create(const AFunc: THttpHandlerFunc);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  { Middleware chain — applies middlewares in order }
  TMiddlewareChain = class(TInterfacedObject, IHttpHandler)
  private
    FMiddlewares: array of IHttpMiddleware;
    FHandler: IHttpHandler;
    FBuilt: IHttpHandler;
    FBuildLock: ISpinLock;
    procedure Build;
  public
    constructor Create(const AHandler: IHttpHandler);
    destructor Destroy; override;
    procedure Use(const AMiddleware: IHttpMiddleware);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  { Helper: create middleware from a function }
  TFuncMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FWrapFunc: TMiddlewareWrapFunc;
  public
    constructor Create(const AWrapFunc: TMiddlewareWrapFunc);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

{ Factory functions }
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler; overload;
function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler; overload;
function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler; overload;
function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;

{** @desc Conditional middleware wrapper. Applies AMiddleware only when
   APredicate returns True for the request. If the predicate returns False,
   the request passes through to the next handler unmodified.

   Example: skip auth for health checks
     WhenMiddleware(
       function(const AReq: IHttpRequest): Boolean
       begin
         Result := AReq.Path <> '/healthz';
       end,
       AuthMiddleware
     ) }
function WhenMiddleware(
  const APredicate: TRequestPredicate;
  const AMiddleware: IHttpMiddleware): IHttpMiddleware;

{** @desc Async middleware: dispatches handler execution to a thread pool.
   Each request is submitted to APool, freeing the acceptor thread.
   The handler runs on a pool thread and writes the response directly.

   Example:
     Server.Use(AsyncMiddleware(MyThreadPool)); }
function AsyncMiddleware(const APool: IThreadPool): IHttpMiddleware;

implementation

uses
  nextpas.core.base.utils;

{ THttpRequestWrapper }

constructor THttpRequestWrapper.Create(const AInner: IHttpRequest);
begin
  inherited Create;
  FInner := AInner;
end;

function THttpRequestWrapper.GetMethod: THttpMethod;
begin
  Result := FInner.GetMethod;
end;

function THttpRequestWrapper.GetUrl: TUrl;
begin
  Result := FInner.GetUrl;
end;

function THttpRequestWrapper.GetPath: string;
begin
  Result := FInner.GetPath;
end;

function THttpRequestWrapper.GetRawQuery: string;
begin
  Result := FInner.GetRawQuery;
end;

function THttpRequestWrapper.GetVersion: THttpVersion;
begin
  Result := FInner.GetVersion;
end;

function THttpRequestWrapper.GetHeaders: IHttpHeaders;
begin
  Result := FInner.GetHeaders;
end;

function THttpRequestWrapper.GetTrailers: IHttpHeaders;
begin
  Result := FInner.GetTrailers;
end;

function THttpRequestWrapper.GetBody: IReader;
begin
  Result := FInner.GetBody;
end;

function THttpRequestWrapper.GetContentLength: Int64;
begin
  Result := FInner.GetContentLength;
end;

function THttpRequestWrapper.GetRemoteAddr: string;
begin
  Result := FInner.GetRemoteAddr;
end;

function THttpRequestWrapper.GetRemoteIp: string;
begin
  Result := FInner.GetRemoteIp;
end;

function THttpRequestWrapper.PathParam(const AName: string): string;
begin
  Result := FInner.PathParam(AName);
end;

function THttpRequestWrapper.QueryParam(const AName: string): string;
begin
  Result := FInner.QueryParam(AName);
end;

function THttpRequestWrapper.GetRequestOptions: THttpRequestOptions;
var
  LOpts: IHttpRequestWithOptions;
begin
  if Supports(FInner, IHttpRequestWithOptions, LOpts) then
    Exit(LOpts.GetRequestOptions);
  Result := Default(THttpRequestOptions);
end;

procedure THttpRequestWrapper.SetRequestOptions(
  const AOptions: THttpRequestOptions);
var
  LOpts: IHttpRequestWithOptions;
begin
  if Supports(FInner, IHttpRequestWithOptions, LOpts) then
    LOpts.SetRequestOptions(AOptions);
end;

function THttpRequestWrapper.GetContext: IHttpContext;
var
  LCtx: IHttpRequestWithContext;
begin
  if Supports(FInner, IHttpRequestWithContext, LCtx) then
    Exit(LCtx.GetContext);
  Result := nil;
end;

procedure THttpRequestWrapper.SetContext(const ACtx: IHttpContext);
var
  LCtx: IHttpRequestWithContext;
begin
  if Supports(FInner, IHttpRequestWithContext, LCtx) then
    LCtx.SetContext(ACtx);
end;

function THttpRequestWrapper.GetArena: IArena;
var
  LArena: IHttpRequestWithArena;
begin
  if Supports(FInner, IHttpRequestWithArena, LArena) then
    Exit(LArena.GetArena);
  Result := nil;
end;

procedure THttpRequestWrapper.SetArena(const AArena: IArena);
var
  LWith: IHttpRequestWithArena;
begin
  if Supports(FInner, IHttpRequestWithArena, LWith) then
    LWith.SetArena(AArena);
end;

{ TFuncHandler }

constructor TFuncHandler.Create(const AFunc: THttpHandlerFunc);
begin
  inherited Create;
  FFunc := AFunc;
end;

procedure TFuncHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  FFunc(AReq, AW);
end;

{ TMiddlewareChain }

constructor TMiddlewareChain.Create(const AHandler: IHttpHandler);
begin
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'HTTP middleware chain root handler must not be nil');
  inherited Create;
  FHandler := AHandler;
  FBuilt := nil;
  FBuildLock := CreateSpinLock;
end;

destructor TMiddlewareChain.Destroy;
var
  LI: Int32;
begin
  FBuilt := nil;
  FHandler := nil;
  FBuildLock := nil;
  for LI := 0 to High(FMiddlewares) do
    FMiddlewares[LI] := nil;
  SetLength(FMiddlewares, 0);
  inherited Destroy;
end;

procedure TMiddlewareChain.Use(const AMiddleware: IHttpMiddleware);
begin
  if AMiddleware = nil then
    raise EHttpError.Create(hekArgument, 'HTTP middleware must not be nil');
  SetLength(FMiddlewares, Length(FMiddlewares) + 1);
  FMiddlewares[High(FMiddlewares)] := AMiddleware;
  FBuilt := nil; // invalidate cached build
end;

procedure TMiddlewareChain.Build;
var
  LI: Int32;
  LHandler: IHttpHandler;
begin
  LHandler := FHandler;
  // Apply in reverse so first Use'd = outermost
  for LI := High(FMiddlewares) downto 0 do
    LHandler := FMiddlewares[LI].Wrap(LHandler);
  FBuilt := LHandler;
end;

procedure TMiddlewareChain.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  if FBuilt = nil then
  begin
    FBuildLock.Acquire;
    try
      if FBuilt = nil then
        Build;
    finally
      FBuildLock.Release;
    end;
  end;
  FBuilt.ServeHTTP(AReq, AW);
end;

{ TFuncMiddleware }

constructor TFuncMiddleware.Create(const AWrapFunc: TMiddlewareWrapFunc);
begin
  inherited Create;
  FWrapFunc := AWrapFunc;
end;

function TFuncMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := FWrapFunc(ANext);
end;

{ Factory functions }

function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler;
begin
  if not Assigned(AFunc) then
    raise EHttpError.Create(hekArgument, 'HTTP handler callback must not be nil');
  Result := TFuncHandler.Create(AFunc);
end;

function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler;
begin
  if not Assigned(AMethod) then
    raise EHttpError.Create(hekArgument, 'HTTP handler method must not be nil');
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AMethod(AReq, AW);
  end);
end;

function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler;
begin
  if not Assigned(AProc) then
    raise EHttpError.Create(hekArgument, 'HTTP handler procedure must not be nil');
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AProc(AReq, AW);
  end);
end;

function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
begin
  if not Assigned(AWrapFunc) then
    raise EHttpError.Create(hekArgument, 'HTTP middleware callback must not be nil');
  Result := TFuncMiddleware.Create(AWrapFunc);
end;

function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
var
  LChain: TMiddlewareChain;
  LI: Int32;
begin
  LChain := TMiddlewareChain.Create(AHandler);
  try
    for LI := 0 to High(AMiddlewares) do
      LChain.Use(AMiddlewares[LI]);
    LChain.Build;
    Result := LChain;
  except
    LChain.Free;
    raise;
  end;
end;

function WhenMiddleware(
  const APredicate: TRequestPredicate;
  const AMiddleware: IHttpMiddleware): IHttpMiddleware;
begin
  if not Assigned(APredicate) then
    raise EHttpError.Create(hekArgument, 'HTTP conditional middleware predicate must not be nil');
  if AMiddleware = nil then
    raise EHttpError.Create(hekArgument, 'HTTP conditional middleware must not be nil');
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  var
    LWrapped: IHttpHandler;
  begin
    LWrapped := AMiddleware.Wrap(ANext);
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if APredicate(AReq) then
        LWrapped.ServeHTTP(AReq, AW)
      else
        ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

function AsyncMiddleware(const APool: IThreadPool): IHttpMiddleware;
begin
  if APool = nil then
    raise EHttpError.Create(hekArgument, 'HTTP async middleware thread pool must not be nil');
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      APool.Submit(procedure
      begin
        ANext.ServeHTTP(AReq, AW);
      end);
    end);
  end);
end;

end.
