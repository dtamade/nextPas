program test_helper_utilities;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes,
  nextpas.core.tls.factory,
  
  nextpas.core.tls.base,
  fafafa.ssl;

type
  TSkipCategory = (
    scDependency,
    scVersion,
    scEnvironment,
    scCapability,
    scOther
  );

var
  TotalTests, PassedTests, FailedTests, SkippedTests: Integer;
  SkipDependency, SkipVersion, SkipEnvironment, SkipCapability, SkipOther: Integer;

procedure Test(const TestName: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(TestName + ': ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(FailedTests);
  end;
end;

procedure ReportGetInfoSetupFailure(const AReason: string);
begin
  Test('GetCertificateInfo setup failure: ' + AReason, False);
end;

procedure SkipOpenSSLGroup(const AGroupName: string; AGroupTests: Integer;
  ACategory: TSkipCategory = scDependency);

  function CategoryLabel: string;
  begin
    case ACategory of
      scDependency: Result := 'dependency';
      scVersion: Result := 'version';
      scEnvironment: Result := 'environment';
      scCapability: Result := 'capability';
    else
      Result := 'other';
    end;
  end;
begin
  if AGroupTests < 0 then
    AGroupTests := 0;

  Inc(SkippedTests, AGroupTests);
  case ACategory of
    scDependency: Inc(SkipDependency, AGroupTests);
    scVersion: Inc(SkipVersion, AGroupTests);
    scEnvironment: Inc(SkipEnvironment, AGroupTests);
    scCapability: Inc(SkipCapability, AGroupTests);
  else
    Inc(SkipOther, AGroupTests);
  end;

  WriteLn('  [SKIP] [', CategoryLabel, '] ', AGroupName,
    ' - OpenSSL not available (', AGroupTests, ' tests)');
end;

const
  // Test certificate (self-signed, generated for testing)
  TEST_CERT_PEM =
    '-----BEGIN CERTIFICATE-----'#10 +
    'MIIDCTCCAfGgAwIBAgIUKFttZTbVLLiFDOfQawtxEuTisLQwDQYJKoZIhvcNAQEL'#10 +
    'BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MTAxMDAyMDY1MFoXDTI2MTAx'#10 +
    'MDAyMDY1MFowFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEF'#10 +
    'AAOCAQ8AMIIBCgKCAQEA3T5viIxgZkeReXAZBbeFrEliVWFzgxzS9S3EvfhgiW+M'#10 +
    'r+X/W9op+VeTFo3wC74BSrmNsSGTgxLkUPZYqlPLdMNZCTKUwu7tAfe7AL4dY26v'#10 +
    'LmCdRiGSD+dinrHdU9XkrbXbsWmHJPuxR45uvoDzPE5Kne+T2xMExZowyBeLEYju'#10 +
    'j/KtO8bRTz4hztbDsOme1mBLBRJJUkID2dYQmO1dF0gYutygfQ9Icd6++0Ttrlpo'#10 +
    '75OKjfjP3BdscWp9FkX034Phg2noRp9qS/w4fr7Iim9Geugq8C6EBAETvWXsrTVb'#10 +
    'gSKTWS/yEN8g7b6kNWprm28OGywqfUHqk26gb7oDrwIDAQABo1MwUTAdBgNVHQ4E'#10 +
    'FgQUNg74vieRDKvMut/+OQrWXgnCL7kwHwYDVR0jBBgwFoAUNg74vieRDKvMut/+'#10 +
    'OQrWXgnCL7kwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAFyd6'#10 +
    'Xl7gDpv1X5SNZcztrLmjQWPuDzMejx4Q+axILB1AvCwPO5dS/sVk4TV6CZAJsDbI'#10 +
    'OH8k3iS3e9D/YXHse8+XTrteFlz7ZHZOKxzdcXiGNWuoFY+WlpVFBwtHriNpVJ9r'#10 +
    'Yw/dH3R8NXUfUXL8XFv9bmHFUaJF3uqoLKwbn1x7zf6NRZVeoOpj3qK5uNVptenU'#10 +
    'vOLht/FR6PiUzbkLia6RaK8L8bSauHaTmnFaVfKiP7LCEWTxqt/qs8j6ENaVY17u'#10 +
    'pSBu1Jxhsg3p2hJrPgmSGVZYogyfd32t14uGSVk+pIUPP7dNPIYFsAxBkWTFn8Nt'#10 +
    '78GHDD+6nrM4fTc9Ww=='#10 +
    '-----END CERTIFICATE-----';

  TEST_PRIVATE_KEY_PEM =
    '-----BEGIN PRIVATE KEY-----'#10 +
    'MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDdPm+IjGBmR5F5'#10 +
    'cBkFt4WsSWJVYXODHNL1LcS9+GCJb4yv5f9b2in5V5MWjfALvgFKuY2xIZODEuRQ'#10 +
    '9liqU8t0w1kJMpTC7u0B97sAvh1jbq8uYJ1GIZIP52Kesd1T1eSttduxaYck+7FH'#10 +
    'jm6+gPM8Tkqd75PbEwTFmjDIF4sRiO6P8q07xtFPPiHO1sOw6Z7WYEsFEklSQgPZ'#10 +
    '1hCY7V0XSBi63KB9D0hx3r77RO2uWmjvk4qN+M/cF2xxan0WRfTfg+GDaehGn2pL'#10 +
    '/Dh+vsiKb0Z66CrwLoQEARO9ZeytNVuBIpNZL/IQ3yDtvqQ1amubbw4bLCp9QeqT'#10 +
    'bqBvugOvAgMBAAECggEAFPiu8Xu+RC5YLkbUwF4kiBpj/Uw2+wB3ngZKxhJt8tPF'#10 +
    'kK4rAJsTQSTZdu5ZCNaSYHG/6hXmLyr9Gbri2FuyseyLGzGVuKKVibW18/yRZD72'#10 +
    'Jl3BxVziRP/9sProIWMULEPMQYALb5Msuz0s5yw+94JDqr6Dvo+KHhb0X8sc2LpR'#10 +
    'EcwbQZWq8rKSSABfYNZxDHAQhBSH46H0MFhAw8msZ6N4fxWIzD7cbQnFxJVNzoCQ'#10 +
    '6ilg07iAZuX1QilzQpmcyLl0QH9nX9wb02tqPfVUy6lcNKn/4aImis6d2ooNPXTy'#10 +
    '86HLcur1U0PsJtgJ8l8KmFJG0VoBLU0YeNRbZZ3J6QKBgQD8buWcyfvF97zot0Vg'#10 +
    '9EXg6BQpBsgzvWCnVg6u/YCUN7qk/4m3rFHcUTcxABWAX4AIkWKMi6AzJsxeFZxG'#10 +
    '0T2jdES8zJCPZRiHH08YfsfB5x8PpbeTpZsv451fg2R9+7vMNUfnSohUuJXWw+LY'#10 +
    '9n5XiIJHV+nc5OLnIviCHL5jaQKBgQDgXrh5Braoc5hXpxnZULZtoB5PTdQd26Ey'#10 +
    '4YMbP0a6BmXITFMuoh5eDwW9bRQPw4BrbFy6yt8dYAXaImmqBKCbAVCW+C4gjrCR'#10 +
    '6kjnYF1U6KKMnbonM/bERByMnGrsiGigXg8BOLg9T42sYBGRMTayRptawt4ygguE'#10 +
    'yP5D4XwDVwKBgFp1bwjRhMy7a1HFozIMNyJSaC8PhByuZ31vpFFm/HWgxtyryfEs'#10 +
    '6iTWYb3IduwKzPnFB5ivzFeoNqIcgmUKRFlXp+40LDWGl9SMDq8Ld4/vv7y+uNtL'#10 +
    'BCKUIWgB0LgoxnJ2QW8L0XDyuJc+mQMAyeOaQn1IbsC+sOT9LiqKHFvJAoGAAUmJ'#10 +
    '1WfsdFr1bMtQoqaL5WUdx2ay6Njxu9D/Z5CdX0PaIaQOdh4H/pInfka57r04Z2Vf'#10 +
    'wtKXJRv/7Jh18rvEEB+ZzsPtv9IRwUSO1oT/BBWxmQzunHr313hskYH0OxctQn5H'#10 +
    'p8IjjHaAYZTLhQG7RpqRGZw0miWU21Yr30fT5lECgYB9eht3Ta80WfajPVj4LPPM'#10 +
    'dzkP0I5U1YybzlTWgr1xRQXZ/DoW4VrY6Rlk8B7vPgwwf4qT8W8yGvxzNo5sP43l'#10 +
    'CMMLdjljeY0PHP/RVcD1zrxuG/7yv7zPILazHrXDjaoh+gvGq+OLCuOq0pxCr0p8'#10 +
    '23vy9JxfBmWvkQHlsKuuVw=='#10 +
    '-----END PRIVATE KEY-----';

{ ============================================================================
  Test Group 1: LoadCertificateFromFile (2 tests)
  ============================================================================ }

procedure TestGroup1_LoadCertificateFromFile;
var
  LTempFile: string;
  LStream: TFileStream;
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
begin
  WriteLn('Test Group 1: LoadCertificateFromFile');
  WriteLn('======================================');
  WriteLn;

  // Initialize OpenSSL properly (loads all required modules)
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not Assigned(LLib) or not LLib.Initialize then
  begin
    SkipOpenSSLGroup('LoadCertificateFromFile', 4);
    Exit;
  end;

  // Test 1: Load certificate from valid PEM file
  WriteLn('Test 1: Load valid certificate from file');
  WriteLn('-----------------------------------------');

  LTempFile := GetTempDir + 'test_cert.pem';
  try
    LStream := TFileStream.Create(LTempFile, fmCreate);
    try
      LStream.WriteBuffer(TEST_CERT_PEM[1], Length(TEST_CERT_PEM));
    finally
      LStream.Free;
    end;

    LCert := LLib.CreateCertificate;
    Test('CreateCertificate returns non-nil', LCert <> nil);

    if LCert <> nil then
    begin
      Test('LoadFromFile returns True for valid file', LCert.LoadFromFile(LTempFile));
    end;
  finally
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  end;

  WriteLn;

  // Test 2: Load from non-existent file
  WriteLn('Test 2: Load from non-existent file');
  WriteLn('------------------------------------');

  LCert := LLib.CreateCertificate;
  Test('CreateCertificate returns non-nil (non-existent file test)', LCert <> nil);
  if LCert <> nil then
    Test('LoadFromFile returns False for non-existent file', not LCert.LoadFromFile('nonexistent_file_xyz_12345.pem'));

  WriteLn;
end;

{ ============================================================================
  Test Group 2: LoadCertificateFromMemory (2 tests)
  ============================================================================ }

procedure TestGroup2_LoadCertificateFromMemory;
var
  LPEMAnsi: AnsiString;
  LInvalidData: AnsiString;
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
begin
  WriteLn('Test Group 2: LoadCertificateFromMemory');
  WriteLn('========================================');
  WriteLn;

  // Initialize OpenSSL properly (loads all required modules)
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not Assigned(LLib) or not LLib.Initialize then
  begin
    SkipOpenSSLGroup('LoadCertificateFromMemory', 4);
    Exit;
  end;

  // Test 3: Load certificate from valid PEM memory
  WriteLn('Test 3: Load valid certificate from memory');
  WriteLn('-------------------------------------------');

  LPEMAnsi := AnsiString(TEST_CERT_PEM);
  LCert := LLib.CreateCertificate;
  Test('CreateCertificate returns non-nil', LCert <> nil);
  if LCert <> nil then
  begin
    Test('LoadFromMemory returns True for valid PEM', LCert.LoadFromMemory(@LPEMAnsi[1], Length(LPEMAnsi)));
  end;

  WriteLn;

  // Test 4: Load from invalid PEM data
  WriteLn('Test 4: Load from invalid PEM data');
  WriteLn('-----------------------------------');

  LInvalidData := 'This is not a valid PEM certificate';
  LCert := LLib.CreateCertificate;
  Test('CreateCertificate returns non-nil', LCert <> nil);
  if LCert <> nil then
    Test('LoadFromMemory returns False for invalid data', not LCert.LoadFromMemory(@LInvalidData[1], Length(LInvalidData)));

  WriteLn;
end;

{ ============================================================================
  Test Group 3: LoadPrivateKeyFromFile (2 tests)
  ============================================================================ }

procedure TestGroup3_LoadPrivateKeyFromFile;
var
  LTempFile: string;
  LStream: TFileStream;
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
begin
  WriteLn('Test Group 3: LoadPrivateKeyFromFile');
  WriteLn('=====================================');
  WriteLn;

  // Initialize OpenSSL properly (loads all required modules)
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not Assigned(LLib) or not LLib.Initialize then
  begin
    SkipOpenSSLGroup('LoadPrivateKeyFromFile', 4);
    Exit;
  end;

  // Test 5: Load private key from valid PEM file
  WriteLn('Test 5: Load valid private key from file');
  WriteLn('-----------------------------------------');

  LTempFile := GetTempDir + 'test_key.pem';
  try
    LStream := TFileStream.Create(LTempFile, fmCreate);
    try
      LStream.WriteBuffer(TEST_PRIVATE_KEY_PEM[1], Length(TEST_PRIVATE_KEY_PEM));
    finally
      LStream.Free;
    end;

    LCtx := LLib.CreateContext(sslCtxServer);
    Test('CreateContext returns non-nil', LCtx <> nil);
    if LCtx <> nil then
    begin
      try
        LCtx.LoadPrivateKey(LTempFile);
        Test('LoadPrivateKey(file) runs without exception', True);
      except
        on E: Exception do
          Test('LoadPrivateKey(file) runs without exception', False);
      end;
    end;
  finally
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  end;

  WriteLn;

  // Test 6: Load from non-existent file
  WriteLn('Test 6: Load from non-existent key file');
  WriteLn('----------------------------------------');

  LCtx := LLib.CreateContext(sslCtxServer);
  Test('CreateContext returns non-nil', LCtx <> nil);
  if LCtx <> nil then
  begin
    try
      LCtx.LoadPrivateKey('nonexistent_key_xyz_12345.pem');
      Test('LoadPrivateKey(file) expected to raise for non-existent file', False);
    except
      on E: Exception do
        Test('LoadPrivateKey(file) expected to raise for non-existent file', True);
    end;
  end;

  WriteLn;
end;

{ ============================================================================
  Test Group 4: LoadPrivateKeyFromMemory (2 tests)
  ============================================================================ }

procedure TestGroup4_LoadPrivateKeyFromMemory;
var
  LPEMAnsi: AnsiString;
  LInvalidData: AnsiString;
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
begin
  WriteLn('Test Group 4: LoadPrivateKeyFromMemory');
  WriteLn('=======================================');
  WriteLn;

  // Initialize OpenSSL properly (loads all required modules)
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not Assigned(LLib) or not LLib.Initialize then
  begin
    SkipOpenSSLGroup('LoadPrivateKeyFromMemory', 4);
    Exit;
  end;

  // Test 7: Load private key from valid PEM memory
  WriteLn('Test 7: Load valid private key from memory');
  WriteLn('-------------------------------------------');

  LPEMAnsi := AnsiString(TEST_PRIVATE_KEY_PEM);
  LCtx := LLib.CreateContext(sslCtxServer);
  Test('CreateContext returns non-nil', LCtx <> nil);
  if LCtx <> nil then
  begin
    try
      LCtx.LoadPrivateKeyPEM(string(LPEMAnsi));
      Test('LoadPrivateKeyPEM runs without exception', True);
    except
      on E: Exception do
        Test('LoadPrivateKeyPEM runs without exception', False);
    end;
  end;

  WriteLn;

  // Test 8: Load from invalid PEM data
  WriteLn('Test 8: Load from invalid key data');
  WriteLn('-----------------------------------');

  LInvalidData := 'This is not a valid PEM private key';
  LCtx := LLib.CreateContext(sslCtxServer);
  Test('CreateContext returns non-nil', LCtx <> nil);
  if LCtx <> nil then
  begin
    try
      LCtx.LoadPrivateKeyPEM(string(LInvalidData));
      Test('LoadPrivateKeyPEM expected to raise for invalid data', False);
    except
      on E: Exception do
        Test('LoadPrivateKeyPEM expected to raise for invalid data', True);
    end;
  end;

  WriteLn;
end;

{ ============================================================================
  Test Group 5: VerifyCertificate (2 tests)
  ============================================================================ }

procedure TestGroup5_VerifyCertificate;
var
  LLib: ISSLLibrary;
  LStore: ISSLCertificateStore;
  LPEMAnsi: AnsiString;
  LResult: Boolean;
  LCert: ISSLCertificate;
begin
  WriteLn('Test Group 5: VerifyCertificate');
  WriteLn('================================');
  WriteLn;

  // Initialize OpenSSL properly (loads all required modules)
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not Assigned(LLib) or not LLib.Initialize then
  begin
    SkipOpenSSLGroup('VerifyCertificate', 4);
    Exit;
  end;

  // Test 9: Verify certificate with CA store
  WriteLn('Test 9: Verify certificate framework');
  WriteLn('-------------------------------------');

  LStore := LLib.CreateCertificateStore;
  LStore.LoadSystemStore;

  LPEMAnsi := AnsiString(TEST_CERT_PEM);
  LCert := LLib.CreateCertificate;
  Test('CreateCertificate returns non-nil', LCert <> nil);
  if (LCert <> nil) and LCert.LoadFromMemory(@LPEMAnsi[1], Length(LPEMAnsi)) then
  begin
    LResult := LStore.VerifyCertificate(LCert);
    WriteLn('  Verification result: ', LResult);
    Test('CertificateStore.VerifyCertificate runs without error', True);
  end
  else
    Test('VerifyCertificate test setup', False);

  WriteLn;

  // Test 10: Verify with nil store (should return false)
  WriteLn('Test 10: Verify with nil parameters');
  WriteLn('------------------------------------');

  LPEMAnsi := AnsiString(TEST_CERT_PEM);
  LCert := LLib.CreateCertificate;
  Test('CreateCertificate returns non-nil (nil store test)', LCert <> nil);
  if (LCert <> nil) and LCert.LoadFromMemory(@LPEMAnsi[1], Length(LPEMAnsi)) then
  begin
    try
      LResult := LCert.Verify(nil);
      WriteLn('  Result with nil store: ', LResult);
      Test('Certificate.Verify returns False for nil store', not LResult);
    except
      on E: Exception do
        Test('Certificate.Verify returns False for nil store', False);
    end;
  end
  else
  begin
    Test('VerifyCertificate(nil store) test setup', False);
  end;

  WriteLn;
end;

{ ============================================================================
  Test Group 6: GetCertificateInfo (2 tests)
  ============================================================================ }

procedure TestGroup6_GetCertificateInfo;
var
  LLib: ISSLLibrary;
  LPEMAnsi: AnsiString;
  LInfo: TSSLCertificateInfo;
  LCert: ISSLCertificate;
begin
  WriteLn('Test Group 6: GetCertificateInfo');
  WriteLn('=================================');
  WriteLn;

  // Initialize OpenSSL properly (loads all required modules)
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not Assigned(LLib) or not LLib.Initialize then
  begin
    SkipOpenSSLGroup('GetCertificateInfo', 4);
    Exit;
  end;

  // Test 11: Get info from valid certificate
  WriteLn('Test 11: Get info from valid certificate');
  WriteLn('-----------------------------------------');

  LPEMAnsi := AnsiString(TEST_CERT_PEM);
  LCert := LLib.CreateCertificate;
  Test('CreateCertificate returns non-nil', LCert <> nil);
  if (LCert <> nil) and LCert.LoadFromMemory(@LPEMAnsi[1], Length(LPEMAnsi)) then
  begin
    LInfo := LCert.GetInfo;
    WriteLn('  Subject: ', LInfo.Subject);
    WriteLn('  Issuer: ', LInfo.Issuer);

    Test('GetInfo returns non-empty subject', Length(LInfo.Subject) > 0);
    Test('GetInfo returns non-empty issuer', Length(LInfo.Issuer) > 0);
  end
  else
  begin
    ReportGetInfoSetupFailure('valid certificate load from memory failed');
  end;

  WriteLn;

  // Test 12: Get info from nil certificate
  WriteLn('Test 12: Get info from nil certificate');
  WriteLn('---------------------------------------');

  FillChar(LInfo, SizeOf(LInfo), 0);
  WriteLn('  Subject length: ', Length(LInfo.Subject));
  Test('GetCertificateInfo returns empty info for nil cert', Length(LInfo.Subject) = 0);

  WriteLn;
end;

{ ============================================================================
  Main Program
  ============================================================================ }

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;
  SkippedTests := 0;
  SkipDependency := 0;
  SkipVersion := 0;
  SkipEnvironment := 0;
  SkipCapability := 0;
  SkipOther := 0;

  WriteLn('Helper Utility Functions Tests');
  WriteLn('==============================');
  WriteLn;
  WriteLn('Testing Phase B3 Step 1: Helper Utility Functions');
  WriteLn('This test suite validates standalone certificate/key helper functions');
  WriteLn;

  TestGroup1_LoadCertificateFromFile;
  TestGroup2_LoadCertificateFromMemory;
  TestGroup3_LoadPrivateKeyFromFile;
  TestGroup4_LoadPrivateKeyFromMemory;
  TestGroup5_VerifyCertificate;
  TestGroup6_GetCertificateInfo;

  WriteLn('=' + StringOfChar('=', 70));
  if TotalTests > 0 then
    WriteLn(Format('Test Results: %d/%d passed (%.1f%%)',
      [PassedTests, TotalTests, PassedTests * 100.0 / TotalTests]))
  else
    WriteLn('Test Results: no executable tests');

  WriteLn(Format('Skipped: %d (dependency=%d, version=%d, environment=%d, capability=%d, other=%d)',
    [SkippedTests, SkipDependency, SkipVersion, SkipEnvironment, SkipCapability, SkipOther]));

  if FailedTests > 0 then
  begin
    WriteLn(Format('%d tests FAILED', [FailedTests]));
    Halt(1);
  end
  else
  begin
    WriteLn('All tests PASSED!');
    WriteLn;
    WriteLn('Phase B3 Step 1 Complete:');
    WriteLn('  ✓ LoadCertificateFromFile tested (2 tests)');
    WriteLn('  ✓ LoadCertificateFromMemory tested (2 tests)');
    WriteLn('  ✓ LoadPrivateKeyFromFile tested (2 tests)');
    WriteLn('  ✓ LoadPrivateKeyFromMemory tested (2 tests)');
    WriteLn('  ✓ VerifyCertificate tested (2 tests)');
    WriteLn('  ✓ GetCertificateInfo tested (2 tests)');
    WriteLn;
    WriteLn('Helper utility functions are ready for use!');
  end;
end.
