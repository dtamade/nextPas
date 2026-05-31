program test_winssl_simple;

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

procedure TestWinSSL;
var
  Lib: ISSLLibrary;
  Context: ISSLContext;
  Connection: ISSLConnection;
  ClientConn: ISSLClientConnection;
  Socket: TSocket;
  Request, Response: AnsiString;
  Buffer: array[0..4095] of Byte;
  BytesRead, BytesSent: Integer;
  Cert: ISSLCertificate;
begin
  WriteLn('=== Testing WinSSL Backend ===');
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
            WriteLn('Handshake state: ', Ord(Connection.DoHandshake));
            Exit;
          end;
          WriteLn('SSL handshake successful!');
          WriteLn;
          
          // Get connection information
          WriteLn('=== Connection Information ===');
          WriteLn('Protocol Version: ', Ord(Connection.GetProtocolVersion));
          WriteLn('Cipher Name: ', Connection.GetCipherName);
          WriteLn('Is Connected: ', Connection.IsConnected);
          WriteLn;
          
          // Get peer certificate
          WriteLn('=== Peer Certificate ===');
          Cert := Connection.GetPeerCertificate;
          if Cert <> nil then
          begin
            WriteLn('Subject: ', Cert.GetSubject);
            WriteLn('Issuer: ', Cert.GetIssuer);
            WriteLn('Serial Number: ', Cert.GetSerialNumber);
            WriteLn('Not Before: ', DateTimeToStr(Cert.GetNotBefore));
            WriteLn('Not After: ', DateTimeToStr(Cert.GetNotAfter));
            WriteLn('Is Expired: ', Cert.IsExpired);
          end
          else
          begin
            WriteLn('No peer certificate available');
          end;
          WriteLn;
          
          // Send HTTP request
          WriteLn('Sending HTTP request...');
          Request := 'GET / HTTP/1.1' + #13#10 +
                     'Host: ' + TEST_HOST + #13#10 +
                     'Connection: close' + #13#10 +
                     #13#10;
          
          BytesSent := Connection.Write(Request[1], Length(Request));
          if BytesSent <= 0 then
          begin
            WriteLn('Error: Failed to send request');
            Exit;
          end;
          WriteLn('Sent ', BytesSent, ' bytes');
          
          // Read response
          WriteLn('Reading response...');
          BytesRead := Connection.Read(Buffer[0], SizeOf(Buffer));
          if BytesRead > 0 then
          begin
            SetLength(Response, BytesRead);
            Move(Buffer[0], Response[1], BytesRead);
            WriteLn('Received ', BytesRead, ' bytes');
            WriteLn;
            WriteLn('=== Response (first 500 chars) ===');
            WriteLn(Copy(Response, 1, 500));
          end
          else
          begin
            WriteLn('Error: Failed to read response');
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
    TestWinSSL;
  except
    on E: Exception do
    begin
      WriteLn('Exception: ', E.Message);
      // Stack trace not available in Free Pascal
    end;
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
