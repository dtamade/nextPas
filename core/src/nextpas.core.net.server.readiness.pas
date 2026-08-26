unit nextpas.core.net.server.readiness;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.net.base, nextpas.core.net.intf, nextpas.core.net.server.base, nextpas.core.net.server.intf;

function NewTcpReadinessServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses nextpas.core.base.utils, nextpas.core.errors, nextpas.core.thread, nextpas.core.time.base, nextpas.core.time.deadline, nextpas.core.platform.io.base, nextpas.core.platform.io, nextpas.core.net.tcp, nextpas.core.net.server.runtime, nextpas.core.text.conv;

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

  TTcpReadinessServer = class(TInterfacedObject, ITcpServer,
    ITcpServerHijackMigration)
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
    procedure ReleaseRuntimeContext;
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
    procedure EnqueueCompletion(const ATicket: ITcpServerPollTargetTicket;
      const ACompletion: ITcpServerWorkCompletion;
      const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
    function IsTargetRegistered(const ATarget: TTcpServerPollSessionTarget): Boolean;
    procedure DrainPendingCompletions;
    procedure ReleaseRegisteredPollTargets;
    procedure WakeReactor;
    procedure HandlePollTarget(const ATarget: TTcpServerPollSessionTarget;
      const AEvents: TPlatformPollEvents);
    procedure HandleListenerReady(const AHandler: ITcpServerHandler);
    procedure ExecuteMigration(const ATicket: ITcpServerPollTargetTicket;
      const AConn: ITcpStream; const ANewSession: ITcpServerSession);
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
    CreateTcpServerRuntimeContext(FWorkerHandoff, LUnusedContext, 0,
      FOptions.WorkerPoolSize);
    FConnWorkers := ThreadPool(FOptions.WorkerPoolSize);
  end;
end;

procedure TTcpReadinessServer.ReleaseRuntimeContext;
begin
  if FWorkerHandoff <> nil then
    FWorkerHandoff.Shutdown;
  DrainPendingCompletions;
  FWorkerHandoff := nil;
  FCompletionQueue.Clear;
  if FConnWorkers <> nil then
    FConnWorkers.Shutdown;
  FConnWorkers := nil;
end;

function TTcpReadinessServer.CreateSessionContext: TTcpServerPollSessionContext;
begin
  Result := TTcpServerPollSessionContext.Create(FWorkerHandoff,
    @EnqueueCompletion, @WakeReactor, Self);
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
  LThisRound: Int32;
begin
  LExpired := FTargetRegistry.CollectExpiredTargets;
  if Length(LExpired) = 0 then
    Exit;
  { 限批清理: 与限批 accept 同理, 到期风暴(万级连接同批到期)若一轮全部
    处理会独占事件循环, active 连接延迟飙升。每轮限批, 剩余目标因
    min 缓存已过期使下轮 poll 超时为 0 立即续清, 吞吐不减。 }
  LThisRound := 0;
  for LI := 0 to SizeUInt(Length(LExpired)) - 1 do
  begin
    if LThisRound >= 512 then
      Break;
    Inc(LThisRound);
    HandlePollTarget(LExpired[LI], []);
  end;
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
  try
    if not TryCreateTcpServerSession(AHandler, AConn, LContext, LSession) then
      LSession := nil;
  except
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;
  if LSession <> nil then
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
  LAddedToPoller: Boolean;
begin
  Result := False;
  LTarget := nil;
  LAddedToPoller := False;
  try
    if not TryCreateTcpServerPollSessionTarget(AConn, ASession, LTarget) then
      Exit(False);
    if LTarget.CurrentEvents <> [] then
    begin
      LErr := platform_poller_add(FPoller, LTarget.SocketHandle,
        LTarget.CurrentEvents, LTarget);
      if LErr <> 0 then
        raise ENetworkError.Create('tcp readiness poller add conn failed (' +
          IntToStr(LErr) + ')');
      LAddedToPoller := True;
    end;
    AContext.BindTarget(LTarget);
    RegisterPollTarget(LTarget);
    Result := True;
  except
    if LTarget <> nil then
    begin
      if LAddedToPoller then
      begin
        LErr := platform_poller_remove(FPoller, LTarget.SocketHandle);
        if LErr <> 0 then
        begin
          RegisterPollTarget(LTarget);
          LTarget := nil;
        end;
      end;
      if LTarget <> nil then
        LTarget.Free;
    end;
    CloseServerOwnedTcpConn(AConn);
    raise;
  end;
end;

procedure TTcpReadinessServer.EnqueueCompletion(
  const ATicket: ITcpServerPollTargetTicket;
  const ACompletion: ITcpServerWorkCompletion;
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  FCompletionQueue.Enqueue(ATicket, ACompletion, AOutcome, AOwnership);
end;

function TTcpReadinessServer.IsTargetRegistered(
  const ATarget: TTcpServerPollSessionTarget): Boolean;
begin
  Result := FTargetRegistry.ContainsTarget(ATarget);
end;

procedure TTcpReadinessServer.DrainPendingCompletions;
var
  LItems: TTcpServerPollPendingCompletionArray;
  LI: SizeUInt;
  LTarget: TTcpServerPollSessionTarget;
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
    LTarget := nil;
    if (LItems[LI].TargetTicket <> nil) and
      LItems[LI].TargetTicket.ResolveTarget(LTarget) and
      (LTarget <> nil) and IsTargetRegistered(LTarget) then
      HandlePollTarget(LTarget, []);
  end;
end;

procedure TTcpReadinessServer.ReleaseRegisteredPollTargets;
var
  LTargets: TTcpServerPollSessionTargetArray;
  LI: SizeUInt;
begin
  LTargets := FTargetRegistry.Drain;
  if Length(LTargets) = 0 then
    Exit;
  for LI := 0 to SizeUInt(Length(LTargets)) - 1 do
  begin
    if LTargets[LI] = nil then
      Continue;
    try
      if LTargets[LI].CurrentEvents <> [] then
        platform_poller_remove(FPoller, LTargets[LI].SocketHandle);
    except
    end;
    CloseServerOwnedTcpConn(LTargets[LI].Connection);
    LTargets[LI].Free;
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
  LDeadlineBefore: TDeadline;
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
    { 精确失效: HandleEvents 内部 Advance 可能改写 WakeDeadline
      (如 Infinite→有限), 真变了才让 min 缓存失效, 否则每轮无条件
      失效会让 ComputePollTimeoutMs 频繁 O(n) 重算(万级连接退化为 O(n²)) }
    LDeadlineBefore := ATarget.WakeDeadline;
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
        ATarget.SetCurrentEvents([]);
      end;
      UnregisterPollTarget(ATarget);
      if LOwnership = tscoServer then
        CloseServerOwnedTcpConn(ATarget.Connection);
      if LOwnership = tscoHandler then
        ATarget.RestoreBlocking;
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
    { Advance 可能已改变 session 的 WakeDeadline(如从 Infinite 转为有限):
      仅当实际变化时失效 min 缓存, 下轮查询惰性重算; 无变化则缓存
      O(1) 直达, 万级连接下避免每轮全扫退化 O(n²) }
    if ATarget.WakeDeadline <> LDeadlineBefore then
      FTargetRegistry.InvalidateMinDeadline;
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
  LThisRound: Int32;
begin
  { 限批 accept: 连接风暴时 accept 队列可积压成千上万, 若一次 accept 到
    EAGAIN 才放手, 单轮会长时间独占事件循环(8000 连实测单轮 ~400ms),
    active 连接延迟随之飙升。每轮限批后交还 poll 循环, 队列未空则
    level-triggered 会立即再次触发, 吞吐不减、轮间保持对其它连接的服务。 }
  LThisRound := 0;
  while FRunning and (LThisRound < 512) do
  begin
    LConn := nil;
    LAcceptResult := FListenerRuntime.TryAccept(LConn);
    if LAcceptResult = tarAccepted then
    begin
      Inc(LThisRound);
      DispatchAcceptedConn(AHandler, LConn);
      Continue;
    end;
    Break;
  end;
end;

procedure TTcpReadinessServer.ExecuteMigration(
  const ATicket: ITcpServerPollTargetTicket;
  const AConn: ITcpStream; const ANewSession: ITcpServerSession);
var
  LOldTarget: TTcpServerPollSessionTarget;
  LNewTarget: TTcpServerPollSessionTarget;
  LContext: TTcpServerPollSessionContext;
  LErr: Int32;
begin
  { reactor 线程执行（经 completion 队列）：把自己 poll 注册摘除、以新会话重挂。
    摘旧：不 RestoreBlocking、不关连接——连接与新会话一体；旧 ticket 随后
    detach，http 完成回调 ResolveTarget 失败即静默让位，不会 RestoreBlocking
    破坏新会话的非阻塞 socket。
    连接级上下文跨迁移复用：新 target 重绑同一 context（worker 推送通道
    经 context 的 handoff ticket 解析，迁移后仍指向新会话）。 }
  LOldTarget := nil;
  if (ATicket = nil) or (not ATicket.ResolveTarget(LOldTarget)) or
    (LOldTarget = nil) or (not IsTargetRegistered(LOldTarget)) then
    Exit;
  LNewTarget := nil;
  LContext := nil;
  try
    if LOldTarget.CurrentEvents <> [] then
    begin
      LErr := platform_poller_remove(FPoller, LOldTarget.SocketHandle);
      if LErr <> 0 then
        raise ENetworkError.Create('tcp readiness poller remove (hijack migrate) failed (' +
          IntToStr(LErr) + ')');
      LOldTarget.SetCurrentEvents([]);
    end;
    LContext := LOldTarget.Context;
    UnregisterPollTarget(LOldTarget);
    LOldTarget.DetachTicket;
    LOldTarget.Free;
    LOldTarget := nil;

    if not TryCreateTcpServerPollSessionTarget(AConn, ANewSession, LNewTarget) then
    begin
      CloseServerOwnedTcpConn(AConn);
      Exit;
    end;
    if LContext = nil then
      LContext := CreateSessionContext;
    LContext.BindTarget(LNewTarget);
    RegisterPollTarget(LNewTarget);
    if LNewTarget.CurrentEvents <> [] then
    begin
      LErr := platform_poller_add(FPoller, LNewTarget.SocketHandle,
        LNewTarget.CurrentEvents, LNewTarget);
      if LErr <> 0 then
        raise ENetworkError.Create('tcp readiness poller add (hijack migrate) failed (' +
          IntToStr(LErr) + ')');
    end;
    { 迁移启动脉冲：hijack 连接可能有 http 解析残留的字节（prepend 前缀，
      socket 上无新数据，epoll 不会事件化），立即调度一次可读推进让其
      进入会话。无残留时 Advance 返回 WouldBlock，幂等地回到等待。 }
    HandlePollTarget(LNewTarget, [peReadable]);
    LNewTarget := nil;
  except
    on E: Exception do
    begin
      { 迁移失败：摘除新 target、关闭连接，避免残留半挂状态。 }
      if LNewTarget <> nil then
      begin
        UnregisterPollTarget(LNewTarget);
        LNewTarget.Free;
      end;
      CloseServerOwnedTcpConn(AConn);
      raise;
    end;
  end;
end;

procedure TTcpReadinessServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LEntries: array[0..255] of TPlatformPollEntry;
  LCount: Int32;
  LTimeoutMs: Int32;
  LErr: Int32;
  LI: Int32;
  LTarget: TTcpServerPollSessionTarget;
  LSetupComplete: Boolean;
  LRuntimeContextReady: Boolean;
begin
  if AHandler = nil then
    raise EArgumentError.Create('tcp server handler must not be nil');

  LRuntimeContextReady := False;
  EnsureRuntimeContext;
  LRuntimeContextReady := True;
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

    LSetupComplete := False;
    try
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
      LSetupComplete := True;
    finally
      if (not LSetupComplete) and FPollerReady then
      begin
        platform_poller_close(FPoller);
        FPollerReady := False;
        ReleaseRuntimeContext;
        LRuntimeContextReady := False;
      end;
    end;

    FRunning := True;
    try
      LRuntimeContextReady := False;
      while FRunning do
      begin
        LTimeoutMs := ComputePollTimeoutMs;
        LErr := platform_poller_wait(FPoller, @LEntries[0], Length(LEntries),
          LTimeoutMs,
          LCount);
        if LErr <> 0 then
        begin
          { EINTR：信号中断属常态（调试器/探针/SIGCHLD），重试本轮；
            截止会话由 HandleExpiredPollTargets 兜底，不因信号丢拍 }
          if LErr = 4 then  { ESysEINTR，与 io.reactor.epoll 同款局部常量 }
            Continue;
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
          if IsTargetRegistered(LTarget) then
            HandlePollTarget(LTarget, LEntries[LI].REvents);
        end;
        HandleExpiredPollTargets;
      end;
    finally
      FRunning := False;
      ReleaseRuntimeContext;
      ReleaseRegisteredPollTargets;
      if FPollerReady then
      begin
        platform_poller_close(FPoller);
        FPollerReady := False;
      end;
    end;
  finally
    if LRuntimeContextReady then
      ReleaseRuntimeContext;
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
