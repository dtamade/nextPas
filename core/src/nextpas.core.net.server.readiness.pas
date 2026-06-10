unit nextpas.core.net.server.readiness;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpReadinessServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.net.tcp,
  nextpas.core.net.server.runtime;

type
  TTcpReadinessServer = class;

  TTcpReadinessConnTask = class(TInterfacedObject)
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

  TTcpReadinessServer = class(TInterfacedObject, ITcpServer)
  private
    const WAKE_USERDATA = Pointer(PtrUInt(1));
  private
    FOptions: TTcpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
    FListenerRuntime: ITcpListenerRuntime;
    FListenerSocketRuntime: ITcpSocketRuntime;
    FConnWorkers: IThreadPool;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FPoller: TPlatformPoller;
    FPollerReady: Boolean;
    FCompletionQueue: TTcpServerPollCompletionQueue;
    FTargetRegistry: TTcpServerPollTargetRegistry;
    procedure EnsureRuntimeContext;
    function CreateSessionContext: TTcpServerPollSessionContext;
    procedure RegisterPollTarget(const ATarget: TTcpServerPollSessionTarget);
    procedure UnregisterPollTarget(const ATarget: TTcpServerPollSessionTarget);
    function ComputePollTimeoutMs: Int32;
    procedure HandleExpiredPollTargets;
    procedure DispatchAcceptedSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    procedure DispatchAcceptedConn(const AHandler: ITcpServerHandler;
      const AConn: ITcpStream);
    function TryRegisterPollDrivenSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession;
      const AContext: TTcpServerPollSessionContext): Boolean;
    procedure EnqueueCompletion(const ATarget: TTcpServerPollSessionTarget;
      const ACompletion: ITcpServerWorkCompletion;
      const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
    procedure DrainPendingCompletions;
    procedure WakeReactor;
    procedure HandlePollTarget(const ATarget: TTcpServerPollSessionTarget;
      const AEvents: TPlatformPollEvents);
    procedure HandleListenerReady(const AHandler: ITcpServerHandler);
  public
    constructor Create(const AOptions: TTcpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

constructor TTcpReadinessConnTask.CreateForHandler(const AConn: ITcpStream;
  const AHandler: ITcpServerHandler;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := ASessionContext;
  FSession := nil;
end;

constructor TTcpReadinessConnTask.CreateForSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
begin
  inherited Create;
  FConn := AConn;
  FHandler := nil;
  FSessionContext := nil;
  FSession := ASession;
end;

procedure TTcpReadinessConnTask.Run;
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

constructor TTcpReadinessServer.Create(const AOptions: TTcpServerOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FRunning := False;
  FListener := nil;
  FListenerRuntime := nil;
  FListenerSocketRuntime := nil;
  FConnWorkers := nil;
  FWorkerHandoff := nil;
  FPollerReady := False;
  FCompletionQueue := TTcpServerPollCompletionQueue.Create;
  FTargetRegistry := TTcpServerPollTargetRegistry.Create;
end;

destructor TTcpReadinessServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FWorkerHandoff := nil;
  FConnWorkers := nil;
  FListenerSocketRuntime := nil;
  FListenerRuntime := nil;
  FListener := nil;
  FCompletionQueue.Free;
  FCompletionQueue := nil;
  FTargetRegistry.Free;
  FTargetRegistry := nil;
  inherited;
end;

procedure TTcpReadinessServer.EnsureRuntimeContext;
var
  LUnusedContext: ITcpServerSessionContext;
begin
  if FWorkerHandoff = nil then
  begin
    CreateTcpServerRuntimeContext(FWorkerHandoff, LUnusedContext);
    FConnWorkers := ThreadPool(0);
  end;
end;

function TTcpReadinessServer.CreateSessionContext: TTcpServerPollSessionContext;
begin
  Result := TTcpServerPollSessionContext.Create(FWorkerHandoff,
    @EnqueueCompletion, @WakeReactor);
end;

procedure TTcpReadinessServer.RegisterPollTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  FTargetRegistry.RegisterTarget(ATarget);
end;

procedure TTcpReadinessServer.UnregisterPollTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  FTargetRegistry.UnregisterTarget(ATarget);
end;

function TTcpReadinessServer.ComputePollTimeoutMs: Int32;
begin
  Result := FTargetRegistry.ComputePollTimeoutMs;
end;

procedure TTcpReadinessServer.HandleExpiredPollTargets;
var
  LExpired: TTcpServerPollSessionTargetArray;
  LI: SizeUInt;
begin
  LExpired := FTargetRegistry.CollectExpiredTargets;
  if Length(LExpired) = 0 then
    Exit;
  for LI := 0 to SizeUInt(Length(LExpired)) - 1 do
    HandlePollTarget(LExpired[LI], []);
end;

procedure TTcpReadinessServer.DispatchAcceptedSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
var
  LTask: TTcpReadinessConnTask;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  LTask := TTcpReadinessConnTask.CreateForSession(AConn, ASession);
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

procedure TTcpReadinessServer.DispatchAcceptedConn(
  const AHandler: ITcpServerHandler; const AConn: ITcpStream);
var
  LTask: TTcpReadinessConnTask;
  LSession: ITcpServerSession;
  LContext: ITcpServerSessionContext;
  LPollContext: TTcpServerPollSessionContext;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  LPollContext := CreateSessionContext;
  LContext := LPollContext;
  if TryCreateTcpServerSession(AHandler, AConn, LContext, LSession) then
  begin
    if TryRegisterPollDrivenSession(AConn, LSession, LPollContext) then
      Exit;
    DispatchAcceptedSession(AConn, LSession);
    Exit;
  end;

  LTask := TTcpReadinessConnTask.CreateForHandler(AConn, AHandler, LContext);
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

function TTcpReadinessServer.TryRegisterPollDrivenSession(
  const AConn: ITcpStream; const ASession: ITcpServerSession;
  const AContext: TTcpServerPollSessionContext): Boolean;
var
  LTarget: TTcpServerPollSessionTarget;
  LErr: Int32;
begin
  Result := False;
  if not TryCreateTcpServerPollSessionTarget(AConn, ASession, LTarget) then
    Exit(False);
  try
    if LTarget.CurrentEvents <> [] then
    begin
      LErr := platform_poller_add(FPoller, LTarget.SocketHandle,
        LTarget.CurrentEvents, LTarget);
      if LErr <> 0 then
        raise ENetworkError.Create('tcp readiness poller add conn failed (' +
          IntToStr(LErr) + ')');
    end;
    AContext.BindTarget(LTarget);
    RegisterPollTarget(LTarget);
    Result := True;
  except
    CloseServerOwnedTcpConn(AConn);
    LTarget.Free;
    raise;
  end;
end;

procedure TTcpReadinessServer.EnqueueCompletion(
  const ATarget: TTcpServerPollSessionTarget;
  const ACompletion: ITcpServerWorkCompletion;
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  FCompletionQueue.Enqueue(ATarget, ACompletion, AOutcome, AOwnership);
end;

procedure TTcpReadinessServer.DrainPendingCompletions;
var
  LItems: TTcpServerPollPendingCompletionArray;
  LI: SizeUInt;
begin
  LItems := FCompletionQueue.Drain;
  if Length(LItems) = 0 then
    Exit;
  for LI := 0 to SizeUInt(Length(LItems)) - 1 do
  begin
    try
      LItems[LI].Completion.Complete(LItems[LI].Outcome, LItems[LI].Ownership);
    except
    end;
    if LItems[LI].Target <> nil then
      HandlePollTarget(LItems[LI].Target, []);
  end;
end;

procedure TTcpReadinessServer.WakeReactor;
begin
  if FPollerReady then
    platform_poller_wake(FPoller);
end;

procedure TTcpReadinessServer.HandlePollTarget(
  const ATarget: TTcpServerPollSessionTarget;
  const AEvents: TPlatformPollEvents);
var
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LErr: Int32;
  LSocketHandle: PtrUInt;
  LHasSocketHandle: Boolean;
  LCallbackCompleted: Boolean;
begin
  LOwnership := tscoServer;
  LSocketHandle := 0;
  LHasSocketHandle := False;
  LCallbackCompleted := False;
  try
    if ATarget.CurrentEvents <> [] then
    begin
      LSocketHandle := ATarget.SocketHandle;
      LHasSocketHandle := True;
    end;
    LResult := ATarget.HandleEvents(AEvents, LNextEvents, LOwnership);
    LCallbackCompleted := True;
    if LResult = tsprDone then
    begin
      if ATarget.CurrentEvents <> [] then
      begin
        LErr := platform_poller_remove(FPoller, LSocketHandle);
        if LErr <> 0 then
          raise ENetworkError.Create('tcp readiness poller remove conn failed (' +
            IntToStr(LErr) + ')');
      end;
      UnregisterPollTarget(ATarget);
      if LOwnership = tscoServer then
        CloseServerOwnedTcpConn(ATarget.Connection);
      ATarget.Free;
      Exit;
    end;

    if LNextEvents <> ATarget.CurrentEvents then
    begin
      if LNextEvents = [] then
      begin
        if ATarget.CurrentEvents <> [] then
        begin
          LErr := platform_poller_remove(FPoller, LSocketHandle);
          if LErr <> 0 then
            raise ENetworkError.Create('tcp readiness poller remove conn failed (' +
              IntToStr(LErr) + ')');
        end;
      end
      else if ATarget.CurrentEvents = [] then
      begin
        LErr := platform_poller_add(FPoller, ATarget.SocketHandle, LNextEvents,
          ATarget);
        if LErr <> 0 then
          raise ENetworkError.Create('tcp readiness poller add conn failed (' +
            IntToStr(LErr) + ')');
      end
      else
      begin
        LErr := platform_poller_modify(FPoller, ATarget.SocketHandle, LNextEvents,
          ATarget);
        if LErr <> 0 then
          raise ENetworkError.Create('tcp readiness poller modify conn failed (' +
            IntToStr(LErr) + ')');
      end;
      ATarget.SetCurrentEvents(LNextEvents);
    end;
  except
    if ATarget.CurrentEvents <> [] then
    begin
      if not LHasSocketHandle then
        Exit;
      LErr := platform_poller_remove(FPoller, LSocketHandle);
      if (LErr <> 0) and LCallbackCompleted then
        Exit;
      ATarget.SetCurrentEvents([]);
    end;
    UnregisterPollTarget(ATarget);
    CloseServerOwnedTcpConn(ATarget.Connection);
    ATarget.Free;
  end;
end;

procedure TTcpReadinessServer.HandleListenerReady(
  const AHandler: ITcpServerHandler);
var
  LConn: ITcpStream;
  LAcceptResult: TTcpAcceptResult;
begin
  while FRunning do
  begin
    LConn := nil;
    LAcceptResult := FListenerRuntime.TryAccept(LConn);
    if LAcceptResult = tarAccepted then
    begin
      DispatchAcceptedConn(AHandler, LConn);
      Continue;
    end;
    Break;
  end;
end;

procedure TTcpReadinessServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LEntries: array[0..7] of TPlatformPollEntry;
  LCount: Int32;
  LTimeoutMs: Int32;
  LErr: Int32;
  LI: Int32;
  LTarget: TTcpServerPollSessionTarget;
begin
  if AHandler = nil then
    raise EArgumentError.Create('tcp server handler must not be nil');

  EnsureRuntimeContext;
  try
    FListener := NetTcpListen(AAddr, APort);
    if not Supports(FListener, ITcpListenerRuntime, FListenerRuntime) then
      raise ENotSupportedError.Create('tcp listener runtime seam not available');
    if not Supports(FListener, ITcpSocketRuntime, FListenerSocketRuntime) then
      raise ENotSupportedError.Create('tcp listener socket runtime seam not available');

    FListenerSocketRuntime.SetBlocking(False);
    LErr := platform_poller_create(FPoller);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp readiness poller create failed (' +
        IntToStr(LErr) + ')');
    FPollerReady := True;

    LErr := platform_poller_enable_wake(FPoller, WAKE_USERDATA);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp readiness poller wake enable failed (' +
        IntToStr(LErr) + ')');

    LErr := platform_poller_add(FPoller,
      FListenerSocketRuntime.NativeSocketHandle,
      [peReadable], nil);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp readiness poller add failed (' +
        IntToStr(LErr) + ')');

    FRunning := True;
    try
      while FRunning do
      begin
        LTimeoutMs := ComputePollTimeoutMs;
        LErr := platform_poller_wait(FPoller, @LEntries[0], Length(LEntries),
          LTimeoutMs,
          LCount);
        if LErr <> 0 then
        begin
          if not FRunning then
            Break;
          raise ENetworkError.Create('tcp readiness poller wait failed (' +
            IntToStr(LErr) + ')');
        end;
        if LCount <= 0 then
        begin
          HandleExpiredPollTargets;
          Continue;
        end;

        for LI := 0 to LCount - 1 do
        begin
          if LEntries[LI].UserData = WAKE_USERDATA then
          begin
            platform_poller_drain_wake(FPoller);
            DrainPendingCompletions;
            Continue;
          end;
          if LEntries[LI].UserData = nil then
          begin
            HandleListenerReady(AHandler);
            Continue;
          end;
          LTarget := TTcpServerPollSessionTarget(LEntries[LI].UserData);
          HandlePollTarget(LTarget, LEntries[LI].REvents);
        end;
        HandleExpiredPollTargets;
      end;
    finally
      FRunning := False;
      if FWorkerHandoff <> nil then
        FWorkerHandoff.Shutdown;
      DrainPendingCompletions;
      FWorkerHandoff := nil;
      FCompletionQueue.Clear;
      FTargetRegistry.Clear;
      if FPollerReady then
      begin
        platform_poller_close(FPoller);
        FPollerReady := False;
      end;
      if FConnWorkers <> nil then
        FConnWorkers.Shutdown;
    end;
  finally
    FConnWorkers := nil;
    FListenerSocketRuntime := nil;
    FListenerRuntime := nil;
    FListener := nil;
  end;
end;

procedure TTcpReadinessServer.Shutdown;
var
  LAddr: TNetAddress;
  LWake: ITcpStream;
  LWoken: Boolean;
begin
  FRunning := False;
  LWoken := False;
  if FPollerReady then
    LWoken := platform_poller_wake(FPoller) = 0;
  if FListener <> nil then
  begin
    if not LWoken then
    begin
      LAddr := FListener.LocalAddr;
      try
        LWake := NetTcpConnect(LAddr.IP, LAddr.Port);
        LWake.Close;
      except
      end;
    end;
    FListener.Close;
  end;
end;

function TTcpReadinessServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTcpReadinessServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function NewTcpReadinessServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := TTcpReadinessServer.Create(AOptions);
end;

end.
