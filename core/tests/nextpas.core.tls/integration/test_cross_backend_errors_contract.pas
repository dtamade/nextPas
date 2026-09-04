{******************************************************************************}
{  Cross-Backend Error Contract Tests                                          }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_cross_backend_errors_contract;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  nextpas.core.system.sysutils, nextpas.core.system.classes,

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

{$IFDEF WINDOWS}
const
  CERT_E_EXPIRED = $800B0101;
  CERT_E_CN_NO_MATCH = $800B010F;
  CERT_E_INVALID_NAME = $800B0114;
{$ELSE}
const
  CERT_E_EXPIRED = $800B0101;
  CERT_E_CN_NO_MATCH = $800B010F;
  CERT_E_INVALID_NAME = $800B0114;
{$ENDIF}

type
  TErrorKind = (ErrNone, ErrExpired, ErrHostname, ErrOther);

var
  Runner: TSimpleTestRunner;

function NormalizeError(aSideIsWin: Boolean; aCode: Integer; const aStr: string): TErrorKind;
begin
  Result := ErrOther;
  if aSideIsWin then
  begin
    // Windows 常见错误码
    if aCode = CERT_E_EXPIRED then Exit(ErrExpired);
    if (aCode = CERT_E_CN_NO_MATCH) or (aCode = CERT_E_INVALID_NAME) then Exit(ErrHostname);
  end
  else
  begin
    // OpenSSL 错误字符串包含关键词（简化归一化）
    if Pos('expired', LowerCase(aStr)) > 0 then Exit(ErrExpired);
    if (Pos('host', LowerCase(aStr)) > 0) or (Pos('name', LowerCase(aStr)) > 0) then Exit(ErrHostname);
  end;
end;

procedure Check(const Name: string; ok: Boolean; const details: string = '');
begin
  Runner.Check(Name, ok, details);
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

function GetVerificationResultString(AConn: ISSLConnection): string;
var
  LCertVerify: ISSLCertificateVerification;
begin
  if Supports(AConn, ISSLCertificateVerification, LCertVerify) then
    Result := LCertVerify.GetVerifyResultString
  else
    Result := '';
end;

function ConnectTCP(const H: string; Port: Word;
  out Sock: TPlatformSocket): Boolean;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := False;
  Sock := PLATFORM_INVALID_SOCKET;
  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(H)), LIP) <> 0 then
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

procedure Probe(const Host: string; out Code: Integer; out Str: string; SideIsWin: Boolean);
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  S: TPlatformSocket;
  ok: Boolean;
begin
  Code := 0; Str := '';
  Lib := {$IFDEF WINDOWS}CreateWinSSLLibrary{$ELSE}TOpenSSLLibrary.Create{$ENDIF};
  if (Lib = nil) or (not Lib.Initialize) then Exit;
  Ctx := Lib.CreateContext(sslCtxClient);
  if Ctx = nil then Exit;
  Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  if not ConnectTCP(Host, 443, S) then Exit;
  try
    Conn := Ctx.CreateConnection(THandle(S.Value));
    if Conn = nil then Exit;
    if not Supports(Conn, ISSLClientConnection, ClientConn) then Exit;
    ClientConn.SetServerName(Host);
    ok := Conn.Connect;
    if not ok then Exit;
    Code := GetVerificationResult(Conn);
    Str := GetVerificationResultString(Conn);
    Conn.Shutdown;
  finally
    if S.IsValid then
      platform_socket_close(S);
  end;
end;

var
  c: Integer; s: string; k: TErrorKind;
  failCode: Integer; failStr: string;
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; ClientConn: ISSLClientConnection;
  Sfd, SockRefused, SockNX: TPlatformSocket; ok: Boolean;

procedure RunErrorTests;
begin
  // 过期证书
  Probe('expired.badssl.com', c, s, {$IFDEF WINDOWS}True{$ELSE}False{$ENDIF});
  Check('expired.badssl.com 非零校验结果', c <> 0, s);
  k := NormalizeError({$IFDEF WINDOWS}True{$ELSE}False{$ENDIF}, c, s);
  Check('expired 归一化为 ErrExpired', k = ErrExpired, s);

  // 主机名不匹配
  Probe('wrong.host.badssl.com', c, s, {$IFDEF WINDOWS}True{$ELSE}False{$ENDIF});
  Check('wrong.host 非零校验结果', c <> 0, s);
  k := NormalizeError({$IFDEF WINDOWS}True{$ELSE}False{$ENDIF}, c, s);
  Check('hostname 归一化为 ErrHostname', k = ErrHostname, s);

  // 错误端口（HTTP 80）— 握手应失败
  Lib := {$IFDEF WINDOWS}CreateWinSSLLibrary{$ELSE}TOpenSSLLibrary.Create{$ENDIF};
  if (Lib <> nil) and Lib.Initialize then
  begin
    Ctx := Lib.CreateContext(sslCtxClient);
    if Ctx <> nil then
    begin
      Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      if ConnectTCP('www.google.com', 80, Sfd) then
      begin
        try
          Conn := Ctx.CreateConnection(THandle(Sfd.Value));
          if (Conn <> nil) and Supports(Conn, ISSLClientConnection, ClientConn) then
            ClientConn.SetServerName('www.google.com');
          ok := (Conn <> nil) and Conn.Connect;
          Check('HTTP:80 握手应失败', not ok);
        finally
          if Sfd.IsValid then
            platform_socket_close(Sfd);
        end;
      end;
    end;
  end;

  // 连接拒绝（本地环回：端口1通常拒绝）
  if ConnectTCP('127.0.0.1', 1, SockRefused) then
  begin
    platform_socket_close(SockRefused);
    Check('127.0.0.1:1 预期连接拒绝', False, '意外连接成功');
  end
  else
    Check('127.0.0.1:1 连接被拒绝（预期）', True);

  // 不存在的域名（NXDOMAIN）
  if ConnectTCP('nonexistent.invalid', 443, SockNX) then
  begin
    platform_socket_close(SockNX);
    Check('nonexistent.invalid 应解析失败', False, '意外连接成功');
  end
  else
    Check('nonexistent.invalid 解析/连接失败（预期）', True);
end;

begin
  WriteLn('Cross-Backend Error Contract Tests');
  WriteLn('===================================');

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    if GetEnvironmentVariable('NEXTPAS_RUN_NETWORK_TESTS') <> '1' then
      Runner.Skip('Network tests gate', '[environment] network tests disabled (NEXTPAS_RUN_NETWORK_TESTS!=1)')
    else
      RunErrorTests;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
