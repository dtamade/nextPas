program test_data_structures;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated
  TSSLConfig.ServerName, the remaining option-bridge boolean field surface
  (`EnableCompression` / `EnableSessionTickets` / `EnableOCSPStapling`),
  and mixed-scope record-shape fields such as `BufferSize` /
  `HandshakeTimeout` explicit so the v1.x compatibility record shape
  stays visible. }

{
  test_data_structures - 数据结构测试

  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2026-01-18

  描述:
    Phase 3.4 测试覆盖 - 数据结构测试
    验证 nextpas.core.tls.base.pas 中的记录类型和数据结构

    此测试可在 Linux 上运行,不需要实际的 SSL 操作

  测试内容:
    1. 记录类型大小和对齐
    2. 字段访问和赋值
    3. 数组和动态数组
    4. 记录初始化和清零
    5. 数据结构完整性
}

uses
  SysUtils,
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

procedure TestCertificateInfoStructure;
var
  LCertInfo: TSSLCertificateInfo;
begin
  WriteLn('【测试 1】TSSLCertificateInfo 结构');
  WriteLn('---');

  // 验证结构大小
  Assert(SizeOf(TSSLCertificateInfo) > 0, 'TSSLCertificateInfo 大小 > 0');

  // 初始化结构
  FillChar(LCertInfo, SizeOf(LCertInfo), 0);

  // 测试字符串字段
  LCertInfo.Subject := 'CN=Test';
  Assert(LCertInfo.Subject = 'CN=Test', 'Subject 字段可访问');

  LCertInfo.Issuer := 'CN=CA';
  Assert(LCertInfo.Issuer = 'CN=CA', 'Issuer 字段可访问');

  LCertInfo.SerialNumber := '123456';
  Assert(LCertInfo.SerialNumber = '123456', 'SerialNumber 字段可访问');

  // 测试日期字段
  LCertInfo.NotBefore := Now;
  Assert(LCertInfo.NotBefore > 0, 'NotBefore 字段可访问');

  LCertInfo.NotAfter := Now + 365;
  Assert(LCertInfo.NotAfter > LCertInfo.NotBefore, 'NotAfter 字段可访问');

  // 测试整数字段
  LCertInfo.PublicKeySize := 2048;
  Assert(LCertInfo.PublicKeySize = 2048, 'PublicKeySize 字段可访问');

  LCertInfo.Version := 3;
  Assert(LCertInfo.Version = 3, 'Version 字段可访问');

  // 测试布尔字段
  LCertInfo.IsCA := True;
  Assert(LCertInfo.IsCA, 'IsCA 字段可访问');

  WriteLn;
end;

procedure TestConnectionInfoStructure;
var
  LConnInfo: TSSLConnectionInfo;
begin
  WriteLn('【测试 2】TSSLConnectionInfo 结构');
  WriteLn('---');

  // 验证结构大小
  Assert(SizeOf(TSSLConnectionInfo) > 0, 'TSSLConnectionInfo 大小 > 0');

  // 初始化结构
  FillChar(LConnInfo, SizeOf(LConnInfo), 0);

  // 测试协议版本字段
  LConnInfo.ProtocolVersion := sslProtocolTLS13;
  Assert(LConnInfo.ProtocolVersion = sslProtocolTLS13, 'ProtocolVersion 字段可访问');

  // 测试字符串字段
  LConnInfo.CipherSuite := 'TLS_AES_256_GCM_SHA384';
  Assert(LConnInfo.CipherSuite = 'TLS_AES_256_GCM_SHA384', 'CipherSuite 字段可访问');

  LConnInfo.SessionId := 'session123';
  Assert(LConnInfo.SessionId = 'session123', 'SessionId 字段可访问');

  LConnInfo.ServerName := 'example.com';
  Assert(LConnInfo.ServerName = 'example.com', 'ServerName 字段可访问');

  LConnInfo.ALPNProtocol := 'h2';
  Assert(LConnInfo.ALPNProtocol = 'h2', 'ALPNProtocol 字段可访问');

  // 测试整数字段
  LConnInfo.KeySize := 256;
  Assert(LConnInfo.KeySize = 256, 'KeySize 字段可访问');

  LConnInfo.MacSize := 32;
  Assert(LConnInfo.MacSize = 32, 'MacSize 字段可访问');

  // 测试布尔字段
  LConnInfo.IsResumed := True;
  Assert(LConnInfo.IsResumed, 'IsResumed 字段可访问');

  WriteLn;
