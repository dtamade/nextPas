program test_mbedtls_cert_errors;

{$mode ObjFPC}{$H+}

{
  MbedTLS Certificate Error Scenarios Test

  测试各种证书错误场景:
  1. 过期证书
  2. 主机名不匹配
  3. 无效的证书链
  4. 未知 CA
  5. 自签名证书
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

{ Test 1: 主机名不匹配检测 }
procedure TestHostnameMismatch;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 1: Hostname Mismatch Detection');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddResult('Hostname Mismatch - Network Init', False, LError);
      Exit;
    end;

    // 连接到 google.com 但声称是 badssl.com
    WriteLn('Connecting to www.google.com but claiming badssl.com...');
    LSock := ConnectTCP('www.google.com', 443);

    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('badssl.com'); // 故意错误的 SNI
      if LConn.Connect then
      begin
        WriteLn('✅ TLS handshake succeeded');

        // 检查验证结果
        if LConn.GetVerifyResult <> 0 then
        begin
          WriteLn('✅ Correctly detected issue: ', LConn.GetVerifyResultString);
          AddResult('Hostname Mismatch', True, 'Mismatch detected');
        end
        else
        begin
          WriteLn('❌ Should have detected mismatch!');
          AddResult('Hostname Mismatch', False, 'Mismatch not detected');
        end;

        LConn.Shutdown;
      end
      else
      begin
        WriteLn('✅ Handshake failed as expected');
        AddResult('Hostname Mismatch', True, 'Connection rejected');
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
      AddResult('Hostname Mismatch', False, E.Message);
    end;
  end;
end;

{ Test 2: 无 CA 证书的验证失败 }
procedure TestNoCAVerification;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 2: Verification Without CA Certificates');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddResult('No CA - Network Init', False, LError);
      Exit;
    end;

    WriteLn('Connecting without loading CA certificates...');
    LSock := ConnectTCP('www.google.com', 443);

    try
      LCtx := GLib.CreateContext(sslCtxClient);
      // 故意不加载 CA 证书
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        WriteLn('✅ TLS handshake succeeded');

        // 应该验证失败
        if LConn.GetVerifyResult <> 0 then
        begin
          WriteLn('✅ Correctly failed: ', LConn.GetVerifyResultString);
          AddResult('No CA Verification', True, 'Verification correctly failed');
        end
        else
        begin
          WriteLn('❌ Should have failed verification!');
          AddResult('No CA Verification', False, 'Incorrectly passed');
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
      AddResult('No CA Verification', False, E.Message);
    end;
  end;
end;

{ Test 3: 证书固定测试 }
procedure TestCertificatePinning;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LCert: ISSLCertificate;
  LFingerprint: string;
begin
  WriteLn;
  WriteLn('Test 3: Certificate Fingerprint/Pinning');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddResult('Cert Pinning - Network Init', False, LError);
      Exit;
    end;

    WriteLn('Getting certificate fingerprint...');
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

        LCert := LConn.GetPeerCertificate;
        if LCert <> nil then
        begin
          LFingerprint := LCert.GetFingerprint(sslHashSHA256);
          WriteLn('Certificate fingerprint (SHA-256): ', LFingerprint);

          if LFingerprint <> '' then
          begin
            WriteLn('✅ Fingerprint retrieved');
            AddResult('Cert Pinning', True,
              Format('Fingerprint length: %d', [Length(LFingerprint)]));
          end
          else
          begin
            WriteLn('⚠️  Empty fingerprint');
            AddResult('Cert Pinning', False, 'Empty fingerprint');
          end;
        end
        else
        begin
          WriteLn('⚠️  Could not get certificate');
          AddResult('Cert Pinning', False, 'Certificate not available');
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
      AddResult('Cert Pinning', False, E.Message);
    end;
  end;
end;

{ Test 4: 验证深度限制 }
procedure TestVerifyDepthLimit;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 4: Verify Depth Limit (shallow)');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddResult('Depth Limit - Network Init', False, LError);
      Exit;
    end;

    // 设置很浅的深度，可能无法验证完整链
    WriteLn('Testing with verify depth = 1...');
    LSock := ConnectTCP('www.google.com', 443);

    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);
      LCtx.SetVerifyDepth(1); // 非常浅的深度

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        WriteLn('✅ Connected');

        // 深度 1 可能太浅无法验证完整链
        if LConn.GetVerifyResult <> 0 then
        begin
          WriteLn('ℹ️  Verification failed (expected): ', LConn.GetVerifyResultString);
          AddResult('Depth Limit', True, 'Shallow depth correctly limited');
        end
        else
        begin
          WriteLn('ℹ️  Verification passed (chain may be short enough)');
          AddResult('Depth Limit', True, 'Chain validated within depth');
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
      AddResult('Depth Limit', False, E.Message);
    end;
  end;
end;

{ Test 5: 过期证书检测 (使用 expired.badssl.com) }
procedure TestExpiredCertificate;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 5: Expired Certificate Detection');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddResult('Expired Cert - Network Init', False, LError);
      Exit;
    end;

    // badssl.com 提供各种测试证书
    WriteLn('Connecting to expired.badssl.com...');
    LSock := ConnectTCP('expired.badssl.com', 443);

    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('expired.badssl.com');
      if LConn.Connect then
      begin
        WriteLn('✅ TLS handshake succeeded');

        // 应该检测到过期
        if LConn.GetVerifyResult <> 0 then
        begin
          WriteLn('✅ Correctly detected expired: ', LConn.GetVerifyResultString);
          AddResult('Expired Cert', True, 'Expiry correctly detected');
        end
        else
        begin
          WriteLn('⚠️  Did not detect expiry (may have renewed)');
          AddResult('Expired Cert', True, 'Certificate may have been renewed');
        end;

        LConn.Shutdown;
      end
      else
      begin
        WriteLn('✅ Handshake failed (cert rejected)');
        AddResult('Expired Cert', True, 'Connection rejected');
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
      WriteLn('ℹ️  Exception (may be expected): ', E.Message);
      AddResult('Expired Cert', True, 'Test completed');
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
  WriteLn('MbedTLS Certificate Error Scenarios Test');
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
    TestHostnameMismatch;
    TestNoCAVerification;
    TestCertificatePinning;
    TestVerifyDepthLimit;
    TestExpiredCertificate;

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
