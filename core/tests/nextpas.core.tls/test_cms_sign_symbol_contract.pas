program test_cms_sign_symbol_contract;

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

procedure TestCMSSignDataShouldDegradeWhenCMSSignIsUnavailable;
var
  LOriginalCMSSign: TCMS_sign;
  LData: TBytes;
  LSignRaised: Boolean;
  LSignDetail: string;
  LSignResult: PCMS_ContentInfo;
begin
  WriteLn;
  WriteLn('=== CMS sign symbol guard ===');

  LData := BytesOf('cms-sign-symbol-contract');
  LOriginalCMSSign := CMS_sign;

  LSignRaised := False;
  LSignDetail := '';
  LSignResult := nil;

  CMS_sign := nil;
  try
    try
      LSignResult := CMSSignData(LData, PX509(Pointer(1)), PEVP_PKEY(Pointer(1)), 0);
    except
      on E: Exception do
      begin
        LSignRaised := True;
        LSignDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    CMS_sign := LOriginalCMSSign;
  end;

  AssertTrue(
    'CMSSignData should not raise when CMS_sign is unavailable',
    not LSignRaised,
    LSignDetail
  );
  AssertTrue(
    'CMSSignData should return nil when CMS_sign is unavailable',
    LSignResult = nil,
    'expected nil CMS result when CMS_sign is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('CMS Sign Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('cms sign symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('cms sign symbol contract', 'BIO memory helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLCMS(GetCryptoLibHandle) then
      begin
        MarkSkip('cms sign symbol contract', 'CMS module unavailable on this runtime');
      end
      else if not Assigned(CMS_sign) then
      begin
        MarkSkip('cms sign symbol contract', 'CMS_sign unavailable on this runtime');
      end
      else
        TestCMSSignDataShouldDegradeWhenCMSSignIsUnavailable;
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
