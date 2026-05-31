program test_openssl_ssl_unload_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
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

procedure TestUnloadClearsLoadedSSLHelperSurface;
begin
  ResetLoaderState;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for unload contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state after successful load');

  Check(Assigned(SSL_CTX_set_options),
    'SSL options helper is assigned before unload');
  Check(Assigned(SSL_CTX_set_cipher_list),
    'SSL cipher-list helper is assigned before unload');
  Check(Assigned(SSL_set_tlsext_host_name),
    'SSL SNI helper is assigned before unload');
  Check(Assigned(SSL_CTX_set_alpn_protos),
    'SSL ALPN helper is assigned before unload');
  Check(Assigned(SSL_CIPHER_get_name),
    'SSL cipher-introspection helper is assigned before unload');

  UnloadOpenSSLSSL;

  Check(not TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module clears loaded state on unload');
  Check(not Assigned(SSL_CTX_set_options),
    'SSL options helper is cleared on unload');
  Check(not Assigned(SSL_CTX_set_cipher_list),
    'SSL cipher-list helper is cleared on unload');
  Check(not Assigned(SSL_set_tlsext_host_name),
    'SSL SNI helper is cleared on unload');
  Check(not Assigned(SSL_CTX_set_alpn_protos),
    'SSL ALPN helper is cleared on unload');
  Check(not Assigned(SSL_CIPHER_get_name),
    'SSL cipher-introspection helper is cleared on unload');
end;

begin
  TestUnloadClearsLoadedSSLHelperSurface;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
