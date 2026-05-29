program mutual_tls;

{$mode objfpc}{$H+}

{ ============================================================================
  示例 8: 双向 TLS 认证（mTLS）
  
  功能：演示如何配置和理解双向 TLS 认证
  用途：学习 mTLS 的概念、配置和应用场景
  
  什么是 mTLS？
    传统 TLS：只有服务器需要证书，客户端验证服务器
    双向 TLS：客户端和服务器都需要证书，互相验证
  
  应用场景：
    - 微服务之间的安全通信
    - API 网关认证
    - 零信任网络架构
    - 企业内部服务
    - IoT 设备认证
  
  编译：fpc -Fusrc -Fusrc/openssl 08_mutual_tls.pas
  运行：08_mutual_tls
  ============================================================================ }

uses
  SysUtils,
  fafafa.ssl;

{ 解释 mTLS 的概念 }
procedure ExplainMutualTLS;
begin
  WriteLn('================================================================================');
  WriteLn('  示例 8: 双向 TLS 认证（mTLS）');
  WriteLn('  理解和配置双向认证');
  WriteLn('================================================================================');
  WriteLn;
  
  WriteLn('[1/4] 什么是双向 TLS (mTLS)？');
  WriteLn;
  WriteLn('  传统 TLS (单向认证)：');
  WriteLn('  ┌─────────┐                    ┌─────────┐');
  WriteLn('  │ 客户端  │ ──── 验证服务器 ──→│ 服务器  │');
  WriteLn('  │ (浏览器)│                    │ (网站)  │');
  WriteLn('  │ 无证书  │                    │ 有证书  │');
  WriteLn('  └─────────┘                    └─────────┘');
  WriteLn;
  WriteLn('  • 只有服务器提供证书');
  WriteLn('  • 客户端验证服务器身份');
  WriteLn('  • 用于公开网站（HTTPS）');
  WriteLn;
  WriteLn('  双向 TLS (mTLS)：');
  WriteLn('  ┌─────────┐                    ┌─────────┐');
  WriteLn('  │ 客户端  │ ←─ 互相验证身份 ─→│ 服务器  │');
  WriteLn('  │ (API)   │                    │ (API)   │');
  WriteLn('  │ 有证书  │                    │ 有证书  │');
  WriteLn('  └─────────┘                    └─────────┘');
  WriteLn;
  WriteLn('  • 客户端和服务器都提供证书');
  WriteLn('  • 双方互相验证身份');
  WriteLn('  • 用于内部服务、API、微服务');
  WriteLn;
end;

{ 演示 mTLS 握手流程 }
procedure ExplainHandshakeProcess;
begin
  WriteLn('[2/4] mTLS 握手流程');
  WriteLn;
  WriteLn('  步骤 1: ClientHello');
  WriteLn('    客户端 → 服务器');
  WriteLn('    • 支持的 TLS 版本');
  WriteLn('    • 支持的加密套件');
  WriteLn('    • 随机数');
  WriteLn;
  WriteLn('  步骤 2: ServerHello + 服务器证书');
  WriteLn('    服务器 → 客户端');
  WriteLn('    • 选择的 TLS 版本和加密套件');
  WriteLn('    • 服务器证书');
  WriteLn('    • 请求客户端证书 ← mTLS 关键！');
  WriteLn;
  WriteLn('  步骤 3: 客户端证书验证');
  WriteLn('    客户端 ↔ 服务器');
  WriteLn('    • 客户端验证服务器证书');
  WriteLn('    • 服务器验证客户端证书 ← mTLS 关键！');
  WriteLn;
  WriteLn('  步骤 4: 完成握手');
  WriteLn('    • 交换密钥');
  WriteLn('    • 建立加密通道');
  WriteLn('    • 开始安全通信');
  WriteLn;
end;

{ 演示如何配置 mTLS }
procedure DemonstrateConfiguration;
var
  LLib: ISSLLibrary;
  LServerCtx, LClientCtx: ISSLContext;
