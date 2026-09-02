unit nextpas.core.webview.fake;

{** @desc webview 无头脚本化后端：纯 Pascal、无引擎、无线程依赖，
       契约测试的唯一载体（CI 不需要图形环境）。

       职责边界（S1）：
       - 完整实现 IWebviewWindow 行为矩阵（状态机/exactly-one/close 语义）
       - invoke 经注册表直调（不经协议帧）；异常→错误码映射按
         CONTRACT §3.3 执行——该映射 S2 随 bridge 落地移入桥内，
         本单元届时改为帧路径转发。演进路径见 docs/webview/CONTRACT.md。
       - Dispatcher 用 sync owner 互斥保护 FIFO 环形队列：接口承诺的
         跨线程安全在 fake 上是真实现，不是测试专用降级。

       测试驱动面（仅测试可见的公共方法，均以 Fake/Fire/Queue/Set/Deliver
       前缀或独立语义命名）：PumpOnce/PumpAll、QueueEvalResult/QueueEvalError、
       FireNavigation*/FireReady/SetScale/SimulateBridgeReady、DeliverInvoke、
       调用记录读取器。

       资产面诚实声明：fake 只支持 embedded provider 挂载；
       MountDirectory 抛 ENotSupportedError（无头环境无文件资产）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.validation,
  nextpas.core.webview.bridge,
  nextpas.core.webview.live,
  nextpas.core.webview.callbacks,
  nextpas.core.bytes.ops,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.fake;

type
  {** invoke 结果记录（断言用）。 *}
  TFakeInvokeOutcome = record
    Cmd: string;
    IsError: Boolean;
    ResultJson: string;  // Ok 路径
    Code: string;        // Fail 路径（BRIDGE_PROTOCOL §5 词汇）
    Message: string;     // Fail 路径 / handler 异常原文
  end;

  TFakeInvokeOutcomes = array of TFakeInvokeOutcome;

  {** eval 结果记录（脚本与回执对，断言用）。 *}
  TFakeEvalRecord = record
    Script: string;
    Answered: Boolean;
    ResultJson: string;
    ErrorMessage: string;
  end;

  TFakeEvalRecords = array of TFakeEvalRecord;

  TFakeEmit = record
    Event: string;
    PayloadJson: string;
  end;
  TFakeEmits = array of TFakeEmit;

  { 在途 Eval：脚本记录下标 + 恰好一次回调对 }
  TFakePendingEval = record
    ScriptIdx: Integer;
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
  end;

  {** 接口引用 → 类引用 的安全通道（QueryInterface 驱动）。
      测试驱动面经 TFakeWebview.FromWindow 获取；禁止接口指针硬转
      类指针（COM 接口指针 ≠ 对象起始地址）。 *}
  IFakeSelfAccess = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E008}']
    function FakeSelf: TObject;
  end;

  {** 无头窗口。通过工厂 CreateFakeWebview 创建；本类型同时暴露
      确定性测试驱动面。 *}
  TFakeWebview = class(TInterfacedObject, IWebviewWindow, IFakeSelfAccess)
  private
    FLck: ILock;
    FClosed: Boolean;
    FWindow: IWindow;
    FOwnsWindow: Boolean;
    FZoom: Double;
    FUserAgent: string;
    FBridgeReady: Boolean;
    FDebugTools: Boolean;
    FInvokesIntf: IWebviewInvokeRegistry;   // 拥有（引用计数）
    FAssetsIntf: IWebviewAssets;            // 拥有
    FInvokes: TObject;             // 非拥有别名：同类私有访问用
    FAssets: TObject;              // 同上
    FEvalScripts: TFakeEvalRecords;
    FEvalScriptsCount: Integer;
    FEvalQueue: array of Boolean;  // 预载结果 FIFO：True=错误（值在 FEvalResults）
    FEvalResults: array of string; // 与 FEvalQueue 平行：成功 JSON 或错误消息
    FEvalQueueCount: Integer;
    FPendingEvals: array of TFakePendingEval;
    FPendingCount: Integer;
    FOutcomes: TFakeInvokeOutcomes;
    FOutcomesCount: Integer;
    { DeliverFrame 协议路径产生的回执脚本（resolve/reject）捕获队列 }
    FCapturedEvals: array of string;
    FCapturedCount: Integer;
    FEmits: TFakeEmits;
    FEmitsCount: Integer;
    FDroppedEmits: Integer;
    FNavigateCount: Integer;
    FReloadCount: Integer;
    FStopCount: Integer;
    FHistory: array of string;
    FHistoryCount: Integer;
    FHistIdx: Integer;
    FOnNavStarted: array of TWebviewNavEventHandler;
    FOnNavStartedCount: Integer;
    FOnNavFinished: array of TWebviewNavEventHandler;
    FOnNavFinishedCount: Integer;
    FOnNavFailed: array of TWebviewNavFailedHandler;
    FOnNavFailedCount: Integer;
    FOnReady: array of TWebviewNotifyHandler;
    FOnReadyCount: Integer;
    procedure RequireOpen;
    procedure GrowQueue; inline;
    procedure RecordOutcome(const ACmd: string; AIsError: Boolean;
      const AResultJson, ACode, AMessage: string);
    { 回执 Eval 脚本捕获队列（DeliverFrame 协议路径专用） }
    procedure EnqueueReceipt(AFrameId: Int64; AIsError: Boolean;
      const AResultJson, ACode, AMessage: string);
    { DeliverInvoke/DeliverFrame 公共分发体；AFrameId < 0 表示无帧直呼 }
    procedure DispatchInvoke(AFrameId: Int64; const ACmd,
      APayloadJson: string);
    procedure PushHistory(const AUrl: string);
    procedure FireReadyHandlers;
    procedure AppendEvalScript(const AScript: string);
    procedure ShiftEvalQueue;
    procedure ShiftEvalList;
    procedure SettleEval(AIdx: Integer; AIsError: Boolean;
      const AValue: string;
      ACallback: TWebviewEvalCallback;
      AOnError: TWebviewEvalErrorCallback);
  protected
    { IWebviewWindow }
    function GetWindow: IWindow;
    procedure Close; virtual;
    function IsClosed: Boolean; inline;
    procedure SetZoom(AFactor: Double); virtual;
    function GetZoom: Double;
    procedure SetUserAgent(const AUserAgent: string); virtual;
    function GetUserAgent: string;
    procedure Navigate(const AUrl: string); virtual;
    procedure NavigateToString(const AHtml: string); virtual;
    procedure Reload; virtual;
    procedure Stop; virtual;
    function CanGoBack: Boolean;
    function GoBack: Boolean;
    function CanGoForward: Boolean;
    function GoForward: Boolean;
    procedure Eval(const AJavascript: string;
      ACallback: TWebviewEvalCallback;
      AOnError: TWebviewEvalErrorCallback); virtual;
    procedure Emit(const AEvent, APayloadJson: string); virtual;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload; virtual;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventMethod); overload; virtual;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventProc); overload; virtual;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload; virtual;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventMethod); overload; virtual;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventProc); overload; virtual;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload; virtual;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedMethod); overload; virtual;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload; virtual;
    procedure OnReady(AHandler: TWebviewNotifyHandler); overload; virtual;
    procedure OnReady(AHandler: TWebviewNotifyMethod); overload; virtual;
    procedure OnReady(AHandler: TWebviewNotifyProc); overload; virtual;
    function GetInvokes: IWebviewInvokeRegistry;
    function GetAssets: IWebviewAssets;
  public
    { 接口引用安全取回类引用；非 fake 窗口抛 EWebviewInvalidState }
    class function FromWindow(const AW: IWebviewWindow): TFakeWebview; static;
    function FakeSelf: TObject;
    constructor Create(const AOptions: TWebviewOptions); virtual;
    constructor CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions); virtual;
    destructor Destroy; override;

    { ---- 测试驱动面 ---- }

    { 泵一次/泵空主线程投递队列 }
    function PumpOnce: Boolean;
    procedure PumpAll;
    function PendingPosts: Integer;

    { 预载 eval 回执 FIFO；有在途 pending 时立即兑现最老一条 }
    procedure QueueEvalResult(const AResultJson: string);
    procedure QueueEvalError(const AMessage: string);

    { 手动触发导航事件（Url 进记录，不影响历史） }
    procedure FireNavigationStarted(const AUrl: string);
    procedure FireNavigationFinished(const AUrl: string);
    procedure FireNavigationFailed(const AUrl: string;
      ACode: Integer; const AMessage: string);
    procedure FireReady;
    procedure SimulateBridgeReady;

    { 模拟一帧 invoke 到达：查注册表→执行 handler→记录 outcome。
      同步 handler 内联执行；异步 handler 的 completion 经 dispatcher
      marshal（需 Pump 兑现 outcome 记录）。 }
    procedure DeliverInvoke(const ACmd, APayloadJson: string);

    { 协议入口（BRIDGE_PROTOCOL §8）：完整走过 bridge——解码校验帧后按
      id 关联回执；非法帧抛 EWebviewBadFrame。成功/失败的 resolve/reject
      Eval 脚本进捕获队列（异步路径在 Pump 兑现后入队）。 }
    procedure DeliverFrame(const AFrameJson: string);

    { 回执脚本捕获队列读取器 }
    function CaptureEvalCount: Integer;
    function CaptureEvalAt(AIndex: Integer): string;

    { 调用记录读取器 }
    function OutcomeCount: Integer;
    function OutcomeAt(AIndex: Integer): TFakeInvokeOutcome;
    function LastOutcome: TFakeInvokeOutcome;
    function EmitCount: Integer;
    function DroppedEmitCount: Integer;
    function LastEmitEvent: string;
    function LastEmitPayloadJson: string;
    function NavigateCount: Integer;
    function EvalRecordCount: Integer;
    function EvalRecordAt(AIndex: Integer): TFakeEvalRecord;
  end;

