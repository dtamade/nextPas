program test_p2_ct;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ct,
  nextpas.core.tls.openssl.api.x509,
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

procedure TestLoadCTFunctions;
begin
  StartTest('Load CT functions');
  try
    LoadCTFunctions;
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCTLogEntryTypeConstants;
begin
  StartTest('CT log entry type constants');
  try
    if (RuntimeInteger(CT_LOG_ENTRY_TYPE_X509) <> 0) then
      FailTest('CT_LOG_ENTRY_TYPE_X509 incorrect')
    else if (RuntimeInteger(CT_LOG_ENTRY_TYPE_PRECERT) <> 1) then
      FailTest('CT_LOG_ENTRY_TYPE_PRECERT incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTVersionConstants;
begin
  StartTest('SCT version constants');
  try
    if (RuntimeInteger(SCT_VERSION_V1) <> 0) then
      FailTest('SCT_VERSION_V1 incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTSourceConstants;
begin
  StartTest('SCT source constants');
  try
    if (RuntimeInteger(SCT_SOURCE_TLS_EXTENSION) <> 1) then
      FailTest('SCT_SOURCE_TLS_EXTENSION incorrect')
    else if (RuntimeInteger(SCT_SOURCE_X509V3_EXTENSION) <> 2) then
      FailTest('SCT_SOURCE_X509V3_EXTENSION incorrect')
    else if (RuntimeInteger(SCT_SOURCE_OCSP_STAPLED_RESPONSE) <> 3) then
      FailTest('SCT_SOURCE_OCSP_STAPLED_RESPONSE incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTValidationStatusConstants;
begin
  StartTest('SCT validation status constants');
  try
    if (RuntimeInteger(SCT_VALIDATION_STATUS_VALID) <> 2) then
      FailTest('SCT_VALIDATION_STATUS_VALID incorrect')
    else if (RuntimeInteger(SCT_VALIDATION_STATUS_INVALID) <> 3) then
      FailTest('SCT_VALIDATION_STATUS_INVALID incorrect')
    else if (RuntimeInteger(SCT_VALIDATION_STATUS_UNVERIFIED) <> 4) then
      FailTest('SCT_VALIDATION_STATUS_UNVERIFIED incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCTPolicyEvalCTXLifecycle;
var
  LCtx: PCT_POLICY_EVAL_CTX;
begin
  StartTest('CT_POLICY_EVAL_CTX lifecycle (new/free)');
  try
    if not Assigned(CT_POLICY_EVAL_CTX_new) then
      FailTest('CT_POLICY_EVAL_CTX_new not loaded')
    else if not Assigned(CT_POLICY_EVAL_CTX_free) then
      FailTest('CT_POLICY_EVAL_CTX_free not loaded')
    else
    begin
      LCtx := CT_POLICY_EVAL_CTX_new();
      if LCtx = nil then
        FailTest('CT_POLICY_EVAL_CTX_new returned nil')
      else
      begin
        CT_POLICY_EVAL_CTX_free(LCtx);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTLifecycle;
var
  LSct: PSCT;
begin
  StartTest('SCT lifecycle (new/free)');
  try
    if not Assigned(SCT_new) then
      FailTest('SCT_new not loaded')
    else if not Assigned(SCT_free) then
      FailTest('SCT_free not loaded')
    else
    begin
      LSct := SCT_new();
      if LSct = nil then
        FailTest('SCT_new returned nil')
      else
      begin
        SCT_free(LSct);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCTLOGSTORELifecycle;
var
  LStore: PCTLOG_STORE;
begin
  StartTest('CTLOG_STORE lifecycle (new/free)');
  try
    if not Assigned(CTLOG_STORE_new) then
      FailTest('CTLOG_STORE_new not loaded')
    else if not Assigned(CTLOG_STORE_free) then
      FailTest('CTLOG_STORE_free not loaded')
    else
    begin
      LStore := CTLOG_STORE_new();
      if LStore = nil then
        FailTest('CTLOG_STORE_new returned nil')
      else
      begin
        CTLOG_STORE_free(LStore);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCTPolicyEvalCTXFunctions;
begin
  StartTest('CT_POLICY_EVAL_CTX functions availability');
  try
    if not Assigned(CT_POLICY_EVAL_CTX_set1_cert) then
      FailTest('CT_POLICY_EVAL_CTX_set1_cert not loaded')
    else if not Assigned(CT_POLICY_EVAL_CTX_get0_cert) then
      FailTest('CT_POLICY_EVAL_CTX_get0_cert not loaded')
    else if not Assigned(CT_POLICY_EVAL_CTX_set1_issuer) then
      FailTest('CT_POLICY_EVAL_CTX_set1_issuer not loaded')
    else if not Assigned(CT_POLICY_EVAL_CTX_get0_issuer) then
      FailTest('CT_POLICY_EVAL_CTX_get0_issuer not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTVersionFunctions;
begin
  StartTest('SCT version functions availability');
  try
    if not Assigned(SCT_get_version) then
      FailTest('SCT_get_version not loaded')
    else if not Assigned(SCT_set_version) then
      FailTest('SCT_set_version not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTLogEntryTypeFunctions;
begin
  StartTest('SCT log entry type functions availability');
  try
    if not Assigned(SCT_get_log_entry_type) then
      FailTest('SCT_get_log_entry_type not loaded')
    else if not Assigned(SCT_set_log_entry_type) then
      FailTest('SCT_set_log_entry_type not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTTimestampFunctions;
begin
  StartTest('SCT timestamp functions availability');
  try
    if not Assigned(SCT_get_timestamp) then
      FailTest('SCT_get_timestamp not loaded')
    else if not Assigned(SCT_set_timestamp) then
      FailTest('SCT_set_timestamp not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTLogIDFunctions;
begin
  StartTest('SCT log ID functions availability');
  try
    if not Assigned(SCT_get0_log_id) then
      FailTest('SCT_get0_log_id not loaded')
    else if not Assigned(SCT_set1_log_id) then
      FailTest('SCT_set1_log_id not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTSignatureFunctions;
begin
  StartTest('SCT signature functions availability');
  try
    if not Assigned(SCT_get0_signature) then
      FailTest('SCT_get0_signature not loaded')
    else if not Assigned(SCT_set1_signature) then
      FailTest('SCT_set1_signature not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTExtensionsFunctions;
begin
  StartTest('SCT extensions functions availability');
  try
    if not Assigned(SCT_get0_extensions) then
      FailTest('SCT_get0_extensions not loaded')
    else if not Assigned(SCT_set1_extensions) then
      FailTest('SCT_set1_extensions not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTSourceFunctions;
begin
  StartTest('SCT source functions availability');
  try
    if not Assigned(SCT_get_source) then
      FailTest('SCT_get_source not loaded')
    else if not Assigned(SCT_set_source) then
      FailTest('SCT_set_source not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTValidationFunctions;
begin
  StartTest('SCT validation functions availability');
  try
    if not Assigned(SCT_validate) then
      FailTest('SCT_validate not loaded')
    else if not Assigned(SCT_get_validation_status) then
      FailTest('SCT_get_validation_status not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTListFunctions;
begin
  StartTest('SCT list functions availability');
  try
    if not Assigned(SCT_LIST_free) then
      FailTest('SCT_LIST_free not loaded')
    else if not Assigned(SCT_LIST_validate) then
      FailTest('SCT_LIST_validate not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCTLOGFunctions;
begin
  StartTest('CTLOG functions availability');
  try
    if not Assigned(CTLOG_new) then
      FailTest('CTLOG_new not loaded')
    else if not Assigned(CTLOG_free) then
      FailTest('CTLOG_free not loaded')
    else if not Assigned(CTLOG_get0_name) then
      FailTest('CTLOG_get0_name not loaded')
    else if not Assigned(CTLOG_get0_public_key) then
      FailTest('CTLOG_get0_public_key not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCTLOGSTOREFunctions;
begin
  StartTest('CTLOG_STORE functions availability');
  try
    if not Assigned(CTLOG_STORE_get0_log_by_id) then
      FailTest('CTLOG_STORE_get0_log_by_id not loaded')
    else if not Assigned(CTLOG_STORE_load_file) then
      FailTest('CTLOG_STORE_load_file not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSCTSerializationFunctions;
begin
  StartTest('SCT serialization functions availability');
  try
    if not Assigned(i2o_SCT) then
      FailTest('i2o_SCT not loaded')
    else if not Assigned(o2i_SCT) then
      FailTest('o2i_SCT not loaded')
    else if not Assigned(i2o_SCT_LIST) then
      FailTest('i2o_SCT_LIST not loaded')
    else if not Assigned(o2i_SCT_LIST) then
      FailTest('o2i_SCT_LIST not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestX509CTExtensionFunctions;
begin
  StartTest('X509 CT extension functions availability');
  try
    if not Assigned(X509_get_ext_d2i) then
      FailTest('X509_get_ext_d2i (required for X509_get_SCT_LIST) not loaded')
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
  WriteLn('Note: CT (Certificate Transparency) provides public,');
  WriteLn('      append-only logs of SSL/TLS certificates (RFC 6962).');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 CT Module Test Suite');
  WriteLn('Testing OpenSSL CT (Certificate Transparency) API');
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
    TestLoadCTFunctions;
    TestCTLogEntryTypeConstants;
    TestSCTVersionConstants;
    TestSCTSourceConstants;
    TestSCTValidationStatusConstants;
    TestCTPolicyEvalCTXLifecycle;
    TestSCTLifecycle;
    TestCTLOGSTORELifecycle;
    TestCTPolicyEvalCTXFunctions;
    TestSCTVersionFunctions;
    TestSCTLogEntryTypeFunctions;
    TestSCTTimestampFunctions;
    TestSCTLogIDFunctions;
    TestSCTSignatureFunctions;
    TestSCTExtensionsFunctions;
    TestSCTSourceFunctions;
    TestSCTValidationFunctions;
    TestSCTListFunctions;
    TestCTLOGFunctions;
    TestCTLOGSTOREFunctions;
    TestSCTSerializationFunctions;
    TestX509CTExtensionFunctions;
    
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
