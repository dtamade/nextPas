program test_winssl_debug;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Windows, WinSock2,
  nextpas.core.tls.base, nextpas.core.tls.winssl.lib;

const
  TEST_HOST = 'www.google.com';
  TEST_PORT = 443;

function CreateTCPSocket(const AHost: string; APort: Word): TSocket;
var
  HostEnt: PHostEnt;
  SockAddr: TSockAddrIn;
  WSAData: TWSAData;
begin
  Result := INVALID_SOCKET;
  
  // Initialize Winsock on Windows
  if WSAStartup($0202, WSAData) <> 0 then
  begin
    WriteLn('Error: Failed to initialize Winsock');
    Exit;
  end;
  
  // Create socket
  Result := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Result = INVALID_SOCKET then
  begin
    WriteLn('Error: Failed to create socket');
    Exit;
  end;
  
  // Resolve host
  HostEnt := gethostbyname(PChar(AHost));
  if HostEnt = nil then
  begin
    WriteLn('Error: Failed to resolve host: ' + AHost);
    closesocket(Result);
    Result := INVALID_SOCKET;
    Exit;
  end;
  
  // Setup address structure
  FillChar(SockAddr, SizeOf(SockAddr), 0);
  SockAddr.sin_family := AF_INET;
  SockAddr.sin_port := htons(APort);
  SockAddr.sin_addr.S_addr := PLongWord(HostEnt^.h_addr_list^)^;
  
  // Connect
  if connect(Result, PSockAddr(@SockAddr)^, SizeOf(SockAddr)) <> 0 then
  begin
    WriteLn('Error: Failed to connect to ' + AHost + ':' + IntToStr(APort));
    closesocket(Result);
    Result := INVALID_SOCKET;
    Exit;
  end;
  
  WriteLn('Info: TCP connection established to ' + AHost + ':' + IntToStr(APort));
end;

procedure TestWinSSLDebug;
var
  Lib: ISSLLibrary;
  Context: ISSLContext;
  Connection: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Socket: TSocket;
  Request, Response: AnsiString;
  Buffer: array[0..16383] of Byte; // Larger buffer
  BytesRead, BytesSent: Integer;
  TotalRead: Integer;
  i, j: Integer;
  ZeroCount: Integer;
