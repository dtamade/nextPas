program test_pem_key_save_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
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

procedure TestPEMKeySaveHelpersShouldDegradeWhenWriteSymbolsAreUnavailable;
var
  LOriginalPEMWriteBioPrivateKey: TPEM_write_bio_PrivateKey;
  LOriginalPEMWriteBioPUBKEY: TPEM_write_bio_PUBKEY;
  LTempPrivateOut: string;
  LTempPublicOut: string;
  LSavePrivateRaised: Boolean;
  LSavePublicRaised: Boolean;
  LSavePrivateDetail: string;
  LSavePublicDetail: string;
  LSavePrivateResult: Boolean;
  LSavePublicResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PEM key save symbol guard ===');

  LTempPrivateOut := GetTempDir(False) + 'fafafa_pem_key_save_symbol_contract_private.pem';
  LTempPublicOut := GetTempDir(False) + 'fafafa_pem_key_save_symbol_contract_public.pem';

  LOriginalPEMWriteBioPrivateKey := PEM_write_bio_PrivateKey;
  LOriginalPEMWriteBioPUBKEY := PEM_write_bio_PUBKEY;

  LSavePrivateRaised := False;
  LSavePublicRaised := False;
  LSavePrivateDetail := '';
  LSavePublicDetail := '';
  LSavePrivateResult := False;
  LSavePublicResult := False;

  PEM_write_bio_PrivateKey := nil;
  try
    try
      LSavePrivateResult := SavePrivateKeyToPEM(LTempPrivateOut, PEVP_PKEY(Pointer(1)), '');
    except
      on E: Exception do
      begin
        LSavePrivateRaised := True;
        LSavePrivateDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PEM_write_bio_PrivateKey := LOriginalPEMWriteBioPrivateKey;
  end;

  PEM_write_bio_PUBKEY := nil;
  try
    try
      LSavePublicResult := SavePublicKeyToPEM(LTempPublicOut, PEVP_PKEY(Pointer(1)));
    except
      on E: Exception do
      begin
        LSavePublicRaised := True;
        LSavePublicDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PEM_write_bio_PUBKEY := LOriginalPEMWriteBioPUBKEY;
    if FileExists(LTempPrivateOut) then
      DeleteFile(LTempPrivateOut);
    if FileExists(LTempPublicOut) then
      DeleteFile(LTempPublicOut);
  end;

  AssertTrue(
    'SavePrivateKeyToPEM should not raise when PEM_write_bio_PrivateKey is unavailable',
    not LSavePrivateRaised,
    LSavePrivateDetail
  );
  AssertTrue(
    'SavePrivateKeyToPEM should return False when PEM_write_bio_PrivateKey is unavailable',
    not LSavePrivateResult,
    'expected False write result when PEM_write_bio_PrivateKey is unavailable'
  );
  AssertTrue(
    'SavePublicKeyToPEM should not raise when PEM_write_bio_PUBKEY is unavailable',
    not LSavePublicRaised,
    LSavePublicDetail
  );
  AssertTrue(
    'SavePublicKeyToPEM should return False when PEM_write_bio_PUBKEY is unavailable',
    not LSavePublicResult,
    'expected False write result when PEM_write_bio_PUBKEY is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PEM Key Save Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pem key save symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pem key save symbol contract', 'BIO file helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pem key save symbol contract', 'PEM module unavailable on this runtime');
      end
      else if not Assigned(PEM_write_bio_PrivateKey) or
              not Assigned(PEM_write_bio_PUBKEY) then
      begin
        MarkSkip('pem key save symbol contract', 'PEM key save helpers unavailable on this runtime');
      end
      else
        TestPEMKeySaveHelpersShouldDegradeWhenWriteSymbolsAreUnavailable;
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
