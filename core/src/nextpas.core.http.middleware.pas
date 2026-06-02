unit nextpas.core.http.middleware;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  { Function type for creating middleware from a closure }
  TMiddlewareWrapFunc = reference to function(const ANext: IHttpHandler): IHttpHandler;

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
  inherited Create;
  FHandler := AHandler;
  FBuilt := nil;
end;

destructor TMiddlewareChain.Destroy;
var
  LI: Int32;
begin
  FBuilt := nil;
  FHandler := nil;
  for LI := 0 to High(FMiddlewares) do
    FMiddlewares[LI] := nil;
  SetLength(FMiddlewares, 0);
  inherited Destroy;
end;

procedure TMiddlewareChain.Use(const AMiddleware: IHttpMiddleware);
begin
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
    Build;
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
  Result := TFuncHandler.Create(AFunc);
end;

function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AMethod(AReq, AW);
  end);
end;

function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AProc(AReq, AW);
  end);
end;

function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
begin
  Result := TFuncMiddleware.Create(AWrapFunc);
end;

function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
var
  LChain: TMiddlewareChain;
  LI: Int32;
begin
  LChain := TMiddlewareChain.Create(AHandler);
  for LI := 0 to High(AMiddlewares) do
    LChain.Use(AMiddlewares[LI]);
  LChain.Build;
  Result := LChain;
end;

end.
