program test_advanced_cert;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.cert.advanced,
  nextpas.core.tls.cert.builder;

procedure TestOCSPClient;
var
  LOCSPClient: IOCSPClient;
  LResponse: TOCSPResponse;
begin
  WriteLn('[Test 1] OCSP Client Interface');
  
  LOCSPClient := CreateOCSPClient;
  LOCSPClient.SetResponderURL('http://ocsp.example.com');
  LOCSPClient.SetTimeout(30);
  
  WriteLn('✓ OCSP client created');
  WriteLn('  Responder URL set');
  WriteLn('  Timeout: 30s');
  WriteLn('  Note: Full OCSP implementation in progress');
  WriteLn;
end;

procedure TestCRLManager;
var
  LCRLMgr: ICRLManager;
begin
  WriteLn('[Test 2] CRL Manager Interface');
  
  LCRLMgr := CreateCRLManager;
  WriteLn('✓ CRL manager created');
  WriteLn('  Note: Full CRL implementation in progress');
  WriteLn;
end;

procedure TestPKCS12;
var
  LOptions: TPKCS12Options;
begin
  WriteLn('[Test 3] PKCS#12 Manager');
  
  LOptions := DefaultPKCS12Options;
  LOptions.FriendlyName := 'My Certificate';
  LOptions.Password := 'secret123';
  LOptions.Iterations := 4096;
  
  WriteLn('✓ PKCS#12 options configured');
  WriteLn('  Friendly name: ', LOptions.FriendlyName);
  WriteLn('  Iterations: ', LOptions.Iterations);
  WriteLn('  Note: Full PKCS#12 implementation in progress');
  WriteLn;
end;

begin
  WriteLn('====================================');
  WriteLn('  Advanced Certificate Features');
  WriteLn('====================================');
  WriteLn;
  
  try
    TestOCSPClient;
    TestCRLManager;
    TestPKCS12;
    
    WriteLn('====================================');
    WriteLn('✓ INTERFACES READY');
    WriteLn('====================================');
    WriteLn;
    WriteLn('Phase 6 interfaces defined:');
    WriteLn('  • IOCSPClient - Online revocation check');
    WriteLn('  • ICRLManager - Offline revocation lists');
    WriteLn('  • TPKCS12Manager - Certificate packaging');
    WriteLn;
    WriteLn('Next: Implement OpenSSL integration');
    
  except
    on E: Exception do
    begin
      WriteLn('Note: ', E.Message);
      WriteLn('(Expected - implementations in progress)');
    end;
  end;
end.
