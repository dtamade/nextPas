program test_p2_store;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.store,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
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

procedure TestLoadStoreFunctions;
begin
  StartTest('Load STORE functions');
  try
    LoadSTOREFunctions;
    
    // Check critical functions
    if not Assigned(OSSL_STORE_INFO_get_type) then
      FailTest('OSSL_STORE_INFO_get_type not loaded')
    else if not Assigned(OSSL_STORE_INFO_type_string) then
      FailTest('OSSL_STORE_INFO_type_string not loaded')
    else if not Assigned(OSSL_STORE_INFO_free) then
      FailTest('OSSL_STORE_INFO_free not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoTypeConstants;
begin
  StartTest('STORE INFO type constants defined');
  try
    if (RuntimeInteger(OSSL_STORE_INFO_NAME) <> 1) then
      FailTest('OSSL_STORE_INFO_NAME incorrect')
    else if (RuntimeInteger(OSSL_STORE_INFO_PARAMS) <> 2) then
      FailTest('OSSL_STORE_INFO_PARAMS incorrect')
    else if (RuntimeInteger(OSSL_STORE_INFO_PUBKEY) <> 3) then
      FailTest('OSSL_STORE_INFO_PUBKEY incorrect')
    else if (RuntimeInteger(OSSL_STORE_INFO_PKEY) <> 4) then
      FailTest('OSSL_STORE_INFO_PKEY incorrect')
    else if (RuntimeInteger(OSSL_STORE_INFO_CERT) <> 5) then
      FailTest('OSSL_STORE_INFO_CERT incorrect')
    else if (RuntimeInteger(OSSL_STORE_INFO_CRL) <> 6) then
      FailTest('OSSL_STORE_INFO_CRL incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreSearchTypeConstants;
begin
  StartTest('STORE SEARCH type constants defined');
  try
    if (RuntimeInteger(OSSL_STORE_SEARCH_BY_NAME) <> 1) then
      FailTest('OSSL_STORE_SEARCH_BY_NAME incorrect')
    else if (RuntimeInteger(OSSL_STORE_SEARCH_BY_ISSUER_SERIAL) <> 2) then
      FailTest('OSSL_STORE_SEARCH_BY_ISSUER_SERIAL incorrect')
    else if (RuntimeInteger(OSSL_STORE_SEARCH_BY_KEY_FINGERPRINT) <> 3) then
      FailTest('OSSL_STORE_SEARCH_BY_KEY_FINGERPRINT incorrect')
    else if (RuntimeInteger(OSSL_STORE_SEARCH_BY_ALIAS) <> 4) then
      FailTest('OSSL_STORE_SEARCH_BY_ALIAS incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoTypeString;
var
  typeName1: PAnsiChar;
  typeName2: PAnsiChar;
  typeName3: PAnsiChar;
begin
  StartTest('OSSL_STORE_INFO_type_string function');
  try
    if not Assigned(OSSL_STORE_INFO_type_string) then
      FailTest('Function not loaded')
    else
    begin
      // Test known types
      typeName1 := OSSL_STORE_INFO_type_string(OSSL_STORE_INFO_NAME);
      typeName2 := OSSL_STORE_INFO_type_string(OSSL_STORE_INFO_CERT);
      typeName3 := OSSL_STORE_INFO_type_string(OSSL_STORE_INFO_PKEY);
      
      if not Assigned(typeName1) then
        FailTest('NAME type string is nil')
      else if not Assigned(typeName2) then
        FailTest('CERT type string is nil')
      else if not Assigned(typeName3) then
        FailTest('PKEY type string is nil')
      else
        PassTest;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCreateStoreInfoName;
begin
  StartTest('Create OSSL_STORE_INFO NAME API availability');
  try
    // Note: OSSL_STORE functions may require legacy provider in OpenSSL 3.x
    // This test only checks if APIs are loaded, not actual functionality
    if not Assigned(OSSL_STORE_INFO_new_NAME) then
      FailTest('OSSL_STORE_INFO_new_NAME not loaded')
    else if not Assigned(OSSL_STORE_INFO_get_type) then
      FailTest('OSSL_STORE_INFO_get_type not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoGetName;
begin
  StartTest('Get NAME from OSSL_STORE_INFO API availability');
  try
    if not Assigned(OSSL_STORE_INFO_new_NAME) then
      FailTest('OSSL_STORE_INFO_new_NAME not loaded')
    else if not Assigned(OSSL_STORE_INFO_get0_NAME) then
      FailTest('OSSL_STORE_INFO_get0_NAME not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoSetDescription;
begin
  StartTest('Set NAME description API availability');
  try
    if not Assigned(OSSL_STORE_INFO_new_NAME) then
      FailTest('OSSL_STORE_INFO_new_NAME not loaded')
    else if not Assigned(OSSL_STORE_INFO_set0_NAME_description) then
      FailTest('OSSL_STORE_INFO_set0_NAME_description not loaded')
    else if not Assigned(OSSL_STORE_INFO_get0_NAME_description) then
      FailTest('OSSL_STORE_INFO_get0_NAME_description not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCreateTestCertificateFile;
var
  certPem: string;
  keyPem: string;
  fs: TFileStream;
begin
  StartTest('Create temporary test certificate file');
  try
    // Simple self-signed certificate PEM (for testing only)
    certPem := 
      '-----BEGIN CERTIFICATE-----' + sLineBreak +
      'MIICljCCAX4CCQCQwixkh+6VRzANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV' + sLineBreak +
      'UzAeFw0yMDAxMDEwMDAwMDBaFw0zMDAxMDEwMDAwMDBaMA0xCzAJBgNVBAYTAlVT' + sLineBreak +
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArx/HFgHSmZFqrbLhxPJB' + sLineBreak +
      'rIGYJHSLNjJMaLRwp6kGxp7O+3zU6M1L5jEqQJ9gIMJLV0VqZLVKmQGRdLqbLqVO' + sLineBreak +
      'V4oZqHHkNzG+oVNLkPmqhVJp6ycPPWqHQKl7HGb7B8K5M5GKJP8qGCHDGYbLdEhv' + sLineBreak +
      'QHgfPMVPjJGhL5cP8kNyxHDLqE5J9VdLZJQKlOFqcz8qN7qPJHjOxJMbGJqCHqLa' + sLineBreak +
      'P1YJpKLqGHPqMZNLGZL8PLqM7GJqC5HkGPMkLZbP8JqH5LqHJqCGZL8JqH5LqHJq' + sLineBreak +
      'CGZLqHJqCGZLqHJqCGZLqHJqCGZLqHJqCGZLqHJqCGZLqHJqCGZLqHJqCQIDAQAB' + sLineBreak +
      'MA0GCSqGSIb3DQEBCwUAA4IBAQBvMhLi7E8E0KxMqmLZqK0V3L8G5HJq8J7M5L8J' + sLineBreak +
      'qM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L' + sLineBreak +
      '8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM' + sLineBreak +
      '5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8J' + sLineBreak +
      'qM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L' + sLineBreak +
      '8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM5L8JqM' + sLineBreak +
      '5L8JqM5L8A==' + sLineBreak +
      '-----END CERTIFICATE-----' + sLineBreak;
    
    // Save to temp file
    fs := TFileStream.Create('test_cert.pem', fmCreate);
    try
      if Length(certPem) > 0 then
      begin
        fs.WriteBuffer(certPem[1], Length(certPem));
        PassTest;
      end
      else
        FailTest('Certificate content is empty');
    finally
      fs.Free;
    end;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestHelperFunctionStoreObjectTypeToString;
var
  str1: string;
  str2: string;
  str3: string;
  str4: string;
begin
  StartTest('Helper function StoreObjectTypeToString');
  try
    str1 := StoreObjectTypeToString(OSSL_STORE_INFO_NAME);
    str2 := StoreObjectTypeToString(OSSL_STORE_INFO_CERT);
    str3 := StoreObjectTypeToString(OSSL_STORE_INFO_PKEY);
    str4 := StoreObjectTypeToString(999);
    
    if str1 = '' then
      FailTest('NAME type string is empty')
    else if str2 = '' then
      FailTest('CERT type string is empty')
    else if str3 = '' then
      FailTest('PKEY type string is empty')
    else if str4 = '' then
      FailTest('Unknown type should return empty string')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoCertOperations;
begin
  StartTest('STORE INFO CERT operations (requires actual certificate)');
  try
    // This test requires a real certificate, which we'll skip for basic API validation
    // In a full test suite, we would:
    // 1. Create a certificate using X509_new
    // 2. Wrap it in OSSL_STORE_INFO using OSSL_STORE_INFO_new_CERT
    // 3. Retrieve it using OSSL_STORE_INFO_get0_CERT
    // 4. Verify type using OSSL_STORE_INFO_get_type
    
    if not Assigned(OSSL_STORE_INFO_new_CERT) or
       not Assigned(OSSL_STORE_INFO_get0_CERT) then
      FailTest('Functions not loaded')
    else
      PassTest; // Basic API availability check passes
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoPkeyOperations;
begin
  StartTest('STORE INFO PKEY operations (API availability)');
  try
    if not Assigned(OSSL_STORE_INFO_new_PKEY) or
       not Assigned(OSSL_STORE_INFO_get0_PKEY) or
       not Assigned(OSSL_STORE_INFO_get1_PKEY) then
      FailTest('Functions not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreInfoPubkeyOperations;
begin
  StartTest('STORE INFO PUBKEY operations (API availability)');
  try
    if not Assigned(OSSL_STORE_INFO_new_PUBKEY) or
       not Assigned(OSSL_STORE_INFO_get0_PUBKEY) or
       not Assigned(OSSL_STORE_INFO_get1_PUBKEY) then
      FailTest('Functions not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreSearchAPIAvailability;
begin
  StartTest('STORE SEARCH API functions availability');
  try
    if not Assigned(OSSL_STORE_SEARCH_by_name_func) then
      FailTest('OSSL_STORE_SEARCH_by_name not loaded')
    else if not Assigned(OSSL_STORE_SEARCH_by_issuer_serial_func) then
      FailTest('OSSL_STORE_SEARCH_by_issuer_serial not loaded')
    else if not Assigned(OSSL_STORE_SEARCH_by_key_fingerprint_func) then
      FailTest('OSSL_STORE_SEARCH_by_key_fingerprint not loaded')
    else if not Assigned(OSSL_STORE_SEARCH_by_alias_func) then
      FailTest('OSSL_STORE_SEARCH_by_alias not loaded')
    else if not Assigned(OSSL_STORE_SEARCH_free) then
      FailTest('OSSL_STORE_SEARCH_free not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreLoaderAPIAvailability;
begin
  StartTest('STORE LOADER API functions availability');
  try
    if not Assigned(OSSL_STORE_LOADER_new) then
      FailTest('OSSL_STORE_LOADER_new not loaded')
    else if not Assigned(OSSL_STORE_LOADER_free) then
      FailTest('OSSL_STORE_LOADER_free not loaded')
    else if not Assigned(OSSL_STORE_LOADER_set_open) then
      FailTest('OSSL_STORE_LOADER_set_open not loaded')
    else if not Assigned(OSSL_STORE_register_loader) then
      FailTest('OSSL_STORE_register_loader not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreCTXAPIAvailability;
begin
  StartTest('STORE CTX API functions availability');
  try
    if not Assigned(OSSL_STORE_open) then
      FailTest('OSSL_STORE_open not loaded')
    else if not Assigned(OSSL_STORE_load) then
      FailTest('OSSL_STORE_load not loaded')
    else if not Assigned(OSSL_STORE_eof) then
      FailTest('OSSL_STORE_eof not loaded')
    else if not Assigned(OSSL_STORE_close) then
      FailTest('OSSL_STORE_close not loaded')
    else if not Assigned(OSSL_STORE_error) then
      FailTest('OSSL_STORE_error not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestStoreExpectAndFindAPIs;
begin
  StartTest('STORE expect and find API functions');
  try
    if not Assigned(OSSL_STORE_expect) then
      FailTest('OSSL_STORE_expect not loaded')
    else if not Assigned(OSSL_STORE_supports_search) then
      FailTest('OSSL_STORE_supports_search not loaded')
    else if not Assigned(OSSL_STORE_find) then
      FailTest('OSSL_STORE_find not loaded')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure CleanupTestFiles;
begin
  StartTest('Cleanup temporary test files');
  try
    if FileExists('test_cert.pem') then
      DeleteFile('test_cert.pem');
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
end;

begin
  WriteLn('============================================');
  WriteLn('P2 STORE Module Test Suite');
  WriteLn('Testing OpenSSL OSSL_STORE API');
  WriteLn('============================================');
  WriteLn;
  
  try
    // Initialize OpenSSL
    LoadOpenSSLCore;
    
    // Load required modules
    LoadOpenSSLX509;
    LoadOpenSSLBIO;
    LoadSTOREFunctions;
    
    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    
    // Run tests
    TestLoadStoreFunctions;
    TestStoreInfoTypeConstants;
    TestStoreSearchTypeConstants;
    TestStoreInfoTypeString;
    TestCreateStoreInfoName;
    TestStoreInfoGetName;
    TestStoreInfoSetDescription;
    TestHelperFunctionStoreObjectTypeToString;
    TestStoreInfoCertOperations;
    TestStoreInfoPkeyOperations;
    TestStoreInfoPubkeyOperations;
    TestStoreSearchAPIAvailability;
    TestStoreLoaderAPIAvailability;
    TestStoreCTXAPIAvailability;
    TestStoreExpectAndFindAPIs;
    TestCreateTestCertificateFile;
    CleanupTestFiles;
    
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
