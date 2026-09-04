program test_performance;

{$mode objfpc}{$H+}

uses
  nextpas.core.system.sysutils, nextpas.core.system.classes, nextpas.core.platform.socket, nextpas.core.time,
  nextpas.core.tls.base, nextpas.core.tls.winssl.lib;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;
  TEST_SIZE = 1024 * 1024; // 1MB

function CreateTCPSocket(const AHost: string; APort: Word): TPlatformSocket;
var
  LAddr: TPlatformSockAddr;
  LIP: UInt32;
begin
  Result := PLATFORM_INVALID_SOCKET;

  if platform_socket_resolve_ipv4(PAnsiChar(AnsiString(AHost)), LIP) <> 0 then
    Exit;

  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
  begin
    Result := PLATFORM_INVALID_SOCKET;
    Exit;
  end;

  platform_sockaddr_ipv4(APort, LIP, LAddr);
  if platform_socket_connect(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(Result);
    Result := PLATFORM_INVALID_SOCKET;
  end;
end;

procedure TestPerformance;
var
  Lib: ISSLLibrary;
  Context: ISSLContext;
  Connection: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Socket: TPlatformSocket;
  Request: AnsiString;
  Buffer: array[0..65535] of Byte; // 64KB buffer
  StartTime, EndTime: TDateTime;
  BytesRead, TotalBytes: Integer;
  BytesSent: Integer;
  ReadCount: Integer;
  ElapsedMs: Int64;
  Throughput: Double;
begin
  WriteLn('=== SSL Performance Test ===');
  WriteLn;

  // Initialize library
  Lib := TWinSSLLibrary.Create as ISSLLibrary;
  if not Lib.Initialize then
  begin
    WriteLn('Failed to initialize WinSSL library');
    Exit;
  end;

  // Create context
  Context := Lib.CreateContext(sslCtxClient);
  Context.SetProtocolVersions([sslProtocolTLS11, sslProtocolTLS12]);

  // Create TCP connection
  Socket := CreateTCPSocket(TEST_HOST, TEST_PORT);
  if Socket.IsInvalid then
  begin
    WriteLn('Failed to create TCP connection');
    Exit;
  end;

  try
    // Create SSL connection
    Connection := Context.CreateConnection(THandle(Socket.Value));
    ClientConn := Connection as ISSLClientConnection;
    ClientConn.SetServerName(TEST_HOST);

    // Perform handshake
    StartTime := Now;
    if not Connection.Connect then
    begin
      WriteLn('SSL handshake failed');
      Exit;
    end;
    EndTime := Now;
    ElapsedMs := DateTimeMillisecondsBetween(EndTime, StartTime);
    WriteLn('Handshake completed in ', ElapsedMs, ' ms');
    WriteLn;

    // Send request for a large file
    Request := 'GET /images/branding/googlelogo/2x/googlelogo_color_272x92dp.png HTTP/1.1' + #13#10 +
               'Host: ' + TEST_HOST + #13#10 +
               'User-Agent: Mozilla/5.0' + #13#10 +
               'Accept: image/png' + #13#10 +
               'Connection: close' + #13#10 +
               #13#10;

    BytesSent := Connection.Write(Request[1], Length(Request));
    WriteLn('Sent ', BytesSent, ' bytes request');

    // Read response and measure throughput
    TotalBytes := 0;
    ReadCount := 0;
    StartTime := Now;

    repeat
      BytesRead := Connection.Read(Buffer[0], SizeOf(Buffer));
      if BytesRead > 0 then
      begin
        Inc(TotalBytes, BytesRead);
        Inc(ReadCount);
      end;
    until BytesRead <= 0;

    EndTime := Now;
    ElapsedMs := DateTimeMillisecondsBetween(EndTime, StartTime);

    // Calculate throughput
    if ElapsedMs > 0 then
    begin
      Throughput := (TotalBytes / 1024.0 / 1024.0) / (ElapsedMs / 1000.0); // MB/s
      WriteLn;
      WriteLn('=== Performance Results ===');
      WriteLn('Total bytes received: ', TotalBytes, ' bytes');
      WriteLn('Number of read calls: ', ReadCount);
      WriteLn('Average bytes per read: ', TotalBytes div Max(1, ReadCount), ' bytes');
      WriteLn('Time elapsed: ', ElapsedMs, ' ms');
      WriteLn('Throughput: ', FormatFloat('0.##', Throughput), ' MB/s');
    end;

    // Test small reads vs large reads
    WriteLn;
    WriteLn('=== Buffer Size Impact Test ===');

    // Note: This would require multiple connections to test properly
    // as we can't re-read the same data
    WriteLn('Current implementation uses 64KB buffer');
    WriteLn('Smaller buffers would require more read() calls');
    WriteLn('Larger buffers might not improve much due to SSL record size limits');

  finally
    platform_socket_close(Socket);
  end;

  WriteLn;
  WriteLn('=== Test Complete ===');
end;

begin
  try
    TestPerformance;
  except
    on E: Exception do
      WriteLn('Exception: ', E.Message);
  end;
end.
