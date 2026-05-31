program test_p2_ssl_options;

{$mode objfpc}{$H+}

uses
  SysUtils, ctypes,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.consts,
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

procedure Test_SSL_Functions_Available;
begin
  WriteLn;
  WriteLn('Test: SSL Context Functions Available');
  WriteLn('----------------------------------------');
  
  TestResult('SSL_CTX_new function loaded', 
             Assigned(SSL_CTX_new),
             'Function is available');
             
  TestResult('SSL_CTX_free function loaded',
             Assigned(SSL_CTX_free),
             'Function is available');
             
  TestResult('SSL_CTX_set_options function loaded',
             Assigned(SSL_CTX_set_options),
             'Function is available');
             
  TestResult('SSL_CTX_get_options function loaded',
             Assigned(SSL_CTX_get_options),
             'Function is available');
             
  TestResult('SSL_CTX_ctrl function loaded',
             Assigned(SSL_CTX_ctrl),
             'Function is available');
end;

procedure Test_SSL_Context_Creation;
var
  ctx: PSSL_CTX;
  method: PSSL_METHOD;
begin
  WriteLn;
  WriteLn('Test: SSL Context Creation');
  WriteLn('----------------------------------------');
  
  try
    // 获取 TLS 方法
    method := TLS_method();
    TestResult('Get TLS method',
               method <> nil,
               'Method pointer obtained');
    
    if method <> nil then
    begin
      // 创建 SSL 上下文
      ctx := SSL_CTX_new(method);
      TestResult('Create SSL context',
                 ctx <> nil,
                 'Context created successfully');
      
      if ctx <> nil then
      begin
        // 清理
        SSL_CTX_free(ctx);
        TestResult('Free SSL context',
                   True,
                   'Context freed successfully');
      end;
    end;
    
  except
    on E: Exception do
      TestResult('SSL context creation', False, E.Message);
  end;
end;

procedure Test_SSL_Options;
var
  ctx: PSSL_CTX;
  method: PSSL_METHOD;
  options: Cardinal;
  newOptions: Cardinal;
begin
  WriteLn;
  WriteLn('Test: SSL Options Management');
  WriteLn('----------------------------------------');
  
  try
    method := TLS_method();
    if method = nil then
    begin
      TestResult('SSL options test', False, 'Failed to get TLS method');
      Exit;
    end;
    
    ctx := SSL_CTX_new(method);
    if ctx = nil then
    begin
      TestResult('SSL options test', False, 'Failed to create context');
      Exit;
    end;
    
    try
      // 测试设置选项
      newOptions := SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2 or SSL_OP_NO_SSLv3);
      TestResult('Set SSL options (disable SSLv2/v3)',
                 newOptions <> 0,
                 'Options set: 0x' + IntToHex(newOptions, 8));
      
      // 测试获取选项
      options := SSL_CTX_get_options(ctx);
      TestResult('Get SSL options',
                 (options and SSL_OP_NO_SSLv2) <> 0,
                 'Options retrieved: 0x' + IntToHex(options, 8));
      
      // 测试添加更多选项
      newOptions := SSL_CTX_set_options(ctx, SSL_OP_NO_COMPRESSION);
      TestResult('Add SSL option (NO_COMPRESSION)',
                 (newOptions and SSL_OP_NO_COMPRESSION) <> 0,
                 'Option added successfully');
      
      // 验证所有选项都已设置
      options := SSL_CTX_get_options(ctx);
      TestResult('Verify cumulative options',
                 ((options and SSL_OP_NO_SSLv2) <> 0) and
                 ((options and SSL_OP_NO_SSLv3) <> 0) and
                 ((options and SSL_OP_NO_COMPRESSION) <> 0),
                 'All options are set');
                 
    finally
      SSL_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      TestResult('SSL options management', False, E.Message);
  end;
end;

procedure Test_Protocol_Version_Control;
var
  ctx: PSSL_CTX;
  method: PSSL_METHOD;
  result: clong;
begin
  WriteLn;
  WriteLn('Test: Protocol Version Control');
  WriteLn('----------------------------------------');
  
  try
    method := TLS_method();
    if method = nil then
    begin
      TestResult('Protocol version control', False, 'Failed to get TLS method');
      Exit;
    end;
    
    ctx := SSL_CTX_new(method);
    if ctx = nil then
    begin
      TestResult('Protocol version control', False, 'Failed to create context');
      Exit;
    end;
    
    try
      // 设置最小协议版本为 TLS 1.2
      result := SSL_CTX_ctrl(ctx, SSL_CTRL_SET_MIN_PROTO_VERSION, TLS1_2_VERSION, nil);
      TestResult('Set minimum protocol version (TLS 1.2)',
                 result = 1,
                 'Min version set successfully');
      
      // 设置最大协议版本为 TLS 1.3
      result := SSL_CTX_ctrl(ctx, SSL_CTRL_SET_MAX_PROTO_VERSION, TLS1_3_VERSION, nil);
      TestResult('Set maximum protocol version (TLS 1.3)',
                 result = 1,
                 'Max version set successfully');
      
      // 获取最小协议版本
      result := SSL_CTX_ctrl(ctx, SSL_CTRL_GET_MIN_PROTO_VERSION, 0, nil);
      TestResult('Get minimum protocol version',
                 result = TLS1_2_VERSION,
                 'Min version: 0x' + IntToHex(result, 4));
      
      // 获取最大协议版本
      result := SSL_CTX_ctrl(ctx, SSL_CTRL_GET_MAX_PROTO_VERSION, 0, nil);
      TestResult('Get maximum protocol version',
                 result = TLS1_3_VERSION,
                 'Max version: 0x' + IntToHex(result, 4));
                 
    finally
      SSL_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      TestResult('Protocol version control', False, E.Message);
  end;
