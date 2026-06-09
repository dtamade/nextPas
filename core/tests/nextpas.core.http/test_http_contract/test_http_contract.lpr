program test_http_contract;
{**
 * @desc Facade and public contract tests.
 *       Proves the public HTTP surface can be consumed through exported contracts.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.http.impl.registry,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

var
  T: TTestRunner;
  GProcHandlerCalled: Boolean;
  GProcHandlerPath: string;
  GRegistryClientTransport: IHttpTransport;
  GRegistryServerTransport: IHttpServerTransport;
  GRegistrySeenClientTimeout: Int64;
  GRegistrySeenServerHeaderLimit: Int32;

function ReadBodyStr(const AReader: IReader): string;
var
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  if AReader = nil then
    Exit;
  repeat
    LN := AReader.Read(LBuf[0], SizeUInt(Length(LBuf)));
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until LN = 0;
end;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  PInterfaceServerCtx = ^TInterfaceServerCtx;
  TInterfaceServerCtx = record
    Server: IHttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TMockHttpTransport = class(TInterfacedObject, IHttpTransport)
  private
    FRoundTripCalled: Boolean;
    FSeenMethod: THttpMethod;
    FSeenPath: string;
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property RoundTripCalled: Boolean read FRoundTripCalled;
    property SeenMethod: THttpMethod read FSeenMethod;
    property SeenPath: string read FSeenPath;
  end;

  TMockServerTransport = class(TInterfacedObject, IHttpServerTransport)
  private
    FServeConnCalled: Boolean;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    property ServeConnCalled: Boolean read FServeConnCalled;
  end;

  TMockServerSession = class(TInterfacedObject, ITcpServerSession)
  private
    FRunCalled: PBoolean;
    FHandlerCalled: PBoolean;
  public
    constructor Create(const ARunCalled, AHandlerCalled: PBoolean);
    function Run: TTcpServerConnOwnership;
  end;

  TMockSessionServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory)
  private
    FServeConnCalled: Boolean;
    FSessionFactoryCalled: Boolean;
    FSessionRunCalled: Boolean;
    FHandlerCalled: Boolean;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property SessionFactoryCalled: Boolean read FSessionFactoryCalled;
    property SessionRunCalled: Boolean read FSessionRunCalled;
    property HandlerCalled: Boolean read FHandlerCalled;
  end;

  TMockContextSessionServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactoryWithContext)
  private
    FServeConnCalled: Boolean;
    FContextSessionFactoryCalled: Boolean;
    FWorkerHandoffSeen: Boolean;
    FSessionRunCalled: Boolean;
    FHandlerCalled: Boolean;
  public
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
    property ServeConnCalled: Boolean read FServeConnCalled;
    property ContextSessionFactoryCalled: Boolean read FContextSessionFactoryCalled;
    property WorkerHandoffSeen: Boolean read FWorkerHandoffSeen;
    property SessionRunCalled: Boolean read FSessionRunCalled;
    property HandlerCalled: Boolean read FHandlerCalled;
  end;

  TMethodHandlerTarget = class
  private
    FCalled: Boolean;
    FSeenPath: string;
  public
    procedure Handle(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
    property Called: Boolean read FCalled;
    property SeenPath: string read FSeenPath;
  end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function InterfaceServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PInterfaceServerCtx;
begin
  Result := nil;
  LCtx := PInterfaceServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartServerWithTransport(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport; out AServer: THttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, ATransport, THttpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

function StartFacadeServer(const AServer: IHttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PInterfaceServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @InterfaceServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

procedure StopServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

procedure StopFacadeServer(var AServer: IHttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function SendRawRequestAndReadAll(const APort: UInt16;
  const ARequest: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    if Length(ARequest) > 0 then
      LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    LConn.Shutdown;
    repeat
      try
        LN := LConn.Read(LBuf[0], SizeUInt(Length(LBuf)));
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

function ReadTextFile(const APath: string): string;
var
  F: file;
  LSize: Int64;
begin
  Assign(F, APath);
  Reset(F, 1);
  try
    LSize := FileSize(F);
    SetLength(Result, Int32(LSize));
    if LSize > 0 then
      BlockRead(F, Result[1], Int32(LSize));
  finally
    Close(F);
  end;
end;

function SourceHas(const ASource, AText: string): Boolean;
begin
  Result := Pos(AText, ASource) > 0;
end;

procedure CheckSourceDoesNotUseLegacyHeaderSetterSpelling(const ASource,
  AContext: string);
var
  LLegacyName: string;
begin
  LLegacyName := 'Set' + '_';
  Check(not SourceHas(ASource, '.' + LLegacyName),
    AContext + ' must not use legacy header setter spelling');
  Check(not SourceHas(ASource, ' ' + LLegacyName),
    AContext + ' must not expose legacy header setter spelling');
  Check(not SourceHas(ASource, '`' + LLegacyName),
    AContext + ' docs must not expose legacy header setter spelling');
  Check(not SourceHas(ASource, 'setheader'),
    AContext + ' docs must spell public API as SetHeader');
end;

procedure PlainHandlerProc(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GProcHandlerCalled := True;
  if AReq <> nil then
    GProcHandlerPath := AReq.Url.Path;
end;

function CreateRegistryClientTransport(
  const AOptions: THttpClientOptions): IHttpTransport;
begin
  GRegistrySeenClientTimeout := AOptions.Timeout;
  Result := GRegistryClientTransport;
end;

function CreateRegistryServerTransport(
  const AOptions: THttpServerOptions): IHttpServerTransport;
begin
  GRegistrySeenServerHeaderLimit := AOptions.MaxHeaderSize;
  Result := GRegistryServerTransport;
end;

{ TMockHttpTransport }

function TMockHttpTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  FRoundTripCalled := True;
  FSeenMethod := AReq.Method;
  FSeenPath := AReq.Url.Path;
  LHeaders := NewHeaders;
  LHeaders.SetHeader('x-transport', 'mock');
  Result := NewResponse(HTTP_STATUS_CREATED, LHeaders, nil);
end;

{ TMockServerTransport }

function TMockServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  if AHandler <> nil then
    AHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/transport')), nil);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

constructor TMockServerSession.Create(const ARunCalled, AHandlerCalled: PBoolean);
begin
  inherited Create;
  FRunCalled := ARunCalled;
  FHandlerCalled := AHandlerCalled;
end;

function TMockServerSession.Run: TTcpServerConnOwnership;
begin
  FRunCalled^ := True;
  FHandlerCalled^ := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TMockSessionServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TMockSessionServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  FSessionFactoryCalled := True;
  Result := TMockServerSession.Create(@FSessionRunCalled, @FHandlerCalled);
end;

function TMockContextSessionServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  FServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TMockContextSessionServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  FContextSessionFactoryCalled := True;
  FWorkerHandoffSeen := (AContext <> nil) and (AContext.WorkerHandoff <> nil);
  Result := TMockServerSession.Create(@FSessionRunCalled, @FHandlerCalled);
end;

{ TMethodHandlerTarget }

procedure TMethodHandlerTarget.Handle(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  FCalled := True;
  if AReq <> nil then
    FSeenPath := AReq.Url.Path;
end;

{ Test 1: NewHeaders — Set/Get/Has/Remove/Count/Clone }
procedure TestNewHeaders;
var
  LH, LClone: IHttpHeaders;
begin
  LH := NewHeaders;
  Check(LH <> nil, 'NewHeaders returns non-nil');
  LH.SetHeader('x-foo', 'bar');
  CheckEqual('bar', LH.Get('x-foo'), 'Get after Set');
  Check(LH.Has('x-foo'), 'Has returns true');
  Check(not LH.Has('x-missing'), 'Has returns false for missing');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count = 1');
  LH.SetHeader('x-baz', 'qux');
  CheckEqual(Int64(2), Int64(LH.Count), 'Count = 2');
  LClone := LH.Clone;
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone preserves values');
  LH.Remove('x-foo');
  Check(not LH.Has('x-foo'), 'Remove removes header');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count after Remove');
  { Clone is independent }
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone independent after Remove');
end;

procedure TestAuthHelpersAvailableThroughFacade;
var
  LH: IHttpHeaders;
begin
  LH := NewHeaders;

  nextpas.core.http.SetBasicAuth(LH, 'Aladdin', 'open sesame');
  CheckEqual('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
    LH.Get('authorization'), 'facade SetBasicAuth sets authorization');

  nextpas.core.http.SetBearerAuth(LH, 'token-123');
  CheckEqual('Bearer token-123', LH.Get('authorization'),
    'facade SetBearerAuth replaces authorization');
end;

procedure TestHeaderValuesArrayAvailableThroughFacade;
var
  LH: IHttpHeaders;
  LValues: nextpas.core.http.TStringArray;
begin
  LH := nextpas.core.http.NewHeaders;
  LH.Add('x-repeat', 'first');
  LH.Add('x-repeat', 'second');

  LValues := LH.GetAll('x-repeat');
  CheckEqual(Int64(2), Int64(Length(LValues)),
    'Facade TStringArray receives repeated header values');
  CheckEqual('first', LValues[0],
    'Facade TStringArray preserves first header value');
  CheckEqual('second', LValues[1],
    'Facade TStringArray preserves second header value');
end;

{ Test 2: NewRouter — Get route + FindRoute }
procedure TestNewRouter;
var
  LRouter: IHttpRouter;
  LCalled: Boolean;
begin
  LCalled := False;
  LRouter := NewRouter;
  Check(LRouter <> nil, 'NewRouter returns non-nil');
  LRouter.Handle(hmGet, '/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LCalled := True;
  end);
  { Verify via ServeHTTP with a mock request }
  LRouter.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/test')), nil);
  Check(LCalled, 'Router dispatches handler');
end;

{ Test 3: IHttpRouter convenience methods are callable through interface }
procedure TestRouterConvenienceMethodsOnInterface;
var
  LRouter: IHttpRouter;
  LHit: string;
begin
  LRouter := NewRouter;
  Check(LRouter <> nil, 'NewRouter returns non-nil for interface convenience methods');

  LRouter.Get('/iface-get', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'get';
  end);
  LRouter.Post('/iface-post', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'post';
  end);
  LRouter.Put('/iface-put', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'put';
  end);
  LRouter.Delete('/iface-delete', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'delete';
  end);
  LRouter.Head('/iface-head', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'head';
  end);
  LRouter.Patch('/iface-patch', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'patch';
  end);
  LRouter.Options('/iface-options', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'options';
  end);
  LRouter.Connect('/iface-connect', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'connect';
  end);
  LRouter.Trace('/iface-trace', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHit := 'trace';
  end);

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/iface-get')), nil);
  CheckEqual('get', LHit, 'IHttpRouter.Get registers GET route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmPost, TUrl.Parse('/iface-post')), nil);
  CheckEqual('post', LHit, 'IHttpRouter.Post registers POST route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmPut, TUrl.Parse('/iface-put')), nil);
  CheckEqual('put', LHit, 'IHttpRouter.Put registers PUT route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmDelete, TUrl.Parse('/iface-delete')), nil);
  CheckEqual('delete', LHit, 'IHttpRouter.Delete registers DELETE route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmHead, TUrl.Parse('/iface-head')), nil);
  CheckEqual('head', LHit, 'IHttpRouter.Head registers HEAD route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmPatch, TUrl.Parse('/iface-patch')), nil);
  CheckEqual('patch', LHit, 'IHttpRouter.Patch registers PATCH route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmOptions, TUrl.Parse('/iface-options')), nil);
  CheckEqual('options', LHit, 'IHttpRouter.Options registers OPTIONS route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmConnect, TUrl.Parse('/iface-connect')), nil);
  CheckEqual('connect', LHit, 'IHttpRouter.Connect registers CONNECT route');

  LHit := '';
  LRouter.ServeHTTP(NewRequest(hmTrace, TUrl.Parse('/iface-trace')), nil);
  CheckEqual('trace', LHit, 'IHttpRouter.Trace registers TRACE route');
end;

{ Test 4: NewRequest — Method/Url/Version accessible }
procedure TestNewRequest;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?q=1');
  LReq := NewRequest(hmPost, LUrl);
  Check(LReq <> nil, 'NewRequest returns non-nil');
  Check(LReq.Method = hmPost, 'Method = POST');
  CheckEqual('/path', LReq.Url.Path, 'Url.Path');
  CheckEqual('q=1', LReq.Url.RawQuery, 'Url.RawQuery');
  CheckEqual('/path', LReq.Path, 'Path direct accessor');
  CheckEqual('q=1', LReq.RawQuery, 'RawQuery direct accessor');
  Check(LReq.Version = hvHttp11, 'Version = HTTP/1.1');
end;

procedure TestNewRequestWithHeadersFacadeOverload;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
begin
  LUrl := TUrl.Parse('http://example.com/api');
  LHeaders := NewHeaders;
  LHeaders.SetHeader('x-api', 'next');

  LReq := nextpas.core.http.NewRequest(hmPatch, LUrl, LHeaders, nil, 0);

  Check(LReq <> nil, 'Facade NewRequest(headers/body) returns non-nil');
  Check(LReq.Method = hmPatch,
    'Facade NewRequest(headers/body) preserves method');
  CheckEqual('next', LReq.Headers.Get('x-api'),
    'Facade NewRequest(headers/body) preserves headers');
end;

procedure TestNewRequestRejectsConflictingContentLengthThroughFacade;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/api');
  LHeaders := NewHeaders;
  LHeaders.SetHeader('content-length', '999');

  LRaised := False;
  try
    nextpas.core.http.NewRequest(hmPost, LUrl, LHeaders, 'hello');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised,
    'Facade NewRequest rejects conflicting content-length header');
end;

procedure TestNewRequestHeadersOnlyFacadeOverload;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
begin
  LUrl := TUrl.Parse('http://example.com/api');
  LHeaders := NewHeaders;
  LHeaders.SetHeader('x-api', 'headers-only');

  LReq := nextpas.core.http.NewRequest(hmGet, LUrl, LHeaders);

  Check(LReq <> nil, 'Facade NewRequest(headers-only) returns non-nil');
  Check(LReq.Method = hmGet,
    'Facade NewRequest(headers-only) preserves method');
  CheckEqual('headers-only', LReq.Headers.Get('x-api'),
    'Facade NewRequest(headers-only) preserves headers');
  Check(LReq.Body = nil, 'Facade NewRequest(headers-only) keeps body nil');
  CheckEqual(Int64(0), LReq.ContentLength,
    'Facade NewRequest(headers-only) stores zero content-length');

  LReq := nextpas.core.http.NewRequest(hmHead,
    'http://example.com/ping?x=1', LHeaders);

  Check(LReq <> nil,
    'Facade NewRequest(string URL, headers-only) returns non-nil');
  Check(LReq.Method = hmHead,
    'Facade NewRequest(string URL, headers-only) preserves method');
  CheckEqual('/ping', LReq.Path,
    'Facade NewRequest(string URL, headers-only) parses path');
  CheckEqual('x=1', LReq.RawQuery,
    'Facade NewRequest(string URL, headers-only) parses query');
  CheckEqual('headers-only', LReq.Headers.Get('x-api'),
    'Facade NewRequest(string URL, headers-only) preserves headers');
  Check(LReq.Body = nil,
    'Facade NewRequest(string URL, headers-only) keeps body nil');
  CheckEqual(Int64(0), LReq.ContentLength,
    'Facade NewRequest(string URL, headers-only) stores zero content-length');
end;

procedure TestNewRequestNilThirdArgumentFacadeCompatibility;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/api');

  LReq := nextpas.core.http.NewRequest(hmPost, LUrl, nil);

  Check(LReq <> nil, 'Facade NewRequest(nil third argument) returns non-nil');
  Check(LReq.Method = hmPost,
    'Facade NewRequest(nil third argument) preserves method');
  Check(LReq.Body <> nil,
    'Facade NewRequest(nil third argument) preserves bytes helper body');
  CheckEqual('0', LReq.Headers.Get('content-length'),
    'Facade NewRequest(nil third argument) preserves bytes helper content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'Facade NewRequest(nil third argument) stores zero content-length');

  LReq := nextpas.core.http.NewRequest(hmPut,
    'http://example.com/upload?x=1', nil);

  Check(LReq <> nil,
    'Facade NewRequest(string URL, nil third argument) returns non-nil');
  Check(LReq.Method = hmPut,
    'Facade NewRequest(string URL, nil third argument) preserves method');
  CheckEqual('/upload', LReq.Path,
    'Facade NewRequest(string URL, nil third argument) parses path');
  CheckEqual('x=1', LReq.RawQuery,
    'Facade NewRequest(string URL, nil third argument) parses query');
  Check(LReq.Body <> nil,
    'Facade NewRequest(string URL, nil third argument) preserves bytes helper body');
  CheckEqual('0', LReq.Headers.Get('content-length'),
    'Facade NewRequest(string URL, nil third argument) preserves bytes helper content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'Facade NewRequest(string URL, nil third argument) stores zero content-length');
end;

procedure TestNewRequestStringUrlFacadeOverloads;
var
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LBody: TBytes;
begin
  LReq := nextpas.core.http.NewRequest(hmGet,
    'http://example.com/search?q=next');

  Check(LReq <> nil, 'Facade NewRequest(string URL) returns non-nil');
  Check(LReq.Method = hmGet, 'Facade NewRequest(string URL) preserves method');
  CheckEqual('/search', LReq.Path,
    'Facade NewRequest(string URL) parses path');
  CheckEqual('q=next', LReq.RawQuery,
    'Facade NewRequest(string URL) parses query');

  LHeaders := NewHeaders;
  LHeaders.SetHeader('x-api', 'next');
  LReq := nextpas.core.http.NewRequest(hmPost,
    'http://example.com/upload', LHeaders, nil, 0);

  Check(LReq <> nil,
    'Facade NewRequest(string URL, headers/body) returns non-nil');
  Check(LReq.Method = hmPost,
    'Facade NewRequest(string URL, headers/body) preserves method');
  CheckEqual('next', LReq.Headers.Get('x-api'),
    'Facade NewRequest(string URL, headers/body) preserves headers');

  LHeaders := NewHeaders;
  LReq := nextpas.core.http.NewRequest(hmPut,
    'http://example.com/string-body', LHeaders, 'hello');

  Check(LReq <> nil,
    'Facade NewRequest(string URL, string body) returns non-nil');
  Check(LReq.Method = hmPut,
    'Facade NewRequest(string URL, string body) preserves method');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'Facade NewRequest(string URL, string body) sets content-length');

  SetLength(LBody, 3);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;
  LHeaders := NewHeaders;
  LReq := nextpas.core.http.NewRequest(hmPatch,
    'http://example.com/bytes-body', LHeaders, LBody);

  Check(LReq <> nil,
    'Facade NewRequest(string URL, bytes body) returns non-nil');
  Check(LReq.Method = hmPatch,
    'Facade NewRequest(string URL, bytes body) preserves method');
  CheckEqual('3', LReq.Headers.Get('content-length'),
    'Facade NewRequest(string URL, bytes body) sets content-length');
end;

procedure TestNewRequestNoHeadersBodyFacadeOverloads;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
  LBody: TBytes;
  LStream: IStream;
  LStreamBytes: TBytes;
begin
  LUrl := TUrl.Parse('http://example.com/bodyless-headers');

  LReq := nextpas.core.http.NewRequest(hmPost, LUrl, 'hello');
  Check(LReq <> nil,
    'Facade NewRequest(TUrl, string body) without headers returns non-nil');
  Check(LReq.Method = hmPost,
    'Facade NewRequest(TUrl, string body) without headers preserves method');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'Facade NewRequest(TUrl, string body) without headers sets content-length');

  SetLength(LBody, 3);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;
  LReq := nextpas.core.http.NewRequest(hmPatch,
    'http://example.com/no-headers-bytes', LBody);
  Check(LReq <> nil,
    'Facade NewRequest(string URL, bytes body) without headers returns non-nil');
  Check(LReq.Method = hmPatch,
    'Facade NewRequest(string URL, bytes body) without headers preserves method');
  CheckEqual('3', LReq.Headers.Get('content-length'),
    'Facade NewRequest(string URL, bytes body) without headers sets content-length');

  SetLength(LStreamBytes, 4);
  LStreamBytes[0] := Ord('d');
  LStreamBytes[1] := Ord('a');
  LStreamBytes[2] := Ord('t');
  LStreamBytes[3] := Ord('a');
  LStream := CreateBytesStreamFrom(LStreamBytes);
  LReq := nextpas.core.http.NewRequest(hmPut, LUrl, LStream as IReader, 4);
  Check(LReq <> nil,
    'Facade NewRequest(TUrl, reader body) without headers returns non-nil');
  Check(LReq.Method = hmPut,
    'Facade NewRequest(TUrl, reader body) without headers preserves method');
  CheckEqual('4', LReq.Headers.Get('content-length'),
    'Facade NewRequest(TUrl, reader body) without headers sets content-length');
end;

procedure TestNewRequestContentTypeBodyFacadeOverloads;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
  LBody: TBytes;
  LStream: IStream;
  LStreamBytes: TBytes;
begin
  LUrl := TUrl.Parse('http://example.com/content-type-body');

  LReq := nextpas.core.http.NewRequest(hmPost, LUrl,
    'text/plain; charset=utf-8', 'hello');
  Check(LReq <> nil,
    'Facade NewRequest(TUrl, content-type, string body) returns non-nil');
  Check(LReq.Method = hmPost,
    'Facade NewRequest(TUrl, content-type, string body) preserves method');
  CheckEqual('text/plain; charset=utf-8', LReq.Headers.Get('content-type'),
    'Facade NewRequest(TUrl, content-type, string body) sets content-type');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'Facade NewRequest(TUrl, content-type, string body) sets content-length');

  SetLength(LBody, 3);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;
  LReq := nextpas.core.http.NewRequest(hmPatch,
    'http://example.com/content-type-bytes',
    'application/octet-stream', LBody);
  Check(LReq <> nil,
    'Facade NewRequest(string URL, content-type, bytes body) returns non-nil');
  Check(LReq.Method = hmPatch,
    'Facade NewRequest(string URL, content-type, bytes body) preserves method');
  CheckEqual('application/octet-stream', LReq.Headers.Get('content-type'),
    'Facade NewRequest(string URL, content-type, bytes body) sets content-type');
  CheckEqual('3', LReq.Headers.Get('content-length'),
    'Facade NewRequest(string URL, content-type, bytes body) sets content-length');

  SetLength(LStreamBytes, 4);
  LStreamBytes[0] := Ord('d');
  LStreamBytes[1] := Ord('a');
  LStreamBytes[2] := Ord('t');
  LStreamBytes[3] := Ord('a');
  LStream := CreateBytesStreamFrom(LStreamBytes);
  LReq := nextpas.core.http.NewRequest(hmPut, LUrl,
    'application/custom', LStream as IReader, 4);
  Check(LReq <> nil,
    'Facade NewRequest(TUrl, content-type, reader body) returns non-nil');
  Check(LReq.Method = hmPut,
    'Facade NewRequest(TUrl, content-type, reader body) preserves method');
  CheckEqual('application/custom', LReq.Headers.Get('content-type'),
    'Facade NewRequest(TUrl, content-type, reader body) sets content-type');
  CheckEqual('4', LReq.Headers.Get('content-length'),
    'Facade NewRequest(TUrl, content-type, reader body) sets content-length');
end;

procedure TestHttpClientShortcutBodyFacadeOverloads;
var
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TMockHttpTransport.Create;
  LClient := nextpas.core.http.NewHttpClient(LTransport);

  LResp := LClient.Post('http://example.com/post', 'text/plain', 'hello');
  Check(LResp <> nil, 'Facade client Post(string body) returns response');

  LResp := LClient.Put('http://example.com/put', 'text/plain', 'world');
  Check(LResp <> nil, 'Facade client Put(string body) returns response');

  LResp := LClient.Patch('http://example.com/patch',
    'application/octet-stream', TBytes.Create(Ord('b'), 0, 255));
  Check(LResp <> nil, 'Facade client Patch(bytes body) returns response');
end;

procedure TestHttpClientCloseIdleConnectionsFacadeMethod;
var
  LTransport: IHttpTransport;
  LClient: IHttpClient;
begin
  LTransport := TMockHttpTransport.Create;
  LClient := nextpas.core.http.NewHttpClient(LTransport);
  LClient.CloseIdleConnections;
  Check(True, 'Facade client CloseIdleConnections is callable');
end;

{ Test 4: NewResponse — StatusCode/Headers accessible }
procedure TestNewResponse;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHeaders;
  LH.SetHeader('x-test', 'val');
  LResp := NewResponse(HTTP_STATUS_CREATED, LH, nil);
  Check(LResp <> nil, 'NewResponse returns non-nil');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'StatusCode = 201');
  CheckEqual('val', LResp.Headers.Get('x-test'), 'Headers accessible');
  Check(LResp.Body = nil, 'Body is nil');

  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_OK, nil, nil);
  Check(LResp.Headers <> nil,
    'Facade NewResponse creates headers when headers argument is nil');
  CheckEqual(Int64(0), Int64(LResp.Headers.Count),
    'Facade NewResponse nil headers start empty');
end;

procedure TestNewResponseBodyFacadeOverloads;
var
  LResp: IHttpResponse;
  LBody: TBytes;
begin
  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_CREATED, nil, 'created');
  CheckEqual('7', LResp.Headers.Get('content-length'),
    'Facade NewResponse string body sets content-length');
  CheckEqual('created', ReadBodyStr(LResp.Body),
    'Facade NewResponse string body is readable');

  SetLength(LBody, 3);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;
  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_OK, nil, LBody);
  CheckEqual('3', LResp.Headers.Get('content-length'),
    'Facade NewResponse bytes body sets content-length');
  Check(LResp.Body <> nil,
    'Facade NewResponse bytes body creates a body reader');

  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_OK, nil, nil);
  CheckEqual('', LResp.Headers.Get('content-length'),
    'Facade NewResponse nil body does not set content-length');
  Check(LResp.Body = nil,
    'Facade NewResponse nil body remains nil');
end;

procedure TestHttpReadResponseBodyStringFacadeHelper;
var
  LResp: IHttpResponse;
begin
  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_NO_CONTENT, NewHeaders, nil);
  CheckEqual('', nextpas.core.http.HttpReadResponseBodyString(LResp),
    'Facade response body string helper is callable');
end;

procedure TestHttpReadResponseBodyBytesFacadeHelper;
var
  LResp: IHttpResponse;
  LBody: TBytes;
begin
  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_NO_CONTENT, NewHeaders, nil);
  LBody := nextpas.core.http.HttpReadResponseBodyBytes(LResp);
  CheckEqual(Int64(0), Int64(Length(LBody)),
    'Facade response body bytes helper is callable');
end;

procedure TestHttpReleaseResponseBodyFacadeHelper;
var
  LResp: IHttpResponse;
begin
  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_NO_CONTENT, NewHeaders, nil);
  nextpas.core.http.HttpReleaseResponseBody(LResp);
  Check(LResp.Body = nil,
    'Facade response body release helper accepts nil body');
end;

{ Test 5: HandlerFunc wraps correctly }
procedure TestHandlerFuncWrap;
var
  LHandler: IHttpHandler;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LCalled := True;
  end);
  Check(LHandler <> nil, 'HandlerFunc returns non-nil');
  LHandler.ServeHTTP(nil, nil);
  Check(LCalled, 'HandlerFunc handler was called');
end;

{ Test 6: HandlerFunc wraps plain procedures through facade }
procedure TestHandlerProcWrap;
var
  LHandler: IHttpHandler;
begin
  GProcHandlerCalled := False;
  GProcHandlerPath := '';
  LHandler := nextpas.core.http.HandlerFunc(@PlainHandlerProc);
  Check(LHandler <> nil, 'Facade HandlerFunc(proc) returns non-nil');
  LHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/proc')), nil);
  Check(GProcHandlerCalled, 'Facade HandlerFunc(proc) dispatches');
  CheckEqual('/proc', GProcHandlerPath, 'Facade HandlerFunc(proc) keeps request');
end;

{ Test 7: HandlerFunc wraps object methods through facade }
procedure TestHandlerMethodWrap;
var
  LTarget: TMethodHandlerTarget;
  LHandler: IHttpHandler;
begin
  LTarget := TMethodHandlerTarget.Create;
  try
    LHandler := nextpas.core.http.HandlerFunc(@LTarget.Handle);
    Check(LHandler <> nil, 'Facade HandlerFunc(method) returns non-nil');
    LHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/method')), nil);
    Check(LTarget.Called, 'Facade HandlerFunc(method) dispatches');
    CheckEqual('/method', LTarget.SeenPath, 'Facade HandlerFunc(method) keeps request');
  finally
    LTarget.Free;
  end;
end;

{ Test 8: Chain applies middleware }
procedure TestChainMiddleware;
var
  LHandler: IHttpHandler;
  LOrder: string;
  LMw: IHttpMiddleware;
  LWrapFunc: TMiddlewareWrapFunc;
begin
  LOrder := '';
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LOrder := LOrder + 'H';
  end);
  LWrapFunc := function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LOrder := LOrder + 'M';
      ANext.ServeHTTP(AReq, AW);
    end);
  end;
  LMw := nextpas.core.http.MiddlewareFunc(LWrapFunc);
  LHandler := Chain(LHandler, [LMw]);
  LHandler.ServeHTTP(nil, nil);
  CheckEqual('MH', LOrder, 'Chain: middleware then handler');
end;

procedure TestCorsMiddlewareAvailableThroughFacade;
var
  LOptions: nextpas.core.http.TCorsOptions;
  LMiddleware: IHttpMiddleware;
begin
  LOptions := nextpas.core.http.TCorsOptions.Default;
  LOptions.AllowOrigins := 'https://example.test';
  LMiddleware := nextpas.core.http.CorsMiddleware(LOptions);
  Check(LMiddleware <> nil,
    'Facade CorsMiddleware returns non-nil middleware');
end;

procedure TestRecoveryMiddlewareAvailableThroughFacade;
var
  LMiddleware: IHttpMiddleware;
begin
  LMiddleware := nextpas.core.http.RecoveryMiddleware;
  Check(LMiddleware <> nil,
    'Facade RecoveryMiddleware returns non-nil middleware');
end;

{ Test 9: Facade exposes server overloads }
procedure TestHttpServerFacadeOverloads;
var
  LHandler: IHttpHandler;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;
  LTransportObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
begin
  LHandler := nextpas.core.http.HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);

  LServer := nextpas.core.http.NewHttpServer(LHandler);
  Check(LServer <> nil, 'Facade NewHttpServer(handler) returns non-nil');

  LOptions := THttpServerOptions.Default;
  LOptions.MaxHeaderSize := 4096;
  LServer := nextpas.core.http.NewHttpServer(LHandler, LOptions);
  Check(LServer <> nil, 'Facade NewHttpServer(handler, options) returns non-nil');

  LTransportObj := TMockServerTransport.Create;
  LTransport := LTransportObj;
  LServer := nextpas.core.http.NewHttpServer(LHandler, LTransport);
  Check(LServer <> nil, 'Facade NewHttpServer(handler, transport) returns non-nil');

  LServer := nextpas.core.http.NewHttpServer(LHandler, LTransport, LOptions);
  Check(LServer <> nil, 'Facade NewHttpServer(handler, transport, options) returns non-nil');
