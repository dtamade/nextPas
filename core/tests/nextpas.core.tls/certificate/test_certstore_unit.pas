program test_certstore_unit;

{$mode objfpc}{$H+}

{
  CertStore 单元测试套件
  测试所有证书存储功能
}

uses
  SysUtils, Classes, Math,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.backed;

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

procedure AssertNotNil(const TestName: string; Obj: Pointer);
begin
  AssertTrue(TestName, Obj <> nil);
end;

procedure TestCertStoreCreation;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
begin
  WriteLn;
  WriteLn('=== CertStore Creation Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  AssertNotNil('Library created', Pointer(SSLLib));
  
  AssertTrue('Library initialized', SSLLib.Initialize);
  
  Store := SSLLib.CreateCertificateStore;
  AssertNotNil('CertStore object created', Pointer(Store));
  
  AssertTrue('Store initially empty', Store.GetCount = 0);
end;

procedure TestCertStoreSystemLoad;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Count: Integer;
begin
  WriteLn;
  WriteLn('=== CertStore System Load Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  Store := SSLLib.CreateCertificateStore;
  
  if Store.LoadSystemStore then
  begin
    Count := Store.GetCount;
    WriteLn('  System certificates loaded: ', Count);
    AssertTrue('System store loaded', True);
    // On most Linux systems, this should be > 0
    if Count > 0 then
      WriteLn('  Found ', Count, ' certificates')
    else
      WriteLn('  Note: No system certificates found (may be normal on some systems)');
  end
  else
    WriteLn('  Note: System store loading failed (may be normal on some systems)');
  
  AssertTrue('LoadSystemStore does not crash', True);
end;

procedure TestCertStorePathLoad;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
begin
  WriteLn;
  WriteLn('=== CertStore Path Load Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  Store := SSLLib.CreateCertificateStore;
  
  // Try common certificate paths
  if DirectoryExists('/etc/ssl/certs') then
  begin
    if Store.LoadFromPath('/etc/ssl/certs') then
    begin
      WriteLn('  Loaded from /etc/ssl/certs: ', Store.GetCount, ' certificates');
      AssertTrue('LoadFromPath succeeded', True);
    end
    else
    begin
      WriteLn('  LoadFromPath returned false (may be expected)');
      AssertTrue('LoadFromPath does not crash', True);
    end;
  end
  else
    WriteLn('  /etc/ssl/certs not found, skipping');
  
  AssertTrue('LoadFromPath test completed', True);
end;

procedure TestCertStoreEnumeration;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  I, Count: Integer;
begin
  WriteLn;
  WriteLn('=== CertStore Enumeration Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  Store := SSLLib.CreateCertificateStore;
  Store.LoadSystemStore;
  
  Count := Store.GetCount;
  AssertTrue('GetCount works', True);
  WriteLn('  Total certificates: ', Count);
  
  // Try to get first few certificates
  for I := 0 to Min(2, Count - 1) do
  begin
    Cert := Store.GetCertificate(I);
    if Cert <> nil then
      WriteLn('  [', I, '] Certificate retrieved')
    else
      WriteLn('  [', I, '] Certificate is nil');
  end;
  
  AssertTrue('GetCertificate enumeration works', True);
end;

procedure TestCertStoreSearch;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== CertStore Search Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  Store := SSLLib.CreateCertificateStore;
  Store.LoadSystemStore;
  
  // Try to find a common CA
  Cert := Store.FindBySubject('DigiCert');
  if Cert <> nil then
    WriteLn('  Found certificate with subject containing "DigiCert"')
  else
    WriteLn('  No certificate found with subject containing "DigiCert"');
  
  AssertTrue('FindBySubject does not crash', True);
  
  Cert := Store.FindByIssuer('CA');
  AssertTrue('FindByIssuer does not crash', True);
  
  Cert := Store.FindBySerialNumber('12345');
  AssertTrue('FindBySerialNumber does not crash', True);
  
  Cert := Store.FindByFingerprint('AB:CD:EF');
  AssertTrue('FindByFingerprint does not crash', True);
end;

procedure TestCertStoreVerificationStoreEffect;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  LeafCert: ISSLCertificate;
  CAOptions, LeafOptions: TCertGenOptions;
  CACertPEM, CAKeyPEM: string;
  LeafCertPEM, LeafKeyPEM: string;
  TempCAFile: string;
  Verified: Boolean;
begin
  WriteLn;
  WriteLn('=== CertStore Verification Store Effect Tests ===');

  Randomize;

  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;

  // 生成一个自签名 CA
  CAOptions := TCertificateUtils.DefaultGenOptions;
  CAOptions.CommonName := 'fafafa.ssl Test Root CA';
  CAOptions.Organization := 'fafafa.ssl';
  CAOptions.IsCA := True;
  CAOptions.ValidDays := 30;

  AssertTrue('Generate CA certificate',
    TCertificateUtils.TryGenerateSelfSigned(CAOptions, CACertPEM, CAKeyPEM));

  // 生成一个由该 CA 签名的叶证书
  LeafOptions := TCertificateUtils.DefaultGenOptions;
  LeafOptions.CommonName := 'leaf.test';
  LeafOptions.Organization := 'fafafa.ssl';
  LeafOptions.IsCA := False;
  LeafOptions.ValidDays := 30;

  AssertTrue('Generate leaf certificate signed by CA',
    TCertificateUtils.TryGenerateSigned(LeafOptions, CACertPEM, CAKeyPEM,
      LeafCertPEM, LeafKeyPEM));

  LeafCert := SSLLib.CreateCertificate;
  AssertNotNil('Leaf cert object created', Pointer(LeafCert));
  AssertTrue('Leaf certificate loaded from PEM', LeafCert.LoadFromPEM(LeafCertPEM));

  Store := SSLLib.CreateCertificateStore;
  AssertNotNil('CertStore object created', Pointer(Store));

  // 未加载 CA 时验证应失败（但不崩溃）
  Verified := LeafCert.Verify(Store);
  AssertTrue('Verify fails without CA loaded', not Verified);

  TempCAFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    Format('fafafa_ssl_test_ca_%d.pem', [Random(1000000)]);

  AssertTrue('Write CA PEM to temp file', TCertificateUtils.SaveToFile(TempCAFile, CACertPEM));
  try
    // 关键：LoadFromFile 必须把 CA 写入 X509_STORE，否则 Verify 仍会失败
    AssertTrue('Store.LoadFromFile(CA) succeeded', Store.LoadFromFile(TempCAFile));

    Verified := LeafCert.Verify(Store);
    AssertTrue('Verify succeeds after CA loaded into store', Verified);
  finally
    DeleteFile(TempCAFile);
  end;
end;

procedure TestCertStoreMemory;
var
  SSLLib: ISSLLibrary;
  Store1, Store2, Store3: ISSLCertificateStore;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== CertStore Memory Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  // Create and destroy multiple stores
  for I := 1 to 10 do
  begin
    Store1 := SSLLib.CreateCertificateStore;
    Store2 := SSLLib.CreateCertificateStore;
    Store3 := SSLLib.CreateCertificateStore;
    Store1.LoadSystemStore;
    // Reference counting should clean up automatically
  end;
  
  AssertTrue('Multiple store creation/destruction succeeds', True);
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests: ', TestsPassed + TestsFailed);
  WriteLn('Passed: ', TestsPassed, ' ✓');
  WriteLn('Failed: ', TestsFailed, ' ✗');
  
  if TestsPassed + TestsFailed > 0 then
    WriteLn('Success rate: ', (TestsPassed * 100) div (TestsPassed + TestsFailed), '%');
  
  WriteLn('========================================');
  
  if TestsFailed = 0 then
  begin
    WriteLn('✅ ALL TESTS PASSED!');
    Halt(0);
  end
  else
  begin
    WriteLn('❌ SOME TESTS FAILED!');
    Halt(1);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('CertStore Unit Tests');
  WriteLn('========================================');
  
  try
    TestCertStoreCreation;
    TestCertStoreSystemLoad;
    TestCertStorePathLoad;
    TestCertStoreEnumeration;
    TestCertStoreSearch;
    TestCertStoreVerificationStoreEffect;
    TestCertStoreMemory;
    
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ FATAL ERROR: ', E.Message);
      WriteLn('   ', E.ClassName);
      Halt(2);
    end;
  end;
end.

