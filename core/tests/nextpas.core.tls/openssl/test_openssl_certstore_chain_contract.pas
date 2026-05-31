program test_openssl_certstore_chain_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.utils;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
    WriteLn('[PASS] ', AName)
  else
  begin
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
    Halt(1);
  end;
end;

function NormalizeHexish(const AValue: string): string;
var
  I: Integer;
  LChar: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    LChar := UpCase(AValue[I]);
    if LChar in ['0'..'9', 'A'..'F'] then
      Result := Result + LChar;
  end;
end;

procedure GenerateChainMaterial(
  out ARootCertPEM, ARootKeyPEM, AInterCertPEM, AInterKeyPEM, ALeafCertPEM, ALeafKeyPEM: string);
var
  LRootOptions: TCertGenOptions;
  LInterOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
begin
  LRootOptions := TCertificateUtils.DefaultGenOptions;
  LRootOptions.CommonName := 'openssl-chain-root.local';
  LRootOptions.Organization := 'fafafa.ssl';
  LRootOptions.IsCA := True;
  AssertTrue('Generate root CA should succeed',
    TCertificateUtils.GenerateSelfSigned(LRootOptions, ARootCertPEM, ARootKeyPEM));

  LInterOptions := TCertificateUtils.DefaultGenOptions;
  LInterOptions.CommonName := 'openssl-chain-intermediate.local';
  LInterOptions.Organization := 'fafafa.ssl';
  LInterOptions.IsCA := True;
  AssertTrue('Generate intermediate CA should succeed',
    TCertificateUtils.GenerateSigned(
      LInterOptions,
      ARootCertPEM,
      ARootKeyPEM,
      AInterCertPEM,
      AInterKeyPEM
    ));

  LLeafOptions := TCertificateUtils.DefaultGenOptions;
  LLeafOptions.CommonName := 'openssl-chain-leaf.local';
  LLeafOptions.Organization := 'fafafa.ssl';
  LLeafOptions.IsCA := False;
  AssertTrue('Generate leaf certificate should succeed',
    TCertificateUtils.GenerateSigned(
      LLeafOptions,
      AInterCertPEM,
      AInterKeyPEM,
      ALeafCertPEM,
      ALeafKeyPEM
    ));
end;

function LoadOpenSSLCertificate(const ASSLLib: ISSLLibrary; const APEM, ALabel: string): ISSLCertificate;
begin
  Result := ASSLLib.CreateCertificate;
  AssertTrue('Create ' + ALabel + ' certificate object should succeed', Result <> nil);
  AssertTrue(ALabel + ' certificate should load from PEM', Result.LoadFromPEM(APEM));
end;

procedure AssertChainFingerprint(const AName: string; const AChain: TSSLCertificateArray;
  AIndex: Integer; const AExpectedFingerprint: string);
begin
  AssertTrue(AName,
    (AIndex >= 0) and
    (AIndex < Length(AChain)) and
    (NormalizeHexish(AChain[AIndex].GetFingerprintSHA256) =
     NormalizeHexish(AExpectedFingerprint)),
    'actual-length=' + IntToStr(Length(AChain)) +
    ', expected-index=' + IntToStr(AIndex));
end;

procedure TestBuildCertificateChainReturnsPartialChainWhenOnlyIntermediatePresent;
var
  LRootCertPEM: string;
  LRootKeyPEM: string;
  LInterCertPEM: string;
  LInterKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
  LSSLLib: ISSLLibrary;
  LLeafCert: ISSLCertificate;
  LInterCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LChain: TSSLCertificateArray;
begin
  WriteLn('=== OpenSSL Partial Chain Contract ===');
  GenerateChainMaterial(
    LRootCertPEM, LRootKeyPEM,
    LInterCertPEM, LInterKeyPEM,
    LLeafCertPEM, LLeafKeyPEM
  );

  LSSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  AssertTrue('OpenSSL library instance should exist', LSSLLib <> nil);
  AssertTrue('OpenSSL library should initialize', LSSLLib.Initialize);

  LLeafCert := LoadOpenSSLCertificate(LSSLLib, LLeafCertPEM, 'leaf');
  LInterCert := LoadOpenSSLCertificate(LSSLLib, LInterCertPEM, 'intermediate');

  LStore := LSSLLib.CreateCertificateStore;
  AssertTrue('Create OpenSSL certificate store should succeed', LStore <> nil);
  AssertTrue('Store should accept intermediate certificate', LStore.AddCertificate(LInterCert));

  LChain := LStore.BuildCertificateChain(LLeafCert);
  AssertTrue('Store with only intermediate should return minimal chain',
    Length(LChain) = 2,
    'Expected 2 certificates, actual=' + IntToStr(Length(LChain)));
  AssertChainFingerprint('Chain[1] should be the intermediate certificate',
    LChain, 1, LInterCert.GetFingerprintSHA256);
end;

procedure TestBuildCertificateChainContinuesToRootWhenRootIsPresent;
var
  LRootCertPEM: string;
  LRootKeyPEM: string;
  LInterCertPEM: string;
  LInterKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
  LSSLLib: ISSLLibrary;
  LLeafCert: ISSLCertificate;
  LInterCert: ISSLCertificate;
  LRootCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LChain: TSSLCertificateArray;
begin
  WriteLn('=== OpenSSL Full Chain Contract ===');
  GenerateChainMaterial(
    LRootCertPEM, LRootKeyPEM,
    LInterCertPEM, LInterKeyPEM,
    LLeafCertPEM, LLeafKeyPEM
  );

  LSSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  AssertTrue('OpenSSL library instance should exist', LSSLLib <> nil);
  AssertTrue('OpenSSL library should initialize', LSSLLib.Initialize);

  LLeafCert := LoadOpenSSLCertificate(LSSLLib, LLeafCertPEM, 'leaf');
  LInterCert := LoadOpenSSLCertificate(LSSLLib, LInterCertPEM, 'intermediate');
  LRootCert := LoadOpenSSLCertificate(LSSLLib, LRootCertPEM, 'root');

  LStore := LSSLLib.CreateCertificateStore;
  AssertTrue('Create OpenSSL certificate store should succeed', LStore <> nil);
  AssertTrue('Store should accept intermediate certificate', LStore.AddCertificate(LInterCert));
  AssertTrue('Store should accept root certificate', LStore.AddCertificate(LRootCert));

  LChain := LStore.BuildCertificateChain(LLeafCert);
  AssertTrue('Store with intermediate and root should return full chain',
    Length(LChain) = 3,
    'Expected 3 certificates, actual=' + IntToStr(Length(LChain)));
  AssertChainFingerprint('Chain[1] should be the intermediate certificate',
    LChain, 1, LInterCert.GetFingerprintSHA256);
  AssertChainFingerprint('Chain[2] should be the root certificate',
    LChain, 2, LRootCert.GetFingerprintSHA256);
end;

begin
  WriteLn('==============================================');
  WriteLn('OpenSSL CertStore Chain Contract');
  WriteLn('==============================================');
  try
    TestBuildCertificateChainReturnsPartialChainWhenOnlyIntermediatePresent;
    WriteLn;
    TestBuildCertificateChainContinuesToRootWhenRootIsPresent;
    WriteLn;
    WriteLn('[PASS] All OpenSSL certstore chain contract tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] Unhandled exception: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