end;

{ Test 10: Facade exposes client overloads }
procedure TestHttpClientFacadeOverloads;
var
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LTransportObj: TMockHttpTransport;
  LTransport: IHttpTransport;
begin
  LClient := nextpas.core.http.NewHttpClient;
  Check(LClient <> nil, 'Facade NewHttpClient returns non-nil');

  LOptions := THttpClientOptions.Default;
  LOptions.Timeout := 1234;
  LClient := nextpas.core.http.NewHttpClient(LOptions);
  Check(LClient <> nil, 'Facade NewHttpClient(options) returns non-nil');

  LTransportObj := TMockHttpTransport.Create;
  LTransport := LTransportObj;
  LClient := nextpas.core.http.NewHttpClient(LTransport);
  Check(LClient <> nil, 'Facade NewHttpClient(transport) returns non-nil');

  LClient := nextpas.core.http.NewHttpClient(LTransport, LOptions);
  Check(LClient <> nil, 'Facade NewHttpClient(transport, options) returns non-nil');
end;

procedure TestHttpClientFacadeUsesRegisteredHttp2RegistryDefault;
var
  LOldFactory: THttpClientTransportFactory;
  LHadFactory: Boolean;
  LOldVersion: THttpVersion;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LTransportObj: TMockHttpTransport;
  LResp: IHttpResponse;
