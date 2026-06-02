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
  
  @author fafafa.ssl team
  @version 1.0.0
}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  nextpas.core.tls.ocsp.cache,
  nextpas.core.tls.ocsp.stapling,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.x509,
  nextpas.core.time;

type
  // ========================================================================
  // OCSP 缓存测试
  // ========================================================================
  
  { TOCSPCacheTest - 测试 OCSP 响应缓存 }
  TOCSPCacheTest = class(TTestCase)
  private
    FCache: TOCSPResponseCache;
    FTestResponse: TBytes;
    FTestSerialNumber: TBytes;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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
  TOCSPStaplingConfigTest = class(TTestCase)
  published
    procedure TestDefaultConfig;
    procedure TestConfigCustomization;
  end;

  TOCSPStaplingResultTest = class(TTestCase)
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
  TOCSPStaplingClientTest = class(TTestCase)
  private
    FClient: TOCSPStaplingClient;
    FCache: TOCSPResponseCache;
    FConfig: TOCSPStaplingConfig;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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
  TOCSPStaplingServerTest = class(TTestCase)
  private
    FServer: TOCSPStaplingServer;
    FCache: TOCSPResponseCache;
    FConfig: TOCSPStaplingConfig;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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
  TOCSPStaplingManagerTest = class(TTestCase)
  private
    FManager: TOCSPStaplingManager;
    FConfig: TOCSPStaplingConfig;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestManagerCreation;
    procedure TestClientInterface;
    procedure TestServerInterface;
    procedure TestCacheManagement;
  end;

implementation

uses
  DateUtils;

// ========================================================================
// TOCSPCacheTest 实现
// ========================================================================

procedure TOCSPCacheTest.SetUp;
begin
  FCache := TOCSPResponseCache.Create;
  SetLength(FTestSerialNumber, 16);
  FillChar(FTestSerialNumber[0], 16, $AB);
  SetLength(FTestResponse, 100);
  FillChar(FTestResponse[0], 100, $AA);
end;

procedure TOCSPCacheTest.TearDown;
begin
  FCache.Free;
end;

procedure TOCSPCacheTest.TestCacheCreation;
begin
  AssertNotNull('Cache should be created', FCache);
  AssertEquals('Cache should be empty initially', 0, FCache.GetCount);
end;

procedure TOCSPCacheTest.TestCachePutAndGet;
var
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  ThisUpdate := Now;
  NextUpdate := Now + 1.0;  // 1天后过期
  
  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);
  
  // 检查计数
  AssertEquals('Cache should contain 1 entry', 1, FCache.GetCount);
  
  // 检查是否存在
  AssertTrue('Cache should contain the entry', 
    FCache.Contains(FTestSerialNumber));
  
  // 获取响应
  AssertTrue('Should retrieve cached response', 
    FCache.Get(FTestSerialNumber, Retrieved));
  
  // 验证内容
  AssertEquals('Retrieved response length should match', 
    Length(FTestResponse), Length(Retrieved));
  AssertTrue('Retrieved response content should match',
    CompareMem(@FTestResponse[0], @Retrieved[0], Length(FTestResponse)));
end;

procedure TOCSPCacheTest.TestCacheExpiry;
var
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  ThisUpdate := Now;
  NextUpdate := Now + (1.0 / 86400.0);  // 1秒后过期 (1/86400 天)
  
  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);
  
  // 立即获取应该成功
  AssertTrue('Should retrieve before expiry', 
    FCache.Get(FTestSerialNumber, Retrieved));
  
  // 等待过期
  Sleep(1500);
  
  // 过期后获取应该失败
  AssertFalse('Should not retrieve after expiry', 
    FCache.Get(FTestSerialNumber, Retrieved));
end;

procedure TOCSPCacheTest.TestCacheRemove;
var
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
begin
  ThisUpdate := Now;
  NextUpdate := Now + 1.0;  // 1天后过期
  
  // 存储响应
  FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);
  AssertTrue('Should contain entry', FCache.Contains(FTestSerialNumber));
  
  // 移除响应
  FCache.Remove(FTestSerialNumber);
  
  // 验证已移除
  AssertFalse('Should not contain entry after removal', 
    FCache.Contains(FTestSerialNumber));
  AssertFalse('Should not retrieve after removal', 
    FCache.Get(FTestSerialNumber, Retrieved));
