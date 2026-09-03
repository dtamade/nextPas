unit test_ocsp_stapling;

{$mode ObjFPC}{$H+}

{
  OCSP Stapling 单元测试

  测试 OCSP 缓存和 Stapling 管理器的核心功能:
  - 缓存的基本操作 (Put/Get/Remove)
  - 缓存的 TTL 管理
  - 缓存统计功能
  - Stapling 客户端功能
  - Stapling 服务端功能
  - Stapling 配置管理

  @author nextpas.core.tls team
  @version 1.0.0
}

interface

uses
  nextpas.core.test,
  nextpas.core.tls.ocsp.cache,
  nextpas.core.tls.ocsp.stapling,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.x509,
  nextpas.core.time, nextpas.core.base, nextpas.core.base.utils, nextpas.core.fs, nextpas.core.math, nextpas.core.text;

type
  // ========================================================================
  // OCSP 缓存测试
  // ========================================================================

  { TOCSPCacheTest - 测试 OCSP 响应缓存 }
  TOCSPCacheTest = class(TTestFixture)
  private
    FCache: TOCSPResponseCache;
    FTestResponse: TBytes;
    FTestSerialNumber: TBytes;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    procedure TestCacheCreation;
    procedure TestCachePutAndGet;
    procedure TestCacheExpiry;
    procedure TestCacheRemove;
    procedure TestCacheClear;
    procedure TestCacheStats;
    procedure TestCacheHitRate;
    procedure TestCachePersistence;
  end;

  // ========================================================================
  // OCSP Stapling 配置测试
  // ========================================================================

  { TOCSPStaplingConfigTest - 测试 Stapling 配置 }
  TOCSPStaplingConfigTest = class(TTestFixture)
  published
    procedure TestDefaultConfig;
    procedure TestConfigCustomization;
  end;

  TOCSPStaplingResultTest = class(TTestFixture)
  published
    procedure TestIsValid;
    procedure TestNeedsRefreshWithoutNextUpdate;
    procedure TestNeedsRefreshWithinWindow;
    procedure TestNeedsRefreshWhenExpired;
    procedure TestNeedsRefreshWhenFresh;
  end;

  // ========================================================================
  // OCSP Stapling 客户端测试
  // ========================================================================

  { TOCSPStaplingClientTest - 测试客户端 Stapling }
  TOCSPStaplingClientTest = class(TTestFixture)
  private
    FClient: TOCSPStaplingClient;
    FCache: TOCSPResponseCache;
    FConfig: TOCSPStaplingConfig;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    procedure TestClientCreation;
    procedure TestShouldRequestStapling;
    procedure TestProcessValidResponse;
    procedure TestProcessInvalidResponse;
    procedure TestProcessEmptyResponse;
    procedure TestValidateStaplingRequirement;
    procedure TestResponseCaching;
  end;

  // ========================================================================
  // OCSP Stapling 服务端测试
  // ========================================================================

  { TOCSPStaplingServerTest - 测试服务端 Stapling }
  TOCSPStaplingServerTest = class(TTestFixture)
  private
    FServer: TOCSPStaplingServer;
    FCache: TOCSPResponseCache;
    FConfig: TOCSPStaplingConfig;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    procedure TestServerCreation;
    procedure TestGetStapledResponse;
    procedure TestResponseRefresh;
    procedure TestAutoRefresh;
    procedure TestCacheIntegration;
  end;

  // ========================================================================
  // OCSP Stapling 管理器测试
  // ========================================================================

  { TOCSPStaplingManagerTest - 测试统一管理器 }
  TOCSPStaplingManagerTest = class(TTestFixture)
  private
    FManager: TOCSPStaplingManager;
    FConfig: TOCSPStaplingConfig;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    procedure TestManagerCreation;
    procedure TestClientInterface;
    procedure TestServerInterface;
    procedure TestCacheManagement;
  end;

implementation

uses
  nextpas.core.time;

// ========================================================================
// TOCSPCacheTest 实现
// ========================================================================

procedure TOCSPCacheTest.BeforeEach;
begin
  FCache := TOCSPResponseCache.Create;
  SetLength(FTestSerialNumber, 16);
  FillChar(FTestSerialNumber[0], 16, $AB);
  SetLength(FTestResponse, 100);
  FillChar(FTestResponse[0], 100, $AA);
