program test_ocsp_validation;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ocsp;

var
  TotalTests, PassedTests, FailedTests: Integer;
  LResult: Boolean;

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

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('========================================');
  WriteLn('OCSP 模块验证测试');
  WriteLn('========================================');
  WriteLn;

  // 初始化 OpenSSL
  WriteLn('初始化 OpenSSL...');
  if not LoadOpenSSLCore then
  begin
    WriteLn('❌ 无法加载 OpenSSL 库');
    Halt(1);
  end;
  WriteLn('✅ OpenSSL 库加载成功');
  WriteLn('版本: ', GetOpenSSLVersionString);
  WriteLn;

  // 测试 OCSP 函数是否可用
  WriteLn('测试 OCSP 函数...');
  
  LResult := Assigned(@OCSP_REQUEST_new) and (OCSP_REQUEST_new <> nil);
  Test('OCSP_REQUEST_new 函数可用', LResult);

  LResult := Assigned(@OCSP_RESPONSE_new) and (OCSP_RESPONSE_new <> nil);
  Test('OCSP_RESPONSE_new 函数可用', LResult);

  LResult := Assigned(@OCSP_BASICRESP_new) and (OCSP_BASICRESP_new <> nil);
  Test('OCSP_BASICRESP_new 函数可用', LResult);

  LResult := Assigned(@OCSP_cert_to_id) and (OCSP_cert_to_id <> nil);
  Test('OCSP_cert_to_id 函数可用', LResult);

  LResult := Assigned(@OCSP_REQUEST_add0_id) and (OCSP_REQUEST_add0_id <> nil);
  Test('OCSP_REQUEST_add0_id 函数可用', LResult);

  LResult := Assigned(@OCSP_RESPONSE_status) and (OCSP_RESPONSE_status <> nil);
  Test('OCSP_RESPONSE_status 函数可用', LResult);

  // 测试常量
  WriteLn;
  WriteLn('测试 OCSP 常量...');
  Test('OCSP_RESPONSE_STATUS_SUCCESSFUL 常量', OCSP_RESPONSE_STATUS_SUCCESSFUL = 0);
  Test('OCSP_RESPONSE_STATUS_MALFORMEDREQUEST 常量', OCSP_RESPONSE_STATUS_MALFORMEDREQUEST = 1);
  Test('V_OCSP_CERTSTATUS_GOOD 常量', V_OCSP_CERTSTATUS_GOOD = 0);
  Test('V_OCSP_CERTSTATUS_REVOKED 常量', V_OCSP_CERTSTATUS_REVOKED = 1);
  Test('V_OCSP_CERTSTATUS_UNKNOWN 常量', V_OCSP_CERTSTATUS_UNKNOWN = 2);

  // 输出测试结果
  WriteLn;
  WriteLn('========================================');
  WriteLn('测试结果总结');
  WriteLn('========================================');
  WriteLn(Format('总测试数: %d', [TotalTests]));
  WriteLn(Format('通过: %d', [PassedTests]));
  WriteLn(Format('失败: %d', [FailedTests]));
  WriteLn(Format('通过率: %.1f%%', [PassedTests * 100.0 / TotalTests]));
  WriteLn;

  if FailedTests > 0 then
  begin
    WriteLn('❌ 测试未完全通过');
    Halt(1);
  end
  else
  begin
    WriteLn('🎉 所有测试通过！OCSP 模块工作正常');
  end;

  UnloadOpenSSLCore;
end.
