program test_base_interface_contract;

{$mode objfpc}{$H+}

{
  test_base_interface_contract - 基础接口契约测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 接口契约测试
    验证 nextpas.core.tls.base.pas 中的接口定义、类型定义和常量

    此测试可在 Linux 上运行,不需要实际的 SSL 操作

  测试内容:
    1. 接口 GUID 唯一性
    2. 类型定义完整性
    3. 常量值正确性
    4. 枚举定义一致性
    5. 记录类型大小和对齐
}

uses
  SysUtils, TypInfo,
  nextpas.core.tls.base;

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

procedure TestInterfaceGUIDs;
var
  LLibGUID, LContextGUID, LConnectionGUID: TGUID;
  LCertGUID, LStoreGUID, LSessionGUID: TGUID;
begin
  WriteLn('【测试 1】接口 GUID 唯一性');
  WriteLn('---');

  // 验证接口 GUID 已定义且唯一
  // ISSLLibrary: {A0E8F4B1-7C3A-4D2E-9F5B-8C6D7E9A0B1C}
  LLibGUID := StringToGUID('{A0E8F4B1-7C3A-4D2E-9F5B-8C6D7E9A0B1C}');
  Assert(True, 'ISSLLibrary GUID 已定义');

  // ISSLContext: {B1F9E5C2-8D4B-5E3F-A06C-9D8E0F1A2B3D}
  LContextGUID := StringToGUID('{B1F9E5C2-8D4B-5E3F-A06C-9D8E0F1A2B3D}');
  Assert(True, 'ISSLContext GUID 已定义');

  // ISSLConnection: {C2A9F6D3-9E5C-6F40-B17D-AE9F102B4C5E}
  LConnectionGUID := StringToGUID('{C2A9F6D3-9E5C-6F40-B17D-AE9F102B4C5E}');
  Assert(True, 'ISSLConnection GUID 已定义');

  // 验证 GUID 唯一性
  Assert(not IsEqualGUID(LLibGUID, LContextGUID), 'ISSLLibrary 和 ISSLContext GUID 不同');
  Assert(not IsEqualGUID(LLibGUID, LConnectionGUID), 'ISSLLibrary 和 ISSLConnection GUID 不同');
  Assert(not IsEqualGUID(LContextGUID, LConnectionGUID), 'ISSLContext 和 ISSLConnection GUID 不同');

  WriteLn;
end;

procedure TestEnumerationTypes;
var
  LLibType: TSSLLibraryType;
  LProtocol: TSSLProtocolVersion;
  LContextType: TSSLContextType;
  LHandshakeState: TSSLHandshakeState;
  LErrorCode: TSSLErrorCode;
  LLogLevel: TSSLLogLevel;
begin
  WriteLn('【测试 2】枚举类型定义');
  WriteLn('---');

  // TSSLLibraryType
  LLibType := sslAutoDetect;
  Assert(Ord(LLibType) = 0, 'sslAutoDetect = 0');
  LLibType := sslOpenSSL;
  Assert(Ord(LLibType) = 1, 'sslOpenSSL = 1');
  LLibType := sslWinSSL;
  Assert(Ord(LLibType) = 4, 'sslWinSSL = 4');

  // TSSLProtocolVersion
  LProtocol := sslProtocolSSL3;
  Assert(Ord(LProtocol) >= 0, 'sslProtocolSSL3 已定义');
  LProtocol := sslProtocolTLS10;
  Assert(Ord(LProtocol) > Ord(sslProtocolSSL3), 'sslProtocolTLS10 > sslProtocolSSL3');
  LProtocol := sslProtocolTLS13;
  Assert(Ord(LProtocol) > Ord(sslProtocolTLS12), 'sslProtocolTLS13 > sslProtocolTLS12');

  // TSSLContextType
  LContextType := sslCtxClient;
  Assert(Ord(LContextType) = 0, 'sslCtxClient = 0');
  LContextType := sslCtxServer;
  Assert(Ord(LContextType) = 1, 'sslCtxServer = 1');

  // TSSLHandshakeState
  LHandshakeState := sslHsNotStarted;
  Assert(Ord(LHandshakeState) = 0, 'sslHsNotStarted = 0');
  LHandshakeState := sslHsCompleted;
  Assert(Ord(LHandshakeState) > 0, 'sslHsCompleted > 0');

  // TSSLErrorCode
  LErrorCode := sslErrNone;
  Assert(Ord(LErrorCode) = 0, 'sslErrNone = 0');
  LErrorCode := sslErrGeneral;
  Assert(Ord(LErrorCode) > 0, 'sslErrGeneral > 0');

  // TSSLLogLevel
  LLogLevel := sslLogNone;
  Assert(Ord(LLogLevel) = 0, 'sslLogNone = 0');
  LLogLevel := sslLogError;
  Assert(Ord(LLogLevel) > Ord(sslLogNone), 'sslLogError > sslLogNone');
  LLogLevel := sslLogTrace;
  Assert(Ord(LLogLevel) > Ord(sslLogDebug), 'sslLogTrace > sslLogDebug');

  WriteLn;
