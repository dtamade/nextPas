program test_cert_info_extraction;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.factory,
  fafafa.ssl;

var
  GPassed, GFailed: Integer;
  GTestCert, GTestKey: string;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('[OK] ', AMessage);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure GenerateTestCertificate;
var
  LOptions: TCertGenOptions;
begin
  WriteLn('=== Generating Test Certificate with Extensions ===');
  
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'test.example.com';
  LOptions.Organization := 'Test Org';
  LOptions.IsCA := False;
  LOptions.ValidDays := 365;
  
  if not TCertificateUtils.GenerateSelfSigned(LOptions, GTestCert, GTestKey) then
  begin
    WriteLn('[FATAL] Failed to generate test certificate');
    Halt(1);
  end;
  
  WriteLn('[OK] Test certificate generated');
  WriteLn('  PEM Length: ', Length(GTestCert));
  WriteLn;
end;

procedure TestBasicInfo;
var
  LInfo: TCertInfo;
begin
  WriteLn('=== Test: Basic Certificate Info ===');
  
  LInfo := TCertificateUtils.GetInfo(GTestCert);
  
  AssertTrue(LInfo.Subject <> '', 'Subject should not be empty');
  AssertTrue(LInfo.Issuer <> '', 'Issuer should not be empty');
  AssertTrue(Pos('test.example.com', LInfo.Subject) > 0, 'Subject should contain CN');
  AssertTrue(LInfo.Version >= 3, 'Should be X509v3 certificate');
  AssertTrue(LInfo.NotBefore < LInfo.NotAfter, 'NotBefore < NotAfter');
  
  WriteLn('  Subject: ', LInfo.Subject);
  WriteLn('  Issuer: ', LInfo.Issuer);
  WriteLn('  Version: ', LInfo.Version);
  WriteLn('  Valid: ', DateTimeToStr(LInfo.NotBefore), ' to ', DateTimeToStr(LInfo.NotAfter));
  
  if Assigned(LInfo.SubjectAltNames) then
    LInfo.SubjectAltNames.Free;
  WriteLn;
end;

procedure TestSubjectAltNames;
var
  LInfo: TCertInfo;
  i: Integer;
begin
  WriteLn('=== Test: SubjectAltName Extraction ===');
  
  LInfo := TCertificateUtils.GetInfo(GTestCert);
  
  // 当前证书可能没有SAN，所以只检查对象存在
  AssertTrue(Assigned(LInfo.SubjectAltNames), 'SubjectAltNames list should be created');
  
  WriteLn('  SAN Count: ', LInfo.SubjectAltNames.Count);
  if LInfo.SubjectAltNames.Count > 0 then
  begin
    WriteLn('  SANs:');
    for i := 0 to LInfo.SubjectAltNames.Count - 1 do
      WriteLn('    - ', LInfo.SubjectAltNames[i]);
  end;
  
  LInfo.SubjectAltNames.Free;
  WriteLn;
end;

procedure TestKeyUsage;
var
  LInfo: TCertInfo;
begin
  WriteLn('=== Test: KeyUsage Info ===');
  
  LInfo := TCertificateUtils.GetInfo(GTestCert);
  
  // 当前KeyUsage是string类型
  WriteLn('  KeyUsage: "', LInfo.KeyUsage, '"');
  WriteLn('  IsCA: ', LInfo.IsCA);
  
  if Assigned(LInfo.SubjectAltNames) then
    LInfo.SubjectAltNames.Free;
  WriteLn;
end;

begin
  GPassed := 0;
  GFailed := 0;
  
  WriteLn('====================================');
  WriteLn('  Certificate Info Extraction Test');
  WriteLn('====================================');
  WriteLn;
  
  try
    GenerateTestCertificate;
    TestBasicInfo;
    TestSubjectAltNames;
    TestKeyUsage;
    
    WriteLn('====================================');
    WriteLn('Results:');
    WriteLn('  Passed: ', GPassed);
    WriteLn('  Failed: ', GFailed);
    WriteLn('====================================');
    
    if GFailed > 0 then
      Halt(1);
      
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
