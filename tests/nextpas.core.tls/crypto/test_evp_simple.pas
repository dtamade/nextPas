program test_evp_simple;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils,
  DynLibs,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp;

// Helper function to convert bytes to hex string
function BytesToHex(const Data: array of Byte): string;
var
  i: Integer;
begin
  Result := '';
  for i := Low(Data) to High(Data) do
    Result := Result + IntToHex(Data[i], 2);
end;

// Test simple AES-128-CBC encryption/decryption
procedure TestAES128CBC;
const
  TestKey: array[0..15] of Byte = (
    $2b, $7e, $15, $16, $28, $ae, $d2, $a6, $ab, $f7, $15, $88, $09, $cf, $4f, $3c
  );
  TestIV: array[0..15] of Byte = (
    $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
  );
  TestPlaintext: AnsiString = 'Hello, World!';
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  ciphertext: array[0..1023] of Byte;
  plaintext: array[0..1023] of Byte;
  outlen, tmplen: Integer;
  TotalLen: Integer;
  success: Boolean;
begin
  WriteLn('Testing AES-128-CBC...');
  success := False;
  
  try
    // Check if EVP functions are loaded
    if not Assigned(EVP_aes_128_cbc) then
    begin
      WriteLn('  [-] EVP_aes_128_cbc not loaded!');
      Exit;
    end;
    if not Assigned(EVP_CIPHER_CTX_new) then
    begin
      WriteLn('  [-] EVP_CIPHER_CTX_new not loaded!');
      Exit;
    end;
    if not Assigned(EVP_EncryptInit_ex) then
    begin
      WriteLn('  [-] EVP_EncryptInit_ex not loaded!');
      Exit;
    end;
    
    // Get cipher
    cipher := EVP_aes_128_cbc();
    if not Assigned(cipher) then
    begin
      WriteLn('  [-] Failed to get cipher');
      Exit;
    end;
    WriteLn('  [+] Cipher obtained');
    
    // === ENCRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create context');
      Exit;
    end;
    
    try
      if EVP_EncryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to init encryption');
        Exit;
      end;
      
      outlen := 0;
      if EVP_EncryptUpdate(ctx, @ciphertext[0], outlen,
         PByte(TestPlaintext), Length(TestPlaintext)) <> 1 then
      begin
        WriteLn('  [-] Failed to encrypt');
        Exit;
      end;
      
      tmplen := 0;
      if EVP_EncryptFinal_ex(ctx, @ciphertext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize encryption');
        Exit;
      end;
      
      TotalLen := outlen + tmplen;
      WriteLn('  [+] Encrypted ', TotalLen, ' bytes');
      Write('      Ciphertext: ');
      for tmplen := 0 to TotalLen - 1 do
        Write(IntToHex(ciphertext[tmplen], 2));
      WriteLn;
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
    // === DECRYPTION ===
    ctx := EVP_CIPHER_CTX_new();
    if not Assigned(ctx) then
    begin
      WriteLn('  [-] Failed to create decrypt context');
      Exit;
    end;
    
    try
      if EVP_DecryptInit_ex(ctx, cipher, nil, @TestKey[0], @TestIV[0]) <> 1 then
      begin
        WriteLn('  [-] Failed to init decryption');
        Exit;
      end;
      
      outlen := 0;
      if EVP_DecryptUpdate(ctx, @plaintext[0], outlen,
         @ciphertext[0], TotalLen) <> 1 then
      begin
        WriteLn('  [-] Failed to decrypt');
        Exit;
      end;
      
      tmplen := 0;
      if EVP_DecryptFinal_ex(ctx, @plaintext[outlen], tmplen) <> 1 then
      begin
        WriteLn('  [-] Failed to finalize decryption');
        Exit;
      end;
      
      TotalLen := outlen + tmplen;
      
      // Verify
      if CompareMem(@plaintext[0], PByte(TestPlaintext), Length(TestPlaintext)) then
      begin
        WriteLn('  [+] Decrypted successfully');
        WriteLn('      Plaintext: ', PAnsiChar(@plaintext[0]));
        success := True;
      end
      else
        WriteLn('  [-] Decryption mismatch');
      
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
    
  finally
    if success then
      WriteLn('  ✅ Test PASSED')
    else
      WriteLn('  ❌ Test FAILED');
  end;
  WriteLn;
end;

var
  LCryptoLib: TLibHandle;
  
begin
  WriteLn('========================================');
  WriteLn('Simple EVP Cipher Test');
  WriteLn('========================================');
  WriteLn;
  
  // Initialize OpenSSL
  try
    if not LoadOpenSSLLibrary then
      raise Exception.Create('Failed to load OpenSSL library');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: Failed to load OpenSSL!');
      WriteLn('Message: ', E.Message);
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL loaded successfully!');
  
  // Load libcrypto for EVP functions
  {$IFDEF MSWINDOWS}
  LCryptoLib := LoadLibrary('libcrypto-3-x64.dll');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto-3.dll');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto.dll');
  {$ELSE}
  LCryptoLib := LoadLibrary('libcrypto.so.3');
  if LCryptoLib = NilHandle then
    LCryptoLib := LoadLibrary('libcrypto.so');
  {$ENDIF}
  
  if LCryptoLib = NilHandle then
  begin
    WriteLn('ERROR: Failed to load libcrypto!');
    Halt(1);
  end;
  
  WriteLn('libcrypto loaded');
  
  // Load EVP module
  if not LoadEVP(LCryptoLib) then
  begin
    WriteLn('ERROR: Failed to load EVP module!');
    FreeLibrary(LCryptoLib);
    Halt(1);
  end;
  
  WriteLn('EVP module loaded successfully!');
  WriteLn;
  WriteLn;
  
  // Run test
  TestAES128CBC;
  
  WriteLn('========================================');
  WriteLn('Test completed!');
  WriteLn('========================================');
end.
