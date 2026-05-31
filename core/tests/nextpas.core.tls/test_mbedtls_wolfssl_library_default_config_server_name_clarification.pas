program test_mbedtls_wolfssl_library_default_config_server_name_clarification;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  TSSLConfig.ServerName compatibility on the optional MbedTLS/WolfSSL
  direct-library paths. }

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.wolfssl.lib;

type
  TLogRecorder = class
  public
    CallCount: Integer;
    LastLevel: TSSLLogLevel;
    LastMessage: string;

    procedure HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
    procedure Reset;
  end;

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

procedure TLogRecorder.HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  Inc(CallCount);
  LastLevel := ALevel;
  LastMessage := AMessage;
end;

procedure TLogRecorder.Reset;
begin
  CallCount := 0;
  LastLevel := sslLogNone;
  LastMessage := '';
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

procedure RunClientDefaultConfigServerNameIgnoredAndWarns(
  ABackend: TSSLLibraryType; const ABackendName, ACallSite: string;
  ACreator: TLibraryCreator);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Ctx: ISSLContext;
  Reason: string;
begin
  TestHeader(ABackendName + ' client default-config ServerName is ignored');

  if not TryCreateInitializedLibrary(ABackend, ACreator, Lib, Reason) then
  begin
    Skip(ABackendName + ' client default-config proof skipped: ' + Reason);
    Exit;
  end;

  Recorder := TLogRecorder.Create;
  Ctx := nil;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.ServerName := 'library-client.example.com';
    Lib.SetDefaultConfig(DefaultConfig);
    Lib.SetLogCallback(@Recorder.HandleLog);

    Recorder.Reset;
    Ctx := Lib.CreateContext(sslCtxClient);

    Assert(Ctx <> nil, ABackendName + ' direct-library client context still builds');
    Assert(Ctx.GetServerName = '',
      ABackendName + ' direct-library client context ignores deprecated default ServerName');
    Assert(Recorder.CallCount > 0,
      ABackendName + ' direct-library client default-config ServerName emits a warning');
    Assert(Recorder.LastLevel = sslLogWarning,
      ABackendName + ' direct-library warning uses warning severity');
    Assert(Pos('TSSLConfig.ServerName', Recorder.LastMessage) > 0,
      ABackendName + ' direct-library warning names TSSLConfig.ServerName');
    Assert(Pos('deprecated context-level SNI compatibility', Recorder.LastMessage) > 0,
      ABackendName + ' direct-library warning marks context-level SNI as compatibility-only');
    Assert(Pos('CreateContext ignores it', Recorder.LastMessage) > 0,
      ABackendName + ' direct-library warning explains that new client contexts ignore deprecated ServerName');
    Assert(Pos(ACallSite, Recorder.LastMessage) > 0,
      ABackendName + ' direct-library warning identifies the library callsite');
  finally
    Ctx := nil;
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    if Assigned(Lib) and Lib.IsInitialized then
      Lib.Finalize;
    Recorder.Free;
  end;
end;

procedure RunServerDefaultConfigServerNameRejected(
  ABackend: TSSLLibraryType; const ABackendName, ACallSite: string;
  ACreator: TLibraryCreator);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Ctx: ISSLContext;
  Reason: string;
begin
  TestHeader(ABackendName + ' server default-config ServerName is rejected');

  if not TryCreateInitializedLibrary(ABackend, ACreator, Lib, Reason) then
  begin
    Skip(ABackendName + ' server default-config proof skipped: ' + Reason);
    Exit;
  end;

  Recorder := TLogRecorder.Create;
  Ctx := nil;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.ServerName := 'library-server.example.com';
    Lib.SetDefaultConfig(DefaultConfig);
    Lib.SetLogCallback(@Recorder.HandleLog);

    Recorder.Reset;
    try
      Ctx := Lib.CreateContext(sslCtxServer);
      if Ctx <> nil then;
      Assert(False,
        ABackendName + ' direct-library server default-config ServerName should raise ESSLConfigurationException');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(E.ErrorCode = sslErrConfiguration,
          ABackendName + ' direct-library server default-config ServerName raises sslErrConfiguration');
        Assert(Pos('ServerName is client-scoped', E.Message) > 0,
          ABackendName + ' direct-library server default-config error explains client scope');
        Assert(Pos(ACallSite, E.Message) > 0,
          ABackendName + ' direct-library server default-config error identifies the library callsite');
      end;
      on E: Exception do
        Assert(False,
          ABackendName + ' direct-library server default-config ServerName raised unexpected ' +
          E.ClassName + ': ' + E.Message);
    end;
  finally
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    if Assigned(Lib) and Lib.IsInitialized then
      Lib.Finalize;
    Recorder.Free;
  end;
end;

procedure RunClientWithoutServerNameDoesNotWarn(
  ABackend: TSSLLibraryType; const ABackendName: string;
  ACreator: TLibraryCreator);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Ctx: ISSLContext;
  Reason: string;
begin
  TestHeader(ABackendName + ' client default-config without ServerName stays quiet');

  if not TryCreateInitializedLibrary(ABackend, ACreator, Lib, Reason) then
  begin
    Skip(ABackendName + ' quiet client default-config proof skipped: ' + Reason);
    Exit;
  end;

  Recorder := TLogRecorder.Create;
  Ctx := nil;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.ServerName := '';
    Lib.SetDefaultConfig(DefaultConfig);
    Lib.SetLogCallback(@Recorder.HandleLog);

    Recorder.Reset;
    Ctx := Lib.CreateContext(sslCtxClient);

    Assert(Ctx <> nil, ABackendName + ' direct-library client context without ServerName still builds');
    Assert(Recorder.CallCount = 0,
      ABackendName + ' direct-library client context without ServerName emits no warning');
  finally
    Ctx := nil;
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    if Assigned(Lib) and Lib.IsInitialized then
      Lib.Finalize;
    Recorder.Free;
  end;
end;

procedure RunBackendSuite(ABackend: TSSLLibraryType; const ABackendName,
  ACallSite: string; ACreator: TLibraryCreator);
begin
  RunClientDefaultConfigServerNameIgnoredAndWarns(
    ABackend,
    ABackendName,
    ACallSite,
    ACreator
  );
  RunServerDefaultConfigServerNameRejected(
    ABackend,
    ABackendName,
    ACallSite,
    ACreator
  );
  RunClientWithoutServerNameDoesNotWarn(
    ABackend,
    ABackendName,
    ACreator
  );
end;

begin
  try
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
