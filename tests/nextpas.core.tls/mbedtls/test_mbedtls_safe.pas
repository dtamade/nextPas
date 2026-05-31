program test_mbedtls_safe;

{$mode ObjFPC}{$H+}

{
  MbedTLS 安全资源管理测试

  显式管理生命周期,使用接口引用避免引用计数问题

  重要: TMbedTLSLibrary 继承自 TInterfacedObject，需要使用接口引用
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
  LLib: ISSLLibrary;  // 使用接口引用避免引用计数问题
  LCtx: TMbedTLSContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LRequest: AnsiString;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Safe Resource Management Test');
  WriteLn('================================================================================');
  WriteLn;

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed: ', LError);
    Halt(1);
  end;

  LLib := TMbedTLSLibrary.Create;
  LCtx := nil;
  LConn := nil;
  LSock := INVALID_SOCKET;

  try
    // 1. 初始化库
    WriteLn('1. Initializing MbedTLS...');
    if not LLib.Initialize then
    begin
      WriteLn('   ❌ Failed');
      Exit;
    end;
    WriteLn('   ✅ ', LLib.GetVersionString);

    // 2. 创建 Context
    WriteLn('2. Creating context...');
    LCtx := TMbedTLSContext.Create(LLib, sslCtxClient);
    WriteLn('   ✅ OK');

    // 3. TCP 连接
    WriteLn('3. Connecting TCP...');
    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    WriteLn('   ✅ Connected');

    // 4. 创建 SSL Connection
    WriteLn('4. Creating SSL connection...');
    LConn := LCtx.CreateConnection(LSock);
    WriteLn('   ✅ Created');

    // 5. TLS 握手
    WriteLn('5. Handshake...');
    if not LConn.Connect then
    begin
      WriteLn('   ❌ Failed: ', LConn.GetVerifyResultString);
      Exit;
    end;
    WriteLn('   ✅ Success!');
    WriteLn('   Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));
    WriteLn('   Cipher: ', LConn.GetCipherName);

    // 6. 发送 HTTP GET
    WriteLn('6. Sending HTTP GET...');
    LRequest := 'GET / HTTP/1.1'#13#10 +
                'Host: ' + TEST_HOST + #13#10 +
                'Connection: close'#13#10#13#10;

    if LConn.Write(LRequest[1], Length(LRequest)) <= 0 then
    begin
      WriteLn('   ❌ Write failed');
      Exit;
    end;
    WriteLn('   ✅ Sent');

    // 7. 读取响应
    WriteLn('7. Reading response...');
    LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
    if LBytesRead > 0 then
    begin
      WriteLn('   ✅ Received ', LBytesRead, ' bytes');
      WriteLn('   First line: ', Copy(AnsiString(PAnsiChar(@LBuffer[0])), 1, 100));
    end
    else
      WriteLn('   ⚠️  No data');

    // 8. 关闭连接
    WriteLn('8. Shutting down...');
    LConn.Shutdown;
    WriteLn('   ✅ Closed');

  finally
    // 按正确顺序清理资源
    WriteLn;
    WriteLn('9. Cleanup...');

    // 9.1 释放连接 (Interface 自动释放)
    if LConn <> nil then
    begin
      WriteLn('   9.1 Releasing connection...');
      LConn := nil;  // 触发 Interface 释放
      WriteLn('       ✅ Connection released');
    end;

    // 9.2 关闭 Socket
    if LSock <> INVALID_SOCKET then
    begin
      WriteLn('   9.2 Closing socket...');
      CloseSocket(LSock);
      WriteLn('       ✅ Socket closed');
    end;

    // 9.3 释放 Context
    if LCtx <> nil then
    begin
      WriteLn('   9.3 Freeing context...');
      try
        LCtx.Free;
        WriteLn('       ✅ Context freed');
      except
        on E: Exception do
          WriteLn('       ⚠️  Context free error: ', E.Message);
      end;
    end;

    // 9.4 Finalize Library
    WriteLn('   9.4 Finalizing library...');
    try
      LLib.Finalize;
      WriteLn('       ✅ Library finalized');
    except
      on E: Exception do
        WriteLn('       ⚠️  Finalize error: ', E.Message);
    end;

    // 9.5 释放 Library 接口引用
    WriteLn('   9.5 Releasing library interface...');
    LLib := nil;  // 释放接口引用
    WriteLn('       ✅ Library released');

    CleanupNetwork;
    WriteLn('   ✅ Cleanup complete');
  end;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('🎉 Test Complete - Checking for memory errors...');
  WriteLn('================================================================================');
end;

begin
  try
    TestConnection;
    WriteLn;
    WriteLn('✅ Program exiting normally');
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
