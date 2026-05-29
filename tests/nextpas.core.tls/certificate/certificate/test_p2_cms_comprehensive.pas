program test_p2_cms_comprehensive;

{$mode ObjFPC}{$H+}

{
  CMS (加密消息语法) 模块综合测试

  测试范围：
  1. CMS 结构创建和释放
  2. CMS 签名和验证
  3. CMS 加密和解密
  4. CMS 收据处理
  5. CMS 接收者信息
  6. CMS 属性管理

  功能级别：生产级测试

  依赖模块：
  - nextpas.core.tls.openssl.api.core (OpenSSL 加载)
  - nextpas.core.tls.openssl.api.cms (CMS API)
  - nextpas.core.tls.openssl.api.x509 (X.509 证书)
  - nextpas.core.tls.openssl.api.evp (EVP 加密)
  - nextpas.core.tls.openssl.api.bio (BIO I/O)
}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.cms,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.pem;

var
  TotalTests, PassedTests, FailedTests: Integer;

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

procedure TestCMS_ContentInfo;
var
  cms: PCMS_ContentInfo;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 1: CMS ContentInfo 基本操作 ===');

  // 测试 CMS_ContentInfo_new
  LResult := Assigned(@CMS_ContentInfo_new) and (CMS_ContentInfo_new <> nil);
  Test('CMS_ContentInfo_new 函数加载', LResult);

  // 测试 CMS_ContentInfo_free
  LResult := Assigned(@CMS_ContentInfo_free) and (CMS_ContentInfo_free <> nil);
  Test('CMS_ContentInfo_free 函数加载', LResult);

  // 测试 DER 编码
  LResult := Assigned(@i2d_CMS_ContentInfo) and (i2d_CMS_ContentInfo <> nil);
  Test('i2d_CMS_ContentInfo 函数加载', LResult);

  // 测试 DER 解码
  LResult := Assigned(@d2i_CMS_ContentInfo) and (d2i_CMS_ContentInfo <> nil);
  Test('d2i_CMS_ContentInfo 函数加载', LResult);

  // 测试 BIO 编码
  LResult := Assigned(@i2d_CMS_bio) and (i2d_CMS_bio <> nil);
  Test('i2d_CMS_bio 函数加载', LResult);

  // 测试 BIO 解码
  LResult := Assigned(@d2i_CMS_bio) and (d2i_CMS_bio <> nil);
  Test('d2i_CMS_bio 函数加载', LResult);
end;

procedure TestCMS_SignOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 2: CMS 签名操作 ===');

  // 测试签名函数
  LResult := Assigned(@CMS_sign) and (CMS_sign <> nil);
  Test('CMS_sign 函数加载', LResult);

  // 测试添加签名者
  LResult := Assigned(@CMS_add1_signer) and (CMS_add1_signer <> nil);
  Test('CMS_add1_signer 函数加载', LResult);

  // 测试收据签名
  LResult := Assigned(@CMS_sign_receipt) and (CMS_sign_receipt <> nil);
  Test('CMS_sign_receipt 函数加载', LResult);

  // 测试最终化
  LResult := Assigned(@CMS_final) and (CMS_final <> nil);
  Test('CMS_final 函数加载', LResult);

  // 测试数据初始化
  LResult := Assigned(@CMS_dataInit) and (CMS_dataInit <> nil);
  Test('CMS_dataInit 函数加载', LResult);

  // 测试数据最终化
  LResult := Assigned(@CMS_data) and (CMS_data <> nil);
  Test('CMS_data 函数加载', LResult);
end;

procedure TestCMS_VerifyOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 3: CMS 验证操作 ===');

  // 测试验证函数
  LResult := Assigned(@CMS_verify) and (CMS_verify <> nil);
  Test('CMS_verify 函数加载', LResult);

  // 测试获取签名者
  LResult := Assigned(@CMS_get0_signers) and (CMS_get0_signers <> nil);
  Test('CMS_get0_signers 函数加载', LResult);

  // 测试数据验证
  LResult := Assigned(@CMS_digest_verify) and (CMS_digest_verify <> nil);
  Test('CMS_digest_verify 函数加载', LResult);

  // 测试签名验证
  LResult := Assigned(@CMS_SignerInfo_verify) and (CMS_SignerInfo_verify <> nil);
  Test('CMS_SignerInfo_verify 函数加载', LResult);

  // 测试获取签名者信息
  LResult := Assigned(@CMS_get0_SignerInfos) and (CMS_get0_SignerInfos <> nil);
  Test('CMS_get0_SignerInfos 函数加载', LResult);
end;

