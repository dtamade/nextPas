program bench_fullchain;
{**
 * @desc Full-chain HTTP benchmark — measures complete request-response cycle:
 *       TCP accept, parse, route, handler, serialize, write, client read.
 *       Single connection, keep-alive, reports req/s per scenario.
 *}
{$I nextpas.core.settings.inc}
uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.middleware,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;
const
  DEFAULT_ITERATIONS = 5000;
  BENCH_MAX_ITERS_ENV = 'NEXTPAS_BENCH_MAX_ITERS';
  BENCH_FILTER_ENV = 'NEXTPAS_BENCH_FILTER';
  BENCH_BACKEND_ENV = 'NEXTPAS_BENCH_BACKEND';
  BENCH_BACKEND_THREADED = 'threaded';
  BENCH_BACKEND_EPOLL = 'epoll';
  BENCH_SERVER_READY_TIMEOUT_MS = 5000;
  ROUTER_HOST = 'router';
  DIRECT_HOST = 'direct';
  DIRECT_1K_HOST = 'direct-1k';
  MIDDLEWARE_HOST = 'middleware';
type
  TScenarioResult = record
    Completed: Int64; ValidationFailures: Int64; DispatchFailures: Int64;
    ElapsedNs: UInt64; NsPerOp: Double; ReqPerSec: Double;
  end;
  TFullchainResponseRead = record
    BytesRead: SizeUInt; StatusCode: Int32; ContentLength: Int64;
    BodyBytes: SizeUInt; Complete: Boolean;
  end;
var
  GServer: THttpServer;
  GServerThreadHandle: TPlatformThreadHandle;
  GServerThreadStarted: Boolean;
  GPort: UInt16;
  GIterations: Int64;
  GFilter: string;
  GBackend: TTcpServerBackend;
  GDirectHandlerHits: Int64;
  GRouterHandlerHits: Int64;
  GMiddlewareHits: Int64;
  GDirectPlaintextReq: string;
  GDirect1KReq: string;
  GMiddlewareReq: string;
  GPlaintextReq: string;
  GJsonReq: string;
  GEchoReq: string;
  GSinkReq: string;
  GParamReq: string;
  GBody1K: string;
  GBody16K: string;
procedure WritePlaintextResponse(const AW: IHttpResponseWriter);
begin
  AW.GetHeaders.SetHeader('content-type', 'text/plain');
  AW.GetHeaders.SetHeader('content-length', '13');
  AW.WriteHeader(HTTP_STATUS_OK);
  AW.Write(PAnsiChar('Hello, World!')^, 13);
end;
procedure WriteBody1KResponse(const AW: IHttpResponseWriter; const ABody1K: string);
begin
  AW.GetHeaders.SetHeader('content-type', 'application/octet-stream');
  AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(ABody1K))));
  AW.WriteHeader(HTTP_STATUS_OK);
  AW.Write(ABody1K[1], SizeUInt(Length(ABody1K)));
end;
function ConfiguredIterations: Int64;
var LValue: string;
begin
  LValue := Trim(GetEnvironmentVariable(BENCH_MAX_ITERS_ENV));
  if LValue = '' then Exit(DEFAULT_ITERATIONS);
  if (not TryStrToInt64(LValue, Result)) or (Result <= 0) then begin WriteLn(StdErr, 'invalid ', BENCH_MAX_ITERS_ENV); Halt(2); end;
end;
function ConfiguredFilter: string;
begin Result := Trim(GetEnvironmentVariable(BENCH_FILTER_ENV)); end;
function ConfiguredBackend: TTcpServerBackend;
var LValue: string;
begin
  LValue := Trim(GetEnvironmentVariable(BENCH_BACKEND_ENV));
  if (LValue = '') or (LValue = BENCH_BACKEND_THREADED) then Exit(TCP_SERVER_BACKEND_THREADED);
  if LValue = BENCH_BACKEND_EPOLL then Exit(TCP_SERVER_BACKEND_EPOLL);
  Halt(2);
