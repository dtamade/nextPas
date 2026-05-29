program test_ssl_ctrl;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

begin
  WriteLn('SSL_ctrl Loading Test');
  WriteLn('=====================');
  WriteLn;
  
  // Load OpenSSL core
  LoadOpenSSLCore();
  
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    WriteLn('[OK] OpenSSL core loaded successfully');
    WriteLn('Version: ', GetOpenSSLVersionString);
  end
  else
  begin
    WriteLn('[ERROR] Failed to load OpenSSL core');
    Halt(1);
  end;
  
  WriteLn;
  WriteLn('Checking SSL_ctrl function pointer...');
  WriteLn;
  
  if Assigned(SSL_ctrl) then
  begin
    WriteLn('[SUCCESS] SSL_ctrl is loaded and assigned!');
    WriteLn('Function pointer address: ', IntToHex(PtrUInt(@SSL_ctrl), 16));
  end
  else
  begin
    WriteLn('[FAIL] SSL_ctrl is nil (not loaded)');
    Halt(1);
  end;
  
  WriteLn;
  WriteLn('Checking SSL_CTX_ctrl function pointer...');
  WriteLn;
  
  if Assigned(SSL_CTX_ctrl) then
  begin
    WriteLn('[SUCCESS] SSL_CTX_ctrl is loaded and assigned!');
    WriteLn('Function pointer address: ', IntToHex(PtrUInt(@SSL_CTX_ctrl), 16));
  end
  else
  begin
    WriteLn('[FAIL] SSL_CTX_ctrl is nil (not loaded)');
    Halt(1);
  end;
  
  WriteLn;
  WriteLn('=====================');
  WriteLn('All control functions loaded successfully!');
  WriteLn('=====================');
end.
