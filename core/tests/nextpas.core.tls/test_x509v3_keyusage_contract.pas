program test_x509v3_keyusage_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.x509v3;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

procedure TestKeyUsageHelperShouldAttachAndBeReadable;
var
  LCert: PX509;
  LAdded: Boolean;
  LUsageMask: Cardinal;
  LBeforeExtCount: Integer;
  LAfterExtCount: Integer;
  LKeyUsageIndex: Integer;
begin
  WriteLn;
  WriteLn('=== X509AddKeyUsage contract ===');

  LCert := X509_new();
  if LCert = nil then
  begin
    AssertTrue('X509_new should return non-nil', False, 'X509_new returned nil');
    Exit;
  end;

  try
    if Assigned(X509_set_version) then
      X509_set_version(LCert, 2);

    LBeforeExtCount := X509_get_ext_count(LCert);

    LAdded := X509AddKeyUsage(LCert, KU_DIGITAL_SIGNATURE or KU_KEY_ENCIPHERMENT);
    LAfterExtCount := X509_get_ext_count(LCert);
    LKeyUsageIndex := X509_get_ext_by_NID(LCert, NID_key_usage, -1);
    LUsageMask := X509_get_key_usage(LCert);

    AssertTrue('X509AddKeyUsage should report success', LAdded);
    AssertTrue('Extension count should increase by one',
      LAfterExtCount = LBeforeExtCount + 1,
      'before=' + IntToStr(LBeforeExtCount) + ', after=' + IntToStr(LAfterExtCount));
    AssertTrue('KeyUsage extension should be queryable by NID',
      LKeyUsageIndex >= 0,
      'index=' + IntToStr(LKeyUsageIndex));
    AssertTrue('KeyUsage should include digitalSignature', (LUsageMask and KU_DIGITAL_SIGNATURE) <> 0,
      'usage=' + IntToHex(LUsageMask, 4));
    AssertTrue('KeyUsage should include keyEncipherment', (LUsageMask and KU_KEY_ENCIPHERMENT) <> 0,
      'usage=' + IntToHex(LUsageMask, 4));
  finally
    X509_free(LCert);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509V3 KeyUsage Helper Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('x509v3 keyusage contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLX509;
      LoadX509V3Functions(GetCryptoLibHandle);

      if (not Assigned(X509_new)) or
         (not Assigned(X509_free)) or
         (not Assigned(X509_get_key_usage)) or
         (not Assigned(X509_get_ext_count)) or
         (not Assigned(X509_get_ext_by_NID)) or
         (not Assigned(X509V3_EXT_conf_nid)) then
      begin
        MarkSkip('x509v3 keyusage contract', 'required symbols unavailable');
      end
      else
        TestKeyUsageHelperShouldAttachAndBeReadable;
    end;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
