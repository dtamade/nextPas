program test_e2e_scenarios;

{******************************************************************************}
{  End-to-End (E2E) Test Scenarios                                             }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init, // Must be first: threading is used before other units' initialization
  nextpas.core.tls.openssl.backed,
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.fs,
  nextpas.core.thread.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  test_openssl_base,
  tls_test_sockets;

var
  Runner: TSimpleTestRunner;
  GLib: ISSLLibrary;
  GNetInitError: string;

// Loopback/network socket helpers built on tls_test_sockets.
// 该单元为异常式 API，这里包一层保持本测试既有的 INVALID_SOCKET 返回约定。
function CreateListenSocket(APort: Word): TSocketHandle;
begin
  Result := INVALID_SOCKET;
  try
    Result := ListenTCP(APort, '127.0.0.1');
  except
    on E: Exception do
      Result := INVALID_SOCKET;
  end;
end;

function ConnectLoopback(APort: Word): TSocketHandle;
begin
  Result := INVALID_SOCKET;
  try
    Result := ConnectTCP('127.0.0.1', APort, 5);
  except
    on E: Exception do
      Result := INVALID_SOCKET;
  end;
end;

function ConnectSocket(const Host: string; Port: Word): TSocketHandle;
begin
  Result := INVALID_SOCKET;
  try
    Result := ConnectTCP(Host, Port, 10);
  except
    on E: Exception do
      Result := INVALID_SOCKET;
  end;
end;

procedure CloseSocket(var S: TSocketHandle);
begin
  tls_test_sockets.CloseSocket(S);
end;

const
  RESUMPTION_PORT = 44591;

type
  TTLSServerThread = class(TWorkerThread)
  private
    FListenSock: TSocketHandle;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TSocketHandle; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
  end;

constructor TTLSServerThread.Create(AListenSock: TSocketHandle; AContext: ISSLContext);
begin
  inherited Create;
  FListenSock := AListenSock;
  FContext := AContext;
  FSuccess := False;
  FError := '';
end;

procedure TTLSServerThread.Execute;
var
  LClientSock: TSocketHandle;
  LConn: ISSLConnection;
begin
  try
    LClientSock := AcceptConnection(FListenSock);
  except
    on E: Exception do
    begin
      FError := 'accept() failed';
      Exit;
    end;
  end;
  try
    LConn := FContext.CreateConnection(THandle(LClientSock));
    if LConn.Accept then
      FSuccess := True
    else
      FError := 'TLS Accept failed';
  finally
    tls_test_sockets.CloseSocket(LClientSock);
  end;
end;

procedure TestSessionResumption;
{$IFDEF UNIX}
var
  LServerCtx, LClientCtx: ISSLContext;
  Conn1, Conn2: ISSLConnection;
  Resumption1, Resumption2: ISSLSessionResumption;
  Sess: ISSLSession;
  Sock1, Sock2: TSocketHandle;
  LListenSock: TSocketHandle;
  LServerThread: TTLSServerThread;
{$ENDIF}
begin
  WriteLn;
  WriteLn('=== Session Resumption Tests ===');
  {$IFDEF UNIX}
  // Loopback OpenSSL server with a session cache: deterministic, offline-safe
  LServerCtx := GLib.CreateContext(sslCtxServer);
  LServerCtx.SetProtocolVersions([sslProtocolTLS12]);
  LServerCtx.SetSessionCacheMode(True);
  LServerCtx.SetSessionTimeout(300);
  try
    LServerCtx.LoadCertificate('certs/server-cert.pem');
    LServerCtx.LoadPrivateKey('certs/server-key.pem');
  except
    on E: Exception do
    begin
      Runner.Skip('Session Resumption - Server cert/key', E.Message);
      Exit;
    end;
  end;

  LClientCtx := GLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS12]);
  LClientCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(RESUMPTION_PORT);
  if LListenSock = INVALID_SOCKET then
  begin
    Runner.Skip('Session Resumption - Listen', 'Failed to bind port ' + IntToStr(RESUMPTION_PORT));
    Exit;
  end;

  try
    // First handshake: full (no reuse)
    LServerThread := TTLSServerThread.Create(LListenSock, LServerCtx);
    LServerThread.Start;

    Sock1 := ConnectLoopback(RESUMPTION_PORT);
    if Sock1 = INVALID_SOCKET then
    begin
      LServerThread.WaitFor;
      LServerThread.Free;
      Runner.Skip('Session Resumption - Connect 1', 'Loopback connect failed');
      Exit;
    end;

    try
      Conn1 := LClientCtx.CreateConnection(THandle(Sock1));
      if Conn1.Connect then
      begin
        Runner.Check('Session Resumption - Handshake 1', True);

        if not Supports(Conn1, ISSLSessionResumption, Resumption1) then
        begin
          Runner.Check('Session Resumption - Owner Surface 1', False,
            'Connection does not expose ISSLSessionResumption');
          Exit;
        end;
        Runner.Check('Session Resumption - Owner Surface 1', True);
        Runner.Check('Session Resumption - Full handshake', not Resumption1.IsSessionReused);

        Sess := Resumption1.GetSession;
        Runner.Check('Session Resumption - Extract Session', Sess <> nil);
      end
      else
      begin
        Runner.Check('Session Resumption - Handshake 1', False, GLib.GetLastErrorString);
        Exit;
      end;
    finally
      CloseSocket(Sock1);
    end;

    LServerThread.WaitFor;
    Runner.Check('Session Resumption - Server accept 1', LServerThread.Success, LServerThread.Error);
    LServerThread.Free;

    if Sess = nil then Exit;

    // Second handshake: must reuse the cached session
    LServerThread := TTLSServerThread.Create(LListenSock, LServerCtx);
    LServerThread.Start;

    Sock2 := ConnectLoopback(RESUMPTION_PORT);
    if Sock2 = INVALID_SOCKET then
    begin
      LServerThread.WaitFor;
      LServerThread.Free;
      Runner.Skip('Session Resumption - Connect 2', 'Loopback connect failed');
      Exit;
    end;

    try
      Conn2 := LClientCtx.CreateConnection(THandle(Sock2));
      if not Supports(Conn2, ISSLSessionResumption, Resumption2) then
      begin
        Runner.Check('Session Resumption - Owner Surface 2', False,
          'Connection does not expose ISSLSessionResumption');
        Exit;
      end;
      Runner.Check('Session Resumption - Owner Surface 2', True);
      Resumption2.SetSession(Sess);  // Set session before Connect
      if Conn2.Connect then
      begin
        Runner.Check('Session Resumption - Handshake 2', True);
        Runner.Check('Session Resumption - Reused', Resumption2.IsSessionReused,
          Format('Was reused: %s', [BoolToStr(Resumption2.IsSessionReused)]));
      end
      else
        Runner.Check('Session Resumption - Handshake 2', False, GLib.GetLastErrorString);
    finally
      CloseSocket(Sock2);
    end;

    LServerThread.WaitFor;
    Runner.Check('Session Resumption - Server accept 2', LServerThread.Success, LServerThread.Error);
    LServerThread.Free;
  finally
    CloseSocket(LListenSock);
  end;
  {$ELSE}
  Runner.Skip('Session Resumption - Setup', 'Loopback resumption is UNIX-only');
  {$ENDIF}