end;

procedure TOCSPCacheTest.AfterEach;
begin
  FCache.Free;
end;

procedure TOCSPCacheTest.TestCacheCreation;
begin
  CheckNotNil(FCache, 'Cache should be created');
  CheckEqual(0, FCache.GetCount, 'Cache should be empty initially');
end;

procedure TOCSPCacheTest.TestCachePutAndGet;
var
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  ThisUpdate := DateTimeUtcNow;
  NextUpdate := DateTimeUtcNow + 1.0;  // 1天后过期

  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);

  // 检查计数
  CheckEqual(1, FCache.GetCount, 'Cache should contain 1 entry');

  // 检查是否存在
  CheckTrue(FCache.Contains(FTestSerialNumber), 'Cache should contain the entry');

  // 获取响应
  CheckTrue(FCache.Get(FTestSerialNumber, Retrieved), 'Should retrieve cached response');

  // 验证内容
  CheckEqual(Length(FTestResponse), Length(Retrieved), 'Retrieved response length should match');
  CheckTrue(CompareMem(@FTestResponse[0], @Retrieved[0], Length(FTestResponse)), 'Retrieved response content should match');
end;

procedure TOCSPCacheTest.TestCacheExpiry;
var
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  ThisUpdate := DateTimeUtcNow;
  NextUpdate := DateTimeUtcNow + (1.0 / 86400.0);  // 1秒后过期 (1/86400 天)

  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);

  // 立即获取应该成功
  CheckTrue(FCache.Get(FTestSerialNumber, Retrieved), 'Should retrieve before expiry');

  // 等待过期
  MsSleep(1500);

  // 过期后获取应该失败
  CheckFalse(FCache.Get(FTestSerialNumber, Retrieved), 'Should not retrieve after expiry');
end;

procedure TOCSPCacheTest.TestCacheRemove;
var
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  ThisUpdate := DateTimeUtcNow;
  NextUpdate := DateTimeUtcNow + 1.0;  // 1天后过期

  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);
  CheckTrue(FCache.Contains(FTestSerialNumber), 'Should contain entry');

  // 移除响应
  FCache.Remove(FTestSerialNumber);

  // 验证已移除
  CheckFalse(FCache.Contains(FTestSerialNumber), 'Should not contain entry after removal');
  CheckFalse(FCache.Get(FTestSerialNumber, Retrieved), 'Should not retrieve after removal');
end;

procedure TOCSPCacheTest.TestCacheClear;
var
  ThisUpdate, NextUpdate: TDateTime;
  TestSerial: TBytes;
begin
  ThisUpdate := DateTimeUtcNow;
  NextUpdate := DateTimeUtcNow + 1.0;

  // 存储多个响应
  SetLength(TestSerial, 16);
  FillChar(TestSerial[0], 16, $01);
  FCache.Put(TestSerial, FTestResponse, ThisUpdate, NextUpdate);
  FillChar(TestSerial[0], 16, $02);
  FCache.Put(TestSerial, FTestResponse, ThisUpdate, NextUpdate);
  FillChar(TestSerial[0], 16, $03);
  FCache.Put(TestSerial, FTestResponse, ThisUpdate, NextUpdate);

  CheckEqual(3, FCache.GetCount, 'Cache should contain 3 entries');

  // 清空缓存
  FCache.Clear;

  // 验证已清空
  CheckEqual(0, FCache.GetCount, 'Cache should be empty after clear');
end;

procedure TOCSPCacheTest.TestCacheStats;
var
  Stats: TOCSPCacheStats;
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
  TestSerial: TBytes;
begin
  ThisUpdate := DateTimeUtcNow;
  NextUpdate := DateTimeUtcNow + 1.0;

  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);

  // 命中
  FCache.Get(FTestSerialNumber, Retrieved);

  // 未命中
  SetLength(TestSerial, 16);
  FillChar(TestSerial[0], 16, $FF);
  FCache.Get(TestSerial, Retrieved);

  // 获取统计
  Stats := FCache.GetStats;

  CheckEqual(1, Stats.TotalEntries, 'Total entries should be 1');
  CheckEqual(1, Stats.Hits, 'Hits should be 1');
  CheckEqual(1, Stats.Misses, 'Misses should be 1');
