program test_capability_deserialization_truth_precedence;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.capability.serializer;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

procedure AssertEqualBool(AExpected, AActual: Boolean; const AField: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s mismatch: expected=%s actual=%s',
      [AField, BoolToStr(AExpected, True), BoolToStr(AActual, True)]));
end;

procedure AssertEqualLevel(AExpected, AActual: TSSLFeatureSupportLevel;
  const AField: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s mismatch: expected=%d actual=%d',
      [AField, Ord(AExpected), Ord(AActual)]));
end;

procedure TestJSONSupportLevelOverridesLegacyBool;
const
  JSONInput =
    '{' +
    '"supportsSNI":true,' +
    '"sniSupport":"none",' +
    '"supportsALPN":false,' +
    '"alpnSupport":"stable",' +
    '"supportsOCSPStapling":true,' +
    '"ocspStaplingSupport":"none",' +
    '"supportsCertificateTransparency":false,' +
    '"certTransparencySupport":"experimental",' +
    '"supportsSessionTickets":false,' +
    '"sessionTicketsSupport":"stable"' +
    '}';
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := JSONToCapabilities(JSONInput);

  AssertEqualBool(False, Caps.SupportsSNI, 'json.supportsSNI');
  AssertEqualLevel(sslSupportNone, Caps.SNISupport, 'json.sniSupport');

  AssertEqualBool(True, Caps.SupportsALPN, 'json.supportsALPN');
  AssertEqualLevel(sslSupportStable, Caps.ALPNSupport, 'json.alpnSupport');

  AssertEqualBool(False, Caps.SupportsOCSPStapling, 'json.supportsOCSPStapling');
  AssertEqualLevel(sslSupportNone, Caps.OCSPStaplingSupport, 'json.ocspStaplingSupport');

  AssertEqualBool(True, Caps.SupportsCertificateTransparency,
    'json.supportsCertificateTransparency');
  AssertEqualLevel(sslSupportExperimental, Caps.CertTransparencySupport,
    'json.certTransparencySupport');

  AssertEqualBool(True, Caps.SupportsSessionTickets, 'json.supportsSessionTickets');
  AssertEqualLevel(sslSupportStable, Caps.SessionTicketsSupport,
    'json.sessionTicketsSupport');
end;

procedure TestXMLSupportLevelOverridesLegacyBool;
const
  XMLInput =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<SSLBackendCapabilities>' +
    '<supportsSNI>true</supportsSNI>' +
    '<sniSupport>none</sniSupport>' +
    '<supportsALPN>false</supportsALPN>' +
    '<alpnSupport>stable</alpnSupport>' +
    '<supportsOCSPStapling>true</supportsOCSPStapling>' +
    '<ocspStaplingSupport>none</ocspStaplingSupport>' +
    '<supportsCertificateTransparency>false</supportsCertificateTransparency>' +
    '<certTransparencySupport>experimental</certTransparencySupport>' +
    '<supportsSessionTickets>false</supportsSessionTickets>' +
    '<sessionTicketsSupport>stable</sessionTicketsSupport>' +
    '</SSLBackendCapabilities>';
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := XMLToCapabilities(XMLInput);

  AssertEqualBool(False, Caps.SupportsSNI, 'xml.supportsSNI');
  AssertEqualLevel(sslSupportNone, Caps.SNISupport, 'xml.sniSupport');

  AssertEqualBool(True, Caps.SupportsALPN, 'xml.supportsALPN');
  AssertEqualLevel(sslSupportStable, Caps.ALPNSupport, 'xml.alpnSupport');

  AssertEqualBool(False, Caps.SupportsOCSPStapling, 'xml.supportsOCSPStapling');
  AssertEqualLevel(sslSupportNone, Caps.OCSPStaplingSupport, 'xml.ocspStaplingSupport');

  AssertEqualBool(True, Caps.SupportsCertificateTransparency,
    'xml.supportsCertificateTransparency');
  AssertEqualLevel(sslSupportExperimental, Caps.CertTransparencySupport,
    'xml.certTransparencySupport');

  AssertEqualBool(True, Caps.SupportsSessionTickets, 'xml.supportsSessionTickets');
  AssertEqualLevel(sslSupportStable, Caps.SessionTicketsSupport,
    'xml.sessionTicketsSupport');
end;

procedure TestLegacyOnlyJSONStaysCompatible;
const
  JSONInput =
    '{' +
    '"supportsSNI":true,' +
    '"supportsALPN":false' +
    '}';
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := JSONToCapabilities(JSONInput);

  AssertEqualBool(True, Caps.SupportsSNI, 'legacy.supportsSNI');
  AssertEqualLevel(sslSupportNone, Caps.SNISupport, 'legacy.sniSupport');

  AssertEqualBool(False, Caps.SupportsALPN, 'legacy.supportsALPN');
  AssertEqualLevel(sslSupportNone, Caps.ALPNSupport, 'legacy.alpnSupport');
end;

begin
  TestJSONSupportLevelOverridesLegacyBool;
  TestXMLSupportLevelOverridesLegacyBool;
  TestLegacyOnlyJSONStaysCompatible;
  WriteLn('PASS: capability deserialization truth precedence');
end.
