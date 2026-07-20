program bench_h2_server;
{**
 * @desc H2 server scale harness (S3-1/S3-2).
 *       S3-2: concurrent multiplex via IHttpTransportMultiplex.RoundTripMany,
 *       server backend threaded|epoll, higher default scale.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.h2.client,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  DEFAULT_CONNECTIONS = 8;
  DEFAULT_STREAMS = 16;
  DEFAULT_BATCHES = 200;
  MODE_SEQUENTIAL = 'sequential';
  MODE_MULTIPLEX = 'multiplex';
  BACKEND_THREADED = 'threaded';
  BACKEND_EPOLL = 'epoll';
  SMALL_BODY = 'h2-ok';

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: IHttpServer;
  end;

  PClientCtx = ^TClientCtx;
  TClientCtx = record
    Port: UInt16;
    Streams: Int32;
    Batches: Int32;
    Mode: string;
    Success: Int32;
    Fail: Int32;
  end;

var
  GConnections: Int32;
  GStreams: Int32;
  GBatches: Int32;
  GMode: string;
  GBackend: TTcpServerBackend;
  GDone: Int32;

procedure RejectInvalid(const AName, AValue: string);
begin
  WriteLn(StdErr, 'invalid ', AName, ': ', AValue);
  Halt(2);
end;

function ParsePositive(const AName, AValue: string): Int32;
var
  LValue: Integer;
begin
  if (not TryStrToInt(AValue, LValue)) or (LValue < 1) then
    RejectInvalid(AName, AValue);
  Result := LValue;
end;

function BackendName: string;
begin
  case GBackend of
    TCP_SERVER_BACKEND_THREADED:
      Result := BACKEND_THREADED;
    TCP_SERVER_BACKEND_EPOLL:
      Result := BACKEND_EPOLL;
  else
    Result := 'unknown';
  end;
end;

procedure ParseOptions;
var
  LI: Integer;
begin
  GConnections := DEFAULT_CONNECTIONS;
  GStreams := DEFAULT_STREAMS;
  GBatches := DEFAULT_BATCHES;
  GMode := MODE_MULTIPLEX;
  { S3-3: poll would-block I/O fixed; epoll is viable scale path. }
  GBackend := TCP_SERVER_BACKEND_EPOLL;
  LI := 1;
  while LI <= ParamCount do
  begin
    if (ParamStr(LI) = '--connections') and (LI < ParamCount) then
    begin
      GConnections := ParsePositive('--connections', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--streams') and (LI < ParamCount) then
    begin
      GStreams := ParsePositive('--streams', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--batches') and (LI < ParamCount) then
    begin
      GBatches := ParsePositive('--batches', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--requests') and (LI < ParamCount) then
    begin
      { Alias for --batches (S3-1 CLI compatibility). }
      GBatches := ParsePositive('--requests', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--mode') and (LI < ParamCount) then
    begin
      if (ParamStr(LI + 1) = MODE_SEQUENTIAL) or
         (ParamStr(LI + 1) = MODE_MULTIPLEX) then
        GMode := ParamStr(LI + 1)
      else
        RejectInvalid('--mode', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--backend') and (LI < ParamCount) then
    begin
      if ParamStr(LI + 1) = BACKEND_THREADED then
        GBackend := TCP_SERVER_BACKEND_THREADED
      else if ParamStr(LI + 1) = BACKEND_EPOLL then
        GBackend := TCP_SERVER_BACKEND_EPOLL
      else
        RejectInvalid('--backend', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else
      Inc(LI);
  end;
end;

function ServerThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AParam);
  try
    LCtx^.Server.ListenAndServe('127.0.0.1', 0);
  except
  end;
end;

function ClientThread(AParam: Pointer): Pointer; cdecl;
var
  LCtx: PClientCtx;
  LTransport: IHttpTransport;
  LMux: IHttpTransportMultiplex;
  LClient: IHttpClient;
  LOpts: TH2ClientTransportOptions;
  LUrl: string;
  LI, LJ: Int32;
  LBatch: Int32;
  LOk: Boolean;
  LResp: IHttpResponse;
  LReqs: array of IHttpRequest;
  LResps: THttpResponseArray;
begin
  Result := nil;
  LCtx := PClientCtx(AParam);
  LCtx^.Success := 0;
  LCtx^.Fail := 0;
  LUrl := 'http://127.0.0.1:' + IntToStr(Int64(LCtx^.Port)) + '/';
  LBatch := LCtx^.Streams;
  if LBatch < 1 then
    LBatch := 1;

  try
    if LCtx^.Mode = MODE_MULTIPLEX then
    begin
      LOpts := TH2ClientTransportOptions.Default;
      LOpts.Timeout := 30000;
      LTransport := NewH2ClientTransport(LOpts);
      if not Supports(LTransport, IHttpTransportMultiplex, LMux) then
      begin
        Inc(LCtx^.Fail);
        InterlockedIncrement(GDone);
        Exit;
      end;
      for LI := 1 to LCtx^.Batches do
      begin
        SetLength(LReqs, LBatch);
        for LJ := 0 to LBatch - 1 do
          LReqs[LJ] := NewRequest(hmGet, LUrl);
        try
          LResps := LMux.RoundTripMany(LReqs);
          if Length(LResps) <> LBatch then
            Inc(LCtx^.Fail, LBatch)
          else
            for LJ := 0 to LBatch - 1 do
            begin
              if (LResps[LJ] <> nil) and
                 (LResps[LJ].StatusCode = HTTP_STATUS_OK) then
                Inc(LCtx^.Success)
              else
                Inc(LCtx^.Fail);
            end;
        except
          Inc(LCtx^.Fail, LBatch);
        end;
        LResps := nil;
        for LJ := 0 to High(LReqs) do
          LReqs[LJ] := nil;
      end;
    end
    else
    begin
      { sequential: public facade client (S3-1 residual). }
      LClient := NewHttpClient(
        THttpClientOptions.Default.WithVersion(hvHttp2).WithTimeout(30000));
      for LI := 1 to LCtx^.Batches do
        for LJ := 0 to LBatch - 1 do
        begin
          LOk := False;
          try
            LResp := LClient.Get(LUrl);
            LOk := (LResp <> nil) and (LResp.StatusCode = HTTP_STATUS_OK);
          except
            LOk := False;
          end;
          if LOk then
            Inc(LCtx^.Success)
          else
            Inc(LCtx^.Fail);
        end;
    end;
  except
    Inc(LCtx^.Fail);
  end;
  InterlockedIncrement(GDone);
end;

var
  LServer: IHttpServer;
  LServerCtx: TServerCtx;
  LHandle: TPlatformThreadHandle;
  LHandles: array of TPlatformThreadHandle;
  LCtxs: array of TClientCtx;
  LOpts: THttpServerOptions;
  LRouter: IHttpRouter;
  LPort: UInt16;
  LI: Int32;
  LRet: Pointer;
  LStart, LEnd: UInt64;
  LElapsedNs: UInt64;
  LSuccess, LFail: Int32;
  LReqPerSec: Double;
  LReadyStart: UInt64;
  LTarget: Int32;
  LStable: Int32;

begin
  ParseOptions;
  GDone := 0;
  LTarget := GConnections * GStreams * GBatches;

  LRouter := NewRouter;
  LRouter.Get('/', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', SMALL_BODY);
  end);

  LOpts := THttpServerOptions.Default.WithVersion(hvHttp2).WithIdleTimeout(60000);
  LOpts.Backend := GBackend;
  LServer := NewHttpServer(LRouter as IHttpHandler, LOpts);
  LServerCtx.Server := LServer;
  platform_thread_create(LHandle, @ServerThread, @LServerCtx);

  LReadyStart := platform_monotonic_ns;
  while (not LServer.IsRunning) or (LServer.LocalAddr.Port = 0) do
  begin
    if platform_monotonic_ns - LReadyStart >= UInt64(5000) * 1000000 then
    begin
      WriteLn(StdErr, 'h2 server not ready');
      Halt(1);
    end;
    platform_thread_sleep_ns(1000000);
  end;
  LPort := LServer.LocalAddr.Port;

  WriteLn('=== HTTP/2 Server Scale Harness ===');
  WriteLn('  mode=', GMode);
  WriteLn('  backend=', BackendName);
  WriteLn('  connections=', GConnections);
  WriteLn('  streams_per_batch=', GStreams);
  WriteLn('  batches_per_conn=', GBatches);
  WriteLn('  target_ops=', LTarget);
  WriteLn('  port=', LPort);
  WriteLn;

  LStart := platform_monotonic_ns;
  SetLength(LHandles, GConnections);
  SetLength(LCtxs, GConnections);
  for LI := 0 to GConnections - 1 do
  begin
    LCtxs[LI].Port := LPort;
    LCtxs[LI].Streams := GStreams;
    LCtxs[LI].Batches := GBatches;
    LCtxs[LI].Mode := GMode;
    LCtxs[LI].Success := 0;
    LCtxs[LI].Fail := 0;
    platform_thread_create(LHandles[LI], @ClientThread, @LCtxs[LI]);
  end;

  while InterlockedCompareExchange(GDone, 0, 0) < GConnections do
    platform_thread_sleep_ns(1000000);

  for LI := 0 to GConnections - 1 do
    platform_thread_join(LHandles[LI], LRet);

  LEnd := platform_monotonic_ns;
  LElapsedNs := LEnd - LStart;

  LSuccess := 0;
  LFail := 0;
  for LI := 0 to GConnections - 1 do
  begin
    Inc(LSuccess, LCtxs[LI].Success);
    Inc(LFail, LCtxs[LI].Fail);
  end;
  if LElapsedNs > 0 then
    LReqPerSec := (LSuccess / (LElapsedNs / 1000000000.0))
  else
    LReqPerSec := 0.0;

  if (LFail = 0) and (LSuccess = LTarget) then
    LStable := 1
  else
    LStable := 0;

  WriteLn('  success=', LSuccess, ' fail=', LFail);
  WriteLn('  elapsed_ms=', LElapsedNs div 1000000);
  WriteLn('  req/s=', Trunc(LReqPerSec));
  WriteLn('  stable=', LStable);
  WriteLn;
  WriteLn('operation=http.server.h2');
  WriteLn('impl=nextpas');
  WriteLn('protocol=h2');
  WriteLn('mode=', GMode);
  WriteLn('backend=', BackendName);
  WriteLn('cleartext=prior_knowledge');
  WriteLn('connections=', GConnections);
  WriteLn('streams_per_batch=', GStreams);
  WriteLn('batches_per_conn=', GBatches);
  WriteLn('target_ops=', LTarget);
  WriteLn('completed=', LSuccess);
  WriteLn('failed=', LFail);
  WriteLn('elapsed_ns=', LElapsedNs);
  WriteLn('req/s=', Trunc(LReqPerSec));
  WriteLn('stable=', LStable);
  WriteLn;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  LServer := nil;

  if LStable = 1 then
    Halt(0)
  else
    Halt(1);
end.