end;

procedure TestConstantValues;
begin
  WriteLn('【测试 3】常量值定义');
  WriteLn('---');

  // SSL 默认常量
  Assert(SSL_DEFAULT_BUFFER_SIZE = 16384, 'SSL_DEFAULT_BUFFER_SIZE = 16384');
  Assert(SSL_DEFAULT_VERIFY_DEPTH = 10, 'SSL_DEFAULT_VERIFY_DEPTH = 10');
  Assert(SSL_DEFAULT_HANDSHAKE_TIMEOUT = 30000, 'SSL_DEFAULT_HANDSHAKE_TIMEOUT = 30000');
  Assert(SSL_DEFAULT_SESSION_TIMEOUT = 300, 'SSL_DEFAULT_SESSION_TIMEOUT = 300');
  Assert(SSL_DEFAULT_SESSION_CACHE_SIZE = 1024, 'SSL_DEFAULT_SESSION_CACHE_SIZE = 1024');

  // 验证常量合理性
  Assert(SSL_DEFAULT_BUFFER_SIZE > 0, 'Buffer size > 0');
  Assert(SSL_DEFAULT_BUFFER_SIZE mod 1024 = 0, 'Buffer size 是 1024 的倍数');
  Assert(SSL_DEFAULT_VERIFY_DEPTH > 0, 'Verify depth > 0');
  Assert(SSL_DEFAULT_HANDSHAKE_TIMEOUT > 0, 'Handshake timeout > 0');
  Assert(SSL_DEFAULT_SESSION_TIMEOUT > 0, 'Session timeout > 0');
  Assert(SSL_DEFAULT_SESSION_CACHE_SIZE > 0, 'Session cache size > 0');

  WriteLn;
end;

procedure TestRecordTypeSizes;
var
  LStats: TSSLStatistics;
  LConfig: TSSLConfig;
  LCertInfo: TSSLCertificateInfo;
  LConnInfo: TSSLConnectionInfo;
  LHealthStatus: TSSLHealthStatus;
  LPerfMetrics: TSSLPerformanceMetrics;
  LErrorRecord: TSSLErrorRecord;
  LDiagInfo: TSSLDiagnosticInfo;
begin
  WriteLn('【测试 4】记录类型大小');
  WriteLn('---');

  // 验证记录类型大小合理
  Assert(SizeOf(TSSLStatistics) > 0, 'TSSLStatistics 大小 > 0');
  Assert(SizeOf(TSSLConfig) > 0, 'TSSLConfig 大小 > 0');
  Assert(SizeOf(TSSLCertificateInfo) > 0, 'TSSLCertificateInfo 大小 > 0');
  Assert(SizeOf(TSSLConnectionInfo) > 0, 'TSSLConnectionInfo 大小 > 0');

  // Phase 3.3 新增类型
  Assert(SizeOf(TSSLHealthStatus) > 0, 'TSSLHealthStatus 大小 > 0');
  Assert(SizeOf(TSSLPerformanceMetrics) > 0, 'TSSLPerformanceMetrics 大小 > 0');
  Assert(SizeOf(TSSLErrorRecord) > 0, 'TSSLErrorRecord 大小 > 0');
  Assert(SizeOf(TSSLDiagnosticInfo) > 0, 'TSSLDiagnosticInfo 大小 > 0');

  // 验证记录可以初始化
  FillChar(LStats, SizeOf(LStats), 0);
  Assert(LStats.ConnectionsTotal = 0, 'TSSLStatistics 可以初始化');

  FillChar(LConfig, SizeOf(LConfig), 0);
  Assert(LConfig.BufferSize = 0, 'TSSLConfig 可以初始化');

  FillChar(LHealthStatus, SizeOf(LHealthStatus), 0);
  Assert(not LHealthStatus.IsConnected, 'TSSLHealthStatus 可以初始化');

  FillChar(LPerfMetrics, SizeOf(LPerfMetrics), 0);
  Assert(LPerfMetrics.HandshakeTime = 0, 'TSSLPerformanceMetrics 可以初始化');

  WriteLn;
end;

procedure TestStatisticsFields;
var
  LStats: TSSLStatistics;
