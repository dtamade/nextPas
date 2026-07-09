unit nextpas.core.http.middleware;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.sync.intf,
  nextpas.core.sync.spinlock;

type
  { Function type for creating middleware from a closure }
  TMiddlewareWrapFunc = reference to function(const ANext: IHttpHandler): IHttpHandler;

  { Predicate for conditional middleware — returns True to apply, False to skip }
  TRequestPredicate = reference to function(const AReq: IHttpRequest): Boolean;

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

implementation

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
    raise EHttpError.Create('HTTP middleware chain root handler must not be nil');
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
    raise EHttpError.Create('HTTP middleware must not be nil');
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
    raise EHttpError.Create('HTTP handler callback must not be nil');
  Result := TFuncHandler.Create(AFunc);
end;

function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler;
begin
  if not Assigned(AMethod) then
    raise EHttpError.Create('HTTP handler method must not be nil');
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AMethod(AReq, AW);
  end);
end;

function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler;
begin
  if not Assigned(AProc) then
    raise EHttpError.Create('HTTP handler procedure must not be nil');
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AProc(AReq, AW);
  end);
end;

function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
begin
  if not Assigned(AWrapFunc) then
    raise EHttpError.Create('HTTP middleware callback must not be nil');
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
    raise EHttpError.Create('HTTP conditional middleware predicate must not be nil');
  if AMiddleware = nil then
    raise EHttpError.Create('HTTP conditional middleware must not be nil');
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

end.
