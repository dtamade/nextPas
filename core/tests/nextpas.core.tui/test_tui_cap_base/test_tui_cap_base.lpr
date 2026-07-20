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

procedure TestCapabilityStatusPartialVerified;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(True, True, True, False, 'pending');
  Check(LStatus.Active and (not LStatus.Verified), 'active unverified');
  CheckEqual('pending', LStatus.FallbackReason, 'pending reason');
end;

procedure TestCapabilityStatusVerifiedClearsReason;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(True, True, True, True, '');
  Check(LStatus.Verified, 'verified');
  CheckEqual('', LStatus.FallbackReason, 'empty reason when verified');
end;

procedure TestCapabilityTierDistinct;
begin
  Check(Ord(tctCore) < Ord(tctExtended), 'core < extended');
  Check(Ord(tctExtended) < Ord(tctExperimental), 'extended < experimental');
  Check(Ord(tctExperimental) < Ord(tctFullOnly), 'experimental < full');
end;

procedure TestCapabilityPolicyDistinct;
begin
  Check(tcpAuto <> tcpEnable, 'auto != enable');
  Check(tcpDisable <> tcpRequire, 'disable != require');
end;

procedure TestCapabilityStatusCopyFields;
var
  A, B: TTuiCapabilityStatus;
begin
  A := TTuiCapabilityStatus.Create(True, False, False, False, 'x');
  B := A;
  Check(not B.Detected, 'copy detected');
  CheckEqual('x', B.FallbackReason, 'copy reason');
end;

procedure TestCapabilityStatusLongReason;
var
  LStatus: TTuiCapabilityStatus;
  LReason: string;
begin
  LReason := 'session-negotiation-pending-query-flags-zero';
  LStatus := TTuiCapabilityStatus.Create(True, True, True, False, LReason);
  CheckEqual(LReason, LStatus.FallbackReason, 'long reason stored');
end;

procedure TestCapabilityStatusRequestedOnly;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(True, False, False, False, 'env-hint-missing');
  Check(LStatus.Requested, 'requested only');
  Check(not LStatus.Detected, 'not detected');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.cap_base');
  T.Test('capability status', @TestCapabilityStatus);
  T.Test('capability status all true', @TestCapabilityStatusAllTrue);
  T.Test('capability status all false', @TestCapabilityStatusAllFalse);
  T.Test('capability tier enum', @TestCapabilityTierEnum);
  T.Test('capability policy enum', @TestCapabilityPolicyEnum);
  T.Test('partial verified pending', @TestCapabilityStatusPartialVerified);
  T.Test('verified clears reason', @TestCapabilityStatusVerifiedClearsReason);
  T.Test('tier ordering', @TestCapabilityTierDistinct);
  T.Test('policy distinct', @TestCapabilityPolicyDistinct);
  T.Test('status copy fields', @TestCapabilityStatusCopyFields);
  T.Test('long reason', @TestCapabilityStatusLongReason);
  T.Test('requested only', @TestCapabilityStatusRequestedOnly);
  if not T.Run then Halt(1);
end.
