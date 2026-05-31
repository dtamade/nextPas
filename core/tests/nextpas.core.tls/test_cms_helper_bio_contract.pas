program test_cms_helper_bio_contract;

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

procedure TestCMSHelpersShouldDegradeWhenBIODependenciesAreUnavailable;
var
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSNull: TBIO_s_null;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
  LData: TBytes;
  LSignRaised: Boolean;
  LSignDetail: string;
  LSignResult: PCMS_ContentInfo;
  LEncryptRaised: Boolean;
  LEncryptDetail: string;
  LEncryptResult: PCMS_ContentInfo;
  LVerifyRaised: Boolean;
  LVerifyDetail: string;
  LVerifyResult: Boolean;
  LDecryptRaised: Boolean;
  LDecryptDetail: string;
  LDecryptResult: TBytes;
begin
  WriteLn;
  WriteLn('=== CMS helper BIO guard ===');

  LData := BytesOf('not-a-real-cms-payload');

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSNull := BIO_s_null;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIOFree := BIO_free;

  LSignRaised := False;
  LSignDetail := '';
  LSignResult := nil;

  BIO_new_mem_buf := nil;
  BIO_free := nil;
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
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
    BIO_free := LOriginalBIOFree;
  end;

  LEncryptRaised := False;
  LEncryptDetail := '';
  LEncryptResult := nil;

  BIO_new_mem_buf := nil;
  BIO_free := nil;
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
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
    BIO_free := LOriginalBIOFree;
  end;

  LVerifyRaised := False;
  LVerifyDetail := '';
  LVerifyResult := False;

  BIO_new := nil;
  BIO_s_null := nil;
  BIO_free := nil;
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
    BIO_new := LOriginalBIONew;
    BIO_s_null := LOriginalBIOSNull;
    BIO_free := LOriginalBIOFree;
  end;

  LDecryptRaised := False;
  LDecryptDetail := '';
  SetLength(LDecryptResult, 0);

  BIO_s_mem := nil;
  BIO_free := nil;
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
    BIO_s_mem := LOriginalBIOSMem;
    BIO_free := LOriginalBIOFree;
  end;

  AssertTrue(
    'CMSSignData should not raise when BIO memory helpers are unavailable',
    not LSignRaised,
    LSignDetail
  );
  AssertTrue(
    'CMSSignData should return nil when BIO memory helpers are unavailable',
    LSignResult = nil,
    'expected nil CMS result when BIO_new_mem_buf/BIO_free are unavailable'
  );
  AssertTrue(
    'CMSEncryptData should not raise when BIO memory helpers are unavailable',
    not LEncryptRaised,
    LEncryptDetail
  );
  AssertTrue(
    'CMSEncryptData should return nil when BIO memory helpers are unavailable',
    LEncryptResult = nil,
    'expected nil CMS result when BIO_new_mem_buf/BIO_free are unavailable'
  );
  AssertTrue(
    'CMSVerifySignature should not raise when BIO sink helpers are unavailable',
    not LVerifyRaised,
    LVerifyDetail
  );
  AssertTrue(
    'CMSVerifySignature should return False when BIO sink helpers are unavailable',
    not LVerifyResult,
    'expected False verify result when BIO_new/BIO_free are unavailable'
  );
  AssertTrue(
    'CMSDecryptData should not raise when BIO output helpers are unavailable',
    not LDecryptRaised,
    LDecryptDetail
  );
  AssertTrue(
    'CMSDecryptData should return empty bytes when BIO output helpers are unavailable',
    Length(LDecryptResult) = 0,
    'expected empty decrypt result when BIO_s_mem/BIO_free are unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('CMS Helper BIO Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('cms helper bio contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_new) or
         not Assigned(BIO_s_null) or
         not Assigned(BIO_s_mem) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('cms helper bio contract', 'BIO helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLCMS(GetCryptoLibHandle) then
      begin
        MarkSkip('cms helper bio contract', 'CMS module unavailable on this runtime');
      end
      else
        TestCMSHelpersShouldDegradeWhenBIODependenciesAreUnavailable;
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
