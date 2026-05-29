{
  test_server_error_handling - WinSSL 服务端错误处理测试
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-01-17
  
  描述:
    测试 WinSSL 后端服务端握手的错误处理功能
    验证任务 4.2: 在握手流程中集成错误处理
}

program test_server_error_handling;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.winssl.context,
  nextpas.core.tls.winssl.connection,
  nextpas.core.tls.winssl.errors;

procedure TestErrorMapping;
var
  ErrorCode: TSSLErrorCode;
  ErrorMsg: string;
begin
  WriteLn('=== 测试错误码映射 ===');
  
  // 测试成功状态
  ErrorCode := MapSchannelError(SEC_E_OK);
  WriteLn('SEC_E_OK -> ', Ord(ErrorCode), ' (应该是 sslErrNone)');
  Assert(ErrorCode = sslErrNone, 'SEC_E_OK should map to sslErrNone');
  
  // 测试握手继续状态
  ErrorCode := MapSchannelError(SEC_I_CONTINUE_NEEDED);
  WriteLn('SEC_I_CONTINUE_NEEDED -> ', Ord(ErrorCode), ' (应该是 sslErrNone)');
  Assert(ErrorCode = sslErrNone, 'SEC_I_CONTINUE_NEEDED should map to sslErrNone');
  
  // 测试不完整消息
  ErrorCode := MapSchannelError(SEC_E_INCOMPLETE_MESSAGE);
  WriteLn('SEC_E_INCOMPLETE_MESSAGE -> ', Ord(ErrorCode), ' (应该是 sslErrWantRead)');
  Assert(ErrorCode = sslErrWantRead, 'SEC_E_INCOMPLETE_MESSAGE should map to sslErrWantRead');
  
  // 测试算法不匹配
  ErrorCode := MapSchannelError(SEC_E_ALGORITHM_MISMATCH);
  WriteLn('SEC_E_ALGORITHM_MISMATCH -> ', Ord(ErrorCode), ' (应该是 sslErrHandshake)');
  Assert(ErrorCode = sslErrHandshake, 'SEC_E_ALGORITHM_MISMATCH should map to sslErrHandshake');
  
  // 测试证书过期
  ErrorCode := MapSchannelError(SEC_E_CERT_EXPIRED);
  WriteLn('SEC_E_CERT_EXPIRED -> ', Ord(ErrorCode), ' (应该是 sslErrCertificateExpired)');
  Assert(ErrorCode = sslErrCertificateExpired, 'SEC_E_CERT_EXPIRED should map to sslErrCertificateExpired');
  
  // 测试不受信任的根
  ErrorCode := MapSchannelError(SEC_E_UNTRUSTED_ROOT);
  WriteLn('SEC_E_UNTRUSTED_ROOT -> ', Ord(ErrorCode), ' (应该是 sslErrCertificateUntrusted)');
  Assert(ErrorCode = sslErrCertificateUntrusted, 'SEC_E_UNTRUSTED_ROOT should map to sslErrCertificateUntrusted');
  
  WriteLn('✓ 错误码映射测试通过');
  WriteLn;
end;

procedure TestErrorMessages;
var
  ErrorMsg: string;
begin
  WriteLn('=== 测试错误消息 ===');
  
  // 测试中文错误消息
  ErrorMsg := GetSchannelErrorMessageCN(SEC_E_ALGORITHM_MISMATCH);
  WriteLn('SEC_E_ALGORITHM_MISMATCH (CN): ', ErrorMsg);
  Assert(Pos('加密算法', ErrorMsg) > 0, 'Chinese error message should contain "加密算法"');
  
  // 测试英文错误消息
  ErrorMsg := GetSchannelErrorMessageEN(SEC_E_ALGORITHM_MISMATCH);
  WriteLn('SEC_E_ALGORITHM_MISMATCH (EN): ', ErrorMsg);
  Assert(Pos('algorithm', LowerCase(ErrorMsg)) > 0, 'English error message should contain "algorithm"');
  
  // 测试证书过期消息
  ErrorMsg := GetSchannelErrorMessageCN(SEC_E_CERT_EXPIRED);
  WriteLn('SEC_E_CERT_EXPIRED (CN): ', ErrorMsg);
  Assert(Pos('过期', ErrorMsg) > 0, 'Chinese error message should contain "过期"');
  
  ErrorMsg := GetSchannelErrorMessageEN(SEC_E_CERT_EXPIRED);
  WriteLn('SEC_E_CERT_EXPIRED (EN): ', ErrorMsg);
  Assert(Pos('expired', LowerCase(ErrorMsg)) > 0, 'English error message should contain "expired"');
  
  WriteLn('✓ 错误消息测试通过');
  WriteLn;
end;

procedure TestServerContextWithoutCertificate;
var
  Factory: ISSLFactory;
  Context: ISSLContext;
  Connection: ISSLConnection;
  ExceptionRaised: Boolean;
