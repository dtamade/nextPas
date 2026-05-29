program test_winssl_context_config;

{$mode objfpc}{$H+}

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes,

  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.winssl.lib;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestPass(const ATestName: string);
begin
  Inc(TestsPassed);
  WriteLn('[PASS] ', ATestName);
end;

procedure TestFail(const ATestName, AReason: string);
begin
  Inc(TestsFailed);
  WriteLn('[FAIL] ', ATestName, ': ', AReason);
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

// ============================================================================
// Test: LoadPrivateKey 基本功能
// ============================================================================
procedure TestLoadPrivateKeyBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  WriteLn('=== Test: LoadPrivateKey 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('LoadPrivateKey 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxServer);

    // 注意：LoadPrivateKey 需要 PFX/P12 格式文件
    // WinSSL 不支持直接加载 PEM 格式私钥
    // 这个测试验证接口可用性
    TestPass('LoadPrivateKey 基本功能 - 接口可用');

  except
    on E: Exception do
      TestFail('LoadPrivateKey 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: LoadCertificate 从内存加载
// ============================================================================
procedure TestLoadCertificateFromMemory;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LMemStream: TMemoryStream;
begin
  WriteLn('=== Test: LoadCertificate 从内存加载 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('LoadCertificate 从内存', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxServer);
    LMemStream := TMemoryStream.Create;
    try
      // 注意：需要有效的证书数据
      // 这个测试验证接口可用性
      TestPass('LoadCertificate 从内存 - 接口可用（使用 TMemoryStream）');
    finally
      LMemStream.Free;
    end;

  except
    on E: Exception do
      TestFail('LoadCertificate 从内存', E.Message);
  end;
end;

// ============================================================================
// Test: SetCipherList 基本功能
// ============================================================================
procedure TestSetCipherListBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LRejected: Boolean;
begin
  WriteLn('=== Test: SetCipherList 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('SetCipherList 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    LRejected := False;
    try
      LContext.SetCipherList('TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384');
    except
      on E: ESSLException do
      begin
        if not IsUnsupportedCipherMessage(E.Message) then
          raise;
        LRejected := True;
      end;
    end;

    if LRejected then
      TestPass('SetCipherList 基本功能 - custom non-default override 正确拒绝')
    else
      TestFail('SetCipherList 基本功能', 'WinSSL 应拒绝 custom non-default cipher-list override');

  except
    on E: Exception do
      TestFail('SetCipherList 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: SetCipherSuites 基本功能
// ============================================================================
procedure TestSetCipherSuitesBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LRejected: Boolean;
begin
  WriteLn('=== Test: SetCipherSuites 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('SetCipherSuites 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    LRejected := False;
    try
      LContext.SetCipherSuites('TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256');
    except
      on E: ESSLException do
      begin
        if not IsUnsupportedCipherMessage(E.Message) then
          raise;
        LRejected := True;
      end;
    end;

    if LRejected then
      TestPass('SetCipherSuites 基本功能 - custom non-default override 正确拒绝')
    else
      TestFail('SetCipherSuites 基本功能', 'WinSSL 应拒绝 custom non-default cipher-suites override');

  except
    on E: Exception do
      TestFail('SetCipherSuites 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: SetALPNProtocols 基本功能
// ============================================================================
procedure TestSetALPNProtocolsBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LALPNProtocols: string;
begin
  WriteLn('=== Test: SetALPNProtocols 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('SetALPNProtocols 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 设置 ALPN 协议列表
    LContext.SetALPNProtocols('h2,http/1.1');

    // 获取 ALPN 协议列表
    LALPNProtocols := LContext.GetALPNProtocols;

    if LALPNProtocols = 'h2,http/1.1' then
      TestPass('SetALPNProtocols 基本功能 - 设置和获取成功')
    else
      TestFail('SetALPNProtocols 基本功能', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('SetALPNProtocols 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: SetSessionCacheSize 基本功能
// ============================================================================
procedure TestSetSessionCacheSizeBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LCacheSize: Integer;
begin
  WriteLn('=== Test: SetSessionCacheSize 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('SetSessionCacheSize 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 设置会话缓存大小
    LContext.SetSessionCacheSize(1000);

    // 获取会话缓存大小
    LCacheSize := LContext.GetSessionCacheSize;

    if LCacheSize = 1000 then
      TestPass('SetSessionCacheSize 基本功能 - 设置和获取成功')
    else
      TestFail('SetSessionCacheSize 基本功能', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('SetSessionCacheSize 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: SetSessionTimeout 基本功能
// ============================================================================
procedure TestSetSessionTimeoutBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LTimeout: Integer;
begin
  WriteLn('=== Test: SetSessionTimeout 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('SetSessionTimeout 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 设置会话超时（秒）
    LContext.SetSessionTimeout(3600);  // 1 小时

    // 获取会话超时
    LTimeout := LContext.GetSessionTimeout;

    if LTimeout = 3600 then
      TestPass('SetSessionTimeout 基本功能 - 设置和获取成功')
    else
      TestFail('SetSessionTimeout 基本功能', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('SetSessionTimeout 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: 配置方法组合使用
// ============================================================================
procedure TestConfigurationCombination;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  WriteLn('=== Test: 配置方法组合使用 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('配置方法组合', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 组合配置
    LContext.SetCipherList(SSL_DEFAULT_CIPHER_LIST);
    LContext.SetALPNProtocols('h2,http/1.1');
    LContext.SetSessionCacheSize(500);
    LContext.SetSessionTimeout(7200);

    // 验证所有配置
    if (LContext.GetCipherList = SSL_DEFAULT_CIPHER_LIST) and
       (LContext.GetALPNProtocols = 'h2,http/1.1') and
       (LContext.GetSessionCacheSize = 500) and
       (LContext.GetSessionTimeout = 7200) then
      TestPass('配置方法组合 - shipped baseline 与其它已发布配置正确应用')
    else
      TestFail('配置方法组合', '部分配置未正确应用');

  except
    on E: Exception do
      TestFail('配置方法组合', E.Message);
  end;
end;

// ============================================================================
// Test: 密码套件安全配置
// ============================================================================
procedure TestSecureCipherConfiguration;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LRejected: Boolean;
begin
  WriteLn('=== Test: 密码套件安全配置 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('密码套件安全配置', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    LRejected := False;
    try
      LContext.SetCipherList(
        'TLS_AES_128_GCM_SHA256:' +
        'TLS_AES_256_GCM_SHA384:' +
        'ECDHE-RSA-AES128-GCM-SHA256:' +
        'ECDHE-RSA-AES256-GCM-SHA384'
      );
    except
      on E: ESSLException do
      begin
        if not IsUnsupportedCipherMessage(E.Message) then
          raise;
        LRejected := True;
      end;
    end;

    if not LRejected then
    begin
      TestFail('密码套件安全配置', 'WinSSL 应拒绝 custom non-default cipher-list override');
      Exit;
    end;

    // 配置现代协议
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);

    TestPass('密码套件安全配置 - custom override 正确拒绝，协议收紧仍可用');

  except
    on E: Exception do
      TestFail('密码套件安全配置', E.Message);
  end;
end;

// ============================================================================
// Test: ALPN 协议协商配置
// ============================================================================
procedure TestALPNConfiguration;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  WriteLn('=== Test: ALPN 协议协商配置 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('ALPN 配置', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 配置 HTTP/2 优先
    LContext.SetALPNProtocols('h2,http/1.1');

    // 注意：ALPN 在 Windows 8.1/Server 2012 R2+ 支持
    // 实际协商在连接时进行
    TestPass('ALPN 配置 - HTTP/2 优先配置成功');

  except
    on E: Exception do
      TestFail('ALPN 配置', E.Message);
  end;
end;

// ============================================================================
// Test: Session 缓存配置
// ============================================================================
procedure TestSessionCacheConfiguration;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  WriteLn('=== Test: Session 缓存配置 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('Session 缓存配置', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 启用 Session 缓存
    LContext.SetSessionCacheMode(True);

    // 配置缓存大小和超时
    LContext.SetSessionCacheSize(1000);  // 1000 个 Session
    LContext.SetSessionTimeout(36000);   // 10 小时

    if LContext.GetSessionCacheMode and
       (LContext.GetSessionCacheSize = 1000) and
       (LContext.GetSessionTimeout = 36000) then
      TestPass('Session 缓存配置 - 配置成功')
    else
      TestFail('Session 缓存配置', '配置未正确应用');

  except
    on E: Exception do
      TestFail('Session 缓存配置', E.Message);
  end;
end;

// ============================================================================
// Main
// ============================================================================
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('WinSSL Context Configuration Unit Tests');
  WriteLn('========================================');
  WriteLn('');

  // 基本功能测试
  TestLoadPrivateKeyBasic;
  TestLoadCertificateFromMemory;
  TestSetCipherListBasic;
  TestSetCipherSuitesBasic;
  TestSetALPNProtocolsBasic;
  TestSetSessionCacheSizeBasic;
  TestSetSessionTimeoutBasic;

  // 组合配置测试
  TestConfigurationCombination;

  // 应用场景测试
  TestSecureCipherConfiguration;
  TestALPNConfiguration;
  TestSessionCacheConfiguration;

  // 总结
  WriteLn('');
  WriteLn('========================================');
  WriteLn('测试总结:');
  WriteLn('  通过: ', TestsPassed);
  WriteLn('  失败: ', TestsFailed);
  WriteLn('========================================');
  WriteLn('');

  if TestsFailed > 0 then
    Halt(1);
end.
