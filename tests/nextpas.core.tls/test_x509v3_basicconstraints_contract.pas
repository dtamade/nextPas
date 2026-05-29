program test_x509v3_basicconstraints_contract;

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

procedure TestBasicConstraintsHelperShouldAttachExtension;
var
  LCert: PX509;
  LAdded: Boolean;
  LBeforeExtCount: Integer;
  LAfterExtCount: Integer;
  LBasicConstraintsIdx: Integer;
begin
  WriteLn;
  WriteLn('=== X509AddBasicConstraints contract ===');

  LCert := X509_new();
  if LCert = nil then
  begin
    AssertTrue('X509_new should return non-nil', False, 'X509_new returned nil');
    Exit;
  end;

  try
    LBeforeExtCount := X509_get_ext_count(LCert);

    try
      LAdded := X509AddBasicConstraints(LCert, True, -1);
    except
      on E: Exception do
      begin
        AssertTrue('X509AddBasicConstraints should not raise exception', False,
          E.ClassName + ': ' + E.Message);
        Exit;
      end;
    end;

    LAfterExtCount := X509_get_ext_count(LCert);
    LBasicConstraintsIdx := X509_get_ext_by_NID(LCert, NID_basic_constraints, -1);

    AssertTrue('X509AddBasicConstraints should report success', LAdded);
    AssertTrue('Extension count should increase by one',
      LAfterExtCount = LBeforeExtCount + 1,
      'before=' + IntToStr(LBeforeExtCount) + ', after=' + IntToStr(LAfterExtCount));
    AssertTrue('BasicConstraints extension should be queryable by NID',
      LBasicConstraintsIdx >= 0,
      'index=' + IntToStr(LBasicConstraintsIdx));
  finally
    X509_free(LCert);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509V3 BasicConstraints Helper Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('x509v3 helper contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLX509;
      LoadX509V3Functions(GetCryptoLibHandle);

      if (not Assigned(X509_new)) or
         (not Assigned(X509_free)) or
         (not Assigned(X509_get_ext_count)) or
         (not Assigned(X509_get_ext_by_NID)) or
         (not Assigned(X509V3_EXT_i2d)) then
      begin
        MarkSkip('x509v3 helper contract',
          'required x509/x509v3 symbols unavailable');
      end
      else
        TestBasicConstraintsHelperShouldAttachExtension;
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
