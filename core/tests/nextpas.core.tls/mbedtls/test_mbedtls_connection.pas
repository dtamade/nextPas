program test_mbedtls_connection;

{$mode ObjFPC}{$H+}

{
  MbedTLS TLS 连接测试

  测试场景:
  1. 连接公共 HTTPS 服务器
  2. 验证 TLS 1.2/1.3 握手
  3. 简单 HTTP GET 请求和响应读取
}

uses
  SysUtils, Classes, Math,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.context,
  nextpas.core.tls.mbedtls.connection,
  fafafa.examples.tcp;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;

procedure TestSimpleConnection;
var
  LLib: ISSLLibrary;  // 使用接口引用避免引用计数问题
  LCtx: TMbedTLSContext;
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
  LMbedConn: TMbedTLSConnection;
  LSock: TSocketHandle;
  LRequest: AnsiString;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
  LState: TSSLHandshakeState;
  LError: string;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Connection Test (HTTP GET)');
  WriteLn('================================================================================');
  WriteLn;

  // 1. 初始化网络
  WriteLn('1. Initializing network...');
  if not InitNetwork(LError) then
  begin
    WriteLn('   ❌ Failed: ', LError);
    Halt(1);
  end;
  WriteLn('   ✅ Network initialized');
  WriteLn;

  // 2. 初始化 Library
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
    LCtx.SetVerifyMode([]);
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
        WriteLn('   ❌ Failed: ', E.Message);
        LLib.Finalize;
        CleanupNetwork;
        Halt(1);
      end;
    end;

    try
      // 5. 创建 SSL Connection
      WriteLn('5. Creating SSL connection...');
      LConn := LCtx.CreateConnection(LSock);
      LClientConn := LConn as ISSLClientConnection;
      LClientConn.SetServerName(TEST_HOST);
      WriteLn('   ✅ SSL connection created (SNI: ', TEST_HOST, ')');

      if LConn is TMbedTLSConnection then
        LMbedConn := TMbedTLSConnection(LConn as TObject)
      else
        LMbedConn := nil;
      WriteLn;

      // 6. TLS 握手
      WriteLn('6. Performing TLS handshake...');
      LState := LConn.DoHandshake;

      if LState = sslHsCompleted then
      begin
        WriteLn('   ✅ Handshake successful!');
        WriteLn('   Protocol: ', Ord(LConn.GetProtocolVersion));
        WriteLn('   Cipher: ', LConn.GetCipherName);
        WriteLn;

        // 7. 发送 HTTP GET
        WriteLn('7. Sending HTTP GET request...');
        LRequest := 'GET / HTTP/1.1'#13#10 +
                    'Host: ' + TEST_HOST + #13#10 +
                    'Connection: close'#13#10#13#10;

        if LConn.Write(LRequest[1], Length(LRequest)) > 0 then
        begin
          WriteLn('   ✅ Request sent (', Length(LRequest), ' bytes)');
          WriteLn;

          // 8. 读取响应
          WriteLn('8. Reading response...');
          LBytesRead := LConn.Read(LBuffer[0], SizeOf(LBuffer));
          if LBytesRead > 0 then
          begin
            WriteLn('   ✅ Response received (', LBytesRead, ' bytes)');
            WriteLn('   First 100 bytes:');
            LBuffer[Min(LBytesRead, 100)] := 0;
            WriteLn('   ', PAnsiChar(@LBuffer[0]));
            WriteLn;
          end
          else
            WriteLn('   ⚠️  No response data');
        end
        else
          WriteLn('   ❌ Failed to send request');

        // 9. 关闭连接
        WriteLn('9. Closing SSL connection...');
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
    WriteLn('10. Finalizing library...');
    LLib.Finalize;
    WriteLn('    ✅ Library finalized');

  finally
    LLib := nil;  // 释放接口引用
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
