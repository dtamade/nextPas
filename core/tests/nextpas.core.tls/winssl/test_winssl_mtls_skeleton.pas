program test_winssl_mtls_skeleton;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{**
 * WinSSL mTLS 客户端测试骨架
 *
 * P3-12: WinSSL 双向认证（mTLS）测试
 *
 * 测试内容:
 * - 客户端证书加载（PFX/MY 存储）
 * - 客户端证书选择
 * - mTLS 握手流程
 * - 证书链验证
 *
 * 运行条件:
 * - 设置环境变量 FAFAFA_RUN_NETWORK_TESTS=1
 * - 设置 FAFAFA_WINSSL_MTLS_SERVER（目标服务器）
 * - 设置 FAFAFA_WINSSL_CLIENT_CERT_SUBJECT 或 FAFAFA_WINSSL_PFX
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2025-12-23
 *}

uses
  {$IFDEF WINDOWS}
  Windows,
  WinSock2,
  nextpas.core.tls.winssl.lib,
  nextpas.core.tls.winssl.certstore,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base;

var
  Total, Passed, Failed, Skipped: Integer;
  Section: string;

procedure BeginSection(const aName: string);
begin
  Section := aName;
  WriteLn;
  WriteLn('=== ', aName, ' ===');
end;

procedure Check(const aName: string; ok: Boolean; const details: string = '');
begin
  Inc(Total);
  Write('  [', Section, '] ', aName, ': ');
  if ok then
  begin
    Inc(Passed);
    WriteLn('PASS');
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL');
    if details <> '' then
      WriteLn('    ', details);
  end;
end;

procedure Skip(const aName: string; const reason: string = '');
begin
  Inc(Total);
  Inc(Skipped);
  Write('  [', Section, '] ', aName, ': SKIP');
  if reason <> '' then
    WriteLn(' (', reason, ')')
  else
    WriteLn;
end;

{$IFDEF WINDOWS}
function InitWinsock: Boolean;
var
  W: TWSAData;
begin
  Result := WSAStartup(MAKEWORD(2, 2), W) = 0;
end;

procedure CleanupWinsock;
begin
  WSACleanup;
end;

function ConnectToHost(const aHost: string; aPort: Word; out aSocket: TSocket): Boolean;
var
  A: TSockAddrIn;
  H: PHostEnt;
  InAddr: TInAddr;
  Tm: Integer;
begin
  Result := False;
  aSocket := INVALID_SOCKET;

  aSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if aSocket = INVALID_SOCKET then
    Exit;

  Tm := 10000;
  setsockopt(aSocket, SOL_SOCKET, SO_RCVTIMEO, @Tm, SizeOf(Tm));
  setsockopt(aSocket, SOL_SOCKET, SO_SNDTIMEO, @Tm, SizeOf(Tm));

  H := gethostbyname(PAnsiChar(AnsiString(aHost)));
  if H = nil then
  begin
    closesocket(aSocket);
    aSocket := INVALID_SOCKET;
    Exit;
  end;

  FillChar(A, SizeOf(A), 0);
  A.sin_family := AF_INET;
  A.sin_port := htons(aPort);
  Move(H^.h_addr_list^^, InAddr, SizeOf(InAddr));
  A.sin_addr := InAddr;

  Result := connect(aSocket, @A, SizeOf(A)) = 0;
  if not Result then
  begin
    closesocket(aSocket);
    aSocket := INVALID_SOCKET;
  end;
end;
{$ENDIF}

{ 测试证书存储访问 }
procedure TestCertificateStoreAccess;
{$IFDEF WINDOWS}
var
  Store: ISSLCertificateStore;
  Count: Integer;
{$ENDIF}
begin
  BeginSection('证书存储访问');

  {$IFDEF WINDOWS}
  // 测试打开个人证书存储
  Store := OpenSystemStore(SSL_STORE_MY);
  Check('打开 MY 存储', Store <> nil);

  if Store <> nil then
  begin
    Count := Store.GetCount;
    Check('获取证书数量', Count >= 0, Format('数量: %d', [Count]));
  end;

  // 测试打开根证书存储
  Store := OpenSystemStore(SSL_STORE_ROOT);
  Check('打开 ROOT 存储', Store <> nil);

  if Store <> nil then
  begin
    Count := Store.GetCount;
    Check('获取根证书数量', Count >= 0, Format('数量: %d', [Count]));
  end;
  {$ELSE}
  Skip('证书存储访问', '仅 Windows 平台');
  {$ENDIF}
end;

