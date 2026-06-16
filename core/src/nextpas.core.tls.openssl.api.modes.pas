unit nextpas.core.tls.openssl.api.modes;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.exceptions, nextpas.core.tls.errors, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.evp;

const
  // GCM constants
  GCM_BLOCK_SIZE = 16;
  GCM_IV_SIZE = 12;
  GCM_TAG_SIZE = 16;
  
  // CCM constants
  CCM_BLOCK_SIZE = 16;
  CCM_MIN_TAG_SIZE = 4;
  CCM_MAX_TAG_SIZE = 16;
  
  // XTS constants
  XTS_BLOCK_SIZE = 16;
  
  // OCB constants
  OCB_BLOCK_SIZE = 16;
  OCB_TAG_SIZE = 16;

  // EVP control commands for AEAD modes
  EVP_CTRL_AEAD_SET_IVLEN = $9;
  EVP_CTRL_AEAD_GET_TAG = $10;
  EVP_CTRL_AEAD_SET_TAG = $11;
  EVP_CTRL_CCM_SET_L = $14;
  EVP_CTRL_CCM_SET_MSGLEN = $15;
  EVP_CTRL_AEAD_SET_IV_FIXED = $12;
  
  // GCM specific
  EVP_CTRL_GCM_SET_IVLEN = $9;
  EVP_CTRL_GCM_GET_TAG = $10;
  EVP_CTRL_GCM_SET_TAG = $11;
  EVP_CTRL_GCM_SET_IV_FIXED = $12;
  EVP_CTRL_GCM_IV_GEN = $13;
  
  // CCM specific  
  EVP_CTRL_CCM_GET_TAG = EVP_CTRL_AEAD_GET_TAG;
  EVP_CTRL_CCM_SET_TAG = EVP_CTRL_AEAD_SET_TAG;
  EVP_CTRL_CCM_SET_IVLEN = EVP_CTRL_AEAD_SET_IVLEN;
  
  // OCB specific
  EVP_CTRL_OCB_SET_TAGLEN = $1c;

