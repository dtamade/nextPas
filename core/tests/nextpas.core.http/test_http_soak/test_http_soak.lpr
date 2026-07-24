program test_http_soak;
{**
 * @desc Q3-1 production soak: H1 keep-alive + H2 multiplex under heaptrc.
 *       Gate is correctness + 0 unfreed at process exit (common.mk -gh).
 *       Not a throughput ranking; sizes stay CI-friendly (~seconds).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.h2.client,
  nextpas.core.platform.thread;

const
  { CI-friendly soak sizes: enough to catch per-request retain, not a load test. }
  H1_SOAK_REQUESTS = 1500;
  H2_SEQ_REQUESTS = 400;
  H2_MUX_STREAMS = 8;
  H2_MUX_BATCHES = 50; { 400 multiplex ops total }
  H2_MUX_EPOLL_BATCHES = 20; { 160 ops on epoll }
  SERVER_IDLE_MS = 5000;
  CLIENT_TIMEOUT_MS = 15000;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: IHttpServer;
    Addr: string;
    Port: UInt16;
  end;

var
  T: TTestSuite;

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

function StartServer(const AHandler: IHttpHandler;
  const AOpts: THttpServerOptions; out AServer: IHttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := NewHttpServer(AHandler, AOpts);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'soak server started');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'soak server bound port');
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

function LocalUrl(const APort: UInt16; const APath: string): string;
begin
  Result := 'http://127.0.0.1:' + IntToStr(Int64(APort)) + APath;
end;

function NewPingRouter: IHttpRouter;
begin
  Result := NewRouter;
  Result.Get('/ping', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'pong');
  end);
end;

procedure RunH1KeepAliveSoak(const ABackend: TTcpServerBackend;
  const ALabel: string);
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOpts: THttpServerOptions;
  LResp: IHttpResponse;
  LUrl: string;
  LI: Int32;
  LOk: Int32;
  LBody: string;
begin
  LRouter := NewPingRouter;
  LOpts := THttpServerOptions.Default.WithIdleTimeout(SERVER_IDLE_MS);
  LOpts.Backend := ABackend;
  LHandle := StartServer(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LClient := NewHttpClient(
      THttpClientOptions.Default.WithTimeout(CLIENT_TIMEOUT_MS));
    LUrl := LocalUrl(LPort, '/ping');
    LOk := 0;
    try
      for LI := 1 to H1_SOAK_REQUESTS do
      begin
        LResp := LClient.Get(LUrl);
        Check(LResp <> nil, ALabel + ': response non-nil');
        CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode),
          ALabel + ': status 200');
        LBody := HttpReadResponseBodyString(LResp);
        CheckEqual('pong', LBody, ALabel + ': body');
        LResp := nil;
        Inc(LOk);
      end;
      CheckEqual(Int64(H1_SOAK_REQUESTS), Int64(LOk), ALabel + ': completed all');
    finally
      LResp := nil;
      LClient := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestH1KeepAliveSoakThreaded;
begin
  RunH1KeepAliveSoak(TCP_SERVER_BACKEND_THREADED, 'H1 threaded soak');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestH1KeepAliveSoakEpoll;
begin
  RunH1KeepAliveSoak(TCP_SERVER_BACKEND_EPOLL, 'H1 epoll soak');
end;
{$ENDIF}

procedure TestH2SequentialSoak;
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOpts: THttpServerOptions;
  LResp: IHttpResponse;
  LUrl: string;
  LI: Int32;
  LOk: Int32;
begin
  LRouter := NewPingRouter;
  LOpts := THttpServerOptions.Default.WithVersion(hvHttp2)
    .WithIdleTimeout(SERVER_IDLE_MS);
  LHandle := StartServer(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LClient := NewHttpClient(
      THttpClientOptions.Default.WithVersion(hvHttp2)
        .WithTimeout(CLIENT_TIMEOUT_MS));
    LUrl := LocalUrl(LPort, '/ping');
    LOk := 0;
    try
      for LI := 1 to H2_SEQ_REQUESTS do
      begin
        LResp := LClient.Get(LUrl);
        Check(LResp <> nil, 'H2 seq: response');
        CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResp.StatusCode),
          'H2 seq: 200');
        CheckEqual('pong', HttpReadResponseBodyString(LResp), 'H2 seq: body');
        LResp := nil;
        Inc(LOk);
      end;
      CheckEqual(Int64(H2_SEQ_REQUESTS), Int64(LOk), 'H2 seq completed');
    finally
      LResp := nil;
      LClient := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure RunH2MultiplexSoak(const ABackend: TTcpServerBackend;
  const ABatches: Int32; const ALabel: string);
