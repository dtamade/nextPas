program test_pem_certificate_symbol_contract;

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

procedure TestPEMCertificateHelpersShouldDegradeWhenCertificateSymbolsAreUnavailable;
var
  LOriginalPEMReadBioX509: TPEM_read_bio_X509;
  LOriginalPEMWriteBioX509: TPEM_write_bio_X509;
  LTempFile: string;
  LTempOut: string;
  LMemoryData: TBytes;
  LLoadFileRaised: Boolean;
  LLoadMemoryRaised: Boolean;
  LSaveRaised: Boolean;
  LLoadFileDetail: string;
  LLoadMemoryDetail: string;
  LSaveDetail: string;
  LCertFromFile: PX509;
  LCertFromMemory: PX509;
  LSaveResult: Boolean;
begin
  WriteLn;
  WriteLn('=== PEM certificate symbol guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_pem_certificate_symbol_contract.pem';
  LTempOut := LTempFile + '.out';
  if not WriteTempTextFile(LTempFile, 'not-a-real-pem') then
  begin
    MarkSkip('pem certificate symbol guard', 'failed to create temp file');
    Exit;
  end;

  LMemoryData := BytesOf('not-a-real-pem');

  LOriginalPEMReadBioX509 := PEM_read_bio_X509;
  LOriginalPEMWriteBioX509 := PEM_write_bio_X509;

  LLoadFileRaised := False;
  LLoadMemoryRaised := False;
  LSaveRaised := False;
  LLoadFileDetail := '';
  LLoadMemoryDetail := '';
  LSaveDetail := '';
  LCertFromFile := nil;
  LCertFromMemory := nil;
  LSaveResult := False;

  PEM_read_bio_X509 := nil;
  try
    try
      LCertFromFile := LoadCertificateFromPEM(LTempFile);
    except
      on E: Exception do
      begin
        LLoadFileRaised := True;
        LLoadFileDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    try
      LCertFromMemory := LoadCertificateFromMemory(LMemoryData);
    except
      on E: Exception do
      begin
        LLoadMemoryRaised := True;
        LLoadMemoryDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PEM_read_bio_X509 := LOriginalPEMReadBioX509;
  end;

  PEM_write_bio_X509 := nil;
  try
    try
      LSaveResult := SaveCertificateToPEM(LTempOut, PX509(Pointer(1)));
    except
      on E: Exception do
      begin
        LSaveRaised := True;
        LSaveDetail := E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    PEM_write_bio_X509 := LOriginalPEMWriteBioX509;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
    if FileExists(LTempOut) then
      DeleteFile(LTempOut);
  end;

  AssertTrue(
    'LoadCertificateFromPEM should not raise when PEM_read_bio_X509 is unavailable',
    not LLoadFileRaised,
    LLoadFileDetail
  );
  AssertTrue(
    'LoadCertificateFromPEM should return nil when PEM_read_bio_X509 is unavailable',
    LCertFromFile = nil,
    'expected nil certificate when PEM_read_bio_X509 is unavailable'
  );
  AssertTrue(
    'LoadCertificateFromMemory should not raise when PEM_read_bio_X509 is unavailable',
    not LLoadMemoryRaised,
    LLoadMemoryDetail
  );
  AssertTrue(
    'LoadCertificateFromMemory should return nil when PEM_read_bio_X509 is unavailable',
    LCertFromMemory = nil,
    'expected nil certificate when PEM_read_bio_X509 is unavailable'
  );
  AssertTrue(
    'SaveCertificateToPEM should not raise when PEM_write_bio_X509 is unavailable',
    not LSaveRaised,
    LSaveDetail
  );
  AssertTrue(
    'SaveCertificateToPEM should return False when PEM_write_bio_X509 is unavailable',
    not LSaveResult,
    'expected False write result when PEM_write_bio_X509 is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PEM Certificate Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pem certificate symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pem certificate symbol contract', 'BIO helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pem certificate symbol contract', 'PEM module unavailable on this runtime');
      end
      else if not Assigned(PEM_read_bio_X509) or
              not Assigned(PEM_write_bio_X509) then
      begin
        MarkSkip('pem certificate symbol contract', 'PEM certificate helpers unavailable on this runtime');
      end
      else
        TestPEMCertificateHelpersShouldDegradeWhenCertificateSymbolsAreUnavailable;
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
