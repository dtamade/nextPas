program test_pkcs12_d2i_symbol_contract;

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

procedure TestLoadPKCS12FromFileShouldDegradeWhenD2IIsUnavailable;
var
  LOriginalD2IPKCS12Bio: Td2i_PKCS12_bio;
  LTempFile: string;
  LLoadRaised: Boolean;
  LLoadDetail: string;
  LLoadResult: Boolean;
  LKey: PEVP_PKEY;
  LCert: PX509;
  LCAs: PSTACK_OF_X509;
begin
  WriteLn;
  WriteLn('=== PKCS12 d2i symbol guard ===');

  LTempFile := GetTempDir(False) + 'fafafa_pkcs12_d2i_symbol_contract.p12';
  if not WriteTempTextFile(LTempFile, 'not-a-real-pkcs12') then
  begin
    MarkSkip('pkcs12 d2i symbol contract', 'failed to create temp file');
    Exit;
  end;

  LOriginalD2IPKCS12Bio := d2i_PKCS12_bio;
  LLoadRaised := False;
  LLoadDetail := '';
  LLoadResult := False;
  LKey := nil;
  LCert := nil;
  LCAs := nil;

  d2i_PKCS12_bio := nil;
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
    d2i_PKCS12_bio := LOriginalD2IPKCS12Bio;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  end;

  AssertTrue(
    'LoadPKCS12FromFile should not raise when d2i_PKCS12_bio is unavailable',
    not LLoadRaised,
    LLoadDetail
  );
  AssertTrue(
    'LoadPKCS12FromFile should return False when d2i_PKCS12_bio is unavailable',
    not LLoadResult,
    'expected False PKCS12 load result when d2i_PKCS12_bio is unavailable'
  );
  AssertTrue(
    'LoadPKCS12FromFile should keep outputs nil when d2i_PKCS12_bio is unavailable',
    (LKey = nil) and (LCert = nil) and (LCAs = nil),
    'expected nil key/cert/CA outputs when d2i_PKCS12_bio is unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('PKCS12 d2i Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('pkcs12 d2i symbol contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_free) then
      begin
        MarkSkip('pkcs12 d2i symbol contract', 'BIO file helpers unavailable on this runtime');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('pkcs12 d2i symbol contract', 'PKCS module unavailable on this runtime');
      end
      else if not Assigned(d2i_PKCS12_bio) then
      begin
        MarkSkip('pkcs12 d2i symbol contract', 'd2i_PKCS12_bio unavailable on this runtime');
      end
      else
        TestLoadPKCS12FromFileShouldDegradeWhenD2IIsUnavailable;
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
