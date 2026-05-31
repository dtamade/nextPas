program generate_certificate;

{$mode objfpc}{$H+}

{ ============================================================================
  示例 2: 证书生成与自签名
  
  功能：演示如何生成 RSA 密钥对和自签名证书
  用途：学习证书和私钥的创建、配置和保存
  
  编译：fpc -Fusrc -Fusrc\openssl 02_generate_certificate.pas
  运行：02_generate_certificate.exe
  ============================================================================ }

uses
  SysUtils, DateUtils,
  fafafa.ssl,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.bn;

const
  KEY_SIZE = 2048;
  CERT_DAYS = 365;
  
procedure GenerateSelfSignedCertificate(
  const aKeyFile: string;
  const aCertFile: string;
  const aCommonName: string;
  const aCountry: string = 'CN';
  const aOrganization: string = 'My Organization');
var
  LPrivKey: PEVP_PKEY;
  LRsa: PRSA;
  LBn: PBIGNUM;
  LCert: PX509;
  LName: PX509_NAME;
  LBio: PBIO;
  LSerial: PASN1_INTEGER;
  LNotBefore, LNotAfter: PASN1_TIME;
begin
  WriteLn('生成自签名证书...');
  WriteLn;
  
  // 1. 生成 RSA 密钥对
  WriteLn('[1/7] 生成 ', KEY_SIZE, ' 位 RSA 密钥对...');
  LPrivKey := EVP_PKEY_new();
  if LPrivKey = nil then
    raise Exception.Create('Failed to create EVP_PKEY');
  
  LRsa := RSA_new();
  LBn := BN_new();
  BN_set_word(LBn, RSA_F4);  // 65537
  
  if RSA_generate_key_ex(LRsa, KEY_SIZE, LBn, nil) <> 1 then
  begin
    RSA_free(LRsa);
    BN_free(LBn);
    EVP_PKEY_free(LPrivKey);
    raise Exception.Create('Failed to generate RSA key');
  end;
  
  if EVP_PKEY_set1_RSA(LPrivKey, LRsa) <> 1 then
  begin
    RSA_free(LRsa);
    BN_free(LBn);
    EVP_PKEY_free(LPrivKey);
    raise Exception.Create('Failed to assign RSA key to EVP_PKEY');
  end;
  RSA_free(LRsa);
  BN_free(LBn);
  WriteLn('      ✓ 密钥对生成成功');
  
  // 2. 创建 X.509 证书
  WriteLn('[2/7] 创建 X.509 证书结构...');
  LCert := X509_new();
  if LCert = nil then
  begin
    EVP_PKEY_free(LPrivKey);
    raise Exception.Create('Failed to create X509');
  end;
  WriteLn('      ✓ 证书结构创建成功');
  
  // 3. 设置证书版本（V3）
  WriteLn('[3/7] 设置证书参数...');
  X509_set_version(LCert, 2);  // 版本 3 = 2
  
  // 设置序列号
  LSerial := X509_get_serialNumber(LCert);
  ASN1_INTEGER_set(LSerial, 1);
  
  // 设置有效期
  LNotBefore := ASN1_TIME_new();
  LNotAfter := ASN1_TIME_new();
  X509_gmtime_adj(LNotBefore, 0);
  X509_gmtime_adj(LNotAfter, Int64(CERT_DAYS) * 24 * 3600);
  X509_set1_notBefore(LCert, LNotBefore);
  X509_set1_notAfter(LCert, LNotAfter);
  ASN1_TIME_free(LNotBefore);
  ASN1_TIME_free(LNotAfter);
  
  WriteLn('      ✓ 版本: V3');
  WriteLn('      ✓ 序列号: 1');
  WriteLn('      ✓ 有效期: ', CERT_DAYS, ' 天');
  
  // 4. 设置主题信息
  WriteLn('[4/7] 设置主题信息...');
  LName := X509_get_subject_name(LCert);
  X509_NAME_add_entry_by_txt(LName, 'C', MBSTRING_ASC,
    PByte(PAnsiChar(AnsiString(aCountry))), -1, -1, 0);
  X509_NAME_add_entry_by_txt(LName, 'O', MBSTRING_ASC,
    PByte(PAnsiChar(AnsiString(aOrganization))), -1, -1, 0);
  X509_NAME_add_entry_by_txt(LName, 'CN', MBSTRING_ASC,
    PByte(PAnsiChar(AnsiString(aCommonName))), -1, -1, 0);
  
  WriteLn('      ✓ 国家: ', aCountry);
  WriteLn('      ✓ 组织: ', aOrganization);
  WriteLn('      ✓ 通用名: ', aCommonName);
  
  // 5. 设置颁发者（自签名，与主题相同）
  WriteLn('[5/7] 设置颁发者...');
  X509_set_issuer_name(LCert, LName);
  WriteLn('      ✓ 颁发者设置完成（自签名）');
  
  // 6. 设置公钥
  WriteLn('[6/7] 设置公钥...');
  X509_set_pubkey(LCert, LPrivKey);
  WriteLn('      ✓ 公钥设置完成');
  
  // 7. 签名证书
  WriteLn('[7/7] 签名证书...');
  if X509_sign(LCert, LPrivKey, EVP_sha256()) = 0 then
  begin
    X509_free(LCert);
    EVP_PKEY_free(LPrivKey);
    raise Exception.Create('Failed to sign certificate');
  end;
  WriteLn('      ✓ 证书签名完成（SHA256）');
  WriteLn;
  
  // 保存私钥到文件
  WriteLn('保存私钥到: ', aKeyFile);
  LBio := BIO_new_file(PAnsiChar(AnsiString(aKeyFile)), 'w');
  if LBio = nil then
  begin
    X509_free(LCert);
    EVP_PKEY_free(LPrivKey);
    raise Exception.CreateFmt('Failed to create file: %s', [aKeyFile]);
  end;
  
  PEM_write_bio_PrivateKey(LBio, LPrivKey, nil, nil, 0, nil, nil);
  BIO_free(LBio);
  WriteLn('      ✓ 私钥已保存');
  
  // 保存证书到文件
  WriteLn('保存证书到: ', aCertFile);
  LBio := BIO_new_file(PAnsiChar(AnsiString(aCertFile)), 'w');
  if LBio = nil then
  begin
    X509_free(LCert);
    EVP_PKEY_free(LPrivKey);
    raise Exception.CreateFmt('Failed to create file: %s', [aCertFile]);
  end;
  
  PEM_write_bio_X509(LBio, LCert);
  BIO_free(LBio);
  WriteLn('      ✓ 证书已保存');
  
  // 清理
  X509_free(LCert);
  EVP_PKEY_free(LPrivKey);