begin
  WriteLn('=== Testing WinSSL Backend with Debug ===');
  WriteLn;
  
  // Create and initialize library
  Lib := TWinSSLLibrary.Create as ISSLLibrary;
  try
    WriteLn('Initializing WinSSL library...');
    if not Lib.Initialize then
    begin
      WriteLn('Error: Failed to initialize WinSSL library');
      Exit;
    end;
    WriteLn('WinSSL library initialized successfully');
    WriteLn;
    
    // Create SSL context
    WriteLn('Creating SSL context...');
    Context := Lib.CreateContext(sslCtxClient);
    try
      // Set protocol versions
      Context.SetProtocolVersions([sslProtocolTLS11, sslProtocolTLS12]);
      WriteLn('SSL context created and configured');
      WriteLn;
      
      // Create TCP socket
      WriteLn('Creating TCP connection to ', TEST_HOST, ':', TEST_PORT, '...');
      Socket := CreateTCPSocket(TEST_HOST, TEST_PORT);
      if Socket = INVALID_SOCKET then
      begin
        WriteLn('Error: Failed to create TCP connection');
        Exit;
      end;
      
      try
        // Create SSL connection
        WriteLn('Creating SSL connection...');
        Connection := Context.CreateConnection(Socket);
        ClientConn := Connection as ISSLClientConnection;
        ClientConn.SetServerName(TEST_HOST);
        try
          // Perform SSL handshake
          WriteLn('Performing SSL handshake...');
          if not Connection.Connect then
          begin
            WriteLn('Error: SSL handshake failed');
            Exit;
          end;
          WriteLn('SSL handshake successful!');
          WriteLn;
          
          // Send HTTP request
          WriteLn('Sending HTTP request...');
          Request := 'GET /robots.txt HTTP/1.1' + #13#10 +
                     'Host: ' + TEST_HOST + #13#10 +
                     'User-Agent: Mozilla/5.0' + #13#10 +
                     'Accept: text/plain' + #13#10 +
                     'Connection: close' + #13#10 +
                     #13#10;
          
          WriteLn('Request length: ', Length(Request), ' bytes');
          WriteLn('Request content:');
          WriteLn(Request);
          
          BytesSent := Connection.Write(Request[1], Length(Request));
          if BytesSent <= 0 then
          begin
            WriteLn('Error: Failed to send request, returned: ', BytesSent);
            Exit;
          end;
          WriteLn('Sent ', BytesSent, ' bytes');
          WriteLn;
          
          // Read response - keep reading until no more data
          WriteLn('Reading response...');
          TotalRead := 0;
          Response := '';
          i := 0;
          
          // Keep reading until connection is closed or error
          ZeroCount := 0;
          while True do
          begin
            Inc(i);
            WriteLn('Read attempt #', i, '...');
            FillChar(Buffer, SizeOf(Buffer), 0);
            BytesRead := Connection.Read(Buffer[0], SizeOf(Buffer)); // Read larger chunks
            
            WriteLn('  Read returned: ', BytesRead);
            
            if BytesRead > 0 then
            begin
              WriteLn('  Received ', BytesRead, ' bytes (Total so far: ', TotalRead + BytesRead, ')');
              SetLength(Response, TotalRead + BytesRead);
              Move(Buffer[0], Response[TotalRead + 1], BytesRead);
              Inc(TotalRead, BytesRead);
              ZeroCount := 0;  // Reset zero count when data is received
              
              // Only show details for first few reads to reduce output
              if i <= 5 then
              begin
                // Show first few bytes in hex
                Write('  First 16 bytes (hex): ');
                for j := 0 to Min(15, BytesRead-1) do
                  Write(IntToHex(Buffer[j], 2), ' ');
                WriteLn;
                
                // Show as chars if printable
                Write('  First 16 bytes (chr): ');
                for j := 0 to Min(15, BytesRead-1) do
                  if (Buffer[j] >= 32) and (Buffer[j] <= 126) then
                    Write(Chr(Buffer[j]))
                  else
                    Write('.');
                WriteLn;
              end;
              WriteLn;
            end
            else if BytesRead = 0 then
            begin
              Inc(ZeroCount);
              WriteLn('  No data available (attempt ', ZeroCount, ' of 10)');
              if ZeroCount >= 10 then
              begin
                WriteLn('  No data after 10 attempts, assuming connection closed');
                Break;
              end;
              Sleep(200);  // Wait a bit before retrying
              Continue;
            end
            else
            begin
              WriteLn('  Connection closed or error: ', BytesRead);
              Break;
            end;
            
            // Small delay to avoid busy waiting
            if i > 100 then // Safety limit
            begin
              WriteLn('  Reached maximum read attempts');
              Break;
            end;
          end;
          
          WriteLn('Total bytes read: ', TotalRead);
          WriteLn;
          
  if TotalRead > 0 then
  begin
    WriteLn('=== Response (first 2000 chars) ===');
    WriteLn(Copy(Response, 1, 2000));
    WriteLn;
    
    // Show last part too
    WriteLn('=== Response (last 500 chars) ===');
    if Length(Response) > 500 then
      WriteLn(Copy(Response, Length(Response) - 500, 500))
    else
      WriteLn(Response);
    WriteLn;
            
            // Also show in hex
            WriteLn('=== Response (first 64 bytes hex) ===');
            for j := 1 to Min(64, Length(Response)) do
            begin
              Write(IntToHex(Ord(Response[j]), 2), ' ');
              if j mod 16 = 0 then WriteLn;
            end;
            WriteLn;
          end
          else
          begin
            WriteLn('No response data received!');
          end;
          
          // Shutdown connection
          WriteLn;
          WriteLn('Shutting down SSL connection...');
          Connection.Shutdown;
          
        finally
          // Connection is freed automatically (interface)
        end;
      finally
        closesocket(Socket);
        WSACleanup;
      end;
    finally
      // Context is freed automatically (interface)
    end;
  finally
    // Lib is freed automatically (interface)
  end;
  
  WriteLn;
  WriteLn('=== Test Complete ===');
end;

begin
  try
    TestWinSSLDebug;
  except
    on E: Exception do
    begin
      WriteLn('Exception: ', E.Message);
    end;
  end;
end.