end;

procedure TOCSPCacheTest.TestCacheClear;
var
  ThisUpdate, NextUpdate: TDateTime;
  TestSerial: TBytes;
begin
  ThisUpdate := Now;
  NextUpdate := Now + 1.0;
  
  // 存储多个响应
  SetLength(TestSerial, 16);
  FillChar(TestSerial[0], 16, $01);
  FCache.Put(TestSerial, FTestResponse, ThisUpdate, NextUpdate);
  FillChar(TestSerial[0], 16, $02);
  FCache.Put(TestSerial, FTestResponse, ThisUpdate, NextUpdate);
  FillChar(TestSerial[0], 16, $03);
  FCache.Put(TestSerial, FTestResponse, ThisUpdate, NextUpdate);
  
  AssertEquals('Cache should contain 3 entries', 3, FCache.GetCount);
  
  // 清空缓存
  FCache.Clear;
  
  // 验证已清空
  AssertEquals('Cache should be empty after clear', 0, FCache.GetCount);
end;

procedure TOCSPCacheTest.TestCacheStats;
var
  Stats: TOCSPCacheStats;
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
  TestSerial: TBytes;
begin
  ThisUpdate := Now;
  NextUpdate := Now + 1.0;
  
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
  
  AssertEquals('Total entries should be 1', 1, Stats.TotalEntries);
  AssertEquals('Hits should be 1', 1, Stats.Hits);
  AssertEquals('Misses should be 1', 1, Stats.Misses);
end;

procedure TOCSPCacheTest.TestCacheHitRate;
var
  Stats: TOCSPCacheStats;
  Retrieved: TBytes;
  ThisUpdate, NextUpdate: TDateTime;
  I: Integer;
  TestSerial: TBytes;
begin
  ThisUpdate := Now;
  NextUpdate := Now + 1.0;
  
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
  
  AssertEquals('Hits should be 10', 10, Stats.Hits);
  AssertEquals('Misses should be 5', 5, Stats.Misses);
  
  // 命中率应该是 10/(10+5) = 66.67%
  AssertTrue('Hit rate should be around 66.67%', 
    Abs(Stats.HitRate - 66.67) < 0.1);
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
    ThisUpdate := Now;
    NextUpdate := Now + 1.0;
    
    // 存储响应
    FCache.Put(FTestSerialNumber, FTestResponse, ThisUpdate, NextUpdate);
    
    // 保存到文件
    AssertTrue('Should save to file', FCache.SaveToFile(TempFile));
    
    // 创建新缓存并加载
    NewCache := TOCSPResponseCache.Create;
    try
      AssertTrue('Should load from file', NewCache.LoadFromFile(TempFile));
      
      // 验证数据
      AssertEquals('Loaded cache should have same count', 
        FCache.GetCount, NewCache.GetCount);
      AssertTrue('Should retrieve from loaded cache', 
        NewCache.Get(FTestSerialNumber, Retrieved));
      AssertEquals('Retrieved response should match', 
        Length(FTestResponse), Length(Retrieved));
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
  
  AssertTrue('Client request should be enabled by default', 
    Config.EnableClientRequest);
  AssertTrue('Server stapling should be enabled by default', 
    Config.EnableServerStapling);
  AssertFalse('Stapling should not be required by default', 
    Config.RequireStapling);
  AssertTrue('Auto refresh should be enabled by default', 
    Config.AutoRefresh);
  AssertEquals('Refresh before expiry should be 3600', 
    3600, Config.RefreshBeforeExpiry);
  AssertEquals('Max retries should be 3', 3, Config.MaxRetries);
  AssertEquals('Timeout should be 10 seconds', 10, Config.TimeoutSeconds);
  AssertTrue('Cache should be enabled by default', Config.UseCache);
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
  AssertFalse('Client request should be disabled', 
    Config.EnableClientRequest);
  AssertTrue('Stapling should be required', Config.RequireStapling);
  AssertEquals('Refresh before expiry should be 7200', 
    7200, Config.RefreshBeforeExpiry);
  AssertEquals('Max retries should be 5', 5, Config.MaxRetries);
  AssertEquals('Timeout should be 30 seconds', 30, Config.TimeoutSeconds);
