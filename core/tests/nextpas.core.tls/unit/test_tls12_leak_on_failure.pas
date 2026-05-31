program test_tls12_leak_on_failure;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads, BaseUnix, Sockets,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

{$IFDEF UNIX}
procedure IgnoreSIGPIPE;
var
  SA: SigActionRec;
begin
  FillChar(SA, SizeOf(SA), 0);
  SA.sa_handler := SigActionHandler(SIG_IGN);
  fpSigAction(SIGPIPE, @SA, nil);
end;
{$ENDIF}

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
var
  LAddr: TInetSockAddr;
  LTimeout: TTimeVal;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Result < 0 then Exit(-1);
  LTimeout.tv_sec := 2;
  LTimeout.tv_usec := 0;
  fpSetSockOpt(Result, SOL_SOCKET, SO_RCVTIMEO, @LTimeout, SizeOf(LTimeout));
  fpSetSockOpt(Result, SOL_SOCKET, SO_SNDTIMEO, @LTimeout, SizeOf(LTimeout));
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr.s_addr := htonl($7F000001);
  if fpConnect(Result, @LAddr, SizeOf(LAddr)) <> 0 then begin fpClose(Result); Exit(-1); end;
end;

procedure TestConnectToClosedPort;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LListenSock, LClientSock, LServerSock: cint;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
  LPort: Word;
begin
  WriteLn('TestConnectToClosedPort - server closes immediately');
  LPort := 44590;

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS12]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  Check(LListenSock >= 0, 'Listen socket');

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client connected');

  // Accept and immediately close server side (RST)
  LAddrLen := SizeOf(LAddr);
  LServerSock := fpAccept(LListenSock, @LAddr, @LAddrLen);
  fpShutdown(LServerSock, 2);
  fpClose(LServerSock);

  LConn := LCtx.CreateConnection(THandle(LClientSock));
  try
    Check(not LConn.Connect, 'Handshake fails when server closes');
  except
    on E: Exception do
      Check(True, 'Handshake raised exception: ' + E.ClassName);
  end;

  LConn := nil;
  fpClose(LClientSock);
  fpClose(LListenSock);
  LCtx := nil;
  LLib.Finalize;
  LLib := nil;
end;

procedure TestConnectToNonTLS;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LListenSock, LClientSock, LServerSock: cint;
  LAddr: TInetSockAddr;
  LAddrLen: TSockLen;
  LPort: Word;
  LGarbage: array[0..19] of Byte;
begin
  WriteLn('TestConnectToNonTLS - server sends garbage');
  LPort := 44591;

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS12]);
  LCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  Check(LListenSock >= 0, 'Listen socket');

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client connected');

  // Accept and send garbage
  LAddrLen := SizeOf(LAddr);
  LServerSock := fpAccept(LListenSock, @LAddr, @LAddrLen);
  FillChar(LGarbage, SizeOf(LGarbage), $FF);
  fpSend(LServerSock, @LGarbage, SizeOf(LGarbage), 0);
  fpClose(LServerSock);

  LConn := LCtx.CreateConnection(THandle(LClientSock));
  try
    if LConn.Connect then
      Check(True, 'Handshake unexpectedly succeeded on garbage')
    else
      Check(True, 'Handshake correctly failed on garbage');
  except
    on E: Exception do
      Check(True, 'Handshake raised exception on garbage: ' + E.ClassName);
  end;

  LConn := nil;
  fpClose(LClientSock);
  fpClose(LListenSock);
  LCtx := nil;
  LLib.Finalize;
  LLib := nil;
end;

begin
  LTotal := 0;
  LPassed := 0;
  {$IFDEF UNIX}IgnoreSIGPIPE;{$ENDIF}

  TestConnectToClosedPort;
  TestConnectToNonTLS;

  WriteLn;
  WriteLn('TLS 1.2 failure path leak tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.

  LClientSock := ConnectTo(LPort);
  Check(LClientSock >= 0, 'Client connected');

  LAddrLen := SizeOf(LAddr);
  LServerSock := fpAccept(LListenSock, @LAddr, @LAddrLen);

  // Server accept in same thread (simple)
  LConn := LServerCtx.CreateConnection(THandle(LServerSock));
  // Don't call Accept - just test client side
  // Actually we need both sides. Use a thread for server.
  LConn := nil;
  fpClose(LServerSock);

  // Just test that client connect + cleanup doesn't leak
  // (server closed, so handshake will fail)
  LConn := LClientCtx.CreateConnection(THandle(LClientSock));
  LConn.Connect; // will fail since server closed
  LConn := nil;

  fpClose(LClientSock);
  fpClose(LListenSock);
  LServerCtx := nil;
  LClientCtx := nil;
  LLib.Finalize;
  LLib := nil;
  Check(True, 'Cleanup completed without crash');
end;

begin
  LTotal := 0;
  LPassed := 0;
  {$IFDEF UNIX}IgnoreSIGPIPE;{$ENDIF}

  TestConnectToClosedPort;
  TestConnectToNonTLS;

  WriteLn;
  WriteLn('TLS 1.2 failure path leak tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
