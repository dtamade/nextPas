program test_openssl_ssl_async_quic_contract;

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

procedure TestLoadPublishesExportedAsyncAndQuicHelpers;
var
  LHandle: TLibHandle;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libssl for SSL async/QUIC contract test');
    Exit;
  end;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for async/QUIC contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state for async/QUIC contract');

  CheckExportedHelperIsBound(LHandle, 'SSL_poll',
    Assigned(SSL_poll),
    'SSL_poll helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_async_callback',
    Assigned(SSL_set_async_callback),
    'SSL async-callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_async_callback_arg',
    Assigned(SSL_set_async_callback_arg),
    'SSL async-callback arg setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_async_status',
    Assigned(SSL_get_async_status),
    'SSL async-status getter');

  CheckExportedHelperIsBound(LHandle, 'SSL_get_stream_id',
    Assigned(SSL_get_stream_id),
    'QUIC stream-id getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_stream_type',
    Assigned(SSL_get_stream_type),
    'QUIC stream-type getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_is_stream_local',
    Assigned(SSL_is_stream_local),
    'QUIC is-stream-local helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_new_stream',
    Assigned(SSL_new_stream),
    'QUIC new-stream helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_accept_stream',
    Assigned(SSL_accept_stream),
    'QUIC accept-stream helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_accept_stream_queue_len',
    Assigned(SSL_get_accept_stream_queue_len),
    'QUIC accept-stream-queue-length helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_default_stream_mode',
    Assigned(SSL_set_default_stream_mode),
    'QUIC default-stream-mode setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_incoming_stream_policy',
    Assigned(SSL_set_incoming_stream_policy),
    'QUIC incoming-stream-policy setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get0_connection',
    Assigned(SSL_get0_connection),
    'QUIC get0-connection helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_is_connection',
    Assigned(SSL_is_connection),
    'QUIC is-connection helper');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_stream_read_error_code',
    Assigned(SSL_get_stream_read_error_code),
    'QUIC stream-read-error-code getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_stream_write_error_code',
    Assigned(SSL_get_stream_write_error_code),
    'QUIC stream-write-error-code getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_conn_close_info',
    Assigned(SSL_get_conn_close_info),
    'QUIC connection-close-info getter');
end;

begin
  TestLoadPublishesExportedAsyncAndQuicHelpers;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