end;

procedure TOCSPStaplingResultTest.TestIsValid;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.Status := ossVerified;
  LResult.CertStatus := ocspGood;
  AssertTrue('Verified good response should be valid', LResult.IsValid);

  LResult.Status := ossExpired;
  AssertFalse('Expired response should not be valid', LResult.IsValid);
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWithoutNextUpdate;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := 0;
  AssertFalse('Missing nextUpdate should not request refresh', LResult.NeedsRefresh);
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWithinWindow;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := DateTimeAddSeconds(DateTimeNow, 1800);
  AssertTrue('Response expiring within one hour should refresh', LResult.NeedsRefresh);
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWhenExpired;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := DateTimeAddSeconds(DateTimeNow, -7200);
  AssertTrue('Expired response should refresh even when long expired', LResult.NeedsRefresh);
end;

procedure TOCSPStaplingResultTest.TestNeedsRefreshWhenFresh;
var
  LResult: TOCSPStaplingResult;
begin
  FillChar(LResult, SizeOf(LResult), 0);
  LResult.NextUpdate := DateTimeAddSeconds(DateTimeNow, 7200);
  AssertFalse('Response expiring after the refresh window should stay fresh', LResult.NeedsRefresh);
end;

// ========================================================================
// TOCSPStaplingClientTest 实现
// ========================================================================

procedure TOCSPStaplingClientTest.SetUp;
begin
  FConfig := TOCSPStaplingConfig.Default;
  FCache := TOCSPResponseCache.Create;
  FClient := TOCSPStaplingClient.Create(FConfig, FCache);
end;

procedure TOCSPStaplingClientTest.TearDown;
begin
  FClient.Free;
  FCache.Free;
end;

procedure TOCSPStaplingClientTest.TestClientCreation;
begin
  AssertNotNull('Client should be created', FClient);
end;

procedure TOCSPStaplingClientTest.TestShouldRequestStapling;
begin
  // 默认配置应该请求 stapling
  AssertTrue('Should request stapling by default', 
    FClient.ShouldRequestStapling);
  
  // 禁用后不应该请求
  FConfig.EnableClientRequest := False;
  FClient.Config := FConfig;
  AssertFalse('Should not request stapling when disabled', 
    FClient.ShouldRequestStapling);
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
    AssertTrue('Successful DER without matching cert should fail verification',
      LResult.Status = ossVerificationFailed);
    AssertTrue('Error message should mention certificate lookup',
      Pos('Certificate', LResult.ErrorMessage) > 0);
    AssertTrue('LastResult should track latest status',
      FClient.LastResult.Status = LResult.Status);
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
    AssertTrue('Status should be verification failed', 
      Result.Status = ossVerificationFailed);
    AssertTrue('Error message should not be empty', 
      Result.ErrorMessage <> '');
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
    AssertTrue('Status should be not provided', 
      Result.Status = ossNotProvided);
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
  AssertTrue('Should validate when not required', 
    FClient.ValidateStaplingRequirement(False));
  
  // 要求 stapling 但未提供时失败
  FConfig.RequireStapling := True;
  FClient.Config := FConfig;
  AssertFalse('Should not validate when required but not provided', 
    FClient.ValidateStaplingRequirement(False));
end;

procedure TOCSPStaplingClientTest.TestResponseCaching;
var
  LResult: TOCSPStaplingResult;
  LInvalid, LEmpty: TBytes;
  LCert, LIssuerCert: TX509Certificate;
begin
  SetLength(LInvalid, 10);
  FillChar(LInvalid[0], 10, 255);
  SetLength(LEmpty, 0);

  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LResult := FClient.ProcessStapledResponse(LInvalid, LCert, LIssuerCert);
    AssertTrue('Invalid response should fail verification',
      LResult.Status = ossVerificationFailed);
    AssertEquals('Failed response should not be cached', 0, FCache.GetCount);

    LResult := FClient.ProcessStapledResponse(LEmpty, LCert, LIssuerCert);
    AssertTrue('Empty response should be marked as not provided',
      LResult.Status = ossNotProvided);
    AssertEquals('Empty response should not be cached', 0, FCache.GetCount);
  finally
    LCert.Free;
    LIssuerCert.Free;
  end;
