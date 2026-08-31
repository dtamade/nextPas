program test_performance_comparison;

{$mode objfpc}{$H+}

{
  OpenSSL 1.1.x vs 3.x Performance Benchmark Comparison

  Purpose: Measure and compare actual performance between OpenSSL versions

  Test Categories:
  - Hash functions (SHA-256, SHA-512)
  - Symmetric encryption (AES-128-CBC, AES-256-CBC, AES-128-GCM)
  - Stream cipher (ChaCha20)

  Method:
  - Run each test 100 times
  - Skip first run (warmup)
  - Calculate min/max/average
  - Test with 1MB data blocks
}

uses
  nextpas.core.system.sysutils, nextpas.core.time,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp;

const
  TEST_ITERATIONS = 100;
  DATA_SIZE = 1024 * 1024; // 1MB
  WARMUP_RUNS = 1;

type
  TTestResult = record
    TestName: string;
    MinTime: Double;
    MaxTime: Double;
    AvgTime: Double;
    TotalTime: Double;
    Throughput: Double; // MB/s
  end;


// FPC 自举编译器环境不支持 TStringHelper 方法调用(Illegal qualifier),
// 所以本地实现左/右填充。
function RepeatChar(AC: Char; ACount: Integer): string;
var
  i: Integer;
begin
  SetLength(Result, ACount);
  for i := 1 to ACount do
    Result[i] := AC;
end;

function PadL(AText: string; AWidth: Integer): string;
var
  LPad: Integer;
begin
  LPad := AWidth - Length(AText);
  if LPad <= 0 then
    Result := AText
  else
    Result := RepeatChar(' ', LPad) + AText;
end;

function PadR(AText: string; AWidth: Integer; AFill: Char = ' '): string;
var
  LPad: Integer;
begin
  LPad := AWidth - Length(AText);
  if LPad <= 0 then
    Result := AText
  else
    Result := AText + RepeatChar(AFill, LPad);
end;

var
  TestData: array[0..DATA_SIZE-1] of Byte;
  Results_11x: array of TTestResult;
  Results_3x: array of TTestResult;

procedure InitializeTestData;
var
  i: Integer;
begin
  // Initialize with pseudo-random data
  for i := 0 to DATA_SIZE-1 do
    TestData[i] := Byte(i mod 256);
end;

function RunHashTest(const TestName: string; HashFunc: PEVP_MD; Iterations: Integer): TTestResult;
var
  ctx: PEVP_MD_CTX;
  digest: array[0..63] of Byte;
  len: Cardinal;
  i: Integer;
  startTime, endTime: TDateTime;
  times: array of Double;
  totalTime, minTime, maxTime: Double;
begin
  Result.TestName := TestName;
  SetLength(times, Iterations);

  for i := 0 to Iterations - 1 do
  begin
    ctx := EVP_MD_CTX_new();
    try
      startTime := Now;

      EVP_DigestInit_ex(ctx, HashFunc, nil);
      EVP_DigestUpdate(ctx, @TestData[0], DATA_SIZE);
      EVP_DigestFinal_ex(ctx, @digest[0], len);

      endTime := Now;
      times[i] := DateTimeMillisecondsBetween(endTime, startTime);
    finally
      EVP_MD_CTX_free(ctx);
    end;
  end;

  // Skip warmup runs and calculate statistics
  totalTime := 0;
  minTime := times[WARMUP_RUNS];
  maxTime := times[WARMUP_RUNS];

  for i := WARMUP_RUNS to Iterations - 1 do
  begin
    totalTime := totalTime + times[i];
    if times[i] < minTime then minTime := times[i];
    if times[i] > maxTime then maxTime := times[i];
  end;

  Result.MinTime := minTime;
  Result.MaxTime := maxTime;
  Result.TotalTime := totalTime;
  Result.AvgTime := totalTime / (Iterations - WARMUP_RUNS);

  // Calculate throughput in MB/s
  if Result.AvgTime > 0 then
    Result.Throughput := (DATA_SIZE / 1024.0 / 1024.0) / (Result.AvgTime / 1000.0)
  else
    Result.Throughput := 0;
end;

function RunCipherTest(const TestName: string; CipherFunc: PEVP_CIPHER;
                       KeySize, IVSize: Integer; Iterations: Integer): TTestResult;
var
  ctx: PEVP_CIPHER_CTX;
  key: array[0..31] of Byte;
  iv: array[0..15] of Byte;
  outbuf: array[0..DATA_SIZE + 255] of Byte;
  outlen, finallen: Integer;
  i: Integer;
  startTime, endTime: TDateTime;
  times: array of Double;
  totalTime, minTime, maxTime: Double;