{ 活跃 fake 窗口数（factory 的 RunLoop 退出条件） }
function FakeLiveWindowCount: Integer;

{ 对所有活跃 fake 窗口各泵一次投递队列 }
procedure FakePumpAll;

implementation

{ handler 异常 → 协议错误码映射：唯一实现移至 bridge（NormalizeInvokeCode），
  fake 与未来真实后端共用同一映射，避免双处定义漂移。 }
function MapInvokeCode(const ACode: string): string;
begin
  Result := NormalizeInvokeCode(ACode);
end;

{ ---- 回调归一化（method/proc → reference）----
  统一存储范式（design-conventions §8）：内部只存 reference 形态。
  单源：nextpas.core.webview.callbacks inline 薄转发，零拷贝闭包，消除四后端重复。 }

function NotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler; inline;
begin
  Result := WebviewNotifyMethodToRef(AHandler);
end;

function NotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler; inline;
begin
  Result := WebviewNotifyProcToRef(AHandler);
end;

function NavMethodToRef(AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler; inline;
begin
  Result := WebviewNavMethodToRef(AHandler);
end;

function NavProcToRef(AHandler: TWebviewNavEventProc): TWebviewNavEventHandler; inline;
begin
  Result := WebviewNavProcToRef(AHandler);
end;

function NavFailedMethodToRef(AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler; inline;
begin
  Result := WebviewNavFailedMethodToRef(AHandler);
end;

function NavFailedProcToRef(AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler; inline;
begin
  Result := WebviewNavFailedProcToRef(AHandler);
end;

function ScaleMethodToRef(AHandler: TWebviewScaleMethod): TWebviewScaleHandler; inline;
begin
  Result := WebviewScaleMethodToRef(AHandler);
end;

function ScaleProcToRef(AHandler: TWebviewScaleProc): TWebviewScaleHandler; inline;
begin
  Result := WebviewScaleProcToRef(AHandler);
end;

{ ---- TFakeDispatcher：互斥保护的环形 FIFO ---- }

type
  TFakeDispatcherRing = array of TWebviewProcRef;
  TFakeDispatcher = class(TInterfacedObject, IWebviewDispatcher)
  private
    FLck: ILock;
    FRing: TFakeDispatcherRing;
    FHead: Integer;
    FCount: Integer;
    FOwnerThread: UInt64;
    procedure LinearizeCopy(const AOldRing: TFakeDispatcherRing; AHead, ACount: Integer; var ANew: TFakeDispatcherRing); inline;
    procedure GrowCopy(var LNew: TFakeDispatcherRing); inline;
    procedure Grow; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure PostRef(AProc: TWebviewProcRef); inline;
    function IsOnMainThread: Boolean; inline;
    function PumpOnce: Boolean;
    procedure PumpAll;
    function PendingCount: Integer;
    procedure DropAll;
    { IWebviewDispatcher }
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
  end;

constructor TFakeDispatcher.Create;
begin
  inherited Create;
  FLck := TMutex.Create as ILock;
  FOwnerThread := platform_thread_id;
end;

destructor TFakeDispatcher.Destroy;
begin
  DropAll;
  inherited Destroy;
end;

procedure TFakeDispatcher.LinearizeCopy(const AOldRing: TFakeDispatcherRing; AHead, ACount: Integer; var ANew: TFakeDispatcherRing); inline;
var
  I, LTail, LOldLen: Integer;
begin
  // perf: two-segment linearize avoids mod/div per element, inline zero extra call, single source for ring linearization (bytes.ops VecGrowCapacity outer); zero extra alloc, managed ref per element preserved
  if ACount = 0 then Exit;
  LOldLen := Length(AOldRing);
  if AHead + ACount <= LOldLen then
  begin
    for I := 0 to ACount - 1 do
      ANew[I] := AOldRing[AHead + I];
  end
  else
  begin
    LTail := LOldLen - AHead;
    for I := 0 to LTail - 1 do
      ANew[I] := AOldRing[AHead + I];
    for I := 0 to ACount - LTail - 1 do
      ANew[LTail + I] := AOldRing[I];
  end;
end;

procedure TFakeDispatcher.GrowCopy(var LNew: TFakeDispatcherRing); inline;
var
  LOldLen, I, LTail: Integer;
begin
  // compat: legacy inline copy under lock kept only for non-contended Grow; Post storm path uses LinearizeCopy outside lock (see PostRef) to avoid O(n) lock amplification
  LOldLen := Length(FRing);
  if FCount = 0 then
  begin
    FRing := LNew;
    FHead := 0;
    Exit;
  end;
  if FHead + FCount <= LOldLen then
  begin
    for I := 0 to FCount - 1 do
      LNew[I] := FRing[FHead + I];
  end
  else
  begin
    LTail := LOldLen - FHead;
    for I := 0 to LTail - 1 do
      LNew[I] := FRing[FHead + I];
    for I := 0 to FCount - LTail - 1 do
      LNew[LTail + I] := FRing[I];
  end;
  // stability: FRing:=LNew releases old ring refs via finalization, LNew retains refs (AddRef already), zero leak
  FRing := LNew;
  FHead := 0;
end;

procedure TFakeDispatcher.Grow; inline;
var
  LNew: TFakeDispatcherRing;
begin
  // perf: single source bytes.ops VecGrowCapacity (0→4→2×) inline; base pure, zero wrapper, zero extra call
  SetLength(LNew, VecGrowCapacity(Length(FRing)));
  GrowCopy(LNew);
end;

procedure TFakeDispatcher.PostRef(AProc: TWebviewProcRef); inline;
var
  LNew: TFakeDispatcherRing;
  LOldRing: TFakeDispatcherRing;
  LHead, LCount, LOldLen, LNewCap, I, LTail: Integer;
begin
  // perf: fast path under lock without alloc
  FLck.Acquire;
  try
    if FCount < Length(FRing) then
    begin
      FRing[(FHead + FCount) mod Length(FRing)] := AProc;
      Inc(FCount);
      Exit;
    end;
    LOldLen := Length(FRing);
    LNewCap := VecGrowCapacity(LOldLen);
    LOldRing := FRing;
    LHead := FHead;
    LCount := FCount;
  finally
    FLck.Release;
  end;
  // perf: heap allocation (SetLength zero-init) outside lock, avoids O(n) lock amplification, single source bytes.ops VecGrowCapacity inline
  SetLength(LNew, LNewCap);
  // perf: O(n) two-segment linearize outside lock — zero lock hold, inline zero extra call, single source LinearizeCopy, bytes.ops capacity single source
  LinearizeCopy(LOldRing, LHead, LCount, LNew);
  // perf: short install under lock — only pointer swap + one slot write, O(1), stale check via length/head/count, single attempt no spin
  FLck.Acquire;
  try
    if FCount < Length(FRing) then
    begin
      FRing[(FHead + FCount) mod Length(FRing)] := AProc;
      Inc(FCount);
      Exit;
    end;
    if (Length(FRing) <> LOldLen) or (FHead <> LHead) or (FCount <> LCount) then
    begin
      // contention: stale snapshot — fallback to single in-lock relinearize without extra alloc/spin
      // perf: at most one extra SetLength inside lock on contention, no outside retry loop, avoids extra SetLength + spin under storm
      if Length(LNew) <> VecGrowCapacity(Length(FRing)) then
        SetLength(LNew, VecGrowCapacity(Length(FRing)));
      if FCount > 0 then
      begin
        if FHead + FCount <= Length(FRing) then
          for I := 0 to FCount - 1 do
            LNew[I] := FRing[FHead + I]
        else
        begin
          LTail := Length(FRing) - FHead;
          for I := 0 to LTail - 1 do
            LNew[I] := FRing[FHead + I];
          for I := 0 to FCount - LTail - 1 do
            LNew[LTail + I] := FRing[I];
        end;
      end;
    end;
    // stability: FRing:=LNew releases old ring refs via finalization, LNew retains refs (AddRef), zero leak
    FRing := LNew;
    FHead := 0;
    FRing[FCount] := AProc;
    Inc(FCount);
  finally
    FLck.Release;
  end;
end;

function TFakeDispatcher.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

function TFakeDispatcher.PumpOnce: Boolean;
var
  LProc: TWebviewProcRef;
begin
  FLck.Acquire;
  try
    if FCount = 0 then
      Exit(False);
    LProc := FRing[FHead];
    FRing[FHead] := nil;
    FHead := (FHead + 1) mod Length(FRing);
    FCount := FCount - 1;
  finally
    FLck.Release;
  end;
  LProc();
  LProc := nil;
  Result := True;
end;

procedure TFakeDispatcher.PumpAll;
begin
  while PumpOnce do ;
end;

function TFakeDispatcher.PendingCount: Integer;
begin
  FLck.Acquire;
  try
    Result := FCount;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.DropAll;
var
  I: Integer;
begin
  FLck.Acquire;
  try
    for I := 0 to FCount - 1 do
      FRing[(FHead + I) mod Length(FRing)] := nil;
    FCount := 0;
    FHead := 0;
  finally
    FLck.Release;
  end;
end;

procedure TFakeDispatcher.Post(AProc: TWebviewProcRef);
begin
  PostRef(AProc);
end;

procedure TFakeDispatcher.Post(AProc: TWebviewProcMethod);
begin
  PostRef(NotifyMethodToRef(AProc));
end;

procedure TFakeDispatcher.Post(AProc: TWebviewProc);
begin
  PostRef(NotifyProcToRef(AProc));
end;

{ ---- invoke 注册表：唯一实现收敛到 bridge（TWebviewInvokeRegistry）----
  fake 仅保留别名；gtk 后端复用同一实现，杜绝双处漂移。 }

type
  TFakeInvokeRegistry = nextpas.core.webview.bridge.TWebviewInvokeRegistry;

{ ---- 资产存储：唯一实现收敛到 bridge（TWebviewAssetsImpl）---- }

type
  TFakeAssets = nextpas.core.webview.bridge.TWebviewAssetsImpl;

{ ---- TFakeCompletion：at-most-once + 主线程 marshal ---- }

type
  TFakeCompletion = class(TInterfacedObject, IWebviewInvokeCompletion)
  private
    FWin: TObject;
    FCmd: string;
    { 来源帧 id；<0 表示 driver 直呼（DeliverInvoke），不产生回执脚本 }
    FFrameId: Int64;
    FDone: Boolean;
    procedure RecordViaDispatcher(AIsError: Boolean;
      const AResultJson, ACode, AMessage: string);
  public
    constructor Create(AWin: TObject; const ACmd: string; AFrameId: Int64);
    procedure Ok(const AResultJson: string);
    procedure Fail(const ACode, AMessage: string);
  end;

constructor TFakeCompletion.Create(AWin: TObject; const ACmd: string;
  AFrameId: Int64);
begin
  inherited Create;
  FWin := AWin;
  FCmd := ACmd;
  FFrameId := AFrameId;
end;

procedure TFakeCompletion.RecordViaDispatcher(AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LWin: TFakeWebview;
  LCmd: string;
  LFrameId: Int64;
begin
  LCmd := FCmd;
  LFrameId := FFrameId;
  LWin := FWin as TFakeWebview;
  LWin.GetWindow.Dispatcher.Post(
    procedure
    begin
      LWin.RecordOutcome(LCmd, AIsError, AResultJson, ACode, AMessage);
      if LFrameId >= 0 then
        LWin.EnqueueReceipt(LFrameId, AIsError, AResultJson,
          NormalizeInvokeCode(ACode), AMessage);
    end);
end;

procedure TFakeCompletion.Ok(const AResultJson: string);
begin
  if FDone then
    raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  RecordViaDispatcher(False, AResultJson, '', '');
end;

procedure TFakeCompletion.Fail(const ACode, AMessage: string);
begin
  if FDone then
    raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  RecordViaDispatcher(True, '',
    ACode, AMessage);
end;

{ 活跃窗口登记（factory RunLoop 的退出事实源）。
  计数口径 = 未 Close 的窗口（持有引用但已 Close 不计入）。 }

var
  GLiveWindows: array of TFakeWebview;
  GLiveWindowsCount: Integer = 0;
  GLiveCount: Integer = 0;

{ GLiveWindows 操作单源收敛到 nextpas.core.webview.live (bytes.ops Vec 单源 inline)：
  GrowLiveWindows/RegisterLive/UnregisterLive 四后端重复已抽至 live 泛型 helpers，
  本单元仅薄转发，零额外堆分配 }
procedure GrowLiveWindows; inline;
begin
  // perf: thin forward to bytes.ops VecGrow single source (0→4→2×), inline
  specialize VecGrow<TFakeWebview>(GLiveWindows, GLiveWindowsCount);
end;

procedure RegisterLive(AWin: TFakeWebview); inline;
begin
  // perf: single source WebviewLiveAdd -> VecGrow inline, zero extra alloc
  specialize WebviewLiveAdd<TFakeWebview>(GLiveWindows, GLiveWindowsCount, AWin);
  Inc(GLiveCount);
end;

procedure UnregisterLive(AWin: TFakeWebview); inline;
begin
  // stability: if never Close'd, live count was still 1 — decrement here; already Closed windows decremented at Close time
  if not AWin.FClosed then
    Dec(GLiveCount);
  // perf: O(1) swap-remove inline, nil trailing to release ref
  specialize WebviewLiveRemoveSwap<TFakeWebview>(GLiveWindows, GLiveWindowsCount, AWin);
end;

function FakeLiveWindowCount: Integer; inline;
begin
  // perf: O(1) cached count inline, zero scan, close 密集零遍历
  Result := GLiveCount;
end;

procedure FakePumpAll;
var
  I: Integer;
begin
  for I := 0 to GLiveWindowsCount - 1 do
    if not GLiveWindows[I].FClosed then
      GLiveWindows[I].PumpOnce;
end;

{ ---- TFakeWebview ---- }

class function TFakeWebview.FromWindow(
  const AW: IWebviewWindow): TFakeWebview;
var
  LAcc: IFakeSelfAccess;
begin
  if (AW <> nil) and (AW.QueryInterface(IFakeSelfAccess, LAcc) = 0) then
    Result := LAcc.FakeSelf as TFakeWebview
  else
    raise EWebviewInvalidState.Create(
      'window is not a nextpas.core.webview.fake instance');
end;

function TFakeWebview.FakeSelf: TObject;
begin
  Result := Self;
end;

function WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions;
begin
  Result := DefaultWindowOptions;
  Result.Title := AOptions.Title;
  Result.Width := AOptions.Width;
  Result.Height := AOptions.Height;
  Result.MinWidth := AOptions.MinWidth;
  Result.MinHeight := AOptions.MinHeight;
  Result.MaxWidth := AOptions.MaxWidth;
  Result.MaxHeight := AOptions.MaxHeight;
  Result.Resizable := AOptions.Resizable;
  Result.Maximized := AOptions.Maximized;
  Result.ParentHandle := nil;
end;

constructor TFakeWebview.Create(const AOptions: TWebviewOptions);
var
  LReg: TFakeInvokeRegistry;
  LAssets: TFakeAssets;
  LWinOpts: TWindowOptions;
begin
  inherited Create;
  FLck := TMutex.Create as ILock;
  FClosed := False;
  FZoom := 1.0;
  FUserAgent := '';
  FBridgeReady := False;
  FDebugTools := AOptions.DebugTools;
  LWinOpts := WindowOptionsOf(AOptions);
  FWindow := TFakeWindow.Create(LWinOpts);
  FOwnsWindow := True;
  LReg := TFakeInvokeRegistry.Create;
  LAssets := TFakeAssets.Create(AOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;    { 拥有（引用计数） }
  FAssetsIntf := LAssets;
  FInvokes := LReg;        { 非拥有别名（同类私有访问） }
  FAssets := LAssets;
  FDroppedEmits := 0;
  FNavigateCount := 0;
  FHistoryCount := 0;
  FHistIdx := -1;
  RegisterLive(Self);

  { Initial* 启动加载：构造即导航。优先级 InitialUrl > InitialHtml
    （CONTRACT §2.2），资产/桥请求都在主循环泵里才发生，Build 返回后的
    挂载先于任何请求，无时序竞态（§3.4） }
  if AOptions.InitialUrl <> '' then
    Navigate(AOptions.InitialUrl)
  else if AOptions.InitialHtml <> '' then
    NavigateToString(AOptions.InitialHtml);
end;

constructor TFakeWebview.CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions);
var
  LReg: TFakeInvokeRegistry;
  LAssets: TFakeAssets;
begin
  inherited Create;
  if AParent = nil then
    raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn');
  FLck := TMutex.Create as ILock;
  FClosed := False;
  FZoom := 1.0;
  FUserAgent := '';
  FBridgeReady := False;
  FDebugTools := AOptions.DebugTools;
  FWindow := AParent;
  FOwnsWindow := False;
  LReg := TFakeInvokeRegistry.Create;
  LAssets := TFakeAssets.Create(AOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;
  FAssetsIntf := LAssets;
  FInvokes := LReg;
  FAssets := LAssets;
  FDroppedEmits := 0;
  FNavigateCount := 0;
  FHistoryCount := 0;
  FHistIdx := -1;
  RegisterLive(Self);
  if AOptions.InitialUrl <> '' then
    Navigate(AOptions.InitialUrl)
  else if AOptions.InitialHtml <> '' then
    NavigateToString(AOptions.InitialHtml);
end;

destructor TFakeWebview.Destroy;
begin
  UnregisterLive(Self);
  inherited Destroy;
end;

procedure TFakeWebview.RequireOpen;
begin
  if FClosed then
    raise EWebviewClosed.Create('webview window is closed');
end;

procedure TFakeWebview.GrowQueue; inline;
begin
  if FEvalQueueCount = Length(FEvalQueue) then
  begin
    specialize VecGrow<Boolean>(FEvalQueue, FEvalQueueCount);
    specialize VecGrow<string>(FEvalResults, FEvalQueueCount);
  end;
end;

procedure TFakeWebview.RecordOutcome(const ACmd: string; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LNew: TFakeInvokeOutcomes;
  LCap, I: Integer;
begin
  // perf: fast path under lock without alloc; contended path alloc outside lock (SetLength zero-init) to avoid lock-amplification jitter
  FLck.Acquire;
  try
    if FOutcomesCount < Length(FOutcomes) then
    begin
      FOutcomes[FOutcomesCount].Cmd := ACmd;
      FOutcomes[FOutcomesCount].IsError := AIsError;
      FOutcomes[FOutcomesCount].ResultJson := AResultJson;
      FOutcomes[FOutcomesCount].Code := ACode;
      FOutcomes[FOutcomesCount].Message := AMessage;
      Inc(FOutcomesCount);
      Exit;
    end;
    LCap := VecGrowCapacity(Length(FOutcomes));
  finally
    FLck.Release;
  end;
  // perf: heap allocation (SetLength zero-init) outside lock, avoids O(n) lock amplification under invoke storm, single source VecGrowCapacity inline
  SetLength(LNew, LCap);
  FLck.Acquire;
  try
    if FOutcomesCount < Length(FOutcomes) then
    begin
      FOutcomes[FOutcomesCount].Cmd := ACmd;
      FOutcomes[FOutcomesCount].IsError := AIsError;
      FOutcomes[FOutcomesCount].ResultJson := AResultJson;
      FOutcomes[FOutcomesCount].Code := ACode;
      FOutcomes[FOutcomesCount].Message := AMessage;
      Inc(FOutcomesCount);
      Exit;
    end;
    if Length(LNew) <= Length(FOutcomes) then
      SetLength(LNew, VecGrowCapacity(Length(FOutcomes)));
    // perf: copy linearization under lock only, inline zero extra call, bytes.ops single source
    for I := 0 to FOutcomesCount - 1 do
      LNew[I] := FOutcomes[I];
    // stability: FOutcomes:=LNew releases old ring refs via refcount, LNew retains (AddRef), zero leak
    FOutcomes := LNew;
    FOutcomes[FOutcomesCount].Cmd := ACmd;
    FOutcomes[FOutcomesCount].IsError := AIsError;
    FOutcomes[FOutcomesCount].ResultJson := AResultJson;
    FOutcomes[FOutcomesCount].Code := ACode;
    FOutcomes[FOutcomesCount].Message := AMessage;
    Inc(FOutcomesCount);
  finally
    FLck.Release;
  end;
end;

procedure TFakeWebview.PushHistory(const AUrl: string);
var
  I: Integer;
begin
  if FHistIdx + 1 < FHistoryCount then
  begin
    for I := FHistIdx + 2 to FHistoryCount - 1 do
      FHistory[I] := '';
    FHistoryCount := FHistIdx + 1;
  end;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<string>(FHistory, FHistoryCount);
  FHistory[FHistoryCount] := AUrl;
  Inc(FHistoryCount);
  FHistIdx := FHistoryCount - 1;
end;

procedure TFakeWebview.FireReadyHandlers;
var
  I: Integer;
begin
  for I := 0 to FOnReadyCount - 1 do
    FOnReady[I]();
end;

procedure TFakeWebview.AppendEvalScript(const AScript: string);
begin
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TFakeEvalRecord>(FEvalScripts, FEvalScriptsCount);
  FEvalScripts[FEvalScriptsCount].Script := AScript;
  FEvalScripts[FEvalScriptsCount].Answered := False;
  Inc(FEvalScriptsCount);
end;

function TFakeWebview.GetWindow: IWindow;
begin
  Result := FWindow;
end;

procedure TFakeWebview.Close;
var
  I, LPendingCount: Integer;
  LPending: array of TFakePendingEval;
  LErr: EWebviewEvalFailed;
  LOnError: TWebviewEvalErrorCallback;
begin
  FLck.Acquire;
  try
    if FClosed then
      Exit;
    FClosed := True;
    // perf: O(1) live count decrement under instance lock (single writer), close密集零扫描
    Dec(GLiveCount);
    // perf: zero-alloc snapshot via pointer swap (no SetLength(LErrors,N)), inline O(1) move; bytes.ops single source unchanged
    LPending := FPendingEvals;
    LPendingCount := FPendingCount;
    FPendingEvals := nil;
    FPendingCount := 0;
    // stability: mark Answered under lock to preserve exactly-once invariant
    for I := 0 to LPendingCount - 1 do
    begin
      FEvalScripts[LPending[I].ScriptIdx].Answered := True;
      FEvalScripts[LPending[I].ScriptIdx].ErrorMessage := 'window closed';
    end;
  finally
    FLck.Release;
  end;
  // perf: single exception instance reused for N callbacks, inline alloc once, zero per-pending heap churn
  if LPendingCount > 0 then
  begin
    LErr := EWebviewEvalFailed.Create('window closed');
    try
      for I := 0 to LPendingCount - 1 do
      begin
        LOnError := LPending[I].OnError;
        if Assigned(LOnError) then
          LOnError(LErr);
        // release callback refs promptly to avoid retention, zero-copy nil
        LPending[I].Callback := nil;
        LPending[I].OnError := nil;
      end;
    finally
      LErr.Free;
    end;
    // stability: clear snapshot storage, release refs, nil trailing (managed)
    for I := 0 to LPendingCount - 1 do
      LPending[I] := Default(TFakePendingEval);
    LPending := nil;
  end;
  if FOwnsWindow and (FWindow <> nil) and not FWindow.IsClosed then
    FWindow.Close;
end;

function TFakeWebview.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TFakeWebview.SetZoom(AFactor: Double);
begin
  RequireOpen;
  if AFactor <= 0 then
    raise EWebviewInvalidState.Create('zoom factor must be > 0');
  FZoom := AFactor;
end;

function TFakeWebview.GetZoom: Double;
begin
  RequireOpen;
  Result := FZoom;
end;

procedure TFakeWebview.SetUserAgent(const AUserAgent: string);
begin
  RequireOpen;
  FUserAgent := AUserAgent;
end;

function TFakeWebview.GetUserAgent: string;
begin
  RequireOpen;
  Result := FUserAgent;
end;

procedure TFakeWebview.Navigate(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  FNavigateCount := FNavigateCount + 1;
  PushHistory(AUrl);
  FBridgeReady := True;
  LEvent.Url := AUrl;
  LEvent.IsError := False;
  LEvent.ErrorCode := 0;
  LEvent.ErrorMessage := '';
  for I := 0 to FOnNavStartedCount - 1 do
    FOnNavStarted[I](LEvent);
  FireReadyHandlers;
end;

procedure TFakeWebview.NavigateToString(const AHtml: string);
begin
  RequireOpen;
  FNavigateCount := FNavigateCount + 1;
  PushHistory('data:text/html;base64,fake');
  FBridgeReady := True;
  FireReadyHandlers;
end;

procedure TFakeWebview.Reload;
begin
  RequireOpen;
  FReloadCount := FReloadCount + 1;
end;

procedure TFakeWebview.Stop;
begin
  RequireOpen;
  FStopCount := FStopCount + 1;
end;

function TFakeWebview.CanGoBack: Boolean;
begin
  RequireOpen;
  Result := FHistIdx > 0;
end;

function TFakeWebview.GoBack: Boolean;
begin
  RequireOpen;
  if FHistIdx <= 0 then
    Exit(False);
  FHistIdx := FHistIdx - 1;
  Result := True;
end;

function TFakeWebview.CanGoForward: Boolean;
begin
  RequireOpen;
  Result := FHistIdx + 1 < FHistoryCount;
end;

function TFakeWebview.GoForward: Boolean;
begin
  RequireOpen;
  if FHistIdx + 1 >= FHistoryCount then
    Exit(False);
  FHistIdx := FHistIdx + 1;
  Result := True;
end;

procedure TFakeWebview.Eval(const AJavascript: string;
  ACallback: TWebviewEvalCallback;
  AOnError: TWebviewEvalErrorCallback);
var
  LHasQueued: Boolean;
  LIsError: Boolean;
  LValue: string;
  LIdx: Integer;
begin
  RequireOpen;
  AppendEvalScript(AJavascript);
  LIdx := FEvalScriptsCount - 1;
  LHasQueued := False;
  LIsError := False;
  LValue := '';
  FLck.Acquire;
  try
    if FEvalQueueCount > 0 then
    begin
      LIsError := FEvalQueue[0];
      LValue := FEvalResults[0];
      ShiftEvalQueue;
      LHasQueued := True;
    end
    else
    begin
      // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
      specialize VecGrow<TFakePendingEval>(FPendingEvals, FPendingCount);
      FPendingEvals[FPendingCount].ScriptIdx := LIdx;
      FPendingEvals[FPendingCount].Callback := ACallback;
      FPendingEvals[FPendingCount].OnError := AOnError;
      Inc(FPendingCount);
    end;
  finally
    FLck.Release;
  end;
  if LHasQueued then
    SettleEval(LIdx, LIsError, LValue, ACallback, AOnError);
end;

procedure TFakeWebview.ShiftEvalQueue;
var
  I: Integer;
begin
  for I := 0 to FEvalQueueCount - 2 do
  begin
    FEvalQueue[I] := FEvalQueue[I + 1];
    FEvalResults[I] := FEvalResults[I + 1];
  end;
  Dec(FEvalQueueCount);
  if FEvalQueueCount < Length(FEvalQueue) then
  begin
    FEvalQueue[FEvalQueueCount] := False;
    FEvalResults[FEvalQueueCount] := '';
  end;
end;

{ 恰好一次兑现：先落记录再触发回调（回调内再入本对象是安全的） }
procedure TFakeWebview.SettleEval(AIdx: Integer; AIsError: Boolean;
  const AValue: string;
  ACallback: TWebviewEvalCallback;
  AOnError: TWebviewEvalErrorCallback);
var
  LErr: EWebviewEvalFailed;
begin
  if FEvalScripts[AIdx].Answered then
    raise EWebviewInvalidState.Create('eval already settled');
  FEvalScripts[AIdx].Answered := True;
  if AIsError then
  begin
    FEvalScripts[AIdx].ErrorMessage := AValue;
    { 异常实例所有权：框架创建、回调期内有效、回调返回后框架释放。
      回调只读信息，不得持有引用（CONTRACT §3.2）。 }
    LErr := EWebviewEvalFailed.Create(AValue);
    try
      AOnError(LErr);
    finally
      LErr.Free;
    end;
  end
  else
  begin
    FEvalScripts[AIdx].ResultJson := AValue;
    ACallback(AValue);
  end;
end;

procedure TFakeWebview.Emit(const AEvent, APayloadJson: string);
begin
  CheckWebviewEventName(AEvent);
  RequireOpen;
  if not FBridgeReady then
  begin
    FDroppedEmits := FDroppedEmits + 1;
    Exit;
  end;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TFakeEmit>(FEmits, FEmitsCount);
  FEmits[FEmitsCount].Event := AEvent;
  FEmits[FEmitsCount].PayloadJson := APayloadJson;
  Inc(FEmitsCount);
end;



procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavStarted, FOnNavStartedCount);
  FOnNavStarted[FOnNavStartedCount] := AHandler;
  Inc(FOnNavStartedCount);
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationStarted(NavMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
  OnNavigationStarted(NavProcToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavFinished, FOnNavFinishedCount);
  FOnNavFinished[FOnNavFinishedCount] := AHandler;
  Inc(FOnNavFinishedCount);
end;

procedure TFakeWebview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationFinished(NavMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
  OnNavigationFinished(NavProcToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNavFailedHandler>(FOnNavFailed, FOnNavFailedCount);
  FOnNavFailed[FOnNavFailedCount] := AHandler;
  Inc(FOnNavFailedCount);
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(NavFailedMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(NavFailedProcToRef(AHandler));
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyHandler);
begin
  RequireOpen;
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<TWebviewNotifyHandler>(FOnReady, FOnReadyCount);
  FOnReady[FOnReadyCount] := AHandler;
  Inc(FOnReadyCount);
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyMethod);
begin
  OnReady(NotifyMethodToRef(AHandler));
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyProc);
begin
  OnReady(NotifyProcToRef(AHandler));
end;

function TFakeWebview.GetInvokes: IWebviewInvokeRegistry;
begin
  Result := TFakeInvokeRegistry(FInvokes);
end;

function TFakeWebview.GetAssets: IWebviewAssets;
begin
  Result := TFakeAssets(FAssets);
end;

{ ---- 驱动面 ---- }

function TFakeWebview.PumpOnce: Boolean;
begin
  if FWindow = nil then Exit(False);
  // Delegate to underlying fake window's dispatcher pump
  try
    Result := TFakeWindow.FromWindow(FWindow).PumpOnce;
  except
    Result := False;
  end;
end;

procedure TFakeWebview.PumpAll;
begin
  if FWindow = nil then Exit;
  try
    TFakeWindow.FromWindow(FWindow).PumpAll;
  except
  end;
end;

function TFakeWebview.PendingPosts: Integer;
begin
  if FWindow = nil then Exit(0);
  try
    Result := TFakeWindow.FromWindow(FWindow).PendingPosts;
  except
    Result := 0;
  end;
end;

procedure TFakeWebview.QueueEvalResult(const AResultJson: string);
var
  LPending: TFakePendingEval;
  LHadPending: Boolean;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if FPendingCount > 0 then
    begin
      LPending := FPendingEvals[0];
      ShiftEvalList;
      LHadPending := True;
    end
    else
    begin
      GrowQueue;
      FEvalQueue[FEvalQueueCount] := False;
      FEvalResults[FEvalQueueCount] := AResultJson;
      Inc(FEvalQueueCount);
    end;
  finally
    FLck.Release;
  end;
  if LHadPending then
    SettleEval(LPending.ScriptIdx, False, AResultJson,
      LPending.Callback, LPending.OnError);
end;

procedure TFakeWebview.QueueEvalError(const AMessage: string);
var
  LPending: TFakePendingEval;
  LHadPending: Boolean;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if FPendingCount > 0 then
    begin
      LPending := FPendingEvals[0];
      ShiftEvalList;
      LHadPending := True;
    end
    else
    begin
      GrowQueue;
      FEvalQueue[FEvalQueueCount] := True;
      FEvalResults[FEvalQueueCount] := AMessage;
      Inc(FEvalQueueCount);
    end;
  finally
    FLck.Release;
  end;
  if LHadPending then
    SettleEval(LPending.ScriptIdx, True, AMessage,
      LPending.Callback, LPending.OnError);
end;

procedure TFakeWebview.ShiftEvalList;
var
  I: Integer;
begin
  for I := 0 to FPendingCount - 2 do
    FPendingEvals[I] := FPendingEvals[I + 1];
  Dec(FPendingCount);
  if FPendingCount < Length(FPendingEvals) then
    FPendingEvals[FPendingCount] := Default(TFakePendingEval);
end;

procedure TFakeWebview.FireNavigationStarted(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to FOnNavStartedCount - 1 do
    FOnNavStarted[I](LEvent);
end;

procedure TFakeWebview.FireNavigationFinished(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to FOnNavFinishedCount - 1 do
    FOnNavFinished[I](LEvent);
end;

procedure TFakeWebview.FireNavigationFailed(const AUrl: string;
  ACode: Integer; const AMessage: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  LEvent.IsError := True;
  LEvent.ErrorCode := ACode;
  LEvent.ErrorMessage := AMessage;
  for I := 0 to FOnNavFailedCount - 1 do
    FOnNavFailed[I](LEvent);
end;

procedure TFakeWebview.FireReady;
begin
  RequireOpen;
  FBridgeReady := True;
  FireReadyHandlers;
end;

procedure TFakeWebview.SimulateBridgeReady;
begin
  RequireOpen;
  FBridgeReady := True;
end;



procedure TFakeWebview.EnqueueReceipt(AFrameId: Int64; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
begin
  // perf: single source bytes.ops VecGrow inline (0→4→2×) zero extra call, live registry single source
  specialize VecGrow<string>(FCapturedEvals, FCapturedCount);
  if AIsError then
    FCapturedEvals[FCapturedCount] :=
      BuildRejectScript(AFrameId, ACode, AMessage)
  else
    FCapturedEvals[FCapturedCount] :=
      BuildResolveScript(AFrameId, AResultJson);
  Inc(FCapturedCount);
end;

function TFakeWebview.CaptureEvalCount: Integer;
begin
  Result := FCapturedCount;
end;

function TFakeWebview.CaptureEvalAt(AIndex: Integer): string;
begin
  Result := FCapturedEvals[AIndex];
end;

procedure TFakeWebview.DispatchInvoke(AFrameId: Int64; const ACmd,
  APayloadJson: string);
var
  LReg: TFakeInvokeRegistry;
  LIsAsync: Boolean;
  LSync: TWebviewInvokeSyncHandler;
  LAsync: TWebviewInvokeAsyncHandler;
  LResultJson: string;
  LCompletion: IWebviewInvokeCompletion;
begin
  LReg := TFakeInvokeRegistry(FInvokes);
  if not LReg.Find(ACmd, LIsAsync, LSync, LAsync) then
  begin
    RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_MISSING,
      'no handler registered for cmd');
    if AFrameId >= 0 then
      EnqueueReceipt(AFrameId, True, '', NPW_CODE_HANDLER_MISSING,
        'no handler registered for cmd');
    Exit;
  end;
  if LIsAsync then
  begin
    LCompletion := TFakeCompletion.Create(Self, ACmd, AFrameId);
    try
      LAsync(APayloadJson, LCompletion);
    except
      on E: Exception do
      begin
        if E is EWebviewInvokeError then
        begin
          RecordOutcome(ACmd, True, '',
            MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '',
              MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
        end
        else
        begin
          RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_ERROR, E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '', NPW_CODE_HANDLER_ERROR,
              E.Message);
        end;
      end;
    end;
  end
  else
  begin
    try
      LResultJson := LSync(APayloadJson);
      RecordOutcome(ACmd, False, LResultJson, '', '');
      if AFrameId >= 0 then
        EnqueueReceipt(AFrameId, False, LResultJson, '', '');
    except
      on E: Exception do
      begin
        if E is EWebviewInvokeError then
        begin
          RecordOutcome(ACmd, True, '',
            MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '',
              MapInvokeCode(EWebviewInvokeError(E).Code), E.Message);
        end
        else
        begin
          RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_ERROR, E.Message);
          if AFrameId >= 0 then
            EnqueueReceipt(AFrameId, True, '', NPW_CODE_HANDLER_ERROR,
              E.Message);
        end;
      end;
    end;
  end;
end;

procedure TFakeWebview.DeliverInvoke(const ACmd, APayloadJson: string);
begin
  RequireOpen;
  { driver 直呼：无帧 id，不产生回执脚本 }
  DispatchInvoke(-1, ACmd, APayloadJson);
end;

procedure TFakeWebview.DeliverFrame(const AFrameJson: string);
var
  LFrame: TWebviewFrame;
begin
  RequireOpen;
  if not TryDecodeFrame(AFrameJson, LFrame) then
    raise EWebviewBadFrame.Create('malformed invoke frame');
  DispatchInvoke(LFrame.Id, LFrame.Cmd, LFrame.PayloadJson);
end;

function TFakeWebview.OutcomeCount: Integer;
begin
  Result := FOutcomesCount;
end;

function TFakeWebview.OutcomeAt(AIndex: Integer): TFakeInvokeOutcome;
begin
  Result := FOutcomes[AIndex];
end;

function TFakeWebview.LastOutcome: TFakeInvokeOutcome;
begin
  if FOutcomesCount = 0 then
    raise EWebviewInvalidState.Create('no invoke outcomes recorded');
  Result := FOutcomes[FOutcomesCount - 1];
end;

function TFakeWebview.EmitCount: Integer;
begin
  Result := FEmitsCount;
end;

function TFakeWebview.DroppedEmitCount: Integer;
begin
  Result := FDroppedEmits;
end;

function TFakeWebview.LastEmitEvent: string;
begin
  if FEmitsCount = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits[FEmitsCount - 1].Event;
end;

function TFakeWebview.LastEmitPayloadJson: string;
begin
  if FEmitsCount = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits[FEmitsCount - 1].PayloadJson;
end;

function TFakeWebview.NavigateCount: Integer;
begin
  Result := FNavigateCount;
end;

function TFakeWebview.EvalRecordCount: Integer;
begin
  Result := FEvalScriptsCount;
end;

function TFakeWebview.EvalRecordAt(AIndex: Integer): TFakeEvalRecord;
begin
  Result := FEvalScripts[AIndex];
end;

initialization

finalization

end.
