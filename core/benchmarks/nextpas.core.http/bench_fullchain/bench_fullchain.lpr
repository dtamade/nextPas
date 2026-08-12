program bench_fullchain;
{**
 * @desc Full-chain HTTP benchmark — measures complete request-response cycle:
 *       TCP accept, parse, route, handler, serialize, write, client read.
 *       Single connection, keep-alive, reports req/s per scenario with strict
 *       response validation (status/content-length/body-bytes) and observed
 *       dispatch-truth validation (direct/router/middleware handler hits).
 *}
{$I nextpas.core.settings.inc}
uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.os.env,
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
    Completed: Int64;
    ValidationFailures: Int64;
    DispatchFailures: Int64;
    ElapsedNs: UInt64;
    NsPerOp: Double;
    ReqPerSec: Double;
  end;
  TFullchainResponseRead = record
    BytesRead: SizeUInt;
    StatusCode: Int32;
    ContentLength: Int64;
    BodyBytes: SizeUInt;
    Complete: Boolean;
  end;
var
  GServer: THttpServer;
  GServerThreadHandle: TPlatformThreadHandle;
  GServerThreadStarted: Boolean;
  GPort: UInt16;
  GIterations: Int64;
  GFilter: string;
  GBackend: TTcpServerBackend;
  GDispatchFailures: Int64;
  GDirectHandlerHits: Int64;
  GRouterHandlerHits: Int64;
  GMiddlewareHits: Int64;
  { Scenario bodies: file-scope templates consumed by the request builders
    and by the direct-1k handler branch. }
  LBody1K: string;
  LBody16K: string;
  GConn: ITcpStream;

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
var
  LValue: string;
begin
  LValue := Trim(GetEnvironmentVariable(BENCH_MAX_ITERS_ENV));
  if LValue = '' then
    Exit(DEFAULT_ITERATIONS);
  if (not TryStrToInt64(LValue, Result)) or (Result <= 0) then
  begin
    WriteLn(StdErr, 'invalid ', BENCH_MAX_ITERS_ENV, ': ', LValue);
    Halt(2);
  end;
end;

function ConfiguredFilter: string;
begin
  Result := Trim(GetEnvironmentVariable(BENCH_FILTER_ENV));
end;

function ConfiguredBackend: TTcpServerBackend;
var
  LValue: string;
begin
  LValue := Trim(GetEnvironmentVariable(BENCH_BACKEND_ENV));
  if (LValue = '') or (LValue = BENCH_BACKEND_THREADED) then
    Exit(TCP_SERVER_BACKEND_THREADED);
  if LValue = BENCH_BACKEND_EPOLL then
    Exit(TCP_SERVER_BACKEND_EPOLL);
  WriteLn(StdErr, 'invalid ', BENCH_BACKEND_ENV, ': ', LValue,
    ' (valid: ', BENCH_BACKEND_THREADED, ', ', BENCH_BACKEND_EPOLL, ')');
  Halt(2);
end;

function BackendName: string;
begin
  case GBackend of
    TCP_SERVER_BACKEND_THREADED: Result := BENCH_BACKEND_THREADED;
    TCP_SERVER_BACKEND_EPOLL: Result := BENCH_BACKEND_EPOLL;
  else
    Result := 'unknown';
  end;
end;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

procedure StopServer;
var
  LThreadResult: Pointer;
begin
  if GServer <> nil then
    GServer.Shutdown;
  if GServerThreadStarted then
  begin
    platform_thread_join(GServerThreadHandle, LThreadResult);
    GServerThreadStarted := False;
    GServerThreadHandle := nil;
  end;
  if GServer <> nil then
  begin
    GServer.Free;
    GServer := nil;
  end;
end;

function WaitForServerReady: Boolean;
var
  LStartNs, LTimeoutNs: UInt64;
begin
  LStartNs := platform_monotonic_ns;
  LTimeoutNs := UInt64(BENCH_SERVER_READY_TIMEOUT_MS) * 1000000;
  while not GServer.IsRunning do
  begin
    if platform_monotonic_ns - LStartNs >= LTimeoutNs then
      Exit(False);
    platform_thread_sleep_ns(1000000);
  end;
  Result := True;
end;

