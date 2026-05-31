program test_pkcs7_helper_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.stack;

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

function ReadAllBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  SetLength(Result, 0);
  if not FileExists(AFileName) then
    Exit;

  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function LoadTestMaterials(out ASignerCert: PX509; out ASignerKey: PEVP_PKEY;
  out ARecipientCert: PX509; out ARecipientKey: PEVP_PKEY;
  out ARecipientStack: PSTACK_OF_X509): Boolean;
const
  TEST_CERT_DIR = 'tests/certificate/test_certs/';
begin
  Result := False;
  ASignerCert := nil;
  ASignerKey := nil;
  ARecipientCert := nil;
  ARecipientKey := nil;
  ARecipientStack := nil;

  ASignerCert := LoadCertificateFromPEM(TEST_CERT_DIR + 'signer_cert.pem');
  ASignerKey := LoadPrivateKeyFromPEM(TEST_CERT_DIR + 'signer_key.pem');
  ARecipientCert := LoadCertificateFromPEM(TEST_CERT_DIR + 'recipient_cert.pem');
  ARecipientKey := LoadPrivateKeyFromPEM(TEST_CERT_DIR + 'recipient_key.pem');
  if (ASignerCert = nil) or (ASignerKey = nil) or
     (ARecipientCert = nil) or (ARecipientKey = nil) then
    Exit;

  ARecipientStack := PSTACK_OF_X509(CreateStack);
  if (ARecipientStack = nil) or
     not PushToStack(POPENSSL_STACK(ARecipientStack), ARecipientCert) then
    Exit;

  Result := True;
end;

procedure TestPKCS7HelpersShouldDegradeWhenBIODependenciesAreUnavailable;
const
  SIGNED_FIXTURE = 'tests/fixtures/p2/pkcs7/pkcs7_signed_attached_v1.der';
var
  LSignerCert: PX509;
  LSignerKey: PEVP_PKEY;
  LRecipientCert: PX509;
  LRecipientKey: PEVP_PKEY;
  LRecipientStack: PSTACK_OF_X509;
  LFixtureData: TBytes;
  LPlainData: TBytes;
  LEncryptedData: TBytes;
  LOutData: TBytes;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
  LOriginalBIORead: TBIO_read;
  LRaised: Boolean;
  LDetail: string;
  LBytesResult: TBytes;
  LBoolResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PKCS7 helper BIO guard ===');

  if not LoadTestMaterials(LSignerCert, LSignerKey, LRecipientCert, LRecipientKey, LRecipientStack) then
  begin
    MarkSkip('PKCS7 helper BIO guard', 'failed to load PKCS7 test certificates or stack');
    Exit;
  end;

  LFixtureData := ReadAllBytes(SIGNED_FIXTURE);
  if Length(LFixtureData) = 0 then
  begin
    MarkSkip('PKCS7 helper BIO guard', 'signed PKCS7 fixture unavailable');
    Exit;
  end;

  LPlainData := BytesOf('pkcs7-helper-contract-data');
  LEncryptedData := EncryptData(LPlainData, LRecipientStack, EVP_aes_256_cbc(), 0);
  if Length(LEncryptedData) = 0 then
  begin
    MarkSkip('PKCS7 helper BIO guard', 'failed to prepare encrypted PKCS7 sample');
    Exit;
  end;

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIOFree := BIO_free;
  LOriginalBIORead := BIO_read;

  BIO_new_mem_buf := nil;
  BIO_free := nil;
  LRaised := False;
  LDetail := '';
  SetLength(LBytesResult, 0);
  try
    try
      LBytesResult := SignData(LPlainData, LSignerCert, LSignerKey, nil, PKCS7_BINARY);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
    BIO_free := LOriginalBIOFree;
  end;
  AssertTrue(
    'SignData should not raise when BIO input helpers are unavailable',
    not LRaised,
    LDetail
  );
  AssertTrue(
    'SignData should return nil when BIO input helpers are unavailable',
    Length(LBytesResult) = 0,
    'expected empty signed payload when BIO_new_mem_buf/BIO_free are unavailable'
  );

  BIO_new := nil;
  BIO_s_mem := nil;
  BIO_free := nil;
  LRaised := False;
  LDetail := '';
  SetLength(LBytesResult, 0);
  try
    try
      LBytesResult := EncryptData(LPlainData, LRecipientStack, EVP_aes_256_cbc(), 0);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    BIO_new := LOriginalBIONew;
    BIO_s_mem := LOriginalBIOSMem;
    BIO_free := LOriginalBIOFree;
  end;
  AssertTrue(
    'EncryptData should not raise when BIO output constructors are unavailable',
    not LRaised,
    LDetail
  );
  AssertTrue(
    'EncryptData should return nil when BIO output constructors are unavailable',
    Length(LBytesResult) = 0,
    'expected empty encrypted payload when BIO_new/BIO_s_mem/BIO_free are unavailable'
  );

  BIO_new := nil;
  BIO_s_mem := nil;
  BIO_free := nil;
  LRaised := False;
  LDetail := '';
  SetLength(LOutData, 0);
  LBoolResult := False;
  try
    try
      LBoolResult := VerifySignedData(LFixtureData, nil, nil, LOutData, PKCS7_NOVERIFY);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    BIO_new := LOriginalBIONew;
    BIO_s_mem := LOriginalBIOSMem;
    BIO_free := LOriginalBIOFree;
  end;
  AssertTrue(
    'VerifySignedData should not raise when BIO output constructors are unavailable',
    not LRaised,
    LDetail
  );
  AssertTrue(
    'VerifySignedData should return False when BIO output constructors are unavailable',
    not LBoolResult,
    'expected False verify result when BIO_new/BIO_s_mem/BIO_free are unavailable'
  );

  BIO_read := nil;
  BIO_free := nil;
  LRaised := False;
  LDetail := '';
  SetLength(LOutData, 0);
  LBoolResult := False;
  try
    try
      LBoolResult := DecryptData(LEncryptedData, LRecipientCert, LRecipientKey, LOutData, 0);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    BIO_read := LOriginalBIORead;
    BIO_free := LOriginalBIOFree;
  end;
  AssertTrue(
    'DecryptData should not raise when BIO readers are unavailable',
    not LRaised,
    LDetail
  );
  AssertTrue(
    'DecryptData should return False when BIO readers are unavailable',
    not LBoolResult,
    'expected False decrypt result when BIO_read/BIO_free are unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS7 Helper BIO Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs7 helper bio contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not LoadOpenSSLPEM(GetCryptoLibHandle) or
         not LoadEVP(GetCryptoLibHandle) or
         not LoadStackFunctions or
         not LoadPKCS7Functions then
      begin
        MarkSkip('pkcs7 helper bio contract', 'PKCS7 prerequisites unavailable on this runtime');
      end
      else if not Assigned(BIO_new_mem_buf) or
              not Assigned(BIO_new) or
              not Assigned(BIO_s_mem) or
              not Assigned(BIO_free) or
              not Assigned(BIO_read) or
              not Assigned(EVP_aes_256_cbc) then
      begin
        MarkSkip('pkcs7 helper bio contract', 'required BIO/EVP/stack helpers unavailable on this runtime');
      end
      else
        TestPKCS7HelpersShouldDegradeWhenBIODependenciesAreUnavailable;
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