begin
  WriteLn('[3/4] 配置 mTLS');
  WriteLn;
  
  // 初始化 SSL 库
  WriteLn('  正在初始化 SSL 库...');
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not LLib.Initialize then
  begin
    WriteLn('  ✗ 无法初始化 SSL 库');
    Exit;
  end;
  
  WriteLn('  ✓ SSL 库初始化成功');
  WriteLn('  版本: ', LLib.GetVersionString);
  WriteLn;
  
  try
    // 配置服务器端 mTLS
    WriteLn('  A. 服务器端配置');
    WriteLn('  ──────────────────────────────────────');
    WriteLn;
    
    LServerCtx := LLib.CreateContext(sslCtxServer);
    WriteLn('  1. 加载服务器证书和私钥');
    WriteLn('     LServerCtx.LoadCertificate(''server.crt'');');
    WriteLn('     LServerCtx.LoadPrivateKey(''server.key'');');
    WriteLn;
    
    WriteLn('  2. 配置验证模式 - 要求客户端证书');
    // 设置验证模式：要求对端证书，验证失败则拒绝连接
    LServerCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);
    WriteLn('     LServerCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);');
    WriteLn('     ✓ 配置完成：服务器将要求并验证客户端证书');
    WriteLn;
    
    WriteLn('  3. 加载客户端 CA 证书（用于验证客户端）');
    WriteLn('     LServerCtx.LoadVerifyLocations(''client-ca.crt'');');
    WriteLn('     ✓ 服务器将使用此 CA 验证客户端证书');
    WriteLn;
    
    // 配置客户端 mTLS
    WriteLn;
    WriteLn('  B. 客户端配置');
    WriteLn('  ──────────────────────────────────────');
    WriteLn;
    
    LClientCtx := LLib.CreateContext(sslCtxClient);
    WriteLn('  1. 加载客户端证书和私钥');
    WriteLn('     LClientCtx.LoadCertificate(''client.crt'');');
    WriteLn('     LClientCtx.LoadPrivateKey(''client.key'');');
    WriteLn;
    
    WriteLn('  2. 配置验证模式 - 验证服务器证书');
    LClientCtx.SetVerifyMode([sslVerifyPeer]);
    WriteLn('     LClientCtx.SetVerifyMode([sslVerifyPeer]);');
    WriteLn('     ✓ 配置完成：客户端将验证服务器证书');
    WriteLn;
    
    WriteLn('  3. 加载服务器 CA 证书（用于验证服务器）');
    WriteLn('     LClientCtx.LoadVerifyLocations(''server-ca.crt'');');
    WriteLn('     ✓ 客户端将使用此 CA 验证服务器证书');
    WriteLn;
    
    WriteLn('  ✓ mTLS 配置完成！');
    WriteLn;
    
  finally
    LLib.Finalize;
  end;
end;

{ 说明实际应用场景 }
procedure ExplainUseCases;
begin
  WriteLn('[4/4] 实际应用场景');
  WriteLn;
  
  WriteLn('  场景 1: 微服务架构');
  WriteLn('  ──────────────────────────────────────');
  WriteLn('  问题：如何确保微服务之间的通信安全？');
  WriteLn('  解决：使用 mTLS 为每个服务颁发证书');
  WriteLn;
  WriteLn('  示例：');
  WriteLn('    [订单服务] ←─ mTLS ─→ [支付服务]');
  WriteLn('    [订单服务] ←─ mTLS ─→ [库存服务]');
  WriteLn('    [支付服务] ←─ mTLS ─→ [通知服务]');
  WriteLn;
  WriteLn('  优势：');
  WriteLn('    • 每个服务都有唯一身份');
  WriteLn('    • 防止未授权服务访问');
  WriteLn('    • 加密传输数据');
  WriteLn;
  
  WriteLn('  场景 2: API 网关');
  WriteLn('  ──────────────────────────────────────');
  WriteLn('  问题：如何验证 API 调用者的身份？');
  WriteLn('  解决：要求客户端提供证书');
  WriteLn;
  WriteLn('  示例：');
  WriteLn('    [移动 App] ─ 客户端证书 ─→ [API 网关]');
  WriteLn('    [Web App]  ─ 客户端证书 ─→ [API 网关]');
  WriteLn('    [合作伙伴] ─ 客户端证书 ─→ [API 网关]');
  WriteLn;
  WriteLn('  优势：');
  WriteLn('    • 比 API Key 更安全');
  WriteLn('    • 无法伪造证书');
  WriteLn('    • 支持证书吊销');
  WriteLn;
  
  WriteLn('  场景 3: IoT 设备认证');
  WriteLn('  ──────────────────────────────────────');
  WriteLn('  问题：如何确保只有授权设备可以连接？');
  WriteLn('  解决：为每个设备颁发唯一证书');
  WriteLn;
  WriteLn('  示例：');
  WriteLn('    [智能门锁] ─ 设备证书 ─→ [云平台]');
  WriteLn('    [温度传感器] ─ 设备证书 ─→ [云平台]');
  WriteLn('    [摄像头] ─ 设备证书 ─→ [云平台]');
  WriteLn;
  WriteLn('  优势：');
  WriteLn('    • 设备身份唯一');
  WriteLn('    • 防止设备伪造');
  WriteLn('    • 支持设备管理');
  WriteLn;
  
  WriteLn('  场景 4: 零信任网络');
  WriteLn('  ──────────────────────────────────────');
  WriteLn('  问题：如何实现"永不信任，始终验证"？');
  WriteLn('  解决：所有连接都使用 mTLS');
  WriteLn;
  WriteLn('  原则：');
  WriteLn('    • 不信任网络位置');
  WriteLn('    • 验证所有连接');
  WriteLn('    • 最小权限访问');
  WriteLn;
  WriteLn('  优势：');
  WriteLn('    • 即使内网也需要认证');
  WriteLn('    • 防止横向移动');
  WriteLn('    • 提高整体安全性');
  WriteLn;