end;

procedure DisplayCertificateInfo(const aCertFile: string);
var
  LLib: ISSLLibrary;
  LCert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('================================================================================');
  WriteLn('  证书信息');
  WriteLn('================================================================================');
  WriteLn;
  
  LLib := CreateOpenSSLLibrary;
  LLib.Initialize;
  try
    LCert := LLib.CreateCertificate;
    if LCert.LoadFromFile(aCertFile) then
    begin
      WriteLn('主题:       ', LCert.GetSubject);
      WriteLn('颁发者:     ', LCert.GetIssuer);
      WriteLn('序列号:     ', LCert.GetSerialNumber);
      WriteLn('版本:       V', LCert.GetVersion);
      WriteLn('有效期从:   ', DateTimeToStr(LCert.GetNotBefore));
      WriteLn('有效期至:   ', DateTimeToStr(LCert.GetNotAfter));
      WriteLn('签名算法:   ', LCert.GetSignatureAlgorithm);
      WriteLn('公钥算法:   ', LCert.GetPublicKeyAlgorithm);
      WriteLn('SHA1 指纹:  ', LCert.GetFingerprintSHA1);
      WriteLn('SHA256 指纹:', LCert.GetFingerprintSHA256);
      WriteLn;
      WriteLn('自签名:     ', BoolToStr(LCert.IsSelfSigned, True));
      WriteLn('是否 CA:    ', BoolToStr(LCert.IsCA, True));
    end
    else
      WriteLn('✗ 无法加载证书文件');
  finally
    LLib.Finalize;
  end;
end;

var
  LKeyFile, LCertFile, LCommonName: string;

begin
  WriteLn('================================================================================');
  WriteLn('  示例 2: 证书生成与自签名');
  WriteLn('================================================================================');
  WriteLn;
  
  // 初始化 OpenSSL
  if not LoadOpenSSLLibrary then
  begin
    WriteLn('✗ 无法加载 OpenSSL 库');
    ExitCode := 1;
    Exit;
  end;
  
  try
    // 设置文件路径
    LKeyFile := 'server.key';
    LCertFile := 'server.crt';
    LCommonName := 'localhost';
    
    WriteLn('配置：');
    WriteLn('  密钥大小:   ', KEY_SIZE, ' 位');
    WriteLn('  有效期:     ', CERT_DAYS, ' 天');
    WriteLn('  通用名:     ', LCommonName);
    WriteLn('  私钥文件:   ', LKeyFile);
    WriteLn('  证书文件:   ', LCertFile);
    WriteLn;
    
    // 生成证书
    GenerateSelfSignedCertificate(
      LKeyFile,
      LCertFile,
      LCommonName,
      'CN',
      'fafafa.ssl Example'
    );
    
    WriteLn;
    WriteLn('✓ 证书生成完成！');
    
    // 显示证书信息
    DisplayCertificateInfo(LCertFile);
    
    WriteLn('================================================================================');
    WriteLn('  完成！');
    WriteLn('================================================================================');
    WriteLn;
    WriteLn('📁 生成的文件：');
    WriteLn('  ', LKeyFile, ' - 私钥文件（请妥善保管！）');
    WriteLn('  ', LCertFile, ' - 证书文件');
    WriteLn;
    WriteLn('🔒 安全提示：');
    WriteLn('  1. 私钥文件应设置为 400 权限（仅所有者可读）');
    WriteLn('  2. 不要将私钥提交到版本控制系统');
    WriteLn('  3. 自签名证书仅用于测试，生产环境请使用 CA 签发的证书');
    WriteLn;
    WriteLn('💡 用途：');
    WriteLn('  - 本地开发和测试');
    WriteLn('  - TLS 服务器示例');
    WriteLn('  - 学习证书格式和结构');
    WriteLn;
    WriteLn('📚 下一步：');
    WriteLn('  - 使用生成的证书运行 TLS 服务器（示例 3）');
    WriteLn('  - 查看 docs/SECURITY_GUIDE.md 了解证书最佳实践');
    WriteLn;
    
    ExitCode := 0;
    
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
