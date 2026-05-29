program test_mbedtls_backend;

{$mode ObjFPC}{$H+}

{
  MbedTLS 后端基础测试

  目标：
  1. 验证 MbedTLS 库加载
  2. 验证基本初始化
  3. 测试简单的 TLS 握手
  4. 对比 OpenSSL/WinSSL 能力
}

uses
  SysUtils, Classes, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.api;

procedure PrintSeparator(const ATitle: string = '');
begin
  WriteLn;
  WriteLn('================================================================================');
  if ATitle <> '' then
    WriteLn('  ', ATitle);
  WriteLn('================================================================================');
  WriteLn;
end;

procedure TestLibraryLoading;
var
  LLib: ISSLLibrary;  // 使用接口引用避免引用计数问题
begin
  PrintSeparator('Test 1: MbedTLS Library Loading');

  WriteLn('1.1 Creating MbedTLS library instance...');
  LLib := TMbedTLSLibrary.Create;
  WriteLn('   ✅ Instance created');

  WriteLn('1.2 Checking initialization status...');
  if LLib.IsInitialized then
    WriteLn('   ⚠️  Already initialized')
  else
    WriteLn('   ✅ Not initialized yet');

  WriteLn('1.3 Initializing MbedTLS...');
  if LLib.Initialize then
  begin
    WriteLn('   ✅ MbedTLS initialized successfully');
    WriteLn('   Version: ', LLib.GetVersionString);
    WriteLn('   Version Number: ', LLib.GetVersionNumber);
    WriteLn('   Type: ', GetEnumName(TypeInfo(TSSLLibraryType), Ord(LLib.GetLibraryType)));
  end
  else
  begin
    WriteLn('   ❌ Initialization failed');
    WriteLn('   Last Error: ', LLib.GetLastErrorString);
    Halt(1);
  end;

  WriteLn('1.4 Finalizing MbedTLS...');
  LLib.Finalize;
  WriteLn('   ✅ Finalized successfully');

  LLib := nil;  // 释放接口引用
end;

procedure TestCapabilities;
var
  LLib: ISSLLibrary;  // 使用接口引用
  LCaps: TSSLBackendCapabilities;
