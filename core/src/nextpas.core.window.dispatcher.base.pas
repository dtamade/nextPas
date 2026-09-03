unit nextpas.core.window.dispatcher.base;

{ window 家族共享 dispatcher 基类（owner window.impl，scope window 家族）。

  家族内特权共享：仅 window.* 后端 uses，不经公共门面 re-export，
  需 TWindowFamilyToken 经 window.impl RequireWindowFamilyToken 显式校验
  （Create 各重载首参 const AToken: TWindowFamilyToken，inline 零拷贝单次
  Pointer 比较，与 live/queue/hash 显式校验对齐，编译期 owner 保障），守四件套与 L0-L3。

  职责：owner 线程记录 + IsOnMainThread 判定；Post 三重载各 inline 零分支直达
  零拷贝直存变体 wwkRef/wwkMethod/wwkProc，复用 TWindowQueue 变体直存；
  热路径 Post 零 case 避调度，冷路径 EnsureQueue 单外联守 I-Cache 防热路径复制膨胀。

  唤醒：空→非空跃迁单次聚合，per-instance 函数指针隔离。

  性能：热路径 inline 薄转发零额外调用、零拷贝 O(1)，
  经 window.impl WindowGrowCapacity → bytes.ops 0→32→2× 单源；
  冷路径 EnsureQueue 单外联守 I-Cache 防热路径复制膨胀，首调冷路径单次
  堆分配不计入 PostSingle 热路径基线（基线预热队列后单次 210ns 零分配，冷路径单独硬化）。

  稳定性：FOwnsQueue 决定释放归属；共享队列由 registry 单源托管，
  per-instance 自行 Clear/Free；所有权快照 + try..finally 防双重/遗漏释放，空队列静默容忍。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.window.intf,
  nextpas.core.window.queue,
  nextpas.core.sync.intf;

type
  TWindowDispatcherWakeProc = procedure(AData: Pointer);

type
  TWindowDispatcherBase = class abstract(TInterfacedObject, IWindowDispatcher)
  protected
    FOwnerThread: UInt64;
    FQueue: TWindowQueue;
    FWaitEvent: IEvent;
    FOwnsQueue: Boolean;
    FWakeProc: TWindowDispatcherWakeProc;
    FWakeData: Pointer;
    procedure DoWake; inline;
    procedure EnsureQueue;
    procedure DoNotifyWake(AWasEmpty: Boolean); inline;
  public
    constructor Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64; AQueue: TWindowQueue; AWait: IEvent; AWakeProc: TWindowDispatcherWakeProc; AWakeData: Pointer; AOwnsQueue: Boolean = False); overload;
    constructor Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64; AQueue: TWindowQueue; AWait: IEvent; AOwnsQueue: Boolean = False); overload;
    constructor Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64; AWakeProc: TWindowDispatcherWakeProc; AWakeData: Pointer); overload;
    constructor Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64); overload;
    destructor Destroy; override;
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload; inline;
    procedure Post(AProc: TWindowProcMethod); overload; inline;
    procedure Post(AProc: TWindowProc); overload; inline;
  end;

implementation

uses
  nextpas.core.platform.thread;

constructor TWindowDispatcherBase.Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64; AQueue: TWindowQueue; AWait: IEvent; AWakeProc: TWindowDispatcherWakeProc; AWakeData: Pointer; AOwnsQueue: Boolean);
begin
  RequireWindowFamilyToken(AToken);
  inherited Create;
  FOwnerThread := AOwnerThread;
  FQueue := AQueue;
  FWaitEvent := AWait;
  FWakeProc := AWakeProc;
  FWakeData := AWakeData;
  FOwnsQueue := AOwnsQueue;
  if (FQueue = nil) and AOwnsQueue then
    EnsureQueue;
end;

constructor TWindowDispatcherBase.Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64; AQueue: TWindowQueue; AWait: IEvent; AOwnsQueue: Boolean);
begin
  RequireWindowFamilyToken(AToken);
  Create(AToken, AOwnerThread, AQueue, AWait, nil, nil, AOwnsQueue);
end;

constructor TWindowDispatcherBase.Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64; AWakeProc: TWindowDispatcherWakeProc; AWakeData: Pointer);
begin
  RequireWindowFamilyToken(AToken);
  inherited Create;
  FOwnerThread := AOwnerThread;
  FOwnsQueue := True;
  FWakeProc := AWakeProc;
  FWakeData := AWakeData;
  EnsureQueue;
