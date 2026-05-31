{**
 * 测试程序: Builder 自动后端选择集成测试（简化版）
 *
 * v1.3.0 Builder 集成
 *
 * 测试场景:
 * 1. WithSecurityFirst - 安全优先
 * 2. WithPerformanceFirst - 性能优先
 * 3. WithCompatibilityFirst - 兼容性优先
 * 4. RequireTLS13 - 要求 TLS 1.3
 * 5. WithBackend - 显式指定后端
 * 6. 链式调用组合
 *}

program test_builder_integration;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.backed;  // 注册 OpenSSL 后端

procedure TestSecurityFirst;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 1: WithSecurityFirst ===');

  try
    Ctx := TSSLContextBuilder.Create
      .WithSecurityFirst
      .WithVerifyPeer
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (安全优先)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestPerformanceFirst;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 2: WithPerformanceFirst ===');

  try
    Ctx := TSSLContextBuilder.Create
      .WithPerformanceFirst
      .WithVerifyPeer
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (性能优先)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestCompatibilityFirst;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 3: WithCompatibilityFirst ===');

  try
    Ctx := TSSLContextBuilder.Create
      .WithCompatibilityFirst
      .WithVerifyPeer
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (兼容性优先)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestRequireTLS13;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 4: RequireTLS13 ===');

  try
    Ctx := TSSLContextBuilder.Create
      .RequireTLS13
      .WithVerifyPeer
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (要求 TLS 1.3)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestExplicitBackend;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 5: WithBackend (显式指定 OpenSSL) ===');

  try
    Ctx := TSSLContextBuilder.Create
      .WithBackend(sslOpenSSL)
      .WithVerifyPeer
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (显式 OpenSSL)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestChaining;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 6: 链式调用组合 ===');

  try
    Ctx := TSSLContextBuilder.Create
      .RequireTLS13
      .RequireCipher(sslCipherCHACHA20_POLY1305)
      .PreferOSNative
      .WithVerifyPeer
      .WithSystemRoots
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (链式调用)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestServerContext;
var
  Ctx: ISSLContext;
  LCertPEM, LKeyPEM: string;
begin
  WriteLn('=== 测试 7: 服务器上下文 (性能优先) ===');

  try
    if not TCertificateUtils.TryGenerateSelfSignedSimple(
      'builder-server.local',
      'Builder Integration Test',
      30,
      LCertPEM,
      LKeyPEM
    ) then
    begin
      WriteLn('❌ 失败: 无法生成测试证书');
      WriteLn;
      Exit;
    end;

    Ctx := TSSLContextBuilder.Create
      .WithPerformanceFirst
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .BuildServer;

    if Ctx <> nil then
      WriteLn('✅ 成功创建服务器上下文')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

procedure TestPKCS11Requirement;
var
  Ctx: ISSLContext;
begin
  WriteLn('=== 测试 8: RequirePKCS11Support ===');

  try
    Ctx := TSSLContextBuilder.Create
      .RequirePKCS11Support
      .WithVerifyPeer
      .BuildClient;

    if Ctx <> nil then
      WriteLn('✅ 成功创建上下文 (要求 PKCS#11)')
    else
      WriteLn('❌ 失败: 返回 nil');
  except
    on E: Exception do
      WriteLn('❌ 失败: ', E.Message);
  end;

  WriteLn;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║  Builder 自动后端选择集成测试 (v1.3.0)                    ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    TestSecurityFirst;
    TestPerformanceFirst;
    TestCompatibilityFirst;
    TestRequireTLS13;
    TestExplicitBackend;
    TestChaining;
    TestServerContext;
    TestPKCS11Requirement;

    WriteLn('════════════════════════════════════════════════════════════');
    WriteLn('✅ 所有测试完成');
    WriteLn('════════════════════════════════════════════════════════════');
  except
    on E: Exception do
    begin
      WriteLn('❌ 测试失败: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
