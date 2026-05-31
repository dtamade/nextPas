program test_http_router;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router;

var
  T: TTestRunner;
  GHandlerCalled: string;

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
  T.Summary;
end.
