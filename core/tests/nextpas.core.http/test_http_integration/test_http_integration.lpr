program test_http_integration;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.middleware,
  nextpas.core.http.url,
  nextpas.core.http.impl.h1.writer;

type
  { IWriter mock that captures output into a string buffer }
  TBytesWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Output: string;
  end;

  { Middleware that adds a header before calling next }
  TAddHeaderHandler = class(TInterfacedObject, IHttpHandler)
  private
    FNext: IHttpHandler;
    FName, FValue: string;
  public
    constructor Create(const ANext: IHttpHandler; const AName, AValue: string);
    destructor Destroy; override;
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TAddHeaderMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FName, FValue: string;
  public
    constructor Create(const AName, AValue: string);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  { Middleware that short-circuits — does NOT call next }
  TBlockMiddlewareHandler = class(TInterfacedObject, IHttpHandler)
  private
    FStatus: THttpStatus;
    FBody: string;
  public
    constructor Create(const AStatus: THttpStatus; const ABody: string);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TBlockMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FStatus: THttpStatus;
    FBody: string;
  public
    constructor Create(const AStatus: THttpStatus; const ABody: string);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  { Middleware that records execution order }
  TOrderMiddlewareHandler = class(TInterfacedObject, IHttpHandler)
  private
    FNext: IHttpHandler;
    FTag: string;
  public
    constructor Create(const ANext: IHttpHandler; const ATag: string);
    destructor Destroy; override;
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TOrderMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FTag: string;
  public
    constructor Create(const ATag: string);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

var
  T: TTestRunner;
  GLog: string;
  GHandlerCalled: Boolean;

{ TBytesWriter }

function TBytesWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  if ACount = 0 then Exit(0);
  LOld := SizeUInt(Length(FBuf));
  SetLength(FBuf, LOld + ACount);
  Move(ABuf, FBuf[LOld + 1], ACount);
  Result := ACount;
end;

function TBytesWriter.Output: string;
begin
  Result := FBuf;
end;

{ TAddHeaderHandler }

constructor TAddHeaderHandler.Create(const ANext: IHttpHandler; const AName, AValue: string);
begin
  inherited Create;
  FNext := ANext;
  FName := AName;
  FValue := AValue;
end;

destructor TAddHeaderHandler.Destroy;
begin
  FNext := nil;
  inherited Destroy;
end;

procedure TAddHeaderHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  AW.GetHeaders.SetHeader(FName, FValue);
  FNext.ServeHTTP(AReq, AW);
end;

{ TAddHeaderMiddleware }

constructor TAddHeaderMiddleware.Create(const AName, AValue: string);
begin
  inherited Create;
  FName := AName;
  FValue := AValue;
end;

function TAddHeaderMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := TAddHeaderHandler.Create(ANext, FName, FValue);
end;

{ TBlockMiddlewareHandler }

constructor TBlockMiddlewareHandler.Create(const AStatus: THttpStatus; const ABody: string);
begin
  inherited Create;
  FStatus := AStatus;
  FBody := ABody;
end;

procedure TBlockMiddlewareHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GLog := GLog + 'blocked;';
  AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(FBody))));
  AW.WriteHeader(FStatus);
  if FBody <> '' then
    AW.Write(FBody[1], SizeUInt(Length(FBody)));
end;

{ TBlockMiddleware }

constructor TBlockMiddleware.Create(const AStatus: THttpStatus; const ABody: string);
begin
  inherited Create;
  FStatus := AStatus;
  FBody := ABody;
end;

function TBlockMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := TBlockMiddlewareHandler.Create(FStatus, FBody);
end;

{ TOrderMiddlewareHandler }

constructor TOrderMiddlewareHandler.Create(const ANext: IHttpHandler; const ATag: string);
begin
  inherited Create;
  FNext := ANext;
  FTag := ATag;
end;

destructor TOrderMiddlewareHandler.Destroy;
begin
  FNext := nil;
  inherited Destroy;
end;

procedure TOrderMiddlewareHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GLog := GLog + FTag + '>';
  FNext.ServeHTTP(AReq, AW);
  GLog := GLog + '<' + FTag;
end;

{ TOrderMiddleware }

constructor TOrderMiddleware.Create(const ATag: string);
begin
  inherited Create;
  FTag := ATag;
end;

function TOrderMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin
  Result := TOrderMiddlewareHandler.Create(ANext, FTag);
end;

{ ===== ServeHTTP + PathParam integration ===== }

procedure TestServeHTTPStaticRoute;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
begin
  GHandlerCalled := False;
  LRouter := THttpRouter.Create;
  try
    LRouter.Get('/hello', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var LBody: string;
    begin
      GHandlerCalled := True;
      LBody := 'world';
      AW.GetHeaders.SetHeader('content-length', '5');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], SizeUInt(Length(LBody)));
    end);

    LReq := NewGetRequest('/hello');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    Check(GHandlerCalled, 'handler was called');
    Check(Pos('HTTP/1.1 200 OK', LBuf.Output) > 0, 'status 200 in output');
    Check(Pos('world', LBuf.Output) > 0, 'body in output');
  finally
    LRouter.Free;
  end;
