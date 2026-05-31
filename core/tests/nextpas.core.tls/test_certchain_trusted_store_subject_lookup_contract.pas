program test_certchain_trusted_store_subject_lookup_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.certchain;

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

procedure TestBuildChainUsesTrustedStoreSubjectLookupForIssuer;
var
  LRootOptions: TCertGenOptions;
  LInterOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LRootCertPEM: string;
  LRootKeyPEM: string;
  LInterCertPEM: string;
  LInterKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
  SSLLib: ISSLLibrary;
  LLeafCert: ISSLCertificate;
  LInterCert: ISSLCertificate;
  LTrustedStore: ISSLCertificateStore;
  LVerifier: ISSLCertificateChainVerifier;
  LChain: TSSLCertificateArray;
begin
  WriteLn('=== Trusted Store Subject Lookup Contract ===');

  LRootOptions := TCertificateUtils.DefaultGenOptions;
  LRootOptions.CommonName := 'trusted-store-root.local';
  LRootOptions.Organization := 'fafafa.ssl';
  LRootOptions.IsCA := True;
  AssertTrue('Generate root CA should succeed',
    TCertificateUtils.GenerateSelfSigned(LRootOptions, LRootCertPEM, LRootKeyPEM));

  LInterOptions := TCertificateUtils.DefaultGenOptions;
  LInterOptions.CommonName := 'trusted-store-intermediate.local';
  LInterOptions.Organization := 'fafafa.ssl';
  LInterOptions.IsCA := True;
  AssertTrue('Generate intermediate CA should succeed',
    TCertificateUtils.GenerateSigned(
      LInterOptions,
      LRootCertPEM,
      LRootKeyPEM,
      LInterCertPEM,
      LInterKeyPEM
    ));

  LLeafOptions := TCertificateUtils.DefaultGenOptions;
  LLeafOptions.CommonName := 'trusted-store-leaf.local';
  LLeafOptions.Organization := 'fafafa.ssl';
  LLeafOptions.IsCA := False;
  AssertTrue('Generate leaf certificate should succeed',
    TCertificateUtils.GenerateSigned(
      LLeafOptions,
      LInterCertPEM,
      LInterKeyPEM,
      LLeafCertPEM,
      LLeafKeyPEM
    ));

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  AssertTrue('OpenSSL library instance should exist', SSLLib <> nil);
  AssertTrue('OpenSSL library should initialize', SSLLib.Initialize);

  LLeafCert := SSLLib.CreateCertificate;
  AssertTrue('Create leaf certificate object should succeed', LLeafCert <> nil);
  AssertTrue('Leaf certificate should load from PEM', LLeafCert.LoadFromPEM(LLeafCertPEM));

  LInterCert := SSLLib.CreateCertificate;
  AssertTrue('Create intermediate certificate object should succeed', LInterCert <> nil);
  AssertTrue('Intermediate certificate should load from PEM', LInterCert.LoadFromPEM(LInterCertPEM));

  LTrustedStore := SSLLib.CreateCertificateStore;
  AssertTrue('Create trusted store should succeed', LTrustedStore <> nil);
  AssertTrue('Trusted store should accept intermediate trust anchor',
    LTrustedStore.AddCertificate(LInterCert));

  LVerifier := TSSLCertificateChainVerifier.Create;
  LVerifier.SetTrustedStore(LTrustedStore);

  AssertTrue('BuildChain should succeed when trusted store contains issuer certificate by subject',
    LVerifier.BuildChain(LLeafCert, LChain));
  AssertTrue('BuildChain should contain leaf plus trusted intermediate anchor',
    Length(LChain) = 2,
    'Expected 2 certificates, actual=' + IntToStr(Length(LChain)));
  AssertTrue('BuildChain should append the trusted intermediate certificate',
    (Length(LChain) = 2) and
    (NormalizeHexish(LChain[1].GetFingerprintSHA256) =
     NormalizeHexish(LInterCert.GetFingerprintSHA256)));
end;

begin
  WriteLn('==============================================');
  WriteLn('Trusted Store Subject Lookup Chain Contract');
  WriteLn('==============================================');
  try
    TestBuildChainUsesTrustedStoreSubjectLookupForIssuer;
    WriteLn;
    WriteLn('[PASS] All trusted-store chain lookup tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] Unhandled exception: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.

