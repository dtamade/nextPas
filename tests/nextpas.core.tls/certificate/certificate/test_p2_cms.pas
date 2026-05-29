program test_p2_cms;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.cms,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.err,
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

procedure TestLoadCMSFunctions;
begin
  StartTest('Load CMS functions');
  try
    if LoadOpenSSLCMS(GetCryptoLibHandle) then
      PassTest
    else
      FailTest('LoadOpenSSLCMS returned False');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSTypeConstants;
begin
  StartTest('CMS recipient info type constants');
  try
    if (RuntimeInteger(CMS_RECIPINFO_TRANS) <> 0) then
      FailTest('CMS_RECIPINFO_TRANS incorrect')
    else if (RuntimeInteger(CMS_RECIPINFO_AGREE) <> 1) then
      FailTest('CMS_RECIPINFO_AGREE incorrect')
    else if (RuntimeInteger(CMS_RECIPINFO_KEK) <> 2) then
      FailTest('CMS_RECIPINFO_KEK incorrect')
    else if (RuntimeInteger(CMS_RECIPINFO_PASS) <> 3) then
      FailTest('CMS_RECIPINFO_PASS incorrect')
    else if (RuntimeInteger(CMS_RECIPINFO_OTHER) <> 4) then
      FailTest('CMS_RECIPINFO_OTHER incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSFlagConstants;
begin
  StartTest('CMS flag constants');
  try
    if (RuntimeInteger(CMS_TEXT) <> $1) then
      FailTest('CMS_TEXT incorrect')
    else if (RuntimeInteger(CMS_NOCERTS) <> $2) then
      FailTest('CMS_NOCERTS incorrect')
    else if (RuntimeInteger(CMS_DETACHED) <> $40) then
      FailTest('CMS_DETACHED incorrect')
    else if (RuntimeInteger(CMS_BINARY) <> $80) then
      FailTest('CMS_BINARY incorrect')
    else if (RuntimeInteger(CMS_STREAM) <> $1000) then
      FailTest('CMS_STREAM incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSContentInfoLifecycle;
var
  LCms: PCMS_ContentInfo;
begin
  StartTest('CMS_ContentInfo lifecycle (new/free)');
  try
    if not Assigned(CMS_ContentInfo_new) then
      FailTest('CMS_ContentInfo_new not loaded')
    else if not Assigned(CMS_ContentInfo_free) then
      FailTest('CMS_ContentInfo_free not loaded')
    else
    begin
      LCms := CMS_ContentInfo_new();
      if LCms = nil then
        FailTest('CMS_ContentInfo_new returned nil')
      else
      begin
        CMS_ContentInfo_free(LCms);
        PassTest;
      end;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSSignFunctionsAvailability;
begin
  StartTest('CMS sign functions availability');
  try
    if not Assigned(CMS_sign) then
      FailTest('CMS_sign not loaded')
    else if not Assigned(CMS_add1_signer) then
      FailTest('CMS_add1_signer not loaded')
    else if not Assigned(CMS_verify) then
      FailTest('CMS_verify not loaded')
    else if not Assigned(CMS_final) then
      FailTest('CMS_final not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSEncryptFunctionsAvailability;
begin
  StartTest('CMS encrypt functions availability');
  try
    if not Assigned(CMS_encrypt) then
      FailTest('CMS_encrypt not loaded')
    else if not Assigned(CMS_decrypt) then
      FailTest('CMS_decrypt not loaded')
    else if not Assigned(CMS_decrypt_set1_pkey) then
      FailTest('CMS_decrypt_set1_pkey not loaded')
    else if not Assigned(CMS_decrypt_set1_key) then
      FailTest('CMS_decrypt_set1_key not loaded')
    else if not Assigned(CMS_decrypt_set1_password) then
      FailTest('CMS_decrypt_set1_password not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSIOFunctionsAvailability;
begin
  StartTest('CMS I/O functions availability');
  try
    if not Assigned(d2i_CMS_ContentInfo) then
      FailTest('d2i_CMS_ContentInfo not loaded')
    else if not Assigned(i2d_CMS_ContentInfo) then
      FailTest('i2d_CMS_ContentInfo not loaded')
    else if not Assigned(d2i_CMS_bio) then
      FailTest('d2i_CMS_bio not loaded')
    else if not Assigned(i2d_CMS_bio) then
      FailTest('i2d_CMS_bio not loaded')
    else if not Assigned(i2d_CMS_bio_stream) then
      FailTest('i2d_CMS_bio_stream not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSRecipientInfoFunctionsAvailability;
begin
  StartTest('CMS RecipientInfo functions availability');
  try
    if not Assigned(CMS_add1_recipient_cert) then
      FailTest('CMS_add1_recipient_cert not loaded')
    else if not Assigned(CMS_add0_recipient_key) then
      FailTest('CMS_add0_recipient_key not loaded')
    else if not Assigned(CMS_add0_recipient_password) then
      FailTest('CMS_add0_recipient_password not loaded')
    else if not Assigned(CMS_RecipientInfo_type) then
      FailTest('CMS_RecipientInfo_type not loaded')
    else if not Assigned(CMS_RecipientInfo_set0_pkey) then
      FailTest('CMS_RecipientInfo_set0_pkey not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSSignerInfoFunctionsAvailability;
begin
  StartTest('CMS SignerInfo functions availability');
  try
    if not Assigned(CMS_get0_SignerInfos) then
      FailTest('CMS_get0_SignerInfos not loaded')
    else if not Assigned(CMS_SignerInfo_get0_signer_id) then
      FailTest('CMS_SignerInfo_get0_signer_id not loaded')
    else if not Assigned(CMS_SignerInfo_get0_signature) then
      FailTest('CMS_SignerInfo_get0_signature not loaded')
    else if not Assigned(CMS_SignerInfo_cert_cmp) then
      FailTest('CMS_SignerInfo_cert_cmp not loaded')
    else if not Assigned(CMS_SignerInfo_verify) then
      FailTest('CMS_SignerInfo_verify not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSAttributeFunctionsAvailability;
begin
  StartTest('CMS signed attribute functions availability');
  try
    if not Assigned(CMS_signed_get_attr_count) then
      FailTest('CMS_signed_get_attr_count not loaded')
    else if not Assigned(CMS_signed_get_attr_by_NID) then
      FailTest('CMS_signed_get_attr_by_NID not loaded')
    else if not Assigned(CMS_signed_get_attr) then
      FailTest('CMS_signed_get_attr not loaded')
    else if not Assigned(CMS_signed_add1_attr) then
      FailTest('CMS_signed_add1_attr not loaded')
    else if not Assigned(CMS_signed_delete_attr) then
      FailTest('CMS_signed_delete_attr not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSUnsignedAttributeFunctionsAvailability;
begin
  StartTest('CMS unsigned attribute functions availability');
  try
    if not Assigned(CMS_unsigned_get_attr_count) then
      FailTest('CMS_unsigned_get_attr_count not loaded')
    else if not Assigned(CMS_unsigned_get_attr_by_NID) then
      FailTest('CMS_unsigned_get_attr_by_NID not loaded')
    else if not Assigned(CMS_unsigned_get_attr) then
      FailTest('CMS_unsigned_get_attr not loaded')
    else if not Assigned(CMS_unsigned_add1_attr) then
      FailTest('CMS_unsigned_add1_attr not loaded')
    else if not Assigned(CMS_unsigned_delete_attr) then
      FailTest('CMS_unsigned_delete_attr not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSUtilityFunctionsAvailability;
begin
  StartTest('CMS utility functions availability');
  try
    if not Assigned(CMS_get0_type) then
      FailTest('CMS_get0_type not loaded')
    else if not Assigned(CMS_set1_eContentType) then
      FailTest('CMS_set1_eContentType not loaded')
    else if not Assigned(CMS_get0_eContentType) then
      FailTest('CMS_get0_eContentType not loaded')
    else if not Assigned(CMS_get0_content) then
      FailTest('CMS_get0_content not loaded')
    else if not Assigned(CMS_is_detached) then
      FailTest('CMS_is_detached not loaded')
    else if not Assigned(CMS_set_detached) then
      FailTest('CMS_set_detached not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSReceiptFunctionsAvailability;
begin
  StartTest('CMS receipt functions availability');
  try
    if not Assigned(CMS_sign_receipt) then
      FailTest('CMS_sign_receipt not loaded')
    else if not Assigned(CMS_verify_receipt) then
      FailTest('CMS_verify_receipt not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSDataInitFunction;
begin
  StartTest('CMS dataInit function availability');
  try
    if not Assigned(CMS_dataInit) then
      FailTest('CMS_dataInit not loaded')
    else if not Assigned(CMS_stream_func) then
      FailTest('CMS_stream_func not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSGetSignersFunction;
begin
  StartTest('CMS_get0_signers function availability');
  try
    if not Assigned(CMS_get0_signers) then
      FailTest('CMS_get0_signers not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSSignerInfoSignFunction;
begin
  StartTest('CMS SignerInfo sign function availability');
  try
    if not Assigned(CMS_SignerInfo_sign) then
      FailTest('CMS_SignerInfo_sign not loaded')
    else if not Assigned(CMS_SignerInfo_verify_content) then
      FailTest('CMS_SignerInfo_verify_content not loaded')
    else if not Assigned(CMS_SignerInfo_get0_md_ctx) then
      FailTest('CMS_SignerInfo_get0_md_ctx not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSRecipientInfoKeyFunctions;
begin
  StartTest('CMS RecipientInfo key functions availability');
  try
    if not Assigned(CMS_RecipientInfo_ktri_get0_signer_id) then
      FailTest('CMS_RecipientInfo_ktri_get0_signer_id not loaded')
    else if not Assigned(CMS_RecipientInfo_ktri_cert_cmp) then
      FailTest('CMS_RecipientInfo_ktri_cert_cmp not loaded')
    else if not Assigned(CMS_RecipientInfo_kekri_get0_id) then
      FailTest('CMS_RecipientInfo_kekri_get0_id not loaded')
    else if not Assigned(CMS_RecipientInfo_kekri_id_cmp) then
      FailTest('CMS_RecipientInfo_kekri_id_cmp not loaded')
    else if not Assigned(CMS_RecipientInfo_set0_key) then
      FailTest('CMS_RecipientInfo_set0_key not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSRecipientInfoEncryptDecrypt;
begin
  StartTest('CMS RecipientInfo encrypt/decrypt functions');
  try
    if not Assigned(CMS_RecipientInfo_decrypt) then
      FailTest('CMS_RecipientInfo_decrypt not loaded')
    else if not Assigned(CMS_RecipientInfo_encrypt) then
      FailTest('CMS_RecipientInfo_encrypt not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSSignerInfoAlgorithmFunctions;
begin
  StartTest('CMS SignerInfo algorithm functions');
  try
    // Note: CMS_set1_signer_cert does not exist in OpenSSL 3.x
    // Only check CMS_SignerInfo_get0_algs
    if not Assigned(CMS_SignerInfo_get0_algs) then
      FailTest('CMS_SignerInfo_get0_algs not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCMSPrintFunction;
begin
  StartTest('CMS print function availability');
  try
    if not Assigned(CMS_ContentInfo_print_ctx) then
      FailTest('CMS_ContentInfo_print_ctx not loaded')
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
  WriteLn('Note: CMS (Cryptographic Message Syntax) is the modern');
  WriteLn('      successor to PKCS#7 with enhanced features.');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 CMS Module Test Suite');
  WriteLn('Testing OpenSSL CMS (Cryptographic Message Syntax) API');
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
    TestLoadCMSFunctions;
    TestCMSTypeConstants;
    TestCMSFlagConstants;
    TestCMSContentInfoLifecycle;
    TestCMSSignFunctionsAvailability;
    TestCMSEncryptFunctionsAvailability;
    TestCMSIOFunctionsAvailability;
    TestCMSRecipientInfoFunctionsAvailability;
    TestCMSSignerInfoFunctionsAvailability;
    TestCMSAttributeFunctionsAvailability;
    TestCMSUnsignedAttributeFunctionsAvailability;
    TestCMSUtilityFunctionsAvailability;
    TestCMSReceiptFunctionsAvailability;
    TestCMSDataInitFunction;
    TestCMSGetSignersFunction;
    TestCMSSignerInfoSignFunction;
    TestCMSRecipientInfoKeyFunctions;
    TestCMSRecipientInfoEncryptDecrypt;
    TestCMSSignerInfoAlgorithmFunctions;
    TestCMSPrintFunction;
    
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
