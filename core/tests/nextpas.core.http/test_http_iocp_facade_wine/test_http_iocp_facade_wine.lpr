program test_http_iocp_facade_wine;
{**
 * @desc HTTP product facade over IOCP: THttpServer (full nextpas.core.http
 *       facade) with Backend=tsbIocp serves real HTTP/1.1 GET + keep-alive
 *       on Windows. End-to-end product evidence — completion-vs-worker path
 *       attribution stays with the net-layer wire suite (test_http_iocp_wine).
 *       The uses clause itself gates "full facade cross-compiles to Win64"
 *       (former CONTRACT residual: TLS chain FPC internal error — resolved).
 *       Non-Windows hosts run the skip branch (assert tsbIocp factory absent).
 *       truth tier depends on the executor: wine-runtime-smoke via
 *       `make wine-runtime-smoke`, host-windows via
 *       scripts/http-host-ci-matrix.sh on a real Windows CI host.
 *       Never Windows scale-ready evidence.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.server.base,
  nextpas.core.net.server,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: IHttpServer;
    Addr: string;
    Port: UInt16;
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
    { ListenAndServe exits on Shutdown }
  end;
  Dispose(LCtx);
end;

function StartIocpFacadeServer(out AServer: IHttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LOpts: THttpServerOptions;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  LOpts := THttpServerOptions.Default;
  LOpts.Backend := TCP_SERVER_BACKEND_IOCP;
  AServer := NewHttpServer(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LB: string;
    begin
      LB := 'iocp-facade-ok';
      AW.GetHeaders.SetHeader('content-length', IntToStr(Length(LB)));
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LB[1], SizeUInt(Length(LB)));
    end),
    LOpts);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0; { OS picks a free port }
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000); { 5ms }
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'facade IOCP server started');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'OS assigned port');
  Result := LHandle;
end;

procedure StopServer(var AServer: IHttpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function ReadUntilMarker(const AConn: ITcpStream; const AMarker: string;
  var AAcc: string): Boolean;
var
  LBuf: array[0..2047] of Byte;
  LN: SizeUInt;
begin
  Result := Pos(AMarker, AAcc) > 0;
  while not Result do
  begin
    LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN = 0 then
      Exit;
    SetLength(AAcc, Length(AAcc) + Int32(LN));
    Move(LBuf[0], AAcc[Length(AAcc) - Int32(LN) + 1], LN);
    Result := Pos(AMarker, AAcc) > 0;
  end;
end;

function ReadToEof(const AConn: ITcpStream; var AAcc: string): SizeInt;
var
  LBuf: array[0..2047] of Byte;
  LN: SizeUInt;
begin
  Result := 0;
  repeat
    LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN = 0 then
      Break;
    SetLength(AAcc, Length(AAcc) + Int32(LN));
    Move(LBuf[0], AAcc[Length(AAcc) - Int32(LN) + 1], LN);
    Inc(Result, SizeInt(LN));
  until False;
end;

procedure TestIocpFacadeFactoryRegistered;
begin
  Check(HasTcpServerFactory(TCP_SERVER_BACKEND_IOCP),
    'Windows registers built-in tsbIocp factory');
end;

procedure TestIocpFacadeGetOk;
var
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LReq, LResp: string;
begin
  LHandle := StartIocpFacadeServer(LServer, LPort);
  try
    LConn := NetTcpConnect('127.0.0.1', LPort);
    try
      LReq :=
        'GET / HTTP/1.1'#13#10 +
        'Host: 127.0.0.1'#13#10 +
        'Connection: close'#13#10 +
        #13#10;
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LResp := '';
      ReadToEof(LConn, LResp);
    finally
      LConn.Close;
    end;
    Check(Pos('HTTP/1.1 200', LResp) = 1, 'facade status line 200');
    Check(Pos('iocp-facade-ok', LResp) > 0, 'facade body served over IOCP');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestIocpFacadeKeepAliveTwoGets;
var
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LConn: ITcpStream;
  LReq, LFirst, LSecond: string;
  LCount, LAt: SizeInt;
begin
  LHandle := StartIocpFacadeServer(LServer, LPort);
  try
    LConn := NetTcpConnect('127.0.0.1', LPort);
    try
      LReq :=
        'GET / HTTP/1.1'#13#10 +
        'Host: 127.0.0.1'#13#10 +
        'Connection: keep-alive'#13#10 +
        #13#10;
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LFirst := '';
      Check(ReadUntilMarker(LConn, 'iocp-facade-ok', LFirst),
        'first keep-alive response arrived');
      Check(Pos('HTTP/1.1 200', LFirst) = 1, 'first status 200');

      { second request on the same product H1 connection }
      LReq :=
        'GET / HTTP/1.1'#13#10 +
        'Host: 127.0.0.1'#13#10 +
        'Connection: close'#13#10 +
        #13#10;
      LConn.Write(LReq[1], SizeUInt(Length(LReq)));
      LSecond := LFirst;
      ReadToEof(LConn, LSecond);
    finally
      LConn.Close;
    end;
    LCount := 0;
    LAt := Pos('iocp-facade-ok', LSecond);
    while LAt > 0 do
    begin
      Inc(LCount);
      LAt := Pos('iocp-facade-ok', LSecond, LAt + 1);
    end;
    Check(LCount >= 2, 'two bodies served on one keep-alive connection');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('IOCP facade smoke is Windows/Wine only; host=',
    {$IFDEF NEXTPAS_LINUX}'linux'{$ELSE}'other'{$ENDIF});
  Check(not HasTcpServerFactory(TCP_SERVER_BACKEND_IOCP),
    'non-Windows host must not register built-in tsbIocp factory');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.http.iocp_facade_wine_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('IOCP factory registered', @TestIocpFacadeFactoryRegistered);
  T.Test('facade THttpServer GET over tsbIocp', @TestIocpFacadeGetOk);
  T.Test('facade keep-alive two GETs over tsbIocp',
    @TestIocpFacadeKeepAliveTwoGets);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then
    Halt(1);
end.
