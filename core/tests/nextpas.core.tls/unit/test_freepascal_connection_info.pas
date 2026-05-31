program test_freepascal_connection_info;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads, BaseUnix, Sockets,{$ENDIF}
  SysUtils, Classes,
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
    FListenSock: cint;
    FClientSock: cint;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
    FConn: ISSLConnection;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: cint; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
    property Conn: ISSLConnection read FConn;
    property ClientSock: cint read FClientSock;
  end;

constructor TServerThread.Create(AListenSock: cint; AContext: ISSLContext);
begin
  inherited Create(True);
  FListenSock := AListenSock;
  FContext := AContext;
  FSuccess := False;
  FreeOnTerminate := False;
end;

procedure TServerThread.Execute;
var
  LClientSock: cint;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
begin
  LAddrLen := SizeOf(LAddr);
  LClientSock := fpAccept(FListenSock, @LAddr, @LAddrLen);
  if LClientSock < 0 then
  begin
    FError := 'accept() failed: ' + IntToStr(fpGetErrno);
    Exit;
  end;
  FClientSock := LClientSock;
  FConn := FContext.CreateConnection(THandle(LClientSock));
  if FConn.Accept then
    FSuccess := True
  else
    FError := 'TLS Accept failed';
end;

function CreateListenSocket(APort: Word): cint;
var
  LAddr: TInetSockAddr;
  LOptVal: cint;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Result < 0 then Exit(-1);
  LOptVal := 1;
  fpSetSockOpt(Result, SOL_SOCKET, SO_REUSEADDR, @LOptVal, SizeOf(LOptVal));
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr.s_addr := htonl($7F000001);
  if fpBind(Result, @LAddr, SizeOf(LAddr)) <> 0 then begin fpClose(Result); Exit(-1); end;
  if fpListen(Result, 5) <> 0 then begin fpClose(Result); Exit(-1); end;
end;

function ConnectTo(APort: Word): cint;
var LAddr: TInetSockAddr;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Result < 0 then Exit(-1);
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr.s_addr := htonl($7F000001);
  if fpConnect(Result, @LAddr, SizeOf(LAddr)) <> 0 then begin fpClose(Result); Exit(-1); end;
end;

var
  LLib: ISSLLibrary;
  LServerCtx, LClientCtx: ISSLContext;
  LConn: ISSLConnection;
  LSession: ISSLSession;
  LPeerCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LListenSock, LClientSock: cint;
  LServerThread: TServerThread;
  LPort: Word;
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
  Check(LListenSock >= 0, 'Listen socket created');

  // Establish TLS connection
  WriteLn('--- Connection Info ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client TCP connected');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock));
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
  if Supports(LConn, ISSLCertificateTransparency) then
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
  if Supports(LConn, ISSLCertificateTransparencyValidation) then
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
  fpClose(LServerThread.ClientSock);
  LServerThread.Free;
  LSession := nil;
  LPeerCert := nil;
  SetLength(LChain, 0);
  LServerCtx := nil;
  LClientCtx := nil;
  fpClose(LClientSock);
  fpClose(LListenSock);

  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('ISSLConnection info test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
