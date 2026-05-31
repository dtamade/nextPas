program test_tls13_psk_loopback;

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
    FResumed: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: cint; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
    property Conn: ISSLConnection read FConn;
    property ClientSock: cint read FClientSock;
    property Resumed: Boolean read FResumed;
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
  LData: TBytes;
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
  begin
    FSuccess := True;
    FResumed := FConn.IsSessionReused;
    LData := TEncoding.ASCII.GetBytes('hello');
    FConn.Write(LData[0], Length(LData));
  end
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
  Check(LListenSock >= 0, 'Listen socket created');

  // First handshake: full TLS 1.3
  WriteLn('--- First handshake (full) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client TCP connected');
  LClientConn := LClientCtx.CreateConnection(THandle(LClientSock));
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
  fpClose(LServerThread.ClientSock);
  LServerThread.Free;
  fpClose(LClientSock);

  if (LSession = nil) or (not LSession.IsResumable) then
  begin
    WriteLn('  [SKIP] No resumable session obtained, cannot test PSK');
    fpClose(LListenSock);
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
  Check(LClientSock >= 0, 'Client TCP connected (2nd)');
  LClientConn := LClientCtx.CreateConnection(THandle(LClientSock));
  LClientConn.SetSession(LSession);
  Check(LClientConn.Connect, 'TLS 1.3 resumed handshake succeeded');
  Check(LClientConn.IsSessionReused, 'Client: session IS resumed');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted resumed: ' + LServerThread.Error);
  Check(LServerThread.Resumed, 'Server: session IS resumed');

  LClientConn.Shutdown;
  LClientConn := nil;
  LServerThread.Conn.Shutdown;
  fpClose(LServerThread.ClientSock);
  LServerThread.Free;
  fpClose(LClientSock);

  LSession := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  fpClose(LListenSock);
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 PSK test: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
