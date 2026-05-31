program test_capability_serialization_support_level_truth;

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

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

function ContainsTextInsensitive(const AText, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AText)) > 0;
end;

procedure TestSupportLevelTruthOverridesLegacyBooleansJSON;
var
  LCaps: TSSLBackendCapabilities;
  LRoundTrip: TSSLBackendCapabilities;
  LJSON: string;
begin
  LCaps := Default(TSSLBackendCapabilities);
  LCaps.SupportsSNI := True;
  LCaps.SNISupport := sslSupportNone;
  LCaps.SupportsOCSPStapling := True;
  LCaps.OCSPStaplingSupport := sslSupportNone;
  LCaps.SupportsSessionTickets := False;
  LCaps.SessionTicketsSupport := sslSupportStable;

  LJSON := CapabilitiesToJSON(LCaps, False);
  Require(ContainsTextInsensitive(LJSON, '"supportsSNI": false'),
    'JSON should normalize supportsSNI from support-level truth');
  Require(ContainsTextInsensitive(LJSON, '"supportsOCSPStapling": false'),
    'JSON should normalize supportsOCSPStapling from support-level truth');
  Require(ContainsTextInsensitive(LJSON, '"supportsSessionTickets": true'),
    'JSON should normalize supportsSessionTickets from support-level truth');
  Require(ContainsTextInsensitive(LJSON, '"sniSupport": "none"'),
    'JSON should still emit explicit sniSupport when support-level truth is present');

  LRoundTrip := JSONToCapabilities(LJSON);
  Require(not LRoundTrip.SupportsSNI,
    'JSON round-trip should keep support-level none as SupportsSNI=false');
  Require(not LRoundTrip.SupportsOCSPStapling,
    'JSON round-trip should keep support-level none as SupportsOCSPStapling=false');
  Require(LRoundTrip.SupportsSessionTickets,
    'JSON round-trip should keep stable SessionTickets support as true');
  Require(LRoundTrip.SNISupport = sslSupportNone,
    'JSON round-trip should preserve SNISupport');
  Require(LRoundTrip.OCSPStaplingSupport = sslSupportNone,
    'JSON round-trip should preserve OCSPStaplingSupport');
  Require(LRoundTrip.SessionTicketsSupport = sslSupportStable,
    'JSON round-trip should preserve SessionTicketsSupport');
end;

procedure TestLegacyOnlyTruthRoundTripJSON;
var
  LCaps: TSSLBackendCapabilities;
  LRoundTrip: TSSLBackendCapabilities;
  LJSON: string;
begin
  LCaps := Default(TSSLBackendCapabilities);
  LCaps.SupportsSNI := True;
  LCaps.SupportsOCSPStapling := True;
  LCaps.SupportsSessionTickets := False;

  LJSON := CapabilitiesToJSON(LCaps, False);
  Require(not ContainsTextInsensitive(LJSON, '"sniSupport"'),
    'legacy-only JSON should omit sniSupport');
  Require(not ContainsTextInsensitive(LJSON, '"ocspStaplingSupport"'),
    'legacy-only JSON should omit ocspStaplingSupport');
  Require(not ContainsTextInsensitive(LJSON, '"sessionTicketsSupport"'),
    'legacy-only JSON should omit sessionTicketsSupport');

  LRoundTrip := JSONToCapabilities(LJSON);
  Require(LRoundTrip.SupportsSNI,
    'legacy-only JSON round-trip should preserve SupportsSNI');
  Require(LRoundTrip.SupportsOCSPStapling,
    'legacy-only JSON round-trip should preserve SupportsOCSPStapling');
  Require(not LRoundTrip.SupportsSessionTickets,
    'legacy-only JSON round-trip should preserve SupportsSessionTickets');
  Require(LRoundTrip.SNISupport = sslSupportNone,
    'legacy-only JSON round-trip should not synthesize SNISupport truth');
end;

procedure TestSupportLevelTruthOverridesLegacyBooleansXML;
var
  LCaps: TSSLBackendCapabilities;
  LRoundTrip: TSSLBackendCapabilities;
  LXML: string;
begin
  LCaps := Default(TSSLBackendCapabilities);
  LCaps.SupportsSNI := True;
  LCaps.SNISupport := sslSupportNone;
  LCaps.SupportsOCSPStapling := True;
  LCaps.OCSPStaplingSupport := sslSupportNone;
  LCaps.SupportsSessionTickets := False;
  LCaps.SessionTicketsSupport := sslSupportStable;

  LXML := CapabilitiesToXML(LCaps, False);
  Require(ContainsTextInsensitive(LXML, '<supportsSNI>False</supportsSNI>'),
    'XML should normalize supportsSNI from support-level truth');
  Require(ContainsTextInsensitive(LXML, '<supportsOCSPStapling>False</supportsOCSPStapling>'),
    'XML should normalize supportsOCSPStapling from support-level truth');
  Require(ContainsTextInsensitive(LXML, '<supportsSessionTickets>True</supportsSessionTickets>'),
    'XML should normalize supportsSessionTickets from support-level truth');
  Require(ContainsTextInsensitive(LXML, '<sniSupport>none</sniSupport>'),
    'XML should still emit explicit sniSupport when support-level truth is present');

  LRoundTrip := XMLToCapabilities(LXML);
  Require(not LRoundTrip.SupportsSNI,
    'XML round-trip should keep support-level none as SupportsSNI=false');
  Require(not LRoundTrip.SupportsOCSPStapling,
    'XML round-trip should keep support-level none as SupportsOCSPStapling=false');
  Require(LRoundTrip.SupportsSessionTickets,
    'XML round-trip should keep stable SessionTickets support as true');
end;

procedure TestLegacyOnlyTruthRoundTripXML;
var
  LCaps: TSSLBackendCapabilities;
  LRoundTrip: TSSLBackendCapabilities;
  LXML: string;
begin
  LCaps := Default(TSSLBackendCapabilities);
  LCaps.SupportsSNI := True;
  LCaps.SupportsOCSPStapling := True;
  LCaps.SupportsSessionTickets := False;

  LXML := CapabilitiesToXML(LCaps, False);
  Require(not ContainsTextInsensitive(LXML, '<sniSupport>'),
    'legacy-only XML should omit sniSupport');
  Require(not ContainsTextInsensitive(LXML, '<ocspStaplingSupport>'),
    'legacy-only XML should omit ocspStaplingSupport');
  Require(not ContainsTextInsensitive(LXML, '<sessionTicketsSupport>'),
    'legacy-only XML should omit sessionTicketsSupport');

  LRoundTrip := XMLToCapabilities(LXML);
  Require(LRoundTrip.SupportsSNI,
    'legacy-only XML round-trip should preserve SupportsSNI');
  Require(LRoundTrip.SupportsOCSPStapling,
    'legacy-only XML round-trip should preserve SupportsOCSPStapling');
  Require(not LRoundTrip.SupportsSessionTickets,
    'legacy-only XML round-trip should preserve SupportsSessionTickets');
  Require(LRoundTrip.SNISupport = sslSupportNone,
    'legacy-only XML round-trip should not synthesize SNISupport truth');
end;

begin
  TestSupportLevelTruthOverridesLegacyBooleansJSON;
  TestLegacyOnlyTruthRoundTripJSON;
  TestSupportLevelTruthOverridesLegacyBooleansXML;
  TestLegacyOnlyTruthRoundTripXML;
  WriteLn('PASS: capability serialization support-level truth');
end.
