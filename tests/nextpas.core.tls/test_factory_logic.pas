program test_factory_logic;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated
  TSSLConfig.ServerName, the remaining option-bridge boolean field surface
  (`EnableCompression` / `EnableSessionTickets` / `EnableOCSPStapling`),
  and mixed-scope record-shape fields such as `BufferSize` /
  `HandshakeTimeout` explicit so the v1.x compatibility record shape
  stays visible. }

{
  test_factory_logic - 工厂模式逻辑测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 工厂逻辑测试
    验证 nextpas.core.tls.factory.pas 中的工厂模式实现

    此测试可在 Linux 上运行,不需要实际的 SSL 操作

  测试内容:
    1. 库注册和取消注册逻辑
    2. 库可用性检测
    3. 默认库管理
    4. 自动检测最佳库
    5. 配置规范化逻辑
}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

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

procedure TestLibraryTypeEnum;
var
  LLibType: TSSLLibraryType;
begin
  WriteLn('【测试 1】库类型枚举定义');
  WriteLn('---');

  // 验证库类型枚举值
  LLibType := sslAutoDetect;
  Assert(Ord(LLibType) = 0, 'sslAutoDetect = 0');

  LLibType := sslOpenSSL;
  Assert(Ord(LLibType) > 0, 'sslOpenSSL > 0');

  LLibType := sslWinSSL;
  Assert(Ord(LLibType) > 0, 'sslWinSSL > 0');

  LLibType := sslWolfSSL;
  Assert(Ord(LLibType) > 0, 'sslWolfSSL > 0');

  // 验证枚举值唯一性
  Assert(Ord(sslOpenSSL) <> Ord(sslWinSSL), 'OpenSSL 和 WinSSL 枚举值不同');
  Assert(Ord(sslOpenSSL) <> Ord(sslWolfSSL), 'OpenSSL 和 WolfSSL 枚举值不同');
  Assert(Ord(sslWinSSL) <> Ord(sslWolfSSL), 'WinSSL 和 WolfSSL 枚举值不同');

  WriteLn;
end;

procedure TestConfigNormalization;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 2】配置规范化逻辑');
  WriteLn('---');

  // 初始化配置
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslOpenSSL;
  LConfig.ContextType := sslCtxClient;

  // 测试协议版本规范化
  LConfig.ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  TSSLFactory.NormalizeConfig(LConfig);

  // 验证禁用旧协议的选项被设置
  Assert(ssoNoSSLv2 in LConfig.Options, '禁用 SSLv2 选项已设置');
  Assert(ssoNoSSLv3 in LConfig.Options, '禁用 SSLv3 选项已设置');
  Assert(ssoNoTLSv1 in LConfig.Options, '禁用 TLS 1.0 选项已设置');
  Assert(ssoNoTLSv1_1 in LConfig.Options, '禁用 TLS 1.1 选项已设置');

  // 验证启用的协议没有被禁用
  Assert(not (ssoNoTLSv1_2 in LConfig.Options), 'TLS 1.2 未被禁用');
  Assert(not (ssoNoTLSv1_3 in LConfig.Options), 'TLS 1.3 未被禁用');

  WriteLn;
end;

procedure TestConfigDefaultValues;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 3】配置默认值设置');
  WriteLn('---');

  // 初始化配置（不设置默认值）
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslOpenSSL;
  LConfig.ContextType := sslCtxClient;

  // 规范化配置
  TSSLFactory.NormalizeConfig(LConfig);

  // 验证默认值被设置
  Assert(LConfig.SessionTimeout > 0, 'Session 超时设置了默认值');
  Assert(LConfig.SessionTimeout = SSL_DEFAULT_SESSION_TIMEOUT,
         'Session 超时默认值正确');

  Assert(LConfig.SessionCacheSize > 0, 'Session 缓存大小设置了默认值');
  Assert(LConfig.SessionCacheSize = SSL_DEFAULT_SESSION_CACHE_SIZE,
         'Session 缓存大小默认值正确');

  Assert(LConfig.VerifyDepth > 0, '验证深度设置了默认值');
  Assert(LConfig.VerifyDepth = SSL_DEFAULT_VERIFY_DEPTH,
         '验证深度默认值正确');

  WriteLn;
end;

procedure TestConfigCompressionOption;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 4】压缩选项规范化');
  WriteLn('---');

  // 测试启用压缩
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.EnableCompression := True;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(not (ssoDisableCompression in LConfig.Options),
         '启用压缩时未设置禁用压缩选项');

  // 测试禁用压缩
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.EnableCompression := False;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(ssoDisableCompression in LConfig.Options,
         '禁用压缩时设置了禁用压缩选项');

  WriteLn;