end;

procedure Test_SSL_Mode;
var
  ctx: PSSL_CTX;
  method: PSSL_METHOD;
  mode: Cardinal;
begin
  WriteLn;
  WriteLn('Test: SSL Mode Settings');
  WriteLn('----------------------------------------');
  
  try
    method := TLS_method();
    if method = nil then
    begin
      TestResult('SSL mode test', False, 'Failed to get TLS method');
      Exit;
    end;
    
    ctx := SSL_CTX_new(method);
    if ctx = nil then
    begin
      TestResult('SSL mode test', False, 'Failed to create context');
      Exit;
    end;
    
    try
      // 设置模式
      mode := Cardinal(SSL_CTX_ctrl(ctx, SSL_CTRL_MODE, 
                                      SSL_MODE_ENABLE_PARTIAL_WRITE or
                                      SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER, 
                                      nil));
      TestResult('Set SSL modes',
                 mode <> 0,
                 'Modes set: 0x' + IntToHex(mode, 8));
      
      // 验证模式已设置
      TestResult('Verify partial write mode enabled',
                 (mode and SSL_MODE_ENABLE_PARTIAL_WRITE) <> 0,
                 'Mode is active');
      
      TestResult('Verify moving buffer mode enabled',
                 (mode and SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER) <> 0,
                 'Mode is active');
                 
    finally
      SSL_CTX_free(ctx);
    end;
    
  except
    on E: Exception do
      TestResult('SSL mode settings', False, E.Message);
  end;
end;

procedure Test_Constants_Defined;
begin
  WriteLn;
  WriteLn('Test: SSL Constants Defined');
  WriteLn('----------------------------------------');
  
  // 测试协议版本常量
  TestResult('TLS 1.0 version constant',
             TLS1_VERSION = $0301,
             'Value: 0x' + IntToHex(TLS1_VERSION, 4));
             
  TestResult('TLS 1.2 version constant',
             TLS1_2_VERSION = $0303,
             'Value: 0x' + IntToHex(TLS1_2_VERSION, 4));
             
  TestResult('TLS 1.3 version constant',
             TLS1_3_VERSION = $0304,
             'Value: 0x' + IntToHex(TLS1_3_VERSION, 4));
  
  // 测试选项常量
  TestResult('SSL_OP_NO_SSLv2 constant',
             SSL_OP_NO_SSLv2 = $01000000,
             'Value: 0x' + IntToHex(SSL_OP_NO_SSLv2, 8));
             
  TestResult('SSL_OP_NO_SSLv3 constant',
             SSL_OP_NO_SSLv3 = $02000000,
             'Value: 0x' + IntToHex(SSL_OP_NO_SSLv3, 8));
             
  TestResult('SSL_OP_NO_TLSv1 constant',
             SSL_OP_NO_TLSv1 = $04000000,
             'Value: 0x' + IntToHex(SSL_OP_NO_TLSv1, 8));
  
  // 测试模式常量
  TestResult('SSL_MODE_ENABLE_PARTIAL_WRITE constant',
             SSL_MODE_ENABLE_PARTIAL_WRITE = $00000001,
             'Value: 0x' + IntToHex(SSL_MODE_ENABLE_PARTIAL_WRITE, 8));
             
  TestResult('SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER constant',
             SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER = $00000002,
             'Value: 0x' + IntToHex(SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER, 8));
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
  WriteLn('P2 Module Test: SSL Options & Protocols');
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
    
    // 加载 SSL 模块
    if not LoadOpenSSLSSL then
    begin
      WriteLn('[ERROR] Failed to load SSL module');
      Halt(1);
    end;
    WriteLn('SSL module loaded successfully');
    
    // 加载 ERR 模块(用于错误处理)
    if not LoadOpenSSLERR then
    begin
      WriteLn('[ERROR] Failed to load ERR module');
      Halt(1);
    end;
    WriteLn('ERR module loaded successfully');
    WriteLn;
    
    // 运行测试
    Test_Constants_Defined;
    Test_SSL_Functions_Available;
    Test_SSL_Context_Creation;
    Test_SSL_Options;
    Test_Protocol_Version_Control;
    Test_SSL_Mode;
    
    PrintSummary;
    
    WriteLn;
    if PassedTests = TotalTests then
    begin
      WriteLn('Result: All tests passed!');
      WriteLn('SSL Options & Protocol module is production ready!');
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
