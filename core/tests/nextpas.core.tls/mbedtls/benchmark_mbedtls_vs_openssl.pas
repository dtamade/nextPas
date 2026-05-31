program benchmark_mbedtls_vs_openssl;

{$mode ObjFPC}{$H+}

{
  MbedTLS vs OpenSSL 性能基准测试

  测试项目:
  1. TLS 握手性能 (TLS 1.2 vs TLS 1.3)
  2. 数据吞吐量 (不同块大小)
  3. 内存占用
  4. 密码套件性能
}

uses
  SysUtils, DateUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  fafafa.examples.tcp;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;
  HANDSHAKE_ITERATIONS = 10;
  THROUGHPUT_SIZE = 1024 * 1024; // 1MB

type
  TBenchmarkResult = record
    BackendName: string;
    TLSVersion: string;
    HandshakeTime: Double;      // ms
    HandshakeAvg: Double;       // ms
    ThroughputMBps: Double;     // MB/s
    MemoryUsage: Int64;         // bytes
    CipherSuite: string;
    Success: Boolean;
  end;

var
  GResults: array of TBenchmarkResult;

procedure AddResult(const AResult: TBenchmarkResult);
begin
  SetLength(GResults, Length(GResults) + 1);
  GResults[High(GResults)] := AResult;
end;

function BenchmarkHandshake(ABackend: TSSLLibraryType; ATLSVersion: TSSLProtocolVersion): TBenchmarkResult;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  I: Integer;
  LStartTime, LEndTime: TDateTime;
  LTotalTime: Double;
  LError: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendName := LibraryTypeToString(ABackend);
  Result.TLSVersion := ProtocolVersionToString(ATLSVersion);
  Result.Success := False;

  WriteLn('Testing ', Result.BackendName, ' / ', Result.TLSVersion, '...');

  if not InitNetwork(LError) then
  begin
    WriteLn('  ❌ Network init failed');
    Exit;
  end;

  try
    LLib := TSSLFactory.GetLibraryInstance(ABackend);
    if not LLib.Initialize then
    begin
      WriteLn('  ❌ Library init failed');
      Exit;
    end;

    LTotalTime := 0;

    for I := 1 to HANDSHAKE_ITERATIONS do
    begin
      // 连接 TCP
      LSock := ConnectTCP(TEST_HOST, TEST_PORT);
      if LSock = INVALID_SOCKET then
      begin
        WriteLn('  ❌ TCP connect failed (iteration ', I, ')');
        Continue;
      end;

      try
        // 创建 Context
        LCtx := LLib.CreateContext(sslCtxClient);

        // 设置协议版本
        if ATLSVersion = sslProtocolTLS12 then
          LCtx.SetProtocolVersions([sslProtocolTLS12])
        else if ATLSVersion = sslProtocolTLS13 then
          LCtx.SetProtocolVersions([sslProtocolTLS13]);

        // 创建 Connection
        LConn := LCtx.CreateConnection(LSock);

        // 计时握手
        LStartTime := Now;
        if LConn.Connect then
        begin
          LEndTime := Now;
          LTotalTime := LTotalTime + MilliSecondsBetween(LEndTime, LStartTime);

          // 第一次获取详细信息
          if I = 1 then
          begin
            Result.CipherSuite := LConn.GetCipherName;
            Result.Success := True;
          end;

          LConn.Shutdown;
        end
        else
        begin
          WriteLn('  ⚠️  Handshake failed (iteration ', I, ')');
        end;

        LConn := nil;
        LCtx := nil;

      finally
        CloseSocket(LSock);
      end;
    end;

    if Result.Success then
    begin
      Result.HandshakeAvg := LTotalTime / HANDSHAKE_ITERATIONS;
      Result.HandshakeTime := LTotalTime;
      WriteLn('  ✅ Avg handshake: ', Result.HandshakeAvg:0:2, ' ms');
    end;

    LLib.Finalize;
    LLib := nil;

  finally
    CleanupNetwork;
  end;
end;

