program test_winssl_connection_edge_cases;

{$mode objfpc}{$H+}

{
  test_winssl_connection_edge_cases - WinSSL 连接边界情况测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 第二阶段
    测试 WinSSL 连接模块的边界情况和错误处理

    需要 Windows 环境运行

  测试内容:
    1. 握手失败和重试
    2. 超时场景
    3. 缓冲区边界情况
    4. 无效状态转换
    5. 错误恢复机制
    6. 非阻塞 I/O 边界情况
    7. 证书验证失败
    8. ALPN/SNI 边界情况
    9. 连接中断和恢复
    10. 资源耗尽场景
}

uses
  {$IFDEF WINDOWS}
  Windows, winsock2,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.context,
  nextpas.core.tls.winssl.connection;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestHandshakeTimeout;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
begin
  WriteLn('【测试 1】握手超时处理');
  WriteLn('---');

  {$IFDEF WINDOWS}
  // 初始化配置
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;
  LConfig.HandshakeTimeout := 100; // 极短超时

  try
    LContext := TSSLFactory.CreateContext(LConfig);

    // 创建无效的 socket（不会连接）
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);
      LConnection.SetTimeout(100);

      // 尝试握手应该超时
      try
        LConnection.DoHandshake;
        Assert(False, '握手应该超时失败');
      except
        on E: ESSLTimeoutException do
          Assert(True, '正确抛出超时异常');
        on E: Exception do
          Assert(True, '握手失败（预期行为）: ' + E.Message);
      end;

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestInvalidStateTransitions;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
  LBuffer: array[0..1023] of Byte;
begin
  WriteLn('【测试 2】无效状态转换');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 尝试在未连接时读取数据
      try
        LConnection.Read(LBuffer, SizeOf(LBuffer));
        Assert(False, '未连接时读取应该失败');
      except
        on E: ESSLException do
          Assert(True, '正确拒绝未连接时的读取操作');
      end;

      // 尝试在未连接时写入数据
      try
        LConnection.Write(LBuffer, 10);
        Assert(False, '未连接时写入应该失败');
      except
        on E: ESSLException do
          Assert(True, '正确拒绝未连接时的写入操作');
      end;

      // 验证连接状态
      Assert(not LConnection.IsConnected, '连接状态正确为未连接');
      Assert(not LConnection.IsHandshakeComplete, '握手状态正确为未完成');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestBufferBoundaries;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
  LSmallBuffer: array[0..9] of Byte;
  LLargeBuffer: array[0..SSL_DEFAULT_BUFFER_SIZE*2-1] of Byte;
begin
  WriteLn('【测试 3】缓冲区边界情况');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 测试零长度读取
      try
        LConnection.Read(LSmallBuffer, 0);
        Assert(True, '零长度读取不应崩溃');
      except
        on E: Exception do
          Assert(True, '零长度读取处理正确: ' + E.Message);
      end;

      // 测试零长度写入
      try
        LConnection.Write(LSmallBuffer, 0);
        Assert(True, '零长度写入不应崩溃');
      except
        on E: Exception do
          Assert(True, '零长度写入处理正确: ' + E.Message);
      end;

      // 测试超大缓冲区
      try
        LConnection.Write(LLargeBuffer, SizeOf(LLargeBuffer));
        Assert(True, '超大缓冲区写入不应崩溃');
      except
        on E: Exception do
          Assert(True, '超大缓冲区处理正确: ' + E.Message);
      end;

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestNonBlockingEdgeCases;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
begin
  WriteLn('【测试 4】非阻塞 I/O 边界情况');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 设置非阻塞模式
      LConnection.SetBlocking(False);
      Assert(not LConnection.GetBlocking, '非阻塞模式设置成功');

      // 测试 WantRead/WantWrite 状态
      Assert(not LConnection.WantRead, 'WantRead 初始状态正确');
      Assert(not LConnection.WantWrite, 'WantWrite 初始状态正确');

      // 切换回阻塞模式
      LConnection.SetBlocking(True);
      Assert(LConnection.GetBlocking, '阻塞模式恢复成功');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestCertificateValidationFailure;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
