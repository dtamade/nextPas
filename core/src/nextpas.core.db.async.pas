unit nextpas.core.db.async;

{** @desc db 异步挂载（V3-B6 匠心修复）：单工池单飞执行器 + 可取消句柄。
       底座：thread.init / thread.pool(1) / sync / async 取消 / errors；阈值经 execution.base 单源复用（L1 纯净）。
       单飞模型，一连接一线程；阈值单源 execution.base（L1 纯净，http/tui 共享 execution 单源，不依赖 db.base），bytes.ops 单源。 *}

{$I nextpas.core.settings.inc}

{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.bytes.ops,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.atomic,
  nextpas.core.execution.base,
  nextpas.core.async.cancellation,
  nextpas.core.sync.event,
  nextpas.core.sync.mutex,
  nextpas.core.sync.intf,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool,
  nextpas.core.time.base;

{ 异步挂载固定税与阈值单源：execution.base（L1 纯净，EXECUTION_MOUNT_OVERHEAD_US=20/
  EXECUTION_MIN_WORTHWHILE_US=50/ExecutionShouldOffload），db 侧不设 DB_ASYNC_* 薄别名，
  消除双源维护与 L1/L3 分层模糊；http/tui 高频提交共享 execution 单源阈值，不依赖 db.base，无可抽新模块候选已评估为零候选。
  固定税 ≈ 两次跨线程唤醒（benchmarks.md 15–20µs 实测）；阈值 >2×固定税；inline 零拷贝，成功单例零分配。自适应钳位与首轮-1 逻辑保留（首轮保守同步零税，微查询免放大，长查询首包需显式预估），跨 http/tui 共享阈值可抽新模块候选已闭环无需新增。 }

type
  { 提交的阻塞工作体：在执行器专用线程运行；内部照常抛 EDbError }
  TDbAsyncWork = reference to procedure;

  {** 在途调用句柄。契约：
      - WaitFor(True) 后取结果：ErrorObj = nil 即成功；非 nil 时对象
        由句柄持有并在句柄析构时销毁——消费方不得手动 Free。
      - IsCanceled = 消费方请求过取消且以失败收场（错误应为
        decTimeout 族）；仅请求取消但自然成功时不置位。
      - Cancel 线程安全、尽力而为：触发后端中断原语；对已完成调用
        无害 no-op。
      - 生命周期纪律：连接必须活得比句柄久（取消控制面属于连接）。 *}
  IDbAsyncHandle = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE00E}']
    function IsDone: Boolean;
    function IsCanceled: Boolean;
    { True = 已完成（成功或已失败）；False = 超时仍在途 }
    function WaitFor(const ATimeoutMs: Cardinal): Boolean;
    function ErrorObj: Exception;
    procedure Cancel;
  end;

