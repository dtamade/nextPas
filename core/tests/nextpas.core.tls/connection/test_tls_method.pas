program test_tls_method;
{$mode objfpc}{$H+}
uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.base;
var
  Method: PSSL_METHOD;
begin
  // Load OpenSSL core which includes SSL functions
  LoadOpenSSLCore();
  
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    WriteLn('ERROR: Failed to load OpenSSL');
    Halt(1);
  end;
  
  WriteLn('OpenSSL loaded: ', GetOpenSSLVersionString);
  WriteLn;
  
  WriteLn('TLS_client_method assigned: ', Assigned(TLS_client_method));
  WriteLn('TLS_server_method assigned: ', Assigned(TLS_server_method));
  
  if Assigned(TLS_client_method) then
  begin
    WriteLn('Calling TLS_client_method...');
    Method := TLS_client_method();
    WriteLn('Result: ', PtrUInt(Method));
    WriteLn('SUCCESS: TLS methods are functional');
  end
  else
  begin
    WriteLn('ERROR: TLS_client_method not loaded');
    Halt(1);
  end;
end.
