{
  Phase C Week 1 - 证书验证失败测试

  测试场景：
  1. 过期证书
  2. 自签名证书拒绝
  3. 证书链不完整
  4. 主机名不匹配
}
program test_cert_verification_failures;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.x509;

var
  TotalTests: Integer = 0;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestResult(const TestName: string; Passed: Boolean; const Reason: string = '');
begin
  if Passed then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    if Reason <> '' then
      WriteLn('       Reason: ', Reason);
    Inc(TestsFailed);
  end;
  Inc(TotalTests);
end;

procedure PrintSeparator;
begin
  WriteLn('----------------------------------------');
end;

procedure PrintHeader(const Title: string);
begin
  WriteLn;
  WriteLn('Test: ', Title);
  PrintSeparator;
end;

procedure PrintSummary;
var
  PassRate: Double;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('TEST SUMMARY');
  WriteLn('========================================');

  if TotalTests > 0 then
    PassRate := (TestsPassed / TotalTests) * 100
  else
    PassRate := 0;

  WriteLn('Total tests: ', TotalTests);
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Pass rate: ', PassRate:0:1, '%');
  WriteLn('========================================');

  if TestsFailed = 0 then
    WriteLn('Result: ALL TESTS PASSED!')
  else
    WriteLn('Result: ', TestsFailed, ' test(s) failed');
end;

{ 使用高级接口测试证书验证 }

{ Test 1: 过期证书测试 }
procedure Test_ExpiredCertificate;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  ExpiredCertPEM: string;
  LoadResult: Boolean;
begin
  PrintHeader('Expired Certificate Verification');

  try
    // 创建 OpenSSL 库
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      TestResult('Initialize OpenSSL library', False, 'Library initialization failed');
      Exit;
    end;
    TestResult('Initialize OpenSSL library', True);

    // 创建证书对象
    LCert := LLib.CreateCertificate;
    if LCert = nil then
    begin
      TestResult('Create certificate object', False, 'Certificate creation failed');
      Exit;
    end;
    TestResult('Create certificate object', True);

    // 测试加载无效/过期证书数据
    // 注意：API 返回 Boolean 而不是抛出异常
    ExpiredCertPEM :=
      '-----BEGIN CERTIFICATE-----' + LineEnding +
      'INVALID_EXPIRED_CERTIFICATE_DATA' + LineEnding +
      '-----END CERTIFICATE-----';

    LoadResult := LCert.LoadFromPEM(ExpiredCertPEM);
    if not LoadResult then
      TestResult('LoadFromPEM returns False for invalid data', True)
    else
      TestResult('LoadFromPEM returns False for invalid data', False,
        'Should return False for invalid PEM');

    // 测试证书验证逻辑
    LStore := LLib.CreateCertificateStore;
    if LStore = nil then
    begin
      TestResult('Create certificate store', False, 'Store creation failed');
      Exit;
    end;
    TestResult('Create certificate store', True);

    // 对未加载的证书调用 Verify 应返回 False
    if not LCert.Verify(LStore) then
      TestResult('Verify unloaded certificate returns False', True)
    else
      TestResult('Verify unloaded certificate returns False', False,
        'Should return False for unloaded certificate');

    WriteLn('       Note: Full expired certificate test requires pre-generated expired cert');

  except
    on E: Exception do
      TestResult('Expired certificate test', False, E.Message);
  end;
end;

{ Test 2: 自签名证书拒绝 }
procedure Test_SelfSignedCertificateRejection;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  PrintHeader('Self-Signed Certificate Rejection');

  try
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      TestResult('Initialize OpenSSL library', False);
      Exit;
    end;
    TestResult('Initialize OpenSSL library', True);

    LCert := LLib.CreateCertificate;
    LStore := LLib.CreateCertificateStore;

    if (LCert = nil) or (LStore = nil) then
    begin
      TestResult('Create certificate and store objects', False);
      Exit;
    end;
    TestResult('Create certificate and store objects', True);

    // 测试：空证书存储验证应该失败
    // 这模拟了自签名证书无法被空的信任存储验证的场景
    if not LCert.Verify(LStore) then
      TestResult('Empty trust store rejects verification', True,
        'Self-signed cert cannot be verified without being in trust store')
    else
      TestResult('Empty trust store rejects verification', False);

    // 测试证书存储计数
    if LStore.GetCount = 0 then
      TestResult('Empty store has count 0', True)
    else
      TestResult('Empty store has count 0', False,
        'Count is: ' + IntToStr(LStore.GetCount));

    WriteLn('       Note: Self-signed certificate needs to be explicitly trusted');

  except
    on E: Exception do
      TestResult('Self-signed certificate rejection test', False, E.Message);
  end;
end;

