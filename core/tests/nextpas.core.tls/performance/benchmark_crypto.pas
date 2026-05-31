program benchmark_crypto;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.aes,
  nextpas.core.tls.openssl.api.sha;

const
  ITERATIONS_HASH = 10000;      // 哈希测试迭代次数
  ITERATIONS_SYMMETRIC = 1000;  // 对称加密迭代次数
  ITERATIONS_ASYMMETRIC = 100;  // 非对称加密迭代次数
  
  TEST_DATA_SIZE = 1024;  // 1KB测试数据

var
  TestData: array[0..TEST_DATA_SIZE-1] of Byte;
  StartTime, EndTime: TDateTime;
  ElapsedMS: Int64;
  ThroughputMBs: Double;

procedure InitTestData;
var
  I: Integer;
begin
  for I := 0 to TEST_DATA_SIZE - 1 do
    TestData[I] := Byte(I mod 256);
end;

function GetElapsedMS(StartT, EndT: TDateTime): Int64;
begin
  Result := MilliSecondsBetween(EndT, StartT);
end;

procedure PrintResult(const TestName: string; Iterations: Integer; ElapsedMS: Int64);
var
  OpsPerSec: Double;
  AvgTimeUS: Double;
begin
  if ElapsedMS > 0 then
  begin
    OpsPerSec := (Iterations / ElapsedMS) * 1000;
    AvgTimeUS := (ElapsedMS * 1000.0) / Iterations;
  end
  else
  begin
    OpsPerSec := 0;
    AvgTimeUS := 0;
  end;
  
  WriteLn(Format('%-30s %8d ops in %6d ms | %10.2f ops/sec | %8.2f µs/op', 
    [TestName, Iterations, ElapsedMS, OpsPerSec, AvgTimeUS]));
end;

procedure BenchmarkSHA256;
var
  I: Integer;
  Ctx: PEVP_MD_CTX;
  Digest: array[0..31] of Byte;
  DigestLen: Cardinal;
  MD: PEVP_MD;
begin
  Write('SHA-256 (' + IntToStr(TEST_DATA_SIZE) + ' bytes)...');
  
  MD := EVP_sha256();
  if not Assigned(MD) then
  begin
    WriteLn(' ✗ SKIPPED (EVP_sha256 not available)');
    Exit;
  end;
  
  StartTime := Now;
  
  for I := 1 to ITERATIONS_HASH do
  begin
    Ctx := EVP_MD_CTX_new();
    if Assigned(Ctx) then
    begin
      EVP_DigestInit_ex(Ctx, MD, nil);
      EVP_DigestUpdate(Ctx, @TestData[0], TEST_DATA_SIZE);
      EVP_DigestFinal_ex(Ctx, @Digest[0], DigestLen);
      EVP_MD_CTX_free(Ctx);
    end;
  end;
  
  EndTime := Now;
  ElapsedMS := GetElapsedMS(StartTime, EndTime);
  
  WriteLn(' ✓');
  PrintResult('  SHA-256', ITERATIONS_HASH, ElapsedMS);
  
  // 计算吞吐量
  ThroughputMBs := (ITERATIONS_HASH * TEST_DATA_SIZE / 1024.0 / 1024.0) / (ElapsedMS / 1000.0);
  WriteLn(Format('  Throughput: %.2f MB/s', [ThroughputMBs]));
end;

procedure BenchmarkSHA512;
var
  I: Integer;
  Ctx: PEVP_MD_CTX;
  Digest: array[0..63] of Byte;
  DigestLen: Cardinal;
  MD: PEVP_MD;
begin
  Write('SHA-512 (' + IntToStr(TEST_DATA_SIZE) + ' bytes)...');
  
  MD := EVP_sha512();
  if not Assigned(MD) then
  begin
    WriteLn(' ✗ SKIPPED (EVP_sha512 not available)');
    Exit;
  end;
  
  StartTime := Now;
  
  for I := 1 to ITERATIONS_HASH do
  begin
    Ctx := EVP_MD_CTX_new();
    if Assigned(Ctx) then
    begin
      EVP_DigestInit_ex(Ctx, MD, nil);
      EVP_DigestUpdate(Ctx, @TestData[0], TEST_DATA_SIZE);
      EVP_DigestFinal_ex(Ctx, @Digest[0], DigestLen);
      EVP_MD_CTX_free(Ctx);
    end;
  end;
  
  EndTime := Now;
  ElapsedMS := GetElapsedMS(StartTime, EndTime);
  
  WriteLn(' ✓');
  PrintResult('  SHA-512', ITERATIONS_HASH, ElapsedMS);
  
  ThroughputMBs := (ITERATIONS_HASH * TEST_DATA_SIZE / 1024.0 / 1024.0) / (ElapsedMS / 1000.0);
  WriteLn(Format('  Throughput: %.2f MB/s', [ThroughputMBs]));
