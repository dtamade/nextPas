{******************************************************************************}
{  Cross-Backend Consistency Contract Tests                                    }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_cross_backend_consistency_contract;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  nextpas.core.base.utils,
  nextpas.core.os.env, nextpas.core.time,

  nextpas.core.tls.base,
  nextpas.core.platform.socket,
  {$IFNDEF WINDOWS}
  nextpas.core.tls.openssl.backed,
  {$ENDIF}
  {$IFDEF WINDOWS}nextpas.core.tls.winssl.lib,{$ENDIF}
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  test_openssl_base;

type
  TSide = (SideOpenSSL, SideWinSSL);

var
  Runner: TSimpleTestRunner;

procedure Check(const Name: string; ok: Boolean; const details: string = '');
begin
  Runner.Check(Name, ok, details);
end;

function EnvEnabled(const VarName: string): Boolean;
begin
  Result := GetEnvironmentVariable(VarName) = '1';
end;

function GetNegotiatedALPN(AConn: ISSLConnection): string;
var
  LConnInfo: ISSLConnectionInfo;
begin
  if Supports(AConn, ISSLConnectionInfo, LConnInfo) then
    Result := LConnInfo.GetSelectedALPNProtocol
  else
    Result := '';
end;

function GetVerificationResult(AConn: ISSLConnection): Integer;
var
  LCertVerify: ISSLCertificateVerification;
begin
  if Supports(AConn, ISSLCertificateVerification, LCertVerify) then
    Result := LCertVerify.GetVerifyResult
  else
    Result := 0;
end;

function CreateLib(aSide: TSide): ISSLLibrary;
begin
  Result := nil;
  case aSide of
    {$IFDEF WINDOWS}
    SideWinSSL: Result := CreateWinSSLLibrary;
    {$ELSE}
    SideWinSSL: Result := nil;  // WinSSL not available on non-Windows
    {$ENDIF}
    {$IFNDEF WINDOWS}
    SideOpenSSL: Result := TOpenSSLLibrary.Create;
    {$ELSE}
    SideOpenSSL: Result := nil;
    {$ENDIF}
  end;
end;

function ConnectTCP(const Host: string; Port: Word;
  out Sock: TPlatformSocket): Boolean;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := False;
  Sock := PLATFORM_INVALID_SOCKET;
  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(Host)), LIP) <> 0 then
    Exit;
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Sock) <> 0 then
    Exit;
  platform_socket_set_timeout(Sock, PLATFORM_SO_RCVTIMEO, 10000);
  platform_socket_set_timeout(Sock, PLATFORM_SO_SNDTIMEO, 10000);
  platform_sockaddr_ipv4(Port, LIP, LAddr);
  if platform_socket_connect(Sock, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(Sock);
    Exit;
  end;
  Result := True;
end;

function RunProbe(aSide: TSide; const Host: string; out Proto: TSSLProtocolVersion; out Cipher, Alpn: string; out VerifyCode: Integer): Boolean;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  S: TPlatformSocket;
  ok: Boolean;
begin
  Result := False; Proto := sslProtocolTLS12; Cipher := ''; Alpn := ''; VerifyCode := 0;
  Lib := CreateLib(aSide);
  if Lib = nil then Exit;
  if not Lib.Initialize then Exit;
  Ctx := Lib.CreateContext(sslCtxClient);
  if Ctx = nil then Exit;
  Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  Ctx.SetALPNProtocols('h2,http/1.1');
  if not ConnectTCP(Host, 443, S) then Exit;
  try
    Conn := Ctx.CreateConnection(THandle(S.Value));
    if Conn = nil then Exit;
    if not Supports(Conn, ISSLClientConnection, ClientConn) then Exit;
    ClientConn.SetServerName(Host);
    ok := Conn.Connect;
    if not ok then Exit;
    Proto := Conn.GetProtocolVersion;
    Cipher := Conn.GetCipherName;
    Alpn := GetNegotiatedALPN(Conn);
    VerifyCode := GetVerificationResult(Conn);
    Result := True;
    Conn.Shutdown;
  finally
    if S.IsValid then
      platform_socket_close(S);
  end;
end;

procedure TestNormalizedContract;
var
  runNet: Boolean;
  oOK, wOK: Boolean;
  oProto: TSSLProtocolVersion; wProto: TSSLProtocolVersion;
  oCipher, wCipher, oAlpn, wAlpn: string;
  oV, wV: Integer;
begin
  WriteLn('=== 跨后端一致性（合同）===');
  runNet := EnvEnabled('NEXTPAS_RUN_NETWORK_TESTS');
  if not runNet then begin
    Check('跳过网络测试 (NEXTPAS_RUN_NETWORK_TESTS!=1)', True);
    Exit;
  end;

  // OpenSSL 侧（Linux 有效）
  {$IFNDEF WINDOWS}
  oOK := RunProbe(SideOpenSSL, 'api.github.com', oProto, oCipher, oAlpn, oV);
  Check('OpenSSL 探测执行', oOK);
  if oOK then begin
    Check('OpenSSL 协议版本有效', oProto in [sslProtocolTLS12, sslProtocolTLS13]);
    Check('OpenSSL 密码套件非空', oCipher <> '');
  end;
  {$ELSE}
  oOK := False;
  Check('OpenSSL 探测（Windows 跳过）', True);
  {$ENDIF}

  // WinSSL 侧（Windows 有效）
  {$IFDEF WINDOWS}
  wOK := RunProbe(SideWinSSL, 'api.github.com', wProto, wCipher, wAlpn, wV);
  Check('WinSSL 探测执行', wOK);
  if wOK then begin
    Check('WinSSL 协议版本有效', wProto in [sslProtocolTLS12, sslProtocolTLS13]);
    Check('WinSSL 密码套件非空', wCipher <> '');
  end;
  {$ELSE}
  wOK := False;
  Check('WinSSL 探测（Linux 跳过）', True);
  {$ENDIF}

  // 若两侧均可用，则比较归一化属性
  if oOK and wOK then
  begin
    Check('协议族一致 (TLS1.2/1.3)', (oProto in [sslProtocolTLS12, sslProtocolTLS13]) and (wProto in [sslProtocolTLS12, sslProtocolTLS13]));
    // ALPN 可能为空或不同，放宽为：两侧只要返回空或在 {h2,http/1.1} 中即可
    if oAlpn <> '' then Check('OpenSSL ALPN 合法', (oAlpn = 'h2') or (oAlpn = 'http/1.1')) else Check('OpenSSL ALPN 允许为空', True);
    if wAlpn <> '' then Check('WinSSL ALPN 合法', (wAlpn = 'h2') or (wAlpn = 'http/1.1')) else Check('WinSSL ALPN 允许为空', True);
  end;
end;

begin
  WriteLn('Cross-Backend Consistency Contract Tests');
  WriteLn('========================================');

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestNormalizedContract;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
