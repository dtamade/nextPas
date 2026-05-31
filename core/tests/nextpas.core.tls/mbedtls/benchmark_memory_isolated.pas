program benchmark_memory_isolated;

{$mode ObjFPC}{$H+}

{
  隔离的内存占用测试

  分别测试每个后端,避免相互影响
}

uses
  SysUtils,
  nextpas.core.tls.base,
  {$IFDEF TEST_OPENSSL}
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  {$ENDIF}
  {$IFDEF TEST_MBEDTLS}
  nextpas.core.tls.mbedtls.lib,
  {$ENDIF}
  fafafa.examples.tcp;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;
  NUM_CONNECTIONS = 5;

function GetMemoryUsage: Int64;
var
  F: TextFile;
  Line: string;
begin
  Result := 0;
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
        if Pos('kB', Line) > 0 then
          Delete(Line, Pos('kB', Line), 10);
        Result := StrToInt64Def(Trim(Line), 0) * 1024;
        Break;
      end;
    end;
    CloseFile(F);
  except
    // Ignore
  end;
end;

procedure TestBackend;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
  LMemStart, LMemInit, LMemConn, LMemEnd: Int64;
  I: Integer;
begin
  LMemStart := GetMemoryUsage;
  WriteLn('1. Program start: ', LMemStart div 1024, ' KB');

  {$IFDEF TEST_OPENSSL}
  WriteLn;
  WriteLn('=== Testing OpenSSL ===');
  LoadOpenSSLCore;
  LoadOpenSSLBIO;
  LoadOpenSSLX509;
  LLib := TOpenSSLLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('❌ Init failed');
    Halt(1);
  end;
  WriteLn('Backend: OpenSSL');
  {$ENDIF}

  {$IFDEF TEST_MBEDTLS}
  WriteLn;
  WriteLn('=== Testing MbedTLS ===');
  LLib := TMbedTLSLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('❌ Init failed');
    Halt(1);
  end;
  WriteLn('Backend: MbedTLS');
  {$ENDIF}
  LMemInit := GetMemoryUsage;
  WriteLn('2. After init: ', LMemInit div 1024, ' KB (+', (LMemInit - LMemStart) div 1024, ' KB)');

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('Creating ', NUM_CONNECTIONS, ' connections...');

  for I := 1 to NUM_CONNECTIONS do
  begin
    LSock := ConnectTCP(TEST_HOST, TEST_PORT);
    if LSock = INVALID_SOCKET then
      Continue;

    try
      LCtx := LLib.CreateContext(sslCtxClient);
      LCtx.SetVerifyMode([]);
      LConn := LCtx.CreateConnection(LSock);

      if LConn.Connect then
      begin
        LConn.Shutdown;
      end;

      LConn := nil;
      LCtx := nil;

    finally
      CloseSocket(LSock);
    end;

    if I = 1 then
    begin
      LMemConn := GetMemoryUsage;
      WriteLn('3. After 1st connection: ', LMemConn div 1024, ' KB (+', (LMemConn - LMemInit) div 1024, ' KB)');
    end;
  end;

  LMemEnd := GetMemoryUsage;
  WriteLn('4. After ', NUM_CONNECTIONS, ' connections: ', LMemEnd div 1024, ' KB (+', (LMemEnd - LMemInit) div 1024, ' KB)');

  LLib.Finalize;
  LLib := nil;
  CleanupNetwork;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('Summary:');
  WriteLn('  Init overhead: ', (LMemInit - LMemStart) div 1024, ' KB');
  WriteLn('  1st connection: ', (LMemConn - LMemInit) div 1024, ' KB');
  WriteLn('  Total for ', NUM_CONNECTIONS, ' connections: ', (LMemEnd - LMemInit) div 1024, ' KB');
  WriteLn('  Average per connection: ', ((LMemEnd - LMemConn) div (NUM_CONNECTIONS - 1)) div 1024, ' KB');
  WriteLn('================================================================================');
end;

begin
  TestBackend;
end.
