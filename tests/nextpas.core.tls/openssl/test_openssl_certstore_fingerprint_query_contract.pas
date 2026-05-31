program test_openssl_certstore_fingerprint_query_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';

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

function BuildFingerprintQueryVariant(const AFingerprint: string): string;
var
  I: Integer;
  LCompact: string;
begin
  LCompact := NormalizeHexish(AFingerprint);
  Result := '';
  for I := 1 to Length(LCompact) do
  begin
    if (I > 1) and (((I - 1) mod 2) = 0) then
      Result := Result + '-';
    Result := Result + LowerCase(LCompact[I]);
  end;
  Result := '  ' + Result + '  ';
end;

procedure RunContract;
var
  LLib: ISSLLibrary;
  LStore: ISSLCertificateStore;
  LCert: ISSLCertificate;
  LFingerprintVariant: string;
  LInitialized: Boolean;
  LLoaded: Boolean;
begin
  LLib := CreateOpenSSLLibrary;
  Check('CreateOpenSSLLibrary returns instance', LLib <> nil);
  if LLib = nil then
    Exit;

  LInitialized := LLib.Initialize;
  Check('OpenSSL library initializes', LInitialized, LLib.GetLastErrorString);
  if not LInitialized then
    Exit;

  LCert := LLib.CreateCertificate;
  Check('CreateCertificate returns instance', LCert <> nil);
  if LCert = nil then
    Exit;

  LLoaded := LCert.LoadFromFile(CERT_FIXTURE_PATH);
  Check('Load fixture certificate', LLoaded, CERT_FIXTURE_PATH);
  if not LLoaded then
    Exit;

  Check('Fixture exposes fingerprint',
    NormalizeHexish(LCert.GetFingerprintSHA256) <> '', LCert.GetFingerprintSHA256);

  LStore := LLib.CreateCertificateStore;
  Check('CreateCertificateStore returns instance', LStore <> nil);
  if LStore = nil then
    Exit;

  Check('Store accepts fixture certificate', LStore.AddCertificate(LCert));

  LFingerprintVariant := BuildFingerprintQueryVariant(LCert.GetFingerprintSHA256);
  Check('FindByFingerprint supports normalized fingerprint query variant',
    LStore.FindByFingerprint(LFingerprintVariant) <> nil, LFingerprintVariant);
  Check('FindByFingerprint whitespace-only query returns nil',
    LStore.FindByFingerprint('   --   ') = nil);
end;

begin
  RunContract;
  WriteLn;
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Failed tests: ', FailedTests);
  if FailedTests <> 0 then
    Halt(1);
end.
