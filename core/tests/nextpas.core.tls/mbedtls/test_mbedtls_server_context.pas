program test_mbedtls_server_context;

{$mode ObjFPC}{$H+}

{
  MbedTLS Server-Side Context Test

  Week 2 Task 2.1: 服务端 Context 创建和证书加载测试

  测试场景:
  1. 服务端 Context 创建 (sslCtxServer)
  2. 加载服务端证书和私钥
  3. 设置服务端验证模式
  4. 验证服务端配置正确性
  5. 错误场景: 缺少证书/私钥、无效文件等
}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib;

type
  TTestResult = record
    Name: string;
    Success: Boolean;
    Message: string;
  end;

var
  GResults: array of TTestResult;
  GLib: ISSLLibrary;

const
  TEST_CERT_PATH = 'tests/certs/server-cert.pem';
  TEST_KEY_PATH = 'tests/certs/server-key.pem';

procedure AddResult(const AName: string; ASuccess: Boolean; const AMessage: string = '');
begin
  SetLength(GResults, Length(GResults) + 1);
  GResults[High(GResults)].Name := AName;
  GResults[High(GResults)].Success := ASuccess;
  GResults[High(GResults)].Message := AMessage;
end;

{ Test 1: 服务端 Context 创建 }
procedure TestServerContextCreation;
var
  LCtx: ISSLContext;
begin
  WriteLn;
  WriteLn('Test 1: Server Context Creation');
  WriteLn('----------------------------------------------');

  try
    WriteLn('Creating server context with sslCtxServer...');
    LCtx := GLib.CreateContext(sslCtxServer);

    if LCtx <> nil then
    begin
      WriteLn('✅ Server context created successfully');
      AddResult('Server Context Creation', True, 'Context created');
    end
    else
    begin
      WriteLn('❌ Failed to create server context');
      AddResult('Server Context Creation', False, 'Context is nil');
    end;

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Server Context Creation', False, E.Message);
    end;
  end;
end;

{ Test 2: 加载服务端证书 }
procedure TestLoadServerCertificate;
var
  LCtx: ISSLContext;
begin
  WriteLn;
  WriteLn('Test 2: Load Server Certificate');
  WriteLn('----------------------------------------------');

  try
    LCtx := GLib.CreateContext(sslCtxServer);

    WriteLn('Loading certificate from: ', TEST_CERT_PATH);
    LCtx.LoadCertificate(TEST_CERT_PATH);

    WriteLn('✅ Certificate loaded successfully');
    AddResult('Load Server Certificate', True, 'Certificate loaded');

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Load Server Certificate', False, E.Message);
    end;
  end;
end;

{ Test 3: 加载服务端私钥 }
procedure TestLoadServerPrivateKey;
var
  LCtx: ISSLContext;
begin
  WriteLn;
  WriteLn('Test 3: Load Server Private Key');
  WriteLn('----------------------------------------------');

  try
    LCtx := GLib.CreateContext(sslCtxServer);

    WriteLn('Loading certificate from: ', TEST_CERT_PATH);
    LCtx.LoadCertificate(TEST_CERT_PATH);

    WriteLn('Loading private key from: ', TEST_KEY_PATH);
    LCtx.LoadPrivateKey(TEST_KEY_PATH);

    WriteLn('✅ Certificate and private key loaded successfully');
    AddResult('Load Server Private Key', True, 'Both loaded');

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Load Server Private Key', False, E.Message);
    end;
  end;
end;

{ Test 4: 设置服务端验证模式 }
procedure TestServerVerifyModes;
var
  LCtx: ISSLContext;
  LMode: TSSLVerifyModes;
