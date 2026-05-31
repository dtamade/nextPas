program test_openssl_ssl_load_contract;

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

procedure TestLoadPublishesExportedInfoAndStateHelpers;
var
  LHandle: TLibHandle;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libssl for SSL load contract test');
    Exit;
  end;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for load contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state after load');

  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_info_callback',
    Assigned(SSL_CTX_set_info_callback),
    'Info-callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_get_info_callback',
    Assigned(SSL_CTX_get_info_callback),
    'Info-callback getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_info_callback',
    Assigned(SSL_set_info_callback),
    'SSL-level info-callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_info_callback',
    Assigned(SSL_get_info_callback),
    'SSL-level info-callback getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_state_string',
    Assigned(SSL_state_string),
    'Short state-string helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_state_string_long',
    Assigned(SSL_state_string_long),
    'Long state-string helper');
end;

procedure TestLoadPublishesExportedSessionTicketAndPSKHelpers;
var
  LHandle: TLibHandle;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libssl for SSL ticket/PSK load contract test');
    Exit;
  end;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for ticket/PSK load contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state for ticket/PSK contract');

  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_tlsext_ticket_key_cb',
    Assigned(SSL_CTX_set_tlsext_ticket_key_cb),
    'Ticket-key callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_session_ticket_ext',
    Assigned(SSL_set_session_ticket_ext),
    'Session-ticket extension setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_session_ticket_ext_cb',
    Assigned(SSL_set_session_ticket_ext_cb),
    'Session-ticket extension callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_use_psk_identity_hint',
    Assigned(SSL_CTX_use_psk_identity_hint),
    'Context PSK identity-hint setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_use_psk_identity_hint',
    Assigned(SSL_use_psk_identity_hint),
    'SSL PSK identity-hint setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_psk_server_callback',
    Assigned(SSL_CTX_set_psk_server_callback),
    'Context PSK server-callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_psk_server_callback',
    Assigned(SSL_set_psk_server_callback),
    'SSL PSK server-callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_psk_client_callback',
    Assigned(SSL_CTX_set_psk_client_callback),
    'Context PSK client-callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_psk_client_callback',
    Assigned(SSL_set_psk_client_callback),
    'SSL PSK client-callback setter');
end;

begin
  TestLoadPublishesExportedInfoAndStateHelpers;
  TestLoadPublishesExportedSessionTicketAndPSKHelpers;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
