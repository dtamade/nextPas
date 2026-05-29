program test_p2_ts;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ts,
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

procedure TestLoadTSFunctions;
begin
  StartTest('Load TS functions');
  try
    LoadTSFunctions;
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSStatusConstants;
begin
  StartTest('TS status constants');
  try
    if (RuntimeInteger(TS_STATUS_GRANTED) <> 0) then
      FailTest('TS_STATUS_GRANTED incorrect')
    else if (RuntimeInteger(TS_STATUS_GRANTED_WITH_MODS) <> 1) then
      FailTest('TS_STATUS_GRANTED_WITH_MODS incorrect')
    else if (RuntimeInteger(TS_STATUS_REJECTION) <> 2) then
      FailTest('TS_STATUS_REJECTION incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSInfoFlagConstants;
begin
  StartTest('TS info flag constants');
  try
    if (RuntimeInteger(TS_INFO_VERSION) <> $0001) then
      FailTest('TS_INFO_VERSION incorrect')
    else if (RuntimeInteger(TS_INFO_POLICY) <> $0002) then
      FailTest('TS_INFO_POLICY incorrect')
    else if (RuntimeInteger(TS_INFO_SERIAL) <> $0008) then
      FailTest('TS_INFO_SERIAL incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSVerifyFlagConstants;
begin
  StartTest('TS verify flag constants');
  try
    if (RuntimeInteger(TS_VFY_VERSION) <> $01) then
      FailTest('TS_VFY_VERSION incorrect')
    else if (RuntimeInteger(TS_VFY_POLICY) <> $02) then
      FailTest('TS_VFY_IMPRINT incorrect')
    else if (RuntimeInteger(TS_VFY_SIGNATURE) <> $80) then
      FailTest('TS_VFY_SIGNATURE incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSMSGIMPRINTLifecycle;
var
  LMsg: PTS_MSG_IMPRINT;
begin
  StartTest('TS_MSG_IMPRINT lifecycle (new/free)');
  try
    if not Assigned(TS_MSG_IMPRINT_new) then
      FailTest('TS_MSG_IMPRINT_new not loaded')
    else if not Assigned(TS_MSG_IMPRINT_free) then
      FailTest('TS_MSG_IMPRINT_free not loaded')
    else
    begin
      LMsg := TS_MSG_IMPRINT_new();
      if LMsg = nil then
        FailTest('TS_MSG_IMPRINT_new returned nil')
      else
      begin
        TS_MSG_IMPRINT_free(LMsg);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSREQLifecycle;
var
  LReq: PTS_REQ;
begin
  StartTest('TS_REQ lifecycle (new/free)');
  try
    if not Assigned(TS_REQ_new) then
      FailTest('TS_REQ_new not loaded')
    else if not Assigned(TS_REQ_free) then
      FailTest('TS_REQ_free not loaded')
    else
    begin
      LReq := TS_REQ_new();
      if LReq = nil then
        FailTest('TS_REQ_new returned nil')
      else
      begin
        TS_REQ_free(LReq);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSTSTINFOLifecycle;
var
  LInfo: PTS_TST_INFO;
begin
  StartTest('TS_TST_INFO lifecycle (new/free)');
  try
    if not Assigned(TS_TST_INFO_new) then
      FailTest('TS_TST_INFO_new not loaded')
    else if not Assigned(TS_TST_INFO_free) then
      FailTest('TS_TST_INFO_free not loaded')
    else
    begin
      LInfo := TS_TST_INFO_new();
      if LInfo = nil then
        FailTest('TS_TST_INFO_new returned nil')
      else
      begin
        TS_TST_INFO_free(LInfo);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSSTATUSINFOLifecycle;
var
  LStatus: PTS_STATUS_INFO;
begin
  StartTest('TS_STATUS_INFO lifecycle (new/free)');
  try
    if not Assigned(TS_STATUS_INFO_new) then
      FailTest('TS_STATUS_INFO_new not loaded')
    else if not Assigned(TS_STATUS_INFO_free) then
      FailTest('TS_STATUS_INFO_free not loaded')
    else
    begin
      LStatus := TS_STATUS_INFO_new();
      if LStatus = nil then
        FailTest('TS_STATUS_INFO_new returned nil')
      else
      begin
        TS_STATUS_INFO_free(LStatus);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSRESPLifecycle;
var
  LResp: PTS_RESP;
begin
  StartTest('TS_RESP lifecycle (new/free)');
  try
    if not Assigned(TS_RESP_new) then
      FailTest('TS_RESP_new not loaded')
    else if not Assigned(TS_RESP_free) then
      FailTest('TS_RESP_free not loaded')
    else
    begin
      LResp := TS_RESP_new();
      if LResp = nil then
        FailTest('TS_RESP_new returned nil')
      else
      begin
        TS_RESP_free(LResp);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSRESPCTXLifecycle;
var
  LCtx: PTS_RESP_CTX;
begin
  StartTest('TS_RESP_CTX lifecycle (new/free)');
  try
    if not Assigned(TS_RESP_CTX_new) then
      FailTest('TS_RESP_CTX_new not loaded')
    else if not Assigned(TS_RESP_CTX_free) then
      FailTest('TS_RESP_CTX_free not loaded')
    else
    begin
      LCtx := TS_RESP_CTX_new();
      if LCtx = nil then
        FailTest('TS_RESP_CTX_new returned nil')
      else
      begin
        TS_RESP_CTX_free(LCtx);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSVERIFYCTXLifecycle;
var
  LCtx: PTS_VERIFY_CTX;
begin
  StartTest('TS_VERIFY_CTX lifecycle (new/free)');
  try
    if not Assigned(TS_VERIFY_CTX_new) then
      FailTest('TS_VERIFY_CTX_new not loaded')
    else if not Assigned(TS_VERIFY_CTX_free) then
      FailTest('TS_VERIFY_CTX_free not loaded')
    else
    begin
      LCtx := TS_VERIFY_CTX_new();
      if LCtx = nil then
        FailTest('TS_VERIFY_CTX_new returned nil')
      else
      begin
        TS_VERIFY_CTX_free(LCtx);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSREQFunctions;
begin
  StartTest('TS_REQ functions availability');
  try
    if not Assigned(TS_REQ_set_version) then
      FailTest('TS_REQ_set_version not loaded')
    else if not Assigned(TS_REQ_get_version) then
      FailTest('TS_REQ_get_version not loaded')
    else if not Assigned(TS_REQ_set_msg_imprint) then
      FailTest('TS_REQ_set_msg_imprint not loaded')
    else if not Assigned(TS_REQ_get_msg_imprint) then
      FailTest('TS_REQ_get_msg_imprint not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSTSTINFOFunctions;
begin
  StartTest('TS_TST_INFO functions availability');
  try
    if not Assigned(TS_TST_INFO_set_version) then
      FailTest('TS_TST_INFO_set_version not loaded')
    else if not Assigned(TS_TST_INFO_get_serial) then
      FailTest('TS_TST_INFO_get_serial not loaded')
    else if not Assigned(TS_TST_INFO_set_time) then
      FailTest('TS_TST_INFO_set_time not loaded')
    else if not Assigned(TS_TST_INFO_get_time) then
      FailTest('TS_TST_INFO_get_time not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSRESPFunctions;
begin
  StartTest('TS_RESP functions availability');
  try
    if not Assigned(TS_RESP_set_status_info) then
      FailTest('TS_RESP_set_status_info not loaded')
    else if not Assigned(TS_RESP_get_status_info) then
      FailTest('TS_RESP_get_status_info not loaded')
    else if not Assigned(TS_RESP_get_token) then
      FailTest('TS_RESP_get_token not loaded')
    else if not Assigned(TS_RESP_get_tst_info) then
      FailTest('TS_RESP_get_tst_info not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSVerificationFunctions;
begin
  StartTest('TS verification functions availability');
  try
    if not Assigned(TS_RESP_verify_signature) then
      FailTest('TS_RESP_verify_signature not loaded')
    else if not Assigned(TS_RESP_verify_response) then
      FailTest('TS_RESP_verify_response not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSIOFunctions;
begin
  StartTest('TS I/O functions availability');
  try
    // Note: TS_REQ_d2i_bio does not exist in OpenSSL 3.x
    if not Assigned(TS_REQ_i2d_bio) then
      FailTest('TS_REQ_i2d_bio not loaded')
    else if not Assigned(TS_RESP_d2i_bio) then
      FailTest('TS_RESP_d2i_bio not loaded')
    else if not Assigned(TS_RESP_i2d_bio) then
      FailTest('TS_RESP_i2d_bio not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestTSPrintFunctions;
begin
  StartTest('TS print functions availability');
  try
    if not Assigned(TS_REQ_print_bio) then
      FailTest('TS_REQ_print_bio not loaded')
    else if not Assigned(TS_RESP_print_bio) then
      FailTest('TS_RESP_print_bio not loaded')
    else if not Assigned(TS_TST_INFO_print_bio) then
      FailTest('TS_TST_INFO_print_bio not loaded')
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
  WriteLn('Note: TS (Timestamp Protocol) provides RFC 3161');
  WriteLn('      timestamping for document integrity.');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 TS Module Test Suite');
  WriteLn('Testing OpenSSL TS (Timestamp Protocol) API');
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
    TestLoadTSFunctions;
    TestTSStatusConstants;
    TestTSInfoFlagConstants;
    TestTSVerifyFlagConstants;
    TestTSMSGIMPRINTLifecycle;
    TestTSREQLifecycle;
    TestTSTSTINFOLifecycle;
    TestTSSTATUSINFOLifecycle;
    TestTSRESPLifecycle;
    TestTSRESPCTXLifecycle;
    TestTSVERIFYCTXLifecycle;
    TestTSREQFunctions;
    TestTSTSTINFOFunctions;
    TestTSRESPFunctions;
    TestTSVerificationFunctions;
    TestTSIOFunctions;
    TestTSPrintFunctions;
    
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