end;
function BackendName: string;
begin
  case GBackend of
    TCP_SERVER_BACKEND_THREADED: Result := BENCH_BACKEND_THREADED;
    TCP_SERVER_BACKEND_EPOLL: Result := BENCH_BACKEND_EPOLL;
  else Result := 'unknown'; end;
end;
function ServerThread(AParam: Pointer): Pointer; cdecl;
begin Result := nil; GServer.ListenAndServe('127.0.0.1', 0); end;
procedure StopServer;
var LThreadResult: Pointer;
begin
  if GServer <> nil then GServer.Shutdown;
  if GServerThreadStarted then begin platform_thread_join(GServerThreadHandle, LThreadResult); GServerThreadStarted := False; GServerThreadHandle := nil; end;
  if GServer <> nil then begin GServer.Free; GServer := nil; end;
end;
function WaitForServerReady: Boolean;
var LStartNs, LTimeoutNs: UInt64;
begin
  LStartNs := platform_monotonic_ns; LTimeoutNs := UInt64(BENCH_SERVER_READY_TIMEOUT_MS) * 1000000;
  while not GServer.IsRunning do begin if platform_monotonic_ns - LStartNs >= LTimeoutNs then Exit(False); platform_thread_sleep_ns(1000000); end;
  Result := True;
end;
procedure SetupServer;
var LRouter, LMiddlewareRouter: THttpRouter; LBody1K: string; LRouterHandler, LMiddlewareHandler: IHttpHandler; LServerOptions: THttpServerOptions;
begin
  SetLength(LBody1K, 1024); FillChar(LBody1K[1], 1024, Ord('x'));
  LServerOptions := THttpServerOptions.Default; LServerOptions.Backend := GBackend;
  LRouter := THttpRouter.Create; LRouterHandler := LRouter as IHttpHandler;
  LMiddlewareRouter := THttpRouter.Create; LMiddlewareHandler := LMiddlewareRouter as IHttpHandler;
  LMiddlewareRouter.Use(MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin Inc(GMiddlewareHits); ANext.ServeHTTP(AReq, AW); end);
  end));
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) begin WritePlaintextResponse(AW); end);
  LMiddlewareRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) begin WritePlaintextResponse(AW); end);
  LRouter.Get('/json', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  const BODY = '{"message":"Hello, World!"}';
  begin AW.GetHeaders.SetHeader('content-type', 'application/json'); AW.GetHeaders.SetHeader('content-length', '27'); AW.WriteHeader(HTTP_STATUS_OK); AW.Write(PAnsiChar(BODY)^, 27); end);
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN, LTotal: SizeUInt;
  begin
    LTotal := 0;
    if AReq.Body <> nil then begin repeat LN := AReq.Body.Read(LBuf[0], 4096); LTotal := LTotal + LN; until LN = 0; end;
    AW.GetHeaders.SetHeader('content-type', 'application/octet-stream'); AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(LTotal)));
    AW.WriteHeader(HTTP_STATUS_OK); if LTotal > 0 then AW.Write(LBuf[0], LTotal);
  end);
  LRouter.Post('/sink', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt;
  begin if AReq.Body <> nil then begin repeat LN := AReq.Body.Read(LBuf[0], SizeOf(LBuf)); until LN = 0; end; AW.GetHeaders.SetHeader('content-length', '0'); AW.WriteHeader(HTTP_STATUS_OK); end);
  LRouter.Get('/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin LBody := 'user:' + AReq.PathParam('id'); AW.GetHeaders.SetHeader('content-type', 'text/plain'); AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody)))); AW.WriteHeader(HTTP_STATUS_OK); AW.Write(LBody[1], SizeUInt(Length(LBody))); end);
  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if AReq.Headers.Get('host') = DIRECT_HOST then begin Inc(GDirectHandlerHits); WritePlaintextResponse(AW); Exit; end;
      if AReq.Headers.Get('host') = DIRECT_1K_HOST then begin Inc(GDirectHandlerHits); WriteBody1KResponse(AW, GBody1K); Exit; end;
      if AReq.Headers.Get('host') = MIDDLEWARE_HOST then begin Inc(GRouterHandlerHits); LMiddlewareHandler.ServeHTTP(AReq, AW); Exit; end;
      Inc(GRouterHandlerHits); LRouterHandler.ServeHTTP(AReq, AW);
    end), LServerOptions);
  GServerThreadStarted := platform_thread_create(GServerThreadHandle, @ServerThread, nil) = 0;
  if not GServerThreadStarted then begin StopServer; raise Exception.Create('server thread create failed'); end;
  if not WaitForServerReady then begin StopServer; raise Exception.Create('server did not become ready'); end;
  GPort := GServer.LocalAddr.Port;