begin
  WriteLn('=== 测试无证书的服务端上下文 ===');
  
  Factory := CreateSSLFactory(sslWinSSL);
  Context := Factory.CreateContext(sslCtxServer);
  
  // 不加载证书,尝试创建连接应该失败
  ExceptionRaised := False;
  try
    // 注意: 这里我们不能真正测试握手,因为需要实际的套接字
    // 但我们可以验证上下文的状态
    WriteLn('服务端上下文创建成功,但未加载证书');
    WriteLn('上下文类型: ', Ord(Context.GetContextType));
    Assert(Context.GetContextType = sslCtxServer, 'Context type should be server');
  except
    on E: Exception do
    begin
      ExceptionRaised := True;
      WriteLn('异常: ', E.ClassName, ': ', E.Message);
    end;
  end;
  
  WriteLn('✓ 无证书上下文测试完成');
  WriteLn;
end;

procedure TestInvalidCertificatePath;
var
  Factory: ISSLFactory;
  Context: ISSLContext;
  ExceptionRaised: Boolean;
begin
  WriteLn('=== 测试无效证书路径 ===');
  
  Factory := CreateSSLFactory(sslWinSSL);
  Context := Factory.CreateContext(sslCtxServer);
  
  ExceptionRaised := False;
  try
    Context.LoadCertificate('nonexistent_certificate.pfx');
    WriteLn('错误: 应该抛出异常但没有');
  except
    on E: ESSLCertificateException do
    begin
      ExceptionRaised := True;
      WriteLn('✓ 正确抛出证书异常: ', E.Message);
    end;
    on E: Exception do
    begin
      ExceptionRaised := True;
      WriteLn('✓ 抛出异常: ', E.ClassName, ': ', E.Message);
    end;
  end;
  
  Assert(ExceptionRaised, 'Should raise exception for invalid certificate path');
  WriteLn('✓ 无效证书路径测试通过');
  WriteLn;
end;

procedure TestErrorCodeClassification;
var
  ErrorCode: TSSLErrorCode;
  Category: string;
begin
  WriteLn('=== 测试错误分类 ===');
  
  // 测试 SSPI 错误分类
  Category := GetWinSSLErrorCategory(SEC_E_ALGORITHM_MISMATCH);
  WriteLn('SEC_E_ALGORITHM_MISMATCH 分类: ', Category);
  Assert(Category = 'SSPI', 'Should be classified as SSPI');
  
  // 测试证书错误分类
  Category := GetWinSSLErrorCategory(CERT_E_EXPIRED);
  WriteLn('CERT_E_EXPIRED 分类: ', Category);
  Assert(Category = 'CERT', 'Should be classified as CERT');
  
  // 测试信任错误分类
  Category := GetWinSSLErrorCategory(TRUST_E_CERT_SIGNATURE);
  WriteLn('TRUST_E_CERT_SIGNATURE 分类: ', Category);
  Assert(Category = 'TRUST', 'Should be classified as TRUST');
  
  WriteLn('✓ 错误分类测试通过');
  WriteLn;
end;

var
  TestsPassed: Integer;
  TestsFailed: Integer;

begin
  WriteLn('========================================');
  WriteLn('WinSSL 服务端错误处理测试');
  WriteLn('任务 4.2: 在握手流程中集成错误处理');
  WriteLn('========================================');
  WriteLn;
  
  TestsPassed := 0;
  TestsFailed := 0;
  
  try
    TestErrorMapping;
    Inc(TestsPassed);
  except
    on E: Exception do
    begin
      WriteLn('✗ 错误码映射测试失败: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  try
    TestErrorMessages;
    Inc(TestsPassed);
  except
    on E: Exception do
    begin
      WriteLn('✗ 错误消息测试失败: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  try
    TestServerContextWithoutCertificate;
    Inc(TestsPassed);
  except
    on E: Exception do
    begin
      WriteLn('✗ 无证书上下文测试失败: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  try
    TestInvalidCertificatePath;
    Inc(TestsPassed);
  except
    on E: Exception do
    begin
      WriteLn('✗ 无效证书路径测试失败: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  try
    TestErrorCodeClassification;
    Inc(TestsPassed);
  except
    on E: Exception do
    begin
      WriteLn('✗ 错误分类测试失败: ', E.Message);
      Inc(TestsFailed);
    end;
  end;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('测试总结');
  WriteLn('========================================');
  WriteLn('通过: ', TestsPassed);
  WriteLn('失败: ', TestsFailed);
  WriteLn('总计: ', TestsPassed + TestsFailed);
  WriteLn;
  
  if TestsFailed = 0 then
  begin
    WriteLn('✓ 所有测试通过!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('✗ 有测试失败');
    ExitCode := 1;
  end;
end.