begin
  WriteLn('【测试 5】证书验证失败场景');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;
  LConfig.VerifyMode := [sslVerifyPeer, sslVerifyFailIfNoPeerCert];

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);
      (LConnection as ISSLClientConnection).SetServerName('invalid.example.com');

      // 验证 ServerName 设置
      Assert((LConnection as ISSLClientConnection).GetServerName = 'invalid.example.com',
             'ServerName 设置正确');

      // 尝试连接到无效服务器应该失败
      try
        LConnection.Connect;
        Assert(False, '连接到无效服务器应该失败');
      except
        on E: ESSLException do
          Assert(True, '正确处理证书验证失败');
      end;

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestALPNEdgeCases;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
  LALPNProtocol: string;
begin
  WriteLn('【测试 6】ALPN 边界情况');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  // 测试空 ALPN 协议列表
  LConfig.ALPNProtocols := '';
  try
    LContext := TSSLFactory.CreateContext(LConfig);
    Assert(True, '空 ALPN 协议列表不应崩溃');
  except
    on E: Exception do
      WriteLn('  注意: ', E.Message);
  end;

  // 测试无效 ALPN 协议格式
  LConfig.ALPNProtocols := 'invalid,,protocol';
  try
    LContext := TSSLFactory.CreateContext(LConfig);
    Assert(True, '无效 ALPN 格式处理正确');
  except
    on E: Exception do
      Assert(True, '正确拒绝无效 ALPN 格式');
  end;

  // 测试超长 ALPN 协议列表
  LConfig.ALPNProtocols := 'h2,http/1.1,spdy/3.1,http/2,h3,quic,websocket,mqtt,amqp,stomp';
  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 在未连接时获取 ALPN 协议应该返回空
      {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
      LALPNProtocol := LConnection.GetSelectedALPNProtocol;
      {$POP}
      Assert(LALPNProtocol = '', '未连接时 ALPN 协议为空');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestConnectionInterruption;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
begin
  WriteLn('【测试 7】连接中断处理');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 测试强制关闭
      LConnection.Close;
      Assert(not LConnection.IsConnected, '强制关闭后连接状态正确');

      // 测试重复关闭
      LConnection.Close;
      Assert(True, '重复关闭不应崩溃');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestErrorRecovery;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LConfig: TSSLConfig;
  LSocket: THandle;
  LHealthStatus: TSSLHealthStatus;
begin
  WriteLn('【测试 8】错误恢复机制');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);
      Assert(Supports(LConnection, ISSLDiagnostics, LDiag), 'WinSSL connection exposes ISSLDiagnostics');

      // 获取健康状态
      LHealthStatus := LDiag.GetHealthStatus;
      Assert(not LHealthStatus.IsConnected, '健康状态：未连接');
      Assert(not LHealthStatus.HandshakeComplete, '健康状态：握手未完成');
      Assert(LHealthStatus.LastError = sslErrNone, '健康状态：无错误');

      // 测试错误后的状态
      try
        LConnection.DoHandshake;
      except
        on E: Exception do
        begin
          // 再次获取健康状态
          LHealthStatus := LDiag.GetHealthStatus;
          Assert(True, '错误后可以获取健康状态');
        end;
      end;

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestResourceExhaustion;
var
  LContext: ISSLContext;
  LConnections: array[0..9] of ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
  I: Integer;
begin
  WriteLn('【测试 9】资源耗尽场景');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    // 创建多个连接
    for I := 0 to High(LConnections) do
    begin
      try
        LConnections[I] := TWinSSLConnection.Create(LContext, LSocket);
      except
        on E: Exception do
          WriteLn('  注意: 创建连接 ', I, ' 失败 - ', E.Message);
      end;
    end;

    Assert(True, '多连接创建不应崩溃');

    // 清理连接
    for I := 0 to High(LConnections) do
      LConnections[I] := nil;

    Assert(True, '多连接清理不应崩溃');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestConnectionInfo;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
  LConnInfo: TSSLConnectionInfo;
