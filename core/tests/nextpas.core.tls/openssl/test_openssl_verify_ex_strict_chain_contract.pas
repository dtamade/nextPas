program test_openssl_verify_ex_strict_chain_contract;

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

function ContainsTextInsensitive(const AText, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AText)) > 0;
end;

procedure TestStrictChainRequiresServerAuthUsage;
var
  LLib: ISSLLibrary;
  LLeafCert: ISSLCertificate;
  LCACert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LVerifyResult: TSSLCertVerifyResult;
  LVerified: Boolean;
  LDiag: string;
begin
  WriteLn('=== OpenSSL VerifyEx Strict-Chain Parity ===');

  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib <> nil, 'OpenSSL library instance should exist');
  Check(LLib.Initialize, 'OpenSSL library should initialize');

  LLeafCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LLeafCert <> nil, 'Leaf certificate object should be created');
  Check(LLeafCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'),
    'Leaf verification fixture should load');

  LCACert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LCACert <> nil, 'CA certificate object should be created');
  Check(LCACert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'CA verification fixture should load');

  LStore := TSSLFactory.CreateCertificateStore(sslOpenSSL);
  Check(LStore <> nil, 'OpenSSL certificate store should be created');
  Check(LStore.AddCertificate(LCACert), 'CA fixture should be added to store');
  Check(Trim(LLeafCert.GetExtension('2.5.29.37')) = '',
    'Leaf fixture should not advertise an explicit extendedKeyUsage extension');

  LVerified := LLeafCert.VerifyEx(LStore, [], LVerifyResult);
  Check(LVerified and LVerifyResult.Success,
    'VerifyEx without strict-chain should succeed for the CA-signed leaf fixture');

  LVerified := LLeafCert.VerifyEx(LStore, [sslCertVerifyStrictChain], LVerifyResult);
  Check((not LVerified) and (not LVerifyResult.Success),
    Format(
      'VerifyEx with strict-chain should fail when serverAuth EKU is absent; actual verified=%s success=%s error=%d msg=%s details=%s',
      [
        BoolToStr(LVerified, True),
        BoolToStr(LVerifyResult.Success, True),
        LVerifyResult.ErrorCode,
        LVerifyResult.ErrorMessage,
        LVerifyResult.DetailedInfo
      ]
    ));

  LDiag := LVerifyResult.ErrorMessage + ' ' + LVerifyResult.DetailedInfo;
  Check(
    ContainsTextInsensitive(LDiag, 'strict') or
    ContainsTextInsensitive(LDiag, 'serverauth') or
    ContainsTextInsensitive(LDiag, 'extended key usage'),
    'Strict-chain failure should mention strict-chain or serverAuth EKU'
  );
end;

begin
  try
    TestStrictChainRequiresServerAuthUsage;
    WriteLn;
    WriteLn('[PASS] OpenSSL VerifyEx strict-chain contract is satisfied.');
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] Unhandled exception: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
