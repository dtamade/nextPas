program test_cms_encrypt_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.cms;

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

procedure TestCMSEncryptDataShouldDegradeWhenCMSEncryptIsUnavailable;
var
  LOriginalCMSEncrypt: TCMS_encrypt;
  LData: TBytes;
  LEncryptRaised: Boolean;
  LEncryptDetail: string;
  LEncryptResult: PCMS_ContentInfo;
begin
  WriteLn;
  WriteLn('=== CMS encrypt symbol guard ===');

  LData := BytesOf('cms-encrypt-symbol-contract');
  LOriginalCMSEncrypt := CMS_encrypt;

  LEncryptRaised := False;
  LEncryptDetail := '';
  LEncryptResult := nil;

  CMS_encrypt := nil;
  try
    try
      LEncryptResult := CMSEncryptData(LData, PSTACK_OF_X509(Pointer(1)), PEVP_CIPHER(Pointer(1)), 0);
    except
      on E: Exception do
      begin
        LEncryptRaised := True;
        LEncryptDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    CMS_encrypt := LOriginalCMSEncrypt;
  end;

  AssertTrue(
    'CMSEncryptData should not raise when CMS_encrypt is unavailable',
    not LEncryptRaised,
    LEncryptDetail
  );
  AssertTrue(
    'CMSEncryptData should return nil when CMS_encrypt is unavailable',
    LEncryptResult = nil,
    'expected nil CMS encrypt result when CMS_encrypt is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('CMS Encrypt Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('cms encrypt symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('cms encrypt symbol contract', 'BIO encrypt helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLCMS(GetCryptoLibHandle) then
      begin
        MarkSkip('cms encrypt symbol contract', 'CMS module unavailable on this runtime');
      end
      else if not Assigned(CMS_encrypt) then
      begin
        MarkSkip('cms encrypt symbol contract', 'CMS_encrypt unavailable on this runtime');
      end
      else
        TestCMSEncryptDataShouldDegradeWhenCMSEncryptIsUnavailable;
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
