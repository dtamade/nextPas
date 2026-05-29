program test_cert_utils;

{$mode objfpc}{$H+}

{
  证书工具类测试
  
  测试 TCertificateUtils 的所有功能
}

uses
  SysUtils, Classes,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;

procedure TestResult(const ATestName: string; ASuccess: Boolean; const ADetails: string = '');
begin
  Inc(TotalTests);
  if ASuccess then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', ATestName);
    if ADetails <> '' then
      WriteLn('       ', ADetails);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', ATestName);
    if ADetails <> '' then
      WriteLn('       Reason: ', ADetails);
  end;
end;

procedure PrintHeader(const ATitle: string);
begin
  WriteLn;
  WriteLn('Test: ', ATitle);
  WriteLn('----------------------------------------');
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('TEST SUMMARY');
  WriteLn('========================================');
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);
  if TotalTests > 0 then
    WriteLn('Pass rate: ', (PassedTests * 100) div TotalTests, '%');
  WriteLn('========================================');
end;

procedure Test1_DefaultOptions;
var
  LOptions: TCertGenOptions;
begin
  PrintHeader('Default Generation Options');
  try
    LOptions := TCertificateUtils.DefaultGenOptions;
    
    TestResult('Default CN is set', LOptions.CommonName <> '');
    TestResult('Default Organization is set', LOptions.Organization <> '');
    TestResult('Default ValidDays > 0', LOptions.ValidDays > 0);
    TestResult('Default KeyType is RSA', LOptions.KeyType = ktRSA);
    TestResult('Default KeyBits is 2048', LOptions.KeyBits = 2048);
    
  except
    on E: Exception do
      TestResult('Default options', False, E.Message);
  end;
end;

procedure Test2_GenerateSelfSignedRSA;
var
  LCert, LKey: string;
  LSuccess: Boolean;
begin
  PrintHeader('Generate Self-Signed Certificate (RSA)');
  try
    LSuccess := TCertificateUtils.GenerateSelfSignedSimple(
      'test.example.com',
      'Test Organization',
      365,
      LCert,
      LKey
    );
    
    TestResult('RSA cert generation returns success', LSuccess);
    TestResult('Certificate PEM generated', LCert <> '');
    TestResult('Private key PEM generated', LKey <> '');
    
    if LCert <> '' then
    begin
      TestResult('Cert starts with BEGIN CERTIFICATE', 
        Pos('-----BEGIN CERTIFICATE-----', LCert) > 0);
      TestResult('Cert has reasonable length', Length(LCert) > 500);
    end;
    
    if LKey <> '' then
    begin
      TestResult('Key starts with BEGIN PRIVATE KEY',
        (Pos('-----BEGIN PRIVATE KEY-----', LKey) > 0) or
        (Pos('-----BEGIN RSA PRIVATE KEY-----', LKey) > 0));
      TestResult('Key has reasonable length', Length(LKey) > 800);
    end;
    
  except
    on E: Exception do
      TestResult('RSA cert generation', False, E.Message);
  end;
end;

procedure Test3_GenerateSelfSignedEC;
var
  LOptions: TCertGenOptions;
  LCert, LKey: string;
  LSuccess: Boolean;
begin
  PrintHeader('Generate Self-Signed Certificate (ECDSA)');
  try
    LOptions := TCertificateUtils.DefaultGenOptions;
    LOptions.CommonName := 'ec.example.com';
    LOptions.KeyType := ktECDSA;
    LOptions.ECCurve := 'prime256v1';
    
    LSuccess := TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey);
    
    TestResult('ECDSA cert generation returns success', LSuccess);
    TestResult('EC certificate PEM generated', LCert <> '');
    TestResult('EC private key PEM generated', LKey <> '');
    
    if LKey <> '' then
    begin
      TestResult('EC key format correct',
        (Pos('-----BEGIN EC PRIVATE KEY-----', LKey) > 0) or
        (Pos('-----BEGIN PRIVATE KEY-----', LKey) > 0));
    end;
    
  except
    on E: Exception do
      TestResult('ECDSA cert generation', False, E.Message);
  end;
end;

procedure Test4_GetCertInfo;
var
  LCert, LKey: string;
  LInfo: TCertInfo;
begin
  PrintHeader('Extract Certificate Information');
  try
    // 先生成一个证书
    if not TCertificateUtils.GenerateSelfSignedSimple(
      'info.example.com',
      'Info Test Org',
      30,
      LCert,
      LKey
    ) then
    begin
      TestResult('Certificate info extraction', False, 'Failed to generate test cert');
      Exit;
    end;
    
    LInfo := TCertificateUtils.GetInfo(LCert);
    try
      TestResult('Subject extracted', LInfo.Subject <> '');
      TestResult('Issuer extracted', LInfo.Issuer <> '');
      TestResult('Version is valid', LInfo.Version >= 1);
      
      WriteLn('  Subject: ', LInfo.Subject);
      WriteLn('  Issuer: ', LInfo.Issuer);
      WriteLn('  Version: ', LInfo.Version);
      
    finally
      if LInfo.SubjectAltNames <> nil then
        LInfo.SubjectAltNames.Free;
    end;
    
  except
    on E: Exception do
      TestResult('Certificate info extraction', False, E.Message);
  end;
