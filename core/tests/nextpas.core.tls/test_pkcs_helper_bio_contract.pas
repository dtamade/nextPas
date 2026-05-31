program test_pkcs_helper_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
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

function WriteTempTextFile(const AFileName, AContent: string): Boolean;
var
  LStream: TFileStream;
  LBytes: UTF8String;
begin
  Result := False;
  ForceDirectories(ExtractFileDir(AFileName));
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LBytes := UTF8String(AContent);
    if Length(LBytes) > 0 then
      LStream.WriteBuffer(LBytes[1], Length(LBytes));
    Result := True;
  finally
    LStream.Free;
  end;
end;

procedure TestPKCSHelpersShouldDegradeWhenBIODependenciesAreUnavailable;
var
  LOriginalBIONewFile: TBIO_new_file;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSNull: TBIO_s_null;
  LOriginalBIOFree: TBIO_free;
  LTempFile: string;
  LData: TBytes;
  LKey: PEVP_PKEY;
  LCert: PX509;
  LCAs: PSTACK_OF_X509;
  LLoadRaised: Boolean;
  LLoadDetail: string;
  LLoadResult: Boolean;
  LSignRaised: Boolean;
  LSignDetail: string;
  LSignResult: PPKCS7;
  LVerifyRaised: Boolean;
  LVerifyDetail: string;
  LVerifyResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PKCS helper BIO guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_pkcs_helper_bio_contract.p12';
  if not WriteTempTextFile(LTempFile, 'not-a-real-pkcs12') then
  begin
    MarkSkip('PKCS helper BIO guard', 'failed to create temp file');
    Exit;
  end;

  LData := BytesOf('not-a-real-pkcs-data');

  LOriginalBIONewFile := BIO_new_file;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSNull := BIO_s_null;
  LOriginalBIOFree := BIO_free;

  LKey := nil;
  LCert := nil;
  LCAs := nil;
  LLoadRaised := False;
  LLoadDetail := '';
  LLoadResult := False;

  BIO_new_file := nil;
  BIO_free := nil;
  try
    try
      LLoadResult := LoadPKCS12FromFile(LTempFile, '', LKey, LCert, LCAs);
    except
      on E: Exception do
      begin
        LLoadRaised := True;
        LLoadDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    BIO_new_file := LOriginalBIONewFile;
    BIO_free := LOriginalBIOFree;
  end;

  LSignRaised := False;
  LSignDetail := '';
  LSignResult := nil;

  BIO_new_mem_buf := nil;
  BIO_free := nil;
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
      LVerifyResult := VerifyPKCS7SignedData(LData, PPKCS7(Pointer(1)), nil, 0);
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
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  end;

  AssertTrue(
    'LoadPKCS12FromFile should not raise when BIO file helpers are unavailable',
    not LLoadRaised,
    LLoadDetail
  );
  AssertTrue(
    'LoadPKCS12FromFile should return False when BIO file helpers are unavailable',
    not LLoadResult,
    'expected False load result when BIO_new_file/BIO_free are unavailable'
  );
  AssertTrue(
    'LoadPKCS12FromFile should keep outputs nil when BIO file helpers are unavailable',
    (LKey = nil) and (LCert = nil) and (LCAs = nil),
    'expected nil key/cert/CA outputs when BIO_new_file/BIO_free are unavailable'
  );
  AssertTrue(
    'CreatePKCS7SignedData should not raise when BIO memory helpers are unavailable',
    not LSignRaised,
    LSignDetail
  );
  AssertTrue(
    'CreatePKCS7SignedData should return nil when BIO memory helpers are unavailable',
    LSignResult = nil,
    'expected nil PKCS7 result when BIO_new_mem_buf/BIO_free are unavailable'
  );
  AssertTrue(
    'VerifyPKCS7SignedData should not raise when BIO sink helpers are unavailable',
    not LVerifyRaised,
    LVerifyDetail
  );
  AssertTrue(
    'VerifyPKCS7SignedData should return False when BIO sink helpers are unavailable',
    not LVerifyResult,
    'expected False verify result when BIO_new/BIO_s_null/BIO_free are unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS Helper BIO Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs helper bio contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_new) or
         not Assigned(BIO_s_null) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs helper bio contract', 'BIO helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs helper bio contract', 'PKCS module unavailable on this runtime');
      end
      else
        TestPKCSHelpersShouldDegradeWhenBIODependenciesAreUnavailable;
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
