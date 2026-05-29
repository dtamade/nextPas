program test_sni_diagnostic;

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl;

var
  SSLLib: TLibHandle;
  FuncPtr: Pointer;
  
begin
  WriteLn('SNI Function Availability Diagnostic');
  WriteLn('=====================================');
  WriteLn;
  
  // Load OpenSSL core
  LoadOpenSSLCore();
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    WriteLn('[OK] OpenSSL core loaded');
    WriteLn('Version: ', GetOpenSSLVersionString);
  end
  else
  begin
    WriteLn('[ERROR] Failed to load OpenSSL core');
    Halt(1);
  end;
  
  WriteLn;
  WriteLn('Checking SSL extension functions...');
  WriteLn;
  
  // Get SSL library handle
  SSLLib := GetSSLLibHandle;
  if SSLLib = 0 then
  begin
    WriteLn('[ERROR] Could not get SSL library handle');
    Halt(1);
  end;
  
  WriteLn('[OK] SSL library handle obtained: ', IntToHex(SSLLib, 16));
  WriteLn;
  
  // Check for SNI functions
  FuncPtr := GetProcAddress(SSLLib, 'SSL_CTX_set_tlsext_servername_callback');
  if FuncPtr <> nil then
    WriteLn('[OK] SSL_CTX_set_tlsext_servername_callback found at: ', IntToHex(PtrUInt(FuncPtr), 16))
  else
    WriteLn('[MISSING] SSL_CTX_set_tlsext_servername_callback not found');
    
  FuncPtr := GetProcAddress(SSLLib, 'SSL_CTX_set_tlsext_servername_arg');
  if FuncPtr <> nil then
    WriteLn('[OK] SSL_CTX_set_tlsext_servername_arg found at: ', IntToHex(PtrUInt(FuncPtr), 16))
  else
    WriteLn('[MISSING] SSL_CTX_set_tlsext_servername_arg not found');
    
  FuncPtr := GetProcAddress(SSLLib, 'SSL_set_tlsext_host_name');
  if FuncPtr <> nil then
    WriteLn('[OK] SSL_set_tlsext_host_name found at: ', IntToHex(PtrUInt(FuncPtr), 16))
  else
    WriteLn('[MISSING] SSL_set_tlsext_host_name not found (Note: This is a macro, not a function)');
    
  FuncPtr := GetProcAddress(SSLLib, 'SSL_get_servername');
  if FuncPtr <> nil then
    WriteLn('[OK] SSL_get_servername found at: ', IntToHex(PtrUInt(FuncPtr), 16))
  else
    WriteLn('[MISSING] SSL_get_servername not found');
    
  FuncPtr := GetProcAddress(SSLLib, 'SSL_get_servername_type');
  if FuncPtr <> nil then
    WriteLn('[OK] SSL_get_servername_type found at: ', IntToHex(PtrUInt(FuncPtr), 16))
  else
    WriteLn('[MISSING] SSL_get_servername_type not found');
    
  WriteLn;
  WriteLn('Testing LoadOpenSSLSSL function...');
  if LoadOpenSSLSSL then
    WriteLn('[OK] LoadOpenSSLSSL succeeded')
  else
    WriteLn('[ERROR] LoadOpenSSLSSL failed');
    
  WriteLn;
  WriteLn('Checking if function pointers are assigned...');
  
  if Assigned(SSL_CTX_set_tlsext_servername_callback) then
    WriteLn('[OK] SSL_CTX_set_tlsext_servername_callback is assigned')
  else
    WriteLn('[MISSING] SSL_CTX_set_tlsext_servername_callback is nil');
    
  if Assigned(SSL_get_servername) then
    WriteLn('[OK] SSL_get_servername is assigned')
  else
    WriteLn('[MISSING] SSL_get_servername is nil');
    
  WriteLn;
  WriteLn('Diagnostic complete.');
end.