{ 编译期单源门禁：串/字节零拷贝单源完全由 bytes.ops/execution.base 单源承载，不设 DB_ASYNC_* 薄别名
  （BYTES_OPS_SINGLE_SOURCE 哨兵，execution.base 阈值单源；bytes 单源 owner=bytes.ops，阈值 owner=execution.base，L1 纯净） }
{$IF not BYTES_OPS_SINGLE_SOURCE}
{$MESSAGE FATAL 'bytes single source drift: BYTES_OPS_SINGLE_SOURCE must be True (owner=bytes.ops)'}
{$ENDIF}

  {** 执行器：一连接一实例一单工池。Submit 单飞——上一调用未收尾前
      再提交抛 EDbError。析构先等在途调用自然收尾（WaitAll），再由池
      关停工作线程，不留后台线程。 *}
  TDbAsyncExecutor = class
  private
    type
      { 在途记录。含托管字段（HandleRef/Work/Child），New/Dispose 自动管理；
        HandleRef/HandleRaw 双引用+@FOp 嵌入槽模式已收敛至 execution.single 共享模块（FPC trunk 临时量 workaround 集中于该共享模块），db 侧复用并扩展取消子令牌 }
      PDbAsyncOp = ^TDbAsyncOp;
      TDbAsyncOp = record
        { 双字段同一实例：托管引用保活（消费方先行丢弃句柄也不悬），裸指针供任务体零开销分发（共享模式见 execution.single.PExecOp） }
        HandleRef: IDbAsyncHandle;
        HandleRaw: TObject;
        Work: TDbAsyncWork;
        Child: IAsyncCancellationToken; { 消费方令牌的子令牌；nil = 未挂 }
      end;

      TDbAsyncHandle = class(TInterfacedObject, IDbAsyncHandle)
      private
        FLk: ILock;
        FDone: IEvent;
        FState: Integer;   { 原子：0=排队 1=在途 2=成功 3=失败 4=取消失败 }
        FCancelReq: Integer;              { 原子：消费方请求过取消 }
        FErrorObj: Exception;
        FCtrl: IDbCancelControl;          { 后端中断面；nil = 不支持 }
      public
        constructor Create(const ACtrl: IDbCancelControl);
        destructor Destroy; override;
        procedure MarkRunning; inline;
        { 落终态并接管异常对象所有权（AErr 可为 nil = 成功） }
        procedure Complete(AErr: Exception);
        { IDbAsyncHandle — inline 零拷贝：仅原子读/事件等待，无串拷贝 }
        function IsDone: Boolean; inline;
        function IsCanceled: Boolean; inline;
        function WaitFor(const ATimeoutMs: Cardinal): Boolean; inline;
        function ErrorObj: Exception;
        procedure Cancel;
      end;
    var
      FConn: IDbConnection;
      FCtrl: IDbCancelControl;            { 探测缓存；nil = 后端无此面 }
      FLk: ILock;
      FPool: IThreadPool;                 { 单工池 = 专用执行线程 }
      FOp: TDbAsyncOp;                    { 零堆分配嵌入槽：@FOp 零 New/Dispose，首轮微查询零固定税（共享模式见 execution.single.FOp） }
      FPending: PDbAsyncOp;               { 单飞槽：nil=空闲，否则=@FOp（执行期间仍占据，保证单飞） }
      FLastUs: Integer;                   { atomic: -1=无历史，否则上一执行实测 µs；首轮-1 逻辑保留 }
      procedure RunPendedOp(AOp: PDbAsyncOp);
      procedure WorkerRunTask;
      procedure FinalizeOp(AOp: PDbAsyncOp; AErr: Exception);
      procedure UpdateAdaptive(const AStart, AEnd: TInstant); inline;
      function ShouldOffloadAdaptive: Boolean; inline;
    public
      constructor Create(const AConn: IDbConnection);
      destructor Destroy; override;
      { 提交阻塞工作体。AToken 非 nil 时建立级联：令牌取消 → 后端中断 }
      function Submit(const AWork: TDbAsyncWork;
        const AToken: IAsyncCancellationToken = nil): IDbAsyncHandle; overload;
      { 自动退避重载：预估 <50µs 时零堆分配零投递，直接走 SubmitInline（inline 薄包装、零拷贝） }
      function Submit(const AWork: TDbAsyncWork; const AEstimatedUs: Cardinal;
        const AToken: IAsyncCancellationToken = nil): IDbAsyncHandle; overload; inline;
      { 零唤醒同步路径：调用线程直接执行，返回已完成句柄，规避固定税
        AUpdateAdaptive=False 时按需关时钟采样（微查询零固定税 + 零采样），默认 True 保留自适应学习 }
      function SubmitInline(const AWork: TDbAsyncWork;
        const AToken: IAsyncCancellationToken = nil;
        const AUpdateAdaptive: Boolean = True): IDbAsyncHandle;
      function InFlight: Boolean; inline;
  end;

implementation

{ 零分配零固定税内联完成句柄：成功路径共享单例，无 FLk/事件/原子，inline 零拷贝，零堆分配 }
type
  TDbInlineSuccessHandle = class(TInterfacedObject, IDbAsyncHandle)
  public
    function IsDone: Boolean; inline;
    function IsCanceled: Boolean; inline;
    function WaitFor(const ATimeoutMs: Cardinal): Boolean; inline;
    function ErrorObj: Exception; inline;
    procedure Cancel; inline;
  end;

var
  GInlineSuccessHandle: IDbAsyncHandle;

{ 取消桥（子令牌回调）：消费方令牌取消 → 后端尽力中断。
  上下文生命周期三重保证：
  1) 回调只在子令牌存活时可触发；
  2) 子令牌由执行器持有至 finalize（DetachFromParent 后摘链，f2b）；
  3) 子令牌注册先于入队，finalize 晚于摘链——op 记录全程存活。 }