procedure TestCMS_EncryptDecrypt;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 4: CMS 加密/解密 ===');

  // 测试加密函数
  LResult := Assigned(@CMS_encrypt) and (CMS_encrypt <> nil);
  Test('CMS_encrypt 函数加载', LResult);

  // 测试解密函数
  LResult := Assigned(@CMS_decrypt) and (CMS_decrypt <> nil);
  Test('CMS_decrypt 函数加载', LResult);

  // 测试设置密文算法
  LResult := Assigned(@CMS_set1_eContentType) and (CMS_set1_eContentType <> nil);
  Test('CMS_set1_eContentType 函数加载', LResult);

  // 测试获取内容类型
  LResult := Assigned(@CMS_get0_type) and (CMS_get0_type <> nil);
  Test('CMS_get0_type 函数加载', LResult);

  // 测试获取内容
  LResult := Assigned(@CMS_get0_content) and (CMS_get0_content <> nil);
  Test('CMS_get0_content 函数加载', LResult);
end;

procedure TestCMS_RecipientInfo;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 5: CMS 接收者信息 ===');

  // 测试添加接收者
  LResult := Assigned(@CMS_add1_recipient_cert) and (CMS_add1_recipient_cert <> nil);
  Test('CMS_add1_recipient_cert 函数加载', LResult);

  // 测试接收者信息类型常量
  Test('CMS_RECIPINFO_TRANS (0)', CMS_RECIPINFO_TRANS = 0);
  Test('CMS_RECIPINFO_AGREE (1)', CMS_RECIPINFO_AGREE = 1);
  Test('CMS_RECIPINFO_KEK (2)', CMS_RECIPINFO_KEK = 2);
  Test('CMS_RECIPINFO_PASS (3)', CMS_RECIPINFO_PASS = 3);
  Test('CMS_RECIPINFO_OTHER (4)', CMS_RECIPINFO_OTHER = 4);
end;

procedure TestCMS_ReceiptOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 6: CMS 收据操作 ===');

  // 测试收据请求
  LResult := Assigned(@CMS_ReceiptRequest_create0) and (CMS_ReceiptRequest_create0 <> nil);
  Test('CMS_ReceiptRequest_create0 函数加载', LResult);

  // Note: CMS_get1_Receipt does not exist in OpenSSL 3.x

  // 测试收据验证
  LResult := Assigned(@CMS_verify_receipt) and (CMS_verify_receipt <> nil);
  Test('CMS_verify_receipt 函数加载', LResult);

  // 测试获取原始收据请求
  LResult := Assigned(@CMS_get1_ReceiptRequest) and (CMS_get1_ReceiptRequest <> nil);
  Test('CMS_get1_ReceiptRequest 函数加载', LResult);
end;

procedure TestCMS_Attributes;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 7: CMS 属性管理 ===');

  // 测试添加签名属性
  LResult := Assigned(@CMS_signed_add1_attr) and (CMS_signed_add1_attr <> nil);
  Test('CMS_signed_add1_attr 函数加载', LResult);

  // 测试获取属性
  LResult := Assigned(@CMS_signed_get_attr) and (CMS_signed_get_attr <> nil);
  Test('CMS_signed_get_attr 函数加载', LResult);
end;

procedure TestCMS_UtilityFunctions;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 8: CMS 工具函数 ===');

  // 测试获取内容
  LResult := Assigned(@CMS_get0_content) and (CMS_get0_content <> nil);
  Test('CMS_get0_content 函数加载', LResult);

  // 测试打印函数
  LResult := Assigned(@CMS_ContentInfo_print_ctx) and (CMS_ContentInfo_print_ctx <> nil);
  Test('CMS_ContentInfo_print_ctx 函数加载', LResult);

  // 测试流操作
  LResult := Assigned(@i2d_CMS_bio_stream) and (i2d_CMS_bio_stream <> nil);
  Test('i2d_CMS_bio_stream 函数加载', LResult);

  // 测试标志常量
  Test('CMS_TEXT 标志 ($1)', CMS_TEXT = $1);
  Test('CMS_DETACHED 标志 ($40)', CMS_DETACHED = $40);
  Test('CMS_BINARY 标志 ($80)', CMS_BINARY = $80);
  Test('CMS_STREAM 标志 ($1000)', CMS_STREAM = $1000);
  Test('CMS_PARTIAL 标志 ($4000)', CMS_PARTIAL = $4000);
  Test('CMS_REUSE_DIGEST 标志 ($8000)', CMS_REUSE_DIGEST = $8000);
  Test('CMS_USE_KEYID 标志 ($10000)', CMS_USE_KEYID = $10000);
end;

procedure TestCMS_TamperedDataFailure;
const
  CERT_PATH = './tests/certificate/test_certs/signer_cert.pem';
  KEY_PATH = './tests/certificate/test_certs/signer_key.pem';
  DATA_PATH = './tests/certificate/test_certs/test_data.txt';
