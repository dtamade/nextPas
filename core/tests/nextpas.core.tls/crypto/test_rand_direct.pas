program test_rand_direct;

{$mode objfpc}{$H+}

uses
  SysUtils, DynLibs,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api;

type
  TRAND_bytes = function(buf: PByte; num: Integer): Integer; cdecl;

var
  LLib: TLibHandle;
  LRAND_bytes: TRAND_bytes;
  LBuf: array[0..31] of Byte;
  
begin
  WriteLn('=== Direct RAND_bytes Test ===');
  WriteLn;
  
  LoadOpenSSLCore();
  WriteLn('Core loaded');
  
  LLib := GetCryptoLibHandle;
  WriteLn('Library handle: ', LLib);
  
  LRAND_bytes := TRAND_bytes(GetProcAddress(LLib, 'RAND_bytes'));
  WriteLn('RAND_bytes assigned: ', Assigned(LRAND_bytes));
  
  if Assigned(LRAND_bytes) then
  begin
    WriteLn('Calling RAND_bytes...');
    if LRAND_bytes(@LBuf[0], 32) = 1 then
      WriteLn('✓ SUCCESS!')
    else
      WriteLn('✗ FAILED');
  end;
end.
