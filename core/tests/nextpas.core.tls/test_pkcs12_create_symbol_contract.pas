program test_pkcs12_create_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.pkcs;

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

procedure TestSavePKCS12ToFileShouldDegradeWhenPKCS12CreateIsUnavailable;
var
  LOriginalPKCS12Create: TPKCS12_create;
  LOutputFile: string;
  LSaveRaised: Boolean;
  LSaveDetail: string;
  LSaveResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PKCS12 create symbol guard ===');

  LOriginalPKCS12Create := PKCS12_create;
  LOutputFile := GetTempDir(False) + 'fafafa_pkcs12_create_symbol_contract.p12';
  if FileExists(LOutputFile) then
    DeleteFile(LOutputFile);

  LSaveRaised := False;
  LSaveDetail := '';
  LSaveResult := False;

  PKCS12_create := nil;
  try
    try
      LSaveResult := SavePKCS12ToFile(LOutputFile, '', PEVP_PKEY(Pointer(1)), PX509(Pointer(1)), nil);
    except
      on E: Exception do
      begin
        LSaveRaised := True;
        LSaveDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PKCS12_create := LOriginalPKCS12Create;
    if FileExists(LOutputFile) then
      DeleteFile(LOutputFile);
  end;

  AssertTrue(
    'SavePKCS12ToFile should not raise when PKCS12_create is unavailable',
    not LSaveRaised,
    LSaveDetail
  );
  AssertTrue(
    'SavePKCS12ToFile should return False when PKCS12_create is unavailable',
    not LSaveResult,
    'expected False PKCS12 save result when PKCS12_create is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS12 Create Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs12 create symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs12 create symbol contract', 'BIO file helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs12 create symbol contract', 'PKCS module unavailable on this runtime');
      end
      else if not Assigned(PKCS12_create) then
      begin
        MarkSkip('pkcs12 create symbol contract', 'PKCS12_create unavailable on this runtime');
      end
      else
        TestSavePKCS12ToFileShouldDegradeWhenPKCS12CreateIsUnavailable;
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
