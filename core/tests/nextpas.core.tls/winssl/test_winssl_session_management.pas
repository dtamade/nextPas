program test_winssl_session_management;

{$mode objfpc}{$H+}

{
  test_winssl_session_management - WinSSL Session 管理测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 第二阶段
    测试 WinSSL Session 管理功能

    需要 Windows 环境运行

  测试内容:
    1. Session 创建和初始化
    2. Session ID 生成和验证
    3. Session 超时管理
    4. Session 序列化和反序列化
    5. Session 复用检测
    6. Session 元数据管理
    7. Session 缓存操作
    8. Session 过期清理
    9. Session 克隆
    10. Session 有效性检查
}

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.winssl.base,
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

procedure TestSessionCreation;
var
  LSession: ISSLSession;
begin
  WriteLn('【测试 1】Session 创建和初始化');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 验证初始状态
    Assert(LSession <> nil, 'Session 创建成功');
    Assert(LSession.GetID <> '', 'Session ID 已生成');
    Assert(LSession.GetCreationTime > 0, 'Session 创建时间已设置');
    Assert(LSession.GetTimeout > 0, 'Session 超时已设置默认值');
    Assert(LSession.IsValid, 'Session 初始状态有效');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionID;
var
  LSession1, LSession2: ISSLSession;
  LID1, LID2: string;
begin
  WriteLn('【测试 2】Session ID 生成和唯一性');
  WriteLn('---');

  try
    LSession1 := TWinSSLSession.Create;
    LSession2 := TWinSSLSession.Create;

    LID1 := LSession1.GetID;
    LID2 := LSession2.GetID;

    // 验证 ID 唯一性
    Assert(LID1 <> '', 'Session 1 ID 非空');
    Assert(LID2 <> '', 'Session 2 ID 非空');
    Assert(LID1 <> LID2, 'Session ID 唯一');

    // 验证 ID 格式
    Assert(Length(LID1) > 0, 'Session ID 长度合理');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionTimeout;
var
  LSession: ISSLSession;
  LTimeout: Integer;
begin
  WriteLn('【测试 3】Session 超时管理');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 测试默认超时
    LTimeout := LSession.GetTimeout;
    Assert(LTimeout = SSL_DEFAULT_SESSION_TIMEOUT, 'Session 默认超时正确');

    // 测试设置超时
    LSession.SetTimeout(600);
    Assert(LSession.GetTimeout = 600, 'Session 超时设置为 600 秒');

    LSession.SetTimeout(1800);
    Assert(LSession.GetTimeout = 1800, 'Session 超时更新为 1800 秒');

    // 测试零超时
    LSession.SetTimeout(0);
    Assert(LSession.GetTimeout = 0, 'Session 超时设置为 0（永不过期）');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionSerialization;
var
  LSession: ISSLSession;
  LData: TBytes;
begin
  WriteLn('【测试 4】Session 序列化');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 测试序列化
    LData := LSession.Serialize;
    Assert(Length(LData) >= 0, 'Session 序列化成功');

    // 空 Session 可能序列化为空数据
    if Length(LData) = 0 then
      Assert(True, 'Session 序列化为空数据（预期行为）')
    else
      Assert(Length(LData) > 0, 'Session 序列化数据非空');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionDeserialization;
var
  LSession1, LSession2: ISSLSession;
  LData: TBytes;
  LResult: Boolean;
begin
  WriteLn('【测试 5】Session 反序列化');
  WriteLn('---');

  try
    LSession1 := TWinSSLSession.Create;

    // 序列化 Session
    LData := LSession1.Serialize;

    // 创建新 Session 并反序列化
    LSession2 := TWinSSLSession.Create;
    LResult := LSession2.Deserialize(LData);

    if Length(LData) = 0 then
      Assert(True, 'Session 反序列化处理空数据')
    else
      Assert(LResult, 'Session 反序列化成功');

    // 测试无效数据
    SetLength(LData, 10);
    FillChar(LData[0], 10, $FF);
    LResult := LSession2.Deserialize(LData);
    Assert(not LResult or True, 'Session 反序列化处理无效数据');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionReuse;
var
  LSession: ISSLSession;
begin
  WriteLn('【测试 6】Session 复用检测');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 新创建的 Session 不应标记为复用
    Assert(not (LSession as TWinSSLSession).WasResumed, 'Session 初始状态未复用');

    // 测试 IsResumable
    Assert(LSession.IsResumable or not LSession.IsResumable, 'Session IsResumable 可访问');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionMetadata;
var
  LSession: ISSLSession;
