program benchmark_crypto_comprehensive;

{$mode objfpc}{$H+}

{**
 * Comprehensive Crypto Performance Benchmark
 *
 * Benchmarks all major cryptographic operations:
 * - SHA-256 hashing (64B, 1KB, 16KB)
 * - SHA-512 hashing (64B, 1KB, 16KB)
 * - AES-256-GCM encryption (64B, 1KB, 16KB)
 * - AES-256-GCM decryption (64B, 1KB, 16KB)
 * - Secure random number generation (64B, 1KB, 16KB)
 *
 * Run: ./benchmark_crypto_comprehensive [iterations]
 * Default: 1000 iterations per benchmark
 *
 * Output:
 * - Console report with mean, P95, P99, ops/s
 * - JSON baseline file for CI regression detection
 *}

uses
  SysUtils, Classes,
  benchmark_framework,
  nextpas.core.tls.crypto.utils;

const
  { Test data sizes }
  SMALL_DATA_SIZE = 64;
  MEDIUM_DATA_SIZE = 1024;
  LARGE_DATA_SIZE = 16384;

var
  { Global test data }
  GSmallData: TBytes;
  GMediumData: TBytes;
  GLargeData: TBytes;

  { Global benchmark instance }
  GBenchmark: TBenchmark;

  { Iteration count }
  GIterations: Integer;

{ ============================================================================ }
{ Test Data Initialization                                                     }
{ ============================================================================ }

procedure InitializeTestData;
var
  I: Integer;
begin
  SetLength(GSmallData, SMALL_DATA_SIZE);
  SetLength(GMediumData, MEDIUM_DATA_SIZE);
  SetLength(GLargeData, LARGE_DATA_SIZE);

  // Fill with pseudo-random data
  for I := 0 to SMALL_DATA_SIZE - 1 do
    GSmallData[I] := Byte(I mod 256);

  for I := 0 to MEDIUM_DATA_SIZE - 1 do
    GMediumData[I] := Byte(I mod 256);

  for I := 0 to LARGE_DATA_SIZE - 1 do
    GLargeData[I] := Byte(I mod 256);
end;

{ ============================================================================ }
{ SHA-256 Benchmarks                                                           }
{ ============================================================================ }

procedure BenchSHA256_64B;
var
  Hash: TBytes;
begin
  Hash := TCryptoUtils.SHA256(GSmallData);
end;

procedure BenchSHA256_1KB;
var
  Hash: TBytes;
begin
  Hash := TCryptoUtils.SHA256(GMediumData);
end;

procedure BenchSHA256_16KB;
var
  Hash: TBytes;
begin
  Hash := TCryptoUtils.SHA256(GLargeData);
end;

{ ============================================================================ }
{ SHA-512 Benchmarks                                                           }
{ ============================================================================ }

procedure BenchSHA512_64B;
var
  Hash: TBytes;
begin
  Hash := TCryptoUtils.SHA512(GSmallData);
end;

procedure BenchSHA512_1KB;
var
  Hash: TBytes;
begin
  Hash := TCryptoUtils.SHA512(GMediumData);
end;

procedure BenchSHA512_16KB;
var
  Hash: TBytes;
begin
  Hash := TCryptoUtils.SHA512(GLargeData);
end;

{ ============================================================================ }
{ AES-256-GCM Encryption Benchmarks                                            }
{ ============================================================================ }

procedure BenchAES_GCM_Encrypt_64B;
var
  Key, IV, Ciphertext: TBytes;
begin
  Key := TCryptoUtils.GenerateKey(256);
  IV := TCryptoUtils.SecureRandom(12);
  Ciphertext := TCryptoUtils.AES_GCM_Encrypt(GSmallData, Key, IV);
end;

procedure BenchAES_GCM_Encrypt_1KB;
var
  Key, IV, Ciphertext: TBytes;
begin
  Key := TCryptoUtils.GenerateKey(256);
  IV := TCryptoUtils.SecureRandom(12);
  Ciphertext := TCryptoUtils.AES_GCM_Encrypt(GMediumData, Key, IV);
end;

procedure BenchAES_GCM_Encrypt_16KB;
var
  Key, IV, Ciphertext: TBytes;
begin
  Key := TCryptoUtils.GenerateKey(256);
  IV := TCryptoUtils.SecureRandom(12);
  Ciphertext := TCryptoUtils.AES_GCM_Encrypt(GLargeData, Key, IV);
end;

{ ============================================================================ }
{ AES-256-GCM Decryption Benchmarks                                            }
{ ============================================================================ }

var
  GEncryptedSmall, GEncryptedMedium, GEncryptedLarge: TBytes;
  GKey, GIV: TBytes;

procedure InitializeEncryptedData;
begin
  GKey := TCryptoUtils.GenerateKey(256);
  GIV := TCryptoUtils.SecureRandom(12);

  GEncryptedSmall := TCryptoUtils.AES_GCM_Encrypt(GSmallData, GKey, GIV);
  GEncryptedMedium := TCryptoUtils.AES_GCM_Encrypt(GMediumData, GKey, GIV);
  GEncryptedLarge := TCryptoUtils.AES_GCM_Encrypt(GLargeData, GKey, GIV);
end;

procedure BenchAES_GCM_Decrypt_64B;
var
  Plaintext: TBytes;
begin
  Plaintext := TCryptoUtils.AES_GCM_Decrypt(GEncryptedSmall, GKey, GIV);
end;

procedure BenchAES_GCM_Decrypt_1KB;
var
  Plaintext: TBytes;
begin
  Plaintext := TCryptoUtils.AES_GCM_Decrypt(GEncryptedMedium, GKey, GIV);
end;

