program test_cert_utils_sign_certificate_with_key_evp_sha256_nil_result_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalEVPSHA256: TEVP_sha256 = nil;

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

function ReturnNilEVPSHA256: PEVP_MD; cdecl;
begin
  Result := nil;
end;

procedure InstallEVPSHA256NilResultWrapper;
begin
  EVP_sha256 := @ReturnNilEVPSHA256;
end;

procedure RestoreOriginalEVPSHA256;
begin
  EVP_sha256 := GOriginalEVPSHA256;
end;

function BuildSelfSignedOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'sign-helper-evp-sha256-nil-self.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
end;

function BuildCAOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'sign-helper-evp-sha256-nil-root.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := True;
  Result.ValidDays := 30;
end;

function BuildLeafOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'sign-helper-evp-sha256-nil-leaf.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.IsCA := False;
  Result.ValidDays := 30;
end;

procedure WarmupGenerateSelfSigned(const AOptions: TCertGenOptions);
var
  LCertPEM: string;
  LKeyPEM: string;
begin
  if not TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM) then
    raise Exception.Create('GenerateSelfSigned warmup returned False');
  if (LCertPEM = '') or (LKeyPEM = '') then
    raise Exception.Create('GenerateSelfSigned warmup returned empty PEM output');
end;

procedure WarmupGenerateSignedMaterials(
  out ACACertPEM: string;
  out ACAKeyPEM: string
);
var
  LCAOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
begin
  LCAOptions := BuildCAOptions;
  if not TCertificateUtils.GenerateSelfSigned(LCAOptions, ACACertPEM, ACAKeyPEM) then
    raise Exception.Create('GenerateSelfSigned warmup returned False');
  if (ACACertPEM = '') or (ACAKeyPEM = '') then
    raise Exception.Create('GenerateSelfSigned warmup returned empty CA material');

  LLeafOptions := BuildLeafOptions;
  if not TCertificateUtils.GenerateSigned(
    LLeafOptions,
    ACACertPEM,
    ACAKeyPEM,
    LLeafCertPEM,
    LLeafKeyPEM
  ) then
    raise Exception.Create('GenerateSigned warmup returned False');
  if (LLeafCertPEM = '') or (LLeafKeyPEM = '') then
    raise Exception.Create('GenerateSigned warmup returned empty leaf material');
end;

procedure AssertGenerateSelfSignedFailureWhenEVPSHA256ReturnsNil(
  const AName: string;
  const AOptions: TCertGenOptions
);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LCertPEM: string;
  LKeyPEM: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTrySimpleRaised: Boolean;
  LTrySimpleDetail: string;
  LTrySimpleResult: Boolean;
begin
  try
    InstallEVPSHA256NilResultWrapper;

    LRaised := False;
    LControlled := False;
    LDetail := '';
    LCertPEM := '';
    LKeyPEM := '';
    try
      TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLCertError;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised,
      'expected GenerateSelfSigned(...) to fail');
    AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);

    InstallEVPSHA256NilResultWrapper;

    LTryRaised := False;
    LTryDetail := '';
    LTryResult := True;
    LCertPEM := 'sentinel-cert';
    LKeyPEM := 'sentinel-key';
    try
      LTryResult := TCertificateUtils.TryGenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
    except
      on E: Exception do
      begin
        LTryRaised := True;
        LTryDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' TryGenerateSelfSigned should not raise', not LTryRaised, LTryDetail);
    AssertTrue(AName + ' TryGenerateSelfSigned should return False', not LTryResult,
      'expected TryGenerateSelfSigned to return False');
    AssertTrue(AName + ' TryGenerateSelfSigned should clear cert output', LCertPEM = '',
      'expected cleared certificate output');
    AssertTrue(AName + ' TryGenerateSelfSigned should clear key output', LKeyPEM = '',
      'expected cleared key output');

    InstallEVPSHA256NilResultWrapper;

    LTrySimpleRaised := False;
    LTrySimpleDetail := '';
    LTrySimpleResult := True;
    LCertPEM := 'sentinel-cert';
    LKeyPEM := 'sentinel-key';
    try
      LTrySimpleResult := TCertificateUtils.TryGenerateSelfSignedSimple(
        AOptions.CommonName,
        AOptions.Organization,
        AOptions.ValidDays,
        LCertPEM,
        LKeyPEM
      );
    except
      on E: Exception do
      begin
        LTrySimpleRaised := True;
        LTrySimpleDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' TryGenerateSelfSignedSimple should not raise',
      not LTrySimpleRaised, LTrySimpleDetail);
    AssertTrue(AName + ' TryGenerateSelfSignedSimple should return False', not LTrySimpleResult,
      'expected TryGenerateSelfSignedSimple to return False');
    AssertTrue(AName + ' TryGenerateSelfSignedSimple should clear cert output', LCertPEM = '',
      'expected cleared certificate output');
    AssertTrue(AName + ' TryGenerateSelfSignedSimple should clear key output', LKeyPEM = '',
      'expected cleared key output');
  finally
    RestoreOriginalEVPSHA256;
  end;