begin
  Result.TestName := TestName;
  SetLength(times, Iterations);

  // Initialize key and IV
  for i := 0 to KeySize - 1 do
    key[i] := Byte(i);
  for i := 0 to IVSize - 1 do
    iv[i] := Byte(i);

  for i := 0 to Iterations - 1 do
  begin
    ctx := EVP_CIPHER_CTX_new();
    try
      startTime := Now;

      EVP_EncryptInit_ex(ctx, CipherFunc, nil, @key[0], @iv[0]);
      EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @TestData[0], DATA_SIZE);
      EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen);

      endTime := Now;
      times[i] := DateTimeMillisecondsBetween(endTime, startTime);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  end;

  // Calculate statistics
  totalTime := 0;
  minTime := times[WARMUP_RUNS];
  maxTime := times[WARMUP_RUNS];

  for i := WARMUP_RUNS to Iterations - 1 do
  begin
    totalTime := totalTime + times[i];
    if times[i] < minTime then minTime := times[i];
    if times[i] > maxTime then maxTime := times[i];
  end;

  Result.MinTime := minTime;
  Result.MaxTime := maxTime;
  Result.TotalTime := totalTime;
  Result.AvgTime := totalTime / (Iterations - WARMUP_RUNS);

  if Result.AvgTime > 0 then
    Result.Throughput := (DATA_SIZE / 1024.0 / 1024.0) / (Result.AvgTime / 1000.0)
  else
    Result.Throughput := 0;
end;

function RunGCMTest(const TestName: string; CipherFunc: PEVP_CIPHER;
                    KeySize: Integer; Iterations: Integer): TTestResult;
var
  ctx: PEVP_CIPHER_CTX;
  key, iv: array[0..31] of Byte;
  tag: array[0..15] of Byte;
  outbuf: array[0..DATA_SIZE + 255] of Byte;
  outlen, finallen: Integer;
  i: Integer;
  startTime, endTime: TDateTime;
  times: array of Double;
  totalTime, minTime, maxTime: Double;
begin
  Result.TestName := TestName;
  SetLength(times, Iterations);

  for i := 0 to KeySize - 1 do
    key[i] := Byte(i);
  for i := 0 to 11 do
    iv[i] := Byte(i);

  for i := 0 to Iterations - 1 do
  begin
    ctx := EVP_CIPHER_CTX_new();
    try
      startTime := Now;

      EVP_EncryptInit_ex(ctx, CipherFunc, nil, @key[0], @iv[0]);
      EVP_EncryptUpdate(ctx, @outbuf[0], outlen, @TestData[0], DATA_SIZE);
      EVP_EncryptFinal_ex(ctx, @outbuf[outlen], finallen);
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, @tag[0]);

      endTime := Now;
      times[i] := DateTimeMillisecondsBetween(endTime, startTime);
    finally
      EVP_CIPHER_CTX_free(ctx);
    end;
  end;

  totalTime := 0;
  minTime := times[WARMUP_RUNS];
  maxTime := times[WARMUP_RUNS];

  for i := WARMUP_RUNS to Iterations - 1 do
  begin
    totalTime := totalTime + times[i];
    if times[i] < minTime then minTime := times[i];
    if times[i] > maxTime then maxTime := times[i];
  end;

  Result.MinTime := minTime;
  Result.MaxTime := maxTime;
  Result.TotalTime := totalTime;
  Result.AvgTime := totalTime / (Iterations - WARMUP_RUNS);

  if Result.AvgTime > 0 then
    Result.Throughput := (DATA_SIZE / 1024.0 / 1024.0) / (Result.AvgTime / 1000.0)
  else
    Result.Throughput := 0;
end;

procedure RunTests(Version: TOpenSSLVersion; var Results: array of TTestResult);
var
  idx: Integer;
begin
  idx := 0;

  WriteLn('Testing hash functions...');
  Results[idx] := RunHashTest('SHA-256', EVP_sha256(), TEST_ITERATIONS);
  Inc(idx);
  Results[idx] := RunHashTest('SHA-512', EVP_sha512(), TEST_ITERATIONS);
  Inc(idx);

  WriteLn('Testing symmetric encryption...');
  Results[idx] := RunCipherTest('AES-128-CBC', EVP_aes_128_cbc(), 16, 16, TEST_ITERATIONS);
  Inc(idx);
  Results[idx] := RunCipherTest('AES-256-CBC', EVP_aes_256_cbc(), 32, 16, TEST_ITERATIONS);
  Inc(idx);

  WriteLn('Testing AEAD modes...');
  Results[idx] := RunGCMTest('AES-128-GCM', EVP_aes_128_gcm(), 16, TEST_ITERATIONS);
  Inc(idx);

  WriteLn('Testing stream cipher...');
  Results[idx] := RunCipherTest('ChaCha20', EVP_chacha20(), 32, 16, TEST_ITERATIONS);
