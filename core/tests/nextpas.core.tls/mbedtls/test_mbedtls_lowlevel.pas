program test_mbedtls_lowlevel;

{$mode ObjFPC}{$H+}

{
  MbedTLS 底层 API 测试

  直接使用 TMbedTLSContext.CreateConnection(Socket) API

  重要:
  - TMbedTLSLibrary 继承自 TInterfacedObject，需要使用接口引用
  - TMbedTLSContext 也继承自 TInterfacedObject
  - Connection 持有 Context 的接口引用 (FContext: ISSLContext)
}

uses
  SysUtils, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.context,
  fafafa.examples.tcp;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this MbedTLS-specific runtime
// file intentionally keeps direct core GetVerifyResult/GetVerifyResultString
// coverage as backend proof. Generic ISSLCertificateVerification owner-path
// guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

procedure TestConnection;
var
  LLib: ISSLLibrary;  // 使用接口引用
  LCtx: ISSLContext;  // 使用接口引用
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LRequest: AnsiString;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Low-Level API Test');
  WriteLn('================================================================================');
  WriteLn;

  // 1. 初始化网络
  WriteLn('1. Initializing network...');
  if not InitNetwork(LError) then
  begin
    WriteLn('   ❌ Failed: ', LError);
    Halt(1);
  end;
  WriteLn('   ✅ OK');
  WriteLn;

  // 2. 初始化 MbedTLS
  WriteLn('2. Initializing MbedTLS...');
  LLib := TMbedTLSLibrary.Create;
  LCtx := nil;
  LConn := nil;
  LSock := INVALID_SOCKET;

  try
    if not LLib.Initialize then
    begin
      WriteLn('   ❌ Failed');
      CleanupNetwork;
      Halt(1);
    end;
    WriteLn('   ✅ ', LLib.GetVersionString);
    WriteLn;

    // 3. 创建 Context
    WriteLn('3. Creating client context...');
    LCtx := TMbedTLSContext.Create(LLib, sslCtxClient);
    WriteLn('   ✅ OK');
    WriteLn;

    // 4. 连接 TCP
    WriteLn('4. Connecting TCP to ', TEST_HOST, ':', TEST_PORT, '...');
    try
      LSock := ConnectTCP(TEST_HOST, TEST_PORT);
      WriteLn('   ✅ Connected');
      WriteLn;
    except
      on E: Exception do
      begin
        WriteLn('   ❌ ', E.Message);
        LCtx := nil;
        LLib.Finalize;
        LLib := nil;
        CleanupNetwork;
        Halt(1);
      end;
    end;

    try
      // 5. 创建 SSL Connection (带 Socket)
      WriteLn('5. Creating SSL connection with socket...');
      LConn := (LCtx as TMbedTLSContext).CreateConnection(LSock);
      WriteLn('   ✅ Created');
      WriteLn;

      // 6. TLS 握手
      WriteLn('6. Performing handshake...');
      try
        if LConn.Connect then
        begin
          WriteLn('   ✅ Success!');
          WriteLn('   Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));
          WriteLn('   Cipher: ', LConn.GetCipherName);
          WriteLn('   Peer Certificate: ', LConn.GetPeerCertificate <> nil);
          WriteLn('   Verify Result: ', LConn.GetVerifyResult);
          WriteLn;

          // 7. 发送简单 HTTP GET
          WriteLn('7. Sending HTTP GET...');
          LRequest := 'GET / HTTP/1.1'#13#10 +
                      'Host: ' + TEST_HOST + #13#10 +
                      'Connection: close'#13#10#13#10;

          if LConn.Write(LRequest[1], Length(LRequest)) > 0 then
          begin
            WriteLn('   ✅ Sent ', Length(LRequest), ' bytes');
            WriteLn;

            // 8. 读取响应
            WriteLn('8. Reading response...');
            try
              LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
              if LBytesRead > 0 then
              begin
                WriteLn('   ✅ Received ', LBytesRead, ' bytes');
                WriteLn('   First 200 bytes:');
                WriteLn('   ', Copy(AnsiString(PAnsiChar(@LBuffer[0])), 1, 200));
              end
              else
                WriteLn('   ⚠️  No data (', LBytesRead, ')');
            except
              on E: Exception do
                WriteLn('   ⚠️  Read exception: ', E.Message);
            end;
            WriteLn;
          end
          else
            WriteLn('   ❌ Failed to send');

          // 9. 关闭
          WriteLn('9. Shutting down...');
          LConn.Shutdown;
          WriteLn('   ✅ Closed');
        end
        else
        begin
          WriteLn('   ❌ Handshake failed');
          WriteLn('   Error: ', LConn.GetVerifyResultString);
        end;
      except
        on E: Exception do
        begin
          WriteLn('   ❌ Exception: ', E.ClassName, ': ', E.Message);
        end;
      end;

    finally
      CloseSocket(LSock);
    end;

    WriteLn;
    WriteLn('10. Cleanup...');

    // 按正确顺序释放
    LConn := nil;
    WriteLn('    ✅ Connection released');

    LCtx := nil;
    WriteLn('    ✅ Context released');

    LLib.Finalize;
    WriteLn('    ✅ Library finalized');

  finally
    LLib := nil;
    CleanupNetwork;
  end;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('Test Complete');
  WriteLn('================================================================================');
end;

begin
  try
    TestConnection;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ Fatal: ', E.ClassName, ': ', E.Message);
      CleanupNetwork;
      Halt(1);
    end;
  end;
end.
