program test_capability_deserialization_roundtrip;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.capability.serializer;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertEqualBool(AExpected, AActual: Boolean; const AField: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s mismatch: expected=%s actual=%s',
      [AField, BoolToStr(AExpected, True), BoolToStr(AActual, True)]));
end;

procedure AssertEqualInt(AExpected, AActual: Integer; const AField: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s mismatch: expected=%d actual=%d', [AField, AExpected, AActual]));
end;

procedure AssertEqualStr(const AExpected, AActual, AField: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s mismatch: expected="%s" actual="%s"', [AField, AExpected, AActual]));
end;

procedure AssertEqualCipherSet(const AExpected, AActual: TSSLCipherSupport;
  const AField: string);
begin
  if AExpected <> AActual then
    Fail(AField + ' mismatch');
end;

procedure AssertEqualHashSet(const AExpected, AActual: TSSLHashSupport;
  const AField: string);
begin
  if AExpected <> AActual then
    Fail(AField + ' mismatch');
end;

procedure AssertEqualKeyExchangeSet(const AExpected, AActual: TSSLKeyExchangeSupport;
  const AField: string);
begin
  if AExpected <> AActual then
    Fail(AField + ' mismatch');
end;

procedure AssertRoundTripEqual(const AExpected, AActual: TSSLBackendCapabilities;
  const ALabel: string);
begin
  AssertEqualBool(AExpected.SupportsTLS13, AActual.SupportsTLS13, ALabel + '.supportsTLS13');
  AssertEqualBool(AExpected.SupportsALPN, AActual.SupportsALPN, ALabel + '.supportsALPN');
  AssertEqualBool(AExpected.SupportsSNI, AActual.SupportsSNI, ALabel + '.supportsSNI');
  AssertEqualInt(Ord(AExpected.MinTLSVersion), Ord(AActual.MinTLSVersion), ALabel + '.minTLSVersion');
  AssertEqualInt(Ord(AExpected.MaxTLSVersion), Ord(AActual.MaxTLSVersion), ALabel + '.maxTLSVersion');

  AssertEqualInt(Ord(AExpected.BackendType), Ord(AActual.BackendType), ALabel + '.backendType');
  AssertEqualInt(Ord(AExpected.BackendImplType), Ord(AActual.BackendImplType), ALabel + '.backendImplType');
  AssertEqualStr(AExpected.BackendVersion, AActual.BackendVersion, ALabel + '.backendVersion');
  AssertEqualBool(AExpected.SupportsDTLS, AActual.SupportsDTLS, ALabel + '.supportsDTLS');

  AssertEqualInt(Ord(AExpected.SNISupport), Ord(AActual.SNISupport), ALabel + '.sniSupport');
  AssertEqualInt(Ord(AExpected.ALPNSupport), Ord(AActual.ALPNSupport), ALabel + '.alpnSupport');
  AssertEqualInt(Ord(AExpected.OCSPStaplingSupport), Ord(AActual.OCSPStaplingSupport), ALabel + '.ocspStaplingSupport');
  AssertEqualInt(Ord(AExpected.CertTransparencySupport), Ord(AActual.CertTransparencySupport), ALabel + '.certTransparencySupport');
  AssertEqualInt(Ord(AExpected.SessionTicketsSupport), Ord(AActual.SessionTicketsSupport), ALabel + '.sessionTicketsSupport');
  AssertEqualInt(Ord(AExpected.SessionCacheSupport), Ord(AActual.SessionCacheSupport), ALabel + '.sessionCacheSupport');
  AssertEqualInt(Ord(AExpected.ZeroRTTSupport), Ord(AActual.ZeroRTTSupport), ALabel + '.zeroRTTSupport');
  AssertEqualInt(Ord(AExpected.EarlyDataSupport), Ord(AActual.EarlyDataSupport), ALabel + '.earlyDataSupport');
  AssertEqualInt(Ord(AExpected.RenegotiationSupport), Ord(AActual.RenegotiationSupport), ALabel + '.renegotiationSupport');
  AssertEqualInt(Ord(AExpected.PostHandshakeAuthSupport), Ord(AActual.PostHandshakeAuthSupport), ALabel + '.postHandshakeAuthSupport');

  AssertEqualCipherSet(AExpected.SupportedCiphers, AActual.SupportedCiphers, ALabel + '.supportedCiphers');
  AssertEqualHashSet(AExpected.SupportedHashes, AActual.SupportedHashes, ALabel + '.supportedHashes');
  AssertEqualKeyExchangeSet(AExpected.SupportedKeyExchanges, AActual.SupportedKeyExchanges, ALabel + '.supportedKeyExchanges');

  AssertEqualBool(AExpected.HasHardwareAcceleration, AActual.HasHardwareAcceleration, ALabel + '.hasHardwareAcceleration');
  AssertEqualBool(AExpected.HasConstantTimeOperations, AActual.HasConstantTimeOperations, ALabel + '.hasConstantTimeOperations');
  AssertEqualBool(AExpected.SupportsDERPrivateKey, AActual.SupportsDERPrivateKey, ALabel + '.supportsDERPrivateKey');
  AssertEqualBool(AExpected.SupportsPKCS8PrivateKey, AActual.SupportsPKCS8PrivateKey, ALabel + '.supportsPKCS8PrivateKey');
  AssertEqualBool(AExpected.SupportsPKCS12, AActual.SupportsPKCS12, ALabel + '.supportsPKCS12');
  AssertEqualBool(AExpected.SupportsPasswordProtectedKeys, AActual.SupportsPasswordProtectedKeys, ALabel + '.supportsPasswordProtectedKeys');
  AssertEqualBool(AExpected.SupportsCustomCipherSuites, AActual.SupportsCustomCipherSuites, ALabel + '.supportsCustomCipherSuites');
  AssertEqualBool(AExpected.SupportsCallbacks, AActual.SupportsCallbacks, ALabel + '.supportsCallbacks');

  AssertEqualInt(AExpected.CompatibilityLevel, AActual.CompatibilityLevel, ALabel + '.compatibilityLevel');
  AssertEqualStr(AExpected.KnownIssues, AActual.KnownIssues, ALabel + '.knownIssues');
end;

procedure TestJSONRoundTrip;
var
  LLib: TOpenSSLLibrary;
  LOriginal: TSSLBackendCapabilities;
  LRecovered: TSSLBackendCapabilities;
  LJSON: string;
begin
  WriteLn('=== JSON Round-trip Test ===');

  LLib := TOpenSSLLibrary.Create;
  try
    if not LLib.Initialize then
      Fail('OpenSSL initialization failed');

    LOriginal := LLib.GetCapabilities;
    LJSON := CapabilitiesToJSON(LOriginal, True);

    try
      LRecovered := JSONToCapabilities(LJSON);
    except
      on E: Exception do
        Fail('JSONToCapabilities raised exception: ' + E.Message);
    end;

    AssertRoundTripEqual(LOriginal, LRecovered, 'json');
    WriteLn('✅ JSON round-trip passed');
  finally
    LLib.Free;
  end;
end;

procedure TestXMLRoundTrip;
var
  LLib: TOpenSSLLibrary;
  LOriginal: TSSLBackendCapabilities;
  LRecovered: TSSLBackendCapabilities;
  LXML: string;
begin
  WriteLn('=== XML Round-trip Test ===');

  LLib := TOpenSSLLibrary.Create;
  try
    if not LLib.Initialize then
      Fail('OpenSSL initialization failed');

    LOriginal := LLib.GetCapabilities;
    LXML := CapabilitiesToXML(LOriginal, True);

    try
      LRecovered := XMLToCapabilities(LXML);
    except
      on E: Exception do
        Fail('XMLToCapabilities raised exception: ' + E.Message);
    end;

    AssertRoundTripEqual(LOriginal, LRecovered, 'xml');
    WriteLn('✅ XML round-trip passed');
  finally
    LLib.Free;
  end;
end;

begin
  WriteLn('fafafa.ssl capability deserialization round-trip tests');
  WriteLn('==============================================');
  TestJSONRoundTrip;
  TestXMLRoundTrip;
  WriteLn('==============================================');
  WriteLn('✅ all round-trip tests passed');
end.
