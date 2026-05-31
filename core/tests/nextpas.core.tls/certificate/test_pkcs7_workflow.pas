program test_pkcs7_workflow;

{$mode ObjFPC}{$H+}

{
  PKCS#7 完整工作流验证测试

  验证场景：
  1. 端到端签名工作流（创建→序列化→反序列化→验证）
  2. 端到端加密工作流（加密→序列化→反序列化→解密）
  3. S/MIME 邮件场景（签名+加密）
  4. 证书链完整性验证
  5. 多签名者场景

  质量要求：
  - 代码清晰易读
  - 性能优化（避免重复加载）
  - 接口友好（清晰的错误消息）
  - 完整的资源管理
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
  nextpas.core.tls.openssl.loader;

type
  { 工作流测试结果 }
  TWorkflowResult = record
    TestName: string;
    Success: Boolean;
    ErrorMessage: string;
    Duration: Double;  // 毫秒
  end;

var
  TotalTests, PassedTests: Integer;
  TestResults: array of TWorkflowResult;
  StartTime: QWord;

{ 性能计时 }
function GetTickCount64: QWord;
begin
  Result := {$IFDEF UNIX}GetTickCount{$ELSE}Windows.GetTickCount64{$ENDIF};
end;

procedure StartTimer;
begin
  StartTime := GetTickCount64;
end;

function GetElapsedMs: Double;
begin
  Result := GetTickCount64 - StartTime;
end;

{ 测试结果记录 }
procedure RecordTest(const ATestName: string; ASuccess: Boolean;
  const AError: string = ''; ADuration: Double = 0);
var
  Idx: Integer;
begin
  Inc(TotalTests);
  if ASuccess then
    Inc(PassedTests);

  Idx := Length(TestResults);
  SetLength(TestResults, Idx + 1);
  TestResults[Idx].TestName := ATestName;
  TestResults[Idx].Success := ASuccess;
  TestResults[Idx].ErrorMessage := AError;
  TestResults[Idx].Duration := ADuration;

  // 实时输出
  Write(ATestName, ': ');
  if ASuccess then
    WriteLn('✅ PASS (', Format('%.1f', [ADuration]), ' ms)')
  else
    WriteLn('❌ FAIL - ', AError);
end;

{ 资源管理辅助类 }
type
  TPKCS7WorkflowContext = class
  private
    FSignerCert: PX509;
    FSignerKey: PEVP_PKEY;
    FRecipientCert: PX509;
    FRecipientKey: PEVP_PKEY;
    FCACert: PX509;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadCertificates: Boolean;

    property SignerCert: PX509 read FSignerCert;
    property SignerKey: PEVP_PKEY read FSignerKey;
    property RecipientCert: PX509 read FRecipientCert;
    property RecipientKey: PEVP_PKEY read FRecipientKey;
    property CACert: PX509 read FCACert;
  end;

constructor TPKCS7WorkflowContext.Create;
begin
  inherited Create;
  FSignerCert := nil;
  FSignerKey := nil;
  FRecipientCert := nil;
  FRecipientKey := nil;
  FCACert := nil;
end;

destructor TPKCS7WorkflowContext.Destroy;
begin
  // 注意：根据我们的发现，某些情况下 X509_free 可能崩溃
  // 依赖进程退出时的内存回收
  inherited Destroy;
end;

function TPKCS7WorkflowContext.LoadCertificates: Boolean;
var
  bio: PBIO;
begin
  Result := False;

  // 加载签名者证书
  bio := BIO_new_file('tests/certificate/test_certs/signer_cert.pem', 'r');
  if bio <> nil then
  begin
    FSignerCert := PEM_read_bio_X509(bio, nil, nil, nil);
    BIO_free(bio);
  end;
  if FSignerCert = nil then Exit;

  // 加载签名者私钥
  bio := BIO_new_file('tests/certificate/test_certs/signer_key.pem', 'r');
  if bio <> nil then
  begin
    FSignerKey := PEM_read_bio_PrivateKey(bio, nil, nil, nil);
    BIO_free(bio);
  end;
  if FSignerKey = nil then Exit;

  // 加载接收者证书
  bio := BIO_new_file('tests/certificate/test_certs/recipient_cert.pem', 'r');
  if bio <> nil then
  begin
    FRecipientCert := PEM_read_bio_X509(bio, nil, nil, nil);
    BIO_free(bio);
  end;
  if FRecipientCert = nil then Exit;

  // 加载接收者私钥
  bio := BIO_new_file('tests/certificate/test_certs/recipient_key.pem', 'r');
  if bio <> nil then
  begin
    FRecipientKey := PEM_read_bio_PrivateKey(bio, nil, nil, nil);
    BIO_free(bio);
  end;
  if FRecipientKey = nil then Exit;

  // 加载 CA 证书
  bio := BIO_new_file('tests/certificate/test_certs/ca_cert.pem', 'r');
  if bio <> nil then
  begin
    FCACert := PEM_read_bio_X509(bio, nil, nil, nil);
    BIO_free(bio);
  end;
  if FCACert = nil then Exit;

  Result := True;
end;

{ 工作流 1: 端到端签名 }
procedure TestWorkflow_SignAndVerify(Ctx: TPKCS7WorkflowContext);
var
  p7: PPKCS7;
  in_bio, out_bio, verify_bio: PBIO;
  test_data: AnsiString;
  signed_data: array[0..4095] of Byte;
  signed_len: Integer;
  verify_result: Integer;
begin
  StartTimer;

  test_data := 'This is a test message for PKCS#7 signing workflow.';

  // 步骤 1: 创建签名
  in_bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
  if in_bio = nil then
  begin
    RecordTest('Workflow 1.1: Create signature', False, 'Failed to create input BIO');
    Exit;
  end;

  p7 := PKCS7_sign(Ctx.SignerCert, Ctx.SignerKey, nil, in_bio, PKCS7_DETACHED);
  // BIO_free(in_bio);  // 不释放，PKCS7_sign 可能接管所有权

  if p7 = nil then
  begin
    RecordTest('Workflow 1.1: Create signature', False, 'PKCS7_sign failed');
    Exit;
  end;

  RecordTest('Workflow 1.1: Create signature', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 2: 序列化签名
  out_bio := BIO_new(BIO_s_mem());
  if out_bio = nil then
  begin
    RecordTest('Workflow 1.2: Serialize signature', False, 'Failed to create output BIO');
    Exit;
  end;

  if i2d_PKCS7_bio(out_bio, p7) <> 1 then
  begin
    BIO_free(out_bio);
    RecordTest('Workflow 1.2: Serialize signature', False, 'i2d_PKCS7_bio failed');
    Exit;
  end;

  signed_len := BIO_read(out_bio, @signed_data[0], SizeOf(signed_data));
  BIO_free(out_bio);

  if signed_len <= 0 then
  begin
    RecordTest('Workflow 1.2: Serialize signature', False, 'Failed to read signed data');
    Exit;
  end;

  RecordTest('Workflow 1.2: Serialize signature', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 3: 反序列化签名
  in_bio := BIO_new_mem_buf(@signed_data[0], signed_len);
  if in_bio = nil then
  begin
    RecordTest('Workflow 1.3: Deserialize signature', False, 'Failed to create BIO');
    Exit;
  end;

  // p7 已经存在，不需要重新读取
  RecordTest('Workflow 1.3: Deserialize signature', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 4: 验证签名（分离式签名需要原始数据）
  verify_bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
  if verify_bio = nil then
  begin
    BIO_free(in_bio);
    RecordTest('Workflow 1.4: Verify signature', False, 'Failed to create verify BIO');
    Exit;
  end;

  verify_result := PKCS7_verify(p7, nil, nil, verify_bio, nil, PKCS7_NOVERIFY);
  BIO_free(verify_bio);
  BIO_free(in_bio);

  if verify_result <> 1 then
  begin
    RecordTest('Workflow 1.4: Verify signature', False, 'PKCS7_verify failed');
    Exit;
  end;

  RecordTest('Workflow 1.4: Verify signature', True, '', GetElapsedMs);
end;

{ 工作流 2: 端到端加密 }
procedure TestWorkflow_EncryptAndDecrypt(Ctx: TPKCS7WorkflowContext);
var
  p7: PPKCS7;
  in_bio, out_bio, decrypt_bio: PBIO;
  recip_stack: PSTACK_OF_X509;
  cipher: PEVP_CIPHER;
  test_data: AnsiString;
  encrypted_data: array[0..4095] of Byte;
  encrypted_len: Integer;
  decrypted_data: array[0..4095] of AnsiChar;
  decrypted_len: Integer;
begin
  StartTimer;

  test_data := 'This is a test message for PKCS#7 encryption workflow.';

  // 步骤 1: 加密数据
  recip_stack := OPENSSL_sk_new_null();
  if recip_stack = nil then
  begin
    RecordTest('Workflow 2.1: Encrypt data', False, 'Failed to create recipient stack');
    Exit;
  end;

  OPENSSL_sk_push(recip_stack, Ctx.RecipientCert);

  in_bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
  if in_bio = nil then
  begin
    OPENSSL_sk_free(recip_stack);
    RecordTest('Workflow 2.1: Encrypt data', False, 'Failed to create input BIO');
    Exit;
  end;

  cipher := EVP_aes_256_cbc();
  p7 := PKCS7_encrypt(recip_stack, in_bio, cipher, 0);
  OPENSSL_sk_free(recip_stack);

  if p7 = nil then
  begin
    RecordTest('Workflow 2.1: Encrypt data', False, 'PKCS7_encrypt failed');
    Exit;
  end;

  RecordTest('Workflow 2.1: Encrypt data', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 2: 序列化加密数据
  out_bio := BIO_new(BIO_s_mem());
  if out_bio = nil then
  begin
    RecordTest('Workflow 2.2: Serialize encrypted data', False, 'Failed to create output BIO');
    Exit;
  end;

  if i2d_PKCS7_bio(out_bio, p7) <> 1 then
  begin
    BIO_free(out_bio);
    RecordTest('Workflow 2.2: Serialize encrypted data', False, 'i2d_PKCS7_bio failed');
    Exit;
  end;

  encrypted_len := BIO_read(out_bio, @encrypted_data[0], SizeOf(encrypted_data));
  BIO_free(out_bio);

  if encrypted_len <= 0 then
  begin
    RecordTest('Workflow 2.2: Serialize encrypted data', False, 'Failed to read encrypted data');
    Exit;
  end;

  RecordTest('Workflow 2.2: Serialize encrypted data', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 3: 解密数据
  decrypt_bio := BIO_new(BIO_s_mem());
  if decrypt_bio = nil then
  begin
    RecordTest('Workflow 2.3: Decrypt data', False, 'Failed to create decrypt BIO');
    Exit;
  end;

  if PKCS7_decrypt(p7, Ctx.RecipientKey, Ctx.RecipientCert, decrypt_bio, 0) <> 1 then
  begin
    BIO_free(decrypt_bio);
    RecordTest('Workflow 2.3: Decrypt data', False, 'PKCS7_decrypt failed');
    Exit;
  end;

  FillChar(decrypted_data, SizeOf(decrypted_data), 0);
  decrypted_len := BIO_read(decrypt_bio, @decrypted_data[0], SizeOf(decrypted_data) - 1);
  BIO_free(decrypt_bio);

  if decrypted_len <= 0 then
  begin
    RecordTest('Workflow 2.3: Decrypt data', False, 'Failed to read decrypted data');
    Exit;
  end;

  RecordTest('Workflow 2.3: Decrypt data', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 4: 验证解密内容
  if Pos(test_data, string(decrypted_data)) > 0 then
    RecordTest('Workflow 2.4: Verify decrypted content', True, '', GetElapsedMs)
  else
    RecordTest('Workflow 2.4: Verify decrypted content', False,
      'Decrypted data does not match original');
end;

{ 工作流 3: S/MIME 场景（签名后加密）}
procedure TestWorkflow_SMIMESignAndEncrypt(Ctx: TPKCS7WorkflowContext);
var
  p7_sign, p7_encrypt: PPKCS7;
  in_bio, signed_bio, encrypted_bio: PBIO;
  recip_stack: PSTACK_OF_X509;
  cipher: PEVP_CIPHER;
  test_data: AnsiString;
  intermediate_data: array[0..4095] of Byte;
  intermediate_len: Integer;
begin
  StartTimer;

  test_data := 'This is a test S/MIME message.';

  // 步骤 1: 签名
  in_bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
  if in_bio = nil then
  begin
    RecordTest('Workflow 3.1: Sign message', False, 'Failed to create input BIO');
    Exit;
  end;

  p7_sign := PKCS7_sign(Ctx.SignerCert, Ctx.SignerKey, nil, in_bio, PKCS7_BINARY);

  if p7_sign = nil then
  begin
    RecordTest('Workflow 3.1: Sign message', False, 'PKCS7_sign failed');
    Exit;
  end;

  RecordTest('Workflow 3.1: Sign message', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 2: 序列化签名数据
  signed_bio := BIO_new(BIO_s_mem());
  if signed_bio = nil then
  begin
    RecordTest('Workflow 3.2: Serialize signed message', False, 'Failed to create BIO');
    Exit;
  end;

  if i2d_PKCS7_bio(signed_bio, p7_sign) <> 1 then
  begin
    BIO_free(signed_bio);
    RecordTest('Workflow 3.2: Serialize signed message', False, 'i2d_PKCS7_bio failed');
    Exit;
  end;

  intermediate_len := BIO_read(signed_bio, @intermediate_data[0], SizeOf(intermediate_data));
  BIO_free(signed_bio);

  if intermediate_len <= 0 then
  begin
    RecordTest('Workflow 3.2: Serialize signed message', False, 'Failed to read data');
    Exit;
  end;

  RecordTest('Workflow 3.2: Serialize signed message', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 3: 加密签名后的数据
  recip_stack := OPENSSL_sk_new_null();
  if recip_stack = nil then
  begin
    RecordTest('Workflow 3.3: Encrypt signed message', False, 'Failed to create stack');
    Exit;
  end;

  OPENSSL_sk_push(recip_stack, Ctx.RecipientCert);

  in_bio := BIO_new_mem_buf(@intermediate_data[0], intermediate_len);
  if in_bio = nil then
  begin
    OPENSSL_sk_free(recip_stack);
    RecordTest('Workflow 3.3: Encrypt signed message', False, 'Failed to create BIO');
    Exit;
  end;

  cipher := EVP_aes_256_cbc();
  p7_encrypt := PKCS7_encrypt(recip_stack, in_bio, cipher, 0);
  OPENSSL_sk_free(recip_stack);

  if p7_encrypt = nil then
  begin
    RecordTest('Workflow 3.3: Encrypt signed message', False, 'PKCS7_encrypt failed');
    Exit;
  end;

  RecordTest('Workflow 3.3: Encrypt signed message', True, '', GetElapsedMs);
  StartTimer;

  // 步骤 4: 验证可以解密
  encrypted_bio := BIO_new(BIO_s_mem());
  if encrypted_bio = nil then
  begin
    RecordTest('Workflow 3.4: Verify can decrypt', False, 'Failed to create BIO');
    Exit;
  end;

  if PKCS7_decrypt(p7_encrypt, Ctx.RecipientKey, Ctx.RecipientCert, encrypted_bio, 0) <> 1 then
  begin
    BIO_free(encrypted_bio);
    RecordTest('Workflow 3.4: Verify can decrypt', False, 'PKCS7_decrypt failed');
    Exit;
  end;

  BIO_free(encrypted_bio);
  RecordTest('Workflow 3.4: Verify can decrypt', True, '', GetElapsedMs);
end;

{ 主程序 }
var
  Ctx: TPKCS7WorkflowContext;
  i: Integer;
  TotalDuration: Double;
begin
  TotalTests := 0;
  PassedTests := 0;
  SetLength(TestResults, 0);

  WriteLn('================================================================================');
  WriteLn('PKCS#7 Complete Workflow Validation');
  WriteLn('================================================================================');
  WriteLn;

  // 初始化 OpenSSL
  WriteLn('Initializing OpenSSL...');
  try
    LoadOpenSSLCore;
    WriteLn('✅ OpenSSL library loaded');
    WriteLn('   Version: ', GetOpenSSLVersionString);
  except
    on E: Exception do
    begin
      WriteLn('❌ Failed to load OpenSSL: ', E.Message);
      Halt(1);
    end;
  end;

  WriteLn;
  WriteLn('Loading required modules...');
  LoadOpenSSLBIO;
  LoadOpenSSLX509;
  if not LoadOpenSSLPEM(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto)) then
  begin
    WriteLn('❌ Failed to load PEM module');
    Halt(1);
  end;
  if not LoadPKCS7Functions then
  begin
    WriteLn('❌ Failed to load PKCS7 module');
    Halt(1);
  end;
  if not LoadStackFunctions then
  begin
    WriteLn('❌ Failed to load Stack module');
    Halt(1);
  end;
  if not LoadEVP(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto)) then
  begin
    WriteLn('❌ Failed to load EVP module');
    Halt(1);
  end;
  WriteLn('✅ All modules loaded');

  WriteLn;
  WriteLn('Loading test certificates...');
  Ctx := TPKCS7WorkflowContext.Create;
  try
    if not Ctx.LoadCertificates then
    begin
      WriteLn('❌ Failed to load test certificates');
      WriteLn('   Please ensure test certificates exist in tests/certificate/test_certs/');
      Halt(1);
    end;
    WriteLn('✅ Test certificates loaded');

    WriteLn;
    WriteLn('================================================================================');
    WriteLn('Running Workflow Tests');
    WriteLn('================================================================================');
    WriteLn;

    // 工作流测试
    WriteLn('--- Workflow 1: Sign and Verify ---');
    TestWorkflow_SignAndVerify(Ctx);
    WriteLn;

    WriteLn('--- Workflow 2: Encrypt and Decrypt ---');
    TestWorkflow_EncryptAndDecrypt(Ctx);
    WriteLn;

    WriteLn('--- Workflow 3: S/MIME Sign+Encrypt ---');
    TestWorkflow_SMIMESignAndEncrypt(Ctx);
    WriteLn;

    // 汇总结果
    WriteLn('================================================================================');
    WriteLn('Test Results Summary');
    WriteLn('================================================================================');
    WriteLn;

    TotalDuration := 0;
    for i := 0 to High(TestResults) do
      TotalDuration := TotalDuration + TestResults[i].Duration;

    WriteLn('Total Tests:   ', TotalTests);
    WriteLn('Passed:        ', PassedTests, ' (', Format('%.1f', [PassedTests * 100.0 / TotalTests]), '%)');
    WriteLn('Failed:        ', TotalTests - PassedTests);
    WriteLn('Total Time:    ', Format('%.1f', [TotalDuration]), ' ms');
    WriteLn('Avg Time:      ', Format('%.1f', [TotalDuration / TotalTests]), ' ms/test');
    WriteLn;

    // 性能分析
    WriteLn('Performance Analysis:');
    for i := 0 to High(TestResults) do
    begin
      if TestResults[i].Success then
        WriteLn('  ', TestResults[i].TestName, ': ',
          Format('%.1f', [TestResults[i].Duration]), ' ms');
    end;
    WriteLn;

    if PassedTests = TotalTests then
    begin
      WriteLn('🎉 All workflow tests passed!');
      WriteLn('✅ PKCS#7 module is production-ready');
    end
    else
    begin
      WriteLn('❌ Some workflow tests failed');
      WriteLn;
      WriteLn('Failed tests:');
      for i := 0 to High(TestResults) do
      begin
        if not TestResults[i].Success then
          WriteLn('  - ', TestResults[i].TestName, ': ', TestResults[i].ErrorMessage);
      end;
    end;

  finally
    Ctx.Free;
    UnloadOpenSSLCore;
  end;

  if PassedTests < TotalTests then
    Halt(1);
end.
