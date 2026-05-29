program test_winssl_utils;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.utils;

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

procedure TestSection(const SectionName: string);
begin
  WriteLn;
  WriteLn('=== ', SectionName, ' ===');
end;

// ============================================================================
// 测试错误码处理
// ============================================================================

procedure TestErrorHandling;
var
  ErrorMsg: string;
  Category: TSchannelErrorCategory;
begin
  TestSection('Error Handling Tests');
  
  // Test 1: Success error code
  Category := GetSchannelErrorCategory(SEC_E_OK);
  if Category = secSuccess then
    TestPass('GetSchannelErrorCategory - Success')
  else
    TestFail('GetSchannelErrorCategory - Success', 'Wrong category');
    
  // Test 2: Continue needed
  Category := GetSchannelErrorCategory(SEC_I_CONTINUE_NEEDED);
  if Category = secContinue then
    TestPass('GetSchannelErrorCategory - Continue')
  else
    TestFail('GetSchannelErrorCategory - Continue', 'Wrong category');
    
  // Test 3: Certificate error
  Category := GetSchannelErrorCategory(SEC_E_CERT_EXPIRED);
  if Category = secCertificateError then
    TestPass('GetSchannelErrorCategory - Certificate')
  else
    TestFail('GetSchannelErrorCategory - Certificate', 'Wrong category');
    
  // Test 4: Get error string
  ErrorMsg := GetSchannelErrorString(SEC_E_OK);
  if Pos('Success', ErrorMsg) > 0 then
    TestPass('GetSchannelErrorString - Success')
  else
    TestFail('GetSchannelErrorString - Success', 'Wrong message: ' + ErrorMsg);
    
  // Test 5: Get error string for certificate expired
  ErrorMsg := GetSchannelErrorString(SEC_E_CERT_EXPIRED);
  if Pos('Certificate expired', ErrorMsg) > 0 then
    TestPass('GetSchannelErrorString - Certificate expired')
  else
    TestFail('GetSchannelErrorString - Certificate expired', 'Wrong message: ' + ErrorMsg);
    
  // Test 6: IsHandshakeContinue
  if IsHandshakeContinue(SEC_I_CONTINUE_NEEDED) then
    TestPass('IsHandshakeContinue - True case')
  else
    TestFail('IsHandshakeContinue - True case', 'Should return True');
    
  // Test 7: IsHandshakeContinue (false case)
  if not IsHandshakeContinue(SEC_E_OK) then
    TestPass('IsHandshakeContinue - False case')
  else
    TestFail('IsHandshakeContinue - False case', 'Should return False');
    
  // Test 8: IsIncompleteMessage
  if IsIncompleteMessage(SEC_E_INCOMPLETE_MESSAGE) then
    TestPass('IsIncompleteMessage - True case')
  else
    TestFail('IsIncompleteMessage - True case', 'Should return True');
    
  // Test 9: IsSuccess
  if IsSuccess(SEC_E_OK) then
    TestPass('IsSuccess - True case')
  else
    TestFail('IsSuccess - True case', 'Should return True');
    
  // Test 10: System error message
  ErrorMsg := GetSystemErrorMessage(0); // 0 = ERROR_SUCCESS
  if ErrorMsg <> '' then
    TestPass('GetSystemErrorMessage - Success')
  else
    TestFail('GetSystemErrorMessage - Success', 'Empty message');
end;

// ============================================================================
// 测试协议版本映射
// ============================================================================

procedure TestProtocolVersionMapping;
var
  Versions: TSSLProtocolVersions;
  Flags: DWORD;
  VersionName: string;
