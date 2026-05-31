program test_openssl_certificate_extension_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.openssl.backed;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_ecdsa_cert.pem';
  EXTENSION_OID = '2.5.29.14';

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

procedure RunContract;
var
  LTruthLib: ISSLLibrary;
  LExpectedCert: ISSLCertificate;
  LExpectedExtension: string;
  LLib: ISSLLibrary;
  LOpenSSLCert: ISSLCertificate;
  LActualExtension: string;
begin
  LTruthLib := CreateInitializedFreePascalLibrary;
  if (LTruthLib = nil) or (not LTruthLib.IsInitialized) then
    Exit;

  LExpectedCert := LTruthLib.CreateCertificate;
  Check('Create FreePascal certificate truth owner', LExpectedCert <> nil);
  if LExpectedCert = nil then
    Exit;

  Check('Load fixture into FreePascal parser truth owner',
    LExpectedCert.LoadFromFile(CERT_FIXTURE_PATH), CERT_FIXTURE_PATH);
  if not LExpectedCert.LoadFromFile(CERT_FIXTURE_PATH) then
    Exit;

  LExpectedExtension := LExpectedCert.GetExtension(EXTENSION_OID);
  Check('Fixture exposes parser-backed Subject Key Identifier truth',
    LExpectedExtension <> '', LExpectedExtension);
  if LExpectedExtension = '' then
    Exit;

  LLib := CreateOpenSSLLibrary;
  Check('CreateOpenSSLLibrary returns instance', LLib <> nil);
  if LLib = nil then
    Exit;

  Check('OpenSSL library initializes', LLib.Initialize, LLib.GetLastErrorString);
  if not LLib.IsInitialized then
    Exit;

  LOpenSSLCert := LLib.CreateCertificate;
  Check('CreateCertificate returns instance', LOpenSSLCert <> nil);
  if LOpenSSLCert = nil then
    Exit;

  Check('OpenSSL certificate loads extension fixture',
    LOpenSSLCert.LoadFromFile(CERT_FIXTURE_PATH), CERT_FIXTURE_PATH);
  if not LOpenSSLCert.LoadFromFile(CERT_FIXTURE_PATH) then
    Exit;

  LActualExtension := LOpenSSLCert.GetExtension(EXTENSION_OID);
  Check('OpenSSL GetExtension matches parser-backed Subject Key Identifier truth',
    LActualExtension = LExpectedExtension,
    'Actual=' + LActualExtension + ' Expected=' + LExpectedExtension);
end;

begin
  RunContract;
  WriteLn;
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Failed tests: ', FailedTests);
  if FailedTests <> 0 then
    Halt(1);
end.