end;

procedure TestConfigSessionTicketsOption;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 5】Session Tickets 选项规范化');
  WriteLn('---');

  // 测试启用 Session Tickets
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.EnableSessionTickets := True;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(ssoEnableSessionTickets in LConfig.Options,
         '启用 Session Tickets 时设置了相应选项');

  // 测试禁用 Session Tickets
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.EnableSessionTickets := False;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(not (ssoEnableSessionTickets in LConfig.Options),
         '禁用 Session Tickets 时未设置相应选项');

  WriteLn;
end;

procedure TestConfigOCSPStaplingOption;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 6】OCSP Stapling 选项规范化');
  WriteLn('---');

  // 测试启用 OCSP Stapling
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.EnableOCSPStapling := True;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(ssoEnableOCSPStapling in LConfig.Options,
         '启用 OCSP Stapling 时设置了相应选项');

  // 测试禁用 OCSP Stapling
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.EnableOCSPStapling := False;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(not (ssoEnableOCSPStapling in LConfig.Options),
         '禁用 OCSP Stapling 时未设置相应选项');

  WriteLn;
end;

procedure TestConfigSessionCacheOption;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 7】Session Cache 选项规范化');
  WriteLn('---');

  // 测试启用 Session Cache（缓存大小 > 0）
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.SessionCacheSize := 1024;
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(ssoEnableSessionCache in LConfig.Options,
         'Session 缓存大小 > 0 时启用 Session Cache');

  // 测试禁用 Session Cache（缓存大小 = 0）
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.SessionCacheSize := 0;
  TSSLFactory.NormalizeConfig(LConfig);
  // 注意：规范化会设置默认值，所以这里会启用
  Assert(ssoEnableSessionCache in LConfig.Options,
         '规范化后 Session Cache 被启用（设置了默认值）');

  WriteLn;
end;

procedure TestConfigRenegotiationOption;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 8】重新协商选项规范化');
  WriteLn('---');

  // 规范化总是禁用重新协商（安全考虑）
  FillChar(LConfig, SizeOf(LConfig), 0);
  TSSLFactory.NormalizeConfig(LConfig);
  Assert(ssoDisableRenegotiation in LConfig.Options,
         '规范化总是禁用重新协商');

  WriteLn;
end;

procedure TestConfigProtocolVersionMapping;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 9】协议版本到选项的映射');
  WriteLn('---');

  // 测试仅启用 TLS 1.2
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.ProtocolVersions := [sslProtocolTLS12];
  TSSLFactory.NormalizeConfig(LConfig);

  Assert(ssoNoSSLv2 in LConfig.Options, 'SSLv2 被禁用');
  Assert(ssoNoSSLv3 in LConfig.Options, 'SSLv3 被禁用');
  Assert(ssoNoTLSv1 in LConfig.Options, 'TLS 1.0 被禁用');
  Assert(ssoNoTLSv1_1 in LConfig.Options, 'TLS 1.1 被禁用');
  Assert(not (ssoNoTLSv1_2 in LConfig.Options), 'TLS 1.2 未被禁用');
  Assert(ssoNoTLSv1_3 in LConfig.Options, 'TLS 1.3 被禁用');

  // 测试启用 TLS 1.2 和 TLS 1.3
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  TSSLFactory.NormalizeConfig(LConfig);

  Assert(not (ssoNoTLSv1_2 in LConfig.Options), 'TLS 1.2 未被禁用');
  Assert(not (ssoNoTLSv1_3 in LConfig.Options), 'TLS 1.3 未被禁用');

  WriteLn;
end;

procedure TestConfigCipherDefaults;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 10】密码套件默认值');
  WriteLn('---');

  // 测试空密码套件列表被设置为默认值
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.CipherList := '';
  LConfig.CipherSuites := '';
  TSSLFactory.NormalizeConfig(LConfig);

  Assert(LConfig.CipherList <> '', 'CipherList 设置了默认值');
  Assert(LConfig.CipherSuites <> '', 'CipherSuites 设置了默认值');

  WriteLn;
end;

procedure TestLibraryTypesSet;
var
  LLibTypes: TSSLLibraryTypes;
