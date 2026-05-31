program test_winssl_session_resumption;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  {$IFDEF WINDOWS}
  Windows, WinSock2,
  {$ENDIF}
  SysUtils, Classes, Process,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.utils,
  nextpas.core.tls.winssl.lib;

var
  Total, Passed, Failed: Integer;
  Section: string;

const
  ResumeMarkerPrefix = '[WINSSL-SESSION-RESUME] ';
  NativeProbeChildEnv = 'FAFAFA_WINSSL_NATIVE_PROBE_CHILD';

type
  TQueryContextAttributesExCandidate = record
    ModuleName: string;
    SymbolName: AnsiString;
  end;

  TQueryContextAttributesExWFunc = function(
    phContext: PCtxtHandle;
    ulAttribute: ULONG;
    pBuffer: Pointer;
    cbBuffer: ULONG
  ): SECURITY_STATUS; stdcall;

var
  QueryContextAttributesExWResolved: Boolean = False;
  QueryContextAttributesExWProc: TQueryContextAttributesExWFunc = nil;
  QueryContextAttributesExResolvedModuleName: string = '';
  QueryContextAttributesExResolvedSymbolName: string = '';

function ResolveSessionHost: string;
begin
  Result := Trim(GetEnvironmentVariable('FAFAFA_WINSSL_SESSION_HOST'));
  if Result = '' then
    Result := 'www.cloudflare.com';
end;

procedure BeginSection(const AName: string);
begin
  Section := AName;
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

procedure Check(const AName: string; AOk: Boolean; const ADetails: string = '');
begin
  Inc(Total);
  Write('  [', Section, '] ', AName, ': ');
  if AOk then
  begin
    Inc(Passed);
    WriteLn('PASS');
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL');
    if ADetails <> '' then
      WriteLn('    ', ADetails);
  end;
end;

procedure EmitResumeMarker(const AMarker: string);
begin
  WriteLn(ResumeMarkerPrefix, AMarker);
end;

function BoolText(AValue: Boolean): string;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function BackendTypeText(ABackend: TSSLLibraryType): string;
begin
  case ABackend of
    sslAutoDetect: Result := 'auto_detect';
    sslOpenSSL: Result := 'openssl';
    sslWolfSSL: Result := 'wolfssl';
    sslMbedTLS: Result := 'mbedtls';
    sslWinSSL: Result := 'winssl';
    sslFreePascal: Result := 'freepascal';
  else
    Result := 'unknown';
  end;
end;

function EnvEnabled(const AName: string): Boolean;
var
  LValue: string;
begin
  LValue := LowerCase(Trim(GetEnvironmentVariable(AName)));
  Result := (LValue = '1') or (LValue = 'true') or
    (LValue = 'yes') or (LValue = 'on');
end;

