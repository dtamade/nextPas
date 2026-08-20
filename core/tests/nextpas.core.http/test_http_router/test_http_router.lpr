program test_http_router;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.router.group,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.cors;

var
  T: TTestSuite;
  GHandlerCalled: string;

type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: THttpStatus;
    FHeaders: IHttpHeaders;
    FBody: string;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Headers: IHttpHeaders read GetHeaders;
    property Body: string read FBody;
  end;

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FHeaders := NewHttpHeaders;
  FBody := '';
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
var
  LStr: string;
begin
  if ACount > 0 then
  begin
    SetLength(LStr, ACount);
    Move(ABuf, LStr[1], ACount);
    FBody := FBody + LStr;
  end;
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

procedure TestPathParamDecode;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/mailboxes/:address/messages',
      procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'mailbox-messages';
      end);

    LHandler := LRouter.FindRoute(hmGet,
      '/mailboxes/matrix%40mock.example.com/messages', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('mailbox-messages', GHandlerCalled, 'correct handler');
    Check(Length(LParams) = 1, 'one param');
    CheckEqual('address', LParams[0].Name, 'param name');
    CheckEqual('matrix@mock.example.com', LParams[0].Value,
      'percent-decoded param value');
  finally
    LRouter.Free;
  end;
end;

procedure TestPathParamPlusLiteral;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users/:id',
      procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'user-by-id';
      end);

    { RFC 3986：path 段中 '+' 是字面加号（Gmail 别名邮箱常见），
      区别于 form/query 的空格语义 }
    LHandler := LRouter.FindRoute(hmGet, '/users/a+b', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('user-by-id', GHandlerCalled, 'correct handler');
    CheckEqual('a+b', LParams[0].Value, 'plus preserved in path param');
  finally
    LRouter.Free;
  end;
end;

procedure TestPathParamEncodedSlash;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/files/:path',
      procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'file';
      end);

    { %2F 段内解码为 '/'：先按字面 '/' 拆段，解码发生在段内，
      不触发新的段匹配 }
    LHandler := LRouter.FindRoute(hmGet, '/files/a%2Fb', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('file', GHandlerCalled, 'correct handler');
    CheckEqual('a/b', LParams[0].Value, 'encoded slash decoded in segment');
  finally
    LRouter.Free;
  end;
end;

procedure TestPathParamLenientPercent;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/users/:id',
      procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'user-by-id';
      end);

    { 截断/非法 '%' 序列宽容透传：畸形 URL 匹配字面，不抛异常 }
    LHandler := LRouter.FindRoute(hmGet, '/users/100%', LParams);
    Check(LHandler <> nil, 'handler found (truncated percent)');
    CheckEqual('100%', LParams[0].Value, 'truncated percent passthrough');

    LHandler := LRouter.FindRoute(hmGet, '/users/%zz', LParams);
    Check(LHandler <> nil, 'handler found (invalid hex)');
    CheckEqual('%zz', LParams[0].Value, 'invalid hex passthrough');
  finally
    LRouter.Free;
  end;
end;

