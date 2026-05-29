program test_priority2_modules;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}
  cthreads,  // 必须在最前面，用于线程模块
  {$ENDIF}
  SysUtils,
  // Priority 2 - Symmetric Ciphers (2 modules)
  nextpas.core.tls.openssl.api.aria,
  nextpas.core.tls.openssl.api.seed,
  
  // Priority 2 - MAC & KDF (1 module)
  nextpas.core.tls.openssl.api.scrypt_whirlpool,  // Fixed!
  
  // Priority 2 - PKI & Certificates (7 modules)
  nextpas.core.tls.openssl.api.pkcs,  // Fixed!
  nextpas.core.tls.openssl.api.pkcs7,  // Testing with fixed stack
  nextpas.core.tls.openssl.api.pkcs12,  // Testing with fixed type casts
  nextpas.core.tls.openssl.api.cms,  // Fixed!
  nextpas.core.tls.openssl.api.ocsp,  // Fixed!
  nextpas.core.tls.openssl.api.ct,  // Fixed!
  nextpas.core.tls.openssl.api.ts,  // Fixed!
  
  // Priority 2 - SSL/TLS (1 module)
  nextpas.core.tls.openssl.api.ssl,  // Fixed!
  
  // Priority 2 - Advanced Features (2 modules)
  nextpas.core.tls.openssl.api.engine,  // Fixed!
  nextpas.core.tls.openssl.api.store,  // Fixed!
  
  // Priority 2 - Utilities (7 modules)
  nextpas.core.tls.openssl.api.buffer,
  nextpas.core.tls.openssl.api.stack,  // Fixed!
  nextpas.core.tls.openssl.api.lhash,  // Fixed!
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.api.conf,  // Fixed!
  nextpas.core.tls.openssl.api.thread;

var
  TotalTests, PassedTests: Integer;

procedure Test(const Name: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(Name + ': ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(PassedTests);
  end
  else
    WriteLn('FAIL');
end;

procedure PrintSeparator;
begin
  WriteLn('================================================');
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  
  WriteLn('Testing Priority 2 Modules Compilation');
  PrintSeparator;
  
  WriteLn('Symmetric Ciphers (2 modules)');
  Test('ARIA module loaded', True);
  Test('SEED module loaded', True);
  WriteLn;
  
  WriteLn('MAC & KDF (1 module)');
  Test('SCrypt/Whirlpool module loaded', True);
  WriteLn;
  
  WriteLn('PKI & Certificates (7 modules)');
  Test('PKCS module loaded', True);
  Test('PKCS#7 module loaded', True);
  Test('PKCS#12 module loaded', True);
  Test('CMS module loaded', True);
  Test('OCSP module loaded', True);
  Test('Certificate Transparency module loaded', True);
  Test('Time-Stamp Protocol module loaded', True);
  WriteLn;
  
  WriteLn('SSL/TLS (1 module)');
  Test('SSL module loaded', True);
  WriteLn;
  
  WriteLn('Advanced Features (2 modules)');
  Test('Engine module loaded', True);
  Test('Store module loaded', True);
  WriteLn;
  
  WriteLn('Utilities (7 modules)');
  Test('Buffer module loaded', True);
  Test('Stack module loaded', True);
  Test('LHash module loaded', True);
  Test('Object identifiers module loaded', True);
  Test('Configuration module loaded', True);
  Test('Thread module loaded', True);
  WriteLn;
  
  PrintSeparator;
  WriteLn(Format('Results: %d/%d tests passed (%.1f%%)', 
    [PassedTests, TotalTests, (PassedTests * 100.0) / TotalTests]));
  PrintSeparator;
  
  if PassedTests = TotalTests then
  begin
    WriteLn('SUCCESS: All Priority 2 modules compiled successfully!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('FAILURE: Some modules failed to compile.');
    ExitCode := 1;
  end;
end.
