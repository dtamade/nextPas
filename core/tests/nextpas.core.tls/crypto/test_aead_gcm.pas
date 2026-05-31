program test_aead_gcm;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.base;

const
  GCM_TAG_SIZE = 16;  // 128-bit authentication tag

var
  TestsPassed, TestsFailed: Integer;

procedure ReportTest(const TestName: string; Success: Boolean);
begin
  if Success then
  begin
    WriteLn('[通过] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[失败] ', TestName);
    Inc(TestsFailed);
  end;
end;

// AES-128-GCM 加密测试
function TestAES128GCMEncrypt: Boolean;
var
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  Key: array[0..15] of Byte;   // 128-bit key
  IV: array[0..11] of Byte;     // 96-bit IV (推荐)
  AAD: array[0..19] of Byte;    // Additional Authenticated Data
  PlainText: array[0..31] of Byte;
  CipherText: array[0..47] of Byte;
  Tag: array[0..15] of Byte;
  OutLen, TotalLen: Integer;
  i: Integer;
begin
  Result := False;
  
  // 初始化测试数据
  for i := 0 to 15 do Key[i] := Byte(i);
  for i := 0 to 11 do IV[i] := Byte(i);
  for i := 0 to 19 do AAD[i] := Byte($AA);
  for i := 0 to 31 do PlainText[i] := Byte($BB);
  
  Cipher := EVP_aes_128_gcm();
  if Cipher = nil then
  begin
    WriteLn('  错误: EVP_aes_128_gcm 返回 nil');
    Exit;
  end;
  
  Ctx := EVP_CIPHER_CTX_new();
  if Ctx = nil then
  begin
    WriteLn('  错误: 无法创建 cipher context');
    Exit;
  end;
  
  try
    // 初始化加密
    if EVP_EncryptInit_ex(Ctx, Cipher, nil, nil, nil) <> 1 then
    begin
      WriteLn('  错误: EVP_EncryptInit_ex 失败');
      Exit;
    end;
    
    // 设置 IV 长度
    if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil) <> 1 then
    begin
      WriteLn('  错误: 设置 IV 长度失败');
      Exit;
    end;
    
    // 设置密钥和 IV
    if EVP_EncryptInit_ex(Ctx, nil, nil, @Key[0], @IV[0]) <> 1 then
    begin
      WriteLn('  错误: 设置密钥和 IV 失败');
      Exit;
    end;
    
    // 提供 AAD
    OutLen := 0;
    if EVP_EncryptUpdate(Ctx, nil, OutLen, @AAD[0], Length(AAD)) <> 1 then
    begin
      WriteLn('  错误: 提供 AAD 失败');
      Exit;
    end;
    
    // 加密明文
    if EVP_EncryptUpdate(Ctx, @CipherText[0], OutLen, @PlainText[0], Length(PlainText)) <> 1 then
    begin
      WriteLn('  错误: 加密失败');
      Exit;
    end;
    TotalLen := OutLen;
    
    // 完成加密
    if EVP_EncryptFinal_ex(Ctx, @CipherText[TotalLen], OutLen) <> 1 then
    begin
      WriteLn('  错误: 完成加密失败');
      Exit;
    end;
    Inc(TotalLen, OutLen);
    
    // 获取认证标签
    if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE, @Tag[0]) <> 1 then
    begin
      WriteLn('  错误: 获取认证标签失败');
      Exit;
    end;
    
    WriteLn('  加密成功: ', TotalLen, ' 字节密文, 16 字节标签');
    Result := (TotalLen = Length(PlainText));
    
  finally
    EVP_CIPHER_CTX_free(Ctx);
  end;
end;

// AES-128-GCM 解密测试
function TestAES128GCMDecrypt: Boolean;
var
  CtxEnc, CtxDec: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  Key: array[0..15] of Byte;
  IV: array[0..11] of Byte;
  AAD: array[0..19] of Byte;
  PlainText: array[0..31] of Byte;
  CipherText: array[0..47] of Byte;
  DecryptedText: array[0..47] of Byte;
  Tag: array[0..15] of Byte;
  OutLen, TotalLen, DecLen: Integer;
  i: Integer;
  Match: Boolean;