end;

procedure PrintResults(const Version: string; const Results: array of TTestResult);
var
  i: Integer;
  HName, HMin, HMax, HAvg, HMBs, HRuler: string;
begin
  WriteLn;
  WriteLn('=== ', Version, ' Results ===');
  WriteLn;
  HName := 'Test'; HMin := 'Min(ms)'; HMax := 'Max(ms)';
  HAvg := 'Avg(ms)'; HMBs := 'MB/s'; HRuler := '';
  WriteLn(PadR(HName, 20), PadL(HMin, 10), PadL(HMax, 10),
          PadL(HAvg, 10), PadL(HMBs, 12));
  WriteLn(PadR(HRuler, 62, '-'));

  for i := 0 to High(Results) do
  begin
    WriteLn(PadR(Results[i].TestName, 20),
            PadL(Format('%8.2f', [Results[i].MinTime]), 10),
            PadL(Format('%8.2f', [Results[i].MaxTime]), 10),
            PadL(Format('%8.2f', [Results[i].AvgTime]), 10),
            PadL(Format('%10.2f', [Results[i].Throughput]), 12));
  end;
end;

procedure PrintComparison;
var
  i: Integer;
  improvement: Double;
  HName, H11x, H3x, HDiff, HRuler: string;
begin
  WriteLn;
  WriteLn('=== Performance Comparison ===');
  WriteLn;
  HName := 'Test'; H11x := '1.1.x(ms)'; H3x := '3.x(ms)';
  HDiff := 'Difference'; HRuler := '';
  WriteLn(PadR(HName, 20), PadL(H11x, 12), PadL(H3x, 12),
          PadL(HDiff, 12));
  WriteLn(PadR(HRuler, 56, '-'));

  for i := 0 to High(Results_11x) do
  begin
    if Results_11x[i].AvgTime > 0 then
      improvement := ((Results_11x[i].AvgTime - Results_3x[i].AvgTime) / Results_11x[i].AvgTime) * 100
    else
      improvement := 0;

    WriteLn(PadR(Results_11x[i].TestName, 20),
            PadL(Format('%10.2f', [Results_11x[i].AvgTime]), 12),
            PadL(Format('%10.2f', [Results_3x[i].AvgTime]), 12),
            PadL(Format('%10.1f%%', [improvement]), 12));
  end;

  WriteLn;
  WriteLn('Note: Positive percentage = 3.x is faster');
end;

procedure RunBenchmark;
begin
  WriteLn('=========================================');
  WriteLn('OpenSSL Performance Benchmark');
  WriteLn('=========================================');
  WriteLn;
  WriteLn('Configuration:');
  WriteLn('  Data size: ', DATA_SIZE div 1024, ' KB');
  WriteLn('  Iterations: ', TEST_ITERATIONS);
  WriteLn('  Warmup runs: ', WARMUP_RUNS);
  WriteLn;

  InitializeTestData;

  // Test OpenSSL 1.1.x
  WriteLn('--- Testing OpenSSL 1.1.x ---');
  LoadOpenSSLCoreWithVersion(sslVersion_1_1);
  LoadEVP(GetCryptoLibHandle);
  WriteLn('Version: ', GetOpenSSLVersionString);
  WriteLn;
  SetLength(Results_11x, 6);
  RunTests(sslVersion_1_1, Results_11x);
  PrintResults('OpenSSL 1.1.x', Results_11x);

  // Properly unload before switching versions
  UnloadEVP;
  UnloadOpenSSLCore;

  WriteLn;
  WriteLn('--- Testing OpenSSL 3.x ---');
  LoadOpenSSLCoreWithVersion(sslVersion_3_0);
  if not LoadEVP(GetCryptoLibHandle) then
    raise Exception.Create('Failed to load EVP for OpenSSL 3.x');
  WriteLn('Version: ', GetOpenSSLVersionString);
  WriteLn;
  SetLength(Results_3x, 6);
  RunTests(sslVersion_3_0, Results_3x);
  PrintResults('OpenSSL 3.x', Results_3x);

  PrintComparison;

  WriteLn;
  WriteLn('=========================================');
  WriteLn('Benchmark completed successfully');
  WriteLn('=========================================');
end;

begin
  try
    RunBenchmark;
    UnloadOpenSSLCore;
  except
    on E: Exception do
    begin
      WriteLn('[ERROR] ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
