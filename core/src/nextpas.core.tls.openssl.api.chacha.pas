unit nextpas.core.tls.openssl.api.chacha;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.exceptions, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.loader;

const
  CHACHA20_KEY_SIZE = 32;
  CHACHA20_IV_SIZE = 12;  // 96-bit nonce
  CHACHA20_BLOCK_SIZE = 64;
  CHACHA20_COUNTER_SIZE = 16;  
  
  POLY1305_KEY_SIZE = 32;
  POLY1305_TAG_SIZE = 16;
  POLY1305_BLOCK_SIZE = 16;

type
  // ChaCha20 context
  chacha20_ctx = record
    key: array[0..CHACHA20_KEY_SIZE-1] of Byte;
    counter: array[0..CHACHA20_COUNTER_SIZE-1] of Byte;
    partial_len: size_t;
    buffer: array[0..CHACHA20_BLOCK_SIZE-1] of Byte;
  end;
  Pchacha20_ctx = ^chacha20_ctx;

  // Poly1305 context
  poly1305_state = record
    opaque_state: array[0..255] of Byte; // Opaque internal state
  end;
  Ppoly1305_state = ^poly1305_state;
  
  // ChaCha20-Poly1305 AEAD tag
  TChaCha20Poly1305Tag = array[0..POLY1305_TAG_SIZE-1] of Byte;
  
  // Function pointer types for ChaCha20
  TChaCha_set_key = procedure(ctx: Pchacha20_ctx; const key: PByte; keylen: Cardinal); cdecl;
  TChaCha_set_iv = procedure(ctx: Pchacha20_ctx; const iv: PByte; counter: PByte); cdecl;
  TChaCha_cipher = procedure(ctx: Pchacha20_ctx; out_data: PByte; const in_data: PByte; len: size_t); cdecl;
  TChaCha20_cbc_encrypt = procedure(const inp: PByte; outp: PByte; len: size_t;
                                    const key: PByte; iv: PByte; enc: Integer); cdecl;

  // Function pointer types for Poly1305
  TPoly1305_Init = function(ctx: Ppoly1305_state; const key: PByte): Integer; cdecl;
  TPoly1305_Update = function(ctx: Ppoly1305_state; const inp: PByte; len: size_t): Integer; cdecl;
  TPoly1305_Final = function(ctx: Ppoly1305_state; mac: PByte): Integer; cdecl;
  TPoly1305 = function(tag: PByte; const msg: PByte; msg_len: size_t; const key: PByte): Integer; cdecl;

  // Function pointer types for ChaCha20-Poly1305 AEAD  
  TEVP_chacha20 = function: PEVP_CIPHER; cdecl;
  TEVP_chacha20_poly1305 = function: PEVP_CIPHER; cdecl;

  // AEAD helper functions
  TChaCha20Poly1305_encrypt = function(const plaintext: PByte; plaintext_len: size_t;
                                      const aad: PByte; aad_len: size_t;
                                      const key: PByte; const iv: PByte;
                                      ciphertext: PByte; tag: PByte): Integer; cdecl;
                                       
  TChaCha20Poly1305_decrypt = function(const ciphertext: PByte; ciphertext_len: size_t;
                                      const aad: PByte; aad_len: size_t;
                                      const tag: PByte; const key: PByte; const iv: PByte;
                                      plaintext: PByte): Integer; cdecl;

var
  // ChaCha20 functions
  ChaCha_set_key: TChaCha_set_key = nil;
  ChaCha_set_iv: TChaCha_set_iv = nil;
  ChaCha_cipher: TChaCha_cipher = nil;
  ChaCha20_cbc_encrypt: TChaCha20_cbc_encrypt = nil;

  // Poly1305 functions  
  Poly1305_Init: TPoly1305_Init = nil;
  Poly1305_Update: TPoly1305_Update = nil;
  Poly1305_Final: TPoly1305_Final = nil;
  Poly1305: TPoly1305 = nil;
  
  // EVP ChaCha20/Poly1305
  EVP_chacha20: TEVP_chacha20 = nil;
  EVP_chacha20_poly1305: TEVP_chacha20_poly1305 = nil;
  
  // AEAD helpers
  ChaCha20Poly1305_encrypt: TChaCha20Poly1305_encrypt = nil;
  ChaCha20Poly1305_decrypt: TChaCha20Poly1305_decrypt = nil;

// Load and unload functions
function LoadChaChaFunctions: Boolean;
procedure UnloadChaChaFunctions;

// High-level helper functions
function ChaCha20Encrypt(const Key: TBytes; const IV: TBytes; const Plaintext: TBytes): TBytes;
function ChaCha20Decrypt(const Key: TBytes; const IV: TBytes; const Ciphertext: TBytes): TBytes;

function ChaCha20Poly1305AEADEncrypt(const Key, Nonce, Plaintext, AAD: TBytes; var AuthTag: TChaCha20Poly1305Tag): TBytes;

function ChaCha20Poly1305AEADDecrypt(const Key, Nonce, Ciphertext, AAD: TBytes; const AuthTag: TChaCha20Poly1305Tag): TBytes;

