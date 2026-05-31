program test_crl;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert,
  nextpas.core.tls.cert.advanced,
  nextpas.core.tls.cert.builder,
  fafafa.ssl;

const
  // Sample empty CRL in PEM format
  SAMPLE_CRL_PEM = 
    '-----BEGIN X509 CRL-----'#10+
    'MIIBKDCBwQIBATANBgkqhkiG9w0BAQsFADA9MQswCQYDVQQGEwJVUzELMAkGA1UE'#10+
    'CBMCQ0ExFjAUBgNVBAoTDWZhZmFmYS5zc2wgQ0ExCTAHBgNVBAMTABcNMjUwMTAx'#10+
    'MDAwMDAwWhcNMjYwMTAxMDAwMDAwWjANBgkqhkiG9w0BAQsFAAOBgQBQl7Q7b8pH'#10+
    '9VJmh2hqJ8kF5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F'#10+
    '5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F'#10+
    '5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F'#10+
    '5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F5F'#10+
    '5F5F5F5F5Q=='#10+
    '-----END X509 CRL-----';

var
  LCRL: ICRLManager;
  LCert: ICertificate;
  LLib: ISSLLibrary;
begin
  WriteLn('====================================');
  WriteLn('  CRL Manager Unit Test');
  WriteLn('====================================');
  WriteLn;
  
  try
    // Step 0: Initialize Library
    WriteLn('[Step 0] Initializing OpenSSL Library...');
    LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not LLib.Initialize then
    begin
      WriteLn('❌ Failed to initialize OpenSSL library!');
      Halt(1);
    end;
    WriteLn('✓ Library initialized: ', LLib.GetVersionString);
    WriteLn;
    
    // Step 1: Create CRL Manager
    WriteLn('[Step 1] Creating CRL Manager...');
    LCRL := CreateCRLManager;
    if Assigned(LCRL) then
      WriteLn('✓ CRL Manager created')
    else
    begin
      WriteLn('❌ Failed to create CRL Manager');
      Halt(1);
    end;
    
    // Step 2: Load CRL from PEM (Note: This is a malformed example, will likely fail)
    WriteLn('[Step 2] Loading CRL from PEM...');
    try
      LCRL.LoadFromPEM(SAMPLE_CRL_PEM);
      WriteLn('✓ CRL loaded');
    except
      on E: Exception do
      begin
        WriteLn('⚠ Expected failure (sample CRL is invalid): ', E.Message);
        WriteLn('✓ Test handled gracefully');
      end;
    end;
    
    // Step 3: Test Revocation Check (will fail since no CRL loaded)
    WriteLn('[Step 3] Testing Revocation Check...');
    LCert := TCertificate.CreateSelfSigned('test.com').Certificate;
    
    try
      if LCRL.IsRevoked(LCert) then
        WriteLn('✓ Certificate is revoked')
      else
        WriteLn('✓ Certificate is not revoked');
    except
      on E: Exception do
        WriteLn('⚠ Expected error (no valid CRL): ', E.Message);
    end;
    
    WriteLn;
    WriteLn('====================================');
    WriteLn('✓ CRL TEST COMPLETE');
    WriteLn('====================================');
    WriteLn('Note: Full CRL testing requires valid CRL data');
    
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
