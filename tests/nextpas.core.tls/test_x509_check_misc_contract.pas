program test_x509_check_misc_contract;

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

procedure TestX509CheckMiscSymbolsAndCallability;
var
  LIssuer, LSubject: PX509;
  LPurposeRes: Integer;
  LTrustRes: Integer;
  LIssuedRes: Integer;
begin
  WriteLn;
  WriteLn('=== X509 misc check contracts ===');

  AssertTrue('X509_check_purpose symbol should be loaded', Assigned(X509_check_purpose));
  AssertTrue('X509_check_trust symbol should be loaded', Assigned(X509_check_trust));
  AssertTrue('X509_check_issued symbol should be loaded', Assigned(X509_check_issued));

  if (not Assigned(X509_check_purpose)) or
     (not Assigned(X509_check_trust)) or
     (not Assigned(X509_check_issued)) then
    Exit;

  LIssuer := X509_new();
  LSubject := X509_new();
  if (LIssuer = nil) or (LSubject = nil) then
  begin
    AssertTrue('X509_new should return non-nil', False, 'X509_new returned nil cert');
    Exit;
  end;

  try
    LPurposeRes := X509_check_purpose(LSubject, 1, 0);
    AssertTrue('X509_check_purpose should be callable', (LPurposeRes >= -1) and (LPurposeRes <= 1), 'result=' + IntToStr(LPurposeRes));

    LTrustRes := X509_check_trust(LSubject, 1, 0);
    AssertTrue('X509_check_trust should be callable', LTrustRes >= 0, 'result=' + IntToStr(LTrustRes));

    LIssuedRes := X509_check_issued(LIssuer, LSubject);
    AssertTrue('X509_check_issued should be callable', LIssuedRes >= 0, 'result=' + IntToStr(LIssuedRes));
  finally
    X509_free(LSubject);
    X509_free(LIssuer);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509 Misc Check Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      MarkSkip('x509 misc check contract', 'OpenSSL core unavailable')
    else
    begin
      LoadOpenSSLX509;

      if (not Assigned(X509_new)) or (not Assigned(X509_free)) then
        MarkSkip('x509 misc check contract', 'required x509 base symbols unavailable')
      else
        TestX509CheckMiscSymbolsAndCallability;
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
