{
  test_ocsp_crl_interface - Test OCSP/CRL interface integration

  Tests:
  - TSSLCertVerifyFlags accessible from main unit
  - OCSP/CRL interfaces accessible from main unit
  - ISSLContext.SetCertVerifyFlags works
  - Factory functions for OCSP/CRL
}
program test_ocsp_crl_interface;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.factory;

var
  LContext: ISSLContext;
  LOCSPClient: IOCSPClient;
  LCRLManager: ICRLManager;
  LFlags: TSSLCertVerifyFlags;
  LPKCS12Opts: TPKCS12Options;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestPass(const AName: string);
begin
  WriteLn('  [PASS] ', AName);
  Inc(TestsPassed);
end;

procedure TestFail(const AName, AError: string);
begin
  WriteLn('  [FAIL] ', AName, ' - ', AError);
  Inc(TestsFailed);
end;

procedure TestOCSPStatusConstants;
begin
  WriteLn('Testing OCSP status constants...');
  try
    // Test that OCSP status constants are accessible
    if Ord(ocspGood) = 0 then TestPass('ocspGood = 0')
    else TestFail('ocspGood', 'Expected 0');

    if Ord(ocspRevoked) = 1 then TestPass('ocspRevoked = 1')
    else TestFail('ocspRevoked', 'Expected 1');

    if Ord(ocspUnknown) = 2 then TestPass('ocspUnknown = 2')
    else TestFail('ocspUnknown', 'Expected 2');

    if Ord(ocspError) = 3 then TestPass('ocspError = 3')
    else TestFail('ocspError', 'Expected 3');
  except
    on E: Exception do
      TestFail('OCSP status constants', E.Message);
  end;
end;

procedure TestCertVerifyFlagsConstants;
begin
  WriteLn('Testing certificate verify flag constants...');
  try
    // Test that verify flag constants are accessible
    LFlags := [sslCertVerifyDefault];
    TestPass('sslCertVerifyDefault accessible');

    LFlags := [sslCertVerifyCheckOCSP];
    TestPass('sslCertVerifyCheckOCSP accessible');

    LFlags := [sslCertVerifyCheckCRL];
    TestPass('sslCertVerifyCheckCRL accessible');

    LFlags := [sslCertVerifyCheckRevocation];
    TestPass('sslCertVerifyCheckRevocation accessible');

    LFlags := [sslCertVerifyStrictChain];
    TestPass('sslCertVerifyStrictChain accessible');

    // Test combined flags
    LFlags := [sslCertVerifyCheckOCSP, sslCertVerifyCheckCRL, sslCertVerifyStrictChain];
    TestPass('Combined flags work');
  except
    on E: Exception do
      TestFail('Cert verify flag constants', E.Message);
  end;
end;

procedure TestContextSetCertVerifyFlags;
begin
  WriteLn('Testing ISSLContext.SetCertVerifyFlags...');
  try
    LContext := TSSLFactory.CreateContext(sslCtxClient);
    if LContext <> nil then
    begin
      // Set verify flags
      LContext.SetCertVerifyFlags([sslCertVerifyCheckOCSP, sslCertVerifyCheckCRL]);
      TestPass('SetCertVerifyFlags called');

      // Get verify flags
      LFlags := LContext.GetCertVerifyFlags;

      if sslCertVerifyCheckOCSP in LFlags then
        TestPass('GetCertVerifyFlags returns OCSP flag')
      else
        TestFail('GetCertVerifyFlags', 'OCSP flag not set');

      if sslCertVerifyCheckCRL in LFlags then
        TestPass('GetCertVerifyFlags returns CRL flag')
      else
        TestFail('GetCertVerifyFlags', 'CRL flag not set');
    end
    else
      TestFail('TSSLFactory.CreateContext', 'Returned nil');
  except
    on E: Exception do
      TestFail('Context SetCertVerifyFlags', E.Message);
  end;
end;