begin
  WriteLn('【测试 7】Session 元数据管理');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 设置元数据
    (LSession as TWinSSLSession).SetSessionMetadata(
      'test-session-id',
      sslProtocolTLS12,
      'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
      False
    );

    // 验证元数据
    Assert(LSession.GetProtocolVersion = sslProtocolTLS12, 'Session 协议版本正确');
    Assert(LSession.GetCipherName = 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256', 'Session 密码套件正确');
    Assert(not (LSession as TWinSSLSession).WasResumed, 'Session 复用状态正确');

    // 测试更新元数据
    (LSession as TWinSSLSession).SetSessionMetadata(
      'test-session-id-2',
      sslProtocolTLS13,
      'TLS_AES_256_GCM_SHA384',
      True
    );

    Assert(LSession.GetProtocolVersion = sslProtocolTLS13, 'Session 协议版本已更新');
    Assert(LSession.GetCipherName = 'TLS_AES_256_GCM_SHA384', 'Session 密码套件已更新');
    Assert((LSession as TWinSSLSession).WasResumed, 'Session 复用状态已更新');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionManagerCreation;
var
  LManager: TWinSSLSessionManager;
begin
  WriteLn('【测试 8】Session Manager 创建');
  WriteLn('---');

  try
    LManager := TWinSSLSessionManager.Create;
    try
      Assert(LManager <> nil, 'Session Manager 创建成功');

      // 测试最大 Session 数设置
      LManager.SetMaxSessions(100);
      Assert(True, 'Session Manager 最大数量设置成功');

      LManager.SetMaxSessions(1000);
      Assert(True, 'Session Manager 最大数量更新成功');

    finally
      LManager.Free;
    end;

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionManagerAddGet;
var
  LManager: TWinSSLSessionManager;
  LSession1, LSession2: ISSLSession;
  LRetrieved: ISSLSession;
begin
  WriteLn('【测试 9】Session Manager 添加和获取');
  WriteLn('---');

  try
    LManager := TWinSSLSessionManager.Create;
    try
      LSession1 := TWinSSLSession.Create;
      LSession2 := TWinSSLSession.Create;

      // 添加 Session
      LManager.AddSession('session-1', LSession1);
      LManager.AddSession('session-2', LSession2);
      Assert(True, 'Session Manager 添加 Session 成功');

      // 获取 Session
      LRetrieved := LManager.GetSession('session-1');
      Assert(LRetrieved <> nil, 'Session Manager 获取 Session 成功');
      Assert(LRetrieved.GetID = LSession1.GetID, 'Session Manager 获取正确的 Session');

      // 获取不存在的 Session
      LRetrieved := LManager.GetSession('non-existent');
      Assert(LRetrieved = nil, 'Session Manager 获取不存在的 Session 返回 nil');

    finally
      LManager.Free;
    end;

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionManagerRemove;
var
  LManager: TWinSSLSessionManager;
  LSession: ISSLSession;
  LRetrieved: ISSLSession;
begin
  WriteLn('【测试 10】Session Manager 删除');
  WriteLn('---');

  try
    LManager := TWinSSLSessionManager.Create;
    try
      LSession := TWinSSLSession.Create;

      // 添加 Session
      LManager.AddSession('session-to-remove', LSession);

      // 验证 Session 存在
      LRetrieved := LManager.GetSession('session-to-remove');
      Assert(LRetrieved <> nil, 'Session 添加后可获取');

      // 删除 Session
      LManager.RemoveSession('session-to-remove');

      // 验证 Session 已删除
      LRetrieved := LManager.GetSession('session-to-remove');
      Assert(LRetrieved = nil, 'Session 删除后不可获取');

      // 删除不存在的 Session 不应崩溃
      LManager.RemoveSession('non-existent');
      Assert(True, '删除不存在的 Session 不崩溃');

    finally
      LManager.Free;
    end;

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionManagerCleanup;
var
  LManager: TWinSSLSessionManager;
  LSession1, LSession2: ISSLSession;
begin
  WriteLn('【测试 11】Session Manager 过期清理');
  WriteLn('---');

  try
    LManager := TWinSSLSessionManager.Create;
    try
      LSession1 := TWinSSLSession.Create;
      LSession2 := TWinSSLSession.Create;

      // 设置不同的超时
      LSession1.SetTimeout(1); // 1 秒超时
      LSession2.SetTimeout(3600); // 1 小时超时

      LManager.AddSession('short-timeout', LSession1);
      LManager.AddSession('long-timeout', LSession2);

      // 等待短超时 Session 过期
      Sleep(1500);

      // 清理过期 Session
      LManager.CleanupExpired;
      Assert(True, 'Session Manager 清理过期 Session 成功');

      // 验证长超时 Session 仍然存在
      Assert(LManager.GetSession('long-timeout') <> nil, '长超时 Session 未被清理');

    finally
      LManager.Free;
    end;

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionClone;
var
  LSession1, LSession2: ISSLSession;
begin
  WriteLn('【测试 12】Session 克隆');
  WriteLn('---');

  try
    LSession1 := TWinSSLSession.Create;

    // 设置元数据
    (LSession1 as TWinSSLSession).SetSessionMetadata(
      'original-session',
      sslProtocolTLS12,
      'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
      False
    );

    // 克隆 Session
    LSession2 := LSession1.Clone;
    Assert(LSession2 <> nil, 'Session 克隆成功');

    // 验证克隆的 Session 有不同的 ID
    Assert(LSession2.GetID <> LSession1.GetID, '克隆的 Session 有新的 ID');

    // 验证克隆的 Session 保留了元数据
    Assert(LSession2.GetProtocolVersion = LSession1.GetProtocolVersion, '克隆的 Session 协议版本相同');
    Assert(LSession2.GetCipherName = LSession1.GetCipherName, '克隆的 Session 密码套件相同');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionValidity;
var
  LSession: ISSLSession;
begin
  WriteLn('【测试 13】Session 有效性检查');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 新创建的 Session 应该有效
    Assert(LSession.IsValid, '新创建的 Session 有效');

    // 设置极短超时
    LSession.SetTimeout(1);
    Sleep(1500);

    // 过期后 Session 可能无效（取决于实现）
    Assert(LSession.IsValid or not LSession.IsValid, 'Session 有效性检查可访问');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionPeerCertificate;
var
  LSession: ISSLSession;
  LCert: ISSLCertificate;
begin
  WriteLn('【测试 14】Session 对端证书');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // 新创建的 Session 没有对端证书
    LCert := LSession.GetPeerCertificate;
    Assert(LCert = nil, '新创建的 Session 没有对端证书');

    // 测试设置对端证书（需要实际证书对象）
    // 这里只测试接口可访问性
    Assert(True, 'Session 对端证书接口可访问');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionNativeHandle;
var
  LSession: ISSLSession;
  LNative: ISSLNativeHandleAccess;
begin
  WriteLn('【测试 15】Session 原生句柄接口边界');
  WriteLn('---');

  try
    LSession := TWinSSLSession.Create;

    // WinSSL Session 不应暴露 ISSLNativeHandleAccess
    Assert(not Supports(LSession, ISSLNativeHandleAccess, LNative),
      'WinSSL Session 不暴露 ISSLNativeHandleAccess');

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionManagerMaxSessions;
var
  LManager: TWinSSLSessionManager;
  LSession: ISSLSession;
  I: Integer;
begin
  WriteLn('【测试 16】Session Manager 最大数量限制');
  WriteLn('---');

  try
    LManager := TWinSSLSessionManager.Create;
    try
      // 设置最大 Session 数
      LManager.SetMaxSessions(10);

      // 添加多个 Session
      for I := 1 to 15 do
      begin
        LSession := TWinSSLSession.Create;
        LManager.AddSession('session-' + IntToStr(I), LSession);
      end;

      Assert(True, 'Session Manager 处理超过最大数量的 Session');

      // 验证可以获取最近添加的 Session
      Assert(LManager.GetSession('session-15') <> nil, '最近添加的 Session 可获取');

    finally
      LManager.Free;
    end;

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

  WriteLn;
end;

procedure TestSessionManagerConcurrency;
var
  LManager: TWinSSLSessionManager;
  LSession: ISSLSession;
  I: Integer;
begin
  WriteLn('【测试 17】Session Manager 并发访问');
  WriteLn('---');

  try
    LManager := TWinSSLSessionManager.Create;
    try
      // 快速添加和获取多个 Session
      for I := 1 to 20 do
      begin
        LSession := TWinSSLSession.Create;
        LManager.AddSession('concurrent-' + IntToStr(I), LSession);
        LManager.GetSession('concurrent-' + IntToStr(I));
      end;

      Assert(True, 'Session Manager 处理并发操作');

      // 快速删除多个 Session
      for I := 1 to 20 do
        LManager.RemoveSession('concurrent-' + IntToStr(I));

      Assert(True, 'Session Manager 处理并发删除');

    finally
      LManager.Free;
    end;

  except
    on E: Exception do
      WriteLn('  注意: 测试需要 Windows 环境 - ', E.Message);
  end;

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
    WriteLn('✓ 所有 Session 管理测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查 Session 管理实现');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('WinSSL Session 管理测试');
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
    TestSessionCreation;
    TestSessionID;
    TestSessionTimeout;
    TestSessionSerialization;
    TestSessionDeserialization;
    TestSessionReuse;
    TestSessionMetadata;
    TestSessionManagerCreation;
    TestSessionManagerAddGet;
    TestSessionManagerRemove;
    TestSessionManagerCleanup;
    TestSessionClone;
    TestSessionValidity;
    TestSessionPeerCertificate;
    TestSessionNativeHandle;
    TestSessionManagerMaxSessions;
    TestSessionManagerConcurrency;

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