end;

procedure TOCSPCacheTest.TestCacheHitRate;
var
  Stats: TOCSPCacheStats;
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
  I: Integer;
  TestSerial: TBytes;
begin
  ThisUpdate := DateTimeUtcNow;
  NextUpdate := DateTimeUtcNow + 1.0;

  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);

  // 10次命中
  for I := 1 to 10 do
    FCache.Get(FTestSerialNumber, Retrieved);

  // 5次未命中
  SetLength(TestSerial, 16);
  for I := 1 to 5 do
  begin
    FillChar(TestSerial[0], 16, Byte(I + 100));
    FCache.Get(TestSerial, Retrieved);
  end;

  // 获取统计
  Stats := FCache.GetStats;

  CheckEqual(10, Stats.Hits, 'Hits should be 10');
  CheckEqual(5, Stats.Misses, 'Misses should be 5');

  // 命中率应该是 10/(10+5) = 66.67%
  CheckTrue(Abs(Stats.HitRate - 66.67) < 0.1, 'Hit rate should be around 66.67%');
end;

procedure TOCSPCacheTest.TestCachePersistence;
var
  TempFile: string;
  NewCache: TOCSPResponseCache;
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  TempFile := GetTempFileName;
  try
    ThisUpdate := DateTimeUtcNow;
    NextUpdate := DateTimeUtcNow + 1.0;

    // 存储响应
    FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);

    // 保存到文件
    CheckTrue(FCache.SaveToFile(TempFile), 'Should save to file');

    // 创建新缓存并加载
    NewCache := TOCSPResponseCache.Create;
    try
      CheckTrue(NewCache.LoadFromFile(TempFile), 'Should load from file');

      // 验证数据
      CheckEqual(FCache.GetCount, NewCache.GetCount, 'Loaded cache should have same count');
      CheckTrue(NewCache.Get(FTestSerialNumber, Retrieved), 'Should retrieve from loaded cache');
      CheckEqual(Length(FTestResponse), Length(Retrieved), 'Retrieved response should match');
    finally
      NewCache.Free;
    end;
  finally
    DeleteFile(TempFile);
  end;
end;

// ========================================================================
// TOCSPStaplingConfigTest 实现
// ========================================================================

procedure TOCSPStaplingConfigTest.TestDefaultConfig;
var
  Config: TOCSPStaplingConfig;
begin
  Config := TOCSPStaplingConfig.Default;

  CheckTrue(Config.EnableClientRequest, 'Client request should be enabled by default');
  CheckTrue(Config.EnableServerStapling, 'Server stapling should be enabled by default');
  CheckFalse(Config.RequireStapling, 'Stapling should not be required by default');
  CheckTrue(Config.AutoRefresh, 'Auto refresh should be enabled by default');
  CheckEqual(3600, Config.RefreshBeforeExpiry, 'Refresh before expiry should be 3600');
  CheckEqual(3, Config.MaxRetries, 'Max retries should be 3');
  CheckEqual(10, Config.TimeoutSeconds, 'Timeout should be 10 seconds');
  CheckTrue(Config.UseCache, 'Cache should be enabled by default');
end;

procedure TOCSPStaplingConfigTest.TestConfigCustomization;
var
  Config: TOCSPStaplingConfig;
begin
  Config := TOCSPStaplingConfig.Default;

  // 自定义配置
  Config.EnableClientRequest := False;
  Config.RequireStapling := True;
  Config.RefreshBeforeExpiry := 7200;
  Config.MaxRetries := 5;
  Config.TimeoutSeconds := 30;

  // 验证自定义值
  CheckFalse(Config.EnableClientRequest, 'Client request should be disabled');
  CheckTrue(Config.RequireStapling, 'Stapling should be required');
  CheckEqual(7200, Config.RefreshBeforeExpiry, 'Refresh before expiry should be 7200');
  CheckEqual(5, Config.MaxRetries, 'Max retries should be 5');
  CheckEqual(30, Config.TimeoutSeconds, 'Timeout should be 30 seconds');
end;

