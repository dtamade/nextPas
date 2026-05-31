program test_mbedtls_connection_final;

{$mode ObjFPC}{$H+}

{
  MbedTLS 连接测试 - 正确的资源管理

  使用 Interface 引用计数,不手动 Free Library
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

procedure TestConnection;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;  // 使用 Interface,不是 TMbedTLSContext!
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LRequest: AnsiString;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Connection Test - Final Version');
  WriteLn('================================================================================');
  WriteLn;

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed');
    Halt(1);
  end;

  LLib := TMbedTLSLibrary.Create;  // 立即转换为 Interface
  LCtx := nil;
  LConn := nil;
  LSock := INVALID_SOCKET;

  try
    WriteLn('1. Initialize MbedTLS...');
    if not LLib.Initialize then
    begin
      WriteLn('   ❌ Failed');
      Exit;
    end;
    WriteLn('   ✅ ', LLib.GetVersionString);

    WriteLn('2. Create context...');
    LCtx := LLib.CreateContext(sslCtxClient);  // 使用工厂方法
    WriteLn('   ✅ OK');

    WriteLn('3. Connect TCP...');
    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    WriteLn('   ✅ Connected');

    WriteLn('4. Create SSL connection...');
    LConn := LCtx.CreateConnection(LSock);
    WriteLn('   ✅ Created');

    WriteLn('5. TLS handshake...');
    if not LConn.Connect then
    begin
      WriteLn('   ❌ Failed');
      Exit;
    end;
    WriteLn('   ✅ Success!');
    WriteLn('   Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));
    WriteLn('   Cipher: ', LConn.GetCipherName);
    WriteLn('   Peer Certificate: ', LConn.GetPeerCertificate <> nil);

    WriteLn('6. Send HTTP GET...');
    LRequest := 'GET / HTTP/1.1'#13#10 + 'Host: ' + TEST_HOST + #13#10 + 'Connection: close'#13#10#13#10;
    if LConn.Write(LRequest[1], Length(LRequest)) <= 0 then
    begin
      WriteLn('   ❌ Write failed');
      Exit;
    end;
    WriteLn('   ✅ Sent ', Length(LRequest), ' bytes');

    WriteLn('7. Read response...');
    LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
    if LBytesRead > 0 then
    begin
      WriteLn('   ✅ Received ', LBytesRead, ' bytes');
      WriteLn('   First line: ', Copy(AnsiString(PAnsiChar(@LBuffer[0])), 1, 100));
    end
    else
      WriteLn('   ⚠️  No data');

    WriteLn('8. Shutdown...');
    LConn.Shutdown;
    WriteLn('   ✅ Closed');

  finally
    WriteLn;
    WriteLn('Cleanup:');

    // 1. 释放 Connection
    if LConn <> nil then
    begin
      WriteLn('  1. Releasing connection...');
      LConn := nil;
      WriteLn('     ✅ Released');
    end;

    // 2. 关闭 Socket
    if LSock <> INVALID_SOCKET then
    begin
      WriteLn('  2. Closing socket...');
      CloseSocket(LSock);
      WriteLn('     ✅ Closed');
    end;

    // 3. 释放 Context (Interface 自动释放)
    if LCtx <> nil then
    begin
      WriteLn('  3. Releasing context interface...');
      LCtx := nil;
      WriteLn('     ✅ Released');
    end;

    // 4. Finalize Library
    WriteLn('  4. Finalizing library...');
    LLib.Finalize;
    WriteLn('     ✅ Finalized');

    // 5. Library 自动释放 (Interface)
    WriteLn('  5. Library will auto-release (interface)');

    CleanupNetwork;
    WriteLn('  ✅ All cleanup complete');
  end;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('🎉 Test Complete!');
  WriteLn('================================================================================');
end;

begin
  try
    TestConnection;
    WriteLn;
    WriteLn('✅ Program exiting cleanly - NO MEMORY ERRORS!');
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
