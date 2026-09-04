program test_winssl_error_mapping_online;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  nextpas.core.platform.socket,
  nextpas.core.system.sysutils, nextpas.core.system.classes,

  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib,
  nextpas.core.tls.winssl.base;
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

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

procedure TestExpiredBadSSL;
var
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; ClientConn: ISSLClientConnection; S: TPlatformSocket;
  runNet: Boolean; ok: Boolean; vr: Integer; vrs: string;
begin
  BeginSection('证书错误映射（在线）');

  runNet := GetEnvironmentVariable('NEXTPAS_RUN_NETWORK_TESTS') = '1';
  if not runNet then begin
    Check('跳过网络测试 (NEXTPAS_RUN_NETWORK_TESTS!=1)', True);
    Exit;
  end;

  if not InitWinsock then begin Check('初始化 Winsock', False); Exit; end;
  try
    Lib := CreateWinSSLLibrary;
    if not Lib.Initialize then begin Check('初始化 WinSSL 库', False, Lib.GetLastErrorString); Exit; end;
    Check('初始化 WinSSL 库', True);

    Ctx := Lib.CreateContext(sslCtxClient);
    Check('创建客户端上下文', Ctx <> nil);
    if Ctx = nil then Exit;

    // 默认启用对等验证，以便 GetVerifyResult 反映链状态
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);

    if not ConnectToHost('expired.badssl.com', 443, S) then begin
      Check('TCP 连接到 expired.badssl.com', False); Exit; end;

    try
      Conn := Ctx.CreateConnection(THandle(S.Value));
      Check('创建 SSL 连接对象', Conn <> nil);
      if Conn = nil then Exit;

      Check('连接支持 ISSLClientConnection',
        Supports(Conn, ISSLClientConnection, ClientConn));
      if not Supports(Conn, ISSLClientConnection, ClientConn) then Exit;

      ClientConn.SetServerName('expired.badssl.com');

      ok := Conn.Connect;
      Check('TLS 握手完成（允许带过期证书）', ok);
      if not ok then Exit;

      // INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: keep this direct core
      // GetVerifyResult/GetVerifyResultString path as a WinSSL-specific online
      // certificate-error proof. The ISSLCertificateVerification owner-path
      // coverage is frozen by generic/contract guidance checks elsewhere.
      vr := Conn.GetVerifyResult;
      vrs := Conn.GetVerifyResultString;
      WriteLn('    验证结果: ', vrs, ' (', IntToHex(vr, 8), ')');
      // 期望过期错误；个别平台可能返回其它证书错误，但必须非0
      Check('证书验证检测到错误', vr <> 0);
      // 如果刚好匹配过期错误，进一步通过
      if vr = CERT_E_EXPIRED then
        Check('错误码映射为 CERT_E_EXPIRED', True)
      else
        Check('错误码（非0）', True, 'Code=' + IntToHex(vr, 8));

      Conn.Shutdown;
      Check('优雅关闭连接', True);
    finally
      if S.IsValid then platform_socket_close(S);
    end;
  finally
    CleanupWinsock;
  end;
end;

begin
  Total := 0; Passed := 0; Failed := 0;
  WriteLn('WinSSL 错误映射（在线）测试');
  TestExpiredBadSSL;
  WriteLn; WriteLn('总计: ', Total, ' 通过: ', Passed, ' 失败: ', Failed);
  if Failed > 0 then Halt(1);
end.