procedure SetupServer;
var
  LRouter, LMiddlewareRouter: THttpRouter;
  LRouterHandler, LMiddlewareHandler: IHttpHandler;
  LServerOptions: THttpServerOptions;
begin
  LServerOptions := THttpServerOptions.Default;
  LServerOptions.Backend := GBackend;
  LRouter := THttpRouter.Create;
  LRouterHandler := LRouter as IHttpHandler;
  LMiddlewareRouter := THttpRouter.Create;
  LMiddlewareHandler := LMiddlewareRouter as IHttpHandler;
  LMiddlewareRouter.Use(MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      Inc(GMiddlewareHits);
      ANext.ServeHTTP(AReq, AW);
    end);
  end));
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    WritePlaintextResponse(AW);
  end);
  LMiddlewareRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    WritePlaintextResponse(AW);
  end);
  LRouter.Get('/json', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  const
    BODY = '{"message":"Hello, World!"}';
  begin
    AW.GetHeaders.SetHeader('content-type', 'application/json');
    AW.GetHeaders.SetHeader('content-length', '27');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar(BODY)^, 27);
  end);
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..4095] of Byte;
    LN, LTotal: SizeUInt;
  begin
    LTotal := 0;
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], 4096);
        LTotal := LTotal + LN;
      until LN = 0;
    end;
    AW.GetHeaders.SetHeader('content-type', 'application/octet-stream');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(LTotal)));
    AW.WriteHeader(HTTP_STATUS_OK);
    if LTotal > 0 then
      AW.Write(LBuf[0], LTotal);
  end);
  LRouter.Post('/sink', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBuf: array[0..4095] of Byte;
    LN: SizeUInt;
  begin
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeOf(LBuf));
      until LN = 0;
    end;
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LRouter.Get('/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'user:' + AReq.PathParam('id');
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if AReq.Headers.Get('host') = DIRECT_HOST then
      begin
        Inc(GDirectHandlerHits);
        WritePlaintextResponse(AW);
        Exit;
      end;
      if AReq.Headers.Get('host') = DIRECT_1K_HOST then
      begin
        Inc(GDirectHandlerHits);
        WriteBody1KResponse(AW, LBody1K);
        Exit;
      end;
      if AReq.Headers.Get('host') = MIDDLEWARE_HOST then
      begin
        Inc(GRouterHandlerHits);
        LMiddlewareHandler.ServeHTTP(AReq, AW);
        Exit;
      end;
      Inc(GRouterHandlerHits);
      LRouterHandler.ServeHTTP(AReq, AW);
    end), LServerOptions);
  GServerThreadStarted := platform_thread_create(GServerThreadHandle, @ServerThread, nil) = 0;
  if not GServerThreadStarted then
  begin
    StopServer;
    raise Exception.Create('server thread create failed');
  end;
  if not WaitForServerReady then
  begin
    StopServer;
    raise Exception.Create('bench_fullchain server did not become ready');
  end;
  GPort := GServer.LocalAddr.Port;
  { The server has completed its readiness warmup; observe dispatch truth from
    now on so observed handler hits equal the scenario iteration count. }
  GDirectHandlerHits := 0;
  GRouterHandlerHits := 0;
  GMiddlewareHits := 0;
end;

function TryParseStatusCode(const AResp: string; out AStatusCode: Int32): Boolean;
var
  LStatusValue: Int64;
begin
  AStatusCode := 0;
  Result := False;
  if (Length(AResp) < 12) or (Copy(AResp, 1, 9) <> 'HTTP/1.1 ') then
    Exit;
  if not TryStrToInt64(Copy(AResp, 10, 3), LStatusValue) then
    Exit;
  if (LStatusValue < 100) or (LStatusValue > 999) then
    Exit;
  AStatusCode := Int32(LStatusValue);
  Result := True;
end;

function TryParseContentLength(const AResp: string; const AHeaderEnd: SizeInt;
  out AContentLength: Int64): Boolean;
var
  LHeaders, LLowerHeaders: string;
  LClPos, LValueStart, LValueEnd: SizeInt;