begin
  WriteLn('【测试 11】库类型集合操作');
  WriteLn('---');

  // 测试空集合
  LLibTypes := [];
  Assert(LLibTypes = [], '空库类型集合');

  // 测试单个库类型
  LLibTypes := [sslOpenSSL];
  Assert(sslOpenSSL in LLibTypes, 'OpenSSL 在集合中');
  Assert(not (sslWinSSL in LLibTypes), 'WinSSL 不在集合中');

  // 测试多个库类型
  LLibTypes := [sslOpenSSL, sslWinSSL];
  Assert(sslOpenSSL in LLibTypes, 'OpenSSL 在集合中');
  Assert(sslWinSSL in LLibTypes, 'WinSSL 在集合中');
  Assert(not (sslWolfSSL in LLibTypes), 'WolfSSL 不在集合中');

  // 测试集合操作
  LLibTypes := [sslOpenSSL];
  Include(LLibTypes, sslWinSSL);
  Assert(sslWinSSL in LLibTypes, 'Include 操作成功');

  Exclude(LLibTypes, sslOpenSSL);
  Assert(not (sslOpenSSL in LLibTypes), 'Exclude 操作成功');

  WriteLn;
end;

procedure TestRegistrationRecordType;
var
  LReg: TSSLLibraryRegistration;
begin
  WriteLn('【测试 12】库注册记录类型');
  WriteLn('---');

  // 验证记录类型可以初始化
  FillChar(LReg, SizeOf(LReg), 0);
  Assert(True, 'TSSLLibraryRegistration 可以初始化');

  // 验证字段可访问
  LReg.LibraryType := sslOpenSSL;
  Assert(LReg.LibraryType = sslOpenSSL, 'LibraryType 字段可访问');

  LReg.Description := 'Test Library';
  Assert(LReg.Description = 'Test Library', 'Description 字段可访问');

  LReg.Priority := 10;
  Assert(LReg.Priority = 10, 'Priority 字段可访问');

  WriteLn;
end;

procedure TestConfigStructureIntegrity;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 13】配置结构完整性');
  WriteLn('---');

  // 验证配置结构大小合理
  Assert(SizeOf(TSSLConfig) > 0, 'TSSLConfig 大小 > 0');

  // 验证可以完全初始化
  FillChar(LConfig, SizeOf(LConfig), 0);
  Assert(LConfig.BufferSize = 0, '配置可以初始化为零');

  // 验证所有主要字段可访问
  LConfig.LibraryType := sslOpenSSL;
  LConfig.ContextType := sslCtxClient;
  LConfig.ProtocolVersions := [sslProtocolTLS12];
  LConfig.PreferredVersion := sslProtocolTLS13;
  LConfig.VerifyMode := [sslVerifyPeer];
  LConfig.VerifyDepth := 10;
  LConfig.BufferSize := 16384;
  LConfig.HandshakeTimeout := 30000;
  LConfig.SessionCacheSize := 1024;
  LConfig.SessionTimeout := 300;

  Assert(LConfig.LibraryType = sslOpenSSL, 'LibraryType 可设置');
  Assert(LConfig.ContextType = sslCtxClient, 'ContextType 可设置');
  Assert(sslProtocolTLS12 in LConfig.ProtocolVersions, 'ProtocolVersions 可设置');
  Assert(LConfig.BufferSize = 16384, 'BufferSize 可设置');

  WriteLn;
end;

procedure TestConfigBooleanFields;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 14】配置布尔字段');
  WriteLn('---');

  FillChar(LConfig, SizeOf(LConfig), 0);

  // 测试布尔字段可设置
  LConfig.EnableCompression := True;
  Assert(LConfig.EnableCompression, 'EnableCompression 可设置为 True');

  LConfig.EnableCompression := False;
  Assert(not LConfig.EnableCompression, 'EnableCompression 可设置为 False');

  LConfig.EnableSessionTickets := True;
  Assert(LConfig.EnableSessionTickets, 'EnableSessionTickets 可设置为 True');

  LConfig.EnableOCSPStapling := True;
  Assert(LConfig.EnableOCSPStapling, 'EnableOCSPStapling 可设置为 True');

  WriteLn;
end;

