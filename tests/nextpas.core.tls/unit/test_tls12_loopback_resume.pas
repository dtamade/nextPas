program test_tls12_loopback_resume;

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
  if ACondition then begin Inc(LPassed); WriteLn('  PASS: ', AName); end
  else begin WriteLn('  FAIL: ', AName); Halt(1); end;
end;

type
  TServerThread = class(TThread)
  private
    FListenSock: cint;
    FContext: ISSLContext;
    FSuccess: Boolean;
    FError: string;
    FCipherName: string;
    FEchoData: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: cint; AContext: ISSLContext);
    property Success: Boolean read FSuccess;
    property Error: string read FError;
    property CipherName: string read FCipherName;
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
  LConn: ISSLConnection;
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
  try
    LConn := FContext.CreateConnection(THandle(LClientSock));
    if LConn.Accept then
    begin
      FSuccess := True;
      FCipherName := LConn.GetCipherName;
    end
    else
      FError := 'TLS Accept failed';
  finally
    fpClose(LClientSock);
  end;
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
  LServerCtx, LClientCtx: ISSLContext;
  LLib: ISSLLibrary;
  LConn: ISSLConnection;
  LSession: ISSLSession;
  LResponse: string;
  LListenSock, LClientSock: cint;
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
  Check(LListenSock >= 0, 'Listen socket created on port ' + IntToStr(LPort));

  // First handshake: full
  WriteLn('--- First handshake (full) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client connected');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock));
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
  fpClose(LClientSock);

  // Second handshake: resumed
  WriteLn('--- Second handshake (resumed) ---');
  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client connected (2nd)');
  LConn := LClientCtx.CreateConnection(THandle(LClientSock));
  LConn.SetSession(LSession);
  Check(LConn.Connect, 'TLS resumed handshake succeeded');
  Check(LConn.IsSessionReused, 'Second handshake IS resumed');

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted resumed: ' + LServerThread.Error);
  LServerThread.Free;
  fpClose(LClientSock);

  fpClose(LListenSock);
  WriteLn;
  WriteLn('Results: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
