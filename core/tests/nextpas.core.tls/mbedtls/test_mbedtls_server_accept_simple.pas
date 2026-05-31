program test_mbedtls_server_accept_simple;

{$mode ObjFPC}{$H+}
{$DEFINE USE_CTHREADS}

{
  MbedTLS Server Accept Test - Simplified with Debug Output

  简化版测试，专注于调试握手问题
}

uses
  {$IFDEF UNIX}
  CThreads,
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.connection,
  fafafa.examples.tcp;

var
  GLib: ISSLLibrary;

const
  TEST_CERT_PATH = 'tests/certs/server-cert.pem';
  TEST_KEY_PATH = 'tests/certs/server-key.pem';
  TEST_PORT = 18443;

{ 服务端线程 }
type
  TServerThread = class(TThread)
  private
    FPort: Word;
    FLib: ISSLLibrary;
  protected
    procedure Execute; override;
  public
    constructor Create(APort: Word; ALib: ISSLLibrary);
  end;

constructor TServerThread.Create(APort: Word; ALib: ISSLLibrary);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPort := APort;
  FLib := ALib;
end;

procedure TServerThread.Execute;
var
  LCtx: ISSLContext;
  LListenSock, LClientSock: TSocketHandle;
  LConn: ISSLConnection;
  LMbedConn: TMbedTLSConnection;
  LState: TSSLHandshakeState;
  LError: string;
  LRetry: Integer;
begin
  try
    WriteLn('[Server] Thread started');

    if not InitNetwork(LError) then
    begin
      WriteLn('[Server] ERROR: Network init failed: ', LError);
      Exit;
    end;

    // Create server context
    WriteLn('[Server] Creating context...');
    LCtx := FLib.CreateContext(sslCtxServer);

    WriteLn('[Server] Keeping shipped cipher baseline...');
    LCtx.SetCipherList(SSL_DEFAULT_CIPHER_LIST);
    WriteLn('[Server] ✅ Shipped cipher baseline kept');

    WriteLn('[Server] Loading certificate...');
    LCtx.LoadCertificate(TEST_CERT_PATH);
    WriteLn('[Server] ✅ Certificate loaded');

    WriteLn('[Server] Loading private key...');
    LCtx.LoadPrivateKey(TEST_KEY_PATH);
    WriteLn('[Server] ✅ Private key loaded');

    WriteLn('[Server] Loading CA bundle (for completeness)...');
    try
      LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
      WriteLn('[Server] ✅ CA bundle loaded');
    except
      on E: Exception do
        WriteLn('[Server] ⚠️  CA bundle load failed: ', E.Message);
    end;

    LCtx.SetVerifyMode([]);
    WriteLn('[Server] ✅ Context configured');

    // Listen
    WriteLn('[Server] Listening on port ', FPort, '...');
    LListenSock := ListenTCP(FPort, '0.0.0.0');

    try
      // Accept
      WriteLn('[Server] Waiting for client...');
      LClientSock := AcceptConnection(LListenSock);
      WriteLn('[Server] Client connected, socket=', LClientSock);

      try
        // Create SSL connection
        LConn := LCtx.CreateConnection(LClientSock);
        WriteLn('[Server] SSL connection created');

        // Try to get MbedTLS specific interface for debugging
        if LConn is TMbedTLSConnection then
        begin
          LMbedConn := TMbedTLSConnection(LConn as TObject);
          WriteLn('[Server] Got MbedTLS connection for debugging');
        end
        else
          LMbedConn := nil;

        // Attempt handshake with retries
        WriteLn('[Server] Starting TLS handshake...');
        LRetry := 0;
        repeat
          LState := LConn.DoHandshake;
          WriteLn('[Server] Handshake state: ', Ord(LState));

          if LMbedConn <> nil then
          begin
            WriteLn('[Server] Last error code: 0x', IntToHex(-LMbedConn.GetLastError, 4));
            WriteLn('[Server] Last error string: ', LMbedConn.GetLastErrorString);
          end;

          case LState of
            sslHsCompleted:
              begin
                WriteLn('[Server] ✅ Handshake completed!');
                WriteLn('[Server] Cipher: ', LConn.GetCipherName);
                WriteLn('[Server] Protocol: ', Ord(LConn.GetProtocolVersion));
                Break;
              end;
            sslHsFailed:
              begin
                WriteLn('[Server] ❌ Handshake failed!');
                Break;
              end;
            sslHsInProgress:
              begin
                WriteLn('[Server] ⏳ Handshake in progress, retry...');
                Sleep(100);
                Inc(LRetry);
              end;
          end;
        until (LState <> sslHsInProgress) or (LRetry > 10);

        if LConn.IsHandshakeComplete then
          WriteLn('[Server] ✅ Final check: Handshake complete')
        else
          WriteLn('[Server] ❌ Final check: Handshake NOT complete');

        LConn.Shutdown;
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
      WriteLn('[Server] EXCEPTION: ', E.ClassName, ': ', E.Message);
  end;

  WriteLn('[Server] Thread exiting');
