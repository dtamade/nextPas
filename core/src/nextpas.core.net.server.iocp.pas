unit nextpas.core.net.server.iocp;
{**
 * @desc Windows IOCP TCP server backend.
 *       phase-1: accept+worker shape — the server owns a GQCS completion
 *       loop (worker thread), arm AcceptEx via AsyncAccept, and hand each
 *       accepted conn to a server-owned completion context.
 *       phase-2: recv + send drain — completion-driven AcceptEx + zero-byte
 *       overlapped recv bridging completions to readiness: poll-driven
 *       sessions advance on the server-owned GQCS loop via TryRead/TryWrite.
 *       Sessions parked on writable interest are re-advanced on a short GQCS
 *       timeout (single -wait invariant: recv parked XOR writable waiter).
 *       Deadline wake is still worker-handoff scope; sessions outside the
 *       guard fall back to worker handoff.
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
  , nextpas.core.platform.io.base
  , nextpas.core.platform.socket
  , nextpas.core.platform.socket.base
  , nextpas.core.time.base
  , nextpas.core.time.deadline
  , nextpas.core.thread
  , nextpas.core.text.conv
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_WINDOWS}

const
  { Retry cadence for sessions parked on writable interest: kernel send
    buffers drain in well under a millisecond once the peer reads, so 1ms
    keeps drain latency low without a busy spin. }
  IOCP_WRITABLE_RETRY_MS = 1;

type
  TTcpIocpServer = class;

  { one per completion-driven conn; context for zero-byte recv completions }
  PIocpConnDriver = ^TIocpConnDriver;
  TIocpConnDriver = record
    Server: TTcpIocpServer;
    Target: TTcpServerPollSessionTarget;
    { deadline wake requested while a recv op is parked: the op has been
      cancelled via TryCancelByContext and the wake is delivered when its
      completion arrives (racing data wins and is delivered as readable) }
    WakePending: Boolean;
  end;

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
    FConnDrivers: array of PIocpConnDriver;
    procedure EnsureRuntimeContext;
    procedure ReleaseRuntimeContext;
    procedure ArmAccept;
    procedure HandleAcceptDone(const AResult: Int32; const AAccepted: PtrInt);
    procedure DispatchAcceptedConn(const AConn: ITcpStream);
    procedure DispatchAcceptedSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    function TryRegisterCompletionRecvSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession): Boolean;
    function ArmConnRecv(const ADriver: PIocpConnDriver): Boolean;
    procedure HandleConnRecvDone(const ADriver: PIocpConnDriver;
      const AResult: Int32);
    procedure AdvanceConnDriver(const ADriver: PIocpConnDriver;
      const AEvents: TPlatformPollEvents);
    procedure RetryWritableWaiters;
    procedure WakeExpiredDeadlines;
    function ComputeWaitTimeoutMs: UInt32;
    procedure AddConnDriver(const ADriver: PIocpConnDriver);
    procedure RemoveConnDriver(const ADriver: PIocpConnDriver);
    procedure CloseConnDriver(const ADriver: PIocpConnDriver;
      const AOwnership: TTcpServerConnOwnership);
    procedure ReleaseConnDrivers;
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

procedure IocpServerConnRecvCallback(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LDriver: PIocpConnDriver;
begin
  if AContext = nil then
    Exit;
  LDriver := PIocpConnDriver(AContext);
  LDriver^.Server.HandleConnRecvDone(LDriver, AResult);
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
  FConnDrivers := nil;
end;

destructor TTcpIocpServer.Destroy;
begin
  if FRunning then
    Shutdown;
  ReleaseConnDrivers;
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
      FOptions.ShutdownTimeoutNs, FOptions.WorkerPoolSize);
    FConnWorkers := ThreadPool(FOptions.WorkerPoolSize);
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

procedure TTcpIocpServer.AddConnDriver(const ADriver: PIocpConnDriver);
begin
  SetLength(FConnDrivers, Length(FConnDrivers) + 1);
  FConnDrivers[High(FConnDrivers)] := ADriver;
end;

procedure TTcpIocpServer.RemoveConnDriver(const ADriver: PIocpConnDriver);
var
  LI: SizeInt;
begin
  for LI := 0 to High(FConnDrivers) do
    if FConnDrivers[LI] = ADriver then
    begin
      FConnDrivers[LI] := FConnDrivers[High(FConnDrivers)];
      SetLength(FConnDrivers, Length(FConnDrivers) - 1);
      Exit;
    end;
end;

procedure TTcpIocpServer.CloseConnDriver(const ADriver: PIocpConnDriver;
  const AOwnership: TTcpServerConnOwnership);
begin
  RemoveConnDriver(ADriver);
  if AOwnership = tscoServer then
    CloseServerOwnedTcpConn(ADriver^.Target.Connection)
  else
    ADriver^.Target.RestoreBlocking;
  ADriver^.Target.Free;
  Dispose(ADriver);
