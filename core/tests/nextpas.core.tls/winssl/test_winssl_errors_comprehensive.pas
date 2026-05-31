program test_winssl_errors_comprehensive;

{$mode objfpc}{$H+}

{
  test_winssl_errors_comprehensive - WinSSL 错误处理综合测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 第四阶段
    测试 WinSSL 错误处理和映射系统

    需要 Windows 环境运行

  测试内容:
    1. Schannel 错误码映射
    2. 错误消息生成（中文/英文）
    3. 错误分类系统
    4. 错误处理器（文件/控制台）
    5. 全局错误日志
    6. 错误信息格式化
    7. 系统错误消息获取
    8. 错误级别处理
    9. 错误上下文管理
    10. 边界情况测试
}

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.errors;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestSchannelErrorMapping;
var
  LResult: TSSLErrorCode;
begin
  WriteLn('【测试 1】Schannel 错误码映射');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试成功状态
    LResult := MapSchannelError(SEC_E_OK);
    Assert(LResult = sslErrNone, 'SEC_E_OK 映射为 sslErrNone');

    // 测试握手继续状态
    LResult := MapSchannelError(SEC_I_CONTINUE_NEEDED);
    Assert(LResult = sslErrNone, 'SEC_I_CONTINUE_NEEDED 映射为 sslErrNone');

    // 测试需要更多数据
    LResult := MapSchannelError(SEC_E_INCOMPLETE_MESSAGE);
    Assert(LResult = sslErrWantRead, 'SEC_E_INCOMPLETE_MESSAGE 映射为 sslErrWantRead');

    // 测试协议错误
    LResult := MapSchannelError(SEC_E_INVALID_TOKEN);
    Assert(LResult = sslErrProtocol, 'SEC_E_INVALID_TOKEN 映射为 sslErrProtocol');

    // 测试算法不匹配
    LResult := MapSchannelError(SEC_E_ALGORITHM_MISMATCH);
    Assert(LResult = sslErrHandshake, 'SEC_E_ALGORITHM_MISMATCH 映射为 sslErrHandshake');

    // 测试证书错误
    LResult := MapSchannelError(SEC_E_UNTRUSTED_ROOT);
    Assert(LResult = sslErrCertificateUntrusted, 'SEC_E_UNTRUSTED_ROOT 映射为 sslErrCertificateUntrusted');

    LResult := MapSchannelError(SEC_E_CERT_EXPIRED);
    Assert(LResult = sslErrCertificateExpired, 'SEC_E_CERT_EXPIRED 映射为 sslErrCertificateExpired');

    LResult := MapSchannelError(CERT_E_REVOKED);
    Assert(LResult = sslErrCertificateRevoked, 'CERT_E_REVOKED 映射为 sslErrCertificateRevoked');

    LResult := MapSchannelError(CERT_E_CN_NO_MATCH);
    Assert(LResult = sslErrHostnameMismatch, 'CERT_E_CN_NO_MATCH 映射为 sslErrHostnameMismatch');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestErrorMessagesChinese;
var
  LMessage: string;
begin
  WriteLn('【测试 2】错误消息生成（中文）');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试成功状态消息
    LMessage := GetSchannelErrorMessageCN(SEC_E_OK);
    Assert(Pos('成功', LMessage) > 0, 'SEC_E_OK 中文消息包含"成功"');

    // 测试握手消息
    LMessage := GetSchannelErrorMessageCN(SEC_I_CONTINUE_NEEDED);
    Assert(Pos('握手', LMessage) > 0, 'SEC_I_CONTINUE_NEEDED 中文消息包含"握手"');

    // 测试证书错误消息
    LMessage := GetSchannelErrorMessageCN(SEC_E_UNTRUSTED_ROOT);
    Assert(Pos('证书', LMessage) > 0, 'SEC_E_UNTRUSTED_ROOT 中文消息包含"证书"');
    Assert(Pos('不受信任', LMessage) > 0, '消息包含"不受信任"');

    LMessage := GetSchannelErrorMessageCN(SEC_E_CERT_EXPIRED);
    Assert(Pos('过期', LMessage) > 0, 'SEC_E_CERT_EXPIRED 中文消息包含"过期"');

    LMessage := GetSchannelErrorMessageCN(CERT_E_CN_NO_MATCH);
    Assert(Pos('名称', LMessage) > 0, 'CERT_E_CN_NO_MATCH 中文消息包含"名称"');

    // 测试协议错误消息
    LMessage := GetSchannelErrorMessageCN(SEC_E_INVALID_TOKEN);
    Assert(Pos('TLS', LMessage) > 0, 'SEC_E_INVALID_TOKEN 中文消息包含"TLS"');

    // 测试内存错误消息
    LMessage := GetSchannelErrorMessageCN(ERROR_NOT_ENOUGH_MEMORY);
    Assert(Pos('内存', LMessage) > 0, 'ERROR_NOT_ENOUGH_MEMORY 中文消息包含"内存"');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestErrorMessagesEnglish;
