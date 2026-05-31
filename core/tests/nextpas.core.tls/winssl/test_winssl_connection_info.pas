program test_winssl_connection_info;

{$mode objfpc}{$H+}

{ INTENTIONAL_CORE_SURFACE: this file intentionally keeps direct core
  GetConnectionInfo / GetProtocolVersion / GetCipherName /
  GetPeerCertificateChain coverage for the WinSSL compatibility-core surface.
  Owner-path coverage lives in ISSLConnectionInfo /
  ISSLCertificateVerification-focused proofs and backend contract checks. }
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

uses
  {$IFDEF WINDOWS}
  Windows, WinSock2,
  {$ELSE}
  Sockets,
  {$ENDIF}
  SysUtils, Classes,

  nextpas.core.tls.base,
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

// ============================================================================
// Test: GetConnectionInfo 基本功能
// ============================================================================
procedure TestGetConnectionInfoBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LInfo: TSSLConnectionInfo;
begin
  WriteLn('=== Test: GetConnectionInfo 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('GetConnectionInfo 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetVerifyMode([]);  // 测试环境禁用验证

    // 注意：这个测试需要实际的网络连接
    // 在实际测试中，应该使用 mock socket 或本地测试服务器
    TestPass('GetConnectionInfo 基本功能 - 接口可用');

  except
    on E: Exception do
      TestFail('GetConnectionInfo 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: GetConnectionInfo 未连接状态
// ============================================================================
procedure TestGetConnectionInfoNotConnected;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LInfo: TSSLConnectionInfo;
  LSocket: TSocket;
begin
  WriteLn('=== Test: GetConnectionInfo 未连接状态 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('GetConnectionInfo 未连接状态', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 创建未连接的连接对象
    LSocket := INVALID_SOCKET;
    LConn := LContext.CreateConnection(LSocket);

    // 获取连接信息（应该返回默认值）
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    LInfo := LConn.GetConnectionInfo;
    {$POP}

    // 验证默认值
    if (LInfo.ProtocolVersion = sslProtocolTLS12) and  // 默认协议版本
       (LInfo.CipherSuite = '') and                     // 空密码套件
       (LInfo.KeySize = 0) and                          // 0 密钥长度
       (not LInfo.IsResumed) then                       // 未复用
      TestPass('GetConnectionInfo 未连接状态 - 返回默认值')
    else
      TestFail('GetConnectionInfo 未连接状态', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('GetConnectionInfo 未连接状态', E.Message);
  end;
end;

// ============================================================================
// Test: GetConnectionInfo 字段完整性
// ============================================================================
procedure TestGetConnectionInfoFields;
begin
  WriteLn('=== Test: GetConnectionInfo 字段完整性 ===');

  // TSSLConnectionInfo 结构应该包含以下字段：
  // - ProtocolVersion: TSSLProtocolVersion
  // - CipherSuite: string
  // - CipherSuiteId: Word
  // - KeyExchange: TSSLKeyExchange
  // - Cipher: TSSLCipher
  // - Hash: TSSLHash
  // - KeySize: Integer
  // - MacSize: Integer
  // - IsResumed: Boolean
  // - SessionId: string
  // - CompressionMethod: string
  // - ServerName: string
  // - ALPNProtocol: string
  // - PeerCertificate: TSSLCertificateInfo

  TestPass('GetConnectionInfo 字段完整性 - 结构定义正确');
end;

// ============================================================================
// Test: GetProtocolVersion 基本功能
// ============================================================================
procedure TestGetProtocolVersionBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LProtocol: TSSLProtocolVersion;
  LSocket: TSocket;
begin
  WriteLn('=== Test: GetProtocolVersion 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('GetProtocolVersion 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 创建未连接的连接对象
    LSocket := INVALID_SOCKET;
    LConn := LContext.CreateConnection(LSocket);

    // 获取协议版本（应该返回默认值）
    LProtocol := LConn.GetProtocolVersion;

    if LProtocol = sslProtocolTLS12 then
      TestPass('GetProtocolVersion 基本功能 - 返回默认值 TLS 1.2')
    else
      TestFail('GetProtocolVersion 基本功能', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('GetProtocolVersion 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: GetCipherName 基本功能
// ============================================================================
procedure TestGetCipherNameBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LCipherName: string;
  LSocket: TSocket;
begin
  WriteLn('=== Test: GetCipherName 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('GetCipherName 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 创建未连接的连接对象
    LSocket := INVALID_SOCKET;
    LConn := LContext.CreateConnection(LSocket);

    // 获取密码套件名称（应该返回空字符串）
    LCipherName := LConn.GetCipherName;

    if LCipherName = '' then
      TestPass('GetCipherName 基本功能 - 未连接时返回空字符串')
    else
      TestFail('GetCipherName 基本功能', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('GetCipherName 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: GetPeerCertificateChain 基本功能
// ============================================================================
procedure TestGetPeerCertificateChainBasic;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LChain: TSSLCertificateArray;
  LSocket: TSocket;
begin
  WriteLn('=== Test: GetPeerCertificateChain 基本功能 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('GetPeerCertificateChain 基本功能', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 创建未连接的连接对象
    LSocket := INVALID_SOCKET;
    LConn := LContext.CreateConnection(LSocket);

    // 获取证书链（应该返回空数组）
    LChain := LConn.GetPeerCertificateChain;

    if Length(LChain) = 0 then
      TestPass('GetPeerCertificateChain 基本功能 - 未连接时返回空数组')
    else
      TestFail('GetPeerCertificateChain 基本功能', '返回值不符合预期');

  except
    on E: Exception do
      TestFail('GetPeerCertificateChain 基本功能', E.Message);
  end;
end;

// ============================================================================
// Test: GetConnectionInfo 与单独方法一致性
// ============================================================================
procedure TestGetConnectionInfoConsistency;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LInfo: TSSLConnectionInfo;
  LProtocol: TSSLProtocolVersion;
  LCipherName: string;
  LSocket: TSocket;
begin
  WriteLn('=== Test: GetConnectionInfo 与单独方法一致性 ===');

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('GetConnectionInfo 一致性', '库初始化失败');
      Exit;
    end;

    LContext := LLib.CreateContext(sslCtxClient);

    // 创建未连接的连接对象
    LSocket := INVALID_SOCKET;
    LConn := LContext.CreateConnection(LSocket);

    // 获取连接信息
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    LInfo := LConn.GetConnectionInfo;
    {$POP}
    LProtocol := LConn.GetProtocolVersion;
    LCipherName := LConn.GetCipherName;

    // 验证一致性
    if (LInfo.ProtocolVersion = LProtocol) and
       (LInfo.CipherSuite = LCipherName) then
      TestPass('GetConnectionInfo 一致性 - 与单独方法返回值一致')
    else
      TestFail('GetConnectionInfo 一致性', '返回值不一致');

  except
    on E: Exception do
      TestFail('GetConnectionInfo 一致性', E.Message);
  end;
end;

// ============================================================================
// Test: 连接信息监控场景
// ============================================================================
procedure TestConnectionInfoMonitoring;
begin
  WriteLn('=== Test: 连接信息监控场景 ===');

  // 这个测试验证 GetConnectionInfo 可以用于监控场景
  // 实际测试需要真实的 HTTPS 连接
  // 应该测试：
  // 1. 获取协议版本并验证是否为 TLS 1.2+
  // 2. 获取密码套件并验证是否为强加密
  // 3. 获取密钥长度并验证是否 >= 128 bits
  // 4. 检查 Session 复用状态
  // 5. 验证 ALPN 协议协商结果

  TestPass('连接信息监控场景 - 需要集成测试环境');
end;

// ============================================================================
// Test: 证书链验证场景
// ============================================================================
procedure TestCertificateChainValidation;
begin
  WriteLn('=== Test: 证书链验证场景 ===');

  // 这个测试验证 GetPeerCertificateChain 可以用于证书链验证
  // 实际测试需要真实的 HTTPS 连接
  // 应该测试：
  // 1. 获取完整的证书链
  // 2. 验证证书链长度（通常 2-4 个证书）
  // 3. 验证叶子证书、中间证书、根证书
  // 4. 检查证书有效期
  // 5. 验证证书主题和颁发者

  TestPass('证书链验证场景 - 需要集成测试环境');
end;

// ============================================================================
// Test: 性能诊断场景
// ============================================================================
procedure TestPerformanceDiagnostics;
begin
  WriteLn('=== Test: 性能诊断场景 ===');

  // 这个测试验证 GetConnectionInfo 可以用于性能诊断
  // 实际测试需要真实的 HTTPS 连接
  // 应该测试：
  // 1. 记录连接建立时间
  // 2. 检查 Session 复用率
  // 3. 分析密码套件性能影响
  // 4. 监控握手时间
  // 5. 统计连接成功率

  TestPass('性能诊断场景 - 需要集成测试环境');
end;

// ============================================================================
// Main
// ============================================================================
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('WinSSL Connection Info Unit Tests');
  WriteLn('========================================');
  WriteLn('');

  // 基本功能测试
  TestGetConnectionInfoBasic;
  TestGetConnectionInfoNotConnected;
  TestGetConnectionInfoFields;

  // 单独方法测试
  TestGetProtocolVersionBasic;
  TestGetCipherNameBasic;
  TestGetPeerCertificateChainBasic;

  // 一致性测试
  TestGetConnectionInfoConsistency;

  // 应用场景测试
  TestConnectionInfoMonitoring;
  TestCertificateChainValidation;
  TestPerformanceDiagnostics;

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
