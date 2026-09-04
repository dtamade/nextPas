program test_freepascal_tls13_server;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.thread.init, nextpas.core.platform.socket,
  nextpas.core.system.sysutils, nextpas.core.system.classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

type
  TServerThread = class(TThread)
  private
    FListenSock: TPlatformSocket;
    FClientSock: TPlatformSocket;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
    FConn: ISSLConnection;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
    property Conn: ISSLConnection read FConn;
    property ClientSock: TPlatformSocket read FClientSock;
  end;

constructor TServerThread.Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
begin
  inherited Create(True);
  FListenSock := AListenSock;
  FContext := AContext;
  FSuccess := False;
  FClientSock := PLATFORM_INVALID_SOCKET;
  FreeOnTerminate := False;
end;

procedure TServerThread.Execute;
var
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LErr: Int32;
begin
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  LErr := platform_socket_accept(FListenSock, @LAddr.Storage[0], @LAddrLen,
    FClientSock);
  if LErr <> 0 then
  begin
    FError := 'accept() failed: ' + IntToStr(LErr);
    Exit;
  end;
  FConn := FContext.CreateConnection(THandle(FClientSock.Value));
  if FConn.Accept then
    FSuccess := True
  else
    FError := 'TLS Accept failed';
end;

function CreateListenSocket(APort: Word): TPlatformSocket;
var
  LAddr: TPlatformSockAddr;
  LOptVal: LongInt;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
    Exit(PLATFORM_INVALID_SOCKET);
  LOptVal := 1;
  platform_socket_setsockopt(Result, PLATFORM_SOL_SOCKET,
    PLATFORM_SO_REUSEADDR, @LOptVal, SizeOf(LOptVal));
  platform_sockaddr_loopback4(APort, LAddr);
  if platform_socket_bind(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(Result);
    Exit(PLATFORM_INVALID_SOCKET);
  end;
  if platform_socket_listen(Result, 5) <> 0 then
  begin
    platform_socket_close(Result);
    Exit(PLATFORM_INVALID_SOCKET);
  end;
end;

function ConnectTo(APort: Word): TPlatformSocket;
var LAddr: TPlatformSockAddr;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    Result) <> 0 then
    Exit(PLATFORM_INVALID_SOCKET);
  platform_sockaddr_loopback4(APort, LAddr);
  if platform_socket_connect(Result, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(Result);
    Exit(PLATFORM_INVALID_SOCKET);
  end;
end;

var
  LLib: ISSLLibrary;
  LServerCtx, LClientCtx: ISSLContext;
  LClientConn: ISSLConnection;
  LSession: ISSLSession;
  LListenSock, LClientSock: TPlatformSocket;
  LServerThread: TServerThread;
  LPort: Word;
  LTmpSock: TPlatformSocket;
begin
  LTotal := 0;
  LPassed := 0;
  LPort := 44499;
  WriteLn('=== TLS 1.3 Server Accept Test ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LServerCtx := LLib.CreateContext(sslCtxServer);
  LServerCtx.SetProtocolVersions([sslProtocolTLS13]);
  LServerCtx.SetSessionCacheMode(True);
  LServerCtx.LoadCertificate('tests/certs/server-cert.pem');
  LServerCtx.LoadPrivateKey('tests/certs/server-key.pem');

  LClientCtx := LLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS13]);
  LClientCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  Check(LListenSock.IsValid, 'Listen socket created');

  // TLS 1.3 full handshake
  WriteLn('--- TLS 1.3 Full Handshake ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client TCP connected');
  LClientConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  Check(LClientConn.Connect, 'TLS 1.3 handshake succeeded');

  // Client-side verification
  Check(LClientConn.GetProtocolVersion = sslProtocolTLS13, 'Client: protocol = TLS13');
  Check(LClientConn.GetCipherName <> '', 'Client: cipher = ' + LClientConn.GetCipherName);
  Check(LClientConn.GetPeerCertificate <> nil, 'Client: peer cert not nil');

  // Session ticket
  LSession := LClientConn.GetSession;
  if LSession <> nil then
  begin
    Check(True, 'Client: session ticket received');
    Check(LSession.GetProtocolVersion = sslProtocolTLS13, 'Session: protocol = TLS13');
    Check(LSession.IsResumable, 'Session: is resumable');
  end
  else
    Check(True, 'Client: no session ticket (acceptable)');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server: Accept succeeded');

  // Server-side verification
  Check(LServerThread.Conn.GetProtocolVersion = sslProtocolTLS13, 'Server: protocol = TLS13');
  Check(LServerThread.Conn.GetCipherName <> '', 'Server: cipher = ' + LServerThread.Conn.GetCipherName);
  Check(LServerThread.Conn.GetState <> '', 'Server: state not empty');

  // Cleanup
  LClientConn.Shutdown;
  LClientConn := nil;
  LServerThread.Conn.Shutdown;
  LTmpSock := LServerThread.ClientSock;
  platform_socket_close(LTmpSock);
  LServerThread.Free;
  LSession := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  platform_socket_close(LClientSock);
  platform_socket_close(LListenSock);

  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 Server test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
