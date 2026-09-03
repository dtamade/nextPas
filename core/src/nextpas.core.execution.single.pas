unit nextpas.core.execution.single;

{** @desc 通用单飞执行器（L1）：1 worker 单工池 + 嵌入式单飞槽 + 自适应阈值。
       为 db.async 等上层提供零平行宇宙的执行底座（thread.pool/sync/platform.time
       收敛于此，消费方仅依赖 execution 单一 L1）。零堆分配嵌入槽，首轮微任务
       亦零 New/Dispose；inline 零拷贝，阈值单源 execution.base（ExecutionShouldOffload/EXECUTION_*，L1 纯净，http/tui 共享）。
       HandleRef/HandleRaw 双引用+@FOp 嵌入槽为 FPC trunk 临时量生命周期缺陷的集中 workaround（共享模块候选已收敛于此，db.async 复用同一模式）。 */}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.sync.intf,
  nextpas.core.thread.intf,
  nextpas.core.execution.base,
  nextpas.core.execution.intf;

type
  TSingleFlightExecutor = class
  private
    type
      PExecOp = ^TExecOp;
      TExecOp = record
        { 双引用同一实例：HandleRef 托管保活（消费方先行丢弃句柄也不悬），HandleRaw 裸指针零开销分发；
          FPC 类指针不保活 workaround 集中于此共享模块（db.async 复用同一模式，仅扩展取消子令牌） }
        HandleRef: IExecutionHandle;
        HandleRaw: TObject;
        Work: TExecutionWork;
      end;
      TExecHandle = class(TInterfacedObject, IExecutionHandle)
      private
        FLk: ILock;
        FDone: IEvent;
        FState: Integer; { 0=排队 1=在途 2=成功 3=失败 }
        FErrorObj: Exception;
      public
        constructor Create;
        destructor Destroy; override;
        procedure MarkRunning; inline;
        procedure Complete(AErr: Exception);
        function IsDone: Boolean; inline;
        function WaitFor(const ATimeoutMs: Cardinal): Boolean; inline;
        function ErrorObj: Exception;
      end;
    var
      FLk: ILock;
      FPool: IThreadPool;
      FOp: TExecOp; { 零堆分配嵌入槽：@FOp 零 New/Dispose，首轮微任务亦零堆分配（FPC workaround 共享槽，db.async 同模式） }
      FPending: PExecOp;
      FLastUs: Integer;
      FThresholdUs: Cardinal;
      procedure RunPendedOp(AOp: PExecOp);
      procedure WorkerRunTask;
      procedure FinalizeOp(AOp: PExecOp; AErr: Exception);
      procedure UpdateAdaptive(const AStartNs, AEndNs: QWord); inline;
      function ShouldOffloadAdaptive: Boolean; inline;
  public
    constructor Create(const AThresholdUs: Cardinal = 50);
    destructor Destroy; override;
    function Submit(const AWork: TExecutionWork): IExecutionHandle; overload;
    function SubmitInline(const AWork: TExecutionWork;
      const AUpdateAdaptive: Boolean = True): IExecutionHandle;
    function InFlight: Boolean; inline;
    property ThresholdUs: Cardinal read FThresholdUs;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.sync.event,
  nextpas.core.sync.mutex,
  nextpas.core.thread.pool,
  nextpas.core.platform.time;

{ TSingleFlightExecutor.TExecHandle }

constructor TSingleFlightExecutor.TExecHandle.Create;
begin
  inherited Create;
  FLk := nextpas.core.sync.mutex.TMutex.Create;
  FDone := CreateEvent(True);
  FState := 0;
end;

destructor TSingleFlightExecutor.TExecHandle.Destroy;
begin
  FErrorObj.Free;
  FErrorObj := nil;
  inherited Destroy;
end;

procedure TSingleFlightExecutor.TExecHandle.MarkRunning; inline;
begin
  atomic_exchange(FState, 1, mo_acq_rel);
end;

procedure TSingleFlightExecutor.TExecHandle.Complete(AErr: Exception);
begin
  FLk.Acquire;
  try
    FErrorObj := AErr;
    if AErr = nil then
      atomic_exchange(FState, 2, mo_acq_rel)
    else
      atomic_exchange(FState, 3, mo_acq_rel);
    FDone.SetEvent;
  finally
    FLk.Release;
  end;
end;

function TSingleFlightExecutor.TExecHandle.IsDone: Boolean; inline;
begin
  Result := atomic_load(FState, mo_acquire) >= 2;
end;

function TSingleFlightExecutor.TExecHandle.WaitFor(const ATimeoutMs: Cardinal): Boolean; inline;
begin
  Result := FDone.WaitTimeout(Int64(ATimeoutMs) * 1000000);
end;

function TSingleFlightExecutor.TExecHandle.ErrorObj: Exception;
begin
  FLk.Acquire;
  try
    Result := FErrorObj;
  finally
    FLk.Release;
  end;
end;

{ TSingleFlightExecutor }

constructor TSingleFlightExecutor.Create(const AThresholdUs: Cardinal);
begin
  inherited Create;
  FThresholdUs := AThresholdUs;
  FLk := nextpas.core.sync.mutex.TMutex.Create;
  FPending := nil;
  FLastUs := -1;
  FPool := CreateThreadPool(1);
end;

destructor TSingleFlightExecutor.Destroy;
var
  LOp: PExecOp;
