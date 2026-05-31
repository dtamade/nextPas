program test_x509_runtime_exports_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509;

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

procedure TestX509RuntimeExports;
var
  LCert: PX509;
  LCompareRes: Integer;
  LBefore: PASN1_TIME;
  LAfter: PASN1_TIME;
begin
  WriteLn;
  WriteLn('=== X509 runtime export contracts ===');

  AssertTrue('X509_cmp symbol should be loaded', Assigned(X509_cmp));
  AssertTrue('X509_get0_notBefore symbol should be loaded', Assigned(X509_get0_notBefore));
  AssertTrue('X509_get0_notAfter symbol should be loaded', Assigned(X509_get0_notAfter));
  AssertTrue('X509_policy_check symbol should be loaded', Assigned(X509_policy_check));
  AssertTrue('X509_policy_tree_free symbol should be loaded', Assigned(X509_policy_tree_free));
  AssertTrue('X509_policy_tree_level_count symbol should be loaded', Assigned(X509_policy_tree_level_count));
  AssertTrue('X509_policy_tree_get0_level symbol should be loaded', Assigned(X509_policy_tree_get0_level));
  AssertTrue('X509_REVOKED_get0_revocationDate symbol should be loaded', Assigned(X509_REVOKED_get0_revocationDate));
  AssertTrue('X509_REVOKED_get_ext_d2i symbol should be loaded', Assigned(X509_REVOKED_get_ext_d2i));

  if (not Assigned(X509_cmp)) or
     (not Assigned(X509_get0_notBefore)) or
     (not Assigned(X509_get0_notAfter)) then
    Exit;

  LCert := X509_new();
  if LCert = nil then
  begin
    AssertTrue('X509_new should return non-nil', False, 'X509_new returned nil');
    Exit;
  end;

  try
    LCompareRes := X509_cmp(LCert, LCert);
    AssertTrue('X509_cmp should return 0 for same cert', LCompareRes = 0, 'result=' + IntToStr(LCompareRes));

    LBefore := X509_get0_notBefore(LCert);
    AssertTrue('X509_get0_notBefore should be callable', True, 'ptr=' + IntToHex(PtrUInt(LBefore), SizeOf(Pointer) * 2));

    LAfter := X509_get0_notAfter(LCert);
    AssertTrue('X509_get0_notAfter should be callable', True, 'ptr=' + IntToHex(PtrUInt(LAfter), SizeOf(Pointer) * 2));
  finally
    X509_free(LCert);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509 Runtime Export Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      MarkSkip('x509 runtime export contract', 'OpenSSL core unavailable')
    else
    begin
      LoadOpenSSLX509;

      if (not Assigned(X509_new)) or (not Assigned(X509_free)) then
        MarkSkip('x509 runtime export contract', 'required x509 base symbols unavailable')
      else
        TestX509RuntimeExports;
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
