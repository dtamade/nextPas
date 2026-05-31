program test_freepascal_diagnostics;

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
    FClientSock: cint;
    FContext: ISSLContext;
    FConn: ISSLConnection;
    FSuccess: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: cint; AContext: ISSLContext);
    property Conn: ISSLConnection read FConn;
    property ClientSock: cint read FClientSock;
    property Success: Boolean read FSuccess;
  end;

constructor TServerThread.Create(AListenSock: cint; AContext: ISSLContext);
begin
  inherited Create(True);
  FListenSock := AListenSock; FContext := AContext;
  FSuccess := False; FClientSock := -1; FreeOnTerminate := False;
end;

procedure TServerThread.Execute;
var LAddr: TInetSockAddr; LAddrLen: TSockLen;
begin
  LAddrLen := SizeOf(LAddr);
  FClientSock := fpAccept(FListenSock, @LAddr, @LAddrLen);
  if FClientSock < 0 then Exit;
  FConn := FContext.CreateConnection(THandle(FClientSock));
  FSuccess := FConn.Accept;
end;

function CreateListenSocket(APort: Word): cint;
var LAddr: TInetSockAddr; LOptVal: cint;
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
  LDiag: ISSLDiagnostics;
  LMetrics: TSSLPerformanceMetrics;
  LInfo: TSSLDiagnosticInfo;
  LHealth: TSSLHealthStatus;
  LListenSock, LClientSock: cint;
  LServerThread: TServerThread;
  LPort: Word;
begin
  LTotal := 0; LPassed := 0;
  LPort := 44710;
  WriteLn('=== FreePascal Diagnostics Interface Test ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LServerCtx := LLib.CreateContext(sslCtxServer);
  LServerCtx.SetProtocolVersions([sslProtocolTLS12]);
  LServerCtx.LoadCertificate('tests/certs/server-cert.pem');
  LServerCtx.LoadPrivateKey('tests/certs/server-key.pem');

  LClientCtx := LLib.CreateContext(sslCtxClient);
  LClientCtx.SetProtocolVersions([sslProtocolTLS12]);
  LClientCtx.SetVerifyMode([]);

  LListenSock := CreateListenSocket(LPort);
  Check(LListenSock >= 0, 'Listen socket');

  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  LConn := LClientCtx.CreateConnection(THandle(LClientSock));
  Check(LConn.Connect, 'TLS handshake');

  // Test ISSLDiagnostics interface
  Check(Supports(LConn, ISSLDiagnostics), 'Supports ISSLDiagnostics');

  if Supports(LConn, ISSLDiagnostics, LDiag) then
  begin
    LMetrics := LDiag.GetPerformanceMetrics;
    Check(LMetrics.HandshakeTime >= 0, 'HandshakeTime >= 0 (got ' + IntToStr(LMetrics.HandshakeTime) + 'ms)');
    Check(not LMetrics.SessionReused, 'SessionReused = False (first handshake)');
    Check(LMetrics.TotalBytesTransferred >= 0, 'TotalBytesTransferred >= 0');

    LHealth := LDiag.GetHealthStatus;
    Check(True, 'GetHealthStatus callable');

    Check(LDiag.IsHealthy, 'IsHealthy = True after successful handshake');

    LInfo := LDiag.GetDiagnosticInfo;
    Check(LInfo.PerformanceMetrics.HandshakeTime >= 0, 'DiagnosticInfo.HandshakeTime >= 0');
  end;

  LServerThread.WaitFor;
  Check(LServerThread.Success, 'Server accepted');

  // Server-side diagnostics
  if Supports(LServerThread.Conn, ISSLDiagnostics, LDiag) then
  begin
    LMetrics := LDiag.GetPerformanceMetrics;
    Check(LMetrics.HandshakeTime >= 0, 'Server HandshakeTime >= 0');
    Check(LDiag.IsHealthy, 'Server IsHealthy');
  end;

  LConn.Shutdown;
  LConn := nil;
  LServerThread.Conn.Shutdown;
  fpClose(LServerThread.ClientSock);
  LServerThread.Free;
  fpClose(LClientSock);
  fpClose(LListenSock);
  LDiag := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('Diagnostics tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
