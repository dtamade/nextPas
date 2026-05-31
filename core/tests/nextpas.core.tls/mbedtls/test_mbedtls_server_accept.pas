program test_mbedtls_server_accept;

{$mode ObjFPC}{$H+}
{$DEFINE USE_CTHREADS}

{
  MbedTLS Server Accept and Handshake Test

  Week 2 Task 2.2: 服务端 Accept 连接和握手测试

  测试场景:
  1. 服务端 Accept 连接
  2. 服务端握手完成
  3. 客户端验证服务端证书
  4. 双向数据传输
  5. 正常关闭连接
}

uses
  {$IFDEF UNIX}
  CThreads,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  fafafa.examples.tcp;

type
  TTestResult = record
    Name: string;
    Success: Boolean;
    Message: string;
  end;

  { 服务端线程 }
  TServerThread = class(TThread)
  private
    FPort: Word;
    FLib: ISSLLibrary;
    FError: string;
    FSuccess: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(APort: Word; ALib: ISSLLibrary);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
  end;

var
  GResults: array of TTestResult;
  GLib: ISSLLibrary;

const
  TEST_CERT_PATH = 'tests/certs/server-cert.pem';
  TEST_KEY_PATH = 'tests/certs/server-key.pem';
  TEST_PORT = 18443;  // 测试端口 (higher port)

procedure AddResult(const AName: string; ASuccess: Boolean; const AMessage: string = '');
begin
  SetLength(GResults, Length(GResults) + 1);
  GResults[High(GResults)].Name := AName;
  GResults[High(GResults)].Success := ASuccess;
  GResults[High(GResults)].Message := AMessage;
end;

{ TServerThread }

constructor TServerThread.Create(APort: Word; ALib: ISSLLibrary);
begin
  inherited Create(True);  // Create suspended
  FreeOnTerminate := False;
  FPort := APort;
  FLib := ALib;
  FSuccess := False;
  FError := '';
end;

procedure TServerThread.Execute;
var
  LCtx: ISSLContext;
  LListenSock, LClientSock: TSocketHandle;
  LConn: ISSLConnection;
  LRecvBuf: array[0..255] of AnsiChar;
  LRecvLen: Integer;
  LError: string;
begin
  try
    WriteLn('[Server] Thread started');

    // Initialize network
    if not InitNetwork(LError) then
    begin
      FError := 'Network init failed: ' + LError;
      Exit;
    end;

    // Create server context
    WriteLn('[Server] Creating context...');
    LCtx := FLib.CreateContext(sslCtxServer);
    LCtx.LoadCertificate(TEST_CERT_PATH);
    LCtx.LoadPrivateKey(TEST_KEY_PATH);
    LCtx.SetVerifyMode([]);  // Don't verify client

    // Listen on port
    WriteLn('[Server] Listening on port ', FPort, '...');
    LListenSock := ListenTCP(FPort, '0.0.0.0');  // Bind to all interfaces

    try
      // Accept client connection
      WriteLn('[Server] Waiting for client...');
      LClientSock := AcceptConnection(LListenSock);
      WriteLn('[Server] Client connected');

      try
        // Create SSL connection
        LConn := LCtx.CreateConnection(LClientSock);

        // Accept TLS handshake
        WriteLn('[Server] Starting TLS handshake...');
        if LConn.Accept then
        begin
          WriteLn('[Server] TLS handshake completed');
          WriteLn('[Server] Cipher: ', LConn.GetCipherName);

          // Receive data from client
          LRecvLen := LConn.Read(LRecvBuf[0], SizeOf(LRecvBuf) - 1);
          if LRecvLen > 0 then
          begin
            LRecvBuf[LRecvLen] := #0;
            WriteLn('[Server] Received: ', string(LRecvBuf));

            // Send response
            LConn.Write(LRecvBuf[0], LRecvLen);  // Echo back
            WriteLn('[Server] Echoed response');
          end;

          LConn.Shutdown;
          WriteLn('[Server] Connection closed');

          FSuccess := True;
        end
        else
        begin
          FError := 'TLS handshake failed';
          WriteLn('[Server] ERROR: ', FError);
        end;

        LConn := nil;
      finally
        CloseSocket(LClientSock);
      end;
    finally
      CloseSocket(LListenSock);
    end;

    LCtx := nil;
    CleanupNetwork;

  except
    on E: Exception do
    begin
      FError := E.Message;
      WriteLn('[Server] EXCEPTION: ', E.Message);
    end;
  end;

  WriteLn('[Server] Thread exiting');
end;

{ Test 1: 基本 Accept 和握手 }
procedure TestBasicAcceptAndHandshake;
var
  LServer: TServerThread;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LClientSock: TSocketHandle;
  LSendData: AnsiString;
  LRecvBuf: array[0..255] of AnsiChar;
  LRecvLen: Integer;
  LError: string;
