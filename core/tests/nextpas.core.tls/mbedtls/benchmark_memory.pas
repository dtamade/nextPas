program benchmark_memory;

{$mode ObjFPC}{$H+}

{
  内存占用对比测试

  测量 OpenSSL vs MbedTLS 的内存占用
}

uses
  SysUtils,
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

function GetMemoryUsage: Int64;
var
  F: TextFile;
  Line: string;
  VmRSS: Int64;
begin
  Result := 0;
  VmRSS := 0;

  AssignFile(F, '/proc/self/status');
  try
    Reset(F);
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      if Pos('VmRSS:', Line) = 1 then
      begin
        Delete(Line, 1, 6);
        Line := Trim(Line);
        // 移除 " kB"
        if Pos('kB', Line) > 0 then
          Delete(Line, Pos('kB', Line), 10);
        VmRSS := StrToInt64Def(Trim(Line), 0);
        Break;
      end;
    end;
    CloseFile(F);
  except
    // Ignore errors
  end;

  Result := VmRSS * 1024; // 转换为字节
end;

procedure TestBackend(const ABackendName: string; ALib: ISSLLibrary);
var
  LMemBefore, LMemAfter, LMemPeak: Int64;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  I: Integer;
begin
  WriteLn('Testing ', ABackendName, '...');

  LMemBefore := GetMemoryUsage;
  WriteLn('  Memory before: ', LMemBefore div 1024, ' KB');

  if not InitNetwork(LError) then
  begin
    WriteLn('  ❌ Network init failed');
    Exit;
  end;

  try
    // 创建多个连接以测量内存占用
    for I := 1 to 3 do
    begin
      LSock := ConnectTCP(TEST_HOST, TEST_PORT);
      if LSock = INVALID_SOCKET then
        Continue;

      try
        LCtx := ALib.CreateContext(sslCtxClient);
        LCtx.SetVerifyMode([]);
        LConn := LCtx.CreateConnection(LSock);

        if LConn.Connect then
        begin
          LMemPeak := GetMemoryUsage;
          LConn.Shutdown;
        end;

        LConn := nil;
        LCtx := nil;

      finally
        CloseSocket(LSock);
      end;
    end;

    LMemAfter := GetMemoryUsage;
    WriteLn('  Memory after: ', LMemAfter div 1024, ' KB');
    WriteLn('  Memory peak: ', LMemPeak div 1024, ' KB');
    WriteLn('  Memory increase: ', (LMemAfter - LMemBefore) div 1024, ' KB');
    WriteLn('  Peak increase: ', (LMemPeak - LMemBefore) div 1024, ' KB');

  finally
    CleanupNetwork;
  end;

  WriteLn;
end;

var
  LOpenSSLLib: ISSLLibrary;
  LMbedTLSLib: ISSLLibrary;

begin
  WriteLn('================================================================================');
  WriteLn('Memory Usage Benchmark');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('Measuring memory usage during TLS connections...');
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
      TestBackend('OpenSSL', LOpenSSLLib);
      LOpenSSLLib.Finalize;
    end;
    LOpenSSLLib := nil;
  except
    on E: Exception do
      WriteLn('❌ OpenSSL error: ', E.Message);
  end;

  // Test MbedTLS
  WriteLn('=== MbedTLS ===');
  try
    LMbedTLSLib := TMbedTLSLibrary.Create;
    if LMbedTLSLib.Initialize then
    begin
      WriteLn('Version: ', LMbedTLSLib.GetVersionString);
      TestBackend('MbedTLS', LMbedTLSLib);
      LMbedTLSLib.Finalize;
    end;
    LMbedTLSLib := nil;
  except
    on E: Exception do
      WriteLn('❌ MbedTLS error: ', E.Message);
  end;

  WriteLn('================================================================================');
  WriteLn('Note: Memory measurements are approximate and include process overhead');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('🎉 Benchmark complete!');
end.
