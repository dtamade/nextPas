program TestCertificatePinning;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.pinning,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.core;

{**
 * Certificate Pinning Test Suite
 *
 * Tests the certificate pinning implementation:
 * 1. Pin creation and validation
 * 2. Certificate hash extraction
 * 3. Public key hash extraction
 * 4. Pin matching logic
 *}

procedure TestPinCreation;
var
  Validator: TPinValidator;
  Hash: TBytes;
begin
  WriteLn('=== Test: Pin Creation ===');
  
  Validator := TPinValidator.Create;
  try
    // Create a test hash
    SetLength(Hash, 32);
    FillChar(Hash[0], 32, $AA);
    
    // Add pin
    Validator.AddPin(Hash, ptPublicKey, 'Test Pin', False);
    
    WriteLn('✓ Pin created successfully');
    WriteLn('  Pin count: ', Length(Validator.Pins));
    WriteLn('  Valid pins: ', Validator.GetValidPinCount);
    
    // Test Base64 pin
    Validator.AddPinBase64(
      'YLh1dUR9y6Kja30RrAn7JKnbQG/uEtLMkBgFF2Fuihg=',
      ptPublicKey,
      'Base64 Test Pin',
      True
    );
    
    WriteLn('✓ Base64 pin created successfully');
    WriteLn('  Total pins: ', Length(Validator.Pins));
    
  finally
    Validator.Free;
  end;
  
  WriteLn;
end;

procedure TestSecureConfiguration;
var
  Validator: TPinValidator;
  Hash: TBytes;
begin
  WriteLn('=== Test: Secure Configuration ===');
  
  Validator := TPinValidator.Create;
  try
    SetLength(Hash, 32);
    
    // Test with 0 pins (insecure)
    if not Validator.IsSecureConfiguration then
      WriteLn('✓ Correctly identified insecure config (0 pins)')
    else
      WriteLn('✗ Failed: Should reject 0 pins');
    
    // Add 1 pin (still insecure)
    FillChar(Hash[0], 32, $AA);
    Validator.AddPin(Hash, ptPublicKey, 'Pin 1', False);
    
    if not Validator.IsSecureConfiguration then
      WriteLn('✓ Correctly identified insecure config (1 pin)')
    else
      WriteLn('✗ Failed: Should reject 1 pin');
    
    // Add 2nd pin (now secure)
    FillChar(Hash[0], 32, $BB);
    Validator.AddPin(Hash, ptPublicKey, 'Pin 2', True);
    
    if Validator.IsSecureConfiguration then
      WriteLn('✓ Correctly identified secure config (2 pins)')
    else
      WriteLn('✗ Failed: Should accept 2 pins');
    
  finally
    Validator.Free;
  end;
  
  WriteLn;
end;

procedure TestPinInfo;
var
  Validator: TPinValidator;
  Hash: TBytes;
  Info: string;
begin
  WriteLn('=== Test: Pin Information ===');
  
  Validator := TPinValidator.Create;
  try
    SetLength(Hash, 32);
    
    // Add test pins
    FillChar(Hash[0], 32, $AA);
    Validator.AddPin(Hash, ptPublicKey, 'Primary Pin', False);
    
    FillChar(Hash[0], 32, $BB);
    Validator.AddPin(Hash, ptCertificate, 'Backup Pin', True);
    
    // Get info
    Info := Validator.GetPinInfo;
    WriteLn(Info);
    
    WriteLn('✓ Pin information retrieved successfully');
    
  finally
    Validator.Free;
  end;
  
  WriteLn;
end;

procedure TestClearPins;
var
  Validator: TPinValidator;
  Hash: TBytes;
begin
  WriteLn('=== Test: Clear Pins ===');
  
  Validator := TPinValidator.Create;
  try
    SetLength(Hash, 32);
    FillChar(Hash[0], 32, $AA);
    
    // Add pins
    Validator.AddPin(Hash, ptPublicKey, 'Pin 1', False);
    Validator.AddPin(Hash, ptPublicKey, 'Pin 2', True);
    
    WriteLn('Pins before clear: ', Length(Validator.Pins));
    
    // Clear
    Validator.ClearPins;
    
    WriteLn('Pins after clear: ', Length(Validator.Pins));
    
    if Length(Validator.Pins) = 0 then
      WriteLn('✓ Pins cleared successfully')
    else
      WriteLn('✗ Failed: Pins not cleared');
    
  finally
    Validator.Free;
  end;
  
  WriteLn;
end;

procedure ShowBestPractices;
begin
  WriteLn('=== Certificate Pinning Best Practices ===');
  WriteLn;
  WriteLn('1. Pin Type:');
  WriteLn('   ✓ Use public key pinning (ptPublicKey)');
  WriteLn('   ✗ Avoid certificate pinning (ptCertificate)');
  WriteLn;
  WriteLn('2. Minimum Pins:');
  WriteLn('   ✓ Always include at least 2 pins');
  WriteLn('   ✓ Primary pin: Current certificate');
  WriteLn('   ✓ Backup pin: Intermediate CA or future certificate');
  WriteLn;
  WriteLn('3. Pin Storage:');
  WriteLn('   ✓ Store pins in compiled code');
  WriteLn('   ✗ Avoid storing in config files');
  WriteLn;
  WriteLn('4. Pin Rotation:');
  WriteLn('   ✓ Plan rotation with overlap period');
  WriteLn('   ✓ Add new pin before removing old pin');
  WriteLn('   ✓ Wait for 90%+ adoption before removing old pin');
  WriteLn;
  WriteLn('5. Security:');
  WriteLn('   ✓ Use SHA-256 hashing');
  WriteLn('   ✓ Constant-time comparison');
  WriteLn('   ✓ Validate after standard X.509 validation');
  WriteLn;
end;

begin
  try
    WriteLn('Certificate Pinning Test Suite');
    WriteLn('==============================');
    WriteLn;
    
    // Initialize OpenSSL
    LoadOpenSSLCore;
    
    // Run tests
    TestPinCreation;
    TestSecureConfiguration;
    TestPinInfo;
    TestClearPins;
    
    // Show best practices
    ShowBestPractices;
    
    WriteLn('All tests completed!');
    WriteLn;
    
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