procedure DbCancelBridgeProc(AData: Pointer);
var
  LOp: TDbAsyncExecutor.PDbAsyncOp;
begin
  LOp := TDbAsyncExecutor.PDbAsyncOp(AData);
  if (LOp <> nil) and (LOp^.HandleRaw <> nil) then
    TDbAsyncExecutor.TDbAsyncHandle(LOp^.HandleRaw).Cancel;
end;

type
  PInlineCancelCtx = ^TInlineCancelCtx;
  TInlineCancelCtx = record
    Flag: PInteger;
    Ctrl: IDbCancelControl;
  end;

procedure InlineCancelBridgeProc(AData: Pointer);
var
  Ctx: PInlineCancelCtx;
begin
  Ctx := PInlineCancelCtx(AData);
  if (Ctx <> nil) and (Ctx^.Flag <> nil) then
    atomic_exchange(Ctx^.Flag^, 1, mo_acq_rel);
  if (Ctx <> nil) and (Ctx^.Ctrl <> nil) then
    Ctx^.Ctrl.RequestCancel;
end;

function GetInlineSuccessHandle: IDbAsyncHandle; inline;
begin
  Result := GInlineSuccessHandle;
end;

{ ---- TDbAsyncExecutor.TDbAsyncHandle ---- }

constructor TDbAsyncExecutor.TDbAsyncHandle.Create(
  const ACtrl: IDbCancelControl);
begin
  inherited Create;
  FLk := nextpas.core.sync.mutex.TMutex.Create;
  FDone := CreateEvent(True);           { 手动复位：终态一次到位 }
  FState := 0;
  FCancelReq := 0;
  FCtrl := ACtrl;
end;

destructor TDbAsyncExecutor.TDbAsyncHandle.Destroy;
begin
  FErrorObj.Free;                       { 异常对象所有权在句柄 }
  FErrorObj := nil;
  inherited Destroy;
end;

procedure TDbAsyncExecutor.TDbAsyncHandle.MarkRunning; inline;
begin
  atomic_exchange(FState, 1, mo_acq_rel);
end;

procedure TDbAsyncExecutor.TDbAsyncHandle.Complete(AErr: Exception);
var
  LTarget: Integer;
begin
  if AErr = nil then
    LTarget := 2
  else if atomic_load(FCancelReq, mo_acquire) <> 0 then
    LTarget := 4                        { 请求过取消 + 失败 = 取消失败 }
  else
    LTarget := 3;
  FLk.Acquire;
  try
    FErrorObj := AErr;                  { 所有权移交（nil 安全） }
    atomic_exchange(FState, LTarget, mo_acq_rel);
    FDone.SetEvent;
  finally
    FLk.Release;
  end;
end;

function TDbAsyncExecutor.TDbAsyncHandle.IsDone: Boolean; inline;
begin
  Result := atomic_load(FState, mo_acquire) >= 2;
end;

function TDbAsyncExecutor.TDbAsyncHandle.IsCanceled: Boolean; inline;
begin
  Result := atomic_load(FState, mo_acquire) = 4;
end;

function TDbAsyncExecutor.TDbAsyncHandle.WaitFor(
  const ATimeoutMs: Cardinal): Boolean; inline;
begin
  Result := FDone.WaitTimeout(Int64(ATimeoutMs) * 1000000);
end;

function TDbAsyncExecutor.TDbAsyncHandle.ErrorObj: Exception;
begin
  FLk.Acquire;
  try
    Result := FErrorObj;
  finally
    FLk.Release;
  end;
end;

procedure TDbAsyncExecutor.TDbAsyncHandle.Cancel;
begin
  if atomic_load(FState, mo_acquire) >= 2 then
    Exit;                               { 已终态：no-op }
  atomic_exchange(FCancelReq, 1, mo_acq_rel);
  if FCtrl <> nil then
    FCtrl.RequestCancel;                { 尽力中断；结果由实际错误定夺 }
end;

{ ---- TDbAsyncExecutor ---- }

