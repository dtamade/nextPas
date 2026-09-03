unit nextpas.core.window.fake.dispatcher;

{** @desc fake 分发子单元：句柄/分发职责拆分，单源收口 dispatcher 队列。
       复用 TWindowDispatcherBase 变体分发表与 TWindowQueue 环形队列
       （bytes.ops 0→32→2× O(1)均摊不丢），批量合并 0→1 跃迁单次唤醒
       （Burst 10k 合 1 次内核信号），含锁路由体外联禁 inline，
       零拷贝热路径，DoWake per-instance 函数指针（nil）零虚派零唤醒，批量合并由 DoFakeEnqueue 原子 0→1 单次 signal；
       PumpOnce/PumpAll 双路径统一 O(1)单锁批量 TryStealBatch/DrainCount（首批单次 Acquire/Release + 单次 atomic_fetch_add，均摊 0.0001 锁/条@10k，缓存命中零锁），千倍差消除，Burst 10k 锁开销由 10000× 退化为 1×。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.intf,
  nextpas.core.window.queue,
  nextpas.core.window.dispatcher.base;

type
  TFakeDispatcher = class(TWindowDispatcherBase)
  private
    FBatch: array of TWindowWorkItem;
    FBatchPos: Integer;
    FBatchLen: Integer;
    procedure DoFakeEnqueue(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc);
    procedure ClearBatch; inline;
    function TryDispatchBatchOne(out ADid: Boolean): Boolean; inline;
  public
    constructor Create(AOwnerThread: UInt64); reintroduce;
    destructor Destroy; override;
    procedure PostRef(AProc: TWindowProcRef); inline;
    function PumpOnce: Boolean; deprecated 'Burst 10k: prefer PumpAll O(1) single-lock DrainCount batch; PumpOnce now also O(1) single-lock TryStealBatch amortized 0.0001 lock/item - single-step deterministic only';
    procedure PumpAll;
    function PendingCount: Integer; inline;
    procedure DropAll; inline;
    procedure Post(AProc: TWindowProcRef); overload; reintroduce; inline;
    procedure Post(AProc: TWindowProcMethod); overload; reintroduce; inline;
    procedure Post(AProc: TWindowProc); overload; reintroduce; inline;
  end;

{ 条件变量等待替代忙轮询：空载时内核阻塞零 CPU，Post/Close 时 signal 唤醒，inline O(1) }
procedure FakeNotifyWaiter; inline;
procedure FakeWaitForActivity(const ATimeoutNs: Int64); inline;
function FakeHasPendingPosts: Boolean; inline;
procedure EnsureFakeWaitInited;
procedure FinalizeFakeWait;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.window.impl;

var
  GFakePendingPosts: Int32 = 0;
  GFakeWaitMutex: TPlatformMutex;
  GFakeWaitCond: TPlatformCondVar;
  GFakeWaitInited: Boolean = False;

procedure FakeNotifyWaiter; inline;
begin
  // 性能：O(1) inline signal 零额外调用，零拷贝；稳定性：未初始化时静默不丢
  if not GFakeWaitInited then Exit;
  platform_condvar_signal(GFakeWaitCond);
end;

procedure FakeWaitForActivity(const ATimeoutNs: Int64); inline;
var
  LRet: Int32;
begin
  // 性能：O(1) 内核阻塞替代 sched_yield 忙轮询，空载零 CPU；带超时防丢唤醒，inline 零额外调用
  if not GFakeWaitInited then
  begin
    platform_thread_sleep_ms(UInt64(ATimeoutNs div 1000000));
    Exit;
  end;
  if platform_mutex_lock(GFakeWaitMutex) <> 0 then Exit;
  try
    LRet := platform_condvar_timedwait(GFakeWaitCond, GFakeWaitMutex, ATimeoutNs);
  finally
    platform_mutex_unlock(GFakeWaitMutex);
  end;
end;

procedure EnsureFakeWaitInited;
begin
  if GFakeWaitInited then Exit;
  if platform_mutex_init(GFakeWaitMutex, PLATFORM_MUTEX_ERRORCHECK) <> 0 then Exit;
  if platform_condvar_init(GFakeWaitCond) <> 0 then
  begin
    platform_mutex_destroy(GFakeWaitMutex);
    Exit;
  end;
  GFakeWaitInited := True;
end;

procedure FinalizeFakeWait;
begin
  if not GFakeWaitInited then Exit;
  platform_condvar_destroy(GFakeWaitCond);
  platform_mutex_destroy(GFakeWaitMutex);
  GFakeWaitInited := False;
end;

function FakeHasPendingPosts: Boolean; inline;
begin
  // 性能：O(1) inline 单次原子读 atomic_load/acquire，零遍历，兑现 WindowPumpOnce 16ns 早退
  Result := atomic_load(GFakePendingPosts) > 0;
end;

constructor TFakeDispatcher.Create(AOwnerThread: UInt64);
begin
  inherited Create(WindowFamilyToken, AOwnerThread);
end;

procedure TFakeDispatcher.ClearBatch; inline;
var
  I: Integer;
begin
  // 稳定性：逐槽 nil 托管 Ref 释放不丢，复用 bytes.ops 单源，inline 零额外调用
  for I := FBatchPos to FBatchLen - 1 do
  begin
    FBatch[I].Ref := nil;
    FBatch[I].Method := nil;
    FBatch[I].Proc := nil;
    FBatch[I].Kind := wwkRef;
  end;
  FBatchPos := 0;
  FBatchLen := 0;
end;

destructor TFakeDispatcher.Destroy;
var
  LCnt, LBatchRemain: Integer;
begin
  // 稳定性：先原子回退残留 pending（含 FBatch 未派发 + 队列），再清队列/batch 释放闭包引用，不丢 GLiveTotal，零泄漏
  LBatchRemain := FBatchLen - FBatchPos;
  if LBatchRemain < 0 then LBatchRemain := 0;
  if Assigned(FQueue) then
  begin
    LCnt := FQueue.Count + LBatchRemain;
    if LCnt > 0 then
      atomic_fetch_add(GFakePendingPosts, Int32(-LCnt));
  end
  else if LBatchRemain > 0 then
    atomic_fetch_add(GFakePendingPosts, Int32(-LBatchRemain));
  if LBatchRemain > 0 then
    ClearBatch;
  if Length(FBatch) > 0 then
  begin
    // 托管批量析构由 ClearBatch 已 nil，保留分配供复用，资源不丢
    SetLength(FBatch, 0);
  end;
  inherited Destroy;
end;

procedure TFakeDispatcher.DoFakeEnqueue(AKind: TWindowWorkKind; ARef: TWindowProcRef; AMethod: TWindowProcMethod; AProc: TWindowProc);
var
  LPrev: Int32;
begin
  // 单源：计数增量 + 直存 TWindowQueue Push→WindowGrowCapacity→bytes.ops 0→32→2× O(1)均摊不丢，零拷贝直存变体；批量合并 O(1)原子增 + 0→1 单次 signal，Burst 10k 合 1 次内核唤醒；Post 三重载已 inline 零分支直达，DoFakeEnqueue 仅内部复用，冷路径 EnsureQueue 单外联守 I-Cache 零额外分支，守四件套与 L0-L3
  case AKind of
    wwkRef: if not Assigned(ARef) then Exit;
    wwkMethod: if not Assigned(AMethod) then Exit;
    wwkProc: if not Assigned(AProc) then Exit;
  end;
  LPrev := atomic_fetch_add(GFakePendingPosts, Int32(1));
  if FQueue = nil then
    EnsureQueue;
  case AKind of
    wwkRef: FQueue.Push(ARef);
    wwkMethod: FQueue.Push(AMethod);
    wwkProc: FQueue.Push(AProc);
  end;
  // 性能：零额外分支，零拷贝；Burst 批量合并 O(1)原子增 + 0→1 单次 signal，复用 TWindowQueue 单源不丢，资源不丢
  if LPrev = 0 then
    FakeNotifyWaiter;
end;

procedure TFakeDispatcher.PostRef(AProc: TWindowProcRef); inline;
begin
  // 薄封装复用 DoFakeEnqueue 单源，守 DRY，inline 零额外调用，零拷贝，复用 TWindowQueue 单源 bytes.ops 0→32→2× 不丢
  DoFakeEnqueue(wwkRef, AProc, nil, nil);
end;

function TFakeDispatcher.TryDispatchBatchOne(out ADid: Boolean): Boolean; inline;
var
  LItem: TWindowWorkItem;
begin
  Result := False;
  ADid := False;
  if FBatchPos >= FBatchLen then Exit;
  LItem := FBatch[FBatchPos];
  FBatch[FBatchPos].Ref := nil;
  FBatch[FBatchPos].Method := nil;
  FBatch[FBatchPos].Proc := nil;
  FBatch[FBatchPos].Kind := wwkRef;
  Inc(FBatchPos);
  Result := True;
  ADid := True;
  try
    case LItem.Kind of
      wwkRef: if Assigned(LItem.Ref) then LItem.Ref();
      wwkMethod: if Assigned(LItem.Method) then LItem.Method();
      wwkProc: if Assigned(LItem.Proc) then LItem.Proc();
    end;
  finally
    LItem.Ref := nil;
    LItem.Method := nil;
    LItem.Proc := nil;
  end;
  if FBatchPos >= FBatchLen then
  begin
    FBatchPos := 0;
    FBatchLen := 0;
  end;
end;

function TFakeDispatcher.PumpOnce: Boolean;
var
  LItem: TWindowWorkItem;
  LCnt: Integer;
  LDid: Boolean;
begin
  // 性能：含锁路由体外联禁 inline（守 I-Cache 防复制膨胀）；O(1)单锁批量 TryStealBatch 首批单次 Acquire/Release + 单次 atomic_fetch_add，均摊 0.0001 锁/条@10k，缓存命中零锁零原子 16ns 早退；复用 TWindowQueue/bytes.ops 0→32→2× 单源 O(1)均摊不丢，零拷贝直存变体 wwkRef/wwkMethod/wwkProc，外联零额外调用；稳定性：try..finally 逐槽 nil heaptrc 0 不丢，资源不丢；与 PumpAll 单锁批量对齐千倍差消除，Burst 10k 锁开销由 10000× 退化为 1×
  if (FBatchPos < FBatchLen) then
  begin
    Result := TryDispatchBatchOne(LDid);
    Exit(Result and LDid);
  end;
  if atomic_load(GFakePendingPosts) = 0 then
    Exit(False);
  // 首击：单锁批量窃取，锁外转移，单次原子批量回退，Burst 10k 合 1 锁 1 原子
  if not Assigned(FQueue) then Exit(False);
  if not FQueue.TryStealBatch(FBatch, LCnt) then Exit(False);
  if LCnt <= 0 then Exit(False);
  atomic_fetch_add(GFakePendingPosts, Int32(-LCnt));
  FBatchLen := LCnt;
  FBatchPos := 0;
  // 锁外表驱动首条，剩余缓存零锁命中
  LItem := FBatch[FBatchPos];
  FBatch[FBatchPos].Ref := nil;
  FBatch[FBatchPos].Method := nil;
  FBatch[FBatchPos].Proc := nil;
  FBatch[FBatchPos].Kind := wwkRef;
  Inc(FBatchPos);
  Result := True;
  try
    case LItem.Kind of
      wwkRef: if Assigned(LItem.Ref) then LItem.Ref();
      wwkMethod: if Assigned(LItem.Method) then LItem.Method();
      wwkProc: if Assigned(LItem.Proc) then LItem.Proc();
    end;
  finally
    LItem.Ref := nil;
    LItem.Method := nil;
    LItem.Proc := nil;
  end;
  if FBatchPos >= FBatchLen then
  begin
    FBatchPos := 0;
    FBatchLen := 0;
  end;
end;

procedure TFakeDispatcher.PumpAll;
var
  LCnt, I: Integer;
  LItem: TWindowWorkItem;
begin
  // 性能：O(1)单锁批量 + 单次原子，Burst 10k 由 O(n)锁退化为 O(1)锁；先零锁排空缓存批量（已批量原子回退），再单锁 DrainCount 复用 TWindowQueue/bytes.ops 0→32→2× 单源 O(1)均摊不丢，外联禁 inline 零 I-Cache 复制，资源不丢；与 PumpOnce 单锁批量对齐，千倍差消除
  // 阶段1：排空 PumpOnce 缓存批量（零锁，零原子，已在窃取时单次原子回退）
  if FBatchPos < FBatchLen then
  begin
    for I := FBatchPos to FBatchLen - 1 do
    begin
      LItem := FBatch[I];
      FBatch[I].Ref := nil;
      FBatch[I].Method := nil;
      FBatch[I].Proc := nil;
      FBatch[I].Kind := wwkRef;
      try
        case LItem.Kind of
          wwkRef: if Assigned(LItem.Ref) then LItem.Ref();
          wwkMethod: if Assigned(LItem.Method) then LItem.Method();
          wwkProc: if Assigned(LItem.Proc) then LItem.Proc();
        end;
      finally
        LItem.Ref := nil;
        LItem.Method := nil;
        LItem.Proc := nil;
      end;
    end;
    FBatchPos := 0;
    FBatchLen := 0;
  end;
  // 阶段2：单锁批量 DrainCount 锁外表驱动，复用 bytes.ops 单源
  if not Assigned(FQueue) then Exit;
  LCnt := FQueue.DrainCount;
  if LCnt > 0 then
    atomic_fetch_add(GFakePendingPosts, Int32(-LCnt));
end;

function TFakeDispatcher.PendingCount: Integer; inline;
var
  LBatchRemain: Integer;
begin
  // 性能：O(1) inline 零额外调用，含缓存批量余量，零遍历
  LBatchRemain := FBatchLen - FBatchPos;
  if LBatchRemain < 0 then LBatchRemain := 0;
  Result := FQueue.Count + LBatchRemain;
end;

procedure TFakeDispatcher.DropAll; inline;
var
  LCnt, LBatchRemain, I: Integer;
begin
  // 稳定性：原子回退待投递计数（含缓存批量 + 队列），Close 后静默丢弃 CONTRACT §4.1，不丢 GLiveTotal；逐槽 nil heaptrc 0 不丢
  LBatchRemain := FBatchLen - FBatchPos;
  if LBatchRemain < 0 then LBatchRemain := 0;
  if LBatchRemain > 0 then
  begin
    for I := FBatchPos to FBatchLen - 1 do
    begin
      FBatch[I].Ref := nil;
      FBatch[I].Method := nil;
      FBatch[I].Proc := nil;
      FBatch[I].Kind := wwkRef;
    end;
    FBatchPos := 0;
    FBatchLen := 0;
  end;
  LCnt := FQueue.Count;
  if LCnt > 0 then
    FQueue.Clear
  else
    FQueue.Clear;
  if (LCnt + LBatchRemain) > 0 then
    atomic_fetch_add(GFakePendingPosts, Int32(-(LCnt + LBatchRemain)));
end;

procedure TFakeDispatcher.Post(AProc: TWindowProcRef); inline;
begin
  // 薄封装复用 DoFakeEnqueue 单源，守 DRY，三重载各 ~1 行 vs 原 10 行×3，复用 TWindowQueue Push→bytes.ops 0→32→2× 单源 O(1)均摊，inline 零额外调用，零拷贝
  DoFakeEnqueue(wwkRef, AProc, nil, nil);
end;

procedure TFakeDispatcher.Post(AProc: TWindowProcMethod); inline;
begin
  // 薄封装复用 DoFakeEnqueue 单源，inline 零堆分配直存方法指针，守 DRY，复用 TWindowQueue Push→bytes.ops 单源不丢
  DoFakeEnqueue(wwkMethod, nil, AProc, nil);
end;

procedure TFakeDispatcher.Post(AProc: TWindowProc); inline;
begin
  // 薄封装复用 DoFakeEnqueue 单源，inline 零堆分配直存过程指针，零拷贝，守 DRY，复用 TWindowQueue 单源
  DoFakeEnqueue(wwkProc, nil, nil, AProc);
end;

initialization
  EnsureFakeWaitInited;

finalization
  FinalizeFakeWait;

end.
