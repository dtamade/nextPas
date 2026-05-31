program test_openssl_ssl_post_handshake_contract;

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

procedure TestLoadPublishesExportedPostHandshakeHelpers;
var
  LHandle: TLibHandle;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libssl for post-handshake-auth load contract test');
    Exit;
  end;

  Check(LoadOpenSSLSSL,
    'SSL module can be loaded for post-handshake-auth load contract test');
  Check(TOpenSSLLoader.IsModuleLoaded(osmSSL),
    'SSL module publishes loaded state for post-handshake-auth contract');

  CheckExportedHelperIsBound(LHandle, 'SSL_CTX_set_post_handshake_auth',
    Assigned(SSL_CTX_set_post_handshake_auth),
    'Context post-handshake-auth setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_set_post_handshake_auth',
    Assigned(SSL_set_post_handshake_auth),
    'SSL post-handshake-auth setter');
  CheckExportedHelperIsBound(LHandle, 'SSL_verify_client_post_handshake',
    Assigned(SSL_verify_client_post_handshake),
    'Post-handshake client-verify helper');
end;

begin
  TestLoadPublishesExportedPostHandshakeHelpers;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
