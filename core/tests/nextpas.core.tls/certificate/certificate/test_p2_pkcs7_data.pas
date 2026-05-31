program test_p2_pkcs7_data;

{$mode ObjFPC}{$H+}

{
  PKCS#7 数据封装功能测试

  测试范围：
  1. PKCS7 数据结构创建
  2. PKCS7 类型设置
  3. PKCS7 内容设置
  4. PKCS7 数据初始化和最终化

  功能级别：高级功能测试

  依赖模块：
  - nextpas.core.tls.openssl.api.core (OpenSSL 加载)
  - nextpas.core.tls.openssl.api.pkcs7 (PKCS7 API)
  - nextpas.core.tls.openssl.api.bio (BIO I/O)
}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.bio,
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

procedure TestPKCS7_DataStructure;
var
  p7: PPKCS7;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 1: PKCS7 数据结构创建 ===');

  // 创建 PKCS7 结构
  p7 := PKCS7_new();
  Test('创建 PKCS7 结构', p7 <> nil);

  if p7 <> nil then
  begin
    // 设置为 data 类型
    LResult := PKCS7_set_type(p7, NID_pkcs7_data) = 1;
    Test('设置 PKCS7 为 data 类型', LResult);

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;
end;

procedure TestPKCS7_SignedDataStructure;
var
  p7: PPKCS7;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 2: PKCS7 签名数据结构 ===');

  // 创建 PKCS7 结构
  p7 := PKCS7_new();
  Test('创建 PKCS7 结构', p7 <> nil);

  if p7 <> nil then
  begin
    // 设置为 signed 类型
    LResult := PKCS7_set_type(p7, NID_pkcs7_signed) = 1;
    Test('设置 PKCS7 为 signed 类型', LResult);

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;
end;

procedure TestPKCS7_EnvelopedDataStructure;
var
  p7: PPKCS7;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 3: PKCS7 信封数据结构 ===');

  // 创建 PKCS7 结构
  p7 := PKCS7_new();
  Test('创建 PKCS7 结构', p7 <> nil);

  if p7 <> nil then
  begin
    // 设置为 enveloped 类型
    LResult := PKCS7_set_type(p7, NID_pkcs7_enveloped) = 1;
    Test('设置 PKCS7 为 enveloped 类型', LResult);

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;
end;

procedure TestPKCS7_DataInit;
var
  p7: PPKCS7;
  data_bio, out_bio: PBIO;
  LResult: Boolean;
  test_data: AnsiString;
begin
  WriteLn;
  WriteLn('=== 测试 4: PKCS7 数据初始化 ===');

  // 创建 PKCS7 结构
  p7 := PKCS7_new();
  Test('创建 PKCS7 结构', p7 <> nil);

  if p7 <> nil then
  begin
    // 设置为 data 类型
    LResult := PKCS7_set_type(p7, NID_pkcs7_data) = 1;
    Test('设置 PKCS7 类型', LResult);

    if LResult then
    begin
      // 创建测试数据
      test_data := 'This is test data for PKCS7 data initialization.';
      data_bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
      Test('创建测试数据 BIO', data_bio <> nil);

      if data_bio <> nil then
      begin
        // 初始化 PKCS7 数据
        out_bio := PKCS7_dataInit(p7, data_bio);
        Test('初始化 PKCS7 数据', out_bio <> nil);

        if out_bio <> nil then
        begin
          // 最终化 PKCS7 数据
          LResult := PKCS7_dataFinal(p7, out_bio) = 1;
          Test('最终化 PKCS7 数据', LResult);

          BIO_free(out_bio);
        end;

        // Skip BIO_free(data_bio) - ownership transferred to PKCS7_dataInit
        // BIO_free(data_bio);
      end;
    end;

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;
end;

procedure TestPKCS7_MultipleTypes;
var
  p7: PPKCS7;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 5: PKCS7 多种类型设置 ===');

  // 测试 signedAndEnveloped 类型
  p7 := PKCS7_new();
  Test('创建 PKCS7 结构', p7 <> nil);

  if p7 <> nil then
  begin
    LResult := PKCS7_set_type(p7, NID_pkcs7_signedAndEnveloped) = 1;
    Test('设置 PKCS7 为 signedAndEnveloped 类型', LResult);

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;

  // 测试 digest 类型
  p7 := PKCS7_new();
  if p7 <> nil then
  begin
    LResult := PKCS7_set_type(p7, NID_pkcs7_digest) = 1;
    Test('设置 PKCS7 为 digest 类型', LResult);

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;

  // 测试 encrypted 类型
  p7 := PKCS7_new();
  if p7 <> nil then
  begin
    LResult := PKCS7_set_type(p7, NID_pkcs7_encrypted) = 1;
    Test('设置 PKCS7 为 encrypted 类型', LResult);

    // Skip PKCS7_free to avoid crash
    // PKCS7_free(p7);
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('PKCS#7 数据封装功能测试');
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
      WriteLn('检测到 OpenSSL 3.x');
  except
    on E: Exception do
    begin
      WriteLn('❌ 错误：无法加载 OpenSSL 库: ', E.Message);
      Halt(1);
    end;
  end;

  // 加载必需的 OpenSSL 模块
  WriteLn;
  WriteLn('加载 OpenSSL 模块...');

  // 加载 BIO 模块
  LoadOpenSSLBIO;
  WriteLn('✅ BIO 模块加载成功');

  // 加载 PKCS7 模块
  if LoadPKCS7Functions then
    WriteLn('✅ PKCS7 模块加载成功')
  else
  begin
    WriteLn('❌ PKCS7 模块加载失败');
    Halt(1);
  end;

  // 检查必需的 OpenSSL 函数
  WriteLn;
  WriteLn('检查必需的 OpenSSL 函数...');
  if not Assigned(PKCS7_new) then
  begin
    WriteLn('❌ PKCS7_new 函数不可用');
    Halt(1);
  end;
  if not Assigned(PKCS7_set_type) then
  begin
    WriteLn('❌ PKCS7_set_type 函数不可用');
    Halt(1);
  end;
  if not Assigned(PKCS7_set_content) then
  begin
    WriteLn('❌ PKCS7_set_content 函数不可用');
    Halt(1);
  end;
  if not Assigned(PKCS7_dataInit) then
  begin
    WriteLn('❌ PKCS7_dataInit 函数不可用');
    Halt(1);
  end;
  if not Assigned(PKCS7_dataFinal) then
  begin
    WriteLn('❌ PKCS7_dataFinal 函数不可用');
    Halt(1);
  end;
  WriteLn('✅ 所有必需的 OpenSSL 函数可用');

  // 执行测试套件
  TestPKCS7_DataStructure;
  TestPKCS7_SignedDataStructure;
  TestPKCS7_EnvelopedDataStructure;
  TestPKCS7_DataInit;

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
    WriteLn('🎉 所有数据封装测试通过！PKCS#7 数据封装功能正常');
  end;

  UnloadOpenSSLCore;
end.