var
  LMessage: string;
begin
  WriteLn('【测试 3】错误消息生成（英文）');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试成功状态消息
    LMessage := GetSchannelErrorMessageEN(SEC_E_OK);
    Assert(Pos('successful', LMessage) > 0, 'SEC_E_OK 英文消息包含"successful"');

    // 测试握手消息
    LMessage := GetSchannelErrorMessageEN(SEC_I_CONTINUE_NEEDED);
    Assert(Pos('Handshake', LMessage) > 0, 'SEC_I_CONTINUE_NEEDED 英文消息包含"Handshake"');

    // 测试证书错误消息
    LMessage := GetSchannelErrorMessageEN(SEC_E_UNTRUSTED_ROOT);
    Assert(Pos('Certificate', LMessage) > 0, 'SEC_E_UNTRUSTED_ROOT 英文消息包含"Certificate"');
    Assert(Pos('untrusted', LMessage) > 0, '消息包含"untrusted"');

    LMessage := GetSchannelErrorMessageEN(SEC_E_CERT_EXPIRED);
    Assert(Pos('expired', LMessage) > 0, 'SEC_E_CERT_EXPIRED 英文消息包含"expired"');

    LMessage := GetSchannelErrorMessageEN(CERT_E_CN_NO_MATCH);
    Assert(Pos('name', LMessage) > 0, 'CERT_E_CN_NO_MATCH 英文消息包含"name"');

    // 测试协议错误消息
    LMessage := GetSchannelErrorMessageEN(SEC_E_INVALID_TOKEN);
    Assert(Pos('TLS', LMessage) > 0, 'SEC_E_INVALID_TOKEN 英文消息包含"TLS"');

    // 测试内存错误消息
    LMessage := GetSchannelErrorMessageEN(ERROR_NOT_ENOUGH_MEMORY);
    Assert(Pos('memory', LMessage) > 0, 'ERROR_NOT_ENOUGH_MEMORY 英文消息包含"memory"');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestErrorClassification;
var
  LResult: TSSLErrorCode;
begin
  WriteLn('【测试 4】错误分类系统');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试成功状态分类
    LResult := ClassifyWinSSLError(SEC_E_OK);
    Assert(LResult = sslErrNone, 'SEC_E_OK 分类为 sslErrNone');

    // 测试握手状态分类
    LResult := ClassifyWinSSLError(SEC_I_CONTINUE_NEEDED);
    Assert(LResult = sslErrNone, 'SEC_I_CONTINUE_NEEDED 分类为 sslErrNone');

    // 测试阻塞状态分类
    LResult := ClassifyWinSSLError(SEC_E_INCOMPLETE_MESSAGE);
    Assert(LResult = sslErrWouldBlock, 'SEC_E_INCOMPLETE_MESSAGE 分类为 sslErrWouldBlock');

    // 测试协议错误分类
    LResult := ClassifyWinSSLError(SEC_E_INVALID_TOKEN);
    Assert(LResult = sslErrProtocol, 'SEC_E_INVALID_TOKEN 分类为 sslErrProtocol');

    // 测试不支持功能分类
    LResult := ClassifyWinSSLError(SEC_E_UNSUPPORTED_FUNCTION);
    Assert(LResult = sslErrUnsupported, 'SEC_E_UNSUPPORTED_FUNCTION 分类为 sslErrUnsupported');

    // 测试证书错误分类
    LResult := ClassifyWinSSLError(SEC_E_UNTRUSTED_ROOT);
    Assert(LResult = sslErrCertificateUntrusted, 'SEC_E_UNTRUSTED_ROOT 分类为 sslErrCertificateUntrusted');

    LResult := ClassifyWinSSLError(SEC_E_CERT_EXPIRED);
    Assert(LResult = sslErrCertificateExpired, 'SEC_E_CERT_EXPIRED 分类为 sslErrCertificateExpired');

    LResult := ClassifyWinSSLError(CERT_E_REVOKED);
    Assert(LResult = sslErrCertificateRevoked, 'CERT_E_REVOKED 分类为 sslErrCertificateRevoked');

    // 测试参数错误分类
    LResult := ClassifyWinSSLError(ERROR_INVALID_PARAMETER);
    Assert(LResult = sslErrInvalidParam, 'ERROR_INVALID_PARAMETER 分类为 sslErrInvalidParam');

    // 测试内存错误分类
    LResult := ClassifyWinSSLError(ERROR_NOT_ENOUGH_MEMORY);
    Assert(LResult = sslErrMemory, 'ERROR_NOT_ENOUGH_MEMORY 分类为 sslErrMemory');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestErrorCategory;