{ 测试客户端证书查找 }
procedure TestClientCertificateLookup;
{$IFDEF WINDOWS}
var
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  CertSubject: string;
  I, Count: Integer;
{$ENDIF}
begin
  BeginSection('客户端证书查找');

  {$IFDEF WINDOWS}
  if GetEnvironmentVariable('FAFAFA_WINSSL_CLIENT_CERT_SUBJECT') = '' then
  begin
    Skip('按主题查找证书', 'FAFAFA_WINSSL_CLIENT_CERT_SUBJECT 未设置');
    Exit;
  end;

  CertSubject := GetEnvironmentVariable('FAFAFA_WINSSL_CLIENT_CERT_SUBJECT');

  Store := OpenSystemStore(SSL_STORE_MY);
  if Store = nil then
  begin
    Check('打开 MY 存储', False);
    Exit;
  end;

  Cert := nil;
  Count := Store.GetCount;
  for I := 0 to Count - 1 do
  begin
    Cert := Store.GetCertificate(I);
    if (Cert <> nil) and (Pos(CertSubject, Cert.GetSubject) > 0) then
      Break;
    Cert := nil;
  end;

  if Cert <> nil then
    Check('找到匹配证书', True, Cert.GetSubject)
  else
    Check('找到匹配证书', False, '未找到: ' + CertSubject);
  {$ELSE}
  Skip('客户端证书查找', '仅 Windows 平台');
  {$ENDIF}
end;

{ 测试 PFX 加载 }
procedure TestPFXLoading;
{$IFDEF WINDOWS}
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  PFXPath, PFXPassword: string;
{$ENDIF}
begin
  BeginSection('PFX 证书加载');

  {$IFDEF WINDOWS}
  PFXPath := GetEnvironmentVariable('FAFAFA_WINSSL_PFX');
  if PFXPath = '' then
  begin
    Skip('PFX 加载测试', 'FAFAFA_WINSSL_PFX 未设置');
    Exit;
  end;

  PFXPassword := GetEnvironmentVariable('FAFAFA_WINSSL_PFX_PASSWORD');

  Lib := CreateWinSSLLibrary;
  if not Lib.Initialize then
  begin
    Check('初始化 WinSSL 库', False, Lib.GetLastErrorString);
    Exit;
  end;
  Check('初始化 WinSSL 库', True);

  Ctx := Lib.CreateContext(sslCtxClient);
  Check('创建客户端上下文', Ctx <> nil);

  if Ctx <> nil then
  begin
    try
      Ctx.LoadPrivateKey(PFXPath, PFXPassword);
      Check('从 PFX 加载证书与私钥', True);
    except
      on E: Exception do
        Check('从 PFX 加载证书与私钥', False, E.Message);
    end;
  end;
  {$ELSE}
  Skip('PFX 证书加载', '仅 Windows 平台');
  {$ENDIF}
end;

{ 测试 mTLS 握手配置 }
procedure TestMTLSConfiguration;
{$IFDEF WINDOWS}
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
{$ENDIF}
begin
  BeginSection('mTLS 配置');

  {$IFDEF WINDOWS}
  Lib := CreateWinSSLLibrary;
  if not Lib.Initialize then
  begin
    Check('初始化 WinSSL 库', False, Lib.GetLastErrorString);
    Exit;
  end;

  Ctx := Lib.CreateContext(sslCtxClient);
  Check('创建客户端上下文', Ctx <> nil);

  if Ctx <> nil then
  begin
    // 测试协议版本设置
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Check('设置协议版本 (TLS 1.2/1.3)', True);

    // 测试服务器名称设置
    // INTENTIONAL_API_SURFACE: context-level SNI setter coverage. This
    // configuration smoke keeps the deprecated context setter visible on purpose.
    Ctx.SetServerName('test.example.com');
    Check('设置服务器名称 (SNI)', True);

    // 测试验证模式设置
    Ctx.SetVerifyMode([sslVerifyPeer]);
    Check('设置验证模式 (VerifyPeer)', True);
  end;
  {$ELSE}
  Skip('mTLS 配置', '仅 Windows 平台');
  {$ENDIF}
end;