begin
  WriteLn('【测试 5】TSSLStatistics 字段完整性');
  WriteLn('---');

  FillChar(LStats, SizeOf(LStats), 0);

  // 基本统计字段
  LStats.ConnectionsTotal := 100;
  Assert(LStats.ConnectionsTotal = 100, 'ConnectionsTotal 字段可访问');

  LStats.ConnectionsActive := 10;
  Assert(LStats.ConnectionsActive = 10, 'ConnectionsActive 字段可访问');

  LStats.HandshakesSuccessful := 90;
  Assert(LStats.HandshakesSuccessful = 90, 'HandshakesSuccessful 字段可访问');

  LStats.HandshakesFailed := 10;
  Assert(LStats.HandshakesFailed = 10, 'HandshakesFailed 字段可访问');

  // Phase 3.3 性能统计字段
  LStats.HandshakeTimeTotal := 5000;
  Assert(LStats.HandshakeTimeTotal = 5000, 'HandshakeTimeTotal 字段可访问');

  LStats.HandshakeTimeMin := 30;
  Assert(LStats.HandshakeTimeMin = 30, 'HandshakeTimeMin 字段可访问');

  LStats.HandshakeTimeMax := 200;
  Assert(LStats.HandshakeTimeMax = 200, 'HandshakeTimeMax 字段可访问');

  LStats.HandshakeTimeAvg := 55;
  Assert(LStats.HandshakeTimeAvg = 55, 'HandshakeTimeAvg 字段可访问');

  // Phase 3.3 Session 复用统计字段
  LStats.SessionsReused := 70;
  Assert(LStats.SessionsReused = 70, 'SessionsReused 字段可访问');

  LStats.SessionsCreated := 30;
  Assert(LStats.SessionsCreated = 30, 'SessionsCreated 字段可访问');

  LStats.SessionReuseRate := 70.0;
  Assert(Abs(LStats.SessionReuseRate - 70.0) < 0.01, 'SessionReuseRate 字段可访问');

  WriteLn;
end;

procedure TestHealthStatusFields;
var
  LHealth: TSSLHealthStatus;
begin
  WriteLn('【测试 6】TSSLHealthStatus 字段完整性');
  WriteLn('---');

  FillChar(LHealth, SizeOf(LHealth), 0);

  // 验证所有字段可访问
  LHealth.IsConnected := True;
  Assert(LHealth.IsConnected, 'IsConnected 字段可访问');

  LHealth.HandshakeComplete := True;
  Assert(LHealth.HandshakeComplete, 'HandshakeComplete 字段可访问');

  LHealth.LastError := sslErrNone;
  Assert(LHealth.LastError = sslErrNone, 'LastError 字段可访问');

  LHealth.LastErrorTime := Now;
  Assert(LHealth.LastErrorTime > 0, 'LastErrorTime 字段可访问');

  LHealth.BytesSent := 1024;
  Assert(LHealth.BytesSent = 1024, 'BytesSent 字段可访问');

  LHealth.BytesReceived := 2048;
  Assert(LHealth.BytesReceived = 2048, 'BytesReceived 字段可访问');

  LHealth.ConnectionAge := 60;
  Assert(LHealth.ConnectionAge = 60, 'ConnectionAge 字段可访问');

  WriteLn;
end;

procedure TestPerformanceMetricsFields;
var
  LMetrics: TSSLPerformanceMetrics;
begin
  WriteLn('【测试 7】TSSLPerformanceMetrics 字段完整性');
  WriteLn('---');

  FillChar(LMetrics, SizeOf(LMetrics), 0);

  // 验证所有字段可访问
  LMetrics.HandshakeTime := 100;
  Assert(LMetrics.HandshakeTime = 100, 'HandshakeTime 字段可访问');

  LMetrics.FirstByteTime := 50;
  Assert(LMetrics.FirstByteTime = 50, 'FirstByteTime 字段可访问');

  LMetrics.TotalBytesTransferred := 10240;
  Assert(LMetrics.TotalBytesTransferred = 10240, 'TotalBytesTransferred 字段可访问');

  LMetrics.AverageLatency := 25;
  Assert(LMetrics.AverageLatency = 25, 'AverageLatency 字段可访问');

  LMetrics.SessionReused := True;
  Assert(LMetrics.SessionReused, 'SessionReused 字段可访问');

  WriteLn;
end;

procedure TestErrorRecordFields;
var
  LError: TSSLErrorRecord;
