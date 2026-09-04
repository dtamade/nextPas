program test_freepascal_diagnostics;

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
  if ACondition then begin Inc(LPassed); WriteLn('  PASS: ', AName); end
  else begin WriteLn('  FAIL: ', AName); Halt(1); end;
end;

type
  TServerThread = class(TWorkerThread)
  private
    FListenSock: TPlatformSocket;
    FClientSock: TPlatformSocket;
    FContext: ISSLContext;
    FConn: ISSLConnection;
    FSuccess: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
    property Conn: ISSLConnection read FConn;
    property ClientSock: TPlatformSocket read FClientSock;
    property Success: Boolean read FSuccess;
  end;

constructor TServerThread.Create(AListenSock: TPlatformSocket; AContext: ISSLContext);
begin
  inherited Create;
  FListenSock := AListenSock; FContext := AContext;
  FSuccess := False; FClientSock := PLATFORM_INVALID_SOCKET;
end;

procedure TServerThread.Execute;
var LAddr: TPlatformSockAddr; LAddrLen: Int32;
begin
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  if platform_socket_accept(FListenSock, @LAddr.Storage[0], @LAddrLen,
    FClientSock) <> 0 then
    Exit;
  FConn := FContext.CreateConnection(THandle(FClientSock.Value));
  FSuccess := FConn.Accept;
end;

function CreateListenSocket(APort: Word): TPlatformSocket;
var LAddr: TPlatformSockAddr; LOptVal: LongInt;
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
  LDiag: ISSLDiagnostics;
  LMetrics: TSSLPerformanceMetrics;
  LInfo: TSSLDiagnosticInfo;
  LHealth: TSSLHealthStatus;
  LListenSock, LClientSock: TPlatformSocket;
  LServerThread: TServerThread;
  LPort: Word;
  LTmpSock: TPlatformSocket;
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
  Check(LListenSock.IsValid, 'Listen socket');

  LServerThread := TServerThread.Create(LListenSock, LServerCtx);
  LServerThread.Start;

  LClientSock := ConnectTo(LPort);
  LConn := LClientCtx.CreateConnection(THandle(LClientSock.Value));
  Check(LConn.Connect, 'TLS handshake');

  // Test ISSLDiagnostics interface
  Check(Supports(LConn, ISSLDiagnostics, LDiag), 'Supports ISSLDiagnostics');

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
  LTmpSock := LServerThread.ClientSock;
  platform_socket_close(LTmpSock);
  LServerThread.Free;
  platform_socket_close(LClientSock);
  platform_socket_close(LListenSock);
  LDiag := nil;
  LServerCtx := nil;
  LClientCtx := nil;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('Diagnostics tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
