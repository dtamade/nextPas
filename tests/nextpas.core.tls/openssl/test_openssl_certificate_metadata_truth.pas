program test_openssl_certificate_metadata_truth;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.openssl.backed;

const
  ECDSA_CA_FIXTURE = 'tests/certificate/test_certs/signer_ecdsa_cert.pem';
  SAN_RICH_FIXTURE = 'tests/certs/san-rich.pem';
  KEYUSAGE_FIXTURE = 'tests/certificate/test_certs/keyusage_cert.pem';

var
  TotalTests: Integer = 0;
  FailedTests: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
    WriteLn('[PASS] ', AName)
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

function CreateInitializedFreePascalLibrary: ISSLLibrary;
begin
  Result := CreateFreePascalSSLLibrary;
  Check('CreateFreePascalSSLLibrary returns instance', Result <> nil);
  if Result = nil then
    Exit;

  Check('FreePascal library initializes', Result.Initialize, Result.GetLastErrorString);
end;

function CreateInitializedOpenSSLLibrary: ISSLLibrary;
begin
  Result := CreateOpenSSLLibrary;
  Check('CreateOpenSSLLibrary returns instance', Result <> nil);
  if Result = nil then
    Exit;

  Check('OpenSSL library initializes', Result.Initialize, Result.GetLastErrorString);
end;

function ArrayContains(const AValues: TSSLStringArray; const AExpected: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AValues) do
    if SameText(AValues[I], AExpected) then
      Exit(True);
end;

function FormatStringArray(const AValues: TSSLStringArray): string;
var
  I: Integer;
begin
  Result := '[';
  for I := 0 to High(AValues) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + AValues[I];
  end;
  Result := Result + ']';
end;

function SameStringArrays(const ALeft, ARight: TSSLStringArray): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
    Exit;

  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

function LoadCertificate(ALib: ISSLLibrary; const AFixturePath, ALabel: string): ISSLCertificate;
begin
  Result := nil;
  if ALib = nil then
    Exit;

  Result := ALib.CreateCertificate;
  Check(ALabel + ' create certificate instance', Result <> nil);
  if Result = nil then
    Exit;

  Check(ALabel + ' loads fixture', Result.LoadFromFile(AFixturePath), AFixturePath);
  if not Result.LoadFromFile(AFixturePath) then
    Result := nil;
end;

procedure TestECDSACAInfoProjection(const ATruthLib, AOpenSSLLib: ISSLLibrary);
var
  LTruthCert: ISSLCertificate;
  LOpenSSLCert: ISSLCertificate;
  LTruthInfo: TSSLCertificateInfo;
  LActualInfo: TSSLCertificateInfo;
begin
  LTruthCert := LoadCertificate(ATruthLib, ECDSA_CA_FIXTURE, 'ECDSA CA fixture truth owner');
  LOpenSSLCert := LoadCertificate(AOpenSSLLib, ECDSA_CA_FIXTURE, 'ECDSA CA fixture OpenSSL');
  if (LTruthCert = nil) or (LOpenSSLCert = nil) then
    Exit;

  LTruthInfo := LTruthCert.GetInfo;
  LActualInfo := LOpenSSLCert.GetInfo;

  Check('ECDSA CA fixture GetInfo exposes public-key size truth',
    LActualInfo.PublicKeySize = LTruthInfo.PublicKeySize,
    'Actual=' + IntToStr(LActualInfo.PublicKeySize) + ' Expected=' + IntToStr(LTruthInfo.PublicKeySize));
  Check('ECDSA CA fixture GetInfo exposes IsCA truth',
    LActualInfo.IsCA = LTruthInfo.IsCA,
    'Actual=' + BoolToStr(LActualInfo.IsCA, True) + ' Expected=' + BoolToStr(LTruthInfo.IsCA, True));
  Check('ECDSA CA fixture GetInfo path length matches parser truth',
    LActualInfo.PathLength = LTruthInfo.PathLength,
    'Actual=' + IntToStr(LActualInfo.PathLength) + ' Expected=' + IntToStr(LTruthInfo.PathLength));
  Check('ECDSA CA fixture GetInfo pathLenConstraint matches parser truth',
    LActualInfo.PathLenConstraint = LTruthInfo.PathLenConstraint,
    'Actual=' + IntToStr(LActualInfo.PathLenConstraint) + ' Expected=' + IntToStr(LTruthInfo.PathLenConstraint));
end;

procedure TestSANRichTruth(const ATruthLib, AOpenSSLLib: ISSLLibrary);
var
  LTruthCert: ISSLCertificate;
  LOpenSSLCert: ISSLCertificate;
  LExpectedSANs: TSSLStringArray;
  LActualSANs: TSSLStringArray;
  LTruthInfo: TSSLCertificateInfo;
  LActualInfo: TSSLCertificateInfo;