end;

{ 主程序 - 客户端 }
var
  LServer: TServerThread;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LMbedConn: TMbedTLSConnection;
  LClientSock: TSocketHandle;
  LState: TSSLHandshakeState;
  LError: string;
  LRetry: Integer;

begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS Server Accept Test - Simplified with Debug');
  WriteLn('================================================================================');
  WriteLn;

  try
    // Initialize
    WriteLn('[Main] Initializing MbedTLS...');
    GLib := TMbedTLSLibrary.Create;
    if not GLib.Initialize then
    begin
      WriteLn('[Main] ❌ Failed to initialize MbedTLS');
      Halt(1);
    end;
    WriteLn('[Main] ✅ MbedTLS ', GLib.GetVersionString);

    // Check files
    if not FileExists(TEST_CERT_PATH) or not FileExists(TEST_KEY_PATH) then
    begin
      WriteLn('[Main] ❌ Certificate files not found');
      Halt(1);
    end;
    WriteLn('[Main] ✅ Certificate files found');
    WriteLn;

    // Start server
    WriteLn('[Main] Starting server thread...');
    LServer := TServerThread.Create(TEST_PORT, GLib);
    LServer.Start;
    Sleep(2000);
    WriteLn('[Main] Server should be listening now');
    WriteLn;

    // Client connect
    if not InitNetwork(LError) then
    begin
      WriteLn('[Client] ❌ Network init failed: ', LError);
      LServer.Terminate;
      LServer.WaitFor;
      LServer.Free;
      Halt(1);
    end;

    WriteLn('[Client] Connecting to 127.0.0.1:', TEST_PORT, '...');
    LClientSock := ConnectTCP('127.0.0.1', TEST_PORT);
    WriteLn('[Client] ✅ TCP connected, socket=', LClientSock);

    try
      // Create client context
      LCtx := GLib.CreateContext(sslCtxClient);
      LCtx.SetVerifyMode([]);  // Don't verify self-signed
      WriteLn('[Client] Context configured');

      // Create connection
      LConn := LCtx.CreateConnection(LClientSock);
      (LConn as ISSLClientConnection).SetServerName('localhost');
      WriteLn('[Client] SSL connection created');

      // Get MbedTLS specific interface
      if LConn is TMbedTLSConnection then
      begin
        LMbedConn := TMbedTLSConnection(LConn as TObject);
        WriteLn('[Client] Got MbedTLS connection for debugging');
      end
      else
        LMbedConn := nil;

      // Attempt handshake
      WriteLn('[Client] Starting TLS handshake...');
      LRetry := 0;
      repeat
        LState := LConn.DoHandshake;
        WriteLn('[Client] Handshake state: ', Ord(LState));

        if LMbedConn <> nil then
        begin
          WriteLn('[Client] Last error code: 0x', IntToHex(-LMbedConn.GetLastError, 4));
          WriteLn('[Client] Last error string: ', LMbedConn.GetLastErrorString);
        end;

        case LState of
          sslHsCompleted:
            begin
              WriteLn('[Client] ✅ Handshake completed!');
              WriteLn('[Client] Cipher: ', LConn.GetCipherName);
              WriteLn('[Client] Protocol: ', Ord(LConn.GetProtocolVersion));
              Break;
            end;
          sslHsFailed:
            begin
              WriteLn('[Client] ❌ Handshake failed!');
              Break;
            end;
          sslHsInProgress:
            begin
              WriteLn('[Client] ⏳ Handshake in progress, retry...');
              Sleep(100);
              Inc(LRetry);
            end;
        end;
      until (LState <> sslHsInProgress) or (LRetry > 10);

      if LConn.IsHandshakeComplete then
        WriteLn('[Client] ✅ Final check: Handshake complete')
      else
        WriteLn('[Client] ❌ Final check: Handshake NOT complete');

      LConn.Shutdown;
      LConn := nil;
      LCtx := nil;
    finally
      CloseSocket(LClientSock);
    end;

    CleanupNetwork;

    // Wait for server
    WriteLn;
    WriteLn('[Main] Waiting for server thread...');
    LServer.WaitFor;
    LServer.Free;

    // Cleanup
    GLib.Finalize;
    GLib := nil;

    WriteLn;
    WriteLn('================================================================================');
    WriteLn('Test completed');
    WriteLn('================================================================================');

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('[Main] ❌ Fatal: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
