program test_provider;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.provider;

procedure TestProviderAvailability;
begin
  WriteLn('Testing Provider Availability...');
  WriteLn;
  
  // Test default provider
  if IsProviderAvailable('default') then
    WriteLn('  [+] default provider: Available')
  else
    WriteLn('  [-] default provider: NOT Available');
  
  // Test base provider
  if IsProviderAvailable('base') then
    WriteLn('  [+] base provider: Available')
  else
    WriteLn('  [-] base provider: NOT Available');
  
  // Test legacy provider
  if IsProviderAvailable('legacy') then
    WriteLn('  [+] legacy provider: Available')
  else
    WriteLn('  [-] legacy provider: NOT Available');
  
  // Test FIPS provider
  if IsProviderAvailable('fips') then
    WriteLn('  [+] fips provider: Available')
  else
    WriteLn('  [-] fips provider: NOT Available (expected in standard builds)');
  
  WriteLn;
end;

procedure TestProviderLoad;
var
  Provider: POSSL_PROVIDER;
  ProviderName: string;
begin
  WriteLn('Testing Provider Load...');
  WriteLn;
  
  // Try to load default provider
  Provider := LoadProvider('default');
  if Assigned(Provider) then
  begin
    ProviderName := GetProviderName(Provider);
    WriteLn('  [+] Successfully loaded provider: ', ProviderName);
    
    // Unload
    if UnloadProvider(Provider) then
      WriteLn('  [+] Successfully unloaded provider')
    else
      WriteLn('  [-] Failed to unload provider');
  end
  else
    WriteLn('  [-] Failed to load default provider');
  
  WriteLn;
end;

procedure TestLibraryContext;
var
  LibCtx: POSSL_LIB_CTX;
begin
  WriteLn('Testing Library Context...');
  WriteLn;
  
  // Create new library context
  LibCtx := CreateLibraryContext;
  if Assigned(LibCtx) then
  begin
    WriteLn('  [+] Successfully created library context');
    
    // Free context
    FreeLibraryContext(LibCtx);
    if not Assigned(LibCtx) then
      WriteLn('  [+] Successfully freed library context')
    else
      WriteLn('  [-] Context not properly freed');
  end
  else
    WriteLn('  [-] Failed to create library context');
  
  WriteLn;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Provider API Test');
  WriteLn('========================================');
  WriteLn;
  
  // Initialize OpenSSL
  try
    LoadOpenSSLCore;
    LoadProviderModule(GetCryptoLibHandle);
  except
    on E: Exception do
    begin
      WriteLn('ERROR: Failed to load OpenSSL library!');
      WriteLn('Message: ', E.Message);
      WriteLn('Make sure OpenSSL 1.1.x or 3.x is installed and accessible.');
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL loaded successfully!');
  WriteLn();
  
  // Run tests
  TestProviderAvailability;
  TestProviderLoad;
  TestLibraryContext;
  
  WriteLn('========================================');
  WriteLn('Provider API tests completed!');
  WriteLn('========================================');
  WriteLn;
  
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
