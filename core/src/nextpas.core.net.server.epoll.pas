unit nextpas.core.net.server.epoll;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpEpollServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.net.tcp,
  nextpas.core.net.server.runtime;

type
  TTcpEpollPollSessionTarget = class;
  TTcpEpollServer = class;

  TTcpEpollPendingCompletion = record
    Target: TTcpEpollPollSessionTarget;
    Completion: ITcpServerWorkCompletion;
    Outcome: TTcpServerWorkOutcome;
    Ownership: TTcpServerConnOwnership;
  end;

  TTcpEpollConnTask = class(TInterfacedObject)
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

  TTcpEpollPollSessionTarget = class
  private
    FConn: ITcpStream;
    FSocketRuntime: ITcpSocketRuntime;
    FSession: ITcpServerSession;
    FPollSession: ITcpServerPollDrivenSession;
    FDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
    FEvents: TPlatformPollEvents;
    FWakeDeadline: TDeadline;
    procedure RefreshWakeDeadline;
  public
    constructor Create(const AConn: ITcpStream;
      const ASocketRuntime: ITcpSocketRuntime;
      const ASession: ITcpServerSession;
      const APollSession: ITcpServerPollDrivenSession);
    function SocketFd: Int32;
    function CurrentEvents: TPlatformPollEvents;
    procedure SetCurrentEvents(const AEvents: TPlatformPollEvents);
    function WakeDeadline: TDeadline;
    function Connection: ITcpStream;
    function HandleEvents(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
  end;

  TTcpEpollQueuedCompletion = class(TInterfacedObject,
    ITcpServerWorkCompletion)
  private
    FServer: TTcpEpollServer;
    FTarget: TTcpEpollPollSessionTarget;
    FInner: ITcpServerWorkCompletion;
  public
    constructor Create(const AServer: TTcpEpollServer;
      const ATarget: TTcpEpollPollSessionTarget;
      const AInner: ITcpServerWorkCompletion);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TTcpEpollWorkerHandoff = class(TInterfacedObject, ITcpServerWorkerHandoff)
  private
    FServer: TTcpEpollServer;
    FBaseHandoff: ITcpServerWorkerHandoff;
    FTarget: TTcpEpollPollSessionTarget;
  public
    constructor Create(const AServer: TTcpEpollServer;
      const ABaseHandoff: ITcpServerWorkerHandoff);
    procedure BindTarget(const ATarget: TTcpEpollPollSessionTarget);
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
  end;

  TTcpEpollSessionContext = class(TInterfacedObject, ITcpServerSessionContext)
  private
    FWorkerHandoffRef: ITcpServerWorkerHandoff;
    FWorkerHandoff: TTcpEpollWorkerHandoff;
  public
    constructor Create(const AServer: TTcpEpollServer;
      const ABaseHandoff: ITcpServerWorkerHandoff);
    procedure BindTarget(const ATarget: TTcpEpollPollSessionTarget);
    function WorkerHandoff: ITcpServerWorkerHandoff;
  end;

  TTcpEpollServer = class(TInterfacedObject, ITcpServer)
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
    FCompletionLock: IMutex;
    FPendingCompletions: array of TTcpEpollPendingCompletion;
    FPendingCompletionCount: SizeUInt;
    FPollTargets: array of TTcpEpollPollSessionTarget;
    FPollTargetCount: SizeUInt;
    procedure EnsureRuntimeContext;
    function CreateSessionContext: TTcpEpollSessionContext;
    procedure RegisterPollTarget(const ATarget: TTcpEpollPollSessionTarget);
    procedure UnregisterPollTarget(const ATarget: TTcpEpollPollSessionTarget);
    function ComputePollTimeoutMs: Int32;
    procedure HandleExpiredPollTargets;
    procedure DispatchAcceptedSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    procedure DispatchAcceptedConn(const AHandler: ITcpServerHandler;
      const AConn: ITcpStream);
    function TryRegisterPollDrivenSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession;
      const AContext: TTcpEpollSessionContext): Boolean;
    procedure EnqueueCompletion(const ATarget: TTcpEpollPollSessionTarget;
      const ACompletion: ITcpServerWorkCompletion;
      const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
    procedure DrainPendingCompletions;
    procedure WakeReactor;
    procedure HandlePollTarget(const ATarget: TTcpEpollPollSessionTarget;
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

constructor TTcpEpollConnTask.CreateForHandler(const AConn: ITcpStream;
  const AHandler: ITcpServerHandler;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := ASessionContext;
  FSession := nil;
end;

constructor TTcpEpollConnTask.CreateForSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
begin
  inherited Create;
  FConn := AConn;
  FHandler := nil;
  FSessionContext := nil;
  FSession := ASession;
end;

procedure TTcpEpollConnTask.Run;
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

constructor TTcpEpollPollSessionTarget.Create(const AConn: ITcpStream;
  const ASocketRuntime: ITcpSocketRuntime; const ASession: ITcpServerSession;
  const APollSession: ITcpServerPollDrivenSession);
begin
  inherited Create;
  FConn := AConn;
  FSocketRuntime := ASocketRuntime;
  FSession := ASession;
  FPollSession := APollSession;
  FEvents := FPollSession.PollEvents;
  if Supports(ASession, ITcpServerPollDrivenSessionWithDeadline,
    FDeadlineSession) then
    RefreshWakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
  if (FEvents = []) and FWakeDeadline.IsInfinite then
    raise EArgumentError.Create('poll-driven session must expose poll events');
end;

function TTcpEpollPollSessionTarget.SocketFd: Int32;
begin
  Result := Int32(FSocketRuntime.NativeSocketHandle);
end;

function TTcpEpollPollSessionTarget.CurrentEvents: TPlatformPollEvents;
begin
  Result := FEvents;
end;

procedure TTcpEpollPollSessionTarget.SetCurrentEvents(
  const AEvents: TPlatformPollEvents);
begin
  FEvents := AEvents;
end;

procedure TTcpEpollPollSessionTarget.RefreshWakeDeadline;
begin
  if FDeadlineSession <> nil then
    FWakeDeadline := FDeadlineSession.WakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
end;

function TTcpEpollPollSessionTarget.WakeDeadline: TDeadline;
begin
  Result := FWakeDeadline;
end;

function TTcpEpollPollSessionTarget.Connection: ITcpStream;
begin
  Result := FConn;
end;

function TTcpEpollPollSessionTarget.HandleEvents(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  Result := FPollSession.Advance(AEvents, ANextEvents, AOwnership);
  RefreshWakeDeadline;
end;

constructor TTcpEpollQueuedCompletion.Create(const AServer: TTcpEpollServer;
  const ATarget: TTcpEpollPollSessionTarget;
  const AInner: ITcpServerWorkCompletion);
begin
  inherited Create;
  FServer := AServer;
  FTarget := ATarget;
  FInner := AInner;
end;

procedure TTcpEpollQueuedCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FServer <> nil then
  begin
    FServer.EnqueueCompletion(FTarget, FInner, AOutcome, AOwnership);
    FServer.WakeReactor;
  end;
  FInner := nil;
  FTarget := nil;
  FServer := nil;
end;

constructor TTcpEpollWorkerHandoff.Create(const AServer: TTcpEpollServer;
  const ABaseHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FServer := AServer;
  FBaseHandoff := ABaseHandoff;
  FTarget := nil;
end;

procedure TTcpEpollWorkerHandoff.BindTarget(
  const ATarget: TTcpEpollPollSessionTarget);
begin
  FTarget := ATarget;
end;

function TTcpEpollWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LCompletion: ITcpServerWorkCompletion;
begin
  if FTarget <> nil then
    LCompletion := TTcpEpollQueuedCompletion.Create(FServer, FTarget, ACompletion)
  else
    LCompletion := ACompletion;
  Result := FBaseHandoff.Submit(AWork, LCompletion);
end;

procedure TTcpEpollWorkerHandoff.Shutdown;
begin
  FBaseHandoff.Shutdown;
end;

constructor TTcpEpollSessionContext.Create(const AServer: TTcpEpollServer;
  const ABaseHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FWorkerHandoff := TTcpEpollWorkerHandoff.Create(AServer, ABaseHandoff);
  FWorkerHandoffRef := FWorkerHandoff;
end;

procedure TTcpEpollSessionContext.BindTarget(
  const ATarget: TTcpEpollPollSessionTarget);
begin
  FWorkerHandoff.BindTarget(ATarget);
end;

function TTcpEpollSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoffRef;
end;

constructor TTcpEpollServer.Create(const AOptions: TTcpServerOptions);
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
  FCompletionLock := nextpas.core.sync.mutex.TMutex.Create;
  SetLength(FPendingCompletions, 4);
  FPendingCompletionCount := 0;
  FPollTargetCount := 0;
end;

destructor TTcpEpollServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FWorkerHandoff := nil;
  FConnWorkers := nil;
  FListenerSocketRuntime := nil;
  FListenerRuntime := nil;
  FListener := nil;
  FCompletionLock := nil;
  inherited;
end;

procedure TTcpEpollServer.EnsureRuntimeContext;
var
  LUnusedContext: ITcpServerSessionContext;
begin
  if FWorkerHandoff = nil then
  begin
    CreateTcpServerRuntimeContext(FWorkerHandoff, LUnusedContext);
    FConnWorkers := ThreadPool(0);
  end;
end;

function TTcpEpollServer.CreateSessionContext: TTcpEpollSessionContext;
begin
  Result := TTcpEpollSessionContext.Create(Self, FWorkerHandoff);
end;

procedure TTcpEpollServer.RegisterPollTarget(
  const ATarget: TTcpEpollPollSessionTarget);
begin
  if FPollTargetCount >= SizeUInt(Length(FPollTargets)) then
    SetLength(FPollTargets, FPollTargetCount + 8);
  FPollTargets[FPollTargetCount] := ATarget;
  Inc(FPollTargetCount);
end;

procedure TTcpEpollServer.UnregisterPollTarget(
  const ATarget: TTcpEpollPollSessionTarget);
var
  LI: SizeUInt;
begin
  if FPollTargetCount = 0 then
    Exit;
  for LI := 0 to FPollTargetCount - 1 do
    if FPollTargets[LI] = ATarget then
    begin
      Dec(FPollTargetCount);
      FPollTargets[LI] := FPollTargets[FPollTargetCount];
      FPollTargets[FPollTargetCount] := nil;
      Exit;
    end;
end;

function TTcpEpollServer.ComputePollTimeoutMs: Int32;
var
  LI: SizeUInt;
  LDeadline: TDeadline;
  LRemaining: TDuration;
  LMs: Int64;
begin
  Result := -1;
  if FPollTargetCount = 0 then
    Exit;
  for LI := 0 to FPollTargetCount - 1 do
  begin
    LDeadline := FPollTargets[LI].WakeDeadline;
    if LDeadline.IsInfinite then
      Continue;
    if LDeadline.IsExpired then
      Exit(0);
    LRemaining := LDeadline.Remaining;
    LMs := LRemaining.AsMilliseconds;
    if (LMs <= 0) and (LRemaining.AsNanoseconds > 0) then
      LMs := 1;
    if LMs > High(Int32) then
      LMs := High(Int32);
    if (Result < 0) or (LMs < Result) then
      Result := Int32(LMs);
  end;
end;

procedure TTcpEpollServer.HandleExpiredPollTargets;
var
  LExpired: array of TTcpEpollPollSessionTarget;
  LCount: SizeUInt;
  LI: SizeUInt;
begin
  SetLength(LExpired, 0);
  LCount := 0;
  if FPollTargetCount = 0 then
    Exit;
  for LI := 0 to FPollTargetCount - 1 do
    if FPollTargets[LI].WakeDeadline.IsExpired then
    begin
      if LCount >= SizeUInt(Length(LExpired)) then
        SetLength(LExpired, LCount + 4);
      LExpired[LCount] := FPollTargets[LI];
      Inc(LCount);
    end;

  if LCount = 0 then
    Exit;
  for LI := 0 to LCount - 1 do
    HandlePollTarget(LExpired[LI], []);
end;

procedure TTcpEpollServer.DispatchAcceptedSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
var
  LTask: TTcpEpollConnTask;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  LTask := TTcpEpollConnTask.CreateForSession(AConn, ASession);
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

procedure TTcpEpollServer.DispatchAcceptedConn(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream);
var
  LTask: TTcpEpollConnTask;
  LSession: ITcpServerSession;
  LContext: ITcpServerSessionContext;
  LPollContext: TTcpEpollSessionContext;
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

  LTask := TTcpEpollConnTask.CreateForHandler(AConn, AHandler, LContext);
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

function TTcpEpollServer.TryRegisterPollDrivenSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession; const AContext: TTcpEpollSessionContext): Boolean;
var
  LPollSession: ITcpServerPollDrivenSession;
  LSocketRuntime: ITcpSocketRuntime;
  LTarget: TTcpEpollPollSessionTarget;
  LErr: Int32;
begin
  Result := False;
  if not Supports(ASession, ITcpServerPollDrivenSession, LPollSession) then
    Exit(False);
  if not Supports(AConn, ITcpSocketRuntime, LSocketRuntime) then
    Exit(False);

  LSocketRuntime.SetBlocking(False);
  LTarget := TTcpEpollPollSessionTarget.Create(AConn, LSocketRuntime,
    ASession, LPollSession);
  try
    if LTarget.CurrentEvents <> [] then
    begin
      LErr := platform_poller_add(FPoller, LTarget.SocketFd,
        LTarget.CurrentEvents, LTarget);
      if LErr <> 0 then
        raise ENetworkError.Create('tcp epoll poller add conn failed (' +
          IntToStr(LErr) + ')');
    end;
    AContext.BindTarget(LTarget);
    RegisterPollTarget(LTarget);
    Result := True;
  except
    LTarget.Free;
    raise;
  end;
end;

procedure TTcpEpollServer.EnqueueCompletion(
  const ATarget: TTcpEpollPollSessionTarget;
  const ACompletion: ITcpServerWorkCompletion;
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
var
  LCapacity: SizeUInt;
begin
  if ACompletion = nil then
    Exit;

  FCompletionLock.Acquire;
  try
    LCapacity := SizeUInt(Length(FPendingCompletions));
    if FPendingCompletionCount >= LCapacity then
    begin
      if LCapacity = 0 then
        LCapacity := 4
      else
        LCapacity := LCapacity * 2;
      SetLength(FPendingCompletions, LCapacity);
    end;
    FPendingCompletions[FPendingCompletionCount].Target := ATarget;
    FPendingCompletions[FPendingCompletionCount].Completion := ACompletion;
    FPendingCompletions[FPendingCompletionCount].Outcome := AOutcome;
    FPendingCompletions[FPendingCompletionCount].Ownership := AOwnership;
    Inc(FPendingCompletionCount);
  finally
    FCompletionLock.Release;
  end;
end;

procedure TTcpEpollServer.DrainPendingCompletions;
var
  LItems: array of TTcpEpollPendingCompletion;
  LCount: SizeUInt;
  LI: SizeUInt;
begin
  FCompletionLock.Acquire;
  try
    LCount := FPendingCompletionCount;
    if LCount = 0 then
      Exit;
    SetLength(LItems, LCount);
    for LI := 0 to LCount - 1 do
    begin
      LItems[LI] := FPendingCompletions[LI];
      FPendingCompletions[LI].Target := nil;
      FPendingCompletions[LI].Completion := nil;
    end;
    FPendingCompletionCount := 0;
  finally
    FCompletionLock.Release;
  end;

  for LI := 0 to LCount - 1 do
  begin
    try
      LItems[LI].Completion.Complete(LItems[LI].Outcome, LItems[LI].Ownership);
    except
    end;
    if LItems[LI].Target <> nil then
      HandlePollTarget(LItems[LI].Target, []);
  end;
end;

procedure TTcpEpollServer.WakeReactor;
begin
  if FPollerReady then
    platform_poller_wake(FPoller);
end;

procedure TTcpEpollServer.HandlePollTarget(
  const ATarget: TTcpEpollPollSessionTarget; const AEvents: TPlatformPollEvents);
var
  LResult: TTcpServerPollResult;
  LNextEvents: TPlatformPollEvents;
  LOwnership: TTcpServerConnOwnership;
  LErr: Int32;
begin
  LOwnership := tscoServer;
  try
    LResult := ATarget.HandleEvents(AEvents, LNextEvents, LOwnership);
    if LResult = tsprDone then
    begin
      if ATarget.CurrentEvents <> [] then
        platform_poller_remove(FPoller, ATarget.SocketFd);
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
          LErr := platform_poller_remove(FPoller, ATarget.SocketFd);
          if LErr <> 0 then
            raise ENetworkError.Create('tcp epoll poller remove conn failed (' +
              IntToStr(LErr) + ')');
        end;
      end
      else if ATarget.CurrentEvents = [] then
      begin
        LErr := platform_poller_add(FPoller, ATarget.SocketFd, LNextEvents,
          ATarget);
        if LErr <> 0 then
          raise ENetworkError.Create('tcp epoll poller add conn failed (' +
            IntToStr(LErr) + ')');
      end
      else
      begin
        LErr := platform_poller_modify(FPoller, ATarget.SocketFd, LNextEvents,
          ATarget);
        if LErr <> 0 then
          raise ENetworkError.Create('tcp epoll poller modify conn failed (' +
            IntToStr(LErr) + ')');
      end;
      ATarget.SetCurrentEvents(LNextEvents);
    end;
  except
    if ATarget.CurrentEvents <> [] then
      platform_poller_remove(FPoller, ATarget.SocketFd);
    UnregisterPollTarget(ATarget);
    CloseServerOwnedTcpConn(ATarget.Connection);
    ATarget.Free;
  end;
end;

procedure TTcpEpollServer.HandleListenerReady(const AHandler: ITcpServerHandler);
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

procedure TTcpEpollServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LEntries: array[0..7] of TPlatformPollEntry;
  LCount: Int32;
  LTimeoutMs: Int32;
  LErr: Int32;
  LI: Int32;
  LTarget: TTcpEpollPollSessionTarget;
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
      raise ENetworkError.Create('tcp epoll poller create failed (' + IntToStr(LErr) + ')');
    FPollerReady := True;

    LErr := platform_poller_enable_wake(FPoller, WAKE_USERDATA);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp epoll poller wake enable failed (' +
        IntToStr(LErr) + ')');

    LErr := platform_poller_add(FPoller,
      Int32(FListenerSocketRuntime.NativeSocketHandle),
      [peReadable], nil);
    if LErr <> 0 then
      raise ENetworkError.Create('tcp epoll poller add failed (' + IntToStr(LErr) + ')');

    FRunning := True;
    try
      while FRunning do
      begin
        LTimeoutMs := ComputePollTimeoutMs;
        LErr := platform_poller_wait(FPoller, @LEntries[0], SizeOf(LEntries),
          LTimeoutMs,
          LCount);
        if LErr <> 0 then
        begin
          if not FRunning then
            Break;
          raise ENetworkError.Create('tcp epoll poller wait failed (' + IntToStr(LErr) + ')');
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
          LTarget := TTcpEpollPollSessionTarget(LEntries[LI].UserData);
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
      FPendingCompletionCount := 0;
      FPollTargetCount := 0;
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

procedure TTcpEpollServer.Shutdown;
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

function TTcpEpollServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTcpEpollServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function NewTcpEpollServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := TTcpEpollServer.Create(AOptions);
end;

end.