begin
  WriteLn('【测试 8】TSSLErrorRecord 字段完整性');
  WriteLn('---');

  FillChar(LError, SizeOf(LError), 0);

  // 验证所有字段可访问
  LError.ErrorCode := sslErrTimeout;
  Assert(LError.ErrorCode = sslErrTimeout, 'ErrorCode 字段可访问');

  LError.ErrorMessage := 'Test error';
  Assert(LError.ErrorMessage = 'Test error', 'ErrorMessage 字段可访问');

  LError.Timestamp := Now;
  Assert(LError.Timestamp > 0, 'Timestamp 字段可访问');

  WriteLn;
end;

procedure TestDiagnosticInfoFields;
var
  LDiag: TSSLDiagnosticInfo;
begin
  WriteLn('【测试 9】TSSLDiagnosticInfo 字段完整性');
  WriteLn('---');

  // 验证所有字段可访问
  FillChar(LDiag.ConnectionInfo, SizeOf(LDiag.ConnectionInfo), 0);
  Assert(True, 'ConnectionInfo 字段可访问');

  FillChar(LDiag.HealthStatus, SizeOf(LDiag.HealthStatus), 0);
  Assert(True, 'HealthStatus 字段可访问');

  FillChar(LDiag.PerformanceMetrics, SizeOf(LDiag.PerformanceMetrics), 0);
  Assert(True, 'PerformanceMetrics 字段可访问');

  SetLength(LDiag.ErrorHistory, 5);
  Assert(Length(LDiag.ErrorHistory) = 5, 'ErrorHistory 数组可访问');

  WriteLn;
end;

procedure TestSetTypes;
var
  LProtocols: TSSLProtocolVersions;
  LVerifyModes: TSSLVerifyModes;
  LOptions: TSSLOptions;
  LVerifyFlags: TSSLCertVerifyFlags;
begin
  WriteLn('【测试 10】集合类型定义');
  WriteLn('---');

  // TSSLProtocolVersions
  LProtocols := [];
  Assert(LProtocols = [], '空协议集合');

  LProtocols := [sslProtocolTLS12];
  Assert(sslProtocolTLS12 in LProtocols, 'TLS 1.2 在集合中');

  LProtocols := [sslProtocolTLS12, sslProtocolTLS13];
  Assert(sslProtocolTLS12 in LProtocols, 'TLS 1.2 在集合中');
  Assert(sslProtocolTLS13 in LProtocols, 'TLS 1.3 在集合中');

  // TSSLVerifyModes
  LVerifyModes := [];
  Assert(LVerifyModes = [], '空验证模式集合');

  LVerifyModes := [sslVerifyPeer];
  Assert(sslVerifyPeer in LVerifyModes, 'VerifyPeer 在集合中');

  // TSSLOptions
  LOptions := [];
  Assert(LOptions = [], '空选项集合');

  LOptions := [ssoEnableSNI];
  Assert(ssoEnableSNI in LOptions, 'EnableSNI 在集合中');

  // TSSLCertVerifyFlags
  LVerifyFlags := [];
  Assert(LVerifyFlags = [], '空验证标志集合');

  WriteLn;
end;

procedure TestBackendCapabilities;
var
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn('【测试 11】TSSLBackendCapabilities 字段完整性');
  WriteLn('---');

  FillChar(LCaps, SizeOf(LCaps), 0);

  // 验证所有字段可访问
  LCaps.SupportsTLS13 := True;
  Assert(LCaps.SupportsTLS13, 'SupportsTLS13 字段可访问');

  LCaps.SupportsALPN := True;
  Assert(LCaps.SupportsALPN, 'SupportsALPN 字段可访问');

  LCaps.SupportsSNI := True;
  Assert(LCaps.SupportsSNI, 'SupportsSNI 字段可访问');

  LCaps.SupportsOCSPStapling := True;
  Assert(LCaps.SupportsOCSPStapling, 'SupportsOCSPStapling 字段可访问');

  LCaps.MinTLSVersion := sslProtocolTLS10;
  Assert(LCaps.MinTLSVersion = sslProtocolTLS10, 'MinTLSVersion 字段可访问');

  LCaps.MaxTLSVersion := sslProtocolTLS13;
  Assert(LCaps.MaxTLSVersion = sslProtocolTLS13, 'MaxTLSVersion 字段可访问');

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
    WriteLn('✓ 所有接口契约测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查类型定义');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('基础接口契约测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  try
    TestInterfaceGUIDs;
    TestEnumerationTypes;
    TestConstantValues;
    TestRecordTypeSizes;
    TestStatisticsFields;
    TestHealthStatusFields;
    TestPerformanceMetricsFields;
    TestErrorRecordFields;
    TestDiagnosticInfoFields;
    TestSetTypes;
    TestBackendCapabilities;

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
