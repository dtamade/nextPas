program test_context_builder_early_data_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

function CreateRuntimeBuilder: ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.WithBackend(sslFreePascal);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', AMessage);
  end;
end;

procedure TestClientDefaultsAndFluentConfig;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
begin
  WriteLn('=== Client Early Data Builder Contract ===');

  LCtx := CreateRuntimeBuilder.BuildClient;
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'FreePascal client context should expose early-data optional interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    AssertTrue(not LEarlyCtx.GetClientEarlyDataEnabled,
      'Client early data should be disabled by default');
    AssertTrue(LEarlyCtx.GetServerEarlyDataPolicy = sslEarlyDataServerReject,
      'Server policy should default to reject on newly built client contexts');
    AssertTrue(LEarlyCtx.GetServerMaxEarlyDataSize = 0,
      'Server max early-data size should default to zero on newly built client contexts');
  end;

  LCtx := CreateRuntimeBuilder
    .WithClientEarlyData(True)
    .BuildClient;
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Builder-enabled client context should still expose early-data optional interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
    AssertTrue(LEarlyCtx.GetClientEarlyDataEnabled,
      'WithClientEarlyData(True) should enable client early data');

  LCtx := CreateRuntimeBuilder
    .WithClientEarlyData(False)
    .BuildClient;
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Builder-disabled client context should still expose early-data optional interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
    AssertTrue(not LEarlyCtx.GetClientEarlyDataEnabled,
      'WithClientEarlyData(False) should explicitly disable client early data');

  WriteLn;
end;

procedure TestServerPolicyFluentConfig;
var
  LCtx: ISSLContext;
  LEarlyCtx: ISSLEarlyDataContext;
  LCertPEM, LKeyPEM: string;
begin
  WriteLn('=== Server Early Data Builder Contract ===');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'early-data.local',
    'fafafa.ssl',
    30,
    LCertPEM,
    LKeyPEM
  ) then
  begin
    AssertTrue(False, 'Should generate self-signed certificate for server builder contract');
    Exit;
  end;

  LCtx := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .BuildServer;
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'FreePascal server context should expose early-data optional interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    AssertTrue(LEarlyCtx.GetServerEarlyDataPolicy = sslEarlyDataServerReject,
      'Server early-data policy should default to reject');
    AssertTrue(LEarlyCtx.GetServerMaxEarlyDataSize = 0,
      'Server early-data max size should default to zero');
  end;

  LCtx := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithServerEarlyDataPolicy(sslEarlyDataServerIssueOnly)
    .WithServerMaxEarlyDataSize(16384)
    .BuildServer;
  AssertTrue(Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx),
    'Builder-configured server context should expose early-data optional interface');
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    AssertTrue(LEarlyCtx.GetServerEarlyDataPolicy = sslEarlyDataServerIssueOnly,
      'WithServerEarlyDataPolicy(issue-only) should be observable on built server context');
    AssertTrue(LEarlyCtx.GetServerMaxEarlyDataSize = 16384,
      'WithServerMaxEarlyDataSize should be observable on built server context');
  end;

  WriteLn;
end;

begin
  WriteLn('Testing context builder early-data contract...');

  TestClientDefaultsAndFluentConfig;
  TestServerPolicyFluentConfig;

  if GTestsFailed > 0 then
  begin
    WriteLn;
    WriteLn(Format('❌ %d builder early-data contract check(s) failed', [GTestsFailed]));
    Halt(1);
  end;

  WriteLn(Format('✅ Context builder early-data contract passed (%d checks)', [GTestsPassed]));
end.
