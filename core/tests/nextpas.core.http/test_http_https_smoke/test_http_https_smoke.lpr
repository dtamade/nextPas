program test_http_https_smoke;
{**
 * @desc Q3-3 H1 HTTPS smoke: keep-alive throughput + client latency under
 *       heaptrc. Origin is a minimal TLS H1 server (registry TLS server path
 *       is H2-only residual — see CONTRACT residual).
 *
 * Not a scale-ready claim for HTTPS; plain H1 epoll RPS remains the KPI.
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.openssl.backed,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

const
  SMOKE_REQUESTS = 30;
  SMOKE_BODY = 'https-ok';
  REPLY =
    'HTTP/1.1 200 OK'#13#10 +
    'Content-Type: text/plain'#13#10 +
    'Content-Length: 8'#13#10 +
    'Connection: keep-alive'#13#10 +
    #13#10 +
    SMOKE_BODY;

var
  T: TTestSuite;
  GListener: ITcpListener;
  GServerCtx: ISSLContext;
  GServerStop: Boolean;
  GServerAccepts: Int32;
  GServerReqs: Int32;

function NewClientCtx: ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;
end;

function NewServerCtx: ISSLContext;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName('127.0.0.1')
    .WithOrganization('nextpas-http-q3-3')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
end;

function ReadOneHttpRequest(const AConn: ITcpStream;
  const AIdleTimeoutMs: Int64): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LP: SizeInt;
begin
  Result := '';
  AConn.SetReadDeadline(
    TDeadline.After(TDuration.FromMilliseconds(AIdleTimeoutMs)));
  try
    repeat
      LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      if LN = 0 then
        Break;
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      LP := Pos(#13#10#13#10, Result);
    until LP > 0;
  except
    Result := '';
  end;
end;

function KeepAliveServerThread(AArg: Pointer): Pointer; cdecl;
{ Multi-accept loop: supports keep-alive reuse and reconnect if pool misses. }
var
  LConn, LTls: ITcpStream;
  LReq: string;
  LReqN: Int32;
begin
  Result := nil;
  while not GServerStop do
  begin
    try
      LConn := GListener.Accept;
    except
      Break;
    end;
    if LConn = nil then
      Break;
    InterlockedIncrement(GServerAccepts);
    try
      LTls := NewTlsServerTcpStream(LConn, GServerCtx);
      try
        LReqN := 0;
        while (not GServerStop) and (LReqN < SMOKE_REQUESTS + 8) do
        begin
          { First request: generous; later keep-alive idle must be short so
            Accept is not blocked when client opens a new connection. }
          if LReqN = 0 then
            LReq := ReadOneHttpRequest(LTls, 5000)
          else
            LReq := ReadOneHttpRequest(LTls, 250);
          if LReq = '' then
            Break;
          Inc(LReqN);
          InterlockedIncrement(GServerReqs);
          LTls.Write(REPLY[1], SizeUInt(Length(REPLY)));
          if (Pos('Connection: close', LReq) > 0) or
             (Pos('connection: close', LReq) > 0) then
            Break;
        end;
      finally
        LTls.Close;
      end;
    except
    end;
    LConn.Close;
  end;
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

function PercentileNs(var ASamples: array of UInt64; const ACount, APct: Integer): UInt64;
var
  LIdx: Integer;
begin
  if ACount <= 0 then
    Exit(0);
  if ACount = 1 then
    Exit(ASamples[0]);
  LIdx := (APct * ACount + 99) div 100 - 1;
  if LIdx < 0 then
    LIdx := 0;
  if LIdx >= ACount then
    LIdx := ACount - 1;
  Result := ASamples[LIdx];
end;

procedure TestH1HttpsKeepAliveSmokeThroughputLatency;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
  LUrl: string;
  LI: Int32;
  LOk: Int32;
  LT0, LT1, LStart, LEnd: UInt64;
  LSamples: array of UInt64;
  LP50, LP99, LMean, LSum: UInt64;
  LElapsedNs: UInt64;
  LReqPerSec: Double;
begin
  GServerStop := False;
  GServerAccepts := 0;
  GServerReqs := 0;
  GServerCtx := NewServerCtx;
  GListener := TcpListen('127.0.0.1', 0);
  LPort := GListener.LocalAddr.Port;
  platform_thread_create(LHandle, @KeepAliveServerThread, nil);
  { Give Accept thread a slice before first dial (TLS handshake race). }
  platform_thread_sleep_ns(50000000);
  try
    LOpts := THttpClientOptions.Default
      .WithTimeout(15000)
      .WithConnectTimeout(10000);
    LOpts.TLSContext := NewClientCtx;
    LClient := NewHttpClient(LOpts);
    LUrl := 'https://127.0.0.1:' + IntToStr(Int64(LPort)) + '/smoke';
    SetLength(LSamples, SMOKE_REQUESTS);
    LOk := 0;
    LSum := 0;
    LStart := platform_monotonic_ns;
    for LI := 0 to SMOKE_REQUESTS - 1 do
    begin
      LT0 := platform_monotonic_ns;
      LResp := LClient.Get(LUrl);
      LT1 := platform_monotonic_ns;
      Check(LResp <> nil, 'https smoke response');
      Checkequal(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'https 200');
      Checkequal(SMOKE_BODY, HttpReadResponseBodyString(LResp), 'https body');
      LResp := nil;
      if LT1 >= LT0 then
      begin
        LSamples[LOk] := LT1 - LT0;
        Inc(LSum, LSamples[LOk]);
      end;
      Inc(LOk);
    end;
    LEnd := platform_monotonic_ns;
    Checkequal(Int64(SMOKE_REQUESTS), Int64(LOk), 'all https requests ok');
    Check(GServerReqs >= SMOKE_REQUESTS, 'server saw requests');
    Check(GServerAccepts >= 1, 'at least one TLS accept');
    { RH-1: TLS streams must be pool-reusable → one accept for N keep-alive GETs. }
    Checkequal(Int64(1), Int64(GServerAccepts),
      'HTTPS keep-alive reuses one TLS connection (accepts=1)');
    Check(GServerReqs >= SMOKE_REQUESTS, 'all reqs on keep-alive connection');

    SortUInt64(LSamples, 0, SMOKE_REQUESTS - 1);
    LP50 := PercentileNs(LSamples, SMOKE_REQUESTS, 50);
    LP99 := PercentileNs(LSamples, SMOKE_REQUESTS, 99);
    LMean := LSum div UInt64(SMOKE_REQUESTS);
    LElapsedNs := LEnd - LStart;
    if LElapsedNs > 0 then
      LReqPerSec := (SMOKE_REQUESTS / (LElapsedNs / 1000000000.0))
    else
      LReqPerSec := 0;

    WriteLn('q3_3_https_smoke=h1_client');
    WriteLn('requests=', SMOKE_REQUESTS);
    WriteLn('server_accepts=', GServerAccepts);
    WriteLn('server_reqs=', GServerReqs);
    if GServerAccepts > 0 then
      WriteLn('reqs_per_accept=', GServerReqs div GServerAccepts)
    else
      WriteLn('reqs_per_accept=0');
    WriteLn('elapsed_ns=', LElapsedNs);
    WriteLn('req/s=', Trunc(LReqPerSec));
    WriteLn('p50_ns=', LP50);
    WriteLn('p99_ns=', LP99);
    WriteLn('mean_ns=', LMean);
    WriteLn('latency_samples=', SMOKE_REQUESTS);

    { Keep-alive reuse: expect substantially faster than per-request handshake. }
    Check(LReqPerSec > 10, 'https keep-alive smoke throughput floor (>10 req/s)');
    Check(LP99 > 0, 'p99 recorded');
    Check(LP50 <= LP99, 'p50 <= p99');

    LClient.CloseIdleConnections;
    LClient := nil;
    LOpts.TLSContext := nil;
  finally
    GServerStop := True;
    if GListener <> nil then
      GListener.Close;
    platform_thread_join(LHandle, LRet);
    GListener := nil;
    GServerCtx := nil;
  end;
end;

procedure TestH1HttpsServerTlsRegistryResidualSourceContract;
{ Registry: THttpServerOptions.TLSContext currently selects H2 TLS transport
  only — H1 HTTPS origin for Q3-3 smoke uses NewTlsServerTcpStream (client
  H1 direct HTTPS is production). }
var
  LReg, LContract: string;
begin
  LReg := ReadFileText('../../../src/nextpas.core.http.impl.registry.pas');
  LContract := ReadFileText('../../../docs/http/CONTRACT.md');
  Check(Pos('TLS HTTP server currently requires HTTP/2', LReg) > 0,
    'registry documents H1 server TLS residual');
  Check(Pos('Q3-3', LContract) > 0, 'CONTRACT has Q3-3 residual section');
  Check(Pos('0 unfreed', LContract) > 0, 'HTTPS residual claims 0 unfreed (R4)');
end;

procedure TestH1HttpsClientRoundTripStillGreen;
{ Regression: single-shot direct HTTPS (same path as Wave E). }
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
begin
  GServerStop := False;
  GServerAccepts := 0;
  GServerReqs := 0;
  GServerCtx := NewServerCtx;
  GListener := TcpListen('127.0.0.1', 0);
  LPort := GListener.LocalAddr.Port;
  platform_thread_create(LHandle, @KeepAliveServerThread, nil);
  platform_thread_sleep_ns(50000000);
  try
    LOpts := THttpClientOptions.Default.WithTimeout(8000).WithConnectTimeout(4000);
    LOpts.TLSContext := NewClientCtx;
    LClient := NewHttpClient(LOpts);
    LResp := LClient.Get('https://127.0.0.1:' + IntToStr(Int64(LPort)) + '/once');
    Checkequal(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode), 'single https 200');
    Checkequal(SMOKE_BODY, HttpReadResponseBodyString(LResp), 'single body');
    LResp := nil;
    LClient.CloseIdleConnections;
    LClient := nil;
  finally
    GServerStop := True;
    if GListener <> nil then
      GListener.Close;
    platform_thread_join(LHandle, LRet);
    GListener := nil;
    GServerCtx := nil;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.http Q3-3 H1 HTTPS smoke');
  T.Test('H1 HTTPS keep-alive smoke throughput + p50/p99',
    @TestH1HttpsKeepAliveSmokeThroughputLatency);
  T.Test('H1 HTTPS single round-trip still green',
    @TestH1HttpsClientRoundTripStillGreen);
  T.Test('H1 server TLS registry residual source-contract',
    @TestH1HttpsServerTlsRegistryResidualSourceContract);
  if not T.Run then
    Halt(1);
end.
