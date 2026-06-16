unit nextpas.core.tls.openssl.api.aead;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.base, nextpas.core.mem.secure;

type
  { AEAD 加密结果 }
  TAEADEncryptResult = record
    Success: Boolean;
    CipherText: TBytes;
    Tag: TBytes;
    ErrorMessage: string;
  end;
  
  { AEAD 解密结果 }
  TAEADDecryptResult = record
    Success: Boolean;
    PlainText: TBytes;
    ErrorMessage: string;
  end;

{ AES-GCM 加密函数 }
function AES_GCM_Encrypt(
  const Key: TBytes;       // 16, 24, or 32 bytes for AES-128/192/256
  const IV: TBytes;        // 12 bytes recommended (96-bit)
  const PlainText: TBytes;
  const AAD: TBytes = nil  // Additional Authenticated Data (可选)
): TAEADEncryptResult;

{ AES-GCM 解密函数 }
function AES_GCM_Decrypt(
  const Key: TBytes;
  const IV: TBytes;
  const CipherText: TBytes;
  const Tag: TBytes;       // 16 bytes (128-bit)
  const AAD: TBytes = nil
): TAEADDecryptResult;

{ ChaCha20-Poly1305 加密函数 }
function ChaCha20_Poly1305_Encrypt(
  const Key: TBytes;       // 32 bytes (256-bit)
  const Nonce: TBytes;     // 12 bytes
  const PlainText: TBytes;
  const AAD: TBytes = nil
): TAEADEncryptResult;

{ ChaCha20-Poly1305 解密函数 }
function ChaCha20_Poly1305_Decrypt(
  const Key: TBytes;
  const Nonce: TBytes;
  const CipherText: TBytes;
  const Tag: TBytes;       // 16 bytes
  const AAD: TBytes = nil
): TAEADDecryptResult;

implementation

