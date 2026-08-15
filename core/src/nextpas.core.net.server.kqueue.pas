unit nextpas.core.net.server.kqueue;
{**
 * @desc macOS/FreeBSD kqueue TCP server backend — 基于 io.reactor.kqueue 的
 *       事件驱动接线（B8 首片）。
 *
 *       形状与 Windows IOCP 后端一致：reactor 驱动 accept + 每连接
 *       「peek 就绪桥接」——AsyncRecv(MSG_PEEK, 1) 完成即代表可读但不消费
 *       数据，把 kqueue 完成语义桥接到 readiness 会话契约
 *       （poll-driven sessions 经 TryRead/TryWrite 推进），非 poll 会话
 *       回退 worker handoff。等待可写的会话由短定时重试（单 wait 不变式：
 *       peek 挂起 XOR 可写等待者）；deadline 唤醒经 TryCancelByContext
 *       取消挂起的 peek 后补发。
 *
 *       truth：仅 macOS/FreeBSD 编译（NEXTPAS_FORCE_HOST_DARWIN 编译门禁）；
 *       runtime smoke 待真机（B8 后续）。Linux 上本分支不参与编译，
 *       仅能以源码/API 结构做静态对照。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpKqueueServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  nextpas.core.errors
  {$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  , nextpas.core.base.utils
  , nextpas.core.io.base
  , nextpas.core.io.reactor.kqueue
  , nextpas.core.net.base
  , nextpas.core.net.intf
  , nextpas.core.net.tcp
  , nextpas.core.net.server.runtime
  , nextpas.core.platform.io.base
  , nextpas.core.platform.posix.ffi
  , nextpas.core.platform.socket
  , nextpas.core.platform.socket.base
  , nextpas.core.time.base
  , nextpas.core.time.deadline
  , nextpas.core.thread
  , nextpas.core.text.conv
  {$ENDIF}
  ;

{$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}

const
  { POSIX MSG_PEEK=0x2（macOS 与 FreeBSD 均同值；posix ffi 未导出该常量）。 }
  KQ_MSG_PEEK = $02;
  { 可写等待者的重试节奏：内核发送缓冲在毫秒内排空，1ms 既不忙转也不拖延迟。 }
  KQUEUE_WRITABLE_RETRY_MS = 1;

type
  TTcpKqueueServer = class;

  { 每连接驱动：peek 完成即代表可读（数据仍在内核缓冲，TryRead 独占消费）。 }
  PKqueueConnDriver = ^TKqueueConnDriver;
  TKqueueConnDriver = record
    Server: TTcpKqueueServer;
    Target: TTcpServerPollSessionTarget;
    PeekByte: Byte;
    { deadline 唤醒要求取消挂起的 peek：其完成（含竞态数据）补发唤醒 }
    WakePending: Boolean;
  end;

  TTcpKqueueConnTask = class(TInterfacedObject)
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

  TTcpKqueueServer = class(TInterfacedObject, ITcpServer)
  private
    FOptions: TTcpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
    FListenerSocketRuntime: ITcpSocketRuntime;
    FConnWorkers: IThreadPool;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FSessionContext: ITcpServerSessionContext;
    FHandler: ITcpServerHandler;
    FReactor: TKqueueReactor;
    FReactorReady: Boolean;
    FAcceptArmed: Boolean;
    FWakeReadFd: Int32;
    FWakeWriteFd: Int32;
    FWakeByte: Byte;
    FConnDrivers: array of PKqueueConnDriver;
    procedure EnsureRuntimeContext;
    procedure ReleaseRuntimeContext;
    procedure EnableWake;
    procedure ArmAccept;
    procedure HandleAcceptDone(const AAccepted: PtrInt);
    procedure DispatchAcceptedConn(const AConn: ITcpStream);
    procedure DispatchAcceptedSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession);
    function TryRegisterCompletionRecvSession(const AConn: ITcpStream;
      const ASession: ITcpServerSession): Boolean;
    function ArmConnRecv(const ADriver: PKqueueConnDriver): Boolean;
    procedure HandleConnRecvDone(const ADriver: PKqueueConnDriver;
      const AResult: Int32);
    procedure AdvanceConnDriver(const ADriver: PKqueueConnDriver;
      const AEvents: TPlatformPollEvents);
    procedure RetryWritableWaiters;
    procedure WakeExpiredDeadlines;
    function ComputeWaitTimeoutMs: Int64;
    procedure AddConnDriver(const ADriver: PKqueueConnDriver);
    procedure RemoveConnDriver(const ADriver: PKqueueConnDriver);
    procedure CloseConnDriver(const ADriver: PKqueueConnDriver;
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

procedure KqueueServerAcceptCallback(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
begin
  if AContext = nil then
    Exit;
  TTcpKqueueServer(AContext).HandleAcceptDone(PtrInt(AResult));
end;

procedure KqueueServerConnRecvCallback(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LDriver: PKqueueConnDriver;
begin
  if AContext = nil then
    Exit;
  LDriver := PKqueueConnDriver(AContext);
  LDriver^.Server.HandleConnRecvDone(LDriver, AResult);
end;

procedure KqueueServerWakeCallback(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
var
  LServer: TTcpKqueueServer;
begin
  if AContext = nil then
    Exit;
  { 唤醒管道字节已由 reactor opRead 排空；仍运行则重挂读端供下轮 shutdown。 }
  LServer := TTcpKqueueServer(AContext);
  if LServer.IsRunning and LServer.FReactorReady and
     (LServer.FWakeReadFd >= 0) then
    LServer.FReactor.AsyncRead(LServer.FWakeReadFd, @LServer.FWakeByte, 1, -1,
      @KqueueServerWakeCallback, LServer);
end;

constructor TTcpKqueueConnTask.CreateForHandler(const AConn: ITcpStream;
  const AHandler: ITcpServerHandler;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  FConn := AConn;
  FHandler := AHandler;
  FSessionContext := ASessionContext;
  FSession := nil;
end;

constructor TTcpKqueueConnTask.CreateForSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
begin
  inherited Create;
  FConn := AConn;
  FHandler := nil;
  FSessionContext := nil;
  FSession := ASession;
end;

procedure TTcpKqueueConnTask.Run;
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

constructor TTcpKqueueServer.Create(const AOptions: TTcpServerOptions);
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
  FWakeReadFd := -1;
  FWakeWriteFd := -1;
  FConnDrivers := nil;
end;

destructor TTcpKqueueServer.Destroy;
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
  if FWakeWriteFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FWakeWriteFd);
    FWakeWriteFd := -1;
  end;
  if FWakeReadFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FWakeReadFd);
    FWakeReadFd := -1;
  end;
  inherited;
end;

procedure TTcpKqueueServer.EnsureRuntimeContext;
begin
  if FWorkerHandoff = nil then
  begin
    CreateTcpServerRuntimeContext(FWorkerHandoff, FSessionContext,
      FOptions.ShutdownTimeoutNs, FOptions.WorkerPoolSize);
    FConnWorkers := ThreadPool(FOptions.WorkerPoolSize);
  end;
end;

procedure TTcpKqueueServer.ReleaseRuntimeContext;
begin
  if FWorkerHandoff <> nil then
    FWorkerHandoff.Shutdown;
  FWorkerHandoff := nil;
  FSessionContext := nil;
  if FConnWorkers <> nil then
    FConnWorkers.Shutdown;
  FConnWorkers := nil;
end;

function TTcpKqueueServer.RemoteFromSocket(
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

procedure TTcpKqueueServer.EnableWake;
var
  LFds: array[0..1] of Int32;
begin
  if FWakeReadFd >= 0 then
    Exit;
  LFds[0] := -1;
  LFds[1] := -1;
  if pipe(@LFds[0]) <> 0 then
    raise ENetworkError.Create('tcp kqueue wake pipe create failed');
  FWakeReadFd := LFds[0];
  FWakeWriteFd := LFds[1];
  { opRead 即排空；单次事件后由回调重挂（EV_ONESHOT 语义）。 }
  if not FReactor.AsyncRead(FWakeReadFd, @FWakeByte, 1, -1,
    @KqueueServerWakeCallback, Self) then
    raise ENetworkError.Create('tcp kqueue wake arm failed');
end;

procedure TTcpKqueueServer.ArmAccept;
var
  LFd: PtrInt;
begin
  if (not FRunning) or (not FReactorReady) or (FListenerSocketRuntime = nil) then
    Exit;
  if FAcceptArmed then
    Exit;
  LFd := PtrInt(FListenerSocketRuntime.NativeSocketHandle);
  if not FReactor.AsyncAccept(LFd, nil, nil, 0, @KqueueServerAcceptCallback,
    Self) then
    raise ENetworkError.Create('tcp kqueue AsyncAccept arm failed');
  FAcceptArmed := True;
end;

procedure TTcpKqueueServer.AddConnDriver(const ADriver: PKqueueConnDriver);
begin
  SetLength(FConnDrivers, Length(FConnDrivers) + 1);
  FConnDrivers[High(FConnDrivers)] := ADriver;
end;

procedure TTcpKqueueServer.RemoveConnDriver(const ADriver: PKqueueConnDriver);
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

procedure TTcpKqueueServer.CloseConnDriver(const ADriver: PKqueueConnDriver;
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

procedure TTcpKqueueServer.ReleaseConnDrivers;
var
  LI: SizeInt;
  LDriver: PKqueueConnDriver;
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

function TTcpKqueueServer.ArmConnRecv(const ADriver: PKqueueConnDriver): Boolean;
begin
  Result := False;
  if (not FRunning) or (not FReactorReady) then
    Exit;
  { MSG_PEEK 1 字节完成即代表可读：不消费数据，TryRead 独占后续读取。 }
  Result := FReactor.AsyncRecv(PtrInt(ADriver^.Target.SocketHandle),
    @ADriver^.PeekByte, 1, KQ_MSG_PEEK, @KqueueServerConnRecvCallback, ADriver);
end;

function TTcpKqueueServer.TryRegisterCompletionRecvSession(
  const AConn: ITcpStream; const ASession: ITcpServerSession): Boolean;
var
  LTarget: TTcpServerPollSessionTarget;
  LDriver: PKqueueConnDriver;
begin
  Result := False;
  if not FReactorReady then
    Exit;
  if not TryCreateTcpServerPollSessionTarget(AConn, ASession, LTarget) then
    Exit;
  { 初始关注必须是只读（会话从读请求开始；可写由 Advance 进入，经定时
    重试承载）。有限 wake deadline 由超时扫描承载。 }
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

procedure TTcpKqueueServer.HandleConnRecvDone(const ADriver: PKqueueConnDriver;
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
    { deadline 唤醒：被取消的 peek 以错误完成并作为空事件集补发
      （epoll expired-target 对等语义）；竞态数据胜出则按可读补发。 }
    if AResult > 0 then
      AdvanceConnDriver(ADriver, [peReadable])
    else
      AdvanceConnDriver(ADriver, []);
    Exit;
  end;
  if AResult <= 0 then
  begin
    { peek 返回 0 = 对端关闭（EOF），负数 = 错误 }
    CloseConnDriver(ADriver, tscoServer);
    Exit;
  end;
  AdvanceConnDriver(ADriver, [peReadable]);
end;

procedure TTcpKqueueServer.AdvanceConnDriver(const ADriver: PKqueueConnDriver;
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
  { 单 wait 不变式（IOCP W2-2 对等）：驱动要么挂起 peek，要么在可写
    等待集——复合等待折叠到可写侧，由定时循环重试。 }
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
  { 空等待且有有限 deadline：纯休眠会话——deadline 扫描唤醒它 }
  if (LNext = []) and (not ADriver^.Target.WakeDeadline.IsInfinite) then
  begin
    ADriver^.Target.SetCurrentEvents(LNext);
    Exit;
  end;
  { 空等待且无 deadline：无法推进——如实关闭 }
  CloseConnDriver(ADriver, tscoServer);
end;

procedure TTcpKqueueServer.RetryWritableWaiters;
var
  LI: SizeInt;
  LWaiters: array of PKqueueConnDriver;
begin
  { 先快照：Advance 可能关闭驱动并改写 FConnDrivers（swap-remove）。 }
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

procedure TTcpKqueueServer.WakeExpiredDeadlines;
var
  LI: SizeInt;
  LExpired: array of PKqueueConnDriver;
  LDriver: PKqueueConnDriver;
begin
  LExpired := nil;
  for LI := 0 to High(FConnDrivers) do
  begin
    LDriver := FConnDrivers[LI];
    if LDriver^.WakePending then
      Continue; { 取消在途——唤醒随其完成补发 }
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
      { 休眠 / 可写等待：无 peek 挂起——直接空事件集唤醒 }
      AdvanceConnDriver(LDriver, []);
      Continue;
    end;
    { peek 挂起：取消并把唤醒推迟到其完成；未命中说明 op 已完成，
      其完成即将分发并会重新推进会话。 }
    if FReactor.TryCancelByContext(LDriver) then
      LDriver^.WakePending := True;
  end;
end;

function TTcpKqueueServer.ComputeWaitTimeoutMs: Int64;
var
  LI: SizeInt;
  LBest: Int64;
  LMs: Int64;
  LDeadline: TDeadline;
  LRemaining: TDuration;
begin
  { min(可写重试节奏, 最近有限 wake deadline)——epoll ComputePollTimeoutMs 对等 }
  LBest := -1;
  for LI := 0 to High(FConnDrivers) do
  begin
    if peWritable in FConnDrivers[LI]^.Target.CurrentEvents then
      if (LBest < 0) or (LBest > KQUEUE_WRITABLE_RETRY_MS) then
        LBest := KQUEUE_WRITABLE_RETRY_MS;
    if FConnDrivers[LI]^.WakePending then
      Continue; { deadline 已处理——等待取消包 }
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
    end;
    if (LBest < 0) or (LMs < LBest) then
      LBest := LMs;
  end;
  Result := LBest; { -1 = 无限阻塞 }
end;

procedure TTcpKqueueServer.DispatchAcceptedSession(const AConn: ITcpStream;
  const ASession: ITcpServerSession);
var
  LTask: TTcpKqueueConnTask;
begin
  if AConn = nil then
    Exit;
  if not FRunning then
  begin
    CloseServerOwnedTcpConn(AConn);
    Exit;
  end;

  LTask := TTcpKqueueConnTask.CreateForSession(AConn, ASession);
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

procedure TTcpKqueueServer.DispatchAcceptedConn(const AConn: ITcpStream);
var
  LTask: TTcpKqueueConnTask;
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
    { 会话在 completion-recv 守卫之外（初始关注非只读 / 无 poll 形状）——
      worker handoff。 }
    DispatchAcceptedSession(AConn, LSession);
    Exit;
  end;

  LTask := TTcpKqueueConnTask.CreateForHandler(AConn, FHandler, FSessionContext);
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

procedure TTcpKqueueServer.HandleAcceptDone(const AAccepted: PtrInt);
var
  LSock: TPlatformSocket;
  LConn: ITcpStream;
begin
  FAcceptArmed := False;

  if AAccepted < 0 then
  begin
    if FRunning then
      ArmAccept;
    Exit;
  end;

  LSock.Value := PtrUInt(AAccepted);

  if not FRunning then
  begin
    platform_socket_close(LSock);
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

procedure TTcpKqueueServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LRuntimeContextReady: Boolean;
  LWaitMs: Int64;
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

    FReactor := TKqueueReactor.Create(64);
    if not FReactor.IsValid then
      raise ENetworkError.Create('tcp kqueue reactor create failed');
    FReactorReady := True;

    FHandler := AHandler;
    FRunning := True;
    try
      LRuntimeContextReady := False;
      EnableWake;
      ArmAccept;
      { 事件循环：分发 kqueue 事件；超时则扫描 deadline + 重试可写等待。
        Shutdown 经唤醒管道打断无限阻塞（PollWait(-1)）。 }
      while FRunning do
      begin
        LWaitMs := ComputeWaitTimeoutMs;
        if FReactor.PollWait(LWaitMs) > 0 then
          Continue;
        WakeExpiredDeadlines;
        RetryWritableWaiters;
      end;
    finally
      FRunning := False;
      FAcceptArmed := False;
      FHandler := nil;
      ReleaseRuntimeContext;
      if FReactorReady then
      begin
        { Close 以负错误触发挂起 peek 回调——存活驱动经 HandleConnRecvDone
          收尾后由 ReleaseConnDrivers 兜底。 }
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
    if FWakeWriteFd >= 0 then
    begin
      nextpas.core.platform.posix.ffi.close(FWakeWriteFd);
      FWakeWriteFd := -1;
    end;
    if FWakeReadFd >= 0 then
    begin
      nextpas.core.platform.posix.ffi.close(FWakeReadFd);
      FWakeReadFd := -1;
    end;
  end;
end;

procedure TTcpKqueueServer.Shutdown;
begin
  FRunning := False;
  if FReactorReady and (FWakeWriteFd >= 0) then
  begin
    FWakeByte := 1;
    nextpas.core.platform.posix.ffi.write(FWakeWriteFd, @FWakeByte, 1);
  end;
  if FListener <> nil then
    FListener.Close;
  if FWorkerHandoff <> nil then
    FWorkerHandoff.Shutdown;
end;

function TTcpKqueueServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTcpKqueueServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function NewTcpKqueueServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := TTcpKqueueServer.Create(AOptions);
end;

{$ELSE}

function NewTcpKqueueServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := nil;
  raise ENotSupportedError.Create('tcp kqueue backend requires macOS or FreeBSD');
end;

{$ENDIF}

end.