unit nextpas.core.http.router.group;
{**
 * @desc Route group helper. Provides prefix-based route grouping with
 *       shared middleware, similar to Express.js router.Router() or
 *       Go chi.Router.Group().
 *
 *       Usage:
 *         var LRouter: IHttpRouter;
 *         var LApi: THttpRouterGroup;
 *         LRouter := NewRouter;
 *         LApi := THttpRouterGroup.Create(LRouter, '/api/v1', [AuthMiddleware]);
 *         LApi.Get('/users', ListUsers);      → GET /api/v1/users
 *         LApi.Post('/users', CreateUser);     → POST /api/v1/users
 *         LApi.Get('/users/:id', GetUser);     → GET /api/v1/users/:id
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpRouterGroup = record
  private
    FRouter: IHttpRouter;
    FPrefix: string;
    FMiddlewares: array of IHttpMiddleware;
    function FullPath(const APath: string): string;
  public
    constructor Create(const ARouter: IHttpRouter;
      const APrefix: string;
      const AMiddlewares: array of IHttpMiddleware);
    procedure Get(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Head(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Post(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Put(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Delete(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Patch(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Options(const APath: string; const AHandler: THttpHandlerFunc);
    procedure Handle(const AMethod: THttpMethod; const APath: string;
      const AHandler: THttpHandlerFunc);
    { Create a nested sub-group with additional prefix and middleware }
    function Group(const ASuffix: string;
      const AMiddlewares: array of IHttpMiddleware): THttpRouterGroup;
  end;

implementation

uses
  nextpas.core.http.middleware;

constructor THttpRouterGroup.Create(const ARouter: IHttpRouter;
  const APrefix: string; const AMiddlewares: array of IHttpMiddleware);
var
  LI: Int32;
begin
  FRouter := ARouter;
  FPrefix := APrefix;
  SetLength(FMiddlewares, Length(AMiddlewares));
  for LI := 0 to High(AMiddlewares) do
    FMiddlewares[LI] := AMiddlewares[LI];
end;

function THttpRouterGroup.FullPath(const APath: string): string;
begin
  if APath = '' then
    Result := FPrefix
  else if APath[1] = '/' then
    Result := FPrefix + APath
  else
    Result := FPrefix + '/' + APath;
end;

procedure THttpRouterGroup.Handle(const AMethod: THttpMethod;
  const APath: string; const AHandler: THttpHandlerFunc);
var
  LWrapped: THttpHandlerFunc;
  LChain: IHttpHandler;
  LI: Int32;
begin
  if Length(FMiddlewares) = 0 then
    FRouter.Handle(AMethod, FullPath(APath), AHandler)
  else
  begin
    { Wrap handler with group middleware: outermost first }
    LChain := HandlerFunc(AHandler);
    for LI := High(FMiddlewares) downto 0 do
      LChain := FMiddlewares[LI].Wrap(LChain);
    LWrapped := procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LChain.ServeHTTP(AReq, AW);
    end;
    FRouter.Handle(AMethod, FullPath(APath), LWrapped);
  end;
end;

procedure THttpRouterGroup.Get(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmGet, APath, AHandler);
end;

procedure THttpRouterGroup.Head(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmHead, APath, AHandler);
end;

procedure THttpRouterGroup.Post(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmPost, APath, AHandler);
end;

procedure THttpRouterGroup.Put(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmPut, APath, AHandler);
end;

procedure THttpRouterGroup.Delete(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmDelete, APath, AHandler);
end;

procedure THttpRouterGroup.Patch(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmPatch, APath, AHandler);
end;

procedure THttpRouterGroup.Options(const APath: string; const AHandler: THttpHandlerFunc);
begin
  Handle(hmOptions, APath, AHandler);
end;

function THttpRouterGroup.Group(const ASuffix: string;
  const AMiddlewares: array of IHttpMiddleware): THttpRouterGroup;
var
  LAllMiddlewares: array of IHttpMiddleware;
  LI, LBase: Int32;
begin
  LBase := Length(FMiddlewares);
  SetLength(LAllMiddlewares, LBase + Length(AMiddlewares));
  for LI := 0 to High(FMiddlewares) do
    LAllMiddlewares[LI] := FMiddlewares[LI];
  for LI := 0 to High(AMiddlewares) do
    LAllMiddlewares[LBase + LI] := AMiddlewares[LI];
  Result := THttpRouterGroup.Create(FRouter, FullPath(ASuffix), LAllMiddlewares);
end;

end.
