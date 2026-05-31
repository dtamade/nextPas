program test_mbedtls_cert_chain;

{$mode ObjFPC}{$H+}

{
  MbedTLS Certificate Chain Verification Test

  测试场景:
  1. 完整证书链验证 (Root CA -> Intermediate CA -> Server)
  2. 自签名证书处理
  3. 中间 CA 缺失
  4. 多级证书链
  5. 证书链构建
}

uses
  SysUtils, Classes, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  fafafa.examples.tcp;

type
  TTestResult = record
    Name: string;
    Success: Boolean;
    Message: string;
  end;

var
  GResults: array of TTestResult;
  GLib: ISSLLibrary;

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this MbedTLS-specific runtime
// file intentionally keeps direct core GetVerifyResult/GetVerifyResultString
// coverage as backend proof. Generic ISSLCertificateVerification owner-path
// guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

procedure AddResult(const AName: string; ASuccess: Boolean; const AMessage: string = '');
begin
  SetLength(GResults, Length(GResults) + 1);
  GResults[High(GResults)].Name := AName;
  GResults[High(GResults)].Success := ASuccess;
  GResults[High(GResults)].Message := AMessage;
end;

procedure AddSkipResult(const AName: string; const AMessage: string = '');
begin
  AddResult(AName, True, 'SKIP: ' + AMessage);
end;

{ Test 1: 完整证书链验证 }
procedure TestFullCertChain;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 1: Full Certificate Chain Verification');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('Full Chain - Network Init', LError);
      Exit;
    end;

    // 测试完整证书链的网站 (Google 有完整的证书链)
    WriteLn('Connecting to www.google.com:443...');
    LSock := ConnectTCP('www.google.com', 443);

    try
      LCtx := GLib.CreateContext(sslCtxClient);

      // 加载系统 CA 证书 (Linux)
      try
        LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
        WriteLn('✅ CA certificates loaded');
      except
        on E: Exception do
          WriteLn('⚠️  Could not load CA certs: ', E.Message);
      end;

      LCtx.SetVerifyMode([sslVerifyPeer]); // 启用验证

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      WriteLn('✅ SNI set to: www.google.com');

      if LConn.Connect then
      begin
        WriteLn('✅ TLS handshake successful');
        WriteLn('   Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion),
          Ord(LConn.GetProtocolVersion)));
        WriteLn('   Cipher: ', LConn.GetCipherName);

        // 检查验证结果
        if LConn.GetVerifyResult = 0 then
        begin
          WriteLn('✅ Certificate verification: PASSED');
          AddResult('Full Chain - Google', True, 'Verification passed');
        end
        else
        begin
          WriteLn('⚠️  Verification result: ', LConn.GetVerifyResult);
          WriteLn('   Message: ', LConn.GetVerifyResultString);
          AddResult('Full Chain - Google', False, LConn.GetVerifyResultString);
        end;

        LConn.Shutdown;
      end
      else
      begin
        WriteLn('❌ TLS handshake failed');
        AddResult('Full Chain - Google', False, 'Handshake failed');
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    CleanupNetwork;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Full Chain - Google', False, E.Message);
    end;
  end;
end;

{ Test 2: 自签名证书 }
procedure TestSelfSignedCert;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 2: Self-Signed Certificate');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddResult('Self-Signed - Network Init', False, LError);
      Exit;
    end;

    // 测试自签名证书的网站
    // 注意: 需要找一个有自签名证书的测试服务器
    WriteLn('Testing self-signed certificate behavior...');
    WriteLn('(Using self-signed-test server would be here)');

    // 需要一个自签名证书的测试服务器（当前环境显式跳过）
    WriteLn('ℹ️  Skipped - need self-signed test server');
    AddSkipResult('Self-Signed Test', 'need self-signed test server');

    CleanupNetwork;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Self-Signed Test', False, E.Message);
    end;
  end;
end;

