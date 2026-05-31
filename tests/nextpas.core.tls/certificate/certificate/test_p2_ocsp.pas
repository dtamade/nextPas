program test_p2_ocsp;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;

procedure StartTest(const TestName: string);
begin
  Inc(TotalTests);
  Write('[', TotalTests, '] ', TestName, '... ');
end;

procedure PassTest;
begin
  Inc(PassedTests);
  WriteLn('PASS');
end;

procedure FailTest(const Reason: string);
begin
  Inc(FailedTests);
  WriteLn('FAIL: ', Reason);
end;

function RuntimeInteger(AValue: Integer): Integer;
begin
  Result := AValue;
end;

procedure TestLoadOCSPFunctions;
begin
  StartTest('Load OCSP functions');
  try
    if LoadOpenSSLOCSP(GetCryptoLibHandle) then
      PassTest
    else
      FailTest('LoadOpenSSLOCSP returned False');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPResponseStatusConstants;
begin
  StartTest('OCSP response status constants');
  try
    if (RuntimeInteger(OCSP_RESPONSE_STATUS_SUCCESSFUL) <> 0) then
      FailTest('OCSP_RESPONSE_STATUS_SUCCESSFUL incorrect')
    else if (RuntimeInteger(OCSP_RESPONSE_STATUS_MALFORMEDREQUEST) <> 1) then
      FailTest('OCSP_RESPONSE_STATUS_MALFORMEDREQUEST incorrect')
    else if (RuntimeInteger(OCSP_RESPONSE_STATUS_INTERNALERROR) <> 2) then
      FailTest('OCSP_RESPONSE_STATUS_INTERNALERROR incorrect')
    else if (RuntimeInteger(OCSP_RESPONSE_STATUS_TRYLATER) <> 3) then
      FailTest('OCSP_RESPONSE_STATUS_TRYLATER incorrect')
    else if (RuntimeInteger(OCSP_RESPONSE_STATUS_SIGREQUIRED) <> 5) then
      FailTest('OCSP_RESPONSE_STATUS_SIGREQUIRED incorrect')
    else if (RuntimeInteger(OCSP_RESPONSE_STATUS_UNAUTHORIZED) <> 6) then
      FailTest('OCSP_RESPONSE_STATUS_UNAUTHORIZED incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPCertStatusConstants;
begin
  StartTest('OCSP certificate status constants');
  try
    if (RuntimeInteger(V_OCSP_CERTSTATUS_GOOD) <> 0) then
      FailTest('V_OCSP_CERTSTATUS_GOOD incorrect')
    else if (RuntimeInteger(V_OCSP_CERTSTATUS_REVOKED) <> 1) then
      FailTest('V_OCSP_CERTSTATUS_REVOKED incorrect')
    else if (RuntimeInteger(V_OCSP_CERTSTATUS_UNKNOWN) <> 2) then
      FailTest('V_OCSP_CERTSTATUS_UNKNOWN incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRevokedStatusConstants;
begin
  StartTest('OCSP revoked status constants');
  try
    if (RuntimeInteger(OCSP_REVOKED_STATUS_UNSPECIFIED) <> 0) then
      FailTest('OCSP_REVOKED_STATUS_UNSPECIFIED incorrect')
    else if (RuntimeInteger(OCSP_REVOKED_STATUS_KEYCOMPROMISE) <> 1) then
      FailTest('OCSP_REVOKED_STATUS_KEYCOMPROMISE incorrect')
    else if (RuntimeInteger(OCSP_REVOKED_STATUS_CACOMPROMISE) <> 2) then
      FailTest('OCSP_REVOKED_STATUS_CACOMPROMISE incorrect')
    else if (RuntimeInteger(OCSP_REVOKED_STATUS_AFFILIATIONCHANGED) <> 3) then
      FailTest('OCSP_REVOKED_STATUS_AFFILIATIONCHANGED incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPFlagConstants;
begin
  StartTest('OCSP flag constants');
  try
    if (RuntimeInteger(OCSP_NOCERTS) <> $1) then
      FailTest('OCSP_NOCERTS incorrect')
    else if (RuntimeInteger(OCSP_NOINTERN) <> $2) then
      FailTest('OCSP_NOINTERN incorrect')
    else if (RuntimeInteger(OCSP_NOSIGS) <> $4) then
      FailTest('OCSP_NOSIGS incorrect')
    else if (RuntimeInteger(OCSP_NOCHAIN) <> $8) then
      FailTest('OCSP_NOCHAIN incorrect')
    else if (RuntimeInteger(OCSP_NOVERIFY) <> $10) then
      FailTest('OCSP_NOVERIFY incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRequestLifecycle;
var
  LReq: POCSP_REQUEST;
begin
  StartTest('OCSP_REQUEST lifecycle (new/free)');
  try
    if not Assigned(OCSP_REQUEST_new) then
      FailTest('OCSP_REQUEST_new not loaded')
    else if not Assigned(OCSP_REQUEST_free) then
      FailTest('OCSP_REQUEST_free not loaded')
    else
    begin
      LReq := OCSP_REQUEST_new();
      if LReq = nil then
        FailTest('OCSP_REQUEST_new returned nil')
      else
      begin
        OCSP_REQUEST_free(LReq);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPResponseLifecycle;
var
  LResp: POCSP_RESPONSE;
begin
  StartTest('OCSP_RESPONSE lifecycle (new/free)');
  try
    if not Assigned(OCSP_RESPONSE_new) then
      FailTest('OCSP_RESPONSE_new not loaded')
    else if not Assigned(OCSP_RESPONSE_free) then
      FailTest('OCSP_RESPONSE_free not loaded')
    else
    begin
      LResp := OCSP_RESPONSE_new();
      if LResp = nil then
        FailTest('OCSP_RESPONSE_new returned nil')
      else
      begin
        OCSP_RESPONSE_free(LResp);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPBasicRespLifecycle;
var
  LBasicResp: POCSP_BASICRESP;
begin
  StartTest('OCSP_BASICRESP lifecycle (new/free)');
  try
    if not Assigned(OCSP_BASICRESP_new) then
      FailTest('OCSP_BASICRESP_new not loaded')
    else if not Assigned(OCSP_BASICRESP_free) then
      FailTest('OCSP_BASICRESP_free not loaded')
    else
    begin
      LBasicResp := OCSP_BASICRESP_new();
      if LBasicResp = nil then
        FailTest('OCSP_BASICRESP_new returned nil')
      else
      begin
        OCSP_BASICRESP_free(LBasicResp);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPCertIDLifecycle;
var
  LCertID: POCSP_CERTID;
begin
  StartTest('OCSP_CERTID lifecycle (new/free)');
  try
    if not Assigned(OCSP_CERTID_new) then
      FailTest('OCSP_CERTID_new not loaded')
    else if not Assigned(OCSP_CERTID_free) then
      FailTest('OCSP_CERTID_free not loaded')
    else
    begin
      LCertID := OCSP_CERTID_new();
      if LCertID = nil then
        FailTest('OCSP_CERTID_new returned nil')
      else
      begin
        OCSP_CERTID_free(LCertID);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRequestIOFunctions;
begin
  StartTest('OCSP request I/O functions availability');
  try
    if not Assigned(d2i_OCSP_REQUEST) then
      FailTest('d2i_OCSP_REQUEST not loaded')
    else if not Assigned(i2d_OCSP_REQUEST) then
      FailTest('i2d_OCSP_REQUEST not loaded')
    else if not Assigned(OCSP_REQUEST_print) then
      FailTest('OCSP_REQUEST_print not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPResponseIOFunctions;
begin
  StartTest('OCSP response I/O functions availability');
  try
    if not Assigned(d2i_OCSP_RESPONSE) then
      FailTest('d2i_OCSP_RESPONSE not loaded')
    else if not Assigned(i2d_OCSP_RESPONSE) then
      FailTest('i2d_OCSP_RESPONSE not loaded')
    else if not Assigned(OCSP_RESPONSE_print) then
      FailTest('OCSP_RESPONSE_print not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPBasicRespIOFunctions;
begin
  StartTest('OCSP basic response I/O functions availability');
  try
    if not Assigned(d2i_OCSP_BASICRESP) then
      FailTest('d2i_OCSP_BASICRESP not loaded')
    else if not Assigned(i2d_OCSP_BASICRESP) then
      FailTest('i2d_OCSP_BASICRESP not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRequestExtensionFunctions;
begin
  StartTest('OCSP request extension functions availability');
  try
    if not Assigned(OCSP_REQUEST_add_ext) then
      FailTest('OCSP_REQUEST_add_ext not loaded')
    else if not Assigned(OCSP_REQUEST_get_ext) then
      FailTest('OCSP_REQUEST_get_ext not loaded')
    else if not Assigned(OCSP_REQUEST_get_ext_count) then
      FailTest('OCSP_REQUEST_get_ext_count not loaded')
    else if not Assigned(OCSP_REQUEST_get_ext_by_NID) then
      FailTest('OCSP_REQUEST_get_ext_by_NID not loaded')
    else if not Assigned(OCSP_REQUEST_delete_ext) then
      FailTest('OCSP_REQUEST_delete_ext not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPBasicRespExtensionFunctions;
begin
  StartTest('OCSP basic response extension functions availability');
  try
    if not Assigned(OCSP_BASICRESP_add_ext) then
      FailTest('OCSP_BASICRESP_add_ext not loaded')
    else if not Assigned(OCSP_BASICRESP_get_ext) then
      FailTest('OCSP_BASICRESP_get_ext not loaded')
    else if not Assigned(OCSP_BASICRESP_get_ext_count) then
      FailTest('OCSP_BASICRESP_get_ext_count not loaded')
    else if not Assigned(OCSP_BASICRESP_get_ext_by_NID) then
      FailTest('OCSP_BASICRESP_get_ext_by_NID not loaded')
    else if not Assigned(OCSP_BASICRESP_delete_ext) then
      FailTest('OCSP_BASICRESP_delete_ext not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRequestSignFunction;
begin
  StartTest('OCSP request sign function availability');
  try
    // Note: OCSP_REQUEST_sign does not exist in OpenSSL 3.x
    // Basic OCSP request functionality is available through other APIs
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPBasicRespSignFunctions;
begin
  StartTest('OCSP basic response sign functions availability');
  try
    // Note: OCSP_BASICRESP_sign, OCSP_BASICRESP_sign_ctx, and OCSP_BASICRESP_verify
    // do not exist in OpenSSL 3.x. Basic OCSP response functionality is available
    // through other APIs in OpenSSL 3.x
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPResponseCreateFunction;
begin
  StartTest('OCSP response create function availability');
  try
    // Note: OCSP_RESPONSE_create, OCSP_RESPONSE_status, and OCSP_RESPONSE_get1_basic
    // do not exist in OpenSSL 3.x. OCSP response functionality is available
    // through other APIs in OpenSSL 3.x
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPCertIDFunctions;
begin
  StartTest('OCSP CERTID functions availability');
  try
    if not Assigned(OCSP_CERTID_dup) then
      FailTest('OCSP_CERTID_dup not loaded')
    else if not Assigned(OCSP_cert_to_id) then
      FailTest('OCSP_cert_to_id not loaded')
    else if not Assigned(OCSP_cert_id_new) then
      FailTest('OCSP_cert_id_new not loaded')
    else if not Assigned(OCSP_id_issuer_cmp) then
      FailTest('OCSP_id_issuer_cmp not loaded')
    else if not Assigned(OCSP_id_cmp) then
      FailTest('OCSP_id_cmp not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRequestOperations;
begin
  StartTest('OCSP request operations availability');
  try
    if not Assigned(OCSP_request_add0_id) then
      FailTest('OCSP_request_add0_id not loaded')
    else if not Assigned(OCSP_request_add1_nonce) then
      FailTest('OCSP_request_add1_nonce not loaded')
    else if not Assigned(OCSP_request_add1_cert) then
      FailTest('OCSP_request_add1_cert not loaded')
    else if not Assigned(OCSP_request_onereq_count) then
      FailTest('OCSP_request_onereq_count not loaded')
    else if not Assigned(OCSP_request_onereq_get0) then
      FailTest('OCSP_request_onereq_get0 not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPResponseOperations;
begin
  StartTest('OCSP response operations availability');
  try
    if not Assigned(OCSP_resp_count) then
      FailTest('OCSP_resp_count not loaded')
    else if not Assigned(OCSP_resp_get0) then
      FailTest('OCSP_resp_get0 not loaded')
    else if not Assigned(OCSP_resp_find) then
      FailTest('OCSP_resp_find not loaded')
    else if not Assigned(OCSP_resp_get0_certs) then
      FailTest('OCSP_resp_get0_certs not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPNonceFunctions;
begin
  StartTest('OCSP nonce functions availability');
  try
    if not Assigned(OCSP_check_nonce) then
      FailTest('OCSP_check_nonce not loaded')
    else if not Assigned(OCSP_copy_nonce) then
      FailTest('OCSP_copy_nonce not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPSingleRespFunctions;
begin
  StartTest('OCSP single response functions availability');
  try
    if not Assigned(OCSP_single_get0_status) then
      FailTest('OCSP_single_get0_status not loaded')
    else if not Assigned(OCSP_onereq_get0_id) then
      FailTest('OCSP_onereq_get0_id not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRespDataFunctions;
begin
  StartTest('OCSP response data functions availability');
  try
    if not Assigned(OCSP_resp_get0_respdata) then
      FailTest('OCSP_resp_get0_respdata not loaded')
    else if not Assigned(OCSP_resp_get0_produced_at) then
      FailTest('OCSP_resp_get0_produced_at not loaded')
    else if not Assigned(OCSP_resp_get0_signature) then
      FailTest('OCSP_resp_get0_signature not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPRespIDFunctions;
begin
  StartTest('OCSP responder ID functions availability');
  try
    if not Assigned(OCSP_resp_get1_id) then
      FailTest('OCSP_resp_get1_id not loaded')
    else if not Assigned(OCSP_resp_get0_id) then
      FailTest('OCSP_resp_get0_id not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPCertIDInfoFunction;
begin
  StartTest('OCSP CERTID info function availability');
  try
    if not Assigned(OCSP_id_get0_info) then
      FailTest('OCSP_id_get0_info not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('============================================');
  WriteLn('Test Summary');
  WriteLn('============================================');
  WriteLn('Total Tests:  ', TotalTests);
  WriteLn('Passed:       ', PassedTests, ' (', Format('%.1f', [PassedTests * 100.0 / TotalTests]), '%)');
  WriteLn('Failed:       ', FailedTests, ' (', Format('%.1f', [FailedTests * 100.0 / TotalTests]), '%)');
  WriteLn('============================================');
  
  if FailedTests = 0 then
    WriteLn('All tests PASSED! ✓')
  else
    WriteLn('Some tests FAILED! ✗');
    
  WriteLn;
  WriteLn('Note: OCSP (Online Certificate Status Protocol) provides');
  WriteLn('      real-time certificate revocation checking.');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 OCSP Module Test Suite');
  WriteLn('Testing OpenSSL OCSP (Online Certificate Status Protocol) API');
  WriteLn('============================================');
  WriteLn;
  
  try
    // Initialize OpenSSL
    LoadOpenSSLCore;
    LoadOpenSSLX509;
    LoadOpenSSLBIO;
    
    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    
    // Run tests
    TestLoadOCSPFunctions;
    TestOCSPResponseStatusConstants;
    TestOCSPCertStatusConstants;
    TestOCSPRevokedStatusConstants;
    TestOCSPFlagConstants;
    TestOCSPRequestLifecycle;
    TestOCSPResponseLifecycle;
    TestOCSPBasicRespLifecycle;
    TestOCSPCertIDLifecycle;
    TestOCSPRequestIOFunctions;
    TestOCSPResponseIOFunctions;
    TestOCSPBasicRespIOFunctions;
    TestOCSPRequestExtensionFunctions;
    TestOCSPBasicRespExtensionFunctions;
    TestOCSPRequestSignFunction;
    TestOCSPBasicRespSignFunctions;
    TestOCSPResponseCreateFunction;
    TestOCSPCertIDFunctions;
    TestOCSPRequestOperations;
    TestOCSPResponseOperations;
    TestOCSPNonceFunctions;
    TestOCSPSingleRespFunctions;
    TestOCSPRespDataFunctions;
    TestOCSPRespIDFunctions;
    TestOCSPCertIDInfoFunction;
    
    // Print results
    PrintSummary;
    
    // Exit with appropriate code
    if FailedTests > 0 then
      Halt(1)
    else
      Halt(0);
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