procedure TOCSPStaplingResultTest.TestIsValid;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.Status := ossVerified;
  LResult.CertStatus := ocspGood;
  CheckTrue(LResult.IsValid, 'Verified good response should be valid');

  LResult.Status := ossExpired;
  CheckFalse(LResult.IsValid, 'Expired response should not be valid');
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWithoutNextUpdate;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := 0;
  CheckFalse(LResult.NeedsRefresh, 'Missing nextUpdate should not request refresh');
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWithinWindow;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := DateTimeAddSeconds(DateTimeUtcNow, 1800);
  CheckTrue(LResult.NeedsRefresh, 'Response expiring within one hour should refresh');
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWhenExpired;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := DateTimeAddSeconds(DateTimeUtcNow, -7200);
  CheckTrue(LResult.NeedsRefresh, 'Expired response should refresh even when long expired');
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWhenFresh;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := DateTimeAddSeconds(DateTimeUtcNow, 7200);
  CheckFalse(LResult.NeedsRefresh, 'Response expiring after the refresh window should stay fresh');
end;

// ========================================================================
// TOCSPStaplingClientTest 实现
// ========================================================================

procedure TOCSPStaplingClientTest.BeforeEach;
begin
  FConfig := TOCSPStaplingConfig.Default;
  FCache := TOCSPResponseCache.Create;
  FClient := TOCSPStaplingClient.Create(FConfig, FCache);
end;

procedure TOCSPStaplingClientTest.AfterEach;
begin
  FClient.Free;
  FCache.Free;
end;

procedure TOCSPStaplingClientTest.TestClientCreation;
begin
  CheckNotNil(FClient, 'Client should be created');
end;

procedure TOCSPStaplingClientTest.TestShouldRequestStapling;
begin
  // 默认配置应该请求 stapling
  CheckTrue(FClient.ShouldRequestStapling, 'Should request stapling by default');

  // 禁用后不应该请求
  FConfig.EnableClientRequest := False;
  FClient.Config := FConfig;
  CheckFalse(FClient.ShouldRequestStapling, 'Should not request stapling when disabled');
end;

procedure TOCSPStaplingClientTest.TestProcessValidResponse;
var
  LResult: TOCSPStaplingResult;
  LResponse: TBytes;
  LCert, LIssuerCert: TX509Certificate;
begin
  // 使用最小 successful OCSP DER（无 SingleResponse），验证确定性失败路径
  SetLength(LResponse, 5);
  LResponse[0] := 48;
  LResponse[1] := 3;
  LResponse[2] := 10;
  LResponse[3] := 1;
  LResponse[4] := 0;

  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LResult := FClient.ProcessStapledResponse(LResponse, LCert, LIssuerCert);
    CheckTrue(LResult.Status = ossVerificationFailed, 'Successful DER without matching cert should fail verification');
    CheckTrue(Pos('Certificate', LResult.ErrorMessage) > 0, 'Error message should mention certificate lookup');
    CheckTrue(FClient.LastResult.Status = LResult.Status, 'LastResult should track latest status');
  finally
    LCert.Free;
    LIssuerCert.Free;
  end;
end;

procedure TOCSPStaplingClientTest.TestProcessInvalidResponse;
var
  Result: TOCSPStaplingResult;
  Response: TBytes;
  Cert, IssuerCert: TX509Certificate;
begin
  // 测试无效响应
  SetLength(Response, 10);
  FillChar(Response[0], 10, $FF);

  Cert := TX509Certificate.Create;
  IssuerCert := TX509Certificate.Create;
  try
    Result := FClient.ProcessStapledResponse(Response, Cert, IssuerCert);
    CheckTrue(Result.Status = ossVerificationFailed, 'Status should be verification failed');
    CheckTrue(Result.ErrorMessage <> '', 'Error message should not be empty');
  finally
    Cert.Free;
    IssuerCert.Free;
  end;
end;

procedure TOCSPStaplingClientTest.TestProcessEmptyResponse;
var
  Result: TOCSPStaplingResult;
  Response: TBytes;
  Cert, IssuerCert: TX509Certificate;
