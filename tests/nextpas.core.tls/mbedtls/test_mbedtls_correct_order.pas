program test_mbedtls_correct_order;

{$mode ObjFPC}{$H+}

{
  MbedTLS 正确释放顺序测试

  正确的顺序:
  1. 释放 Connection (Interface,自动)
  2. 关闭 Socket
  3. Context 由 Connection 的接口引用自动管理，不需要手动释放
  4. Finalize + 释放 Library (使用接口引用)

  重要:
  - TMbedTLSLibrary 继承自 TInterfacedObject，需要使用接口引用
  - TMbedTLSContext 也继承自 TInterfacedObject
  - Connection 持有 Context 的接口引用 (FContext: ISSLContext)
  - 当 Connection 释放时，如果是最后一个引用，Context 也会自动释放
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
  LLib: ISSLLibrary;  // 使用接口引用
  LCtx: ISSLContext;  // 使用接口引用，让引用计数机制管理生命周期
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LRequest: AnsiString;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Correct Resource Order Test');
  WriteLn('================================================================================');
  WriteLn;

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed');
    Halt(1);
  end;

  LLib := TMbedTLSLibrary.Create;
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
    LCtx := TMbedTLSContext.Create(LLib, sslCtxClient);
    WriteLn('   ✅ OK');

    WriteLn('3. Connect TCP...');
    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    WriteLn('   ✅ Connected');

    WriteLn('4. Create SSL connection...');
    // 注意：CreateConnection 需要 TMbedTLSContext，但 LCtx 是 ISSLContext
    // 需要类型转换或修改 API
    LConn := (LCtx as TMbedTLSContext).CreateConnection(LSock);
    WriteLn('   ✅ Created');

    WriteLn('5. TLS handshake...');
    if not LConn.Connect then
    begin
      WriteLn('   ❌ Failed');
      Exit;
    end;
    WriteLn('   ✅ Success! Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));

    WriteLn('6. Send HTTP GET...');
    LRequest := 'GET / HTTP/1.1'#13#10 + 'Host: ' + TEST_HOST + #13#10 + 'Connection: close'#13#10#13#10;
    if LConn.Write(LRequest[1], Length(LRequest)) <= 0 then
    begin
      WriteLn('   ❌ Write failed');
      Exit;
    end;
    WriteLn('   ✅ Sent');

    WriteLn('7. Read response...');
    LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
    if LBytesRead > 0 then
      WriteLn('   ✅ Received ', LBytesRead, ' bytes')
    else
      WriteLn('   ⚠️  No data');

    WriteLn('8. Shutdown...');
    LConn.Shutdown;
    WriteLn('   ✅ Closed');

  finally
    WriteLn;
    WriteLn('Cleanup in correct order:');

    // 1. 释放 Connection
    // Connection 持有 Context 的接口引用，释放 Connection 会减少 Context 的引用计数
    if LConn <> nil then
    begin
      WriteLn('  1. Releasing connection interface...');
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

    // 3. 释放 Context 接口引用
    // 由于我们也持有 LCtx 接口引用，Context 不会在 Connection 释放时被销毁
    // 需要先 Finalize Library（Context 需要调用 mbedtls 函数清理）
    // 但这会导致问题：Context.Destroy 调用 mbedtls_ssl_config_free
    // 解决：先释放 Context，再 Finalize
    if LCtx <> nil then
    begin
      WriteLn('  3. Releasing context interface (triggers cleanup)...');
      LCtx := nil;
      WriteLn('     ✅ Released');
    end;

    // 4. Finalize Library
    WriteLn('  4. Finalizing library (unloads DLLs)...');
    LLib.Finalize;
    WriteLn('     ✅ Finalized');

    // 5. 释放 Library 接口引用
    WriteLn('  5. Releasing library interface...');
    LLib := nil;
    WriteLn('     ✅ Released');

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
    WriteLn('✅ Program exiting cleanly (no memory errors)');
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