var
  LCert: PX509;
  LKey: PEVP_PKEY;
  LCMS: PCMS_ContentInfo;
  LStream: TFileStream;
  LData: TBytes;
  LEmptyData: TBytes;
  LTamperedData: TBytes;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 9: CMS 篡改数据验签失败 ===');

  LoadOpenSSLBIO;
  LResult := LoadOpenSSLPEM(GetCryptoLibHandle);
  Test('加载 PEM 模块', LResult);

  Test('CMS_sign 函数加载', Assigned(CMS_sign));
  Test('CMS_verify 函数加载', Assigned(CMS_verify));
  if (not Assigned(CMS_sign)) or (not Assigned(CMS_verify)) then
    Exit;

  LCert := LoadCertificateFromPEM(CERT_PATH);
  Test('加载 CMS 签名证书', LCert <> nil);

  LKey := LoadPrivateKeyFromPEM(KEY_PATH);
  Test('加载 CMS 签名私钥', LKey <> nil);
  if (LCert = nil) or (LKey = nil) then
    Exit;

  LStream := TFileStream.Create(DATA_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LData, LStream.Size);
    if Length(LData) > 0 then
      LStream.ReadBuffer(LData[0], Length(LData));
  finally
    LStream.Free;
  end;

  Test('读取原始数据用于签名', Length(LData) > 0);
  if Length(LData) = 0 then
    Exit;

  LCMS := CMSSignData(LData, LCert, LKey);
  Test('创建 detached CMS 签名', LCMS <> nil);

  if LCMS = nil then
    Exit;

  LResult := CMSVerifySignature(LData, LCMS, nil, nil, CMS_NOVERIFY);
  Test('使用原始数据验签应成功', LResult);

  // 不使用 CMS_NOVERIFY 且不提供信任链，预期验签失败
  LResult := CMSVerifySignature(LData, LCMS, nil, nil, 0);
  Test('缺失受信任 CA 时验签应失败', not LResult);

  SetLength(LEmptyData, 0);
  LResult := CMSVerifySignature(LEmptyData, LCMS, nil, nil, CMS_NOVERIFY);
  Test('detached 签名在空输入下验签应失败', not LResult);

  LTamperedData := Copy(LData, 0, Length(LData));
  Test('复制原始数据用于篡改', Length(LTamperedData) > 0);
  if Length(LTamperedData) = 0 then
    Exit;

  LTamperedData[0] := LTamperedData[0] xor $01;
  LResult := CMSVerifySignature(LTamperedData, LCMS, nil, nil, CMS_NOVERIFY);
  Test('使用篡改数据验签应失败', not LResult);

  if Assigned(CMS_ContentInfo_free) then
    CMS_ContentInfo_free(LCMS);
end;

procedure TestCMS_DecryptRecipientMismatchFailure;
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
  LRecipients: PSTACK_OF_X509;
  LStream: TFileStream;
  LData: TBytes;
  LEncryptedCMS: PCMS_ContentInfo;
  LOutBio: PBIO;
  LReadBuffer: array[0..255] of Byte;
  LReadLen: Integer;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 11: CMS 错误接收者解密失败 ===');

  LoadOpenSSLBIO;
  LResult := LoadOpenSSLPEM(GetCryptoLibHandle);
  Test('加载 PEM 模块', LResult);

  LResult := LoadStackFunctions;
  Test('加载 Stack 模块', LResult);

  LResult := LoadEVP(GetCryptoLibHandle);
  Test('加载 EVP 模块', LResult);

  Test('CMS_encrypt 函数加载', Assigned(CMS_encrypt));
  Test('CMS_decrypt 函数加载', Assigned(CMS_decrypt));
  Test('OPENSSL_sk_new_null 函数加载', Assigned(OPENSSL_sk_new_null));
  if (not Assigned(CMS_encrypt)) or (not Assigned(CMS_decrypt)) or
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

  LRecipients := OPENSSL_sk_new_null();
  Test('创建 CMS 接收者证书栈', LRecipients <> nil);
  if LRecipients = nil then
    Exit;

  OPENSSL_sk_push(LRecipients, LRecipientCert);

  LStream := TFileStream.Create(DATA_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LData, LStream.Size);
    if Length(LData) > 0 then
      LStream.ReadBuffer(LData[0], Length(LData));
  finally
    LStream.Free;
  end;

  Test('读取待加密数据', Length(LData) > 0);
  if Length(LData) = 0 then
    Exit;

  LEncryptedCMS := CMSEncryptData(LData, LRecipients, EVP_aes_256_cbc(), 0);
  Test('创建 CMS 加密数据', LEncryptedCMS <> nil);
  if LEncryptedCMS = nil then
    Exit;

  LOutBio := BIO_new(BIO_s_mem());
  Test('为正确接收者创建输出 BIO', LOutBio <> nil);
  if LOutBio <> nil then
  begin
    LResult := CMS_decrypt(LEncryptedCMS, LRecipientKey, LRecipientCert, nil, LOutBio, 0) = 1;
    Test('正确接收者解密应成功', LResult);
    if LResult then
    begin
      LReadLen := BIO_read(LOutBio, @LReadBuffer[0], SizeOf(LReadBuffer));
      Test('正确接收者解密输出非空', LReadLen > 0);
    end
    else
      Test('正确接收者解密输出非空', False);
    if Assigned(BIO_free) then
      BIO_free(LOutBio);
  end
  else
  begin
    Test('正确接收者解密应成功', False);
    Test('正确接收者解密输出非空', False);
  end;

  LOutBio := BIO_new(BIO_s_mem());
  Test('为错误接收者创建输出 BIO', LOutBio <> nil);
  if LOutBio <> nil then
  begin
    LResult := CMS_decrypt(LEncryptedCMS, LWrongKey, LWrongCert, nil, LOutBio, 0) = 1;
    Test('错误接收者解密应失败', not LResult);
    if Assigned(BIO_free) then
      BIO_free(LOutBio);
  end
  else
    Test('错误接收者解密应失败', False);

  if Assigned(CMS_ContentInfo_free) then
    CMS_ContentInfo_free(LEncryptedCMS);

  if Assigned(OPENSSL_sk_free) then
    OPENSSL_sk_free(LRecipients);
