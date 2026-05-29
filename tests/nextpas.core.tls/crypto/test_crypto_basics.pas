program test_crypto_basics;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils, Classes, Windows,
  // OpenSSL 模块
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.sha,
  nextpas.core.tls.openssl.api.aes,
  nextpas.core.tls.openssl.api.hmac,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.pem;

var
  LibCrypto: THandle;
  TestsPassed, TestsFailed: Integer;

procedure PrintTestHeader(const TestName: string);
begin
  WriteLn;
  WriteLn('----------------------------------------');
  WriteLn('测试: ', TestName);
  WriteLn('----------------------------------------');
end;

procedure PrintTestResult(const TestName: string; Success: Boolean; const Details: string = '');
begin
  Write('  ', TestName:40, ': ');
  if Success then
  begin
    WriteLn('[通过]');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[失败] - ', Details);
    Inc(TestsFailed);
  end;
end;

// SHA256 哈希测试
function TestSHA256: Boolean;
var
  Input: string;
  InputBytes: TBytes;
  Hash: array[0..31] of Byte;
  HashStr: string;
  I: Integer;
begin
  Result := False;
  try
    Input := 'Hello, OpenSSL!';
    InputBytes := TEncoding.UTF8.GetBytes(Input);
    
    // 计算 SHA256
    if not Assigned(SHA256) then Exit;
    SHA256(@InputBytes[0], Length(InputBytes), @Hash[0]);
    
    // 转换为十六进制字符串
    HashStr := '';
    for I := 0 to 31 do
      HashStr := HashStr + IntToHex(Hash[I], 2);
    
    WriteLn('    输入: ', Input);
    WriteLn('    SHA256: ', HashStr);
    
    // 验证哈希长度
    Result := Length(HashStr) = 64;
  except
    on E: Exception do
      WriteLn('    错误: ', E.Message);
  end;
end;

// HMAC-SHA256 测试
function TestHMAC: Boolean;
var
  Key, Data: string;
  KeyBytes, DataBytes: TBytes;
  Hash: array[0..31] of Byte;
  HashLen: Cardinal;
  HashStr: string;
  I: Integer;
begin
  Result := False;
  try
    Key := 'secret_key';
    Data := 'message to authenticate';
    KeyBytes := TEncoding.UTF8.GetBytes(Key);
    DataBytes := TEncoding.UTF8.GetBytes(Data);
    HashLen := 32;
    
    // 计算 HMAC-SHA256
    if not Assigned(HMAC) or not Assigned(EVP_sha256) then Exit;
    
    HMAC(EVP_sha256(), @KeyBytes[0], Length(KeyBytes),
         @DataBytes[0], Length(DataBytes), @Hash[0], HashLen);
    
    // 转换为十六进制
    HashStr := '';
    for I := 0 to HashLen - 1 do
      HashStr := HashStr + IntToHex(Hash[I], 2);
    
    WriteLn('    密钥: ', Key);
    WriteLn('    数据: ', Data);
    WriteLn('    HMAC-SHA256: ', HashStr);
    
    Result := HashLen = 32;
  except
    on E: Exception do
      WriteLn('    错误: ', E.Message);
  end;
end;

// AES 加密/解密测试
function TestAESEncryption: Boolean;
var
  Key: array[0..31] of Byte;  // 256-bit key
  IV: array[0..15] of Byte;   // 128-bit IV
  PlainText, CipherText, DecryptedText: string;
  PlainBytes, CipherBytes, DecryptedBytes: TBytes;
  Ctx: PEVP_CIPHER_CTX;
  OutLen, FinalLen: Integer;