begin
  TestSection('Protocol Version Mapping Tests');
  
  // Test 1: TLS 1.2 client flag
  Versions := [sslProtocolTLS12];
  Flags := ProtocolVersionsToSchannelFlags(Versions, False);
  if (Flags and SP_PROT_TLS1_2_CLIENT) <> 0 then
    TestPass('ProtocolVersionsToSchannelFlags - TLS 1.2 Client')
  else
    TestFail('ProtocolVersionsToSchannelFlags - TLS 1.2 Client', 'Flag not set');
    
  // Test 2: TLS 1.2 server flag
  Versions := [sslProtocolTLS12];
  Flags := ProtocolVersionsToSchannelFlags(Versions, True);
  if (Flags and SP_PROT_TLS1_2_SERVER) <> 0 then
    TestPass('ProtocolVersionsToSchannelFlags - TLS 1.2 Server')
  else
    TestFail('ProtocolVersionsToSchannelFlags - TLS 1.2 Server', 'Flag not set');
    
  // Test 3: Multiple versions (TLS 1.2 + TLS 1.3)
  Versions := [sslProtocolTLS12, sslProtocolTLS13];
  Flags := ProtocolVersionsToSchannelFlags(Versions, False);
  if ((Flags and SP_PROT_TLS1_2_CLIENT) <> 0) and 
     ((Flags and SP_PROT_TLS1_3_CLIENT) <> 0) then
    TestPass('ProtocolVersionsToSchannelFlags - Multiple versions')
  else
    TestFail('ProtocolVersionsToSchannelFlags - Multiple versions', 'Flags not set correctly');
    
  // Test 4: Parse flags back to versions
  Flags := SP_PROT_TLS1_2_CLIENT or SP_PROT_TLS1_3_CLIENT;
  Versions := SchannelFlagsToProtocolVersions(Flags, False);
  if (sslProtocolTLS12 in Versions) and (sslProtocolTLS13 in Versions) then
    TestPass('SchannelFlagsToProtocolVersions - Multiple versions')
  else
    TestFail('SchannelFlagsToProtocolVersions - Multiple versions', 'Versions not parsed correctly');
    
  // Test 5: Get protocol version name
  VersionName := GetProtocolVersionName(sslProtocolTLS12);
  if VersionName = 'TLS 1.2' then
    TestPass('GetProtocolVersionName - TLS 1.2')
  else
    TestFail('GetProtocolVersionName - TLS 1.2', 'Wrong name: ' + VersionName);
    
  // Test 6: Get protocol version name for TLS 1.3
  VersionName := GetProtocolVersionName(sslProtocolTLS13);
  if VersionName = 'TLS 1.3' then
    TestPass('GetProtocolVersionName - TLS 1.3')
  else
    TestFail('GetProtocolVersionName - TLS 1.3', 'Wrong name: ' + VersionName);
    
  // Test 7: Check deprecated protocol (SSL 2.0)
  if IsProtocolDeprecated(sslProtocolSSL2) then
    TestPass('IsProtocolDeprecated - SSL 2.0')
  else
    TestFail('IsProtocolDeprecated - SSL 2.0', 'Should be deprecated');
    
  // Test 8: Check non-deprecated protocol (TLS 1.2)
  if not IsProtocolDeprecated(sslProtocolTLS12) then
    TestPass('IsProtocolDeprecated - TLS 1.2')
  else
    TestFail('IsProtocolDeprecated - TLS 1.2', 'Should not be deprecated');
end;

// ============================================================================
// 测试缓冲区管理
// ============================================================================

procedure TestBufferManagement;
var
  Buffer: PSecBuffer;
  BufferDesc: PSecBufferDesc;
  Handle: TSecHandle;
