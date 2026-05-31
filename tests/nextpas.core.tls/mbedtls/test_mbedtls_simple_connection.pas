program test_mbedtls_simple_connection;

{$mode ObjFPC}{$H+}

{
  MbedTLS 简单 TLS 连接测试

  测试流程:
  1. 使用 TMbedTLSLibrary 创建库
  2. 创建 Client Context
  3. 连接 www.google.com:443
  4. 执行 TLS 握手
  5. 简单验证连接状态
}

uses
  SysUtils, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.context,
  nextpas.core.tls.mbedtls.connection,
  fafafa.examples.tcp;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this MbedTLS-specific runtime
// file intentionally keeps direct core GetVerifyResult/GetVerifyResultString
// coverage as backend proof. Generic ISSLCertificateVerification owner-path
// guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

procedure TestSimpleConnection;
var
  LLib: ISSLLibrary;  // 使用接口引用避免引用计数问题
  LCtx: TMbedTLSContext;
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
  LMbedConn: TMbedTLSConnection;
  LSock: TSocketHandle;
  LError: string;
  LState: TSSLHandshakeState;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Simple Connection Test');
  WriteLn('================================================================================');
  WriteLn;

  // 1. 初始化网络
  WriteLn('1. Initializing network...');
  if not InitNetwork(LError) then
  begin
    WriteLn('   ❌ Failed to initialize network: ', LError);
    Halt(1);
  end;
  WriteLn('   ✅ Network initialized');
  WriteLn;

  // 2. 初始化 MbedTLS
  WriteLn('2. Initializing MbedTLS library...');
  LLib := TMbedTLSLibrary.Create;
  try
    if not LLib.Initialize then
    begin
      WriteLn('   ❌ Failed to initialize MbedTLS');
      CleanupNetwork;
      Halt(1);
    end;
    WriteLn('   ✅ Initialized: ', LLib.GetVersionString);
    WriteLn;

    // 3. 创建 Context
    WriteLn('3. Creating SSL context...');
    LCtx := TMbedTLSContext.Create(LLib, sslCtxClient);
    LCtx.SetVerifyMode([]);  // 暂不验证证书
    WriteLn('   ✅ Context created');
    WriteLn;

    // 4. 创建 TCP Socket
    WriteLn('4. Connecting to ', TEST_HOST, ':', TEST_PORT, '...');
    try
      LSock := ConnectTCP(TEST_HOST, TEST_PORT);
      WriteLn('   ✅ TCP connected');
      WriteLn;
    except
      on E: Exception do
      begin
        WriteLn('   ❌ Failed to connect: ', E.Message);
        LLib.Finalize;
        CleanupNetwork;
        Halt(1);
      end;
    end;

    try
      // 5. 创建 SSL Connection（传入 socket）
      WriteLn('5. Creating SSL connection...');
      LConn := LCtx.CreateConnection(LSock);
      LClientConn := LConn as ISSLClientConnection;
      LClientConn.SetServerName(TEST_HOST);
      WriteLn('   ✅ SSL connection created (SNI: ', TEST_HOST, ')');
      WriteLn;

      // 获取 MbedTLS 特定接口用于调试
      if LConn is TMbedTLSConnection then
        LMbedConn := TMbedTLSConnection(LConn as TObject)
      else
        LMbedConn := nil;

      // 6. TLS 握手
      WriteLn('6. Performing TLS handshake...');
      LState := LConn.DoHandshake;

      if LState = sslHsCompleted then
      begin
        WriteLn('   ✅ Handshake successful!');
        WriteLn('   Protocol Version: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));
        WriteLn('   Cipher: ', LConn.GetCipherName);
        WriteLn('   Peer Certificate: ', LConn.GetPeerCertificate <> nil);
        WriteLn('   Verify Result: ', LConn.GetVerifyResult);
        WriteLn;

        // 7. 关闭连接
        WriteLn('7. Closing connection...');
        LConn.Shutdown;
        WriteLn('   ✅ SSL connection closed');
      end
      else
      begin
        WriteLn('   ❌ Handshake failed (state=', Ord(LState), ')');
        if LMbedConn <> nil then
          WriteLn('   Error: ', LMbedConn.GetLastErrorString);
      end;

      LConn := nil;

    finally
      CloseSocket(LSock);
    end;

    WriteLn;
    WriteLn('8. Finalizing library...');
    LLib.Finalize;
    WriteLn('   ✅ Library finalized');

  finally
    LLib := nil;  // 释放接口引用，自动释放对象
    CleanupNetwork;
  end;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('🎉 Connection Test Complete!');
  WriteLn('================================================================================');
end;

begin
  try
    TestSimpleConnection;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ Fatal error: ', E.ClassName, ': ', E.Message);
      CleanupNetwork;
      Halt(1);
    end;
  end;
end.