end;
function TryParseStatusCode(const AResp: string; out AStatusCode: Int32): Boolean;
var LStatusValue: Int64;
begin
  AStatusCode := 0; Result := False;
  if (Length(AResp) < 12) or (Copy(AResp, 1, 9) <> 'HTTP/1.1 ') then Exit;
  if not TryStrToInt64(Copy(AResp, 10, 3), LStatusValue) then Exit;
  if (LStatusValue < 100) or (LStatusValue > 999) then Exit;
  AStatusCode := Int32(LStatusValue); Result := True;
end;
function TryParseContentLength(const AResp: string; const AHeaderEnd: SizeInt; out AContentLength: Int64): Boolean;
var LHeaders, LLowerHeaders: string; LClPos, LValueStart, LValueEnd: SizeInt;
begin
  AContentLength := -1; Result := False;
  if AHeaderEnd <= 0 then Exit;
  LHeaders := Copy(AResp, 1, AHeaderEnd - 1); LLowerHeaders := LowerCase(LHeaders);
  LClPos := Pos(#13#10'content-length:', LLowerHeaders);
  if LClPos = 0 then Exit;
  LValueStart := LClPos + Length(#13#10'content-length:');
  while (LValueStart <= Length(LHeaders)) and ((LHeaders[LValueStart] = ' ') or (LHeaders[LValueStart] = #9)) do Inc(LValueStart);
  LValueEnd := LValueStart;
  while (LValueEnd <= Length(LHeaders)) and (LHeaders[LValueEnd] >= '0') and (LHeaders[LValueEnd] <= '9') do Inc(LValueEnd);
  if LValueEnd = LValueStart then Exit;
  Result := TryStrToInt64(Copy(LHeaders, LValueStart, LValueEnd - LValueStart), AContentLength);
end;
function ResponseMatchesScenario(const AResponse: TFullchainResponseRead; const AResponseBodyBytes: SizeUInt): Boolean;
begin Result := AResponse.Complete and (AResponse.StatusCode = HTTP_STATUS_OK) and (AResponse.ContentLength = Int64(AResponseBodyBytes)) and (AResponse.BodyBytes = AResponseBodyBytes); end;
function ReadResponse(const AConn: ITcpStream): TFullchainResponseRead;
var LBuf: array[0..4095] of Byte; LN: SizeUInt; LHeaderEnd: SizeInt; LResp: string; LContentLen, LBodyRead, LNeed: Int64; LReadSize: SizeUInt;
  procedure AppendBytes(const ABuf; const ACount: SizeUInt);
  var LOld: SizeInt;
  begin if ACount = 0 then Exit; LOld := Length(LResp); SetLength(LResp, LOld + SizeInt(ACount)); Move(ABuf, LResp[LOld + 1], ACount); end;
begin
  Result.BytesRead := 0; Result.StatusCode := 0; Result.ContentLength := -1; Result.BodyBytes := 0; Result.Complete := False;
  LResp := ''; LHeaderEnd := 0;
  repeat LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf))); if LN = 0 then Exit; AppendBytes(LBuf[0], LN); Inc(Result.BytesRead, LN); LHeaderEnd := Pos(#13#10#13#10, LResp); until LHeaderEnd > 0;
  if not TryParseStatusCode(LResp, Result.StatusCode) then Exit;
  if not TryParseContentLength(LResp, LHeaderEnd, LContentLen) then Exit;
  if LContentLen < 0 then Exit;
  Result.ContentLength := LContentLen;
  LBodyRead := Length(LResp) - (LHeaderEnd + 3);
  while LBodyRead < LContentLen do begin LNeed := LContentLen - LBodyRead; if LNeed > SizeInt(SizeOf(LBuf)) then LReadSize := SizeUInt(SizeOf(LBuf)) else LReadSize := SizeUInt(LNeed); LN := AConn.Read(LBuf[0], LReadSize); if LN = 0 then Break; Inc(LBodyRead, Int64(LN)); Inc(Result.BytesRead, LN); end;
  if LBodyRead >= 0 then Result.BodyBytes := SizeUInt(LBodyRead);
  Result.Complete := LBodyRead = LContentLen;
end;
var
  GConn: ITcpStream;
  GSink: UInt64;
procedure BenchDirectPlaintext(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GDirectPlaintextReq[1], SizeUInt(Length(GDirectPlaintextReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(13); end;
procedure BenchDirect1K(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GDirect1KReq[1], SizeUInt(Length(GDirect1KReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(1024); end;
procedure BenchMiddlewareNoop(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GMiddlewareReq[1], SizeUInt(Length(GMiddlewareReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(13); end;
procedure BenchPlaintext(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GPlaintextReq[1], SizeUInt(Length(GPlaintextReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(13); end;
procedure BenchJson(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GJsonReq[1], SizeUInt(Length(GJsonReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(27); end;
procedure BenchEcho1K(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GEchoReq[1], SizeUInt(Length(GEchoReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(1024); end;
procedure BenchSink16K(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GSinkReq[1], SizeUInt(Length(GSinkReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(16384); end;
procedure BenchParamRoute(const ACtx: IBenchContext);
var LResp: TFullchainResponseRead;
begin GConn.Write(GParamReq[1], SizeUInt(Length(GParamReq))); LResp := ReadResponse(GConn); if LResp.Complete then GSink := GSink xor UInt64(LResp.BodyBytes); ACtx.SetBytes(Length('user:12345')); end;
var LSuite: IBenchSuite;
begin
  GIterations := ConfiguredIterations; GFilter := ConfiguredFilter; GBackend := ConfiguredBackend; GSink := 0;
  SetLength(GBody1K, 1024); FillChar(GBody1K[1], 1024, Ord('x'));
  SetLength(GBody16K, 16384); FillChar(GBody16K[1], 16384, Ord('x'));
  GDirectPlaintextReq := 'GET / HTTP/1.1'#13#10'Host: ' + DIRECT_HOST + #13#10'Content-Length: 0'#13#10#13#10;
  GDirect1KReq := 'GET / HTTP/1.1'#13#10'Host: ' + DIRECT_1K_HOST + #13#10'Content-Length: 0'#13#10#13#10;
  GMiddlewareReq := 'GET / HTTP/1.1'#13#10'Host: ' + MIDDLEWARE_HOST + #13#10'Content-Length: 0'#13#10#13#10;
  GPlaintextReq := 'GET / HTTP/1.1'#13#10'Host: ' + ROUTER_HOST + #13#10'Content-Length: 0'#13#10#13#10;
  GJsonReq := 'GET /json HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
  GEchoReq := 'POST /echo HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 1024'#13#10#13#10 + GBody1K;
  GSinkReq := 'POST /sink HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: ' + IntToStr(Int64(Length(GBody16K))) + #13#10#13#10 + GBody16K;
  GParamReq := 'GET /users/12345 HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
  SetupServer;
  try
    GConn := TcpConnect('127.0.0.1', GPort);
    GConn.SetNoDelay(True);
    GConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(30)));
    LSuite := TBenchSuite.Create('fullchain');
    LSuite.Add('Direct/Plaintext', @BenchDirectPlaintext).Add('Direct/1KB', @BenchDirect1K)
      .Add('Middleware/Noop', @BenchMiddlewareNoop).Add('Router/Plaintext', @BenchPlaintext)
      .Add('Router/JSON', @BenchJson).Add('Router/Echo/1KB', @BenchEcho1K)
      .Add('Router/Sink/16KB', @BenchSink16K).Add('Router/Param', @BenchParamRoute);
    WriteLn(LSuite.Run.PrintToConsole);
    GConn.Close;
  finally
    StopServer;
  end;
end.
