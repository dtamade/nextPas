program test_http_router;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router;

var
  T: TTestRunner;
  GHandlerCalled: string;

type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: THttpStatus;
    FHeaders: IHttpHeaders;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Headers: IHttpHeaders read GetHeaders;
  end;

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FHeaders := NewHttpHeaders;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TMockResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TMockResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

procedure TMockResponseWriter.Flush;
begin
end;

function IntToStr(const V: Int32): string;
begin
  Str(V, Result);
end;

procedure ResetState;
begin
  GHandlerCalled := '';
end;

{ --- Test procedures --- }

procedure TestStaticRouteMatch;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'users';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/users', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('users', GHandlerCalled, 'correct handler');
    Check(Length(LParams) = 0, 'no params');
  finally
    LRouter.Free;
  end;
end;

procedure TestStaticRouteNoMatch;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);

    LHandler := LRouter.FindRoute(hmGet, '/posts', LParams);
    Check(LHandler = nil, 'no handler for unmatched path');
  finally
    LRouter.Free;
  end;
end;

procedure TestPathParamSingle;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'user-by-id';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/users/42', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('user-by-id', GHandlerCalled, 'correct handler');
    Check(Length(LParams) = 1, 'one param');
    CheckEqual('id', LParams[0].Name, 'param name');
    CheckEqual('42', LParams[0].Value, 'param value');
  finally
    LRouter.Free;
  end;
end;

procedure TestMultipleParams;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users/:uid/posts/:pid', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'user-post';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/users/7/posts/99', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('user-post', GHandlerCalled, 'correct handler');
    Check(Length(LParams) = 2, 'two params');
    CheckEqual('uid', LParams[0].Name, 'param 0 name');
    CheckEqual('7', LParams[0].Value, 'param 0 value');
    CheckEqual('pid', LParams[1].Name, 'param 1 name');
    CheckEqual('99', LParams[1].Value, 'param 1 value');
  finally
    LRouter.Free;
  end;
end;

