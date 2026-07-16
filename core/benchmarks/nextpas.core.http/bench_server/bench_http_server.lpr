program bench_http_server;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.thread.init,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.errors,
  nextpas.core.os.env,
  nextpas.core.text.conv,
  nextpas.core.http.base, nextpas.core.http.intf, nextpas.core.http.server,
  nextpas.core.http.middleware, nextpas.core.net, nextpas.core.net.intf,
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.platform.thread, nextpas.core.platform.time;
const
  SMALL_RESPONSE = 'Hello, World!';
  BENCH_BACKEND_ENV = 'NEXTPAS_BENCH_BACKEND';
var
  GServer: THttpServer;
  GServerThreadHandle: TPlatformThreadHandle;
  GServerThreadStarted: Boolean;
  GPort: UInt16;
  GBackend: TTcpServerBackend;
  GSink: UInt64;
function ConfiguredBackend: TTcpServerBackend;
var LValue: string;
begin
  LValue := Trim(GetEnvironmentVariable(BENCH_BACKEND_ENV));
  if (LValue = '') or (LValue = 'threaded') then Exit(TCP_SERVER_BACKEND_THREADED);
  if LValue = 'epoll' then Exit(TCP_SERVER_BACKEND_EPOLL);
  Halt(2);
end;
function ServerThread(AParam: Pointer): Pointer; cdecl;
begin Result := nil; GServer.ListenAndServe('127.0.0.1', 0); end;
procedure StopServer;
var LThreadResult: Pointer;
begin
  if GServer <> nil then GServer.Shutdown;
  if GServerThreadStarted then begin platform_thread_join(GServerThreadHandle, LThreadResult); GServerThreadStarted := False; end;
  if GServer <> nil then begin GServer.Free; GServer := nil; end;
end;
function WaitForServerReady: Boolean;
var LStartNs, LTimeoutNs: UInt64;
begin
  LStartNs := platform_monotonic_ns; LTimeoutNs := 5000 * 1000000;
  while not GServer.IsRunning do begin if platform_monotonic_ns - LStartNs >= LTimeoutNs then Exit(False); platform_thread_sleep_ns(1000000); end;
  Result := True;
end;
procedure SetupServer;
var LOptions: THttpServerOptions;
begin
  LOptions := THttpServerOptions.Default; LOptions.Backend := GBackend;
  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain');
      AW.GetHeaders.SetHeader('content-length', '13');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(SMALL_RESPONSE[1], 13);
    end), LOptions);
  GServerThreadStarted := platform_thread_create(GServerThreadHandle, @ServerThread, nil) = 0;
  if not GServerThreadStarted then begin StopServer; raise Exception.Create('server thread failed'); end;
  if not WaitForServerReady then begin StopServer; raise Exception.Create('server not ready'); end;
  GPort := GServer.LocalAddr.Port;
end;
var GConn: ITcpStream;
procedure BenchHelloWorld(const ACtx: IBenchContext);
var LReq: string; LBuf: array[0..4095] of Byte; LN: SizeUInt;
begin
  LReq := 'GET / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
  GConn.Write(LReq[1], SizeUInt(Length(LReq)));
  repeat LN := GConn.Read(LBuf[0], SizeOf(LBuf)); GSink := GSink xor UInt64(LN); until LN = 0;
  ACtx.SetBytes(13);
end;
var LSuite: IBenchSuite;
begin
  GBackend := ConfiguredBackend; GSink := 0;
  SetupServer;
  try
    GConn := TcpConnect('127.0.0.1', GPort);
    GConn.SetNoDelay(True);
    GConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(30)));
    LSuite := TBenchSuite.Create('http-server');
    LSuite.Add('HelloWorld', @BenchHelloWorld);
    WriteLn(LSuite.Run.PrintToConsole);
    GConn.Close;
  finally
    StopServer;
  end;
end.
