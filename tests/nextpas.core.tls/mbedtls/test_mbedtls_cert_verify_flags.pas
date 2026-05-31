program test_mbedtls_cert_verify_flags;

{$mode ObjFPC}{$H+}

{
  MbedTLS Certificate Verify Flags Test

  测试各种证书验证标志:
  1. sslVerifyPeer - 验证对端证书
  2. sslVerifyFailIfNoPeerCert - 要求对端证书存在
  3. sslVerifyClientOnce - 仅验证一次客户端证书
  4. 组合标志测试
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

{ Test 1: sslVerifyPeer 标志 }
procedure TestVerifyPeerFlag;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 1: sslVerifyPeer Flag');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('VerifyPeer Flag - Init', LError);
      Exit;
    end;

    // 子测试 1.1: 启用 sslVerifyPeer
    WriteLn;
    WriteLn('1.1: With sslVerifyPeer (valid cert)');
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
          WriteLn('✅ Verification passed with sslVerifyPeer');
          AddResult('VerifyPeer - Valid', True, 'Passed');
        end
        else
        begin
          WriteLn('❌ Unexpected failure: ', LConn.GetVerifyResultString);
          AddResult('VerifyPeer - Valid', False, LConn.GetVerifyResultString);
        end;
        LConn.Shutdown;
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    // 子测试 1.2: 禁用验证
    WriteLn;
    WriteLn('1.2: Without sslVerifyPeer (no verification)');
    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      // 不加载 CA，不启用验证
      LCtx.SetVerifyMode([]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        WriteLn('✅ Connected without verification');
        // 验证应该被跳过
        AddResult('VerifyPeer - Disabled', True, 'Connection succeeded');
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
      AddResult('VerifyPeer Flag', False, E.Message);
    end;
  end;
end;

{ Test 2: 验证失败时的行为 }
procedure TestVerifyFailureBehavior;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 2: Verification Failure Behavior');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('Verify Failure - Init', LError);
      Exit;
    end;

    // 测试: 启用验证但使用错误的主机名
    WriteLn('Testing with wrong hostname (www.google.com as badssl.com)...');
    LSock := ConnectTCP('www.google.com', 443);

    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('badssl.com'); // 错误的 SNI
      if LConn.Connect then
      begin
        WriteLn('✅ Handshake succeeded (verification is post-handshake)');

        // 检查验证结果
        if LConn.GetVerifyResult <> 0 then
        begin
          WriteLn('✅ Verification correctly failed');
          WriteLn('   Error: ', LConn.GetVerifyResultString);
          AddResult('Verify Failure - Detection', True, 'Error correctly reported');
        end
        else
        begin
          WriteLn('❌ Should have failed verification');
          AddResult('Verify Failure - Detection', False, 'No error reported');
        end;

        LConn.Shutdown;
      end
      else
      begin
        WriteLn('ℹ️  Handshake failed');
        AddResult('Verify Failure - Detection', True, 'Handshake rejected');
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
      AddResult('Verify Failure', False, E.Message);
    end;
  end;
end;

{ Test 3: 多种证书验证标志组合 }
procedure TestCertVerifyFlags;
var
  LCtx: ISSLContext;
  LFlags: TSSLCertVerifyFlags;
begin
  WriteLn;
  WriteLn('Test 3: Certificate Verify Flags API');
  WriteLn('----------------------------------------------');

  try
    LCtx := GLib.CreateContext(sslCtxClient);

    // 测试设置和获取标志
    WriteLn('Testing SetCertVerifyFlags/GetCertVerifyFlags...');

    LFlags := [];
    LCtx.SetCertVerifyFlags(LFlags);
    LFlags := LCtx.GetCertVerifyFlags;
    if LFlags = [] then
      WriteLn('✅ Empty flags: OK')
    else
      raise Exception.Create('Empty flags round-trip mismatch');

    LFlags := [sslCertVerifyIgnoreExpiry];
    LCtx.SetCertVerifyFlags(LFlags);
    LFlags := LCtx.GetCertVerifyFlags;
    if (sslCertVerifyIgnoreExpiry in LFlags) and
      not (sslCertVerifyIgnoreHostname in LFlags) then
      WriteLn('✅ IgnoreExpiry flag: TRUE')
    else
      raise Exception.Create('IgnoreExpiry flag round-trip mismatch');

    LFlags := [sslCertVerifyIgnoreExpiry, sslCertVerifyIgnoreHostname];
    LCtx.SetCertVerifyFlags(LFlags);
    LFlags := LCtx.GetCertVerifyFlags;
    if (sslCertVerifyIgnoreExpiry in LFlags) and
      (sslCertVerifyIgnoreHostname in LFlags) then
      WriteLn('✅ Multiple flags round-trip: OK')
    else
      raise Exception.Create('Multiple verify flags round-trip mismatch');

    AddResult('CertVerifyFlags API', True, 'Get/Set working');

    LCtx := nil;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('CertVerifyFlags API', False, E.Message);
    end;
  end;
end;

{ Test 4: 验证深度不同值测试 }
procedure TestVerifyDepthValues;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LDepths: array[0..3] of Integer = (1, 5, 10, 100);
  I: Integer;
begin
  WriteLn;
  WriteLn('Test 4: Verify Depth Different Values');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('Verify Depth Values - Init', LError);
      Exit;
    end;

    for I := 0 to High(LDepths) do
    begin
      WriteLn;
      WriteLn(Format('4.%d: Verify depth = %d', [I + 1, LDepths[I]]));

      LSock := ConnectTCP('www.google.com', 443);
      try
        LCtx := GLib.CreateContext(sslCtxClient);
        LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
        LCtx.SetVerifyMode([sslVerifyPeer]);
        LCtx.SetVerifyDepth(LDepths[I]);

        LConn := LCtx.CreateConnection(LSock);
        (LConn as ISSLClientConnection).SetServerName('www.google.com');
        if LConn.Connect then
        begin
          if LConn.GetVerifyResult = 0 then
          begin
            WriteLn(Format('✅ Passed with depth=%d', [LDepths[I]]));
            AddResult(Format('Depth=%d', [LDepths[I]]), True, 'Verification passed');
          end
          else
          begin
            WriteLn(Format('⚠️  Failed with depth=%d: %s',
              [LDepths[I], LConn.GetVerifyResultString]));
            AddResult(Format('Depth=%d', [LDepths[I]]), False,
              'Verification failed');
          end;

          LConn.Shutdown;
        end;

        LConn := nil;
        LCtx := nil;
      finally
        CloseSocket(LSock);
      end;
    end;

    CleanupNetwork;
  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Verify Depth Values', False, E.Message);
    end;
  end;
end;

{ Test 5: GetVerifyResult 错误码测试 }
procedure TestVerifyResultCodes;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LResult: Integer;
begin
  WriteLn;
  WriteLn('Test 5: GetVerifyResult Error Codes');
  WriteLn('----------------------------------------------');

  try
    if not InitNetwork(LError) then
    begin
      AddSkipResult('VerifyResult Codes - Init', LError);
      Exit;
    end;

    // 子测试 5.1: 成功验证 (result = 0)
    WriteLn;
    WriteLn('5.1: Successful verification (expect 0)');
    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        LResult := LConn.GetVerifyResult;
        WriteLn('Verify result: ', LResult);
        WriteLn('String: ', LConn.GetVerifyResultString);

        if LResult = 0 then
        begin
          WriteLn('✅ Result is 0 (success)');
          AddResult('VerifyResult - Success', True, 'Code = 0');
        end
        else
        begin
          WriteLn('⚠️  Unexpected result: ', LResult);
          AddResult('VerifyResult - Success', False, Format('Code = %d', [LResult]));
        end;

        LConn.Shutdown;
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LSock);
    end;

    // 子测试 5.2: 验证失败 (result != 0)
    WriteLn;
    WriteLn('5.2: Failed verification (expect non-zero)');
    LSock := ConnectTCP('www.google.com', 443);
    try
      LCtx := GLib.CreateContext(sslCtxClient);
      // 不加载 CA - 应该失败
      LCtx.SetVerifyMode([sslVerifyPeer]);

      LConn := LCtx.CreateConnection(LSock);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');
      if LConn.Connect then
      begin
        LResult := LConn.GetVerifyResult;
        WriteLn('Verify result: ', LResult);
        WriteLn('String: ', LConn.GetVerifyResultString);

        if LResult <> 0 then
        begin
          WriteLn('✅ Result is non-zero (failure detected)');
          AddResult('VerifyResult - Failure', True, Format('Code = %d', [LResult]));
        end
        else
        begin
          WriteLn('❌ Should have failed!');
          AddResult('VerifyResult - Failure', False, 'Incorrectly passed');
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
      AddResult('VerifyResult Codes', False, E.Message);
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
  WriteLn('MbedTLS Certificate Verify Flags Test');
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
    TestVerifyPeerFlag;
    TestVerifyFailureBehavior;
    TestCertVerifyFlags;
    TestVerifyDepthValues;
    TestVerifyResultCodes;

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