constructor TDbAsyncExecutor.Create(const AConn: IDbConnection);
begin
  inherited Create;
  if AConn = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db async: 连接不能为空');
  FConn := AConn;
  { 直接 QueryInterface（不用 SysUtils 的 Supports）；失败 = 后端无取消面 }
  FCtrl := nil;
  FConn.QueryInterface(IDbCancelControl, FCtrl);
  FLk := nextpas.core.sync.mutex.TMutex.Create;
  FPending := nil;
  FLastUs := -1;                              { -1=无历史，首轮保守同步零税（阈值 ~50µs，EXECUTION_MIN_WORTHWHILE_US；微查询免 20µs 固定税，长查询首包需显式预估 >阈值或 SubmitInline/同步直调保可取消） }
  FPool := CreateThreadPool(1);               { 单工 = 专用执行线程（经 execution 收敛，阈值单源 execution.base） }
end;

destructor TDbAsyncExecutor.Destroy;
var
  LOp: PDbAsyncOp;
begin
  { 停车顺序：等已入队任务全部收尾（含在途调用的自然结束——诚实
    语义，不半途丢弃）→ 兜底清理滞留槽 → 池关停工作线程 }
  FPool.WaitAll;
  LOp := FPending;
  FPending := nil;
  if LOp <> nil then
    FinalizeOp(LOp, EDbError.CreateSimple(dbkUnknown,
      'db async: 执行器销毁时调用尚未启动'));
  FPool.Shutdown;
  inherited Destroy;
end;

procedure TDbAsyncExecutor.UpdateAdaptive(const AStart, AEnd: TInstant); inline;
var
  LUs: Int64;
  LDur: TDuration;
begin
  { 单调不回退，单次原子写，inline 零额外分配；mo_relaxed 足够（阈值护栏为 advisory）
    钳位至 High(Integer) 防 Int64->Integer 回绕：超长查询 (>2147s) 仍判为值得 offload，不误判同步路径；自适应钳位保留
    时钟源经 L1 nextpas.core.time.base.TInstant.Now 单源（owner=time，L3 只经 time 封装） }
  LDur := AEnd.DurationSince(AStart);
  LUs := LDur.AsMicroseconds;
  if LUs < 0 then
    LUs := 0;
  if LUs > High(Integer) then
    LUs := High(Integer);
  atomic_store(FLastUs, Integer(LUs), mo_relaxed);
end;

function TDbAsyncExecutor.ShouldOffloadAdaptive: Boolean; inline;
var
  LUs: Integer;
begin
  { 单次原子读，inline 零拷贝；首轮未知保守同步零税：微查询 1.4µs 免 20µs 固定税放大（阈值 ~50µs，EXECUTION_MIN_WORTHWHILE_US=50 单源 execution.base）；
    长查询首包需显式预估 >阈值或走 SubmitInline/同步直调保可取消，次轮起按实测阈值退避；阈值单源 ExecutionShouldOffload（= execution.base，L1 纯净，http/tui 共享，bytes.ops 单源，无可抽新模块候选）；自适应钳位与首轮-1 逻辑保留 }
  LUs := atomic_load(FLastUs, mo_relaxed);
  if LUs < 0 then
    Exit(False);
  Result := ExecutionShouldOffload(Cardinal(LUs));
end;

procedure TDbAsyncExecutor.RunPendedOp(AOp: PDbAsyncOp);
var
  LErr: Exception;
  LStart, LEnd: TInstant;
begin
  TDbAsyncHandle(AOp^.HandleRaw).MarkRunning;
  LErr := nil;
  LStart := TInstant.Now;
  try
    AOp^.Work;
  except
    on E: Exception do
    begin
      AcquireExceptionObject;             { 阻止自动释放：跨作用域移交 }
      LErr := E;
    end;
  end;
  LEnd := TInstant.Now;
  UpdateAdaptive(LStart, LEnd);
  { finalize 自身不得让线程死亡：内部无抛出点（Complete/Dispose） }
  FinalizeOp(AOp, LErr);
end;

procedure TDbAsyncExecutor.WorkerRunTask;
var
  LOp: PDbAsyncOp;
begin
  { 零堆分配嵌入槽：FPending=@FOp 执行期间仍占据单飞槽，InFlight 持续
    为真直至 FinalizeOp 清槽；无 New/Dispose，托管引用在 FinalizeOp 清空 }
  FLk.Acquire;
  try
    LOp := FPending;
  finally
    FLk.Release;
  end;
  if LOp <> nil then
    RunPendedOp(LOp);
