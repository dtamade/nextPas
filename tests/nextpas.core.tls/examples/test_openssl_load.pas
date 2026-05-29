program test_openssl_load;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

begin
  WriteLn('Testing OpenSSL library loading...');
  WriteLn('');
  
  try
    // Try to load OpenSSL
    LoadOpenSSLCore;
    
    if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('SUCCESS: OpenSSL libraries loaded successfully!');
      
      // Try to get version
      if Assigned(OpenSSL_version_num) then
      begin
        WriteLn('OpenSSL version number: ', IntToHex(OpenSSL_version_num(), 8));
      end;
      
      if Assigned(OpenSSL_version) then
      begin
        WriteLn('OpenSSL version string: ', string(OpenSSL_version(0)));
      end;
      
      // Unload
      UnloadOpenSSLCore;
      WriteLn('');
      WriteLn('OpenSSL libraries unloaded.');
    end
    else
    begin
      WriteLn('FAILED: Could not load OpenSSL libraries.');
      WriteLn('Make sure OpenSSL is installed and DLLs are in PATH.');
      WriteLn('');
      WriteLn('On Windows, you need:');
      WriteLn('  - libcrypto-1_1-x64.dll (or libcrypto-3-x64.dll for OpenSSL 3.x)');
      WriteLn('  - libssl-1_1-x64.dll (or libssl-3-x64.dll for OpenSSL 3.x)');
      WriteLn('');
      WriteLn('You can download OpenSSL from:');
      WriteLn('  https://slproweb.com/products/Win32OpenSSL.html');
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
    end;
  end;
  
  WriteLn('');
  WriteLn('Test completed.');
end.