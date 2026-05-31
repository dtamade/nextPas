program test_load_modules;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rand;

var
  LBuf: array[0..31] of Byte;

begin
  WriteLn('=== Module Loading Test ===');
  WriteLn;
  
  WriteLn('[1] Loading Core...');
  LoadOpenSSLCore();
  WriteLn('  Core loaded: ', TOpenSSLLoader.IsModuleLoaded(osmCore));
  WriteLn;
  
  WriteLn('[2] Loading EVP...');
  LoadEVP(GetCryptoLibHandle);
  WriteLn('  EVP loaded: True');
  WriteLn('  EVP_aes_256_gcm assigned: ', Assigned(EVP_aes_256_gcm));
  WriteLn;
  
  WriteLn('[3] Loading RAND...');
  if LoadOpenSSLRAND() then
    WriteLn('  RAND loaded: True')
  else
    WriteLn('  RAND loaded: False');
  WriteLn('  RAND_bytes assigned: ', Assigned(RAND_bytes));
  WriteLn;
  
  if Assigned(RAND_bytes) then
  begin
    WriteLn('[4] Testing RAND_bytes...');
    if RAND_bytes(@LBuf[0], 32) = 1 then
      WriteLn('  ✓ RAND_bytes works!')
    else
      WriteLn('  ✗ RAND_bytes failed');
  end;
end.