begin
  LOldFactory := nil;
  LHadFactory := TryGetClientTransportFactory(hvHttp2, LOldFactory);
  LOldVersion := GetDefaultClientVersion;
  LTransportObj := TMockHttpTransport.Create;
  GRegistryClientTransport := LTransportObj as IHttpTransport;
  GRegistrySeenClientTimeout := 0;
  RegisterClientTransport(hvHttp2, @CreateRegistryClientTransport);
  SetDefaultClientVersion(hvHttp2);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 3456;
    LClient := nextpas.core.http.NewHttpClient(LOptions);
    LResp := LClient.Get('http://example.com/facade-h2');
    Check(LResp <> nil, 'Facade HTTP/2 registry client returns response');
    CheckEqual(Int64(201), Int64(LResp.StatusCode),
      'Facade HTTP/2 registry client returns transport response');
    Check(LTransportObj.RoundTripCalled,
      'Facade NewHttpClient(options) consumes registered HTTP/2 default transport');
    Check(LTransportObj.SeenMethod = hmGet,
      'Facade HTTP/2 registry client sees GET');
    CheckEqual('/facade-h2', LTransportObj.SeenPath,
      'Facade HTTP/2 registry client sees parsed path');
    CheckEqual(Int64(3456), GRegistrySeenClientTimeout,
      'Facade HTTP/2 registry client factory sees options');
  finally
    LResp := nil;
    LClient := nil;
    if LHadFactory then
      RegisterClientTransport(hvHttp2, LOldFactory)
    else
      UnregisterClientTransport(hvHttp2);
    SetDefaultClientVersion(LOldVersion);
    GRegistryClientTransport := nil;
  end;