procedure TestWildcard;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/static/*filepath', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'static';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/static/css/style.css', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('static', GHandlerCalled, 'correct handler');
    Check(Length(LParams) = 1, 'one param');
    CheckEqual('filepath', LParams[0].Name, 'param name');
    CheckEqual('css/style.css', LParams[0].Value, 'param value');
  finally
    LRouter.Free;
  end;
end;

procedure TestMethodDispatch;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/items', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'get-items';
    end);
    LRouter.Handle(hmPost, '/items', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'post-items';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/items', LParams);
    Check(LHandler <> nil, 'GET handler found');
    LHandler(nil, nil);
    CheckEqual('get-items', GHandlerCalled, 'GET handler');

    ResetState;
    LHandler := LRouter.FindRoute(hmPost, '/items', LParams);
    Check(LHandler <> nil, 'POST handler found');
    LHandler(nil, nil);
    CheckEqual('post-items', GHandlerCalled, 'POST handler');

    { Different method with no route }
    LHandler := LRouter.FindRoute(hmPut, '/items', LParams);
    Check(LHandler = nil, 'PUT has no handler');
  finally
    LRouter.Free;
  end;
end;

procedure TestConvenienceMethods;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Get('/a', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'get-a';
    end);
    LRouter.Post('/b', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'post-b';
    end);
    LRouter.Put('/c', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'put-c';
    end);
    LRouter.Delete('/d', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'delete-d';
    end);
    LRouter.Head('/e', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'head-e';
    end);
    LRouter.Patch('/f', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'patch-f';
    end);
    LRouter.Options('/g', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'options-g';
    end);
    LRouter.Connect('/h', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'connect-h';
    end);
    LRouter.Trace('/i', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'trace-i';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/a', LParams);
    Check(LHandler <> nil, 'Get convenience');
    LHandler(nil, nil);
    CheckEqual('get-a', GHandlerCalled, 'Get handler');

    LHandler := LRouter.FindRoute(hmPost, '/b', LParams);
    Check(LHandler <> nil, 'Post convenience');
    LHandler(nil, nil);
    CheckEqual('post-b', GHandlerCalled, 'Post handler');

    LHandler := LRouter.FindRoute(hmPut, '/c', LParams);
    Check(LHandler <> nil, 'Put convenience');
    LHandler(nil, nil);
    CheckEqual('put-c', GHandlerCalled, 'Put handler');

    LHandler := LRouter.FindRoute(hmDelete, '/d', LParams);
    Check(LHandler <> nil, 'Delete convenience');
    LHandler(nil, nil);
    CheckEqual('delete-d', GHandlerCalled, 'Delete handler');

    LHandler := LRouter.FindRoute(hmHead, '/e', LParams);
    Check(LHandler <> nil, 'Head convenience');
    LHandler(nil, nil);
    CheckEqual('head-e', GHandlerCalled, 'Head handler');

    LHandler := LRouter.FindRoute(hmPatch, '/f', LParams);
    Check(LHandler <> nil, 'Patch convenience');
    LHandler(nil, nil);
    CheckEqual('patch-f', GHandlerCalled, 'Patch handler');

    LHandler := LRouter.FindRoute(hmOptions, '/g', LParams);
    Check(LHandler <> nil, 'Options convenience');
    LHandler(nil, nil);
    CheckEqual('options-g', GHandlerCalled, 'Options handler');

    LHandler := LRouter.FindRoute(hmConnect, '/h', LParams);
    Check(LHandler <> nil, 'Connect convenience');
    LHandler(nil, nil);
    CheckEqual('connect-h', GHandlerCalled, 'Connect handler');

    LHandler := LRouter.FindRoute(hmTrace, '/i', LParams);
    Check(LHandler <> nil, 'Trace convenience');
    LHandler(nil, nil);
    CheckEqual('trace-i', GHandlerCalled, 'Trace handler');
  finally
    LRouter.Free;
  end;
end;

procedure TestStaticWinsOverParam;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'param';
    end);
    LRouter.Handle(hmGet, '/users/new', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'static-new';
    end);

    { Static should win }
    LHandler := LRouter.FindRoute(hmGet, '/users/new', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('static-new', GHandlerCalled, 'static wins over param');

    { Param still works for other values }
    ResetState;
    LHandler := LRouter.FindRoute(hmGet, '/users/123', LParams);
    Check(LHandler <> nil, 'param handler found');
    LHandler(nil, nil);
    CheckEqual('param', GHandlerCalled, 'param handler works');
    CheckEqual('id', LParams[0].Name, 'param name');
    CheckEqual('123', LParams[0].Value, 'param value');
  finally
    LRouter.Free;
  end;
end;

procedure TestTrailingSlash;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'no-slash';
    end);
    LRouter.Handle(hmGet, '/users/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'with-slash';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/users', LParams);
    Check(LHandler <> nil, 'no-slash handler');
    LHandler(nil, nil);
    CheckEqual('no-slash', GHandlerCalled, 'no trailing slash');

    ResetState;
    LHandler := LRouter.FindRoute(hmGet, '/users/', LParams);
    Check(LHandler <> nil, 'with-slash handler');
    LHandler(nil, nil);
    CheckEqual('with-slash', GHandlerCalled, 'with trailing slash');
  finally
    LRouter.Free;
  end;
end;

procedure TestDuplicateRouteRaises;
var
  LRouter: THttpRouter;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/dup', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);

    LCaught := False;
    try
      LRouter.Handle(hmGet, '/dup', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
      end);
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'duplicate route raises EHttpError');
  finally
    LRouter.Free;
  end;
end;

procedure TestEmptyPatternRaises;
var
  LRouter: THttpRouter;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  try
    LCaught := False;
    try
      LRouter.Handle(hmGet, '', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
      end);
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'empty pattern raises EHttpError');
  finally
    LRouter.Free;
  end;
end;

procedure TestWildcardMustBeLast;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  { Wildcard captures everything after it — no further segments matter }
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/files/*path', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'files';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/files/a/b/c/d.txt', LParams);
    Check(LHandler <> nil, 'wildcard matches deep path');
    LHandler(nil, nil);
    CheckEqual('files', GHandlerCalled, 'wildcard handler');
    CheckEqual('path', LParams[0].Name, 'wildcard param name');
    CheckEqual('a/b/c/d.txt', LParams[0].Value, 'wildcard captures all');
  finally
    LRouter.Free;
  end;
end;

procedure TestDeepStaticRoute;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/api/v1/users/list', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'deep';
    end);

    LHandler := LRouter.FindRoute(hmGet, '/api/v1/users/list', LParams);
    Check(LHandler <> nil, 'deep static route found');
    LHandler(nil, nil);
    CheckEqual('deep', GHandlerCalled, 'deep handler');
    Check(Length(LParams) = 0, 'no params');

    { Partial path should not match }
    LHandler := LRouter.FindRoute(hmGet, '/api/v1/users', LParams);
    Check(LHandler = nil, 'partial path no match');
  finally
    LRouter.Free;
  end;
end;

procedure Test100StaticRoutes;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
  LI: Int32;
  LPath: string;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    for LI := 1 to 100 do
    begin
      LPath := '/route' + Copy('000', 1, 3 - Length(IntToStr(LI))) + IntToStr(LI);
      LRouter.Handle(hmGet, LPath, procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'found';
      end);
    end;
    LHandler := LRouter.FindRoute(hmGet, '/route099', LParams);
    Check(LHandler <> nil, '100 static: /route099 found');
    LHandler(nil, nil);
    CheckEqual('found', GHandlerCalled, '100 static: correct handler');
  finally
    LRouter.Free;
  end;
end;

procedure Test100ParamRoutes;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
  LI: Int32;
  LPrefix: string;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    for LI := 1 to 100 do
    begin
      LPrefix := '/prefix' + IntToStr(LI) + '/:id';
      LRouter.Handle(hmGet, LPrefix, procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'param-hit';
      end);
    end;
    LHandler := LRouter.FindRoute(hmGet, '/prefix42/abc', LParams);
    Check(LHandler <> nil, '100 param: /prefix42/:id found');
    LHandler(nil, nil);
    CheckEqual('param-hit', GHandlerCalled, '100 param: correct handler');
    Check(Length(LParams) = 1, '100 param: one param');
    CheckEqual('id', LParams[0].Name, '100 param: param name');
    CheckEqual('abc', LParams[0].Value, '100 param: param value');
  finally
    LRouter.Free;
  end;
end;

procedure TestMixedPriorityStaticWins;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/api/:version/:resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'param';
    end);
    LRouter.Handle(hmGet, '/api/v1/users', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'static';
    end);
    LHandler := LRouter.FindRoute(hmGet, '/api/v1/users', LParams);
    Check(LHandler <> nil, 'mixed priority: handler found');
    LHandler(nil, nil);
    CheckEqual('static', GHandlerCalled, 'mixed priority: static wins');
  finally
    LRouter.Free;
  end;
end;

procedure TestRootRoute;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'root';
    end);
    LHandler := LRouter.FindRoute(hmGet, '/', LParams);
    Check(LHandler <> nil, 'root route found');
    LHandler(nil, nil);
    CheckEqual('root', GHandlerCalled, 'root handler');
  finally
    LRouter.Free;
  end;
end;

procedure TestDoubleSlashNoMatch;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users/:id/posts', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    { Double slash should not match the param route }
    LHandler := LRouter.FindRoute(hmGet, '/users//posts', LParams);
    Check(LHandler = nil, 'double slash does not match param route');
  finally
    LRouter.Free;
  end;
end;

procedure TestMultipleWildcardsRaises;
var
  LRouter: THttpRouter;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/files/*path', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LCaught := False;
    try
      LRouter.Handle(hmGet, '/files/*other', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
      end);
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'duplicate wildcard at same level raises');
  finally
    LRouter.Free;
  end;
end;

procedure TestServeHTTPIntegration;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LCalled: Boolean;
begin
  LCalled := False;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/api/items/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LCalled := True;
      GHandlerCalled := AReq.PathParam('id');
    end);
    LUrl := TUrl.Parse('/api/items/77');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LRouter.ServeHTTP(LReq, nil);
    Check(LCalled, 'ServeHTTP: handler was called');
    CheckEqual('77', GHandlerCalled, 'ServeHTTP: path param correct');
  finally
    LRouter.Free;
  end;
end;

procedure Test405ListsAllMethods;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
  LAllow: string;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LRouter.Handle(hmPost, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LUrl := TUrl.Parse('/resource');
    LReq := THttpRequest.Create(hmPut, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    { Use a mock response writer that captures headers }
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(405), Int64(LWriter.GetStatus), '405 status');
    LAllow := LWriter.GetHeaders.Get('allow');
    Check(Pos('GET', LAllow) > 0, '405 Allow contains GET');
    Check(Pos('POST', LAllow) > 0, '405 Allow contains POST');
  finally
    LRouter.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.http.router');
  T.Run('Static route match', @TestStaticRouteMatch);
  T.Run('Static route no match', @TestStaticRouteNoMatch);
  T.Run('Path param single', @TestPathParamSingle);
  T.Run('Multiple params', @TestMultipleParams);
  T.Run('Wildcard', @TestWildcard);
  T.Run('Method dispatch', @TestMethodDispatch);
  T.Run('Convenience methods', @TestConvenienceMethods);
  T.Run('Static wins over param', @TestStaticWinsOverParam);
  T.Run('Trailing slash', @TestTrailingSlash);
  T.Run('Duplicate route raises', @TestDuplicateRouteRaises);
  T.Run('Empty pattern raises', @TestEmptyPatternRaises);
  T.Run('Wildcard must be last', @TestWildcardMustBeLast);
  T.Run('Deep static route', @TestDeepStaticRoute);
  T.Run('100 static routes', @Test100StaticRoutes);
  T.Run('100 param routes', @Test100ParamRoutes);
  T.Run('Mixed priority static wins', @TestMixedPriorityStaticWins);
  T.Run('Root route', @TestRootRoute);
  T.Run('Double slash no match', @TestDoubleSlashNoMatch);
  T.Run('Multiple wildcards raises', @TestMultipleWildcardsRaises);
  T.Run('ServeHTTP integration', @TestServeHTTPIntegration);
  T.Run('405 lists all methods', @Test405ListsAllMethods);
  T.Summary;
end.
