program test_ocsp;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert,
  nextpas.core.tls.cert.advanced,
  nextpas.core.tls.cert.builder,
  fafafa.ssl;

var
  LOCSP: IOCSPClient;
  LCert, LIssuer: ICertificate;
  LResp: TOCSPResponse;
  LLib: ISSLLibrary;
begin
  WriteLn('====================================');
  WriteLn('  OCSP Client Unit Test');
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
    
    // Step 1: Create OCSP Client
    WriteLn('[Step 1] Creating OCSP Client...');
    LOCSP := CreateOCSPClient;
    if Assigned(LOCSP) then
      WriteLn('✓ OCSP Client created')
    else
    begin
      WriteLn('❌ Failed to create OCSP Client');
      Halt(1);
    end;
    
    // Step 2: Test Configuration
    WriteLn('[Step 2] Configuring Client...');
    LOCSP.SetResponderURL('http://ocsp.example.com');
    LOCSP.SetTimeout(5);
    WriteLn('✓ Configuration set');
    
    // Step 3: Test Check (Expected Failure - No Certs)
    WriteLn('[Step 3] Testing Check (Expect Error)...');
    
    // Create dummy self-signed certs for testing
    LCert := TCertificate.CreateSelfSigned('test.com').Certificate;
    LIssuer := TCertificate.CreateSelfSigned('issuer.com').Certificate;
    
    LResp := LOCSP.CheckCertificate(LCert, LIssuer);
    
    if LResp.Status = ocspError then
      WriteLn('✓ Correctly returned Error (Network/Mock)')
    else
      WriteLn('? Returned status: ', Ord(LResp.Status));
      
    WriteLn('  Message: ', LResp.ErrorMessage);
    
    WriteLn;
    WriteLn('====================================');
    WriteLn('✓ OCSP TEST COMPLETE');
    WriteLn('====================================');
    
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