begin
  // 测试空响应
  SetLength(Response, 0);

  Cert := TX509Certificate.Create;
  IssuerCert := TX509Certificate.Create;
  try
    Result := FClient.ProcessStapledResponse(Response, Cert, IssuerCert);
    CheckTrue(Result.Status = ossNotProvided, 'Status should be not provided');
  finally
    Cert.Free;
    IssuerCert.Free;
  end;
end;

procedure TOCSPStaplingClientTest.TestValidateStaplingRequirement;
begin
  // 不要求 stapling 时总是通过
  FConfig.RequireStapling := False;
  FClient.Config := FConfig;
  CheckTrue(FClient.ValidateStaplingRequirement(False), 'Should validate when not required');

  // 要求 stapling 但未提供时失败
  FConfig.RequireStapling := True;
  FClient.Config := FConfig;
  CheckFalse(FClient.ValidateStaplingRequirement(False), 'Should not validate when required but not provided');
end;

procedure TOCSPStaplingClientTest.TestResponseCaching;
var
  LInvalidResult: TOCSPStaplingResult;
  LEmptyResult: TOCSPStaplingResult;
  LInvalid, LEmpty: TBytes;
  LCert, LIssuerCert: TX509Certificate;
begin
  FillChar(LInvalidResult, SizeOf(LInvalidResult), 0);
  FillChar(LEmptyResult, SizeOf(LEmptyResult), 0);
  SetLength(LInvalid, 10);
  FillChar(LInvalid[0], 10, 255);
  SetLength(LEmpty, 0);

  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LInvalidResult := FClient.ProcessStapledResponse(LInvalid, LCert, LIssuerCert);
    CheckTrue(LInvalidResult.Status = ossVerificationFailed, 'Invalid response should fail verification');
    CheckEqual(0, FCache.GetCount, 'Failed response should not be cached');

    LEmptyResult := FClient.ProcessStapledResponse(LEmpty, LCert, LIssuerCert);
    CheckTrue(LEmptyResult.Status = ossNotProvided, 'Empty response should be marked as not provided');
    CheckEqual(0, FCache.GetCount, 'Empty response should not be cached');
  finally
    Finalize(LEmptyResult);
    Finalize(LInvalidResult);
    LCert.Free;
    LIssuerCert.Free;
  end;
end;

// ========================================================================
// TOCSPStaplingServerTest 实现
// ========================================================================

procedure TOCSPStaplingServerTest.BeforeEach;
begin
  FConfig := TOCSPStaplingConfig.Default;
  FCache := TOCSPResponseCache.Create;
  FServer := TOCSPStaplingServer.Create(FConfig, FCache);
end;

procedure TOCSPStaplingServerTest.AfterEach;
begin
  FServer.Free;
  FCache.Free;
end;

procedure TOCSPStaplingServerTest.TestServerCreation;
begin
  CheckNotNil(FServer, 'Server should be created');
end;

procedure TOCSPStaplingServerTest.TestGetStapledResponse;
var
  LConfig: TOCSPStaplingConfig;
  LServer: TOCSPStaplingServer;
  LCert, LIssuerCert: TX509Certificate;
  LResponse: TBytes;
begin
  // 在禁用 stapling 配置下，服务端应稳定返回空响应（不触发网络）
  LConfig := TOCSPStaplingConfig.Default;
  LConfig.EnableServerStapling := False;
  LServer := TOCSPStaplingServer.Create(LConfig, FCache);
  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LResponse := LServer.GetStapledResponse(LCert, LIssuerCert, False);
    CheckEqual(0, Length(LResponse), 'Disabled stapling should return empty response');
  finally
    LCert.Free;
    LIssuerCert.Free;
    LServer.Free;
  end;
end;

procedure TOCSPStaplingServerTest.TestResponseRefresh;
var
  LCert, LIssuerCert: TX509Certificate;
begin
  // 空白证书不包含 AIA OCSP URL，刷新应失败但不能抛异常
  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    CheckFalse(FServer.RefreshResponse(LCert, LIssuerCert), 'Refresh should fail when certificate has no OCSP URL');
  finally
    LCert.Free;
    LIssuerCert.Free;
  end;
end;