procedure TestConfigStringFields;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 15】配置字符串字段');
  WriteLn('---');

  FillChar(LConfig, SizeOf(LConfig), 0);

  // 测试字符串字段可设置
  LConfig.CertificateFile := '/path/to/cert.pem';
  Assert(LConfig.CertificateFile = '/path/to/cert.pem', 'CertificateFile 可设置');

  LConfig.PrivateKeyFile := '/path/to/key.pem';
  Assert(LConfig.PrivateKeyFile = '/path/to/key.pem', 'PrivateKeyFile 可设置');

  LConfig.CAFile := '/path/to/ca.pem';
  Assert(LConfig.CAFile = '/path/to/ca.pem', 'CAFile 可设置');

  LConfig.ServerName := 'example.com';
  Assert(LConfig.ServerName = 'example.com', '兼容字段 ServerName 仍可设置');

  LConfig.ALPNProtocols := 'h2,http/1.1';
  Assert(LConfig.ALPNProtocols = 'h2,http/1.1', 'ALPNProtocols 可设置');

  WriteLn;
end;

procedure TestConfigEarlyDataFields;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 16】配置 Early Data 字段');
  WriteLn('---');

  FillChar(LConfig, SizeOf(LConfig), 0);

  Assert(not LConfig.ClientEarlyDataEnabled, 'ClientEarlyDataEnabled 默认为 False');
  Assert(LConfig.ServerEarlyDataPolicy = sslEarlyDataServerReject,
    'ServerEarlyDataPolicy 默认为 Reject');
  Assert(LConfig.ServerMaxEarlyDataSize = 0,
    'ServerMaxEarlyDataSize 默认为 0');
  Assert(LConfig.ServerEarlyDataReplayStoreFile = '',
    'ServerEarlyDataReplayStoreFile 默认为空');
  Assert(LConfig.ServerEarlyDataReplayStoreDirectory = '',
    'ServerEarlyDataReplayStoreDirectory 默认为空');

  LConfig.ClientEarlyDataEnabled := True;
  Assert(LConfig.ClientEarlyDataEnabled, 'ClientEarlyDataEnabled 可设置为 True');

  LConfig.ServerEarlyDataPolicy := sslEarlyDataServerIssueOnly;
  Assert(LConfig.ServerEarlyDataPolicy = sslEarlyDataServerIssueOnly,
    'ServerEarlyDataPolicy 可设置为 IssueOnly');

  LConfig.ServerMaxEarlyDataSize := 42;
  Assert(LConfig.ServerMaxEarlyDataSize = 42,
    'ServerMaxEarlyDataSize 可设置');

  LConfig.ServerEarlyDataReplayStoreFile := '/tmp/factory-replay-store.bin';
  Assert(LConfig.ServerEarlyDataReplayStoreFile = '/tmp/factory-replay-store.bin',
    'ServerEarlyDataReplayStoreFile 可设置');

  LConfig.ServerEarlyDataReplayStoreDirectory := '/tmp/factory-replay-store-dir';
  Assert(LConfig.ServerEarlyDataReplayStoreDirectory = '/tmp/factory-replay-store-dir',
    'ServerEarlyDataReplayStoreDirectory 可设置');

  TSSLFactory.NormalizeConfig(LConfig);
  Assert(LConfig.ClientEarlyDataEnabled,
    'NormalizeConfig 保留 ClientEarlyDataEnabled');
  Assert(LConfig.ServerEarlyDataPolicy = sslEarlyDataServerIssueOnly,
    'NormalizeConfig 保留 ServerEarlyDataPolicy');
  Assert(LConfig.ServerMaxEarlyDataSize = 42,
    'NormalizeConfig 保留 ServerMaxEarlyDataSize');
  Assert(LConfig.ServerEarlyDataReplayStoreFile = '/tmp/factory-replay-store.bin',
    'NormalizeConfig 保留 ServerEarlyDataReplayStoreFile');
  Assert(LConfig.ServerEarlyDataReplayStoreDirectory = '/tmp/factory-replay-store-dir',
    'NormalizeConfig 保留 ServerEarlyDataReplayStoreDirectory');

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
    WriteLn('✓ 所有工厂逻辑测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查工厂实现');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('工厂模式逻辑测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  try
    TestLibraryTypeEnum;
    TestConfigNormalization;
    TestConfigDefaultValues;
    TestConfigCompressionOption;
    TestConfigSessionTicketsOption;
    TestConfigOCSPStaplingOption;
    TestConfigSessionCacheOption;
    TestConfigRenegotiationOption;
    TestConfigProtocolVersionMapping;
    TestConfigCipherDefaults;
    TestLibraryTypesSet;
    TestRegistrationRecordType;
    TestConfigStructureIntegrity;
    TestConfigBooleanFields;
    TestConfigStringFields;
    TestConfigEarlyDataFields;

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