function Poly1305MAC(const Key: TBytes; const Message: TBytes): TBytes;

implementation


function LoadChaChaFunctions: Boolean;
var
  LHandle: TLibHandle;
begin
  Result := False;

  // Phase 3.3 P0+ - 使用统一的动态库加载器（替换 ~20 行重复代码）
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle = 0 then
    Exit;
    
  // Load ChaCha20 functions (may not be available in older OpenSSL)
  ChaCha_set_key := TChaCha_set_key(TOpenSSLLoader.GetFunction(LHandle, 'ChaCha_set_key'));
  ChaCha_set_iv := TChaCha_set_iv(TOpenSSLLoader.GetFunction(LHandle, 'ChaCha_set_iv'));
  ChaCha_cipher := TChaCha_cipher(TOpenSSLLoader.GetFunction(LHandle, 'ChaCha_cipher'));
  ChaCha20_cbc_encrypt := TChaCha20_cbc_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'ChaCha20_cbc_encrypt'));
  
  // Load Poly1305 functions
  Poly1305_Init := TPoly1305_Init(TOpenSSLLoader.GetFunction(LHandle, 'Poly1305_Init'));
  Poly1305_Update := TPoly1305_Update(TOpenSSLLoader.GetFunction(LHandle, 'Poly1305_Update'));
  Poly1305_Final := TPoly1305_Final(TOpenSSLLoader.GetFunction(LHandle, 'Poly1305_Final'));
  Poly1305 := TPoly1305(TOpenSSLLoader.GetFunction(LHandle, 'Poly1305'));
  
  // Load EVP ChaCha20/Poly1305 (preferred method)
  EVP_chacha20 := TEVP_chacha20(TOpenSSLLoader.GetFunction(LHandle, 'EVP_chacha20'));
  EVP_chacha20_poly1305 := TEVP_chacha20_poly1305(TOpenSSLLoader.GetFunction(LHandle, 'EVP_chacha20_poly1305'));
  
  // Note: High-level AEAD helpers may not exist as direct exports
  ChaCha20Poly1305_encrypt := TChaCha20Poly1305_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'ChaCha20Poly1305_encrypt'));
  ChaCha20Poly1305_decrypt := TChaCha20Poly1305_decrypt(TOpenSSLLoader.GetFunction(LHandle, 'ChaCha20Poly1305_decrypt'));
  
  // Check if at least EVP functions are available
  TOpenSSLLoader.SetModuleLoaded(osmChaCha, Assigned(EVP_chacha20) or Assigned(ChaCha_cipher));
  Result := TOpenSSLLoader.IsModuleLoaded(osmChaCha);
end;

procedure UnloadChaChaFunctions;
begin
  ChaCha_set_key := nil;
  ChaCha_set_iv := nil;
  ChaCha_cipher := nil;
  ChaCha20_cbc_encrypt := nil;
  
  Poly1305_Init := nil;
  Poly1305_Update := nil;
  Poly1305_Final := nil;
  Poly1305 := nil;
  
  EVP_chacha20 := nil;
  EVP_chacha20_poly1305 := nil;
  ChaCha20Poly1305_encrypt := nil;
  ChaCha20Poly1305_decrypt := nil;

  TOpenSSLLoader.SetModuleLoaded(osmChaCha, False);

  // 注意: 库卸载由 TOpenSSLLoader 自动处理（在 finalization 部分）
end;


// High-level helper functions implementation

