program test_openssl_certificate_hostname_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('[FAIL] ', AMessage);
    Halt(1);
  end;
  WriteLn('[PASS] ', AMessage);
end;

function LoadCertificate(const APath, ALabel: string): ISSLCertificate;
begin
  Result := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(Result <> nil, ALabel + ' certificate object should be created');
  Check(Result.LoadFromFile(APath), ALabel + ' fixture should load');
end;

procedure TestHostnameFixtureParity;
var
  LLib: ISSLLibrary;
  LSanCert: ISSLCertificate;
  LConflictCert: ISSLCertificate;
  LWildcardCert: ISSLCertificate;
begin
  WriteLn('=== OpenSSL VerifyHostname Fixture Parity ===');

  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib <> nil, 'OpenSSL library instance should exist');
  Check(LLib.Initialize, 'OpenSSL library should initialize');

  LSanCert := LoadCertificate('tests/certs/san-test.pem', 'SAN');
  Check(LSanCert.VerifyHostname('san-test.local'),
    'SAN fixture should accept DNS:san-test.local');
  Check(LSanCert.VerifyHostname('example.test'),
    'SAN fixture should accept DNS:example.test');
  Check(LSanCert.VerifyHostname('127.0.0.1'),
    'SAN fixture should accept IP:127.0.0.1');
  Check(not LSanCert.VerifyHostname('wrong.test'),
    'SAN fixture should reject unrelated hostname');

  LConflictCert := LoadCertificate(
    'tests/certificate/test_certs/san_cn_conflict_cert.pem',
    'SAN-vs-CN conflict'
  );
  Check(not LConflictCert.VerifyHostname('cn-only.example.com'),
    'SAN-vs-CN conflict fixture should prioritize SAN over CN');
  Check(LConflictCert.VerifyHostname('alt.example.com'),
    'SAN-vs-CN conflict fixture should still accept SAN DNS entry');

  LWildcardCert := LoadCertificate(
    'tests/certificate/test_certs/san_wildcard_cert.pem',
    'Wildcard SAN'
  );
  Check(LWildcardCert.VerifyHostname('api.example.com'),
    'Wildcard SAN fixture should accept single-label subdomain');
  Check(not LWildcardCert.VerifyHostname('deep.api.example.com'),
    'Wildcard SAN fixture should reject multi-label subdomain');
end;

begin
  try
    TestHostnameFixtureParity;
    WriteLn;
    WriteLn('[PASS] OpenSSL VerifyHostname fixture parity is satisfied.');
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] Unhandled exception: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
