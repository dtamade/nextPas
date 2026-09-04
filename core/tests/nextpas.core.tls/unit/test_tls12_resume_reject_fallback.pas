program test_tls12_resume_reject_fallback;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.thread.init,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.thread.base,
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base,
  nextpas.core.io.intf,
  nextpas.core.fs,
  nextpas.core.tls.socket_stream,
  nextpas.core.tls.tls12.client,
  nextpas.core.tls.tls12.server,
  nextpas.core.tls.x509,
  nextpas.core.tls.pem;

type
  TTLS12ServerThread = class(TWorkerThread)
  private
    FListenSocket: TPlatformSocket;
    FPort: Word;
    FConfig: TTLS12ServerConfig;
    FState: TTLS12ServerState;
    FHandshakeOk: Boolean;
    FError: string;
    procedure BindAndListen;
    procedure LoadConfig;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    property Port: Word read FPort;
    property HandshakeOk: Boolean read FHandshakeOk;
    property HandshakeError: string read FError;
    property State: TTLS12ServerState read FState;
  end;

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

function LoadFileBytes(const APath: string): TBytes;
begin
  Result := ReadFile(APath);
end;

function LoadCertificateDER(const APath: string): TBytes;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
begin
  LReader := TPEMReader.Create;
  try
    LReader.LoadFromFile(APath);
    LBlocks := LReader.GetCertificates;
    if Length(LBlocks) = 0 then
      raise Exception.Create('No certificate found in ' + APath);
    Result := LBlocks[0].Data;
  finally
    LReader.Free;
  end;
end;

constructor TTLS12ServerThread.Create;
begin
  inherited Create;
  FListenSocket := PLATFORM_INVALID_SOCKET;
  FillChar(FState, SizeOf(FState), 0);
  FillChar(FConfig, SizeOf(FConfig), 0);
  LoadConfig;
  BindAndListen;
  Start;
end;

destructor TTLS12ServerThread.Destroy;
begin
  if FListenSocket.IsValid then
    platform_socket_close(FListenSocket);
  if Assigned(FConfig.Certificate) then
    FConfig.Certificate.Free;
  inherited Destroy;
end;

procedure TTLS12ServerThread.LoadConfig;
begin
  FConfig.CertificateDER := LoadCertificateDER('examples/localhost.crt');
  FConfig.PrivateKeyDER := LoadFileBytes('examples/localhost.key');
  FConfig.Certificate := TX509Certificate.Create;
  FConfig.Certificate.LoadFromDER(FConfig.CertificateDER);
  FConfig.ServerName := 'localhost';
  FConfig.SupportEMS := True;
  SetLength(FConfig.ALPNProtocols, 0);
  FConfig.RequestClientCert := False;
  FConfig.SNICallback := nil;
  SetLength(FConfig.CipherSuites, 0);
  SetLength(FConfig.SessionID, 0);
  FConfig.SessionCacheEnabled := True;
  FConfig.SessionLookup := nil;
end;

procedure TTLS12ServerThread.BindAndListen;
var
  LAddr: TPlatformSockAddr;
  LBound: TPlatformSockAddr;
  LBoundLen: Int32;
  LAddrIP: UInt32;
  LPort: UInt16;