procedure TOCSPStaplingServerTest.TestAutoRefresh;
begin
  // 测试自动刷新启用/禁用
  CheckFalse(FServer.AutoRefreshEnabled, 'Auto refresh should be disabled initially');

  FServer.EnableAutoRefresh;
  CheckTrue(FServer.AutoRefreshEnabled, 'Auto refresh should be enabled');

  FServer.DisableAutoRefresh;
  CheckFalse(FServer.AutoRefreshEnabled, 'Auto refresh should be disabled');
end;

procedure TOCSPStaplingServerTest.TestCacheIntegration;
var
  LConfig: TOCSPStaplingConfig;
  LServer: TOCSPStaplingServer;
  LThisUpdate, LNextUpdate: TDateTime;
  LSerial, LCachedResponse, LReturned: TBytes;
  LCert, LIssuerCert: TX509Certificate;
begin
  // 预置缓存条目，验证禁用 stapling 时不会破坏缓存内容
  SetLength(LSerial, 0);
  SetLength(LCachedResponse, 5);
  LCachedResponse[0] := 48;
  LCachedResponse[1] := 3;
  LCachedResponse[2] := 10;
  LCachedResponse[3] := 1;
  LCachedResponse[4] := 0;
  LThisUpdate := DateTimeUtcNow;
  LNextUpdate := DateTimeUtcNow + 1.0;
  FCache.Put(LSerial, LCachedResponse, LThisUpdate, LNextUpdate);
  CheckEqual(1, FCache.GetCount, 'Cache should contain preload entry');

  LConfig := TOCSPStaplingConfig.Default;
  LConfig.EnableServerStapling := False;
  LServer := TOCSPStaplingServer.Create(LConfig, FCache);
  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LReturned := LServer.GetStapledResponse(LCert, LIssuerCert, False);
    CheckEqual(0, Length(LReturned), 'Disabled server should return empty response');
    CheckEqual(1, FCache.GetCount, 'Cache entry should remain unchanged');
  finally
    LCert.Free;
    LIssuerCert.Free;
    LServer.Free;
  end;
end;

// ========================================================================
// TOCSPStaplingManagerTest 实现
// ========================================================================

procedure TOCSPStaplingManagerTest.BeforeEach;
begin
  FConfig := TOCSPStaplingConfig.Default;
  FManager := TOCSPStaplingManager.Create(FConfig);
end;

procedure TOCSPStaplingManagerTest.AfterEach;
begin
  FManager.Free;
end;

procedure TOCSPStaplingManagerTest.TestManagerCreation;
begin
  CheckNotNil(FManager, 'Manager should be created');
  CheckNotNil(FManager.Client, 'Client should be created');
  CheckNotNil(FManager.Server, 'Server should be created');
  CheckNotNil(FManager.Cache, 'Cache should be created');
end;

procedure TOCSPStaplingManagerTest.TestClientInterface;
begin
  // 测试客户端接口
  CheckTrue(FManager.ClientShouldRequest, 'Should request stapling');
end;

procedure TOCSPStaplingManagerTest.TestServerInterface;
var
  LConfig: TOCSPStaplingConfig;
  LManager: TOCSPStaplingManager;
  LCert, LIssuerCert: TX509Certificate;
  LResponse: TBytes;
begin
  LConfig := TOCSPStaplingConfig.Default;
  LConfig.EnableServerStapling := False;
  LManager := TOCSPStaplingManager.Create(LConfig);
  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LResponse := LManager.ServerGetResponse(LCert, LIssuerCert);
    CheckEqual(0, Length(LResponse), 'Server response should be empty when stapling disabled');
    CheckFalse(LManager.ServerRefreshResponse(LCert, LIssuerCert), 'Server refresh should fail without OCSP URL');
  finally
    LCert.Free;
    LIssuerCert.Free;
    LManager.Free;
  end;
end;

procedure TOCSPStaplingManagerTest.TestCacheManagement;
var
  Stats: TOCSPCacheStats;
begin
  // 测试缓存管理
  Stats := FManager.GetCacheStats;
  CheckEqual(0, Stats.TotalEntries, 'Cache should be empty initially');

  // 清空缓存
  FManager.ClearCache;
  Stats := FManager.GetCacheStats;
  CheckEqual(0, Stats.TotalEntries, 'Cache should be empty after clear');
end;

// ========================================================================
// 注册测试
// ========================================================================

end.
