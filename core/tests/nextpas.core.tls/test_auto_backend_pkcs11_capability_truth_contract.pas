program test_auto_backend_pkcs11_capability_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.openssl.backed;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function AnyAvailableBackendPublishesPKCS11: Boolean;
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
    if (LLib <> nil) and LLib.GetCapabilities.SupportsPKCS11 then
      Exit(True);
  end;
end;

var
  LRequirements: TSSLRequirements;
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LExpectedAvailable: Boolean;
begin
  WriteLn('Testing Auto-Backend PKCS#11 Capability Truth Contract');
  WriteLn('======================================================');

  LExpectedAvailable := AnyAvailableBackendPublishesPKCS11;

  LRequirements := CreateDefaultRequirements(optBalanced);
  LRequirements.PlatformPreferences.RequirePKCS11 := True;

  LBuilder := TSSLContextBuilder.Create.WithAutoBackendSelection(LRequirements);
  LResult := LBuilder.TryBuildClient(LContext);

  if LExpectedAvailable then
  begin
    Require(LResult.IsOk,
      'Auto-backend selection must succeed when at least one available backend publishes PKCS#11');
    Require(LContext <> nil,
      'Context must be created when a published PKCS#11-capable backend exists');
  end
  else
  begin
    Require(LResult.IsErr,
      'Auto-backend selection must fail when no available backend publishes PKCS#11');
    Require(LContext = nil,
      'Context must remain nil when no published PKCS#11-capable backend exists');
    Require(Pos('No suitable SSL backend found for requirements', LResult.ErrorMessage) > 0,
      'Error should mention that no suitable backend satisfies the PKCS#11 requirement');
  end;

  WriteLn('✅ Auto-backend PKCS#11 capability truth contract verified');
end.
