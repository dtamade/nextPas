program test_cms_verify_symbol_contract;

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

procedure TestCMSVerifySignatureShouldDegradeWhenCMSVerifyIsUnavailable;
var
  LOriginalCMSVerify: TCMS_verify;
  LData: TBytes;
  LVerifyRaised: Boolean;
  LVerifyDetail: string;
  LVerifyResult: Boolean;
begin
  WriteLn;
  WriteLn('=== CMS verify symbol guard ===');

  LData := BytesOf('cms-verify-symbol-contract');
  LOriginalCMSVerify := CMS_verify;

  LVerifyRaised := False;
  LVerifyDetail := '';
  LVerifyResult := False;

  CMS_verify := nil;
  try
    try
      LVerifyResult := CMSVerifySignature(LData, PCMS_ContentInfo(Pointer(1)), nil, nil, 0);
    except
      on E: Exception do
      begin
        LVerifyRaised := True;
        LVerifyDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    CMS_verify := LOriginalCMSVerify;
  end;

  AssertTrue(
    'CMSVerifySignature should not raise when CMS_verify is unavailable',
    not LVerifyRaised,
    LVerifyDetail
  );
  AssertTrue(
    'CMSVerifySignature should return False when CMS_verify is unavailable',
    not LVerifyResult,
    'expected False CMS verify result when CMS_verify is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('CMS Verify Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('cms verify symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_new) or
         not Assigned(BIO_s_null) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('cms verify symbol contract', 'BIO verify helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLCMS(GetCryptoLibHandle) then
      begin
        MarkSkip('cms verify symbol contract', 'CMS module unavailable on this runtime');
      end
      else if not Assigned(CMS_verify) then
      begin
        MarkSkip('cms verify symbol contract', 'CMS_verify unavailable on this runtime');
      end
      else
        TestCMSVerifySignatureShouldDegradeWhenCMSVerifyIsUnavailable;
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
