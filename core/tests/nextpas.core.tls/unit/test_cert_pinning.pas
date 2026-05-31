{**
 * test_cert_pinning - Certificate Pinning Unit Tests
 *
 * Comprehensive test suite for certificate pinning functionality.
 * Tests both certificate pinning and public key pinning (SPKI).
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-31
 *}
program test_cert_pinning;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.cert.pinning,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.crypto.utils,
  Base64;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

{** 创建测试用的自签名证书 *}
function CreateTestCertificate(const CommonName: string): PX509;
var
  Pkey: PEVP_PKEY;
  X509Name: PX509_NAME;
  SerialNumber: PASN1_INTEGER;
  {$IFDEF OPENSSL_3_0}
  Ctx: PEVP_PKEY_CTX;
  {$ELSE}
  Rsa: PRSA;
  Bn: PBIGNUM;
  {$ENDIF}
begin
  Result := X509_new();
  if Result = nil then
    raise Exception.Create('Failed to create X509 certificate');

  // 设置版本
  X509_set_version(Result, 2);

  // 设置序列号
  SerialNumber := ASN1_INTEGER_new();
  ASN1_INTEGER_set(SerialNumber, 1);
  X509_set_serialNumber(Result, SerialNumber);
  ASN1_INTEGER_free(SerialNumber);

  // 设置有效期
  X509_gmtime_adj(X509_get_notBefore(Result), 0);
  X509_gmtime_adj(X509_get_notAfter(Result), 365 * 24 * 60 * 60);

  // 生成密钥对
  Pkey := EVP_PKEY_new();
  if Pkey = nil then
  begin
    X509_free(Result);
    raise Exception.Create('Failed to create EVP_PKEY');
  end;

  // 生成 RSA 密钥
  {$IFDEF OPENSSL_3_0}
  // OpenSSL 3.0+ 使用 EVP_PKEY_generate
  Ctx := EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nil);
  if Ctx = nil then
  begin
    EVP_PKEY_free(Pkey);
    X509_free(Result);
    raise Exception.Create('Failed to create EVP_PKEY_CTX');
  end;
  
  try
    if EVP_PKEY_keygen_init(Ctx) <= 0 then
      raise Exception.Create('Failed to init keygen');
    if EVP_PKEY_CTX_set_rsa_keygen_bits(Ctx, 2048) <= 0 then
      raise Exception.Create('Failed to set key bits');
    if EVP_PKEY_keygen(Ctx, @Pkey) <= 0 then
      raise Exception.Create('Failed to generate key');
  finally
    EVP_PKEY_CTX_free(Ctx);
  end;
  {$ELSE}
  // OpenSSL 1.1.1 使用 RSA_generate_key_ex
  Rsa := RSA_new();
  Bn := BN_new();
  BN_set_word(Bn, RSA_F4);
  RSA_generate_key_ex(Rsa, 2048, Bn, nil);
  EVP_PKEY_assign_RSA(Pkey, Rsa);
  BN_free(Bn);
  {$ENDIF}

  X509_set_pubkey(Result, Pkey);

  // 设置主题名称
  X509Name := X509_get_subject_name(Result);
  X509_NAME_add_entry_by_txt(X509Name, 'CN', MBSTRING_ASC, 
    PAnsiChar(AnsiString(CommonName)), -1, -1, 0);

  // 设置颁发者名称（自签名）
  X509_set_issuer_name(Result, X509Name);

  // 签名
  X509_sign(Result, Pkey, EVP_sha256());

  EVP_PKEY_free(Pkey);
end;

{** 测试：TCertificatePin 基本功能 *}
procedure Test_CertificatePin_Basic;
var
  Pin: TCertificatePin;
  Base64Hash: string;
begin
  WriteLn('=== Test_CertificatePin_Basic ===');
  
  // 测试从 Base64 创建 Pin
  Base64Hash := 'X3pGTSOuJeEVw989IJ/cEtXUEmy52zs1TZQrU06KUKg=';
  Pin := TCertificatePin.FromBase64(Base64Hash, ptPublicKey, 'Test Pin', False);
  
  Assert(Pin.PinType = ptPublicKey, 'Pin type should be ptPublicKey');
  Assert(Pin.Description = 'Test Pin', 'Pin description should match');
  Assert(not Pin.IsBackup, 'Pin should not be backup');
  Assert(Pin.IsValid, 'Pin should be valid');
  
  // 测试 ToBase64
  Assert(Pin.ToBase64 = Base64Hash, 'ToBase64 should return original hash');
  
  WriteLn;