begin
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    FListenSocket) <> 0 then
    raise Exception.Create('socket() failed');

  if platform_socket_set_reuseaddr(FListenSocket, True) <> 0 then
  begin
    platform_socket_close(FListenSocket);
    raise Exception.Create('setsockopt(SO_REUSEADDR) failed');
  end;

  platform_sockaddr_loopback4(0, LAddr);
  if platform_socket_bind(FListenSocket, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(FListenSocket);
    raise Exception.Create('bind() failed');
  end;
  if platform_socket_listen(FListenSocket, 1) <> 0 then
  begin
    platform_socket_close(FListenSocket);
    raise Exception.Create('listen() failed');
  end;

  LBound.Clear;
  LBoundLen := SizeOf(LBound.Storage);
  if platform_socket_getsockname(FListenSocket, @LBound.Storage[0],
    @LBoundLen) <> 0 then
  begin
    platform_socket_close(FListenSocket);
    raise Exception.Create('getsockname() failed');
  end;
  LBound.Len := LBoundLen;
  platform_sockaddr_ipv4_extract(LBound, LAddrIP, LPort);
  if LPort = 0 then
  begin
    platform_socket_close(FListenSocket);
    raise Exception.Create('getsockname() returned empty port');
  end;
  FPort := LPort;
end;

procedure TTLS12ServerThread.Execute;
var
  LClient: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LStream: IStream;
begin
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  LClient := PLATFORM_INVALID_SOCKET;
  if platform_socket_accept(FListenSocket, @LAddr.Storage[0], @LAddrLen,
    LClient) <> 0 then
  begin
    FError := 'accept() failed';
    Exit;
  end;

  LStream := SocketHandleAsIStream(THandle(LClient.Value));
  try
    FHandshakeOk := TryTLS12ServerHandshake(LStream, FConfig, FState, FError);
  finally
    LStream := nil;
    platform_socket_close(LClient);
  end;
end;

function ConnectLoopback(APort: Word; out ASock: TPlatformSocket;
  out AStream: IStream): Boolean;
var
  LAddr: TPlatformSockAddr;
begin
  ASock := PLATFORM_INVALID_SOCKET;
  AStream := nil;
  Result := False;
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    ASock) <> 0 then
    Exit;
  platform_sockaddr_loopback4(APort, LAddr);
  if platform_socket_connect(ASock, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    platform_socket_close(ASock);
    Exit;
  end;
  AStream := SocketHandleAsIStream(THandle(ASock.Value));
  Result := True;
end;

procedure CloseLoopback(var ASock: TPlatformSocket; var AStream: IStream);
begin
  AStream := nil;
  if ASock.IsValid then
    platform_socket_close(ASock);
end;

procedure WaitForServer(AThread: TTLS12ServerThread; const AStep: string);
begin
  AThread.WaitFor;
  Check(AThread.HandshakeOk, AStep + ' server handshake succeeded: ' + AThread.HandshakeError);
end;

procedure TestResumeRejectFallsBackToFullHandshake;
var
  LServer1, LServer2: TTLS12ServerThread;
  LSock: TPlatformSocket;
  LStream: IStream;
  LState1, LState2: TTLS12ClientState;
  LError: string;
  LProtos: array of string;
  LCache: TTLS12SessionCache;
  LInitialSessionID: TBytes;
begin
  WriteLn('TestResumeRejectFallsBackToFullHandshake');
  SetLength(LProtos, 0);

  LServer1 := TTLS12ServerThread.Create;
  try
    Check(ConnectLoopback(LServer1.Port, LSock, LStream),
      'TCP connect to initial server succeeds');
    try
      Check(TryTLS12ClientHandshake(LStream, 'localhost', LProtos, LState1, LError),
        'Initial full handshake succeeds: ' + LError);
      Check(not LState1.Resumed, 'Initial handshake is not resumed');
      Check(Length(LState1.SessionID) > 0, 'Initial handshake receives session ID');
      Check(Length(LState1.PeerCertificatesDER) > 0, 'Initial handshake receives certificate chain');
      LInitialSessionID := Copy(LState1.SessionID);
    finally
      CloseLoopback(LSock, LStream);
    end;

    WaitForServer(LServer1, 'Initial');
  finally
    LServer1.Free;
  end;

  LCache.SessionID := Copy(LState1.SessionID);
  LCache.MasterSecret := Copy(LState1.MasterSecret);
  LCache.CipherSuite := LState1.CipherSuite;
  LCache.ServerName := 'localhost';

  LServer2 := TTLS12ServerThread.Create;
  try
    Check(ConnectLoopback(LServer2.Port, LSock, LStream),
      'TCP connect to fallback server succeeds');
    try
      Check(TryTLS12ClientHandshakeWithResume(LStream, 'localhost', LProtos, LCache, LState2, LError),
        'Rejected resumption falls back to full handshake: ' + LError);
      Check(not LState2.Resumed, 'Fallback handshake is marked non-resumed');
      Check(Length(LState2.PeerCertificatesDER) > 0, 'Fallback handshake still reads certificate chain');
      Check(Length(LState2.MasterSecret) = 48, 'Fallback handshake derives full master secret');
      Check(Length(LState2.SessionID) > 0, 'Fallback handshake stores server session ID');
      Check((Length(LInitialSessionID) <> Length(LState2.SessionID)) or
        (not CompareMem(@LInitialSessionID[0], @LState2.SessionID[0], Length(LState2.SessionID))),
        'Fallback handshake accepts a new session ID');
    finally
      CloseLoopback(LSock, LStream);
    end;

    WaitForServer(LServer2, 'Fallback');
  finally
    LServer2.Free;
  end;

  if Assigned(LState1.PeerCertificate) then
    LState1.PeerCertificate.Free;
  if Assigned(LState2.PeerCertificate) then
    LState2.PeerCertificate.Free;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestResumeRejectFallsBackToFullHandshake;

  WriteLn;
  WriteLn('TLS12 resume reject fallback tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then
    Halt(1);
end.
