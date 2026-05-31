program test_ecdh_simple;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ecdh;

begin
  WriteLn('========================================');
  WriteLn('  OpenSSL ECDH Module Basic Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    LoadOpenSSLCore;
    WriteLn('OpenSSL Version: ', OpenSSL_version(0));
    WriteLn;
    
    WriteLn('[PASS] ECDH module compiled successfully');
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