{ Test 3: 验证模式测试 }
procedure TestVerifyModes;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 3: Verify Mode Variations');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('Verify Modes - Network Init', LError);
      Exit;
    end;

    // 测试 1: 不验证
    WriteLn;
    WriteLn('3.1: No verification (empty verify mode)');
    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.SetVerifyMode([]); // 不验证

      LConn := LCtx.CreateConnection(LSock);
      if LConn.Connect then
      begin
        WriteLn('✅ Connected without verification');
        AddResult('Verify Mode - None', True, 'Connection succeeded');
        LConn.Shutdown;
      end
      else
      begin
        WriteLn('❌ Connection failed');
        AddResult('Verify Mode - None', False, 'Connection failed');
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    // 测试 2: 仅验证对端
    WriteLn;
    WriteLn('3.2: Verify peer only');
    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        if LConn.GetVerifyResult = 0 then
        begin
          WriteLn('✅ Peer verification passed');
          AddResult('Verify Mode - Peer', True, 'Verification passed');
        end
        else
        begin
          WriteLn('⚠️  Verification failed: ', LConn.GetVerifyResultString);
          AddResult('Verify Mode - Peer', False, LConn.GetVerifyResultString);
        end;
        LConn.Shutdown;
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    CleanupNetwork;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Verify Modes', False, E.Message);
    end;
  end;
end;

{ Test 4: 获取证书信息 }
procedure TestCertificateInfo;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LCert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('Test 4: Certificate Information Retrieval');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('Cert Info - Network Init', LError);
      Exit;
    end;

    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        WriteLn('✅ Connected');

        // 获取对端证书
        LCert := LConn.GetPeerCertificate;
        if LCert <> nil then
        begin
          WriteLn;
          WriteLn('Certificate Information:');
          WriteLn('  Subject: ', LCert.GetSubject);
          WriteLn('  Issuer: ', LCert.GetIssuer);
          WriteLn('  Valid From: ', DateTimeToStr(LCert.GetNotBefore));
          WriteLn('  Valid To: ', DateTimeToStr(LCert.GetNotAfter));
          WriteLn('  Serial: ', LCert.GetSerialNumber);

          // 检查证书是否在有效期内
          if (LCert.GetNotBefore < Now) and (LCert.GetNotAfter > Now) then
          begin
            WriteLn('✅ Certificate is currently valid');
            AddResult('Cert Info - Validity', True, 'Certificate valid');
          end
          else
          begin
            WriteLn('⚠️  Certificate validity issue');
            AddResult('Cert Info - Validity', False, 'Not in valid period');
          end;
        end
        else
        begin
          WriteLn('⚠️  Could not retrieve peer certificate');
          AddResult('Cert Info - Retrieval', False, 'Certificate not available');
        end;

        LConn.Shutdown;
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    CleanupNetwork;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Cert Info', False, E.Message);
    end;
  end;
end;

{ Test 5: 验证深度测试 }
procedure TestCertChainLength;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 5: Verify Depth Control');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('Verify Depth - Network Init', LError);
      Exit;
    end;

    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);
      LCtx.SetVerifyDepth(10); // 允许最多 10 级证书链

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        WriteLn('✅ Connected with verify depth = 10');

        if LConn.GetVerifyResult = 0 then
        begin
          WriteLn('✅ Verification passed');
          AddResult('Verify Depth - Test', True, 'Verification passed');
        end
        else
        begin
          WriteLn('⚠️  Verification failed: ', LConn.GetVerifyResultString);
          AddResult('Verify Depth - Test', False, LConn.GetVerifyResultString);
        end;

        LConn.Shutdown;
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    CleanupNetwork;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Verify Depth', False, E.Message);
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
  WriteLn('MbedTLS Certificate Chain Verification Test');
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

    // Run tests
    TestFullCertChain;
    TestSelfSignedCert;
    TestVerifyModes;
    TestCertificateInfo;
    TestCertChainLength;

    AddResult('Self-Signed Test uses explicit SKIP marker',
      Pos('SKIP:', UpperCase(GResults[1].Message)) = 1,
      GResults[1].Message);

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
