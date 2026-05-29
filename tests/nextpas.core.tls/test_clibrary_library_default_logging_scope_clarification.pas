program test_clibrary_library_default_logging_scope_clarification;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
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

function CallbackEquals(AExpected, AActual: TSSLLogCallback): Boolean;
begin
  Result := (TMethod(AExpected).Code = TMethod(AActual).Code) and
            (TMethod(AExpected).Data = TMethod(AActual).Data);
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

procedure RunBackendSuite(ABackend: TSSLLibraryType; const ABackendName: string;
  ACreator: TLibraryCreator);
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  SnapshotConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Callback: TSSLLogCallback;
  Reason: string;
begin
  TestHeader(ABackendName + ' library-default logging round-trip and dispatch stay aligned');

  if not TryCreateInitializedLibrary(ABackend, ACreator, Lib, Reason) then
  begin
    Skip(ABackendName + ' logging proof skipped: ' + Reason);
    Exit;
  end;

  Recorder := TLogRecorder.Create;
  try
    OriginalConfig := Lib.GetDefaultConfig;

    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.LogCallback := @Recorder.HandleLog;
    Lib.SetDefaultConfig(DefaultConfig);

    SnapshotConfig := Lib.GetDefaultConfig;
    Assert(SnapshotConfig.LogLevel = sslLogWarning,
      ABackendName + ' SetDefaultConfig visibleizes LogLevel in GetDefaultConfig');
    Assert(not Assigned(SnapshotConfig.LogCallback),
      ABackendName + ' SetDefaultConfig keeps LogCallback detached from the default-config write surface');

    Recorder.Reset;
    Lib.Log(sslLogWarning, 'warning should stay muted before SetLogCallback');
    Assert(Recorder.CallCount = 0,
      ABackendName + ' SetDefaultConfig(LogCallback) alone does not install the runtime callback');

    Callback := @Recorder.HandleLog;
    Lib.SetLogCallback(Callback);

    SnapshotConfig := Lib.GetDefaultConfig;
    Assert(SnapshotConfig.LogLevel = sslLogWarning,
      ABackendName + ' SetLogCallback keeps configured LogLevel unchanged');
    Assert(CallbackEquals(Callback, SnapshotConfig.LogCallback),
      ABackendName + ' SetLogCallback visibleizes callback in GetDefaultConfig');

    Recorder.Reset;
    Lib.Log(sslLogInfo, 'info should stay filtered');
    Assert(Recorder.CallCount = 0,
      ABackendName + ' Log does not dispatch messages above configured LogLevel');

    Lib.Log(sslLogWarning, 'warning should be delivered');
    Assert(Recorder.CallCount = 1,
      ABackendName + ' Log dispatches messages at configured LogLevel');
    Assert(Recorder.LastLevel = sslLogWarning,
      ABackendName + ' Log dispatch preserves the requested log level');
    Assert(Pos('warning should be delivered', Recorder.LastMessage) > 0,
      ABackendName + ' Log dispatch preserves the message content');

    DefaultConfig := SnapshotConfig;
    DefaultConfig.LogLevel := sslLogError;
    DefaultConfig.LogCallback := nil;
    Lib.SetDefaultConfig(DefaultConfig);

    SnapshotConfig := Lib.GetDefaultConfig;
    Assert(SnapshotConfig.LogLevel = sslLogError,
      ABackendName + ' SetDefaultConfig still updates LogLevel after callback detachment');
    Assert(CallbackEquals(Callback, SnapshotConfig.LogCallback),
      ABackendName + ' SetDefaultConfig does not clear the installed callback; SetLogCallback remains the owner');

    Recorder.Reset;
    Lib.Log(sslLogWarning, 'warning should stay filtered at error level');
    Assert(Recorder.CallCount = 0,
      ABackendName + ' SetDefaultConfig(LogLevel) can tighten filtering without clearing the callback');

    Lib.Log(sslLogError, 'error should still be delivered');
    Assert(Recorder.CallCount = 1,
      ABackendName + ' Installed callback still receives logs after SetDefaultConfig updates LogLevel');
  finally
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    if Assigned(Lib) and Lib.IsInitialized then
      Lib.Finalize;
    Recorder.Free;
  end;
end;

begin
  try
    RunBackendSuite(sslOpenSSL, 'OpenSSL', @CreateOpenSSLLibrary);
    RunBackendSuite(sslMbedTLS, 'MbedTLS', @CreateMbedTLSLibrary);
    RunBackendSuite(sslWolfSSL, 'WolfSSL', @CreateWolfSSLLibrary);

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
