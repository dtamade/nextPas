program digital_signature;

{$mode objfpc}{$H+}

{ ============================================================================
  示例 6: 数字签名与验证（RSA-SHA256）
  
  功能：演示如何使用 RSA 密钥进行数字签名和验证
  用途：学习数字签名的创建、验证和应用
  
  应用场景：
    - 文件完整性验证
    - 软件包签名
    - API 请求认证
    - 数字证书签发
  
  编译：fpc -Fusrc -Fusrc/openssl 06_digital_signature.pas
  运行：06_digital_signature
  ============================================================================ }

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp;

{ 辅助函数：字节数组转十六进制字符串 }
function BytesToHex(const ABytes: array of Byte; ALen: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to ALen - 1 do
    Result := Result + IntToHex(ABytes[i], 2);
end;

{ RSA + SHA256 数字签名演示 }
procedure DemonstrateRSASigning;
var
  LLib: ISSLLibrary;
  LPKey: PEVP_PKEY;
  LPKeyCtx: PEVP_PKEY_CTX;
  LMDCtx: PEVP_MD_CTX;
  LMD: PEVP_MD;
  LMessage, LTamperedMsg: AnsiString;
  LSignature: array[0..511] of Byte;  // RSA 2048 = 256 bytes max
  LSigLen: NativeUInt;
  LVerifyResult: Integer;
begin
  WriteLn('================================================================================');
  WriteLn('  示例 6: RSA-SHA256 数字签名与验证');
  WriteLn('  演示密钥生成、签名创建和验证过程');
  WriteLn('================================================================================');
  WriteLn;
  
  // 初始化 SSL 库
  WriteLn('[1/5] 初始化 SSL 库');
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not LLib.Initialize then
  begin
  WriteLn('     ✗ 无法初始化 SSL 库');
    Exit;
  end;
  WriteLn('     ✓ SSL 库初始化成功');
  WriteLn('     版本: ', LLib.GetVersionString);
  WriteLn;
  
  try
    // 1. 生成 RSA 密钥对（使用现代 EVP API）
    WriteLn('[2/5] 生成 RSA 密钥对');
    WriteLn('     密钥长度: 2048 位');
    WriteLn('     算法: RSA');
    WriteLn;
    
    // 创建密钥生成上下文
    WriteLn('     正在生成密钥对...');
    LPKeyCtx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
    if LPKeyCtx = nil then
    begin
      WriteLn('     ✗ 无法创建密钥生成上下文');
      Exit;
    end;
    
    // 初始化密钥生成
    if EVP_PKEY_keygen_init(LPKeyCtx) <> 1 then
    begin
      EVP_PKEY_CTX_free(LPKeyCtx);
      WriteLn('     ✗ 密钥生成初始化失败');
      Exit;
    end;
    
    // 设置 RSA 密钥长度为 2048 位
    if EVP_PKEY_CTX_ctrl(LPKeyCtx, EVP_PKEY_RSA, EVP_PKEY_OP_KEYGEN, 
                         EVP_PKEY_CTRL_RSA_KEYGEN_BITS, 2048, nil) <= 0 then
    begin
      EVP_PKEY_CTX_free(LPKeyCtx);
      WriteLn('     ✗ 无法设置密钥长度');
      Exit;
    end;
    
    // 生成密钥对
    LPKey := nil;
    if EVP_PKEY_keygen(LPKeyCtx, LPKey) <> 1 then
    begin
      EVP_PKEY_CTX_free(LPKeyCtx);
      WriteLn('     ✗ 密钥生成失败');
      Exit;
    end;
    
    EVP_PKEY_CTX_free(LPKeyCtx);
    
    WriteLn('     ✓ 密钥对生成成功');
    WriteLn('     密钥长度: ', EVP_PKEY_get_bits(LPKey), ' 位');
    WriteLn;
    
    // 2. 准备要签名的消息
    WriteLn('[3/5] 准备签名数据');
    LMessage := 'This is a test message for digital signature verification.';
    WriteLn('     消息: ', LMessage);
    WriteLn('     消息长度: ', Length(LMessage), ' 字节');
    WriteLn;
    
    // 3. 创建数字签名
    WriteLn('[4/5] 创建数字签名');
    WriteLn('     算法: RSA + SHA-256');
    WriteLn;
    
    LMDCtx := EVP_MD_CTX_new();
    if LMDCtx = nil then
    begin
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 无法创建消息摘要上下文');
      Exit;
    end;
    
    LMD := EVP_sha256();
    if LMD = nil then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 无法获取 SHA-256 算法');
      Exit;
    end;
    
    // 初始化签名操作
    LPKeyCtx := nil;
    if EVP_DigestSignInit(LMDCtx, @LPKeyCtx, LMD, nil, LPKey) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 签名初始化失败');
      Exit;
    end;
    
    // 计算签名长度
    LSigLen := 0;
    if EVP_DigestSignFinal(LMDCtx, nil, LSigLen) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 无法获取签名长度');
      Exit;
    end;
    
    WriteLn('     签名长度: ', LSigLen, ' 字节');
    
    // 生成签名
    if EVP_DigestSignUpdate(LMDCtx, @LMessage[1], Length(LMessage)) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 签名更新失败');
      Exit;
    end;

    if EVP_DigestSignFinal(LMDCtx, @LSignature[0], LSigLen) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 签名生成失败');
      Exit;
    end;
    
    WriteLn('     ✓ 签名创建成功');
    WriteLn('     签名 (前 32 字节): ', BytesToHex(LSignature, 32));
    WriteLn;
    
    EVP_MD_CTX_free(LMDCtx);
    
    // 4. 验证数字签名
    WriteLn('[5/5] 验证数字签名');
    WriteLn;
    
    // 4.1 验证原始消息
    WriteLn('  测试 1: 验证原始消息');
    LMDCtx := EVP_MD_CTX_new();
    if LMDCtx = nil then
    begin
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 无法创建消息摘要上下文');
      Exit;
    end;
    
    LPKeyCtx := nil;
    if EVP_DigestVerifyInit(LMDCtx, @LPKeyCtx, EVP_sha256(), nil, LPKey) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 验证初始化失败');
      Exit;
    end;
    
    if EVP_DigestVerifyUpdate(LMDCtx, @LMessage[1], Length(LMessage)) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 验证更新失败');
      Exit;
    end;

    LVerifyResult := EVP_DigestVerifyFinal(LMDCtx, @LSignature[0], LSigLen);
    
    if LVerifyResult = 1 then
      WriteLn('     ✓ 签名验证通过 - 消息完整且未被篡改')
    else
      WriteLn('     ✗ 签名验证失败 - 消息可能被篡改');
    
    WriteLn;
    EVP_MD_CTX_free(LMDCtx);
    
    // 4.2 验证被篡改的消息
    WriteLn('  测试 2: 验证被篡改的消息');
    LTamperedMsg := 'This is a TAMPERED message for digital signature verification.';
    WriteLn('     篡改后消息: ', LTamperedMsg);
    
    LMDCtx := EVP_MD_CTX_new();
    if LMDCtx = nil then
    begin
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 无法创建消息摘要上下文');
      Exit;
    end;
    
    LPKeyCtx := nil;
    if EVP_DigestVerifyInit(LMDCtx, @LPKeyCtx, EVP_sha256(), nil, LPKey) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 验证初始化失败');
      Exit;
    end;
    
    if EVP_DigestVerifyUpdate(LMDCtx, @LTamperedMsg[1], Length(LTamperedMsg)) <> 1 then
    begin
      EVP_MD_CTX_free(LMDCtx);
      EVP_PKEY_free(LPKey);
      WriteLn('     ✗ 验证更新失败');
      Exit;
    end;

    LVerifyResult := EVP_DigestVerifyFinal(LMDCtx, @LSignature[0], LSigLen);
    
    if LVerifyResult = 1 then
      WriteLn('     ✗ 签名验证通过 - 这不应该发生！')
    else
      WriteLn('     ✓ 签名验证失败 - 成功检测到消息篡改');
    
    WriteLn;
    EVP_MD_CTX_free(LMDCtx);
    
    // 清理资源
    EVP_PKEY_free(LPKey);
    
    WriteLn('================================================================================');
    WriteLn('  ✓ 示例执行完成！');
    WriteLn('================================================================================');
    WriteLn;
    WriteLn('💡 学到的知识：');
    WriteLn('  1. 如何生成 RSA 密钥对（2048 位）');
    WriteLn('  2. 如何使用 RSA + SHA-256 创建数字签名');
    WriteLn('  3. 如何验证数字签名的有效性');
    WriteLn('  4. 数字签名可以检测消息篡改');
    WriteLn;
    WriteLn('🔒 数字签名的作用：');
    WriteLn('  - 完整性：确保数据未被修改');
    WriteLn('  - 身份认证：证明数据来源');
    WriteLn('  - 不可否认性：签名者无法否认签署行为');
    WriteLn;
    WriteLn('📚 实际应用：');
    WriteLn('  - 软件包签名（APK、RPM、DEB）');
    WriteLn('  - 代码签名证书（EXE、DLL）');
    WriteLn('  - JWT 令牌签名');
    WriteLn('  - 区块链交易签名');
    WriteLn('  - PDF 文档签名');
    WriteLn;
    WriteLn('⚙️ 技术细节：');
    WriteLn('  - RSA 2048 位密钥提供约 112 位安全强度');
    WriteLn('  - SHA-256 提供 256 位哈希输出');
    WriteLn('  - 签名长度等于 RSA 密钥长度（256 字节）');
    WriteLn('  - 验证速度比签名快 (公钥运算vs私钥运算)');
    WriteLn;
    
    ExitCode := 0;
    
  finally
    LLib.Finalize;
  end;
end;

begin
  try
    DemonstrateRSASigning;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('================================================================================');
      WriteLn('  ✗ 错误: ', E.Message);
      WriteLn('================================================================================');
      WriteLn;
      ExitCode := 1;
    end;
  end;
end.
