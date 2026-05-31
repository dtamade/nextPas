program test_get_proc;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core;

var
  LProc1, LProc2: Pointer;

begin
  LoadOpenSSLCore();
  WriteLn('Loaded OpenSSL');
  WriteLn;
  
  WriteLn('Method 1: GetProcAddress');
  LProc1 := GetProcAddress(GetCryptoLibHandle, 'RAND_bytes');
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
