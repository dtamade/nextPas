program benchmark_throughput;

{$mode ObjFPC}{$H+}

{
  数据吞吐量测试

  测试从 HTTPS 服务器读取数据的速度
}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.mbedtls.lib,
  fafafa.examples.tcp;

const
  // 使用一个返回较大响应的服务
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;
  TEST_PATH = '/';
  ITERATIONS = 5;

type
  TThroughputResult = record
    BackendName: string;
    TotalBytes: Int64;
    TimeMs: Int64;
    ThroughputMBps: Double;
    Success: Boolean;
  end;

function BenchmarkThroughput(const ABackendName: string; ALib: ISSLLibrary): TThroughputResult;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LRequest: AnsiString;
  LBuffer: array[0..8191] of Byte;
  LBytesRead: Integer;
  LTotalBytes: Int64;
  LStart, LEnd: Int64;
  LError: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendName := ABackendName;
  Result.Success := False;

  WriteLn('Testing ', ABackendName, '...');

  if not InitNetwork(LError) then
  begin
    WriteLn('  ❌ Network init failed');
    Exit;
  end;

  try
    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    if LSock = INVALID_SOCKET then
    begin
      WriteLn('  ❌ TCP connect failed');
      Exit;
    end;

    try
      LCtx := ALib.CreateContext(sslCtxClient);
      LCtx.SetVerifyMode([]);  // 禁用验证以测试纯性能
      LConn := LCtx.CreateConnection(LSock);

      if not LConn.Connect then
      begin
        WriteLn('  ❌ Handshake failed');
        Exit;
      end;

      // 发送 HTTP GET
      LRequest := 'GET ' + TEST_PATH + ' HTTP/1.1'#13#10 +
                  'Host: ' + TEST_HOST + #13#10 +
                  'User-Agent: fafafa.ssl-benchmark/1.0'#13#10 +
                  'Accept: */*'#13#10 +
                  'Connection: close'#13#10#13#10;

      if LConn.Write(LRequest[1], Length(LRequest)) <= 0 then
      begin
        WriteLn('  ❌ Write failed');
        Exit;
      end;

      // 读取响应并计时
      LTotalBytes := 0;
      LStart := GetTickCount64;

      repeat
        LBytesRead := LConn.Read(LBuffer, SizeOf(LBuffer));
        if LBytesRead > 0 then
          LTotalBytes := LTotalBytes + LBytesRead;
      until LBytesRead <= 0;

      LEnd := GetTickCount64;

      Result.TotalBytes := LTotalBytes;
      Result.TimeMs := LEnd - LStart;

      if Result.TimeMs > 0 then
      begin
        Result.ThroughputMBps := (LTotalBytes / 1024.0 / 1024.0) / (Result.TimeMs / 1000.0);
        Result.Success := True;

        WriteLn('  ✅ Read ', LTotalBytes, ' bytes in ', Result.TimeMs, ' ms');
        WriteLn('  Throughput: ', Result.ThroughputMBps:0:2, ' MB/s');
      end;

      LConn.Shutdown;
      LConn := nil;
      LCtx := nil;

    finally
      CloseSocket(LSock);
    end;

  finally
    CleanupNetwork;
  end;
end;

function TestMultiple(const ABackendName: string; ALib: ISSLLibrary): TThroughputResult;
var
  I: Integer;
  LResult: TThroughputResult;
  LTotalBytes: Int64;
  LTotalTime: Int64;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendName := ABackendName;

  LTotalBytes := 0;
  LTotalTime := 0;

  for I := 1 to ITERATIONS do
  begin
    LResult := BenchmarkThroughput(ABackendName, ALib);
    if LResult.Success then
    begin
      LTotalBytes := LTotalBytes + LResult.TotalBytes;
      LTotalTime := LTotalTime + LResult.TimeMs;
    end;
  end;

  if LTotalTime > 0 then
  begin
    Result.TotalBytes := LTotalBytes;
    Result.TimeMs := LTotalTime;
    Result.ThroughputMBps := (LTotalBytes / 1024.0 / 1024.0) / (LTotalTime / 1000.0);
    Result.Success := True;
  end;
