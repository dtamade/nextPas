program test_mbedtls_connection_peer_certificate_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.api,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.connection,
  nextpas.core.tls.mbedtls.certificate,
  nextpas.core.tls.mbedtls.native_handle;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GStubPeerCert: Pmbedtls_x509_crt = nil;

// INTENTIONAL_CORE_SURFACE: this backend proof file intentionally keeps direct
// core GetPeerCertificateChain coverage as runtime proof. Generic
// ISSLCertificateVerification owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function StubMbedTLSSSLGetPeerCert(ssl: Pmbedtls_ssl_context): Pmbedtls_x509_crt; cdecl;
begin
  Result := GStubPeerCert;
end;

function CaptureCertHandle(const ACert: ISSLCertificate): Pointer;
var
  LNative: ISSLNativeHandleAccess;
begin
  Result := nil;
  if (ACert <> nil) and Supports(ACert, ISSLNativeHandleAccess, LNative) then
    Result := LNative.GetNativeHandle;
end;

function ReadTextFile(const AFileName: string): string;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  Result := '';
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LBytes, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LBytes[0], LStream.Size);
  finally
    LStream.Free;
  end;

  if Length(LBytes) > 0 then
    SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
end;

procedure TestConnectionPeerCertificateMustMaterializeOwnedCopy;
var
  LFixture: TMbedTLSCertificate;
  LLeafFixture: TMbedTLSCertificate;
  LIssuerFixture: TMbedTLSCertificate;
  LStream: TMemoryStream;
  LConn: TMbedTLSConnection;
  LCert: ISSLCertificate;
  LIssuerFromPeerCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LLeafPEM: string;
  LIssuerPEM: string;
  LCombinedPEM: string;
  LExpectedLeafFingerprint: string;
  LExpectedIssuerFingerprint: string;
  LFixtureHandle: Pointer;
  LOriginalGetPeerCert: Tmbedtls_ssl_get_peer_cert;
  LOriginalParse: Tmbedtls_x509_crt_parse;
