program test_capability_diff_support_level_truth;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.capability.diff;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

function HasChangedField(const ADiff: TCapabilityDiffResult;
  const AFieldName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ADiff.ChangedFields) do
    if SameText(ADiff.ChangedFields[I].FieldName, AFieldName) then
      Exit(True);
end;

procedure TestSupportLevelChangesAreNotIgnored;
var
  Caps1, Caps2: TSSLBackendCapabilities;
  Diff: TCapabilityDiffResult;
begin
  FillChar(Caps1, SizeOf(Caps1), 0);
  FillChar(Caps2, SizeOf(Caps2), 0);

  Caps1.SupportsSNI := True;
  Caps2.SupportsSNI := True;
  Caps1.SNISupport := sslSupportExperimental;
  Caps2.SNISupport := sslSupportStable;

  Caps1.EarlyDataSupport := sslSupportNone;
  Caps2.EarlyDataSupport := sslSupportExperimental;

  Diff := CompareCapabilities(Caps1, Caps2);

  if not HasChangedField(Diff, 'SNISupport') then
    Fail('support-level diff missed SNISupport change');

  if not HasChangedField(Diff, 'EarlyDataSupport') then
    Fail('support-level diff missed EarlyDataSupport change');

  if HasChangedField(Diff, 'SupportsSNI') then
    Fail('support-level truth should prevent duplicate legacy SupportsSNI diff');
end;

procedure TestLegacyBooleanFallbackStillWorks;
var
  Caps1, Caps2: TSSLBackendCapabilities;
  Diff: TCapabilityDiffResult;
begin
  FillChar(Caps1, SizeOf(Caps1), 0);
  FillChar(Caps2, SizeOf(Caps2), 0);

  Caps1.SupportsSNI := False;
  Caps2.SupportsSNI := True;

  Diff := CompareCapabilities(Caps1, Caps2);

  if not HasChangedField(Diff, 'SupportsSNI') then
    Fail('legacy-only diff should still detect SupportsSNI change');
end;

begin
  TestSupportLevelChangesAreNotIgnored;
  TestLegacyBooleanFallbackStillWorks;
  WriteLn('PASS: capability diff support-level truth');
end.
