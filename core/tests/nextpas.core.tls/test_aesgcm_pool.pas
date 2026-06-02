program test_aesgcm_pool;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.aesgcm.pool,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.backed,  // 确保 OpenSSL 后端注册
  nextpas.core.tls.exceptions;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('  [PASS] ', AMessage);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('  [FAIL] ', AMessage);
  end;
end;

procedure TestBasicPoolCreation;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
begin
  WriteLn('Test: Basic Pool Creation');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    Assert(LPool.Enabled, 'Pool should be enabled by default');
    Assert(LPool.PoolSize = DEFAULT_POOL_SIZE, 'Pool size should match default');
  finally
    LPool.Free;
  end;
end;

procedure TestContextAcquisition;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV: TBytes;
  LCtx: PEVP_CIPHER_CTX;
begin
  WriteLn('Test: Context Acquisition');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    // 生成测试密钥（256位）
    LKey := TCryptoUtils.GenerateKey(256);

    // 获取加密上下文
    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV);

    Assert(LCtx <> nil, 'Context should not be nil');
    Assert(Length(LIV) = GCM_IV_LENGTH, 'IV length should be 12 bytes');

    // 归还上下文
    LPool.ReleaseContext(LCtx);
  finally
    LPool.Free;
  end;
end;

procedure TestIVUniqueness;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV1, LIV2, LIV3: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  I: Integer;
  LAllUnique: Boolean;
begin
  WriteLn('Test: IV Uniqueness');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey := TCryptoUtils.GenerateKey(256);

    // 获取三个 IV
    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV1);
    LPool.ReleaseContext(LCtx);

    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV2);
    LPool.ReleaseContext(LCtx);

    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV3);
    LPool.ReleaseContext(LCtx);

    // 验证所有 IV 都不相同
    LAllUnique := True;

    // 比较 IV1 和 IV2
    for I := 0 to Length(LIV1) - 1 do
    begin
      if LIV1[I] <> LIV2[I] then
        Break;
      if I = Length(LIV1) - 1 then
        LAllUnique := False;
    end;

    // 比较 IV1 和 IV3
    if LAllUnique then
    begin
      for I := 0 to Length(LIV1) - 1 do
      begin
        if LIV1[I] <> LIV3[I] then
          Break;
        if I = Length(LIV1) - 1 then
          LAllUnique := False;
      end;
    end;

    // 比较 IV2 和 IV3
    if LAllUnique then
    begin
      for I := 0 to Length(LIV2) - 1 do
      begin
        if LIV2[I] <> LIV3[I] then
          Break;
        if I = Length(LIV2) - 1 then
          LAllUnique := False;
      end;
    end;

    Assert(LAllUnique, 'All IVs should be unique');
  finally
    LPool.Free;
  end;
end;

procedure TestContextReuse;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV: TBytes;
  LCtx1, LCtx2: PEVP_CIPHER_CTX;
  LStats: TAESGCMPoolStats;
begin
  WriteLn('Test: Context Reuse (Cache Hit)');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey := TCryptoUtils.GenerateKey(256);

    // 第一次获取（缓存未命中）
    LCtx1 := LPool.AcquireContextWithIV(LKey, True, LIV);
    LPool.ReleaseContext(LCtx1);

    // 第二次获取（应该缓存命中）
    LCtx2 := LPool.AcquireContextWithIV(LKey, True, LIV);
    LPool.ReleaseContext(LCtx2);

    // 验证统计信息
    LStats := LPool.GetStats;
    Assert(LStats.TotalRequests = 2, 'Total requests should be 2');
    Assert(LStats.CacheHits = 1, 'Cache hits should be 1');
    Assert(LStats.CacheMisses = 1, 'Cache misses should be 1');
    Assert(LStats.HitRate > 0, 'Hit rate should be > 0');
  finally
    LPool.Free;
  end;
end;

procedure TestDifferentKeys;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey1, LKey2, LIV: TBytes;
  LCtx1, LCtx2: PEVP_CIPHER_CTX;
  LStats: TAESGCMPoolStats;