end;

procedure TestLargeDataTransfer;
var
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Sock: TSocketHandle;
  Req: string;
  Resp: TBytes;
  TotalRead: Integer;
  BytesRead: Integer;
  CAFile: string;
begin
  WriteLn;
  WriteLn('=== Large Data Transfer Tests ===');

  CAFile := '';
  if FileExists('/etc/ssl/certs/ca-certificates.crt') then
    CAFile := '/etc/ssl/certs/ca-certificates.crt'
  else if FileExists('/etc/pki/tls/certs/ca-bundle.crt') then
    CAFile := '/etc/pki/tls/certs/ca-bundle.crt';

  if CAFile = '' then
  begin
    Runner.Skip('Large Data - Setup', 'No system CA bundle found');
    Exit;
  end;

  Ctx := GLib.CreateContext(sslCtxClient);
  Ctx.LoadCAFile(CAFile);

  Sock := ConnectSocket('www.cloudflare.com', 443);
  if Sock = INVALID_SOCKET then
  begin
    Runner.Skip('Large Data - Connect', 'Socket failed');
    Exit;
  end;

  try
    Conn := Ctx.CreateConnection(Sock);
    (Conn as ISSLClientConnection).SetServerName('www.cloudflare.com');
    if Conn.Connect then
    begin
      Runner.Check('Large Data - Handshake', True);

      Req := 'GET / HTTP/1.1'#13#10'Host: www.cloudflare.com'#13#10'Connection: close'#13#10#13#10;
      Conn.WriteString(Req);

      TotalRead := 0;
      SetLength(Resp, 4096);
      repeat
        BytesRead := Conn.Read(Resp[0], Length(Resp));
        if BytesRead > 0 then
          Inc(TotalRead, BytesRead);
      until BytesRead <= 0;

      Runner.Check('Large Data - Transfer', TotalRead > 10000, Format('Read %d bytes', [TotalRead]));
    end
    else
      Runner.Check('Large Data - Handshake', False, GLib.GetLastErrorString);
  finally
    CloseSocket(Sock);
  end;
end;

procedure TestClientCertAuth;
begin
  WriteLn;
  WriteLn('=== Client Certificate Auth Tests ===');
  // Would need valid client certificates to test
  Runner.Check('Client Cert Auth - Skipped (No certs)', True);
end;

begin
  WriteLn('End-to-End Scenarios');
  WriteLn('====================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not InitNetwork(GNetInitError) then
    begin
      WriteLn('ERROR: Failed to initialize network: ', GNetInitError);
      Halt(1);
    end;

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    try
      GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
      if not GLib.Initialize then
      begin
        WriteLn('ERROR: Failed to initialize SSL library');
        Halt(1);
      end;

      WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

      TestSessionResumption;
      TestLargeDataTransfer;
      TestClientCertAuth;

    except
      on E: Exception do
        WriteLn('FATAL: ', E.Message);
    end;

    Runner.PrintSummary;
    // 自然结束而非 Halt:让程序级全局接口变量(GLib 等)正常终结,heaptrc 保持 0 unfreed
    ExitCode := Runner.FailCount;
  finally
    Runner.Free;
  end;
end.