end;

procedure TestConfigStructure;
var
  LConfig: TSSLConfig;
begin
  WriteLn('【测试 3】TSSLConfig 结构');
  WriteLn('---');

  // 验证结构大小
  Assert(SizeOf(TSSLConfig) > 0, 'TSSLConfig 大小 > 0');

  // 初始化结构
  FillChar(LConfig, SizeOf(LConfig), 0);

  // 测试枚举字段
  LConfig.LibraryType := sslOpenSSL;
  Assert(LConfig.LibraryType = sslOpenSSL, 'LibraryType 字段可访问');

  LConfig.ContextType := sslCtxClient;
  Assert(LConfig.ContextType = sslCtxClient, 'ContextType 字段可访问');

  LConfig.PreferredVersion := sslProtocolTLS13;
  Assert(LConfig.PreferredVersion = sslProtocolTLS13, 'PreferredVersion 字段可访问');

  // 测试集合字段
  LConfig.ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  Assert(sslProtocolTLS12 in LConfig.ProtocolVersions, 'ProtocolVersions 集合可访问');
  Assert(sslProtocolTLS13 in LConfig.ProtocolVersions, 'ProtocolVersions 集合可访问');

  LConfig.VerifyMode := [sslVerifyPeer, sslVerifyFailIfNoPeerCert];
  Assert(sslVerifyPeer in LConfig.VerifyMode, 'VerifyMode 集合可访问');

  LConfig.Options := [ssoEnableSNI, ssoEnableALPN];
  Assert(ssoEnableSNI in LConfig.Options, 'Options 集合可访问');

  // 测试整数字段
  LConfig.VerifyDepth := 10;
  Assert(LConfig.VerifyDepth = 10, 'VerifyDepth 字段可访问');

  LConfig.BufferSize := 16384;
  Assert(LConfig.BufferSize = 16384, 'BufferSize 字段可访问');

  LConfig.HandshakeTimeout := 30000;
  Assert(LConfig.HandshakeTimeout = 30000, 'HandshakeTimeout 字段可访问');

  LConfig.SessionCacheSize := 1024;
  Assert(LConfig.SessionCacheSize = 1024, 'SessionCacheSize 字段可访问');

  LConfig.SessionTimeout := 300;
  Assert(LConfig.SessionTimeout = 300, 'SessionTimeout 字段可访问');

  // 测试字符串字段
  LConfig.CertificateFile := '/path/to/cert.pem';
  Assert(LConfig.CertificateFile = '/path/to/cert.pem', 'CertificateFile 字段可访问');

  LConfig.PrivateKeyFile := '/path/to/key.pem';
  Assert(LConfig.PrivateKeyFile = '/path/to/key.pem', 'PrivateKeyFile 字段可访问');

  LConfig.CAFile := '/path/to/ca.pem';
  Assert(LConfig.CAFile = '/path/to/ca.pem', 'CAFile 字段可访问');

  LConfig.ServerName := 'example.com';
  Assert(LConfig.ServerName = 'example.com', '兼容字段 ServerName 仍可访问');

  LConfig.ALPNProtocols := 'h2,http/1.1';
  Assert(LConfig.ALPNProtocols = 'h2,http/1.1', 'ALPNProtocols 字段可访问');

  // 测试布尔字段
  LConfig.EnableCompression := True;
  Assert(LConfig.EnableCompression, 'EnableCompression 字段可访问');

  LConfig.EnableSessionTickets := True;
  Assert(LConfig.EnableSessionTickets, 'EnableSessionTickets 字段可访问');

  LConfig.EnableOCSPStapling := True;
  Assert(LConfig.EnableOCSPStapling, 'EnableOCSPStapling 字段可访问');

  WriteLn;
end;

procedure TestStatisticsStructure;
var
  LStats: TSSLStatistics;
