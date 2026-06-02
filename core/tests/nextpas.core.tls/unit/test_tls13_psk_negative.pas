program test_tls13_psk_negative;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  {$IFDEF UNIX}cthreads, BaseUnix, Sockets,{$ENDIF}
  SysUtils, Classes,
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
    FListenSock: cint;
    FClientSock: cint;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: cint; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
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
  LConn: ISSLConnection;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
begin
  LAddrLen := SizeOf(LAddr);
  FClientSock := fpAccept(FListenSock, @LAddr, @LAddrLen);
  if FClientSock < 0 then
  begin
    FError := 'accept failed';
    Exit;
  end;
  LConn := FContext.CreateConnection(THandle(FClientSock));
  if LConn.Accept then
    FSuccess := True
  else
    FError := 'Accept failed (expected for bad binder)';
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

procedure TestBadSession;
var
  LLib: ISSLLibrary;
  LServerCtx, LClientCtx: ISSLContext;
  LConn: ISSLConnection;
  LBadSession: TFreePascalSession;
  LSession: ISSLSession;
  LListenSock, LClientSock: cint;
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
  Check(LListenSock >= 0, 'Listen socket');

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
    7200, 12345, Now, 7200, 0
  );
  LSession := LBadSession;

  // Try to resume with bad session - server should reject
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client connected');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock));
  LConn.SetSession(LSession);

  // Connect should either fail or fall back to full handshake
  if LConn.Connect then
    Check(not LConn.IsSessionReused, 'Bad PSK: fell back to full handshake (not resumed)')
  else
    Check(True, 'Bad PSK: handshake failed (server rejected)');

  LServerThread.WaitFor;
  LServerThread.Free;
  fpClose(LClientSock);
  fpClose(LListenSock);
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
    Now - 1, 1, 0
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
