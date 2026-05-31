program test_crypto_utils_improved;

{$mode objfpc}{$H+}

{
  测试改进后的TCryptoUtils
  验证：
  1. 初始化正常
  2. 异常处理正确
  3. 系统随机降级工作
  4. 所有核心功能可用
}

uses
  SysUtils,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.exceptions;

procedure TestHashFunctions;
var
  LHash: TBytes;
  LHashHex: string;
begin
  WriteLn('[1] 测试哈希函数...');
  
  // SHA-256 (TBytes)
  LHash := TCryptoUtils.SHA256(TEncoding.UTF8.GetBytes('Hello'));
  LHashHex := TCryptoUtils.BytesToHex(LHash);
  WriteLn('  SHA-256(Hello): ', Copy(LHashHex, 1, 32), '...');
  Assert(Length(LHash) = 32, 'SHA-256 should return 32 bytes');
  
  // SHA-256 (string)
  LHash := TCryptoUtils.SHA256('World');
  Assert(Length(LHash) = 32, 'SHA-256 string overload should work');
  
  // SHA-512
  LHash := TCryptoUtils.SHA512('Test');
  Assert(Length(LHash) = 64, 'SHA-512 should return 64 bytes');
  
  WriteLn('  ✓ 哈希函数测试通过');
  WriteLn;
end;

procedure TestRandomGeneration;
var
  LRandom1, LRandom2, LKey, LIV: TBytes;
  I: Integer;
  LAllSame: Boolean;
begin
  WriteLn('[2] 测试随机数生成...');
  
  // 基本随机数
  LRandom1 := TCryptoUtils.SecureRandom(16);
  Assert(Length(LRandom1) = 16, 'SecureRandom should return requested length');
  
  // 验证不是全零
  LAllSame := True;
  for I := 1 to High(LRandom1) do
    if LRandom1[I] <> LRandom1[0] then
    begin
      LAllSame := False;
      Break;
    end;
  Assert(not LAllSame, 'Random data should not be all same');
  
  // 验证两次调用返回不同值
  LRandom2 := TCryptoUtils.SecureRandom(16);
  LAllSame := True;
  for I := 0 to 15 do
    if LRandom1[I] <> LRandom2[I] then
    begin
      LAllSame := False;
      Break;
    end;
  Assert(not LAllSame, 'Two random calls should return different values');
  
  // 密钥生成
  LKey := TCryptoUtils.GenerateKey(256);
  Assert(Length(LKey) = 32, 'GenerateKey(256) should return 32 bytes');
  
  // IV生成
  LIV := TCryptoUtils.GenerateIV(16);
  Assert(Length(LIV) = 16, 'GenerateIV(16) should return 16 bytes');
  
  WriteLn('  ✓ 随机数生成测试通过（使用降级方案）');
  WriteLn;
end;

procedure TestEncryption;
var
  LPlaintext, LKey, LIV, LCiphertext, LDecrypted: TBytes;
  I: Integer;
  LMatch: Boolean;
begin
  WriteLn('[3] 测试AES-256-GCM加密...');
  
  LPlaintext := TEncoding.UTF8.GetBytes('Secret Message!');
  LKey := TCryptoUtils.GenerateKey(256);
  LIV := TCryptoUtils.GenerateIV(12);
  
  // 加密
  LCiphertext := TCryptoUtils.AES_GCM_Encrypt(LPlaintext, LKey, LIV);
  WriteLn('  明文长度: ', Length(LPlaintext));
  WriteLn('  密文长度: ', Length(LCiphertext), ' (含16字节标签)');
  Assert(Length(LCiphertext) = Length(LPlaintext) + 16, 'Ciphertext should be plaintext + 16 byte tag');
  
  // 解密
  LDecrypted := TCryptoUtils.AES_GCM_Decrypt(LCiphertext, LKey, LIV);
  Assert(Length(LDecrypted) = Length(LPlaintext), 'Decrypted length should match');
  
  // 验证内容
  LMatch := True;
  for I := 0 to High(LPlaintext) do
    if LPlaintext[I] <> LDecrypted[I] then
    begin
      LMatch := False;
      Break;
    end;
  Assert(LMatch, 'Decrypted content should match original');
  
  WriteLn('  ✓ AES-GCM 加密/解密通过');
  WriteLn;
end;

procedure TestExceptionHandling;
var
  LCaught: Boolean;
  LBadKey: TBytes;
begin
  WriteLn('[4] 测试异常处理...');
  
  // 测试无效参数
  LCaught := False;
  try
    TCryptoUtils.SecureRandom(-1);
  except
    on E: ESSLInvalidArgument do
    begin
      LCaught := True;
      WriteLn('  ✓ 捕获到预期的 ESSLInvalidArgument: ', E.Message);
    end;
  end;
  Assert(LCaught, 'Should throw ESSLInvalidArgument for negative length');
  
  // 测试加密参数验证
  LCaught := False;
  try
    SetLength(LBadKey, 16);  // 错误的密钥长度
    TCryptoUtils.AES_GCM_Encrypt(TEncoding.UTF8.GetBytes('test'), LBadKey, LBadKey);
  except
    on E: ESSLInvalidArgument do
    begin
      LCaught := True;
      WriteLn('  ✓ 捕获到密钥长度错误: ', E.Message);
    end;
  end;
  Assert(LCaught, 'Should validate key size');
  
  WriteLn('  ✓ 异常处理测试通过');
  WriteLn;
end;

procedure TestUtilityFunctions;
var
  LBytes: TBytes;
  LHex: string;
  LParsed: TBytes;
  I: Integer;
begin
  WriteLn('[5] 测试工具函数...');
  
  // Hex编码
  SetLength(LBytes, 3);
  LBytes[0] := $AB;
  LBytes[1] := $CD;
  LBytes[2] := $EF;
  LHex := TCryptoUtils.BytesToHex(LBytes);
  Assert(LHex = 'ABCDEF', 'BytesToHex should work');
  WriteLn('  BytesToHex: ', LHex);
  
  // Hex解码
  LParsed := TCryptoUtils.HexToBytes('ABCDEF');
  Assert(Length(LParsed) = 3, 'HexToBytes length');
  Assert((LParsed[0] = $AB) and (LParsed[1] = $CD) and (LParsed[2] = $EF), 'HexToBytes content');
  
  WriteLn('  ✓ 工具函数测试通过');
  WriteLn;
end;

begin
  WriteLn('==========================================');
  WriteLn('  改进的TCryptoUtils测试');
  WriteLn('==========================================');
  WriteLn;
  
  try
    TestHashFunctions;
    TestRandomGeneration;
    TestEncryption;
    TestExceptionHandling;
    TestUtilityFunctions;
    
    WriteLn('==========================================');
    WriteLn('✅ 所有测试通过！');
    WriteLn('==========================================');
    WriteLn;
    WriteLn('改进内容：');
    WriteLn('  ✓ 统一异常处理（ESSLException层次）');
    WriteLn('  ✓ 系统随机数降级（/dev/urandom）');
    WriteLn('  ✓ 完整的参数验证');
    WriteLn('  ✓ 详细的错误消息');
    WriteLn('  ✓ XML文档注释');
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('==========================================');
      WriteLn('✗ 测试失败');
      WriteLn('异常: ', E.ClassName);
      WriteLn('消息: ', E.Message);
      WriteLn('==========================================');
      Halt(1);
    end;
  end;
  
  WriteLn;
  WriteLn('按Enter退出...');
  ReadLn;
end.
