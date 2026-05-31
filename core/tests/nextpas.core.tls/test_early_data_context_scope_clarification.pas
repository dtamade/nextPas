program test_early_data_context_scope_clarification;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.factory,
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

procedure AssertContextEarlyDataState(
  ACtx: ISSLContext;
  AClientEnabled: Boolean;
  AServerPolicy: TSSLEarlyDataServerPolicy;
  AServerMaxSize: Cardinal;
  const ALabel: string
);
var
  LEarlyCtx: ISSLEarlyDataContext;
begin
  Assert(Supports(ACtx, ISSLEarlyDataContext, LEarlyCtx),
    ALabel + ' exposes ISSLEarlyDataContext');
  if not Supports(ACtx, ISSLEarlyDataContext, LEarlyCtx) then
    Exit;

  Assert(LEarlyCtx.GetClientEarlyDataEnabled = AClientEnabled,
    ALabel + ' client early-data flag matches expected scope');
  Assert(LEarlyCtx.GetServerEarlyDataPolicy = AServerPolicy,
    ALabel + ' server early-data policy matches expected scope');
  Assert(LEarlyCtx.GetServerMaxEarlyDataSize = AServerMaxSize,
    ALabel + ' server max early-data size matches expected scope');
end;

procedure Test_BuilderBuildClient_OnlyAppliesClientScopedEarlyDataConfig;
var
  LCtx: ISSLContext;
begin
  TestHeader('Builder BuildClient only applies client-scoped early-data config');

  LCtx := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithClientEarlyData(True)
    .WithServerEarlyDataPolicy(sslEarlyDataServerIssueOnly)
    .WithServerMaxEarlyDataSize(2048)
    .BuildClient;

  AssertContextEarlyDataState(
    LCtx,
    True,
    sslEarlyDataServerReject,
    0,
    'Builder-built client context'
  );
end;

procedure Test_BuilderBuildServer_OnlyAppliesServerScopedEarlyDataConfig;
var
  LCtx: ISSLContext;
  LCertPEM: string;
  LKeyPEM: string;
begin
  TestHeader('Builder BuildServer only applies server-scoped early-data config');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'builder-earlydata-scope.local',
    'fafafa.ssl',
    30,
    LCertPEM,
    LKeyPEM
  ) then
  begin
    Assert(False, 'Should generate self-signed certificate for builder server early-data scope test');
    Exit;
  end;

  LCtx := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithClientEarlyData(True)
    .WithServerEarlyDataPolicy(sslEarlyDataServerIssueOnly)
    .WithServerMaxEarlyDataSize(2048)
    .BuildServer;

  AssertContextEarlyDataState(
    LCtx,
    False,
    sslEarlyDataServerIssueOnly,
    2048,
    'Builder-built server context'
  );
end;

procedure Test_FactoryDefaultConfig_AppliesContextRelevantEarlyDataSubset;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  ClientCtx: ISSLContext;
  ServerCtx: ISSLContext;
begin
  TestHeader('Factory default config applies only context-relevant early-data subset');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  try
    DefaultConfig := OriginalConfig;
    DefaultConfig.ClientEarlyDataEnabled := True;
    DefaultConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
    DefaultConfig.ServerMaxEarlyDataSize := 11;
    Lib.SetDefaultConfig(DefaultConfig);

    ClientCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
    AssertContextEarlyDataState(
      ClientCtx,
      True,
      sslEarlyDataServerReject,
      0,
      'Default-path client context'
    );

    ServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    AssertContextEarlyDataState(
      ServerCtx,
      False,
      sslEarlyDataServerIssueOnly,
      11,
      'Default-path server context'
    );
  finally
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_FactoryOneShotConfig_AppliesContextRelevantEarlyDataSubset;
var
  ClientConfig: TSSLConfig;
  ServerConfig: TSSLConfig;
  ClientCtx: ISSLContext;
  ServerCtx: ISSLContext;
begin
  TestHeader('Factory one-shot config applies only context-relevant early-data subset');

  ClientConfig := CreateDefaultConfig(sslCtxClient);
  ClientConfig.LibraryType := sslFreePascal;
  ClientConfig.ContextType := sslCtxClient;
  ClientConfig.ClientEarlyDataEnabled := True;
  ClientConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
  ClientConfig.ServerMaxEarlyDataSize := 7;

  ClientCtx := TSSLFactory.CreateContext(ClientConfig);
  AssertContextEarlyDataState(
    ClientCtx,
    True,
    sslEarlyDataServerReject,
    0,
    'One-shot client context'
  );

  ServerConfig := CreateDefaultConfig(sslCtxServer);
  ServerConfig.LibraryType := sslFreePascal;
  ServerConfig.ContextType := sslCtxServer;
  ServerConfig.ClientEarlyDataEnabled := True;
  ServerConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
  ServerConfig.ServerMaxEarlyDataSize := 7;

  ServerCtx := TSSLFactory.CreateContext(ServerConfig);
  AssertContextEarlyDataState(
    ServerCtx,
    False,
    sslEarlyDataServerIssueOnly,
    7,
    'One-shot server context'
  );
end;

procedure Test_EarlyDataHelpers_RespectContextScope;
var
  ClientCtx: ISSLContext;
  ServerCtx: ISSLContext;
begin
  TestHeader('Early-data helpers respect context scope');

  ClientCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  Assert(TSSLHelper.ConfigureClientEarlyData(ClientCtx, True),
    'ConfigureClientEarlyData should succeed on client context');
  AssertContextEarlyDataState(
    ClientCtx,
    True,
    sslEarlyDataServerReject,
    0,
    'Helper-configured client context'
  );
  Assert(not TSSLHelper.ConfigureServerEarlyData(ClientCtx,
      sslEarlyDataServerAccept, 32),
    'ConfigureServerEarlyData should reject client context');
  AssertContextEarlyDataState(
    ClientCtx,
    True,
    sslEarlyDataServerReject,
    0,
    'Client context after rejected server helper'
  );

  ServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  Assert(TSSLHelper.ConfigureServerEarlyData(ServerCtx,
      sslEarlyDataServerIssueOnly, 32),
    'ConfigureServerEarlyData should succeed on server context');
  AssertContextEarlyDataState(
    ServerCtx,
    False,
    sslEarlyDataServerIssueOnly,
    32,
    'Helper-configured server context'
  );
  Assert(not TSSLHelper.ConfigureClientEarlyData(ServerCtx, True),
    'ConfigureClientEarlyData should reject server context');
  AssertContextEarlyDataState(
    ServerCtx,
    False,
    sslEarlyDataServerIssueOnly,
    32,
    'Server context after rejected client helper'
  );
end;

begin
  try
    Test_BuilderBuildClient_OnlyAppliesClientScopedEarlyDataConfig;
    Test_BuilderBuildServer_OnlyAppliesServerScopedEarlyDataConfig;
    Test_FactoryDefaultConfig_AppliesContextRelevantEarlyDataSubset;
    Test_FactoryOneShotConfig_AppliesContextRelevantEarlyDataSubset;
    Test_EarlyDataHelpers_RespectContextScope;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.Message);
      Halt(1);
    end;
  end;
end.
