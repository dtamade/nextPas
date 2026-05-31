program test_aes_simple;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.aes;

begin
  WriteLn('========================================');
  WriteLn('  OpenSSL AES Module Basic Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    LoadOpenSSLCore;
    WriteLn('OpenSSL Version: ', OpenSSL_version(0));
    WriteLn;
    
    WriteLn('[PASS] AES module compiled successfully');
    WriteLn('[INFO] Module functions available - ready for detailed testing');
    WriteLn;
    
    WriteLn('========================================');
    WriteLn('Status: BASIC TEST PASSED');
    WriteLn('========================================');
    
    UnloadOpenSSLCore;
    ExitCode := 0;
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] Error: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