end;

procedure TestServeHTTPWithParam;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
  LGotId: string;
begin
  LRouter := THttpRouter.Create;
  try
    LGotId := '';
    LRouter.Get('/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LGotId := AReq.PathParam('id');
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end);

    LReq := NewGetRequest('/users/42');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    CheckEqual('42', LGotId, 'path param extracted');
    Check(Pos('HTTP/1.1 200', LBuf.Output) > 0, 'status 200 in output');
  finally
    LRouter.Free;
  end;
end;

procedure TestServeHTTPMultipleParams;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
  LGotUid, LGotPid: string;
begin
  LRouter := THttpRouter.Create;
  try
    LGotUid := '';
    LGotPid := '';
    LRouter.Get('/users/:uid/posts/:pid', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LGotUid := AReq.PathParam('uid');
      LGotPid := AReq.PathParam('pid');
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end);

    LReq := NewGetRequest('/users/7/posts/99');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    CheckEqual('7', LGotUid, 'uid param');
    CheckEqual('99', LGotPid, 'pid param');
  finally
    LRouter.Free;
  end;
end;

procedure TestServeHTTPWildcard;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
  LGotPath: string;
begin
  LRouter := THttpRouter.Create;
  try
    LGotPath := '';
    LRouter.Get('/static/*filepath', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LGotPath := AReq.PathParam('filepath');
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end);

    LReq := NewGetRequest('/static/css/main.css');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    CheckEqual('css/main.css', LGotPath, 'wildcard captures rest');
  finally
    LRouter.Free;
  end;
end;

procedure TestServeHTTP404;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Get('/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end);

    LReq := NewGetRequest('/not-exists');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    Check(Pos('HTTP/1.1 404', LBuf.Output) > 0, '404 status in output');
  finally
    LRouter.Free;
  end;
end;

procedure TestServeHTTP405;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
  LUrl: TUrl;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Get('/items', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end);
    LRouter.Post('/items', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_CREATED);
    end);

    { PUT /items should be 405 }
    LUrl := Default(TUrl);
    LUrl.Path := '/items';
    LReq := NewRequest(hmPut, LUrl);
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    Check(Pos('HTTP/1.1 405', LBuf.Output) > 0, '405 status in output');
    Check(Pos('allow:', LBuf.Output) > 0, 'Allow header present');
  finally
    LRouter.Free;
  end;
end;

{ ===== Middleware integration ===== }

procedure TestRouterUseSingleMiddleware;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
begin
  LRouter := THttpRouter.Create;
  try
    LRouter.Use(TAddHeaderMiddleware.Create('x-custom', 'injected'));
    LRouter.Get('/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end);

    LReq := NewGetRequest('/test');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    Check(Pos('x-custom: injected', LBuf.Output) > 0, 'middleware added header');
    Check(Pos('HTTP/1.1 200', LBuf.Output) > 0, 'status 200');
  finally
    LRouter.Free;
  end;
end;

procedure TestRouterUseMultipleMiddlewares;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
begin
  GLog := '';
  LRouter := THttpRouter.Create;
  try
    LRouter.Use(TOrderMiddleware.Create('A'));
    LRouter.Use(TOrderMiddleware.Create('B'));
    LRouter.Get('/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GLog := GLog + 'handler;';
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end);

    LReq := NewGetRequest('/test');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    CheckEqual('A>B>handler;<B<A', GLog, 'middlewares execute in order');
  finally
    LRouter.Free;
  end;
end;

procedure TestMiddlewareShortCircuit;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
begin
  GLog := '';
  GHandlerCalled := False;
  LRouter := THttpRouter.Create;
  try
    LRouter.Use(TBlockMiddleware.Create(HTTP_STATUS_FORBIDDEN, 'denied'));
    LRouter.Get('/admin', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      GHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end);

    LReq := NewGetRequest('/admin');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    Check(not GHandlerCalled, 'handler NOT called');
    Check(Pos('HTTP/1.1 403', LBuf.Output) > 0, '403 status');
    Check(Pos('denied', LBuf.Output) > 0, 'block body written');
  finally
    LRouter.Free;
  end;
end;

procedure TestMiddlewareWithPathParams;
var
  LRouter: THttpRouter;
  LReq: IHttpRequest;
  LBuf: TBytesWriter;
  LW: IHttpResponseWriter;
  LGotId: string;
begin
  LRouter := THttpRouter.Create;
  try
    LGotId := '';
    LRouter.Use(TAddHeaderMiddleware.Create('x-traced', 'yes'));
    LRouter.Get('/items/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LGotId := AReq.PathParam('id');
      AW.GetHeaders.SetHeader('content-length', '2');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('ok')^, 2);
    end);

    LReq := NewGetRequest('/items/55');
    LBuf := TBytesWriter.Create;
    LW := TH1ResponseWriter.Create(LBuf as IWriter);
    LRouter.ServeHTTP(LReq, LW);

    CheckEqual('55', LGotId, 'path param accessible after middleware');
    Check(Pos('x-traced: yes', LBuf.Output) > 0, 'middleware header present');
  finally
    LRouter.Free;
  end;
