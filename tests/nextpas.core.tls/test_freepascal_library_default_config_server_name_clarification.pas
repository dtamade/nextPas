program test_freepascal_library_default_config_server_name_clarification;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  TSSLConfig.ServerName compatibility on the FreePascal direct-library path. }

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
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

function CreateInitializedLibrary: ISSLLibrary;
begin
  Result := CreateFreePascalSSLLibrary;
  if Result = nil then
    raise Exception.Create('CreateFreePascalSSLLibrary returned nil');

  if not Result.Initialize then
    raise Exception.Create('FreePascal library failed to initialize for direct-library ServerName clarification test');
end;

procedure Test_ClientDefaultConfigServerName_IsIgnoredAndWarns;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal library client default-config ServerName is ignored');

  Lib := CreateInitializedLibrary;
  Recorder := TLogRecorder.Create;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.ServerName := 'library-client.example.com';
    Lib.SetDefaultConfig(DefaultConfig);
    Lib.SetLogCallback(@Recorder.HandleLog);

    Recorder.Reset;
    Ctx := Lib.CreateContext(sslCtxClient);

    Assert(Ctx <> nil, 'FreePascal direct-library client context still builds');
    Assert(Ctx.GetServerName = '',
      'FreePascal direct-library client context no longer preserves deprecated default ServerName');
    Assert(Recorder.CallCount > 0,
      'FreePascal direct-library client default-config ServerName emits a warning');
    Assert(Recorder.LastLevel = sslLogWarning,
      'FreePascal direct-library warning uses warning severity');
    Assert(Pos('TSSLConfig.ServerName', Recorder.LastMessage) > 0,
      'FreePascal direct-library warning names TSSLConfig.ServerName');
    Assert(Pos('deprecated context-level SNI compatibility', Recorder.LastMessage) > 0,
      'FreePascal direct-library warning marks context-level SNI as compatibility-only');
    Assert(Pos('CreateContext ignores it', Recorder.LastMessage) > 0,
      'FreePascal direct-library warning explains that new client contexts ignore deprecated ServerName');
    Assert(Pos('TFreePascalSSLLibrary.CreateContext', Recorder.LastMessage) > 0,
      'FreePascal direct-library warning identifies the library callsite');
  finally
    Ctx := nil;
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
    Recorder.Free;
  end;
end;

procedure Test_ServerDefaultConfigServerName_IsRejected;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal library server default-config ServerName is rejected');

  Lib := CreateInitializedLibrary;
  Recorder := TLogRecorder.Create;
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
        'FreePascal direct-library server default-config ServerName should raise ESSLConfigurationException');
    except
      on E: ESSLConfigurationException do
      begin
        Assert(E.ErrorCode = sslErrConfiguration,
          'FreePascal direct-library server default-config ServerName raises sslErrConfiguration');
        Assert(Pos('ServerName is client-scoped', E.Message) > 0,
          'FreePascal direct-library server default-config error explains client scope');
        Assert(Pos('TFreePascalSSLLibrary.CreateContext', E.Message) > 0,
          'FreePascal direct-library server default-config error identifies the library callsite');
      end;
      on E: Exception do
        Assert(False,
          'FreePascal direct-library server default-config ServerName raised unexpected ' +
          E.ClassName + ': ' + E.Message);
    end;
  finally
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
    Recorder.Free;
  end;
end;

procedure Test_ClientWithoutServerName_DoesNotWarn;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Recorder: TLogRecorder;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal library client default-config without ServerName stays quiet');

  Lib := CreateInitializedLibrary;
  Recorder := TLogRecorder.Create;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.LogLevel := sslLogWarning;
    DefaultConfig.ServerName := '';
    Lib.SetDefaultConfig(DefaultConfig);
    Lib.SetLogCallback(@Recorder.HandleLog);

    Recorder.Reset;
    Ctx := Lib.CreateContext(sslCtxClient);

    Assert(Ctx <> nil, 'FreePascal direct-library client context without ServerName still builds');
    Assert(Recorder.CallCount = 0,
      'FreePascal direct-library client context without ServerName emits no warning');
  finally
    Ctx := nil;
    Lib.SetLogCallback(OriginalConfig.LogCallback);
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
    Recorder.Free;
  end;
end;

begin
  try
    Test_ClientDefaultConfigServerName_IsIgnoredAndWarns;
    Test_ServerDefaultConfigServerName_IsRejected;
    Test_ClientWithoutServerName_DoesNotWarn;

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
