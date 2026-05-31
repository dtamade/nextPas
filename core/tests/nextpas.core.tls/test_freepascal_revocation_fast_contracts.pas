program test_freepascal_revocation_fast_contracts;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.certchain,
  nextpas.core.tls.crl;

const
  REVOKED_SERIAL = 1001;
  NON_REVOKED_SERIAL = 1002;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function ContainsTextInsensitive(const AValue, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AValue)) > 0;
end;

function ReadTextFile(const AFileName: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(AFileName);
    Result := LText.Text;
  finally
    LText.Free;
  end;
end;

function CreateFreePascalCertificate: ISSLCertificate;
var
  LLib: ISSLLibrary;
begin
  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  AssertTrue(LLib <> nil, 'FreePascal library should be available');
  Result := LLib.CreateCertificate;
  AssertTrue(Result <> nil, 'FreePascal certificate instance should be created');
end;

function CreateTrustedStore: ISSLCertificateStore;
var
  LLib: ISSLLibrary;
begin
  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  AssertTrue(LLib <> nil, 'FreePascal library should be available for certificate store creation');
  Result := LLib.CreateCertificateStore;
  AssertTrue(Result <> nil, 'FreePascal certificate store should be created');
  AssertTrue(
    Result.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'Trusted store should load the CA certificate fixture'
  );
end;

function CreateSignedLeafCertificate(ASerialNumber: Int64): ISSLCertificate;
var
  LOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
begin
  LCACertPEM := ReadTextFile('tests/certificate/test_certs/ca_cert.pem');
  LCAKeyPEM := ReadTextFile('tests/certificate/test_certs/ca_key.pem');

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'example.com';
  LOptions.Organization := 'fafafa.ssl-tests';
  LOptions.ValidDays := 30;
  LOptions.NotBefore := Now - 2;
  LOptions.NotAfter := Now + 30;
  LOptions.SerialNumber := ASerialNumber;
  LOptions.SubjectAltNames := TStringList.Create;
  try
    LOptions.SubjectAltNames.Add('example.com');
    AssertTrue(
      TCertificateUtils.GenerateSigned(
        LOptions,
        LCACertPEM,
        LCAKeyPEM,
        LLeafCertPEM,
        LLeafKeyPEM
      ),
      'GenerateSigned should create a CA-signed leaf certificate for fast revocation contracts'
    );
  finally
    LOptions.SubjectAltNames.Free;
    LOptions.SubjectAltNames := nil;
  end;

  Result := CreateFreePascalCertificate;
  AssertTrue(Result.LoadFromPEM(LLeafCertPEM), 'Generated leaf certificate should load as PEM');
end;

function VerifyChainWithCRLFiles(
  ALeafCert: ISSLCertificate;
  const ACRLFiles: array of string
): TChainVerifyResult;
var
  LVerifier: ISSLCertificateChainVerifier;
  LTrustedStore: ISSLCertificateStore;
  LIssuerCert: ISSLCertificate;
  LCRLs: TStringList;
  LChain: TSSLCertificateArray;
  I: Integer;
begin
  LVerifier := TSSLCertificateChainVerifier.Create;
  LVerifier.SetOptions([
    cvoCheckTime,
    cvoCheckSignature,
    cvoCheckCAConstraints,
    cvoCheckRevocation
  ]);

  LTrustedStore := CreateTrustedStore;
  LVerifier.SetTrustedStore(LTrustedStore);

  LCRLs := TStringList.Create;
  try
    for I := Low(ACRLFiles) to High(ACRLFiles) do
      LCRLs.Add(ReadTextFile(ACRLFiles[I]));
    LVerifier.SetCRLStore(LCRLs);

    LIssuerCert := CreateFreePascalCertificate;
    AssertTrue(
      LIssuerCert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
      'Issuer certificate fixture should load'
    );

    SetLength(LChain, 2);
    LChain[0] := ALeafCert;
    LChain[1] := LIssuerCert;
    Result := LVerifier.VerifyChain(LChain);
  finally
    LCRLs.Free;
  end;
end;

procedure FreeVerifyResult(var AResult: TChainVerifyResult);
begin
  if AResult.Warnings <> nil then
  begin
    AResult.Warnings.Free;
    AResult.Warnings := nil;
  end;
end;

procedure TestCRLIssuerRetainsAttributeNames;
var
  LCRL: TX509CRL;
  LIssuer: string;
begin
  WriteLn('Testing CRL issuer formatting...');
  LCRL := TX509CRL.Create;
  try
    LCRL.LoadFromFile('tests/certificate/test_certs/revocation_revoked_crl.pem');
    LIssuer := LCRL.Issuer.ToString;
    AssertTrue(Pos('CN=Test CA', LIssuer) > 0,
      'CRL issuer string should keep CN short name: ' + LIssuer);
    AssertTrue(Pos('O=Test CA', LIssuer) > 0,
      'CRL issuer string should keep O short name: ' + LIssuer);
  finally
    LCRL.Free;
  end;
end;

procedure TestMatchingCRLAllowsNonRevokedLeaf;
var
  LLeafCert: ISSLCertificate;
  LResult: TChainVerifyResult;
begin
  WriteLn('Testing matching CRL non-revoked path...');
  LLeafCert := CreateSignedLeafCertificate(NON_REVOKED_SERIAL);
  LResult := VerifyChainWithCRLFiles(
    LLeafCert,
    ['tests/certificate/test_certs/revocation_revoked_crl.pem']
  );
  try
    AssertTrue(LResult.IsValid,
      'Matching CRL should allow a non-revoked serial: ' + LResult.ErrorMessage);
    AssertEqualsInt(0, LResult.RevocationStatus,
      'Matching non-revoked CRL path should surface RevocationStatus=0');
  finally
    FreeVerifyResult(LResult);
  end;
end;

procedure TestMatchingCRLRejectsRevokedLeaf;
var
  LLeafCert: ISSLCertificate;
  LResult: TChainVerifyResult;
begin
  WriteLn('Testing matching CRL revoked path...');
  LLeafCert := CreateSignedLeafCertificate(REVOKED_SERIAL);
  LResult := VerifyChainWithCRLFiles(
    LLeafCert,
    ['tests/certificate/test_certs/revocation_revoked_crl.pem']
  );
  try
    AssertTrue(not LResult.IsValid,
      'Matching CRL should reject the revoked serial');
    AssertEqualsInt(1, LResult.RevocationStatus,
      'Revoked CRL path should surface RevocationStatus=1');
    AssertTrue(ContainsTextInsensitive(LResult.ErrorMessage, 'revoked'),
      'Revoked CRL path should surface revoked wording: ' + LResult.ErrorMessage);
  finally
    FreeVerifyResult(LResult);
  end;
end;

procedure TestUnavailableCRLFailsClosed;
var
  LLeafCert: ISSLCertificate;
  LResult: TChainVerifyResult;
begin
  WriteLn('Testing unavailable CRL path...');
  LLeafCert := CreateSignedLeafCertificate(NON_REVOKED_SERIAL);
  LResult := VerifyChainWithCRLFiles(LLeafCert, []);
  try
    AssertTrue(not LResult.IsValid,
      'Unavailable CRL material should fail closed');
    AssertEqualsInt(2, LResult.RevocationStatus,
      'Unavailable CRL path should surface RevocationStatus=2');
    AssertTrue(ContainsTextInsensitive(LResult.ErrorMessage, 'no caller-provided crl material'),
      'Unavailable CRL path should mention CRL verification: ' + LResult.ErrorMessage);
  finally
    FreeVerifyResult(LResult);
  end;
end;

begin
  WriteLn('FreePascal revocation fast contracts');
  WriteLn('==============================================');
  WriteLn;

  TestCRLIssuerRetainsAttributeNames;
  TestMatchingCRLAllowsNonRevokedLeaf;
  TestMatchingCRLRejectsRevokedLeaf;
  TestUnavailableCRLFailsClosed;

  WriteLn;
  WriteLn('All FreePascal revocation fast contracts passed.');
end.
