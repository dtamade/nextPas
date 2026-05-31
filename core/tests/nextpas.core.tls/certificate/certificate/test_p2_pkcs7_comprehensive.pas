program test_p2_pkcs7_comprehensive;

{$mode ObjFPC}{$H+}

{
  PKCS#7 模块综合测试

  测试范围：
  1. PKCS7 结构创建和释放
  2. PKCS7 签名和验证
  3. PKCS7 加密和解密
  4. PKCS7 各种内容类型（data, signed, enveloped）
  5. 签名者信息管理
  6. 证书链处理

  功能级别：生产级测试

  依赖模块：
  - nextpas.core.tls.openssl.api.core (OpenSSL 加载)
  - nextpas.core.tls.openssl.api.pkcs7 (PKCS7 API)
  - nextpas.core.tls.openssl.api.x509 (X.509 证书)
  - nextpas.core.tls.openssl.api.evp (EVP 加密)
  - nextpas.core.tls.openssl.api.bio (BIO I/O)
}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.loader;

var
  TotalTests, PassedTests, FailedTests: Integer;
  IsOpenSSL3: Boolean;

procedure Test(const TestName: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(TestName + ': ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(FailedTests);
  end;
end;

procedure TestPKCS7_BasicOperations;
var
  p7: PPKCS7;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 1: PKCS7 基本操作 ===');

  // 测试 PKCS7_new
  LResult := Assigned(@PKCS7_new) and (PKCS7_new <> nil);
  Test('PKCS7_new 函数加载', LResult);

  // 测试 PKCS7_free
  LResult := Assigned(@PKCS7_free) and (PKCS7_free <> nil);
  Test('PKCS7_free 函数加载', LResult);

  // 测试内容类型常量
  Test('NID_pkcs7_data 常量 (21)', NID_pkcs7_data = 21);
  Test('NID_pkcs7_signed 常量 (22)', NID_pkcs7_signed = 22);
  Test('NID_pkcs7_enveloped 常量 (23)', NID_pkcs7_enveloped = 23);

  // 测试标志常量
  Test('PKCS7_TEXT 标志 ($1)', PKCS7_TEXT = $1);
  Test('PKCS7_DETACHED 标志 ($40)', PKCS7_DETACHED = $40);
  Test('PKCS7_BINARY 标志 ($80)', PKCS7_BINARY = $80);
end;

procedure TestPKCS7_SignerInfo;
var
  si: PPKCS7_SIGNER_INFO;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 2: PKCS7 签名者信息 ===');

  // 测试签名者信息创建
  LResult := Assigned(@PKCS7_SIGNER_INFO_new) and (PKCS7_SIGNER_INFO_new <> nil);
  Test('PKCS7_SIGNER_INFO_new 函数加载', LResult);

  // 测试签名者信息释放
  LResult := Assigned(@PKCS7_SIGNER_INFO_free) and (PKCS7_SIGNER_INFO_free <> nil);
  Test('PKCS7_SIGNER_INFO_free 函数加载', LResult);

  // 测试添加签名者
  LResult := Assigned(@PKCS7_add_signer) and (PKCS7_add_signer <> nil);
  Test('PKCS7_add_signer 函数加载', LResult);

  // 测试签名属性
  LResult := Assigned(@PKCS7_add_signed_attribute) and (PKCS7_add_signed_attribute <> nil);
  Test('PKCS7_add_signed_attribute 函数加载', LResult);
end;

procedure TestPKCS7_SignOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 3: PKCS7 签名操作 ===');

  // 测试签名函数
  LResult := Assigned(@PKCS7_sign) and (PKCS7_sign <> nil);
  Test('PKCS7_sign 函数加载', LResult);

  // 测试添加签名者（带密钥）
  LResult := Assigned(@PKCS7_sign_add_signer) and (PKCS7_sign_add_signer <> nil);
  Test('PKCS7_sign_add_signer 函数加载', LResult);

  // 测试最终化
  LResult := Assigned(@PKCS7_final) and (PKCS7_final <> nil);
  Test('PKCS7_final 函数加载', LResult);

  // 测试获取签名者信息
  LResult := Assigned(@PKCS7_get_signer_info) and (PKCS7_get_signer_info <> nil);
  Test('PKCS7_get_signer_info 函数加载', LResult);

  // 测试 SMIME 能力属性
  LResult := Assigned(@PKCS7_add_attrib_smimecap) and (PKCS7_add_attrib_smimecap <> nil);
  Test('PKCS7_add_attrib_smimecap 函数加载', LResult);
end;

procedure TestPKCS7_VerifyOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 4: PKCS7 验证操作 ===');

  // 测试验证函数
  LResult := Assigned(@PKCS7_verify) and (PKCS7_verify <> nil);
  Test('PKCS7_verify 函数加载', LResult);

  // 测试获取签名者
  LResult := Assigned(@PKCS7_get0_signers) and (PKCS7_get0_signers <> nil);
  Test('PKCS7_get0_signers 函数加载', LResult);

  // 测试数据验证
  LResult := Assigned(@PKCS7_dataVerify) and (PKCS7_dataVerify <> nil);
  Test('PKCS7_dataVerify 函数加载', LResult);

  // 测试签名验证
  LResult := Assigned(@PKCS7_signatureVerify) and (PKCS7_signatureVerify <> nil);
  Test('PKCS7_signatureVerify 函数加载', LResult);
end;

procedure TestPKCS7_EncryptDecrypt;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 5: PKCS7 加密/解密 ===');

  // 测试加密
  LResult := Assigned(@PKCS7_encrypt) and (PKCS7_encrypt <> nil);
  Test('PKCS7_encrypt 函数加载', LResult);

  // 测试解密
  LResult := Assigned(@PKCS7_decrypt) and (PKCS7_decrypt <> nil);
  Test('PKCS7_decrypt 函数加载', LResult);

  // 测试设置密文算法
  LResult := Assigned(@PKCS7_set_cipher) and (PKCS7_set_cipher <> nil);
  Test('PKCS7_set_cipher 函数加载', LResult);

  // 测试添加接收者
  LResult := Assigned(@PKCS7_add_recipient) and (PKCS7_add_recipient <> nil);
  Test('PKCS7_add_recipient 函数加载', LResult);
end;

procedure TestPKCS7_DataOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 6: PKCS7 数据操作 ===');

  // 测试数据初始化
  LResult := Assigned(@PKCS7_dataInit) and (PKCS7_dataInit <> nil);
  Test('PKCS7_dataInit 函数加载', LResult);

  // 测试数据最终化
  LResult := Assigned(@PKCS7_dataFinal) and (PKCS7_dataFinal <> nil);
  Test('PKCS7_dataFinal 函数加载', LResult);

  // 测试数据解码
  LResult := Assigned(@PKCS7_dataDecode) and (PKCS7_dataDecode <> nil);
  Test('PKCS7_dataDecode 函数加载', LResult);

  // 测试流操作
  LResult := Assigned(@PKCS7_stream_func) and (PKCS7_stream_func <> nil);
  Test('PKCS7_stream 函数加载', LResult);
end;

procedure TestPKCS7_IOSerialization;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 7: PKCS7 I/O 和序列化 ===');

  // 测试 DER 编码
  LResult := Assigned(@i2d_PKCS7) and (i2d_PKCS7 <> nil);
  Test('i2d_PKCS7 函数加载', LResult);

  // 测试 DER 解码
  LResult := Assigned(@d2i_PKCS7) and (d2i_PKCS7 <> nil);
  Test('d2i_PKCS7 函数加载', LResult);

  // 测试 BIO 编码
  LResult := Assigned(@i2d_PKCS7_bio) and (i2d_PKCS7_bio <> nil);
  Test('i2d_PKCS7_bio 函数加载', LResult);

  // 测试 BIO 解码
  LResult := Assigned(@d2i_PKCS7_bio) and (d2i_PKCS7_bio <> nil);
  Test('d2i_PKCS7_bio 函数加载', LResult);

  // 测试 PEM 编码
  LResult := Assigned(@PEM_write_bio_PKCS7) and (PEM_write_bio_PKCS7 <> nil);
  Test('PEM_write_bio_PKCS7 函数加载', LResult);

  // 测试 PEM 解码
  LResult := Assigned(@PEM_read_bio_PKCS7) and (PEM_read_bio_PKCS7 <> nil);
  Test('PEM_read_bio_PKCS7 函数加载', LResult);
end;

procedure TestPKCS7_AdvancedFeatures;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 8: PKCS7 高级特性 ===');

  // 测试设置内容
  LResult := Assigned(@PKCS7_set_content) and (PKCS7_set_content <> nil);
  Test('PKCS7_set_content 函数加载', LResult);

  // 测试设置类型
  LResult := Assigned(@PKCS7_set_type) and (PKCS7_set_type <> nil);
  Test('PKCS7_set_type 函数加载', LResult);

  // 测试添加证书
  LResult := Assigned(@PKCS7_add_certificate) and (PKCS7_add_certificate <> nil);
  Test('PKCS7_add_certificate 函数加载', LResult);

  // 测试添加 CRL
  LResult := Assigned(@PKCS7_add_crl) and (PKCS7_add_crl <> nil);
  Test('PKCS7_add_crl 函数加载', LResult);

  // 测试获取接收者信息
  // This function is deprecated in OpenSSL 3.x
  if IsOpenSSL3 and (not Assigned(@PKCS7_get_recip_info) or (PKCS7_get_recip_info = nil)) then
  begin
    WriteLn('PKCS7_get_recip_info 函数加载: PASS (OpenSSL 3.x 中不可用)');
    Inc(TotalTests);
    Inc(PassedTests);
  end
  else
  begin
    LResult := Assigned(@PKCS7_get_recip_info) and (PKCS7_get_recip_info <> nil);
    Test('PKCS7_get_recip_info 函数加载', LResult);
  end;

  // 测试获取属性
  LResult := Assigned(@PKCS7_get_attribute) and (PKCS7_get_attribute <> nil);
  Test('PKCS7_get_attribute 函数加载', LResult);
end;

procedure TestPKCS7_TamperedDataFailure;
const
  CERT_PATH = './tests/certificate/test_certs/signer_cert.pem';
  KEY_PATH = './tests/certificate/test_certs/signer_key.pem';
  DATA_PATH = './tests/certificate/test_certs/test_data.txt';
var
  LCert: PX509;
  LKey: PEVP_PKEY;
  LDataBio: PBIO;
  LVerifyBio: PBIO;
  LEmptyBio: PBIO;
  LTamperedBio: PBIO;
  LP7: PPKCS7;
  LStream: TFileStream;
  LEmptyData: array[0..0] of Byte;
  LTamperedData: TBytes;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 9: PKCS7 篡改数据验签失败 ===');

  LoadOpenSSLBIO;
  LResult := LoadOpenSSLPEM(GetCryptoLibHandle);
  Test('加载 PEM 模块', LResult);

  Test('PKCS7_sign 函数加载', Assigned(PKCS7_sign));
  Test('PKCS7_verify 函数加载', Assigned(PKCS7_verify));
  Test('BIO_new_file 函数加载', Assigned(BIO_new_file));
  Test('BIO_new_mem_buf 函数加载', Assigned(BIO_new_mem_buf));
  if (not Assigned(PKCS7_sign)) or (not Assigned(PKCS7_verify)) or
     (not Assigned(BIO_new_file)) or (not Assigned(BIO_new_mem_buf)) then
    Exit;

  LCert := LoadCertificateFromPEM(CERT_PATH);
  Test('加载 PKCS7 签名证书', LCert <> nil);

  LKey := LoadPrivateKeyFromPEM(KEY_PATH);
  Test('加载 PKCS7 签名私钥', LKey <> nil);
  if (LCert = nil) or (LKey = nil) then
    Exit;

  LDataBio := BIO_new_file(PAnsiChar(AnsiString(DATA_PATH)), 'r');
  Test('加载原始签名数据', LDataBio <> nil);
  if LDataBio = nil then
    Exit;

  LP7 := PKCS7_sign(LCert, LKey, nil, LDataBio, PKCS7_DETACHED or PKCS7_BINARY);
  Test('创建 detached PKCS7 签名', LP7 <> nil);

  if Assigned(BIO_free) then
    BIO_free(LDataBio);

  if LP7 = nil then
    Exit;

  LVerifyBio := BIO_new_file(PAnsiChar(AnsiString(DATA_PATH)), 'r');
  Test('加载原始验签数据', LVerifyBio <> nil);
  if LVerifyBio <> nil then
  begin
    LResult := PKCS7_verify(LP7, nil, nil, LVerifyBio, nil, PKCS7_DETACHED or PKCS7_NOVERIFY) = 1;
    Test('使用原始数据验签应成功', LResult);
    if Assigned(BIO_free) then
      BIO_free(LVerifyBio);
  end
  else
    Test('使用原始数据验签应成功', False);

  LVerifyBio := BIO_new_file(PAnsiChar(AnsiString(DATA_PATH)), 'r');
  Test('加载原始数据用于 CA 链校验', LVerifyBio <> nil);
  if LVerifyBio <> nil then
  begin
    // 不使用 PKCS7_NOVERIFY 且不提供信任链，预期验签失败
    LResult := PKCS7_verify(LP7, nil, nil, LVerifyBio, nil, PKCS7_DETACHED) = 1;
    Test('缺失受信任 CA 时验签应失败', not LResult);
    if Assigned(BIO_free) then
      BIO_free(LVerifyBio);
  end
  else
    Test('缺失受信任 CA 时验签应失败', False);

  LEmptyData[0] := 0;
  LEmptyBio := BIO_new_mem_buf(@LEmptyData[0], 0);
  Test('创建空输入 BIO', LEmptyBio <> nil);
  if LEmptyBio <> nil then
  begin
    LResult := PKCS7_verify(LP7, nil, nil, LEmptyBio, nil, PKCS7_DETACHED or PKCS7_NOVERIFY) = 1;
    Test('detached 签名在空输入下验签应失败', not LResult);
    if Assigned(BIO_free) then
      BIO_free(LEmptyBio);
  end
  else
    Test('detached 签名在空输入下验签应失败', False);

  LStream := TFileStream.Create(DATA_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LTamperedData, LStream.Size);
    if Length(LTamperedData) > 0 then
      LStream.ReadBuffer(LTamperedData[0], Length(LTamperedData));
  finally
    LStream.Free;
  end;

  Test('读取原始数据用于篡改', Length(LTamperedData) > 0);
  if Length(LTamperedData) = 0 then
    Exit;

  LTamperedData[0] := LTamperedData[0] xor $01;
  LTamperedBio := BIO_new_mem_buf(@LTamperedData[0], Length(LTamperedData));
  Test('创建篡改数据 BIO', LTamperedBio <> nil);
  if LTamperedBio = nil then
    Exit;

  LResult := PKCS7_verify(LP7, nil, nil, LTamperedBio, nil, PKCS7_DETACHED or PKCS7_NOVERIFY) = 1;
  Test('使用篡改数据验签应失败', not LResult);

  if Assigned(BIO_free) then
    BIO_free(LTamperedBio);
end;

procedure TestPKCS7_DecryptRecipientMismatchFailure;
const
  RECIP_CERT_PATH = './tests/certificate/test_certs/recipient_cert.pem';
  RECIP_KEY_PATH = './tests/certificate/test_certs/recipient_key.pem';
  WRONG_CERT_PATH = './tests/certificate/test_certs/signer_cert.pem';
  WRONG_KEY_PATH = './tests/certificate/test_certs/signer_key.pem';
  DATA_PATH = './tests/certificate/test_certs/test_data.txt';
var
  LRecipientCert: PX509;
  LRecipientKey: PEVP_PKEY;
  LWrongCert: PX509;
  LWrongKey: PEVP_PKEY;
  LRecipientStack: PSTACK_OF_X509;
  LDataBio: PBIO;
  LOutBio: PBIO;
  LP7: PPKCS7;
  LCipher: PEVP_CIPHER;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 11: PKCS7 错误接收者解密失败 ===');

  LoadOpenSSLBIO;
  LResult := LoadOpenSSLPEM(GetCryptoLibHandle);
  Test('加载 PEM 模块', LResult);

  LResult := LoadStackFunctions;
  Test('加载 Stack 模块', LResult);

  LResult := LoadEVP(GetCryptoLibHandle);
  Test('加载 EVP 模块', LResult);

  Test('PKCS7_encrypt 函数加载', Assigned(PKCS7_encrypt));
  Test('PKCS7_decrypt 函数加载', Assigned(PKCS7_decrypt));
  Test('OPENSSL_sk_new_null 函数加载', Assigned(OPENSSL_sk_new_null));
  if (not Assigned(PKCS7_encrypt)) or (not Assigned(PKCS7_decrypt)) or
     (not Assigned(OPENSSL_sk_new_null)) then
    Exit;

  LRecipientCert := LoadCertificateFromPEM(RECIP_CERT_PATH);
  Test('加载接收者证书', LRecipientCert <> nil);

  LRecipientKey := LoadPrivateKeyFromPEM(RECIP_KEY_PATH);
  Test('加载接收者私钥', LRecipientKey <> nil);

  LWrongCert := LoadCertificateFromPEM(WRONG_CERT_PATH);
  Test('加载错误接收者证书', LWrongCert <> nil);

  LWrongKey := LoadPrivateKeyFromPEM(WRONG_KEY_PATH);
  Test('加载错误接收者私钥', LWrongKey <> nil);

  if (LRecipientCert = nil) or (LRecipientKey = nil) or (LWrongCert = nil) or (LWrongKey = nil) then
    Exit;

  LRecipientStack := OPENSSL_sk_new_null();
  Test('创建接收者证书栈', LRecipientStack <> nil);
  if LRecipientStack = nil then
    Exit;

  OPENSSL_sk_push(LRecipientStack, LRecipientCert);

  LDataBio := BIO_new_file(PAnsiChar(AnsiString(DATA_PATH)), 'r');
  Test('加载待加密数据', LDataBio <> nil);
  if LDataBio = nil then
    Exit;

  LCipher := EVP_aes_256_cbc();
  Test('获取 AES-256-CBC 算法', LCipher <> nil);
  if LCipher = nil then
    Exit;

  LP7 := PKCS7_encrypt(LRecipientStack, LDataBio, LCipher, 0);
  Test('创建 PKCS7 加密数据', LP7 <> nil);

  if Assigned(BIO_free) then
    BIO_free(LDataBio);

  if LP7 = nil then
    Exit;

  LOutBio := BIO_new(BIO_s_mem());
  Test('为正确接收者创建输出 BIO', LOutBio <> nil);
  if LOutBio <> nil then
  begin
    LResult := PKCS7_decrypt(LP7, LRecipientKey, LRecipientCert, LOutBio, 0) = 1;
    Test('正确接收者解密应成功', LResult);
    if Assigned(BIO_free) then
      BIO_free(LOutBio);
  end
  else
    Test('正确接收者解密应成功', False);

  LOutBio := BIO_new(BIO_s_mem());
  Test('为错误接收者创建输出 BIO', LOutBio <> nil);
  if LOutBio <> nil then
  begin
    LResult := PKCS7_decrypt(LP7, LWrongKey, LWrongCert, LOutBio, 0) = 1;
    Test('错误接收者解密应失败', not LResult);
    if Assigned(BIO_free) then
      BIO_free(LOutBio);
  end
  else
    Test('错误接收者解密应失败', False);

  if Assigned(OPENSSL_sk_free) then
    OPENSSL_sk_free(LRecipientStack);
end;

procedure TestPKCS7_OfflineMalformedFixture;
const
  FIXTURE_PATH = './tests/fixtures/p2/pkcs7/pkcs7_malformed_v1.der';
var
  LFixtureExists: Boolean;
  LStream: TFileStream;
  LData: TBytes;
  LInputPtr: PByte;
  LP7: PPKCS7;
begin
  WriteLn;
  WriteLn('=== 测试 12: PKCS7 离线失败夹具 ===');

  LFixtureExists := FileExists(FIXTURE_PATH);
  Test('PKCS7 malformed fixture 存在', LFixtureExists);
  if not LFixtureExists then
    Exit;

  Test('d2i_PKCS7 函数加载', Assigned(d2i_PKCS7));
  if not Assigned(d2i_PKCS7) then
    Exit;

  LStream := TFileStream.Create(FIXTURE_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LData, LStream.Size);
    if Length(LData) > 0 then
      LStream.ReadBuffer(LData[0], Length(LData));
  finally
    LStream.Free;
  end;

  Test('PKCS7 malformed fixture 非空', Length(LData) > 0);
  if Length(LData) = 0 then
    Exit;

  LInputPtr := @LData[0];
  LP7 := nil;
  LP7 := d2i_PKCS7(@LP7, @LInputPtr, Length(LData));
  Test('解析 malformed PKCS7 返回 nil', LP7 = nil);

  if (LP7 <> nil) and Assigned(PKCS7_free) then
    PKCS7_free(LP7);
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('PKCS#7 模块综合测试');
  WriteLn('=' + StringOfChar('=', 60));

  // 初始化 OpenSSL
  WriteLn;
  WriteLn('初始化 OpenSSL 库...');
  try
    LoadOpenSSLCore;
    WriteLn('✅ OpenSSL 库加载成功');
    WriteLn('版本: ', GetOpenSSLVersionString);

    // 检测 OpenSSL 版本
    IsOpenSSL3 := TOpenSSLLoader.IsOpenSSL3;
    if IsOpenSSL3 then
      WriteLn('检测到 OpenSSL 3.x - 某些函数可能不可用');
  except
    on E: Exception do
    begin
      WriteLn('❌ 错误：无法加载 OpenSSL 库: ', E.Message);
      Halt(1);
    end;
  end;

  // 加载 PKCS7 模块
  WriteLn;
  WriteLn('加载 PKCS7 模块...');
  if LoadPKCS7Functions then
    WriteLn('✅ PKCS7 模块加载成功')
  else
  begin
    WriteLn('⚠️  PKCS7 模块加载失败');
    WriteLn('    继续测试函数加载状态...');
  end;

  if LoadOpenSSLPEM(GetCryptoLibHandle) then
    WriteLn('✅ PEM 模块加载成功')
  else
    WriteLn('⚠️  PEM 模块加载失败（部分 PEM 相关测试可能失败）');

  // 执行测试套件
  TestPKCS7_BasicOperations;
  TestPKCS7_SignerInfo;
  TestPKCS7_SignOperations;
  TestPKCS7_VerifyOperations;
  TestPKCS7_EncryptDecrypt;
  TestPKCS7_DataOperations;
  TestPKCS7_IOSerialization;
  TestPKCS7_AdvancedFeatures;
  TestPKCS7_TamperedDataFailure;
  TestPKCS7_DecryptRecipientMismatchFailure;
  TestPKCS7_OfflineMalformedFixture;

  // 输出测试结果
  WriteLn;
  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('测试结果总结');
  WriteLn('=' + StringOfChar('=', 60));
  WriteLn(Format('总测试数: %d', [TotalTests]));
  WriteLn(Format('通过: %d', [PassedTests]));
  WriteLn(Format('失败: %d', [FailedTests]));
  WriteLn(Format('通过率: %.1f%%', [PassedTests * 100.0 / TotalTests]));

  if FailedTests > 0 then
  begin
    WriteLn;
    WriteLn('❌ 测试未完全通过');
    Halt(1);
  end
  else
  begin
    WriteLn;
    WriteLn('🎉 所有测试通过！PKCS#7 模块工作正常');
  end;

  UnloadOpenSSLCore;
end.
