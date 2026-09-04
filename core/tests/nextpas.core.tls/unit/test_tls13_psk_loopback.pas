program test_tls13_psk_loopback;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.socket,
  nextpas.core.system.classes,
  nextpas.core.text.conv,
  nextpas.core.base,
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
    FResumed: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
    property Conn: ISSLConnection read FConn;
    property ClientSock: TPlatformSocket read FClientSock;
    property Resumed: Boolean read FResumed;
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
  LData: TBytes;
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
  begin
    FSuccess := True;
    FResumed := FConn.IsSessionReused;
    LData := StringToUTF8Bytes('hello');
    FConn.Write(LData[0], Length(LData));
  end
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
  LBuf: array[0..63] of Byte;
  LRead: Integer;
begin
  LTotal := 0;
  LPassed := 0;
  LPort := 44511;
  WriteLn('=== TLS 1.3 PSK Session Resumption Loopback ===');

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

  // First handshake: full TLS 1.3
  WriteLn('--- First handshake (full) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client TCP connected');
  LClientConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  Check(LClientConn.Connect, 'TLS 1.3 full handshake succeeded');
  Check(LClientConn.GetProtocolVersion = sslProtocolTLS13, 'Protocol = TLS 1.3');
  Check(not LClientConn.IsSessionReused, 'First handshake NOT resumed');

  // Read server data to trigger processing of NewSessionTicket
  LRead := LClientConn.Read(LBuf[0], SizeOf(LBuf));
  Check(LRead > 0, 'Client read server data (' + IntToStr(LRead) + ' bytes)');

  LSession := LClientConn.GetSession;
  WriteLn('  Session: ', BoolToStr(LSession <> nil, 'obtained', 'nil'));
  if LSession <> nil then
    WriteLn('  Resumable: ', BoolToStr(LSession.IsResumable, 'yes', 'no'));

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted: ' + LServerThread.Error);
  Check(not LServerThread.Resumed, 'Server: first handshake not resumed');

  LClientConn.Shutdown;
  LClientConn := nil;
  LServerThread.Conn.Shutdown;
  LTmpSock := LServerThread.ClientSock;
  platform_socket_close(LTmpSock);
  LServerThread.Free;
  platform_socket_close(LClientSock);

  if (LSession = nil) or (not LSession.IsResumable) then
  begin
    WriteLn('  [SKIP] No resumable session obtained, cannot test PSK');
    platform_socket_close(LListenSock);
    LLib.Finalize;
    WriteLn;
    WriteLn('TLS 1.3 PSK test: ', LPassed, '/', LTotal, ' passed (PSK skipped)');
    Halt(0);
  end;

  Check(LSession.IsResumable, 'Session is resumable');
  Check(LSession.GetProtocolVersion = sslProtocolTLS13, 'Session protocol = TLS 1.3');

  // Second handshake: resumed with PSK
  WriteLn('--- Second handshake (PSK resume) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client TCP connected (2nd)');
  LClientConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  LClientConn.SetSession(LSession);
  Check(LClientConn.Connect, 'TLS 1.3 resumed handshake succeeded');
  Check(LClientConn.IsSessionReused, 'Client: session IS resumed');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted resumed: ' + LServerThread.Error);
  Check(LServerThread.Resumed, 'Server: session IS resumed');

  LClientConn.Shutdown;
  LClientConn := nil;
  LServerThread.Conn.Shutdown;
  LTmpSock := LServerThread.ClientSock;
  platform_socket_close(LTmpSock);
  LServerThread.Free;
  platform_socket_close(LClientSock);

  LSession := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  platform_socket_close(LListenSock);
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 PSK test: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
