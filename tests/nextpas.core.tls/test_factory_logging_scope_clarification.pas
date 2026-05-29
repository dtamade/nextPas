program test_factory_logging_scope_clarification;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

type
  TLogRecorder = class
  public
    CallCount: Integer;
    LastLevel: TSSLLogLevel;
    LastMessage: string;

    procedure HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
    procedure Reset;
  end;

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

function CallbackEquals(AExpected, AActual: TSSLLogCallback): Boolean;
begin
  Result := (TMethod(AExpected).Code = TMethod(AActual).Code) and
            (TMethod(AExpected).Data = TMethod(AActual).Data);
end;

procedure ExpectConfigurationError(const ALabel: string; const AConfig: TSSLConfig);
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
      Assert(Pos('Log', E.Message) > 0,
        ALabel + ' mentions logging scope in the error message');
    end;
    on E: Exception do
      Assert(False, ALabel + ' raised unexpected ' + E.ClassName + ': ' + E.Message);
  end;
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

procedure Test_RequestConfigRejectsNonDefaultLogLevel;
var
  Config: TSSLConfig;
begin
  TestHeader('Request path rejects non-default LogLevel');

  Config := CreateDefaultConfig(sslCtxClient);
  Config.LibraryType := sslFreePascal;
  Config.LogLevel := sslLogInfo;

  ExpectConfigurationError('CreateContext(AConfig) with request LogLevel', Config);
end;

procedure Test_RequestConfigRejectsLogCallback;
var
  Config: TSSLConfig;
  Recorder: TLogRecorder;
begin
  TestHeader('Request path rejects LogCallback');

  Recorder := TLogRecorder.Create;
  try
    Config := CreateDefaultConfig(sslCtxClient);
    Config.LibraryType := sslFreePascal;
    Config.LogCallback := @Recorder.HandleLog;

    ExpectConfigurationError('CreateContext(AConfig) with request LogCallback', Config);
  finally
    Recorder.Free;
  end;
end;

procedure Test_LibraryDefaultLoggingRoundTripAndDispatch;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  SnapshotConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Callback: TSSLLogCallback;
begin
  TestHeader('Library default logging round-trip and dispatch stay aligned');

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  Recorder := TLogRecorder.Create;
  try
    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.LogCallback := @Recorder.HandleLog;
    Lib.SetDefaultConfig(DefaultConfig);

    SnapshotConfig := Lib.GetDefaultConfig;
    Assert(SnapshotConfig.LogLevel = sslLogWarning,
      'SetDefaultConfig visibleizes LogLevel in GetDefaultConfig');
    Assert(not Assigned(SnapshotConfig.LogCallback),
      'SetDefaultConfig keeps LogCallback detached from the default-config write surface');

    Recorder.Reset;
    Lib.Log(sslLogWarning, 'warning should stay muted before SetLogCallback');
    Assert(Recorder.CallCount = 0,
      'SetDefaultConfig(LogCallback) alone does not install the runtime callback');

    Callback := @Recorder.HandleLog;
    Lib.SetLogCallback(Callback);

    SnapshotConfig := Lib.GetDefaultConfig;
    Assert(SnapshotConfig.LogLevel = sslLogWarning,
      'SetLogCallback keeps configured LogLevel unchanged');
    Assert(CallbackEquals(Callback, SnapshotConfig.LogCallback),
      'SetLogCallback visibleizes callback in GetDefaultConfig');

    Recorder.Reset;
    Lib.Log(sslLogInfo, 'info should stay filtered');
    Assert(Recorder.CallCount = 0,
      'Log does not dispatch messages above configured LogLevel');

    Lib.Log(sslLogWarning, 'warning should be delivered');
    Assert(Recorder.CallCount = 1,
      'Log dispatches messages at configured LogLevel');
    Assert(Recorder.LastLevel = sslLogWarning,
      'Log dispatch preserves the requested log level');
    Assert(Pos('warning should be delivered', Recorder.LastMessage) > 0,
      'Log dispatch preserves the message content');

    DefaultConfig := SnapshotConfig;
    DefaultConfig.LogLevel := sslLogError;
    DefaultConfig.LogCallback := nil;
    Lib.SetDefaultConfig(DefaultConfig);

    SnapshotConfig := Lib.GetDefaultConfig;
    Assert(SnapshotConfig.LogLevel = sslLogError,
      'SetDefaultConfig still updates LogLevel after callback detachment');
    Assert(CallbackEquals(Callback, SnapshotConfig.LogCallback),
      'SetDefaultConfig does not clear the installed callback; SetLogCallback remains the owner');

    Recorder.Reset;
    Lib.Log(sslLogWarning, 'warning should stay filtered at error level');
    Assert(Recorder.CallCount = 0,
      'SetDefaultConfig(LogLevel) can tighten filtering without clearing the callback');

    Lib.Log(sslLogError, 'error should still be delivered');
    Assert(Recorder.CallCount = 1,
      'Installed callback still receives logs after SetDefaultConfig updates LogLevel');
  finally
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    Recorder.Free;
  end;
end;

begin
  try
    Test_RequestConfigRejectsNonDefaultLogLevel;
    Test_RequestConfigRejectsLogCallback;
    Test_LibraryDefaultLoggingRoundTripAndDispatch;

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
