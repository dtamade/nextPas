program test_winssl_actual_features;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{$IFDEF WINDOWS}
uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestPass(const TestName: string);
begin
  WriteLn('[PASS] ', TestName);
  Inc(TestsPassed);
end;

procedure TestFail(const TestName, Reason: string);
begin
  WriteLn('[FAIL] ', TestName, ': ', Reason);
  Inc(TestsFailed);
end;

procedure Test1_WinSSLLibrary;
var
  LLib: ISSLLibrary;
begin
  WriteLn;
  WriteLn('=== Test 1: WinSSL Library 创建 ===');
  
  try
    LLib := CreateWinSSLLibrary;
    
    if LLib <> nil then
    begin
      TestPass('WinSSL Library 创建成功');
      WriteLn('   Version: ', LLib.GetVersionString);
      
      if LLib.Initialize then
        TestPass('WinSSL Library 初始化')
      else
        TestFail('WinSSL Library 初始化', 'Initialize returned false');
        
      WriteLn('   IsInitialized: ', LLib.IsInitialized);
    end
    else
      TestFail('WinSSL Library 创建', 'Returned nil');
      
  except
    on E: Exception do
      TestFail('WinSSL Library 创建', E.Message);
  end;
end;

procedure Test2_WinSSLContext;
var
  LContext: ISSLContext;
  LLib: ISSLLibrary;
begin
  WriteLn;
  WriteLn('=== Test 2: WinSSL Context 创建和配置 ===');
  
  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('WinSSL Context 创建', 'Library initialization failed');
      Exit;
    end;
    
    LContext := LLib.CreateContext(sslCtxClient);
    
    if LContext <> nil then
    begin
      TestPass('WinSSL Context 创建成功');
      
      // 测试协议版本设置
      LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      TestPass('设置协议版本 (TLS 1.2/1.3)');
      
      // 测试验证模式设置
      LContext.SetVerifyMode([sslVerifyPeer]);
      TestPass('设置验证模式 (VerifyPeer)');
    end
    else
      TestFail('WinSSL Context 创建', 'Returned nil');
      
  except
    on E: Exception do
      TestFail('WinSSL Context 创建', E.Message);
  end;
end;

procedure Test3_ProtocolSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn;
  WriteLn('=== Test 3: 协议支持检测 ===');
  
  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('协议支持检测', 'Library initialization failed');
      Exit;
    end;
    
    // TLS 1.2 应该被支持
    if LLib.IsProtocolSupported(sslProtocolTLS12) then
      TestPass('TLS 1.2 支持')
    else
      TestFail('TLS 1.2 支持', 'Should be supported');
      
    // SSL 2.0 不应该被支持
    if not LLib.IsProtocolSupported(sslProtocolSSL2) then
      TestPass('SSL 2.0 不支持 (正确)')
    else
      TestFail('SSL 2.0 不支持', 'Should not be supported');
      
  except
    on E: Exception do
      TestFail('协议支持检测', E.Message);
  end;
end;

procedure Test4_FeatureSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn;
  WriteLn('=== Test 4: 功能支持检测 ===');
  
  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      TestFail('功能支持检测', 'Library initialization failed');
      Exit;
    end;
    
    // SNI 应该被支持
    if LLib.IsFeatureSupported(sslFeatSNI) then
      TestPass('SNI 支持')
    else
      TestFail('SNI 支持', 'Should be supported');
      
    // Session Cache 应该被支持
    if LLib.IsFeatureSupported(sslFeatSessionCache) then
      TestPass('Session Cache 支持')
    else
      TestFail('Session Cache 支持', 'Should be supported');
      
  except
    on E: Exception do
      TestFail('功能支持检测', E.Message);
  end;
end;

begin
  WriteLn('WinSSL Actual Features Test');
  WriteLn('============================');
  
  Test1_WinSSLLibrary;
  Test2_WinSSLContext;
  Test3_ProtocolSupport;
  Test4_FeatureSupport;
  
  WriteLn;
  WriteLn('============================');
  WriteLn('Test Results:');
  WriteLn('  Passed: ', TestsPassed);
  WriteLn('  Failed: ', TestsFailed);
  WriteLn('  Total:  ', TestsPassed + TestsFailed);
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('All tests passed!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn;
    WriteLn('Some tests failed!');
    ExitCode := 1;
  end;
end.
{$ELSE}
begin
  WriteLn('This test is Windows-only');
end.
{$ENDIF}
