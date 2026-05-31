program test_factory_server_name_scope_clarification;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  TSSLConfig.ServerName compatibility-only semantics on factory paths. }

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.exceptions;

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

function ConnectionServerName(ACtx: ISSLContext): string;
var
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
begin
  LConn := ACtx.CreateConnection(THandle(-1));
  if not Supports(LConn, ISSLClientConnection, LClientConn) then
    raise Exception.Create('Connection does not support ISSLClientConnection');
  Result := LClientConn.GetServerName;
end;

procedure Test_DefaultConfig_ClientServerName_IsIgnored;
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LDefaultConfig: TSSLConfig;
  LCtx: ISSLContext;
begin
  TestHeader('Client default-config ServerName is ignored on FreePascal');

  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  LOriginalConfig := LLib.GetDefaultConfig;
  try
    LDefaultConfig := LOriginalConfig;
    LDefaultConfig.ServerName := 'client-default.example.com';
    LLib.SetDefaultConfig(LDefaultConfig);

    LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
    Assert(LCtx.GetServerName = '',
      'Client default-config context no longer preserves ServerName');
    Assert(ConnectionServerName(LCtx) = '',
      'FreePascal client default-config connection still keeps empty ServerName');
  finally
    LLib.SetDefaultConfig(LOriginalConfig);
  end;
end;

procedure Test_DefaultConfig_ServerServerName_IsRejected;
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LDefaultConfig: TSSLConfig;
  LRaised: Boolean;
begin
  TestHeader('Server default-config ServerName is rejected');

  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  LOriginalConfig := LLib.GetDefaultConfig;
  try
    LDefaultConfig := LOriginalConfig;
    LDefaultConfig.ServerName := 'server-default.example.com';
    LLib.SetDefaultConfig(LDefaultConfig);

    LRaised := False;
    try
      TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
    except
      on E: ESSLConfigurationException do
        LRaised := True;
      on E: Exception do
      begin
        Assert(False,
          'CreateContext(sslCtxServer, sslFreePascal) raised unexpected ' +
          E.ClassName + ': ' + E.Message);
        Exit;
      end
    end;

    Assert(LRaised,
      'CreateContext(sslCtxServer, sslFreePascal) with default-config ServerName raises ESSLConfigurationException');
  finally
    LLib.SetDefaultConfig(LOriginalConfig);
  end;
end;

procedure Test_OneShot_ClientServerName_IsIgnored;
var
  LConfig: TSSLConfig;
  LCtx: ISSLContext;
begin
  TestHeader('Client one-shot ServerName is ignored on FreePascal');

  LConfig := CreateDefaultConfig(sslCtxClient);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ContextType := sslCtxClient;
  LConfig.ServerName := 'client-oneshot.example.com';

  LCtx := TSSLFactory.CreateContext(LConfig);
  Assert(LCtx.GetServerName = '',
    'Client one-shot context no longer preserves ServerName');
  Assert(ConnectionServerName(LCtx) = '',
    'FreePascal client one-shot connection still keeps empty ServerName');
end;

procedure Test_OneShot_ServerServerName_IsRejected;
var
  LConfig: TSSLConfig;
  LRaised: Boolean;
begin
  TestHeader('Server one-shot ServerName is rejected');

  LConfig := CreateDefaultConfig(sslCtxServer);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ContextType := sslCtxServer;
  LConfig.ServerName := 'server-oneshot.example.com';

  LRaised := False;
  try
    TSSLFactory.CreateContext(LConfig);
  except
    on E: ESSLConfigurationException do
      LRaised := True;
    on E: Exception do
    begin
      Assert(False,
        'CreateContext(const AConfig) raised unexpected ' + E.ClassName + ': ' + E.Message);
      Exit;
    end
  end;

  Assert(LRaised,
    'CreateContext(const AConfig) with server ServerName raises ESSLConfigurationException');
end;

begin
  try
    Test_DefaultConfig_ClientServerName_IsIgnored;
    Test_DefaultConfig_ServerServerName_IsRejected;
    Test_OneShot_ClientServerName_IsIgnored;
    Test_OneShot_ServerServerName_IsRejected;

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
