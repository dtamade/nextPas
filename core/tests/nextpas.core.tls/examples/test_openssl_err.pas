program test_openssl_err;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.err;

procedure TestErrorHandling;
var
  ErrorCode: Cardinal;
  ErrorStr: string;
  I: Integer;
begin
  WriteLn('Testing OpenSSL Error Handling');
  WriteLn('------------------------------');
  WriteLn;
  
  // Load ERR module
  Write('Loading ERR module... ');
  if not LoadOpenSSLERR then
  begin
    WriteLn('FAILED!');
    Exit;
  end;
  WriteLn('OK');
  WriteLn;
  
  // Clear any existing errors
  WriteLn('Clearing error queue...');
  if Assigned(ERR_clear_error) then
  begin
    ERR_clear_error();
    WriteLn('Error queue cleared.');
  end
  else
    WriteLn('ERR_clear_error not available');
  WriteLn;
  
  // Check if there are any errors in the queue
  if Assigned(ERR_peek_error) then
  begin
    ErrorCode := ERR_peek_error();
    if ErrorCode = 0 then
      WriteLn('Error queue is empty (as expected).')
    else
      WriteLn('Warning: Error queue has errors: ', IntToHex(ErrorCode, 8));
  end
  else
    WriteLn('ERR_peek_error not available');
  WriteLn;
  
  // Print some error code information
  WriteLn('OpenSSL Error Library Codes:');
  WriteLn('  ERR_LIB_NONE    = ', ERR_LIB_NONE);
  WriteLn('  ERR_LIB_SYS     = ', ERR_LIB_SYS);
  WriteLn('  ERR_LIB_BN      = ', ERR_LIB_BN);
  WriteLn('  ERR_LIB_RSA     = ', ERR_LIB_RSA);
  WriteLn('  ERR_LIB_EVP     = ', ERR_LIB_EVP);
  WriteLn('  ERR_LIB_SSL     = ', ERR_LIB_SSL);
  WriteLn;
  
  // Test error packing/unpacking
  WriteLn('Testing error packing/unpacking:');
  ErrorCode := ERR_PACK_INLINE(ERR_LIB_SSL, 0, 100);
  WriteLn('  Packed error (lib=SSL, reason=100): $', IntToHex(ErrorCode, 8));
  WriteLn('  Library:  ', ERR_GET_LIB_INLINE(ErrorCode));
  WriteLn('  Function: ', ERR_GET_FUNC_INLINE(ErrorCode));
  WriteLn('  Reason:   ', ERR_GET_REASON_INLINE(ErrorCode));
  WriteLn;
  
  // Cleanup
  UnloadOpenSSLERR;
  WriteLn('Test completed successfully.');
end;

begin
  WriteLn('OpenSSL Error Module Test');
  WriteLn('=========================');
  WriteLn;
  
  // Load OpenSSL core
  Write('Loading OpenSSL libraries... ');
  try
    LoadOpenSSLCore;
    WriteLn('OK');
  except
    on E: Exception do
    begin
      WriteLn('FAILED!');
      WriteLn('Error: ', E.Message);
      Exit;
    end;
  end;
  
  WriteLn('OpenSSL version: ', OpenSSL_version(0));
  WriteLn;
  
  // Run tests
  TestErrorHandling;
  
  // Cleanup
  UnloadOpenSSLCore;
end.