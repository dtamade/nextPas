program test_x509v3_basicconstraints_pathlen_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
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

procedure TestBasicConstraintsPathLenShouldBeObservable;
var
  LCert: PX509;
  LAdded: Boolean;
  LPathLen: Int64;
begin
  WriteLn;
  WriteLn('=== X509AddBasicConstraints pathLen contract ===');

  LCert := X509_new();
  if LCert = nil then
  begin
    AssertTrue('X509_new should return non-nil', False, 'X509_new returned nil');
    Exit;
  end;

  try
    if Assigned(X509_set_version) then
      X509_set_version(LCert, 2);

    LAdded := X509AddBasicConstraints(LCert, True, 0);
    LPathLen := X509_get_pathlen(LCert);

    AssertTrue('X509AddBasicConstraints should report success', LAdded);
    AssertTrue('PathLen should be 0 when helper is called with PathLen=0',
      LPathLen = 0,
      'pathLen=' + IntToStr(LPathLen));
  finally
    X509_free(LCert);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509V3 BasicConstraints PathLen Contract');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('x509v3 basicconstraints pathlen contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLX509;
      LoadX509V3Functions(GetCryptoLibHandle);

      if (not Assigned(X509_new)) or
         (not Assigned(X509_free)) or
         (not Assigned(X509_get_pathlen)) or
         (not Assigned(X509V3_EXT_i2d)) then
      begin
        MarkSkip('x509v3 basicconstraints pathlen contract', 'required symbols unavailable');
      end
      else
        TestBasicConstraintsPathLenShouldBeObservable;
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