end;

// ========================================================================
// TOCSPStaplingServerTest 实现
// ========================================================================

procedure TOCSPStaplingServerTest.SetUp;
begin
  FConfig := TOCSPStaplingConfig.Default;
  FCache := TOCSPResponseCache.Create;
  FServer := TOCSPStaplingServer.Create(FConfig, FCache);
end;

procedure TOCSPStaplingServerTest.TearDown;
begin
  FServer.Free;
  FCache.Free;
end;

procedure TOCSPStaplingServerTest.TestServerCreation;
begin
  AssertNotNull('Server should be created', FServer);
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
    AssertEquals('Disabled stapling should return empty response', 0, Length(LResponse));
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
    AssertFalse('Refresh should fail when certificate has no OCSP URL',
      FServer.RefreshResponse(LCert, LIssuerCert));
  finally
    LCert.Free;
    LIssuerCert.Free;
  end;
end;

procedure TOCSPStaplingServerTest.TestAutoRefresh;
begin
  // 测试自动刷新启用/禁用
  AssertFalse('Auto refresh should be disabled initially', 
    FServer.AutoRefreshEnabled);
  
  FServer.EnableAutoRefresh;
  AssertTrue('Auto refresh should be enabled', 
    FServer.AutoRefreshEnabled);
  
  FServer.DisableAutoRefresh;
  AssertFalse('Auto refresh should be disabled', 
    FServer.AutoRefreshEnabled);
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
  LThisUpdate := Now;
  LNextUpdate := Now + 1.0;
  FCache.Put(LSerial, LCachedResponse, LThisUpdate, LNextUpdate);
  AssertEquals('Cache should contain preload entry', 1, FCache.GetCount);

  LConfig := TOCSPStaplingConfig.Default;
  LConfig.EnableServerStapling := False;
  LServer := TOCSPStaplingServer.Create(LConfig, FCache);
  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    LReturned := LServer.GetStapledResponse(LCert, LIssuerCert, False);
    AssertEquals('Disabled server should return empty response', 0, Length(LReturned));
    AssertEquals('Cache entry should remain unchanged', 1, FCache.GetCount);
  finally
    LCert.Free;
    LIssuerCert.Free;
    LServer.Free;
  end;
end;

// ========================================================================
// TOCSPStaplingManagerTest 实现
// ========================================================================

procedure TOCSPStaplingManagerTest.SetUp;
begin
  FConfig := TOCSPStaplingConfig.Default;
  FManager := TOCSPStaplingManager.Create(FConfig);
end;

procedure TOCSPStaplingManagerTest.TearDown;
begin
  FManager.Free;
end;

procedure TOCSPStaplingManagerTest.TestManagerCreation;
begin
  AssertNotNull('Manager should be created', FManager);
  AssertNotNull('Client should be created', FManager.Client);
  AssertNotNull('Server should be created', FManager.Server);
  AssertNotNull('Cache should be created', FManager.Cache);
end;

procedure TOCSPStaplingManagerTest.TestClientInterface;
begin
  // 测试客户端接口
  AssertTrue('Should request stapling', FManager.ClientShouldRequest);
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
    AssertEquals('Server response should be empty when stapling disabled',
      0, Length(LResponse));
    AssertFalse('Server refresh should fail without OCSP URL',
      LManager.ServerRefreshResponse(LCert, LIssuerCert));
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
  AssertEquals('Cache should be empty initially', 0, Stats.TotalEntries);
  
  // 清空缓存
  FManager.ClearCache;
  Stats := FManager.GetCacheStats;
  AssertEquals('Cache should be empty after clear', 0, Stats.TotalEntries);
end;

// ========================================================================
// 注册测试
// ========================================================================

initialization
  RegisterTest(TOCSPCacheTest);
  RegisterTest(TOCSPStaplingConfigTest);
  RegisterTest(TOCSPStaplingResultTest);
  RegisterTest(TOCSPStaplingClientTest);
  RegisterTest(TOCSPStaplingServerTest);
  RegisterTest(TOCSPStaplingManagerTest);

end.