begin
  WriteLn('【测试 4】TSSLStatistics 结构');
  WriteLn('---');

  // 验证结构大小
  Assert(SizeOf(TSSLStatistics) > 0, 'TSSLStatistics 大小 > 0');

  // 初始化结构
  FillChar(LStats, SizeOf(LStats), 0);

  // 测试 Int64 字段
  LStats.ConnectionsTotal := 1000;
  Assert(LStats.ConnectionsTotal = 1000, 'ConnectionsTotal 字段可访问');

  LStats.HandshakesSuccessful := 950;
  Assert(LStats.HandshakesSuccessful = 950, 'HandshakesSuccessful 字段可访问');

  LStats.HandshakesFailed := 50;
  Assert(LStats.HandshakesFailed = 50, 'HandshakesFailed 字段可访问');

  LStats.BytesSent := 1048576;
  Assert(LStats.BytesSent = 1048576, 'BytesSent 字段可访问');

  LStats.BytesReceived := 2097152;
  Assert(LStats.BytesReceived = 2097152, 'BytesReceived 字段可访问');

  // Phase 3.3 字段
  LStats.HandshakeTimeTotal := 50000;
  Assert(LStats.HandshakeTimeTotal = 50000, 'HandshakeTimeTotal 字段可访问');

  LStats.SessionsReused := 700;
  Assert(LStats.SessionsReused = 700, 'SessionsReused 字段可访问');

  LStats.SessionsCreated := 300;
  Assert(LStats.SessionsCreated = 300, 'SessionsCreated 字段可访问');

  // 测试 Integer 字段
  LStats.ConnectionsActive := 10;
  Assert(LStats.ConnectionsActive = 10, 'ConnectionsActive 字段可访问');

  LStats.HandshakeTimeMin := 30;
  Assert(LStats.HandshakeTimeMin = 30, 'HandshakeTimeMin 字段可访问');

  LStats.HandshakeTimeMax := 200;
  Assert(LStats.HandshakeTimeMax = 200, 'HandshakeTimeMax 字段可访问');

  LStats.HandshakeTimeAvg := 52;
  Assert(LStats.HandshakeTimeAvg = 52, 'HandshakeTimeAvg 字段可访问');

  // 测试 Double 字段
  LStats.SessionReuseRate := 70.0;
  Assert(Abs(LStats.SessionReuseRate - 70.0) < 0.01, 'SessionReuseRate 字段可访问');

  WriteLn;
end;

procedure TestPhase33Structures;
var
  LHealth: TSSLHealthStatus;
  LMetrics: TSSLPerformanceMetrics;
  LError: TSSLErrorRecord;
  LDiag: TSSLDiagnosticInfo;
begin
  WriteLn('【测试 5】Phase 3.3 新增结构');
  WriteLn('---');

  // TSSLHealthStatus
  Assert(SizeOf(TSSLHealthStatus) > 0, 'TSSLHealthStatus 大小 > 0');
  FillChar(LHealth, SizeOf(LHealth), 0);
  LHealth.IsConnected := True;
  LHealth.BytesSent := 1024;
  Assert(LHealth.IsConnected, 'TSSLHealthStatus 可初始化和访问');

  // TSSLPerformanceMetrics
  Assert(SizeOf(TSSLPerformanceMetrics) > 0, 'TSSLPerformanceMetrics 大小 > 0');
  FillChar(LMetrics, SizeOf(LMetrics), 0);
  LMetrics.HandshakeTime := 100;
  LMetrics.SessionReused := True;
  Assert(LMetrics.HandshakeTime = 100, 'TSSLPerformanceMetrics 可初始化和访问');

  // TSSLErrorRecord
  Assert(SizeOf(TSSLErrorRecord) > 0, 'TSSLErrorRecord 大小 > 0');
  FillChar(LError, SizeOf(LError), 0);
  LError.ErrorCode := sslErrTimeout;
  LError.ErrorMessage := 'Test error';
  Assert(LError.ErrorCode = sslErrTimeout, 'TSSLErrorRecord 可初始化和访问');

  // TSSLDiagnosticInfo
  Assert(SizeOf(TSSLDiagnosticInfo) > 0, 'TSSLDiagnosticInfo 大小 > 0');
  SetLength(LDiag.ErrorHistory, 5);
  Assert(Length(LDiag.ErrorHistory) = 5, 'TSSLDiagnosticInfo 可初始化和访问');

  WriteLn;
