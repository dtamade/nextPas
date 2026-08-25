unit nextpas.core.db.async;

{** @desc db 异步挂载（V3-B6 / INC-4）：把阻塞 db 调用投递到专用
       执行线程，立即返回可等待、可取消的句柄。

       底座全部来自 core 家族（不在本单元造平行宇宙）：
       - 线程运行时初始化：nextpas.core.thread.init（cthreads 的正替，
         本单元建线程，故随单元引入保证初始化次序——tui.task 先例）；
       - 执行线程：nextpas.core.thread.pool 的单工池（1 worker），
         关停语义（Shutdown/WaitAll）由池负责；
       - 等待/事件：nextpas.core.sync 事件与互斥；
       - 取消令牌：nextpas.core.async 的 IAsyncCancellationToken；
       - 异常基座：nextpas.core.errors（不直接引 SysUtils）。

       硬规则（路线图 D8/G3，CONTRACT §2.17）：
       - 连接仍一连接一线程：一个执行器绑定一个连接租约，单飞模型
         （同一时刻至多一个在途调用），异步的是"等待"不是并发复用。
       - 取消经子令牌级联映射为后端中断原语（IDbCancelControl：pg =
         PQcancel，sqlite = progress handler 中断）；取消引发失败统一
         归一 decTimeout（"查询取消"语义位）。
       - 默认零成本：不使用本单元时 db 家族行为与同步直调逐字节一致。

       时序不变式（Submit 关键路径）：子令牌回调注册先于工作体入队
       ——否则极小工作体可能在注册完成前已执行完毕并释放 op 记录，
       回调上下文悬挂。 *}

{$I nextpas.core.settings.inc}

{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.atomic,
  nextpas.core.async.cancellation,
  nextpas.core.sync.event,
  nextpas.core.sync.mutex,
  nextpas.core.sync.intf,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool;

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

  {** 执行器：一连接一实例一单工池。Submit 单飞——上一调用未收尾前
      再提交抛 EDbError。析构先等在途调用自然收尾（WaitAll），再由池
      关停工作线程，不留后台线程。 *}
  TDbAsyncExecutor = class
  private
    type
      { 在途记录。含托管字段（HandleRef/Work/Child），New/Dispose 自动管理 }
      PDbAsyncOp = ^TDbAsyncOp;
      TDbAsyncOp = record
        { 双字段同一实例：托管引用保活（消费方先行丢弃句柄也不悬），
          裸指针供任务体零开销分发 }
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
        procedure MarkRunning;
        { 落终态并接管异常对象所有权（AErr 可为 nil = 成功） }
        procedure Complete(AErr: Exception);
        { IDbAsyncHandle }
        function IsDone: Boolean;
        function IsCanceled: Boolean;
        function WaitFor(const ATimeoutMs: Cardinal): Boolean;
        function ErrorObj: Exception;
        procedure Cancel;
      end;
    var
      FConn: IDbConnection;
      FCtrl: IDbCancelControl;            { 探测缓存；nil = 后端无此面 }
      FLk: ILock;
      FPool: IThreadPool;                 { 单工池 = 专用执行线程 }
      FPending: PDbAsyncOp;               { 单飞槽：槽即队列 }
      procedure RunPendedOp(AOp: PDbAsyncOp);
      procedure WorkerRunTask;
      procedure FinalizeOp(AOp: PDbAsyncOp; AErr: Exception);
    public
      constructor Create(const AConn: IDbConnection);
      destructor Destroy; override;
      { 提交阻塞工作体。AToken 非 nil 时建立级联：令牌取消 → 后端中断 }
      function Submit(const AWork: TDbAsyncWork;
        const AToken: IAsyncCancellationToken = nil): IDbAsyncHandle;
      function InFlight: Boolean;
  end;

implementation

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

procedure TDbAsyncExecutor.TDbAsyncHandle.MarkRunning;
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

function TDbAsyncExecutor.TDbAsyncHandle.IsDone: Boolean;
begin
  Result := atomic_load(FState, mo_acquire) >= 2;
end;

function TDbAsyncExecutor.TDbAsyncHandle.IsCanceled: Boolean;
begin
  Result := atomic_load(FState, mo_acquire) = 4;
end;

function TDbAsyncExecutor.TDbAsyncHandle.WaitFor(
  const ATimeoutMs: Cardinal): Boolean;
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
  FPool := CreateThreadPool(1);               { 单工 = 专用执行线程 }
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

procedure TDbAsyncExecutor.RunPendedOp(AOp: PDbAsyncOp);
var
  LErr: Exception;
begin
  TDbAsyncHandle(AOp^.HandleRaw).MarkRunning;
  LErr := nil;
  try
    AOp^.Work;
  except
    on E: Exception do
    begin
      AcquireExceptionObject;             { 阻止自动释放：跨作用域移交 }
      LErr := E;
    end;
  end;
  { finalize 自身不得让线程死亡：内部无抛出点（Complete/Dispose） }
  FinalizeOp(AOp, LErr);
end;

procedure TDbAsyncExecutor.WorkerRunTask;
var
  LOp: PDbAsyncOp;
begin
  { 任务体只捕获 Self；op 从单飞槽取走——取件即清槽（所有权移交
    worker，InFlight 随之翻假；finalize Dispose 后槽内不残留悬垂指针） }
  FLk.Acquire;
  try
    LOp := FPending;
    FPending := nil;
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
    DetachFromParent 契约）。随后摘除取消面、句柄落终态、Dispose
    释放 op 记录（托管字段 HandleRef/Work/Child 引用一并释放）。 }
  if AOp^.Child <> nil then
  begin
    AOp^.Child.DetachFromParent;
    AOp^.Child := nil;
  end;
  LCtrl := TDbAsyncHandle(AOp^.HandleRaw).FCtrl;
  if LCtrl <> nil then
    LCtrl.DisarmCancel;
  TDbAsyncHandle(AOp^.HandleRaw).Complete(AErr);
  Dispose(AOp);
