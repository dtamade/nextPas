{
  test_openssl_early_data_context - OpenSSL Early Data Context 接口测试
  
  测试 TOpenSSLContext 的 ISSLEarlyDataContext 和 
  ISSLServerOCSPStaplingContext 接口实现
}

program test_openssl_early_data_context;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  fafafa.ssl;  // 注册所有后端

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  EarlyDataCtx: ISSLEarlyDataContext;
  OCSPStaplingCtx: ISSLServerOCSPStaplingContext;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Pass(const ATestName: string);
begin
  WriteLn('[PASS] ', ATestName);
  Inc(TestsPassed);
end;

procedure Fail(const ATestName, AReason: string);
begin
  WriteLn('[FAIL] ', ATestName, ': ', AReason);
  Inc(TestsFailed);
end;

procedure TestEarlyDataInterfaceSupport;
begin
  Write('Test 1: ISSLEarlyDataContext interface support... ');
  try
    if Supports(Ctx, ISSLEarlyDataContext, EarlyDataCtx) then
      Pass('ISSLEarlyDataContext interface supported')
    else
      Fail('ISSLEarlyDataContext interface support', 'Interface not supported');
  except
    on E: Exception do
      Fail('ISSLEarlyDataContext interface support', E.Message);
  end;
end;

procedure TestOCSPStaplingInterfaceSupport;
begin
  Write('Test 2: ISSLServerOCSPStaplingContext interface support... ');
  try
    if Supports(Ctx, ISSLServerOCSPStaplingContext, OCSPStaplingCtx) then
      Pass('ISSLServerOCSPStaplingContext interface supported')
    else
      Fail('ISSLServerOCSPStaplingContext interface support', 'Interface not supported');
  except
    on E: Exception do
      Fail('ISSLServerOCSPStaplingContext interface support', E.Message);
  end;
end;

procedure TestClientEarlyDataEnabled;
begin
  Write('Test 3: Client Early Data enabled/disabled... ');
  try
    // 默认应该是禁用的
    if not EarlyDataCtx.GetClientEarlyDataEnabled then
    begin
      // 启用
      EarlyDataCtx.SetClientEarlyDataEnabled(True);
      if EarlyDataCtx.GetClientEarlyDataEnabled then
      begin
        // 禁用
        EarlyDataCtx.SetClientEarlyDataEnabled(False);
        if not EarlyDataCtx.GetClientEarlyDataEnabled then
          Pass('Client Early Data enable/disable')
        else
          Fail('Client Early Data enable/disable', 'Failed to disable');
      end
      else
        Fail('Client Early Data enable/disable', 'Failed to enable');
    end
    else
      Fail('Client Early Data enable/disable', 'Default should be disabled');
  except
    on E: Exception do
      Fail('Client Early Data enable/disable', E.Message);
  end;
end;

procedure TestServerEarlyDataPolicy;
begin
  Write('Test 4: Server Early Data policy... ');
  try
    // 默认应该是 Reject
    if EarlyDataCtx.GetServerEarlyDataPolicy = sslEarlyDataServerReject then
    begin
      // 设置为 Accept
      EarlyDataCtx.SetServerEarlyDataPolicy(sslEarlyDataServerAccept);
      if EarlyDataCtx.GetServerEarlyDataPolicy = sslEarlyDataServerAccept then
      begin
        // 设置为 IssueOnly
        EarlyDataCtx.SetServerEarlyDataPolicy(sslEarlyDataServerIssueOnly);
        if EarlyDataCtx.GetServerEarlyDataPolicy = sslEarlyDataServerIssueOnly then
        begin
          // 恢复为 Reject
          EarlyDataCtx.SetServerEarlyDataPolicy(sslEarlyDataServerReject);
          if EarlyDataCtx.GetServerEarlyDataPolicy = sslEarlyDataServerReject then
            Pass('Server Early Data policy')
          else
            Fail('Server Early Data policy', 'Failed to set Reject');
        end
        else
          Fail('Server Early Data policy', 'Failed to set IssueOnly');
      end
      else
        Fail('Server Early Data policy', 'Failed to set Accept');
    end
    else
      Fail('Server Early Data policy', 'Default should be Reject');
  except
    on E: Exception do
      Fail('Server Early Data policy', E.Message);
  end;
end;

procedure TestServerMaxEarlyDataSize;
begin
  Write('Test 5: Server max early data size... ');
  try
    // 默认应该是 16384 (16KB)
    if EarlyDataCtx.GetServerMaxEarlyDataSize = 16384 then
    begin
      // 设置为 8192
      EarlyDataCtx.SetServerMaxEarlyDataSize(8192);
      if EarlyDataCtx.GetServerMaxEarlyDataSize = 8192 then
      begin
        // 设置为 32768
        EarlyDataCtx.SetServerMaxEarlyDataSize(32768);
        if EarlyDataCtx.GetServerMaxEarlyDataSize = 32768 then
        begin
          // 恢复默认值
          EarlyDataCtx.SetServerMaxEarlyDataSize(16384);
          if EarlyDataCtx.GetServerMaxEarlyDataSize = 16384 then
            Pass('Server max early data size')
          else
            Fail('Server max early data size', 'Failed to restore default');
        end
        else
          Fail('Server max early data size', 'Failed to set 32768');
      end
      else
        Fail('Server max early data size', 'Failed to set 8192');
    end
    else
      Fail('Server max early data size', 'Default should be 16384');
  except
    on E: Exception do
      Fail('Server max early data size', E.Message);
  end;
