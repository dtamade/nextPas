program test_certificate_chain_methods;

{$mode objfpc}{$H+}

{
  测试证书链方法
  验证 SetIssuerCertificate 和 GetIssuerCertificate 功能
}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.certificate;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(const TestName: string; Condition: Boolean);
begin
  Write('  [TEST] ', TestName, '... ');
  if Condition then
  begin
    WriteLn('✓ PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('✗ FAIL');
    Inc(TestsFailed);
  end;
end;

procedure AssertNotNil(const TestName: string; Obj: IInterface);
begin
  AssertTrue(TestName, Obj <> nil);
end;

procedure TestSetGetIssuerCertificate;
var
  LeafCert, IssuerCert, RetrievedIssuer: ISSLCertificate;
  LeafPEM, IssuerPEM: string;
begin
  WriteLn;
  WriteLn('=== Test Set/Get Issuer Certificate ===');
  
  // 简单的自签名证书
  LeafPEM := 
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'MIICljCCAX4CCQCKz8PfGfZT9TANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV' + LineEnding +
    'UzAeFw0yNDAxMDEwMDAwMDBaFw0yNTAxMDEwMDAwMDBaMA0xCzAJBgNVBAYTAlVT' + LineEnding +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw8v7t' + LineEnding +
    'n8=' + LineEnding +
    '-----END CERTIFICATE-----';
    
  IssuerPEM :=
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'MIICljCCAX4CCQCKz8PfGfZT9TANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV' + LineEnding +
    'UzAeFw0yNDAxMDEwMDAwMDBaFw0yNTAxMDEwMDAwMDBaMA0xCzAJBgNVBAYTAlVT' + LineEnding +
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw8v7t' + LineEnding +
    'n8=' + LineEnding +
    '-----END CERTIFICATE-----';
  
  // 创建证书
  LeafCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  IssuerCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  
  AssertNotNil('LeafCert created', LeafCert);
  AssertNotNil('IssuerCert created', IssuerCert);
  
  // 测试初始状态
  RetrievedIssuer := LeafCert.GetIssuerCertificate;
  AssertTrue('Initially no issuer', RetrievedIssuer = nil);
  
  // 设置颁发者证书
  LeafCert.SetIssuerCertificate(IssuerCert);
  
  // 获取颁发者证书
  RetrievedIssuer := LeafCert.GetIssuerCertificate;
  AssertNotNil('Issuer retrieved', RetrievedIssuer);
  
  // 验证是同一个对象
  AssertTrue('Same issuer object', RetrievedIssuer = IssuerCert);
  
  // 测试清除颁发者
  LeafCert.SetIssuerCertificate(nil);
  RetrievedIssuer := LeafCert.GetIssuerCertificate;
  AssertTrue('Issuer cleared', RetrievedIssuer = nil);
  
  // 测试重新设置
  LeafCert.SetIssuerCertificate(IssuerCert);
  RetrievedIssuer := LeafCert.GetIssuerCertificate;
  AssertNotNil('Issuer set again', RetrievedIssuer);
end;

procedure TestCertificateChainBuilding;
var
  RootCert, IntermediateCert, LeafCert: ISSLCertificate;
  Retrieved: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== Test Certificate Chain Building ===');
  
  // 创建证书链: Root -> Intermediate -> Leaf
  RootCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  IntermediateCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  LeafCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  
  AssertNotNil('RootCert created', RootCert);
  AssertNotNil('IntermediateCert created', IntermediateCert);
  AssertNotNil('LeafCert created', LeafCert);
  
  // 构建链
  LeafCert.SetIssuerCertificate(IntermediateCert);
  IntermediateCert.SetIssuerCertificate(RootCert);
  
  // 验证链: Leaf -> Intermediate
  Retrieved := LeafCert.GetIssuerCertificate;
  AssertTrue('Leaf -> Intermediate', Retrieved = IntermediateCert);
  
  // 验证链: Intermediate -> Root
  if Retrieved <> nil then
  begin
    Retrieved := Retrieved.GetIssuerCertificate;
    AssertTrue('Intermediate -> Root', Retrieved = RootCert);
    
    // 验证根证书没有颁发者
    if Retrieved <> nil then
    begin
      Retrieved := Retrieved.GetIssuerCertificate;
      AssertTrue('Root has no issuer', Retrieved = nil);
    end;
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('Certificate Chain Methods Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests: ', TestsPassed + TestsFailed);
  WriteLn('Passed: ', TestsPassed, ' ✓');
  WriteLn('Failed: ', TestsFailed, ' ✗');
  if TestsPassed + TestsFailed > 0 then
    WriteLn('Success rate: ', (TestsPassed * 100) div (TestsPassed + TestsFailed), '%');
  WriteLn('========================================');
  
  if TestsFailed = 0 then
  begin
    WriteLn('✅ ALL CERTIFICATE CHAIN TESTS PASSED!');
    Halt(0);
  end
  else
  begin
    WriteLn('❌ SOME TESTS FAILED!');
    Halt(1);
  end;
end;

var
  SSLLib: ISSLLibrary;

begin
  WriteLn('========================================');
  WriteLn('Certificate Chain Methods Tests');
  WriteLn('========================================');
  
  try
    // Initialize OpenSSL
    SSLLib := CreateOpenSSLLibrary;
    if SSLLib = nil then
    begin
      WriteLn('Failed to create OpenSSL library');
      Halt(2);
    end;
    
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL library');
      Halt(2);
    end;
    
    WriteLn('OpenSSL initialized: ', SSLLib.GetVersionString);
    
    // Run test cases
    TestSetGetIssuerCertificate;
    TestCertificateChainBuilding;
    
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ FATAL ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