begin
  WriteLn;
  WriteLn('Test 4: Server Verify Modes');
  WriteLn('----------------------------------------------');

  try
    LCtx := GLib.CreateContext(sslCtxServer);
    LCtx.LoadCertificate(TEST_CERT_PATH);
    LCtx.LoadPrivateKey(TEST_KEY_PATH);

    // 子测试 4.1: 不验证客户端证书
    WriteLn;
    WriteLn('4.1: No client verification');
    LCtx.SetVerifyMode([]);
    LMode := LCtx.GetVerifyMode;
    if LMode = [] then
    begin
      WriteLn('✅ No verification mode set');
      AddResult('Server Verify - None', True, 'Mode = []');
    end
    else
    begin
      WriteLn('⚠️  Unexpected mode (not empty)');
      AddResult('Server Verify - None', False, 'Mode not empty');
    end;

    // 子测试 4.2: 请求客户端证书但不强制
    WriteLn;
    WriteLn('4.2: Request client certificate (optional)');
    LCtx.SetVerifyMode([sslVerifyPeer]);
    LMode := LCtx.GetVerifyMode;
    if sslVerifyPeer in LMode then
    begin
      WriteLn('✅ sslVerifyPeer mode set');
      AddResult('Server Verify - Optional', True, 'sslVerifyPeer enabled');
    end
    else
    begin
      WriteLn('❌ sslVerifyPeer not in mode');
      AddResult('Server Verify - Optional', False, 'Flag not set');
    end;

    // 子测试 4.3: 强制要求客户端证书 (mTLS)
    WriteLn;
    WriteLn('4.3: Require client certificate (mTLS)');
    LCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);
    LMode := LCtx.GetVerifyMode;
    if (sslVerifyPeer in LMode) and (sslVerifyFailIfNoPeerCert in LMode) then
    begin
      WriteLn('✅ mTLS mode set (both flags)');
      AddResult('Server Verify - mTLS', True, 'Both flags enabled');
    end
    else
    begin
      WriteLn('❌ mTLS flags incomplete');
      AddResult('Server Verify - mTLS', False, 'Flags not set correctly');
    end;

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Server Verify Modes', False, E.Message);
    end;
  end;
end;

{ Test 5: 加载 CA 证书用于客户端验证 }
procedure TestLoadCAForClientVerification;
var
  LCtx: ISSLContext;
begin
  WriteLn;
  WriteLn('Test 5: Load CA for Client Verification');
  WriteLn('----------------------------------------------');

  try
    LCtx := GLib.CreateContext(sslCtxServer);
    LCtx.LoadCertificate(TEST_CERT_PATH);
    LCtx.LoadPrivateKey(TEST_KEY_PATH);

    WriteLn('Loading CA bundle for client verification...');
    LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');

    WriteLn('Setting mTLS mode...');
    LCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);

    WriteLn('✅ CA loaded, ready for mTLS');
    AddResult('Load CA for Client Verify', True, 'CA and mTLS configured');

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Load CA for Client Verify', False, E.Message);
    end;
  end;
end;

{ Test 6: 错误场景 - 缺少证书 }
procedure TestMissingCertificate;
var
  LCtx: ISSLContext;
  LFailed: Boolean;
begin
  WriteLn;
  WriteLn('Test 6: Error - Missing Certificate');
  WriteLn('----------------------------------------------');

  LFailed := False;
  try
    LCtx := GLib.CreateContext(sslCtxServer);

    WriteLn('Attempting to load non-existent certificate...');
    LCtx.LoadCertificate('nonexistent.pem');

    WriteLn('⚠️  No exception raised (unexpected)');
    AddResult('Error - Missing Cert', False, 'No exception');

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('✅ Exception raised: ', E.Message);
      AddResult('Error - Missing Cert', True, 'Exception raised');
      LFailed := True;
    end;
  end;

  if not LFailed then
  begin
    WriteLn('ℹ️  Implementation may not validate file existence immediately');
  end;
end;

{ Test 7: 错误场景 - 私钥不匹配 }
procedure TestKeyMismatch;
var
  LCtx: ISSLContext;
  LFailed: Boolean;