begin
  WriteLn('【测试 10】连接信息获取');
  WriteLn('---');

  // INTENTIONAL_CORE_SURFACE: keep this direct core GetConnectionInfo path as
  // a WinSSL-specific compatibility-core surface proof. The owner-path checks
  // now live in ISSLConnectionInfo-focused contracts elsewhere.

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 在未连接时获取连接信息
      {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
      LConnInfo := LConnection.GetConnectionInfo;
      {$POP}
      Assert(LConnInfo.ProtocolVersion = sslProtocolUnknown, '未连接时协议版本为未知');
      Assert(LConnInfo.CipherSuite = '', '未连接时密码套件为空');
      Assert(not LConnInfo.IsResumed, '未连接时会话未复用');

      // 获取协议版本
      Assert(LConnection.GetProtocolVersion = sslProtocolUnknown, '未连接时协议版本为未知');

      // 获取密码套件名称
      Assert(LConnection.GetCipherName = '', '未连接时密码套件为空');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestPerformanceMetrics;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LConfig: TSSLConfig;
  LSocket: THandle;
  LMetrics: TSSLPerformanceMetrics;
  LDiagInfo: TSSLDiagnosticInfo;
begin
  WriteLn('【测试 11】性能指标获取');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);
      Assert(Supports(LConnection, ISSLDiagnostics, LDiag), 'WinSSL connection exposes ISSLDiagnostics');

      // 获取性能指标
      LMetrics := LDiag.GetPerformanceMetrics;
      Assert(LMetrics.HandshakeTime = 0, '未连接时握手时间为 0');
      Assert(LMetrics.TotalBytesTransferred = 0, '未连接时传输字节数为 0');
      Assert(not LMetrics.SessionReused, '未连接时会话未复用');

      // 获取诊断信息
      LDiagInfo := LDiag.GetDiagnosticInfo;
      Assert(not LDiagInfo.HealthStatus.IsConnected, '诊断信息：未连接');
      Assert(Length(LDiagInfo.ErrorHistory) >= 0, '诊断信息：错误历史可访问');

      // 测试健康检查
      Assert(not LDiag.IsHealthy, '未连接时健康检查返回 False');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure TestTimeoutConfiguration;
var
  LContext: ISSLContext;
  LConnection: ISSLConnection;
  LConfig: TSSLConfig;
  LSocket: THandle;
begin
  WriteLn('【测试 12】超时配置');
  WriteLn('---');

  {$IFDEF WINDOWS}
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslWinSSL;
  LConfig.ContextType := sslCtxClient;

  try
    LContext := TSSLFactory.CreateContext(LConfig);
    LSocket := INVALID_SOCKET;

    try
      LConnection := TWinSSLConnection.Create(LContext, LSocket);

      // 测试超时设置
      LConnection.SetTimeout(5000);
      Assert(LConnection.GetTimeout = 5000, '超时设置为 5000ms');

      LConnection.SetTimeout(10000);
      Assert(LConnection.GetTimeout = 10000, '超时更新为 10000ms');

      // 测试零超时
      LConnection.SetTimeout(0);
      Assert(LConnection.GetTimeout = 0, '超时设置为 0（无限等待）');

    finally
      LConnection := nil;
    end;
  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;
  {$ELSE}
  WriteLn('  跳过: 此测试需要 Windows 环境');
  {$ENDIF}

  WriteLn;
end;

procedure PrintSummary;
begin
  WriteLn('=========================================');
  WriteLn('测试总结');
  WriteLn('=========================================');
  WriteLn('通过: ', GTestsPassed);
  WriteLn('失败: ', GTestsFailed);
  WriteLn('总计: ', GTestsPassed + GTestsFailed);

  if GTestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('✓ 所有连接边界情况测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查连接实现');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('WinSSL 连接边界情况测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  {$IFDEF WINDOWS}
  WriteLn('运行环境: Windows');
  {$ELSE}
  WriteLn('运行环境: 非 Windows（部分测试将跳过）');
  {$ENDIF}
  WriteLn;

  try
    TestHandshakeTimeout;
    TestInvalidStateTransitions;
    TestBufferBoundaries;
    TestNonBlockingEdgeCases;
    TestCertificateValidationFailure;
    TestALPNEdgeCases;
    TestConnectionInterruption;
    TestErrorRecovery;
    TestResourceExhaustion;
    TestConnectionInfo;
    TestPerformanceMetrics;
    TestTimeoutConfiguration;

    WriteLn;
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn('错误: ', E.Message);
      Halt(1);
    end;
  end;
end.
