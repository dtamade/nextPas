unit nextpas.core.net.server.iocp;
{**
 * @desc Windows IOCP TCP server backend (phase-1).
 *       Completion-driven AcceptEx + foundation worker handoff for sync
 *       session/handler execution. Mirrors epoll phase-1 shape: evented
 *       accept path, not full completion-driven per-connection protocol I/O.
 *       truth: registered only on Windows; wine-runtime-smoke is not
 *       real-Windows scale-ready evidence.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpIocpServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  nextpas.core.errors
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.base.utils
  , nextpas.core.io.base
  , nextpas.core.io.reactor.iocp
  , nextpas.core.net.base
  , nextpas.core.net.intf
  , nextpas.core.net.tcp
  , nextpas.core.net.server.runtime
  , nextpas.core.platform.socket
  , nextpas.core.platform.socket.base
  , nextpas.core.thread
  , nextpas.core.text.conv
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_WINDOWS}

type
  TTcpIocpServer = class;

  TTcpIocpConnTask = class(TInterfacedObject)
  private
    FConn: ITcpStream;
    FHandler: ITcpServerHandler;
    FSessionContext: ITcpServerSessionContext;
    FSession: ITcpServerSession;
  public
    constructor CreateForHandler(const AConn: ITcpStream;
      const AHandler: ITcpServerHandler;
      const ASessionContext: ITcpServerSessionContext);
    constructor CreateForSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    procedure Run;
  end;

  TTcpIocpServer = class(TInterfacedObject, ITcpServer)
  private
    FOptions: TTcpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
    FListenerSocketRuntime: ITcpSocketRuntime;
    FConnWorkers: IThreadPool;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FSessionContext: ITcpServerSessionContext;
    FHandler: ITcpServerHandler;
    FReactor: TIocpReactor;
    FReactorReady: Boolean;
    FAcceptArmed: Boolean;
    procedure EnsureRuntimeContext;
    procedure ReleaseRuntimeContext;
    procedure ArmAccept;
    procedure HandleAcceptDone(const AResult: Int32; const AAccepted: PtrInt);
    procedure DispatchAcceptedConn(const AConn: ITcpStream);
    procedure DispatchAcceptedSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    function RemoteFromSocket(const ASock: TPlatformSocket): TNetAddress;
  public
    constructor Create(const AOptions: TTcpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

procedure IocpServerAcceptCallback(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LServer: TTcpIocpServer;
  LAccepted: PtrInt;
begin
  if AContext = nil then
    Exit;
  LServer := TTcpIocpServer(AContext);
  { Capture before any re-arm overwrites reactor last-accept state. }
  LAccepted := LServer.FReactor.LastAcceptedSocket;
  LServer.HandleAcceptDone(AResult, LAccepted);
end;

constructor TTcpIocpConnTask.CreateForHandler(const AConn: ITcpStream;
  const AHandler: ITcpServerHandler;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := ASessionContext;
  FSession := nil;
end;

constructor TTcpIocpConnTask.CreateForSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
begin
  inherited Create;
  FConn := AConn;
  FHandler := nil;
  FSessionContext := nil;
  FSession := ASession;
end;

procedure TTcpIocpConnTask.Run;
var
  LOwnership: TTcpServerConnOwnership;
begin
  if FSession <> nil then
    LOwnership := ExecuteTcpServerSession(FSession)
  else
    LOwnership := ExecuteTcpServerConnHandler(FHandler, FConn, FSessionContext);
  if LOwnership = tscoServer then
    CloseServerOwnedTcpConn(FConn);
  FConn := nil;
  FHandler := nil;
  FSessionContext := nil;
  FSession := nil;
end;

constructor TTcpIocpServer.Create(const AOptions: TTcpServerOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FRunning := False;
  FListener := nil;
  FListenerSocketRuntime := nil;
  FConnWorkers := nil;
  FWorkerHandoff := nil;
  FSessionContext := nil;
  FHandler := nil;
  FReactorReady := False;
  FAcceptArmed := False;
end;

destructor TTcpIocpServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FHandler := nil;
  FSessionContext := nil;
  FWorkerHandoff := nil;
  FConnWorkers := nil;
  FListenerSocketRuntime := nil;
  FListener := nil;
  if FReactorReady then
  begin
    FReactor.Close;
    FReactorReady := False;
  end;
  inherited;
end;

procedure TTcpIocpServer.EnsureRuntimeContext;
begin
  if FWorkerHandoff = nil then
  begin
    CreateTcpServerRuntimeContext(FWorkerHandoff, FSessionContext,
      FOptions.ShutdownTimeoutNs);
    FConnWorkers := ThreadPool(0);
  end;
end;

procedure TTcpIocpServer.ReleaseRuntimeContext;
begin
  if FWorkerHandoff <> nil then
    FWorkerHandoff.Shutdown;
  FWorkerHandoff := nil;
  FSessionContext := nil;
  if FConnWorkers <> nil then
    FConnWorkers.Shutdown;
  FConnWorkers := nil;
end;

function TTcpIocpServer.RemoteFromSocket(
  const ASock: TPlatformSocket): TNetAddress;
var
  LSa: TPlatformSockAddr;
  LLen: Int32;
  LIP: UInt32;
  LPort: UInt16;
begin
  Result := TNetAddress.Any(0);
  LSa.Clear;
  LLen := SizeOf(LSa.Storage);
  if platform_socket_getpeername(ASock, @LSa.Storage[0], @LLen) <> 0 then
    Exit;
  LSa.Len := LLen;
  platform_sockaddr_ipv4_extract(LSa, LIP, LPort);
  Result.IP := platform_ipv4_to_string(platform_ntohl(LIP));
  Result.Port := LPort;
  Result.IsIPv6 := False;
end;

procedure TTcpIocpServer.ArmAccept;
var
  LFd: PtrInt;
begin
  if (not FRunning) or (not FReactorReady) or (FListenerSocketRuntime = nil) then
    Exit;
  if FAcceptArmed then
    Exit;
  LFd := PtrInt(FListenerSocketRuntime.NativeSocketHandle);
  if not FReactor.AsyncAccept(LFd, nil, nil, 0, @IocpServerAcceptCallback, Self) then
    raise ENetworkError.Create('tcp iocp AsyncAccept arm failed');
  FAcceptArmed := True;
end;

procedure TTcpIocpServer.DispatchAcceptedSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
var
  LTask: TTcpIocpConnTask;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  LTask := TTcpIocpConnTask.CreateForSession(AConn, ASession);
  try
    FConnWorkers.Submit(procedure
    begin
      try
        LTask.Run;
      finally
        LTask.Free;
      end;
    end);
  except
    LTask.Free;
    CloseServerOwnedTcpConn(AConn);
    raise;
  end;
end;

procedure TTcpIocpServer.DispatchAcceptedConn(const AConn: ITcpStream);
var
  LTask: TTcpIocpConnTask;
  LSession: ITcpServerSession;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  try
    if not TryCreateTcpServerSession(FHandler, AConn, FSessionContext, LSession) then
      LSession := nil;
  except
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;
  if LSession <> nil then
  begin
    { Phase-1: no completion-driven per-conn protocol path yet — worker handoff. }
    DispatchAcceptedSession(AConn, LSession);
    Exit;
  end;

  LTask := TTcpIocpConnTask.CreateForHandler(AConn, FHandler, FSessionContext);
  try
    FConnWorkers.Submit(procedure
    begin
      try
        LTask.Run;
      finally
        LTask.Free;
      end;
    end);
  except
    LTask.Free;
    CloseServerOwnedTcpConn(AConn);
    raise;
  end;
end;

procedure TTcpIocpServer.HandleAcceptDone(const AResult: Int32;
  const AAccepted: PtrInt);
var
  LSock: TPlatformSocket;
  LConn: ITcpStream;
begin
  FAcceptArmed := False;

  if AAccepted = PtrInt(PtrUInt(-1)) then
  begin
    if FRunning then
      ArmAccept;
    Exit;
  end;

  LSock.Value := PtrUInt(AAccepted);

  if (not FRunning) or (AResult < 0) then
  begin
    platform_socket_close(LSock);
    if FRunning then
      ArmAccept;
    Exit;
  end;

  try
    LConn := NetTcpStreamFromConnectedSocket(LSock, RemoteFromSocket(LSock));
  except
    platform_socket_close(LSock);
    if FRunning then
      ArmAccept;
    Exit;
  end;

  DispatchAcceptedConn(LConn);
  if FRunning then
    ArmAccept;
end;

procedure TTcpIocpServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LRuntimeContextReady: Boolean;
begin
  if AHandler = nil then
    raise EArgumentError.Create('tcp server handler must not be nil');

  LRuntimeContextReady := False;
  EnsureRuntimeContext;
  LRuntimeContextReady := True;
  try
    FListener := NetTcpListen(AAddr, APort);
    if not Supports(FListener, ITcpSocketRuntime, FListenerSocketRuntime) then
      raise ENotSupportedError.Create('tcp listener socket runtime seam not available');

    FReactor := TIocpReactor.Create(64);
    if not FReactor.IsValid then
      raise ENetworkError.Create('tcp iocp reactor create failed');
    FReactorReady := True;

    FHandler := AHandler;
    FRunning := True;
    try
      LRuntimeContextReady := False;
      ArmAccept;
      { Blocking GQCS loop; Shutdown posts a wake packet via reactor.Stop. }
      FReactor.Run;
    finally
      FRunning := False;
      FAcceptArmed := False;
      FHandler := nil;
      ReleaseRuntimeContext;
      if FReactorReady then
      begin
        FReactor.Close;
        FReactorReady := False;
      end;
    end;
  finally
    if LRuntimeContextReady then
      ReleaseRuntimeContext;
    FListenerSocketRuntime := nil;
    if FListener <> nil then
    begin
      FListener.Close;
      FListener := nil;
    end;
  end;
end;

procedure TTcpIocpServer.Shutdown;
begin
  FRunning := False;
  if FReactorReady then
    FReactor.Stop;
  if FListener <> nil then
    FListener.Close;
  if FWorkerHandoff <> nil then
    FWorkerHandoff.Shutdown;
end;

function TTcpIocpServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTcpIocpServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function NewTcpIocpServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := TTcpIocpServer.Create(AOptions);
end;

{$ELSE}

function NewTcpIocpServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := nil;
  raise ENotSupportedError.Create('tcp iocp backend requires Windows');
end;

{$ENDIF}

end.