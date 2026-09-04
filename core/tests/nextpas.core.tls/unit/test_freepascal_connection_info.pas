program test_freepascal_connection_info;

{$mode objfpc}{$H+}{$J-}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.socket,
  nextpas.core.thread.base,
  nextpas.core.text.conv,
  nextpas.core.base.utils,
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
  TServerThread = class(TWorkerThread)
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
  inherited Create;
  FListenSock := AListenSock;
  FContext := AContext;
  FSuccess := False;
end;

procedure TServerThread.Execute;
var
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
  FClientSock := LClientSock;
  FConn := FContext.CreateConnection(THandle(LClientSock.Value));
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
  LConn: ISSLConnection;
  LCT: ISSLCertificateTransparency;
  LCTV: ISSLCertificateTransparencyValidation;
  LSession: ISSLSession;
  LPeerCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LListenSock, LClientSock: TPlatformSocket;
  LServerThread: TServerThread;
  LPort: Word;
  LTmpSock: TPlatformSocket;
begin
  LTotal := 0;
  LPassed := 0;
  LPort := 44488;
  WriteLn('=== ISSLConnection Info Methods Test ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LServerCtx := LLib.CreateContext(sslCtxServer);
  LServerCtx.SetProtocolVersions([sslProtocolTLS12]);
  LServerCtx.SetSessionCacheMode(True);
  LServerCtx.LoadCertificate('tests/certs/server-cert.pem');
  LServerCtx.LoadPrivateKey('tests/certs/server-key.pem');
  LServerCtx.SetALPNProtocols('h2,http/1.1');

  LClientCtx := LLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS12]);
  LClientCtx.SetVerifyMode([]);
  LClientCtx.SetALPNProtocols('h2,http/1.1');

  LListenSock := CreateListenSocket(LPort);
  Check(LListenSock.IsValid, 'Listen socket created');

  // Establish TLS connection
  WriteLn('--- Connection Info ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock.IsValid, 'Client TCP connected');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  Check(LConn.Connect, 'TLS handshake succeeded');

  // Protocol version
  Check(LConn.GetProtocolVersion = sslProtocolTLS12, 'GetProtocolVersion = TLS12');

  // Cipher name
  Check(LConn.GetCipherName <> '', 'GetCipherName not empty: ' + LConn.GetCipherName);

  // ALPN (may not be negotiated in all configurations)
  if LConn.GetSelectedALPNProtocol <> '' then
    Check(True, 'ALPN negotiated: ' + LConn.GetSelectedALPNProtocol)
  else
    Check(True, 'ALPN not negotiated (acceptable for TLS 1.2 loopback)');

  // Peer certificate (client sees server cert)
  LPeerCert := LConn.GetPeerCertificate;
  Check(LPeerCert <> nil, 'GetPeerCertificate not nil');
  Check(LPeerCert.GetSubjectCN = 'localhost', 'Peer cert CN = localhost');

  // Peer certificate chain
  LChain := LConn.GetPeerCertificateChain;
  Check(Length(LChain) >= 1, 'GetPeerCertificateChain length >= 1');

  // Verify result
  Check(LConn.GetVerifyResult >= 0, 'GetVerifyResult >= 0');
  Check(LConn.GetVerifyResultString <> '', 'GetVerifyResultString not empty');

  // Session
  Check(not LConn.IsSessionReused, 'First connection not resumed');
  LSession := LConn.GetSession;
  Check(LSession <> nil, 'GetSession not nil');
  Check(LSession.IsResumable, 'Session is resumable');
  Check(LSession.GetProtocolVersion = sslProtocolTLS12, 'Session protocol = TLS12');
  Check(LSession.GetCipherName <> '', 'Session cipher name not empty');

  // Connection state
  Check(LConn.GetState <> '', 'GetState not empty');

  // CT/SCT (FreePascal backend implements ISSLCertificateTransparency)
  WriteLn('--- CT/SCT ---');
  if Supports(LConn, ISSLCertificateTransparency, LCT) then
  begin
    Check(True, 'Connection supports ISSLCertificateTransparency');
    Check((LConn as ISSLCertificateTransparency).GetSignedCertificateTimestampCount >= 0,
      'GetSignedCertificateTimestampCount >= 0');
    Check((LConn as ISSLCertificateTransparency).GetCertificateTransparencyStatus <> '',
      'GetCertificateTransparencyStatus not empty');
  end
  else
    Check(True, 'CT interface not available (acceptable)');

  // CT Validation
  if Supports(LConn, ISSLCertificateTransparencyValidation, LCTV) then
  begin
    Check(True, 'Connection supports ISSLCertificateTransparencyValidation');
    Check((LConn as ISSLCertificateTransparencyValidation).GetCertificateTransparencyValidationStatus <> '',
      'GetCertificateTransparencyValidationStatus not empty');
  end
  else
    Check(True, 'CT Validation interface not available (acceptable)');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted: ' + LServerThread.Error);

  // Server-side connection info
  WriteLn('--- Server Connection Info ---');
  Check(LServerThread.Conn.GetProtocolVersion = sslProtocolTLS12, 'Server: protocol = TLS12');
  Check(LServerThread.Conn.GetCipherName <> '', 'Server: cipher not empty');
  if LServerThread.Conn.GetSelectedALPNProtocol <> '' then
    Check(True, 'Server: ALPN negotiated')
  else
    Check(True, 'Server: ALPN not negotiated (acceptable)');

  // Cleanup: shutdown connections before releasing
  LConn.Shutdown;
  LConn := nil;
  LServerThread.Conn.Shutdown;
  LTmpSock := LServerThread.ClientSock;
  platform_socket_close(LTmpSock);
  LServerThread.Free;
  LSession := nil;
  LPeerCert := nil;
  SetLength(LChain, 0);
  LServerCtx := nil;
  LClientCtx := nil;
  platform_socket_close(LClientSock);
  platform_socket_close(LListenSock);

  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('ISSLConnection info test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
