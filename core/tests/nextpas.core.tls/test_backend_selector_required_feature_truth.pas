program test_backend_selector_required_feature_truth;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

function FeatureLevelPresent(ALevel: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ALevel <> sslSupportNone;
end;

function BackendSupportsFeature(
  const ACaps: TSSLBackendCapabilities;
  AFeature: TSSLFeature
): Boolean;
begin
  case AFeature of
    sslFeatSNI:
      Result := FeatureLevelPresent(ACaps.SNISupport);
    sslFeatALPN:
      Result := FeatureLevelPresent(ACaps.ALPNSupport);
    sslFeatSessionCache:
      Result := FeatureLevelPresent(ACaps.SessionCacheSupport);
    sslFeatSessionTickets:
      Result := FeatureLevelPresent(ACaps.SessionTicketsSupport);
    sslFeatRenegotiation:
      Result := FeatureLevelPresent(ACaps.RenegotiationSupport);
    sslFeatOCSPStapling:
      Result := FeatureLevelPresent(ACaps.OCSPStaplingSupport);
    sslFeatCertificateTransparency:
      Result := FeatureLevelPresent(ACaps.CertTransparencySupport);
  end;
end;

function AnyAvailableBackendSupportsFeature(AFeature: TSSLFeature): Boolean;
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
    if BackendSupportsFeature(LLib.GetCapabilities, AFeature) then
      Exit(True);
  end;
end;

function CreateSingleFeatureRequirements(AFeature: TSSLFeature): TSSLRequirements;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.RequiredProtocols := [sslProtocolTLS12];
  Result.RequiredFeatures := [AFeature];
  Result.OptimizationTarget := optBalanced;
end;

procedure Test_FeatureRequirement_IsCountedAndSatisfied(
  AFeature: TSSLFeature;
  const AFeatureLabel: string
);
var
  LRequirements: TSSLRequirements;
  LResults: TSSLBackendMatchArray;
  LExpectAnyMatch: Boolean;
  I: Integer;
begin
  TestHeader(AFeatureLabel + ' required feature participates in selector scoring');

  LRequirements := CreateSingleFeatureRequirements(AFeature);
  LExpectAnyMatch := AnyAvailableBackendSupportsFeature(AFeature);
  LResults := SelectBestBackends(LRequirements, 10);

  if LExpectAnyMatch then
    Assert(Length(LResults) > 0,
      'At least one available backend satisfies ' + AFeatureLabel + ' requirement')
  else
    Assert(Length(LResults) = 0,
      'Selector returns no backends when ' + AFeatureLabel + ' is unavailable everywhere');

  for I := 0 to High(LResults) do
  begin
    Assert(LResults[I].MatchDetails.RequiredFeaturesTotal = 2,
      'RequiredFeaturesTotal counts TLS12 + ' + AFeatureLabel + ' for result #' + IntToStr(I + 1));
    Assert(LResults[I].MatchDetails.RequiredFeaturesMatched = 2,
      'RequiredFeaturesMatched counts TLS12 + ' + AFeatureLabel + ' for result #' + IntToStr(I + 1));
    Assert(BackendSupportsFeature(LResults[I].Capabilities, AFeature),
      'Returned result #' + IntToStr(I + 1) + ' really supports ' + AFeatureLabel);
  end;
end;

begin
  try
    Test_FeatureRequirement_IsCountedAndSatisfied(
      sslFeatSessionCache,
      'session cache'
    );
    Test_FeatureRequirement_IsCountedAndSatisfied(
      sslFeatRenegotiation,
      'renegotiation'
    );

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
