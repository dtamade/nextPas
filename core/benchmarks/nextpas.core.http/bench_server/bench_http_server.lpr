program bench_http_server;
{**
 * @desc HTTP server multi-client keep-alive QPS + client latency benchmark.
 *       CLI-compatible with run_server_comparison.sh / Go / Rust rows.
 *       L1: emits p50_ns / p99_ns / mean_ns (client-observed).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.server,
  nextpas.core.http.middleware,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.http2.alpn,
  nextpas.core.tls.openssl.backed,
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

type
  PClientCtx = ^TClientCtx;
  TClientCtx = record
    Requests: Int32;
    Samples: array of UInt64;
    SampleCount: Int32;
    Success: Int32;
  end;

var
  GServer: THttpServer;
  GPort: UInt16;
  GDone: Int32;
  GRequests: Int32;
  GRequestedThreads: Int32;
  GThreads: Int32;
  GWorkload: string;
  GBackend: TTcpServerBackend;
  GResponseBody1K: AnsiString;
  GTls: Boolean;
  GClientTls: ISSLContext;

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

function NewServerTlsContext: ISSLContext;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('127.0.0.1')
    .WithOrganization('nextpas-h1-bench')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
end;

function NewClientTlsContext: ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;
end;

function TransportName: string;
begin
  if GTls then
    Result := 'tls-alpn-http1.1'
  else
    Result := 'cleartext-h1';
end;

function ClientThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PClientCtx;
  LI: Int32;
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
  LExpectedBodyLen: SizeUInt;
  LT0, LT1: UInt64;
const
  REQ_NO_URL: AnsiString =
    'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;
  REQ_URL_PATH: AnsiString =
    'GET /api/v1/users HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;
  REQ_ADAPTER_NO_URL: AnsiString =
    'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: keep-alive'#13#10 +
    'Content-Length: 0'#13#10#13#10;
begin
  Result := nil;
  LCtx := PClientCtx(AParam);
  LCtx^.Success := 0;
  LCtx^.SampleCount := 0;
  SetLength(LCtx^.Samples, LCtx^.Requests);
  if GWorkload = WORKLOAD_RESPONSE_1K then
    LExpectedBodyLen := RESPONSE_1K_LEN
  else
    LExpectedBodyLen := SMALL_RESPONSE_LEN;
  try
    LConn := TcpConnect('127.0.0.1', GPort);
    LConn.SetNoDelay(True);
    if GTls then
      LConn := NewTlsClientTcpStream(LConn, GClientTls, '127.0.0.1',
        HTTP11_ALPN_PROTOCOL);
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
    for LI := 1 to LCtx^.Requests do
    begin
      LT0 := platform_monotonic_ns;
      if GWorkload = WORKLOAD_URL_PATH then
        LConn.Write(PAnsiChar(REQ_URL_PATH)^, Length(REQ_URL_PATH))
      else if GWorkload = WORKLOAD_ADAPTER_NO_URL then
        LConn.Write(PAnsiChar(REQ_ADAPTER_NO_URL)^, Length(REQ_ADAPTER_NO_URL))
      else
        LConn.Write(PAnsiChar(REQ_NO_URL)^, Length(REQ_NO_URL));
      LTotal := 0;
      LN := 0;
      repeat
        if LTotal >= SizeUInt(Length(LBuf)) then
          Break;
        LN := LConn.Read(LBuf[LTotal], SizeUInt(Length(LBuf)) - LTotal);
        if LN = 0 then
          Break;
        Inc(LTotal, LN);
      until ResponseComplete(LBuf, LTotal, LExpectedBodyLen);
      if not ResponseComplete(LBuf, LTotal, LExpectedBodyLen) then
        Break;
      LT1 := platform_monotonic_ns;
      if LT1 >= LT0 then
      begin
        LCtx^.Samples[LCtx^.SampleCount] := LT1 - LT0;
        Inc(LCtx^.SampleCount);
      end;
      Inc(LCtx^.Success);
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
  GTls := False;
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
    else if ParamStr(LI) = '--tls' then
    begin
      GTls := True;
      Inc(LI);
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
  Result := 'fast';
end;

function ResponseBodyBytesForWorkload: SizeUInt;
begin
  if GWorkload = WORKLOAD_RESPONSE_1K then
    Exit(RESPONSE_1K_LEN);
  Result := SMALL_RESPONSE_LEN;
end;

procedure SortUInt64(var A: array of UInt64; ALeft, ARight: Integer);
var
  LI, LJ: Integer;
  LPivot, LTmp: UInt64;
begin
  LI := ALeft;
  LJ := ARight;
  LPivot := A[(ALeft + ARight) div 2];
  repeat
    while A[LI] < LPivot do
      Inc(LI);
    while A[LJ] > LPivot do
      Dec(LJ);
    if LI <= LJ then
    begin
      LTmp := A[LI];
      A[LI] := A[LJ];
      A[LJ] := LTmp;
      Inc(LI);
      Dec(LJ);
    end;
  until LI > LJ;
  if ALeft < LJ then
    SortUInt64(A, ALeft, LJ);
  if LI < ARight then
    SortUInt64(A, LI, ARight);
end;

function PercentileNs(var ASamples: array of UInt64; const ACount: Integer;
  const APct: Integer): UInt64;
var
  LIdx: Integer;
begin
  if ACount <= 0 then
    Exit(0);
  if ACount = 1 then
    Exit(ASamples[0]);
  { nearest-rank: index = ceil(pct/100 * N) - 1, clamped }
  LIdx := (APct * ACount + 99) div 100 - 1;
  if LIdx < 0 then
    LIdx := 0;
  if LIdx >= ACount then
    LIdx := ACount - 1;
  Result := ASamples[LIdx];
end;

var
  LHandle: TPlatformThreadHandle;
  LHandles: array of TPlatformThreadHandle;
  LCtxs: array of TClientCtx;
  LServerOptions: THttpServerOptions;
  LI, LJ: Int32;
  LThreadRequests: Int32;
  LStart, LEnd: UInt64;
  LElapsedNs: UInt64;
  LReqPerSec: Double;
  LNsPerOp: Double;
  LRet: Pointer;
  LReadyStart: UInt64;
  LAllSamples: array of UInt64;
  LSampleTotal: Integer;
  LSuccess: Int32;
  LSum: UInt64;
  LP50, LP99, LMean: UInt64;

begin
  ParseOptions;
  if GWorkload = WORKLOAD_RESPONSE_1K then
  begin
    SetLength(GResponseBody1K, RESPONSE_1K_LEN);
    FillChar(GResponseBody1K[1], RESPONSE_1K_LEN, Byte('x'));
  end;
  GDone := 0;

  LServerOptions := THttpServerOptions.Default;
  LServerOptions.Backend := GBackend;
  if GTls then
  begin
    LServerOptions.TLSContext := NewServerTlsContext;
    GClientTls := NewClientTlsContext;
  end;
  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      if (GWorkload = WORKLOAD_URL_PATH) and
         (AReq.Path <> '/api/v1/users') then
      begin
        AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
        Exit;
      end;
      AW.Headers.SetHeader('content-type', 'text/plain');
      if GWorkload = WORKLOAD_RESPONSE_1K then
        AW.Headers.SetHeader('content-length', RESPONSE_1K_LEN_TEXT)
      else
        AW.Headers.SetHeader('content-length', SMALL_RESPONSE_LEN_TEXT);
      AW.WriteHeader(HTTP_STATUS_OK);
      if GWorkload = WORKLOAD_RESPONSE_1K then
        AW.Write(PAnsiChar(GResponseBody1K)^, Length(GResponseBody1K))
      else
        AW.Write(PAnsiChar(SMALL_RESPONSE_BODY)^, SMALL_RESPONSE_LEN);
    end), LServerOptions);

  platform_thread_create(LHandle, @ServerThread, nil);
  LReadyStart := platform_monotonic_ns;
  while (not GServer.IsRunning) or (GServer.LocalAddr.Port = 0) do
  begin
    if platform_monotonic_ns - LReadyStart >= UInt64(5000) * 1000000 then
    begin
      WriteLn(StdErr, 'server not ready');
      Halt(1);
    end;
    platform_thread_sleep_ns(1000000);
  end;
  GPort := GServer.LocalAddr.Port;

  WriteLn('=== HTTP Server Benchmark ===');
  WriteLn('  Requests:  ', GRequests);
  WriteLn('  Threads:   ', GThreads);
  WriteLn('  Workload:  ', GWorkload);
  WriteLn('  Backend:   ', BackendName);
  WriteLn('  Transport: ', TransportName);
  WriteLn('  Port:      ', GPort);
  WriteLn;

  LStart := platform_monotonic_ns;

  SetLength(LHandles, GThreads);
  SetLength(LCtxs, GThreads);
  for LI := 0 to GThreads - 1 do
  begin
    LThreadRequests := GRequests div GThreads;
    if LI < (GRequests mod GThreads) then
      Inc(LThreadRequests);
    LCtxs[LI].Requests := LThreadRequests;
    LCtxs[LI].SampleCount := 0;
    LCtxs[LI].Success := 0;
    platform_thread_create(LHandles[LI], @ClientThread, @LCtxs[LI]);
  end;

  while InterlockedCompareExchange(GDone, 0, 0) < GThreads do
    platform_thread_sleep_ns(1000000);

  for LI := 0 to GThreads - 1 do
    platform_thread_join(LHandles[LI], LRet);

  LEnd := platform_monotonic_ns;
  LElapsedNs := LEnd - LStart;

  LSuccess := 0;
  LSampleTotal := 0;
  for LI := 0 to GThreads - 1 do
  begin
    Inc(LSuccess, LCtxs[LI].Success);
    Inc(LSampleTotal, LCtxs[LI].SampleCount);
  end;

  SetLength(LAllSamples, LSampleTotal);
  LJ := 0;
  LSum := 0;
  for LI := 0 to GThreads - 1 do
  begin
    for LThreadRequests := 0 to LCtxs[LI].SampleCount - 1 do
    begin
      LAllSamples[LJ] := LCtxs[LI].Samples[LThreadRequests];
      Inc(LSum, LAllSamples[LJ]);
      Inc(LJ);
    end;
  end;

  LP50 := 0;
  LP99 := 0;
  LMean := 0;
  if LSampleTotal > 0 then
  begin
    SortUInt64(LAllSamples, 0, LSampleTotal - 1);
    LP50 := PercentileNs(LAllSamples, LSampleTotal, 50);
    LP99 := PercentileNs(LAllSamples, LSampleTotal, 99);
    LMean := LSum div UInt64(LSampleTotal);
  end;

  if LElapsedNs > 0 then
    LReqPerSec := (LSuccess / (LElapsedNs / 1000000000.0))
  else
    LReqPerSec := 0.0;
  if LSuccess > 0 then
    LNsPerOp := LElapsedNs / LSuccess
  else
    LNsPerOp := 0.0;

  WriteLn('  Completed: ', LSuccess, ' / ', GRequests);
  WriteLn('  Elapsed:   ', LElapsedNs div 1000000, ' ms');
  WriteLn('  Req/s:     ', Trunc(LReqPerSec));
  WriteLn('  p50_ns:    ', LP50);
  WriteLn('  p99_ns:    ', LP99);
  WriteLn;
  WriteLn('operation=http.server.keepalive');
  WriteLn('workload=', GWorkload);
  WriteLn('impl=nextpas');
  WriteLn('backend=', BackendName);
  WriteLn('transport=', TransportName);
  if GTls then
    WriteLn('cleartext=false')
  else
    WriteLn('cleartext=true');
  WriteLn('nextpas_h1_path=', ExpectedH1PathForWorkload);
  WriteLn('client_read_mode=header_plus_content_length');
  WriteLn('response_body_bytes=', ResponseBodyBytesForWorkload);
  WriteLn('iterations=', GRequests);
  WriteLn('requested_threads=', GRequestedThreads);
  WriteLn('effective_threads=', GThreads);
  WriteLn('threads=', GThreads);
  WriteLn('completed=', LSuccess);
  WriteLn('elapsed_ns=', LElapsedNs);
  WriteLn('ns/op=', Trunc(LNsPerOp));
  WriteLn('req/s=', Trunc(LReqPerSec));
  WriteLn('latency_samples=', LSampleTotal);
  WriteLn('p50_ns=', LP50);
  WriteLn('p99_ns=', LP99);
  WriteLn('mean_ns=', LMean);
  WriteLn;

  GServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  GServer.Free;
end.
