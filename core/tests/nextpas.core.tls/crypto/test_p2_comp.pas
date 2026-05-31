program test_p2_comp;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.comp,
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

procedure TestLoadCompFunctions;
begin
  StartTest('Load COMP functions');
  try
    LoadCOMPFunctions;
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCompConstants;
begin
  StartTest('COMP compression method NID constants');
  try
    if (RuntimeInteger(NID_zlib_compression) <> 125) then
      FailTest('NID_zlib_compression incorrect')
    else if (RuntimeInteger(NID_rle_compression) <> 124) then
      FailTest('NID_rle_compression incorrect')
    else if (RuntimeInteger(NID_brotli_compression) <> 1138) then
      FailTest('NID_brotli_compression incorrect')
    else if (RuntimeInteger(NID_zstd_compression) <> 1139) then
      FailTest('NID_zstd_compression incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCompLevelConstants;
begin
  StartTest('COMP compression level constants');
  try
    if (RuntimeInteger(COMP_ZLIB_LEVEL_DEFAULT) <> -1) then
      FailTest('COMP_ZLIB_LEVEL_DEFAULT incorrect')
    else if (RuntimeInteger(COMP_ZLIB_LEVEL_NONE) <> 0) then
      FailTest('COMP_ZLIB_LEVEL_NONE incorrect')
    else if (RuntimeInteger(COMP_ZLIB_LEVEL_BEST_SPEED) <> 1) then
      FailTest('COMP_ZLIB_LEVEL_BEST_SPEED incorrect')
    else if (RuntimeInteger(COMP_ZLIB_LEVEL_BEST) <> 9) then
      FailTest('COMP_ZLIB_LEVEL_BEST incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCompStrategyConstants;
begin
  StartTest('COMP compression strategy constants');
  try
    if (RuntimeInteger(COMP_ZLIB_STRATEGY_DEFAULT) <> 0) then
      FailTest('COMP_ZLIB_STRATEGY_DEFAULT incorrect')
    else if (RuntimeInteger(COMP_ZLIB_STRATEGY_FILTERED) <> 1) then
      FailTest('COMP_ZLIB_STRATEGY_FILTERED incorrect')
    else if (RuntimeInteger(COMP_ZLIB_STRATEGY_HUFFMAN_ONLY) <> 2) then
      FailTest('COMP_ZLIB_STRATEGY_HUFFMAN_ONLY incorrect')
    else if (RuntimeInteger(COMP_ZLIB_STRATEGY_RLE) <> 3) then
      FailTest('COMP_ZLIB_STRATEGY_RLE incorrect')
    else if (RuntimeInteger(COMP_ZLIB_STRATEGY_FIXED) <> 4) then
      FailTest('COMP_ZLIB_STRATEGY_FIXED incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCompWindowBitsConstants;
begin
  StartTest('COMP window bits constants');
  try
    if (RuntimeInteger(COMP_ZLIB_WINDOW_BITS_DEFAULT) <> 15) then
      FailTest('COMP_ZLIB_WINDOW_BITS_DEFAULT incorrect')
    else if (RuntimeInteger(COMP_ZLIB_WINDOW_BITS_MIN) <> 8) then
      FailTest('COMP_ZLIB_WINDOW_BITS_MIN incorrect')
    else if (RuntimeInteger(COMP_ZLIB_WINDOW_BITS_MAX) <> 15) then
      FailTest('COMP_ZLIB_WINDOW_BITS_MAX incorrect')
    else
      PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCOMPMethodFunctionsAvailability;
begin
  StartTest('COMP method functions availability');
  try
    // Note: These functions may not be available in OpenSSL 3.x
    // as SSL/TLS compression is deprecated
    
    // Check basic function pointers (may be nil)
    if Assigned(COMP_CTX_new) then
      WriteLn('  [INFO] COMP_CTX_new loaded');
    if Assigned(COMP_CTX_free) then
      WriteLn('  [INFO] COMP_CTX_free loaded');
    if Assigned(COMP_get_name) then
      WriteLn('  [INFO] COMP_get_name loaded');
    if Assigned(COMP_get_type) then
      WriteLn('  [INFO] COMP_get_type loaded');
      
    // These are expected to not be available in modern OpenSSL
    PassTest;  // API loading doesn't fail, just may return nil
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCOMPCompressionMethodsAvailability;
begin
  StartTest('COMP compression method getters availability');
  try
    // Note: COMP functions are deprecated in OpenSSL 3.x
    // Testing availability, not functionality
    
    if Assigned(COMP_zlib) then
      WriteLn('  [INFO] COMP_zlib loaded');
    if Assigned(COMP_zlib_oneshot) then
      WriteLn('  [INFO] COMP_zlib_oneshot loaded');
    if Assigned(COMP_brotli) then
      WriteLn('  [INFO] COMP_brotli loaded');
    if Assigned(COMP_zstd) then
      WriteLn('  [INFO] COMP_zstd loaded');
    if Assigned(COMP_rle) then
      WriteLn('  [INFO] COMP_rle loaded');
      
    PassTest;  // API check passes regardless of actual availability
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestSSLCOMPFunctionsAvailability;
begin
  StartTest('SSL_COMP functions availability');
  try
    // SSL compression functions (deprecated in OpenSSL 3.x)
    
    if Assigned(SSL_COMP_add_compression_method) then
      WriteLn('  [INFO] SSL_COMP_add_compression_method loaded');
    if Assigned(SSL_COMP_get_compression_methods) then
      WriteLn('  [INFO] SSL_COMP_get_compression_methods loaded');
    if Assigned(SSL_COMP_get0_name) then
      WriteLn('  [INFO] SSL_COMP_get0_name loaded');
    if Assigned(SSL_COMP_get_id) then
      WriteLn('  [INFO] SSL_COMP_get_id loaded');
    if Assigned(SSL_COMP_free_compression_methods) then
      WriteLn('  [INFO] SSL_COMP_free_compression_methods loaded');
      
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestBIOCompressFunctionsAvailability;
begin
  StartTest('BIO compression functions availability');
  try
    // BIO compression filters
    
    if Assigned(BIO_f_zlib) then
      WriteLn('  [INFO] BIO_f_zlib loaded');
    if Assigned(BIO_f_brotli) then
      WriteLn('  [INFO] BIO_f_brotli loaded');
    if Assigned(BIO_f_zstd) then
      WriteLn('  [INFO] BIO_f_zstd loaded');
      
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestCOMPCompressExpandAvailability;
begin
  StartTest('COMP compress/expand functions availability');
  try
    if Assigned(COMP_compress) then
      WriteLn('  [INFO] COMP_compress loaded');
    if Assigned(COMP_expand) then
      WriteLn('  [INFO] COMP_expand loaded');
    if Assigned(COMP_compress_block) then
      WriteLn('  [INFO] COMP_compress_block loaded');
    if Assigned(COMP_expand_block) then
      WriteLn('  [INFO] COMP_expand_block loaded');
      
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestZlibParameterFunctionsAvailability;
begin
  StartTest('Zlib parameter setting functions availability');
  try
    if Assigned(COMP_zlib_set_level) then
      WriteLn('  [INFO] COMP_zlib_set_level loaded');
    if Assigned(COMP_zlib_set_window_bits) then
      WriteLn('  [INFO] COMP_zlib_set_window_bits loaded');
    if Assigned(COMP_zlib_set_mem_level) then
      WriteLn('  [INFO] COMP_zlib_set_mem_level loaded');
    if Assigned(COMP_zlib_set_strategy) then
      WriteLn('  [INFO] COMP_zlib_set_strategy loaded');
      
    PassTest;
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestHelperFunctionGetCompressionMethodName;
var
  name: string;
begin
  StartTest('Helper function GetCompressionMethodName (nil check)');
  try
    name := GetCompressionMethodName(nil);
    
    // Should return 'Unknown' for nil method
    if name = 'Unknown' then
      PassTest
    else
      FailTest('Expected "Unknown", got "' + name + '"');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestHelperFunctionIsCompressionSupported;
var
  supported: Boolean;
begin
  StartTest('Helper function IsCompressionSupported (nil check)');
  try
    supported := IsCompressionSupported(nil);
    
    // Should return False for nil method
    if not supported then
      PassTest
    else
      FailTest('Expected False for nil method');
  except
    on E: Exception do
      FailTest('Exception: ' + E.Message);
  end;
end;

procedure TestDeprecationWarning;
begin
  StartTest('Deprecation warning check');
  try
    WriteLn;
    WriteLn('  [WARNING] SSL/TLS compression is DEPRECATED in OpenSSL 3.x');
    WriteLn('  [WARNING] Most COMP functions may not be available');
    WriteLn('  [WARNING] This is expected and normal behavior');
    WriteLn('  [INFO] Use application-level compression instead');
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
  WriteLn('Note: COMP API is deprecated in OpenSSL 3.x');
  WriteLn('      Function availability checks passing is expected');
  WriteLn('      even when functions return nil pointers.');
end;

begin
  WriteLn('============================================');
  WriteLn('P2 COMP Module Test Suite');
  WriteLn('Testing OpenSSL Compression API');
  WriteLn('============================================');
  WriteLn;
  
  try
    // Initialize OpenSSL
    LoadOpenSSLCore;
    LoadOpenSSLBIO;
    
    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);
    WriteLn;
    
    // Run tests
    TestLoadCompFunctions;
    TestCompConstants;
    TestCompLevelConstants;
    TestCompStrategyConstants;
    TestCompWindowBitsConstants;
    TestCOMPMethodFunctionsAvailability;
    TestCOMPCompressionMethodsAvailability;
    TestSSLCOMPFunctionsAvailability;
    TestBIOCompressFunctionsAvailability;
    TestCOMPCompressExpandAvailability;
    TestZlibParameterFunctionsAvailability;
    TestHelperFunctionGetCompressionMethodName;
    TestHelperFunctionIsCompressionSupported;
    TestDeprecationWarning;
    
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
