program test_winssl_library_basic;

{$mode objfpc}{$H+}

uses
  SysUtils,
  
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
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

procedure TestSection(const SectionName: string);
begin
  WriteLn;
  WriteLn('=== ', SectionName, ' ===');
end;

// ============================================================================
// 测试库初始化
// ============================================================================

procedure TestLibraryInitialization;
var
  Lib: ISSLLibrary;
begin
  TestSection('Library Initialization Tests');
  
  // Test 1: Create library
  try
    Lib := CreateWinSSLLibrary;
    SSLLib := Lib;  // 保存到全局变量供后续测试使用
    if Lib <> nil then
      TestPass('CreateWinSSLLibrary')
    else
      TestFail('CreateWinSSLLibrary', 'Returned nil');
  except
    on E: Exception do
      TestFail('CreateWinSSLLibrary', E.Message);
  end;
  
  // Test 2: Initialize library
  try
    if Lib.Initialize then
      TestPass('Library.Initialize')
    else
      TestFail('Library.Initialize', 'Returned False');
  except
    on E: Exception do
      TestFail('Library.Initialize', E.Message);
  end;
  
  // Test 3: Check if initialized
  if Lib.IsInitialized then
    TestPass('Library.IsInitialized')
  else
    TestFail('Library.IsInitialized', 'Not initialized');
end;

// ============================================================================
// 测试版本信息
// ============================================================================

procedure TestVersionInfo;
var
  VersionStr: string;
  LibType: TSSLLibraryType;
begin
  TestSection('Version Information Tests');
  
  // Test 1: Get library type
  try
    LibType := SSLLib.GetLibraryType;
    if LibType = sslWinSSL then
      TestPass('GetLibraryType')
    else
      TestFail('GetLibraryType', 'Wrong type');
  except
    on E: Exception do
      TestFail('GetLibraryType', E.Message);
  end;
  
  // Test 2: Get version string
  try
    VersionStr := SSLLib.GetVersionString;
    if Pos('Schannel', VersionStr) > 0 then
      TestPass('GetVersionString: ' + VersionStr)
    else
      TestFail('GetVersionString', 'Invalid version string: ' + VersionStr);
  except
    on E: Exception do
      TestFail('GetVersionString', E.Message);
  end;
  
  // Test 3: Get version number
  try
    if SSLLib.GetVersionNumber > 0 then
      TestPass('GetVersionNumber')
    else
      TestFail('GetVersionNumber', 'Invalid version number');
  except
    on E: Exception do
      TestFail('GetVersionNumber', E.Message);
  end;
  
  // Test 4: Get compile flags
  try
    VersionStr := SSLLib.GetCompileFlags;
    if Length(VersionStr) > 0 then
      TestPass('GetCompileFlags: ' + VersionStr)
    else
      TestFail('GetCompileFlags', 'Empty string');
  except
    on E: Exception do
      TestFail('GetCompileFlags', E.Message);
  end;
end;

// ============================================================================
// 测试协议支持
// ============================================================================

procedure TestProtocolSupport;
begin
  TestSection('Protocol Support Tests');
  
  // Test 1: TLS 1.2 support
  if SSLLib.IsProtocolSupported(sslProtocolTLS12) then
    TestPass('TLS 1.2 supported')
  else
    TestFail('TLS 1.2 supported', 'Should be supported');
    
  // Test 2: SSL 2.0 not supported
  if not SSLLib.IsProtocolSupported(sslProtocolSSL2) then
    TestPass('SSL 2.0 not supported (correct)')
  else
    TestFail('SSL 2.0 not supported', 'Should not be supported');
    
  // Test 3: SSL 3.0 not supported
  if not SSLLib.IsProtocolSupported(sslProtocolSSL3) then
    TestPass('SSL 3.0 not supported (correct)')
  else
    TestFail('SSL 3.0 not supported', 'Should not be supported');
end;

// ============================================================================
// 测试功能支持
// ============================================================================

procedure TestFeatureSupport;
begin
  TestSection('Feature Support Tests');

  // Test 1: SNI support
  if SSLLib.IsFeatureSupported(sslFeatSNI) then
    TestPass('SNI supported')
  else
    TestFail('SNI supported', 'Should be supported');

  // Test 2: Session cache support
  if SSLLib.IsFeatureSupported(sslFeatSessionCache) then
    TestPass('Session cache supported')
  else
    TestFail('Session cache supported', 'Should be supported');
end;

// ============================================================================
// 测试上下文创建
// ============================================================================

