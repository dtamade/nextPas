program test_cms_decrypt_symbol_contract;

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

procedure TestCMSDecryptDataShouldDegradeWhenCMSDecryptIsUnavailable;
var
  LOriginalCMSDecrypt: TCMS_decrypt;
  LDecryptRaised: Boolean;
  LDecryptDetail: string;
  LDecryptResult: TBytes;
begin
  WriteLn;
  WriteLn('=== CMS decrypt symbol guard ===');

  LOriginalCMSDecrypt := CMS_decrypt;

  LDecryptRaised := False;
  LDecryptDetail := '';
  SetLength(LDecryptResult, 0);

  CMS_decrypt := nil;
  try
    try
      LDecryptResult := CMSDecryptData(PCMS_ContentInfo(Pointer(1)), PEVP_PKEY(Pointer(1)), nil, 0);
    except
      on E: Exception do
      begin
        LDecryptRaised := True;
        LDecryptDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    CMS_decrypt := LOriginalCMSDecrypt;
  end;

  AssertTrue(
    'CMSDecryptData should not raise when CMS_decrypt is unavailable',
    not LDecryptRaised,
    LDecryptDetail
  );
  AssertTrue(
    'CMSDecryptData should return empty bytes when CMS_decrypt is unavailable',
    Length(LDecryptResult) = 0,
    'expected empty CMS decrypt result when CMS_decrypt is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('CMS Decrypt Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('cms decrypt symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new) or
         not Assigned(BIO_s_null) or
         not Assigned(BIO_s_mem) or
         not Assigned(BIO_free) or
         not Assigned(BIO_read) then
      begin
        MarkSkip('cms decrypt symbol contract', 'BIO decrypt helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLCMS(GetCryptoLibHandle) then
      begin
        MarkSkip('cms decrypt symbol contract', 'CMS module unavailable on this runtime');
      end
      else if not Assigned(CMS_decrypt) then
      begin
        MarkSkip('cms decrypt symbol contract', 'CMS_decrypt unavailable on this runtime');
      end
      else
        TestCMSDecryptDataShouldDegradeWhenCMSDecryptIsUnavailable;
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