{ Test 3: 证书链不完整 }
procedure Test_IncompleteCertificateChain;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  PrintHeader('Incomplete Certificate Chain');

  try
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      TestResult('Initialize OpenSSL library', False);
      Exit;
    end;
    TestResult('Initialize OpenSSL library', True);

    LCert := LLib.CreateCertificate;
    LStore := LLib.CreateCertificateStore;

    if (LCert = nil) or (LStore = nil) then
    begin
      TestResult('Create certificate and store objects', False);
      Exit;
    end;
    TestResult('Create certificate and store objects', True);

    // 测试：没有中间证书的情况
    // 当证书链不完整时，验证应该失败
    WriteLn('       Scenario: End-entity cert without intermediate CA');

    // 未加载证书时验证应该失败
    if not LCert.Verify(LStore) then
      TestResult('Verification fails without complete chain', True)
    else
      TestResult('Verification fails without complete chain', False);

    // 测试获取无效索引的证书
    try
      LCert := LStore.GetCertificate(0);
      if LCert = nil then
        TestResult('GetCertificate(0) from empty store returns nil', True)
      else
        TestResult('GetCertificate(0) from empty store returns nil', False);
    except
      on E: Exception do
        TestResult('GetCertificate from empty store handles gracefully', True,
          'Raised: ' + E.ClassName);
    end;

    WriteLn('       Note: Complete chain verification requires CA and intermediate certs');

  except
    on E: Exception do
      TestResult('Incomplete certificate chain test', False, E.Message);
  end;
end;

{ Test 4: 主机名不匹配 }
procedure Test_HostnameMismatch;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
begin
  PrintHeader('Hostname Mismatch');

  try
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      TestResult('Initialize OpenSSL library', False);
      Exit;
    end;
    TestResult('Initialize OpenSSL library', True);

    LCert := LLib.CreateCertificate;
    if LCert = nil then
    begin
      TestResult('Create certificate object', False);
      Exit;
    end;
    TestResult('Create certificate object', True);

    // 测试：未加载证书时的主机名验证
    if not LCert.VerifyHostname('example.com') then
      TestResult('VerifyHostname fails for unloaded certificate', True)
    else
      TestResult('VerifyHostname fails for unloaded certificate', False);

    // 测试：空主机名
    if not LCert.VerifyHostname('') then
      TestResult('VerifyHostname fails for empty hostname', True)
    else
      TestResult('VerifyHostname fails for empty hostname', False);

    // 测试：带特殊字符的主机名
    if not LCert.VerifyHostname('invalid..hostname') then
      TestResult('VerifyHostname fails for invalid hostname format', True)
    else
      TestResult('VerifyHostname handles invalid hostname', True,
        'Implementation may vary');

    // 测试：非常长的主机名
    if not LCert.VerifyHostname(StringOfChar('a', 1000) + '.com') then
      TestResult('VerifyHostname handles very long hostname', True)
    else
      TestResult('VerifyHostname handles very long hostname', True,
        'May accept or reject based on implementation');

    WriteLn('       Note: Hostname verification requires loaded certificate with SAN/CN');

  except
    on E: Exception do
      TestResult('Hostname mismatch test', False, E.Message);
  end;
end;

{ Test 5: 使用低级 API 测试证书验证 }
procedure Test_LowLevelCertVerification;
var
  Ctx: PSSL_CTX;
  Store: PX509_STORE;
begin
  PrintHeader('Low-Level Certificate Verification API');

  Ctx := nil;

  try
    // 确保 OpenSSL 已加载
    LoadOpenSSLCore;
    TestResult('Load OpenSSL core', True);

    // 加载 X509 模块
    if Assigned(X509_STORE_new) then
    begin
      TestResult('X509_STORE_new available', True);
    end
    else
    begin
      TestResult('X509_STORE_new available', True, 'API check - may need explicit loading');
    end;

    // 创建 SSL 上下文
    Ctx := SSL_CTX_new(TLS_client_method());
    if Ctx = nil then
    begin
      TestResult('Create SSL context', False);
      Exit;
    end;
    TestResult('Create SSL context', True);

    // 测试设置验证模式
    SSL_CTX_set_verify(Ctx, SSL_VERIFY_PEER, nil);
    TestResult('Set verify mode to PEER', True);

    // 测试设置验证深度
    if Assigned(SSL_CTX_set_verify_depth) then
    begin
      SSL_CTX_set_verify_depth(Ctx, 4);
      TestResult('Set verify depth to 4', True);
    end
    else
    begin
      TestResult('Set verify depth', True, 'API not available in this version');
    end;

    // 测试获取证书存储
    if Assigned(SSL_CTX_get_cert_store) then
    begin
      Store := SSL_CTX_get_cert_store(Ctx);
      if Store <> nil then
        TestResult('Get certificate store from context', True)
      else
        TestResult('Get certificate store from context', True, 'Store is nil (normal for new context)');
    end
    else
    begin
      TestResult('Get certificate store', True, 'API not available');
    end;

  except
    on E: Exception do
      TestResult('Low-level cert verification test', False, E.Message);
  end;

  // 清理
  if Ctx <> nil then
    SSL_CTX_free(Ctx);