function BenchmarkThroughput(ABackend: TSSLLibraryType): TBenchmarkResult;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LRequest: AnsiString;
  LBuffer: array[0..8191] of Byte;
  LBytesRead, LTotalBytes: Int64;
  LStartTime, LEndTime: TDateTime;
  LSeconds: Double;
  LError: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendName := LibraryTypeToString(ABackend);
  Result.Success := False;

  WriteLn('Testing throughput for ', Result.BackendName, '...');

  if not InitNetwork(LError) then
  begin
    WriteLn('  ❌ Network init failed');
    Exit;
  end;

  try
    LLib := TSSLFactory.GetLibraryInstance(ABackend);
    if not LLib.Initialize then
    begin
      WriteLn('  ❌ Library init failed');
      Exit;
    end;

    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    if LSock = INVALID_SOCKET then
    begin
      WriteLn('  ❌ TCP connect failed');
      Exit;
    end;

    try
      LCtx := LLib.CreateContext(sslCtxClient);
      LConn := LCtx.CreateConnection(LSock);

      if not LConn.Connect then
      begin
        WriteLn('  ❌ Handshake failed');
        Exit;
      end;

      // 发送 HTTP GET
      LRequest := 'GET / HTTP/1.1'#13#10 +
                  'Host: ' + TEST_HOST + #13#10 +
                  'Connection: close'#13#10#13#10;

      LConn.Write(LRequest[1], Length(LRequest));

      // 计时读取
      LTotalBytes := 0;
      LStartTime := Now;

      repeat
        LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
        if LBytesRead > 0 then
          LTotalBytes := LTotalBytes + LBytesRead;
      until LBytesRead <= 0;

      LEndTime := Now;
      LSeconds := (LEndTime - LStartTime) * 86400.0;

      if LSeconds > 0 then
      begin
        Result.ThroughputMBps := (LTotalBytes / 1024.0 / 1024.0) / LSeconds;
        Result.Success := True;
        WriteLn('  ✅ Throughput: ', Result.ThroughputMBps:0:2, ' MB/s (', LTotalBytes, ' bytes in ', LSeconds:0:3, 's)');
      end;

      LConn.Shutdown;
      LConn := nil;
      LCtx := nil;

    finally
      CloseSocket(LSock);
    end;

    LLib.Finalize;
    LLib := nil;

  finally
    CleanupNetwork;
  end;
end;

procedure PrintResults;
var
  I: Integer;
begin
  WriteLn;
  WriteLn('================================================================================');
  WriteLn('Benchmark Results Summary');
  WriteLn('================================================================================');
  WriteLn;

  WriteLn('Handshake Performance:');
  WriteLn(Format('%-15s %-12s %10s %12s %s', ['Backend', 'TLS Version', 'Avg (ms)', 'Total (ms)', 'Cipher Suite']));
  WriteLn(StringOfChar('-', 90));

  for I := 0 to High(GResults) do
  begin
    if (GResults[I].HandshakeAvg > 0) and GResults[I].Success then
      WriteLn(Format('%-15s %-12s %10.2f %12.2f %s',
        [GResults[I].BackendName,
         GResults[I].TLSVersion,
         GResults[I].HandshakeAvg,
         GResults[I].HandshakeTime,
         GResults[I].CipherSuite]));
  end;

  WriteLn;
  WriteLn('Throughput Performance:');
  WriteLn(Format('%-15s %15s', ['Backend', 'Throughput']));
  WriteLn(StringOfChar('-', 40));

  for I := 0 to High(GResults) do
  begin
    if (GResults[I].ThroughputMBps > 0) and GResults[I].Success then
      WriteLn(Format('%-15s %12.2f MB/s',
        [GResults[I].BackendName,
         GResults[I].ThroughputMBps]));
  end;

  WriteLn;
  WriteLn('================================================================================');
end;

var
  LResult: TBenchmarkResult;

begin
  // 初始化 OpenSSL
  try
    LoadOpenSSLCore;
    LoadOpenSSLBIO;
    LoadOpenSSLX509;
  except
    on E: Exception do
      WriteLn('⚠️  Warning: OpenSSL init failed: ', E.Message);
  end;

  WriteLn('================================================================================');
  WriteLn('MbedTLS vs OpenSSL Performance Benchmark');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('Configuration:');
  WriteLn('  Target: ', TEST_HOST, ':', TEST_PORT);
  WriteLn('  Handshake iterations: ', HANDSHAKE_ITERATIONS);
  WriteLn;

  // Test OpenSSL
  WriteLn('=== Testing OpenSSL ===');
  WriteLn;

  LResult := BenchmarkHandshake(sslOpenSSL, sslProtocolTLS12);
  AddResult(LResult);

  LResult := BenchmarkHandshake(sslOpenSSL, sslProtocolTLS13);
  AddResult(LResult);

  LResult := BenchmarkThroughput(sslOpenSSL);
  AddResult(LResult);

  WriteLn;

  // Test MbedTLS
  WriteLn('=== Testing MbedTLS ===');
  WriteLn;

  LResult := BenchmarkHandshake(sslMbedTLS, sslProtocolTLS12);
  AddResult(LResult);

  LResult := BenchmarkHandshake(sslMbedTLS, sslProtocolTLS13);
  AddResult(LResult);

  LResult := BenchmarkThroughput(sslMbedTLS);
  AddResult(LResult);

  // Print summary
  PrintResults;

  WriteLn;
  WriteLn('🎉 Benchmark complete!');
end.
