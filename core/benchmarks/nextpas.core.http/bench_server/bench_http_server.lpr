program bench_http_server;
{**
 * @desc HTTP server hello-world QPS benchmark.
 *       Starts server, hammers it with concurrent connections, reports req/s.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.server,
  nextpas.core.http.middleware,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  DEFAULT_NUM_REQUESTS = 20000;
  DEFAULT_NUM_THREADS = 4;
  BENCH_BACKEND_THREADED = 'threaded';
  BENCH_BACKEND_EPOLL = 'epoll';
  WORKLOAD_NO_URL = 'no_url';
  WORKLOAD_URL_PATH = 'url_path';
  WORKLOAD_ADAPTER_NO_URL = 'adapter_no_url';
  WORKLOAD_RESPONSE_1K = 'response_1k';
  VALID_WORKLOADS_TEXT = 'no_url, url_path, adapter_no_url, or response_1k';
  VALID_BACKENDS_TEXT = 'threaded or epoll';
  SMALL_RESPONSE_BODY = 'Hello, World!';
  SMALL_RESPONSE_LEN = 13;
  SMALL_RESPONSE_LEN_TEXT = '13';
  RESPONSE_1K_LEN = 1024;
  RESPONSE_1K_LEN_TEXT = '1024';

var
  GServer: THttpServer;
  GPort: UInt16;
  GDone: Int32;
  GSuccess: Int32;
  GRequests: Int32;
  GRequestedThreads: Int32;
  GThreads: Int32;
  GWorkload: string;
  GBackend: TTcpServerBackend;
  GResponseBody1K: AnsiString;

procedure RejectInvalidWorkload(const AValue: string);
begin
  WriteLn(StdErr, 'invalid --workload: ', AValue,
    '; expected one of: ', VALID_WORKLOADS_TEXT);
  Halt(2);
end;

procedure RejectInvalidPositiveOption(const AName, AValue: string);
begin
  WriteLn(StdErr, 'invalid ', AName, ': ', AValue,
    '; expected positive integer');
  Halt(2);
end;

procedure RejectInvalidBackend(const AValue: string);
begin
  WriteLn(StdErr, 'invalid --backend: ', AValue,
    '; expected one of: ', VALID_BACKENDS_TEXT);
  Halt(2);
end;

function ParsePositiveOption(const AName, AValue: string): Int32;
var
  LValue: Integer;
begin
  if (not TryStrToInt(AValue, LValue)) or (LValue < 1) then
    RejectInvalidPositiveOption(AName, AValue);
  Result := LValue;
end;

function ParseBackendOption(const AValue: string): TTcpServerBackend;
begin
  if AValue = BENCH_BACKEND_THREADED then
    Exit(TCP_SERVER_BACKEND_THREADED);
  if AValue = BENCH_BACKEND_EPOLL then
    Exit(TCP_SERVER_BACKEND_EPOLL);
  RejectInvalidBackend(AValue);
end;

function ResponseComplete(const ABuf: array of Byte; const ATotal: SizeUInt;
  const ABodyLen: SizeUInt): Boolean;
var
  LI: SizeUInt;
begin
  Result := False;
  if ATotal < 4 then
    Exit;
  for LI := 0 to ATotal - 4 do
    if (ABuf[LI] = 13) and (ABuf[LI + 1] = 10) and
       (ABuf[LI + 2] = 13) and (ABuf[LI + 3] = 10) then
    begin
      Result := ATotal >= LI + 4 + ABodyLen;
      Exit;
    end;
end;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

function ClientThread(AParam: Pointer): Pointer; cdecl;
var
  LI: Int32;
  LRequests: Int32;
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
  LExpectedBodyLen: SizeUInt;
const
  REQ_NO_URL: AnsiString = 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;
  REQ_URL_PATH: AnsiString = 'GET /api/v1/users HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;
  REQ_ADAPTER_NO_URL: AnsiString = 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: keep-alive'#13#10'Content-Length: 0'#13#10#13#10;
begin
  Result := nil;
  LRequests := Int32(PtrUInt(AParam));
  if GWorkload = WORKLOAD_RESPONSE_1K then
    LExpectedBodyLen := RESPONSE_1K_LEN
  else
    LExpectedBodyLen := SMALL_RESPONSE_LEN;
  try
    LConn := TcpConnect('127.0.0.1', GPort);
    LConn.SetNoDelay(True);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
    for LI := 1 to LRequests do
    begin
      if GWorkload = WORKLOAD_URL_PATH then
        LConn.Write(PAnsiChar(REQ_URL_PATH)^, Length(REQ_URL_PATH))
      else if GWorkload = WORKLOAD_ADAPTER_NO_URL then
        LConn.Write(PAnsiChar(REQ_ADAPTER_NO_URL)^, Length(REQ_ADAPTER_NO_URL))
      else
        LConn.Write(PAnsiChar(REQ_NO_URL)^, Length(REQ_NO_URL));
      LTotal := 0;
      repeat
        if LTotal >= SizeUInt(Length(LBuf)) then
          Break;
        LN := LConn.Read(LBuf[LTotal], SizeUInt(Length(LBuf)) - LTotal);
        if LN = 0 then Break;
        Inc(LTotal, LN);
      until ResponseComplete(LBuf, LTotal, LExpectedBodyLen);
      if LN = 0 then Break;
      InterlockedIncrement(GSuccess);
    end;
    LConn.Close;
  except
  end;
  InterlockedIncrement(GDone);
end;

procedure ParseOptions;
var
  LI: Integer;
begin
  GRequests := DEFAULT_NUM_REQUESTS;
  GRequestedThreads := DEFAULT_NUM_THREADS;
  GThreads := DEFAULT_NUM_THREADS;
  GWorkload := WORKLOAD_NO_URL;
  GBackend := TCP_SERVER_BACKEND_THREADED;
  LI := 1;
  while LI <= ParamCount do
  begin
    if (ParamStr(LI) = '--requests') and (LI < ParamCount) then
    begin
      GRequests := ParsePositiveOption('--requests', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--threads') and (LI < ParamCount) then
    begin
      GRequestedThreads := ParsePositiveOption('--threads', ParamStr(LI + 1));
      GThreads := GRequestedThreads;
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--workload') and (LI < ParamCount) then
    begin
      if (ParamStr(LI + 1) = WORKLOAD_NO_URL) or
         (ParamStr(LI + 1) = WORKLOAD_URL_PATH) or
         (ParamStr(LI + 1) = WORKLOAD_ADAPTER_NO_URL) or
         (ParamStr(LI + 1) = WORKLOAD_RESPONSE_1K) then
        GWorkload := ParamStr(LI + 1)
      else
        RejectInvalidWorkload(ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--backend') and (LI < ParamCount) then
    begin
      GBackend := ParseBackendOption(ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else
      Inc(LI);
  end;
  if GThreads > GRequests then
    GThreads := GRequests;
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

function ExpectedH1PathForWorkload: string;
begin
  { All current benchmark requests are no-body HTTP/1.1 requests that should
    stay on the conservative H1 fast path. }
  Result := 'fast';
end;

function ResponseBodyBytesForWorkload: SizeUInt;
begin
  if GWorkload = WORKLOAD_RESPONSE_1K then
    Exit(RESPONSE_1K_LEN);
  Result := SMALL_RESPONSE_LEN;
end;

var
  LHandle: TPlatformThreadHandle;
  LHandles: array of TPlatformThreadHandle;
  LServerOptions: THttpServerOptions;
  LI: Int32;
  LThreadRequests: Int32;
  LStart, LEnd: UInt64;
  LElapsedNs: UInt64;
  LReqPerSec: Double;
  LNsPerOp: Double;
  LRet: Pointer;

begin
  ParseOptions;
  if GWorkload = WORKLOAD_RESPONSE_1K then
  begin
    SetLength(GResponseBody1K, RESPONSE_1K_LEN);
    FillChar(GResponseBody1K[1], RESPONSE_1K_LEN, Byte('x'));
  end;
  GDone := 0;
  GSuccess := 0;

  LServerOptions := THttpServerOptions.Default;
  LServerOptions.Backend := GBackend;
  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if (GWorkload = WORKLOAD_URL_PATH) and
         (AReq.Path <> '/api/v1/users') then
      begin
        AW.WriteHeader(404);
        Exit;
      end;
      AW.Headers.Set_('content-type', 'text/plain');
      if GWorkload = WORKLOAD_RESPONSE_1K then
        AW.Headers.Set_('content-length', RESPONSE_1K_LEN_TEXT)
      else
        AW.Headers.Set_('content-length', SMALL_RESPONSE_LEN_TEXT);
      AW.WriteHeader(200);
      if GWorkload = WORKLOAD_RESPONSE_1K then
        AW.Write(PAnsiChar(GResponseBody1K)^, Length(GResponseBody1K))
      else
        AW.Write(PAnsiChar(SMALL_RESPONSE_BODY)^, SMALL_RESPONSE_LEN);
    end), LServerOptions);

  platform_thread_create(LHandle, @ServerThread, nil);
  while GServer.LocalAddr.Port = 0 do
    platform_thread_sleep_ns(1000000);
  GPort := GServer.LocalAddr.Port;

  WriteLn('=== HTTP Server Benchmark ===');
  WriteLn('  Requests: ', GRequests);
  WriteLn('  Threads:  ', GThreads);
  WriteLn('  Workload: ', GWorkload);
  WriteLn('  Port:     ', GPort);
  WriteLn;

  LStart := platform_monotonic_ns;

  SetLength(LHandles, GThreads);
  for LI := 0 to GThreads - 1 do
  begin
    LThreadRequests := GRequests div GThreads;
    if LI < (GRequests mod GThreads) then
      Inc(LThreadRequests);
    platform_thread_create(LHandles[LI], @ClientThread, Pointer(PtrInt(LThreadRequests)));
  end;

  while InterlockedCompareExchange(GDone, 0, 0) < GThreads do
    platform_thread_sleep_ns(1000000);

  for LI := 0 to GThreads - 1 do
    platform_thread_join(LHandles[LI], LRet);

  LEnd := platform_monotonic_ns;
  LElapsedNs := LEnd - LStart;

  LReqPerSec := (GSuccess / (LElapsedNs / 1000000000.0));
  if GSuccess > 0 then
    LNsPerOp := LElapsedNs / GSuccess
  else
    LNsPerOp := 0.0;

  WriteLn('  Completed: ', GSuccess, ' / ', GRequests);
  WriteLn('  Elapsed:   ', LElapsedNs div 1000000, ' ms');
  WriteLn('  Req/s:     ', Trunc(LReqPerSec));
  WriteLn;
  WriteLn('operation=http.server.keepalive');
  WriteLn('workload=', GWorkload);
  WriteLn('impl=nextpas');
  WriteLn('backend=', BackendName);
  WriteLn('nextpas_h1_path=', ExpectedH1PathForWorkload);
  WriteLn('client_read_mode=header_plus_content_length');
  WriteLn('response_body_bytes=', ResponseBodyBytesForWorkload);
  WriteLn('iterations=', GRequests);
  WriteLn('requested_threads=', GRequestedThreads);
  WriteLn('effective_threads=', GThreads);
  WriteLn('threads=', GThreads);
  WriteLn('completed=', GSuccess);
  WriteLn('elapsed_ns=', LElapsedNs);
  WriteLn('ns/op=', Trunc(LNsPerOp));
  WriteLn('req/s=', Trunc(LReqPerSec));
  WriteLn;

  GServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  GServer.Free;
end.