type
  // GCM context (opaque)
  GCM128_CONTEXT = record
    opaque_data: array[0..511] of Byte;
  end;
  PGCM128_CONTEXT = ^GCM128_CONTEXT;
  
  // CCM context (opaque)
  CCM128_CONTEXT = record
    opaque_data: array[0..511] of Byte;
  end;
  PCCM128_CONTEXT = ^CCM128_CONTEXT;
  
  // XTS context
  XTS128_CONTEXT = record
    opaque_data: array[0..255] of Byte;
  end;
  PXTS128_CONTEXT = ^XTS128_CONTEXT;
  
  // OCB context
  OCB128_CONTEXT = record
    opaque_data: array[0..511] of Byte;
  end;
  POCB128_CONTEXT = ^OCB128_CONTEXT;
  
  // Block cipher function types
  Tblock128_f = procedure(const inp: PByte; outp: PByte; const key: Pointer); cdecl;
  Tctr128_f = procedure(const inp: PByte; outp: PByte; blocks: size_t; 
                      const key: Pointer; ivec: PByte); cdecl;
  Tccm128_f = procedure(const inp: PByte; outp: PByte; blocks: size_t;
                      const key: Pointer; ivec: PByte; cmac: PByte); cdecl;
  
  // GCM function pointer types
  TGCM128_new = function(key: Pointer; block: Tblock128_f): PGCM128_CONTEXT; cdecl;
  TGCM128_free = procedure(ctx: PGCM128_CONTEXT); cdecl;
  TGCM128_setiv = function(ctx: PGCM128_CONTEXT; const iv: PByte; len: size_t): Integer; cdecl;
  TGCM128_aad = function(ctx: PGCM128_CONTEXT; const aad: PByte; len: size_t): Integer; cdecl;
  TGCM128_encrypt = function(ctx: PGCM128_CONTEXT; const inp: PByte; outp: PByte; len: size_t): Integer; cdecl;
  TGCM128_decrypt = function(ctx: PGCM128_CONTEXT; const inp: PByte; outp: PByte; len: size_t): Integer; cdecl;
  TGCM128_finish = function(ctx: PGCM128_CONTEXT; const tag: PByte; len: size_t): Integer; cdecl;
  TGCM128_tag = procedure(ctx: PGCM128_CONTEXT; tag: PByte; len: size_t); cdecl;
  
  // CCM function pointer types
  TCCM128_new = function(key: Pointer; block: Tblock128_f): PCCM128_CONTEXT; cdecl;
  TCCM128_free = procedure(ctx: PCCM128_CONTEXT); cdecl;
  TCCM128_init = function(ctx: PCCM128_CONTEXT; M: Cardinal; L: Cardinal; key: Pointer; block: Tblock128_f): Integer; cdecl;
  TCCM128_setiv = function(ctx: PCCM128_CONTEXT; const nonce: PByte; nlen: size_t; mlen: size_t): Integer; cdecl;
  TCCM128_aad = function(ctx: PCCM128_CONTEXT; const aad: PByte; alen: size_t): Integer; cdecl;
  TCCM128_encrypt = function(ctx: PCCM128_CONTEXT; const inp: PByte; outp: PByte; len: size_t): Integer; cdecl;
  TCCM128_decrypt = function(ctx: PCCM128_CONTEXT; const inp: PByte; outp: PByte; len: size_t): Integer; cdecl;
  TCCM128_tag = function(ctx: PCCM128_CONTEXT; tag: PByte; len: size_t): size_t; cdecl;
  
  // XTS function pointer types
  TXTS128_encrypt = function(const ctx: PXTS128_CONTEXT; const iv: PByte;
                            const inp: PByte; outp: PByte; len: size_t; enc: Integer): Integer; cdecl;
  TXTS128_decrypt = function(const ctx: PXTS128_CONTEXT; const iv: PByte;
                            const inp: PByte; outp: PByte; len: size_t; enc: Integer): Integer; cdecl;
  
  // OCB function pointer types  
  TOCB128_new = function(keyenc: Pointer; keydec: Pointer; encrypt_block: Tblock128_f;
                        decrypt_block: Tblock128_f): POCB128_CONTEXT; cdecl;
  TOCB128_free = procedure(ctx: POCB128_CONTEXT); cdecl;
  TOCB128_init = function(ctx: POCB128_CONTEXT; keyenc: Pointer; keydec: Pointer;
                        encrypt_block: Tblock128_f; decrypt_block: Tblock128_f): Integer; cdecl;
  TOCB128_setiv = function(ctx: POCB128_CONTEXT; const iv: PByte; len: size_t; taglen: size_t): Integer; cdecl;
  TOCB128_aad = function(ctx: POCB128_CONTEXT; const aad: PByte; len: size_t): Integer; cdecl;
  TOCB128_encrypt = function(ctx: POCB128_CONTEXT; const inp: PByte; outp: PByte; len: size_t): Integer; cdecl;
  TOCB128_decrypt = function(ctx: POCB128_CONTEXT; const inp: PByte; outp: PByte; len: size_t): Integer; cdecl;
  TOCB128_finish = function(ctx: POCB128_CONTEXT; const tag: PByte; len: size_t): Integer; cdecl;
  TOCB128_tag = function(ctx: POCB128_CONTEXT; tag: PByte; len: size_t): Integer; cdecl;
  
  // WRAP mode functions
  TAES_wrap_key = function(key: Pointer; const iv: PByte; outp: PByte;
                          const inp: PByte; inlen: size_t): Integer; cdecl;
  TAES_unwrap_key = function(key: Pointer; const iv: PByte; outp: PByte;
                            const inp: PByte; inlen: size_t): Integer; cdecl;

var
  // GCM functions
  GCM128_new: TGCM128_new = nil;
  GCM128_free: TGCM128_free = nil;
  GCM128_setiv: TGCM128_setiv = nil;
  GCM128_aad: TGCM128_aad = nil;
  GCM128_encrypt: TGCM128_encrypt = nil;
  GCM128_decrypt: TGCM128_decrypt = nil;
  GCM128_finish: TGCM128_finish = nil;
  GCM128_tag: TGCM128_tag = nil;
  
  // CCM functions
  CCM128_new: TCCM128_new = nil;
  CCM128_free: TCCM128_free = nil;
  CCM128_init: TCCM128_init = nil;
  CCM128_setiv: TCCM128_setiv = nil;
  CCM128_aad: TCCM128_aad = nil;
  CCM128_encrypt: TCCM128_encrypt = nil;
  CCM128_decrypt: TCCM128_decrypt = nil;
  CCM128_tag: TCCM128_tag = nil;
  
  // XTS functions
  XTS128_encrypt: TXTS128_encrypt = nil;
  XTS128_decrypt: TXTS128_decrypt = nil;
  
  // OCB functions
  OCB128_new: TOCB128_new = nil;
  OCB128_free: TOCB128_free = nil;
  OCB128_init: TOCB128_init = nil;
  OCB128_setiv: TOCB128_setiv = nil;
  OCB128_aad: TOCB128_aad = nil;
  OCB128_encrypt: TOCB128_encrypt = nil;
  OCB128_decrypt: TOCB128_decrypt = nil;
  OCB128_finish: TOCB128_finish = nil;
  OCB128_tag: TOCB128_tag = nil;
  
  // WRAP functions
  AES_wrap_key: TAES_wrap_key = nil;
  AES_unwrap_key: TAES_unwrap_key = nil;