end;

{ Test 11: Facade client injection delegates round-trip to transport }
procedure TestHttpClientTransportInjection;
var
  LObj: TMockHttpTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LObj := TMockHttpTransport.Create;
  LTransport := LObj;
  LClient := nextpas.core.http.NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.com/injected?x=1');
  Check(LObj.RoundTripCalled, 'Injected client transport was called');
  Check(LObj.SeenMethod = hmGet, 'Injected client transport sees GET');
  CheckEqual('/injected', LObj.SeenPath, 'Injected client transport sees parsed path');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'Injected client transport response returned');
end;

{ Test 12: Facade server injection delegates accepted connections to transport }
procedure TestHttpServerTransportInjection;
var
  LObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LHandlerCalled: Boolean;
  LWait: Int32;
begin
  LObj := TMockServerTransport.Create;
  LTransport := LObj;
  LHandlerCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    Check(AReq.Method = hmGet, 'Injected server transport sees handler');
    CheckEqual('/transport', AReq.Url.Path, 'Injected server transport passes handler request');
  end);

  LHandle := StartServerWithTransport(LHandler, LTransport, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;

    LWait := 0;
    while (not LObj.ServeConnCalled) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LObj.ServeConnCalled, 'Injected server transport was called');
    Check(LHandlerCalled, 'Injected server transport can dispatch handler');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpServerFacadeUsesRegisteredHttp3RegistryDefault;
var
  LOldFactory: THttpServerTransportFactory;
  LHadFactory: Boolean;
  LOldVersion: THttpVersion;
  LServer: IHttpServer;
  LOptions: THttpServerOptions;
  LTransportObj: TMockServerTransport;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LHandlerCalled: Boolean;
  LSeenHandlerPath: string;
  LWait: Int32;