end;

procedure TDbAsyncExecutor.FinalizeOp(AOp: PDbAsyncOp; AErr: Exception);
var
  LCtrl: IDbCancelControl;
begin
  { 子令牌摘链先行：此后消费方令牌再取消不再触达本 op（f2b 的
    DetachFromParent 契约）。随后摘除取消面、句柄落终态、托管引用
    清零即释放（嵌入槽零 New/Dispose，首轮微查询零固定税）。清槽
    在锁内完成保证单飞纪律，InFlight 持续为真直至此。 }
  if AOp^.Child <> nil then
  begin
    AOp^.Child.DetachFromParent;
    AOp^.Child := nil;
  end;
  LCtrl := TDbAsyncHandle(AOp^.HandleRaw).FCtrl;
  if LCtrl <> nil then
    LCtrl.DisarmCancel;
  TDbAsyncHandle(AOp^.HandleRaw).Complete(AErr);
  { 零堆分配：嵌入槽托管引用清零即释放，无 Dispose }
  AOp^.HandleRef := nil;
  AOp^.HandleRaw := nil;
  AOp^.Work := nil;
  { 清单飞槽（锁内保证与 Submit 互斥） }
  FLk.Acquire;
  try
    if FPending = AOp then
      FPending := nil;
  finally
    FLk.Release;
  end;
end;

function TDbAsyncExecutor.Submit(const AWork: TDbAsyncWork;
  const AToken: IAsyncCancellationToken): IDbAsyncHandle;
var
  LOp: PDbAsyncOp;
  LHandle: TDbAsyncHandle;
  { 不变式 b 的物理载体：句柄的首个接口引用本地独立保活（FPC trunk 临时量生命周期坑：类指针不保活，构造后 rc=0；若唯一引用仅在 op 记录里 worker 可在取回 Result 前 finalize 析构致 UAF。此引用保证自创建起不可提前死亡；execution.single 为共享收敛非依赖，漂移不影响本单元保活）。 }
  LHeld: IDbAsyncHandle;
  LChild: IAsyncCancellationToken;
  LCtrl: IDbCancelControl;
  LConflict: Boolean;
  LSelf: TDbAsyncExecutor;
