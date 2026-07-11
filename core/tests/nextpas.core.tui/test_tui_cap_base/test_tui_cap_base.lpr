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
  Check(not LStatus.Verified, 'verified is stored');
  CheckEqual('probe-failed', LStatus.FallbackReason, 'fallback reason is stored');
end;

procedure TestCapabilityStatusAllTrue;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(True, True, True, True, '');
  Check(LStatus.Requested, 'all true requested');
  Check(LStatus.Detected, 'all true detected');
  Check(LStatus.Active, 'all true active');
  Check(LStatus.Verified, 'all true verified');
  CheckEqual('', LStatus.FallbackReason, 'empty fallback');
end;

procedure TestCapabilityStatusAllFalse;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(False, False, False, False, 'not available');
  Check(not LStatus.Requested, 'all false requested');
  Check(not LStatus.Detected, 'all false detected');
  Check(not LStatus.Active, 'all false active');
  Check(not LStatus.Verified, 'all false verified');
  CheckEqual('not available', LStatus.FallbackReason, 'fallback reason');
end;

procedure TestCapabilityTierEnum;
var
  LTier: TTuiCapabilityTier;
begin
  LTier := tctCore;
  Check(LTier = tctCore, 'core tier');
  LTier := tctExtended;
  Check(LTier = tctExtended, 'extended tier');
  LTier := tctExperimental;
  Check(LTier = tctExperimental, 'experimental tier');
  LTier := tctFullOnly;
  Check(LTier = tctFullOnly, 'full only tier');
end;

procedure TestCapabilityPolicyEnum;
var
  LPolicy: TTuiCapabilityPolicy;
begin
  LPolicy := tcpAuto;
  Check(LPolicy = tcpAuto, 'auto policy');
  LPolicy := tcpEnable;
  Check(LPolicy = tcpEnable, 'enable policy');
  LPolicy := tcpDisable;
  Check(LPolicy = tcpDisable, 'disable policy');
  LPolicy := tcpRequire;
  Check(LPolicy = tcpRequire, 'require policy');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.cap_base');
  T.Test('capability status', @TestCapabilityStatus);
  T.Test('capability status all true', @TestCapabilityStatusAllTrue);
  T.Test('capability status all false', @TestCapabilityStatusAllFalse);
  T.Test('capability tier enum', @TestCapabilityTierEnum);
  T.Test('capability policy enum', @TestCapabilityPolicyEnum);
  if not T.Run then Halt(1);
end.
