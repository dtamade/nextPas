program test_wolfssl_metadata_accuracy;

{$mode ObjFPC}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.certificate,
  nextpas.core.tls.wolfssl.session;

var
  TestsSkipped: Integer = 0;
  SkipDependency: Integer = 0;
  SkipCapability: Integer = 0;
  SkipOther: Integer = 0;

procedure SkipTest(const AMessage: string; const ACategory: string = 'other');
begin
  Inc(TestsSkipped);

  if LowerCase(ACategory) = 'dependency' then
    Inc(SkipDependency)
  else if LowerCase(ACategory) = 'capability' then
    Inc(SkipCapability)
  else
    Inc(SkipOther);

  WriteLn('[SKIP] [', ACategory, '] ', AMessage);
end;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d, actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertEqualStr(const AExpected, AActual, AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected="%s", actual="%s")', [AMessage, AExpected, AActual]));
end;

procedure TestEmptyCertificateMetadata;
var
  LCert: TWolfSSLCertificate;
begin
  WriteLn('=== Empty certificate metadata ===');
  LCert := TWolfSSLCertificate.Create;
  try
    AssertTrue(LCert.GetNotBefore = 0, 'NotBefore should be unknown for empty cert');
    AssertTrue(LCert.GetNotAfter = 0, 'NotAfter should be unknown for empty cert');
    AssertTrue(not LCert.IsExpired, 'Empty cert should not be misreported as expired');
    AssertEqualInt(0, LCert.GetDaysUntilExpiry, 'Empty cert days-until-expiry should be 0');
    AssertEqualStr('', LCert.GetFingerprintSHA1, 'Empty cert SHA1 fingerprint should be empty');
    AssertEqualStr('', LCert.GetFingerprintSHA256, 'Empty cert SHA256 fingerprint should be empty');
  finally
    LCert.Free;
  end;
end;

procedure TestLoadedCertificateMetadata;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LPEM: string;
  LDER: TBytes;
  LNotBefore: TDateTime;
  LNotAfter: TDateTime;
begin
  WriteLn('=== Loaded certificate metadata ===');
  LLib := CreateWolfSSLLibrary;
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    SkipTest('WolfSSL runtime unavailable; loaded-certificate metadata test skipped', 'dependency');
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    AssertTrue(LCert.LoadFromFile('tests/certs/server-cert.pem'),
      'Should load tests/certs/server-cert.pem');

    LPEM := LCert.SaveToPEM;
    AssertTrue(LPEM <> '', 'PEM export should not be empty after loading cert');

    LDER := LCert.SaveToDER;
    AssertTrue(Length(LDER) > 0, 'DER export should not be empty after loading cert');

    AssertTrue(Length(LCert.GetFingerprintSHA1) = 40,
      'SHA1 fingerprint should be 40 hex chars');
    AssertTrue(Length(LCert.GetFingerprintSHA256) = 64,
      'SHA256 fingerprint should be 64 hex chars');

    LNotBefore := LCert.GetNotBefore;
    LNotAfter := LCert.GetNotAfter;

    AssertTrue(LNotBefore > 0,
      'NotBefore should be decoded (wolfSSL API or DER fallback)');
    AssertTrue(LNotAfter > 0,
      'NotAfter should be decoded (wolfSSL API or DER fallback)');
    AssertTrue(LNotAfter >= LNotBefore,
      'notAfter should be equal or later than notBefore');
    AssertTrue(Abs(LNotAfter - LNotBefore) > (1.0 / SecsPerDay),
      'Certificate validity window should be non-trivial');
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;


procedure TestIsCABasicConstraints;
var
  LLib: ISSLLibrary;
  LCaCert: TWolfSSLCertificate;
  LLeafCert: TWolfSSLCertificate;
begin
  WriteLn('=== IsCA basic constraints ===');
  LLib := CreateWolfSSLLibrary;
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    SkipTest('WolfSSL runtime unavailable; IsCA metadata checks skipped', 'dependency');
    Exit;
  end;

  LCaCert := TWolfSSLCertificate.Create;
  LLeafCert := TWolfSSLCertificate.Create;
  try
    AssertTrue(LCaCert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
      'Should load CA certificate fixture');
    AssertTrue(LCaCert.IsCA,
      'CA certificate should report IsCA=True');

    AssertTrue(LLeafCert.LoadFromFile('tests/certificate/test_certs/recipient_cert.pem'),
      'Should load leaf certificate fixture (non-CA)');
    AssertTrue(not LLeafCert.IsCA,
      'Leaf certificate should report IsCA=False');
  finally
    LLeafCert.Free;
    LCaCert.Free;
    LLib.Finalize;
  end;
end;


procedure TestSubjectAltNamesCoverage;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LSANs: TSSLStringArray;
  I: Integer;
  LFoundPrimary: Boolean;
  LFoundSecondary: Boolean;