end;

{ 总结和最佳实践 }
procedure ShowSummary;
begin
  WriteLn('================================================================================');
  WriteLn('  ✓ 示例执行完成！');
  WriteLn('================================================================================');
  WriteLn;
  
  WriteLn('💡 关键要点：');
  WriteLn('  1. mTLS = 双向 TLS = 客户端和服务器都需要证书');
  WriteLn('  2. 服务器验证客户端身份，客户端验证服务器身份');
  WriteLn('  3. 比单向 TLS 更安全，适合内部服务');
  WriteLn('  4. 需要管理更多证书（CA、服务器、客户端）');
  WriteLn;
  
  WriteLn('🔒 mTLS vs 其他认证方式：');
  WriteLn;
  WriteLn('  认证方式          安全性    复杂度    适用场景');
  WriteLn('  ─────────────────────────────────────────────');
  WriteLn('  密码认证          低        低        用户登录');
  WriteLn('  API Key           中        低        公开 API');
  WriteLn('  OAuth 2.0         中        中        第三方授权');
  WriteLn('  JWT               中        中        无状态认证');
  WriteLn('  mTLS              高        高        服务间通信 ⭐');
  WriteLn;
  
  WriteLn('📚 证书管理最佳实践：');
  WriteLn('  1. 使用私有 CA 颁发内部证书');
  WriteLn('  2. 设置合理的证书有效期（90天推荐）');
  WriteLn('  3. 实现证书自动轮换');
  WriteLn('  4. 建立证书吊销机制（CRL/OCSP）');
  WriteLn('  5. 安全存储私钥（HSM/密钥管理服务）');
  WriteLn('  6. 监控证书过期时间');
  WriteLn('  7. 为不同环境使用不同的 CA');
  WriteLn;
  
  WriteLn('⚙️ fafafa.ssl 中的 mTLS 配置：');
  WriteLn;
  WriteLn('  // 服务器端');
  WriteLn('  LServerCtx := LLib.CreateContext(sslCtxServer);');
  WriteLn('  LServerCtx.LoadCertificate(''server.crt'');');
  WriteLn('  LServerCtx.LoadPrivateKey(''server.key'');');
  WriteLn('  LServerCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);');
  WriteLn('  LServerCtx.LoadVerifyLocations(''client-ca.crt'');');
  WriteLn;
  WriteLn('  // 客户端');
  WriteLn('  LClientCtx := LLib.CreateContext(sslCtxClient);');
  WriteLn('  LClientCtx.LoadCertificate(''client.crt'');');
  WriteLn('  LClientCtx.LoadPrivateKey(''client.key'');');
  WriteLn('  LClientCtx.SetVerifyMode([sslVerifyPeer]);');
  WriteLn('  LClientCtx.LoadVerifyLocations(''server-ca.crt'');');
  WriteLn;
  
  WriteLn('🔗 相关资源：');
  WriteLn('  - 示例 02: 证书生成（生成测试证书）');
  WriteLn('  - 示例 06: 数字签名（理解证书签名）');
  WriteLn('  - 示例 07: 证书链验证（理解证书验证）');
  WriteLn('  - RFC 8446: TLS 1.3 规范');
  WriteLn('  - RFC 5280: X.509 证书规范');
  WriteLn;
  
  WriteLn('⚠️ 常见问题：');
  WriteLn('  Q: mTLS 会影响性能吗？');
  WriteLn('  A: 握手时稍慢（增加证书验证），但数据传输性能相同。');
  WriteLn('     可以使用 TLS 会话复用减少握手开销。');
  WriteLn;
  WriteLn('  Q: 如何管理大量客户端证书？');
  WriteLn('  A: 使用自动化工具（如 cert-manager、Vault）管理证书生命周期。');
  WriteLn;
  WriteLn('  Q: 客户端证书丢失怎么办？');
  WriteLn('  A: 立即吊销旧证书，重新颁发新证书。这就是为什么需要 CRL/OCSP。');
  WriteLn;
  WriteLn('  Q: 可以混合使用 mTLS 和其他认证吗？');
  WriteLn('  A: 可以！mTLS 用于传输层安全，应用层可以添加额外认证（如 JWT）。');
  WriteLn;
end;

begin
  try
    ExplainMutualTLS;
    ExplainHandshakeProcess;
    DemonstrateConfiguration;
    ExplainUseCases;
    ShowSummary;
    
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
