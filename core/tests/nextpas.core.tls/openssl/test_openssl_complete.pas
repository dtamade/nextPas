program test_openssl_complete;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  fafafa.ssl;

procedure TestOpenSSL;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Store: ISSLCertificateStore;
begin
  WriteLn('========================================');
  WriteLn('OpenSSL Complete Test');
  WriteLn('========================================');
  
  // Test 1: Library Creation
  Write('[Test 1] Creating OpenSSL library... ');
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if Lib = nil then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  
  // Test 2: Initialize
  Write('[Test 2] Initializing... ');
  if not Lib.Initialize then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  WriteLn('  Version: ', Lib.GetVersionString);
  
  // Test 3: Create Context
  Write('[Test 3] Creating client context... ');
  Ctx := Lib.CreateContext(sslCtxClient);
  if Ctx = nil then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  
  // Test 4: Set Protocol Versions
  Write('[Test 4] Setting protocol versions... ');
  Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  WriteLn('OK');
  
  // Test 5: Create Certificate Store
  Write('[Test 5] Creating certificate store... ');
  Store := Lib.CreateCertificateStore;
  if Store = nil then
  begin
    WriteLn('FAILED');
    Halt(1);
  end;
  WriteLn('OK');
  
  // Test 6: Load System Certificates
  Write('[Test 6] Loading system certificates... ');
  if Store.LoadSystemStore then
    WriteLn('OK')
  else
    WriteLn('SKIPPED (may not be available)');
  
  // Test 7: Finalize
  Write('[Test 7] Finalizing... ');
  Lib.Finalize;
  WriteLn('OK');
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('All tests PASSED!');
  WriteLn('========================================');
end;

begin
  try
    TestOpenSSL;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