procedure BenchAES_GCM_Decrypt_16KB;
var
  Plaintext: TBytes;
begin
  Plaintext := TCryptoUtils.AES_GCM_Decrypt(GEncryptedLarge, GKey, GIV);
end;

{ ============================================================================ }
{ Secure Random Number Generation Benchmarks                                   }
{ ============================================================================ }

procedure BenchSecureRandom_64B;
var
  Random: TBytes;
begin
  Random := TCryptoUtils.SecureRandom(SMALL_DATA_SIZE);
end;

procedure BenchSecureRandom_1KB;
var
  Random: TBytes;
begin
  Random := TCryptoUtils.SecureRandom(MEDIUM_DATA_SIZE);
end;

procedure BenchSecureRandom_16KB;
var
  Random: TBytes;
begin
  Random := TCryptoUtils.SecureRandom(LARGE_DATA_SIZE);
end;

{ ============================================================================ }
{ Key Generation Benchmarks                                                    }
{ ============================================================================ }

procedure BenchGenerateKey_128bit;
var
  Key: TBytes;
begin
  Key := TCryptoUtils.GenerateKey(128);
end;

procedure BenchGenerateKey_256bit;
var
  Key: TBytes;
begin
  Key := TCryptoUtils.GenerateKey(256);
end;

{ ============================================================================ }
{ Main Program                                                                 }
{ ============================================================================ }

procedure RegisterAllTests;
begin
  WriteLn('Registering benchmark tests...');

  // SHA-256 tests
  GBenchmark.RegisterTest('sha256_64b', @BenchSHA256_64B);
  GBenchmark.RegisterTest('sha256_1kb', @BenchSHA256_1KB);
  GBenchmark.RegisterTest('sha256_16kb', @BenchSHA256_16KB);

  // SHA-512 tests
  GBenchmark.RegisterTest('sha512_64b', @BenchSHA512_64B);
  GBenchmark.RegisterTest('sha512_1kb', @BenchSHA512_1KB);
  GBenchmark.RegisterTest('sha512_16kb', @BenchSHA512_16KB);

  // AES-256-GCM encryption tests
  GBenchmark.RegisterTest('aes_gcm_enc_64b', @BenchAES_GCM_Encrypt_64B);
  GBenchmark.RegisterTest('aes_gcm_enc_1kb', @BenchAES_GCM_Encrypt_1KB);
  GBenchmark.RegisterTest('aes_gcm_enc_16kb', @BenchAES_GCM_Encrypt_16KB);

  // AES-256-GCM decryption tests
  GBenchmark.RegisterTest('aes_gcm_dec_64b', @BenchAES_GCM_Decrypt_64B);
  GBenchmark.RegisterTest('aes_gcm_dec_1kb', @BenchAES_GCM_Decrypt_1KB);
  GBenchmark.RegisterTest('aes_gcm_dec_16kb', @BenchAES_GCM_Decrypt_16KB);

  // Secure random number generation tests
  GBenchmark.RegisterTest('secure_random_64b', @BenchSecureRandom_64B);
  GBenchmark.RegisterTest('secure_random_1kb', @BenchSecureRandom_1KB);
  GBenchmark.RegisterTest('secure_random_16kb', @BenchSecureRandom_16KB);

  // Key generation tests
  GBenchmark.RegisterTest('generate_key_128bit', @BenchGenerateKey_128bit);
  GBenchmark.RegisterTest('generate_key_256bit', @BenchGenerateKey_256bit);

  WriteLn('Registered ', 17, ' benchmark tests');
end;

procedure PrintUsage;
begin
  WriteLn('Usage: ', ExtractFileName(ParamStr(0)), ' [iterations]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  iterations    Number of iterations per test (default: 1000)');
  WriteLn;
  WriteLn('Examples:');
  WriteLn('  ', ExtractFileName(ParamStr(0)), '           # Run with 1000 iterations');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' 500       # Run with 500 iterations');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' 10000     # Run with 10000 iterations');
end;

begin
  WriteLn('================================================================');
  WriteLn('Comprehensive Crypto Performance Benchmark');
  WriteLn('================================================================');
  WriteLn;

  // Parse command line arguments
  GIterations := 1000;
  if ParamCount > 0 then
  begin
    if (ParamStr(1) = '-h') or (ParamStr(1) = '--help') then
    begin
      PrintUsage;
      Halt(0);
    end;

    GIterations := StrToIntDef(ParamStr(1), 1000);
    if GIterations <= 0 then
    begin
      WriteLn('Error: Iterations must be positive');
      Halt(1);
    end;
  end;

  WriteLn('Iterations per test: ', GIterations);
  WriteLn;

  // Initialize test data
  WriteLn('Initializing test data...');
  InitializeTestData;
  InitializeEncryptedData;
  WriteLn('Test data initialized');
  WriteLn;

  // Create benchmark instance
  GBenchmark := TBenchmark.Create;
  try
    GBenchmark.WarmupIterations := 100;
    GBenchmark.RegressionThreshold := 0.15; // 15%

    // Register all tests
    RegisterAllTests;
    WriteLn;

    // Run all tests
    WriteLn('Running benchmarks...');
    WriteLn('================================================================');
    GBenchmark.Run(GIterations);
    WriteLn('================================================================');
    WriteLn;

    // Print results
    GBenchmark.PrintResults;
    WriteLn;

    // Save baseline
    WriteLn('Saving baseline to crypto_baseline.json...');
    GBenchmark.SaveBaseline('crypto_baseline.json');
    WriteLn('Baseline saved');
    WriteLn;

    WriteLn('================================================================');
    WriteLn('Benchmark completed successfully');
    WriteLn('================================================================');
  finally
    GBenchmark.Free;
  end;
end.
