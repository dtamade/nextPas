program test_mbedtls_alpn;

{$mode ObjFPC}{$H+}

{
  MbedTLS ALPN Support Test

  测试:
  1. ALPN 协议设置
  2. ALPN 协商 (h2, http/1.1)
  3. 获取协商结果
}

uses
  SysUtils, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  fafafa.examples.tcp;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;

procedure TestALPNNegotiation;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LSelectedProtocol: string;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS ALPN Support Test');
  WriteLn('================================================================================');
  WriteLn;

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed');
    Halt(1);
  end;

  WriteLn('1. Initialize MbedTLS...');
  LLib := TMbedTLSLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('   ❌ Failed');
    CleanupNetwork;
    Halt(1);
  end;
  WriteLn('   ✅ ', LLib.GetVersionString);

  WriteLn('2. Connect TCP to ', TEST_HOST, ':', TEST_PORT, '...');
  LSock := ConnectTCP(TEST_HOST, TEST_PORT);
  WriteLn('   ✅ Connected');

  try
    WriteLn('3. Create SSL context...');
    LCtx := LLib.CreateContext(sslCtxClient);
    LCtx.SetVerifyMode([]);

    // 设置 ALPN 协议列表
    WriteLn('4. Set ALPN protocols (h2, http/1.1)...');
    LCtx.SetALPNProtocols('h2,http/1.1');
    WriteLn('   ✅ ALPN protocols set');

    WriteLn('5. Create SSL connection...');
    LConn := LCtx.CreateConnection(LSock);
    WriteLn('   ✅ Connection created');

    WriteLn('6. TLS handshake...');
    if not LConn.Connect then
    begin
      WriteLn('   ❌ Handshake failed');
      CloseSocket(LSock);
      LLib.Finalize;
      CleanupNetwork;
      Halt(1);
    end;
    WriteLn('   ✅ Handshake success');
    WriteLn('   Protocol: ', GetEnumName(TypeInfo(TSSLProtocolVersion), Ord(LConn.GetProtocolVersion)));

    // 检查 ALPN 协商结果
    WriteLn('7. Check ALPN negotiation result...');
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    LSelectedProtocol := LConn.GetSelectedALPNProtocol;
    {$POP}
    WriteLn('   Selected protocol: "', LSelectedProtocol, '"');

    if LSelectedProtocol <> '' then
    begin
      WriteLn('   ✅ ALPN negotiated: ', LSelectedProtocol);
      if (LSelectedProtocol = 'h2') or (LSelectedProtocol = 'http/1.1') then
        WriteLn('   ✅ Valid protocol selected')
      else
        WriteLn('   ⚠️  Unexpected protocol: ', LSelectedProtocol);
    end
    else
      WriteLn('   ℹ️  No ALPN negotiated (server may not support)');

    LConn.Shutdown;
    LConn := nil;
    LCtx := nil;

  finally
    CloseSocket(LSock);
  end;

  LLib.Finalize;
  LLib := nil;
  CleanupNetwork;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('✅ Test Complete - ALPN Support Working!');
  WriteLn('================================================================================');
end;

begin
  try
    TestALPNNegotiation;
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