procedure TestContextCreation;
begin
  TestSection('Context Creation Tests');
  
  // Test 1: Create client context
  try
    Context := SSLLib.CreateContext(sslCtxClient);
    if Context <> nil then
      TestPass('CreateContext (client)')
    else
      TestFail('CreateContext (client)', 'Returned nil');
  except
    on E: Exception do
      TestFail('CreateContext (client)', E.Message);
  end;
  
  if Context <> nil then
  begin
    // Test 2: Get context type
    if Context.GetContextType = sslCtxClient then
      TestPass('Context.GetContextType')
    else
      TestFail('Context.GetContextType', 'Wrong type');
      
    // Test 3: Set protocol versions
    try
      Context.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      TestPass('Context.SetProtocolVersions');
    except
      on E: Exception do
        TestFail('Context.SetProtocolVersions', E.Message);
    end;
    
    // Test 4: Get protocol versions
    try
      if sslProtocolTLS12 in Context.GetProtocolVersions then
        TestPass('Context.GetProtocolVersions')
      else
        TestFail('Context.GetProtocolVersions', 'TLS 1.2 not in set');
    except
      on E: Exception do
        TestFail('Context.GetProtocolVersions', E.Message);
    end;
    
    // Test 5: Set server name
    try
      // INTENTIONAL_API_SURFACE: context-level SNI setter coverage. This
      // WinSSL smoke test intentionally keeps the deprecated context API visible.
      Context.SetServerName('example.com');
      if Context.GetServerName = 'example.com' then
        TestPass('Context SetServerName/GetServerName')
      else
        TestFail('Context SetServerName/GetServerName', 'Value mismatch');
    except
      on E: Exception do
        TestFail('Context SetServerName/GetServerName', E.Message);
    end;
  end;
end;

// ============================================================================
// 测试错误处理
// ============================================================================

procedure TestErrorHandling;
begin
  TestSection('Error Handling Tests');
  
  // Test 1: Clear error
  try
    SSLLib.ClearError;
    if SSLLib.GetLastError = 0 then
      TestPass('ClearError')
    else
      TestFail('ClearError', 'Error not cleared');
  except
    on E: Exception do
      TestFail('ClearError', E.Message);
  end;
end;

// ============================================================================
// 测试统计信息
// ============================================================================

procedure TestStatistics;
var
  Stats: TSSLStatistics;
begin
  TestSection('Statistics Tests');
  
  // Test 1: Get statistics
  try
    Stats := SSLLib.GetStatistics;
    // 至少应该有一个上下文被创建
    if Stats.ConnectionsTotal > 0 then
      TestPass('GetStatistics (ConnectionsTotal > 0)')
    else
      TestFail('GetStatistics', 'No connections counted');
  except
    on E: Exception do
      TestFail('GetStatistics', E.Message);
  end;
  
  // Test 2: Reset statistics
  try
    SSLLib.ResetStatistics;
    Stats := SSLLib.GetStatistics;
    if Stats.ConnectionsTotal = 0 then
      TestPass('ResetStatistics')
    else
      TestFail('ResetStatistics', 'Statistics not reset');
  except
    on E: Exception do
      TestFail('ResetStatistics', E.Message);
  end;
end;

// ============================================================================
// 测试库清理
// ============================================================================

procedure TestLibraryFinalization;
begin
  TestSection('Library Finalization Tests');
  
  // Test 1: Finalize library
  try
    SSLLib.Finalize;
    if not SSLLib.IsInitialized then
      TestPass('Library.Finalize')
    else
      TestFail('Library.Finalize', 'Still initialized');
  except
    on E: Exception do
      TestFail('Library.Finalize', E.Message);
  end;
end;

// ============================================================================
// 主程序
// ============================================================================

begin
  WriteLn('WinSSL Library Basic Tests');
  WriteLn('===========================');
  WriteLn;
  
  try
    TestLibraryInitialization;
    TestVersionInfo;
    TestProtocolSupport;
    TestFeatureSupport;
    TestContextCreation;
    TestErrorHandling;
    TestStatistics;
    TestLibraryFinalization;
    
    WriteLn;
    WriteLn('===========================');
    WriteLn('Test Results:');
    WriteLn('  Passed: ', TestsPassed);
    WriteLn('  Failed: ', TestsFailed);
    WriteLn('  Total:  ', TestsPassed + TestsFailed);
    
    if TestsFailed = 0 then
    begin
      WriteLn;
      WriteLn('�?All tests passed!');
      ExitCode := 0;
    end
    else
    begin
      WriteLn;
      WriteLn('�?Some tests failed!');
      ExitCode := 1;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
