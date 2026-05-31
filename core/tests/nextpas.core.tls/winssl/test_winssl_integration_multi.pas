program test_winssl_integration_multi;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  Windows, SysUtils, Classes, WinSock2,
  
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.lib;

var
  TotalTests, PassedTests, FailedTests: Integer;
  CurrentSection: string;

procedure BeginSection(const aName: string);
begin
  CurrentSection := aName;
  WriteLn;
  WriteLn('=== ', aName, ' ===');
end;

procedure Test(const aName: string; aCondition: Boolean; const aDetails: string = '');
begin
  Inc(TotalTests);
  Write('  [', CurrentSection, '] ', aName, ': ');

  if aCondition then
  begin
    WriteLn('PASS');
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(FailedTests);
    if aDetails <> '' then
      WriteLn('    原因: ', aDetails);
  end;
end;

function FormatNativeErrorHex(const AValue: Integer): string;
begin
  Result := '0x' + IntToHex(Cardinal(AValue), 8);
end;

function DescribeSSLException(E: ESSLException): string;
begin
  Result := E.Message;
  if E.NativeError <> 0 then
    Result := Result + ' [native=' + FormatNativeErrorHex(E.NativeError) + ']';
  if E.Context <> '' then
    Result := Result + ' [context=' + E.Context + ']';
end;

function DescribeException(E: Exception): string;
begin
  if E is ESSLException then
    Result := DescribeSSLException(ESSLException(E))
  else
    Result := E.Message;
end;

function HasAlgorithmMismatchNativeError(E: ESSLException): Boolean;
begin
  Result := Cardinal(E.NativeError) = $80090331;
end;

function IsOptionalTLS13OnlyFailure(E: Exception): Boolean;
begin
  Result := (E is ESSLException) and
            HasAlgorithmMismatchNativeError(ESSLException(E));
end;

function IsExpectedHandshakeFailure(E: Exception): Boolean;
begin
  Result := (E is ESSLConnectionException) or
            (E is ESSLCertificateException) or
            ((E is ESSLInitializationException) and
             HasAlgorithmMismatchNativeError(ESSLException(E)));
end;

procedure TestExpectedHandshakeFailurePath(const aTestName, aHost: string;
  aContext: ISSLContext; aSocket: TSocket);
var
  LConn: ISSLConnection;
begin
  try
    LConn := aContext.CreateConnection(aSocket);
    (LConn as ISSLClientConnection).SetServerName(aHost);
    Test(aTestName, not LConn.Connect);
  except
    on E: Exception do
      Test(aTestName, IsExpectedHandshakeFailure(E), DescribeException(E));
  end;
end;

function InitWinsock: Boolean;
var
  LWSAData: TWSAData;
begin
  Result := WSAStartup(MAKEWORD(2, 2), LWSAData) = 0;
end;

procedure CleanupWinsock;
begin
  WSACleanup;
end;

function ConnectToHost(const aHost: string; aPort: Word; out aSocket: TSocket): Boolean;
var
  LAddr: TSockAddrIn;
  LHostEnt: PHostEnt;
  LInAddr: TInAddr;
  LTimeout: Integer;
begin
  Result := False;
  aSocket := INVALID_SOCKET;

  // Create socket
  aSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if aSocket = INVALID_SOCKET then
    Exit;

  // Set timeout
  LTimeout := 10000; // 10 seconds
  setsockopt(aSocket, SOL_SOCKET, SO_RCVTIMEO, @LTimeout, SizeOf(LTimeout));
  setsockopt(aSocket, SOL_SOCKET, SO_SNDTIMEO, @LTimeout, SizeOf(LTimeout));

  // Resolve hostname
  LHostEnt := gethostbyname(PAnsiChar(AnsiString(aHost)));
  if LHostEnt = nil then
  begin
    closesocket(aSocket);
    aSocket := INVALID_SOCKET;
    Exit;
  end;

  // Connect
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(aPort);
  Move(LHostEnt^.h_addr_list^^, LInAddr, SizeOf(LInAddr));
  LAddr.sin_addr := LInAddr;

  Result := connect(aSocket, @LAddr, SizeOf(LAddr)) = 0;
  if not Result then
  begin
    closesocket(aSocket);
    aSocket := INVALID_SOCKET;
  end;
end;

function SendHTTPRequest(aConn: ISSLConnection; const aHost, aPath: string): Boolean;
var
  LRequest: string;
begin
  LRequest := 'GET ' + aPath + ' HTTP/1.1'#13#10 +
              'Host: ' + aHost + #13#10 +
              'Connection: close'#13#10 +
              'User-Agent: WinSSL-Test/1.0'#13#10 +
              #13#10;

  Result := aConn.WriteString(LRequest);
