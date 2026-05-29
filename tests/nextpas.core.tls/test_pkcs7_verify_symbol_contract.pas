program test_pkcs7_verify_symbol_contract;

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

procedure TestVerifyPKCS7SignedDataShouldDegradeWhenPKCS7VerifyIsUnavailable;
var
  LOriginalPKCS7Verify: TPKCS7_verify;
  LData: TBytes;
  LVerifyRaised: Boolean;
  LVerifyDetail: string;
  LVerifyResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PKCS7 verify symbol guard ===');

  LData := BytesOf('pkcs7-verify-symbol-contract');
  LOriginalPKCS7Verify := PKCS7_verify;

  LVerifyRaised := False;
  LVerifyDetail := '';
  LVerifyResult := False;

  PKCS7_verify := nil;
  try
    try
      LVerifyResult := VerifyPKCS7SignedData(LData, PPKCS7(Pointer(1)), nil, 0);
    except
      on E: Exception do
      begin
        LVerifyRaised := True;
        LVerifyDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PKCS7_verify := LOriginalPKCS7Verify;
  end;

  AssertTrue(
    'VerifyPKCS7SignedData should not raise when PKCS7_verify is unavailable',
    not LVerifyRaised,
    LVerifyDetail
  );
  AssertTrue(
    'VerifyPKCS7SignedData should return False when PKCS7_verify is unavailable',
    not LVerifyResult,
    'expected False PKCS7 verify result when PKCS7_verify is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS7 Verify Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs7 verify symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_new) or
         not Assigned(BIO_s_null) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs7 verify symbol contract', 'BIO verify helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs7 verify symbol contract', 'PKCS module unavailable on this runtime');
      end
      else if not Assigned(PKCS7_verify) then
      begin
        MarkSkip('pkcs7 verify symbol contract', 'PKCS7_verify unavailable on this runtime');
      end
      else
        TestVerifyPKCS7SignedDataShouldDegradeWhenPKCS7VerifyIsUnavailable;
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
