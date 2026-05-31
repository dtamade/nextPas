program test_capability_serialization_truth_projection;

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

procedure RequireContains(const AText, APattern, ALabel: string);
begin
  if Pos(APattern, AText) = 0 then
    Fail(ALabel + ' missing pattern: ' + APattern);
end;

procedure TestJSONSupportLevelProjectsLegacyBool;
var
  Caps: TSSLBackendCapabilities;
  JSONText: string;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  Caps.SupportsSNI := False;
  Caps.SNISupport := sslSupportStable;

  JSONText := CapabilitiesToJSON(Caps, False);

  RequireContains(JSONText, '"supportsSNI": true', 'json.sniProjection');
  RequireContains(JSONText, '"sniSupport": "stable"', 'json.sniSupport');
end;

procedure TestJSONSupportLevelNoneProjectsLegacyBoolWhenRecordIsV12Aware;
var
  Caps: TSSLBackendCapabilities;
  JSONText: string;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  Caps.SupportsSNI := True;
  Caps.SNISupport := sslSupportNone;
  Caps.EarlyDataSupport := sslSupportExperimental;

  JSONText := CapabilitiesToJSON(Caps, False);

  RequireContains(JSONText, '"supportsSNI": false', 'json.noneProjection');
  RequireContains(JSONText, '"sniSupport": "none"', 'json.noneSupport');
end;

procedure TestXMLSupportLevelProjectsLegacyBool;
var
  Caps: TSSLBackendCapabilities;
  XMLText: string;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  Caps.SupportsALPN := False;
  Caps.ALPNSupport := sslSupportStable;

  XMLText := CapabilitiesToXML(Caps, False);

  RequireContains(XMLText, '<supportsALPN>True</supportsALPN>', 'xml.alpnProjection');
  RequireContains(XMLText, '<alpnSupport>stable</alpnSupport>', 'xml.alpnSupport');
end;

procedure TestXMLSupportLevelNoneProjectsLegacyBoolWhenRecordIsV12Aware;
var
  Caps: TSSLBackendCapabilities;
  XMLText: string;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  Caps.SupportsSessionTickets := True;
  Caps.SessionTicketsSupport := sslSupportNone;
  Caps.ZeroRTTSupport := sslSupportExperimental;

  XMLText := CapabilitiesToXML(Caps, False);

  RequireContains(XMLText, '<supportsSessionTickets>False</supportsSessionTickets>', 'xml.noneProjection');
  RequireContains(XMLText, '<sessionTicketsSupport>none</sessionTicketsSupport>', 'xml.noneSupport');
end;

begin
  TestJSONSupportLevelProjectsLegacyBool;
  TestJSONSupportLevelNoneProjectsLegacyBoolWhenRecordIsV12Aware;
  TestXMLSupportLevelProjectsLegacyBool;
  TestXMLSupportLevelNoneProjectsLegacyBoolWhenRecordIsV12Aware;
  WriteLn('PASS: capability serialization truth projection');
end.