end;

procedure TTcpIocpServer.ReleaseConnDrivers;
var
  LI: SizeInt;
  LDriver: PIocpConnDriver;
begin
  for LI := 0 to High(FConnDrivers) do
  begin
    LDriver := FConnDrivers[LI];
    if LDriver = nil then
      Continue;
    CloseServerOwnedTcpConn(LDriver^.Target.Connection);
    LDriver^.Target.Free;
    Dispose(LDriver);
  end;
  FConnDrivers := nil;
end;

function TTcpIocpServer.ArmConnRecv(const ADriver: PIocpConnDriver): Boolean;
begin
  Result := False;
  if (not FRunning) or (not FReactorReady) then
    Exit;
  { Zero-byte overlapped recv: completion signals readability without
    consuming data — bridges IOCP completions to readiness semantics. }
  Result := FReactor.AsyncRecv(PtrInt(ADriver^.Target.SocketHandle), nil, 0, 0,
    @IocpServerConnRecvCallback, ADriver);
end;

function TTcpIocpServer.TryRegisterCompletionRecvSession(
  const AConn: ITcpStream; const ASession: ITcpServerSession): Boolean;
var
  LTarget: TTcpServerPollSessionTarget;
  LDriver: PIocpConnDriver;
begin
  Result := False;
  if not FReactorReady then
    Exit;
  if not TryCreateTcpServerPollSessionTarget(AConn, ASession, LTarget) then
    Exit;
  { Initial interest must be readable-only (sessions start by reading a
    request; writable interest is entered later via Advance and served by
    the timeout retry loop). Finite wake deadlines are served by the
    GQCS-timeout deadline sweep (WakeExpiredDeadlines). }
  if LTarget.CurrentEvents <> [peReadable] then
  begin
    LTarget.RestoreBlocking;
    LTarget.Free;
    Exit;
  end;
  New(LDriver);
  LDriver^.Server := Self;
  LDriver^.Target := LTarget;
  LDriver^.WakePending := False;
  if not ArmConnRecv(LDriver) then
  begin
    Dispose(LDriver);
    LTarget.RestoreBlocking;
    LTarget.Free;
    Exit;
  end;
  AddConnDriver(LDriver);
  Result := True;
end;

procedure TTcpIocpServer.HandleConnRecvDone(const ADriver: PIocpConnDriver;
  const AResult: Int32);
begin
  if not FRunning then
  begin
    CloseConnDriver(ADriver, tscoServer);
    Exit;
  end;
  if ADriver^.WakePending then
  begin
    ADriver^.WakePending := False;
    { Deadline wake: the cancelled recv completes with an error and is fed
      as an empty event set (epoll expired-target parity); racing data
      wins and is delivered as readable instead. }
    if AResult >= 0 then
      AdvanceConnDriver(ADriver, [peReadable])
    else
      AdvanceConnDriver(ADriver, []);
    Exit;
  end;
  if AResult < 0 then
  begin
    CloseConnDriver(ADriver, tscoServer);
    Exit;
  end;
  AdvanceConnDriver(ADriver, [peReadable]);
end;

procedure TTcpIocpServer.AdvanceConnDriver(const ADriver: PIocpConnDriver;
  const AEvents: TPlatformPollEvents);
var
  LNext: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LResult: TTcpServerPollResult;
begin
  try
    LResult := ADriver^.Target.HandleEvents(AEvents, LNext, LOwnership);
  except
    CloseConnDriver(ADriver, tscoServer);
    Exit;
  end;
  if LResult = tsprDone then
  begin
    CloseConnDriver(ADriver, LOwnership);
    Exit;
  end;
  { Single-wait invariant: a driver either has a recv op parked or sits in
    the writable-waiter set — never both. Composite wait sets collapse to
    the writable side (W2-2 simplification); the timeout loop retries them. }
  if peWritable in LNext then
  begin
    ADriver^.Target.SetCurrentEvents(LNext);
    Exit;
  end;
  if LNext = [peReadable] then
  begin
    ADriver^.Target.SetCurrentEvents(LNext);
    if not ArmConnRecv(ADriver) then
      CloseConnDriver(ADriver, tscoServer);
    Exit;
  end;
  { Empty wait set with a finite deadline: pure sleeper — the deadline
    sweep wakes it (HandleEvents already refreshed WakeDeadline). }
  if (LNext = []) and (not ADriver^.Target.WakeDeadline.IsInfinite) then
  begin
    ADriver^.Target.SetCurrentEvents(LNext);
    Exit;
  end;
  { Empty wait set without a deadline cannot make progress — close honestly. }
  CloseConnDriver(ADriver, tscoServer);
end;

procedure TTcpIocpServer.RetryWritableWaiters;
var
  LI: SizeInt;
  LWaiters: array of PIocpConnDriver;
