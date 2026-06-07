program bench_fullchain;
{**
 * @desc Full-chain HTTP benchmark — measures complete request-response cycle:
 *       TCP accept, parse, route, handler, serialize, write, client read.
 *       Single connection, keep-alive, reports req/s per scenario.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
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
  ROUTER_HOST = 'router';
  DIRECT_HOST = 'direct';

type
  TScenarioResult = record
    Completed: Int64;
    ElapsedNs: UInt64;
    NsPerOp: Double;
    ReqPerSec: Double;
  end;

var
  GServer: THttpServer;
  GPort: UInt16;
  GIterations: Int64;
  GFilter: string;
  GBackend: TTcpServerBackend;

procedure WritePlaintextResponse(const AW: IHttpResponseWriter);
begin
  AW.GetHeaders.Set_('content-type', 'text/plain');
  AW.GetHeaders.Set_('content-length', '13');
  AW.WriteHeader(HTTP_STATUS_OK);
  AW.Write(PAnsiChar('Hello, World!')^, 13);
end;

procedure WriteBody1KResponse(const AW: IHttpResponseWriter; const ABody1K: string);
begin
  AW.GetHeaders.Set_('content-type', 'application/octet-stream');
  AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(ABody1K))));
  AW.WriteHeader(HTTP_STATUS_OK);
  AW.Write(ABody1K[1], SizeUInt(Length(ABody1K)));
end;

function ConfiguredIterations: Int64;
var
  LValue: string;
begin
  Result := DEFAULT_ITERATIONS;
  LValue := Trim(GetEnvironmentVariable(BENCH_MAX_ITERS_ENV));
  if (LValue <> '') and TryStrToInt64(LValue, Result) and (Result > 0) then
    Exit;
  Result := DEFAULT_ITERATIONS;
end;

function ConfiguredFilter: string;
begin
  Result := Trim(GetEnvironmentVariable(BENCH_FILTER_ENV));
end;

procedure RejectInvalidBackend(const AValue: string);
begin
  WriteLn(StdErr, 'invalid ', BENCH_BACKEND_ENV, ': ', AValue,
    '; expected one of: threaded or epoll');
  Halt(2);
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
  RejectInvalidBackend(LValue);
end;

function BackendName: string;
begin
  case GBackend of
    TCP_SERVER_BACKEND_THREADED:
      Result := BENCH_BACKEND_THREADED;
    TCP_SERVER_BACKEND_EPOLL:
      Result := BENCH_BACKEND_EPOLL;
  else
    Result := 'unknown';
  end;
end;

function ExpectedH1PathForWorkload(const AWorkload: string): string;
begin
  if (AWorkload = 'echo_1k') or (AWorkload = 'sink_16k') then
    Exit('llhttp');
  Result := 'fast';
end;

function ShouldRunScenario(const AWorkload, AName: string): Boolean;
var
  LFilter: string;
begin
  if GFilter = '' then
  begin
    Result := True;
    Exit;
  end;

  LFilter := LowerCase(GFilter);
  Result :=
    (Pos(LFilter, LowerCase(AWorkload)) > 0) or
    (Pos(LFilter, LowerCase(AName)) > 0);
end;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

procedure SetupServer;
var
  LRouter: THttpRouter;
  LHandle: TPlatformThreadHandle;
  LBody1K: string;
  LRouterHandler: IHttpHandler;
  LServerOptions: THttpServerOptions;
begin
  SetLength(LBody1K, 1024);
  FillChar(LBody1K[1], 1024, Ord('x'));
  LServerOptions := THttpServerOptions.Default;
  LServerOptions.Backend := GBackend;

  LRouter := THttpRouter.Create;
  LRouterHandler := LRouter as IHttpHandler;

  { Plaintext }
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    WritePlaintextResponse(AW);
  end);

  { JSON }
  LRouter.Get('/json', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  const BODY = '{"message":"Hello, World!"}';
  begin
    AW.GetHeaders.Set_('content-type', 'application/json');
    AW.GetHeaders.Set_('content-length', '27');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar(BODY)^, 27);
  end);

  { Echo POST body }
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt; LTotal: SizeUInt;
  begin
    LTotal := 0;
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], 4096);
        LTotal := LTotal + LN;
      until LN = 0;
    end;
    AW.GetHeaders.Set_('content-type', 'application/octet-stream');
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(LTotal)));
    AW.WriteHeader(HTTP_STATUS_OK);
    { Echo back same size — just write the buffer contents }
    if LTotal > 0 then
      AW.Write(LBuf[0], LTotal);
  end);

  { Drain POST body without echoing it back. }
  LRouter.Post('/sink', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt;
  begin
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeOf(LBuf));
      until LN = 0;
    end;
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);

  { Router with params }
  LRouter.Get('/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'user:' + AReq.PathParam('id');
    AW.GetHeaders.Set_('content-type', 'text/plain');
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);

  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if AReq.Headers.Get('host') = DIRECT_HOST then
      begin
        if AReq.Path = '/1k' then
        begin
          WriteBody1KResponse(AW, LBody1K);
          Exit;
        end;
        WritePlaintextResponse(AW);
        Exit;
      end;
      LRouterHandler.ServeHTTP(AReq, AW);
    end), LServerOptions);
  platform_thread_create(LHandle, @ServerThread, nil);
  while not GServer.IsRunning do
    platform_thread_sleep_ns(1000000);
  GPort := GServer.LocalAddr.Port;
