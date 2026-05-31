program test_openssl_verify_ex_store_flag_isolation_contract;

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

procedure TestIgnoreExpiryDoesNotLeakAcrossCalls;
var
  LLib: ISSLLibrary;
  LExpiredLeaf: ISSLCertificate;
  LCACert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LVerifyResult: TSSLCertVerifyResult;
  LVerified: Boolean;
begin
  WriteLn('=== OpenSSL VerifyEx Store Flag Isolation ===');

  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib <> nil, 'OpenSSL library instance should exist');
  Check(LLib.Initialize, 'OpenSSL library should initialize');

  LExpiredLeaf := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LExpiredLeaf <> nil, 'Expired leaf certificate object should be created');
  Check(LExpiredLeaf.LoadFromFile('tests/certs/expired-signer.pem'),
    'Expired verification fixture should load');

  LCACert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LCACert <> nil, 'CA certificate object should be created');
  Check(LCACert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'CA verification fixture should load');

  LStore := TSSLFactory.CreateCertificateStore(sslOpenSSL);
  Check(LStore <> nil, 'OpenSSL certificate store should be created');
  Check(LStore.AddCertificate(LCACert), 'CA fixture should be added to store');

  LVerified := LExpiredLeaf.VerifyEx(LStore, [], LVerifyResult);
  Check((not LVerified) and (not LVerifyResult.Success),
    'Expired leaf without IgnoreExpiry should fail before any flagged call');
  Check(
    ContainsTextInsensitive(LVerifyResult.ErrorMessage + ' ' + LVerifyResult.DetailedInfo, 'expired'),
    'Initial expiry failure should mention expired'
  );

  LVerified := LExpiredLeaf.VerifyEx(LStore, [sslCertVerifyIgnoreExpiry], LVerifyResult);
  Check(LVerified and LVerifyResult.Success,
    'Expired leaf with IgnoreExpiry should succeed');

  LVerified := LExpiredLeaf.VerifyEx(LStore, [], LVerifyResult);
  Check(
    (not LVerified) and (not LVerifyResult.Success),
    Format(
      'IgnoreExpiry must not leak into subsequent calls on the same store; actual verified=%s success=%s error=%d msg=%s details=%s',
      [
        BoolToStr(LVerified, True),
        BoolToStr(LVerifyResult.Success, True),
        LVerifyResult.ErrorCode,
        LVerifyResult.ErrorMessage,
        LVerifyResult.DetailedInfo
      ]
    )
  );
end;

procedure TestAllowSelfSignedDoesNotLeakAcrossCalls;
var
  LLib: ISSLLibrary;
  LSelfSignedLeaf: ISSLCertificate;
  LEmptyStore: ISSLCertificateStore;
  LVerifyResult: TSSLCertVerifyResult;
  LVerified: Boolean;
begin
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib <> nil, 'OpenSSL library instance for self-signed isolation should exist');
  Check(LLib.Initialize, 'OpenSSL library for self-signed isolation should initialize');

  LSelfSignedLeaf := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LSelfSignedLeaf <> nil, 'Self-signed leaf certificate object should be created');
  Check(LSelfSignedLeaf.LoadFromFile('tests/certs/version1-cert.pem'),
    'Self-signed verification fixture should load');

  LEmptyStore := TSSLFactory.CreateCertificateStore(sslOpenSSL);
  Check(LEmptyStore <> nil, 'Empty OpenSSL certificate store should be created');

  LVerified := LSelfSignedLeaf.VerifyEx(LEmptyStore, [], LVerifyResult);
  Check((not LVerified) and (not LVerifyResult.Success),
    'Self-signed leaf without AllowSelfSigned should fail before any flagged call');
  Check(
    ContainsTextInsensitive(LVerifyResult.ErrorMessage + ' ' + LVerifyResult.DetailedInfo, 'self-signed') or
    ContainsTextInsensitive(LVerifyResult.ErrorMessage + ' ' + LVerifyResult.DetailedInfo, 'trusted') or
    ContainsTextInsensitive(LVerifyResult.ErrorMessage + ' ' + LVerifyResult.DetailedInfo, 'issuer'),
    'Initial self-signed failure should expose trust diagnostic'
  );

  LVerified := LSelfSignedLeaf.VerifyEx(LEmptyStore, [sslCertVerifyAllowSelfSigned], LVerifyResult);
  Check(
    LVerified and LVerifyResult.Success,
    Format(
      'Self-signed leaf with AllowSelfSigned should succeed; actual verified=%s success=%s error=%d msg=%s details=%s',
      [
        BoolToStr(LVerified, True),
        BoolToStr(LVerifyResult.Success, True),
        LVerifyResult.ErrorCode,
        LVerifyResult.ErrorMessage,
        LVerifyResult.DetailedInfo
      ]
    )
  );

  LVerified := LSelfSignedLeaf.VerifyEx(LEmptyStore, [], LVerifyResult);
  Check(
    (not LVerified) and (not LVerifyResult.Success),
    Format(
      'AllowSelfSigned must not leak into subsequent calls on the same store; actual verified=%s success=%s error=%d msg=%s details=%s',
      [
        BoolToStr(LVerified, True),
        BoolToStr(LVerifyResult.Success, True),
        LVerifyResult.ErrorCode,
        LVerifyResult.ErrorMessage,
        LVerifyResult.DetailedInfo
      ]
    )
  );
end;

begin
  try
    TestIgnoreExpiryDoesNotLeakAcrossCalls;
    TestAllowSelfSignedDoesNotLeakAcrossCalls;
    WriteLn;
    WriteLn('[PASS] OpenSSL VerifyEx store-flag isolation contract is satisfied.');
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] Unhandled exception: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