function EnvInt(const AName: string; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(Trim(GetEnvironmentVariable(AName)), ADefault);
end;

function IsNativeProbeChildMode: Boolean;
begin
  Result := EnvEnabled(NativeProbeChildEnv);
end;

function ResolveQueryContextAttributesExW: TQueryContextAttributesExWFunc;
var
  LCandidates: array[0..5] of TQueryContextAttributesExCandidate;
  LModule: HMODULE;
  I: Integer;
begin
  if not QueryContextAttributesExWResolved then
  begin
    QueryContextAttributesExWResolved := True;
    QueryContextAttributesExResolvedModuleName := '';
    QueryContextAttributesExResolvedSymbolName := '';

    LCandidates[0].ModuleName := SECUR32_DLL;
    LCandidates[0].SymbolName := 'QueryContextAttributesExW';
    LCandidates[1].ModuleName := SECUR32_DLL;
    LCandidates[1].SymbolName := 'QueryContextAttributesExA';
    LCandidates[2].ModuleName := SECUR32_DLL;
    LCandidates[2].SymbolName := 'QueryContextAttributesEx';
    LCandidates[3].ModuleName := 'sspicli.dll';
    LCandidates[3].SymbolName := 'QueryContextAttributesExW';
    LCandidates[4].ModuleName := 'sspicli.dll';
    LCandidates[4].SymbolName := 'QueryContextAttributesExA';
    LCandidates[5].ModuleName := 'sspicli.dll';
    LCandidates[5].SymbolName := 'QueryContextAttributesEx';

    for I := Low(LCandidates) to High(LCandidates) do
    begin
      LModule := GetModuleHandle(PChar(LCandidates[I].ModuleName));
      if LModule = 0 then
        LModule := LoadLibrary(PChar(LCandidates[I].ModuleName));
      if LModule = 0 then
        Continue;

      Pointer(QueryContextAttributesExWProc) :=
        GetProcAddress(LModule, PAnsiChar(LCandidates[I].SymbolName));
      if Assigned(QueryContextAttributesExWProc) then
      begin
        QueryContextAttributesExResolvedModuleName := LCandidates[I].ModuleName;
        QueryContextAttributesExResolvedSymbolName := string(LCandidates[I].SymbolName);
        Break;
      end;
    end;
  end;

  Result := QueryContextAttributesExWProc;
end;

function TryQueryCurrentSessionInfoWithSizedBuffer(
  ACtxtHandle: PCtxtHandle;
  out ASessionInfo: SecPkgContext_SessionInfo;
  out AStatus: SECURITY_STATUS;
  out AUsedQueryEx: Boolean
): Boolean;
var
  LQueryEx: TQueryContextAttributesExWFunc;
begin
  FillChar(ASessionInfo, SizeOf(ASessionInfo), 0);
  AUsedQueryEx := False;

  LQueryEx := ResolveQueryContextAttributesExW;
  if Assigned(LQueryEx) then
  begin
    AUsedQueryEx := True;
    AStatus := LQueryEx(ACtxtHandle, SECPKG_ATTR_SESSION_INFO, @ASessionInfo,
      SizeOf(ASessionInfo));
  end
  else
    AStatus := QueryContextAttributesW(ACtxtHandle, SECPKG_ATTR_SESSION_INFO,
      @ASessionInfo);

  Result := IsSuccess(AStatus);
end;

function TryQueryConnectionInfoControl(
  ACtxtHandle: PCtxtHandle;
  out AConnectionInfo: TSecPkgContext_ConnectionInfo;
  out AStatus: SECURITY_STATUS
): Boolean;
begin
  FillChar(AConnectionInfo, SizeOf(AConnectionInfo), 0);
  AStatus := QueryContextAttributesW(ACtxtHandle, SECPKG_ATTR_CONNECTION_INFO,
    @AConnectionInfo);
  Result := IsSuccess(AStatus);
end;

function QueryResolverModuleText: string;
begin
  if QueryContextAttributesExResolvedModuleName <> '' then
    Result := QueryContextAttributesExResolvedModuleName
  else
    Result := 'none';
end;

function QueryResolverSymbolText: string;
begin
  if QueryContextAttributesExResolvedSymbolName <> '' then
    Result := QueryContextAttributesExResolvedSymbolName
  else
    Result := 'none';
end;

procedure SetProcessEnvironment(const AName, AValue: string);
begin
  if AValue = '' then
    Windows.SetEnvironmentVariable(PChar(AName), nil)
  else
    Windows.SetEnvironmentVariable(PChar(AName), PChar(AValue));
end;

function ExtractResumeMarker(const ALine: string; out AMarker: string): Boolean;
begin
  Result := Pos(ResumeMarkerPrefix, ALine) = 1;
  if Result then
    AMarker := Trim(Copy(ALine, Length(ResumeMarkerPrefix) + 1, MaxInt))
  else
    AMarker := '';
end;

procedure UpdateNativeProbeObservationFromMarker(const AMarker: string;
  var AObservedNativeReuse: Boolean; var AProbeSucceeded: Boolean);
begin
  if Pos('native_probe ', AMarker) <> 1 then
    Exit;

  if Pos('available=true', AMarker) > 0 then
  begin
    AProbeSucceeded := True;
    if Pos('reused=true', AMarker) > 0 then
      AObservedNativeReuse := True;
  end;
end;

procedure AppendAvailableProcessOutput(AProcess: TProcess; var AOutput: string);
var
  LBuffer: array[0..2047] of Byte;
  LBytesRead: LongInt;
  LChunk: RawByteString;
begin
  while AProcess.Output.NumBytesAvailable > 0 do
  begin
    LBytesRead := AProcess.Output.Read(LBuffer, SizeOf(LBuffer));
    if LBytesRead <= 0 then
      Break;
    SetString(LChunk, PAnsiChar(@LBuffer[0]), LBytesRead);
    AOutput := AOutput + string(LChunk);
  end;
end;

function RunIsolatedNativeProbeWorker(const AHost: string; AAttemptCount: Integer;
  out AExitCode: Integer; out AOutput: string; out AObservedNativeReuse: Boolean;
  out AProbeSucceeded: Boolean; out ALastMarker: string): Boolean;
var
  LProcess: TProcess;
  LOutputLines: TStringList;
  LOriginalHost: string;
  LOriginalAttempts: string;
  LOriginalRunNet: string;
  LOriginalProbeEnabled: string;
  LOriginalChildMode: string;
  LMarker: string;
  I: Integer;
begin
  Result := False;
  AExitCode := -1;
  AOutput := '';
  AObservedNativeReuse := False;
  AProbeSucceeded := False;
  ALastMarker := 'none';

  LOriginalHost := GetEnvironmentVariable('FAFAFA_WINSSL_SESSION_HOST');
  LOriginalAttempts := GetEnvironmentVariable('FAFAFA_WINSSL_SESSION_ATTEMPTS');
  LOriginalRunNet := GetEnvironmentVariable('FAFAFA_RUN_NETWORK_TESTS');
  LOriginalProbeEnabled := GetEnvironmentVariable('FAFAFA_WINSSL_ENABLE_NATIVE_PROBE');
  LOriginalChildMode := GetEnvironmentVariable(NativeProbeChildEnv);

  SetProcessEnvironment('FAFAFA_WINSSL_SESSION_HOST', AHost);
  SetProcessEnvironment('FAFAFA_WINSSL_SESSION_ATTEMPTS', IntToStr(AAttemptCount));
  SetProcessEnvironment('FAFAFA_RUN_NETWORK_TESTS', '1');
  SetProcessEnvironment('FAFAFA_WINSSL_ENABLE_NATIVE_PROBE', '1');
  SetProcessEnvironment(NativeProbeChildEnv, '1');

  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := ParamStr(0);
    LProcess.Options := [poUsePipes, poStderrToOutPut];
    LProcess.Execute;
    while LProcess.Running do
    begin
      AppendAvailableProcessOutput(LProcess, AOutput);
      Sleep(10);
    end;
    AppendAvailableProcessOutput(LProcess, AOutput);
    LProcess.WaitOnExit;
    AExitCode := LProcess.ExitCode;
  except
    on E: Exception do
    begin
      AExitCode := -1;
      AOutput := Format('worker_exception=%s:%s', [E.ClassName, E.Message]);
      ALastMarker := 'worker_launch_exception';
    end;
  end;
  LProcess.Free;

  SetProcessEnvironment('FAFAFA_WINSSL_SESSION_HOST', LOriginalHost);
  SetProcessEnvironment('FAFAFA_WINSSL_SESSION_ATTEMPTS', LOriginalAttempts);
  SetProcessEnvironment('FAFAFA_RUN_NETWORK_TESTS', LOriginalRunNet);
  SetProcessEnvironment('FAFAFA_WINSSL_ENABLE_NATIVE_PROBE', LOriginalProbeEnabled);
  SetProcessEnvironment(NativeProbeChildEnv, LOriginalChildMode);

  LOutputLines := TStringList.Create;
  try
    LOutputLines.Text := AOutput;
    for I := 0 to LOutputLines.Count - 1 do
    begin
      if ExtractResumeMarker(TrimRight(LOutputLines[I]), LMarker) then
      begin
        ALastMarker := LMarker;
        if Pos('native_probe ', LMarker) = 1 then
        begin
          EmitResumeMarker(LMarker);
          UpdateNativeProbeObservationFromMarker(LMarker,
            AObservedNativeReuse, AProbeSucceeded);
        end;
      end;
    end;
  finally
    LOutputLines.Free;
  end;

  EmitResumeMarker(Format(
    'native_probe_worker exit_code=%d probe_succeeded=%s observed_reuse=%s last_marker=%s',
    [AExitCode, BoolText(AProbeSucceeded), BoolText(AObservedNativeReuse),
     ALastMarker]));
  Result := AExitCode = 0;
end;

function InitWinsock: Boolean;
var
  LWSAData: TWSAData;
begin
  Result := WSAStartup(MAKEWORD(2, 2), LWSAData) = 0;
end;

procedure CleanupWinsock;
begin
  WSACleanup;
end;

function ConnectToHost(const AHost: string; APort: Word; out ASocket: TSocket): Boolean;
var
  LAddr: TSockAddrIn;
  LHostEnt: PHostEnt;
  LInAddr: TInAddr;
  LTimeout: Integer;
begin
  Result := False;
  ASocket := INVALID_SOCKET;

  ASocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if ASocket = INVALID_SOCKET then
    Exit;

  LTimeout := 10000;
  setsockopt(ASocket, SOL_SOCKET, SO_RCVTIMEO, @LTimeout, SizeOf(LTimeout));
  setsockopt(ASocket, SOL_SOCKET, SO_SNDTIMEO, @LTimeout, SizeOf(LTimeout));

  LHostEnt := gethostbyname(PAnsiChar(AnsiString(AHost)));
  if LHostEnt = nil then
  begin
    closesocket(ASocket);
    ASocket := INVALID_SOCKET;
    Exit;
  end;

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  Move(LHostEnt^.h_addr_list^^, LInAddr, SizeOf(LInAddr));
  LAddr.sin_addr := LInAddr;

  Result := connect(ASocket, @LAddr, SizeOf(LAddr)) = 0;
  if not Result then
  begin
    closesocket(ASocket);
    ASocket := INVALID_SOCKET;
  end;
end;

function TryQueryNativeSessionReuse(const AConn: ISSLConnection;
  const ALabel: string; out AReused: Boolean; out ADetails: string): Boolean;
var
  LNativeAccess: ISSLNativeHandleAccess;
  LCtxtHandle: PCtxtHandle;
  LConnectionInfo: TSecPkgContext_ConnectionInfo;
  LControlStatus: SECURITY_STATUS;
  LSessionInfo: SecPkgContext_SessionInfo;
  LStatus: SECURITY_STATUS;
  LQueryAPI: string;
  LUsedQueryEx: Boolean;
begin
  Result := False;
  AReused := False;
  ADetails := '';

  EmitResumeMarker(Format('native_probe label=%s stage=before_supports',
    [ALabel]));
  if not Supports(AConn, ISSLNativeHandleAccess, LNativeAccess) then
  begin
    EmitResumeMarker(Format('native_probe label=%s stage=supports_unavailable',
      [ALabel]));
    ADetails := 'native_handle_access_unavailable';
    Exit;
  end;

  EmitResumeMarker(Format('native_probe label=%s stage=after_supports',
    [ALabel]));
  EmitResumeMarker(Format('native_probe label=%s stage=before_get_native_handle',
    [ALabel]));
  LCtxtHandle := PCtxtHandle(LNativeAccess.GetNativeHandle);
  EmitResumeMarker(Format(
    'native_probe label=%s stage=after_get_native_handle handle_nil=%s',
    [ALabel, BoolText(LCtxtHandle = nil)]));
  if LCtxtHandle = nil then
  begin
    ADetails := 'native_handle_nil';
    Exit;
  end;

  FillChar(LSessionInfo, SizeOf(LSessionInfo), 0);
  try
    EmitResumeMarker(Format(
      'native_probe label=%s stage=handle_metadata backend=%s handle_valid=%s lower=%s upper=%s',
      [ALabel, BackendTypeText(LNativeAccess.GetBackendType),
       BoolText(LNativeAccess.IsNativeHandleValid),
       IntToHex(QWord(LCtxtHandle^.dwLower), SizeOf(LCtxtHandle^.dwLower) * 2),
       IntToHex(QWord(LCtxtHandle^.dwUpper), SizeOf(LCtxtHandle^.dwUpper) * 2)]));
    EmitResumeMarker(Format(
      'native_probe label=%s stage=before_query_context_attributes',
      [ALabel]));
    EmitResumeMarker(Format(
      'native_probe label=%s stage=before_control_query attribute=connection_info',
      [ALabel]));
    if not TryQueryConnectionInfoControl(LCtxtHandle, LConnectionInfo,
      LControlStatus) then
    begin
      EmitResumeMarker(Format(
        'native_probe label=%s stage=control_query_failed status=0x%x',
        [ALabel, LControlStatus]));
      ADetails := Format('control_status=0x%x', [LControlStatus]);
      Exit;
    end;
    EmitResumeMarker(Format(
      'native_probe label=%s stage=after_control_query status=0x%x protocol=0x%x cipher=0x%x',
      [ALabel, LControlStatus, LConnectionInfo.dwProtocol,
       LConnectionInfo.aiCipher]));
    LUsedQueryEx := Assigned(ResolveQueryContextAttributesExW);
    if LUsedQueryEx then
      LQueryAPI := 'query_context_attributes_exw'
    else
      LQueryAPI := 'query_context_attributesw';
    EmitResumeMarker(Format(
      'native_probe label=%s stage=query_resolver module=%s symbol=%s resolved=%s',
      [ALabel, QueryResolverModuleText, QueryResolverSymbolText,
       BoolText(LUsedQueryEx)]));
    EmitResumeMarker(Format(
      'native_probe label=%s stage=query_api api=%s',
      [ALabel, LQueryAPI]));
    if not TryQueryCurrentSessionInfoWithSizedBuffer(LCtxtHandle, LSessionInfo,
      LStatus, LUsedQueryEx) then
    begin
      EmitResumeMarker(Format(
        'native_probe label=%s stage=query_failed status=0x%x',
        [ALabel, LStatus]));
      ADetails := Format('status=0x%x', [LStatus]);
      Exit;
    end;

    AReused := (LSessionInfo.dwFlags and SSL_SESSION_RECONNECT) <> 0;
    EmitResumeMarker(Format(
      'native_probe label=%s stage=after_query_context_attributes status=0x%x reused=%s flags=0x%x',
      [ALabel, LStatus, BoolText(AReused), LSessionInfo.dwFlags]));
    ADetails := Format('status=0x%x flags=0x%x',
      [LStatus, LSessionInfo.dwFlags]);
    Result := True;
  except
    on E: Exception do
    begin
      EmitResumeMarker(Format(
        'native_probe label=%s stage=exception class=%s message=%s',
        [ALabel, E.ClassName, E.Message]));
      ADetails := Format('exception=%s:%s', [E.ClassName, E.Message]);
      Result := False;
    end;
  end;
end;

procedure ValidateReuseTruth(const ALabel: string; const AConn: ISSLConnection;
  out AReused: Boolean);
var
  LDiag: ISSLDiagnostics;
  LResumption: ISSLSessionResumption;
  LInfo: TSSLConnectionInfo;
  LPerf: TSSLPerformanceMetrics;
begin
  AReused := AConn.IsSessionReused;
  LInfo := AConn.GetConnectionInfo;

  Check(ALabel + ' exposes ISSLDiagnostics',
    Supports(AConn, ISSLDiagnostics, LDiag));
  if not Supports(AConn, ISSLDiagnostics, LDiag) then
  begin
    EmitResumeMarker(Format(
      'signal label=%s diagnostics_surface=missing',
      [ALabel]));
    Exit;
  end;
  LPerf := LDiag.GetPerformanceMetrics;

  Check(ALabel + ' exposes ISSLSessionResumption',
    Supports(AConn, ISSLSessionResumption, LResumption));
  if Supports(AConn, ISSLSessionResumption, LResumption) then
    Check(ALabel + ' optional/core reuse truth aligns',
      LResumption.IsSessionReused = AReused,
      Format('optional=%s core=%s',
        [BoolText(LResumption.IsSessionReused), BoolText(AReused)]));

  Check(ALabel + ' connection info mirrors reuse truth',
    LInfo.IsResumed = AReused,
    Format('info=%s core=%s',
      [BoolText(LInfo.IsResumed), BoolText(AReused)]));

  Check(ALabel + ' performance metrics mirror reuse truth',
    LPerf.SessionReused = AReused,
    Format('perf=%s core=%s',
      [BoolText(LPerf.SessionReused), BoolText(AReused)]));

  EmitResumeMarker(Format(
    'signal label=%s reused=%s info_resumed=%s perf_reused=%s',
    [ALabel, BoolText(AReused), BoolText(LInfo.IsResumed),
     BoolText(LPerf.SessionReused)]));
end;

procedure TestSameContextResumptionTruth(const AHost: string);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption1, LResumptionN: ISSLSessionResumption;
  LSession: ISSLSession;
  LSocket: TSocket;
  LRunNet: Boolean;
  LRequireReuse: Boolean;
  LObservedReuse: Boolean;
  LObservedNativeReuse: Boolean;
  LNativeProbeEnabled: Boolean;
  LNativeProbeChildMode: Boolean;
  LNativeProbeSucceeded: Boolean;
  LRequireNativeReuse: Boolean;
  LSessionConfigured: Boolean;
  LAttemptCount: Integer;
  LAttempt: Integer;
  LOk: Boolean;
  LReused: Boolean;
  LNativeReused: Boolean;
  LNativeDetails: string;
  LWorkerExitCode: Integer;
  LWorkerOutput: string;
  LWorkerLastMarker: string;
  LInitError: string;
begin
  BeginSection('WinSSL session resumption truth');

  LRunNet := EnvEnabled('FAFAFA_RUN_NETWORK_TESTS');
  if not LRunNet then
  begin
    Check('skip network test (FAFAFA_RUN_NETWORK_TESTS!=1)', True);
    EmitResumeMarker('summary skipped=true reason=network_gate');
    Exit;
  end;

  LAttemptCount := EnvInt('FAFAFA_WINSSL_SESSION_ATTEMPTS', 4);
  if LAttemptCount < 1 then
    LAttemptCount := 1;
  LRequireReuse := EnvEnabled('FAFAFA_WINSSL_REQUIRE_REUSE');
  LRequireNativeReuse := EnvEnabled('FAFAFA_WINSSL_REQUIRE_NATIVE_REUSE');
  LNativeProbeEnabled := EnvEnabled('FAFAFA_WINSSL_ENABLE_NATIVE_PROBE') or
    LRequireNativeReuse;
  LNativeProbeChildMode := IsNativeProbeChildMode;
  LObservedReuse := False;
  LObservedNativeReuse := False;
  LNativeProbeSucceeded := False;
  LSessionConfigured := False;
  LSession := nil;
  EmitResumeMarker(
    'evidence_model public_reuse_truth=conservative_shared_path native_probe_truth=isolated_worker_opt_in');

  if not InitWinsock then
  begin
    Check('initialize Winsock', False);
    EmitResumeMarker('summary skipped=false phase=init_winsock status=fail');
    Exit;
  end;

  try
    LLib := CreateWinSSLLibrary;
    LOk := (LLib <> nil) and LLib.Initialize;
    if LOk then
      LInitError := ''
    else if LLib <> nil then
      LInitError := LLib.GetLastErrorString
    else
      LInitError := 'library instance is nil';
    Check('initialize WinSSL library', LOk, LInitError);
    if not LOk then
    begin
      EmitResumeMarker('summary skipped=false phase=initialize_library status=fail');
      Exit;
    end;

    LCtx := LLib.CreateContext(sslCtxClient);
    Check('create client context', LCtx <> nil);
    if LCtx = nil then
    begin
      EmitResumeMarker('summary skipped=false phase=create_context status=fail');
      Exit;
    end;

    // Prefer TLS 1.2 here because classic session-ID/ticket reconnects are
    // more stable across public servers and CI runners.
    LCtx.SetProtocolVersions([sslProtocolTLS12]);

    LSocket := INVALID_SOCKET;
    if not ConnectToHost(AHost, 443, LSocket) then
    begin
      Check('TCP connect for initial handshake', False, AHost);
      EmitResumeMarker('summary skipped=false phase=initial_tcp_connect status=fail');
      Exit;
    end;

    try
      LConn := LCtx.CreateConnection(LSocket);
      Check('create SSL connection for initial handshake', LConn <> nil);
      if LConn = nil then
      begin
        EmitResumeMarker('summary skipped=false phase=initial_create_connection status=fail');
        Exit;
      end;

      Check('initial connection exposes ISSLSessionResumption',
        Supports(LConn, ISSLSessionResumption, LResumption1));
      if not Supports(LConn, ISSLSessionResumption, LResumption1) then
      begin
        EmitResumeMarker('summary skipped=false phase=initial_owner_surface status=fail');
        Exit;
      end;

      (LConn as ISSLClientConnection).SetServerName(AHost);
      LOk := LConn.Connect;
      Check('initial handshake completes', LOk, AHost);
      if not LOk then
      begin
        EmitResumeMarker('summary skipped=false phase=initial_handshake status=fail');
        Exit;
      end;

      ValidateReuseTruth('initial_handshake', LConn, LReused);
      Check('initial handshake must not report reuse', not LReused,
        'fresh handshake unexpectedly reported session reuse');

      if LNativeProbeEnabled and LNativeProbeChildMode then
      begin
        EmitResumeMarker(
          'native_probe label=initial_handshake pending=true mode=isolated_worker');
        if TryQueryNativeSessionReuse(LConn, 'initial_handshake', LNativeReused,
          LNativeDetails) then
        begin
          LNativeProbeSucceeded := True;
          Check('initial native probe must not report reconnect', not LNativeReused,
            LNativeDetails);
          EmitResumeMarker(Format(
            'native_probe label=initial_handshake available=true reused=%s %s',
            [BoolText(LNativeReused), LNativeDetails]));
        end
        else
          EmitResumeMarker(Format(
            'native_probe label=initial_handshake available=false reason=%s',
            [LNativeDetails]));
      end
      else if not LNativeProbeEnabled then
        EmitResumeMarker(
          'native_probe label=initial_handshake available=false reason=disabled_by_default');

      LSession := LResumption1.GetSession;
      LSessionConfigured := LSession <> nil;
      Check('initial handshake captures session metadata', LSessionConfigured);
      if LSessionConfigured then
        Check('captured session metadata is resumable',
          LSession.IsResumable,
          'captured session should remain resumable for the next attempt');

      LConn.Shutdown;
    finally
      if LSocket <> INVALID_SOCKET then
        closesocket(LSocket);
    end;

    for LAttempt := 1 to LAttemptCount do
    begin
      LSocket := INVALID_SOCKET;
      if not ConnectToHost(AHost, 443, LSocket) then
      begin
        Check(Format('TCP connect for resumed attempt #%d', [LAttempt]), False, AHost);
        Continue;
      end;

      try
        LConn := LCtx.CreateConnection(LSocket);
        Check(Format('create SSL connection for resumed attempt #%d', [LAttempt]),
          LConn <> nil);
        if LConn = nil then
          Continue;

        Check(Format('resumed attempt #%d exposes ISSLSessionResumption', [LAttempt]),
          Supports(LConn, ISSLSessionResumption, LResumptionN));
        if not Supports(LConn, ISSLSessionResumption, LResumptionN) then
          Continue;

        if LSessionConfigured then
          LResumptionN.SetSession(LSession);

        Check(Format('pre-handshake attempt #%d does not preclaim reuse', [LAttempt]),
          not LResumptionN.IsSessionReused,
          'reuse state must remain false until the handshake actually completes');

        (LConn as ISSLClientConnection).SetServerName(AHost);
        LOk := LConn.Connect;
        Check(Format('same-context resumed attempt #%d completes', [LAttempt]), LOk, AHost);
        if not LOk then
          Continue;

        ValidateReuseTruth(Format('same_context_attempt_%d', [LAttempt]), LConn, LReused);
        EmitResumeMarker(Format('attempt index=%d reused=%s session_configured=%s',
          [LAttempt, BoolText(LReused), BoolText(LSessionConfigured)]));
        if LReused then
          LObservedReuse := True;

        if LNativeProbeEnabled and LNativeProbeChildMode then
        begin
          EmitResumeMarker(Format(
            'native_probe label=same_context_attempt_%d pending=true mode=isolated_worker',
            [LAttempt]));
          if TryQueryNativeSessionReuse(LConn,
            Format('same_context_attempt_%d', [LAttempt]), LNativeReused,
            LNativeDetails) then
          begin
            LNativeProbeSucceeded := True;
            EmitResumeMarker(Format(
              'native_probe label=same_context_attempt_%d available=true reused=%s %s',
              [LAttempt, BoolText(LNativeReused), LNativeDetails]));
            if LNativeReused then
              LObservedNativeReuse := True;
          end
          else
            EmitResumeMarker(Format(
              'native_probe label=same_context_attempt_%d available=false reason=%s',
              [LAttempt, LNativeDetails]));
        end
        else if not LNativeProbeEnabled then
          EmitResumeMarker(Format(
            'native_probe label=same_context_attempt_%d available=false reason=disabled_by_default',
            [LAttempt]));

        LConn.Shutdown;
      finally
        if LSocket <> INVALID_SOCKET then
          closesocket(LSocket);
      end;

      if LObservedReuse then
        Break;
    end;

    if LNativeProbeEnabled and not LNativeProbeChildMode then
    begin
      RunIsolatedNativeProbeWorker(AHost, LAttemptCount, LWorkerExitCode,
        LWorkerOutput, LObservedNativeReuse, LNativeProbeSucceeded,
        LWorkerLastMarker);
      if LRequireNativeReuse then
        Check('isolated native probe worker exits cleanly', LWorkerExitCode = 0,
          Format('exit_code=%d last_marker=%s',
            [LWorkerExitCode, LWorkerLastMarker]))
      else
        Check('isolated native probe worker evidence recorded', True,
          Format('exit_code=%d last_marker=%s probe_succeeded=%s',
            [LWorkerExitCode, LWorkerLastMarker,
             BoolText(LNativeProbeSucceeded)]));
    end;

    EmitResumeMarker(Format(
      'summary host=%s attempts=%d observed_reuse=%s native_probe_enabled=%s native_observed_reuse=%s native_probe_succeeded=%s require_reuse=%s require_native_reuse=%s session_configured=%s',
      [AHost, LAttemptCount, BoolText(LObservedReuse), BoolText(LNativeProbeEnabled),
       BoolText(LObservedNativeReuse), BoolText(LNativeProbeSucceeded),
       BoolText(LRequireReuse),
       BoolText(LRequireNativeReuse), BoolText(LSessionConfigured)]));

    if LRequireReuse then
      Check('same-context reconnect eventually observes session reuse',
        LObservedReuse,
        Format('host=%s attempts=%d', [AHost, LAttemptCount]))
    else
      Check('same-context reconnect evidence recorded', True,
        Format('observed_reuse=%s attempts=%d',
          [BoolText(LObservedReuse), LAttemptCount]));

    if LRequireNativeReuse then
      Check('same-context reconnect eventually observes native reuse',
        LNativeProbeSucceeded and LObservedNativeReuse,
        Format('native_probe_succeeded=%s host=%s attempts=%d',
          [BoolText(LNativeProbeSucceeded), AHost, LAttemptCount]));
  finally
    CleanupWinsock;
  end;
end;

begin
  Total := 0;
  Passed := 0;
  Failed := 0;

  WriteLn('WinSSL session resumption runtime truth test');
  TestSameContextResumptionTruth(ResolveSessionHost);

  WriteLn;
  WriteLn('总计: ', Total, ' 通过: ', Passed, ' 失败: ', Failed);
  if Failed > 0 then
    Halt(1);
end.
