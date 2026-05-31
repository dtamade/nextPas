program test_mbedtls_interface_only;

{$mode ObjFPC}{$H+}

{
  MbedTLS Interface 引用计数测试

  完全依赖 Interface 引用计数,不手动 Free 任何对象
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
  LLib: ISSLLibrary;  // 使用 Interface!
  LCtx: ISSLContext;  // 使用 Interface!
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LRequest: AnsiString;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Interface Reference Counting Test');
  WriteLn('================================================================================');
  WriteLn;

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed');
    Halt(1);
  end;

  LSock := INVALID_SOCKET;

  try
    WriteLn('1. Create library (as interface)...');
    LLib := TMbedTLSLibrary.Create;  // 创建后立即转为 Interface
    if not LLib.Initialize then
    begin
      WriteLn('   ❌ Init failed');
      Exit;
    end;
    WriteLn('   ✅ ', LLib.GetVersionString);

    WriteLn('2. Create context (as interface)...');
    LCtx := TMbedTLSContext.Create(LLib, sslCtxClient) as ISSLContext;
    WriteLn('   ✅ OK');

    WriteLn('3. Connect TCP...');
    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    WriteLn('   ✅ Connected');

    WriteLn('4. Create SSL connection...');
    LConn := LCtx.CreateConnection(LSock);
    WriteLn('   ✅ Created');

    WriteLn('5. Handshake...');
    if not LConn.Connect then
    begin
      WriteLn('   ❌ Failed');
      Exit;
    end;
    WriteLn('   ✅ Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));

    WriteLn('6. Send...');
    LRequest := 'GET / HTTP/1.1'#13#10 + 'Host: ' + TEST_HOST + #13#10 + 'Connection: close'#13#10#13#10;
    LConn.Write(LRequest[1], Length(LRequest));
    WriteLn('   ✅ Sent');

    WriteLn('7. Receive...');
    LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
    WriteLn('   ✅ Received ', LBytesRead, ' bytes');

    WriteLn('8. Shutdown...');
    LConn.Shutdown;
    WriteLn('   ✅ Closed');

  finally
    WriteLn;
    WriteLn('Cleanup (all automatic via interface reference counting):');

    if LSock <> INVALID_SOCKET then
    begin
      WriteLn('  - Closing socket...');
      CloseSocket(LSock);
      WriteLn('    ✅ Closed');
    end;

    WriteLn('  - Releasing LConn interface (ref count)...');
    LConn := nil;
    WriteLn('    ✅ Released');

    WriteLn('  - Releasing LCtx interface (ref count)...');
    LCtx := nil;
    WriteLn('    ✅ Released');

    WriteLn('  - Releasing LLib interface (ref count, will trigger Finalize)...');
    LLib := nil;
    WriteLn('    ✅ Released');

    CleanupNetwork;
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
    WriteLn('✅ Program exiting (should be clean)');
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
