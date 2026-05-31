program test_auto_backend_tpm_capability_truth_contract;

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

var
  LRequirements: TSSLRequirements;
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('Testing Auto-Backend TPM Capability Truth Contract');
  WriteLn('==================================================');

  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('[SKIP] OpenSSL backend not available; skip TPM selector truth contract');
    Halt(0);
  end;

  LRequirements := CreateDefaultRequirements(optBalanced);
  LRequirements.PlatformPreferences.RequireTPM := True;

  LBuilder := TSSLContextBuilder.Create.WithAutoBackendSelection(LRequirements);
  LResult := LBuilder.TryBuildClient(LContext);

  Require(LResult.IsErr,
    'Auto-backend selection must fail when TPM support is required but no shipped backend publishes it');
  Require(LContext = nil,
    'Context must remain nil when TPM requirement cannot be satisfied');
  Require(Pos('No suitable SSL backend found for requirements', LResult.ErrorMessage) > 0,
    'Error should mention that no suitable backend satisfies the TPM requirement');

  WriteLn('✅ Auto-backend TPM capability truth contract verified');
end.