begin
  Result := False;
  
  // 初始化测试数据
  for i := 0 to 15 do Key[i] := Byte(i);
  for i := 0 to 11 do IV[i] := Byte(i);
  for i := 0 to 19 do AAD[i] := Byte($AA);
  for i := 0 to 31 do PlainText[i] := Byte($BB);
  
  Cipher := EVP_aes_128_gcm();
  if Cipher = nil then Exit;
  
  // 先加密
  CtxEnc := EVP_CIPHER_CTX_new();
  if CtxEnc = nil then Exit;
  
  try
    EVP_EncryptInit_ex(CtxEnc, Cipher, nil, nil, nil);
    EVP_CIPHER_CTX_ctrl(CtxEnc, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil);
    EVP_EncryptInit_ex(CtxEnc, nil, nil, @Key[0], @IV[0]);
    OutLen := 0;
    EVP_EncryptUpdate(CtxEnc, nil, OutLen, @AAD[0], Length(AAD));
    EVP_EncryptUpdate(CtxEnc, @CipherText[0], OutLen, @PlainText[0], Length(PlainText));
    TotalLen := OutLen;
    EVP_EncryptFinal_ex(CtxEnc, @CipherText[TotalLen], OutLen);
    Inc(TotalLen, OutLen);
    EVP_CIPHER_CTX_ctrl(CtxEnc, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE, @Tag[0]);
  finally
    EVP_CIPHER_CTX_free(CtxEnc);
  end;
  
  // 现在解密
  CtxDec := EVP_CIPHER_CTX_new();
  if CtxDec = nil then Exit;
  
  try
    // 初始化解密
    if EVP_DecryptInit_ex(CtxDec, Cipher, nil, nil, nil) <> 1 then Exit;
    if EVP_CIPHER_CTX_ctrl(CtxDec, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil) <> 1 then Exit;
    if EVP_DecryptInit_ex(CtxDec, nil, nil, @Key[0], @IV[0]) <> 1 then Exit;
    
    // 提供 AAD
    DecLen := 0;
    if EVP_DecryptUpdate(CtxDec, nil, DecLen, @AAD[0], Length(AAD)) <> 1 then Exit;
    
    // 解密密文
    if EVP_DecryptUpdate(CtxDec, @DecryptedText[0], DecLen, @CipherText[0], TotalLen) <> 1 then Exit;
    TotalLen := DecLen;
    
    // 设置预期的标签
    if EVP_CIPHER_CTX_ctrl(CtxDec, EVP_CTRL_GCM_SET_TAG, GCM_TAG_SIZE, @Tag[0]) <> 1 then Exit;
    
    // 完成解密（验证标签）
    if EVP_DecryptFinal_ex(CtxDec, @DecryptedText[TotalLen], DecLen) <> 1 then
    begin
      WriteLn('  错误: 认证标签验证失败');
      Exit;
    end;
    Inc(TotalLen, DecLen);
    
    // 验证明文
    Match := True;
    for i := 0 to Length(PlainText) - 1 do
    begin
      if DecryptedText[i] <> PlainText[i] then
      begin
        Match := False;
        Break;
      end;
    end;
    
    if Match and (TotalLen = Length(PlainText)) then
    begin
      WriteLn('  解密成功: ', TotalLen, ' 字节明文, 认证通过');
      Result := True;
    end
    else
      WriteLn('  错误: 解密的明文不匹配');
    
  finally
    EVP_CIPHER_CTX_free(CtxDec);
  end;
end;

// AES-256-GCM 测试
function TestAES256GCM: Boolean;
var
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  Key: array[0..31] of Byte;   // 256-bit key
  IV: array[0..11] of Byte;
  PlainText: array[0..63] of Byte;
  CipherText: array[0..79] of Byte;
  Tag: array[0..15] of Byte;
  OutLen, TotalLen: Integer;
  i: Integer;
begin
  Result := False;
  
  for i := 0 to 31 do Key[i] := Byte(i);
  for i := 0 to 11 do IV[i] := Byte(i);
  for i := 0 to 63 do PlainText[i] := Byte($CC);
  
  Cipher := EVP_aes_256_gcm();
  if Cipher = nil then Exit;
  
  Ctx := EVP_CIPHER_CTX_new();
  if Ctx = nil then Exit;
  
  try
    if EVP_EncryptInit_ex(Ctx, Cipher, nil, nil, nil) <> 1 then Exit;
    if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil) <> 1 then Exit;
    if EVP_EncryptInit_ex(Ctx, nil, nil, @Key[0], @IV[0]) <> 1 then Exit;
    if EVP_EncryptUpdate(Ctx, @CipherText[0], OutLen, @PlainText[0], Length(PlainText)) <> 1 then Exit;
    TotalLen := OutLen;
    if EVP_EncryptFinal_ex(Ctx, @CipherText[TotalLen], OutLen) <> 1 then Exit;
    Inc(TotalLen, OutLen);
    if EVP_CIPHER_CTX_ctrl(Ctx, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE, @Tag[0]) <> 1 then Exit;
    
    WriteLn('  AES-256-GCM 加密成功: ', TotalLen, ' 字节');
    Result := (TotalLen = Length(PlainText));
    
  finally
    EVP_CIPHER_CTX_free(Ctx);
  end;
end;