begin
  WriteLn;
  WriteLn('Test 7: Error - Key/Certificate Mismatch');
  WriteLn('----------------------------------------------');

  LFailed := False;
  try
    LCtx := GLib.CreateContext(sslCtxServer);

    WriteLn('Loading certificate...');
    LCtx.LoadCertificate(TEST_CERT_PATH);

    WriteLn('Attempting to load mismatched key...');
    // 使用系统 CA 证书作为"错误"的密钥文件
    LCtx.LoadPrivateKey('/etc/ssl/certs/ca-certificates.crt');

    WriteLn('⚠️  No exception raised');
    AddResult('Error - Key Mismatch', False, 'No exception');

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('✅ Exception raised: ', E.Message);
      AddResult('Error - Key Mismatch', True, 'Mismatch detected');
      LFailed := True;
    end;
  end;

  if not LFailed then
  begin
    WriteLn('ℹ️  Key/cert validation may occur during handshake');
  end;
end;

{ Test 8: 多次配置覆盖 }
procedure TestMultipleConfigurations;
var
  LCtx: ISSLContext;
begin
  WriteLn;
  WriteLn('Test 8: Multiple Configurations (Overwrite)');
  WriteLn('----------------------------------------------');

  try
    LCtx := GLib.CreateContext(sslCtxServer);

    WriteLn('First configuration...');
    LCtx.LoadCertificate(TEST_CERT_PATH);
    LCtx.LoadPrivateKey(TEST_KEY_PATH);
    LCtx.SetVerifyMode([]);

    WriteLn('Second configuration (overwrite)...');
    LCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);
    LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');

    if (sslVerifyPeer in LCtx.GetVerifyMode) and
       (sslVerifyFailIfNoPeerCert in LCtx.GetVerifyMode) then
    begin
      WriteLn('✅ Configuration overwritten successfully');
      AddResult('Multiple Configurations', True, 'Overwrite works');
    end
    else
    begin
      WriteLn('❌ Configuration not updated');
      AddResult('Multiple Configurations', False, 'Overwrite failed');
    end;

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Multiple Configurations', False, E.Message);
    end;
  end;
end;

procedure PrintSummary;
var
  I, LPassed, LFailed: Integer;
begin
  WriteLn;
  WriteLn('================================================================================');
  WriteLn('TEST SUMMARY');
  WriteLn('================================================================================');
  WriteLn;

  LPassed := 0;
  LFailed := 0;

  for I := 0 to High(GResults) do
  begin
    if GResults[I].Success then
    begin
      Write('✅ PASS: ');
      Inc(LPassed);
    end
    else
    begin
      Write('❌ FAIL: ');
      Inc(LFailed);
    end;

    WriteLn(GResults[I].Name);
    if GResults[I].Message <> '' then
      WriteLn('         ', GResults[I].Message);
  end;

  WriteLn;
  WriteLn('Total: ', Length(GResults), ' tests');
  WriteLn('Passed: ', LPassed);
  WriteLn('Failed: ', LFailed);
  WriteLn;

  if LFailed = 0 then
    WriteLn('🎉 All tests passed!')
  else
    WriteLn('⚠️  Some tests failed');

  WriteLn('================================================================================');
end;

begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Server Context Test');
  WriteLn('================================================================================');

  try
    // Initialize MbedTLS
    WriteLn;
    WriteLn('Initializing MbedTLS...');
    GLib := TMbedTLSLibrary.Create;
    if not GLib.Initialize then
    begin
      WriteLn('❌ Failed to initialize MbedTLS');
      Halt(1);
    end;
    WriteLn('✅ MbedTLS ', GLib.GetVersionString);

    // Check certificate files exist
    WriteLn;
    WriteLn('Checking test certificate files...');
    if not FileExists(TEST_CERT_PATH) then
    begin
      WriteLn('❌ Certificate not found: ', TEST_CERT_PATH);
      Halt(1);
    end;
    if not FileExists(TEST_KEY_PATH) then
    begin
      WriteLn('❌ Private key not found: ', TEST_KEY_PATH);
      Halt(1);
    end;
    WriteLn('✅ Certificate files found');

    // Run tests
    TestServerContextCreation;
    TestLoadServerCertificate;
    TestLoadServerPrivateKey;
    TestServerVerifyModes;
    TestLoadCAForClientVerification;
    TestMissingCertificate;
    TestKeyMismatch;
    TestMultipleConfigurations;

    // Print summary
    PrintSummary;

    // Cleanup
    GLib.Finalize;
    GLib := nil;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ Fatal error: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
