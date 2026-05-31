program test_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

begin
  WriteLn('Simple OpenSSL Load Test');
  WriteLn('========================');
  WriteLn;
  
  try
    WriteLn('Calling LoadOpenSSLCore...');
    LoadOpenSSLCore;
    
    WriteLn('Checking if loaded...');
    if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('[SUCCESS] OpenSSL loaded successfully!');
      WriteLn('Crypto handle: ', PtrInt(GetCryptoLibHandle));
      WriteLn('SSL handle: ', PtrInt(GetSSLLibHandle));
      WriteLn('Version: ', GetOpenSSLVersionString);
    end
    else
    begin
      WriteLn('[FAILED] OpenSSL not loaded');
    end;
  except
    on E: Exception do
    begin
      WriteLn('[EXCEPTION] ', E.ClassName, ': ', E.Message);
    end;
  end;
  
  WriteLn;
  WriteLn('Test complete.');
end.