begin
  LTruthCert := LoadCertificate(ATruthLib, SAN_RICH_FIXTURE, 'SAN-rich fixture truth owner');
  LOpenSSLCert := LoadCertificate(AOpenSSLLib, SAN_RICH_FIXTURE, 'SAN-rich fixture OpenSSL');
  if (LTruthCert = nil) or (LOpenSSLCert = nil) then
    Exit;

  LExpectedSANs := LTruthCert.GetSubjectAltNames;
  LActualSANs := LOpenSSLCert.GetSubjectAltNames;
  Check('SAN-rich fixture getter keeps parser SAN truth',
    SameStringArrays(LActualSANs, LExpectedSANs),
    'Actual=' + FormatStringArray(LActualSANs) + ' Expected=' + FormatStringArray(LExpectedSANs));
  Check('SAN-rich fixture getter contains admin@example-rich.test',
    ArrayContains(LActualSANs, 'admin@example-rich.test'),
    FormatStringArray(LActualSANs));
  Check('SAN-rich fixture getter contains spiffe://mesh/service',
    ArrayContains(LActualSANs, 'spiffe://mesh/service'),
    FormatStringArray(LActualSANs));

  LTruthInfo := LTruthCert.GetInfo;
  LActualInfo := LOpenSSLCert.GetInfo;
  Check('SAN-rich fixture GetInfo keeps parser SAN truth',
    SameStringArrays(LActualInfo.SubjectAltNames, LTruthInfo.SubjectAltNames),
    'Actual=' + FormatStringArray(LActualInfo.SubjectAltNames) +
    ' Expected=' + FormatStringArray(LTruthInfo.SubjectAltNames));
end;

procedure TestKeyUsageTruth(const ATruthLib, AOpenSSLLib: ISSLLibrary);
var
  LTruthCert: ISSLCertificate;
  LOpenSSLCert: ISSLCertificate;
  LExpectedValues: TSSLStringArray;
  LActualValues: TSSLStringArray;
  LTruthInfo: TSSLCertificateInfo;
  LActualInfo: TSSLCertificateInfo;
begin
  LTruthCert := LoadCertificate(ATruthLib, KEYUSAGE_FIXTURE, 'KeyUsage fixture truth owner');
  LOpenSSLCert := LoadCertificate(AOpenSSLLib, KEYUSAGE_FIXTURE, 'KeyUsage fixture OpenSSL');
  if (LTruthCert = nil) or (LOpenSSLCert = nil) then
    Exit;

  LExpectedValues := LTruthCert.GetKeyUsage;
  LActualValues := LOpenSSLCert.GetKeyUsage;
  Check('KeyUsage fixture getter keeps parser key-usage truth',
    SameStringArrays(LActualValues, LExpectedValues),
    'Actual=' + FormatStringArray(LActualValues) + ' Expected=' + FormatStringArray(LExpectedValues));

  LExpectedValues := LTruthCert.GetExtendedKeyUsage;
  LActualValues := LOpenSSLCert.GetExtendedKeyUsage;
  Check('KeyUsage fixture getter keeps parser extended-key-usage truth',
    SameStringArrays(LActualValues, LExpectedValues),
    'Actual=' + FormatStringArray(LActualValues) + ' Expected=' + FormatStringArray(LExpectedValues));

  LTruthInfo := LTruthCert.GetInfo;
  LActualInfo := LOpenSSLCert.GetInfo;
  Check('KeyUsage fixture GetInfo bitfield keeps parser truth',
    LActualInfo.KeyUsage = LTruthInfo.KeyUsage,
    'Actual=' + IntToHex(LActualInfo.KeyUsage, 4) + ' Expected=' + IntToHex(LTruthInfo.KeyUsage, 4));
end;

procedure RunContract;
var
  LTruthLib: ISSLLibrary;
  LOpenSSLLib: ISSLLibrary;
begin
  LTruthLib := CreateInitializedFreePascalLibrary;
  if (LTruthLib = nil) or (not LTruthLib.IsInitialized) then
    Exit;

  LOpenSSLLib := CreateInitializedOpenSSLLibrary;
  if (LOpenSSLLib = nil) or (not LOpenSSLLib.IsInitialized) then
    Exit;

  TestECDSACAInfoProjection(LTruthLib, LOpenSSLLib);
  TestSANRichTruth(LTruthLib, LOpenSSLLib);
  TestKeyUsageTruth(LTruthLib, LOpenSSLLib);
end;

begin
  RunContract;
  WriteLn;
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Failed tests: ', FailedTests);
  if FailedTests <> 0 then
    Halt(1);
end.
