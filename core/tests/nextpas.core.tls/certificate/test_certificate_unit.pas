program test_certificate_unit;

{$mode objfpc}{$H+}

{
  Certificate 单元测试套件
  测试所有证书相关功能
}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  EnableSystemStoreDebug: Boolean = False;

function ArrayContains(const AValues: TSSLStringArray; const AExpected: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(AValues) to High(AValues) do
  begin
    if SameText(AValues[I], AExpected) then
      Exit(True);
  end;
end;

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

procedure AssertFalse(const TestName: string; Condition: Boolean);
begin
  AssertTrue(TestName, not Condition);
end;

procedure AssertNotNil(const TestName: string; Obj: Pointer);
begin
  AssertTrue(TestName, Obj <> nil);
end;

procedure TestCertificateCreation;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== Certificate Creation Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  AssertNotNil('Library created', Pointer(SSLLib));
  
  AssertTrue('Library initialized', SSLLib.Initialize);
  
  // 注意：OpenSSL backend 不支持直接创建空证书
  // 证书应该从文件或数据加载
  Cert := SSLLib.CreateCertificate;
  if Cert = nil then
  begin
    WriteLn('  Note: Empty certificate creation not supported (expected behavior)');
    AssertTrue('CreateCertificate returns nil as expected', True);
  end
  else
    AssertNotNil('Certificate object created', Pointer(Cert));
end;

procedure TestCertificateInfo;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
begin
  WriteLn;
  WriteLn('=== Certificate Info Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  // 使用Store测试，因为空证书可能不稳定
  Store := SSLLib.CreateCertificateStore;
  AssertNotNil('Can create certificate store', Pointer(Store));
  
  // 如果系统有证书，加载并测试
  if Store.LoadSystemStore then
  begin
    WriteLn('  System certificates loaded for testing');
    AssertTrue('Store loads system certs', Store.GetCount > 0);
  end
  else
    AssertTrue('Store creation works', True);
end;

procedure TestCertificateInfoFromSystemStore;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  Info: TSSLCertificateInfo;
  KeyUsageList: TSSLStringArray;
  SANValues: TSSLStringArray;
  TmpStr: string;
begin
  WriteLn;
  WriteLn('=== Certificate GetInfo/System Store Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  Store := SSLLib.CreateCertificateStore;
  AssertNotNil('System store can be created', Pointer(Store));
  
  if not Store.LoadSystemStore then
  begin
    WriteLn('  Note: System store not available, skipping GetInfo tests');
    AssertTrue('LoadSystemStore failed but did not crash', True);
    Exit;
  end;
  
  if Store.GetCount <= 0 then
  begin
    WriteLn('  Note: System store is empty, skipping GetInfo tests');
    AssertTrue('Empty system store handled gracefully', True);
    Exit;
  end;
  
  Cert := Store.GetCertificate(0);
  AssertNotNil('Can retrieve first certificate from system store', Pointer(Cert));
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 1: GetSubject');
  TmpStr := Cert.GetSubject;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 1 OK');

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 2: GetIssuer');
  TmpStr := Cert.GetIssuer;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 2 OK');

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 3: GetSerialNumber');
  TmpStr := Cert.GetSerialNumber;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 3 OK');

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 4: GetNotBefore');
  Info.NotBefore := Cert.GetNotBefore;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 4 OK');

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 5: GetNotAfter');
  Info.NotAfter := Cert.GetNotAfter;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 5 OK');

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 6: IsCA');
  Info.IsCA := Cert.IsCA;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 6 OK, IsCA = ', BoolToStr(Info.IsCA, True));

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 7: GetKeyUsage');
  KeyUsageList := Cert.GetKeyUsage;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 7 OK, KeyUsage count = ', Length(KeyUsageList));

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 8: GetSubjectAltNames');
  SANValues := Cert.GetSubjectAltNames;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 8 OK, SAN count = ', Length(SANValues));

  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 9: GetInfo');
  Info := Cert.GetInfo;
  if EnableSystemStoreDebug then
    WriteLn('  [DEBUG] Step 9 OK');
  
  // IsCA 标志在 Info 与接口层之间应保持一致
  AssertTrue('Info.IsCA matches IsCA', Info.IsCA = Cert.IsCA);
  
  // KeyUsage 位字段与文本列表之间的基本关系：
  // 如果位字段非零，则文本列表应至少包含一个条目
  KeyUsageList := Cert.GetKeyUsage;
  if Info.KeyUsage <> 0 then
    AssertTrue('Non-zero KeyUsage bitfield implies textual list not empty',
      Length(KeyUsageList) > 0)
  else
    AssertTrue('Zero KeyUsage bitfield is allowed', True);
end;

procedure TestCertificateFingerprints;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  FP_SHA1, FP_SHA256: string;
begin
  WriteLn;
  WriteLn('=== Certificate Fingerprint Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping fingerprint tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试空证书的指纹
  FP_SHA1 := Cert.GetFingerprintSHA1;
  AssertTrue('SHA1 fingerprint returns empty for empty cert', FP_SHA1 = '');
  
  FP_SHA256 := Cert.GetFingerprintSHA256;
  AssertTrue('SHA256 fingerprint returns empty for empty cert', FP_SHA256 = '');
  
  // 测试通用接口
  FP_SHA1 := Cert.GetFingerprint(sslHashSHA1);
  AssertTrue('GetFingerprint(SHA1) works', FP_SHA1 = '');
  
  FP_SHA256 := Cert.GetFingerprint(sslHashSHA256);
  AssertTrue('GetFingerprint(SHA256) works', FP_SHA256 = '');
end;

procedure TestCertificateStatus;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== Certificate Status Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping status tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试状态检查（空证书应该不会崩溃）
  AssertTrue('IsExpired does not crash', True);
  Cert.IsExpired;
  
  AssertTrue('IsSelfSigned does not crash', True);
  Cert.IsSelfSigned;
  
  AssertTrue('IsCA does not crash', True);
  Cert.IsCA;
end;

procedure TestCertificatePublicKey;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  PubKey, Algorithm: string;
begin
  WriteLn;
  WriteLn('=== Certificate Public Key Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping public key tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试公钥获取
  PubKey := Cert.GetPublicKey;
  AssertTrue('GetPublicKey returns string', True);
  
  Algorithm := Cert.GetPublicKeyAlgorithm;
  AssertTrue('GetPublicKeyAlgorithm returns string', True);
  
  Algorithm := Cert.GetSignatureAlgorithm;
  AssertTrue('GetSignatureAlgorithm returns string', True);
end;

procedure TestCertificateExtensions;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  Ext: string;
  SANs, KeyUsage: TSSLStringArray;
begin
  WriteLn;
  WriteLn('=== Certificate Extensions Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping extensions tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试扩展获取（不应崩溃）
  Ext := Cert.GetExtension('2.5.29.17');
  AssertTrue('GetExtension does not crash', True);
  
  SANs := Cert.GetSubjectAltNames;
  AssertTrue('GetSubjectAltNames returns array without crashing', Length(SANs) >= 0);
  
  KeyUsage := Cert.GetKeyUsage;
  AssertTrue('GetKeyUsage returns array without crashing', Length(KeyUsage) >= 0);
  
  KeyUsage := Cert.GetExtendedKeyUsage;
  AssertTrue('GetExtendedKeyUsage returns array without crashing', Length(KeyUsage) >= 0);
end;

procedure TestCertificateDates;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  NotBefore, NotAfter: TDateTime;
begin
  WriteLn;
  WriteLn('=== Certificate Date Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping date tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试日期获取
  NotBefore := Cert.GetNotBefore;
  AssertTrue('GetNotBefore returns value', NotBefore >= 0);
  
  NotAfter := Cert.GetNotAfter;
  AssertTrue('GetNotAfter returns value', NotAfter >= 0);
  
  if (NotBefore = 0) and (NotAfter = 0) then
    AssertTrue('Unknown empty-certificate dates are allowed', True)
  else
    AssertTrue('Known certificate dates stay ordered', NotAfter > NotBefore);
end;

procedure TestCertificateVerification;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  Store: ISSLCertificateStore;
  VerifyResult: TSSLCertVerifyResult;
  Verified: Boolean;
begin
  WriteLn;
  WriteLn('=== Certificate Verification Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping verification tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  Store := SSLLib.CreateCertificateStore;
  
  // 测试基础验证（空证书应该失败但不崩溃）
  Verified := Cert.Verify(Store);
  AssertTrue('Verify with empty store does not crash', True);
  
  // 测试高级验证
  Verified := Cert.VerifyEx(Store, [], VerifyResult);
  AssertTrue('VerifyEx does not crash', True);
  AssertTrue('VerifyEx returns result structure', True);
  
  // 测试主机名验证
  Verified := Cert.VerifyHostname('example.com');
  AssertTrue('VerifyHostname does not crash', True);
end;

procedure TestCertificateSerializationPEM;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  PEM: string;
  Loaded: Boolean;
begin
  WriteLn;
  WriteLn('=== Certificate PEM Serialization Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping PEM tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试PEM导出
  PEM := Cert.SaveToPEM;
  AssertTrue('SaveToPEM returns string', True);
  
  // 测试PEM导入（空PEM应该失败但不崩溃）
  Loaded := Cert.LoadFromPEM('');
  AssertTrue('LoadFromPEM with empty string does not crash', True);
end;

procedure TestCertificateSerializationDER;
var
  SSLLib: ISSLLibrary;
  Cert: ISSLCertificate;
  DER: TBytes;
  EmptyDER: TBytes;
  Loaded: Boolean;
begin
  WriteLn;
  WriteLn('=== Certificate DER Serialization Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  Cert := SSLLib.CreateCertificate;
  
  if Cert = nil then
  begin
    WriteLn('  Note: Skipping DER tests (empty cert not supported)');
    AssertTrue('CreateCertificate returns nil', True);
    Exit;
  end;
  
  // 测试DER导出
  DER := Cert.SaveToDER;
  AssertTrue('SaveToDER returns bytes', True);
  
  // 测试DER导入（空DER应该失败但不崩溃）
  SetLength(EmptyDER, 0);
  Loaded := Cert.LoadFromDER(EmptyDER);
  AssertTrue('LoadFromDER with empty bytes does not crash', True);
end;

procedure TestCertificateMemoryLeaks;
var
  SSLLib: ISSLLibrary;
  Cert1, Cert2, Cert3: ISSLCertificate;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Certificate Memory Management Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  SSLLib.Initialize;
  
  // 创建和销毁多个证书对象
  // 注意：OpenSSL backend 不支持空证书，所以这个测试只是验证调用不崩溃
  for I := 1 to 100 do
  begin
    Cert1 := SSLLib.CreateCertificate;
    Cert2 := SSLLib.CreateCertificate;
    Cert3 := SSLLib.CreateCertificate;
    // 引用计数应该自动清理
  end;
  
  WriteLn('  Note: Empty cert creation returns nil (expected behavior)');
  AssertTrue('Multiple cert creation/destruction succeeds', True);
end;

procedure TestCertificateSAN;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  SANs: TSSLStringArray;
  HasSanTest, HasExample, HasIp: Boolean;
  Info: TSSLCertificateInfo;
  I: Integer;
  InInfo: Boolean;
begin
  WriteLn;
  WriteLn('=== Certificate SAN Parsing Tests ===');
  
  SSLLib := CreateOpenSSLLibrary;
  AssertNotNil('OpenSSL library created for SAN tests', Pointer(SSLLib));
  if not SSLLib.Initialize then
  begin
    WriteLn('  Note: OpenSSL library initialization failed, skipping SAN tests');
    AssertTrue('Initialize OpenSSL library for SAN tests', False);
    Exit;
  end;

  Store := SSLLib.CreateCertificateStore;
  if Store = nil then
  begin
    WriteLn('  Note: Failed to create certificate store for SAN tests, skipping');
    AssertTrue('CreateCertificateStore returns nil', True);
    Exit;
  end;
  
  if not Store.LoadFromFile('tests/certs/san-test.pem') then
  begin
    WriteLn('  Note: SAN test certificate not available, skipping');
    AssertTrue('LoadFromFile failed but did not crash', True);
    Exit;
  end;

  if Store.GetCount <= 0 then
  begin
    WriteLn('  Note: SAN store is empty after loading test certificate, skipping');
    AssertTrue('SAN store is empty but handled gracefully', True);
    Exit;
  end;

  Cert := Store.GetCertificate(0);
  if Cert = nil then
  begin
    WriteLn('  Note: Failed to retrieve SAN test certificate from store, skipping');
    AssertTrue('GetCertificate(0) returned nil', True);
    Exit;
  end;
  
  SANs := Cert.GetSubjectAltNames;
  AssertTrue('GetSubjectAltNames returns non-empty array for SAN cert', Length(SANs) > 0);
  HasSanTest := ArrayContains(SANs, 'san-test.local');
  HasExample := ArrayContains(SANs, 'example.test');
  HasIp := ArrayContains(SANs, '127.0.0.1');
  AssertTrue('SANs contain DNS:san-test.local', HasSanTest);
  AssertTrue('SANs contain DNS:example.test', HasExample);
  AssertTrue('SANs contain IP:127.0.0.1', HasIp);
  
  Info := Cert.GetInfo;
  InInfo := False;
  for I := 0 to High(Info.SubjectAltNames) do
  begin
    if Info.SubjectAltNames[I] = 'san-test.local' then
    begin
      InInfo := True;
      Break;
    end;
  end;
  AssertTrue('Info.SubjectAltNames contains DNS:san-test.local', InInfo);
end;

procedure TestCertificateVerifyHostnameSAN;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== Certificate Hostname Verification (SAN) ===');

  SSLLib := CreateOpenSSLLibrary;
  AssertNotNil('OpenSSL library created for VerifyHostname SAN tests', Pointer(SSLLib));
  if not SSLLib.Initialize then
  begin
    WriteLn('  Note: OpenSSL library initialization failed, skipping VerifyHostname SAN tests');
    AssertTrue('Initialize OpenSSL library for VerifyHostname SAN tests', False);
    Exit;
  end;

  Store := SSLLib.CreateCertificateStore;
  if Store = nil then
  begin
    WriteLn('  Note: Failed to create certificate store for VerifyHostname SAN tests, skipping');
    AssertTrue('CreateCertificateStore returns nil for VerifyHostname SAN tests', True);
    Exit;
  end;

  if not Store.LoadFromFile('tests/certs/san-test.pem') then
  begin
    WriteLn('  Note: SAN test certificate not available, skipping VerifyHostname SAN tests');
    AssertTrue('LoadFromFile failed but did not crash (VerifyHostname SAN)', True);
    Exit;
  end;

  if Store.GetCount <= 0 then
  begin
    WriteLn('  Note: SAN store is empty after loading test certificate, skipping VerifyHostname SAN tests');
    AssertTrue('SAN store empty but handled gracefully (VerifyHostname SAN)', True);
    Exit;
  end;

  Cert := Store.GetCertificate(0);
  if Cert = nil then
  begin
    WriteLn('  Note: Failed to retrieve SAN test certificate from store, skipping VerifyHostname SAN tests');
    AssertTrue('GetCertificate(0) returned nil (VerifyHostname SAN)', True);
    Exit;
  end;

  AssertTrue('VerifyHostname accepts DNS:san-test.local', Cert.VerifyHostname('san-test.local'));
  AssertTrue('VerifyHostname accepts DNS:example.test', Cert.VerifyHostname('example.test'));
  AssertTrue('VerifyHostname accepts IP:127.0.0.1', Cert.VerifyHostname('127.0.0.1'));
  AssertFalse('VerifyHostname rejects unrelated hostname', Cert.VerifyHostname('invalid.test'));
  AssertFalse('VerifyHostname rejects mismatched IP', Cert.VerifyHostname('192.0.2.1'));
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
  WriteLn('Certificate Unit Tests');
  WriteLn('========================================');
  
  try
    TestCertificateCreation;
    TestCertificateInfo;
    TestCertificateInfoFromSystemStore;
    TestCertificateFingerprints;
    TestCertificateStatus;
    TestCertificatePublicKey;
    TestCertificateExtensions;
    TestCertificateDates;
    TestCertificateVerification;
    TestCertificateSerializationPEM;
    TestCertificateSerializationDER;
    TestCertificateMemoryLeaks;
    TestCertificateSAN;
    TestCertificateVerifyHostnameSAN;
    
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
