program test_winssl_mtls_e2e_local;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  nextpas.core.platform.socket,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.base.utils,
  nextpas.core.os.env,

  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  Total, Passed, Failed: Integer;
  Section: string;

procedure BeginSection(const aName: string);
begin
  Section := aName;
  WriteLn; WriteLn('=== ', aName, ' ===');
end;

procedure Check(const aName: string; ok: Boolean; const details: string = '');
begin
  Inc(Total);
  Write('  [', Section, '] ', aName, ': ');
  if ok then begin Inc(Passed); WriteLn('PASS'); end
  else begin Inc(Failed); WriteLn('FAIL'); if details <> '' then WriteLn('    ', details); end;
end;

function InitWinsock: Boolean; begin Result := True; end;
procedure CleanupWinsock; begin end;

function ConnectToHost(const aHost: string; aPort: Word;
  out aSocket: TPlatformSocket): Boolean;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := False;
  aSocket := PLATFORM_INVALID_SOCKET;
  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(aHost)), LIP) <> 0 then
    Exit;
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    aSocket) <> 0 then
    Exit;
  platform_socket_set_timeout(aSocket, PLATFORM_SO_RCVTIMEO, 10000);
  platform_socket_set_timeout(aSocket, PLATFORM_SO_SNDTIMEO, 10000);
  platform_sockaddr_ipv4(aPort, LIP, LAddr);
  if platform_socket_connect(aSocket, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(aSocket);
    Exit;
  end;
  Result := True;
end;

function Env(const name: string; const defVal: string): string; begin Result := GetEnvironmentVariable(name); if Result = '' then Result := defVal; end;
function EnvDefault(const name: string): string; begin Result := GetEnvironmentVariable(name); end;

procedure Test_mTLS_E2E_Local;
var
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; ClientConn: ISSLClientConnection;
  Host, Pfx, PfxPass, CaFile: string; Port: Integer; S: TPlatformSocket; ok: Boolean;
begin
  BeginSection('WinSSL mTLS E2E (local s_server)');

  {$IFNDEF WINDOWS}
  Check('平台', False, 'Windows only'); Exit;
  {$ENDIF}

  Host := Env('NEXTPAS_WINSSL_MTLS_SERVER', '127.0.0.1');
  Port := StrToIntDef(Env('NEXTPAS_WINSSL_MTLS_PORT', '44330'), 44330);
  Pfx := Env('NEXTPAS_WINSSL_PFX', '');
  PfxPass := Env('NEXTPAS_WINSSL_PFX_PASSWORD', '');
  CaFile := Env('NEXTPAS_TLS_CA', '');

  if (Pfx = '') then begin Check('环境变量', False, '缺少 NEXTPAS_WINSSL_PFX'); Exit; end;

  if not InitWinsock then begin Check('初始化 Winsock', False); Exit; end;
  try
    Lib := CreateWinSSLLibrary;
    if (Lib = nil) or (not Lib.Initialize) then begin Check('初始化 WinSSL 库', False); Exit; end;
    Check('初始化 WinSSL 库', True);

    Ctx := Lib.CreateContext(sslCtxClient);
    Check('创建客户端上下文', Ctx <> nil);
    if Ctx = nil then Exit;

    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    try
      Ctx.LoadPrivateKey(Pfx, PfxPass);
      Check('加载客户端 PFX 证书与私钥', True);
    except on E: Exception do
      begin Check('加载客户端 PFX', False, E.Message); Exit; end;
    end;

    if CaFile <> '' then
    begin
      try
        Ctx.LoadCAFile(CaFile);
        Check('加载 CA（用于验证服务端证书）', True);
      except on E: Exception do Check('加载 CA', False, E.Message);
      end;
    end;

    if not ConnectToHost(Host, Port, S) then begin Check('TCP 连接到 ' + Host + ':' + IntToStr(Port), False); Exit; end;
    try
      Conn := Ctx.CreateConnection(THandle(S.Value));
      Check('创建 SSL 连接对象', Conn <> nil);
      if Conn = nil then Exit;

      Check('连接支持 ISSLClientConnection',
        Supports(Conn, ISSLClientConnection, ClientConn));
      if not Supports(Conn, ISSLClientConnection, ClientConn) then Exit;

      ClientConn.SetServerName(Host);

      ok := (Conn <> nil) and (Conn.DoHandshake = sslHsCompleted);
      Check('mTLS 握手', ok);
      if ok then Conn.Shutdown;
    finally
      if S.IsValid then platform_socket_close(S);
    end;

  finally
    CleanupWinsock;
  end;
end;

begin
  Total := 0; Passed := 0; Failed := 0;
  Test_mTLS_E2E_Local;
  WriteLn; WriteLn('总计: ', Total, ' 通过: ', Passed, ' 失败: ', Failed);
  if Failed > 0 then Halt(1);
end.




















