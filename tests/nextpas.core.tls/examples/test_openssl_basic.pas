program test_openssl_basic;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes,
  // Core units
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.rand;

procedure TestOpenSSLInitialization;
begin
  WriteLn('=== Testing OpenSSL Initialization ===');
  WriteLn;
  
  // Load OpenSSL library
  WriteLn('Loading OpenSSL libraries...');
  if LoadOpenSSL then
  begin
    WriteLn('OpenSSL loaded successfully!');
    WriteLn('Version: ', GetOpenSSLVersionText);
    WriteLn('Version Number: ', Format('0x%x', [GetOpenSSLVersionNumber]));
    WriteLn;
  end
  else
  begin
    WriteLn('Failed to load OpenSSL!');
    Exit;
  end;
end;

procedure TestCryptoFunctions;
var
  Buffer: array[0..31] of Byte;
  HashResult: array[0..31] of Byte;
  I: Integer;
begin
  WriteLn('=== Testing Basic Crypto Functions ===');
  WriteLn;
  
  // Test random generation
  Write('Testing random generation... ');
  if RAND_bytes(@Buffer[0], Length(Buffer)) = 1 then
  begin
    WriteLn('OK');
    Write('Random bytes: ');
    for I := 0 to 15 do
      Write(Format('%.2x', [Buffer[I]]));
    WriteLn('...');
  end
  else
    WriteLn('FAILED');
    
  WriteLn;
end;

procedure TestEVPFunctions;
var
  Ctx: PEVP_MD_CTX;
  MD: PEVP_MD;
  Data: AnsiString;
  Digest: array[0..63] of Byte;
  DigestLen: Cardinal;
  I: Integer;
begin
  WriteLn('=== Testing EVP Functions ===');
  WriteLn;
  
  // Test EVP hash
  Data := 'Hello, OpenSSL!';
  MD := EVP_sha256;
  
  if Assigned(MD) then
  begin
    WriteLn('SHA256 digest available');
    Ctx := EVP_MD_CTX_new;
    
    if Assigned(Ctx) then
    begin
      if EVP_DigestInit_ex(Ctx, MD, nil) = 1 then
      begin
        if EVP_DigestUpdate(Ctx, PAnsiChar(Data), Length(Data)) = 1 then
        begin
          DigestLen := SizeOf(Digest);
          if EVP_DigestFinal_ex(Ctx, @Digest[0], @DigestLen) = 1 then
          begin
            Write('SHA256 of "', Data, '": ');
            for I := 0 to DigestLen - 1 do
              Write(Format('%.2x', [Digest[I]]));
            WriteLn;
          end
          else
            WriteLn('DigestFinal failed');
        end
        else
          WriteLn('DigestUpdate failed');
      end
      else
        WriteLn('DigestInit failed');
        
      EVP_MD_CTX_free(Ctx);
    end
    else
      WriteLn('Failed to create MD context');
  end
  else
    WriteLn('SHA256 not available');
    
  WriteLn;
end;

procedure TestErrorHandling;
var
  ErrorCode: Cardinal;
  ErrorStr: array[0..255] of AnsiChar;
begin
  WriteLn('=== Testing Error Handling ===');
  WriteLn;
  
  // Clear error stack
  ERR_clear_error;
  
  // Generate an error (intentionally)
  EVP_DigestInit_ex(nil, nil, nil);
  
  // Get last error
  ErrorCode := ERR_get_error;
  if ErrorCode <> 0 then
  begin
    WriteLn('Error code: ', Format('0x%x', [ErrorCode]));
    ERR_error_string(ErrorCode, @ErrorStr[0]);
    WriteLn('Error string: ', ErrorStr);
  end
  else
    WriteLn('No error in queue');
    
  WriteLn;
end;

begin
  try
    WriteLn('OpenSSL Basic Test Program');
    WriteLn('==========================');
    WriteLn;
    
    TestOpenSSLInitialization;
    TestCryptoFunctions;
    TestEVPFunctions;
    TestErrorHandling;
    
    // Clean up
    UnloadOpenSSL;
    WriteLn('OpenSSL unloaded.');
    
    WriteLn;
    WriteLn('All tests completed!');
  except
    on E: Exception do
    begin
      WriteLn('Exception: ', E.Message);
      Exit;
    end;
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.