function AES_GCM_Encrypt(
  const Key: TBytes;
  const IV: TBytes;
  const PlainText: TBytes;
  const AAD: TBytes
): TAEADEncryptResult;
var
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  OutLen, TotalLen: Integer;
  TempBuffer: TBytes;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  SetLength(Result.CipherText, 0);
  SetLength(Result.Tag, 16);
  
  // 验证输入
  if Length(Key) = 0 then
  begin
    Result.ErrorMessage := 'Key is empty';
    Exit;
  end;
  
  if Length(IV) = 0 then
  begin
    Result.ErrorMessage := 'IV is empty';
    Exit;
  end;
  
  // 选择密码算法
  case Length(Key) of
    16: Cipher := EVP_aes_128_gcm();
    24: Cipher := EVP_aes_192_gcm();
    32: Cipher := EVP_aes_256_gcm();
  else
    Result.ErrorMessage := 'Invalid key length (must be 16, 24, or 32 bytes)';
    Exit;
  end;
  
  if not Assigned(Cipher) then
  begin
    Result.ErrorMessage := 'GCM cipher not available';
    Exit;
  end;
  
  // 创建上下文
  Ctx := EVP_CIPHER_CTX_new();
  if not Assigned(Ctx) then
  begin
    Result.ErrorMessage := 'Failed to create cipher context';
    Exit;
  end;
  
  try
    // 初始化加密
    if EVP_EncryptInit_ex(Ctx, Cipher, nil, nil, nil) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to initialize encryption';
      Exit;
    end;
    
    // 设置 IV 长度
    if Assigned(EVP_CIPHER_CTX_ctrl) then
    begin
      if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set IV length';
        Exit;
      end;
    end;
    
    // 设置密钥和 IV
    if EVP_EncryptInit_ex(Ctx, nil, nil, PByte(@Key[0]), PByte(@IV[0])) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to set key and IV';
      Exit;
    end;
    
    // 提供 AAD (如果有)
    if Length(AAD) > 0 then
    begin
      OutLen := 0;
      if EVP_EncryptUpdate(Ctx, nil, OutLen, PByte(@AAD[0]), Integer(Length(AAD))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set AAD';
        Exit;
      end;
    end;
    
    // 加密明文
    SetLength(TempBuffer, Length(PlainText) + 32); // 额外空间用于填充
    OutLen := 0;
    TotalLen := 0;
    
    if Length(PlainText) > 0 then
    begin
      if EVP_EncryptUpdate(Ctx, PByte(@TempBuffer[0]), OutLen, PByte(@PlainText[0]), Integer(Length(PlainText))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to encrypt data';
        Exit;
      end;
      TotalLen := OutLen;
    end;
    
    // 完成加密
    if EVP_EncryptFinal_ex(Ctx, PByte(@TempBuffer[TotalLen]), OutLen) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to finalize encryption';
      Exit;
    end;
    Inc(TotalLen, OutLen);
    
    // 复制密文到结果
    SetLength(Result.CipherText, TotalLen);
    if TotalLen > 0 then
      Move(TempBuffer[0], Result.CipherText[0], TotalLen);
    
    // 获取认证标签
    if Assigned(EVP_CIPHER_CTX_ctrl) then
    begin
      if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_GET_TAG, 16, Pointer(@Result.Tag[0])) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to get authentication tag';
        Exit;
      end;
    end;
    
    Result.Success := True;

  finally
    if Length(TempBuffer) > 0 then
      SecureZeroMemory(@TempBuffer[0], Length(TempBuffer));
    EVP_CIPHER_CTX_free(Ctx);
  end;
end;

function AES_GCM_Decrypt(
  const Key: TBytes;
  const IV: TBytes;
  const CipherText: TBytes;
  const Tag: TBytes;
  const AAD: TBytes
): TAEADDecryptResult;
var
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  OutLen, TotalLen: Integer;
  TempBuffer: TBytes;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  SetLength(Result.PlainText, 0);
  
  // 验证输入
  if Length(Key) = 0 then
  begin
    Result.ErrorMessage := 'Key is empty';
    Exit;
  end;
  
  if Length(IV) = 0 then
  begin
    Result.ErrorMessage := 'IV is empty';
    Exit;
  end;
  
  if Length(Tag) <> 16 then
  begin
    Result.ErrorMessage := 'Tag must be 16 bytes';
    Exit;
  end;
  
  // 选择密码算法
  case Length(Key) of
    16: Cipher := EVP_aes_128_gcm();
    24: Cipher := EVP_aes_192_gcm();
    32: Cipher := EVP_aes_256_gcm();
  else
    Result.ErrorMessage := 'Invalid key length (must be 16, 24, or 32 bytes)';
    Exit;
  end;
  
  if not Assigned(Cipher) then
  begin
    Result.ErrorMessage := 'GCM cipher not available';
    Exit;
  end;
  
  // 创建上下文
  Ctx := EVP_CIPHER_CTX_new();
  if not Assigned(Ctx) then
  begin
    Result.ErrorMessage := 'Failed to create cipher context';
    Exit;
  end;
  
  try
    // 初始化解密
    if EVP_DecryptInit_ex(Ctx, Cipher, nil, nil, nil) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to initialize decryption';
      Exit;
    end;
    
    // 设置 IV 长度
    if Assigned(EVP_CIPHER_CTX_ctrl) then
    begin
      if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set IV length';
        Exit;
      end;
    end;
    
    // 设置密钥和 IV
    if EVP_DecryptInit_ex(Ctx, nil, nil, PByte(@Key[0]), PByte(@IV[0])) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to set key and IV';
      Exit;
    end;
    
    // 提供 AAD (如果有)
    if Length(AAD) > 0 then
    begin
      OutLen := 0;
      if EVP_DecryptUpdate(Ctx, nil, OutLen, PByte(@AAD[0]), Integer(Length(AAD))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set AAD';
        Exit;
      end;
    end;
    
    // 解密密文
    SetLength(TempBuffer, Length(CipherText) + 32);
    OutLen := 0;
    TotalLen := 0;
    
    if Length(CipherText) > 0 then
    begin
      if EVP_DecryptUpdate(Ctx, PByte(@TempBuffer[0]), OutLen, PByte(@CipherText[0]), Integer(Length(CipherText))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to decrypt data';
        Exit;
      end;
      TotalLen := OutLen;
    end;
    
    // 设置预期的标签
    if Assigned(EVP_CIPHER_CTX_ctrl) then
    begin
      if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_TAG, 16, Pointer(@Tag[0])) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set authentication tag';
        Exit;
      end;
    end;
    
    // 完成解密（验证标签）
    if EVP_DecryptFinal_ex(Ctx, PByte(@TempBuffer[TotalLen]), OutLen) <> 1 then
    begin
      Result.ErrorMessage := 'Authentication failed - data may be corrupted or tampered';
      Exit;
    end;
    Inc(TotalLen, OutLen);
    
    // 复制明文到结果
    SetLength(Result.PlainText, TotalLen);
    if TotalLen > 0 then
      Move(TempBuffer[0], Result.PlainText[0], TotalLen);

    Result.Success := True;

  finally
    if Length(TempBuffer) > 0 then
      SecureZeroMemory(@TempBuffer[0], Length(TempBuffer));
    EVP_CIPHER_CTX_free(Ctx);
  end;
end;

function ChaCha20_Poly1305_Encrypt(
  const Key: TBytes;
  const Nonce: TBytes;
  const PlainText: TBytes;
  const AAD: TBytes
): TAEADEncryptResult;
var
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  OutLen, TotalLen: Integer;
  TempBuffer: TBytes;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  SetLength(Result.CipherText, 0);
  SetLength(Result.Tag, 16);
  
  // 验证输入
  if Length(Key) <> 32 then
  begin
    Result.ErrorMessage := 'Key must be 32 bytes for ChaCha20-Poly1305';
    Exit;
  end;
  
  if Length(Nonce) <> 12 then
  begin
    Result.ErrorMessage := 'Nonce must be 12 bytes';
    Exit;
  end;
  
  Cipher := EVP_chacha20_poly1305();
  if not Assigned(Cipher) then
  begin
    Result.ErrorMessage := 'ChaCha20-Poly1305 cipher not available';
    Exit;
  end;
  
  Ctx := EVP_CIPHER_CTX_new();
  if not Assigned(Ctx) then
  begin
    Result.ErrorMessage := 'Failed to create cipher context';
    Exit;
  end;
  
  try
    // 初始化加密
    if EVP_EncryptInit_ex(Ctx, Cipher, nil, PByte(@Key[0]), PByte(@Nonce[0])) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to initialize encryption';
      Exit;
    end;
    
    // 提供 AAD
    if Length(AAD) > 0 then
    begin
      OutLen := 0;
      if EVP_EncryptUpdate(Ctx, nil, OutLen, PByte(@AAD[0]), Integer(Length(AAD))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set AAD';
        Exit;
      end;
    end;
    
    // 加密
    SetLength(TempBuffer, Length(PlainText) + 32);
    OutLen := 0;
    TotalLen := 0;
    
    if Length(PlainText) > 0 then
    begin
      if EVP_EncryptUpdate(Ctx, PByte(@TempBuffer[0]), OutLen, PByte(@PlainText[0]), Integer(Length(PlainText))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to encrypt data';
        Exit;
      end;
      TotalLen := OutLen;
    end;
    
    if EVP_EncryptFinal_ex(Ctx, PByte(@TempBuffer[TotalLen]), OutLen) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to finalize encryption';
      Exit;
    end;
    Inc(TotalLen, OutLen);
    
    SetLength(Result.CipherText, TotalLen);
    if TotalLen > 0 then
      Move(TempBuffer[0], Result.CipherText[0], TotalLen);
    
    // 获取标签
    if Assigned(EVP_CIPHER_CTX_ctrl) then
    begin
      if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_AEAD_GET_TAG, 16, Pointer(@Result.Tag[0])) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to get authentication tag';
        Exit;
      end;
    end;
    
    Result.Success := True;

  finally
    if Length(TempBuffer) > 0 then
      SecureZeroMemory(@TempBuffer[0], Length(TempBuffer));
    EVP_CIPHER_CTX_free(Ctx);
  end;
end;

function ChaCha20_Poly1305_Decrypt(
  const Key: TBytes;
  const Nonce: TBytes;
  const CipherText: TBytes;
  const Tag: TBytes;
  const AAD: TBytes
): TAEADDecryptResult;
var
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  OutLen, TotalLen: Integer;
  TempBuffer: TBytes;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  SetLength(Result.PlainText, 0);
  
  if Length(Key) <> 32 then
  begin
    Result.ErrorMessage := 'Key must be 32 bytes';
    Exit;
  end;
  
  if Length(Nonce) <> 12 then
  begin
    Result.ErrorMessage := 'Nonce must be 12 bytes';
    Exit;
  end;
  
  if Length(Tag) <> 16 then
  begin
    Result.ErrorMessage := 'Tag must be 16 bytes';
    Exit;
  end;
  
  Cipher := EVP_chacha20_poly1305();
  if not Assigned(Cipher) then
  begin
    Result.ErrorMessage := 'ChaCha20-Poly1305 cipher not available';
    Exit;
  end;
  
  Ctx := EVP_CIPHER_CTX_new();
  if not Assigned(Ctx) then
  begin
    Result.ErrorMessage := 'Failed to create cipher context';
    Exit;
  end;
  
  try
    if EVP_DecryptInit_ex(Ctx, Cipher, nil, PByte(@Key[0]), PByte(@Nonce[0])) <> 1 then
    begin
      Result.ErrorMessage := 'Failed to initialize decryption';
      Exit;
    end;
    
    if Length(AAD) > 0 then
    begin
      OutLen := 0;
      if EVP_DecryptUpdate(Ctx, nil, OutLen, PByte(@AAD[0]), Integer(Length(AAD))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set AAD';
        Exit;
      end;
    end;
    
    SetLength(TempBuffer, Length(CipherText) + 32);
    OutLen := 0;
    TotalLen := 0;
    
    if Length(CipherText) > 0 then
    begin
      if EVP_DecryptUpdate(Ctx, PByte(@TempBuffer[0]), OutLen, PByte(@CipherText[0]), Integer(Length(CipherText))) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to decrypt data';
        Exit;
      end;
      TotalLen := OutLen;
    end;
    
    if Assigned(EVP_CIPHER_CTX_ctrl) then
    begin
      if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_AEAD_SET_TAG, 16, Pointer(@Tag[0])) <> 1 then
      begin
        Result.ErrorMessage := 'Failed to set authentication tag';
        Exit;
      end;
    end;
    
    if EVP_DecryptFinal_ex(Ctx, PByte(@TempBuffer[TotalLen]), OutLen) <> 1 then
    begin
      Result.ErrorMessage := 'Authentication failed';
      Exit;
    end;
    Inc(TotalLen, OutLen);
    
    SetLength(Result.PlainText, TotalLen);
    if TotalLen > 0 then
      Move(TempBuffer[0], Result.PlainText[0], TotalLen);
    
    Result.Success := True;

  finally
    if Length(TempBuffer) > 0 then
      SecureZeroMemory(@TempBuffer[0], Length(TempBuffer));
    EVP_CIPHER_CTX_free(Ctx);
  end;
end;

end.