begin
  { Snapshot first: AdvanceConnDriver may close drivers and mutate
    FConnDrivers (swap-remove) while we iterate. }
  LWaiters := nil;
  for LI := 0 to High(FConnDrivers) do
    if peWritable in FConnDrivers[LI]^.Target.CurrentEvents then
    begin
      SetLength(LWaiters, Length(LWaiters) + 1);
      LWaiters[High(LWaiters)] := FConnDrivers[LI];
    end;
  for LI := 0 to High(LWaiters) do
    AdvanceConnDriver(LWaiters[LI], [peWritable]);
end;

procedure TTcpIocpServer.WakeExpiredDeadlines;
var
  LI: SizeInt;
  LExpired: array of PIocpConnDriver;
  LDriver: PIocpConnDriver;
begin
  { Snapshot first: AdvanceConnDriver may close drivers and mutate
    FConnDrivers (swap-remove) while we iterate. }
  LExpired := nil;
  for LI := 0 to High(FConnDrivers) do
  begin
    LDriver := FConnDrivers[LI];
    if LDriver^.WakePending then
      Continue; { cancel in flight — wake rides its completion }
    if LDriver^.Target.WakeDeadline.IsInfinite then
      Continue;
    if not LDriver^.Target.WakeDeadline.IsExpired then
      Continue;
    SetLength(LExpired, Length(LExpired) + 1);
    LExpired[High(LExpired)] := LDriver;
  end;
  for LI := 0 to High(LExpired) do
  begin
    LDriver := LExpired[LI];
    if (LDriver^.Target.CurrentEvents = []) or
       (peWritable in LDriver^.Target.CurrentEvents) then
    begin
      { sleeper / writable waiter: no recv op parked — wake directly with
        an empty event set (epoll HandleExpiredPollTargets parity) }
      AdvanceConnDriver(LDriver, []);
      Continue;
    end;
    { recv op parked: cancel it and defer the wake to its completion.
      A miss means the op is no longer pending — its completion is about
      to be dispatched and will re-advance the session anyway. }
    if FReactor.TryCancelByContext(LDriver) then
      LDriver^.WakePending := True;
  end;
end;

function TTcpIocpServer.ComputeWaitTimeoutMs: UInt32;
var
  LI: SizeInt;
  LBest: Int64;
  LMs: Int64;
  LDeadline: TDeadline;
  LRemaining: TDuration;
begin
  { min over writable retry cadence and the nearest finite wake deadline
    (epoll ComputePollTimeoutMs parity: expired -> 0, sub-ms -> 1ms). }
  LBest := -1;
  for LI := 0 to High(FConnDrivers) do
  begin
    if peWritable in FConnDrivers[LI]^.Target.CurrentEvents then
      if (LBest < 0) or (LBest > IOCP_WRITABLE_RETRY_MS) then
        LBest := IOCP_WRITABLE_RETRY_MS;
    if FConnDrivers[LI]^.WakePending then
      Continue; { deadline already handled — waiting on the cancel packet }
    LDeadline := FConnDrivers[LI]^.Target.WakeDeadline;
    if LDeadline.IsInfinite then
      Continue;
    if LDeadline.IsExpired then
      LMs := 0
    else
    begin
      LRemaining := LDeadline.Remaining;
      LMs := LRemaining.AsMilliseconds;
      if (LMs <= 0) and (LRemaining.AsNanoseconds > 0) then
        LMs := 1;
      if LMs > High(Int32) then
        LMs := High(Int32);
    end;
    if (LBest < 0) or (LMs < LBest) then
      LBest := LMs;
  end;
  if LBest < 0 then
    Result := IOCP_WAIT_INFINITE
  else
    Result := UInt32(LBest);
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
    if TryRegisterCompletionRecvSession(AConn, LSession) then
      Exit;
    { Session outside the completion-recv guard (non-readable initial
      interest or no poll shape) — worker handoff. }
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
      { Server-owned event loop (epoll-server parity): dispatch completions,
        and on timeout re-advance sessions parked on writable interest.
        Shutdown posts a wake packet via reactor.Stop. }
      while FRunning do
        case FReactor.PollOneWait(ComputeWaitTimeoutMs) of
          iprTimeout:
            begin
              WakeExpiredDeadlines;
              RetryWritableWaiters;
            end;
          iprWoken:
            ; { stop wake — loop condition re-checks FRunning }
        end;
    finally
      FRunning := False;
      FAcceptArmed := False;
      FHandler := nil;
      ReleaseRuntimeContext;
      if FReactorReady then
      begin
        { Close fires pending zero-byte recv callbacks with a negative
          error — surviving drivers are cleaned via HandleConnRecvDone. }
        FReactor.Close;
        FReactorReady := False;
      end;
      ReleaseConnDrivers;
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