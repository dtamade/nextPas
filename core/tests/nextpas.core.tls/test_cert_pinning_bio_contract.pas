program test_cert_pinning_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert,
  nextpas.core.tls.openssl.cert.builder,
  nextpas.core.tls.cert.pinning,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem;

var
  GLib: ISSLLibrary = nil;
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

function RequireCertificateHandle(const AKeyPair: IKeyPairWithCertificate): PX509;
var
  LCertEx: ICertificateEx;
begin
  if (AKeyPair = nil) or (AKeyPair.Certificate = nil) then
    raise Exception.Create('keypair fixture is missing certificate');
  if not Supports(AKeyPair.Certificate, ICertificateEx, LCertEx) then
    raise Exception.Create('certificate fixture does not support ICertificateEx');

  Result := PX509(LCertEx.X509Handle);
  if Result = nil then
    raise Exception.Create('certificate fixture did not expose a valid PX509 handle');
end;

function ComputePublicKeyHash(ACert: PX509): TBytes;
var
  LPubKey: PEVP_PKEY;
  LSPKILen: Integer;
  LBuffer: PByte;
  LWritePtr: PByte;
begin
  SetLength(Result, 0);

  if ACert = nil then
    Exit;

  LPubKey := X509_get_pubkey(ACert);
  if LPubKey = nil then
    raise Exception.Create('failed to extract public key from test certificate');

  try
    LSPKILen := i2d_PUBKEY(LPubKey, nil);
    if LSPKILen <= 0 then
      raise Exception.Create('failed to determine SPKI DER length for test certificate');

    GetMem(LBuffer, LSPKILen);
    try
      LWritePtr := LBuffer;
      if i2d_PUBKEY(LPubKey, @LWritePtr) <= 0 then
        raise Exception.Create('failed to encode SPKI DER for test certificate');

      SetLength(Result, LSPKILen);
      Move(LBuffer^, Result[0], LSPKILen);
      Result := TCryptoUtils.SHA256(Result);
    finally
      FreeMem(LBuffer);
    end;
  finally
    EVP_PKEY_free(LPubKey);
  end;
end;

procedure AssertValidateCertificateMatches(
  const AName: string;
  AValidator: TPinValidator;
  ACert: PX509
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LRaised := False;
  LDetail := '';
  LResult := False;
  try
    LResult := AValidator.ValidateCertificate(ACert);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return True', LResult,
    'expected matching public-key pin validation to succeed');
end;

procedure AssertValidateCertificateChainMatches(
  const AName: string;
  AValidator: TPinValidator;
  const AChain: array of PX509
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LRaised := False;
  LDetail := '';
  LResult := False;
  try
    LResult := AValidator.ValidateCertificateChain(AChain);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return True', LResult,
    'expected matching public-key chain validation to succeed');
end;

procedure AssertValidateCertificateExMatches(
  const AName: string;
  AValidator: TPinValidatorEx;
  ACert: PX509
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
  LValidation: TPinValidationResult;
begin
  LRaised := False;
  LDetail := '';
  FillChar(LValidation, SizeOf(LValidation), 0);
  LValidation.MatchedPinIndex := -1;
  LResult := False;
  try
    LResult := AValidator.ValidateCertificateEx(ACert, LValidation);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return True', LResult,
    'expected matching public-key pin validation to succeed');
  AssertTrue(AName + ' should mark Success', LValidation.Success,
    'expected ValidateCertificateEx to report success');
  AssertTrue(AName + ' should record matched pin', LValidation.MatchedPinIndex = 0,
    'expected the first configured pin to match');
  AssertTrue(AName + ' should expose public key fingerprint',
    LValidation.PublicKeyFingerprint <> '',
    'expected a populated public key fingerprint');
end;

procedure TestPinningShouldIgnoreUnusedBIOHelpers;
var
  LKeyPair: IKeyPairWithCertificate;
  LValidator: TPinValidator;
  LValidatorEx: TPinValidatorEx;
  LCert: PX509;
  LChain: array[0..0] of PX509;
  LPubKeyHash: TBytes;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Certificate pinning BIO guard ===');

  if (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(X509_get_pubkey)) or
     (not Assigned(i2d_PUBKEY)) or
     (not Assigned(EVP_PKEY_free)) then
  begin
    MarkSkip('certificate pinning bio contract',
      'required baseline OpenSSL BIO/X509/EVP helpers are unavailable');
    Exit;
  end;

  LKeyPair := TCertificate.CreateSelfSigned('cert-pinning-bio-guard.local');
  if LKeyPair = nil then
    raise Exception.Create('failed to create self-signed certificate fixture');

  LCert := RequireCertificateHandle(LKeyPair);
  LPubKeyHash := ComputePublicKeyHash(LCert);
  if Length(LPubKeyHash) <> 32 then
    raise Exception.Create('failed to compute 32-byte SPKI hash fixture');

  LValidator := TPinValidator.Create;
  LValidatorEx := TPinValidatorEx.Create;
  try
    LValidator.AddPin(LPubKeyHash, ptPublicKey, 'Primary SPKI Pin', False);
    LValidatorEx.AddPin(LPubKeyHash, ptPublicKey, 'Primary SPKI Pin', False);
    LChain[0] := LCert;

    LOriginalBIONew := BIO_new;
    LOriginalBIOSMem := BIO_s_mem;
    LOriginalBIOFree := BIO_free;

    BIO_new := nil;
    try
      AssertValidateCertificateMatches(
        'ValidateCertificate when BIO_new is unavailable',
        LValidator,
        LCert
      );
      AssertValidateCertificateChainMatches(
        'ValidateCertificateChain when BIO_new is unavailable',
        LValidator,
        LChain
      );
      AssertValidateCertificateExMatches(
        'ValidateCertificateEx when BIO_new is unavailable',
        LValidatorEx,
        LCert
      );
    finally
      BIO_new := LOriginalBIONew;
    end;

    BIO_s_mem := nil;
    try
      AssertValidateCertificateMatches(
        'ValidateCertificate when BIO_s_mem is unavailable',
        LValidator,
        LCert
      );
      AssertValidateCertificateChainMatches(
        'ValidateCertificateChain when BIO_s_mem is unavailable',
        LValidator,
        LChain
      );
      AssertValidateCertificateExMatches(
        'ValidateCertificateEx when BIO_s_mem is unavailable',
        LValidatorEx,
        LCert
      );
    finally
      BIO_s_mem := LOriginalBIOSMem;
    end;

    BIO_free := nil;
    try
      AssertValidateCertificateMatches(
        'ValidateCertificate when BIO_free is unavailable',
        LValidator,
        LCert
      );
      AssertValidateCertificateChainMatches(
        'ValidateCertificateChain when BIO_free is unavailable',
        LValidator,
        LChain
      );
      AssertValidateCertificateExMatches(
        'ValidateCertificateEx when BIO_free is unavailable',
        LValidatorEx,
        LCert
      );
    finally
      BIO_free := LOriginalBIOFree;
    end;
  finally
    LValidator.Free;
    LValidatorEx.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Pinning BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate pinning bio contract',
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
      TestPinningShouldIgnoreUnusedBIOHelpers;

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
