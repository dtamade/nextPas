program test_factory_server_name_compatibility_warning;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  TSSLConfig.ServerName compatibility warnings on factory paths. }

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.logging;

type
  TWarningCaptureLogger = class(TBaseLogger)
  public
    CallCount: Integer;
    LastMessage: string;

    procedure WriteLog(const AMessage: string); override;
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

procedure TWarningCaptureLogger.WriteLog(const AMessage: string);
begin
  Inc(CallCount);
  LastMessage := AMessage;
end;

procedure TWarningCaptureLogger.Reset;
begin
  CallCount := 0;
  LastMessage := '';
end;

procedure Test_DefaultConfigClientServerName_LogsCompatibilityWarning;
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LDefaultConfig: TSSLConfig;
  LOriginalLogger: ISecurityLogger;
  LLogger: TWarningCaptureLogger;
  LCtx: ISSLContext;
begin
  TestHeader('Default-config client ServerName logs compatibility warning');

  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  LOriginalConfig := LLib.GetDefaultConfig;
  LOriginalLogger := TSecurityLog.Logger;
  LLogger := TWarningCaptureLogger.Create;
  LLogger.SetMinLevel(selWarning);
  TSecurityLog.Logger := LLogger;
  try
    LDefaultConfig := LOriginalConfig;
    LDefaultConfig.ServerName := 'default-warning.example.com';
    LLib.SetDefaultConfig(LDefaultConfig);

    LLogger.Reset;
    LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);

    Assert(LCtx <> nil, 'Default-config client context still builds');
    Assert(LCtx.GetServerName = '',
      'Default-config client context no longer retains deprecated ServerName state');
    Assert(LLogger.CallCount > 0, 'Default-config client ServerName emits a warning');
    Assert(Pos('TSSLConfig.ServerName', LLogger.LastMessage) > 0,
      'Default-config warning names TSSLConfig.ServerName');
    Assert(Pos('deprecated context-level SNI compatibility', LLogger.LastMessage) > 0,
      'Default-config warning marks context-level SNI as compatibility-only');
    Assert(Pos('CreateContext ignores it', LLogger.LastMessage) > 0,
      'Default-config warning explains that the built context ignores deprecated ServerName');
    Assert(Pos('TSSLFactory.CreateContext(AContextType, ALibType)', LLogger.LastMessage) > 0,
      'Default-config warning identifies the factory callsite');
  finally
    TSecurityLog.Logger := LOriginalLogger;
    LLib.SetDefaultConfig(LOriginalConfig);
  end;
end;

procedure Test_OneShotClientServerName_LogsCompatibilityWarning;
var
  LConfig: TSSLConfig;
  LOriginalLogger: ISecurityLogger;
  LLogger: TWarningCaptureLogger;
  LCtx: ISSLContext;
begin
  TestHeader('One-shot client ServerName logs compatibility warning');

  LOriginalLogger := TSecurityLog.Logger;
  LLogger := TWarningCaptureLogger.Create;
  LLogger.SetMinLevel(selWarning);
  TSecurityLog.Logger := LLogger;
  try
    LConfig := CreateDefaultConfig(sslCtxClient);
    LConfig.LibraryType := sslFreePascal;
    LConfig.ContextType := sslCtxClient;
    LConfig.ServerName := 'oneshot-warning.example.com';

    LLogger.Reset;
    LCtx := TSSLFactory.CreateContext(LConfig);

    Assert(LCtx <> nil, 'One-shot client context still builds');
    Assert(LCtx.GetServerName = '',
      'One-shot client context no longer retains deprecated ServerName state');
    Assert(LLogger.CallCount > 0, 'One-shot client ServerName emits a warning');
    Assert(Pos('TSSLConfig.ServerName', LLogger.LastMessage) > 0,
      'One-shot warning names TSSLConfig.ServerName');
    Assert(Pos('deprecated context-level SNI compatibility', LLogger.LastMessage) > 0,
      'One-shot warning marks context-level SNI as compatibility-only');
    Assert(Pos('CreateContext ignores it', LLogger.LastMessage) > 0,
      'One-shot warning explains that the built context ignores deprecated ServerName');
    Assert(Pos('TSSLFactory.CreateContext(const AConfig)', LLogger.LastMessage) > 0,
      'One-shot warning identifies the factory callsite');
  finally
    TSecurityLog.Logger := LOriginalLogger;
  end;
end;

procedure Test_ClientWithoutServerName_DoesNotWarn;
var
  LConfig: TSSLConfig;
  LOriginalLogger: ISecurityLogger;
  LLogger: TWarningCaptureLogger;
  LCtx: ISSLContext;
begin
  TestHeader('Client config without ServerName stays quiet');

  LOriginalLogger := TSecurityLog.Logger;
  LLogger := TWarningCaptureLogger.Create;
  LLogger.SetMinLevel(selWarning);
  TSecurityLog.Logger := LLogger;
  try
    LConfig := CreateDefaultConfig(sslCtxClient);
    LConfig.LibraryType := sslFreePascal;
    LConfig.ContextType := sslCtxClient;

    LLogger.Reset;
    LCtx := TSSLFactory.CreateContext(LConfig);

    Assert(LCtx <> nil, 'Client context without ServerName still builds');
    Assert(LLogger.CallCount = 0, 'Client config without ServerName emits no warning');
  finally
    TSecurityLog.Logger := LOriginalLogger;
  end;
end;

begin
  try
    Test_DefaultConfigClientServerName_LogsCompatibilityWarning;
    Test_OneShotClientServerName_LogsCompatibilityWarning;
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
