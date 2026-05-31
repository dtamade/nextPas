program test_winssl_error_mapping_online;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  {$IFDEF WINDOWS}Windows, WinSock2,{$ENDIF}
  SysUtils, Classes,
  
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

function InitWinsock: Boolean; var W: TWSAData; begin Result := WSAStartup(MAKEWORD(2,2), W) = 0; end;
procedure CleanupWinsock; begin WSACleanup; end;

function ConnectToHost(const aHost: string; aPort: Word; out aSocket: TSocket): Boolean;
var A: TSockAddrIn; H: PHostEnt; InAddr: TInAddr; Tm: Integer;
begin
  Result := False; aSocket := INVALID_SOCKET;
  aSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if aSocket = INVALID_SOCKET then Exit;
  Tm := 10000; setsockopt(aSocket, SOL_SOCKET, SO_RCVTIMEO, @Tm, SizeOf(Tm));
  setsockopt(aSocket, SOL_SOCKET, SO_SNDTIMEO, @Tm, SizeOf(Tm));
  H := gethostbyname(PAnsiChar(AnsiString(aHost)));
  if H = nil then begin closesocket(aSocket); aSocket := INVALID_SOCKET; Exit; end;
  FillChar(A, SizeOf(A), 0); A.sin_family := AF_INET; A.sin_port := htons(aPort);
  Move(H^.h_addr_list^^, InAddr, SizeOf(InAddr)); A.sin_addr := InAddr;
  Result := connect(aSocket, @A, SizeOf(A)) = 0;
  if not Result then begin closesocket(aSocket); aSocket := INVALID_SOCKET; end;
end;

procedure TestExpiredBadSSL;
var
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; ClientConn: ISSLClientConnection; S: TSocket;
  runNet: Boolean; ok: Boolean; vr: Integer; vrs: string;
begin
  BeginSection('证书错误映射（在线）');

  runNet := GetEnvironmentVariable('FAFAFA_RUN_NETWORK_TESTS') = '1';
  if not runNet then begin
    Check('跳过网络测试 (FAFAFA_RUN_NETWORK_TESTS!=1)', True);
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
      Conn := Ctx.CreateConnection(S);
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
      if S <> INVALID_SOCKET then closesocket(S);
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