end;

procedure TestOCSPStaplingResponse;
var
  TestResponse: TBytes;
  Retrieved: TBytes;
begin
  Write('Test 6: OCSP Stapling response... ');
  try
    // 初始应该没有响应
    if not OCSPStaplingCtx.HasServerStapledOCSPResponse then
    begin
      // 设置一个测试响应
      SetLength(TestResponse, 10);
      TestResponse[0] := $30; // DER SEQUENCE tag
      TestResponse[1] := $08; // Length
      TestResponse[2] := $01;
      TestResponse[3] := $02;
      TestResponse[4] := $03;
      TestResponse[5] := $04;
      TestResponse[6] := $05;
      TestResponse[7] := $06;
      TestResponse[8] := $07;
      TestResponse[9] := $08;
      
      OCSPStaplingCtx.SetServerStapledOCSPResponse(TestResponse);
      
      if OCSPStaplingCtx.HasServerStapledOCSPResponse then
      begin
        Retrieved := OCSPStaplingCtx.GetServerStapledOCSPResponse;
        if (Length(Retrieved) = Length(TestResponse)) and
           (Retrieved[0] = TestResponse[0]) and
           (Retrieved[9] = TestResponse[9]) then
        begin
          // 清除响应
          OCSPStaplingCtx.ClearServerStapledOCSPResponse;
          if not OCSPStaplingCtx.HasServerStapledOCSPResponse then
            Pass('OCSP Stapling response')
          else
            Fail('OCSP Stapling response', 'Failed to clear');
        end
        else
          Fail('OCSP Stapling response', 'Retrieved data mismatch');
      end
      else
        Fail('OCSP Stapling response', 'Failed to set response');
    end
    else
      Fail('OCSP Stapling response', 'Initial state should be empty');
  except
    on E: Exception do
      Fail('OCSP Stapling response', E.Message);
  end;
end;

procedure TestOCSPStaplingEmptyResponse;
var
  EmptyResponse: TBytes;
begin
  Write('Test 7: OCSP Stapling empty response error... ');
  try
    SetLength(EmptyResponse, 0);
    try
      OCSPStaplingCtx.SetServerStapledOCSPResponse(EmptyResponse);
      Fail('OCSP Stapling empty response error', 'Should raise exception');
    except
      on E: ESSLInvalidArgument do
        Pass('OCSP Stapling empty response error');
      on E: Exception do
        Fail('OCSP Stapling empty response error', 'Wrong exception type: ' + E.ClassName);
    end;
  except
    on E: Exception do
      Fail('OCSP Stapling empty response error', E.Message);
  end;
end;

procedure TestOCSPStaplingFileNotFound;
begin
  Write('Test 8: OCSP Stapling file not found error... ');
  try
    try
      OCSPStaplingCtx.LoadServerStapledOCSPResponseFile('/nonexistent/file.der');
      Fail('OCSP Stapling file not found error', 'Should raise exception');
    except
      on E: ESSLException do
        Pass('OCSP Stapling file not found error');
      on E: Exception do
        Fail('OCSP Stapling file not found error', 'Wrong exception type: ' + E.ClassName);
    end;
  except
    on E: Exception do
      Fail('OCSP Stapling file not found error', E.Message);
  end;
end;

begin
  WriteLn('=== OpenSSL Early Data Context Interface Tests ===');
  WriteLn;

  try
    // 创建 OpenSSL 库实例
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if Lib = nil then
    begin
      WriteLn('ERROR: Failed to get OpenSSL library');
      Halt(1);
    end;

    // 创建客户端上下文
    Ctx := Lib.CreateContext(sslCtxClient);
    if Ctx = nil then
    begin
      WriteLn('ERROR: Failed to create SSL context');
      Halt(1);
    end;

    WriteLn('OpenSSL library loaded successfully');
    WriteLn('SSL context created successfully');
    WriteLn;

    // 运行测试
    TestEarlyDataInterfaceSupport;
    TestOCSPStaplingInterfaceSupport;
    
    if EarlyDataCtx <> nil then
    begin
      TestClientEarlyDataEnabled;
      TestServerEarlyDataPolicy;
      TestServerMaxEarlyDataSize;
    end;
    
    if OCSPStaplingCtx <> nil then
    begin
      TestOCSPStaplingResponse;
      TestOCSPStaplingEmptyResponse;
      TestOCSPStaplingFileNotFound;
    end;

    // 输出结果
    WriteLn;
    WriteLn('=== Test Results ===');
    WriteLn('Passed: ', TestsPassed);
    WriteLn('Failed: ', TestsFailed);
    WriteLn('Total:  ', TestsPassed + TestsFailed);
    WriteLn;

    if TestsFailed = 0 then
    begin
      WriteLn('✅ All tests passed!');
      Halt(0);
    end
    else
    begin
      WriteLn('❌ Some tests failed!');
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