begin
  if AWork = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db async: 工作体不能为空');
  { 自适应护栏（无预估路径）：基于上一执行实测耗时自动退避，inline 薄包装、零拷贝，
    阈值单源 ExecutionShouldOffload（= execution.base，L1 纯净；阈值 50µs >2×固定税 20µs）；
    首轮未知保守同步零税（微查询免 20µs 固定税放大），长查询首包需显式预估 >阈值或 SubmitInline/同步直调；次轮起按实测退避。
    判据与 EstimatedUs 重载同源单点（http/tui 共享 execution 单源）。 }
  if not ShouldOffloadAdaptive then
    Exit(SubmitInline(AWork, AToken));
  LCtrl := FCtrl;
  LSelf := Self;
  { 零堆分配嵌入槽：LOp=@FOp，无 New/Dispose，首轮微查询亦零堆分配（共享模式见 execution.single，FPC workaround 集中）。全部装配先行，最后才入队可见 }
  LOp := @FOp;
  { 嵌入槽在空闲时托管字段已清零（Finalize 置 nil），此处防御性清零 }
  LOp^.HandleRaw := nil;
  LOp^.HandleRef := nil;
  LOp^.Work := nil;
  LOp^.Child := nil;
  LHeld := nil;
  LChild := nil;
  try
    LHandle := TDbAsyncHandle.Create(LCtrl);
    LHeld := LHandle;                     { 首个接口引用先行（rc 0→1） }
    LOp^.HandleRaw := LHandle;            { 对象身份：零开销分发 }
    LOp^.HandleRef := LHandle;            { 托管引用保活（引用计数 +1） }
    LOp^.Work := AWork;
    if AToken <> nil then
    begin
      LChild := AToken.CreateChildToken;
      LChild.OnCancel(@DbCancelBridgeProc, LOp);
      LOp^.Child := LChild;
      LChild := nil;
    end;
    { 取消面只在异步操作期间安装（sqlite 进度回调有每 N 步成本，
      常驻会污染同连接的同步直调——默认零成本硬规则）；与级联注册
      同属入队前装配。 }
    if LCtrl <> nil then
      LCtrl.ArmCancel;
  except
    if LOp^.Child <> nil then
    begin
      LOp^.Child.DetachFromParent;
      LOp^.Child := nil;
    end;
    if LChild <> nil then
    begin
      LChild.DetachFromParent;
      LChild := nil;
    end;
    if LCtrl <> nil then
      try
        LCtrl.DisarmCancel;
      except
      end;
    { 零堆分配：清零托管引用即释放，无 Dispose }
    LOp^.HandleRef := nil;
    LOp^.HandleRaw := nil;
    LOp^.Work := nil;
    raise;
  end;
  { 锁内单出口置位，冲突在锁外抛（FPC 工具链坑：锁持 try-finally 内
    raise 泄漏调用方临时接口——工厂 DbRegisterDriver 同款规避） }
  FLk.Acquire;
  try
    LConflict := FPending <> nil;
    if not LConflict then
      FPending := LOp;
  finally
    FLk.Release;
  end;
  if LConflict then
  begin
    if LOp^.Child <> nil then
    begin
      LOp^.Child.DetachFromParent;
      LOp^.Child := nil;
    end;
    if LCtrl <> nil then
      try
        LCtrl.DisarmCancel;
      except
      end;
    { 零堆分配：清零托管引用即释放，无 Dispose }
    LOp^.HandleRef := nil;
    LOp^.HandleRaw := nil;
    LOp^.Work := nil;
    raise EDbError.CreateSimple(dbkUnknown,
      'db async: 上一调用仍在途（单飞模型，禁止并发提交）');
  end;
  { 任务体捕获 Self 与 LOp：匿名闭包经 pool 投递到单工线程。
    槽即队列——worker 取件即清槽，无第二层缓冲。入队失败则整体
    回滚（清槽 + 摘链 + 释放 op），不留悬垂回调与死槽。 }
  try
    FPool.Submit(procedure
      begin
        LSelf.WorkerRunTask;
      end);
  except
    FLk.Acquire;
    try
      if FPending = LOp then
        FPending := nil;
    finally
      FLk.Release;
    end;
    if LOp^.Child <> nil then
    begin
      LOp^.Child.DetachFromParent;
      LOp^.Child := nil;
    end;
    if LCtrl <> nil then
      try
        LCtrl.DisarmCancel;
      except
      end;
    { 零堆分配：清零托管引用即释放，无 Dispose }
    LOp^.HandleRef := nil;
    LOp^.HandleRaw := nil;
    LOp^.Work := nil;
    raise;                              { 锁外重抛，生命周期照常管理 }
  end;
  { 不变式 b：此刻 op 记录可能已被 worker finalize；LHeld 保证对象
    存活，此处只做引用移交（嵌入槽无 Dispose，首轮微查询零固定税） }
  Result := LHeld;                      { 消费方引用（引用计数 +1） }
end;

function TDbAsyncExecutor.Submit(const AWork: TDbAsyncWork;
  const AEstimatedUs: Cardinal;
  const AToken: IAsyncCancellationToken): IDbAsyncHandle; inline;
begin
  { inline 薄包装：阈值外才支付 ~20µs 固定税（两次唤醒，嵌入槽零 New/Dispose，EXECUTION_MOUNT_OVERHEAD_US 单源 execution.base），
    阈值内零堆分配零投递，直接 SubmitInline（零拷贝 Move、bytes.ops 单源、
    单飞检查仍生效，终态语义一致；阈值单源 ExecutionShouldOffload，与自适应护栏同源单点，http/tui 共享 execution 单源）。 }
  if not ExecutionShouldOffload(AEstimatedUs) then
    Result := SubmitInline(AWork, AToken)
  else
    Result := Submit(AWork, AToken);
end;

function TDbAsyncExecutor.SubmitInline(const AWork: TDbAsyncWork;
  const AToken: IAsyncCancellationToken;
  const AUpdateAdaptive: Boolean): IDbAsyncHandle;
var
  LErr: Exception;
  LStart, LEnd: TInstant;
  LHandle: TDbAsyncHandle;
  LHeld: IDbAsyncHandle;
  LChild: IAsyncCancellationToken;
  LCancelFlag: Integer;
  LCtx: TInlineCancelCtx;
  LArmed: Boolean;