end;

procedure AssertGenerateSignedFailureWhenEVPSHA256ReturnsNil(
  const AName: string;
  const AOptions: TCertGenOptions;
  const ACACertPEM, ACAKeyPEM: string
);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LCertPEM: string;
  LKeyPEM: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
begin
  try
    InstallEVPSHA256NilResultWrapper;

    LRaised := False;
    LControlled := False;
    LDetail := '';
    LCertPEM := '';
    LKeyPEM := '';
    try
      TCertificateUtils.GenerateSigned(AOptions, ACACertPEM, ACAKeyPEM, LCertPEM, LKeyPEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLCertError;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised,
      'expected GenerateSigned(...) to fail');
    AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);

    InstallEVPSHA256NilResultWrapper;

    LTryRaised := False;
    LTryDetail := '';
    LTryResult := True;
    LCertPEM := 'sentinel-cert';
    LKeyPEM := 'sentinel-key';
    try
      LTryResult := TCertificateUtils.TryGenerateSigned(
        AOptions,
        ACACertPEM,
        ACAKeyPEM,
        LCertPEM,
        LKeyPEM
      );
    except
      on E: Exception do
      begin
        LTryRaised := True;
        LTryDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' TryGenerateSigned should not raise', not LTryRaised, LTryDetail);
    AssertTrue(AName + ' TryGenerateSigned should return False', not LTryResult,
      'expected TryGenerateSigned to return False');
    AssertTrue(AName + ' TryGenerateSigned should clear cert output', LCertPEM = '',
      'expected cleared certificate output');
    AssertTrue(AName + ' TryGenerateSigned should clear key output', LKeyPEM = '',
      'expected cleared key output');
  finally
    RestoreOriginalEVPSHA256;
  end;
end;

procedure TestGenerateSelfSignedShouldFailWhenEVPSHA256ReturnsNil;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned EVP_sha256 nil-result family ===');

  if (not Assigned(X509_sign)) or
     (not Assigned(EVP_sha256)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(PEM_write_bio_PrivateKey)) then
  begin
    MarkSkip('certificate utils sign helper EVP_sha256 nil-result selfsigned family contract',
      'required baseline OpenSSL signing/export helpers are unavailable');
    Exit;
  end;

  LOptions := BuildSelfSignedOptions;
  WarmupGenerateSelfSigned(LOptions);

  AssertGenerateSelfSignedFailureWhenEVPSHA256ReturnsNil(
    'GenerateSelfSigned when EVP_sha256 returns nil',
    LOptions
  );
end;

procedure TestGenerateSignedShouldFailWhenEVPSHA256ReturnsNil;
var
  LLeafOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSigned EVP_sha256 nil-result family ===');

  if (not Assigned(X509_sign)) or
     (not Assigned(EVP_sha256)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(PEM_write_bio_PrivateKey)) then
  begin
    MarkSkip('certificate utils sign helper EVP_sha256 nil-result signed family contract',
      'required baseline OpenSSL signing/export helpers are unavailable');
    Exit;
  end;

  LLeafOptions := BuildLeafOptions;
  WarmupGenerateSignedMaterials(LCACertPEM, LCAKeyPEM);

  AssertGenerateSignedFailureWhenEVPSHA256ReturnsNil(
    'GenerateSigned when EVP_sha256 returns nil',
    LLeafOptions,
    LCACertPEM,
    LCAKeyPEM
  );
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils SignCertificateWithKey EVP_sha256 Nil-Result Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils sign helper EVP_sha256 nil-result family contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
      if not LoadEVP(GetCryptoLibHandle) then
        raise Exception.Create('failed to load EVP support');
    end;

    if SkippedTests = 0 then
    begin
      GOriginalEVPSHA256 := EVP_sha256;
      try
        TestGenerateSelfSignedShouldFailWhenEVPSHA256ReturnsNil;
        TestGenerateSignedShouldFailWhenEVPSHA256ReturnsNil;
      finally
        EVP_sha256 := GOriginalEVPSHA256;
      end;
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
      WriteLn;
      WriteLn('[FATAL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
