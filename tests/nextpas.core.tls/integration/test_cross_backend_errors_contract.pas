{******************************************************************************}
{  Cross-Backend Error Contract Tests                                          }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_cross_backend_errors_contract;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,

  nextpas.core.tls.base,
  {$IFNDEF WINDOWS}
  sockets,
  BaseUnix, Unix,
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

type
  TInetSockAddr = record
    sin_family: cushort;
    sin_port: cushort;
    sin_addr: in_addr;
    sin_zero: array[0..7] of char;
  end;

  PHostEnt = ^THostEnt;
  THostEnt = record
    h_name: PChar;
    h_aliases: PPChar;
    h_addrtype: cint;
    h_length: cint;
    h_addr_list: PPChar;
  end;

function gethostbyname(name: PChar): PHostEnt; cdecl; external 'c';
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

{$IFDEF WINDOWS}
function ConnectTCP(const H: string; Port: Word; out Sock: THandle): Boolean;
var A: TSockAddrIn; WSA: TWSAData; HE: PHostEnt; InA: TInAddr; Tm: Integer;
begin
  Result := False; Sock := INVALID_HANDLE_VALUE; if WSAStartup(MAKEWORD(2,2), WSA) <> 0 then Exit;
  Sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP); if Sock = INVALID_SOCKET then Exit;
  Tm := 10000; setsockopt(Sock, SOL_SOCKET, SO_RCVTIMEO, @Tm, SizeOf(Tm)); setsockopt(Sock, SOL_SOCKET, SO_SNDTIMEO, @Tm, SizeOf(Tm));
  HE := gethostbyname(PAnsiChar(AnsiString(H))); if HE = nil then begin closesocket(Sock); Sock := INVALID_SOCKET; Exit; end;
  FillChar(A, SizeOf(A), 0); A.sin_family := AF_INET; A.sin_port := htons(Port); Move(HE^.h_addr_list^^, InA, SizeOf(InA)); A.sin_addr := InA;
  Result := connect(Sock, @A, SizeOf(A)) = 0; if not Result then begin closesocket(Sock); Sock := INVALID_SOCKET; end;
end;
{$ELSE}
function ConnectTCP(const H: string; Port: Word; out Sock: THandle): Boolean;
var A: TInetSockAddr; HE: PHostEnt; Sfd: cint;
begin
  Result := False; Sock := THandle(-1);
  Sfd := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Sfd < 0 then Exit;
  HE := gethostbyname(PChar(H));
  if HE = nil then begin fpClose(Sfd); Exit; end;
  FillChar(A, SizeOf(A), 0);
  A.sin_family := AF_INET;
  A.sin_port := htons(Port);
  Move(HE^.h_addr_list^^, A.sin_addr, SizeOf(A.sin_addr));
  if fpConnect(Sfd, @A, SizeOf(A)) = 0 then
  begin
    Sock := Sfd; Result := True;
  end
  else
    fpClose(Sfd);
end;
{$ENDIF}

procedure Probe(const Host: string; out Code: Integer; out Str: string; SideIsWin: Boolean);
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  S: THandle;
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
    Conn := Ctx.CreateConnection(S);
    if Conn = nil then Exit;
    if not Supports(Conn, ISSLClientConnection, ClientConn) then Exit;
    ClientConn.SetServerName(Host);
    ok := Conn.Connect;
    if not ok then Exit;
    Code := GetVerificationResult(Conn);
    Str := GetVerificationResultString(Conn);
    Conn.Shutdown;
  finally
    {$IFDEF WINDOWS} if S <> INVALID_HANDLE_VALUE then closesocket(S) {$ELSE} if S <> THandle(-1) then fpClose(S) {$ENDIF};
  end;
end;

var
  c: Integer; s: string; k: TErrorKind;
  failCode: Integer; failStr: string;
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; ClientConn: ISSLClientConnection;
  Sfd, SockRefused, SockNX: THandle; ok: Boolean;

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
          Conn := Ctx.CreateConnection(Sfd);
          if (Conn <> nil) and Supports(Conn, ISSLClientConnection, ClientConn) then
            ClientConn.SetServerName('www.google.com');
          ok := (Conn <> nil) and Conn.Connect;
          Check('HTTP:80 握手应失败', not ok);
        finally
          {$IFDEF WINDOWS} if Sfd <> INVALID_HANDLE_VALUE then closesocket(Sfd) {$ELSE} if Sfd <> THandle(-1) then fpClose(Sfd) {$ENDIF};
        end;
      end;
    end;
  end;

  // 连接拒绝（本地环回：端口1通常拒绝）
  if ConnectTCP('127.0.0.1', 1, SockRefused) then
  begin
    {$IFDEF WINDOWS} closesocket(SockRefused) {$ELSE} fpClose(SockRefused) {$ENDIF};
    Check('127.0.0.1:1 预期连接拒绝', False, '意外连接成功');
  end
  else
    Check('127.0.0.1:1 连接被拒绝（预期）', True);

  // 不存在的域名（NXDOMAIN）
  if ConnectTCP('nonexistent.invalid', 443, SockNX) then
  begin
    {$IFDEF WINDOWS} closesocket(SockNX) {$ELSE} fpClose(SockNX) {$ENDIF};
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

    if GetEnvironmentVariable('FAFAFA_RUN_NETWORK_TESTS') <> '1' then
      Runner.Skip('Network tests gate', '[environment] network tests disabled (FAFAFA_RUN_NETWORK_TESTS!=1)')
    else
      RunErrorTests;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.
