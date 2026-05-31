program test_pem_helper_bio_contract;

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

procedure TestPEMHelpersShouldDegradeWhenBIODependenciesAreUnavailable;
var
  LOriginalBIONewFile: TBIO_new_file;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIOFree: TBIO_free;
  LTempFile: string;
  LTempOut: string;
  LMemoryData: TBytes;
  LLoadFileRaised: Boolean;
  LSaveFileRaised: Boolean;
  LLoadMemoryRaised: Boolean;
  LLoadFileDetail: string;
  LSaveFileDetail: string;
  LLoadMemoryDetail: string;
  LCertFromFile: PX509;
  LSaveFileResult: Boolean;
  LCertFromMemory: PX509;
begin
  WriteLn;
  WriteLn('=== PEM helper BIO guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_pem_helper_bio_contract.pem';
  LTempOut := LTempFile + '.out';
  if not WriteTempTextFile(LTempFile, 'not-a-real-pem') then
  begin
    MarkSkip('PEM helper BIO guard', 'failed to create temp file');
    Exit;
  end;

  LMemoryData := BytesOf('not-a-real-pem');

  LOriginalBIONewFile := BIO_new_file;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIOFree := BIO_free;

  BIO_new_file := nil;
  BIO_new_mem_buf := nil;
  BIO_free := nil;

  LLoadFileRaised := False;
  LSaveFileRaised := False;
  LLoadMemoryRaised := False;
  LLoadFileDetail := '';
  LSaveFileDetail := '';
  LLoadMemoryDetail := '';
  LCertFromFile := nil;
  LSaveFileResult := False;
  LCertFromMemory := nil;

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
      LSaveFileResult := SaveCertificateToPEM(LTempOut, PX509(Pointer(1)));
    except
      on E: Exception do
      begin
        LSaveFileRaised := True;
        LSaveFileDetail := E.ClassName + ': ' + E.Message;
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
    BIO_new_file := LOriginalBIONewFile;
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
    BIO_free := LOriginalBIOFree;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
    if FileExists(LTempOut) then
      DeleteFile(LTempOut);
  end;

  AssertTrue(
    'LoadCertificateFromPEM should not raise when BIO file helpers are unavailable',
    not LLoadFileRaised,
    LLoadFileDetail
  );
  AssertTrue(
    'LoadCertificateFromPEM should return nil when BIO file helpers are unavailable',
    LCertFromFile = nil,
    'expected nil certificate when BIO_new_file/BIO_free are unavailable'
  );
  AssertTrue(
    'SaveCertificateToPEM should not raise when BIO file helpers are unavailable',
    not LSaveFileRaised,
    LSaveFileDetail
  );
  AssertTrue(
    'SaveCertificateToPEM should return False when BIO file helpers are unavailable',
    not LSaveFileResult,
    'expected False write result when BIO_new_file/BIO_free are unavailable'
  );
  AssertTrue(
    'LoadCertificateFromMemory should not raise when BIO memory helpers are unavailable',
    not LLoadMemoryRaised,
    LLoadMemoryDetail
  );
  AssertTrue(
    'LoadCertificateFromMemory should return nil when BIO memory helpers are unavailable',
    LCertFromMemory = nil,
    'expected nil certificate when BIO_new_mem_buf/BIO_free are unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PEM Helper BIO Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pem helper bio contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pem helper bio contract', 'BIO helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('pem helper bio contract', 'PEM module unavailable on this runtime');
      end
      else
        TestPEMHelpersShouldDegradeWhenBIODependenciesAreUnavailable;
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
