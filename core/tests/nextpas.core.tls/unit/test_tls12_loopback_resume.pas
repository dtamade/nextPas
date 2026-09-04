program test_tls12_loopback_resume;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.socket,
  nextpas.core.thread.base,
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then begin Inc(LPassed); WriteLn('  PASS: ', AName); end
  else begin WriteLn('  FAIL: ', AName); Halt(1); end;
end;

type
  TServerThread = class(TWorkerThread)
  private
    FListenSock: TPlatformSocket;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
    FCipherName: string;
    FEchoData: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
    property CipherName: string read FCipherName;
  end;

constructor TServerThread.Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
begin
  inherited Create;
  FListenSock := AListenSock;
  FContext := AContext;
  FSuccess := False;
end;

procedure TServerThread.Execute;
var
  LConn: ISSLConnection;
  LClientSock: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LErr: Int32;
begin
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  LErr := platform_socket_accept(FListenSock, @LAddr.Storage[0], @LAddrLen,
    LClientSock);
  if LErr <> 0 then
  begin
    FError := 'accept() failed: ' + IntToStr(LErr);
    Exit;
  end;
  try
    LConn := FContext.CreateConnection(THandle(LClientSock.Value));
    if LConn.Accept then
    begin
      FSuccess := True;
      FCipherName := LConn.GetCipherName;
    end
    else
      FError := 'TLS Accept failed';
  finally
    platform_socket_close(LClientSock);
  end;
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
  LServerCtx, LClientCtx: ISSLContext;
  LLib: ISSLLibrary;
  LConn: ISSLConnection;
  LSession: ISSLSession;
  LResponse: string;
  LListenSock, LClientSock: TPlatformSocket;
  LServerThread: TServerThread;
  LPort: Word;
begin
  LTotal := 0;
  LPassed := 0;
  LPort := 44477;
  WriteLn('=== TLS 1.2 Loopback Session Resumption ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LServerCtx := LLib.CreateContext(sslCtxServer);
  LServerCtx.SetProtocolVersions([sslProtocolTLS12]);
  LServerCtx.SetSessionCacheMode(True);
  LServerCtx.LoadCertificate('tests/certs/server-cert.pem');
  LServerCtx.LoadPrivateKey('tests/certs/server-key.pem');

  LClientCtx := LLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS12]);
  LClientCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  Check(LListenSock.IsValid, 'Listen socket created on port ' + IntToStr(LPort));

  // First handshake: full
  WriteLn('--- First handshake (full) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client connected');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  Check(LConn.Connect, 'TLS handshake succeeded');
  Check(LConn.GetProtocolVersion = sslProtocolTLS12, 'Protocol is TLS 1.2');
  Check(LConn.GetCipherName <> '', 'Cipher: ' + LConn.GetCipherName);
  Check(not LConn.IsSessionReused, 'First handshake NOT resumed');

  LSession := LConn.GetSession;
  Check(LSession <> nil, 'Session obtained');
  Check(LSession.IsResumable, 'Session is resumable');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted: ' + LServerThread.Error);
  LServerThread.Free;
  platform_socket_close(LClientSock);

  // Second handshake: resumed
  WriteLn('--- Second handshake (resumed) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client connected (2nd)');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  LConn.SetSession(LSession);
  Check(LConn.Connect, 'TLS resumed handshake succeeded');
  Check(LConn.IsSessionReused, 'Second handshake IS resumed');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted resumed: ' + LServerThread.Error);
  LServerThread.Free;
  platform_socket_close(LClientSock);

  platform_socket_close(LListenSock);
  WriteLn;
  WriteLn('Results: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