begin
  LOldFactory := nil;
  LHadFactory := TryGetServerTransportFactory(hvHttp3, LOldFactory);
  LOldVersion := GetDefaultServerVersion;
  LTransportObj := TMockServerTransport.Create;
  GRegistryServerTransport := LTransportObj as IHttpServerTransport;
  GRegistrySeenServerHeaderLimit := 0;
  RegisterServerTransport(hvHttp3, @CreateRegistryServerTransport);
  SetDefaultServerVersion(hvHttp3);
  LHandlerCalled := False;
  LSeenHandlerPath := '';
  try
    LOptions := THttpServerOptions.Default;
    LOptions.MaxHeaderSize := 12288;
    LServer := nextpas.core.http.NewHttpServer(
      nextpas.core.http.HandlerFunc(procedure(const AReq: IHttpRequest;
        const AW: IHttpResponseWriter)
      begin
        LHandlerCalled := True;
        if AReq <> nil then
          LSeenHandlerPath := AReq.Url.Path;
      end), LOptions);
    LHandle := StartFacadeServer(LServer, LPort);
    try
      LConn := TcpConnect('127.0.0.1', LPort);
      LConn.Close;

      LWait := 0;
      while (not LTransportObj.ServeConnCalled) and (LWait < 200) do
      begin
        platform_thread_sleep_ns(5000000);
        Inc(LWait);
      end;

      Check(LTransportObj.ServeConnCalled,
        'Facade NewHttpServer(handler, options) consumes registered HTTP/3 default transport');
      Check(LHandlerCalled, 'Facade HTTP/3 registry server transport can dispatch handler');
      CheckEqual('/transport', LSeenHandlerPath,
        'Facade HTTP/3 registry server handler sees transport request');
      CheckEqual(Int64(12288), Int64(GRegistrySeenServerHeaderLimit),
        'Facade HTTP/3 registry server factory sees options');
    finally
      StopFacadeServer(LServer, LHandle);
    end;
  finally
    if LHadFactory then
      RegisterServerTransport(hvHttp3, LOldFactory)
    else
      UnregisterServerTransport(hvHttp3);
    SetDefaultServerVersion(LOldVersion);
    GRegistryServerTransport := nil;
  end;
end;

procedure TestHttpServerTransportInjectionPrefersSessionFactory;
var
  LObj: TMockSessionServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LWait: Int32;
begin
  LObj := TMockSessionServerTransport.Create;
  LTransport := LObj;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);

  LHandle := StartServerWithTransport(LHandler, LTransport, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;

    LWait := 0;
    while (not LObj.SessionRunCalled) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LObj.SessionFactoryCalled,
      'Injected server transport session factory was called');
    Check(LObj.SessionRunCalled,
      'Injected server transport session was run');
    Check(not LObj.ServeConnCalled,
      'legacy ServeConn is bypassed when session factory is available');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpServerTransportInjectionPrefersContextSessionFactory;
var
  LObj: TMockContextSessionServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LWait: Int32;
begin
  LObj := TMockContextSessionServerTransport.Create;
  LTransport := LObj;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
  end);

  LHandle := StartServerWithTransport(LHandler, LTransport, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Close;

    LWait := 0;
    while (not LObj.SessionRunCalled) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LObj.ContextSessionFactoryCalled,
      'Injected server transport context session factory was called');
    Check(LObj.WorkerHandoffSeen,
      'Injected server transport context session factory sees worker handoff');
    Check(LObj.SessionRunCalled,
      'Injected server transport context session was run');
    Check(not LObj.ServeConnCalled,
      'legacy ServeConn is bypassed when context session factory is available');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 13: UrlEncode/UrlDecode round-trip }
procedure TestUrlEncodeDecodeRoundTrip;
var
  LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'hello world&foo=bar/baz';
  LEncoded := UrlEncode(LOriginal);
  Check(Pos(' ', LEncoded) = 0, 'Encoded has no spaces');
  Check(Pos('&', LEncoded) = 0, 'Encoded has no &');
  LDecoded := UrlDecode(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'Round-trip preserves value');
end;

{ Test 14: ParseQueryString basic }
procedure TestParseQueryString;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('a=1&b=hello&c=');
  Check(Length(LParams) = 3, 'ParseQueryString: 3 params');
  CheckEqual('a', LParams[0].Name, 'param 0 name');
  CheckEqual('1', LParams[0].Value, 'param 0 value');
  CheckEqual('b', LParams[1].Name, 'param 1 name');
  CheckEqual('hello', LParams[1].Value, 'param 1 value');
  CheckEqual('c', LParams[2].Name, 'param 2 name');
  CheckEqual('', LParams[2].Value, 'param 2 value empty');
end;

{ Test 15: EncodeQueryString round-trip }
procedure TestEncodeQueryStringRoundTrip;
var
  LParams, LParsed: TQueryParams;
  LEncoded: string;
begin
  SetLength(LParams, 2);
  LParams[0].Name := 'key';
  LParams[0].Value := 'val ue';
  LParams[1].Name := 'x';
  LParams[1].Value := 'y&z';
  LEncoded := EncodeQueryString(LParams);
  LParsed := ParseQueryString(LEncoded);
  Check(Length(LParsed) = 2, 'round-trip: 2 params');
  CheckEqual('key', LParsed[0].Name, 'round-trip: name 0');
  CheckEqual('val ue', LParsed[0].Value, 'round-trip: value 0');
  CheckEqual('x', LParsed[1].Name, 'round-trip: name 1');
  CheckEqual('y&z', LParsed[1].Value, 'round-trip: value 1');
end;

procedure TestQueryParamHelpersAvailableThroughFacade;
var
  LParams: TQueryParams;
begin
  LParams := nextpas.core.http.ParseQueryString('q=hello&empty=');

  Check(nextpas.core.http.QueryParamHas(LParams, 'q'),
    'Facade QueryParamHas finds present query parameter');
  CheckEqual('hello', nextpas.core.http.QueryParamValue(LParams, 'q'),
    'Facade QueryParamValue returns query parameter value');
  Check(nextpas.core.http.QueryParamHas(LParams, 'empty'),
    'Facade QueryParamHas treats empty value as present');
  CheckEqual('', nextpas.core.http.QueryParamValue(LParams, 'missing'),
    'Facade QueryParamValue returns empty string for missing query parameter');
end;

{ Test 16: HttpMethodToStr all methods }
procedure TestHttpMethodToStr;
begin
  CheckEqual('GET', HttpMethodToStr(hmGet), 'GET');
  CheckEqual('HEAD', HttpMethodToStr(hmHead), 'HEAD');
  CheckEqual('POST', HttpMethodToStr(hmPost), 'POST');
  CheckEqual('PUT', HttpMethodToStr(hmPut), 'PUT');
  CheckEqual('DELETE', HttpMethodToStr(hmDelete), 'DELETE');
  CheckEqual('PATCH', HttpMethodToStr(hmPatch), 'PATCH');
  CheckEqual('OPTIONS', HttpMethodToStr(hmOptions), 'OPTIONS');
  CheckEqual('CONNECT', HttpMethodToStr(hmConnect), 'CONNECT');
  CheckEqual('TRACE', HttpMethodToStr(hmTrace), 'TRACE');
end;

{ Test 17: HttpStrToMethod all methods }
procedure TestHttpStrToMethod;
begin
  Check(HttpStrToMethod('GET') = hmGet, 'GET');
  Check(HttpStrToMethod('HEAD') = hmHead, 'HEAD');
  Check(HttpStrToMethod('POST') = hmPost, 'POST');
  Check(HttpStrToMethod('PUT') = hmPut, 'PUT');
  Check(HttpStrToMethod('DELETE') = hmDelete, 'DELETE');
  Check(HttpStrToMethod('PATCH') = hmPatch, 'PATCH');
  Check(HttpStrToMethod('OPTIONS') = hmOptions, 'OPTIONS');
  Check(HttpStrToMethod('CONNECT') = hmConnect, 'CONNECT');
  Check(HttpStrToMethod('TRACE') = hmTrace, 'TRACE');
end;

{ Test 18: HttpStatusText known codes }
procedure TestHttpStatusText;
begin
  CheckEqual('Continue', HttpStatusText(HTTP_STATUS_CONTINUE), '100');
  CheckEqual('Switching Protocols',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_SWITCHING_PROTOCOLS), '101 facade');
  CheckEqual('Early Hints',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_EARLY_HINTS), '103 facade');
  CheckEqual('OK', HttpStatusText(HTTP_STATUS_OK), '200');
  CheckEqual('Created', HttpStatusText(HTTP_STATUS_CREATED), '201');
  CheckEqual('See Other',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_SEE_OTHER), '303 facade');
  CheckEqual('Payload Too Large',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_PAYLOAD_TOO_LARGE), '413 facade');
  CheckEqual('Expectation Failed',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_EXPECTATION_FAILED), '417 facade');
  CheckEqual('Not Found', HttpStatusText(HTTP_STATUS_NOT_FOUND), '404');
  CheckEqual('Internal Server Error', HttpStatusText(HTTP_STATUS_INTERNAL_SERVER_ERROR), '500');
  CheckEqual('Not Implemented',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_NOT_IMPLEMENTED), '501 facade');
  CheckEqual('Request Header Fields Too Large',
    nextpas.core.http.HttpStatusText(
      nextpas.core.http.HTTP_STATUS_HEADER_TOO_LARGE), '431 facade');
  CheckEqual('Method Not Allowed', HttpStatusText(HTTP_STATUS_METHOD_NOT_ALLOWED), '405');
  CheckEqual('Bad Request', HttpStatusText(HTTP_STATUS_BAD_REQUEST), '400');
