program benchmark_aesgcm_pool;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, DateUtils,
  benchmark_framework,
  nextpas.core.tls.init,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.aesgcm.pool;

const
  WARMUP_ITERATIONS = 100;
  TEST_ITERATIONS = 1000;

var
  Framework: TBenchmark;
  TestKey: TBytes;
  TestData64B: TBytes;
  TestData1KB: TBytes;
  TestData16KB: TBytes;

procedure InitializeTestData;
begin
  WriteLn('Initializing test data...');

  // 生成测试密钥和数据
  TestKey := TCryptoUtils.GenerateKey(256);
  TestData64B := TCryptoUtils.SecureRandom(64);
  TestData1KB := TCryptoUtils.SecureRandom(1024);
  TestData16KB := TCryptoUtils.SecureRandom(16384);

  WriteLn('Test data initialized');
end;

{ ==================== 传统方式基准测试 ==================== }

procedure BenchmarkTraditionalEncrypt64B;
var
  LIV, LResult: TBytes;
begin
  LIV := TCryptoUtils.SecureRandom(12);
  LResult := TCryptoUtils.AES_GCM_Encrypt(TestData64B, TestKey, LIV);
end;

procedure BenchmarkTraditionalEncrypt1KB;
var
  LIV, LResult: TBytes;
begin
  LIV := TCryptoUtils.SecureRandom(12);
  LResult := TCryptoUtils.AES_GCM_Encrypt(TestData1KB, TestKey, LIV);
end;

procedure BenchmarkTraditionalEncrypt16KB;
var
  LIV, LResult: TBytes;
begin
  LIV := TCryptoUtils.SecureRandom(12);
  LResult := TCryptoUtils.AES_GCM_Encrypt(TestData16KB, TestKey, LIV);
end;

procedure BenchmarkTraditionalDecrypt64B;
var
  LIV, LCiphertext, LResult: TBytes;
begin
  // 预先加密一次
  LIV := TCryptoUtils.SecureRandom(12);
  LCiphertext := TCryptoUtils.AES_GCM_Encrypt(TestData64B, TestKey, LIV);
  LResult := TCryptoUtils.AES_GCM_Decrypt(LCiphertext, TestKey, LIV);
end;

procedure BenchmarkTraditionalDecrypt1KB;
var
  LIV, LCiphertext, LResult: TBytes;
begin
  LIV := TCryptoUtils.SecureRandom(12);
  LCiphertext := TCryptoUtils.AES_GCM_Encrypt(TestData1KB, TestKey, LIV);
  LResult := TCryptoUtils.AES_GCM_Decrypt(LCiphertext, TestKey, LIV);
end;

procedure BenchmarkTraditionalDecrypt16KB;
var
  LIV, LCiphertext, LResult: TBytes;
begin
  LIV := TCryptoUtils.SecureRandom(12);
  LCiphertext := TCryptoUtils.AES_GCM_Encrypt(TestData16KB, TestKey, LIV);
  LResult := TCryptoUtils.AES_GCM_Decrypt(LCiphertext, TestKey, LIV);
end;

{ ==================== 池化方式基准测试 ==================== }

procedure BenchmarkPooledEncrypt64B;
var
  LIV, LResult: TBytes;
begin
  LResult := TCryptoUtils.AES_GCM_EncryptPooled(TestData64B, TestKey, LIV);
end;

procedure BenchmarkPooledEncrypt1KB;
var
  LIV, LResult: TBytes;
begin
  LResult := TCryptoUtils.AES_GCM_EncryptPooled(TestData1KB, TestKey, LIV);
end;

procedure BenchmarkPooledEncrypt16KB;
var
  LIV, LResult: TBytes;
begin
  LResult := TCryptoUtils.AES_GCM_EncryptPooled(TestData16KB, TestKey, LIV);
end;

procedure BenchmarkPooledDecrypt64B;
var
  LIV, LCiphertext, LResult: TBytes;
begin
  // 预先加密一次
  LCiphertext := TCryptoUtils.AES_GCM_EncryptPooled(TestData64B, TestKey, LIV);
  LResult := TCryptoUtils.AES_GCM_DecryptPooled(LCiphertext, TestKey, LIV);
end;

procedure BenchmarkPooledDecrypt1KB;
var
  LIV, LCiphertext, LResult: TBytes;
begin
  LCiphertext := TCryptoUtils.AES_GCM_EncryptPooled(TestData1KB, TestKey, LIV);
  LResult := TCryptoUtils.AES_GCM_DecryptPooled(LCiphertext, TestKey, LIV);
end;

procedure BenchmarkPooledDecrypt16KB;
var
  LIV, LCiphertext, LResult: TBytes;