{ 测试完整 mTLS 握手 }
procedure TestMTLSHandshake;
{$IFDEF WINDOWS}
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Socket: TSocket;
  ServerHost: string;
  ServerPort: Word;
{$ENDIF}
begin
  BeginSection('mTLS 握手');

  {$IFDEF WINDOWS}
  if GetEnvironmentVariable('FAFAFA_RUN_NETWORK_TESTS') <> '1' then
  begin
    Skip('mTLS 握手测试', 'FAFAFA_RUN_NETWORK_TESTS != 1');
    Exit;
  end;

  ServerHost := GetEnvironmentVariable('FAFAFA_WINSSL_MTLS_SERVER');
  if ServerHost = '' then
  begin
    Skip('mTLS 握手测试', 'FAFAFA_WINSSL_MTLS_SERVER 未设置');
    Exit;
  end;

  ServerPort := 443;

  if not InitWinsock then
  begin
    Check('初始化 Winsock', False);
    Exit;
  end;

  try
    Lib := CreateWinSSLLibrary;
    if not Lib.Initialize then
    begin
      Check('初始化 WinSSL 库', False, Lib.GetLastErrorString);
      Exit;
    end;

    Ctx := Lib.CreateContext(sslCtxClient);
    if Ctx = nil then
    begin
      Check('创建客户端上下文', False);
      Exit;
    end;

    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);

    // 加载客户端证书
    if GetEnvironmentVariable('FAFAFA_WINSSL_PFX') <> '' then
    begin
      try
        Ctx.LoadPrivateKey(
          GetEnvironmentVariable('FAFAFA_WINSSL_PFX'),
          GetEnvironmentVariable('FAFAFA_WINSSL_PFX_PASSWORD')
        );
        Check('加载客户端证书 (PFX)', True);
      except
        on E: Exception do
        begin
          Check('加载客户端证书 (PFX)', False, E.Message);
          Exit;
        end;
      end;
    end
    else
    begin
      Skip('加载客户端证书', '需要设置 FAFAFA_WINSSL_PFX');
      Exit;
    end;

    // 连接到服务器
    if not ConnectToHost(ServerHost, ServerPort, Socket) then
    begin
      Check('TCP 连接到 ' + ServerHost, False);
      Exit;
    end;
    Check('TCP 连接到 ' + ServerHost, True);

    try
      Conn := Ctx.CreateConnection(THandle(Socket));
      Check('创建连接对象', Conn <> nil);

      if Conn <> nil then
      begin
        Check('连接支持 ISSLClientConnection',
          Supports(Conn, ISSLClientConnection, ClientConn));
        if not Supports(Conn, ISSLClientConnection, ClientConn) then
          Exit;

        ClientConn.SetServerName(ServerHost);

        if Conn.DoHandshake = sslHsCompleted then
          Check('mTLS 握手', True)
        else
          Check('mTLS 握手', False, 'Handshake failed');
      end;
    finally
      closesocket(Socket);
    end;
  finally
    CleanupWinsock;
  end;
  {$ELSE}
  Skip('mTLS 握手测试', '仅 Windows 平台');
  {$ENDIF}
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('================================================================');
  WriteLn('WinSSL mTLS 测试摘要');
  WriteLn('================================================================');
  WriteLn('总计: ', Total);
  WriteLn('通过: ', Passed);
  WriteLn('失败: ', Failed);
  WriteLn('跳过: ', Skipped);
  WriteLn;

  if Failed = 0 then
  begin
    if Skipped > 0 then
      WriteLn('结果: 部分测试已跳过（非 Windows 平台或缺少配置）')
    else
      WriteLn('结果: 全部测试通过');
  end
  else
    WriteLn('结果: 存在失败的测试');

  WriteLn('================================================================');
end;

begin
  Total := 0;
  Passed := 0;
  Failed := 0;
  Skipped := 0;

  WriteLn('================================================================');
  WriteLn('WinSSL mTLS 客户端测试骨架');
  WriteLn('================================================================');
  WriteLn;
  WriteLn('说明:');
  WriteLn('  此测试需要设置以下环境变量:');
  WriteLn('  - FAFAFA_RUN_NETWORK_TESTS=1 (启用网络测试)');
  WriteLn('  - FAFAFA_WINSSL_MTLS_SERVER (mTLS 服务器地址)');
  WriteLn('  - FAFAFA_WINSSL_PFX (客户端 PFX 证书路径)');
  WriteLn('  - FAFAFA_WINSSL_PFX_PASSWORD (PFX 密码，可选)');
  WriteLn('  - FAFAFA_WINSSL_CLIENT_CERT_SUBJECT (或使用存储中的证书)');
  WriteLn;

  TestCertificateStoreAccess;
  TestClientCertificateLookup;
  TestPFXLoading;
  TestMTLSConfiguration;
  TestMTLSHandshake;

  PrintSummary;

  if Failed > 0 then
    Halt(1);
end.
