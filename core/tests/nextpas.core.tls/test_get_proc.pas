program test_get_proc;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.dl,
  nextpas.core.tls.openssl.api.core;

var
  LProc1, LProc2: Pointer;
  LHandle: TPlatformLibrary;

begin
  LoadOpenSSLCore();
  WriteLn('Loaded OpenSSL');
  WriteLn;

  WriteLn('Method 1: TPlatformLibrary.Sym');
  LHandle := GetCryptoLibHandle;
  if LHandle.IsValid then
    LHandle.Sym(PAnsiChar('RAND_bytes'), LProc1)
  else
    LProc1 := nil;
  WriteLn('  Result: ', PtrUInt(LProc1));
  WriteLn;

  WriteLn('Method 2: GetCryptoProcAddress');
  LProc2 := GetCryptoProcAddress('RAND_bytes');
  WriteLn('  Result: ', PtrUInt(LProc2));
  WriteLn;

  if LProc1 = LProc2 then
    WriteLn('✓ Both methods work')
  else
    WriteLn('✗ Methods differ!');
end.