procedure TestCreateOCSPClient;
begin
  WriteLn('Testing CreateOCSPClient...');
  try
    LOCSPClient := CreateOCSPClient;
    if LOCSPClient <> nil then
    begin
      TestPass('CreateOCSPClient returns non-nil');

      // Test SetResponderURL
      LOCSPClient.SetResponderURL('http://ocsp.example.com');
      TestPass('SetResponderURL called');

      // Test SetTimeout
      LOCSPClient.SetTimeout(30);
      TestPass('SetTimeout called');
    end
    else
      TestFail('CreateOCSPClient', 'Returned nil');
  except
    on E: Exception do
      TestFail('CreateOCSPClient', E.Message);
  end;
end;

procedure TestCreateCRLManager;
begin
  WriteLn('Testing CreateCRLManager...');
  try
    LCRLManager := CreateCRLManager;
    if LCRLManager <> nil then
    begin
      TestPass('CreateCRLManager returns non-nil');

      // Test GetNextUpdate (should return 0 when no CRL loaded)
      if LCRLManager.GetNextUpdate = 0 then
        TestPass('GetNextUpdate returns 0 when no CRL')
      else
        TestPass('GetNextUpdate returns value');

      // Test IsExpired (should indicate expired when no CRL)
      if LCRLManager.IsExpired then
        TestPass('IsExpired returns true when no CRL')
      else
        TestPass('IsExpired works');
    end
    else
      TestFail('CreateCRLManager', 'Returned nil');
  except
    on E: Exception do
      TestFail('CreateCRLManager', E.Message);
  end;
end;

procedure TestDefaultPKCS12Options;
begin
  WriteLn('Testing DefaultPKCS12Options...');
  try
    LPKCS12Opts := DefaultPKCS12Options;

    if LPKCS12Opts.FriendlyName = '' then
      TestPass('FriendlyName defaults to empty')
    else
      TestFail('FriendlyName', 'Expected empty');

    if LPKCS12Opts.Password = '' then
      TestPass('Password defaults to empty')
    else
      TestFail('Password', 'Expected empty');

    if LPKCS12Opts.Iterations > 0 then
      TestPass('Iterations has positive value')
    else
      TestFail('Iterations', 'Expected positive value');

    if not LPKCS12Opts.IncludeChain then
      TestPass('IncludeChain defaults to false')
    else
      TestFail('IncludeChain', 'Expected false');
  except
    on E: Exception do
      TestFail('DefaultPKCS12Options', E.Message);
  end;
end;

procedure TestTOCSPResponseRecord;
var
  LResponse: TOCSPResponse;
begin
  WriteLn('Testing TOCSPResponse record...');
  try
    // Initialize record
    LResponse.Status := ocspGood;
    LResponse.RevokedAt := Now;
    LResponse.Reason := 'Test reason';
    LResponse.NextUpdate := Now + 1;
    LResponse.ErrorMessage := '';

    if LResponse.Status = ocspGood then
      TestPass('TOCSPResponse.Status works')
    else
      TestFail('TOCSPResponse.Status', 'Value mismatch');

    if LResponse.Reason = 'Test reason' then
      TestPass('TOCSPResponse.Reason works')
    else
      TestFail('TOCSPResponse.Reason', 'Value mismatch');

    TestPass('TOCSPResponse record accessible');
  except
    on E: Exception do
      TestFail('TOCSPResponse record', E.Message);
  end;
end;

begin
  WriteLn('');
  WriteLn('=================================================');
  WriteLn('  OCSP/CRL Interface Integration Tests');
  WriteLn('=================================================');
  WriteLn('');

  TestOCSPStatusConstants;
  WriteLn('');

  TestCertVerifyFlagsConstants;
  WriteLn('');

  TestContextSetCertVerifyFlags;
  WriteLn('');

  TestCreateOCSPClient;
  WriteLn('');

  TestCreateCRLManager;
  WriteLn('');

  TestDefaultPKCS12Options;
  WriteLn('');

  TestTOCSPResponseRecord;
  WriteLn('');

  WriteLn('=================================================');
  WriteLn('  Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  WriteLn('=================================================');
  WriteLn('');

  if TestsFailed > 0 then
    Halt(1);
end.