begin
  LCiphertext := TCryptoUtils.AES_GCM_EncryptPooled(TestData16KB, TestKey, LIV);
  LResult := TCryptoUtils.AES_GCM_DecryptPooled(LCiphertext, TestKey, LIV);
end;

{ ==================== 池统计信息 ==================== }

procedure PrintPoolStats;
var
  LStats: TAESGCMPoolStats;
begin
  LStats := GetGlobalAESGCMPool.GetStats;

  WriteLn('');
  WriteLn('========================================');
  WriteLn('  AES-GCM Context Pool Statistics');
  WriteLn('========================================');
  WriteLn('Total Requests:    ', LStats.TotalRequests);
  WriteLn('Cache Hits:        ', LStats.CacheHits);
  WriteLn('Cache Misses:      ', LStats.CacheMisses);
  WriteLn('Context Resets:    ', LStats.ContextResets);
  WriteLn('IV Base Regens:    ', LStats.IVBaseRegens);
  WriteLn('Hit Rate:          ', LStats.HitRate:0:2, '%');
  WriteLn('========================================');
  WriteLn('');
end;

procedure RunAllBenchmarks;
begin
  WriteLn('========================================');
  WriteLn('  AES-GCM Context Pool Benchmark');
  WriteLn('========================================');
  WriteLn('Iterations: ', TEST_ITERATIONS);
  WriteLn('Warmup:     ', WARMUP_ITERATIONS);
  WriteLn('');

  InitializeTestData;

  Framework := TBenchmark.Create;
  try
    Framework.WarmupIterations := WARMUP_ITERATIONS;

    WriteLn('Registering traditional (non-pooled) benchmarks...');

    // 传统方式 - 加密
    Framework.RegisterTest('AES-GCM Encrypt 64B (Traditional)', @BenchmarkTraditionalEncrypt64B);
    Framework.RegisterTest('AES-GCM Encrypt 1KB (Traditional)', @BenchmarkTraditionalEncrypt1KB);
    Framework.RegisterTest('AES-GCM Encrypt 16KB (Traditional)', @BenchmarkTraditionalEncrypt16KB);

    // 传统方式 - 解密
    Framework.RegisterTest('AES-GCM Decrypt 64B (Traditional)', @BenchmarkTraditionalDecrypt64B);
    Framework.RegisterTest('AES-GCM Decrypt 1KB (Traditional)', @BenchmarkTraditionalDecrypt1KB);
    Framework.RegisterTest('AES-GCM Decrypt 16KB (Traditional)', @BenchmarkTraditionalDecrypt16KB);

    WriteLn('Registering pooled benchmarks...');

    // 池化方式 - 加密
    Framework.RegisterTest('AES-GCM Encrypt 64B (Pooled)', @BenchmarkPooledEncrypt64B);
    Framework.RegisterTest('AES-GCM Encrypt 1KB (Pooled)', @BenchmarkPooledEncrypt1KB);
    Framework.RegisterTest('AES-GCM Encrypt 16KB (Pooled)', @BenchmarkPooledEncrypt16KB);

    // 池化方式 - 解密
    Framework.RegisterTest('AES-GCM Decrypt 64B (Pooled)', @BenchmarkPooledDecrypt64B);
    Framework.RegisterTest('AES-GCM Decrypt 1KB (Pooled)', @BenchmarkPooledDecrypt1KB);
    Framework.RegisterTest('AES-GCM Decrypt 16KB (Pooled)', @BenchmarkPooledDecrypt16KB);

    WriteLn('');
    WriteLn('Running all benchmarks...');
    WriteLn('');

    // 运行所有测试
    Framework.Run(TEST_ITERATIONS);

    WriteLn('');
    WriteLn('Generating performance comparison report...');
    WriteLn('');

    Framework.PrintResults;
    Framework.SaveBaseline('tests/benchmarks/results/aesgcm_pool_baseline.json');

    PrintPoolStats;

    WriteLn('');
    WriteLn('Performance comparison:');
    WriteLn('');
    WriteLn('Expected improvements with context pool:');
    WriteLn('- Small data blocks (64B-1KB): 2-3x faster encryption');
    WriteLn('- Reduced context creation overhead');
    WriteLn('- High cache hit rate (>90% for same key)');
    WriteLn('');
    WriteLn('Results saved to: tests/benchmarks/results/aesgcm_pool_baseline.json');
    WriteLn('');

  finally
    Framework.Free;
  end;
end;

begin
  try
    // Initialize OpenSSL before running benchmarks
    InitializeOpenSSL;
    WriteLn('OpenSSL initialized: ', GetOpenSSLVersion);
    WriteLn('');
    
    RunAllBenchmarks;
    ExitCode := 0;
  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
