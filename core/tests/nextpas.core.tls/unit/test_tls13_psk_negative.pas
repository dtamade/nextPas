program test_tls13_psk_negative;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  nextpas.core.thread.init,
  nextpas.core.platform.socket,
  nextpas.core.system.classes,
  nextpas.core.base,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.freepascal.session;

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
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
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
  LConn: ISSLConnection;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  if platform_socket_accept(FListenSock, @LAddr.Storage[0], @LAddrLen,
    FClientSock) <> 0 then
  begin
    FError := 'accept failed';
    Exit;
  end;
  LConn := FContext.CreateConnection(THandle(FClientSock.Value));
  if LConn.Accept then
    FSuccess := True
  else
    FError := 'Accept failed (expected for bad binder)';
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

procedure TestBadSession;
var
  LLib: ISSLLibrary;
  LServerCtx, LClientCtx: ISSLContext;
  LConn: ISSLConnection;
  LBadSession: TFreePascalSession;
  LSession: ISSLSession;
  LListenSock, LClientSock: TPlatformSocket;
  LServerThread: TServerThread;
  LPort: Word;
  LFakePSK, LFakeTicket, LFakeNonce: TBytes;
begin
  WriteLn('TestBadSession - corrupted PSK should be rejected');
  LPort := 44580;

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
  Check(LListenSock.IsValid, 'Listen socket');

  // Create a fake session with garbage PSK
  SetLength(LFakePSK, 48);
  FillChar(LFakePSK[0], 48, $AA);
  SetLength(LFakeTicket, 32);
  FillChar(LFakeTicket[0], 32, $BB);
  SetLength(LFakeNonce, 8);
  FillChar(LFakeNonce[0], 8, 0);

  LBadSession := TFreePascalSession.Create;
  LBadSession.ConfigureResumption(
    $1302, 'TLS_AES_256_GCM_SHA384',
    LFakeNonce, LFakeTicket, LFakePSK,
    7200, 12345, DateTimeNow, 7200, 0
  );
  LSession := LBadSession;

  // Try to resume with bad session - server should reject
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client connected');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  LConn.SetSession(LSession);

  // Connect should either fail or fall back to full handshake
  if LConn.Connect then
    Check(not LConn.IsSessionReused, 'Bad PSK: fell back to full handshake (not resumed)')
  else
    Check(True, 'Bad PSK: handshake failed (server rejected)');

  LServerThread.WaitFor;
  LServerThread.Free;
  platform_socket_close(LClientSock);
  platform_socket_close(LListenSock);
  LSession := nil;
  LConn := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  LLib.Finalize;
  LLib := nil;
end;

procedure TestExpiredSession;
var
  LLib: ISSLLibrary;
  LClientCtx: ISSLContext;
  LBadSession: TFreePascalSession;
  LSession: ISSLSession;
  LFakePSK, LFakeTicket, LFakeNonce: TBytes;
begin
  WriteLn('TestExpiredSession - expired session should not be resumable');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LClientCtx := LLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS13]);

  SetLength(LFakePSK, 48);
  FillChar(LFakePSK[0], 48, $CC);
  SetLength(LFakeTicket, 32);
  FillChar(LFakeTicket[0], 32, $DD);
  SetLength(LFakeNonce, 8);
  FillChar(LFakeNonce[0], 8, 0);

  LBadSession := TFreePascalSession.Create;
  LBadSession.ConfigureResumption(
    $1302, 'TLS_AES_256_GCM_SHA384',
    LFakeNonce, LFakeTicket, LFakePSK,
    1, 0,
    DateTimeNow - 1, 1, 0
  );
  LSession := LBadSession;

  Check(not LSession.IsValid, 'Expired session is not valid');
  Check(not LSession.IsResumable, 'Expired session is not resumable');

  LSession := nil;
  LClientCtx := nil;
  LLib.Finalize;
  LLib := nil;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestExpiredSession;
  TestBadSession;

  WriteLn;
  WriteLn('TLS 1.3 PSK negative tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
