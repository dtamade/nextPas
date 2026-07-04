program test_tui_cap_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.cap.base,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCapabilityStatus;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(True, True, False, False, 'probe-failed');
  Check(LStatus.Requested, 'requested is stored');
  Check(LStatus.Detected, 'detected is stored');
  Check(not LStatus.Active, 'active is stored');
  CheckEqual('probe-failed', LStatus.FallbackReason, 'fallback reason is stored');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.cap_base');
  T.Test('capability status', @TestCapabilityStatus);
  if not T.Run then Halt(1);
end.
