program test_lib_core_functionality;

{$mode objfpc}{$H+}

{
  核心功能验证测试
  
  功能：验证库的核心组件是否正常工作（无需网络连接）
  用途：快速发现编译和初始化问题
}

uses
  SysUtils, Classes,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.encoding,
  nextpas.core.tls.openssl.backed;

type
  TTestResult = record
    Name: string;
    Passed: Boolean;
    ErrorMsg: string;
  end;

var
  GResults: array of TTestResult;
  GTotalTests: Integer = 0;
  GPassedTests: Integer = 0;

procedure AddResult(const AName: string; APassed: Boolean; const AError: string = '');
begin
  SetLength(GResults, Length(GResults) + 1);
  GResults[High(GResults)].Name := AName;
  GResults[High(GResults)].Passed := APassed;
  GResults[High(GResults)].ErrorMsg := AError;
  Inc(GTotalTests);
  if APassed then
    Inc(GPassedTests);
end;

procedure TestLibraryInitialization;
var
  LLib: ISSLLibrary;
begin
  Write('[1] Library Initialization... ');
  try
    LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if LLib = nil then
    begin
      AddResult('Library Creation', False, 'CreateLibrary returned nil');
      WriteLn('✗');
      Exit;
    end;
    
    if not LLib.Initialize then
    begin
      AddResult('Library Initialization', False, 'Initialize returned False');
      WriteLn('✗');
      Exit;
    end;
    
    AddResult('Library Initialization', True);
    WriteLn('✓');
    WriteLn('    Version: ', LLib.GetVersionString);
    
    LLib.Finalize;
  except
    on E: Exception do
    begin
      AddResult('Library Initialization', False, E.Message);
      WriteLn('✗');
      WriteLn('    Error: ', E.Message);
    end;
  end;
end;

procedure TestContextCreation;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  Write('[2] SSL Context Creation... ');
  try
    LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not LLib.Initialize then
    begin
      AddResult('Context Creation', False, 'Library init failed');
      WriteLn('✗');
      Exit;
    end;
    
    // Test client context
    LContext := LLib.CreateContext(sslCtxClient);
    if LContext = nil then
    begin
      AddResult('Client Context', False, 'CreateContext(Client) returned nil');
      WriteLn('✗');
      LLib.Finalize;
      Exit;
    end;
    
    // Test server context  
    LContext := LLib.CreateContext(sslCtxServer);
    if LContext = nil then
    begin
      AddResult('Server Context', False, 'CreateContext(Server) returned nil');
      WriteLn('✗');
      LLib.Finalize;
      Exit;
    end;
    
    AddResult('SSL Context Creation', True);
    WriteLn('✓');
    WriteLn('    Client & Server contexts created successfully');
    
    LLib.Finalize;
  except
    on E: Exception do
    begin
      AddResult('SSL Context Creation', False, E.Message);
      WriteLn('✗');
      WriteLn('    Error: ', E.Message);
    end;
  end;
end;

procedure TestCryptoUtils;
var
  LHash: TBytes;
  LHexHash, LBase64Hash: string;
  LEncoded, LDecoded: string;
begin
  Write('[3] Crypto Utils (Base64, SHA256)... ');
  try
    // Test SHA256
    LHash := TCryptoUtils.SHA256('test');
    if Length(LHash) <> 32 then
    begin
      AddResult('SHA256', False, Format('Expected 32 bytes, got %d', [Length(LHash)]));
      WriteLn('✗');
      Exit;
    end;
    
    LHexHash := TCryptoUtils.SHA256Hex('test');
    if LHexHash <> '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' then
    begin
      AddResult('SHA256Hex', False, 'Hash mismatch');
      WriteLn('✗');
      Exit;
    end;
    
    // Test Base64
    LEncoded := TEncodingUtils.Base64Encode('Hello World');
    if LEncoded <> 'SGVsbG8gV29ybGQ=' then
    begin
      AddResult('Base64Encode', False, 'Encoding mismatch');
      WriteLn('✗');
      Exit;
    end;
    
    LDecoded := TEncodingUtils.Base64DecodeString(LEncoded);
    if LDecoded <> 'Hello World' then
    begin
      AddResult('Base64Decode', False, 'Decoding mismatch');
      WriteLn('✗');
      Exit;
    end;
    
    // Test SHA256Base64
    LBase64Hash := TCryptoUtils.SHA256Base64('test');
    
    AddResult('Crypto Utils', True);
    WriteLn('✓');
    WriteLn('    SHA256, Base64 working correctly');
  except
    on E: Exception do
    begin
      AddResult('Crypto Utils', False, E.Message);
      WriteLn('✗');
      WriteLn('    Error: ', E.Message);
    end;
  end;
