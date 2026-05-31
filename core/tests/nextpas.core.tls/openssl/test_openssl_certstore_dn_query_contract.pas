program test_openssl_certstore_dn_query_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';
  SUBJECT_FRAGMENT = 'CN=Test Signer,O=Test Org';
  ISSUER_FRAGMENT = 'CN=Test CA,O=Test CA';

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

function BuildLooseDNQueryVariant(const AValue: string): string;
begin
  Result := Trim(AValue);
  Result := StringReplace(Result, ',', ' , ', [rfReplaceAll]);
  Result := StringReplace(Result, '=', ' = ', [rfReplaceAll]);
  Result := '  ' + LowerCase(Result) + '  ';
end;

procedure RunContract;
var
  LLib: ISSLLibrary;
  LStore: ISSLCertificateStore;
  LCert: ISSLCertificate;
  LSubjectVariant: string;
  LIssuerVariant: string;
begin
  LLib := CreateOpenSSLLibrary;
  Check('CreateOpenSSLLibrary returns instance', LLib <> nil);
  if LLib = nil then
    Exit;

  Check('OpenSSL library initializes', LLib.Initialize, LLib.GetLastErrorString);
  if not LLib.Initialize then
    Exit;

  LCert := LLib.CreateCertificate;
  Check('CreateCertificate returns instance', LCert <> nil);
  if LCert = nil then
    Exit;

  Check('Load distinct-issuer fixture', LCert.LoadFromFile(CERT_FIXTURE_PATH), CERT_FIXTURE_PATH);
  if not LCert.LoadFromFile(CERT_FIXTURE_PATH) then
    Exit;

  Check('Fixture subject contains expected fragment',
    Pos(SUBJECT_FRAGMENT, LCert.GetSubject) > 0, LCert.GetSubject);
  Check('Fixture issuer contains expected fragment',
    Pos(ISSUER_FRAGMENT, LCert.GetIssuer) > 0, LCert.GetIssuer);

  LStore := LLib.CreateCertificateStore;
  Check('CreateCertificateStore returns instance', LStore <> nil);
  if LStore = nil then
    Exit;

  Check('Store accepts fixture certificate', LStore.AddCertificate(LCert));

  LSubjectVariant := BuildLooseDNQueryVariant(SUBJECT_FRAGMENT);
  LIssuerVariant := BuildLooseDNQueryVariant(ISSUER_FRAGMENT);

  Check('FindBySubject supports normalized partial DN fragment query',
    LStore.FindBySubject(LSubjectVariant) <> nil, LSubjectVariant);
  Check('FindBySubject empty query returns nil',
    LStore.FindBySubject('') = nil);
  Check('FindByIssuer supports normalized partial DN fragment query',
    LStore.FindByIssuer(LIssuerVariant) <> nil, LIssuerVariant);
  Check('FindByIssuer empty query returns nil',
    LStore.FindByIssuer('') = nil);
end;

begin
  RunContract;
  WriteLn;
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Failed tests: ', FailedTests);
  if FailedTests <> 0 then
    Halt(1);
end.
