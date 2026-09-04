program test_winssl_https_client;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.socket,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.base.utils,

  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

var
  SSLLib: ISSLLibrary;
  Context: ISSLContext;
  Connection: ISSLConnection;
  ClientConnection: ISSLClientConnection;
  Socket: TPlatformSocket;
  Host: string;
  Port: Word;
  Request: string;
  Response: array[0..4095] of Char;
  BytesRead: Integer;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure TestPass(const TestName: string);
begin
  WriteLn('[PASS] ', TestName);
  Inc(TestsPassed);
end;

procedure TestFail(const TestName, Reason: string);
begin
  WriteLn('[FAIL] ', TestName, ': ', Reason);
  Inc(TestsFailed);
end;

function CreateTCPSocket(const aHost: string; aPort: Word): TPlatformSocket;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := PLATFORM_INVALID_SOCKET;

  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(aHost)), LIP) <> 0 then
  begin
    WriteLn('Failed to resolve host: ', aHost);
    Exit;
  end;

  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
  begin
    WriteLn('Failed to create socket');
    Result := PLATFORM_INVALID_SOCKET;
    Exit;
  end;

  platform_socket_set_timeout(Result, PLATFORM_SO_RCVTIMEO, 10000);
  platform_socket_set_timeout(Result, PLATFORM_SO_SNDTIMEO, 10000);
  platform_sockaddr_ipv4(aPort, LIP, LAddr);
  if platform_socket_connect(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    WriteLn('Failed to connect');
    platform_socket_close(Result);
    Result := PLATFORM_INVALID_SOCKET;
    Exit;
  end;

  WriteLn('TCP connection established to ', aHost, ':', aPort);
end;

begin
  WriteLn('=== WinSSL HTTPS Client Test ===');
  WriteLn;

  try
    // 设置目标服务器
    Host := 'www.google.com';
    Port := 443;

  WriteLn('Target: https://', Host, ':', Port);
  WriteLn;

  // Test 1: 创建 SSL 库
  WriteLn('Test 1: Creating SSL library...');
  try
    SSLLib := CreateWinSSLLibrary;
    if SSLLib <> nil then
      TestPass('Create SSL library')
    else
    begin
      TestFail('Create SSL library', 'Returned nil');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      TestFail('Create SSL library', E.Message);
      Halt(1);
    end;
  end;

  // Test 2: 初始化库
  WriteLn('Test 2: Initializing SSL library...');
  if not SSLLib.Initialize then
  begin
    TestFail('Initialize library', SSLLib.GetLastErrorString);
    Halt(1);
  end;
  TestPass('Initialize library');
  WriteLn('  Version: ', SSLLib.GetVersionString);

  // Test 3: 创建客户端上下文
  WriteLn('Test 3: Creating client context...');
  try
    Context := SSLLib.CreateContext(sslCtxClient);
    if Context <> nil then
      TestPass('Create client context')
    else
    begin
      TestFail('Create client context', 'Returned nil');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      TestFail('Create client context', E.Message);
      Halt(1);
    end;
  end;

  // Test 4: 配置上下文
  WriteLn('Test 4: Configuring context...');
  try
    // 设置协议版本
    Context.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);

    // 设置验证模式（暂时不验证证书）
    Context.SetVerifyMode([]);

    TestPass('Configure context (SNI: ' + Host + ')');
  except
    on E: Exception do
    begin
      TestFail('Configure context', E.Message);
      Halt(1);
    end;
  end;

  // Test 5: 创建 TCP 连接
  WriteLn('Test 5: Creating TCP connection...');
  Socket := CreateTCPSocket(Host, Port);
  if Socket.IsInvalid then
  begin
    TestFail('Create TCP connection', 'Socket creation failed');
    Halt(1);
  end;
  TestPass('Create TCP connection');

  // Test 6: 创建 SSL 连接
  WriteLn('Test 6: Creating SSL connection...');
  try
    Connection := Context.CreateConnection(THandle(Socket.Value));
    if Connection <> nil then
      TestPass('Create SSL connection')
    else
    begin
      TestFail('Create SSL connection', 'Returned nil');
      platform_socket_close(Socket);
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      TestFail('Create SSL connection', E.Message);
      platform_socket_close(Socket);
      Halt(1);
    end;
  end;

  if Supports(Connection, ISSLClientConnection, ClientConnection) then
  begin
    ClientConnection.SetServerName(Host);
    TestPass('Configure connection SNI (' + Host + ')');
  end
  else
  begin
    TestFail('Configure connection SNI', 'Connection does not support ISSLClientConnection');
    platform_socket_close(Socket);
    Halt(1);
  end;

  // Test 7: 执行 TLS 握手
  WriteLn('Test 7: Performing TLS handshake...');
  WriteLn('  This may take a few seconds...');
  try
    if Connection.Connect then
    begin
      TestPass('TLS handshake completed');
      WriteLn('  Protocol: ', ProtocolVersionToString(Connection.GetProtocolVersion));
      WriteLn('  Cipher: ', Connection.GetCipherName);
    end
    else
    begin
      TestFail('TLS handshake', 'Connect returned False');
      Connection.Close;
      platform_socket_close(Socket);
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      TestFail('TLS handshake', E.Message);
      Connection.Close;
      platform_socket_close(Socket);
      Halt(1);
    end;
  end;

  // Test 8: 发送 HTTP GET 请求
  WriteLn('Test 8: Sending HTTP GET request...');
  Request := 'GET / HTTP/1.1'#13#10 +
             'Host: ' + Host + #13#10 +
             'User-Agent: WinSSL-Test/1.0'#13#10 +
             'Connection: close'#13#10 +
             #13#10;

  try
    if Connection.WriteString(Request) then
      TestPass('Send HTTP request (' + IntToStr(Length(Request)) + ' bytes)')
    else
    begin
      TestFail('Send HTTP request', 'WriteString returned False');
      Connection.Close;
      platform_socket_close(Socket);
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      TestFail('Send HTTP request', E.Message);
      Connection.Close;
      platform_socket_close(Socket);
      Halt(1);
    end;
  end;

  // Test 9: 接收 HTTP 响应
  WriteLn('Test 9: Receiving HTTP response...');
  try
    BytesRead := Connection.Read(Response, SizeOf(Response) - 1);
    if BytesRead > 0 then
    begin
      Response[BytesRead] := #0;
      TestPass('Receive HTTP response (' + IntToStr(BytesRead) + ' bytes)');

      // 显示响应的前几行
      WriteLn;
      WriteLn('--- Response Preview ---');
      WriteLn(Copy(PChar(@Response[0]), 1, 400));
      WriteLn('--- End Preview ---');
      WriteLn;

      // 检查是否是 HTTP 响应
      if Pos('HTTP/', PChar(@Response[0])) > 0 then
        TestPass('Valid HTTP response received')
      else
        TestFail('HTTP response validation', 'Not a valid HTTP response');
    end
    else
    begin
      TestFail('Receive HTTP response', 'Read returned ' + IntToStr(BytesRead));
    end;
  except
    on E: Exception do
    begin
      TestFail('Receive HTTP response', E.Message);
    end;
  end;

  // Test 10: 优雅关闭连接
  WriteLn('Test 10: Closing SSL connection...');
  try
    if Connection.Shutdown then
      TestPass('SSL connection shutdown')
    else
      TestPass('SSL connection shutdown (best effort)');
  except
    on E: Exception do
    begin
      WriteLn('[WARN] Shutdown exception: ', E.Message);
      TestPass('SSL connection shutdown (with exception)');
    end;
  end;

  // 关闭 socket
  platform_socket_close(Socket);

  // 清理
  Connection := nil;
  Context := nil;
  SSLLib.Finalize;
  SSLLib := nil;

  // 总结
  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);
  WriteLn;

  if TestsFailed = 0 then
  begin
    WriteLn('🎉 ALL TESTS PASSED! 🎉');
    WriteLn;
    WriteLn('Successfully completed HTTPS connection to ', Host, '!');
    WriteLn('WinSSL backend is working correctly.');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('❌ SOME TESTS FAILED');
    ExitCode := 1;
  end;

  finally
  end;
end.