end;

procedure Test5_SaveAndLoad;
var
  LCert, LKey: string;
  LLoadedCert: string;
  LFileName: string;
begin
  PrintHeader('Save and Load Certificate');
  LFileName := 'test_cert.pem';
  try
    // 生成证书
    if not TCertificateUtils.GenerateSelfSignedSimple(
      'save.example.com',
      'Save Test Org',
      365,
      LCert,
      LKey
    ) then
    begin
      TestResult('Save and load test', False, 'Failed to generate cert');
      Exit;
    end;
    
    // 保存
    if TCertificateUtils.SaveToFile(LFileName, LCert) then
      TestResult('Save certificate to file', True)
    else
    begin
      TestResult('Save certificate to file', False);
      Exit;
    end;
    
    // 加载
    LLoadedCert := TCertificateUtils.LoadFromFile(LFileName);
    TestResult('Load certificate from file', LLoadedCert <> '');
    TestResult('Loaded cert matches original', LLoadedCert = LCert);
    
    // 清理
    if FileExists(LFileName) then
      DeleteFile(LFileName);
    
  except
    on E: Exception do
    begin
      TestResult('Save and load', False, E.Message);
      if FileExists(LFileName) then
        DeleteFile(LFileName);
    end;
  end;
end;

procedure Test6_CustomOptions;
var
  LOptions: TCertGenOptions;
  LCert, LKey: string;
begin
  PrintHeader('Generate Certificate with Custom Options');
  try
    LOptions := TCertificateUtils.DefaultGenOptions;
    LOptions.CommonName := 'custom.example.com';
    LOptions.Organization := 'Custom Corp';
    LOptions.OrganizationalUnit := 'IT Department';
    LOptions.Country := 'CN';
    LOptions.State := 'Beijing';
    LOptions.Locality := 'Beijing';
    LOptions.ValidDays := 730;  // 2 years
    LOptions.KeyBits := 4096;    // 4096-bit key
    
    if TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey) then
    begin
      TestResult('Custom options cert generation', True);
      TestResult('Custom cert has content', Length(LCert) > 500);
      TestResult('4096-bit key has larger size', Length(LKey) > 1600);
    end
    else
      TestResult('Custom options cert generation', False);
    
  except
    on E: Exception do
      TestResult('Custom options', False, E.Message);
  end;
end;

procedure Test7_MultipleGeneration;
var
  LCert1, LKey1, LCert2, LKey2: string;
begin
  PrintHeader('Multiple Certificate Generation');
  try
    // 生成第一个
    if not TCertificateUtils.GenerateSelfSignedSimple(
      'cert1.example.com',
      'Test Org 1',
      365,
      LCert1,
      LKey1
    ) then
    begin
      TestResult('Multiple generation test', False, 'Failed to generate cert1');
      Exit;
    end;
    
    // 生成第二个
    if not TCertificateUtils.GenerateSelfSignedSimple(
      'cert2.example.com',
      'Test Org 2',
      365,
      LCert2,
      LKey2
    ) then
    begin
      TestResult('Multiple generation test', False, 'Failed to generate cert2');
      Exit;
    end;
    
    TestResult('First cert generated', LCert1 <> '');
    TestResult('Second cert generated', LCert2 <> '');
    TestResult('Certs are different', LCert1 <> LCert2);
    TestResult('Keys are different', LKey1 <> LKey2);
    
  except
    on E: Exception do
      TestResult('Multiple generation', False, E.Message);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utilities Test Suite');
  WriteLn('========================================');
  WriteLn;
  
  try
    // 初始化OpenSSL
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('ERROR: Failed to load OpenSSL');
      Halt(1);
    end;
    WriteLn('OpenSSL loaded: ', GetOpenSSLVersionString);
    WriteLn;
    
    // 运行测试
    Test1_DefaultOptions;
    Test2_GenerateSelfSignedRSA;
    Test3_GenerateSelfSignedEC;
    Test4_GetCertInfo;
    Test5_SaveAndLoad;
    Test6_CustomOptions;
    Test7_MultipleGeneration;
    
    // 打印总结
    PrintSummary;
    
    if FailedTests > 0 then
    begin
      WriteLn;
      WriteLn('Result: ', FailedTests, ' test(s) failed');
      Halt(1);
    end
    else
    begin
      WriteLn;
      WriteLn('Result: All tests passed!');
      WriteLn('Certificate utilities are working correctly ✓');
    end;
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;

  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