begin
  WriteLn;
  WriteLn('=== MbedTLS connection peer certificate chain completeness ===');

  if (not Assigned(mbedtls_ssl_set_bio)) or
     (not Assigned(mbedtls_x509_crt_parse)) then
  begin
    MarkSkip('mbedtls connection peer certificate contract',
      'required baseline MbedTLS SSL/X509 helpers are unavailable');
    Exit;
  end;

  LLeafPEM := ReadTextFile('tests/certificate/test_certs/signer_cert.pem');
  LIssuerPEM := ReadTextFile('tests/certificate/test_certs/ca_cert.pem');
  if (LLeafPEM = '') or (LIssuerPEM = '') then
  begin
    MarkSkip('mbedtls connection peer certificate contract',
      'failed to read signer/issuer PEM fixtures');
    Exit;
  end;

  LLeafFixture := TMbedTLSCertificate.Create;
  if not LLeafFixture.LoadFromPEM(LLeafPEM) then
  begin
    LLeafFixture.Free;
    MarkSkip('mbedtls connection peer certificate contract',
      'failed to load signer_cert.pem fixture');
    Exit;
  end;

  LIssuerFixture := TMbedTLSCertificate.Create;
  if not LIssuerFixture.LoadFromPEM(LIssuerPEM) then
  begin
    LLeafFixture.Free;
    LIssuerFixture.Free;
    MarkSkip('mbedtls connection peer certificate contract',
      'failed to load ca_cert.pem fixture');
    Exit;
  end;

  LFixture := TMbedTLSCertificate.Create;
  LCombinedPEM := LLeafPEM + LineEnding + LIssuerPEM;
  if not LFixture.LoadFromPEM(LCombinedPEM) then
  begin
    LLeafFixture.Free;
    LIssuerFixture.Free;
    LFixture.Free;
    MarkSkip('mbedtls connection peer certificate contract',
      'failed to load combined signer/issuer PEM chain fixture');
    Exit;
  end;

  LExpectedLeafFingerprint := LLeafFixture.GetFingerprintSHA256;
  LExpectedIssuerFingerprint := LIssuerFixture.GetFingerprintSHA256;
  LFixtureHandle := LFixture.GetNativeHandle;
  GStubPeerCert := Pmbedtls_x509_crt(LFixtureHandle);

  LOriginalGetPeerCert := mbedtls_ssl_get_peer_cert;
  LOriginalParse := mbedtls_x509_crt_parse;
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TMbedTLSConnection.Create(nil, nil, LStream);

    mbedtls_ssl_get_peer_cert := @StubMbedTLSSSLGetPeerCert;

    LCert := LConn.GetPeerCertificate;
    AssertTrue('GetPeerCertificate should materialize a certificate',
      LCert <> nil);
    AssertTrue('GetPeerCertificate fingerprint should match the fixture',
      (LCert <> nil) and SameText(LCert.GetFingerprintSHA256, LExpectedLeafFingerprint));
    AssertTrue('GetPeerCertificate must return an owned copy instead of the borrowed source handle',
      (LCert <> nil) and (CaptureCertHandle(LCert) <> nil) and
      (CaptureCertHandle(LCert) <> LFixtureHandle));
    LIssuerFromPeerCert := nil;
    if LCert <> nil then
      LIssuerFromPeerCert := LCert.GetIssuerCertificate;
    AssertTrue('GetPeerCertificate should preserve issuer link',
      LIssuerFromPeerCert <> nil);
    AssertTrue('GetPeerCertificate issuer link should match the issuer fixture',
      (LIssuerFromPeerCert <> nil) and
      SameText(LIssuerFromPeerCert.GetFingerprintSHA256, LExpectedIssuerFingerprint));

    LChain := LConn.GetPeerCertificateChain;
    AssertTrue('GetPeerCertificateChain should expose the peer leaf and issuer',
      Length(LChain) = 2,
      Format('expected chain length 2 but got %d', [Length(LChain)]));
    AssertTrue('GetPeerCertificateChain leaf fingerprint should match the fixture',
      (Length(LChain) >= 1) and SameText(LChain[0].GetFingerprintSHA256, LExpectedLeafFingerprint));
    AssertTrue('GetPeerCertificateChain leaf must also be an owned copy',
      (Length(LChain) >= 1) and (CaptureCertHandle(LChain[0]) <> nil) and
      (CaptureCertHandle(LChain[0]) <> LFixtureHandle));
    AssertTrue('GetPeerCertificateChain issuer entry should match the fixture',
      (Length(LChain) >= 2) and SameText(LChain[1].GetFingerprintSHA256, LExpectedIssuerFingerprint));
    AssertTrue('GetPeerCertificateChain leaf should preserve issuer link',
      (Length(LChain) >= 1) and (LChain[0].GetIssuerCertificate <> nil));
    AssertTrue('GetPeerCertificateChain leaf issuer link should match the issuer entry',
      (Length(LChain) >= 1) and (LChain[0].GetIssuerCertificate <> nil) and
      SameText(LChain[0].GetIssuerCertificate.GetFingerprintSHA256, LExpectedIssuerFingerprint));
    AssertTrue('GetPeerCertificateChain issuer entry should not invent a higher issuer link',
      (Length(LChain) >= 2) and (LChain[1].GetIssuerCertificate = nil));

    mbedtls_x509_crt_parse := nil;
    LCert := LConn.GetPeerCertificate;
    AssertTrue('GetPeerCertificate should fail closed when cert-copy helper is unavailable',
      LCert = nil);
    LChain := LConn.GetPeerCertificateChain;
    AssertTrue('GetPeerCertificateChain should fail closed when cert-copy helper is unavailable',
      Length(LChain) = 0,
      Format('expected empty chain but got %d entries', [Length(LChain)]));
  finally
    mbedtls_ssl_get_peer_cert := LOriginalGetPeerCert;
    mbedtls_x509_crt_parse := LOriginalParse;
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
    LIssuerFixture.Free;
    LLeafFixture.Free;
    LFixture.Free;
    GStubPeerCert := nil;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('MbedTLS Connection Peer Certificate Contract Test');
  WriteLn('========================================');

  try
    GLib := CreateMbedTLSLibrary;
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('mbedtls connection peer certificate contract',
        'failed to initialize MbedTLS library');

    if SkippedTests = 0 then
      TestConnectionPeerCertificateMustMaterializeOwnedCopy;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