function ChaCha20Encrypt(const Key: TBytes; const IV: TBytes; const Plaintext: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  outlen, finlen: Integer;
begin
  Result := nil;
  if not Assigned(EVP_chacha20) then
    raise ESSLCryptoError.Create('ChaCha20 not available');
    
  if Length(Key) <> CHACHA20_KEY_SIZE then
    raise ESSLInvalidArgument.Create('Invalid key size for ChaCha20');
    
  if Length(IV) <> CHACHA20_IV_SIZE then
    raise ESSLInvalidArgument.Create('Invalid IV size for ChaCha20');
  
  SetLength(Result, Length(Plaintext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    if EVP_EncryptInit_ex(ctx, EVP_chacha20(), nil, @Key[0], @IV[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize ChaCha20 encryption');
      
    if EVP_EncryptUpdate(ctx, @Result[0], @outlen, @Plaintext[0], Length(Plaintext)) <> 1 then
      raise ESSLEncryptionException.Create('Failed to encrypt with ChaCha20');
      
    if EVP_EncryptFinal_ex(ctx, @Result[outlen], @finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize ChaCha20 encryption');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function ChaCha20Decrypt(const Key: TBytes; const IV: TBytes; const Ciphertext: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  outlen, finlen: Integer;
begin
  Result := nil;
  if not Assigned(EVP_chacha20) then
    raise ESSLCryptoError.Create('ChaCha20 not available');
    
  if Length(Key) <> CHACHA20_KEY_SIZE then
    raise ESSLInvalidArgument.Create('Invalid key size for ChaCha20');
    
  if Length(IV) <> CHACHA20_IV_SIZE then
    raise ESSLInvalidArgument.Create('Invalid IV size for ChaCha20');
  
  SetLength(Result, Length(Ciphertext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    if EVP_DecryptInit_ex(ctx, EVP_chacha20(), nil, @Key[0], @IV[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize ChaCha20 decryption');
      
    if EVP_DecryptUpdate(ctx, @Result[0], @outlen, @Ciphertext[0], Length(Ciphertext)) <> 1 then
      raise ESSLDecryptionException.Create('Failed to decrypt with ChaCha20');
      
    if EVP_DecryptFinal_ex(ctx, @Result[outlen], @finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize ChaCha20 decryption');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function ChaCha20Poly1305AEADEncrypt(const Key, Nonce, Plaintext, AAD: TBytes; var AuthTag: TChaCha20Poly1305Tag): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  outlen, finlen: Integer;
begin
  Result := nil;
  if not Assigned(EVP_chacha20_poly1305) then
    raise ESSLCryptoError.Create('ChaCha20-Poly1305 not available');
    
  if Length(Key) <> CHACHA20_KEY_SIZE then
    raise ESSLInvalidArgument.Create('Invalid key size for ChaCha20-Poly1305');
    
  if Length(Nonce) <> CHACHA20_IV_SIZE then
    raise ESSLInvalidArgument.Create('Invalid nonce size for ChaCha20-Poly1305');
  
  SetLength(Result, Length(Plaintext));
  FillChar(AuthTag, SizeOf(AuthTag), 0);
  
  ctx := EVP_CIPHER_CTX_new();
  try
    if EVP_EncryptInit_ex(ctx, EVP_chacha20_poly1305(), nil, @Key[0], @Nonce[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize ChaCha20-Poly1305 encryption');
    
    // Set AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_EncryptUpdate(ctx, nil, @outlen, @AAD[0], Length(AAD)) <> 1 then
        raise ESSLCryptoError.Create('Failed to set AAD');
    end;
    
    // Encrypt plaintext
    if EVP_EncryptUpdate(ctx, @Result[0], @outlen, @Plaintext[0], Length(Plaintext)) <> 1 then
      raise ESSLEncryptionException.Create('Failed to encrypt with ChaCha20-Poly1305');
      
    if EVP_EncryptFinal_ex(ctx, @Result[outlen], @finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize ChaCha20-Poly1305 encryption');
      
    SetLength(Result, outlen + finlen);
    
    // Get tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, POLY1305_TAG_SIZE, @AuthTag) <> 1 then
      raise ESSLCryptoError.Create('Failed to get authentication tag');
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function ChaCha20Poly1305AEADDecrypt(const Key, Nonce, Ciphertext, AAD: TBytes; const AuthTag: TChaCha20Poly1305Tag): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  outlen, finlen: Integer;
begin
  Result := nil;
  if not Assigned(EVP_chacha20_poly1305) then
    raise ESSLCryptoError.Create('ChaCha20-Poly1305 not available');
    
  if Length(Key) <> CHACHA20_KEY_SIZE then
    raise ESSLInvalidArgument.Create('Invalid key size for ChaCha20-Poly1305');
    
  if Length(Nonce) <> CHACHA20_IV_SIZE then
    raise ESSLInvalidArgument.Create('Invalid nonce size for ChaCha20-Poly1305');
  
  SetLength(Result, Length(Ciphertext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    if EVP_DecryptInit_ex(ctx, EVP_chacha20_poly1305(), nil, @Key[0], @Nonce[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize ChaCha20-Poly1305 decryption');
    
    // Set AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_DecryptUpdate(ctx, nil, @outlen, @AAD[0], Length(AAD)) <> 1 then
        raise ESSLCryptoError.Create('Failed to set AAD');
    end;
    
    // Decrypt ciphertext
    if EVP_DecryptUpdate(ctx, @Result[0], @outlen, @Ciphertext[0], Length(Ciphertext)) <> 1 then
      raise ESSLDecryptionException.Create('Failed to decrypt with ChaCha20-Poly1305');
    
    // Set expected tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, POLY1305_TAG_SIZE, @AuthTag) <> 1 then
      raise ESSLCryptoError.Create('Failed to set authentication tag');
      
    // Verify tag and finalize
    if EVP_DecryptFinal_ex(ctx, @Result[outlen], @finlen) <> 1 then
      raise ESSLDecryptionException.Create('Authentication verification failed');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function Poly1305MAC(const Key: TBytes; const Message: TBytes): TBytes;
var
  ctx: poly1305_state;
begin
  Result := nil;
  if not Assigned(Poly1305) then
    raise ESSLCryptoError.Create('Poly1305 not available');
    
  if Length(Key) <> POLY1305_KEY_SIZE then
    raise ESSLInvalidArgument.Create('Invalid key size for Poly1305');
  
  SetLength(Result, POLY1305_TAG_SIZE);
  
  if Poly1305(@Result[0], @Message[0], Length(Message), @Key[0]) <> 1 then
    raise ESSLCryptoError.Create('Poly1305 MAC computation failed');
end;

initialization
  
finalization
  UnloadChaChaFunctions;
  
end.