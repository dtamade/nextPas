program test_handle;

{$mode objfpc}{$H+}

uses
  nextpas.core.system.sysutils,
  nextpas.core.platform.dl,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

var
  LProc: Pointer;
  LHandle: TPlatformLibrary;

begin
  WriteLn('Before loading');
  WriteLn('TOpenSSLLoader.IsModuleLoaded(osmCore): ', TOpenSSLLoader.IsModuleLoaded(osmCore));
  LHandle := GetCryptoLibHandle;
  WriteLn('GetCryptoLibHandle valid: ', LHandle.IsValid);
  WriteLn;

  LoadOpenSSLCore();
  WriteLn('After loading');
  WriteLn('TOpenSSLLoader.IsModuleLoaded(osmCore): ', TOpenSSLLoader.IsModuleLoaded(osmCore));
  LHandle := GetCryptoLibHandle;
  WriteLn('GetCryptoLibHandle valid: ', LHandle.IsValid);
  WriteLn;

  if LHandle.IsValid then
  begin
    WriteLn('✓ Handle OK');

    // 尝试加载RAND_bytes
    if LHandle.Sym(PAnsiChar('RAND_bytes'), LProc) = 0 then
      WriteLn('RAND_bytes proc: ', PtrUInt(LProc))
    else
      WriteLn('RAND_bytes proc: not found');
  end
  else
    WriteLn('✗ Handle is NULL!');
end.