// Load and unload functions
function LoadModesFunctions: Boolean;
procedure UnloadModesFunctions;

// High-level helper functions for GCM
function AES_GCM_Encrypt(const Key: TBytes; const IV: TBytes; const AAD: TBytes;
                        const Plaintext: TBytes; out Tag: TBytes): TBytes;
function AES_GCM_Decrypt(const Key: TBytes; const IV: TBytes; const AAD: TBytes;
                        const Ciphertext: TBytes; const Tag: TBytes): TBytes;

// High-level helper functions for CCM
function AES_CCM_Encrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Plaintext: TBytes; TagSize: Integer; out Tag: TBytes): TBytes;
function AES_CCM_Decrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Ciphertext: TBytes; const Tag: TBytes): TBytes;

// High-level helper functions for XTS (disk encryption)
function AES_XTS_Encrypt(const Key1, Key2: TBytes; const Tweak: TBytes;
                        const Plaintext: TBytes): TBytes;
function AES_XTS_Decrypt(const Key1, Key2: TBytes; const Tweak: TBytes;
                        const Ciphertext: TBytes): TBytes;

// High-level helper functions for OCB
function AES_OCB_Encrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Plaintext: TBytes; out Tag: TBytes): TBytes;
function AES_OCB_Decrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Ciphertext: TBytes; const Tag: TBytes): TBytes;

// Key wrapping functions
function AES_WrapKey(const KEK: TBytes; const Plaintext: TBytes): TBytes;
function AES_UnwrapKey(const KEK: TBytes; const Ciphertext: TBytes): TBytes;

implementation


function LoadModesFunctions: Boolean;
var
  LHandle: TLibHandle;