begin
  FPool.WaitAll;
  LOp := FPending;
  FPending := nil;
  if LOp <> nil then
    FinalizeOp(LOp, ENextPasError.Create('execution: executor destroy with pending op'));
  FPool.Shutdown;
  inherited Destroy;
end;

procedure TSingleFlightExecutor.UpdateAdaptive(const AStartNs, AEndNs: QWord); inline;
var
  LUs: QWord;
begin
  { 钳位至 High(Integer) 防 QWord->Integer 回绕：超长任务仍判为值得 offload }
  LUs := (AEndNs - AStartNs) div 1000;
  if LUs > QWord(High(Integer)) then
    LUs := QWord(High(Integer));
  atomic_store(FLastUs, Integer(LUs), mo_relaxed);
end;

function TSingleFlightExecutor.ShouldOffloadAdaptive: Boolean; inline;
var
  LUs: Integer;
begin
  { 首轮未知保守同步零税：微任务免固定税放大（阈值 ~50µs，EXECUTION_MIN_WORTHWHILE_US）；长任务首包需显式预估 >阈值或 SubmitInline，次轮起按实测阈值退避（ExecutionShouldOffload 单源，L1 纯净） }
  LUs := atomic_load(FLastUs, mo_relaxed);
  if LUs < 0 then
    Exit(False);
  Result := Cardinal(LUs) >= FThresholdUs;
end;

procedure TSingleFlightExecutor.RunPendedOp(AOp: PExecOp);
var
  LErr: Exception;
  LStart, LEnd: QWord;
begin
  TExecHandle(AOp^.HandleRaw).MarkRunning;
  LErr := nil;
  LStart := QWord(platform_monotonic_ns);
  try
    AOp^.Work();
  except
    on E: Exception do
    begin
      AcquireExceptionObject;
      LErr := E;
    end;
  end;
  LEnd := QWord(platform_monotonic_ns);
  UpdateAdaptive(LStart, LEnd);
  FinalizeOp(AOp, LErr);
end;

procedure TSingleFlightExecutor.WorkerRunTask;
var
  LOp: PExecOp;
begin
  FLk.Acquire;
  try
    LOp := FPending;
  finally
    FLk.Release;
  end;
  if LOp <> nil then
    RunPendedOp(LOp);
end;

procedure TSingleFlightExecutor.FinalizeOp(AOp: PExecOp; AErr: Exception);
begin
  TExecHandle(AOp^.HandleRaw).Complete(AErr);
  AOp^.HandleRef := nil;
  AOp^.HandleRaw := nil;
  AOp^.Work := nil;
  FLk.Acquire;
  try
    if FPending = AOp then
      FPending := nil;
  finally
    FLk.Release;
  end;
end;

function TSingleFlightExecutor.Submit(const AWork: TExecutionWork): IExecutionHandle;
var
  LOp: PExecOp;
  LHandle: TExecHandle;
  LHeld: IExecutionHandle;
  LConflict: Boolean;
  LSelf: TSingleFlightExecutor;
begin
  if AWork = nil then
    raise ENextPasError.Create('execution: work is nil');
  if not ShouldOffloadAdaptive then
    Exit(SubmitInline(AWork));
  LSelf := Self;
  LOp := @FOp;
  LOp^.HandleRaw := nil;
  LOp^.HandleRef := nil;
  LOp^.Work := nil;
  LHeld := nil;
  try
    LHandle := TExecHandle.Create;
    LHeld := LHandle;
    LOp^.HandleRaw := LHandle;
    LOp^.HandleRef := LHandle;
    LOp^.Work := AWork;
  except
    LOp^.HandleRef := nil;
    LOp^.HandleRaw := nil;
    LOp^.Work := nil;
    raise;
  end;
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
    LOp^.HandleRef := nil;
    LOp^.HandleRaw := nil;
    LOp^.Work := nil;
    raise ENextPasError.Create('execution: single-flight conflict');
  end;
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
    LOp^.HandleRef := nil;
    LOp^.HandleRaw := nil;
    LOp^.Work := nil;
    raise;
  end;
  Result := LHeld;
end;

function TSingleFlightExecutor.SubmitInline(const AWork: TExecutionWork;
  const AUpdateAdaptive: Boolean): IExecutionHandle;
var
  LHandle: TExecHandle;
  LHeld: IExecutionHandle;
  LErr: Exception;
  LStart, LEnd: QWord;
begin
  if AWork = nil then
    raise ENextPasError.Create('execution: work is nil');
  { lock-free 单飞检查：零 FLk 竞争，acquire 可见写侧 Release；与 InFlight 同源，db.async 同步收敛 }
  if atomic_load(PPointer(@FPending)^, mo_acquire) <> nil then
    raise ENextPasError.Create('execution: single-flight conflict');
  LHandle := TExecHandle.Create;
  LHeld := LHandle;
  LHandle.MarkRunning;
  LErr := nil;
  if AUpdateAdaptive then
    LStart := QWord(platform_monotonic_ns)
  else
    LStart := 0;
  try
    AWork();
  except
    on E: Exception do
    begin
      AcquireExceptionObject;
      LErr := E;
    end;
  end;
  if AUpdateAdaptive then
  begin
    LEnd := QWord(platform_monotonic_ns);
    UpdateAdaptive(LStart, LEnd);
  end;
  LHandle.Complete(LErr);
  Result := LHeld;
end;

function TSingleFlightExecutor.InFlight: Boolean; inline;
begin
  Result := atomic_load(PPointer(@FPending)^, mo_acquire) <> nil;
end;

end.
