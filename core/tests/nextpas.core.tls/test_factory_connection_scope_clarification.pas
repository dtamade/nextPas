program test_factory_connection_scope_clarification;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
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

procedure ExpectOneShotConfigurationError(const ALabel: string; const AConfig: TSSLConfig;
  const APrimaryFragment, ASecondaryFragment: string);
var
  Ctx: ISSLContext;
begin
  try
    Ctx := TSSLFactory.CreateContext(AConfig);
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
        ALabel + ' points callers to the supported replacement path');
    end;
    on E: Exception do
      Assert(False, ALabel + ' raised unexpected ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure ExpectLibraryDefaultConfigurationError(const ALabel: string;
  AMutator: TConfigMutator; const APrimaryFragment, ASecondaryFragment: string);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  MutatedConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  try
    MutatedConfig := OriginalConfig;
    AMutator(MutatedConfig);
    Lib.SetDefaultConfig(MutatedConfig);

    try
      Ctx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
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
          ALabel + ' points callers to the supported replacement path');
      end;
      on E: Exception do
        Assert(False, ALabel + ' raised unexpected ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_RequestConfigRejectsCustomHandshakeTimeout;
var
  Config: TSSLConfig;
begin
  TestHeader('Request path rejects custom HandshakeTimeout');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;
  Config.HandshakeTimeout := 100;

  ExpectOneShotConfigurationError(
    'CreateContext(AConfig) with custom HandshakeTimeout',
    Config,
    'HandshakeTimeout',
    'ISSLConnectionControl.SetTimeout'
  );
end;

procedure Test_RequestConfigRejectsCustomBufferSize;
var
  Config: TSSLConfig;
begin
  TestHeader('Request path rejects custom BufferSize');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;
  Config.BufferSize := SSL_DEFAULT_BUFFER_SIZE * 2;

  ExpectOneShotConfigurationError(
    'CreateContext(AConfig) with custom BufferSize',
    Config,
    'BufferSize',
    'transport/IO'
  );
end;

procedure SetLibraryHandshakeTimeout(var AConfig: TSSLConfig);
begin
  AConfig.HandshakeTimeout := 100;
end;

procedure SetLibraryBufferSize(var AConfig: TSSLConfig);
begin
  AConfig.BufferSize := SSL_DEFAULT_BUFFER_SIZE * 2;
end;

procedure Test_LibraryDefaultRejectsCustomHandshakeTimeout;
begin
  TestHeader('Library default path rejects custom HandshakeTimeout');

  ExpectLibraryDefaultConfigurationError(
    'CreateContext(AContextType, ALibType) with custom library HandshakeTimeout',
    @SetLibraryHandshakeTimeout,
    'HandshakeTimeout',
    'ISSLConnectionControl.SetTimeout'
  );
end;

procedure Test_LibraryDefaultRejectsCustomBufferSize;
begin
  TestHeader('Library default path rejects custom BufferSize');

  ExpectLibraryDefaultConfigurationError(
    'CreateContext(AContextType, ALibType) with custom library BufferSize',
    @SetLibraryBufferSize,
    'BufferSize',
    'transport/IO'
  );
end;

begin
  try
    Test_RequestConfigRejectsCustomHandshakeTimeout;
    Test_RequestConfigRejectsCustomBufferSize;
    Test_LibraryDefaultRejectsCustomHandshakeTimeout;
    Test_LibraryDefaultRejectsCustomBufferSize;

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
