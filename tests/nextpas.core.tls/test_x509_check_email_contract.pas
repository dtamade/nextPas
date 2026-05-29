program test_x509_check_email_contract;

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

procedure TestX509CheckEmailSymbolAndCallability;
var
  LCert: PX509;
  LResult: Integer;
  LEmail: AnsiString;
begin
  WriteLn;
  WriteLn('=== X509_check_email contract ===');

  AssertTrue('X509_check_email symbol should be loaded', Assigned(X509_check_email));

  if not Assigned(X509_check_email) then
    Exit;

  LCert := X509_new();
  if LCert = nil then
  begin
    AssertTrue('X509_new should return non-nil', False, 'X509_new returned nil');
    Exit;
  end;

  try
    LEmail := 'test@example.com';
    LResult := X509_check_email(LCert, PAnsiChar(LEmail), Length(LEmail), 0);
    AssertTrue('X509_check_email should be callable and not match empty cert',
      LResult <> 1,
      'result=' + IntToStr(LResult));
  finally
    X509_free(LCert);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509 check_email Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      MarkSkip('x509 check_email contract', 'OpenSSL core unavailable')
    else
    begin
      LoadOpenSSLX509;

      if (not Assigned(X509_new)) or (not Assigned(X509_free)) then
        MarkSkip('x509 check_email contract', 'required x509 base symbols unavailable')
      else
        TestX509CheckEmailSymbolAndCallability;
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