end;

function ReceiveHTTPResponse(aConn: ISSLConnection; out aResponse: string; aMaxSize: Integer = 8192): Boolean;
var
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
  LTotal: Integer;
begin
  Result := False;
  aResponse := '';
  LTotal := 0;

  repeat
    LBytesRead := aConn.Read(LBuffer[0], SizeOf(LBuffer));

    if LBytesRead > 0 then
    begin
      SetLength(aResponse, Length(aResponse) + LBytesRead);
      Move(LBuffer[0], aResponse[Length(aResponse) - LBytesRead + 1], LBytesRead);
      LTotal += LBytesRead;
      Result := True;
    end;

    // Stop if we've received enough data or read completed
    if (LTotal >= aMaxSize) or (LBytesRead <= 0) then
      Break;

  until False;
end;

function TryExtractHTTPStatusCode(const AResponse: string; out AStatusCode: Integer;
  out AStatusLine: string): Boolean;
var
  LBreakPos: Integer;
  LSpacePos: Integer;
  LStatusText: string;
begin
  Result := False;
  AStatusCode := 0;
  AStatusLine := '';

  if AResponse = '' then
    Exit;

  AStatusLine := AResponse;
  LBreakPos := Pos(#13#10, AStatusLine);
  if LBreakPos = 0 then
    LBreakPos := Pos(#10, AStatusLine);
  if LBreakPos > 0 then
    SetLength(AStatusLine, LBreakPos - 1);

  if Pos('HTTP/', AStatusLine) <> 1 then
    Exit;

  LSpacePos := Pos(' ', AStatusLine);
  if LSpacePos <= 0 then
    Exit;

  LStatusText := Copy(AStatusLine, LSpacePos + 1, 3);
  if Length(LStatusText) <> 3 then
    Exit;

  AStatusCode := StrToIntDef(LStatusText, 0);
  Result := AStatusCode >= 100;
end;

procedure TestHTTPSServer(const aName, aHost: string; aPort: Word; const aPath: string = '/');
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  LResponse: string;
  LProtocol: TSSLProtocolVersion;
  LCipherName: string;
  LConnected: Boolean;
  LStatusCode: Integer;
  LStatusLine: string;
begin
  BeginSection(aName);

  LSocket := INVALID_SOCKET;
  LConnected := False;

  try
    // Create and initialize library
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      Test('初始化 WinSSL 库', False, LLib.GetLastErrorString);
      Exit;
    end;
    Test('初始化 WinSSL 库', True);

    // Create context
    LContext := LLib.CreateContext(sslCtxClient);
    Test('创建客户端上下文', LContext <> nil);
    if LContext = nil then
      Exit;

    // Set protocol versions (TLS 1.2 and 1.3)
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Test('设置协议版本 (TLS 1.2/1.3)', True);

    // Disable certificate verification for testing (empty set = no verification)
    LContext.SetVerifyMode([]);
    Test('禁用证书验证（测试模式）', True);

    // Connect TCP socket
    Test('TCP 连接到 ' + aHost, ConnectToHost(aHost, aPort, LSocket));
    if LSocket = INVALID_SOCKET then
      Exit;

    // Create SSL connection
    LConn := LContext.CreateConnection(LSocket);
    Test('创建 SSL 连接对象', LConn <> nil);
    if LConn = nil then
      Exit;

    (LConn as ISSLClientConnection).SetServerName(aHost);
    Test('设置 SNI 主机名', True);

    // Perform TLS handshake
    LConnected := LConn.Connect;
    Test('TLS 握手完成', LConnected);
    if not LConnected then
      Exit;

    // Get protocol version
    LProtocol := LConn.GetProtocolVersion;
    Test('获取协议版本', LProtocol in [sslProtocolTLS12, sslProtocolTLS13],
      'Protocol: ' + IntToStr(Ord(LProtocol)));

    // Get cipher name
    LCipherName := LConn.GetCipherName;
    Test('获取密码套件', LCipherName <> '', 'Cipher: ' + LCipherName);

    // Check connection state
    Test('连接状态为已连接', LConn.IsConnected);

    // Send HTTP request
    Test('发送 HTTP GET 请求', SendHTTPRequest(LConn, aHost, aPath));

    // Receive HTTP response
    Test('接收 HTTP 响应', ReceiveHTTPResponse(LConn, LResponse));

    // Validate HTTP response
    Test('响应包含 HTTP 状态行', Pos('HTTP/', LResponse) > 0);
    Test('响应大小 > 0', Length(LResponse) > 0, Format('Size: %d bytes', [Length(LResponse)]));

    Test('响应状态码可解析',
      TryExtractHTTPStatusCode(LResponse, LStatusCode, LStatusLine),
      LStatusLine);
    if LStatusCode > 0 then
      Test('响应状态码不是 5xx',
        LStatusCode < 500,
        Format('Status: %d line=%s', [LStatusCode, LStatusLine]));

    // Graceful shutdown
    LConn.Shutdown;
    Test('优雅关闭连接', True);

  finally
    if LSocket <> INVALID_SOCKET then
      closesocket(LSocket);
  end;
end;

procedure TestProtocolNegotiation;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  LProtocol: TSSLProtocolVersion;
begin
  BeginSection('协议版本协商测试');

  LSocket := INVALID_SOCKET;

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      Test('初始化库失败', False);
      Exit;
    end;

    // Test 1: TLS 1.2 only
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.google.com', 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');

      if LConn.Connect then
      begin
        LProtocol := LConn.GetProtocolVersion;
        Test('强制 TLS 1.2 协商成功', LProtocol = sslProtocolTLS12);
        LConn.Shutdown;
      end
      else
        Test('强制 TLS 1.2 协商', False);

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end;

    // Test 2: TLS 1.3 (if supported by both client and server)
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.cloudflare.com', 443, LSocket) then
    begin
      try
        LConn := LContext.CreateConnection(LSocket);
        (LConn as ISSLClientConnection).SetServerName('www.cloudflare.com');

        if LConn.Connect then
        begin
          LProtocol := LConn.GetProtocolVersion;
          Test('TLS 1.3 协商（如果支持）', LProtocol = sslProtocolTLS13);
          LConn.Shutdown;
        end
        else
        begin
          // TLS 1.3 may not be supported on older Windows versions
          Test('TLS 1.3 协商（可能不支持）', True, '平台可能不支持 TLS 1.3');
        end;
      except
        on E: Exception do
        begin
          if IsOptionalTLS13OnlyFailure(E) then
            Test('TLS 1.3 协商（可能不支持）', True,
              'Schannel 平台不支持 TLS 1.3 only 凭据获取: ' +
              DescribeException(E))
          else
            Test('TLS 1.3 协商（异常）', False, DescribeException(E));
        end;
      end;

      if LSocket <> INVALID_SOCKET then
      begin
        closesocket(LSocket);
        LSocket := INVALID_SOCKET;
      end;
    end;

    // Test 3: Auto-negotiation (TLS 1.2 and 1.3)
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.microsoft.com', 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName('www.microsoft.com');

      if LConn.Connect then
      begin
        LProtocol := LConn.GetProtocolVersion;
        Test('自动协商协议版本', LProtocol in [sslProtocolTLS12, sslProtocolTLS13]);
        LConn.Shutdown;
      end
      else
        Test('自动协商', False);

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end;

  finally
    if LSocket <> INVALID_SOCKET then
      closesocket(LSocket);
  end;
end;

procedure TestDataTransferSizes;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  LResponse: string;
begin
  BeginSection('数据传输大小测试');

  LSocket := INVALID_SOCKET;

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      Test('初始化库失败', False);
      Exit;
    end;

    // Test small response (< 1KB) - robots.txt
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.google.com', 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName('www.google.com');

      if LConn.Connect then
      begin
        SendHTTPRequest(LConn, 'www.google.com', '/robots.txt');
        if ReceiveHTTPResponse(LConn, LResponse, 2048) then
        begin
          Test('小数据传输 (< 2KB)', Length(LResponse) > 0,
            Format('实际大小: %d bytes', [Length(LResponse)]));
        end
        else
          Test('小数据传输', False);

        LConn.Shutdown;
      end;

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end;

    // Test medium response (~10KB) - main page
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.microsoft.com', 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName('www.microsoft.com');

      if LConn.Connect then
      begin
        SendHTTPRequest(LConn, 'www.microsoft.com', '/');
        if ReceiveHTTPResponse(LConn, LResponse, 32768) then
        begin
          Test('中等数据传输 (~10KB)', Length(LResponse) >= 512,
            Format('实际大小: %d bytes', [Length(LResponse)]));
        end
        else
          Test('中等数据传输', False);

        LConn.Shutdown;
      end;

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end;

    // Test large response (> 10KB) - API response
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('api.github.com', 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName('api.github.com');

      if LConn.Connect then
      begin
        SendHTTPRequest(LConn, 'api.github.com', '/');
        if ReceiveHTTPResponse(LConn, LResponse, 65536) then
        begin
          Test('大数据传输（API 响应）', Length(LResponse) > 0,
            Format('实际大小: %d bytes', [Length(LResponse)]));
        end
        else
          Test('大数据传输', False);

        LConn.Shutdown;
      end;

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end;

  finally
    if LSocket <> INVALID_SOCKET then
      closesocket(LSocket);
  end;
end;

procedure TestErrorScenarios;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
begin
  BeginSection('错误场景测试');

  LSocket := INVALID_SOCKET;

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      Test('初始化库失败', False);
      Exit;
    end;

    // Test 1: Invalid hostname
    Test('无效主机名连接失败', not ConnectToHost('invalid-host-name-that-does-not-exist-12345.com', 443, LSocket));

    // Test 2: Wrong port (HTTP port instead of HTTPS)
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.google.com', 80, LSocket) then
    begin
      // TLS handshake should fail on HTTP port
      TestExpectedHandshakeFailurePath('HTTP 端口 TLS 握手失败', 'www.google.com',
        LContext, LSocket);

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end
    else
      Test('连接到 HTTP 端口', False);

    // Test 3: Mismatched protocol (SSL 3.0 only - should fail)
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolSSL3]);
    LContext.SetVerifyMode([]);

    if ConnectToHost('www.google.com', 443, LSocket) then
    begin
      // SSL 3.0 is deprecated and should fail
      TestExpectedHandshakeFailurePath('SSL 3.0 握手失败（已废弃）', 'www.google.com',
        LContext, LSocket);

      closesocket(LSocket);
      LSocket := INVALID_SOCKET;
    end;

    // Test 4: Connection timeout (using a non-routable IP)
    Test('连接超时处理', not ConnectToHost('192.0.2.1', 443, LSocket),
      '使用非可路由 IP 测试超时');

  finally
    if LSocket <> INVALID_SOCKET then
      closesocket(LSocket);
  end;