begin
  WriteLn('=== SubjectAltNames extraction ===');
  LLib := CreateWolfSSLLibrary;
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    SkipTest('WolfSSL runtime unavailable; SAN extraction checks skipped', 'dependency');
    Exit;
  end;

  if not Assigned(wolfSSL_X509_get_next_altname) then
  begin
    SkipTest('WolfSSL SAN API unavailable; SAN extraction checks skipped', 'capability');
    LLib.Finalize;
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    AssertTrue(LCert.LoadFromFile('tests/certs/san-test.pem'),
      'Should load SAN fixture tests/certs/san-test.pem');

    LSANs := LCert.GetSubjectAltNames;
    AssertTrue(Length(LSANs) >= 2,
      'SAN fixture should expose at least two DNS SAN entries');

    LFoundPrimary := False;
    LFoundSecondary := False;
    for I := 0 to High(LSANs) do
    begin
      if SameText(Trim(LSANs[I]), 'san-test.local') then
        LFoundPrimary := True;
      if SameText(Trim(LSANs[I]), 'example.test') then
        LFoundSecondary := True;
    end;

    AssertTrue(LFoundPrimary,
      'SAN list should contain san-test.local');
    AssertTrue(LFoundSecondary,
      'SAN list should contain example.test');
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestDefaultSessionMetadata;
var
  LSession: TWolfSSLSession;
begin
  WriteLn('=== Default session metadata ===');
  LSession := TWolfSSLSession.Create;
  try
    AssertTrue(LSession.GetProtocolVersion = sslProtocolUnknown,
      'Default session protocol should be unknown');
    AssertEqualStr('unknown', LSession.GetCipherName,
      'Default session cipher should be explicit unknown');
  finally
    LSession.Free;
  end;
end;

procedure TestInvalidCertificateInputRejection;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LBadDER: TBytes;
  LPEMBuf: AnsiString;
begin
  WriteLn('=== Invalid certificate input rejection ===');
  LLib := CreateWolfSSLLibrary;
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    SkipTest('WolfSSL runtime unavailable; invalid-input checks skipped', 'dependency');
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    AssertTrue(LCert.LoadFromFile('tests/certs/server-cert.pem'),
      'Precondition: should load valid certificate fixture');
    AssertTrue(Length(LCert.SaveToDER) > 0,
      'Precondition: valid certificate should expose DER data');

    AssertTrue(not LCert.LoadFromMemory(nil, 0),
      'LoadFromMemory should reject nil/zero input');
    AssertTrue(Length(LCert.SaveToDER) = 0,
      'LoadFromMemory failure should clear previously loaded DER state');

    SetLength(LBadDER, 4);
    LBadDER[0] := $30;
    LBadDER[1] := $82;
    LBadDER[2] := $00;
    LBadDER[3] := $01;
    AssertTrue(not LCert.LoadFromDER(LBadDER),
      'LoadFromDER should reject malformed DER payload');
    AssertTrue(Length(LCert.SaveToDER) = 0,
      'LoadFromDER failure should keep DER state empty');

    AssertTrue(not LCert.LoadFromPEM('not a pem cert'),
      'LoadFromPEM should reject malformed PEM text');
    AssertTrue(Length(LCert.SaveToDER) = 0,
      'LoadFromPEM failure should keep DER state empty');

    LPEMBuf := AnsiString('-----BEGIN CERTIFICATE-----' + LineEnding +
      'invalid' + LineEnding +
      '-----END CERTIFICATE-----');
    AssertTrue(not LCert.LoadFromMemory(@LPEMBuf[1], Length(LPEMBuf)),
      'LoadFromMemory should reject malformed PEM text');
    AssertTrue(Length(LCert.SaveToDER) = 0,
      'LoadFromMemory PEM-text failure should keep state empty');
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestProtocolMappingDefaults;
begin
  WriteLn('=== Protocol mapping defaults ===');
  AssertTrue(WolfSSLProtocolToSSL($0303) = sslProtocolTLS12,
    'TLS1.2 mapping should remain stable');
  AssertTrue(WolfSSLProtocolToSSL($0304) = sslProtocolTLS13,
    'TLS1.3 mapping should remain stable');
  AssertTrue(WolfSSLProtocolToSSL($1234) = sslProtocolUnknown,
    'Unknown wire protocol should map to unknown');
end;

begin
  WriteLn('fafafa.ssl wolfssl metadata accuracy tests');
  WriteLn('============================================');

  TestEmptyCertificateMetadata;
  TestLoadedCertificateMetadata;
  TestIsCABasicConstraints;
  TestSubjectAltNamesCoverage;
  TestDefaultSessionMetadata;
  TestInvalidCertificateInputRejection;
  TestProtocolMappingDefaults;

  WriteLn('============================================');
  WriteLn('Skipped: ', TestsSkipped,
    ' (dependency=', SkipDependency, ', capability=', SkipCapability, ', other=', SkipOther, ')');
  WriteLn('✅ wolfssl metadata accuracy tests passed');
end.