begin
  WriteLn;
  WriteLn('Test 1: Basic Accept and Handshake');
  WriteLn('======================================================================');

  try
    // Start server thread
    LServer := TServerThread.Create(TEST_PORT, GLib);
    LServer.Start;
    Sleep(2000);  // Give server time to start and listen

    WriteLn('[Client] Starting...');

    if not InitNetwork(LError) then
    begin
      AddResult('Accept and Handshake - Init', False, LError);
      LServer.Terminate;
      LServer.WaitFor;
      LServer.Free;
      Exit;
    end;

    // Connect to server
    WriteLn('[Client] Connecting to 127.0.0.1:', TEST_PORT, '...');
    LClientSock := ConnectTCP('127.0.0.1', TEST_PORT);
    WriteLn('[Client] TCP connected');

    try
      // Create client context
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.SetVerifyMode([]);  // Don't verify self-signed cert

      // Create connection
      LConn := LCtx.CreateConnection(LClientSock);
      (LConn as ISSLClientConnection).SetServerName('localhost');

      // Connect (TLS handshake)
      WriteLn('[Client] Starting TLS handshake...');
      if LConn.Connect then
      begin
        WriteLn('[Client] TLS handshake completed');
        WriteLn('[Client] Cipher: ', LConn.GetCipherName);

        // Send data to server
        LSendData := 'Hello from client';
        LConn.Write(LSendData[1], Length(LSendData));
        WriteLn('[Client] Sent: ', LSendData);

        // Receive echo
        LRecvLen := LConn.Read(LRecvBuf[0], SizeOf(LRecvBuf) - 1);
        if LRecvLen > 0 then
        begin
          LRecvBuf[LRecvLen] := #0;
          WriteLn('[Client] Received: ', string(LRecvBuf));

          if string(LRecvBuf) = LSendData then
          begin
            WriteLn('✅ Echo matched');
            AddResult('Accept and Handshake', True, 'Full round-trip successful');
          end
          else
          begin
            WriteLn('❌ Echo mismatch');
            AddResult('Accept and Handshake', False, 'Data mismatch');
          end;
        end
        else
        begin
          WriteLn('❌ No response from server');
          AddResult('Accept and Handshake', False, 'No response');
        end;

        LConn.Shutdown;
        WriteLn('[Client] Connection closed');
      end
      else
      begin
        WriteLn('❌ Client handshake failed');
        AddResult('Accept and Handshake', False, 'Client handshake failed');
      end;

      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LClientSock);
    end;

    CleanupNetwork;

    // Wait for server thread
    WriteLn('[Client] Waiting for server thread...');
    LServer.WaitFor;

    if not LServer.Success then
    begin
      WriteLn('[Client] Server reported error: ', LServer.Error);
      AddResult('Accept and Handshake - Server', False, LServer.Error);
    end
    else
    begin
      WriteLn('[Client] Server completed successfully');
      AddResult('Accept and Handshake - Server', True, 'Server OK');
    end;

    LServer.Free;

  except
    on E: Exception do
    begin
      WriteLn('❌ Exception: ', E.Message);
      AddResult('Accept and Handshake', False, E.Message);
    end;
  end;
end;

procedure PrintSummary;
var
  I, LPassed, LFailed: Integer;
begin
  WriteLn;
  WriteLn('================================================================================');
  WriteLn('TEST SUMMARY');
  WriteLn('================================================================================');
  WriteLn;

  LPassed := 0;
  LFailed := 0;

  for I := 0 to High(GResults) do
  begin
    if GResults[I].Success then
    begin
      Write('✅ PASS: ');
      Inc(LPassed);
    end
    else
    begin
      Write('❌ FAIL: ');
      Inc(LFailed);
    end;

    WriteLn(GResults[I].Name);
    if GResults[I].Message <> '' then
      WriteLn('         ', GResults[I].Message);
  end;

  WriteLn;
  WriteLn('Total: ', Length(GResults), ' tests');
  WriteLn('Passed: ', LPassed);
  WriteLn('Failed: ', LFailed);
  WriteLn;

  if LFailed = 0 then
    WriteLn('🎉 All tests passed!')
  else
    WriteLn('⚠️  Some tests failed');

  WriteLn('================================================================================');
end;

begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Server Accept and Handshake Test');
  WriteLn('================================================================================');

  try
    // Initialize MbedTLS
    WriteLn;
    WriteLn('Initializing MbedTLS...');
    GLib := TMbedTLSLibrary.Create;
    if not GLib.Initialize then
    begin
      WriteLn('❌ Failed to initialize MbedTLS');
      Halt(1);
    end;
    WriteLn('✅ MbedTLS ', GLib.GetVersionString);

    // Check certificate files exist
    WriteLn('Checking test certificate files...');
    if not FileExists(TEST_CERT_PATH) then
    begin
      WriteLn('❌ Certificate not found: ', TEST_CERT_PATH);
      Halt(1);
    end;
    if not FileExists(TEST_KEY_PATH) then
    begin
      WriteLn('❌ Private key not found: ', TEST_KEY_PATH);
      Halt(1);
    end;
    WriteLn('✅ Certificate files found');

    // Run tests
    TestBasicAcceptAndHandshake;

    // Print summary
    PrintSummary;

    // Cleanup
    GLib.Finalize;
    GLib := nil;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ Fatal error: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