end;

{** 测试：TPinValidator 添加和清除 Pin *}
procedure Test_PinValidator_AddClear;
var
  Validator: TPinValidator;
  Hash: TBytes;
begin
  WriteLn('=== Test_PinValidator_AddClear ===');
  
  Validator := TPinValidator.Create;
  try
    // 测试初始状态
    Assert(Validator.GetValidPinCount = 0, 'Initial pin count should be 0');
    Assert(not Validator.IsSecureConfiguration, 'Should not be secure with 0 pins');
    
    // 添加第一个 Pin
    SetLength(Hash, 32);
    FillChar(Hash[0], 32, $AA);
    Validator.AddPin(Hash, ptPublicKey, 'Pin 1', False);
    Assert(Validator.GetValidPinCount = 1, 'Pin count should be 1');
    
    // 添加第二个 Pin
    FillChar(Hash[0], 32, $BB);
    Validator.AddPin(Hash, ptPublicKey, 'Pin 2', True);
    Assert(Validator.GetValidPinCount = 2, 'Pin count should be 2');
    Assert(Validator.IsSecureConfiguration, 'Should be secure with 2 pins');
    
    // 清除所有 Pin
    Validator.ClearPins;
    Assert(Validator.GetValidPinCount = 0, 'Pin count should be 0 after clear');
    
  finally
    Validator.Free;
  end;
  
  WriteLn;
end;

{** 测试：TPinValidator Base64 添加 *}
procedure Test_PinValidator_AddBase64;
var
  Validator: TPinValidator;
begin
  WriteLn('=== Test_PinValidator_AddBase64 ===');
  
  Validator := TPinValidator.Create;
  try
    // 添加 Base64 编码的 Pin
    Validator.AddPinBase64('X3pGTSOuJeEVw989IJ/cEtXUEmy52zs1TZQrU06KUKg=', 
      ptPublicKey, 'Base64 Pin 1', False);
    Validator.AddPinBase64('YLh1dUR9y6Kja30RrAn7JKnbQG/uEtLMkBgFF2Fuihg=', 
      ptPublicKey, 'Base64 Pin 2', True);
    
    Assert(Validator.GetValidPinCount = 2, 'Should have 2 pins');
    Assert(Validator.IsSecureConfiguration, 'Should be secure configuration');
    
  finally
    Validator.Free;
  end;
  
  WriteLn;
end;

{** 测试：证书哈希提取 *}
procedure Test_CertificateHash_Extraction;
var
  Cert: PX509;
  Validator: TPinValidator;
  CertHash: TBytes;
  Base64Hash: string;
  Digest: array[0..31] of Byte;
  DigestLen: Cardinal;
begin
  WriteLn('=== Test_CertificateHash_Extraction ===');
  
  // 创建测试证书
  Cert := CreateTestCertificate('test.example.com');
  try
    Validator := TPinValidator.Create;
    try
      // 提取证书哈希（使用私有方法的反射或直接测试）
      // 这里我们通过验证流程间接测试
      
      // 计算证书的 SHA-256 哈希
      if X509_digest(Cert, EVP_sha256(), @Digest[0], @DigestLen) = 1 then
      begin
        SetLength(CertHash, DigestLen);
        Move(Digest[0], CertHash[0], DigestLen);
        
        // 添加证书 Pin
        Validator.AddPin(CertHash, ptCertificate, 'Test Cert Pin', False);
        
        // 验证证书
        Assert(Validator.ValidateCertificate(Cert), 'Certificate should match pin');
      end
      else
        Assert(False, 'Failed to compute certificate digest');
      
    finally
      Validator.Free;
    end;
  finally
    X509_free(Cert);
  end;
  
  WriteLn;
end;

{** 测试：公钥哈希提取 *}
procedure Test_PublicKeyHash_Extraction;
var
  Cert: PX509;
  Validator: TPinValidator;
  PubKey: PEVP_PKEY;
  Bio: PBIO;
  SPKIData: TBytes;
  SPKILen: Integer;
  PubKeyHash: TBytes;
