program benchmark_handshake_simple;

{$mode ObjFPC}{$H+}

{
  简化版握手性能测试

  对比 OpenSSL vs MbedTLS 的 TLS 握手性能
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
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;
  ITERATIONS = 10;

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this MbedTLS-specific runtime
// file intentionally keeps direct core GetVerifyResult/GetVerifyResultString
// coverage as backend proof. Generic ISSLCertificateVerification owner-path
// guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

function BenchmarkBackend(const ABackendName: string; ALib: ISSLLibrary): Double;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  I: Integer;
  LStart, LEnd: Int64;
  LTotalTime: Int64;
  LError: string;
begin
  Result := 0;
  LTotalTime := 0;

  WriteLn('Testing ', ABackendName, '...');

  for I := 1 to ITERATIONS do
  begin
    if not InitNetwork(LError) then
      Continue;

    try
      LSock := ConnectTCP(TEST_HOST, TEST_PORT);
      if LSock = INVALID_SOCKET then
        Continue;

      try
        LCtx := ALib.CreateContext(sslCtxClient);
        LCtx.SetVerifyMode([]);  // 禁用证书验证
        LConn := LCtx.CreateConnection(LSock);

        LStart := GetTickCount64;
        if LConn.Connect then
        begin
          LEnd := GetTickCount64;
          LTotalTime := LTotalTime + (LEnd - LStart);

          if I = 1 then
            WriteLn('  Cipher: ', LConn.GetCipherName);

          LConn.Shutdown;
        end
        else if I = 1 then
          WriteLn('  ⚠️  Handshake failed: ', LConn.GetVerifyResultString);

        LConn := nil;
        LCtx := nil;

      finally
        CloseSocket(LSock);
      end;

    finally
      CleanupNetwork;
    end;
  end;

  Result := LTotalTime / ITERATIONS;
  WriteLn('  Average: ', Result:0:2, ' ms');
  WriteLn;
end;

var
  LOpenSSLLib: ISSLLibrary;
  LMbedTLSLib: ISSLLibrary;
  LOpenSSLTime, LMbedTLSTime: Double;
  LSpeedup: Double;

begin
  WriteLn('================================================================================');
  WriteLn('TLS Handshake Performance Benchmark');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('Configuration:');
  WriteLn('  Target: ', TEST_HOST, ':', TEST_PORT);
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
      LOpenSSLTime := BenchmarkBackend('OpenSSL', LOpenSSLLib);
      LOpenSSLLib.Finalize;
    end
    else
      WriteLn('❌ Failed to initialize OpenSSL');

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
      LMbedTLSTime := BenchmarkBackend('MbedTLS', LMbedTLSLib);
      LMbedTLSLib.Finalize;
    end
    else
      WriteLn('❌ Failed to initialize MbedTLS');

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
  WriteLn('Backend      Average Handshake Time');
  WriteLn('------------ ---------------------');
  WriteLn(Format('%-12s %10.2f ms', ['OpenSSL', LOpenSSLTime]));
  WriteLn(Format('%-12s %10.2f ms', ['MbedTLS', LMbedTLSTime]));
  WriteLn;

  if (LOpenSSLTime > 0) and (LMbedTLSTime > 0) then
  begin
    if LMbedTLSTime < LOpenSSLTime then
    begin
      LSpeedup := ((LOpenSSLTime - LMbedTLSTime) / LOpenSSLTime) * 100;
      WriteLn(Format('MbedTLS is %.1f%% faster than OpenSSL', [LSpeedup]));
    end
    else
    begin
      LSpeedup := ((LMbedTLSTime - LOpenSSLTime) / LMbedTLSTime) * 100;
      WriteLn(Format('OpenSSL is %.1f%% faster than MbedTLS', [LSpeedup]));
    end;
  end;

  WriteLn;
  WriteLn('🎉 Benchmark complete!');
end.
