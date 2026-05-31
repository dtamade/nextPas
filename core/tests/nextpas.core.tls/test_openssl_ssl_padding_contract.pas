program test_openssl_ssl_padding_contract;

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

procedure TestLoadPublishesExportedKeylogAndPaddingHelpers;
var
  LHandle: TLibHandle;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libssl for SSL keylog/padding contract test');
    Exit;
  end;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for keylog/padding contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state for keylog/padding contract');

  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_keylog_callback',
    Assigned(SSL_CTX_set_keylog_callback),
    'Context keylog setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_get_keylog_callback',
    Assigned(SSL_CTX_get_keylog_callback),
    'Context keylog getter');

  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_record_padding_callback',
    Assigned(SSL_CTX_set_record_padding_callback),
    'Context record-padding callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_get_record_padding_callback',
    Assigned(SSL_CTX_get_record_padding_callback),
    'Context record-padding callback getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_record_padding_callback_arg',
    Assigned(SSL_CTX_set_record_padding_callback_arg),
    'Context record-padding arg setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_get_record_padding_callback_arg',
    Assigned(SSL_CTX_get_record_padding_callback_arg),
    'Context record-padding arg getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_block_padding',
    Assigned(SSL_CTX_set_block_padding),
    'Context block-padding setter');

  CheckExportedHelperIsBound(LHandle, 'SSL_set_record_padding_callback',
    Assigned(SSL_set_record_padding_callback),
    'SSL record-padding callback setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_record_padding_callback',
    Assigned(SSL_get_record_padding_callback),
    'SSL record-padding callback getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_record_padding_callback_arg',
    Assigned(SSL_set_record_padding_callback_arg),
    'SSL record-padding arg setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_get_record_padding_callback_arg',
    Assigned(SSL_get_record_padding_callback_arg),
    'SSL record-padding arg getter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_block_padding',
    Assigned(SSL_set_block_padding),
    'SSL block-padding setter');
end;

begin
  TestLoadPublishesExportedKeylogAndPaddingHelpers;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
