unit nextpas.core.net.server.runtime;

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.net.intf, nextpas.core.net.server.base, nextpas.core.net.server.intf, nextpas.core.sync.intf, nextpas.core.platform.io.base, nextpas.core.time.deadline, nextpas.core.lockfree.mpsc, nextpas.core.collections.hashmap;

type
  TTcpServerPollSessionTarget = class;
  ITcpServerPollTargetTicket = interface;
  TTcpServerPollSessionTargetArray = array of TTcpServerPollSessionTarget;

  { worker→reactor 帧推送类型（IWebSocketFrameWorkerPush） }
  TTcpServerFramePushKind = (
    fpSendText,
    fpSendBinary,
    fpSendClose
  );

  { readiness 服务器实现：在 reactor 线程执行 hijack 连接迁移
    （ITcpServerSessionContext.HandoffHijackedConn 语义）。 }
  ITcpServerHijackMigration = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000019}']
    procedure ExecuteMigration(const ATicket: ITcpServerPollTargetTicket;
      const AConn: ITcpStream; const ANewSession: ITcpServerSession);
  end;

  TTcpServerPollCompletionEnqueueProc = procedure(
    const ATicket: ITcpServerPollTargetTicket;
    const ACompletion: ITcpServerWorkCompletion;
    const AOutcome: TTcpServerWorkOutcome;
    const AOwnership: TTcpServerConnOwnership) of object;
  TTcpServerPollWakeProc = procedure of object;

  TTcpServerPollPendingCompletion = record
    TargetTicket: ITcpServerPollTargetTicket;
    Completion: ITcpServerWorkCompletion;
    Outcome: TTcpServerWorkOutcome;
    Ownership: TTcpServerConnOwnership;
  end;
  TTcpServerPollPendingCompletionArray = array of TTcpServerPollPendingCompletion;

  ITcpServerPollTargetTicket = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000012}']
    function ResolveTarget(out ATarget: TTcpServerPollSessionTarget): Boolean;
    procedure DetachTarget;
  end;

  TTcpServerPollSessionContext = class;

  TTcpServerPollSessionTarget = class
  private
    FConn: ITcpStream;
    FSocketRuntime: ITcpSocketRuntime;
    FSession: ITcpServerSession;
    FPollSession: ITcpServerPollDrivenSession;
    FDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
    FEvents: TPlatformPollEvents;
    FWakeDeadline: TDeadline;
    FTicket: ITcpServerPollTargetTicket;
    { 服务器 shutdown drain 标记：reactor 线程已对本 target 发起过
      BeginShutdownClose（防 drain 阶段逐轮重扫时重复发起）。 }
    FShutdownClose: Boolean;
    { 连接级上下文（worker handoff / hijack 迁移载体）。迁移（hijack）时
      复用同一 context 并重绑新 target 的 ticket，保证 worker 推送通道
      跨会话迁移保持有效。强引用不成环：ticket 对 target 是弱引用。 }
    FContext: ITcpServerSessionContext;
    procedure RefreshWakeDeadline;
  public
    constructor Create(const AConn: ITcpStream;
      const ASocketRuntime: ITcpSocketRuntime;
      const ASession: ITcpServerSession;
      const APollSession: ITcpServerPollDrivenSession;
      const AInitialEvents: TPlatformPollEvents;
      const AInitialWakeDeadline: TDeadline);
    destructor Destroy; override;
    function SocketHandle: PtrUInt;
    function CurrentEvents: TPlatformPollEvents;
    procedure SetCurrentEvents(const AEvents: TPlatformPollEvents);
    function WakeDeadline: TDeadline;
    function Connection: ITcpStream;
    function PollSession: ITcpServerSession;
    function TargetTicket: ITcpServerPollTargetTicket;
    procedure DetachTicket;
    procedure RestoreBlocking;
    function HandleEvents(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    procedure SetContext(const AContext: ITcpServerSessionContext);
    function Context: TTcpServerPollSessionContext;
    { shutdown drain 标记（见 FShutdownClose）：drain 发启与收尾判定共用 }
    procedure MarkShutdownClose;
    function IsShutdownClose: Boolean;
  end;

  TTcpServerPollWorkerHandoff = class(TInterfacedObject,
    ITcpServerWorkerHandoff)
  private
    FBaseHandoff: ITcpServerWorkerHandoff;
    FTargetTicket: ITcpServerPollTargetTicket;
    FEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
    FWake: TTcpServerPollWakeProc;
  public
    constructor Create(const ABaseHandoff: ITcpServerWorkerHandoff;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc);
    procedure BindTarget(const ATarget: TTcpServerPollSessionTarget);
    function TargetTicket: ITcpServerPollTargetTicket;
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
    procedure Shutdown;
  end;

  TTcpServerPollSessionContext = class(TInterfacedObject,
    ITcpServerSessionContext, IWebSocketFrameWorkerPush)
  private
    FWorkerHandoffRef: ITcpServerWorkerHandoff;
    FWorkerHandoff: TTcpServerPollWorkerHandoff;
    FEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
    FWake: TTcpServerPollWakeProc;
    FMigration: ITcpServerHijackMigration;
    { hijack 迁移登记（HandoffHijackedConn 可 worker 线程调）：登记后由
      reactor 线程（poll 让位完成时）经 SubmitHijackMigration 提交执行。
      FMigrationArmed 用 InterlockedExchange 保证跨线程可见性。 }
    FMigrationArmed: LongInt;
    FPendingConn: ITcpStream;
    FPendingSession: ITcpServerSession;
    procedure SubmitFramePush(const AKind: TTcpServerFramePushKind;
      const AText: string; const APayload: array of Byte;
      const ACode: UInt16; const AReason: string);
  public
    constructor Create(const ABaseHandoff: ITcpServerWorkerHandoff;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc;
      const AMigration: ITcpServerHijackMigration);
    procedure BindTarget(const ATarget: TTcpServerPollSessionTarget);
    function WorkerHandoff: ITcpServerWorkerHandoff;
    function HandoffHijackedConn(const AConn: ITcpStream;
      const ANewSession: ITcpServerSession): Boolean;
    function SubmitHijackMigration: Boolean;
    procedure SubmitSendText(const AText: string);
    procedure SubmitSendTexts(const ATexts: array of string);
    procedure SubmitSendBinary(const APayload: array of Byte);
    procedure SubmitSendClose(const ACode: UInt16; const AReason: string);
  end;

  { hijack 连接迁移 completion：reactor 线程执行（见 ITcpServerSessionContext.
    HandoffHijackedConn / ITcpServerHijackMigration 语义）。 }
  TTcpServerHijackMigrationCompletion = class(TInterfacedObject,
    ITcpServerWorkCompletion)
  private
    FTargetTicket: ITcpServerPollTargetTicket;
    FConn: ITcpStream;
    FNewSession: ITcpServerSession;
    FMigration: ITcpServerHijackMigration;
  public
    constructor Create(const ATicket: ITcpServerPollTargetTicket;
      const AConn: ITcpStream; const ANewSession: ITcpServerSession;
      const AMigration: ITcpServerHijackMigration);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  { worker→reactor 帧推送 completion：reactor 线程经 ticket 解析目标会话发送。 }
  TTcpServerFramePushCompletion = class(TInterfacedObject,
    ITcpServerWorkCompletion)
  private
    FTargetTicket: ITcpServerPollTargetTicket;
    FKind: TTcpServerFramePushKind;
    FText: string;
    FPayload: array of Byte;
    FCode: UInt16;
    FReason: string;
  public
    constructor Create(const ATicket: ITcpServerPollTargetTicket;
      const AKind: TTcpServerFramePushKind; const AText: string;
      const APayload: array of Byte; const ACode: UInt16; const AReason: string);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  { 批量发文本帧 completion：一次入队+唤醒承载 N 帧，reactor 循环逐帧
    SendText（省控制面：completion 分配/MPSC 入队/FWake 各 N-1 次）。 }
  TTcpServerFramePushBatchCompletion = class(TInterfacedObject,
    ITcpServerWorkCompletion)
  private
    FTargetTicket: ITcpServerPollTargetTicket;
    FTexts: array of string;
  public
    constructor Create(const ATicket: ITcpServerPollTargetTicket;
      const ATexts: array of string);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  { H5-1: T1 MPSC of Pointer → heap PCompletionNode (managed interfaces on node).
    N worker Enqueue / single reactor Drain. See charter-h5-net-completion-mpsc. }
  TTcpServerPollCompletionQueue = class
  private
    type
      TPointerMpsc = specialize TMpscQueueImpl<Pointer>;
    var
      FQueue: TPointerMpsc;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const ATicket: ITcpServerPollTargetTicket;
      const ACompletion: ITcpServerWorkCompletion;
      const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
    function Drain: TTcpServerPollPendingCompletionArray;
    procedure Clear;
  end;

  TTcpServerPollTargetRegistry = class
  private
    type
      { target 指针 → FItems 槽位; 只比较指针值, 不读 target 字段:
        批处理中已 Free 的 target 指针仍可能出现在本批事件条目里, 防悬垂 }
      TIndexMap = specialize THashMap<Pointer, SizeUInt>;
    var
      FItems: TTcpServerPollSessionTargetArray;
      FCount: SizeUInt;
      FIndexMap: TIndexMap;
      { min WakeDeadline 缓存: FMinValid=False 时惰性全扫重算。
        常态(无 target 到期)下 ComputePollTimeoutMs/CollectExpiredTargets
        从每轮 O(n) 降为 O(1); 到期批处理在同轮循环内完成, 删除不触发重算 }
      FMinDeadline: TDeadline;
      FMinValid: Boolean;
    procedure RecomputeMinDeadline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterTarget(const ATarget: TTcpServerPollSessionTarget);
    procedure UnregisterTarget(const ATarget: TTcpServerPollSessionTarget);
    procedure InvalidateMinDeadline;
    function ContainsTarget(const ATarget: TTcpServerPollSessionTarget): Boolean;
    function ComputePollTimeoutMs: Int32;
    function CollectExpiredTargets: TTcpServerPollSessionTargetArray;
    { 快照全部已注册 target（副本；调用方不得持引用跨轮使用）：
      shutdown drain 发启时逐轮扫描。 }
    function Snapshot: TTcpServerPollSessionTargetArray;
    { 是否存在已标记 shutdown-close 的 target：drain 收尾判定（全部
      drain 完成 = 无标记 target 残留）。O(n) 扫描，仅 shutdown drain
      路径调用。 }
    function AnyShutdownClose: Boolean;
    function Drain: TTcpServerPollSessionTargetArray;
    procedure Clear;
  end;

procedure CreateTcpServerRuntimeContext(
  out AWorkerHandoff: ITcpServerWorkerHandoff;
  out ASessionContext: ITcpServerSessionContext;
  const AShutdownTimeoutNs: Int64 = 0;
  const AWorkerPoolSize: Integer = 0);
function TryCreateTcpServerSession(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext;
  out ASession: ITcpServerSession): Boolean;
function TryCreateTcpServerPollSessionTarget(const AConn: ITcpStream;
  const ASession: ITcpServerSession;
  out ATarget: TTcpServerPollSessionTarget): Boolean;
function ExecuteTcpServerSession(
  const ASession: ITcpServerSession): TTcpServerConnOwnership;
function ExecuteTcpServerConnHandler(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext): TTcpServerConnOwnership;
procedure CloseServerOwnedTcpConn(const AConn: ITcpStream);

implementation

uses nextpas.core.base.utils, nextpas.core.errors, nextpas.core.sync.mutex, nextpas.core.thread, nextpas.core.time.base, nextpas.core.net.server.ws.session;

{ registry O(1) 索引辅助: hash/equals 只操作指针值(不 deref),
  deadline 先后比较用剩余时长(同一时钟基准) }
function RegistryPtrHash(const AKey: Pointer): UInt32;
begin
  Result := HashOfPointer(AKey);
end;

function RegistryPtrEquals(const A, B: Pointer): Boolean;
begin
  Result := A = B;
end;

function RegistryDeadlineEarlier(const A, B: TDeadline): Boolean;
begin
  if A.IsInfinite then
    Exit(False);
  if B.IsInfinite then
    Exit(True);
  Result := A.Remaining.AsNanoseconds < B.Remaining.AsNanoseconds;
end;

type
  { Heap node so interfaces never enter T1 MPSC element type (unmanaged Pointer only). }
  PCompletionNode = ^TCompletionNode;
  TCompletionNode = record
    Item: TTcpServerPollPendingCompletion;
  end;

  TTcpServerWorkTask = class(TInterfacedObject)
  private
    FWork: ITcpServerWork;
    FCompletion: ITcpServerWorkCompletion;
  public
    constructor Create(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion);
    procedure Run;
  end;

  TTcpServerDefaultWorkerHandoff = class(TInterfacedObject,
    ITcpServerWorkerHandoff)
  private
    FPool: IThreadPool;
    FMutex: IMutex;
    FShuttingDown: Boolean;
    FShutdownTimeoutNs: Int64;
  public
    constructor Create(const AShutdownTimeoutNs: Int64 = 0;
      const AWorkerPoolSize: Integer = 0);
    procedure Shutdown;
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
  end;

  TTcpServerDefaultSessionContext = class(TInterfacedObject,
    ITcpServerSessionContext, IWsServerShutdownRegistry)
  private
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FWsLock: IMutex;
    FWsNotifiers: array of IWsServerShutdownNotifier;
  public
    constructor Create(const AWorkerHandoff: ITcpServerWorkerHandoff);
    destructor Destroy; override;
    function WorkerHandoff: ITcpServerWorkerHandoff;
    function HandoffHijackedConn(const AConn: ITcpStream;
      const ANewSession: ITcpServerSession): Boolean;
    function SubmitHijackMigration: Boolean;
    procedure RegisterShutdownNotifier(
      const ANotifier: IWsServerShutdownNotifier);
    procedure UnregisterShutdownNotifier(
      const ANotifier: IWsServerShutdownNotifier);
    procedure ShutdownAll(const ATimeoutNs: Int64);
  end;

  TTcpServerPollQueuedCompletion = class(TInterfacedObject,
    ITcpServerWorkCompletion)
  private
    FTargetTicket: ITcpServerPollTargetTicket;
    FInner: ITcpServerWorkCompletion;
    FEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
    FWake: TTcpServerPollWakeProc;
  public
    constructor Create(const ATicket: ITcpServerPollTargetTicket;
      const AInner: ITcpServerWorkCompletion;
      const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
      const AWake: TTcpServerPollWakeProc);
    procedure Complete(const AOutcome: TTcpServerWorkOutcome;
      const AOwnership: TTcpServerConnOwnership);
  end;

  TTcpServerPollTargetTicket = class(TInterfacedObject,
    ITcpServerPollTargetTicket)
  private
    FLock: IMutex;
    FTarget: TTcpServerPollSessionTarget;
  public
    constructor Create(const ATarget: TTcpServerPollSessionTarget);
    function ResolveTarget(out ATarget: TTcpServerPollSessionTarget): Boolean;
    procedure DetachTarget;
  end;

constructor TTcpServerPollTargetTicket.Create(
  const ATarget: TTcpServerPollSessionTarget);
begin
  inherited Create;
  FLock := nextpas.core.sync.mutex.TMutex.Create;
  FTarget := ATarget;
end;

function TTcpServerPollTargetTicket.ResolveTarget(
  out ATarget: TTcpServerPollSessionTarget): Boolean;
begin
  FLock.Acquire;
  try
    ATarget := FTarget;
    Result := ATarget <> nil;
  finally
    FLock.Release;
  end;
end;

procedure TTcpServerPollTargetTicket.DetachTarget;
begin
  FLock.Acquire;
  try
    FTarget := nil;
  finally
    FLock.Release;
  end;
end;

constructor TTcpServerPollSessionTarget.Create(const AConn: ITcpStream;
  const ASocketRuntime: ITcpSocketRuntime; const ASession: ITcpServerSession;
  const APollSession: ITcpServerPollDrivenSession;
  const AInitialEvents: TPlatformPollEvents;
  const AInitialWakeDeadline: TDeadline);
begin
  inherited Create;
  FConn := AConn;
  FSocketRuntime := ASocketRuntime;
  FSession := ASession;
  FPollSession := APollSession;
  FEvents := AInitialEvents;
  if Supports(ASession, ITcpServerPollDrivenSessionWithDeadline,
    FDeadlineSession) then
    FWakeDeadline := AInitialWakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
  FTicket := TTcpServerPollTargetTicket.Create(Self);
end;

destructor TTcpServerPollSessionTarget.Destroy;
begin
  DetachTicket;
  FDeadlineSession := nil;
  FPollSession := nil;
  FSession := nil;
  FSocketRuntime := nil;
  FConn := nil;
  FContext := nil;
  inherited;
end;

function TTcpServerPollSessionTarget.SocketHandle: PtrUInt;
begin
  Result := FSocketRuntime.NativeSocketHandle;
end;

function TTcpServerPollSessionTarget.CurrentEvents: TPlatformPollEvents;
begin
  Result := FEvents;
end;

procedure TTcpServerPollSessionTarget.SetCurrentEvents(
  const AEvents: TPlatformPollEvents);
begin
  FEvents := AEvents;
end;

procedure TTcpServerPollSessionTarget.RefreshWakeDeadline;
begin
  if FDeadlineSession <> nil then
    FWakeDeadline := FDeadlineSession.WakeDeadline
  else
    FWakeDeadline := TDeadline.Infinite;
end;

function TTcpServerPollSessionTarget.WakeDeadline: TDeadline;
begin
  Result := FWakeDeadline;
end;

function TTcpServerPollSessionTarget.Connection: ITcpStream;
begin
  Result := FConn;
end;

function TTcpServerPollSessionTarget.PollSession: ITcpServerSession;
begin
  Result := FSession;
end;

function TTcpServerPollSessionTarget.TargetTicket: ITcpServerPollTargetTicket;
begin
  Result := FTicket;
end;

procedure TTcpServerPollSessionTarget.DetachTicket;
begin
  if FTicket <> nil then
    FTicket.DetachTarget;
end;

procedure TTcpServerPollSessionTarget.SetContext(
  const AContext: ITcpServerSessionContext);
begin
  FContext := AContext;
end;

function TTcpServerPollSessionTarget.Context: TTcpServerPollSessionContext;
begin
  Result := FContext as TTcpServerPollSessionContext;
end;

procedure TTcpServerPollSessionTarget.RestoreBlocking;
begin
  FSocketRuntime.SetBlocking(True);
end;

function TTcpServerPollSessionTarget.HandleEvents(
  const AEvents: TPlatformPollEvents; out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  Result := FPollSession.Advance(AEvents, ANextEvents, AOwnership);
  RefreshWakeDeadline;
end;

procedure TTcpServerPollSessionTarget.MarkShutdownClose;
begin
  FShutdownClose := True;
end;

function TTcpServerPollSessionTarget.IsShutdownClose: Boolean;
begin
  Result := FShutdownClose;
end;

constructor TTcpServerPollQueuedCompletion.Create(
  const ATicket: ITcpServerPollTargetTicket;
  const AInner: ITcpServerWorkCompletion;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FTargetTicket := ATicket;
  FInner := AInner;
  FEnqueueCompletion := AEnqueueCompletion;
  FWake := AWake;
end;

procedure TTcpServerPollQueuedCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if Assigned(FEnqueueCompletion) then
  begin
    FEnqueueCompletion(FTargetTicket, FInner, AOutcome, AOwnership);
    if Assigned(FWake) then
      FWake();
  end
  else if FInner <> nil then
    FInner.Complete(AOutcome, AOwnership);
  FInner := nil;
  FTargetTicket := nil;
end;

{ TTcpServerHijackMigrationCompletion }

constructor TTcpServerHijackMigrationCompletion.Create(
  const ATicket: ITcpServerPollTargetTicket;
  const AConn: ITcpStream; const ANewSession: ITcpServerSession;
  const AMigration: ITcpServerHijackMigration);
begin
  inherited Create;
  FTargetTicket := ATicket;
  FConn := AConn;
  FNewSession := ANewSession;
  FMigration := AMigration;
end;

procedure TTcpServerHijackMigrationCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
begin
  if FMigration <> nil then
    FMigration.ExecuteMigration(FTargetTicket, FConn, FNewSession);
  FMigration := nil;
  FNewSession := nil;
  FConn := nil;
  FTargetTicket := nil;
end;

{ TTcpServerFramePushCompletion }

constructor TTcpServerFramePushCompletion.Create(
  const ATicket: ITcpServerPollTargetTicket;
  const AKind: TTcpServerFramePushKind; const AText: string;
  const APayload: array of Byte; const ACode: UInt16; const AReason: string);
begin
  inherited Create;
  FTargetTicket := ATicket;
  FKind := AKind;
  FText := AText;
  SetLength(FPayload, Length(APayload));
  if Length(APayload) > 0 then
    Move(APayload[0], FPayload[0], Length(APayload));
  FCode := ACode;
  FReason := AReason;
end;

procedure TTcpServerFramePushCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
var
  LTarget: TTcpServerPollSessionTarget;
  LSession: IWebSocketFrameSession;
begin
  LTarget := nil;
  LSession := nil;
  if (FTargetTicket <> nil) and FTargetTicket.ResolveTarget(LTarget) and
    (LTarget <> nil) then
  begin
    if Supports(LTarget.PollSession, IWebSocketFrameSession, LSession) then
    begin
      case FKind of
        fpSendText:  LSession.SendText(FText);
        fpSendBinary: LSession.SendBinary(FPayload);
        fpSendClose: LSession.SendClose(FCode, FReason);
      end;
    end;
  end;
  LSession := nil;
  LTarget := nil;
  FTargetTicket := nil;
end;

{ TTcpServerFramePushBatchCompletion }

constructor TTcpServerFramePushBatchCompletion.Create(
  const ATicket: ITcpServerPollTargetTicket;
  const ATexts: array of string);
var
  LI: Integer;
begin
  inherited Create;
  FTargetTicket := ATicket;
  SetLength(FTexts, Length(ATexts));
  for LI := 0 to High(ATexts) do
    FTexts[LI] := ATexts[LI];
end;

procedure TTcpServerFramePushBatchCompletion.Complete(
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
var
  LTarget: TTcpServerPollSessionTarget;
  LSession: IWebSocketFrameSession;
begin
  LTarget := nil;
  LSession := nil;
  if (FTargetTicket <> nil) and FTargetTicket.ResolveTarget(LTarget) and
    (LTarget <> nil) then
  begin
    if Supports(LTarget.PollSession, IWebSocketFrameSession, LSession) then
      { 批量写：一次 EnqueueWire 拼接 + 单次 FlushOutbound 冲刷（省 N-1
        次冲刷调用/syscall——写侧批量化，B18）。 }
      LSession.SendTexts(FTexts);
  end;
  LSession := nil;
  LTarget := nil;
  FTargetTicket := nil;
  FTexts := nil;
end;

constructor TTcpServerPollWorkerHandoff.Create(
  const ABaseHandoff: ITcpServerWorkerHandoff;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc);
begin
  inherited Create;
  FBaseHandoff := ABaseHandoff;
  FTargetTicket := nil;
  FEnqueueCompletion := AEnqueueCompletion;
  FWake := AWake;
end;

procedure TTcpServerPollWorkerHandoff.BindTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  if ATarget <> nil then
    FTargetTicket := ATarget.TargetTicket
  else
    FTargetTicket := nil;
end;

function TTcpServerPollWorkerHandoff.TargetTicket: ITcpServerPollTargetTicket;
begin
  Result := FTargetTicket;
end;

function TTcpServerPollWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LCompletion: ITcpServerWorkCompletion;
begin
  if (FTargetTicket <> nil) and Assigned(FEnqueueCompletion) then
    LCompletion := TTcpServerPollQueuedCompletion.Create(FTargetTicket,
      ACompletion, FEnqueueCompletion, FWake)
  else
    LCompletion := ACompletion;
  Result := FBaseHandoff.Submit(AWork, LCompletion);
end;

procedure TTcpServerPollWorkerHandoff.Shutdown;
begin
  FBaseHandoff.Shutdown;
end;

constructor TTcpServerPollSessionContext.Create(
  const ABaseHandoff: ITcpServerWorkerHandoff;
  const AEnqueueCompletion: TTcpServerPollCompletionEnqueueProc;
  const AWake: TTcpServerPollWakeProc;
  const AMigration: ITcpServerHijackMigration);
begin
  inherited Create;
  FWorkerHandoff := TTcpServerPollWorkerHandoff.Create(ABaseHandoff,
    AEnqueueCompletion, AWake);
  FWorkerHandoffRef := FWorkerHandoff;
  FEnqueueCompletion := AEnqueueCompletion;
  FWake := AWake;
  FMigration := AMigration;
end;

procedure TTcpServerPollSessionContext.BindTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  FWorkerHandoff.BindTarget(ATarget);
  if ATarget <> nil then
    ATarget.SetContext(Self);
end;

function TTcpServerPollSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoffRef;
end;

function TTcpServerPollSessionContext.HandoffHijackedConn(
  const AConn: ITcpStream;
  const ANewSession: ITcpServerSession): Boolean;
begin
  Result := False;
  if (FWorkerHandoff = nil) or (FMigration = nil) then
    Exit;
  if (FWorkerHandoff.TargetTicket = nil) or (AConn = nil) or
    (ANewSession = nil) then
    Exit;
  if not Assigned(FEnqueueCompletion) then
    Exit;
  if InterlockedExchange(FMigrationArmed, 1) <> 0 then
    Exit;
  { 登记迁移：http 让位完成后经 SubmitHijackMigration（reactor 线程）提交，确保
    迁移 completion 排在让位 completion 之后、旧会话完成回调前执行。 }
  FPendingConn := AConn;
  FPendingSession := ANewSession;
  Result := True;
end;

function TTcpServerPollSessionContext.SubmitHijackMigration: Boolean;
begin
  Result := False;
  if InterlockedExchange(FMigrationArmed, 0) = 0 then
    Exit;
  { reactor 线程执行（提交在让位 completion 之后）：摘旧会话 poll 注册 →
    新会话重挂。 }
  FEnqueueCompletion(FWorkerHandoff.TargetTicket,
    TTcpServerHijackMigrationCompletion.Create(
      FWorkerHandoff.TargetTicket, FPendingConn, FPendingSession, FMigration),
    tswoCompleted, tscoHandler);
  FPendingConn := nil;
  FPendingSession := nil;
  if Assigned(FWake) then
    FWake();
  Result := True;
end;

procedure TTcpServerPollSessionContext.SubmitFramePush(
  const AKind: TTcpServerFramePushKind; const AText: string;
  const APayload: array of Byte; const ACode: UInt16; const AReason: string);
begin
  if (FWorkerHandoff = nil) or (FWorkerHandoff.TargetTicket = nil) then
    Exit;
  if not Assigned(FEnqueueCompletion) then
    Exit;
  { 发帧 completion 在 reactor 线程执行，经 ticket 解析目标会话发送。 }
  FEnqueueCompletion(FWorkerHandoff.TargetTicket,
    TTcpServerFramePushCompletion.Create(FWorkerHandoff.TargetTicket,
      AKind, AText, APayload, ACode, AReason),
    tswoCompleted, tscoHandler);
  if Assigned(FWake) then
    FWake();
end;

procedure TTcpServerPollSessionContext.SubmitSendText(const AText: string);
begin
  SubmitFramePush(fpSendText, AText, [], 0, '');
end;

procedure TTcpServerPollSessionContext.SubmitSendTexts(
  const ATexts: array of string);
begin
  if (FWorkerHandoff = nil) or (FWorkerHandoff.TargetTicket = nil) then
    Exit;
  if not Assigned(FEnqueueCompletion) then
    Exit;
  if Length(ATexts) = 0 then
    Exit;
  { 整批一个 completion + 一次唤醒（与单帧 SubmitFramePush 同一入队/唤醒
    通道，控制面成本与帧数无关）。 }
  FEnqueueCompletion(FWorkerHandoff.TargetTicket,
    TTcpServerFramePushBatchCompletion.Create(FWorkerHandoff.TargetTicket,
      ATexts),
    tswoCompleted, tscoHandler);
  if Assigned(FWake) then
    FWake();
end;

procedure TTcpServerPollSessionContext.SubmitSendBinary(
  const APayload: array of Byte);
begin
  SubmitFramePush(fpSendBinary, '', APayload, 0, '');
end;

procedure TTcpServerPollSessionContext.SubmitSendClose(
  const ACode: UInt16; const AReason: string);
begin
  SubmitFramePush(fpSendClose, '', [], ACode, AReason);
end;

constructor TTcpServerPollCompletionQueue.Create;
begin
  inherited Create;
  FQueue := TPointerMpsc.Create;
end;

destructor TTcpServerPollCompletionQueue.Destroy;
var
  LPtr: Pointer;
  LNode: PCompletionNode;
begin
  if FQueue <> nil then
  begin
    FQueue.Close;
    while FQueue.TryDequeue(LPtr) do
    begin
      LNode := PCompletionNode(LPtr);
      LNode^.Item.TargetTicket := nil;
      LNode^.Item.Completion := nil;
      Dispose(LNode);
    end;
    FQueue.Free;
    FQueue := nil;
  end;
  inherited;
end;

procedure TTcpServerPollCompletionQueue.Enqueue(
  const ATicket: ITcpServerPollTargetTicket;
  const ACompletion: ITcpServerWorkCompletion;
  const AOutcome: TTcpServerWorkOutcome;
  const AOwnership: TTcpServerConnOwnership);
var
  LNode: PCompletionNode;
begin
  if ACompletion = nil then
    Exit;
  if FQueue = nil then
    Exit;

  New(LNode);
  LNode^.Item.TargetTicket := ATicket;
  LNode^.Item.Completion := ACompletion;
  LNode^.Item.Outcome := AOutcome;
  LNode^.Item.Ownership := AOwnership;
  if not FQueue.TryEnqueue(Pointer(LNode)) then
  begin
    LNode^.Item.TargetTicket := nil;
    LNode^.Item.Completion := nil;
    Dispose(LNode);
  end;
end;

function TTcpServerPollCompletionQueue.Drain: TTcpServerPollPendingCompletionArray;
var
  LPtr: Pointer;
  LNode: PCompletionNode;
  LCount: SizeUInt;
  LCap: SizeUInt;
begin
  Result := nil;
  if FQueue = nil then
    Exit;
  LCount := 0;
  LCap := 0;
  while FQueue.TryDequeue(LPtr) do
  begin
    LNode := PCompletionNode(LPtr);
    if LCount >= LCap then
    begin
      if LCap = 0 then
        LCap := 4
      else
        LCap := LCap * 2;
      SetLength(Result, LCap);
    end;
    Result[LCount] := LNode^.Item;
    LNode^.Item.TargetTicket := nil;
    LNode^.Item.Completion := nil;
    Dispose(LNode);
    Inc(LCount);
  end;
  if LCount <> LCap then
    SetLength(Result, LCount);
end;

procedure TTcpServerPollCompletionQueue.Clear;
begin
  Drain;
end;

constructor TTcpServerPollTargetRegistry.Create;
begin
  inherited Create;
  FIndexMap := TIndexMap.Create(16, @RegistryPtrHash, @RegistryPtrEquals);
  FMinDeadline := TDeadline.Infinite;
  FMinValid := False;
end;

destructor TTcpServerPollTargetRegistry.Destroy;
begin
  FIndexMap.Free;
  inherited Destroy;
end;

procedure TTcpServerPollTargetRegistry.RecomputeMinDeadline;
var
  LI: SizeUInt;
  LDeadline: TDeadline;
begin
  FMinDeadline := TDeadline.Infinite;
  for LI := 0 to FCount - 1 do
  begin
    LDeadline := FItems[LI].WakeDeadline;
    if LDeadline.IsInfinite then
      Continue;
    if FMinDeadline.IsInfinite or
       RegistryDeadlineEarlier(LDeadline, FMinDeadline) then
      FMinDeadline := LDeadline;
  end;
  FMinValid := True;
end;

procedure TTcpServerPollTargetRegistry.RegisterTarget(
  const ATarget: TTcpServerPollSessionTarget);
begin
  if FCount >= SizeUInt(Length(FItems)) then
    SetLength(FItems, FCount + 8);
  FItems[FCount] := ATarget;
  FIndexMap.AddOrAssign(Pointer(ATarget), FCount);
  Inc(FCount);
  { min 缓存增量更新: 新 target 更早到期才刷新 }
  if FMinValid and (not ATarget.WakeDeadline.IsInfinite) then
    if FMinDeadline.IsInfinite or
       RegistryDeadlineEarlier(ATarget.WakeDeadline, FMinDeadline) then
      FMinDeadline := ATarget.WakeDeadline;
end;

procedure TTcpServerPollTargetRegistry.UnregisterTarget(
  const ATarget: TTcpServerPollSessionTarget);
var
  LIdx: SizeUInt;
  LMoved: TTcpServerPollSessionTarget;
begin
  if (FCount = 0) or (ATarget = nil) then
    Exit;
  if not FIndexMap.TryGetValue(Pointer(ATarget), LIdx) then
    Exit;
  Dec(FCount);
  if LIdx < FCount then
  begin
    LMoved := FItems[FCount];
    FItems[LIdx] := LMoved;
    FIndexMap.AddOrAssign(Pointer(LMoved), LIdx);
  end;
  FItems[FCount] := nil;
  FIndexMap.Remove(Pointer(ATarget));
  { min 缓存: 被删的是当前(或并列)最早到期者才失效, 查询时惰性重算。
    到期批处理在同一轮循环内完成(期间无查询), 不会退化为 O(n²) }
  if FMinValid and (not ATarget.WakeDeadline.IsInfinite) then
    if FMinDeadline.IsInfinite or
       (not RegistryDeadlineEarlier(FMinDeadline, ATarget.WakeDeadline)) then
      FMinValid := False;
  ATarget.DetachTicket;
end;

function TTcpServerPollTargetRegistry.ContainsTarget(
  const ATarget: TTcpServerPollSessionTarget): Boolean;
begin
  Result := (ATarget <> nil) and FIndexMap.ContainsKey(Pointer(ATarget));
end;

procedure TTcpServerPollTargetRegistry.InvalidateMinDeadline;
begin
  FMinValid := False;
end;

function TTcpServerPollTargetRegistry.ComputePollTimeoutMs: Int32;
var
  LRemaining: TDuration;
  LMs: Int64;
begin
  Result := -1;
  if FCount = 0 then
    Exit;
  { O(1) 快速路径: 用 min 缓存; 失效才全扫 }
  if not FMinValid then
    RecomputeMinDeadline;
  if FMinDeadline.IsInfinite then
    Exit;
  if FMinDeadline.IsExpired then
    Exit(0);
  LRemaining := FMinDeadline.Remaining;
  LMs := LRemaining.AsMilliseconds;
  if (LMs <= 0) and (LRemaining.AsNanoseconds > 0) then
    LMs := 1;
  if LMs > High(Int32) then
    LMs := High(Int32);
  Result := Int32(LMs);
end;

function TTcpServerPollTargetRegistry.CollectExpiredTargets: TTcpServerPollSessionTargetArray;
var
  LI: SizeUInt;
  LCount: SizeUInt;
begin
  Result := nil;
  if FCount = 0 then
    Exit;
  { O(1) 快速路径: min 未过期则无任何过期, 免轮末每轮 O(n) 全扫 }
  if not FMinValid then
    RecomputeMinDeadline;
  if FMinDeadline.IsInfinite or (not FMinDeadline.IsExpired) then
    Exit;
  LCount := 0;
  for LI := 0 to FCount - 1 do
    if FItems[LI].WakeDeadline.IsExpired then
    begin
      if LCount >= SizeUInt(Length(Result)) then
        SetLength(Result, LCount + 4);
      Result[LCount] := FItems[LI];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

function TTcpServerPollTargetRegistry.Snapshot: TTcpServerPollSessionTargetArray;
var
  LI: SizeUInt;
begin
  Result := nil;
  if FCount = 0 then
    Exit;
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
    Result[LI] := FItems[LI];
end;

function TTcpServerPollTargetRegistry.AnyShutdownClose: Boolean;
var
  LI: SizeUInt;
begin
  { FCount 为无符号：0 时直接返回，避免 FCount-1 下溢扫越界 }
  Result := False;
  if FCount = 0 then
    Exit;
  for LI := 0 to FCount - 1 do
    if (FItems[LI] <> nil) and FItems[LI].IsShutdownClose then
      Exit(True);
end;

function TTcpServerPollTargetRegistry.Drain: TTcpServerPollSessionTargetArray;
var
  LI: SizeUInt;
begin
  Result := nil;
  if FCount = 0 then
    Exit;
  SetLength(Result, FCount);
  for LI := 0 to FCount - 1 do
  begin
    Result[LI] := FItems[LI];
    if FItems[LI] <> nil then
    begin
      FItems[LI].DetachTicket;
      FIndexMap.Remove(Pointer(FItems[LI]));
    end;
    FItems[LI] := nil;
  end;
  FCount := 0;
  FMinValid := False;
end;

procedure TTcpServerPollTargetRegistry.Clear;
var
  LI: SizeUInt;
begin
  if FCount = 0 then
    Exit;
  for LI := 0 to FCount - 1 do
  begin
    if FItems[LI] <> nil then
      FIndexMap.Remove(Pointer(FItems[LI]));
    FItems[LI] := nil;
  end;
  FCount := 0;
  FMinValid := False;
end;

constructor TTcpServerWorkTask.Create(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion);
begin
  inherited Create;
  FWork := AWork;
  FCompletion := ACompletion;
end;

procedure TTcpServerWorkTask.Run;
var
  LOutcome: TTcpServerWorkOutcome;
  LOwnership: TTcpServerConnOwnership;
begin
  LOutcome := tswoCompleted;
  LOwnership := tscoServer;
  try
    LOwnership := FWork.Execute;
  except
    LOutcome := tswoFailed;
    LOwnership := tscoServer;
  end;
  try
    FCompletion.Complete(LOutcome, LOwnership);
  except
  end;
  FCompletion := nil;
  FWork := nil;
end;

constructor TTcpServerDefaultWorkerHandoff.Create(
  const AShutdownTimeoutNs: Int64; const AWorkerPoolSize: Integer);
begin
  inherited Create;
  { WorkerPoolSize: 0 = auto（platform_cpu_count，既有行为）；>0 覆盖，
    放开流式并发上界（token888 已知差距 #2 收口）。 }
  FPool := ThreadPool(AWorkerPoolSize);
  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FShuttingDown := False;
  FShutdownTimeoutNs := AShutdownTimeoutNs;
end;

procedure TTcpServerDefaultWorkerHandoff.Shutdown;
var
  LPool: IThreadPool;
begin
  FMutex.Acquire;
  try
    if FShuttingDown then
      Exit;
    FShuttingDown := True;
    LPool := FPool;
    FPool := nil;
  finally
    FMutex.Release;
  end;
  if LPool <> nil then
  begin
    LPool.Shutdown;
    if FShutdownTimeoutNs > 0 then
      LPool.WaitAllTimeout(FShutdownTimeoutNs)
    else
      LPool.WaitAll;
  end;
end;

function TTcpServerDefaultWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LTask: TTcpServerWorkTask;
begin
  if AWork = nil then
    raise EArgumentError.Create('tcp server handoff work must not be nil');
  if ACompletion = nil then
    raise EArgumentError.Create('tcp server handoff completion must not be nil');

  FMutex.Acquire;
  try
    if FShuttingDown or (FPool = nil) then
      Exit(tshrShuttingDown);
    LTask := TTcpServerWorkTask.Create(AWork, ACompletion);
    try
      FPool.Submit(procedure
      begin
        try
          LTask.Run;
        finally
          LTask.Free;
        end;
      end);
    except
      LTask.Free;
      raise;
    end;
    Result := tshrAccepted;
  finally
    FMutex.Release;
  end;
end;

constructor TTcpServerDefaultSessionContext.Create(
  const AWorkerHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FWorkerHandoff := AWorkerHandoff;
  FWsLock := nextpas.core.sync.mutex.TMutex.Create;
end;

destructor TTcpServerDefaultSessionContext.Destroy;
begin
  { 释放前清空登记：会话收尾路径应已逐个 Unregister，这里兜底防悬挂。 }
  FWsNotifiers := nil;
  FWsLock := nil;
  inherited Destroy;
end;

function TTcpServerDefaultSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoff;
end;

function TTcpServerDefaultSessionContext.HandoffHijackedConn(
  const AConn: ITcpStream;
  const ANewSession: ITcpServerSession): Boolean;
begin
  { 非 poll 容器（threaded 后端）无 poll target 可迁移，显式拒绝。 }
  Result := False;
end;

function TTcpServerDefaultSessionContext.SubmitHijackMigration: Boolean;
begin
  Result := False;
end;

procedure TTcpServerDefaultSessionContext.RegisterShutdownNotifier(
  const ANotifier: IWsServerShutdownNotifier);
var
  N: SizeInt;
begin
  if ANotifier = nil then
    Exit;
  FWsLock.Acquire;
  try
    N := Length(FWsNotifiers);
    SetLength(FWsNotifiers, N + 1);
    FWsNotifiers[N] := ANotifier;
  finally
    FWsLock.Release;
  end;
end;

procedure TTcpServerDefaultSessionContext.UnregisterShutdownNotifier(
  const ANotifier: IWsServerShutdownNotifier);
var
  I, N: SizeInt;
begin
  if ANotifier = nil then
    Exit;
  FWsLock.Acquire;
  try
    N := Length(FWsNotifiers);
    for I := 0 to N - 1 do
      if FWsNotifiers[I] = ANotifier then
      begin
        FWsNotifiers[I] := FWsNotifiers[N - 1];
        SetLength(FWsNotifiers, N - 1);
        Break;
      end;
  finally
    FWsLock.Release;
  end;
end;

procedure TTcpServerDefaultSessionContext.ShutdownAll(
  const ATimeoutNs: Int64);
var
  LSnapshot: array of IWsServerShutdownNotifier;
  LDeadline: TDeadline;
  LRemaining: TDuration;
  I, N: SizeInt;
begin
  FWsLock.Acquire;
  try
    N := Length(FWsNotifiers);
    SetLength(LSnapshot, N);
    for I := 0 to N - 1 do
      LSnapshot[I] := FWsNotifiers[I];
  finally
    FWsLock.Release;
  end;
  if N = 0 then
    Exit;
  { 先全部唤醒（连接线程被 waitable cancel 唤醒 → ReadMessage 退出，
    close frame 1001 由会话收尾路径补发），再逐个等待收尾；剩余时间
    递减，超时强关。0 = 无限等待（与 HTTP ShutdownTimeout=0 语义一致）。 }
  for I := 0 to N - 1 do
    LSnapshot[I].NotifyShutdown;
  if ATimeoutNs <= 0 then
  begin
    for I := 0 to N - 1 do
      LSnapshot[I].WaitFinished(0);
    Exit;
  end;
  LDeadline := TDeadline.After(TDuration.FromNanoseconds(ATimeoutNs));
  for I := 0 to N - 1 do
  begin
    LRemaining := LDeadline.Remaining;
    if LRemaining.AsNanoseconds <= 0 then
      LSnapshot[I].ForceClose
    else if not LSnapshot[I].WaitFinished(LRemaining.AsNanoseconds) then
      LSnapshot[I].ForceClose;
  end;
end;

procedure CreateTcpServerRuntimeContext(
  out AWorkerHandoff: ITcpServerWorkerHandoff;
  out ASessionContext: ITcpServerSessionContext;
  const AShutdownTimeoutNs: Int64 = 0;
  const AWorkerPoolSize: Integer = 0);
begin
  AWorkerHandoff := TTcpServerDefaultWorkerHandoff.Create(AShutdownTimeoutNs,
    AWorkerPoolSize);
  ASessionContext := TTcpServerDefaultSessionContext.Create(AWorkerHandoff);
end;

function TryCreateTcpServerSession(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext;
  out ASession: ITcpServerSession): Boolean;
var
  LContextFactory: ITcpServerSessionFactoryWithContext;
  LSessionFactory: ITcpServerSessionFactory;
begin
  ASession := nil;
  if Supports(AHandler, ITcpServerSessionFactoryWithContext, LContextFactory) then
  begin
    ASession := LContextFactory.NewSession(AConn, AContext);
    if ASession = nil then
      raise EArgumentError.Create('tcp server session factory returned nil');
    Exit(True);
  end;
  if Supports(AHandler, ITcpServerSessionFactory, LSessionFactory) then
  begin
    ASession := LSessionFactory.NewSession(AConn);
    if ASession = nil then
      raise EArgumentError.Create('tcp server session factory returned nil');
    Exit(True);
  end;
  Result := False;
end;

function TryCreateTcpServerPollSessionTarget(const AConn: ITcpStream;
  const ASession: ITcpServerSession;
  out ATarget: TTcpServerPollSessionTarget): Boolean;
var
  LPollSession: ITcpServerPollDrivenSession;
  LDeadlineSession: ITcpServerPollDrivenSessionWithDeadline;
  LSocketRuntime: ITcpSocketRuntime;
  LEvents: TPlatformPollEvents;
  LWakeDeadline: TDeadline;
begin
  ATarget := nil;
  if not Supports(ASession, ITcpServerPollDrivenSession, LPollSession) then
    Exit(False);
  if not Supports(AConn, ITcpSocketRuntime, LSocketRuntime) then
    Exit(False);

  LEvents := LPollSession.PollEvents;
  if Supports(ASession, ITcpServerPollDrivenSessionWithDeadline,
    LDeadlineSession) then
    LWakeDeadline := LDeadlineSession.WakeDeadline
  else
    LWakeDeadline := TDeadline.Infinite;
  if (LEvents = []) and LWakeDeadline.IsInfinite then
    Exit(False);

  LSocketRuntime.SetBlocking(False);
  ATarget := TTcpServerPollSessionTarget.Create(AConn, LSocketRuntime,
    ASession, LPollSession, LEvents, LWakeDeadline);
  Result := True;
end;

function ExecuteTcpServerSession(
  const ASession: ITcpServerSession): TTcpServerConnOwnership;
begin
  if ASession = nil then
    raise EArgumentError.Create('tcp server session must not be nil');
  Result := ASession.Run;
end;

function ExecuteTcpServerConnHandler(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext): TTcpServerConnOwnership;
var
  LSession: ITcpServerSession;
begin
  Result := tscoServer;
  try
    if TryCreateTcpServerSession(AHandler, AConn, AContext, LSession) then
      Result := ExecuteTcpServerSession(LSession)
    else
      Result := AHandler.ServeConn(AConn);
  except
    Result := tscoServer;
  end;
end;

procedure CloseServerOwnedTcpConn(const AConn: ITcpStream);
begin
  if AConn = nil then
    Exit;
  try
    AConn.Shutdown;
  except
  end;
  try
    AConn.Close;
  except
  end;
end;

end.