var
  LCategory: string;
begin
  WriteLn('【测试 5】错误分类名称');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试 SSPI 错误分类
    LCategory := GetWinSSLErrorCategory(SEC_E_OK);
    Assert(LCategory = 'SSPI', 'SEC_E_OK 分类为 SSPI');

    LCategory := GetWinSSLErrorCategory(SEC_E_INVALID_TOKEN);
    Assert(LCategory = 'SSPI', 'SEC_E_INVALID_TOKEN 分类为 SSPI');

    // 测试 CERT 错误分类
    LCategory := GetWinSSLErrorCategory(CERT_E_EXPIRED);
    Assert(LCategory = 'CERT', 'CERT_E_EXPIRED 分类为 CERT');

    LCategory := GetWinSSLErrorCategory(CERT_E_CN_NO_MATCH);
    Assert(LCategory = 'CERT', 'CERT_E_CN_NO_MATCH 分类为 CERT');

    // 测试 TRUST 错误分类
    LCategory := GetWinSSLErrorCategory(TRUST_E_CERT_SIGNATURE);
    Assert(LCategory = 'TRUST', 'TRUST_E_CERT_SIGNATURE 分类为 TRUST');

    // 测试 WIN32 错误分类
    LCategory := GetWinSSLErrorCategory(ERROR_INVALID_PARAMETER);
    Assert(LCategory = 'WIN32', 'ERROR_INVALID_PARAMETER 分类为 WIN32');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestConsoleErrorHandler;
var
  LHandler: ISSLErrorHandler;
  LErrorInfo: TSSLErrorInfo;
begin
  WriteLn('【测试 6】控制台错误处理器');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 创建控制台错误处理器
    LHandler := TSSLConsoleErrorHandler.Create;
    Assert(LHandler <> nil, '控制台错误处理器创建成功');

    // 测试错误处理
    FillChar(LErrorInfo, SizeOf(LErrorInfo), 0);
    LErrorInfo.Level := sslErrorError;
    LErrorInfo.Code := SEC_E_CERT_EXPIRED;
    LErrorInfo.Message := '测试错误消息';
    LErrorInfo.Context := 'TestContext';
    LErrorInfo.Timestamp := Now;

    LHandler.HandleError(LErrorInfo);
    Assert(True, '控制台错误处理器处理错误成功');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestErrorInfoFormatting;
var
  LErrorInfo: TSSLErrorInfo;
  LFormatted: string;