begin
  WriteLn('Test: Different Keys (Cache Miss)');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey1 := TCryptoUtils.GenerateKey(256);
    LKey2 := TCryptoUtils.GenerateKey(256);

    // 使用第一个密钥
    LCtx1 := LPool.AcquireContextWithIV(LKey1, True, LIV);
    LPool.ReleaseContext(LCtx1);

    // 使用第二个密钥（应该缓存未命中）
    LCtx2 := LPool.AcquireContextWithIV(LKey2, True, LIV);
    LPool.ReleaseContext(LCtx2);

    // 验证统计信息
    LStats := LPool.GetStats;
    Assert(LStats.TotalRequests = 2, 'Total requests should be 2');
    Assert(LStats.CacheMisses = 2, 'Cache misses should be 2 (different keys)');
  finally
    LPool.Free;
  end;
end;

procedure TestEncryptDecryptModes;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV: TBytes;
  LCtxEnc, LCtxDec: PEVP_CIPHER_CTX;
  LStats: TAESGCMPoolStats;
begin
  WriteLn('Test: Encrypt/Decrypt Modes');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey := TCryptoUtils.GenerateKey(256);

    // 获取加密上下文
    LCtxEnc := LPool.AcquireContextWithIV(LKey, True, LIV);
    LPool.ReleaseContext(LCtxEnc);

    // 获取解密上下文（应该缓存未命中，因为模式不同）
    LCtxDec := LPool.AcquireContextWithIV(LKey, False, LIV);
    LPool.ReleaseContext(LCtxDec);

    // 验证统计信息
    LStats := LPool.GetStats;
    Assert(LStats.TotalRequests = 2, 'Total requests should be 2');
    Assert(LStats.CacheMisses = 2, 'Cache misses should be 2 (different modes)');
  finally
    LPool.Free;
  end;
end;

procedure TestStatistics;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LStats: TAESGCMPoolStats;
  I: Integer;
begin
  WriteLn('Test: Statistics Tracking');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey := TCryptoUtils.GenerateKey(256);

    // 执行多次操作
    for I := 1 to 10 do
    begin
      LCtx := LPool.AcquireContextWithIV(LKey, True, LIV);
      LPool.ReleaseContext(LCtx);
    end;

    // 验证统计信息
    LStats := LPool.GetStats;
    Assert(LStats.TotalRequests = 10, 'Total requests should be 10');
    Assert(LStats.CacheHits = 9, 'Cache hits should be 9');
    Assert(LStats.CacheMisses = 1, 'Cache misses should be 1');
    Assert(Abs(LStats.HitRate - 90.0) < 0.1, 'Hit rate should be ~90%');

    // 重置统计信息
    LPool.ResetStats;
    LStats := LPool.GetStats;
    Assert(LStats.TotalRequests = 0, 'Total requests should be 0 after reset');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolSizeLimit;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKeys: array[0..19] of TBytes;
  LIV: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  I: Integer;
  LStats: TAESGCMPoolStats;
begin
  WriteLn('Test: Pool Size Limit (LRU Eviction)');

  LConfig := DefaultAESGCMPoolConfig;
  LConfig.PoolSize := 8;  // 小池大小
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    // 生成 20 个不同的密钥
    for I := 0 to 19 do
      LKeys[I] := TCryptoUtils.GenerateKey(256);

    // 使用所有密钥（超过池大小）
    for I := 0 to 19 do
    begin
      LCtx := LPool.AcquireContextWithIV(LKeys[I], True, LIV);
      LPool.ReleaseContext(LCtx);
    end;

    // 验证统计信息
    LStats := LPool.GetStats;
    Assert(LStats.TotalRequests = 20, 'Total requests should be 20');
    Assert(LStats.CacheMisses = 20, 'All should be cache misses (different keys)');
    Assert(LStats.ContextResets > 0, 'Context resets should occur (LRU eviction)');
  finally
    LPool.Free;
  end;
end;

procedure TestGlobalPool;
var
  LKey, LIV: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LPool: TAESGCMContextPool;
begin
  WriteLn('Test: Global Pool Instance');

  LKey := TCryptoUtils.GenerateKey(256);

  // 使用全局池
  LCtx := PooledAESGCMContext(LKey, True, LIV);
  Assert(LCtx <> nil, 'Global pool context should not be nil');
  Assert(Length(LIV) = GCM_IV_LENGTH, 'IV length should be 12 bytes');

  // 获取全局池实例
  LPool := GetGlobalAESGCMPool;
  Assert(LPool <> nil, 'Global pool instance should not be nil');
  Assert(LPool.Enabled, 'Global pool should be enabled');

  // 归还上下文
  LPool.ReleaseContext(LCtx);
