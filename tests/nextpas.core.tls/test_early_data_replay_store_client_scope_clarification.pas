program test_early_data_replay_store_client_scope_clarification;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.exceptions,
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

function ErrorsContain(const AResult: TBuildValidationResult;
  const AFragment: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AResult.ErrorCount - 1 do
    if Pos(AFragment, AResult.Errors[I]) > 0 then
      Exit(True);
end;

procedure Test_BuilderValidateClientRejectsServerReplayStoreFile;
var
  LBuilder: ISSLContextBuilder;
  LValidation: TBuildValidationResult;
begin
  TestHeader('Builder ValidateClient rejects server replay-store file');

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithServerEarlyDataReplayStoreFile('tmp/client-scope-file.bin');

  LValidation := LBuilder.ValidateClient;

  Assert(not LValidation.IsValid,
    'ValidateClient should reject server_early_data_replay_store_file on client builders');
  Assert(LValidation.HasErrors,
    'ValidateClient should report an error for server_early_data_replay_store_file');
  Assert(ErrorsContain(LValidation, 'server_early_data_replay_store_file'),
    'ValidateClient error should name server_early_data_replay_store_file');
end;

procedure Test_BuilderValidateClientRejectsServerReplayStoreDirectory;
var
  LBuilder: ISSLContextBuilder;
  LValidation: TBuildValidationResult;
begin
  TestHeader('Builder ValidateClient rejects server replay-store directory');

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithServerEarlyDataReplayStoreDirectory('tmp/client-scope-replay-dir');

  LValidation := LBuilder.ValidateClient;

  Assert(not LValidation.IsValid,
    'ValidateClient should reject server_early_data_replay_store_directory on client builders');
  Assert(LValidation.HasErrors,
    'ValidateClient should report an error for server_early_data_replay_store_directory');
  Assert(ErrorsContain(LValidation, 'server_early_data_replay_store_directory'),
    'ValidateClient error should name server_early_data_replay_store_directory');
end;

procedure Test_TryBuildClientRejectsServerReplayStoreFile;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Builder TryBuildClient rejects server replay-store file');

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithServerEarlyDataReplayStoreFile('tmp/client-build-file.bin');

  LResult := LBuilder.TryBuildClient(LContext);

  Assert(LResult.IsErr,
    'TryBuildClient should fail when server_early_data_replay_store_file is set');
  Assert(LContext = nil,
    'TryBuildClient should not return a context when server_early_data_replay_store_file is set');
  Assert(Pos('server_early_data_replay_store_file', LResult.ErrorMessage) > 0,
    'TryBuildClient error should name server_early_data_replay_store_file');
end;

procedure Test_TryBuildClientRejectsServerReplayStoreDirectory;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Builder TryBuildClient rejects server replay-store directory');

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithServerEarlyDataReplayStoreDirectory('tmp/client-build-replay-dir');

  LResult := LBuilder.TryBuildClient(LContext);

  Assert(LResult.IsErr,
    'TryBuildClient should fail when server_early_data_replay_store_directory is set');
  Assert(LContext = nil,
    'TryBuildClient should not return a context when server_early_data_replay_store_directory is set');
  Assert(Pos('server_early_data_replay_store_directory', LResult.ErrorMessage) > 0,
    'TryBuildClient error should name server_early_data_replay_store_directory');
end;

procedure Test_FactoryDefaultClientContextRejectsServerReplayStoreFile;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  ModifiedConfig: TSSLConfig;
  LContext: ISSLContext;
begin
  TestHeader('Factory default client path rejects server replay-store file');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;

  try
    ModifiedConfig := OriginalConfig;
    ModifiedConfig.ServerEarlyDataReplayStoreFile := 'tmp/default-client-replay-file.bin';
    Lib.SetDefaultConfig(ModifiedConfig);

    try
      LContext := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
      Assert(False,
        'Factory default client path should reject server_early_data_replay_store_file');
      if LContext <> nil then;
    except
      on E: ESSLConfigurationException do
      begin
        Assert(Pos('server_early_data_replay_store_file', E.Message) > 0,
          'Factory default-path error should name server_early_data_replay_store_file');
      end;
      on E: Exception do
        Assert(False,
          'Factory default client path should raise configuration exception: ' + E.Message);
    end;
  finally
    Lib.SetDefaultConfig(OriginalConfig);
  end;
end;

procedure Test_FactoryOneShotClientContextRejectsServerReplayStoreDirectory;
var
  LConfig: TSSLConfig;
  LContext: ISSLContext;
begin
  TestHeader('Factory one-shot client path rejects server replay-store directory');

  LConfig := CreateDefaultConfig(sslCtxClient);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ContextType := sslCtxClient;
  LConfig.ServerEarlyDataReplayStoreDirectory := 'tmp/one-shot-client-replay-dir';

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    Assert(False,
      'Factory one-shot client path should reject server_early_data_replay_store_directory');
    if LContext <> nil then;
  except
    on E: ESSLConfigurationException do
    begin
      Assert(Pos('server_early_data_replay_store_directory', E.Message) > 0,
        'Factory one-shot error should name server_early_data_replay_store_directory');
    end;
    on E: Exception do
      Assert(False,
        'Factory one-shot client path should raise configuration exception: ' + E.Message);
  end;
end;

begin
  try
    Test_BuilderValidateClientRejectsServerReplayStoreFile;
    Test_BuilderValidateClientRejectsServerReplayStoreDirectory;
    Test_TryBuildClientRejectsServerReplayStoreFile;
    Test_TryBuildClientRejectsServerReplayStoreDirectory;
    Test_FactoryDefaultClientContextRejectsServerReplayStoreFile;
    Test_FactoryOneShotClientContextRejectsServerReplayStoreDirectory;

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