begin
  WriteLn('=== Test_PublicKeyHash_Extraction ===');
  
  // 创建测试证书
  Cert := CreateTestCertificate('test.example.com');
  try
    Validator := TPinValidator.Create;
    try
      // 提取公钥并计算 SPKI 哈希
      PubKey := X509_get_pubkey(Cert);
      if PubKey <> nil then
      begin
        try
          Bio := BIO_new(BIO_s_mem());
          if Bio <> nil then
          begin
            try
              if i2d_PUBKEY_bio(Bio, PubKey) > 0 then
              begin
                SPKILen := BIO_ctrl_pending(Bio);
                SetLength(SPKIData, SPKILen);
                BIO_read(Bio, @SPKIData[0], SPKILen);
                
                // 计算 SHA-256
                PubKeyHash := TCryptoUtils.SHA256(SPKIData);
                
                // 添加公钥 Pin
                Validator.AddPin(PubKeyHash, ptPublicKey, 'Test PubKey Pin', False);
                
                // 验证证书
                Assert(Validator.ValidateCertificate(Cert), 'Public key should match pin');
              end
              else
                Assert(False, 'Failed to encode public key');
            finally
              BIO_free(Bio);
            end;
          end
          else
            Assert(False, 'Failed to create BIO');
        finally
          EVP_PKEY_free(PubKey);
        end;
      end
      else
        Assert(False, 'Failed to extract public key');
      
    finally
      Validator.Free;
    end;
  finally
    X509_free(Cert);
  end;
  
  WriteLn;
end;

{** 测试：Pin 验证失败 *}
procedure Test_PinValidation_Failure;
var
  Cert: PX509;
  Validator: TPinValidator;
  WrongHash: TBytes;
begin
  WriteLn('=== Test_PinValidation_Failure ===');
  
  // 创建测试证书
  Cert := CreateTestCertificate('test.example.com');
  try
    Validator := TPinValidator.Create;
    try
      // 添加错误的 Pin
      SetLength(WrongHash, 32);
      FillChar(WrongHash[0], 32, $FF);
      Validator.AddPin(WrongHash, ptPublicKey, 'Wrong Pin', False);
      
      // 验证应该失败
      Assert(not Validator.ValidateCertificate(Cert), 'Validation should fail with wrong pin');
      
    finally
      Validator.Free;
    end;
  finally
    X509_free(Cert);
  end;
  
  WriteLn;
end;

{** 测试：证书链验证 *}
procedure Test_CertificateChain_Validation;
var
  Cert1, Cert2: PX509;
  Validator: TPinValidator;
  Chain: array[0..1] of PX509;
  PubKey: PEVP_PKEY;
  Bio: PBIO;
  SPKIData: TBytes;
  SPKILen: Integer;
  PubKeyHash: TBytes;
begin
  WriteLn('=== Test_CertificateChain_Validation ===');
  
  // 创建两个测试证书
  Cert1 := CreateTestCertificate('leaf.example.com');
  Cert2 := CreateTestCertificate('intermediate.example.com');
  try
    Validator := TPinValidator.Create;
    try
      // 提取第二个证书的公钥哈希
      PubKey := X509_get_pubkey(Cert2);
      if PubKey <> nil then
      begin
        try
          Bio := BIO_new(BIO_s_mem());
          if Bio <> nil then
          begin
            try
              if i2d_PUBKEY_bio(Bio, PubKey) > 0 then
              begin
                SPKILen := BIO_ctrl_pending(Bio);
                SetLength(SPKIData, SPKILen);
                BIO_read(Bio, @SPKIData[0], SPKILen);
                PubKeyHash := TCryptoUtils.SHA256(SPKIData);
                
                // 添加第二个证书的 Pin
                Validator.AddPin(PubKeyHash, ptPublicKey, 'Intermediate Pin', False);
                
                // 构建证书链
                Chain[0] := Cert1;
                Chain[1] := Cert2;
                
                // 验证证书链（应该匹配第二个证书）
                Assert(Validator.ValidateCertificateChain(Chain), 
                  'Chain validation should succeed');
              end;
            finally
              BIO_free(Bio);
            end;
          end;
        finally
          EVP_PKEY_free(PubKey);
        end;
      end;
      
    finally
      Validator.Free;
    end;
  finally
    X509_free(Cert1);
    X509_free(Cert2);
  end;
  
  WriteLn;
end;