begin
  TestSection('Buffer Management Tests');
  
  // Test 1: Allocate SecBuffer
  try
    Buffer := AllocSecBuffer(1024, SECBUFFER_DATA);
    if (Buffer <> nil) and (Buffer^.cbBuffer = 1024) and 
       (Buffer^.BufferType = SECBUFFER_DATA) then
      TestPass('AllocSecBuffer - Allocation')
    else
      TestFail('AllocSecBuffer - Allocation', 'Invalid buffer');
    FreeSecBuffer(Buffer);
  except
    on E: Exception do
      TestFail('AllocSecBuffer - Allocation', E.Message);
  end;
  
  // Test 2: Allocate empty SecBuffer
  try
    Buffer := AllocSecBuffer(0, SECBUFFER_EMPTY);
    if (Buffer <> nil) and (Buffer^.cbBuffer = 0) and (Buffer^.pvBuffer = nil) then
      TestPass('AllocSecBuffer - Empty buffer')
    else
      TestFail('AllocSecBuffer - Empty buffer', 'Invalid buffer');
    FreeSecBuffer(Buffer);
  except
    on E: Exception do
      TestFail('AllocSecBuffer - Empty buffer', E.Message);
  end;
  
  // Test 3: Allocate SecBufferDesc
  try
    BufferDesc := AllocSecBufferDesc(3);
    if (BufferDesc <> nil) and (BufferDesc^.cBuffers = 3) and 
       (BufferDesc^.ulVersion = SECBUFFER_VERSION) then
    begin
      TestPass('AllocSecBufferDesc - Allocation');
      // 手动释放，因为 FreeSecBufferDesc 会尝试释放未初始化的缓冲区
      FreeMem(BufferDesc^.pBuffers);
      Dispose(BufferDesc);
    end
    else
      TestFail('AllocSecBufferDesc - Allocation', 'Invalid buffer descriptor');
  except
    on E: Exception do
      TestFail('AllocSecBufferDesc - Allocation', E.Message);
  end;
  
  // Test 4: Initialize SecHandle
  InitSecHandle(Handle);
  if (Handle.dwLower = 0) and (Handle.dwUpper = 0) then
    TestPass('InitSecHandle - Initialization')
  else
    TestFail('InitSecHandle - Initialization', 'Handle not initialized');
    
  // Test 5: IsValidSecHandle (invalid)
  if not IsValidSecHandle(Handle) then
    TestPass('IsValidSecHandle - Invalid handle')
  else
    TestFail('IsValidSecHandle - Invalid handle', 'Should be invalid');
    
  // Test 6: IsValidSecHandle (valid)
  Handle.dwLower := 1;
  if IsValidSecHandle(Handle) then
    TestPass('IsValidSecHandle - Valid handle')
  else
    TestFail('IsValidSecHandle - Valid handle', 'Should be valid');
    
  // Test 7: ClearSecHandle
  ClearSecHandle(Handle);
  if (Handle.dwLower = 0) and (Handle.dwUpper = 0) then
    TestPass('ClearSecHandle - Clear')
  else
    TestFail('ClearSecHandle - Clear', 'Handle not cleared');
end;

// ============================================================================
// 测试字符串转换
// ============================================================================

procedure TestStringConversion;
var
  TestStr: string;
  PWide: PWideChar;
  WideStr: WideString;
begin
  TestSection('String Conversion Tests');
  
  // Test 1: StringToPWideChar
  try
    TestStr := 'Hello World';
    PWide := StringToPWideChar(TestStr);
    if PWide <> nil then
      TestPass('StringToPWideChar - Allocation')
    else
      TestFail('StringToPWideChar - Allocation', 'Returned nil');
    FreePWideCharString(PWide);
  except
    on E: Exception do
      TestFail('StringToPWideChar - Allocation', E.Message);
  end;
  
  // Test 2: StringToPWideChar with empty string
  try
    PWide := StringToPWideChar('');
    if PWide = nil then
      TestPass('StringToPWideChar - Empty string')
    else
    begin
      TestFail('StringToPWideChar - Empty string', 'Should return nil');
      FreePWideCharString(PWide);
    end;
  except
    on E: Exception do
      TestFail('StringToPWideChar - Empty string', E.Message);
  end;
  
  // Test 3: AnsiToWide
  try
    WideStr := AnsiToWide('Test');
    if Length(WideStr) > 0 then
      TestPass('AnsiToWide - Conversion')
    else
      TestFail('AnsiToWide - Conversion', 'Empty result');
  except
    on E: Exception do
      TestFail('AnsiToWide - Conversion', E.Message);
  end;
  
  // Test 4: WideToUTF8
  try
    TestStr := WideToUTF8(WideString('Test'));
    if Length(TestStr) > 0 then
      TestPass('WideToUTF8 - Conversion')
    else
      TestFail('WideToUTF8 - Conversion', 'Empty result');
  except
    on E: Exception do
      TestFail('WideToUTF8 - Conversion', E.Message);
  end;
end;

// ============================================================================
// 主程序
// ============================================================================

begin
  WriteLn('WinSSL Utils Function Tests');
  WriteLn('============================');
  
  try
    TestErrorHandling;
    TestProtocolVersionMapping;
    TestBufferManagement;
    TestStringConversion;
    
    WriteLn;
    WriteLn('============================');
    WriteLn('Test Results:');
    WriteLn('  Passed: ', TestsPassed);
    WriteLn('  Failed: ', TestsFailed);
    WriteLn('  Total:  ', TestsPassed + TestsFailed);
    
    if TestsFailed = 0 then
    begin
      WriteLn;
      WriteLn('✓ All tests passed!');
      ExitCode := 0;
    end
    else
    begin
      WriteLn;
      WriteLn('✗ Some tests failed!');
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
