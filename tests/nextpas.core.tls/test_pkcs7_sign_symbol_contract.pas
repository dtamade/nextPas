program test_pkcs7_sign_symbol_contract;

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

procedure TestCreatePKCS7SignedDataShouldDegradeWhenPKCS7SignIsUnavailable;
var
  LOriginalPKCS7Sign: TPKCS7_sign;
  LData: TBytes;
  LSignRaised: Boolean;
  LSignDetail: string;
  LSignResult: PPKCS7;
begin
  WriteLn;
  WriteLn('=== PKCS7 sign symbol guard ===');

  LData := BytesOf('pkcs7-sign-symbol-contract');
  LOriginalPKCS7Sign := PKCS7_sign;

  LSignRaised := False;
  LSignDetail := '';
  LSignResult := nil;

  PKCS7_sign := nil;
  try
    try
      LSignResult := CreatePKCS7SignedData(LData, PX509(Pointer(1)), PEVP_PKEY(Pointer(1)), 0);
    except
      on E: Exception do
      begin
        LSignRaised := True;
        LSignDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PKCS7_sign := LOriginalPKCS7Sign;
  end;

  AssertTrue(
    'CreatePKCS7SignedData should not raise when PKCS7_sign is unavailable',
    not LSignRaised,
    LSignDetail
  );
  AssertTrue(
    'CreatePKCS7SignedData should return nil when PKCS7_sign is unavailable',
    LSignResult = nil,
    'expected nil PKCS7 result when PKCS7_sign is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS7 Sign Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs7 sign symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs7 sign symbol contract', 'BIO memory helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs7 sign symbol contract', 'PKCS module unavailable on this runtime');
      end
      else if not Assigned(PKCS7_sign) then
      begin
        MarkSkip('pkcs7 sign symbol contract', 'PKCS7_sign unavailable on this runtime');
      end
      else
        TestCreatePKCS7SignedDataShouldDegradeWhenPKCS7SignIsUnavailable;
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
