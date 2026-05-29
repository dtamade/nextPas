program test_pkcs7_data_debug;

{$mode ObjFPC}{$H+}

{
  调试 test_p2_pkcs7_data 崩溃问题

  简化版测试，逐步定位崩溃位置
}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.loader;

procedure TestPKCS7_DataInit_Debug;
var
  p7: PPKCS7;
  data_bio, out_bio: PBIO;
  LResult: Boolean;
  test_data: AnsiString;
begin
  WriteLn('=== Debug: PKCS7 DataInit Test ===');

  // 创建 PKCS7 结构
  WriteLn('1. 创建 PKCS7 结构...');
  p7 := PKCS7_new();
  if p7 = nil then
  begin
    WriteLn('   FAIL: PKCS7_new() 返回 nil');
    Exit;
  end;
  WriteLn('   OK: PKCS7 结构已创建');

  // 设置为 data 类型
  WriteLn('2. 设置 PKCS7 类型为 data...');
  LResult := PKCS7_set_type(p7, NID_pkcs7_data) = 1;
  if not LResult then
  begin
    WriteLn('   FAIL: PKCS7_set_type() 失败');
    Exit;
  end;
  WriteLn('   OK: 类型设置成功');

  // 创建测试数据
  WriteLn('3. 创建测试数据 BIO...');
  test_data := 'This is test data for PKCS7 data initialization.';
  data_bio := BIO_new_mem_buf(PAnsiChar(test_data), Length(test_data));
  if data_bio = nil then
  begin
    WriteLn('   FAIL: BIO_new_mem_buf() 返回 nil');
    Exit;
  end;
  WriteLn('   OK: 数据 BIO 已创建');

  // 初始化 PKCS7 数据
  WriteLn('4. 初始化 PKCS7 数据...');
  out_bio := PKCS7_dataInit(p7, data_bio);
  if out_bio = nil then
  begin
    WriteLn('   FAIL: PKCS7_dataInit() 返回 nil');
    BIO_free(data_bio);
    Exit;
  end;
  WriteLn('   OK: PKCS7 数据已初始化');

  // 最终化 PKCS7 数据
  WriteLn('5. 最终化 PKCS7 数据...');
  LResult := PKCS7_dataFinal(p7, out_bio) = 1;
  if not LResult then
    WriteLn('   FAIL: PKCS7_dataFinal() 失败')
  else
    WriteLn('   OK: PKCS7 数据已最终化');

  // 释放资源
  WriteLn('6. 释放 out_bio...');
  BIO_free(out_bio);
  WriteLn('   OK: out_bio 已释放');

  WriteLn('7. 跳过释放 data_bio（可能已被 PKCS7_dataInit 接管）...');
  // BIO_free(data_bio);  // 不要释放！
  WriteLn('   OK: 跳过 data_bio 释放');

  WriteLn('8. 跳过释放 PKCS7 结构（内存将在进程退出时回收）...');
  // PKCS7_free(p7);  // 不要释放！
  WriteLn('   OK: 跳过 PKCS7 结构释放');

  WriteLn('9. 测试完成，准备返回...');
end;

begin
  WriteLn('==========================================');
  WriteLn('PKCS7 DataInit Debug Test');
  WriteLn('==========================================');
  WriteLn;

  // 初始化 OpenSSL
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

  WriteLn;
  WriteLn('加载 OpenSSL 模块...');
  LoadOpenSSLBIO;
  WriteLn('✅ BIO 模块加载成功');

  if LoadPKCS7Functions then
    WriteLn('✅ PKCS7 模块加载成功')
  else
  begin
    WriteLn('❌ PKCS7 模块加载失败');
    Halt(1);
  end;

  WriteLn;

  // 执行调试测试
  TestPKCS7_DataInit_Debug;

  WriteLn;
  WriteLn('==========================================');
  WriteLn('准备卸载 OpenSSL...');
  UnloadOpenSSLCore;
  WriteLn('✅ OpenSSL 已卸载');

  WriteLn;
  WriteLn('🎉 测试完成，程序即将退出');
end.
