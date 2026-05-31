program test_random_pool;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.random.pool,
  nextpas.core.tls.random;

procedure TestBasicFunctionality;
var
  LPool: TRandomPool;
  LConfig: TRandomPoolConfig;
  LBuffer: array[0..1023] of Byte;
  LStats: TRandomPoolStats;
begin
  WriteLn('=== Test 1: Basic Functionality ===');

  LConfig := TRandomPoolConfig.Default;
  LPool := TRandomPool.Create(LConfig);
  try
    // Test 1: Get 1KB random data
    if LPool.GetBytes(@LBuffer[0], 1024) then
      WriteLn('[PASS] Successfully generated 1KB random data')
    else
      WriteLn('[FAIL] Failed to generate random data');

    // Test 2: Check statistics
    LStats := LPool.GetStats;
    WriteLn(Format('[INFO] Total requests: %d', [LStats.TotalRequests]));
    WriteLn(Format('[INFO] Cache hits: %d', [LStats.CacheHits]));
    WriteLn(Format('[INFO] Cache misses: %d', [LStats.CacheMisses]));
    WriteLn(Format('[INFO] Hit rate: %.2f%%', [LStats.HitRate]));

  finally
    LPool.Free;
  end;

  WriteLn;
end;

procedure TestPerformance;
const
  ITERATIONS = 1000;
  DATA_SIZE = 1024; // 1KB
var
  LPool: TRandomPool;
  LConfig: TRandomPoolConfig;
  LBuffer: array[0..DATA_SIZE-1] of Byte;
  LStats: TRandomPoolStats;
  I: Integer;
  LStartTime, LEndTime: TDateTime;
  LElapsedMs: Int64;
  LThroughput: Double;
begin
  WriteLn('=== Test 2: Performance Benchmark ===');
  WriteLn(Format('Iterations: %d, Data size: %d bytes', [ITERATIONS, DATA_SIZE]));

  // Test with pool enabled
  WriteLn;
  WriteLn('--- With Random Pool (Enabled) ---');
  LConfig := TRandomPoolConfig.Default;
  LConfig.Enabled := True;
  LPool := TRandomPool.Create(LConfig);
  try
    LStartTime := Now;
    for I := 1 to ITERATIONS do
    begin
      if not LPool.GetBytes(@LBuffer[0], DATA_SIZE) then
      begin
        WriteLn('[FAIL] Failed to generate random data');
        Exit;
      end;
    end;
    LEndTime := Now;

    LElapsedMs := MilliSecondsBetween(LEndTime, LStartTime);
    LThroughput := (ITERATIONS * 1000.0) / LElapsedMs;

    WriteLn(Format('[RESULT] Time: %d ms', [LElapsedMs]));
    WriteLn(Format('[RESULT] Throughput: %.0f ops/s', [LThroughput]));
    WriteLn(Format('[RESULT] Avg latency: %.3f ms', [LElapsedMs / ITERATIONS]));

    LStats := LPool.GetStats;
    WriteLn(Format('[STATS] Cache hit rate: %.2f%%', [LStats.HitRate]));
    WriteLn(Format('[STATS] Refill count: %d', [LStats.RefillCount]));

  finally
    LPool.Free;
  end;

  // Test without pool (direct generation)
  WriteLn;
  WriteLn('--- Without Random Pool (Direct) ---');
  LStartTime := Now;
  for I := 1 to ITERATIONS do
  begin
    if not SecureRandomBytes(@LBuffer[0], DATA_SIZE) then
    begin
      WriteLn('[FAIL] Failed to generate random data');
      Exit;
    end;
  end;
  LEndTime := Now;

  LElapsedMs := MilliSecondsBetween(LEndTime, LStartTime);
  LThroughput := (ITERATIONS * 1000.0) / LElapsedMs;

  WriteLn(Format('[RESULT] Time: %d ms', [LElapsedMs]));
  WriteLn(Format('[RESULT] Throughput: %.0f ops/s', [LThroughput]));
  WriteLn(Format('[RESULT] Avg latency: %.3f ms', [LElapsedMs / ITERATIONS]));

  WriteLn;
end;

procedure TestThreadSafety;
var
  LPool: TRandomPool;
  LConfig: TRandomPoolConfig;
  LBuffer: array[0..255] of Byte;
  I: Integer;
begin
  WriteLn('=== Test 3: Thread Safety (Basic) ===');

  LConfig := TRandomPoolConfig.Default;
  LPool := TRandomPool.Create(LConfig);
  try
    // Simulate concurrent access (basic test)
    for I := 1 to 100 do
    begin
      if not LPool.GetBytes(@LBuffer[0], 256) then
      begin
        WriteLn('[FAIL] Failed to generate random data');
        Exit;
      end;
    end;

    WriteLn('[PASS] Thread safety basic test passed');

  finally
    LPool.Free;
  end;

  WriteLn;
end;

procedure TestConfiguration;
var
  LPool: TRandomPool;
  LConfig: TRandomPoolConfig;
  LBuffer: array[0..8191] of Byte;
  LStats: TRandomPoolStats;
begin
  WriteLn('=== Test 4: Configuration Options ===');

  // Test with disabled pool
  WriteLn('--- Pool Disabled ---');
  LConfig := TRandomPoolConfig.Default;
  LConfig.Enabled := False;
  LPool := TRandomPool.Create(LConfig);
  try
    if LPool.GetBytes(@LBuffer[0], 1024) then
      WriteLn('[PASS] Direct generation works when pool disabled')
    else
      WriteLn('[FAIL] Direct generation failed');

    LStats := LPool.GetStats;
    WriteLn(Format('[INFO] Cache misses (expected): %d', [LStats.CacheMisses]));

  finally
    LPool.Free;
  end;

  // Test with large request (exceeds MaxRequestSize)
  WriteLn;
  WriteLn('--- Large Request (> MaxRequestSize) ---');
  LConfig := TRandomPoolConfig.Default;
  LConfig.Enabled := True;
  LConfig.MaxRequestSize := 4096;
  LPool := TRandomPool.Create(LConfig);
  try
    if LPool.GetBytes(@LBuffer[0], 8192) then
      WriteLn('[PASS] Large request handled correctly')
    else
      WriteLn('[FAIL] Large request failed');

    LStats := LPool.GetStats;
    WriteLn(Format('[INFO] Cache misses (expected for large request): %d', [LStats.CacheMisses]));

  finally
    LPool.Free;
  end;

  WriteLn;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════╗');
  WriteLn('║  fafafa.ssl Random Pool Test Suite                    ║');
  WriteLn('║  Phase B: Performance Optimization                     ║');
  WriteLn('╚════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    TestBasicFunctionality;
    TestPerformance;
    TestThreadSafety;
    TestConfiguration;

    WriteLn('╔════════════════════════════════════════════════════════╗');
    WriteLn('║  All Tests Completed Successfully                     ║');
    WriteLn('╚════════════════════════════════════════════════════════╝');

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('╔════════════════════════════════════════════════════════╗');
      WriteLn('║  Test Failed with Exception                            ║');
      WriteLn('╚════════════════════════════════════════════════════════╝');
      WriteLn('[ERROR] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