end;

procedure TestMultipleInitFinalize;
var
  LLib: ISSLLibrary;
  I: Integer;
begin
  Write('[4] Multiple Init/Finalize Cycles... ');
  try
    for I := 1 to 10 do
    begin
      LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
      if not LLib.Initialize then
      begin
        AddResult('Multiple Init/Finalize', False, Format('Failed at iteration %d', [I]));
        WriteLn('✗');
        Exit;
      end;
      LLib.Finalize;
    end;
    
    AddResult('Multiple Init/Finalize', True);
    WriteLn('✓');
    WriteLn('    10 cycles completed successfully');
  except
    on E: Exception do
    begin
      AddResult('Multiple Init/Finalize', False, E.Message);
      WriteLn('✗');
      WriteLn('    Error: ', E.Message);
    end;
  end;
end;

procedure TestContextConfiguration;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
begin
  Write('[5] Context Configuration... ');
  try
    LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not LLib.Initialize then
    begin
      AddResult('Context Configuration', False, 'Init failed');
      WriteLn('✗');
      Exit;
    end;
    
    LContext := LLib.CreateContext(sslCtxClient);
    
    // Test various config methods
    try
      // INTENTIONAL_API_SURFACE: context-level SNI setter coverage. This
      // smoke test validates the context API itself, not recommended connection flow.
      LContext.SetServerName('www.example.com');
      LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      LContext.SetVerifyMode([sslVerifyPeer]);
      
      AddResult('Context Configuration', True);
      WriteLn('✓');
      WriteLn('    SetServerName, SetProtocolVersions, SetVerifyMode working');
    except
      on E: Exception do
      begin
        AddResult('Context Configuration', False, E.Message);
        WriteLn('✗');
        WriteLn('    Error: ', E.Message);
      end;
    end;
    
    LLib.Finalize;
  except
    on E: Exception do
    begin
      AddResult('Context Configuration', False, E.Message);
      WriteLn('✗');
      WriteLn('    Error: ', E.Message);
    end;
  end;
end;

procedure PrintSummary;
var
  I: Integer;
begin
  WriteLn;
  WriteLn('================================================================');
  WriteLn('Test Summary:');
  WriteLn('  Total:  ', GTotalTests);
  WriteLn('  Passed: ', GPassedTests, Format('  (%.1f%%)', [GPassedTests * 100.0 / GTotalTests]));
  WriteLn('  Failed: ', GTotalTests - GPassedTests);
  WriteLn('================================================================');
  WriteLn;
  
  if GPassedTests < GTotalTests then
  begin
    WriteLn('Failed Tests:');
    for I := 0 to High(GResults) do
    begin
      if not GResults[I].Passed then
        WriteLn('  - ', GResults[I].Name, ': ', GResults[I].ErrorMsg);
    end;
    WriteLn;
  end;
  
  if GPassedTests = GTotalTests then
  begin
    WriteLn('✅ All core functionality tests passed!');
    WriteLn;
    WriteLn('Library is ready for:');
    WriteLn('  1. Network connection testing');
    WriteLn('  2. Real HTTPS website testing');
    WriteLn('  3. Production use');
  end
  else
  begin
    WriteLn('⚠️  Some tests failed. Library may not be fully functional.');
    WriteLn;
    WriteLn('Next steps:');
    WriteLn('  1. Review error messages above');
    WriteLn('  2. Check OpenSSL installation');
    WriteLn('  3. Verify library paths');
  end;
end;

begin
  WriteLn('================================================================');
  WriteLn('  fafafa.ssl - Core Functionality Verification');
  WriteLn('================================================================');
  WriteLn;
  WriteLn('Platform: ', {$I %FPCTARGETOS%});
  WriteLn('Compiler: Free Pascal ', {$I %FPCVERSION%});
  WriteLn;
  WriteLn('Running tests...');
  WriteLn('----------------------------------------------------------------');
  
  TestLibraryInitialization;
  TestContextCreation;
  TestCryptoUtils;
  TestMultipleInitFinalize;
  TestContextConfiguration;
  
  WriteLn('----------------------------------------------------------------');
  
  PrintSummary;
  
  if GPassedTests < GTotalTests then
    Halt(1);
end.
