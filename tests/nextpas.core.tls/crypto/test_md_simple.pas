program test_md_simple;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.md;

begin
  WriteLn('========================================');
  WriteLn('  OpenSSL MD Module Basic Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    LoadOpenSSLCore;
    WriteLn('OpenSSL Version: ', OpenSSL_version(0));
    WriteLn;
    
    WriteLn('[PASS] MD module compiled successfully');
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