end;

{ ===== Header validation integration ===== }

procedure TestHeaderCRLFInValueRaises;
var
  LHeaders: IHttpHeaders;
  LCaught: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LCaught := False;
  try
    LHeaders.SetHeader('x-bad', 'value'#13#10'injected: yes');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'CRLF in header value raises EHttpError');
end;

procedure TestHeaderEmptyNameRaises;
var
  LHeaders: IHttpHeaders;
  LCaught: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LCaught := False;
  try
    LHeaders.SetHeader('', 'value');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'empty header name raises EHttpError');
end;

procedure TestHeaderColonInNameRaises;
var
  LHeaders: IHttpHeaders;
  LCaught: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LCaught := False;
  try
    LHeaders.SetHeader('bad:name', 'value');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'colon in header name raises EHttpError');
end;

{ ===== URL edge cases ===== }

procedure TestUrlParseNoPath;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://host?query=1');
  CheckEqual('host', LUrl.Host, 'host parsed');
  CheckEqual('query=1', LUrl.RawQuery, 'query parsed');
  { Path may be empty when no path segment present }
  Check(True, 'no crash on missing path');
end;

procedure TestUrlParsePortOverflow;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    TUrl.Parse('http://host:70000/path');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'port overflow raises EHttpError');
end;

procedure TestUrlParseIPv6WithPort;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://[::1]:443/path');
  CheckEqual('::1', LUrl.Host, 'IPv6 host parsed');
  CheckEqual(Int64(443), Int64(LUrl.Port), 'port parsed');
  CheckEqual('/path', LUrl.Path, 'path parsed');
end;

{ ===== H1 Writer integration ===== }

procedure TestH1WriterChunkedWhenNoContentLength;
var
  LBuf: TBytesWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
begin
  { When no Content-Length or Transfer-Encoding, chunked encoding is auto-added }
  LBuf := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LBuf as IWriter);
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;

  Check(Pos('transfer-encoding: chunked', LBuf.Output) > 0, 'Transfer-Encoding: chunked auto-added');
  Check(Pos('connection: close', LBuf.Output) = 0, 'Connection: close not auto-added');
  Check(Pos('5'#13#10'hello'#13#10, LBuf.Output) > 0, 'chunked body written');
  LRW.Free;
end;

procedure TestH1WriterExplicitContentLength;
var
  LBuf: TBytesWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
begin
  { When Content-Length is set, Connection: close should NOT be added }
  LBuf := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LBuf as IWriter);
  LRW.GetHeaders.SetHeader('content-length', '5');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));

  Check(Pos('connection: close', LBuf.Output) = 0, 'no Connection: close when Content-Length set');
  Check(Pos('content-length: 5', LBuf.Output) > 0, 'Content-Length present');
  LRW.Free;
end;

{ ===== Main ===== }

begin
  T := TTestRunner.Create('nextpas.core.http.integration');
  { ServeHTTP + PathParam }
  T.Run('ServeHTTP static route', @TestServeHTTPStaticRoute);
  T.Run('ServeHTTP with :param', @TestServeHTTPWithParam);
  T.Run('ServeHTTP multiple params', @TestServeHTTPMultipleParams);
  T.Run('ServeHTTP wildcard', @TestServeHTTPWildcard);
  T.Run('ServeHTTP 404', @TestServeHTTP404);
  T.Run('ServeHTTP 405 + Allow header', @TestServeHTTP405);
  { Middleware }
  T.Run('Router.Use single middleware', @TestRouterUseSingleMiddleware);
  T.Run('Router.Use multiple middlewares order', @TestRouterUseMultipleMiddlewares);
  T.Run('Middleware short-circuit', @TestMiddlewareShortCircuit);
  T.Run('Middleware + path params', @TestMiddlewareWithPathParams);
  { Header validation }
  T.Run('Header CRLF in value raises', @TestHeaderCRLFInValueRaises);
  T.Run('Header empty name raises', @TestHeaderEmptyNameRaises);
  T.Run('Header colon in name raises', @TestHeaderColonInNameRaises);
  { URL edge cases }
  T.Run('URL parse no path', @TestUrlParseNoPath);
  T.Run('URL parse port overflow', @TestUrlParsePortOverflow);
  T.Run('URL parse IPv6 with port', @TestUrlParseIPv6WithPort);
  { H1 Writer }
  T.Run('H1 Writer chunked encoding auto-added', @TestH1WriterChunkedWhenNoContentLength);
  T.Run('H1 Writer explicit Content-Length', @TestH1WriterExplicitContentLength);
  T.Summary;
end.