end;

procedure TestHttpStatusClassHelpersThroughFacade;
begin
  Check(nextpas.core.http.HttpStatusIsInformational(HTTP_STATUS_CONTINUE),
    'facade informational');
  Check(nextpas.core.http.HttpStatusIsSuccess(HTTP_STATUS_OK),
    'facade success');
  Check(nextpas.core.http.HttpStatusIsRedirect(HTTP_STATUS_FOUND),
    'facade redirect');
  Check(nextpas.core.http.HttpStatusIsClientError(HTTP_STATUS_NOT_FOUND),
    'facade client error');
  Check(nextpas.core.http.HttpStatusIsServerError(
    HTTP_STATUS_INTERNAL_SERVER_ERROR), 'facade server error');
  Check(not nextpas.core.http.HttpStatusIsSuccess(
    HTTP_STATUS_INTERNAL_SERVER_ERROR), 'facade success false for 500');
end;

procedure TestHttpWriteResponseStringThroughFacade;
var
  LW: IHttpResponseWriter;
  LRaised: Boolean;
begin
  LW := nil;
  LRaised := False;
  try
    nextpas.core.http.HttpWriteResponseString(LW, HTTP_STATUS_OK,
      'text/plain', 'hello');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'facade response string helper is visible');
end;

{ Test 19: IHttpTransport public contract shape }
procedure TestHttpTransportRoundTripContract;
var
  LObj: TMockHttpTransport;
  LTransport: IHttpTransport;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LObj := TMockHttpTransport.Create;
  LTransport := LObj;
  LReq := NewRequest(hmPost, TUrl.Parse('/transport?x=1'));
  LResp := LTransport.RoundTrip(LReq);
  Check(LObj.RoundTripCalled, 'RoundTrip was called');
  Check(LObj.SeenMethod = hmPost, 'RoundTrip receives request method');
  CheckEqual('/transport', LObj.SeenPath, 'RoundTrip receives request path');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'RoundTrip returns response');
  CheckEqual('mock', LResp.Headers.Get('x-transport'), 'RoundTrip response headers');
end;

{ Test 20: IHttpServerTransport public contract shape }
procedure TestHttpServerTransportServeConnContract;
var
  LObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LHandlerCalled: Boolean;
  LOwnership: TTcpServerConnOwnership;
begin
  LObj := TMockServerTransport.Create;
  LTransport := LObj;
  LHandlerCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    Check(AReq.Method = hmGet, 'ServeConn passes request method');
    CheckEqual('/transport', AReq.Url.Path, 'ServeConn passes request path');
  end);
  LOwnership := LTransport.ServeConn(nil, LHandler);
  Check(LObj.ServeConnCalled, 'ServeConn was called');
  Check(LHandlerCalled, 'ServeConn can dispatch handler');
  Check(LOwnership = TCP_SERVER_CONN_OWNERSHIP_SERVER,
    'ServeConn returns server ownership when handler does not detach');
end;

{ Test 21: IHttpHijacker is exported by facade }
procedure TestHttpHijackerFacadeAlias;
var
  LHijacker: IHttpHijacker;
begin
  LHijacker := nil;
  Check(LHijacker = nil, 'IHttpHijacker type is available through facade');
end;

procedure TestHttpServerRejectsNilHandler;
var
  LOptions: THttpServerOptions;
  LRaised: Boolean;
  LHandler: IHttpHandler;
  LServer: IHttpServer;
begin
  LOptions := THttpServerOptions.Default;
  LHandler := nil;

  LRaised := False;
  try
    THttpServer.Create(LHandler, LOptions).Free;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'THttpServer.Create rejects nil handler');

  LRaised := False;
  try
    LServer := NewHttpServer(LHandler);
    LServer := nil;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'NewHttpServer rejects nil handler');
end;

procedure TestHttpServerOptionsRejectNegativeValues;
var
  LOptions: THttpServerOptions;

  procedure CheckRejects(const AOptions: THttpServerOptions;
    const ALabel: string; const AUseInjectedTransport: Boolean = False);
  var
    LHandler: IHttpHandler;
    LTransport: IHttpServerTransport;
    LRaised: Boolean;
  begin
    LHandler := HandlerFunc(procedure(const AReq: IHttpRequest;
      const AW: IHttpResponseWriter)
    begin
    end);
    if AUseInjectedTransport then
      LTransport := TMockServerTransport.Create
    else
      LTransport := nil;

    LRaised := False;
    try
      if AUseInjectedTransport then
        NewHttpServer(LHandler, LTransport, AOptions)
      else
        NewHttpServer(LHandler, AOptions);
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, ALabel);
  end;

begin
  LOptions := THttpServerOptions.Default;
  LOptions.ReadTimeout := -1;
  CheckRejects(LOptions, 'negative server read timeout raises EArgumentError');

  LOptions := THttpServerOptions.Default;
  LOptions.WriteTimeout := -1;
  CheckRejects(LOptions, 'negative server write timeout raises EArgumentError');

  LOptions := THttpServerOptions.Default;
  LOptions.IdleTimeout := -1;
  CheckRejects(LOptions, 'negative server idle timeout raises EArgumentError');

  LOptions := THttpServerOptions.Default;
  LOptions.MaxHeaderSize := -1;
  CheckRejects(LOptions, 'negative server max header size raises EArgumentError');

  LOptions := THttpServerOptions.Default;
  LOptions.MaxBodySize := -1;
  CheckRejects(LOptions, 'negative server max body size raises EArgumentError',
    True);
end;

procedure TestHttpServerLifecycleContractOnInterface;
var
  LHandler: IHttpHandler;
  LServer: IHttpServer;
  LAddr: TNetAddress;
begin
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
  end);

  LServer := NewHttpServer(LHandler);
  Check(LServer <> nil, 'NewHttpServer returns IHttpServer contract');
  Check(not LServer.IsRunning, 'IHttpServer reports not running before listen');

  LAddr := LServer.LocalAddr;
  CheckEqual('0.0.0.0', LAddr.IP,
    'IHttpServer.LocalAddr uses any-address placeholder before listen');
  CheckEqual(Int64(0), Int64(LAddr.Port),
    'IHttpServer.LocalAddr uses port 0 before listen');

  LServer.Shutdown;
  Check(not LServer.IsRunning,
    'IHttpServer.Shutdown remains safe before listen');
end;

procedure TestHttpServerHonorsExplicitBackendSelection;
var
  LOptions: THttpServerOptions;
  LRaised: Boolean;
  LHandler: IHttpHandler;
  LServer: IHttpServer;
begin
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
  end);
  LOptions := THttpServerOptions.Default;
  {$IFDEF WINDOWS}
  LOptions.Backend := TCP_SERVER_BACKEND_KQUEUE;
  {$ELSE}
  LOptions.Backend := TCP_SERVER_BACKEND_IOCP;
  {$ENDIF}

  LRaised := False;
  try
    THttpServer.Create(LHandler, LOptions).Free;
  except
    on E: ENotSupportedError do
      LRaised := True;
  end;
  Check(LRaised, 'THttpServer.Create forwards explicit backend selection');

  LRaised := False;
  try
    LServer := NewHttpServer(LHandler, LOptions);
    LServer := nil;
  except
    on E: ENotSupportedError do
      LRaised := True;
  end;
  Check(LRaised, 'NewHttpServer(handler, options) forwards explicit backend selection');
end;

procedure TestHttpServerFacadeOwnerBoundarySourceContract;
var
  LSource: string;
begin
  LSource := ReadTextFile('../../../src/nextpas.core.http.server.pas');

  Check(SourceHas(LSource,
    'THttpConnHandler = class(TInterfacedObject, ITcpServerHandler,'#10 +
    '    ITcpServerSessionFactory, ITcpServerSessionFactoryWithContext)'),
    'HTTP connection handler stays a TCP server handler/session bridge');
  Check(SourceHas(LSource,
    'if Supports(Transport, IHttpServerSessionFactoryWithContext, LContextFactory) then'),
    'HTTP server prefers context-aware transport session factory');
  Check(SourceHas(LSource,
    'Result := THttpConnSession.Create(Transport, Handler, AConn);'),
    'HTTP server keeps legacy ServeConn fallback behind a session object');

  Check(SourceHas(LSource, 'LTcpOptions := TTcpServerOptions.Default;'),
    'HTTP server starts from TCP server default options');
  Check(SourceHas(LSource, 'LTcpOptions.Backend := AOptions.Backend;'),
    'HTTP server forwards backend selection to TCP server options');
  Check(SourceHas(LSource, 'FTcpServer := NewTcpServer(LTcpOptions);'),
    'HTTP server creates runtime through the TCP server facade');

  Check(SourceHas(LSource,
    'FTcpServer.ListenAndServe(AAddr, APort, FConnHandler);'),
    'HTTP ListenAndServe delegates listener ownership to TCP server');
  Check(SourceHas(LSource, 'FTcpServer.Shutdown;'),
    'HTTP Shutdown delegates lifecycle ownership to TCP server');
  Check(SourceHas(LSource, 'Result := FTcpServer.LocalAddr'),
    'HTTP LocalAddr delegates address truth to TCP server');
  Check(SourceHas(LSource,
    'Result := (FTcpServer <> nil) and FTcpServer.IsRunning;'),
    'HTTP IsRunning delegates runtime truth to TCP server');
