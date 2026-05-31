program test_early_data_public_api_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
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

procedure Test_MainUnit_ReExports_And_Helper_Surface;
var
  LClientCtx: ISSLContext;
  LServerCtx: ISSLContext;
  LConn: ISSLConnection;
  LEarlyCtx: ISSLEarlyDataContext;
  LEarlyConn: ISSLEarlyDataConnection;
  LStatus: TSSLEarlyDataStatus;
  LPolicy: TSSLEarlyDataServerPolicy;
begin
  TestHeader('Main unit exposes early-data public API ergonomically');

  LStatus := sslEarlyDataNone;
  Assert(LStatus = sslEarlyDataNone,
    'fafafa.ssl re-exports TSSLEarlyDataStatus and enum values');

  LPolicy := sslEarlyDataServerReject;
  Assert(LPolicy = sslEarlyDataServerReject,
    'fafafa.ssl re-exports TSSLEarlyDataServerPolicy and enum values');

  LClientCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  Assert(TSSLHelper.SupportsEarlyDataContext(LClientCtx),
    'TSSLHelper detects context early-data support');
  Assert(TSSLHelper.TryGetEarlyDataContext(LClientCtx, LEarlyCtx),
    'TSSLHelper returns ISSLEarlyDataContext without direct Supports(...)');
  Assert(not LEarlyCtx.GetClientEarlyDataEnabled,
    'client early-data defaults remain observable from fafafa.ssl only');
  Assert(TSSLHelper.ConfigureClientEarlyData(LClientCtx, True),
    'TSSLHelper can enable client early-data');
  Assert(LEarlyCtx.GetClientEarlyDataEnabled,
    'ConfigureClientEarlyData updates the context');

  LServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  Assert(TSSLHelper.TryGetEarlyDataContext(LServerCtx, LEarlyCtx),
    'server context also exposes ISSLEarlyDataContext');
  Assert(TSSLHelper.ConfigureServerEarlyData(LServerCtx,
      sslEarlyDataServerIssueOnly, 32),
    'TSSLHelper can configure server early-data policy and max-size');
  Assert(LEarlyCtx.GetServerEarlyDataPolicy = sslEarlyDataServerIssueOnly,
    'ConfigureServerEarlyData updates server early-data policy');
  Assert(LEarlyCtx.GetServerMaxEarlyDataSize = 32,
    'ConfigureServerEarlyData updates server max early-data size');

  LConn := LClientCtx.CreateConnection(THandle(-1));
  Assert(TSSLHelper.SupportsEarlyDataConnection(LConn),
    'TSSLHelper detects connection early-data support');
  Assert(TSSLHelper.TryGetEarlyDataConnection(LConn, LEarlyConn),
    'TSSLHelper returns ISSLEarlyDataConnection without direct Supports(...)');
  Assert(TSSLHelper.GetEarlyDataStatus(LConn) = sslEarlyDataNone,
    'TSSLHelper exposes default early-data status');
  Assert(TSSLHelper.GetEarlyDataLimit(LConn) = 0,
    'TSSLHelper exposes default early-data limit');
end;

begin
  try
    Test_MainUnit_ReExports_And_Helper_Surface;

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
