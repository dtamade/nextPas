program test_fluent_builder;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.cert.builder;

var
  LKeyPair: IKeyPairWithCertificate;
  LCert: ICertificate;
  LSAN: TStringArray;
  I: Integer;
begin
  WriteLn('====================================');
  WriteLn('  Fluent Builder API Demo');
  WriteLn('====================================');
  WriteLn;
  
  try
    // Test 1: Simple self-signed certificate
    WriteLn('[Test 1] Creating simple self-signed certificate...');
    LKeyPair := TCertificateBuilder.Create
      .WithCommonName('example.com')
      .WithOrganization('Test Inc')
      .ValidFor(365)
      .WithRSAKey(2048)
      .SelfSigned;
    
    WriteLn('✓ Certificate created');
    WriteLn('  Subject: ', LKeyPair.Certificate.Subject);
    WriteLn;
    
    // Test 2: Server certificate with SANs
    WriteLn('[Test 2] Creating server certificate with SANs...');
    LKeyPair := TCertificateBuilder.Create
      .WithCommonName('api.example.com')
      .WithOrganization('Example Corp')
      .WithCountry('US')
      .AddSubjectAltName('api.example.com')
      .AddSubjectAltName('*.api.example.com')
      .AddSubjectAltName('www.example.com')
      .WithECDSAKey('prime256v1')
      .ValidFor(90)
      .SelfSigned;
    
    LCert := LKeyPair.Certificate;
    WriteLn('✓ Server certificate created');
    WriteLn('  Subject: ', LCert.Subject);
    WriteLn('  Issuer: ', LCert.Issuer);
    WriteLn('  Valid until: ', DateTimeToStr(LCert.NotAfter));
    
    LSAN := LCert.GetSubjectAltNames;
    if Length(LSAN) > 0 then
    begin
      WriteLn('  Subject Alt Names:');
      for I := 0 to High(LSAN) do
        WriteLn('    - ', LSAN[I]);
    end;
    WriteLn;
    
    // Test 3: Save to files
    WriteLn('[Test 3] Saving certificate to files...');
    LKeyPair.SaveToFiles('test_server.crt', 'test_server.key');
    WriteLn('✓ Saved to test_server.crt and test_server.key');
    WriteLn;
    
    // Test 4: CA certificate
    WriteLn('[Test 4] Creating CA certificate...');
    LKeyPair := TCertificateBuilder.Create
      .WithCommonName('Test CA')
      .WithOrganization('Test Organization')
      .WithCountry('US')
      .ValidFor(3650)
      .AsCA
      .WithRSAKey(4096)
      .SelfSigned;
    
    WriteLn('✓ CA certificate created');
    WriteLn('  Subject: ', LKeyPair.Certificate.Subject);
    WriteLn('  Is CA: ', LKeyPair.Certificate.IsCA);
    WriteLn;
    
    WriteLn('====================================');
    WriteLn('✓ ALL TESTS PASSED');
    WriteLn('====================================');
    
  except
    on E: Exception do
    begin
      WriteLn('❌ ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