end;

procedure TestHttpArchitectureDocsCurrentPublicApiContract;
var
  LSource: string;
begin
  LSource := ReadTextFile('../../../docs/http/ARCHITECTURE.md');

  Check(not SourceHas(LSource,
    '支持 HTTP/1.1、HTTP/2、HTTP/3 三个版本'),
    'architecture docs must not imply built-in H2/H3 implementation');
  Check(SourceHas(LSource, '当前内建实现为 HTTP/1.1'),
    'architecture docs must state built-in H1 truth');
  Check(SourceHas(LSource, 'H2/H3 仅保留版本枚举、registry / transport seam 与规划'),
    'architecture docs must state H2/H3 seam-only truth');

  Check(not SourceHas(LSource, 'procedure Group('),
    'architecture docs must not document nonexistent router Group API');
  Check(SourceHas(LSource, 'procedure Get(const APattern: string;'),
    'architecture docs must include router verb helper truth');
  Check(SourceHas(LSource, 'procedure Trace(const APattern: string;'),
    'architecture docs must include full router verb helper truth');

  Check(not SourceHas(LSource, '    Query: string;'),
    'architecture docs must not use obsolete TUrl.Query field');
  Check(SourceHas(LSource, 'UserInfo: string;'),
    'architecture docs must include current TUrl.UserInfo field');
  Check(SourceHas(LSource, 'RawQuery: string;'),
    'architecture docs must include current TUrl.RawQuery field');
  Check(SourceHas(LSource, 'ParseRequestTarget'),
    'architecture docs must include request-target parse seam');
  Check(SourceHas(LSource, 'HostPort'),
    'architecture docs must include current TUrl.HostPort helper');
  Check(SourceHas(LSource, 'property Version: THttpVersion read GetVersion;'),
    'architecture docs must include handler-visible request version');
  Check(SourceHas(LSource, 'property ContentLength: Int64 read GetContentLength;'),
    'architecture docs must include handler-visible content length');
  Check(SourceHas(LSource, 'property RemoteAddr: string read GetRemoteAddr;'),
    'architecture docs must include handler-visible remote address');
end;

procedure TestHttpApiCoverageResponseBodyHelperTruthContract;
var
  LSource: string;
begin
  LSource := ReadTextFile('../../../docs/http/API_COVERAGE.md');

  Check(not SourceHas(LSource, '只消费不自动 close'),
    'API coverage must not claim read helpers leave body open');
  Check(SourceHas(LSource,
    'HttpReadResponseBodyString` / `HttpReadResponseBodyBytes` 会消费并释放 body'),
    'API coverage must state response read helpers release body');
  Check(SourceHas(LSource,
    'HttpReleaseResponseBody` 只用于调用方决定不读取 body 时显式释放'),
    'API coverage must state release helper ownership boundary');
end;

procedure TestHttpApiCoverageRouterHeadFallbackTruthContract;
var
  LSource: string;
begin
  LSource := ReadTextFile('../../../docs/http/API_COVERAGE.md');

  Check(SourceHas(LSource, 'HEAD fallback to GET route'),
    'API coverage must document router HEAD fallback to GET');
  Check(SourceHas(LSource, 'explicit HEAD route wins'),
    'API coverage must document explicit HEAD route precedence');
  Check(SourceHas(LSource, '405 Allow includes implicit HEAD'),
    'API coverage must document implicit HEAD in Allow');
end;

procedure TestHttpApiCoverageNoBodyTransferEncodingTruthContract;
var
  LSource: string;
begin
  LSource := ReadTextFile('../../../docs/http/API_COVERAGE.md');

  Check(SourceHas(LSource, 'strips preset chunked `Transfer-Encoding`'),
    'API coverage must document no-body preset transfer-encoding strip');
  Check(SourceHas(LSource, 'no-body / informational wire output'),
    'API coverage must document response writer no-body/informational wire boundary');
end;

procedure TestHttpFacadeHelperSourceContract;
var
  LFacadeSource: string;
begin
  LFacadeSource := ReadTextFile('../../../src/nextpas.core.http.pas');

  Check(SourceHas(LFacadeSource,
    'TStringArray = nextpas.core.http.intf.TStringArray;'),
    'HTTP facade must re-export header value array type');
  Check(SourceHas(LFacadeSource,
    'TMiddlewareWrapFunc = nextpas.core.http.middleware.TMiddlewareWrapFunc;'),
    'HTTP facade must re-export middleware wrap callback type');
  Check(SourceHas(LFacadeSource,
    'TCorsOptions = nextpas.core.http.middleware.cors.TCorsOptions;'),
    'HTTP facade must re-export CORS options type');
  Check(SourceHas(LFacadeSource,
    'function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;'),
    'HTTP facade must expose MiddlewareFunc helper');
  Check(SourceHas(LFacadeSource,
    'function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;'),
    'HTTP facade must expose CorsMiddleware helper');
  Check(SourceHas(LFacadeSource,
    'function RecoveryMiddleware: IHttpMiddleware;'),
    'HTTP facade must expose RecoveryMiddleware helper');
  Check(SourceHas(LFacadeSource,
    'function QueryParamValue(const AParams: TQueryParams; const AName: string): string;'),
    'HTTP facade must expose QueryParamValue helper');
  Check(SourceHas(LFacadeSource,
    'function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean;'),
    'HTTP facade must expose QueryParamHas helper');
end;

procedure TestHttpPublicHeaderSetterNamingContract;
var
  LInterfaceSource: string;
  LFacadeSource: string;
  LApiCoverageSource: string;
begin
  LInterfaceSource := ReadTextFile('../../../src/nextpas.core.http.intf.pas');
  LFacadeSource := ReadTextFile('../../../src/nextpas.core.http.pas');
  LApiCoverageSource := ReadTextFile('../../../docs/http/API_COVERAGE.md');

  Check(SourceHas(LInterfaceSource,
    'procedure SetHeader(const AName, AValue: string);'),
    'IHttpHeaders must expose SetHeader spelling');
  Check(SourceHas(LApiCoverageSource, 'SetHeader'),
    'API coverage must document SetHeader spelling');
  CheckSourceDoesNotUseLegacyHeaderSetterSpelling(LInterfaceSource,
    'HTTP interface source');
  CheckSourceDoesNotUseLegacyHeaderSetterSpelling(LFacadeSource,
    'HTTP facade source');
  CheckSourceDoesNotUseLegacyHeaderSetterSpelling(LApiCoverageSource,
    'HTTP API coverage');
end;

procedure TestChunkedRequestTrailerContract;
var
  LRouter: IHttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerValue: string;
const
  REQ =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Trailer: X-Test'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Test: value'#13#10#13#10;
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  LGotTrailerValue := '';
  LRouter := NewRouter;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
    LRespBody: string;
  begin
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;
    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerValue := AReq.Headers.Get('X-Test');

    LRespBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LRespBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LRespBody[1], SizeUInt(Length(LRespBody)));
  end);

  LHandle := StartServerWithTransport(LRouter as IHttpHandler, nil, LServer, LPort);
  try
    LResp := SendRawRequestAndReadAll(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0,
      'Chunked trailer contract returns 200');
    Check(Pos('ok', LResp) > 0,
      'Chunked trailer contract preserves response body');
    CheckEqual('hello', LGotBody,
      'Chunked trailer contract decodes chunked body');
    CheckEqual('X-Test', LGotTrailerDecl,
      'Chunked trailer contract preserves declaration header');
    CheckEqual('', LGotTrailerValue,
      'Chunked trailer contract hides trailer field from ordinary headers');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestChunkedRequestMultipleTrailerDeclarationContract;
var
  LRouter: IHttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LResp: string;
  LGotBody: string;
  LGotTrailerDecl: string;
  LGotTrailerDeclValues: TStringArray;
  LGotTraceValue: string;
  LGotAuthValue: string;
  LGotTraceValues: TStringArray;
  LGotAuthValues: TStringArray;
  LHasTrace: Boolean;
  LHasAuth: Boolean;
const
  REQ =
    'POST /upload HTTP/1.1'#13#10 +
    'Host: localhost'#13#10 +
    'Connection: close'#13#10 +
    'Transfer-Encoding: chunked'#13#10 +
    'Trailer: X-Trace, X-Auth-Context'#13#10#13#10 +
    '5'#13#10'hello'#13#10 +
    '0'#13#10 +
    'X-Trace: abc123'#13#10 +
    'X-Auth-Context: role=admin'#13#10#13#10;
