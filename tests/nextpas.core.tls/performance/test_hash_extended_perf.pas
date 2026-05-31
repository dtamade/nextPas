program test_hash_extended_perf;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api;

const
  TEST_ITERATIONS = 1000;
  WARMUP_ITERATIONS = 10;
  TEST_DATA_SIZE = 1024 * 100; // 100KB

type
  THashAlgorithm = record
    Name: string;
    AlgoName: PAnsiChar;
  end;

const
  HASH_ALGORITHMS: array[0..4] of THashAlgorithm = (
    (Name: 'SHA-1'; AlgoName: 'sha1'),
    (Name: 'SHA-224'; AlgoName: 'sha224'),
    (Name: 'SHA-256'; AlgoName: 'sha256'),
    (Name: 'SHA-384'; AlgoName: 'sha384'),
    (Name: 'RIPEMD-160'; AlgoName: 'ripemd160')
  );

var
  TestData: array[0..TEST_DATA_SIZE-1] of Byte;
  CurrentVersion: string;

procedure InitTestData;
var
  i: Integer;
begin
  for i := 0 to TEST_DATA_SIZE - 1 do
    TestData[i] := Byte(i and $FF);
end;

function TestHashPerformance(const AlgoName: PAnsiChar; Iterations: Integer; IsWarmup: Boolean): Double;
var
  ctx: PEVP_MD_CTX;
  md: PEVP_MD;
  digest: array[0..EVP_MAX_MD_SIZE-1] of Byte;
  digest_len: Cardinal;
  i: Integer;
  StartTime, EndTime: TDateTime;
  TotalMs: Double;
begin
  Result := 0;
  
  md := EVP_get_digestbyname(AlgoName);
  if md = nil then
  begin
    if not IsWarmup then
      WriteLn('  ✗ Algorithm not available: ', AlgoName);
    Exit;
  end;

  StartTime := Now;
  
  for i := 1 to Iterations do
  begin
    ctx := EVP_MD_CTX_new();
    if ctx = nil then
    begin
      if not IsWarmup then
        WriteLn('  ✗ Failed to create context');
      Exit;
    end;

    if EVP_DigestInit_ex(ctx, md, nil) <> 1 then
    begin
      EVP_MD_CTX_free(ctx);
      if not IsWarmup then
        WriteLn('  ✗ Failed to initialize digest');
      Exit;
    end;

    if EVP_DigestUpdate(ctx, @TestData[0], TEST_DATA_SIZE) <> 1 then
    begin
      EVP_MD_CTX_free(ctx);
      if not IsWarmup then
        WriteLn('  ✗ Failed to update digest');
      Exit;
    end;

    if EVP_DigestFinal_ex(ctx, @digest[0], @digest_len) <> 1 then
    begin
      EVP_MD_CTX_free(ctx);
      if not IsWarmup then
        WriteLn('  ✗ Failed to finalize digest');
      Exit;
    end;

    EVP_MD_CTX_free(ctx);
  end;

  EndTime := Now;
  TotalMs := MilliSecondsBetween(EndTime, StartTime);
  Result := TotalMs / Iterations;
end;

procedure TestAlgorithm(const HashAlgo: THashAlgorithm);
var
  WarmupTime, AvgTime: Double;
  ThroughputMBps: Double;
begin
  Write('  Testing ', HashAlgo.Name, '...');
  
  // Warmup
  WarmupTime := TestHashPerformance(HashAlgo.AlgoName, WARMUP_ITERATIONS, True);
  if WarmupTime = 0 then
  begin
    WriteLn(' SKIP (not available)');
    Exit;
  end;

  // Real test
  AvgTime := TestHashPerformance(HashAlgo.AlgoName, TEST_ITERATIONS, False);
  if AvgTime = 0 then
  begin
    WriteLn(' FAILED');
    Exit;
  end;

  ThroughputMBps := (TEST_DATA_SIZE / 1024.0 / 1024.0) / (AvgTime / 1000.0);
  
  WriteLn(' OK');
  WriteLn('    Average time: ', Format('%.6f', [AvgTime]), ' ms');
  WriteLn('    Throughput:   ', Format('%.2f', [ThroughputMBps]), ' MB/s');
end;

procedure TestWithVersion;
var
  i: Integer;
  VersionStr: string;
  Separator: string;
begin
  WriteLn;
  Separator := StringOfChar('=', 70);
  WriteLn(Separator);
  WriteLn('Testing OpenSSL Extended Hash Algorithms');
  WriteLn(Separator);
  
  // Load OpenSSL
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('✗ Failed to load OpenSSL');
      Exit;
    end;
  end;

  // EVP functions are automatically loaded with the OpenSSL library

  VersionStr := GetOpenSSLVersion;
  WriteLn('Loaded: ', VersionStr);
  WriteLn;

  // Test all hash algorithms
  for i := Low(HASH_ALGORITHMS) to High(HASH_ALGORITHMS) do
    TestAlgorithm(HASH_ALGORITHMS[i]);

  WriteLn;
end;

procedure GenerateComparisonReport;
var
  Separator: string;
begin
  WriteLn;
  Separator := StringOfChar('=', 70);
  WriteLn(Separator);
  WriteLn('EXTENDED HASH ALGORITHM PERFORMANCE TEST COMPLETED');
  WriteLn(Separator);
  WriteLn;
  WriteLn('Test Configuration:');
  WriteLn('  Data Size:    ', TEST_DATA_SIZE div 1024, ' KB');
  WriteLn('  Iterations:   ', TEST_ITERATIONS);
  WriteLn('  Warmup Runs:  ', WARMUP_ITERATIONS);
  WriteLn;
  WriteLn('Note: Run this test multiple times and compare results');
  WriteLn('      for accurate performance comparison between versions.');
  WriteLn;
end;

begin
  WriteLn('Extended Hash Algorithm Performance Test');
  WriteLn;

  InitTestData;

  // Test with system OpenSSL
  TestWithVersion;

  GenerateComparisonReport;

  WriteLn('Press Enter to exit...');
  ReadLn;
end.