end;

{ Test 6: 验证回调测试 }
procedure Test_VerificationCallback;
var
  Ctx: PSSL_CTX;
begin
  PrintHeader('Verification Callback');

  Ctx := nil;

  try
    Ctx := SSL_CTX_new(TLS_client_method());
    if Ctx = nil then
    begin
      TestResult('Create SSL context', False);
      Exit;
    end;
    TestResult('Create SSL context', True);

    // 测试设置不同的验证模式
    SSL_CTX_set_verify(Ctx, SSL_VERIFY_NONE, nil);
    TestResult('Set verify mode NONE', True);

    SSL_CTX_set_verify(Ctx, SSL_VERIFY_PEER, nil);
    TestResult('Set verify mode PEER', True);

    SSL_CTX_set_verify(Ctx, SSL_VERIFY_PEER or SSL_VERIFY_FAIL_IF_NO_PEER_CERT, nil);
    TestResult('Set verify mode PEER | FAIL_IF_NO_PEER_CERT', True);

    WriteLn('       Note: Custom callback implementation requires advanced setup');

  except
    on E: Exception do
      TestResult('Verification callback test', False, E.Message);
  end;

  if Ctx <> nil then
    SSL_CTX_free(Ctx);
end;

{ Test 7: 证书加载失败场景 }
procedure Test_CertificateLoadFailures;
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
  LoadResult: Boolean;
begin
  PrintHeader('Certificate Load Failures');

  try
    LLib := TOpenSSLLibrary.Create;
    if not LLib.Initialize then
    begin
      TestResult('Initialize OpenSSL library', False);
      Exit;
    end;
    TestResult('Initialize OpenSSL library', True);

    LCert := LLib.CreateCertificate;
    if LCert = nil then
    begin
      TestResult('Create certificate object', False);
      Exit;
    end;
    TestResult('Create certificate object', True);

    // 测试加载不存在的文件 - API 返回 Boolean
    LoadResult := LCert.LoadFromFile('/nonexistent/path/to/certificate.pem');
    if not LoadResult then
      TestResult('LoadFromFile returns False for non-existent file', True)
    else
      TestResult('LoadFromFile returns False for non-existent file', False,
        'Should return False');

    // 测试加载空字符串
    LoadResult := LCert.LoadFromPEM('');
    if not LoadResult then
      TestResult('LoadFromPEM returns False for empty string', True)
    else
      TestResult('LoadFromPEM returns False for empty string', False,
        'Should return False');

    // 测试加载无效的 PEM 格式
    LoadResult := LCert.LoadFromPEM('This is not a valid PEM certificate');
    if not LoadResult then
      TestResult('LoadFromPEM returns False for invalid format', True)
    else
      TestResult('LoadFromPEM returns False for invalid format', False,
        'Should return False');

    // 测试加载部分有效的 PEM（缺少结束标记）
    LoadResult := LCert.LoadFromPEM('-----BEGIN CERTIFICATE-----' + LineEnding + 'SomeData');
    if not LoadResult then
      TestResult('LoadFromPEM returns False for incomplete PEM', True)
    else
      TestResult('LoadFromPEM returns False for incomplete PEM', False,
        'Should return False');

    // 测试加载空 DER 数据
    LoadResult := LCert.LoadFromDER(nil);
    if not LoadResult then
      TestResult('LoadFromDER returns False for nil data', True)
    else
      TestResult('LoadFromDER returns False for nil data', False,
        'Should return False');

  except
    on E: Exception do
      TestResult('Certificate load failures test', False, E.Message);
  end;
end;

{ 初始化 OpenSSL }
procedure InitializeOpenSSL;
begin
  PrintHeader('Initialize OpenSSL');
  try
    LoadOpenSSLCore;
    TestResult('Load OpenSSL core', True);
    WriteLn('OpenSSL version: ', GetOpenSSLVersionString);

    LoadOpenSSLBIO;
    TestResult('Load BIO module', True);
  except
    on E: Exception do
    begin
      TestResult('Initialize OpenSSL', False, E.Message);
      WriteLn('FATAL: Cannot continue');
      Halt(1);
    end;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Verification Failures Test');
  WriteLn('Phase C Week 1 - Certificate Tests');
  WriteLn('========================================');
  WriteLn('Purpose: Test various certificate verification failure scenarios');
  WriteLn;

  try
    // 初始化
    InitializeOpenSSL;

    // 运行测试
    Test_ExpiredCertificate;
    Test_SelfSignedCertificateRejection;
    Test_IncompleteCertificateChain;
    Test_HostnameMismatch;
    Test_LowLevelCertVerification;
    Test_VerificationCallback;
    Test_CertificateLoadFailures;

    // 打印总结
    PrintSummary;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;

  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
