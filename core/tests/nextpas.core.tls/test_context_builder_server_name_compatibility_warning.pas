program test_context_builder_server_name_compatibility_warning;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  WithSNI compatibility warnings on builder paths. }

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
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

function LegacyContextServerName(ACtx: ISSLContext): string;
begin
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Result := ACtx.GetServerName;
  {$POP}
end;

procedure Test_BuildClientWithSNI_LogsCompatibilityWarning;
var
  LOriginalLogger: ISecurityLogger;
  LLogger: TWarningCaptureLogger;
  LCtx: ISSLContext;
begin
  TestHeader('BuildClient WithSNI logs compatibility warning');

  LOriginalLogger := TSecurityLog.Logger;
  LLogger := TWarningCaptureLogger.Create;
  LLogger.SetMinLevel(selWarning);
  TSecurityLog.Logger := LLogger;
  try
    LLogger.Reset;
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    LCtx := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .WithSNI('builder-client-warning.example.com')
      .BuildClient;
    {$POP}

    Assert(LCtx <> nil, 'BuildClient still succeeds');
    Assert(LegacyContextServerName(LCtx) = '',
      'BuildClient no longer retains the deprecated client-side ServerName on built contexts');
    Assert(LLogger.CallCount > 0, 'BuildClient WithSNI emits a warning');
    Assert(Pos('WithSNI', LLogger.LastMessage) > 0,
      'BuildClient warning names WithSNI');
    Assert(Pos('deprecated context-level SNI compatibility', LLogger.LastMessage) > 0,
      'BuildClient warning marks context-level SNI as compatibility-only');
    Assert(Pos('BuildClient ignores it', LLogger.LastMessage) > 0,
      'BuildClient warning explains that the built client context ignores legacy WithSNI');
    Assert(Pos('TSSLContextBuilderImpl.BuildClient', LLogger.LastMessage) > 0,
      'BuildClient warning identifies the builder callsite');
  finally
    TSecurityLog.Logger := LOriginalLogger;
  end;
end;

procedure Test_BuildServerWithSNI_LogsCompatibilityWarning;
var
  LOriginalLogger: ISecurityLogger;
  LLogger: TWarningCaptureLogger;
  LCtx: ISSLContext;
  LCertPEM: string;
  LKeyPEM: string;
begin
  TestHeader('BuildServer WithSNI logs compatibility warning');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'builder-warning.local', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
    raise Exception.Create('Failed to generate self-signed certificate');

  LOriginalLogger := TSecurityLog.Logger;
  LLogger := TWarningCaptureLogger.Create;
  LLogger.SetMinLevel(selWarning);
  TSecurityLog.Logger := LLogger;
  try
    LLogger.Reset;
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    LCtx := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithSNI('builder-server-warning.example.com')
      .BuildServer;
    {$POP}

    Assert(LCtx <> nil, 'BuildServer still succeeds');
    Assert(LegacyContextServerName(LCtx) = '',
      'BuildServer no longer retains the deprecated client-only ServerName on server contexts');
    Assert(LLogger.CallCount > 0, 'BuildServer WithSNI emits a warning');
    Assert(Pos('WithSNI', LLogger.LastMessage) > 0,
      'BuildServer warning names WithSNI');
    Assert(Pos('BuildServer ignores it', LLogger.LastMessage) > 0,
      'BuildServer warning explains that the built server context ignores legacy WithSNI');
    Assert(Pos('server-side connections ignore it', LLogger.LastMessage) > 0,
      'BuildServer warning also explains the server-side connection ignore semantics');
    Assert(Pos('TSSLContextBuilderImpl.BuildServer', LLogger.LastMessage) > 0,
      'BuildServer warning identifies the builder callsite');
  finally
    TSecurityLog.Logger := LOriginalLogger;
  end;
end;

procedure Test_BuildClientWithoutSNI_DoesNotWarn;
var
  LOriginalLogger: ISecurityLogger;
  LLogger: TWarningCaptureLogger;
  LCtx: ISSLContext;
begin
  TestHeader('BuildClient without WithSNI stays quiet');

  LOriginalLogger := TSecurityLog.Logger;
  LLogger := TWarningCaptureLogger.Create;
  LLogger.SetMinLevel(selWarning);
  TSecurityLog.Logger := LLogger;
  try
    LLogger.Reset;
    LCtx := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .BuildClient;

    Assert(LCtx <> nil, 'BuildClient without WithSNI still succeeds');
    Assert(LLogger.CallCount = 0, 'BuildClient without WithSNI emits no warning');
  finally
    TSecurityLog.Logger := LOriginalLogger;
  end;
end;

begin
  try
    Test_BuildClientWithSNI_LogsCompatibilityWarning;
    Test_BuildServerWithSNI_LogsCompatibilityWarning;
    Test_BuildClientWithoutSNI_DoesNotWarn;

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