{** 测试：RequireValidPin 属性 *}
procedure Test_RequireValidPin_Property;
var
  Cert: PX509;
  Validator: TPinValidator;
  WrongHash: TBytes;
begin
  WriteLn('=== Test_RequireValidPin_Property ===');
  
  Cert := CreateTestCertificate('test.example.com');
  try
    Validator := TPinValidator.Create;
    try
      // 添加错误的 Pin
      SetLength(WrongHash, 32);
      FillChar(WrongHash[0], 32, $FF);
      Validator.AddPin(WrongHash, ptPublicKey, 'Wrong Pin', False);
      
      // 默认应该要求验证
      Assert(Validator.RequireValidPin, 'RequireValidPin should be True by default');
      Assert(not Validator.ValidateCertificate(Cert), 
        'Validation should fail when RequireValidPin is True');
      
      // 禁用强制验证
      Validator.RequireValidPin := False;
      Assert(Validator.ValidateCertificate(Cert), 
        'Validation should succeed when RequireValidPin is False');
      
    finally
      Validator.Free;
    end;
  finally
    X509_free(Cert);
  end;
  
  WriteLn;
end;

{** 测试：TPinValidatorEx 详细结果 *}
procedure Test_PinValidatorEx_DetailedResult;
var
  Cert: PX509;
  Validator: TPinValidatorEx;
  Result: TPinValidationResult;
  PubKey: PEVP_PKEY;
  Bio: PBIO;
  SPKIData: TBytes;
  SPKILen: Integer;
  PubKeyHash: TBytes;
begin
  WriteLn('=== Test_PinValidatorEx_DetailedResult ===');
  
  Cert := CreateTestCertificate('test.example.com');
  try
    Validator := TPinValidatorEx.Create;
    try
      // 提取公钥哈希
      PubKey := X509_get_pubkey(Cert);
      if PubKey <> nil then
      begin
        try
          Bio := BIO_new(BIO_s_mem());
          if Bio <> nil then
          begin
            try
              if i2d_PUBKEY_bio(Bio, PubKey) > 0 then
              begin
                SPKILen := BIO_ctrl_pending(Bio);
                SetLength(SPKIData, SPKILen);
                BIO_read(Bio, @SPKIData[0], SPKILen);
                PubKeyHash := TCryptoUtils.SHA256(SPKIData);
                
                // 添加 Pin
                Validator.AddPin(PubKeyHash, ptPublicKey, 'Test Pin', False);
                
                // 验证并获取详细结果
                if Validator.ValidateCertificateEx(Cert, Result) then
                begin
                  Assert(Result.Success, 'Result.Success should be True');
                  Assert(Result.MatchedPinIndex = 0, 'Should match first pin');
                  Assert(Result.MatchedPinDescription = 'Test Pin', 
                    'Should match pin description');
                  Assert(Result.PublicKeyFingerprint <> '', 
                    'Should have public key fingerprint');
                end
                else
                  Assert(False, 'Validation should succeed');
              end;
            finally
              BIO_free(Bio);
            end;
          end;
        finally
          EVP_PKEY_free(PubKey);
        end;
      end;
      
    finally
      Validator.Free;
    end;
  finally
    X509_free(Cert);
  end;
  
  WriteLn;
end;

{** 主程序 *}
begin
  WriteLn('========================================');
  WriteLn('Certificate Pinning Unit Tests');
  WriteLn('========================================');
  WriteLn;

  // 初始化 OpenSSL
  if not Assigned(OPENSSL_init_ssl) then
  begin
    WriteLn('ERROR: OpenSSL not loaded');
    Halt(1);
  end;

  try
    // 运行测试
    Test_CertificatePin_Basic;
    Test_PinValidator_AddClear;
    Test_PinValidator_AddBase64;
    Test_CertificateHash_Extraction;
    Test_PublicKeyHash_Extraction;
    Test_PinValidation_Failure;
    Test_CertificateChain_Validation;
    Test_RequireValidPin_Property;
    Test_PinValidatorEx_DetailedResult;

    // 输出结果
    WriteLn('========================================');
    WriteLn('Test Results:');
    WriteLn('  Passed: ', TestsPassed);
    WriteLn('  Failed: ', TestsFailed);
    WriteLn('  Total:  ', TestsPassed + TestsFailed);
    WriteLn('========================================');

    if TestsFailed > 0 then
      Halt(1);

  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.Message);
      Halt(1);
    end;
  end;
end.