end;

procedure TestDisabledPool;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV: TBytes;
  LCtx: PEVP_CIPHER_CTX;
begin
  WriteLn('Test: Disabled Pool');

  LConfig := DefaultAESGCMPoolConfig;
  LConfig.Enabled := False;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey := TCryptoUtils.GenerateKey(256);

    // 尝试获取上下文（应该返回 nil）
    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV);

    Assert(LCtx = nil, 'Disabled pool should return nil context');
    Assert(Length(LIV) = 0, 'Disabled pool should return empty IV');
  finally
    LPool.Free;
  end;
end;

procedure TestIVCounterIncrement;
var
  LPool: TAESGCMContextPool;
  LConfig: TAESGCMPoolConfig;
  LKey, LIV1, LIV2: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LCounter1, LCounter2: UInt32;
begin
  WriteLn('Test: IV Counter Increment');

  LConfig := DefaultAESGCMPoolConfig;
  LPool := TAESGCMContextPool.Create(LConfig);
  try
    LKey := TCryptoUtils.GenerateKey(256);

    // 获取第一个 IV
    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV1);
    LPool.ReleaseContext(LCtx);

    // 获取第二个 IV
    LCtx := LPool.AcquireContextWithIV(LKey, True, LIV2);
    LPool.ReleaseContext(LCtx);

    // 提取计数器（最后 4 字节，大端字节序）
    LCounter1 := (UInt32(LIV1[8]) shl 24) or
                 (UInt32(LIV1[9]) shl 16) or
                 (UInt32(LIV1[10]) shl 8) or
                 UInt32(LIV1[11]);

    LCounter2 := (UInt32(LIV2[8]) shl 24) or
                 (UInt32(LIV2[9]) shl 16) or
                 (UInt32(LIV2[10]) shl 8) or
                 UInt32(LIV2[11]);

    // 验证计数器递增
    Assert(LCounter2 = LCounter1 + 1, 'IV counter should increment by 1');

    // 验证基础值相同（前 8 字节）
    Assert(CompareMem(@LIV1[0], @LIV2[0], GCM_IV_BASE_LENGTH),
           'IV base should be the same for same key');
  finally
    LPool.Free;
  end;
end;

procedure RunAllTests;
var
  LTestKey, LTestIV, LTestData, LTestResult: TBytes;
begin
  WriteLn('========================================');
  WriteLn('  AES-GCM Context Pool Test Suite');
  WriteLn('========================================');
  WriteLn('');

  // Initialize OpenSSL by calling an AES-GCM encryption to ensure all EVP functions are loaded
  try
    LTestKey := TCryptoUtils.GenerateKey(256);
    LTestIV := TCryptoUtils.SecureRandom(12);
    LTestData := TCryptoUtils.SecureRandom(16);
    LTestResult := TCryptoUtils.AES_GCM_Encrypt(LTestData, LTestKey, LTestIV);
    WriteLn('OpenSSL initialized successfully (AES-GCM test passed)');
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: Failed to initialize OpenSSL: ', E.Message);
      ExitCode := 2;
      Exit;
    end;
  end;
  WriteLn('');

  TestBasicPoolCreation;
  WriteLn('');

  TestContextAcquisition;
  WriteLn('');

  TestIVUniqueness;
  WriteLn('');

  TestContextReuse;
  WriteLn('');

  TestDifferentKeys;
  WriteLn('');

  TestEncryptDecryptModes;
  WriteLn('');

  TestStatistics;
  WriteLn('');

  TestPoolSizeLimit;
  WriteLn('');

  TestGlobalPool;
  WriteLn('');

  TestDisabledPool;
  WriteLn('');

  TestIVCounterIncrement;
  WriteLn('');

  WriteLn('========================================');
  WriteLn('  Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests:  ', TotalTests);
  WriteLn('Passed:       ', PassedTests);
  WriteLn('Failed:       ', FailedTests);
  WriteLn('');

  if FailedTests = 0 then
  begin
    WriteLn('✓ All tests passed!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('✗ Some tests failed!');
    ExitCode := 1;
  end;
end;

begin
  try
    RunAllTests;
  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