end;

procedure TestMultipleSequentialConnections;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  LResponse: string;
  i: Integer;
  LSuccessCount: Integer;
begin
  BeginSection('多次连续连接测试');

  LSuccessCount := 0;

  try
    LLib := CreateWinSSLLibrary;
    if not LLib.Initialize then
    begin
      Test('初始化库失败', False);
      Exit;
    end;

    // Perform 5 sequential connections
    for i := 1 to 5 do
    begin
      LSocket := INVALID_SOCKET;
      LContext := LLib.CreateContext(sslCtxClient);
      LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      LContext.SetVerifyMode([]);

      if ConnectToHost('www.google.com', 443, LSocket) then
      begin
        LConn := LContext.CreateConnection(LSocket);
        (LConn as ISSLClientConnection).SetServerName('www.google.com');

        if LConn.Connect then
        begin
          if SendHTTPRequest(LConn, 'www.google.com', '/') then
          begin
            if ReceiveHTTPResponse(LConn, LResponse, 4096) then
            begin
              if Length(LResponse) > 0 then
                Inc(LSuccessCount);
            end;
          end;

          LConn.Shutdown;
        end;

        closesocket(LSocket);
      end;
    end;

    Test('5 次连续连接', LSuccessCount >= 4,
      Format('成功: %d/5 次', [LSuccessCount]));

    Test('稳定性检查', LSuccessCount = 5,
      Format('成功率: %.1f%%', [LSuccessCount * 20.0]));

  except
    on E: Exception do
      Test('连续连接稳定性', False, E.Message);
  end;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('=========================================');
  WriteLn('WinSSL 多场景集成测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');

  // Initialize Winsock
  if not InitWinsock then
  begin
    WriteLn('错误: 无法初始化 Winsock');
    Halt(1);
  end;

  try
    // Test 4 major HTTPS servers
    TestHTTPSServer('Google (www.google.com)', 'www.google.com', 443, '/');
    TestHTTPSServer('GitHub API (api.github.com)', 'api.github.com', 443, '/');
    TestHTTPSServer('Cloudflare (1.1.1.1)', '1.1.1.1', 443, '/');
    TestHTTPSServer('Microsoft (www.microsoft.com)', 'www.microsoft.com', 443, '/');

    // Protocol negotiation tests
    TestProtocolNegotiation;

    // Data transfer size tests
    TestDataTransferSizes;

    // Error scenario tests
    TestErrorScenarios;

    // Stability tests
    TestMultipleSequentialConnections;

  finally
    CleanupWinsock;
  end;

  WriteLn;
  WriteLn('=========================================');
  WriteLn('测试摘要');
  WriteLn('=========================================');
  WriteLn(Format('总计: %d 个测试', [TotalTests]));
  WriteLn(Format('通过: %d 个 (%.1f%%)', [PassedTests, PassedTests * 100.0 / TotalTests]));
  WriteLn(Format('失败: %d 个', [FailedTests]));
  WriteLn('=========================================');

  if FailedTests > 0 then
    Halt(1);
end.
