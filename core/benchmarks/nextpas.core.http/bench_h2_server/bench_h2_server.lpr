program bench_h2_server;
{**
 * @desc H2 server multi-connection / multi-stream scale harness (S3-1).
 *       Cleartext prior-knowledge HTTP/2 via public facade (same as
 *       test_http_h2_facade). Not an H1 comparison KPI; baseline for S3.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  DEFAULT_CONNECTIONS = 4;
  DEFAULT_STREAMS = 4;
  DEFAULT_REQUESTS = 100;
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
    Requests: Int32;
    Success: Int32;
    Fail: Int32;
  end;

var
  GConnections: Int32;
  GStreams: Int32;
  GRequests: Int32;
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

procedure ParseOptions;
var
  LI: Integer;
begin
  GConnections := DEFAULT_CONNECTIONS;
  GStreams := DEFAULT_STREAMS;
  GRequests := DEFAULT_REQUESTS;
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
    else if (ParamStr(LI) = '--requests') and (LI < ParamCount) then
    begin
      GRequests := ParsePositive('--requests', ParamStr(LI + 1));
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
  LClient: IHttpClient;
  LUrl: string;
  LI, LJ: Int32;
  LBatch: Int32;
  LOk: Boolean;
  LResp: IHttpResponse;
begin
  Result := nil;
  LCtx := PClientCtx(AParam);
  LCtx^.Success := 0;
  LCtx^.Fail := 0;
  LUrl := 'http://127.0.0.1:' + IntToStr(Int64(LCtx^.Port)) + '/';
  try
    LClient := NewHttpClient(
      THttpClientOptions.Default.WithVersion(hvHttp2).WithTimeout(10000));
    { S3-1 baseline: sequential GETs on H2 keep-alive (facade path).
      True concurrent multiplex via RoundTripMany is S3-2+ (transport seam). }
    for LI := 1 to LCtx^.Requests do
    begin
      LBatch := LCtx^.Streams;
      if LBatch < 1 then
        LBatch := 1;
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

begin
  ParseOptions;
  GDone := 0;

  LRouter := NewRouter;
  LRouter.Get('/', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', SMALL_BODY);
  end);

  LOpts := THttpServerOptions.Default.WithVersion(hvHttp2).WithIdleTimeout(30000);
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

  WriteLn('=== HTTP/2 Server Scale Harness (S3-1) ===');
  WriteLn('  connections=', GConnections);
  WriteLn('  streams_per_batch=', GStreams);
  WriteLn('  batches_per_conn=', GRequests);
  WriteLn('  port=', LPort);
  WriteLn;

  LStart := platform_monotonic_ns;
  SetLength(LHandles, GConnections);
  SetLength(LCtxs, GConnections);
  for LI := 0 to GConnections - 1 do
  begin
    LCtxs[LI].Port := LPort;
    LCtxs[LI].Streams := GStreams;
    LCtxs[LI].Requests := GRequests;
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

  WriteLn('  success=', LSuccess, ' fail=', LFail);
  WriteLn('  elapsed_ms=', LElapsedNs div 1000000);
  WriteLn('  req/s=', Trunc(LReqPerSec));
  WriteLn;
  WriteLn('operation=http.server.h2');
  WriteLn('impl=nextpas');
  WriteLn('protocol=h2');
  WriteLn('mode=cleartext_prior_knowledge');
  WriteLn('connections=', GConnections);
  WriteLn('streams_per_batch=', GStreams);
  WriteLn('batches_per_conn=', GRequests);
  WriteLn('target_ops=', GConnections * GStreams * GRequests);
  WriteLn('completed=', LSuccess);
  WriteLn('failed=', LFail);
  WriteLn('elapsed_ns=', LElapsedNs);
  WriteLn('req/s=', Trunc(LReqPerSec));
  WriteLn('stable=', Ord((LFail = 0) and (LSuccess = GConnections * GStreams * GRequests)));
  WriteLn;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  LServer := nil;

  if (LFail = 0) and (LSuccess = GConnections * GStreams * GRequests) then
    Halt(0)
  else
    Halt(1);
end.
