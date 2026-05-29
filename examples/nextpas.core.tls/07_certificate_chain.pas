program certificate_chain;

{$mode objfpc}{$H+}

{ ============================================================================
  示例 7: 证书链验证（概念演示）
  
  功能：演示证书链的概念和验证流程
  用途：理解 X.509 证书链、信任锚点和证书验证
  
  证书链结构：
    Root CA (根证书颁发机构)
      ↓
    Intermediate CA (中间证书颁发机构)
      ↓
    End-Entity Certificate (最终实体证书 / 服务器证书)
  
  编译：fpc -Fusrc -Fusrc/openssl 07_certificate_chain.pas
  运行：07_certificate_chain
  ============================================================================ }

uses
  SysUtils,
  fafafa.ssl;

procedure ExplainCertificateChain;
begin
  WriteLn('[1/4] 证书链的概念');
  WriteLn;
  WriteLn('  什么是证书链？');
  WriteLn('  ═══════════════════════════════════════════════════════════════');
  WriteLn('  证书链是一系列数字证书的层级结构，用于验证身份的可信度。');
  WriteLn;
  WriteLn('  典型的证书链结构：');
  WriteLn;
  WriteLn('    ┌─────────────────────────────┐');
  WriteLn('    │  Root CA 根证书颁发机构       │  ← 自签名，被操作系统信任');
  WriteLn('    │  (例如: DigiCert Root CA)    │');
  WriteLn('    └──────────────┬──────────────┘');
  WriteLn('                   │ 签名');
  WriteLn('                   ↓');
  WriteLn('    ┌─────────────────────────────┐');
  WriteLn('    │  Intermediate CA 中间 CA     │  ← 由 Root CA 签名');
  WriteLn('    │  (例如: DigiCert TLS CA)     │');
  WriteLn('    └──────────────┬──────────────┘');
  WriteLn('                   │ 签名');
  WriteLn('                   ↓');
  WriteLn('    ┌─────────────────────────────┐');
  WriteLn('    │  End-Entity Certificate     │  ← 由 Intermediate CA 签名');
  WriteLn('    │  (例如: www.example.com)    │     这是服务器使用的证书');
  WriteLn('    └─────────────────────────────┘');
  WriteLn;
  WriteLn('  ═══════════════════════════════════════════════════════════════');
  WriteLn;
end;

procedure ExplainTrustAnchor;
begin
  WriteLn('[2/4] 信任锚点（Trust Anchor）');
  WriteLn;
  WriteLn('  什么是信任锚点？');
  WriteLn('  ─────────────────────────────────────────────────────────────');
  WriteLn('  信任锚点是证书链验证的起点，通常是 Root CA 证书。');
  WriteLn;
  WriteLn('  操作系统预装的根证书存储位置：');
  WriteLn;
  WriteLn('    Windows:');
  WriteLn('      - 证书管理器: certmgr.msc');
  WriteLn('      - 受信任的根证书颁发机构');
  WriteLn('      - 通常有 100+ 个预装的根证书');
  WriteLn;
  WriteLn('    Linux:');
  WriteLn('      - /etc/ssl/certs/ca-certificates.crt');
  WriteLn('      - /etc/ssl/certs/ 目录');
  WriteLn('      - 由 ca-certificates 包管理');
  WriteLn;
  WriteLn('    macOS:');
  WriteLn('      - Keychain Access 钥匙串访问');
  WriteLn('      - 系统根证书');
  WriteLn;
  WriteLn('  ─────────────────────────────────────────────────────────────');
  WriteLn;
end;