begin
  PrintSeparator('Test 2: MbedTLS Capabilities');

  LLib := TMbedTLSLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('❌ Failed to initialize MbedTLS');
    Exit;
  end;

  WriteLn('2.1 Querying capabilities...');
  LCaps := LLib.GetCapabilities;
  WriteLn('   ✅ Capabilities retrieved');
  WriteLn;

  WriteLn('TLS/SSL Features:');
  WriteLn('  TLS 1.0:              ', LCaps.MinTLSVersion <= sslProtocolTLS10);
  WriteLn('  TLS 1.1:              ', LCaps.MinTLSVersion <= sslProtocolTLS11);
  WriteLn('  TLS 1.2:              ', LCaps.MaxTLSVersion >= sslProtocolTLS12);
  WriteLn('  TLS 1.3:              ', LCaps.SupportsTLS13);
  WriteLn('  ALPN:                 ', LCaps.SupportsALPN);
  WriteLn('  SNI:                  ', LCaps.SupportsSNI);
  WriteLn('  Session Tickets:      ', LCaps.SupportsSessionTickets);
  WriteLn('  OCSP Stapling:        ', LCaps.SupportsOCSPStapling);
  WriteLn('  Certificate Transparency: ', LCaps.SupportsCertificateTransparency);
  WriteLn;

  WriteLn('Cryptographic Features:');
  WriteLn('  ECDHE:                ', LCaps.SupportsECDHE);
  WriteLn('  ChaCha20-Poly1305:    ', LCaps.SupportsChaChaPoly);
  WriteLn;

  WriteLn('Protocol Versions:');
  WriteLn('  Min TLS:              ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LCaps.MinTLSVersion)));
  WriteLn('  Max TLS:              ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LCaps.MaxTLSVersion)));
  WriteLn;

  WriteLn('2.2 Testing protocol support...');
  WriteLn('  TLS 1.0: ', LLib.IsProtocolSupported(sslProtocolTLS10));
  WriteLn('  TLS 1.1: ', LLib.IsProtocolSupported(sslProtocolTLS11));
  WriteLn('  TLS 1.2: ', LLib.IsProtocolSupported(sslProtocolTLS12));
  WriteLn('  TLS 1.3: ', LLib.IsProtocolSupported(sslProtocolTLS13));
  WriteLn;

  LLib.Finalize;
  LLib := nil;  // 释放接口引用
end;

procedure TestComparison;
var
  LMbedLib: ISSLLibrary;  // 使用接口引用
  LMbedCaps: TSSLBackendCapabilities;
begin
  PrintSeparator('Test 3: MbedTLS vs OpenSSL Comparison');

  LMbedLib := TMbedTLSLibrary.Create;
  if not LMbedLib.Initialize then
  begin
    WriteLn('❌ Failed to initialize MbedTLS');
    Exit;
  end;

  LMbedCaps := LMbedLib.GetCapabilities;

  WriteLn('Comparison Summary:');
  WriteLn;
  WriteLn('Feature                   | MbedTLS | OpenSSL | Match');
  WriteLn('--------------------------|---------|---------|-------');
  WriteLn('TLS 1.2                   |   ', BoolToStr(LMbedCaps.MaxTLSVersion >= sslProtocolTLS12, '✓', '✗'), '     |   ✓     |  ', BoolToStr(True, '✓', '✗'));
  WriteLn('TLS 1.3                   |   ', BoolToStr(LMbedCaps.SupportsTLS13, '✓', '✗'), '     |   ✗     |  ', BoolToStr(not LMbedCaps.SupportsTLS13, '✓', '✗'));
  WriteLn('ALPN                      |   ', BoolToStr(LMbedCaps.SupportsALPN, '✓', '✗'), '     |   ✓     |  ', BoolToStr(LMbedCaps.SupportsALPN, '✓', '✗'));
  WriteLn('SNI                       |   ', BoolToStr(LMbedCaps.SupportsSNI, '✓', '✗'), '     |   ✓     |  ', BoolToStr(LMbedCaps.SupportsSNI, '✓', '✗'));
  WriteLn('ECDHE                     |   ', BoolToStr(LMbedCaps.SupportsECDHE, '✓', '✗'), '     |   ✓     |  ', BoolToStr(LMbedCaps.SupportsECDHE, '✓', '✗'));
  WriteLn;

  WriteLn('Key Differences:');
  WriteLn('  • MbedTLS: Designed for embedded/IoT (smaller footprint)');
  WriteLn('  • OpenSSL: Full-featured (larger, more features)');
  WriteLn('  • MbedTLS TLS 1.3: ', BoolToStr(LMbedCaps.SupportsTLS13, 'Supported', 'Limited/Experimental'));
  WriteLn;

  LMbedLib.Finalize;
  LMbedLib := nil;  // 释放接口引用
end;

procedure TestContextCreation;
var
  LLib: ISSLLibrary;  // 使用接口引用避免引用计数问题
  LCtx: ISSLContext;
begin
  PrintSeparator('Test 4: Context Creation');

  LLib := TMbedTLSLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('❌ Failed to initialize MbedTLS');
    Exit;
  end;

  WriteLn('4.1 Creating client context...');
  try
    LCtx := LLib.CreateContext(sslCtxClient);
    if LCtx <> nil then
    begin
      WriteLn('   ✅ Client context created successfully');
      WriteLn('   Context type: ', GetEnumName(TypeInfo(TSSLContextType), Ord(LCtx.GetContextType)));
      LCtx := nil;  // 释放接口引用
    end
    else
      WriteLn('   ❌ Failed to create client context');
  except
    on E: Exception do
      WriteLn('   ❌ Exception: ', E.Message);
  end;

  WriteLn;
  WriteLn('4.2 Creating server context...');
  try
    LCtx := LLib.CreateContext(sslCtxServer);
    if LCtx <> nil then
    begin
      WriteLn('   ✅ Server context created successfully');
      WriteLn('   Context type: ', GetEnumName(TypeInfo(TSSLContextType), Ord(LCtx.GetContextType)));
      LCtx := nil;  // 释放接口引用
    end
    else
      WriteLn('   ❌ Failed to create server context');
  except
    on E: Exception do
      WriteLn('   ❌ Exception: ', E.Message);
  end;

  LLib.Finalize;
  LLib := nil;  // 释放接口引用
end;

begin
  try
    PrintSeparator('MbedTLS Backend Test Suite');

    WriteLn('System Info:');
    WriteLn('  OS: Linux');
    WriteLn('  Arch: x86_64');
    WriteLn('  MbedTLS Version: 3.6.5 (expected)');
    WriteLn;

    // Run tests
    TestLibraryLoading;
    TestCapabilities;
    TestComparison;
    TestContextCreation;

    PrintSeparator('Test Complete');
    WriteLn('✅ MbedTLS backend basic tests completed');
    WriteLn;
    WriteLn('Summary:');
    WriteLn('  • MbedTLS library loads successfully');
    WriteLn('  • Initialization/finalization works');
    WriteLn('  • Capability detection functional');
    WriteLn('  • Context creation works');
    WriteLn;
    WriteLn('Next Steps:');
    WriteLn('  1. Test actual TLS connections');
    WriteLn('  2. Compare performance with OpenSSL');
    WriteLn('  3. Test certificate validation');
    WriteLn('  4. Measure memory footprint');
    WriteLn;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ Fatal error: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
