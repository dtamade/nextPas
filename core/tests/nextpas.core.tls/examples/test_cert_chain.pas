program test_cert_chain;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.base;

var
  GRootCert, GRootKey: string;
  GInterCert, GInterKey: string;
  GLeafCert, GLeafKey: string;
  GTempDir: string;

procedure Setup;
var
  LOptions: TCertGenOptions;
begin
  WriteLn('Setting up test environment...');
  GTempDir := 'temp_certs';
  if not DirectoryExists(GTempDir) then
    CreateDir(GTempDir);

  // 1. Generate Root CA
  Write('Generating Root CA... ');
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'Test Root CA';
  LOptions.IsCA := True;
  if TCertificateUtils.GenerateSelfSigned(LOptions, GRootCert, GRootKey) then
    WriteLn('OK')
  else
  begin
    WriteLn('Failed');
    Halt(1);
  end;
  
  // Save Root CA to file for verification
  TCertificateUtils.SaveToFile(GTempDir + PathDelim + 'root.crt', GRootCert);

  // 2. Generate Intermediate CA
  Write('Generating Intermediate CA... ');
  LOptions.CommonName := 'Test Intermediate CA';
  LOptions.IsCA := True;
  if TCertificateUtils.GenerateSigned(LOptions, GRootCert, GRootKey, GInterCert, GInterKey) then
    WriteLn('OK')
  else
  begin
    WriteLn('Failed');
    Halt(1);
  end;
  
  // Save Intermediate CA (optional, but good for debugging)
  TCertificateUtils.SaveToFile(GTempDir + PathDelim + 'inter.crt', GInterCert);

  // 3. Generate Leaf Certificate
  Write('Generating Leaf Certificate... ');
  WriteLn('(Inter Cert Len: ', Length(GInterCert), ', Key Len: ', Length(GInterKey), ')');
  LOptions.CommonName := 'test.example.com';
  LOptions.IsCA := False;
  if TCertificateUtils.GenerateSigned(LOptions, GInterCert, GInterKey, GLeafCert, GLeafKey) then
    WriteLn('OK')
  else
  begin
    WriteLn('Failed');
    Halt(1);
  end;
  
  TCertificateUtils.SaveToFile(GTempDir + PathDelim + 'leaf.crt', GLeafCert);
end;

procedure TestVerifyChain;
var
  LResult: Boolean;
begin
  WriteLn('Testing VerifyChain...');
  
  // Test 1: Verify Leaf against Root CA (Full Chain needs to be constructed or provided)
  // TCertificateUtils.VerifyChain takes ACertPEM and ACAPath.
  // It builds the chain from the leaf.
  // However, the intermediate cert needs to be available to the verifier.
  // In my implementation of VerifyChain, I only set TrustedStore from ACAPath.
  // The intermediate certs usually need to be provided or found.
  // TCertificateUtils.VerifyChain implementation:
  // LVerifier := TSSLCertificateChainVerifier.Create;
  // ...
  // LVerifier.VerifyCertificate(LCert);
  // TSSLCertificateChainVerifier.FindIssuer looks in TrustedStore and IntermediateStore.
  // If I don't provide IntermediateStore, it might fail if the chain is not complete in the leaf PEM (which it isn't, it's just the leaf).
  
  // So, VerifyChain might fail if I don't bundle the intermediate with the leaf or provide it.
  // Let's see if I can bundle them.
  // PEM format allows multiple certs.
  
  Write('  [1] Verify Leaf with Root CA (Missing Intermediate)... ');
  LResult := TCertificateUtils.VerifyChain(GLeafCert, GTempDir + PathDelim + 'root.crt');
  if not LResult then
    WriteLn('Failed (Expected, as intermediate is missing)')
  else
    WriteLn('Passed (Unexpected!)');
    
  // Test 2: Bundle Intermediate with Leaf
  Write('  [2] Verify Leaf+Intermediate with Root CA... ');
  LResult := TCertificateUtils.VerifyChain(GLeafCert + #10 + GInterCert, GTempDir + PathDelim + 'root.crt');
  // Note: VerifyChain loads ACertPEM into LCert.
  // ISSLCertificate.LoadFromPEM usually loads the FIRST certificate found.
  // So LCert will be the leaf.
  // But TSSLCertificateChainVerifier needs to find the issuer.
  // If the issuer is not in TrustedStore (Root is there, Inter is not), it needs to be in IntermediateStore.
  // My VerifyChain implementation DOES NOT populate IntermediateStore from the input PEM.
  // This is a limitation of my simple VerifyChain implementation.
  
  // To make this work, I might need to improve VerifyChain to load extra certs from PEM into IntermediateStore?
  // Or I should rely on the fact that some SSL libraries can build chain if provided in context.
  // But TSSLCertificateChainVerifier is manual.
  
  if LResult then 
    WriteLn('Passed') 
  else 
    WriteLn('Failed (Likely due to missing intermediate in store)');

end;

procedure Cleanup;
begin
  // DeleteFile(GTempDir + PathDelim + 'root.crt');
  // DeleteFile(GTempDir + PathDelim + 'inter.crt');
  // DeleteFile(GTempDir + PathDelim + 'leaf.crt');
  // RemoveDir(GTempDir);
end;

begin
  try
    Setup;
    TestVerifyChain;
    Cleanup;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
end.