begin
  LGotBody := '';
  LGotTrailerDecl := '';
  SetLength(LGotTrailerDeclValues, 0);
  LGotTraceValue := '';
  LGotAuthValue := '';
  SetLength(LGotTraceValues, 0);
  SetLength(LGotAuthValues, 0);
  LHasTrace := False;
  LHasAuth := False;
  LRouter := NewRouter;
  LRouter.Post('/upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBuf: array[0..15] of Byte;
    LN: SizeUInt;
    LBody: string;
    LRespBody: string;
  begin
    LBody := '';
    if AReq.Body <> nil then
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN > 0 then
        begin
          SetLength(LBody, Length(LBody) + Int32(LN));
          Move(LBuf[0], LBody[Length(LBody) - Int32(LN) + 1], LN);
        end;
      until LN = 0;

    LGotBody := LBody;
    LGotTrailerDecl := AReq.Headers.Get('Trailer');
    LGotTrailerDeclValues := AReq.Headers.GetAll('Trailer');
    LGotTraceValue := AReq.Headers.Get('X-Trace');
    LGotAuthValue := AReq.Headers.Get('X-Auth-Context');
    LGotTraceValues := AReq.Headers.GetAll('X-Trace');
    LGotAuthValues := AReq.Headers.GetAll('X-Auth-Context');
    LHasTrace := AReq.Headers.Has('X-Trace');
    LHasAuth := AReq.Headers.Has('X-Auth-Context');

    LRespBody := 'ok';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LRespBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LRespBody[1], SizeUInt(Length(LRespBody)));
  end);

  LHandle := StartServerWithTransport(LRouter as IHttpHandler, nil, LServer, LPort);
  try
    LResp := SendRawRequestAndReadAll(LPort, REQ);
    Check(Pos('200 OK', LResp) > 0,
      'Chunked multiple trailer declaration contract returns 200');
    CheckEqual('hello', LGotBody,
      'Chunked multiple trailer declaration contract decodes chunked body');
    CheckEqual('X-Trace, X-Auth-Context', LGotTrailerDecl,
      'Chunked multiple trailer declaration contract preserves declaration header');
    CheckEqual(Int64(1), Int64(Length(LGotTrailerDeclValues)),
      'Chunked multiple trailer declaration contract keeps one declaration entry');
    CheckEqual('X-Trace, X-Auth-Context', LGotTrailerDeclValues[0],
      'Chunked multiple trailer declaration contract preserves declaration entry text');
    CheckEqual('', LGotTraceValue,
      'Chunked multiple trailer declaration contract hides trace trailer field');
    CheckEqual('', LGotAuthValue,
      'Chunked multiple trailer declaration contract hides auth trailer field');
    CheckEqual(Int64(0), Int64(Length(LGotTraceValues)),
      'Chunked multiple trailer declaration contract exposes no trace trailer values');
    CheckEqual(Int64(0), Int64(Length(LGotAuthValues)),
      'Chunked multiple trailer declaration contract exposes no auth trailer values');
    Check(not LHasTrace,
      'Chunked multiple trailer declaration contract does not report hidden trace trailer field');
    Check(not LHasAuth,
      'Chunked multiple trailer declaration contract does not report hidden auth trailer field');
  finally
    StopServer(LServer, LHandle);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.http.contract');
  T.Run('NewHeaders: Set/Get/Has/Remove/Count/Clone', @TestNewHeaders);
  T.Run('Auth helpers are available through facade',
    @TestAuthHelpersAvailableThroughFacade);
  T.Run('Header value array is available through facade',
    @TestHeaderValuesArrayAvailableThroughFacade);
  T.Run('NewRouter: Get route + FindRoute', @TestNewRouter);
  T.Run('IHttpRouter convenience methods are callable through interface', @TestRouterConvenienceMethodsOnInterface);
  T.Run('NewRequest: Method/Url/Version', @TestNewRequest);
  T.Run('NewRequest headers/body overload is available through facade',
    @TestNewRequestWithHeadersFacadeOverload);
  T.Run('NewRequest rejects conflicting content-length through facade',
    @TestNewRequestRejectsConflictingContentLengthThroughFacade);
  T.Run('NewRequest headers-only overload is available through facade',
    @TestNewRequestHeadersOnlyFacadeOverload);
  T.Run('NewRequest nil third argument stays source-compatible through facade',
    @TestNewRequestNilThirdArgumentFacadeCompatibility);
  T.Run('NewRequest string URL overloads are available through facade',
    @TestNewRequestStringUrlFacadeOverloads);
  T.Run('NewRequest no-headers body overloads are available through facade',
    @TestNewRequestNoHeadersBodyFacadeOverloads);
  T.Run('NewRequest content-type body overloads are available through facade',
    @TestNewRequestContentTypeBodyFacadeOverloads);
  T.Run('HttpClient shortcut body overloads are available through facade',
    @TestHttpClientShortcutBodyFacadeOverloads);
  T.Run('HttpClient CloseIdleConnections is available through facade',
    @TestHttpClientCloseIdleConnectionsFacadeMethod);
  T.Run('NewResponse: StatusCode/Headers', @TestNewResponse);
  T.Run('NewResponse body overloads are available through facade',
    @TestNewResponseBodyFacadeOverloads);
  T.Run('HttpReadResponseBodyString is available through facade',
    @TestHttpReadResponseBodyStringFacadeHelper);
  T.Run('HttpReadResponseBodyBytes is available through facade',
    @TestHttpReadResponseBodyBytesFacadeHelper);
  T.Run('HttpReleaseResponseBody is available through facade',
    @TestHttpReleaseResponseBodyFacadeHelper);
  T.Run('HandlerFunc wraps correctly', @TestHandlerFuncWrap);
  T.Run('HandlerFunc wraps plain procedures through facade', @TestHandlerProcWrap);
  T.Run('HandlerFunc wraps object methods through facade', @TestHandlerMethodWrap);
  T.Run('Chain applies middleware', @TestChainMiddleware);
  T.Run('CORS middleware is available through facade',
    @TestCorsMiddlewareAvailableThroughFacade);
  T.Run('Recovery middleware is available through facade',
    @TestRecoveryMiddlewareAvailableThroughFacade);
  T.Run('NewHttpServer overloads are available through facade', @TestHttpServerFacadeOverloads);
  T.Run('NewHttpClient overloads are available through facade', @TestHttpClientFacadeOverloads);
  T.Run('Facade NewHttpClient consumes registered HTTP/2 registry default',
    @TestHttpClientFacadeUsesRegisteredHttp2RegistryDefault);
  T.Run('Injected client transport is used through facade client', @TestHttpClientTransportInjection);
  T.Run('Injected server transport is used through facade server', @TestHttpServerTransportInjection);
  T.Run('Facade NewHttpServer consumes registered HTTP/3 registry default',
    @TestHttpServerFacadeUsesRegisteredHttp3RegistryDefault);
  T.Run('Injected server transport session factory is preferred',
    @TestHttpServerTransportInjectionPrefersSessionFactory);
  T.Run('Injected server transport context session factory is preferred',
    @TestHttpServerTransportInjectionPrefersContextSessionFactory);
  T.Run('UrlEncode/UrlDecode round-trip', @TestUrlEncodeDecodeRoundTrip);
  T.Run('ParseQueryString basic', @TestParseQueryString);
  T.Run('EncodeQueryString round-trip', @TestEncodeQueryStringRoundTrip);
  T.Run('QueryParam helpers are available through facade',
    @TestQueryParamHelpersAvailableThroughFacade);
  T.Run('HttpMethodToStr all methods', @TestHttpMethodToStr);
  T.Run('HttpStrToMethod all methods', @TestHttpStrToMethod);
  T.Run('HttpStatusText known codes', @TestHttpStatusText);
  T.Run('HttpStatus class helpers are available through facade',
    @TestHttpStatusClassHelpersThroughFacade);
  T.Run('HttpWriteResponseString is available through facade',
    @TestHttpWriteResponseStringThroughFacade);
  T.Run('IHttpTransport RoundTrip contract shape', @TestHttpTransportRoundTripContract);
  T.Run('IHttpServerTransport ServeConn contract shape', @TestHttpServerTransportServeConnContract);
  T.Run('IHttpHijacker facade alias', @TestHttpHijackerFacadeAlias);
  T.Run('HttpServer rejects nil handler', @TestHttpServerRejectsNilHandler);
  T.Run('HttpServer options reject negative values',
    @TestHttpServerOptionsRejectNegativeValues);
  T.Run('IHttpServer lifecycle contract shape', @TestHttpServerLifecycleContractOnInterface);
  T.Run('HttpServer honors explicit backend selection',
    @TestHttpServerHonorsExplicitBackendSelection);
  T.Run('HttpServer facade owner-boundary source contract',
    @TestHttpServerFacadeOwnerBoundarySourceContract);
  T.Run('HTTP architecture docs current public API contract',
    @TestHttpArchitectureDocsCurrentPublicApiContract);
  T.Run('HTTP API coverage response body helper truth contract',
    @TestHttpApiCoverageResponseBodyHelperTruthContract);
  T.Run('HTTP API coverage router HEAD fallback truth contract',
    @TestHttpApiCoverageRouterHeadFallbackTruthContract);
  T.Run('HTTP API coverage no-body transfer-encoding truth contract',
    @TestHttpApiCoverageNoBodyTransferEncodingTruthContract);
  T.Run('HTTP facade helper source contract',
    @TestHttpFacadeHelperSourceContract);
  T.Run('HTTP public header setter naming contract',
    @TestHttpPublicHeaderSetterNamingContract);
  T.Run('Chunked request trailer contract',
    @TestChunkedRequestTrailerContract);
  T.Run('Chunked request multiple trailer declaration contract',
    @TestChunkedRequestMultipleTrailerDeclarationContract);
  T.Summary;
end.
