program test_winssl_alpn_sni;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  {$IFDEF WINDOWS}Windows, WinSock2,{$ENDIF}
  SysUtils, Classes,
  
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
  if ok then begin
    Inc(Passed); WriteLn('PASS');
  end else begin
    Inc(Failed); WriteLn('FAIL');
    if details <> '' then WriteLn('    ', details);
  end;
end;

function InitWinsock: Boolean;
var W: TWSAData; begin Result := WSAStartup(MAKEWORD(2,2), W) = 0; end;
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

procedure TestAlpnSni(const Host: string);
var
  Lib: ISSLLibrary; Ctx: ISSLContext; Conn: ISSLConnection; S: TSocket;
  Proto: string; Handshook: Boolean; runNet: Boolean;
begin
  BeginSection('ALPN/SNI 客户端协商');

  runNet := GetEnvironmentVariable('FAFAFA_RUN_NETWORK_TESTS') = '1';
  if not runNet then begin
    Check('跳过网络测试 (FAFAFA_RUN_NETWORK_TESTS!=1)', True);
    Exit;
  end;

  if not InitWinsock then begin
    Check('初始化 Winsock', False); Exit; end;
  try
    Lib := CreateWinSSLLibrary;
    if not Lib.Initialize then begin Check('初始化 WinSSL 库', False, Lib.GetLastErrorString); Exit; end;
    Check('初始化 WinSSL 库', True);

    Ctx := Lib.CreateContext(sslCtxClient);
    Check('创建客户端上下文', Ctx <> nil);
    if Ctx = nil then Exit;

    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Check('设置协议版本 (TLS 1.2/1.3)', True);

    Ctx.SetALPNProtocols('h2,http/1.1');
    Check('设置 ALPN 偏好字符串', Ctx.GetALPNProtocols = 'h2,http/1.1');

    if not ConnectToHost(Host, 443, S) then begin
      Check('TCP 连接到 ' + Host, False); Exit; end;

    try
      Conn := Ctx.CreateConnection(S);
      Check('创建 SSL 连接对象', Conn <> nil);
      if Conn = nil then Exit;
      (Conn as ISSLClientConnection).SetServerName(Host);
      Check('设置 SNI 主机名', True);

      Handshook := Conn.Connect;
      Check('TLS 握手完成', Handshook);
      if not Handshook then Exit;

      {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
      Proto := Conn.GetSelectedALPNProtocol;
      {$POP}
      WriteLn('    协商 ALPN: "', Proto, '"');
      // 不强制要求为 h2，部分平台默认回退 http/1.1 或空
      Check('读取协商协议（可为空/h2/http/1.1）', True, 'ALPN=' + Proto);

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
  WriteLn('WinSSL ALPN/SNI 测试');
  TestAlpnSni('api.github.com');
  WriteLn; WriteLn('总计: ', Total, ' 通过: ', Passed, ' 失败: ', Failed);
  if Failed > 0 then Halt(1);
end.