end;

{ Read one full HTTP response from a keep-alive connection }
function ReadResponse(const AConn: ITcpStream): SizeUInt;
var
  LBuf: array[0..4095] of Byte;
  LN, LTotal: SizeUInt;
  LHeaderEnd: SizeInt;
  LResp: string;
  LClPos, LClEnd: SizeInt;
  LContentLen, LBodyRead: SizeInt;
  LNeed: SizeInt;
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
  LResp := '';
  LTotal := 0;
  LHeaderEnd := 0;
  { Read until we see CRLFCRLF. Use chunk reads so the benchmark measures the
    server path instead of a byte-at-a-time client parser. }
  repeat
    LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN = 0 then begin Result := LTotal; Exit; end;
    AppendBytes(LBuf[0], LN);
    Inc(LTotal, LN);
    LHeaderEnd := Pos(#13#10#13#10, LResp);
  until LHeaderEnd > 0;

  { Parse content-length }
  LContentLen := 0;
  LClPos := Pos('content-length: ', LResp);
  if LClPos > 0 then
  begin
    LClPos := LClPos + 16;
    LClEnd := LClPos;
    while (LClEnd <= Length(LResp)) and (LResp[LClEnd] >= '0') and (LResp[LClEnd] <= '9') do
      Inc(LClEnd);
    LContentLen := SizeInt(StrToInt(Copy(LResp, LClPos, LClEnd - LClPos)));
  end;

  { Read body }
  LBodyRead := Length(LResp) - (LHeaderEnd + 3);
  while LBodyRead < LContentLen do
  begin
    LNeed := LContentLen - LBodyRead;
    if LNeed > SizeInt(SizeOf(LBuf)) then
      LReadSize := SizeUInt(SizeOf(LBuf))
    else
      LReadSize := SizeUInt(LNeed);
    LN := AConn.Read(LBuf[0], LReadSize);
    if LN = 0 then Break;
    Inc(LBodyRead, SizeInt(LN));
    Inc(LTotal, LN);
  end;
  Result := LTotal;
end;

function RunScenario(const AWorkload, AName, ARequest: string;
  const AExpectMin, AResponseBodyBytes: SizeUInt): TScenarioResult;
var
  LConn: ITcpStream;
  LStart, LEnd, LElapsedNs: UInt64;
  LI: Int64;
  LBytesRead: SizeUInt;
  LReqPerSec: Double;
begin
  Result.Completed := 0;
  Result.ElapsedNs := 0;
  Result.NsPerOp := 0;
  Result.ReqPerSec := 0;

  if not ShouldRunScenario(AWorkload, AName) then
    Exit;

  LConn := TcpConnect('127.0.0.1', GPort);
  LConn.SetNoDelay(True);
  LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(30)));

  { Warmup }
  for LI := 1 to 10 do
  begin
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    ReadResponse(LConn);
  end;

  LStart := platform_monotonic_ns;
  for LI := 1 to GIterations do
  begin
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    LBytesRead := ReadResponse(LConn);
    if LBytesRead >= AExpectMin then
      Inc(Result.Completed);
  end;
  LEnd := platform_monotonic_ns;
  LConn.Close;

  LElapsedNs := LEnd - LStart;
  if GIterations > 0 then
    Result.NsPerOp := Double(LElapsedNs) / Double(GIterations);
  if LElapsedNs > 0 then
    LReqPerSec := (Double(Result.Completed) / (Double(LElapsedNs) / 1000000000.0))
  else
    LReqPerSec := 0;
  Result.ElapsedNs := LElapsedNs;
  Result.ReqPerSec := LReqPerSec;

  WriteLn('  ', AName:25, '  ', GIterations, ' reqs  ', LElapsedNs div 1000000, ' ms  ',
    Trunc(LReqPerSec):8, ' req/s');
  WriteLn('operation=http.fullchain.keepalive');
  WriteLn('workload=', AWorkload);
  WriteLn('response_body_bytes=', AResponseBodyBytes);
  WriteLn('backend=', BackendName);
  WriteLn('nextpas_h1_path=', ExpectedH1PathForWorkload(AWorkload));
  WriteLn('iterations=', GIterations);
  WriteLn('completed=', Result.Completed);
  WriteLn('elapsed_ns=', Result.ElapsedNs);
  WriteLn('ns/op=', Result.NsPerOp:0:1);
  WriteLn('req/s=', Result.ReqPerSec:0:0);
  WriteLn;