var
  LRouter: IHttpRouter;
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LTransport: IHttpTransport;
  LMux: IHttpTransportMultiplex;
  LH2Opts: TH2ClientTransportOptions;
  LUrl: string;
  LReqs: array of IHttpRequest;
  LResps: THttpResponseArray;
  LI, LJ: Int32;
  LOk: Int32;
  LTarget: Int32;
begin
  LTarget := ABatches * H2_MUX_STREAMS;
  LRouter := NewPingRouter;
  LOpts := THttpServerOptions.Default.WithVersion(hvHttp2)
    .WithIdleTimeout(SERVER_IDLE_MS);
  LOpts.Backend := ABackend;
  LHandle := StartServer(LRouter as IHttpHandler, LOpts, LServer, LPort);
  try
    LH2Opts := TH2ClientTransportOptions.Default;
    LH2Opts.Timeout := CLIENT_TIMEOUT_MS;
    LTransport := NewH2ClientTransport(LH2Opts);
    Check(Supports(LTransport, IHttpTransportMultiplex, LMux),
      ALabel + ': transport multiplex');
    LUrl := LocalUrl(LPort, '/ping');
    LOk := 0;
    try
      for LI := 1 to ABatches do
      begin
        SetLength(LReqs, H2_MUX_STREAMS);
        for LJ := 0 to H2_MUX_STREAMS - 1 do
          LReqs[LJ] := NewRequest(hmGet, LUrl);
        try
          LResps := LMux.RoundTripMany(LReqs);
          CheckEqual(Int64(H2_MUX_STREAMS), Int64(Length(LResps)),
            ALabel + ': batch size');
          for LJ := 0 to H2_MUX_STREAMS - 1 do
          begin
            Check(LResps[LJ] <> nil, ALabel + ': resp non-nil');
            CheckEqual(Int64(HTTP_STATUS_OK), Int64(LResps[LJ].StatusCode),
              ALabel + ': status');
            CheckEqual('pong', HttpReadResponseBodyString(LResps[LJ]),
              ALabel + ': body');
            Inc(LOk);
          end;
        finally
          LResps := nil;
          for LJ := 0 to High(LReqs) do
            LReqs[LJ] := nil;
          SetLength(LReqs, 0);
        end;
      end;
      CheckEqual(Int64(LTarget), Int64(LOk), ALabel + ': all mux ops');
    finally
      LResps := nil;
      LReqs := nil;
      LMux := nil;
      LTransport := nil;
    end;
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestH2MultiplexSoakThreaded;
begin
  RunH2MultiplexSoak(TCP_SERVER_BACKEND_THREADED, H2_MUX_BATCHES,
    'H2 mux threaded');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestH2MultiplexSoakEpoll;
begin
  RunH2MultiplexSoak(TCP_SERVER_BACKEND_EPOLL, H2_MUX_EPOLL_BATCHES,
    'H2 mux epoll');
end;
{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.http soak (Q3-1)');
  T.Test('H1 keep-alive soak threaded (1500×)', @TestH1KeepAliveSoakThreaded);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('H1 keep-alive soak epoll (1500×)', @TestH1KeepAliveSoakEpoll);
  {$ENDIF}
  T.Test('H2 sequential soak facade (400×)', @TestH2SequentialSoak);
  T.Test('H2 multiplex soak RoundTripMany threaded (50×8)',
    @TestH2MultiplexSoakThreaded);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('H2 multiplex soak RoundTripMany epoll (20×8)',
    @TestH2MultiplexSoakEpoll);
  {$ENDIF}
  if not T.Run then
    Halt(1);
end.