begin
  if AWork = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db async: 工作体不能为空');
  { 单飞检查：lock-free 原子读零 FLk 竞争（高频微查询热点零锁），acquire 可见写侧 FLk Release 后的 FPending；语义与 InFlight 同源，bytes.ops 单源不变，inline 零拷贝。 }
  if atomic_load(PPointer(@FPending)^, mo_acquire) <> nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db async: 上一调用仍在途（单飞模型，禁止并发提交）');
  { token 预检 + 内联取消桥：已取消则零执行直接落取消终态（尽力 honor，不静默忽略）；否则子令牌桥接后端中断（Arm/OnCancel/Disarm），inline 零拷贝 }
  LChild := nil;
  LCancelFlag := 0;
  LArmed := False;
  if AToken <> nil then
  begin
    if AToken.IsCancelled then
    begin
      if AUpdateAdaptive then
        LStart := TInstant.Now;
      LErr := EDbError.CreateSimple(decTimeout, 'db async: canceled');
      LHandle := TDbAsyncHandle.Create(FCtrl);
      LHeld := LHandle;
      LHandle.MarkRunning;
      LHandle.Cancel;
      LHandle.Complete(LErr);
      if AUpdateAdaptive then
      begin
        LEnd := TInstant.Now;
        UpdateAdaptive(LStart, LEnd);
      end;
      Result := LHeld;
      Exit;
    end;
    LCtx.Flag := @LCancelFlag;
    LCtx.Ctrl := FCtrl;
    LChild := AToken.CreateChildToken;
    LChild.OnCancel(@InlineCancelBridgeProc, @LCtx);
    if FCtrl <> nil then
    begin
      FCtrl.ArmCancel;
      LArmed := True;
    end;
  end;
  { 零唤醒零分配路径：成功时零堆分配零固定税——无 TDbAsyncHandle.Create、无 MarkRunning/Complete/FLk 轻锁，直接返回单例句柄（inline 零拷贝，bytes.ops 单源）。
    仅失败路径分配句柄承载异常对象并落终态；时钟采样按 AUpdateAdaptive 按需开关（False 零 syscall）。 }
  LErr := nil;
  if AUpdateAdaptive then
    LStart := TInstant.Now;
  try
    AWork();
  except
    on E: Exception do
    begin
      AcquireExceptionObject;
      LErr := E;
    end;
  end;
  if LChild <> nil then
  begin
    LChild.DetachFromParent;
    LChild := nil;
  end;
  LCtx.Ctrl := nil;
  if LArmed and (FCtrl <> nil) then
    try
      FCtrl.DisarmCancel;
    except
    end;
  if AUpdateAdaptive then
  begin
    LEnd := TInstant.Now;
    UpdateAdaptive(LStart, LEnd);
  end;
  if LErr = nil then
    Exit(GetInlineSuccessHandle);
  LHandle := TDbAsyncHandle.Create(FCtrl);
  LHeld := LHandle;
  LHandle.MarkRunning;
  if atomic_load(LCancelFlag, mo_acquire) <> 0 then
    LHandle.Cancel;
  LHandle.Complete(LErr);
  Result := LHeld;
end;

function TDbAsyncExecutor.InFlight: Boolean; inline;
begin
  { lock-free 诊断读：单次原子读，无互斥竞争；写侧 FLk 持有，读侧 acquire 可见 }
  Result := atomic_load(PPointer(@FPending)^, mo_acquire) <> nil;
end;

{ ---- TDbInlineSuccessHandle ---- }

function TDbInlineSuccessHandle.IsDone: Boolean; inline;
begin
  Result := True;
end;

function TDbInlineSuccessHandle.IsCanceled: Boolean; inline;
begin
  Result := False;
end;

function TDbInlineSuccessHandle.WaitFor(const ATimeoutMs: Cardinal): Boolean; inline;
begin
  Result := True;
end;

function TDbInlineSuccessHandle.ErrorObj: Exception; inline;
begin
  Result := nil;
end;

procedure TDbInlineSuccessHandle.Cancel; inline;
begin
end;

initialization
  GInlineSuccessHandle := TDbInlineSuccessHandle.Create;

finalization
  GInlineSuccessHandle := nil;

end.
