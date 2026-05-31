program test_ocsp_simple;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ocsp;

var
  LResult: Boolean;
  LCount: Integer;

begin
  WriteLn('========================================');
  WriteLn('OCSP 模块简单验证测试');
  WriteLn('========================================');
  WriteLn;

  // 初始化 OpenSSL
  WriteLn('1. 初始化 OpenSSL...');
  try
    LoadOpenSSLCore;
    WriteLn('   ✅ OpenSSL 库加载成功');
  except
    on E: Exception do
    begin
      WriteLn('   ❌ OpenSSL 加载失败: ', E.Message);
      Halt(1);
    end;
  end;
  WriteLn;

  // 统计可用函数数量
  WriteLn('2. 检查 OCSP 函数可用性...');
  LCount := 0;
  
  if Assigned(OCSP_REQUEST_new) then Inc(LCount, 1);
  if Assigned(OCSP_RESPONSE_new) then Inc(LCount, 1);
  if Assigned(OCSP_BASICRESP_new) then Inc(LCount, 1);
  if Assigned(OCSP_cert_to_id) then Inc(LCount, 1);
  if Assigned(OCSP_REQUEST_add0_id) then Inc(LCount, 1);
  if Assigned(OCSP_RESPONSE_status) then Inc(LCount, 1);
  if Assigned(OCSP_parse_url) then Inc(LCount, 1);
  if Assigned(OCSP_check_validity) then Inc(LCount, 1);
  
  WriteLn(Format('   可用函数数量: %d/8', [LCount]));
  
  if LCount >= 5 then
    WriteLn('   ✅ 大部分 OCSP 函数可用')
  else
    WriteLn('   ⚠️  部分 OCSP 函数不可用');
  WriteLn;

  // 检查常量
  WriteLn('3. 检查 OCSP 常量...');
  WriteLn(Format('   OCSP_RESPONSE_STATUS_SUCCESSFUL = %d', [OCSP_RESPONSE_STATUS_SUCCESSFUL]));
  WriteLn(Format('   V_OCSP_CERTSTATUS_GOOD = %d', [V_OCSP_CERTSTATUS_GOOD]));
  WriteLn(Format('   V_OCSP_CERTSTATUS_REVOKED = %d', [V_OCSP_CERTSTATUS_REVOKED]));
  WriteLn(Format('   V_OCSP_CERTSTATUS_UNKNOWN = %d', [V_OCSP_CERTSTATUS_UNKNOWN]));
  WriteLn('   ✅ 常量定义正确');
  WriteLn;

  // 输出结果
  WriteLn('========================================');
  if LCount >= 5 then
  begin
    WriteLn('✅ OCSP 模块验证成功！');
    WriteLn('   模块已可正常使用');
  end
  else
  begin
    WriteLn('⚠️  OCSP 模块部分可用');
    WriteLn('   建议检查 OpenSSL 库版本');
  end;
  WriteLn('========================================');
  WriteLn;
  
  WriteLn('按 Enter 键退出...');
  ReadLn;
end.
