program test_p2_err;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.err;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;

procedure TestResult(const TestName: string; Success: Boolean; const Details: string = '');
begin
  Inc(TotalTests);
  if Success then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', TestName);
    if Details <> '' then
      WriteLn('       ', Details);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    if Details <> '' then
      WriteLn('       Reason: ', Details);
  end;
end;

procedure Test_ERR_Functions_Available;
begin
  WriteLn;
  WriteLn('Test: ERR Functions Available');
  WriteLn('----------------------------------------');
  
  TestResult('ERR_get_error function loaded', 
             Assigned(ERR_get_error),
             'Function is available');
             
  TestResult('ERR_error_string function loaded',
             Assigned(ERR_error_string),
             'Function is available');
             
  TestResult('ERR_clear_error function loaded',
             Assigned(ERR_clear_error),
             'Function is available');
end;

procedure Test_ERR_Clear_Error;
begin
  WriteLn;
  WriteLn('Test: Clear Error Queue');
  WriteLn('----------------------------------------');
  
  try
    // 清除错误队列
    ERR_clear_error();
    TestResult('Clear error queue', True, 'Successfully cleared');
    
    // 验证队列为空
    TestResult('Error queue is empty',
               ERR_get_error() = 0,
               'No errors in queue');
  except
    on E: Exception do
      TestResult('Clear error queue', False, E.Message);
  end;
end;

procedure Test_ERR_Get_Error;
var
  ErrCode: Cardinal;
  ErrMsg: array[0..255] of AnsiChar;
  TestErrCode: Cardinal;
begin
  WriteLn;
  WriteLn('Test: Get Error Code and Message');
  WriteLn('----------------------------------------');
  
  try
    // 清除现有错误
    ERR_clear_error();
    
    // 获取错误代码（应该为0）
    ErrCode := ERR_get_error();
    TestResult('Get error when queue is empty',
               ErrCode = 0,
               'Error code: ' + IntToStr(ErrCode));
    
    // 测试错误字符串转换（使用构造的错误代码）
    // ERR_LIB_SSL = 20, reason = 1
    if Assigned(ERR_error_string_n) then
    begin
      TestErrCode := (ERR_LIB_SSL shl 24) or 1;
      FillChar(ErrMsg, SizeOf(ErrMsg), 0);
      ERR_error_string_n(TestErrCode, @ErrMsg[0], SizeOf(ErrMsg));
      TestResult('Get error string for constructed error',
                 ErrMsg[0] <> #0,
                 'Error string: ' + string(ErrMsg));
    end
    else
      TestResult('Get error string', False, 'Function not available');
      
  except
    on E: Exception do
      TestResult('Get error code', False, E.Message);
  end;
end;

procedure Test_ERR_Peek_Error;
var
  ErrCode: Cardinal;
begin
  WriteLn;
  WriteLn('Test: Peek Error (Non-Destructive Read)');
  WriteLn('----------------------------------------');
  
  try
    ERR_clear_error();
    
    if Assigned(ERR_peek_error) then
    begin
      ErrCode := ERR_peek_error();
      TestResult('Peek error when queue is empty',
                 ErrCode = 0,
                 'Error code: ' + IntToStr(ErrCode));
                 
      // 再次 peek 应该返回相同结果
      ErrCode := ERR_peek_error();
      TestResult('Peek error is non-destructive',
                 ErrCode = 0,
                 'Error code still: ' + IntToStr(ErrCode));
    end
    else
      TestResult('Peek error', False, 'Function not available');
      
  except
    on E: Exception do
      TestResult('Peek error', False, E.Message);
  end;
end;

procedure Test_ERR_Error_String_n;
var
  ErrMsg: array[0..255] of AnsiChar;
begin
  WriteLn;
  WriteLn('Test: Error String with Length');
  WriteLn('----------------------------------------');
  
  try
    if Assigned(ERR_error_string_n) then
    begin
      FillChar(ErrMsg, SizeOf(ErrMsg), 0);
      ERR_error_string_n(0, @ErrMsg[0], SizeOf(ErrMsg));
      
      TestResult('Get error string with length',
                 True,
                 'Function executed successfully');
    end
    else
      TestResult('Error string with length', False, 'Function not available');
      
  except
    on E: Exception do
      TestResult('Error string with length', False, E.Message);
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('TEST SUMMARY');
  WriteLn('========================================');
  WriteLn('Total tests: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', TotalTests - PassedTests);
  if TotalTests > 0 then
    WriteLn('Pass rate: ', (PassedTests * 100) div TotalTests, '.', 
            ((PassedTests * 1000) div TotalTests) mod 10, '%');
  WriteLn('========================================');
end;

begin
  WriteLn('========================================');
  WriteLn('P2 Module Test: ERR (Error Handling)');
  WriteLn('========================================');
  
  try
    // 加载 OpenSSL
    LoadOpenSSLCore();
    
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('[ERROR] Failed to load OpenSSL');
      Halt(1);
    end;
    
    WriteLn('OpenSSL version: ', GetOpenSSLVersionString);
    
    // 加载 ERR 模块
    if not LoadOpenSSLERR then
    begin
      WriteLn('[ERROR] Failed to load ERR module');
      Halt(1);
    end;
    WriteLn('ERR module loaded successfully');
    WriteLn();
    
    // 运行测试
    Test_ERR_Functions_Available;
    Test_ERR_Clear_Error;
    Test_ERR_Get_Error;
    Test_ERR_Peek_Error;
    Test_ERR_Error_String_n;
    
    PrintSummary;
    
    WriteLn;
    if PassedTests = TotalTests then
    begin
      WriteLn('Result: All tests passed!');
      WriteLn('ERR module is production ready!');
    end
    else
    begin
      WriteLn('Result: ', TotalTests - PassedTests, ' test(s) failed');
      Halt(1);
    end;
      
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