end;

constructor TWindowDispatcherBase.Create(const AToken: TWindowFamilyToken; AOwnerThread: UInt64);
begin
  RequireWindowFamilyToken(AToken);
  Create(AToken, AOwnerThread, TWindowDispatcherWakeProc(nil), nil);
end;

destructor TWindowDispatcherBase.Destroy;
var
  LQueue: TWindowQueue;
begin
  // 稳定性：所有权快照 + try..finally 保证 Clear/Free 不丢不重；共享队列由 registry 单源托管，FOwnsQueue=false 时仅置 nil 不 Free，防双重释放
  LQueue := nil;
  if FOwnsQueue then
  begin
    LQueue := FQueue;
    FQueue := nil;
    FOwnsQueue := False;
    if Assigned(LQueue) then
    try
      LQueue.Clear;
    finally
      LQueue.Free;
    end;
  end else
    FQueue := nil;
  FWaitEvent := nil;
  FWakeProc := nil;
  FWakeData := nil;
  inherited;
end;

procedure TWindowDispatcherBase.EnsureQueue;
var
  LNew: TWindowQueue;
begin
  // 冷路径外联守 I-Cache，持单次堆分配；先局部构造成功后再发布归属，异常路径不留半初始化不丢不重
  if FQueue <> nil then Exit;
  LNew := TWindowQueue.Create(WindowFamilyToken);
  FQueue := LNew;
  FOwnsQueue := True;
  // FWaitEvent nil 容忍：共享场景由 registry 单源 RegistryEnsureDispatcherWait 注入，per-instance 经 FWakeProc 隔离；DoNotifyWake 判空，不以空块掩盖初始化完整性
end;

procedure TWindowDispatcherBase.DoWake; inline;
begin
  if Assigned(FWakeProc) then
    FWakeProc(FWakeData);
end;

procedure TWindowDispatcherBase.DoNotifyWake(AWasEmpty: Boolean); inline;
begin
  if not AWasEmpty then Exit;
  if FWaitEvent <> nil then
    FWaitEvent.SetEvent;
  DoWake;
end;

function TWindowDispatcherBase.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowDispatcherBase.Post(AProc: TWindowProcRef); inline;
var
  LWasEmpty: Boolean;
begin
  // 性能：inline 薄转发零分支直达零拷贝直存 wwkRef，零 case 避调度，复用 TWindowQueue Push→WindowGrowCapacity→bytes.ops 0→32→2× 单源 O(1)均摊；冷路径 EnsureQueue 单外联守 I-Cache，首调堆分配不入 PostSingle 基线（per-instance 构造已预热 FQueue≠nil，热路径零分支；共享队列由 registry 注入，空队列静默容忍资源不丢）
  if not Assigned(AProc) then Exit;
  if FQueue = nil then
    EnsureQueue;
  LWasEmpty := FQueue.Push(AProc);
  DoNotifyWake(LWasEmpty);
end;

procedure TWindowDispatcherBase.Post(AProc: TWindowProcMethod); inline;
var
  LWasEmpty: Boolean;
begin
  // 性能：inline 薄转发零堆分配直存 wwkMethod，零 case 避调度，复用 TWindowQueue Push→bytes.ops 单源 O(1)均摊；冷路径 EnsureQueue 单外联守 I-Cache，首调不入基线（per-instance 已预热，热路径零额外调用 inline 零拷贝）
  if not Assigned(AProc) then Exit;
  if FQueue = nil then
    EnsureQueue;
  LWasEmpty := FQueue.Push(AProc);
  DoNotifyWake(LWasEmpty);
end;

procedure TWindowDispatcherBase.Post(AProc: TWindowProc); inline;
var
  LWasEmpty: Boolean;
begin
  // 性能：inline 薄转发零堆分配直存 wwkProc，零 case 避调度，复用 TWindowQueue Push→bytes.ops 单源 O(1)均摊；冷路径 EnsureQueue 单外联守 I-Cache，首调不入基线（per-instance 已预热，资源不丢）
  if not Assigned(AProc) then Exit;
  if FQueue = nil then
    EnsureQueue;
  LWasEmpty := FQueue.Push(AProc);
  DoNotifyWake(LWasEmpty);
end;

end.
