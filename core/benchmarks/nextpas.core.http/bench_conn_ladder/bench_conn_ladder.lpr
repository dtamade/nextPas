program bench_conn_ladder;
{**
 * @desc HTTP server connection ladder: open N keep-alive connections, idle hold,
 *       optional probe request. Documents stable points and failure modes (fd limits).
 *       Not a QPS harness — see bench_http_server for multi-conn RPS.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.server,
  nextpas.core.http.middleware,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.platform.resource,
  nextpas.core.platform.resource.base;

const
  DEFAULT_CONNECTIONS = 100;
  DEFAULT_HOLD_MS = 2000;
  DEFAULT_BATCH = 64;
  DEFAULT_PROBE = 1;
  DEFAULT_RAISE_NOFILE = 1;
  BENCH_BACKEND_THREADED = 'threaded';
  BENCH_BACKEND_EPOLL = 'epoll';
  SMALL_RESPONSE_BODY = 'Hello, World!';
  SMALL_RESPONSE_LEN = 13;
  SMALL_RESPONSE_LEN_TEXT = '13';
  REQ_NO_URL: AnsiString =
    'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Content-Length: 0'#13#10#13#10;

var
  GServer: THttpServer;
  GPort: UInt16;
  GConnections: Int32;
  GHoldMs: Int32;
  GBatch: Int32;
  GProbe: Boolean;
  GRaiseNofile: Boolean;
  GBackend: TTcpServerBackend;
  GOpenOk: Int32;
  GOpenFail: Int32;
  GProbeOk: Int32;
  GProbeFail: Int32;
  GNofileRaise: string;
  GNofileSoft: UInt64;
  GNofileHard: UInt64;
  GServerIdleTimeoutMs: Int64;

procedure RejectInvalidPositiveOption(const AName, AValue: string);
begin
  WriteLn(StdErr, 'invalid ', AName, ': ', AValue,
    '; expected non-negative integer');
  Halt(2);
end;

procedure RejectInvalidBackend(const AValue: string);
begin
  WriteLn(StdErr, 'invalid --backend: ', AValue,
    '; expected one of: threaded or epoll');
  Halt(2);
end;

function ParseNonNegativeOption(const AName, AValue: string): Int32;
var
  LValue: Integer;
begin
  if (not TryStrToInt(AValue, LValue)) or (LValue < 0) then
    RejectInvalidPositiveOption(AName, AValue);
  Result := LValue;
end;

function ParsePositiveOption(const AName, AValue: string): Int32;
var
  LValue: Integer;
begin
  if (not TryStrToInt(AValue, LValue)) or (LValue < 1) then
  begin
    WriteLn(StdErr, 'invalid ', AName, ': ', AValue,
      '; expected positive integer');
    Halt(2);
  end;
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

function ParseBool01(const AName, AValue: string): Boolean;
begin
  if AValue = '0' then
    Exit(False);
  if AValue = '1' then
    Exit(True);
  WriteLn(StdErr, 'invalid ', AName, ': ', AValue, '; expected 0 or 1');
  Halt(2);
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

function ReadFullResponse(const AConn: ITcpStream): Boolean;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
begin
  Result := False;
  LTotal := 0;
  LN := 0;
  repeat
    if LTotal >= SizeUInt(Length(LBuf)) then
      Exit;
    LN := AConn.Read(LBuf[LTotal], SizeUInt(Length(LBuf)) - LTotal);
    if LN = 0 then
      Exit;
    Inc(LTotal, LN);
  until ResponseComplete(LBuf, LTotal, SMALL_RESPONSE_LEN);
  Result := ResponseComplete(LBuf, LTotal, SMALL_RESPONSE_LEN);
end;

function ExchangeRequest(const AConn: ITcpStream): Boolean;
begin
  Result := False;
  try
    AConn.Write(PAnsiChar(REQ_NO_URL)^, Length(REQ_NO_URL));
    Result := ReadFullResponse(AConn);
  except
    Result := False;
  end;
end;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  try
    GServer.ListenAndServe('127.0.0.1', 0);
  except
    { Keep ladder harness process alive for failure-mode reporting. }
  end;
end;

procedure ParseOptions;
var
  LI: Integer;
begin
  GConnections := DEFAULT_CONNECTIONS;
  GHoldMs := DEFAULT_HOLD_MS;
  GBatch := DEFAULT_BATCH;
  GProbe := DEFAULT_PROBE <> 0;
  GRaiseNofile := DEFAULT_RAISE_NOFILE <> 0;
  GBackend := TCP_SERVER_BACKEND_EPOLL;
  LI := 1;
  while LI <= ParamCount do
  begin
    if (ParamStr(LI) = '--connections') and (LI < ParamCount) then
    begin
      GConnections := ParsePositiveOption('--connections', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--hold-ms') and (LI < ParamCount) then
    begin
      GHoldMs := ParseNonNegativeOption('--hold-ms', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--batch') and (LI < ParamCount) then
    begin
      GBatch := ParsePositiveOption('--batch', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--probe') and (LI < ParamCount) then
    begin
      GProbe := ParseBool01('--probe', ParamStr(LI + 1));
      Inc(LI, 2);
    end
    else if (ParamStr(LI) = '--raise-nofile') and (LI < ParamCount) then
    begin
      GRaiseNofile := ParseBool01('--raise-nofile', ParamStr(LI + 1));
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
end;

procedure RefreshNofileLimits;
var
  LLimit: TPlatformResourceLimit;
begin
  GNofileSoft := 0;
  GNofileHard := 0;
  if platform_resource_get_limit(prlkOpenFiles, LLimit) = 0 then
  begin
    GNofileSoft := LLimit.Current;
    GNofileHard := LLimit.Maximum;
  end;
end;

procedure MaybeRaiseNofile;
var
  LLimit: TPlatformResourceLimit;
  LNeed: UInt64;
  LWant: UInt64;
  LRc: Int32;
begin
  GNofileRaise := 'skipped';
  RefreshNofileLimits;
  if not GRaiseNofile then
    Exit;

  { Same-process client+server ≈ 2N fds + overhead. }
  LNeed := UInt64(GConnections) * 2 + 4096;
  LWant := LNeed;
  if (GNofileHard > 0) and (GNofileHard < PLATFORM_RESOURCE_LIMIT_INFINITY) and
     (LWant > GNofileHard) then
    LWant := GNofileHard;

  if (GNofileSoft >= LWant) and (GNofileSoft > 0) then
  begin
    GNofileRaise := 'already_ok';
    Exit;
  end;

  LLimit.Current := LWant;
  LLimit.Maximum := GNofileHard;
  if LLimit.Maximum = 0 then
    LLimit.Maximum := LWant;
  if (LLimit.Maximum < LLimit.Current) and
     (LLimit.Maximum <> PLATFORM_RESOURCE_LIMIT_INFINITY) then
    LLimit.Current := LLimit.Maximum;

  LRc := platform_resource_set_limit(prlkOpenFiles, LLimit);
  RefreshNofileLimits;
  if LRc = 0 then
    GNofileRaise := 'ok'
  else
    GNofileRaise := 'failed';
end;

var
  LHandle: TPlatformThreadHandle;
  LServerOptions: THttpServerOptions;
  LConns: array of ITcpStream;
  LI: Int32;
  LStart, LEnd: UInt64;
  LElapsedMs: UInt64;
  LRet: Pointer;
  LReadyStart: UInt64;
  LStable: Int32;
  LProbeEnabled: Int32;
  LIdleForHold: Int64;

begin
  ParseOptions;
  GOpenOk := 0;
  GOpenFail := 0;
  GProbeOk := 0;
  GProbeFail := 0;

  MaybeRaiseNofile;

  LServerOptions := THttpServerOptions.Default;
  LServerOptions.Backend := GBackend;
  { Idle must cover hold + probe; 0 = unlimited. Default 30s is usually enough
    for hold_ms=2s; raise explicitly so long holds don't false-fail. }
  LIdleForHold := Int64(GHoldMs) + 60000;
  if LIdleForHold < 30000 then
    LIdleForHold := 30000;
  LServerOptions.IdleTimeout := LIdleForHold;
  GServerIdleTimeoutMs := LServerOptions.IdleTimeout;

  GServer := THttpServer.Create(HandlerFunc(
    procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.Headers.SetHeader('content-type', 'text/plain');
      AW.Headers.SetHeader('content-length', SMALL_RESPONSE_LEN_TEXT);
      AW.WriteHeader(HTTP_STATUS_OK);
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

  WriteLn('=== HTTP Connection Ladder ===');
  WriteLn('  Connections: ', GConnections);
  WriteLn('  Hold-ms:     ', GHoldMs);
  WriteLn('  Backend:     ', BackendName);
  WriteLn('  Probe:       ', Ord(GProbe));
  WriteLn('  Port:        ', GPort);
  WriteLn('  nofile soft: ', GNofileSoft);
  WriteLn('  nofile hard: ', GNofileHard);
  WriteLn('  nofile raise:', GNofileRaise);
  WriteLn;

  SetLength(LConns, GConnections);
  LStart := platform_monotonic_ns;

  for LI := 0 to GConnections - 1 do
  begin
    try
      LConns[LI] := TcpConnect('127.0.0.1', GPort);
      LConns[LI].SetNoDelay(True);
      LConns[LI].SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
      if ExchangeRequest(LConns[LI]) then
        Inc(GOpenOk)
      else
      begin
        Inc(GOpenFail);
        try
          LConns[LI].Close;
        except
        end;
        LConns[LI] := nil;
      end;
    except
      Inc(GOpenFail);
      LConns[LI] := nil;
    end;
    if (GBatch > 0) and (((LI + 1) mod GBatch) = 0) then
      platform_thread_sleep_ns(0);
  end;

  if GHoldMs > 0 then
    platform_thread_sleep_ns(UInt64(GHoldMs) * 1000000);

  if GProbe then
  begin
    for LI := 0 to GConnections - 1 do
    begin
      if LConns[LI] = nil then
        Continue;
      try
        LConns[LI].SetReadDeadline(TDeadline.After(TDuration.FromSeconds(10)));
        if ExchangeRequest(LConns[LI]) then
          Inc(GProbeOk)
        else
          Inc(GProbeFail);
      except
        Inc(GProbeFail);
      end;
    end;
  end;

  for LI := 0 to GConnections - 1 do
  begin
    if LConns[LI] <> nil then
    begin
      try
        LConns[LI].Close;
      except
      end;
      LConns[LI] := nil;
    end;
  end;

  LEnd := platform_monotonic_ns;
  LElapsedMs := (LEnd - LStart) div 1000000;

  LStable := 0;
  if (GOpenOk = GConnections) and (GOpenFail = 0) then
  begin
    if (not GProbe) or ((GProbeOk = GOpenOk) and (GProbeFail = 0)) then
      LStable := 1;
  end;

  if GProbe then
    LProbeEnabled := 1
  else
    LProbeEnabled := 0;

  WriteLn('  open_ok=', GOpenOk, ' open_fail=', GOpenFail);
  if GProbe then
    WriteLn('  probe_ok=', GProbeOk, ' probe_fail=', GProbeFail);
  WriteLn('  elapsed_ms=', LElapsedMs);
  WriteLn('  stable=', LStable);
  WriteLn;
  WriteLn('operation=http.server.conn_ladder');
  WriteLn('backend=', BackendName);
  WriteLn('target_connections=', GConnections);
  WriteLn('open_ok=', GOpenOk);
  WriteLn('open_fail=', GOpenFail);
  WriteLn('hold_ms=', GHoldMs);
  WriteLn('probe_enabled=', LProbeEnabled);
  WriteLn('probe_ok=', GProbeOk);
  WriteLn('probe_fail=', GProbeFail);
  WriteLn('batch=', GBatch);
  WriteLn('rlimit_nofile_soft=', GNofileSoft);
  WriteLn('rlimit_nofile_hard=', GNofileHard);
  WriteLn('nofile_raise=', GNofileRaise);
  WriteLn('server_idle_timeout_ms=', GServerIdleTimeoutMs);
  WriteLn('elapsed_ms=', LElapsedMs);
  WriteLn('stable=', LStable);
  WriteLn;

  GServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  GServer.Free;

  if LStable = 1 then
    Halt(0)
  else
    Halt(1);
end.