end;

procedure TestCMS_OfflineMalformedFixture;
const
  FIXTURE_PATH = './tests/fixtures/p2/cms/cms_malformed_v1.der';
var
  LFixtureExists: Boolean;
  LStream: TFileStream;
  LData: TBytes;
  LInputPtr: PByte;
  LCMS: PCMS_ContentInfo;
begin
  WriteLn;
  WriteLn('=== 测试 12: CMS 离线失败夹具 ===');

  LFixtureExists := FileExists(FIXTURE_PATH);
  Test('CMS malformed fixture 存在', LFixtureExists);
  if not LFixtureExists then
    Exit;

  Test('d2i_CMS_ContentInfo 函数加载', Assigned(d2i_CMS_ContentInfo));
  if not Assigned(d2i_CMS_ContentInfo) then
    Exit;

  LStream := TFileStream.Create(FIXTURE_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LData, LStream.Size);
    if Length(LData) > 0 then
      LStream.ReadBuffer(LData[0], Length(LData));
  finally
    LStream.Free;
  end;

  Test('CMS malformed fixture 非空', Length(LData) > 0);
  if Length(LData) = 0 then
    Exit;

  LInputPtr := @LData[0];
  LCMS := nil;
  LCMS := d2i_CMS_ContentInfo(@LCMS, @LInputPtr, Length(LData));
  Test('解析 malformed CMS 返回 nil', LCMS = nil);

  if (LCMS <> nil) and Assigned(CMS_ContentInfo_free) then
    CMS_ContentInfo_free(LCMS);
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('CMS (加密消息语法) 模块综合测试');
  WriteLn('=' + StringOfChar('=', 60));

  // 初始化 OpenSSL
  WriteLn;
  WriteLn('初始化 OpenSSL 库...');
  try
    LoadOpenSSLCore;
    WriteLn('✅ OpenSSL 库加载成功');
    WriteLn('版本: ', GetOpenSSLVersionString);
  except
    on E: Exception do
    begin
      WriteLn('❌ 错误：无法加载 OpenSSL 库: ', E.Message);
      Halt(1);
    end;
  end;

  // 加载 CMS 模块
  WriteLn;
  WriteLn('加载 CMS 模块...');
  if not LoadOpenSSLCMS(GetCryptoLibHandle) then
  begin
    WriteLn('❌ 错误：无法加载 CMS 模块');
    Halt(1);
  end;
  WriteLn('✅ CMS 模块加载成功');

  // 执行测试套件
  TestCMS_ContentInfo;
  TestCMS_SignOperations;
  TestCMS_VerifyOperations;
  TestCMS_EncryptDecrypt;
  TestCMS_RecipientInfo;
  TestCMS_ReceiptOperations;
  TestCMS_Attributes;
  TestCMS_UtilityFunctions;
  TestCMS_TamperedDataFailure;
  TestCMS_DecryptRecipientMismatchFailure;
  TestCMS_OfflineMalformedFixture;
  // Note: PEM operations removed - they belong to PEM module, not CMS module

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
    WriteLn('🎉 所有测试通过！CMS 模块工作正常');
  end;

  UnloadOpenSSLCore;
end.
