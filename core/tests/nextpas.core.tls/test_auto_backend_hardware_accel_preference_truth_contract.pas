program test_auto_backend_hardware_accel_preference_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.freepascal.lib
  {$IFDEF UNIX}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.openssl.base
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.mbedtls.base
  , nextpas.core.tls.wolfssl.lib
  , nextpas.core.tls.wolfssl.base
  {$ENDIF}
  {$IFDEF WINDOWS}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.winssl.lib
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  ;

const
  // Current selector formula:
  // platform score bonus = 25, balanced platform weight = 10,
  // so preferred score delta should be (25 * 10) div 100 = 2.
  HARDWARE_ACCEL_PREFERRED_SCORE_DELTA = 2;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function FindMatchByType(
  const AMatches: TSSLBackendMatchArray;
  ABackendType: TSSLLibraryType;
  out AMatch: TSSLBackendMatch
): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AMatches) do
  begin
    if AMatches[I].BackendType <> ABackendType then
      Continue;

    AMatch := AMatches[I];
    Exit(True);
  end;
end;

function AnyAvailableBackendHasHardwareAcceleration: Boolean;
var
  LType: TSSLLibraryType;
  LLib: ISSLLibrary;
begin
  Result := False;

  for LType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if LType = sslAutoDetect then
      Continue;
    if not TSSLFactory.IsLibraryAvailable(LType) then
      Continue;

    LLib := TSSLFactory.GetLibrary(LType);
    if (LLib <> nil) and LLib.GetCapabilities.HasHardwareAcceleration then
      Exit(True);
  end;
end;

procedure RequireContextBackendMatchesSelected(
  const AContext: ISSLContext;
  ASelectedType: TSSLLibraryType
);
var
  LNativeAccess: ISSLNativeHandleAccess;
begin
  if Supports(AContext, ISSLNativeHandleAccess, LNativeAccess) then
  begin
    Require(LNativeAccess.GetBackendType = ASelectedType,
      'Builder context must use the same backend selected by SelectBestBackend');
  end
  else
  begin
    Require(ASelectedType = sslFreePascal,
      'Only the FreePascal backend should lack ISSLNativeHandleAccess in this contract');
  end;
end;

procedure RequireHardwareAccelScoreTruth(
  const ABaselineMatches: TSSLBackendMatchArray;
  const APreferredMatches: TSSLBackendMatchArray
);
var
  I: Integer;
  LPreferredMatch: TSSLBackendMatch;
  LExpectedScore: Integer;
begin
  Require(Length(ABaselineMatches) = Length(APreferredMatches),
    'Hardware-accel preference must not change the qualifying backend set');

  for I := 0 to High(ABaselineMatches) do
  begin
    Require(FindMatchByType(APreferredMatches, ABaselineMatches[I].BackendType, LPreferredMatch),
      'Preferred match list must contain every baseline backend');

    if ABaselineMatches[I].Capabilities.HasHardwareAcceleration then
      LExpectedScore := ABaselineMatches[I].MatchScore + HARDWARE_ACCEL_PREFERRED_SCORE_DELTA
    else
      LExpectedScore := ABaselineMatches[I].MatchScore;

    Require(LPreferredMatch.MatchScore = LExpectedScore,
      Format('Backend %s score must follow hardware-accel preference truth (expected %d, got %d)',
        [LibraryTypeToString(ABaselineMatches[I].BackendType), LExpectedScore, LPreferredMatch.MatchScore]));
  end;
end;

var
  LBaseRequirements: TSSLRequirements;
  LPreferredRequirements: TSSLRequirements;
  LBaselineMatches: TSSLBackendMatchArray;
  LPreferredMatches: TSSLBackendMatchArray;
  LSelectedType: TSSLLibraryType;
  LSelectedScore: Integer;
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('Testing Auto-Backend Hardware-Accel Preference Truth Contract');
  WriteLn('=============================================================');

  LBaseRequirements := CreateDefaultRequirements(optBalanced);
  LBaseRequirements.MinSecurityScore := 0;
  LBaseRequirements.MinPerformanceScore := 0;
  LBaseRequirements.MinCompatibilityLevel := 0;

  LPreferredRequirements := LBaseRequirements;
  LPreferredRequirements.PlatformPreferences.PreferHardwareAccel := True;

  LBaselineMatches := SelectBestBackends(LBaseRequirements, 0);
  LPreferredMatches := SelectBestBackends(LPreferredRequirements, 0);

  Require(Length(LBaselineMatches) > 0,
    'Baseline selector must find at least one qualifying backend');
  Require(Length(LPreferredMatches) > 0,
    'Preferred selector must find at least one qualifying backend');
  Require(AnyAvailableBackendHasHardwareAcceleration,
    'Current runtime must expose at least one hardware-accelerated backend for this truth contract');

  RequireHardwareAccelScoreTruth(LBaselineMatches, LPreferredMatches);

  Require(SelectBestBackend(LPreferredRequirements, LSelectedType, LSelectedScore),
    'SelectBestBackend must succeed for hardware-accel preferred requirements');
  Require(LSelectedType = LPreferredMatches[0].BackendType,
    'SelectBestBackend must return the top-ranked backend from SelectBestBackends');
  Require(LSelectedScore = LPreferredMatches[0].MatchScore,
    'SelectBestBackend score must match the top-ranked preferred candidate');

  LBuilder := TSSLContextBuilder.Create.WithAutoBackendSelection(LPreferredRequirements);
  LResult := LBuilder.TryBuildClient(LContext);

  Require(LResult.IsOk,
    'Auto-backend builder must succeed for hardware-accel preferred requirements');
  Require(LContext <> nil,
    'Context must be created for hardware-accel preferred requirements');
  RequireContextBackendMatchesSelected(LContext, LSelectedType);

  WriteLn('✅ Auto-backend hardware-accel preference truth contract verified');
end.