begin
  Result := False;

  // Phase 3.3 P0+ - 使用统一的动态库加载器（替换 ~25 行重复代码）
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle = 0 then
    Exit;
    
  // Load GCM mode functions
  GCM128_new := TGCM128_new(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_new'));
  GCM128_free := TGCM128_free(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_release'));
  GCM128_setiv := TGCM128_setiv(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_setiv'));
  GCM128_aad := TGCM128_aad(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_aad'));
  GCM128_encrypt := TGCM128_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_encrypt'));
  GCM128_decrypt := TGCM128_decrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_decrypt'));
  GCM128_finish := TGCM128_finish(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_finish'));
  GCM128_tag := TGCM128_tag(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_gcm128_tag'));
  
  // Load CCM mode functions
  CCM128_new := TCCM128_new(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_new'));
  CCM128_free := TCCM128_free(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_release'));
  CCM128_init := TCCM128_init(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_init'));
  CCM128_setiv := TCCM128_setiv(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_setiv'));
  CCM128_aad := TCCM128_aad(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_aad'));
  CCM128_encrypt := TCCM128_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_encrypt'));
  CCM128_decrypt := TCCM128_decrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_decrypt'));
  CCM128_tag := TCCM128_tag(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ccm128_tag'));
  
  // Load XTS mode functions
  XTS128_encrypt := TXTS128_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_xts128_encrypt'));
  XTS128_decrypt := TXTS128_decrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_xts128_decrypt'));
  
  // Load OCB mode functions  
  OCB128_new := TOCB128_new(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_new'));
  OCB128_free := TOCB128_free(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_release'));
  OCB128_init := TOCB128_init(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_init'));
  OCB128_setiv := TOCB128_setiv(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_setiv'));
  OCB128_aad := TOCB128_aad(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_aad'));
  OCB128_encrypt := TOCB128_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_encrypt'));
  OCB128_decrypt := TOCB128_decrypt(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_decrypt'));
  OCB128_finish := TOCB128_finish(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_finish'));
  OCB128_tag := TOCB128_tag(TOpenSSLLoader.GetFunction(LHandle, 'CRYPTO_ocb128_tag'));
  
  // Load key wrapping functions
  AES_wrap_key := TAES_wrap_key(TOpenSSLLoader.GetFunction(LHandle, 'AES_wrap_key'));
  AES_unwrap_key := TAES_unwrap_key(TOpenSSLLoader.GetFunction(LHandle, 'AES_unwrap_key'));
  
  // Treat the direct-modes module as ready only when every exported helper surface
  // has the symbols it needs. Partial availability must not publish a loaded state.
  Result := Assigned(GCM128_new) and Assigned(GCM128_free) and
            Assigned(GCM128_setiv) and Assigned(GCM128_aad) and
            Assigned(GCM128_encrypt) and Assigned(GCM128_decrypt) and
            Assigned(GCM128_finish) and Assigned(GCM128_tag) and
            Assigned(CCM128_new) and Assigned(CCM128_free) and
            Assigned(CCM128_init) and Assigned(CCM128_setiv) and
            Assigned(CCM128_aad) and Assigned(CCM128_encrypt) and
            Assigned(CCM128_decrypt) and Assigned(CCM128_tag) and
            Assigned(XTS128_encrypt) and Assigned(XTS128_decrypt) and
            Assigned(OCB128_new) and Assigned(OCB128_free) and
            Assigned(OCB128_init) and Assigned(OCB128_setiv) and
            Assigned(OCB128_aad) and Assigned(OCB128_encrypt) and
            Assigned(OCB128_decrypt) and Assigned(OCB128_finish) and
            Assigned(OCB128_tag) and
            Assigned(AES_wrap_key) and Assigned(AES_unwrap_key);
  if not Result then
  begin
    UnloadModesFunctions;
    Exit(False);
  end;

  TOpenSSLLoader.SetModuleLoaded(osmModes, True);
end;

procedure UnloadModesFunctions;
begin
  // Clear GCM functions
  GCM128_new := nil;
  GCM128_free := nil;
  GCM128_setiv := nil;
  GCM128_aad := nil;
  GCM128_encrypt := nil;
  GCM128_decrypt := nil;
  GCM128_finish := nil;
  GCM128_tag := nil;
  
  // Clear CCM functions
  CCM128_new := nil;
  CCM128_free := nil;
  CCM128_init := nil;
  CCM128_setiv := nil;
  CCM128_aad := nil;
  CCM128_encrypt := nil;
  CCM128_decrypt := nil;
  CCM128_tag := nil;
  
  // Clear XTS functions
  XTS128_encrypt := nil;
  XTS128_decrypt := nil;
  
  // Clear OCB functions
  OCB128_new := nil;
  OCB128_free := nil;
  OCB128_init := nil;
  OCB128_setiv := nil;
  OCB128_aad := nil;
  OCB128_encrypt := nil;
  OCB128_decrypt := nil;
  OCB128_finish := nil;
  OCB128_tag := nil;
  
  // Clear wrap functions
  AES_wrap_key := nil;
  AES_unwrap_key := nil;

  TOpenSSLLoader.SetModuleLoaded(osmModes, False);

  // 注意: 库卸载由 TOpenSSLLoader 自动处理（在 finalization 部分）
end;


// High-level helper function implementations

function AES_GCM_Encrypt(const Key: TBytes; const IV: TBytes; const AAD: TBytes;
                        const Plaintext: TBytes; out Tag: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  outlen, finlen: Integer;
  KeyPtr, IVPtr, AADPtr, PlainPtr, ResultPtr, TagPtr: PByte;
begin
  Result := nil;
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  // Select cipher based on key size
  case Length(Key) of
    16: cipher := EVP_aes_128_gcm();
    24: cipher := EVP_aes_192_gcm();
    32: cipher := EVP_aes_256_gcm();
  else
    RaiseInvalidParameter('AES-GCM key size');
  end;
  
  SetLength(Result, Length(Plaintext));
  SetLength(Tag, GCM_TAG_SIZE);
  
  // Get pointers to array data
  KeyPtr := @Key[0];
  IVPtr := @IV[0];
  ResultPtr := @Result[0];
  TagPtr := @Tag[0];
  if Length(AAD) > 0 then
    AADPtr := @AAD[0]
  else
    AADPtr := nil;
  if Length(Plaintext) > 0 then
    PlainPtr := @Plaintext[0]
  else
    PlainPtr := nil;
  
  ctx := EVP_CIPHER_CTX_new();
  try
    // Initialize encryption
    if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-GCM');
      
    // Set IV length if not default
    if Length(IV) <> 12 then
    begin
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, Integer(Length(IV)), nil) <> 1 then
        raise ESSLCryptoError.Create('Failed to set IV length');
    end;
    
    // Initialize with key and IV
    if EVP_EncryptInit_ex(ctx, nil, nil, KeyPtr, IVPtr) <> 1 then
      raise ESSLCryptoError.Create('Failed to set key and IV');
      
    // Process AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_EncryptUpdate(ctx, nil, outlen, AADPtr, Integer(Length(AAD))) <> 1 then
        raise ESSLCryptoError.Create('Failed to process AAD');
    end;
    
    // Encrypt plaintext
    if EVP_EncryptUpdate(ctx, ResultPtr, outlen, PlainPtr, Integer(Length(Plaintext))) <> 1 then
      raise ESSLEncryptionException.Create('Failed to encrypt');
      
    // Finalize
    if EVP_EncryptFinal_ex(ctx, PByte(PtrUInt(ResultPtr) + PtrUInt(outlen)), finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize encryption');
      
    SetLength(Result, outlen + finlen);
    
    // Get tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE, TagPtr) <> 1 then
      raise ESSLCryptoError.Create('Failed to get tag');
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_GCM_Decrypt(const Key: TBytes; const IV: TBytes; const AAD: TBytes;
                        const Ciphertext: TBytes; const Tag: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  outlen, finlen: Integer;
  KeyPtr, IVPtr, AADPtr, CipherPtr, ResultPtr, TagPtr: PByte;
begin
  Result := nil;
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  // Select cipher based on key size
  case Length(Key) of
    16: cipher := EVP_aes_128_gcm();
    24: cipher := EVP_aes_192_gcm();
    32: cipher := EVP_aes_256_gcm();
  else
    RaiseInvalidParameter('AES-GCM key size');
  end;
  
  if Length(Tag) <> GCM_TAG_SIZE then
    RaiseInvalidParameter('GCM tag size');
  
  SetLength(Result, Length(Ciphertext));
  
  // Get pointers to array data
  KeyPtr := @Key[0];
  IVPtr := @IV[0];
  ResultPtr := @Result[0];
  TagPtr := @Tag[0];
  if Length(AAD) > 0 then
    AADPtr := @AAD[0]
  else
    AADPtr := nil;
  if Length(Ciphertext) > 0 then
    CipherPtr := @Ciphertext[0]
  else
    CipherPtr := nil;
  
  ctx := EVP_CIPHER_CTX_new();
  try
    // Initialize decryption
    if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-GCM');
      
    // Set IV length if not default
    if Length(IV) <> 12 then
    begin
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, Integer(Length(IV)), nil) <> 1 then
        raise ESSLCryptoError.Create('Failed to set IV length');
    end;
    
    // Initialize with key and IV
    if EVP_DecryptInit_ex(ctx, nil, nil, KeyPtr, IVPtr) <> 1 then
      raise ESSLCryptoError.Create('Failed to set key and IV');
      
    // Process AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_DecryptUpdate(ctx, nil, outlen, AADPtr, Integer(Length(AAD))) <> 1 then
        raise ESSLCryptoError.Create('Failed to process AAD');
    end;
    
    // Decrypt ciphertext
    if EVP_DecryptUpdate(ctx, ResultPtr, outlen, CipherPtr, Integer(Length(Ciphertext))) <> 1 then
      raise ESSLDecryptionException.Create('Failed to decrypt');
    
    // Set expected tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, GCM_TAG_SIZE, TagPtr) <> 1 then
      raise ESSLCryptoError.Create('Failed to set tag');
      
    // Verify tag and finalize
    if EVP_DecryptFinal_ex(ctx, PByte(PtrUInt(ResultPtr) + PtrUInt(outlen)), finlen) <> 1 then
      raise ESSLDecryptionException.Create('Authentication verification failed');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_CCM_Encrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Plaintext: TBytes; TagSize: Integer; out Tag: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  outlen, finlen: Integer;
  KeyPtr, NoncePtr, AADPtr, PlainPtr, ResultPtr, TagPtr: PByte;
begin
  Result := nil;
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  // Select cipher based on key size
  case Length(Key) of
    16: cipher := EVP_aes_128_ccm();
    24: cipher := EVP_aes_192_ccm();
    32: cipher := EVP_aes_256_ccm();
  else
    RaiseInvalidParameter('AES-CCM key size');
  end;
  
  if (TagSize < CCM_MIN_TAG_SIZE) or (TagSize > CCM_MAX_TAG_SIZE) then
    RaiseInvalidParameter('CCM tag size');
  
  SetLength(Result, Length(Plaintext));
  SetLength(Tag, TagSize);
  
  // Get pointers
  KeyPtr := @Key[0];
  NoncePtr := @Nonce[0];
  ResultPtr := @Result[0];
  TagPtr := @Tag[0];
  if Length(AAD) > 0 then AADPtr := @AAD[0] else AADPtr := nil;
  if Length(Plaintext) > 0 then PlainPtr := @Plaintext[0] else PlainPtr := nil;
  
  ctx := EVP_CIPHER_CTX_new();
  try
    // Initialize encryption
    if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-CCM');
    
    // Set nonce length
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_IVLEN, Integer(Length(Nonce)), nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to set nonce length');
    
    // Set tag length
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_TAG, TagSize, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to set tag length');
    
    // Initialize with key and nonce
    if EVP_EncryptInit_ex(ctx, nil, nil, KeyPtr, NoncePtr) <> 1 then
      raise ESSLCryptoError.Create('Failed to set key and nonce');
    
    // Set message length (required for CCM)
    if EVP_EncryptUpdate(ctx, nil, outlen, nil, Integer(Length(Plaintext))) <> 1 then
      raise ESSLCryptoError.Create('Failed to set message length');
    
    // Process AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_EncryptUpdate(ctx, nil, outlen, AADPtr, Integer(Length(AAD))) <> 1 then
        raise ESSLCryptoError.Create('Failed to process AAD');
    end;
    
    // Encrypt plaintext
    if EVP_EncryptUpdate(ctx, ResultPtr, outlen, PlainPtr, Integer(Length(Plaintext))) <> 1 then
      raise ESSLEncryptionException.Create('Failed to encrypt');
    
    // Finalize (no output for CCM)
    if EVP_EncryptFinal_ex(ctx, PByte(PtrUInt(ResultPtr) + PtrUInt(outlen)), finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize encryption');
    
    // Get tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_GET_TAG, TagSize, TagPtr) <> 1 then
      raise ESSLCryptoError.Create('Failed to get tag');
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_CCM_Decrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Ciphertext: TBytes; const Tag: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  outlen: Integer;
begin
  Result := nil;
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  // Select cipher based on key size
  case Length(Key) of
    16: cipher := EVP_aes_128_ccm();
    24: cipher := EVP_aes_192_ccm();
    32: cipher := EVP_aes_256_ccm();
  else
    RaiseInvalidParameter('AES-CCM key size');
  end;
  
  SetLength(Result, Length(Ciphertext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    // Initialize decryption
    if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-CCM');
    
    // Set nonce length
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_IVLEN, Integer(Length(Nonce)), nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to set nonce length');
    
    // Set tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_CCM_SET_TAG, Integer(Length(Tag)), @Tag[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to set tag');
    
    // Initialize with key and nonce
    if EVP_DecryptInit_ex(ctx, nil, nil, @Key[0], @Nonce[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to set key and nonce');
    
    // Set message length (required for CCM)
    if EVP_DecryptUpdate(ctx, nil, outlen, nil, Length(Ciphertext)) <> 1 then
      raise ESSLCryptoError.Create('Failed to set message length');
    
    // Process AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_DecryptUpdate(ctx, nil, outlen, @AAD[0], Length(AAD)) <> 1 then
        raise ESSLCryptoError.Create('Failed to process AAD');
    end;
    
    // Decrypt and verify
    if EVP_DecryptUpdate(ctx, @Result[0], outlen, @Ciphertext[0], Length(Ciphertext)) <= 0 then
      raise ESSLDecryptionException.Create('Decryption or authentication failed');
      
    SetLength(Result, outlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_XTS_Encrypt(const Key1, Key2: TBytes; const Tweak: TBytes;
                        const Plaintext: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  combined_key: TBytes;
  outlen, finlen: Integer;
begin
  Result := nil;
  // XTS requires two keys
  if Length(Key1) <> Length(Key2) then
    RaiseInvalidParameter('XTS key pair size');
    
  // Combine keys for XTS
  SetLength(combined_key, Length(Key1) + Length(Key2));
  Move(Key1[0], combined_key[0], Length(Key1));
  Move(Key2[0], combined_key[Length(Key1)], Length(Key2));
  
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  case Length(Key1) of
    16: cipher := EVP_aes_128_xts();  // Total key = 256 bits
    32: cipher := EVP_aes_256_xts();  // Total key = 512 bits
  else
    RaiseInvalidParameter('AES-XTS key size');
  end;
  
  SetLength(Result, Length(Plaintext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    if EVP_EncryptInit_ex(ctx, cipher, nil, @combined_key[0], @Tweak[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-XTS');
      
    if EVP_EncryptUpdate(ctx, @Result[0], outlen, @Plaintext[0], Length(Plaintext)) <> 1 then
      raise ESSLEncryptionException.Create('Failed to encrypt with AES-XTS');
      
    if EVP_EncryptFinal_ex(ctx, @Result[outlen], finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize AES-XTS encryption');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_XTS_Decrypt(const Key1, Key2: TBytes; const Tweak: TBytes;
                        const Ciphertext: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  combined_key: TBytes;
  outlen, finlen: Integer;
begin
  Result := nil;
  // XTS requires two keys
  if Length(Key1) <> Length(Key2) then
    RaiseInvalidParameter('XTS key pair size');
    
  // Combine keys for XTS
  SetLength(combined_key, Length(Key1) + Length(Key2));
  Move(Key1[0], combined_key[0], Length(Key1));
  Move(Key2[0], combined_key[Length(Key1)], Length(Key2));
  
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  case Length(Key1) of
    16: cipher := EVP_aes_128_xts();  // Total key = 256 bits
    32: cipher := EVP_aes_256_xts();  // Total key = 512 bits
  else
    RaiseInvalidParameter('AES-XTS key size');
  end;
  
  SetLength(Result, Length(Ciphertext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    if EVP_DecryptInit_ex(ctx, cipher, nil, @combined_key[0], @Tweak[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-XTS');
      
    if EVP_DecryptUpdate(ctx, @Result[0], outlen, @Ciphertext[0], Length(Ciphertext)) <> 1 then
      raise ESSLDecryptionException.Create('Failed to decrypt with AES-XTS');
      
    if EVP_DecryptFinal_ex(ctx, @Result[outlen], finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize AES-XTS decryption');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_OCB_Encrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Plaintext: TBytes; out Tag: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  outlen, finlen: Integer;
begin
  Result := nil;
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  // Select cipher based on key size
  case Length(Key) of
    16: cipher := EVP_aes_128_ocb();
    24: cipher := EVP_aes_192_ocb();
    32: cipher := EVP_aes_256_ocb();
  else
    RaiseInvalidParameter('AES-OCB key size');
  end;
  
  SetLength(Result, Length(Plaintext) + OCB_TAG_SIZE); // OCB may expand
  SetLength(Tag, OCB_TAG_SIZE);
  
  ctx := EVP_CIPHER_CTX_new();
  try
    // Initialize encryption
    if EVP_EncryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-OCB');
      
    // Set nonce length if not default
    if Length(Nonce) <> 12 then
    begin
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, Integer(Length(Nonce)), nil) <> 1 then
        raise ESSLCryptoError.Create('Failed to set nonce length');
    end;
    
    // Set tag length
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_OCB_SET_TAGLEN, OCB_TAG_SIZE, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to set tag length');
    
    // Initialize with key and nonce
    if EVP_EncryptInit_ex(ctx, nil, nil, @Key[0], @Nonce[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to set key and nonce');
      
    // Process AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_EncryptUpdate(ctx, nil, outlen, @AAD[0], Length(AAD)) <> 1 then
        raise ESSLCryptoError.Create('Failed to process AAD');
    end;
    
    // Encrypt plaintext
    if EVP_EncryptUpdate(ctx, @Result[0], outlen, @Plaintext[0], Length(Plaintext)) <> 1 then
      raise ESSLEncryptionException.Create('Failed to encrypt');
      
    // Finalize
    if EVP_EncryptFinal_ex(ctx, @Result[outlen], finlen) <> 1 then
      raise ESSLCryptoError.Create('Failed to finalize encryption');
      
    SetLength(Result, outlen + finlen);
    
    // Get tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, OCB_TAG_SIZE, @Tag[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to get tag');
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_OCB_Decrypt(const Key: TBytes; const Nonce: TBytes; const AAD: TBytes;
                        const Ciphertext: TBytes; const Tag: TBytes): TBytes;
var
  ctx: PEVP_CIPHER_CTX;
  cipher: PEVP_CIPHER;
  outlen, finlen: Integer;
begin
  Result := nil;
  // Note: EVP functions are loaded automatically through nextpas.core.tls.openssl.api
    
  // Select cipher based on key size
  case Length(Key) of
    16: cipher := EVP_aes_128_ocb();
    24: cipher := EVP_aes_192_ocb();
    32: cipher := EVP_aes_256_ocb();
  else
    RaiseInvalidParameter('AES-OCB key size');
  end;
  
  if Length(Tag) <> OCB_TAG_SIZE then
    RaiseInvalidParameter('OCB tag size');
  
  SetLength(Result, Length(Ciphertext));
  
  ctx := EVP_CIPHER_CTX_new();
  try
    // Initialize decryption
    if EVP_DecryptInit_ex(ctx, cipher, nil, nil, nil) <> 1 then
      raise ESSLCryptoError.Create('Failed to initialize AES-OCB');
      
    // Set nonce length if not default
    if Length(Nonce) <> 12 then
    begin
      if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, Integer(Length(Nonce)), nil) <> 1 then
        raise ESSLCryptoError.Create('Failed to set nonce length');
    end;
    
    // Initialize with key and nonce
    if EVP_DecryptInit_ex(ctx, nil, nil, @Key[0], @Nonce[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to set key and nonce');
      
    // Set expected tag
    if EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, OCB_TAG_SIZE, @Tag[0]) <> 1 then
      raise ESSLCryptoError.Create('Failed to set tag');
      
    // Process AAD if provided
    if Length(AAD) > 0 then
    begin
      if EVP_DecryptUpdate(ctx, nil, outlen, @AAD[0], Length(AAD)) <> 1 then
        raise ESSLCryptoError.Create('Failed to process AAD');
    end;
    
    // Decrypt ciphertext
    if EVP_DecryptUpdate(ctx, @Result[0], outlen, @Ciphertext[0], Length(Ciphertext)) <> 1 then
      raise ESSLDecryptionException.Create('Failed to decrypt');
      
    // Verify tag and finalize
    if EVP_DecryptFinal_ex(ctx, @Result[outlen], finlen) <> 1 then
      raise ESSLDecryptionException.Create('Authentication verification failed');
      
    SetLength(Result, outlen + finlen);
  finally
    EVP_CIPHER_CTX_free(ctx);
  end;
end;

function AES_WrapKey(const KEK: TBytes; const Plaintext: TBytes): TBytes;
begin
  Result := nil;
  if not Assigned(AES_wrap_key) then
    RaiseFunctionNotAvailable('AES_wrap_key');
    
  if Length(Plaintext) mod 8 <> 0 then
    RaiseInvalidParameter('plaintext length (must be multiple of 8)');
    
  SetLength(Result, Length(Plaintext) + 8); // Wrapped key is 8 bytes larger
  
  if AES_wrap_key(@KEK[0], nil, @Result[0], @Plaintext[0], Length(Plaintext)) <= 0 then
    raise ESSLCryptoError.Create('AES key wrap failed');
end;

function AES_UnwrapKey(const KEK: TBytes; const Ciphertext: TBytes): TBytes;
begin
  Result := nil;
  if not Assigned(AES_unwrap_key) then
    RaiseFunctionNotAvailable('AES_unwrap_key');
    
  if Length(Ciphertext) mod 8 <> 0 then
    RaiseInvalidParameter('ciphertext length (must be multiple of 8)');
    
  if Length(Ciphertext) < 16 then
    RaiseInvalidParameter('ciphertext length (minimum 16 bytes)');
    
  SetLength(Result, Length(Ciphertext) - 8); // Unwrapped key is 8 bytes smaller
  
  if AES_unwrap_key(@KEK[0], nil, @Result[0], @Ciphertext[0], Length(Ciphertext)) <= 0 then
    raise ESSLCryptoError.Create('AES key unwrap failed or authentication failed');
end;

initialization
  
finalization
  UnloadModesFunctions;
  
end.