// 测试无效标签检测
function TestInvalidTag: Boolean;
var
  CtxEnc, CtxDec: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  Key: array[0..15] of Byte;
  IV: array[0..11] of Byte;
  PlainText: array[0..31] of Byte;
  CipherText: array[0..47] of Byte;
  DecryptedText: array[0..47] of Byte;
  Tag: array[0..15] of Byte;
  OutLen, TotalLen, DecLen: Integer;
  i: Integer;
begin
  Result := False;
  
  for i := 0 to 15 do Key[i] := Byte(i);
  for i := 0 to 11 do IV[i] := Byte(i);
  for i := 0 to 31 do PlainText[i] := Byte($DD);
  
  Cipher := EVP_aes_128_gcm();
  
  // 加密
  CtxEnc := EVP_CIPHER_CTX_new();
  if CtxEnc = nil then Exit;
  
  try
    EVP_EncryptInit_ex(CtxEnc, Cipher, nil, nil, nil);
    EVP_CIPHER_CTX_ctrl(CtxEnc, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil);
    EVP_EncryptInit_ex(CtxEnc, nil, nil, @Key[0], @IV[0]);
    EVP_EncryptUpdate(CtxEnc, @CipherText[0], OutLen, @PlainText[0], Length(PlainText));
    TotalLen := OutLen;
    EVP_EncryptFinal_ex(CtxEnc, @CipherText[TotalLen], OutLen);
    Inc(TotalLen, OutLen);
    EVP_CIPHER_CTX_ctrl(CtxEnc, EVP_CTRL_GCM_GET_TAG, GCM_TAG_SIZE, @Tag[0]);
  finally
    EVP_CIPHER_CTX_free(CtxEnc);
  end;
  
  // 篡改标签
  Tag[0] := Tag[0] xor $FF;
  
  // 尝试解密（应该失败）
  CtxDec := EVP_CIPHER_CTX_new();
  if CtxDec = nil then Exit;
  
  try
    EVP_DecryptInit_ex(CtxDec, Cipher, nil, nil, nil);
    EVP_CIPHER_CTX_ctrl(CtxDec, EVP_CTRL_GCM_SET_IVLEN, Length(IV), nil);
    EVP_DecryptInit_ex(CtxDec, nil, nil, @Key[0], @IV[0]);
    DecLen := 0;
    EVP_DecryptUpdate(CtxDec, @DecryptedText[0], DecLen, @CipherText[0], TotalLen);
    EVP_CIPHER_CTX_ctrl(CtxDec, EVP_CTRL_GCM_SET_TAG, GCM_TAG_SIZE, @Tag[0]);
    
    // 应该在这里失败
    if EVP_DecryptFinal_ex(CtxDec, @DecryptedText[DecLen], OutLen) = 1 then
    begin
      WriteLn('  错误: 篡改的标签未被检测到！');
      Result := False;
    end
    else
    begin
      WriteLn('  正确: 篡改的标签被检测并拒绝');
      Result := True;
    end;
    
  finally
    EVP_CIPHER_CTX_free(CtxDec);
  end;
end;

var
  LoadSuccess: Boolean;

begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('AES-GCM AEAD 模式单元测试');
  WriteLn('========================================');
  WriteLn;
  
  TestsPassed := 0;
  TestsFailed := 0;
  
  // 加载 OpenSSL
  Write('加载 OpenSSL 库... ');
  LoadOpenSSLCore;
  LoadSuccess := TOpenSSLLoader.IsModuleLoaded(osmCore);
  if not LoadSuccess then
  begin
    WriteLn('失败');
    WriteLn('错误: 无法加载 OpenSSL 库');
    Halt(1);
  end;
  WriteLn('成功');
  WriteLn('OpenSSL 版本: ', GetOpenSSLVersionString);
  WriteLn;
  
  // 加载 EVP 函数
  Write('加载 EVP 函数... ');
  if LoadEVP(GetCryptoLibHandle) then
    WriteLn('成功')
  else
  begin
    WriteLn('失败');
    UnloadOpenSSLCore;
    Halt(1);
  end;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('开始测试');
  WriteLn('========================================');
  WriteLn;
  
  // 运行测试
  ReportTest('AES-128-GCM 加密', TestAES128GCMEncrypt);
  ReportTest('AES-128-GCM 解密和认证', TestAES128GCMDecrypt);
  ReportTest('AES-256-GCM 加密', TestAES256GCM);
  ReportTest('无效认证标签检测', TestInvalidTag);
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('测试总结');
  WriteLn('========================================');
  WriteLn('通过: ', TestsPassed);
  WriteLn('失败: ', TestsFailed);
  WriteLn('总计: ', TestsPassed + TestsFailed);
  WriteLn;
  
  if TestsFailed = 0 then
    WriteLn('所有测试通过! ✓')
  else
    WriteLn('部分测试失败.');
  
  // 清理
  UnloadEVP;
  UnloadOpenSSLCore;
  
  WriteLn;
  WriteLn('按回车键退出...');
  ReadLn;
end.