begin
  AContentLength := -1;
  Result := False;
  if AHeaderEnd <= 0 then
    Exit;
  LHeaders := Copy(AResp, 1, AHeaderEnd - 1);
  LLowerHeaders := LowerCase(LHeaders);
  LClPos := Pos(#13#10'content-length:', LLowerHeaders);
  if LClPos = 0 then
    Exit;
  LValueStart := LClPos + Length(#13#10'content-length:');
  while (LValueStart <= Length(LHeaders)) and
    ((LHeaders[LValueStart] = ' ') or (LHeaders[LValueStart] = #9)) do
    Inc(LValueStart);
  LValueEnd := LValueStart;
  while (LValueEnd <= Length(LHeaders)) and (LHeaders[LValueEnd] >= '0') and
    (LHeaders[LValueEnd] <= '9') do
    Inc(LValueEnd);
  if LValueEnd = LValueStart then
    Exit;
  Result := TryStrToInt64(
    Copy(LHeaders, LValueStart, LValueEnd - LValueStart), AContentLength);
end;

function ResponseMatchesScenario(const AResponse: TFullchainResponseRead;
  const AResponseBodyBytes: SizeUInt): Boolean;
begin
  Result := AResponse.Complete and
    (AResponse.StatusCode = HTTP_STATUS_OK) and
    (AResponse.ContentLength = Int64(AResponseBodyBytes)) and
    (AResponse.BodyBytes = AResponseBodyBytes);
end;

{ Read one full HTTP response from a keep-alive connection }
function ReadResponse(const AConn: ITcpStream): TFullchainResponseRead;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LHeaderEnd: SizeInt;
  LResp: string;
  LContentLen, LBodyRead, LNeed: Int64;
  LReadSize: SizeUInt;

  procedure AppendBytes(const ABuf; const ACount: SizeUInt);
  var
    LOld: SizeInt;
  begin
    if ACount = 0 then
      Exit;
    LOld := Length(LResp);
    SetLength(LResp, LOld + SizeInt(ACount));
    Move(ABuf, LResp[LOld + 1], ACount);
  end;

begin
  Result.BytesRead := 0;
  Result.StatusCode := 0;
  Result.ContentLength := -1;
  Result.BodyBytes := 0;
  Result.Complete := False;
  LResp := '';
  LHeaderEnd := 0;
  repeat
    LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN = 0 then
      Exit;
    AppendBytes(LBuf[0], LN);
    Inc(Result.BytesRead, LN);
    LHeaderEnd := Pos(#13#10#13#10, LResp);
  until LHeaderEnd > 0;
  if not TryParseStatusCode(LResp, Result.StatusCode) then
    Exit;
  if not TryParseContentLength(LResp, LHeaderEnd, LContentLen) then
    Exit;
  if LContentLen < 0 then
    Exit;
  Result.ContentLength := LContentLen;
  LBodyRead := Length(LResp) - (LHeaderEnd + 3);
  while LBodyRead < LContentLen do
  begin
    LNeed := LContentLen - LBodyRead;
    if LNeed > SizeInt(SizeOf(LBuf)) then
      LReadSize := SizeUInt(SizeOf(LBuf))
    else
      LReadSize := SizeUInt(LNeed);
    LN := AConn.Read(LBuf[0], LReadSize);
    if LN = 0 then
      Break;
    Inc(LBodyRead, Int64(LN));
    Inc(Result.BytesRead, LN);
  end;
  if LBodyRead >= 0 then
    Result.BodyBytes := SizeUInt(LBodyRead);
  Result.Complete := LBodyRead = LContentLen;
end;

function ExpectedDispatchPathForWorkload(const AWorkload: string): string;
begin
  if AWorkload = 'direct_root' then
    Exit('direct_handler');
  if AWorkload = 'direct_1k' then
    Exit('direct_handler');
  if AWorkload = 'middleware_noop' then
    Exit('middleware_router');
  Result := 'router';
end;

function ShouldRunScenario(const AWorkload: string): Boolean;
begin
  Result := (GFilter = '') or (Pos(GFilter, AWorkload) > 0);
end;

function ValidateDispatchTruth(const AExpectedPath: string;
  const AExpectedHits: Int64; var ADispatchFailure: Boolean): Boolean;
begin
  Result := True;
  case AExpectedPath of
    'direct_handler':
      if GDirectHandlerHits <> AExpectedHits then
      begin
        ADispatchFailure := True;
        Result := False;
      end;
    'middleware_router':
      if GMiddlewareHits <> AExpectedHits then
      begin
        ADispatchFailure := True;
        Result := False;
      end;
  else
    if GRouterHandlerHits <> AExpectedHits then
    begin
      ADispatchFailure := True;
      Result := False;
    end;
  end;
end;

function RunScenario(const ARequest: string;
  const AResponseBodyBytes: Int64): TScenarioResult;
var
  LIt: Int64;
  LStartNs, LEndNs: UInt64;
  LConn: ITcpStream;
  LResponse: TFullchainResponseRead;
begin
  Result.Completed := 0;
  Result.ValidationFailures := 0;
  Result.DispatchFailures := 0;
  Result.ElapsedNs := 0;
  Result.NsPerOp := 0;
  Result.ReqPerSec := 0;
  LConn := GConn;
  LStartNs := platform_monotonic_ns;
  for LIt := 1 to GIterations do
  begin
    GConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    LResponse := ReadResponse(LConn);
    if ResponseMatchesScenario(LResponse, AResponseBodyBytes) then
      Inc(Result.Completed)
    else
      Inc(Result.ValidationFailures);
  end;
  LEndNs := platform_monotonic_ns;
  Result.ElapsedNs := LEndNs - LStartNs;
  if Result.Completed > 0 then
  begin
    Result.NsPerOp := Result.ElapsedNs / Result.Completed;
    Result.ReqPerSec := 1000000000.0 / Result.NsPerOp;
  end;
end;

procedure RecordScenarioResult(const AResult: TScenarioResult;
  const AWorkload, ADispatchPath, AH1Path: string;
  const ARequestBodyBytes, AResponseBodyBytes: Int64;
  var AValidationFailure: Boolean);
begin
  if AResult.ValidationFailures <> 0 then
    AValidationFailure := True;
  WriteLn('workload=' + AWorkload);
  WriteLn('nextpas_h1_path=' + AH1Path);
  WriteLn('nextpas_dispatch_path=' + ADispatchPath);
  WriteLn('response_validation=strict_status_content_length_body_bytes');
  WriteLn('request_body_bytes=' + IntToStr(ARequestBodyBytes));
  WriteLn('response_body_bytes=' + IntToStr(AResponseBodyBytes));
  WriteLn('iterations=' + IntToStr(GIterations));
  WriteLn('completed=' + IntToStr(AResult.Completed));
  WriteLn('validation_failures=' + IntToStr(AResult.ValidationFailures));
  WriteLn('elapsed_ns=' + IntToStr(Int64(AResult.ElapsedNs)));
  WriteLn('ns/op=' + FloatToStr(AResult.NsPerOp));
  WriteLn('req/s=' + FloatToStr(AResult.ReqPerSec));
end;

function RunScenarioByName(const AWorkload: string; const ARequest: string;
  const ARequestBodyBytes, AResponseBodyBytes: Int64; const AH1Path: string;
  var AValidationFailure, ADispatchFailure: Boolean): Boolean;
var
  LResult: TScenarioResult;
  LExpectedPath: string;
  LHitsBefore: Int64;
begin
  Result := False;
  if not ShouldRunScenario(AWorkload) then
    Exit;
  LExpectedPath := ExpectedDispatchPathForWorkload(AWorkload);
  case LExpectedPath of
    'direct_handler': LHitsBefore := GDirectHandlerHits;
    'middleware_router': LHitsBefore := GMiddlewareHits;
  else
    LHitsBefore := GRouterHandlerHits;
  end;
  LResult := RunScenario(ARequest, AResponseBodyBytes);
  RecordScenarioResult(LResult, AWorkload, LExpectedPath, AH1Path,
    ARequestBodyBytes, AResponseBodyBytes, AValidationFailure);
  if not ValidateDispatchTruth(LExpectedPath, LHitsBefore + GIterations,
    ADispatchFailure) then
    Inc(GDispatchFailures);
  Result := True;
end;

var
  LDirectPlaintextReq: string;
  LDirect1KReq: string;
  LMiddlewareReq: string;
  LPlaintextReq: string;
  LJsonReq: string;
  LEchoReq: string;
  LSinkReq: string;
  LParamReq: string;

var
  LValidationFailure: Boolean;
  LDispatchFailure: Boolean;
  LScenariosRun: Int64;
  LNoMatch: Boolean;

begin
  GIterations := ConfiguredIterations;
  GFilter := ConfiguredFilter;
  GBackend := ConfiguredBackend;
  GDispatchFailures := 0;
  SetLength(LBody1K, 1024);
  FillChar(LBody1K[1], 1024, Ord('x'));
  SetLength(LBody16K, 16384);
  FillChar(LBody16K[1], 16384, Ord('x'));
  { Scenario 1: Plaintext without router dispatch }
  LDirectPlaintextReq := 'GET / HTTP/1.1'#13#10'Host: ' + DIRECT_HOST +
    #13#10'Content-Length: 0'#13#10#13#10;
  LDirect1KReq := 'GET / HTTP/1.1'#13#10'Host: ' + DIRECT_1K_HOST +
    #13#10'Content-Length: 0'#13#10#13#10;
  { Scenario 1c: Plaintext with no-op middleware }
  LMiddlewareReq := 'GET / HTTP/1.1'#13#10'Host: ' + MIDDLEWARE_HOST + #13#10 +
    'Content-Length: 0'#13#10#13#10;
  { Scenario 1: Plaintext }
  LPlaintextReq := 'GET / HTTP/1.1'#13#10'Host: ' + ROUTER_HOST +
    #13#10'Content-Length: 0'#13#10#13#10;
  LJsonReq := 'GET /json HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
  LEchoReq := 'POST /echo HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 1024'#13#10#13#10 +
    LBody1K;
  LSinkReq := 'POST /sink HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: ' +
    IntToStr(Int64(Length(LBody16K))) + #13#10#13#10 + LBody16K;
  LParamReq := 'GET /users/12345 HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10;
  SetupServer;
  try
    GConn := TcpConnect('127.0.0.1', GPort);
    GConn.SetNoDelay(True);
    GConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(30)));
    { Residual cost isolation ladder (local characterization, not ranking):
      L0 net bench_tcp socket floor -> L1 micro benches (parser/headers/router/
      writer/outbound) -> L2 fullchain Direct/* (HTTP+socket, no router) ->
      L3 Router/* / Middleware/* -> L4 multi-thread server comparison. }
    WriteLn('operation=http.fullchain.keepalive');
    WriteLn('client_read_mode=buffered');
    WriteLn('backend=', BackendName);
    WriteLn('bench_max_iters=', IntToStr(GIterations));
    WriteLn('bench_filter=', GFilter);
    WriteLn('cost_isolation_ladder=net_bench_tcp|micro|direct|router_middleware|server_comparison');
    LScenariosRun := 0;
    if RunScenarioByName('direct_root', LDirectPlaintextReq, 0, 13, 'fast',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('direct_1k', LDirect1KReq, 0, 1024, 'fast',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('middleware_noop', LMiddlewareReq, 0, 13, 'fast',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('plaintext', LPlaintextReq, 0, 13, 'fast',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('json', LJsonReq, 0, 27, 'fast',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('echo_1k', LEchoReq, 1024, 1024, 'llhttp',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('sink_16k', LSinkReq, 16384, 0, 'llhttp',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    if RunScenarioByName('param_route', LParamReq, 0, 10, 'fast',
      LValidationFailure, LDispatchFailure) then
      Inc(LScenariosRun);
    WriteLn('dispatch_validation=observed_handler_hits');
    WriteLn('dispatch_failures=', IntToStr(GDispatchFailures));
    WriteLn('observed_direct_handler_hits=', IntToStr(GDirectHandlerHits));
    WriteLn('observed_router_handler_hits=', IntToStr(GRouterHandlerHits));
    WriteLn('observed_middleware_hits=', IntToStr(GMiddlewareHits));
    LNoMatch := LScenariosRun = 0;
    if LNoMatch then
      WriteLn('  No matching full-chain scenarios.');
    GConn.Close;
  finally
    StopServer;
  end;
  if LNoMatch then
    Halt(2);
  if LValidationFailure or (GDispatchFailures > 0) then
    Halt(3);
end.
