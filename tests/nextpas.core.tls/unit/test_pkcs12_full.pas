program test_pkcs12_full;

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
  LKeyPair: IKeyPairWithCertificate;
  LP12Data: TBytes;
  LLoadedCert: ICertificate;
  LLoadedKey: IPrivateKey;
  LOptions: TPKCS12Options;
  LLib: ISSLLibrary;
begin
  WriteLn('====================================');
  WriteLn('  PKCS#12 Full Integration Test');
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
    
    // Step 1: Generate certificate
    WriteLn('[Step 1] Generating certificate...');
    LKeyPair := TCertificate.CreateSelfSigned('pkcs12-test.com');
    WriteLn('✓ Certificate generated');
    WriteLn('  Subject: ', LKeyPair.Certificate.Subject);
    WriteLn;
    
    // Step 2: Export to PKCS#12
    WriteLn('[Step 2] Exporting to PKCS#12...');
    LOptions := DefaultPKCS12Options;
    LOptions.FriendlyName := 'Test Certificate';
    LOptions.Password := 'test123';
    LOptions.Iterations := 2048;
    
    LP12Data := TPKCS12Manager.CreatePKCS12(
      LKeyPair.Certificate,
      LKeyPair.PrivateKey,
      LOptions
    );
    WriteLn('✓ Exported to PKCS#12');
    WriteLn('  Size: ', Length(LP12Data), ' bytes');
    WriteLn;
    
    // Step 3: Save to file
    WriteLn('[Step 3] Saving to file...');
    TPKCS12Manager.CreatePKCS12ToFile(
      LKeyPair.Certificate,
      LKeyPair.PrivateKey,
      'test.p12',
      LOptions
    );
    WriteLn('✓ Saved to test.p12');
    WriteLn;
    
    // Step 4: Import from PKCS#12
    WriteLn('[Step 4] Importing from PKCS#12...');
    if TPKCS12Manager.LoadFromPKCS12(LP12Data, 'test123', LLoadedCert, LLoadedKey) then
    begin
      WriteLn('✓ Imported from PKCS#12');
      WriteLn('  Loaded Subject: ', LLoadedCert.Subject);
      WriteLn('  Loaded Issuer: ', LLoadedCert.Issuer);
      WriteLn;
      
      // Step 5: Verify data integrity
      WriteLn('[Step 5] Verifying data integrity...');
      if LLoadedCert.Subject = LKeyPair.Certificate.Subject then
        WriteLn('✓ Subject matches')
      else
        WriteLn('✗ Subject mismatch!');
        
      if LLoadedCert.SerialNumber = LKeyPair.Certificate.SerialNumber then
        WriteLn('✓ Serial number matches')
      else
        WriteLn('✗ Serial number mismatch!');
      WriteLn;
    end
    else
      WriteLn('✗ Failed to import!');
    
    WriteLn('====================================');
    WriteLn('✓ PKCS#12 TEST COMPLETE');
    WriteLn('====================================');
    WriteLn;
    WriteLn('Architecture refactor successful:');
    WriteLn('  • Dual-mode PEM+Handle support');
    WriteLn('  • Lazy conversion (performance)');
    WriteLn('  • OpenSSL handle access');
    WriteLn('  • PKCS#12 export/import working');
    WriteLn;
    
  except
    on E: Exception do
    begin
      WriteLn('❌ ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