procedure ExplainVerificationProcess;
begin
  WriteLn('[3/4] 证书验证流程');
  WriteLn;
  WriteLn('  如何验证证书链？');
  WriteLn('  ═══════════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('  步骤 1: 获取服务器证书');
  WriteLn('    - 客户端连接到服务器（例如 https://www.example.com）');
  WriteLn('    - 服务器发送其证书和中间证书链');
  WriteLn;
  WriteLn('  步骤 2: 构建证书链');
  WriteLn('    - 从服务器证书开始');
  WriteLn('    - 找到签名此证书的中间 CA');
  WriteLn('    - 继续向上，直到找到根 CA');
  WriteLn;
  WriteLn('  步骤 3: 验证每个证书');
  WriteLn('    - ✓ 签名验证：使用上级证书的公钥验证签名');
  WriteLn('    - ✓ 有效期检查：证书是否在有效期内');
  WriteLn('    - ✓ 吊销检查：证书是否被吊销 (CRL/OCSP)');
  WriteLn('    - ✓ 用途检查：证书用途是否匹配（服务器认证）');
  WriteLn('    - ✓ 主机名验证：证书主题是否匹配域名');
  WriteLn;
  WriteLn('  步骤 4: 信任验证');
  WriteLn('    - 根 CA 是否在信任存储中？');
  WriteLn('    - 如果是 → 验证通过 ✓');
  WriteLn('    - 如果否 → 验证失败 ✗');
  WriteLn;
  WriteLn('  ═══════════════════════════════════════════════════════════════');
  WriteLn;
end;

procedure DemonstrateWithFafafaSSL;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  WriteLn('[4/4] 使用 fafafa.ssl 进行证书验证');
  WriteLn;
  
  // 初始化 SSL 库
  WriteLn('  1. 初始化 SSL 库...');
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not LLib.Initialize then
  begin
    WriteLn('     ✗ 无法初始化 SSL 库');
    Exit;
  end;
  
  WriteLn('     ✓ SSL 库初始化成功');
  WriteLn('     版本: ', LLib.GetVersionString);
  WriteLn;
  
  try
    // 创建 SSL 上下文
    WriteLn('  2. 创建 SSL 上下文...');
    LContext := LLib.CreateContext(sslCtxClient);
    WriteLn('     ✓ 上下文创建成功');
    WriteLn;
    
    // 配置证书验证
    WriteLn('  3. 配置证书验证参数...');
    LContext.SetVerifyMode([sslVerifyPeer]);  // 启用对端验证
    WriteLn('     ✓ 启用对端证书验证');
    WriteLn('     ✓ 自动加载系统根证书存储');
    WriteLn;
    
    // 设置验证深度
    WriteLn('  4. 设置证书链验证深度...');
    LContext.SetVerifyDepth(10);  // 最多验证 10 级证书链
    WriteLn('     ✓ 验证深度: 10 级');
    WriteLn('     (大多数证书链深度为 2-3 级)');
    WriteLn;
    
    WriteLn('  5. 准备就绪！');
    WriteLn;
    WriteLn('     此 SSL 上下文已配置好证书验证功能。');
    WriteLn('     当建立 TLS 连接时，fafafa.ssl 将自动：');
    WriteLn('       • 获取服务器证书和中间证书');
    WriteLn('       • 构建完整的证书链');
    WriteLn('       • 验证每个证书的签名');
    WriteLn('       • 检查证书有效期');
    WriteLn('       • 验证主机名匹配');
    WriteLn('       • 确认根 CA 在信任存储中');
    WriteLn;
    
  finally
    LLib.Finalize;
  end;
end;

procedure ExplainCommonIssues;
begin
  WriteLn('════════════════════════════════════════════════════════════════════');
  WriteLn('  ⚠️ 常见证书验证问题');
  WriteLn('════════════════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('  问题 1: 证书过期');
  WriteLn('    现象: "certificate has expired"');
  WriteLn('    原因: 证书已超过有效期');
  WriteLn('    解决: 服务器需要续期证书');
  WriteLn;
  WriteLn('  问题 2: 自签名证书');
  WriteLn('    现象: "self signed certificate"');
  WriteLn('    原因: 证书由自己签名，不在信任存储中');
  WriteLn('    解决: 将根证书添加到信任存储，或仅用于开发环境');
  WriteLn;
  WriteLn('  问题 3: 主机名不匹配');
  WriteLn('    现象: "Hostname mismatch"');
  WriteLn('    原因: 证书的 CN/SAN 与实际域名不符');
  WriteLn('    解决: 使用正确的域名，或为所有域名申请证书');
  WriteLn;
  WriteLn('  问题 4: 中间证书缺失');
  WriteLn('    现象: "unable to get local issuer certificate"');
  WriteLn('    原因: 服务器未发送完整的证书链');
  WriteLn('    解决: 服务器配置需包含中间证书');
  WriteLn;
  WriteLn('  问题 5: 根证书不受信任');
  WriteLn('    现象: "certificate verify failed"');
  WriteLn('    原因: 根 CA 不在系统信任存储中');
  WriteLn('    解决: 更新系统根证书，或手动添加');
  WriteLn;
  WriteLn('════════════════════════════════════════════════════════════════════');
  WriteLn;
end;

begin
  WriteLn('================================================================================');
  WriteLn('  示例 7: 证书链验证（概念演示）');
  WriteLn('  理解 X.509 证书链和验证流程');
  WriteLn('================================================================================');
  WriteLn;
  
  try
    ExplainCertificateChain;
    ExplainTrustAnchor;
    ExplainVerificationProcess;
    DemonstrateWithFafafaSSL;
    ExplainCommonIssues;
    
    WriteLn('================================================================================');
    WriteLn('  ✓ 示例执行完成！');
    WriteLn('================================================================================');
    WriteLn;
    WriteLn('💡 学到的知识：');
    WriteLn('  1. 证书链的层级结构（Root CA → Intermediate CA → End-Entity）');
    WriteLn('  2. 信任锚点的概念和位置');
    WriteLn('  3. 证书验证的完整流程');
    WriteLn('  4. 如何使用 fafafa.ssl 配置证书验证');
    WriteLn('  5. 常见证书问题的诊断和解决');
    WriteLn;
    WriteLn('🔒 安全最佳实践：');
    WriteLn('  - 始终启用证书验证（sslVerifyPeer）');
    WriteLn('  - 定期更新系统根证书存储');
    WriteLn('  - 服务器应发送完整的证书链');
    WriteLn('  - 使用受信任 CA 颁发的证书');
    WriteLn('  - 监控证书过期时间，提前续期');
    WriteLn;
    WriteLn('📚 下一步：');
    WriteLn('  - 查看示例 1: TLS 客户端 (01_tls_client.pas) - 包含实际证书验证');
    WriteLn('  - 查看示例 2: 证书生成 (02_generate_certificate.pas)');
    WriteLn('  - 阅读 docs/SECURITY_GUIDE.md 了解证书安全');
    WriteLn;
    
    ExitCode := 0;
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('================================================================================');
      WriteLn('  ✗ 错误: ', E.Message);
      WriteLn('================================================================================');
      WriteLn;
      ExitCode := 1;
    end;
  end;
end.
