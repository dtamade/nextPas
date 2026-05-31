program test_pem_key_read_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
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

procedure TestPEMKeyReadHelpersShouldDegradeWhenReadSymbolsAreUnavailable;
var
  LOriginalPEMReadBioPrivateKey: TPEM_read_bio_PrivateKey;
  LOriginalPEMReadBioPUBKEY: TPEM_read_bio_PUBKEY;
  LTempFile: string;
  LMemoryData: TBytes;
  LLoadPrivateFileRaised: Boolean;
  LLoadPrivateMemoryRaised: Boolean;
  LLoadPublicFileRaised: Boolean;
  LLoadPrivateFileDetail: string;
  LLoadPrivateMemoryDetail: string;
  LLoadPublicFileDetail: string;
  LPrivateFromFile: PEVP_PKEY;
  LPrivateFromMemory: PEVP_PKEY;
  LPublicFromFile: PEVP_PKEY;
begin
  WriteLn;
  WriteLn('=== PEM key read symbol guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_pem_key_read_symbol_contract.pem';
  if not WriteTempTextFile(LTempFile, 'not-a-real-pem') then
  begin
    MarkSkip('pem key read symbol guard', 'failed to create temp file');
    Exit;
  end;

  LMemoryData := BytesOf('not-a-real-pem');

  LOriginalPEMReadBioPrivateKey := PEM_read_bio_PrivateKey;
  LOriginalPEMReadBioPUBKEY := PEM_read_bio_PUBKEY;

  LLoadPrivateFileRaised := False;
  LLoadPrivateMemoryRaised := False;
  LLoadPublicFileRaised := False;
  LLoadPrivateFileDetail := '';
  LLoadPrivateMemoryDetail := '';
  LLoadPublicFileDetail := '';
  LPrivateFromFile := nil;
  LPrivateFromMemory := nil;
  LPublicFromFile := nil;

  PEM_read_bio_PrivateKey := nil;
  try
    try
      LPrivateFromFile := LoadPrivateKeyFromPEM(LTempFile);
    except
      on E: Exception do
      begin
        LLoadPrivateFileRaised := True;
        LLoadPrivateFileDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    try
      LPrivateFromMemory := LoadPrivateKeyFromMemory(LMemoryData);
    except
      on E: Exception do
      begin
        LLoadPrivateMemoryRaised := True;
        LLoadPrivateMemoryDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PEM_read_bio_PrivateKey := LOriginalPEMReadBioPrivateKey;
  end;

  PEM_read_bio_PUBKEY := nil;
  try
    try
      LPublicFromFile := LoadPublicKeyFromPEM(LTempFile);
    except
      on E: Exception do
      begin
        LLoadPublicFileRaised := True;
        LLoadPublicFileDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PEM_read_bio_PUBKEY := LOriginalPEMReadBioPUBKEY;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  end;

  AssertTrue(
    'LoadPrivateKeyFromPEM should not raise when PEM_read_bio_PrivateKey is unavailable',
    not LLoadPrivateFileRaised,
    LLoadPrivateFileDetail
  );
  AssertTrue(
    'LoadPrivateKeyFromPEM should return nil when PEM_read_bio_PrivateKey is unavailable',
    LPrivateFromFile = nil,
    'expected nil key when PEM_read_bio_PrivateKey is unavailable'
  );
  AssertTrue(
    'LoadPrivateKeyFromMemory should not raise when PEM_read_bio_PrivateKey is unavailable',
    not LLoadPrivateMemoryRaised,
    LLoadPrivateMemoryDetail
  );
  AssertTrue(
    'LoadPrivateKeyFromMemory should return nil when PEM_read_bio_PrivateKey is unavailable',
    LPrivateFromMemory = nil,
    'expected nil key when PEM_read_bio_PrivateKey is unavailable'
  );
  AssertTrue(
    'LoadPublicKeyFromPEM should not raise when PEM_read_bio_PUBKEY is unavailable',
    not LLoadPublicFileRaised,
    LLoadPublicFileDetail
  );
  AssertTrue(
    'LoadPublicKeyFromPEM should return nil when PEM_read_bio_PUBKEY is unavailable',
    LPublicFromFile = nil,
    'expected nil key when PEM_read_bio_PUBKEY is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PEM Key Read Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pem key read symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pem key read symbol contract', 'BIO helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pem key read symbol contract', 'PEM module unavailable on this runtime');
      end
      else if not Assigned(PEM_read_bio_PrivateKey) or
              not Assigned(PEM_read_bio_PUBKEY) then
      begin
        MarkSkip('pem key read symbol contract', 'PEM key read helpers unavailable on this runtime');
      end
      else
        TestPEMKeyReadHelpersShouldDegradeWhenReadSymbolsAreUnavailable;
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