begin
  Result := False;
  try
    PlainText := 'This is a secret message for AES encryption test!';
    
    // 生成随机密钥和 IV
    if not Assigned(RAND_bytes) then Exit;
    RAND_bytes(@Key[0], 32);
    RAND_bytes(@IV[0], 16);
    
    // 创建加密上下文
    if not Assigned(EVP_CIPHER_CTX_new) then Exit;
    Ctx := EVP_CIPHER_CTX_new();
    if Ctx = nil then Exit;
    
    try
      PlainBytes := TEncoding.UTF8.GetBytes(PlainText);
      SetLength(CipherBytes, Length(PlainBytes) + 16); // 预留空间
      
      // 初始化加密
      if not Assigned(EVP_EncryptInit_ex) or not Assigned(EVP_aes_256_cbc) then Exit;
      if EVP_EncryptInit_ex(Ctx, EVP_aes_256_cbc(), nil, @Key[0], @IV[0]) <> 1 then Exit;
      
      // 加密数据
      if not Assigned(EVP_EncryptUpdate) then Exit;
      if EVP_EncryptUpdate(Ctx, @CipherBytes[0], OutLen, @PlainBytes[0], Length(PlainBytes)) <> 1 then Exit;
      
      // 完成加密
      if not Assigned(EVP_EncryptFinal_ex) then Exit;
      if EVP_EncryptFinal_ex(Ctx, @CipherBytes[OutLen], FinalLen) <> 1 then Exit;
      SetLength(CipherBytes, OutLen + FinalLen);
      
      WriteLn('    原文长度: ', Length(PlainBytes), ' 字节');
      WriteLn('    密文长度: ', Length(CipherBytes), ' 字节');
      
      // 重置上下文用于解密
      if not Assigned(EVP_CIPHER_CTX_reset) then Exit;
      EVP_CIPHER_CTX_reset(Ctx);
      
      // 初始化解密
      SetLength(DecryptedBytes, Length(CipherBytes) + 16);
      if not Assigned(EVP_DecryptInit_ex) then Exit;
      if EVP_DecryptInit_ex(Ctx, EVP_aes_256_cbc(), nil, @Key[0], @IV[0]) <> 1 then Exit;
      
      // 解密数据
      if not Assigned(EVP_DecryptUpdate) then Exit;
      if EVP_DecryptUpdate(Ctx, @DecryptedBytes[0], OutLen, @CipherBytes[0], Length(CipherBytes)) <> 1 then Exit;
      
      // 完成解密
      if not Assigned(EVP_DecryptFinal_ex) then Exit;
      if EVP_DecryptFinal_ex(Ctx, @DecryptedBytes[OutLen], FinalLen) <> 1 then Exit;
      SetLength(DecryptedBytes, OutLen + FinalLen);
      
      DecryptedText := TEncoding.UTF8.GetString(DecryptedBytes);
      WriteLn('    解密结果匹配: ', (DecryptedText = PlainText));
      
      Result := DecryptedText = PlainText;
    finally
      if Assigned(EVP_CIPHER_CTX_free) then
        EVP_CIPHER_CTX_free(Ctx);
    end;
  except
    on E: Exception do
      WriteLn('    错误: ', E.Message);
  end;
end;

// RSA 密钥生成和签名/验证测试
function TestRSASignature: Boolean;
var
  KeyPair: PEVP_PKEY;
  Ctx: PEVP_PKEY_CTX;
  MdCtx: PEVP_MD_CTX;
  Message: string;
  MessageBytes: TBytes;
  Signature: array[0..511] of Byte;
  SigLen: NativeUInt;
begin
  Result := False;
  try
    // 生成 RSA 密钥对
    if not Assigned(EVP_PKEY_new) then Exit;
    KeyPair := EVP_PKEY_new();
    if KeyPair = nil then Exit;
    
    if not Assigned(EVP_PKEY_CTX_new_id) then Exit;
    Ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
    if Ctx = nil then
    begin
      EVP_PKEY_free(KeyPair);
      Exit;
    end;
    
    try
      // 初始化密钥生成
      if not Assigned(EVP_PKEY_keygen_init) then Exit;
      if EVP_PKEY_keygen_init(Ctx) <= 0 then Exit;
      
      // 设置 RSA 密钥长度
      if not Assigned(EVP_PKEY_CTX_set_rsa_keygen_bits) then Exit;
      if EVP_PKEY_CTX_set_rsa_keygen_bits(Ctx, 2048) <= 0 then Exit;
      
      // 生成密钥
      if not Assigned(EVP_PKEY_keygen) then Exit;
      if EVP_PKEY_keygen(Ctx, @KeyPair) <= 0 then Exit;
      
      WriteLn('    RSA 密钥对生成成功 (2048 位)');
      
      // 准备消息
      Message := 'This is a message to be signed with RSA';
      MessageBytes := TEncoding.UTF8.GetBytes(Message);
      
      // 创建签名上下文
      if not Assigned(EVP_MD_CTX_new) then Exit;
      MdCtx := EVP_MD_CTX_new();
      if MdCtx = nil then Exit;
      
      try
        // 初始化签名
        if not Assigned(EVP_DigestSignInit) or not Assigned(EVP_sha256) then Exit;
        if EVP_DigestSignInit(MdCtx, nil, EVP_sha256(), nil, KeyPair) <= 0 then Exit;
        
        // 计算签名
        SigLen := SizeOf(Signature);
        if not Assigned(EVP_DigestSign) then Exit;
        if EVP_DigestSign(MdCtx, @Signature[0], SigLen, @MessageBytes[0], Length(MessageBytes)) <= 0 then Exit;
        
        WriteLn('    消息: ', Message);
        WriteLn('    签名长度: ', SigLen, ' 字节');
        
        // 重置上下文用于验证
        if not Assigned(EVP_MD_CTX_reset) then Exit;
        EVP_MD_CTX_reset(MdCtx);
        
        // 初始化验证
        if not Assigned(EVP_DigestVerifyInit) then Exit;
        if EVP_DigestVerifyInit(MdCtx, nil, EVP_sha256(), nil, KeyPair) <= 0 then Exit;
        
        // 验证签名
        if not Assigned(EVP_DigestVerify) then Exit;
        Result := EVP_DigestVerify(MdCtx, @Signature[0], SigLen, @MessageBytes[0], Length(MessageBytes)) = 1;
        
        WriteLn('    签名验证: ', BoolToStr(Result, '成功', '失败'));
      finally
        if Assigned(EVP_MD_CTX_free) then
          EVP_MD_CTX_free(MdCtx);
      end;
    finally
      if Assigned(EVP_PKEY_CTX_free) then
        EVP_PKEY_CTX_free(Ctx);
      if Assigned(EVP_PKEY_free) then
        EVP_PKEY_free(KeyPair);
    end;
  except
    on E: Exception do
      WriteLn('    错误: ', E.Message);
  end;
