program test_openssl_ssl_early_data_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  Dynlibs,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.ssl;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Fail(const AMessage: string);
begin
  Inc(GTestsFailed);
  WriteLn('[FAIL] ', AMessage);
end;

procedure Pass(const AMessage: string);
begin
  Inc(GTestsPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Pass(AMessage)
  else
    Fail(AMessage);
end;

procedure ResetLoaderState;
begin
  UnloadOpenSSLSSL;
  TOpenSSLLoader.ResetModuleStates;
end;

procedure CheckExportedHelperIsBound(AHandle: TLibHandle; const ASymbol: string;
  AAssigned: Boolean; const ALabel: string);
begin
  if TOpenSSLLoader.IsFunctionAvailable(AHandle, ASymbol) then
    Check(AAssigned, ALabel + ' is bound when libssl exports ' + ASymbol)
  else
    WriteLn('[SKIP] libssl does not export ', ASymbol);
end;

procedure TestLoadPublishesExportedEarlyDataHelpers;
var
  LHandle: TLibHandle;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libssl for SSL early-data contract test');
    Exit;
  end;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for early-data contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state for early-data contract');

  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_max_early_data',
    Assigned(SSL_CTX_set_max_early_data),
    'Context max-early-data setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_get_max_early_data',
    Assigned(SSL_CTX_get_max_early_data),
    'Context max-early-data getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_max_early_data',
    Assigned(SSL_set_max_early_data),
    'SSL max-early-data setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_max_early_data',
    Assigned(SSL_get_max_early_data),
    'SSL max-early-data getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_early_data_status',
    Assigned(SSL_get_early_data_status),
    'Early-data status getter');
end;

begin
  TestLoadPublishesExportedEarlyDataHelpers;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
