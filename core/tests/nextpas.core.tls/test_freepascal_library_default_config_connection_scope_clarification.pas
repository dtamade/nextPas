program test_freepascal_library_default_config_connection_scope_clarification;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.freepascal.lib;

type
  TConfigMutator = procedure(var AConfig: TSSLConfig);

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

function CreateInitializedLibrary: ISSLLibrary;
begin
  Result := CreateFreePascalSSLLibrary;
  if Result = nil then
    raise Exception.Create('CreateFreePascalSSLLibrary returned nil');

  if not Result.Initialize then
    raise Exception.Create(
      'FreePascal library failed to initialize for direct-library connection-scope clarification test'
    );
end;

procedure ExpectConfigurationError(const ALabel: string; AMutator: TConfigMutator;
  const APrimaryFragment, ASecondaryFragment: string);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  MutatedConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  Lib := CreateInitializedLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    MutatedConfig := OriginalConfig;
    AMutator(MutatedConfig);
    Lib.SetDefaultConfig(MutatedConfig);

    try
      Ctx := Lib.CreateContext(sslCtxClient);
      if Ctx <> nil then;
      Assert(False, ALabel + ' should raise ESSLConfigurationException');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(E.ErrorCode = sslErrConfiguration,
          ALabel + ' raises sslErrConfiguration');
        Assert(Pos(APrimaryFragment, E.Message) > 0,
          ALabel + ' mentions the mismatched config field');
        Assert(Pos(ASecondaryFragment, E.Message) > 0,
          ALabel + ' points to the supported replacement path');
        Assert(Pos('TFreePascalSSLLibrary.CreateContext', E.Message) > 0,
          ALabel + ' identifies the direct-library callsite');
      end;
      on E: Exception do
        Assert(False, ALabel + ' raised unexpected ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

procedure SetLibraryHandshakeTimeout(var AConfig: TSSLConfig);
begin
  AConfig.HandshakeTimeout := 100;
end;

procedure SetLibraryBufferSize(var AConfig: TSSLConfig);
begin
  AConfig.BufferSize := SSL_DEFAULT_BUFFER_SIZE * 2;
end;

procedure Test_DirectLibraryRejectsCustomHandshakeTimeout;
begin
  TestHeader('FreePascal direct-library path rejects custom HandshakeTimeout');

  ExpectConfigurationError(
    'ISSLLibrary.CreateContext(AType) with custom library HandshakeTimeout',
    @SetLibraryHandshakeTimeout,
    'HandshakeTimeout',
    'ISSLConnectionControl.SetTimeout'
  );
end;

procedure Test_DirectLibraryRejectsCustomBufferSize;
begin
  TestHeader('FreePascal direct-library path rejects custom BufferSize');

  ExpectConfigurationError(
    'ISSLLibrary.CreateContext(AType) with custom library BufferSize',
    @SetLibraryBufferSize,
    'BufferSize',
    'transport/IO'
  );
end;

procedure Test_DirectLibraryStillBuildsWithRequestSafeDefaults;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal direct-library path still builds with request-safe defaults');

  Lib := CreateInitializedLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    Lib.SetDefaultConfig(OriginalConfig);

    Ctx := Lib.CreateContext(sslCtxClient);
    Assert(Ctx <> nil,
      'ISSLLibrary.CreateContext(AType) still succeeds when default config keeps request-safe connection scope fields');
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

begin
  try
    Test_DirectLibraryRejectsCustomHandshakeTimeout;
    Test_DirectLibraryRejectsCustomBufferSize;
    Test_DirectLibraryStillBuildsWithRequestSafeDefaults;

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
