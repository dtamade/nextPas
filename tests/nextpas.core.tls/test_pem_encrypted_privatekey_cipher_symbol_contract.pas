program test_pem_encrypted_privatekey_cipher_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem;

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

procedure TestEncryptedPrivateKeySaveShouldDegradeWhenCipherSymbolIsUnavailable;
var
  LOriginalEVPAes256Cbc: TEVP_aes_256_cbc;
  LTempOut: string;
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PEM encrypted private key cipher symbol guard ===');

  LTempOut := GetTempDir(False) + 'fafafa_pem_encrypted_privatekey_cipher_symbol_contract.pem';
  LOriginalEVPAes256Cbc := EVP_aes_256_cbc;
  LRaised := False;
  LDetail := '';
  LResult := False;

  EVP_aes_256_cbc := nil;
  try
    try
      LResult := SavePrivateKeyToPEM(LTempOut, PEVP_PKEY(Pointer(1)), 'testpass');
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    EVP_aes_256_cbc := LOriginalEVPAes256Cbc;
    if FileExists(LTempOut) then
      DeleteFile(LTempOut);
  end;

  AssertTrue(
    'SavePrivateKeyToPEM encrypted branch should not raise when EVP_aes_256_cbc is unavailable',
    not LRaised,
    LDetail
  );
  AssertTrue(
    'SavePrivateKeyToPEM encrypted branch should return False when EVP_aes_256_cbc is unavailable',
    not LResult,
    'expected False write result when EVP_aes_256_cbc is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PEM Encrypted PrivateKey Cipher Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pem encrypted privatekey cipher symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pem encrypted privatekey cipher symbol contract', 'BIO file helpers unavailable on this runtime');
      end
      else if not LoadEVP(GetCryptoLibHandle) then
      begin
        MarkSkip('pem encrypted privatekey cipher symbol contract', 'EVP module unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pem encrypted privatekey cipher symbol contract', 'PEM module unavailable on this runtime');
      end
      else if not Assigned(EVP_aes_256_cbc) or
              not Assigned(PEM_write_bio_PrivateKey) then
      begin
        MarkSkip('pem encrypted privatekey cipher symbol contract', 'required encrypted private-key helpers unavailable on this runtime');
      end
      else
        TestEncryptedPrivateKeySaveShouldDegradeWhenCipherSymbolIsUnavailable;
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