end;

procedure BenchmarkAES256_CBC;
var
  I: Integer;
  Ctx: PEVP_CIPHER_CTX;
  Cipher: PEVP_CIPHER;
  Key: array[0..31] of Byte;  // 256 bits
  IV: array[0..15] of Byte;    // 128 bits
  OutBuf: array[0..TEST_DATA_SIZE+15] of Byte;
  OutLen, FinalLen: Integer;
begin
  Write('AES-256-CBC encrypt (' + IntToStr(TEST_DATA_SIZE) + ' bytes)...');
  
  Cipher := EVP_aes_256_cbc();
  if not Assigned(Cipher) then
  begin
    WriteLn(' ✗ SKIPPED (EVP_aes_256_cbc not available)');
    Exit;
  end;
  
  // 初始化密钥和IV
  FillChar(Key, SizeOf(Key), $AA);
  FillChar(IV, SizeOf(IV), $BB);
  
  StartTime := Now;
  
  for I := 1 to ITERATIONS_SYMMETRIC do
  begin
    Ctx := EVP_CIPHER_CTX_new();
    if Assigned(Ctx) then
    begin
      EVP_EncryptInit_ex(Ctx, Cipher, nil, @Key[0], @IV[0]);
      EVP_EncryptUpdate(Ctx, @OutBuf[0], OutLen, @TestData[0], TEST_DATA_SIZE);
      EVP_EncryptFinal_ex(Ctx, @OutBuf[OutLen], FinalLen);
      EVP_CIPHER_CTX_free(Ctx);
    end;
  end;
  
  EndTime := Now;
  ElapsedMS := GetElapsedMS(StartTime, EndTime);
  
  WriteLn(' ✓');
  PrintResult('  AES-256-CBC Encrypt', ITERATIONS_SYMMETRIC, ElapsedMS);
  
  ThroughputMBs := (ITERATIONS_SYMMETRIC * TEST_DATA_SIZE / 1024.0 / 1024.0) / (ElapsedMS / 1000.0);
  WriteLn(Format('  Throughput: %.2f MB/s', [ThroughputMBs]));
end;

procedure BenchmarkRSA2048_Sign;
begin
  // RSA签名基准测试暂时跳过
  // 原因: EVP_PKEY相关API需要更复杂的设置
  WriteLn('RSA-2048 签名 - ⏭️  SKIPPED (复杂API，后续实现)');
end;

procedure PrintHeader;
begin
  WriteLn('========================================');
  WriteLn('fafafa.ssl 性能基准测试');
  WriteLn('========================================');
  WriteLn;
  WriteLn('OpenSSL版本: ', GetOpenSSLVersionString);
  WriteLn('测试数据大小: ', TEST_DATA_SIZE, ' bytes');
  WriteLn;
end;

procedure PrintFooter;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('测试完成');
  WriteLn('========================================');
end;

begin
  // 加载OpenSSL
  if not LoadOpenSSLCore then
  begin
    WriteLn('错误: 无法加载OpenSSL库');
    Halt(1);
  end;
  
  InitTestData;
  
  PrintHeader;
  
  WriteLn('=== 哈希算法基准 ===');
  WriteLn;
  BenchmarkSHA256;
  WriteLn;
  BenchmarkSHA512;
  WriteLn;
  
  WriteLn('=== 对称加密基准 ===');
  WriteLn;
  BenchmarkAES256_CBC;
  WriteLn;
  
  WriteLn('=== 非对称加密基准 ===');
  WriteLn;
  BenchmarkRSA2048_Sign;
  WriteLn;
  
  PrintFooter;
  
  // 清理
  UnloadOpenSSLCore;
end.