procedure TestWildcardDecode;
var
  LRouter: THttpRouter;
  LParams: TRouteParams;
  LHandler: THttpHandlerFunc;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/static/*filepath',
      procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        GHandlerCalled := 'static';
      end);

    LHandler := LRouter.FindRoute(hmGet, '/static/a%20b/c%40d.txt', LParams);
    Check(LHandler <> nil, 'handler found');
    LHandler(nil, nil);
    CheckEqual('static', GHandlerCalled, 'correct handler');
    Check(Length(LParams) = 1, 'one param');
    CheckEqual('filepath', LParams[0].Name, 'param name');
    CheckEqual('a b/c@d.txt', LParams[0].Value, 'wildcard percent-decoded');
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

procedure TestNilHandlerRaises;
var
  LRouter: THttpRouter;
  LHandler: THttpHandlerFunc;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  try
    LHandler := nil;
    LCaught := False;
    try
      LRouter.Handle(hmGet, '/nil', LHandler);
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'nil route handler raises EHttpError');
  finally
    LRouter.Free;
  end;
end;

procedure TestNilMiddlewareRaises;
var
  LRouter: THttpRouter;
  LMiddleware: IHttpMiddleware;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  try
    LMiddleware := nil;
    LCaught := False;
    try
      LRouter.Use(LMiddleware);
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'nil router middleware raises EHttpError');
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

procedure TestHeadFallsBackToGetRoute;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Get('/headable', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      CheckEqual(Int64(Ord(hmHead)), Int64(Ord(AReq.Method)),
        'HEAD fallback preserves request method');
      GHandlerCalled := 'get-headable';
    end);

    LUrl := TUrl.Parse('/headable');
    LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual('get-headable', GHandlerCalled, 'HEAD should use GET route');
  finally
    LRouter.Free;
  end;
end;

procedure TestExplicitHeadRouteWinsOverGetFallback;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
begin
  ResetState;
  LRouter := THttpRouter.Create;
  try
    LRouter.Get('/headable', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'get-headable';
    end);
    LRouter.Head('/headable', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'head-headable';
    end);

    LUrl := TUrl.Parse('/headable');
    LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual('head-headable', GHandlerCalled,
      'explicit HEAD route should win over GET fallback');
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
  LMock: TMockResponseWriter;
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
    LMock := TMockResponseWriter.Create;
    LWriter := LMock;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(405), Int64(LWriter.GetStatus), '405 status');
    LAllow := LWriter.GetHeaders.Get('allow');
    Check(Pos('GET', LAllow) > 0, '405 Allow contains GET');
    Check(Pos('HEAD', LAllow) > 0, '405 Allow contains implicit HEAD');
    Check(Pos('POST', LAllow) > 0, '405 Allow contains POST');
    { RFC 7807 Problem Details body from HttpWriteErrorResponse }
    CheckEqual('application/problem+json',
      LWriter.GetHeaders.Get('content-type'), '405 content-type');
    Check(Pos('"title":"method_not_allowed"', LMock.Body) > 0,
      '405 has problem title code');
    Check(Pos('"status":405', LMock.Body) > 0, '405 body carries status');
  finally
    LWriter := nil;
    LReq := nil;
    LRouter.Free;
  end;
end;

procedure Test404ReturnsJsonError;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
  LMock: TMockResponseWriter;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LUrl := TUrl.Parse('/not-exists');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LMock := TMockResponseWriter.Create;
    LWriter := LMock;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(404), Int64(LWriter.GetStatus), '404 status');
    CheckEqual('application/problem+json',
      LWriter.GetHeaders.Get('content-type'), '404 content-type');
    Check(Pos('"title":"not_found"', LMock.Body) > 0,
      '404 has problem title code');
    Check(Pos('"status":404', LMock.Body) > 0, '404 body carries status');
  finally
    LWriter := nil;
    LReq := nil;
    LRouter.Free;
  end;
end;

{ Middleware runs on unmatched routes (global request chain): 404/405
  responses get the same middleware treatment as matched routes, while
  status, Allow header and problem body are preserved. }

procedure TestMiddlewareRunsOnNotFound;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
  LMock: TMockResponseWriter;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LRouter.Use(MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
    begin
      Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        AW.Headers.SetHeader('x-mw', 'ran');
        ANext.ServeHTTP(AReq, AW);
      end);
    end));
    LUrl := TUrl.Parse('/not-exists');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LMock := TMockResponseWriter.Create;
    LWriter := LMock;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(404), Int64(LWriter.GetStatus), '404 status through middleware');
    CheckEqual('ran', LWriter.GetHeaders.Get('x-mw'),
      'middleware ran on not-found response');
    Check(Pos('"title":"not_found"', LMock.Body) > 0,
      '404 problem body preserved through middleware');
  finally
    LWriter := nil;
    LReq := nil;
    LRouter.Free;
  end;
end;

procedure TestMiddlewareRunsOnMethodNotAllowed;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
  LMock: TMockResponseWriter;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LRouter.Use(MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
    begin
      Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        AW.Headers.SetHeader('x-mw', 'ran');
        ANext.ServeHTTP(AReq, AW);
      end);
    end));
    LUrl := TUrl.Parse('/resource');
    LReq := THttpRequest.Create(hmPost, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LMock := TMockResponseWriter.Create;
    LWriter := LMock;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(405), Int64(LWriter.GetStatus), '405 status through middleware');
    CheckEqual('ran', LWriter.GetHeaders.Get('x-mw'),
      'middleware ran on method-not-allowed response');
    Check(Pos('GET', LWriter.GetHeaders.Get('allow')) > 0,
      'Allow header preserved through middleware');
    Check(Pos('"title":"method_not_allowed"', LMock.Body) > 0,
      '405 problem body preserved through middleware');
  finally
    LWriter := nil;
    LReq := nil;
    LRouter.Free;
  end;
end;

{ CORS preflight to a route with no OPTIONS handler: the router would answer
  405, but the CORS middleware short-circuits the preflight first (OPTIONS +
  Origin + Access-Control-Request-Method) so the browser sees a 204. }
procedure TestCorsPreflightInterceptsUnmatchedOptions;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
  LOpts: TCorsOptions;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Handle(hmGet, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
    end);
    LOpts := TCorsOptions.Default;
    LRouter.Use(CorsMiddleware(LOpts));
    LUrl := TUrl.Parse('/resource');
    LReq := THttpRequest.Create(hmOptions, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LReq.Headers.SetHeader('Origin', 'https://example.test');
    LReq.Headers.SetHeader('Access-Control-Request-Method', 'GET');
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(204), Int64(LWriter.GetStatus),
      'preflight to GET-only route gets 204 from CORS middleware');
    CheckEqual('*', LWriter.GetHeaders.Get('Access-Control-Allow-Origin'),
      'CORS headers present on unmatched-route preflight');
  finally
    LWriter := nil;
    LReq := nil;
    LRouter.Free;
  end;
end;

{ Chain order on unmatched routes matches matched routes: the first
  registered middleware is outermost. Sequence: a1 b1 [404 responder]
  b2 a2. }
procedure TestMiddlewareOrderingOnUnmatched;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LWriter: IHttpResponseWriter;
  LSeq: string;
begin
  LSeq := '';
  LRouter := THttpRouter.Create;
  try
    LRouter.Use(MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
    begin
      Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        LSeq := LSeq + 'a1';
        ANext.ServeHTTP(AReq, AW);
        LSeq := LSeq + 'a2';
      end);
    end));
    LRouter.Use(MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
    begin
      Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        LSeq := LSeq + 'b1';
        ANext.ServeHTTP(AReq, AW);
        LSeq := LSeq + 'b2';
      end);
    end));
    LUrl := TUrl.Parse('/missing');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual(Int64(404), Int64(LWriter.GetStatus), '404 status');
    CheckEqual('a1b1b2a2', LSeq, 'middleware order preserved on not-found');
  finally
    LWriter := nil;
    LReq := nil;
    LRouter.Free;
  end;
end;

{ RouterGroup tests }

procedure TestRouterGroupPrefix;
var
  LRouter: IHttpRouter;
  LGroup: THttpRouterGroup;
  LReq: IHttpRequest;
  LWriter: IHttpResponseWriter;
begin
  LRouter := NewRouter;
  LGroup := THttpRouterGroup.Create(LRouter, '/api/v1', []);
  try
    LGroup.Get('/users', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'users';
    end);
    GHandlerCalled := '';
    LReq := THttpRequest.Create(hmGet, TUrl.ParseRequestTarget('/api/v1/users'),
      hvHttp11, NewHttpHeaders, nil, 0);
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual('users', GHandlerCalled, 'group route matched at full path');
  finally
    LWriter := nil;
    LReq := nil;
    LGroup := Default(THttpRouterGroup);
    LRouter := nil;
  end;
end;

procedure TestRouterGroupWithMiddleware;
var
  LRouter: IHttpRouter;
  LGroup: THttpRouterGroup;
  LMwApplied: Boolean;
  LReq: IHttpRequest;
  LWriter: IHttpResponseWriter;
begin
  LRouter := NewRouter;
  LMwApplied := False;
  LGroup := THttpRouterGroup.Create(LRouter, '/api', [
    MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
    begin
      Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      begin
        LMwApplied := True;
        ANext.ServeHTTP(AReq, AW);
      end);
    end)
  ]);
  try
    LGroup.Get('/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'test';
    end);
    GHandlerCalled := '';
    LReq := THttpRequest.Create(hmGet, TUrl.ParseRequestTarget('/api/test'),
      hvHttp11, NewHttpHeaders, nil, 0);
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    Check(LMwApplied, 'group middleware was applied');
    CheckEqual('test', GHandlerCalled, 'handler was called');
  finally
    LWriter := nil;
    LReq := nil;
    LGroup := Default(THttpRouterGroup);
    LRouter := nil;
  end;
end;

procedure TestRouterGroupNested;
var
  LRouter: IHttpRouter;
  LApi: THttpRouterGroup;
  LV1: THttpRouterGroup;
  LReq: IHttpRequest;
  LWriter: IHttpResponseWriter;
begin
  LRouter := NewRouter;
  LApi := THttpRouterGroup.Create(LRouter, '/api', []);
  LV1 := LApi.Group('/v1', []);
  try
    LV1.Get('/items', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := 'items';
    end);
    GHandlerCalled := '';
    LReq := THttpRequest.Create(hmGet, TUrl.ParseRequestTarget('/api/v1/items'),
      hvHttp11, NewHttpHeaders, nil, 0);
    LWriter := TMockResponseWriter.Create;
    LRouter.ServeHTTP(LReq, LWriter);
    CheckEqual('items', GHandlerCalled, 'nested group route matched');
  finally
    LWriter := nil;
    LReq := nil;
    LV1 := Default(THttpRouterGroup);
    LApi := Default(THttpRouterGroup);
    LRouter := nil;
  end;
end;

procedure TestServeHTTPTrailingSlashNormalized;
var
  LRouter: IHttpRouter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LRouter := NewRouter;
  LRouter.Get('/api/users', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    GHandlerCalled := 'users';
  end);

  { Trailing slash should be normalized away }
  GHandlerCalled := '';
  LW := TMockResponseWriter.Create;
  LReq := THttpRequest.Create(hmGet, TUrl.ParseRequestTarget('/api/users/'),
    hvHttp11, NewHttpHeaders, nil, 0);
  LRouter.ServeHTTP(LReq, LW);
  CheckEqual('users', GHandlerCalled, '/api/users/ matches /api/users');

  { Multiple trailing slashes should also be normalized }
  GHandlerCalled := '';
  LW := TMockResponseWriter.Create;
  LReq := THttpRequest.Create(hmGet, TUrl.ParseRequestTarget('/api/users//'),
    hvHttp11, NewHttpHeaders, nil, 0);
  LRouter.ServeHTTP(LReq, LW);
  CheckEqual('users', GHandlerCalled, '/api/users// matches /api/users');

  { Root path stays as / }
  LRouter := NewRouter;
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    GHandlerCalled := 'root';
  end);
  GHandlerCalled := '';
  LW := TMockResponseWriter.Create;
  LReq := THttpRequest.Create(hmGet, TUrl.ParseRequestTarget('/'),
    hvHttp11, NewHttpHeaders, nil, 0);
  LRouter.ServeHTTP(LReq, LW);
  CheckEqual('root', GHandlerCalled, '/ matches root');
end;

{ MatchPathPattern 语义矩阵（与 router 消费语义同源：':xxx' 单段非空、
  '*xxx' 剩余可空、段数规则、折叠/空串边角） }
procedure TestMatchPathPattern;
begin
  { 静态精确 }
  Check(MatchPathPattern('/users', '/users'), 'static exact');
  Check(not MatchPathPattern('/users', '/posts'), 'static different');
  Check(not MatchPathPattern('/users', '/users/1'), 'static vs longer path');
  Check(not MatchPathPattern('/users/1', '/users'), 'longer pattern vs path');
  { 静态逐字（非前缀）}
  Check(not MatchPathPattern('/users2', '/users'), 'static literal not prefix');
  Check(not MatchPathPattern('/users', '/users2'), 'path longer than static');

  { ':xxx' 单段通配 }
  Check(MatchPathPattern('/users/:id', '/users/42'), 'param single');
  Check(MatchPathPattern('/users/:id/posts/:pid', '/users/42/posts/9'), 'param multi');
  Check(MatchPathPattern('/v1/:model/chat/completions', '/v1/gpt-4.5-turbo/chat/completions'),
    'param dotted value');
  Check(MatchPathPattern('/x/:p', '/x/a-b_c.d'), 'param arbitrary chars');
  Check(not MatchPathPattern('/users/:id', '/users/42/posts'), 'param extra path seg');
  Check(not MatchPathPattern('/users/:id/posts', '/users/42'), 'param missing path seg');
  Check(not MatchPathPattern('/users/:id', '/users'), 'param no segment');

  { '*xxx' 剩余通配（可空）}
  Check(MatchPathPattern('/*', '/a/b/c'), 'wildcard rest');
  Check(MatchPathPattern('/*', '/'), 'wildcard empty rest');
  Check(MatchPathPattern('/files/*rest', '/files/a/b'), 'named wildcard rest');
  Check(MatchPathPattern('/files/*rest', '/files/'), 'named wildcard empty rest');
  Check(MatchPathPattern('/files/*rest', '/files'), 'named wildcard no rest segment');
  Check(not MatchPathPattern('/a/*', '/b/c'), 'wildcard static mismatch');
  { '*' 后段无意义（与 router InsertRoute Break 同源）}
  Check(MatchPathPattern('/a/*x/b', '/a/z/b'), 'wildcard not last still matches rest');

  { 段数 / 折叠 / 首尾斜杠 }
  Check(MatchPathPattern('/a/b', '//a//b'), 'collapse inner slashes');
  Check(MatchPathPattern('/a/b/', '/a/b'), 'trailing slash pattern');
  Check(MatchPathPattern('/a/b', '/a/b/'), 'trailing slash path');
  Check(MatchPathPattern('/', '/'), 'root matches root');
  Check(not MatchPathPattern('/a', '/a/b/c'), 'segment count larger path');
  Check(not MatchPathPattern('/a/b/c', '/a'), 'segment count larger pattern');

  { 空串边角 }
  Check(MatchPathPattern('', ''), 'empty matches empty');
  Check(not MatchPathPattern('', '/'), 'empty pattern vs root');
  Check(not MatchPathPattern('/', ''), 'root pattern vs empty');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.router');
  T.Test('Static route match', @TestStaticRouteMatch);
  T.Test('Static route no match', @TestStaticRouteNoMatch);
  T.Test('Path param single', @TestPathParamSingle);
  T.Test('Path param percent-decode', @TestPathParamDecode);
  T.Test('Path param plus literal', @TestPathParamPlusLiteral);
  T.Test('Path param encoded slash', @TestPathParamEncodedSlash);
  T.Test('Path param lenient percent', @TestPathParamLenientPercent);
  T.Test('Multiple params', @TestMultipleParams);
  T.Test('Wildcard', @TestWildcard);
  T.Test('Wildcard percent-decode', @TestWildcardDecode);
  T.Test('Method dispatch', @TestMethodDispatch);
  T.Test('Convenience methods', @TestConvenienceMethods);
  T.Test('Static wins over param', @TestStaticWinsOverParam);
  T.Test('Trailing slash', @TestTrailingSlash);
  T.Test('Duplicate route raises', @TestDuplicateRouteRaises);
  T.Test('Empty pattern raises', @TestEmptyPatternRaises);
  T.Test('Nil handler raises', @TestNilHandlerRaises);
  T.Test('Nil middleware raises', @TestNilMiddlewareRaises);
  T.Test('Wildcard must be last', @TestWildcardMustBeLast);
  T.Test('Deep static route', @TestDeepStaticRoute);
  T.Test('100 static routes', @Test100StaticRoutes);
  T.Test('100 param routes', @Test100ParamRoutes);
  T.Test('Mixed priority static wins', @TestMixedPriorityStaticWins);
  T.Test('Root route', @TestRootRoute);
  T.Test('Double slash no match', @TestDoubleSlashNoMatch);
  T.Test('Multiple wildcards raises', @TestMultipleWildcardsRaises);
  T.Test('ServeHTTP integration', @TestServeHTTPIntegration);
  T.Test('HEAD falls back to GET route', @TestHeadFallsBackToGetRoute);
  T.Test('explicit HEAD route wins over GET fallback',
    @TestExplicitHeadRouteWinsOverGetFallback);
  T.Test('405 lists all methods', @Test405ListsAllMethods);
  T.Test('404 returns JSON error', @Test404ReturnsJsonError);
  T.Test('middleware runs on not-found', @TestMiddlewareRunsOnNotFound);
  T.Test('middleware runs on method-not-allowed', @TestMiddlewareRunsOnMethodNotAllowed);
  T.Test('CORS preflight intercepts unmatched OPTIONS', @TestCorsPreflightInterceptsUnmatchedOptions);
  T.Test('middleware order preserved on not-found', @TestMiddlewareOrderingOnUnmatched);
  { RouterGroup }
  T.Test('Group: prefix applied', @TestRouterGroupPrefix);
  T.Test('Group: middleware applied', @TestRouterGroupWithMiddleware);
  T.Test('Group: nested prefix', @TestRouterGroupNested);
  T.Test('ServeHTTP trailing slash normalized', @TestServeHTTPTrailingSlashNormalized);
  T.Test('MatchPathPattern matrix', @TestMatchPathPattern);
  if not T.Run then Halt(1);
end.