end;

procedure TestBackendCapabilitiesStructure;
var
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn('【测试 6】TSSLBackendCapabilities 结构');
  WriteLn('---');

  // 验证结构大小
  Assert(SizeOf(TSSLBackendCapabilities) > 0, 'TSSLBackendCapabilities 大小 > 0');

  // 初始化结构
  FillChar(LCaps, SizeOf(LCaps), 0);

  // 测试布尔字段
  LCaps.SupportsTLS13 := True;
  Assert(LCaps.SupportsTLS13, 'SupportsTLS13 字段可访问');

  LCaps.SupportsALPN := True;
  Assert(LCaps.SupportsALPN, 'SupportsALPN 字段可访问');

  LCaps.SupportsSNI := True;
  Assert(LCaps.SupportsSNI, 'SupportsSNI 字段可访问');

  LCaps.SupportsOCSPStapling := True;
  Assert(LCaps.SupportsOCSPStapling, 'SupportsOCSPStapling 字段可访问');

  LCaps.SupportsCertificateTransparency := True;
  Assert(LCaps.SupportsCertificateTransparency, 'SupportsCertificateTransparency 字段可访问');

  LCaps.SupportsSessionTickets := True;
  Assert(LCaps.SupportsSessionTickets, 'SupportsSessionTickets 字段可访问');

  LCaps.SupportsECDHE := True;
  Assert(LCaps.SupportsECDHE, 'SupportsECDHE 字段可访问');

  LCaps.SupportsChaChaPoly := True;
  Assert(LCaps.SupportsChaChaPoly, 'SupportsChaChaPoly 字段可访问');

  LCaps.SupportsPEMPrivateKey := True;
  Assert(LCaps.SupportsPEMPrivateKey, 'SupportsPEMPrivateKey 字段可访问');

  // 测试枚举字段
  LCaps.MinTLSVersion := sslProtocolTLS10;
  Assert(LCaps.MinTLSVersion = sslProtocolTLS10, 'MinTLSVersion 字段可访问');

  LCaps.MaxTLSVersion := sslProtocolTLS13;
  Assert(LCaps.MaxTLSVersion = sslProtocolTLS13, 'MaxTLSVersion 字段可访问');

  WriteLn;
end;

procedure TestCertificateArrayType;
var
  LCertArray: TSSLCertificateArray;
begin
  WriteLn('【测试 7】TSSLCertificateArray 动态数组');
  WriteLn('---');

  // 测试空数组
  LCertArray := nil;
  Assert(Length(LCertArray) = 0, '空证书数组长度为 0');

  // 测试数组分配
  SetLength(LCertArray, 5);
  Assert(Length(LCertArray) = 5, '可以设置证书数组长度');

  // 测试数组清空
  SetLength(LCertArray, 0);
  Assert(Length(LCertArray) = 0, '可以清空证书数组');

  WriteLn;
end;

procedure TestStringArrayType;
var
  LStrArray: TSSLStringArray;
begin
  WriteLn('【测试 8】TSSLStringArray 动态数组');
  WriteLn('---');

  // 测试空数组
  LStrArray := nil;
  Assert(Length(LStrArray) = 0, '空字符串数组长度为 0');

  // 测试数组分配和赋值
  SetLength(LStrArray, 3);
  LStrArray[0] := 'first';
  LStrArray[1] := 'second';
  LStrArray[2] := 'third';
  Assert(Length(LStrArray) = 3, '可以设置字符串数组长度');
  Assert(LStrArray[0] = 'first', '可以访问数组元素');
  Assert(LStrArray[2] = 'third', '可以访问数组元素');

  WriteLn;
end;