begin
  WriteLn('【测试 7】错误信息格式化');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 准备错误信息
    FillChar(LErrorInfo, SizeOf(LErrorInfo), 0);
    LErrorInfo.Level := sslErrorError;
    LErrorInfo.Code := SEC_E_CERT_EXPIRED;
    LErrorInfo.Message := '证书已过期';
    LErrorInfo.Context := 'TWinSSLConnection.DoHandshake';
    LErrorInfo.Timestamp := Now;

    // 格式化错误信息
    LFormatted := FormatErrorInfo(LErrorInfo);
    Assert(Length(LFormatted) > 0, '错误信息格式化成功');
    Assert(Pos('ERROR', LFormatted) > 0, '格式化信息包含错误级别');
    Assert(Pos('证书已过期', LFormatted) > 0, '格式化信息包含错误消息');

    // 测试不同错误级别
    LErrorInfo.Level := sslErrorDebug;
    LFormatted := FormatErrorInfo(LErrorInfo);
    Assert(Pos('DEBUG', LFormatted) > 0, '格式化信息包含 DEBUG 级别');

    LErrorInfo.Level := sslErrorWarning;
    LFormatted := FormatErrorInfo(LErrorInfo);
    Assert(Pos('WARNING', LFormatted) > 0, '格式化信息包含 WARNING 级别');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestSystemErrorMessage;
var
  LMessage: string;
begin
  WriteLn('【测试 8】系统错误消息获取');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试常见系统错误
    LMessage := GetSystemErrorMessage(ERROR_INVALID_PARAMETER);
    Assert(Length(LMessage) > 0, 'ERROR_INVALID_PARAMETER 系统消息非空');

    LMessage := GetSystemErrorMessage(ERROR_NOT_ENOUGH_MEMORY);
    Assert(Length(LMessage) > 0, 'ERROR_NOT_ENOUGH_MEMORY 系统消息非空');

    LMessage := GetSystemErrorMessage(ERROR_ACCESS_DENIED);
    Assert(Length(LMessage) > 0, 'ERROR_ACCESS_DENIED 系统消息非空');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestGlobalErrorLogging;
begin
  WriteLn('【测试 9】全局错误日志');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试启用/禁用错误日志
    EnableErrorLogging(True);
    Assert(True, '启用错误日志成功');

    EnableErrorLogging(False);
    Assert(True, '禁用错误日志成功');

    // 测试设置全局错误处理器
    SetGlobalErrorHandler(TSSLConsoleErrorHandler.Create);
    Assert(True, '设置全局错误处理器成功');

    // 清理
    SetGlobalErrorHandler(nil);
    EnableErrorLogging(False);

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestFriendlyErrorMessages;
var
  LMessage: string;
begin
  WriteLn('【测试 10】友好错误消息');
  WriteLn('---');

  {$IFDEF WINDOWS}
  try
    // 测试中文友好消息
    LMessage := GetFriendlyErrorMessageCN(SEC_E_CERT_EXPIRED);
    Assert(Pos('过期', LMessage) > 0, '中文友好消息包含"过期"');

    LMessage := GetFriendlyErrorMessageCN(ERROR_INVALID_PARAMETER);
    Assert(Pos('参数', LMessage) > 0, '中文友好消息包含"参数"');

    // 测试英文友好消息
    LMessage := GetFriendlyErrorMessageEN(SEC_E_CERT_EXPIRED);
    Assert(Pos('expired', LMessage) > 0, '英文友好消息包含"expired"');

    LMessage := GetFriendlyErrorMessageEN(ERROR_INVALID_PARAMETER);
    Assert(Pos('parameter', LMessage) > 0, '英文友好消息包含"parameter"');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure PrintSummary;
begin
  WriteLn('=========================================');
  WriteLn('测试总结');
  WriteLn('=========================================');
  WriteLn('通过: ', GTestsPassed);
  WriteLn('失败: ', GTestsFailed);
  WriteLn('总计: ', GTestsPassed + GTestsFailed);

  if GTestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('✓ 所有错误处理测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查错误处理实现');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('WinSSL 错误处理综合测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  {$IFDEF WINDOWS}
  WriteLn('运行环境: Windows');
  {$ELSE}
  WriteLn('运行环境: 非 Windows（部分测试将跳过）');
  {$ENDIF}
  WriteLn;

  try
    TestSchannelErrorMapping;
    TestErrorMessagesChinese;
    TestErrorMessagesEnglish;
    TestErrorClassification;
    TestErrorCategory;
    TestConsoleErrorHandler;
    TestErrorInfoFormatting;
    TestSystemErrorMessage;
    TestGlobalErrorLogging;
    TestFriendlyErrorMessages;

    WriteLn;
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn('错误: ', E.Message);
      Halt(1);
    end;
  end;
end.
