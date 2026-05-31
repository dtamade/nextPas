program test_handle;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

var
  LProc: Pointer;

begin
  WriteLn('Before loading');
  WriteLn('TOpenSSLLoader.IsModuleLoaded(osmCore): ', TOpenSSLLoader.IsModuleLoaded(osmCore));
  WriteLn('GetCryptoLibHandle: ', GetCryptoLibHandle);
  WriteLn;
  
  LoadOpenSSLCore();
  WriteLn('After loading');
  WriteLn('TOpenSSLLoader.IsModuleLoaded(osmCore): ', TOpenSSLLoader.IsModuleLoaded(osmCore));
  WriteLn('GetCryptoLibHandle: ', GetCryptoLibHandle);
  WriteLn;
  
  if GetCryptoLibHandle <> 0 then
  begin
    WriteLn('✓ Handle OK: ', GetCryptoLibHandle);
    
    // 尝试加载RAND_bytes
    LProc := GetProcAddress(GetCryptoLibHandle, 'RAND_bytes');
    WriteLn('RAND_bytes proc: ', PtrUInt(LProc));
  end
  else
    WriteLn('✗ Handle is NULL!');
end.