procedure TestStructureAlignment;
begin
  WriteLn('【测试 9】结构对齐和大小');
  WriteLn('---');

  // 验证关键结构的大小合理性
  Assert(SizeOf(TSSLCertificateInfo) >= 100, 'TSSLCertificateInfo 大小合理');
  Assert(SizeOf(TSSLConnectionInfo) >= 50, 'TSSLConnectionInfo 大小合理');
  Assert(SizeOf(TSSLConfig) >= 100, 'TSSLConfig 大小合理');
  Assert(SizeOf(TSSLStatistics) >= 100, 'TSSLStatistics 大小合理');

  // Phase 3.3 结构
  Assert(SizeOf(TSSLHealthStatus) >= 30, 'TSSLHealthStatus 大小合理');
  Assert(SizeOf(TSSLPerformanceMetrics) >= 20, 'TSSLPerformanceMetrics 大小合理');
  Assert(SizeOf(TSSLErrorRecord) >= 20, 'TSSLErrorRecord 大小合理');

  // 验证指针大小
  Assert(SizeOf(Pointer) > 0, 'Pointer 大小 > 0');
  Assert(SizeOf(PSSLCertificateInfo) = SizeOf(Pointer), 'PSSLCertificateInfo 是指针');
  Assert(SizeOf(PSSLConnectionInfo) = SizeOf(Pointer), 'PSSLConnectionInfo 是指针');

  WriteLn;
end;

procedure TestStructureInitialization;
var
  LCertInfo: TSSLCertificateInfo;
  LConnInfo: TSSLConnectionInfo;
  LConfig: TSSLConfig;
  LStats: TSSLStatistics;
begin
  WriteLn('【测试 10】结构初始化');
  WriteLn('---');

  // 测试 FillChar 初始化
  FillChar(LCertInfo, SizeOf(LCertInfo), 0);
  Assert(LCertInfo.Version = 0, 'FillChar 可以初始化 TSSLCertificateInfo');

  FillChar(LConnInfo, SizeOf(LConnInfo), 0);
  Assert(LConnInfo.KeySize = 0, 'FillChar 可以初始化 TSSLConnectionInfo');

  FillChar(LConfig, SizeOf(LConfig), 0);
  Assert(LConfig.BufferSize = 0, 'FillChar 可以初始化 TSSLConfig');

  FillChar(LStats, SizeOf(LStats), 0);
  Assert(LStats.ConnectionsTotal = 0, 'FillChar 可以初始化 TSSLStatistics');

  // 测试部分初始化
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.LibraryType := sslOpenSSL;
  LConfig.BufferSize := 16384;
  Assert(LConfig.LibraryType = sslOpenSSL, '部分初始化后字段可访问');
  Assert(LConfig.BufferSize = 16384, '部分初始化后字段可访问');

  WriteLn;
end;

procedure TestStructureCopying;
var
  LConfig1, LConfig2: TSSLConfig;
begin
  WriteLn('【测试 11】结构复制');
  WriteLn('---');

  // 初始化第一个结构
  FillChar(LConfig1, SizeOf(LConfig1), 0);
  LConfig1.LibraryType := sslOpenSSL;
  LConfig1.ContextType := sslCtxClient;
  LConfig1.BufferSize := 16384;
  LConfig1.ServerName := 'example.com';

  // 复制结构
  LConfig2 := LConfig1;

  // 验证复制成功
  Assert(LConfig2.LibraryType = sslOpenSSL, '结构复制后 LibraryType 正确');
  Assert(LConfig2.ContextType = sslCtxClient, '结构复制后 ContextType 正确');
  Assert(LConfig2.BufferSize = 16384, '结构复制后 BufferSize 正确');
  Assert(LConfig2.ServerName = 'example.com', '结构复制后兼容字段 ServerName 正确');

  // 修改副本不影响原始
  LConfig2.BufferSize := 32768;
  Assert(LConfig1.BufferSize = 16384, '修改副本不影响原始结构');
  Assert(LConfig2.BufferSize = 32768, '副本可以独立修改');

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
    WriteLn('✓ 所有数据结构测试通过！');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，请检查数据结构定义');
  end;
  WriteLn('=========================================');
end;

begin
  WriteLn('=========================================');
  WriteLn('数据结构测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  try
    TestCertificateInfoStructure;
    TestConnectionInfoStructure;
    TestConfigStructure;
    TestStatisticsStructure;
    TestPhase33Structures;
    TestBackendCapabilitiesStructure;
    TestCertificateArrayType;
    TestStringArrayType;
    TestStructureAlignment;
    TestStructureInitialization;
    TestStructureCopying;

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