end;

function TDbAsyncExecutor.Submit(const AWork: TDbAsyncWork;
  const AToken: IAsyncCancellationToken): IDbAsyncHandle;
var
  LOp: PDbAsyncOp;
  LHandle: TDbAsyncHandle;
  LChild: IAsyncCancellationToken;
  LCtrl: IDbCancelControl;
  LConflict: Boolean;
  LSelf: TDbAsyncExecutor;
begin
  if AWork = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'db async: 工作体不能为空');
  LCtrl := FCtrl;
  LSelf := Self;
  { 全部装配先行（句柄 + 级联），最后才入队可见——见单元头时序不变式 }
  New(LOp);
  LHandle := TDbAsyncHandle.Create(LCtrl);
  LOp^.HandleRaw := LHandle;            { 对象身份：零开销分发 }
  LOp^.HandleRef := LHandle;            { 托管引用保活（引用计数 +1） }
  LOp^.Work := AWork;
  LOp^.Child := nil;
  if AToken <> nil then
  begin
    LChild := AToken.CreateChildToken;
    LChild.OnCancel(@DbCancelBridgeProc, LOp);
    LOp^.Child := LChild;
  end;
  { 取消面只在异步操作期间安装（sqlite 进度回调有每 N 步成本，
    常驻会污染同连接的同步直调——默认零成本硬规则）；与级联注册
    同属入队前装配。 }
  if LCtrl <> nil then
    LCtrl.ArmCancel;
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
    Dispose(LOp);                       { 托管字段引用一并释放 }
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
      FPending := nil;
    finally
      FLk.Release;
    end;
    if LOp^.Child <> nil then
    begin
      LOp^.Child.DetachFromParent;
      LOp^.Child := nil;
    end;
    Dispose(LOp);                       { 托管字段引用一并释放 }
    raise;                              { 锁外重抛，生命周期照常管理 }
  end;
  Result := LOp^.HandleRef;             { 消费方引用（引用计数 +1） }
end;

function TDbAsyncExecutor.InFlight: Boolean;
begin
  FLk.Acquire;
  try
    Result := FPending <> nil;
  finally
    FLk.Release;
  end;
end;

end.