end;

var
  LOpenSSLLib: ISSLLibrary;
  LMbedTLSLib: ISSLLibrary;
  LOpenSSLResult, LMbedTLSResult: TThroughputResult;
  LSpeedupPercent: Double;

begin
  WriteLn('================================================================================');
  WriteLn('Data Throughput Benchmark');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('Configuration:');
  WriteLn('  Target: ', TEST_HOST, ':', TEST_PORT);
  WriteLn('  Path: ', TEST_PATH);
  WriteLn('  Iterations: ', ITERATIONS);
  WriteLn;

  // Test OpenSSL
  WriteLn('=== OpenSSL ===');
  try
    LoadOpenSSLCore;
    LoadOpenSSLBIO;
    LoadOpenSSLX509;

    LOpenSSLLib := TOpenSSLLibrary.Create;
    if LOpenSSLLib.Initialize then
    begin
      WriteLn('Version: ', LOpenSSLLib.GetVersionString);
      LOpenSSLResult := TestMultiple('OpenSSL', LOpenSSLLib);
      LOpenSSLLib.Finalize;
    end;
    LOpenSSLLib := nil;
  except
    on E: Exception do
      WriteLn('❌ OpenSSL error: ', E.Message);
  end;

  WriteLn;

  // Test MbedTLS
  WriteLn('=== MbedTLS ===');
  try
    LMbedTLSLib := TMbedTLSLibrary.Create;
    if LMbedTLSLib.Initialize then
    begin
      WriteLn('Version: ', LMbedTLSLib.GetVersionString);
      LMbedTLSResult := TestMultiple('MbedTLS', LMbedTLSLib);
      LMbedTLSLib.Finalize;
    end;
    LMbedTLSLib := nil;
  except
    on E: Exception do
      WriteLn('❌ MbedTLS error: ', E.Message);
  end;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('Results Summary');
  WriteLn('================================================================================');
  WriteLn;

  if LOpenSSLResult.Success and LMbedTLSResult.Success then
  begin
    WriteLn(Format('%-15s %15s %15s %15s', ['Backend', 'Total Bytes', 'Total Time', 'Throughput']));
    WriteLn(StringOfChar('-', 70));
    WriteLn(Format('%-15s %15d %12d ms %12.2f MB/s',
      ['OpenSSL', LOpenSSLResult.TotalBytes, LOpenSSLResult.TimeMs, LOpenSSLResult.ThroughputMBps]));
    WriteLn(Format('%-15s %15d %12d ms %12.2f MB/s',
      ['MbedTLS', LMbedTLSResult.TotalBytes, LMbedTLSResult.TimeMs, LMbedTLSResult.ThroughputMBps]));
    WriteLn;

    if LMbedTLSResult.ThroughputMBps > LOpenSSLResult.ThroughputMBps then
    begin
      LSpeedupPercent := ((LMbedTLSResult.ThroughputMBps - LOpenSSLResult.ThroughputMBps) /
                          LOpenSSLResult.ThroughputMBps) * 100;
      WriteLn(Format('MbedTLS is %.1f%% faster', [LSpeedupPercent]));
    end
    else
    begin
      LSpeedupPercent := ((LOpenSSLResult.ThroughputMBps - LMbedTLSResult.ThroughputMBps) /
                          LMbedTLSResult.ThroughputMBps) * 100;
      WriteLn(Format('OpenSSL is %.1f%% faster', [LSpeedupPercent]));
    end;
  end
  else
  begin
    WriteLn('⚠️  Incomplete results');
    if LOpenSSLResult.Success then
      WriteLn('OpenSSL: ', LOpenSSLResult.ThroughputMBps:0:2, ' MB/s');
    if LMbedTLSResult.Success then
      WriteLn('MbedTLS: ', LMbedTLSResult.ThroughputMBps:0:2, ' MB/s');
  end;

  WriteLn;
  WriteLn('🎉 Benchmark complete!');
end.