end;

// 随机数生成测试
function TestRandomGeneration: Boolean;
var
  RandomBytes: array[0..31] of Byte;
  RandomStr: string;
  I: Integer;
begin
  Result := False;
  try
    // 生成 32 字节随机数
    if not Assigned(RAND_bytes) then Exit;
    if RAND_bytes(@RandomBytes[0], 32) <> 1 then Exit;
    
    // 转换为十六进制
    RandomStr := '';
    for I := 0 to 31 do
      RandomStr := RandomStr + IntToHex(RandomBytes[I], 2);
    
    WriteLn('    生成 32 字节随机数: ', RandomStr);
    
    // 验证不是全零
    Result := False;
    for I := 0 to 31 do
      if RandomBytes[I] <> 0 then
      begin
        Result := True;
        Break;
      end;
    
    WriteLn('    随机性检查: ', BoolToStr(Result, '通过', '失败'));
  except
    on E: Exception do
      WriteLn('    错误: ', E.Message);
  end;
end;

procedure LoadOpenSSLLibrary;
const
  LIBCRYPTO_NAME = 'libcrypto-1_1-x64.dll';
  LIBCRYPTO_NAME_3 = 'libcrypto-3-x64.dll';
begin
  // 尝试加载 OpenSSL 3.0
  LibCrypto := LoadLibrary(LIBCRYPTO_NAME_3);
  
  // 如果失败，尝试加载 OpenSSL 1.1
  if LibCrypto = 0 then
    LibCrypto := LoadLibrary(LIBCRYPTO_NAME);
  
  if LibCrypto = 0 then
  begin
    WriteLn('错误: 无法加载 OpenSSL 库');
    WriteLn('请确保 OpenSSL DLL 文件在系统路径中');
    Halt(1);
  end;
end;

procedure LoadModules;
begin
  // 加载必要的模块
  LoadErrModule(LibCrypto);
  LoadEVPModule(LibCrypto);
  LoadRandModule(LibCrypto);
  LoadRSAModule(LibCrypto);
  LoadSHAModule(LibCrypto);
  LoadAESModule(LibCrypto);
  LoadHMACModule(LibCrypto);
  LoadBIOModule(LibCrypto);
  LoadPEMModule(LibCrypto);
end;

procedure UnloadModules;
begin
  UnloadPEMModule;
  UnloadBIOModule;
  UnloadHMACModule;
  UnloadAESModule;
  UnloadSHAModule;
  UnloadRSAModule;
  UnloadRandModule;
  UnloadEVPModule;
  UnloadErrModule;
end;

procedure PrintSummary;
var
  Total: Integer;
  PassRate: Double;
begin
  Total := TestsPassed + TestsFailed;
  if Total > 0 then
    PassRate := (TestsPassed / Total) * 100
  else
    PassRate := 0;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('           测试结果汇总');
  WriteLn('========================================');
  WriteLn('  总测试数: ', Total);
  WriteLn('  通过: ', TestsPassed);
  WriteLn('  失败: ', TestsFailed);
  WriteLn('  通过率: ', PassRate:0:1, '%');
  WriteLn('========================================');
  
  if TestsFailed = 0 then
    WriteLn('所有测试通过！')
  else
    WriteLn('存在失败的测试，请检查。');
end;

begin
  WriteLn('========================================');
  WriteLn('     OpenSSL 基础功能测试');
  WriteLn('========================================');
  
  TestsPassed := 0;
  TestsFailed := 0;
  
  // 加载 OpenSSL 库
  WriteLn;
  WriteLn('加载 OpenSSL 库...');
  LoadOpenSSLLibrary;
  LoadModules;
  WriteLn('OpenSSL 库加载成功');
  
  // 执行测试
  PrintTestHeader('随机数生成');
  PrintTestResult('RAND_bytes', TestRandomGeneration);
  
  PrintTestHeader('哈希算法');
  PrintTestResult('SHA256', TestSHA256);
  PrintTestResult('HMAC-SHA256', TestHMAC);
  
  PrintTestHeader('对称加密');
  PrintTestResult('AES-256-CBC', TestAESEncryption);
  
  PrintTestHeader('非对称加密');
  PrintTestResult('RSA 签名/验证', TestRSASignature);
  
  // 打印汇总
  PrintSummary;
  
  // 清理
  WriteLn;
  WriteLn('清理资源...');
  UnloadModules;
  if LibCrypto <> 0 then FreeLibrary(LibCrypto);
  WriteLn('清理完成');
  
  WriteLn;
  WriteLn('按 Enter 退出...');
  ReadLn;
end.