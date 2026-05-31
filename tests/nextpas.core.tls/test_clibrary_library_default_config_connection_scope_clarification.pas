program test_clibrary_library_default_config_connection_scope_clarification;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.wolfssl.lib;

type
  TConfigMutator = procedure(var AConfig: TSSLConfig);
  TLibraryCreator = function: ISSLLibrary;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GTestsSkipped: Integer = 0;

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

procedure Skip(const AMessage: string);
begin
  Inc(GTestsSkipped);
  WriteLn('  SKIP: ', AMessage);
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

function TryCreateInitializedLibrary(ABackend: TSSLLibraryType;
  ACreator: TLibraryCreator; out ALib: ISSLLibrary; out AReason: string): Boolean;
begin
  Result := False;
  ALib := nil;
  AReason := '';

  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    AReason := 'backend not available on this platform';
    Exit;
  end;

  ALib := ACreator();
  if ALib = nil then
  begin
    AReason := 'direct-library creator returned nil';
    Exit;
  end;

  if not ALib.Initialize then
  begin
    AReason := 'library initialization failed';
    ALib := nil;
    Exit;
  end;

  Result := True;
end;

procedure SetLibraryHandshakeTimeout(var AConfig: TSSLConfig);
begin
  AConfig.HandshakeTimeout := 100;
end;

procedure SetLibraryBufferSize(var AConfig: TSSLConfig);
begin
  AConfig.BufferSize := SSL_DEFAULT_BUFFER_SIZE * 2;
end;

procedure ExpectConfigurationError(ABackend: TSSLLibraryType;
  const ABackendName, ACallSite, ALabel: string; ACreator: TLibraryCreator;
  AMutator: TConfigMutator; const APrimaryFragment, ASecondaryFragment: string);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  MutatedConfig: TSSLConfig;
  Ctx: ISSLContext;
  Reason: string;
begin
  if not TryCreateInitializedLibrary(ABackend, ACreator, Lib, Reason) then
  begin
    Skip(ABackendName + ' ' + ALabel + ' skipped: ' + Reason);
    Exit;
  end;

  try
    OriginalConfig := Lib.GetDefaultConfig;
    MutatedConfig := OriginalConfig;
    AMutator(MutatedConfig);
    Lib.SetDefaultConfig(MutatedConfig);

    try
      Ctx := Lib.CreateContext(sslCtxClient);
      if Ctx <> nil then;
      Assert(False, ABackendName + ' ' + ALabel + ' should raise ESSLConfigurationException');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(E.ErrorCode = sslErrConfiguration,
          ABackendName + ' ' + ALabel + ' raises sslErrConfiguration');
        Assert(Pos(APrimaryFragment, E.Message) > 0,
          ABackendName + ' ' + ALabel + ' mentions the mismatched config field');
        Assert(Pos(ASecondaryFragment, E.Message) > 0,
          ABackendName + ' ' + ALabel + ' points to the supported replacement path');
        Assert(Pos(ACallSite, E.Message) > 0,
          ABackendName + ' ' + ALabel + ' identifies the direct-library callsite');
      end;
      on E: Exception do
        Assert(False,
          ABackendName + ' ' + ALabel + ' raised unexpected ' +
          E.ClassName + ': ' + E.Message);
    end;
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    if Assigned(Lib) and Lib.IsInitialized then
      Lib.Finalize;
  end;
end;

procedure ExpectSafeDefaultsStillBuild(ABackend: TSSLLibraryType;
  const ABackendName: string; ACreator: TLibraryCreator);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  Ctx: ISSLContext;
  Reason: string;
begin
  if not TryCreateInitializedLibrary(ABackend, ACreator, Lib, Reason) then
  begin
    Skip(ABackendName + ' safe-default build proof skipped: ' + Reason);
    Exit;
  end;

  try
    OriginalConfig := Lib.GetDefaultConfig;
    Lib.SetDefaultConfig(OriginalConfig);

    Ctx := Lib.CreateContext(sslCtxClient);
    Assert(Ctx <> nil,
      ABackendName + ' direct-library path still succeeds when default config keeps request-safe connection scope fields');
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    if Assigned(Lib) and Lib.IsInitialized then
      Lib.Finalize;
  end;
end;

procedure RunBackendSuite(ABackend: TSSLLibraryType; const ABackendName,
  ACallSite: string; ACreator: TLibraryCreator);
begin
  TestHeader(ABackendName + ' direct-library path rejects custom HandshakeTimeout');
  ExpectConfigurationError(
    ABackend,
    ABackendName,
    ACallSite,
    'ISSLLibrary.CreateContext(AType) with custom library HandshakeTimeout',
    ACreator,
    @SetLibraryHandshakeTimeout,
    'HandshakeTimeout',
    'ISSLConnectionControl.SetTimeout'
  );

  TestHeader(ABackendName + ' direct-library path rejects custom BufferSize');
  ExpectConfigurationError(
    ABackend,
    ABackendName,
    ACallSite,
    'ISSLLibrary.CreateContext(AType) with custom library BufferSize',
    ACreator,
    @SetLibraryBufferSize,
    'BufferSize',
    'transport/IO'
  );

  TestHeader(ABackendName + ' direct-library path still builds with request-safe defaults');
  ExpectSafeDefaultsStillBuild(ABackend, ABackendName, ACreator);
end;

begin
  try
    RunBackendSuite(
      sslOpenSSL,
      'OpenSSL',
      'TOpenSSLLibrary.CreateContext',
      @CreateOpenSSLLibrary
    );
    RunBackendSuite(
      sslMbedTLS,
      'MbedTLS',
      'TMbedTLSLibrary.CreateContext',
      @CreateMbedTLSLibrary
    );
    RunBackendSuite(
      sslWolfSSL,
      'WolfSSL',
      'TWolfSSLLibrary.CreateContext',
      @CreateWolfSSLLibrary
    );

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);
    WriteLn('Tests Skipped: ', GTestsSkipped);

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