end;

var
  LDirectPlaintextReq: string;
  LDirect1KReq: string;
  LBody1K: string;
  LEchoReq: string;
  LBody16K: string;
  LSinkReq: string;
  LResult: TScenarioResult;
  LScenariosRun: Int32;

begin
  GIterations := ConfiguredIterations;
  GFilter := ConfiguredFilter;
  GBackend := ConfiguredBackend;
  LScenariosRun := 0;

  WriteLn('=== nextpas.core.http.fullchain benchmark ===');
  WriteLn('operation=http.fullchain.keepalive');
  WriteLn('client_read_mode=buffered');
  WriteLn('backend=', BackendName);
  WriteLn('bench_max_iters=', GIterations);
  if GFilter <> '' then
    WriteLn('bench_filter=', GFilter);
  WriteLn('  Iterations per scenario: ', GIterations);
  WriteLn;

  SetupServer;
  WriteLn('  Server listening on port ', GPort);
  WriteLn;

  { Scenario 1: Plaintext without router dispatch }
  LDirectPlaintextReq :=
    'GET / HTTP/1.1'#13#10'Host: ' + DIRECT_HOST + #13#10'Content-Length: 0'#13#10#13#10;
  LResult := RunScenario('direct_root',
    'Direct root (GET /, no router)', LDirectPlaintextReq, 50, 13);
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  { Scenario 1b: 1 KiB fixed response without router dispatch }
  LDirect1KReq :=
    'GET /1k HTTP/1.1'#13#10'Host: ' + DIRECT_HOST + #13#10'Content-Length: 0'#13#10#13#10;
  LResult := RunScenario('direct_1k',
    'Direct 1KB (GET /1k, no router)', LDirect1KReq, 1000, 1024);
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  { Scenario 1: Plaintext }
  LResult := RunScenario('plaintext', 'Plaintext (GET /)',
    'GET / HTTP/1.1'#13#10'Host: ' + ROUTER_HOST + #13#10'Content-Length: 0'#13#10#13#10,
    50, 13);
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  { Scenario 2: JSON }
  LResult := RunScenario('json', 'JSON (GET /json)',
    'GET /json HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10,
    60, 27);
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  { Scenario 3: Body echo 1KB }
  SetLength(LBody1K, 1024);
  FillChar(LBody1K[1], 1024, Ord('x'));
  LEchoReq := 'POST /echo HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 1024'#13#10#13#10 + LBody1K;
  LResult := RunScenario('echo_1k', 'Echo 1KB (POST /echo)', LEchoReq, 100,
    1024);
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  { Scenario 4: Body sink 16KB }
  SetLength(LBody16K, 16 * 1024);
  FillChar(LBody16K[1], Length(LBody16K), Ord('x'));
  LSinkReq := 'POST /sink HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: ' +
    IntToStr(Int64(Length(LBody16K))) + #13#10#13#10 + LBody16K;
  LResult := RunScenario('sink_16k', 'Sink 16KB (POST /sink)', LSinkReq, 20, 0);
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  { Scenario 5: Router with params }
  LResult := RunScenario('param_route', 'Param (GET /users/12345)',
    'GET /users/12345 HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10,
    50, SizeUInt(Length('user:12345')));
  if LResult.ElapsedNs > 0 then
    Inc(LScenariosRun);

  if LScenariosRun = 0 then
  begin
    WriteLn('  No matching full-chain scenarios.');
    GServer.Shutdown;
    GServer.Free;
    Halt(2);
  end;

  WriteLn;
  GServer.Shutdown;
  GServer.Free;
  WriteLn('Done.');
end.
