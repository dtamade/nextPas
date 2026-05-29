program test_default_config;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  fafafa.ssl;

type
  TLogCallbackProbe = class
  public
    procedure HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
  end;

procedure AssertTrue(const AName: string; AValue: Boolean);
begin
  if AValue then
    WriteLn('  [PASS] ', AName)
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Halt(1);
  end;
end;

procedure TLogCallbackProbe.HandleLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  if (ALevel = sslLogNone) and (AMessage = '') then;
end;

procedure TestDefaultConfigSecurityBaseline;
var
  Cfg: TSSLConfig;
begin
  Cfg := CreateDefaultConfig(sslCtxClient);

  AssertTrue('CreateDefaultConfig returns correct context type', Cfg.ContextType = sslCtxClient);
  AssertTrue('Default options contains ssoDisableCompression', ssoDisableCompression in Cfg.Options);
  AssertTrue('Default options contains ssoDisableRenegotiation', ssoDisableRenegotiation in Cfg.Options);

  AssertTrue('Default options disables SSLv2', ssoNoSSLv2 in Cfg.Options);
  AssertTrue('Default options disables SSLv3', ssoNoSSLv3 in Cfg.Options);
  AssertTrue('Default options disables TLSv1.0', ssoNoTLSv1 in Cfg.Options);
  AssertTrue('Default options disables TLSv1.1', ssoNoTLSv1_1 in Cfg.Options);

  AssertTrue('VerifyDepth non-zero', Cfg.VerifyDepth > 0);
  AssertTrue('CipherList not empty', Cfg.CipherList <> '');
  AssertTrue('CipherSuites not empty', Cfg.CipherSuites <> '');
  AssertTrue('UseSystemRoots defaults to False', not Cfg.UseSystemRoots);
  AssertTrue('ClientEarlyDataEnabled defaults to False', not Cfg.ClientEarlyDataEnabled);
  AssertTrue('ServerEarlyDataPolicy defaults to Reject',
    Cfg.ServerEarlyDataPolicy = sslEarlyDataServerReject);
  AssertTrue('ServerMaxEarlyDataSize defaults to 0',
    Cfg.ServerMaxEarlyDataSize = 0);
  AssertTrue('ServerEarlyDataReplayStoreFile defaults to empty',
    Cfg.ServerEarlyDataReplayStoreFile = '');
end;

procedure TestDefaultConfigIgnoresLibraryScopedLoggingDefaults;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  LoggingConfig: TSSLConfig;
  Cfg: TSSLConfig;
  Probe: TLogCallbackProbe;
  OriginalDefaultLibrary: TSSLLibraryType;
begin
  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  OriginalConfig := Lib.GetDefaultConfig;
  OriginalDefaultLibrary := TSSLFactory.GetDefaultLibrary;
  Probe := TLogCallbackProbe.Create;
  try
    LoggingConfig := OriginalConfig;
    LoggingConfig.LogLevel := sslLogTrace;
    LoggingConfig.LogCallback := @Probe.HandleLog;
    Lib.SetDefaultConfig(LoggingConfig);
    TSSLFactory.SetDefaultLibrary(sslFreePascal);

    Cfg := CreateDefaultConfig(sslCtxClient);

    AssertTrue('CreateDefaultConfig keeps request-safe LogLevel',
      Cfg.LogLevel = sslLogError);
    AssertTrue('CreateDefaultConfig clears library-scoped LogCallback',
      not Assigned(Cfg.LogCallback));
  finally
    TSSLFactory.SetDefaultLibrary(OriginalDefaultLibrary);
    Lib.SetDefaultConfig(OriginalConfig);
    Probe.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  fafafa.ssl DefaultConfig 单元测试');
  WriteLn('========================================');

  TestDefaultConfigSecurityBaseline;
  TestDefaultConfigIgnoresLibraryScopedLoggingDefaults;

  WriteLn('所有测试通过！✓');
end.
