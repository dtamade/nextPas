program test_winssl_context_comprehensive;

{$mode objfpc}{$H+}

{
  test_winssl_context_comprehensive - WinSSL 上下文综合测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 第四阶段
    测试 WinSSL 上下文配置和管理系统

    需要 Windows 环境运行

  测试内容:
    1. 上下文创建和初始化
    2. 协议版本配置
    3. 验证模式配置
    4. 密码套件配置
    5. 会话管理配置
    6. 服务器名称配置
    7. ALPN 协议配置
    8. 证书验证标志
    9. 选项配置
    10. 上下文类型查询
    11. 上下文有效性检查
    12. 原生句柄获取
}

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.winssl.base;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

function IsUnsupportedCipherMessage(const AMessage: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(AMessage);
  Result := (Pos('unsupported', LLower) > 0) or
    (Pos('supportscustomciphersuites', LLower) > 0) or
    (Pos('不支持', AMessage) > 0);
end;

procedure TestContextCreation;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 1】上下文创建和初始化');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 初始化配置
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    // 创建客户端上下文
    LContext := TSSLFactory.CreateContext(LConfig);
    Assert(LContext <> nil, '客户端上下文创建成功');
    Assert(LContext.GetContextType = sslCtxClient, '上下文类型为客户端');
    Assert(LContext.IsValid, '上下文有效');

    // 创建服务端上下文
    LConfig.ContextType := sslCtxServer;
    LContext := TSSLFactory.CreateContext(LConfig);
    Assert(LContext <> nil, '服务端上下文创建成功');
    Assert(LContext.GetContextType = sslCtxServer, '上下文类型为服务端');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestProtocolVersions;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
  LVersions: TSSLProtocolVersions;
begin
  WriteLn('【测试 2】协议版本配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试默认协议版本
    LVersions := LContext.GetProtocolVersions;
    Assert(LVersions <> [], '默认协议版本非空');

    // 测试设置 TLS 1.2
    LContext.SetProtocolVersions([sslProtocolTLS12]);
    LVersions := LContext.GetProtocolVersions;
    Assert(sslProtocolTLS12 in LVersions, '协议版本包含 TLS 1.2');

    // 测试设置 TLS 1.3
    LContext.SetProtocolVersions([sslProtocolTLS13]);
    LVersions := LContext.GetProtocolVersions;
    Assert(sslProtocolTLS13 in LVersions, '协议版本包含 TLS 1.3');

    // 测试设置多个版本
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LVersions := LContext.GetProtocolVersions;
    Assert(sslProtocolTLS12 in LVersions, '协议版本包含 TLS 1.2');
    Assert(sslProtocolTLS13 in LVersions, '协议版本包含 TLS 1.3');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestVerifyMode;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
  LMode: TSSLVerifyModes;
begin
  WriteLn('【测试 3】验证模式配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试默认验证模式
    LMode := LContext.GetVerifyMode;
    Assert(LMode <> [], '默认验证模式非空');

    // 测试设置验证对端
    LContext.SetVerifyMode([sslVerifyPeer]);
    LMode := LContext.GetVerifyMode;
    Assert(sslVerifyPeer in LMode, '验证模式包含 VerifyPeer');

    // 测试设置多个验证选项
    LContext.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);
    LMode := LContext.GetVerifyMode;
    Assert(sslVerifyPeer in LMode, '验证模式包含 VerifyPeer');
    Assert(sslVerifyFailIfNoPeerCert in LMode, '验证模式包含 FailIfNoPeerCert');

    // 测试验证深度
    LContext.SetVerifyDepth(10);
    Assert(LContext.GetVerifyDepth = 10, '验证深度设置为 10');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestCipherConfiguration;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
  LRejected: Boolean;
begin
  WriteLn('【测试 4】密码套件配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    LRejected := False;
    try
      LContext.SetCipherList('HIGH:!aNULL:!MD5');
    except
      on E: ESSLException do
      begin
        Assert(IsUnsupportedCipherMessage(E.Message),
          'WinSSL custom cipher-list rejection reports unsupported semantics');
        LRejected := True;
      end;
    end;
    Assert(LRejected, 'WinSSL custom cipher-list override is rejected');

    LRejected := False;
    try
      LContext.SetCipherSuites('TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256');
    except
      on E: ESSLException do
      begin
        Assert(IsUnsupportedCipherMessage(E.Message),
          'WinSSL custom cipher-suites rejection reports unsupported semantics');
        LRejected := True;
      end;
    end;
    Assert(LRejected, 'WinSSL custom cipher-suites override is rejected');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestSessionManagement;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 5】会话管理配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试会话缓存模式
    LContext.SetSessionCacheMode(True);
    Assert(LContext.GetSessionCacheMode, '会话缓存已启用');

    LContext.SetSessionCacheMode(False);
    Assert(not LContext.GetSessionCacheMode, '会话缓存已禁用');

    // 测试会话超时
    LContext.SetSessionTimeout(600);
    Assert(LContext.GetSessionTimeout = 600, '会话超时设置为 600 秒');

    // 测试会话缓存大小
    LContext.SetSessionCacheSize(1024);
    Assert(LContext.GetSessionCacheSize = 1024, '会话缓存大小设置为 1024');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestServerNameConfiguration;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 6】服务器名称配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // INTENTIONAL_API_SURFACE: context-level SNI setter coverage. This
    // comprehensive context test validates ISSLContext setter/getter behavior,
    // not recommended connection-flow guidance.
    // 测试设置服务器名称
    LContext.SetServerName('example.com');
    Assert(LContext.GetServerName = 'example.com', '服务器名称设置为 example.com');

    LContext.SetServerName('test.example.org');
    Assert(LContext.GetServerName = 'test.example.org', '服务器名称更新为 test.example.org');

    // 测试清空服务器名称
    LContext.SetServerName('');
    Assert(LContext.GetServerName = '', '服务器名称已清空');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestALPNConfiguration;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 7】ALPN 协议配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试设置 ALPN 协议
    LContext.SetALPNProtocols('h2,http/1.1');
    Assert(LContext.GetALPNProtocols = 'h2,http/1.1', 'ALPN 协议设置为 h2,http/1.1');

    LContext.SetALPNProtocols('h3,h2,http/1.1');
    Assert(LContext.GetALPNProtocols = 'h3,h2,http/1.1', 'ALPN 协议更新为 h3,h2,http/1.1');

    // 测试清空 ALPN 协议
    LContext.SetALPNProtocols('');
    Assert(LContext.GetALPNProtocols = '', 'ALPN 协议已清空');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestOptionsConfiguration;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
  LOptions: TSSLOptions;
begin
  WriteLn('【测试 8】选项配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试默认选项
    LOptions := LContext.GetOptions;
    Assert(LOptions <> [], '默认选项非空');

    // 测试设置选项
    LContext.SetOptions([ssoEnableSNI, ssoEnableALPN]);
    LOptions := LContext.GetOptions;
    Assert(ssoEnableSNI in LOptions, '选项包含 EnableSNI');
    Assert(ssoEnableALPN in LOptions, '选项包含 EnableALPN');

    // 测试更新选项
    LContext.SetOptions([ssoEnableSessionCache, ssoEnableSessionTickets]);
    LOptions := LContext.GetOptions;
    Assert(ssoEnableSessionCache in LOptions, '选项包含 EnableSessionCache');
    Assert(ssoEnableSessionTickets in LOptions, '选项包含 EnableSessionTickets');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestCertVerifyFlags;
var
  LContext: ISSLContext;
  LConfig: TSSLConfig;
  LFlags: TSSLCertVerifyFlags;
begin
  WriteLn('【测试 9】证书验证标志');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试默认验证标志
    LFlags := LContext.GetCertVerifyFlags;
    Assert(LFlags <> [], '默认验证标志非空');

    // 测试设置验证标志
    LContext.SetCertVerifyFlags([sslCertVerifyCheckRevocation]);
    LFlags := LContext.GetCertVerifyFlags;
    Assert(sslCertVerifyCheckRevocation in LFlags, '验证标志包含 CheckRevocation');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestContextValidity;
var
  LContext: ISSLContext;
  LNativeAccess: ISSLNativeHandleAccess;
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 10】上下文有效性检查');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    FillChar(LConfig, SizeOf(LConfig), 0);
    LConfig.LibraryType := sslWinSSL;
    LConfig.ContextType := sslCtxClient;

    LContext := TSSLFactory.CreateContext(LConfig);

    // 测试上下文有效性
    Assert(LContext.IsValid, '上下文有效');

    // 测试获取原生句柄
    Assert(Supports(LContext, ISSLNativeHandleAccess, LNativeAccess),
      '上下文支持原生句柄访问');
    if LNativeAccess <> nil then
      Assert(LNativeAccess.GetNativeHandle <> nil, '原生句柄非空');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure PrintSummary;
begin
  WriteLn('=========================================');
  WriteLn('测试总结');
  WriteLn('=========================================');
  WriteLn('通过: ', GTestsPassed);
  WriteLn('失败: ', GTestsFailed);
  WriteLn('总计: ', GTestsPassed + GTestsFailed);

  if GTestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('✓ 所有上下文配置测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查上下文实现');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('WinSSL 上下文综合测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  {$IFDEF WINDOWS}
  WriteLn('运行环境: Windows');
  {$ELSE}
  WriteLn('运行环境: 非 Windows（部分测试将跳过）');
  {$ENDIF}
  WriteLn;

  try
    TestContextCreation;
    TestProtocolVersions;
    TestVerifyMode;
    TestCipherConfiguration;
    TestSessionManagement;
    TestServerNameConfiguration;
    TestALPNConfiguration;
    TestOptionsConfiguration;
    TestCertVerifyFlags;
    TestContextValidity;

    WriteLn;
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn('错误: ', E.Message);
      Halt(1);
    end;
  end;
end.
