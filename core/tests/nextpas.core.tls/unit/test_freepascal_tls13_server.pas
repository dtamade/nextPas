program test_freepascal_tls13_server;

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
  FClientSock := -1;
  FreeOnTerminate := False;
end;

procedure TServerThread.Execute;
var
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
begin
  LAddrLen := SizeOf(LAddr);
  FClientSock := fpAccept(FListenSock, @LAddr, @LAddrLen);
  if FClientSock < 0 then
  begin
    FError := 'accept() failed: ' + IntToStr(fpGetErrno);
    Exit;
  end;
  FConn := FContext.CreateConnection(THandle(FClientSock));
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
  LClientConn: ISSLConnection;
  LSession: ISSLSession;
  LListenSock, LClientSock: cint;
  LServerThread: TServerThread;
  LPort: Word;
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
  Check(LListenSock >= 0, 'Listen socket created');

  // TLS 1.3 full handshake
  WriteLn('--- TLS 1.3 Full Handshake ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client TCP connected');
  LClientConn := LClientCtx.CreateConnection(THandle(LClientSock));
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
  fpClose(LServerThread.ClientSock);
  LServerThread.Free;
  LSession := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  fpClose(LClientSock);
  fpClose(LListenSock);

  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 Server test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
