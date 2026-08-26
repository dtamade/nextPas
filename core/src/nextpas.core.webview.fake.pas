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
  nextpas.core.webview.bridge;

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
    FVisible: Boolean;
    FResizable: Boolean;
    FMaximized: Boolean;
    FMinimized: Boolean;
    FTitle: string;
    FWidth: Integer;
    FHeight: Integer;
    FZoom: Double;
    FUserAgent: string;
    FScale: Double;
    FBridgeReady: Boolean;
    FDebugTools: Boolean;
    FDispatcher: IWebviewDispatcher;
    FInvokesIntf: IWebviewInvokeRegistry;   // 拥有（引用计数）
    FAssetsIntf: IWebviewAssets;            // 拥有
    FInvokes: TObject;             // 非拥有别名：同类私有访问用
    FAssets: TObject;              // 同上
    FEvalScripts: TFakeEvalRecords;
    FEvalQueue: array of Boolean;  // 预载结果 FIFO：True=错误（值在 FEvalResults）
    FEvalResults: array of string; // 与 FEvalQueue 平行：成功 JSON 或错误消息
    FPendingEvals: array of TFakePendingEval;
    FOutcomes: TFakeInvokeOutcomes;
    { DeliverFrame 协议路径产生的回执脚本（resolve/reject）捕获队列 }
    FCapturedEvals: array of string;
    FEmits: array of record
      Event: string;
      PayloadJson: string;
    end;
    FDroppedEmits: Integer;
    FNavigateCount: Integer;
    FReloadCount: Integer;
    FStopCount: Integer;
    FHistory: array of string;
    FHistIdx: Integer;
    FOnNavStarted: array of TWebviewNavEventHandler;
    FOnNavFinished: array of TWebviewNavEventHandler;
    FOnNavFailed: array of TWebviewNavFailedHandler;
    FOnWindowClosed: array of TWebviewNotifyHandler;
    FOnReady: array of TWebviewNotifyHandler;
    FOnScaleChanged: array of TWebviewScaleHandler;
    procedure RequireOpen;
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
    procedure Close; virtual;
    function IsClosed: Boolean;
    procedure Show; virtual;
    procedure Hide; virtual;
    function IsVisible: Boolean;
    procedure Focus; virtual;
    procedure SetTitle(const ATitle: string); virtual;
    function GetTitle: string; virtual;
    procedure SetBounds(AWidth, AHeight: Integer); virtual;
    function GetWidth: Integer;
    function GetHeight: Integer;
    procedure SetResizable(AResizable: Boolean); virtual;
    procedure Maximize; virtual;
    procedure Unmaximize; virtual;
    function IsMaximized: Boolean;
    procedure Minimize; virtual;
    procedure Restore; virtual;
    function IsMinimized: Boolean;
    procedure SetZoom(AFactor: Double); virtual;
    function GetZoom: Double;
    procedure SetUserAgent(const AUserAgent: string); virtual;
    function GetUserAgent: string;
    function GetScaleFactor: Double;
    procedure OnScaleChanged(AHandler: TWebviewScaleHandler); overload; virtual;
    procedure OnScaleChanged(AHandler: TWebviewScaleMethod); overload; virtual;
    procedure OnScaleChanged(AHandler: TWebviewScaleProc); overload; virtual;
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
    function GetDispatcher: IWebviewDispatcher;
    function NativeHandle: TWebviewNativeHandle;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload; virtual;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventMethod); overload; virtual;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventProc); overload; virtual;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload; virtual;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventMethod); overload; virtual;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventProc); overload; virtual;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload; virtual;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedMethod); overload; virtual;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload; virtual;
    procedure OnWindowClosed(AHandler: TWebviewNotifyHandler); overload; virtual;
    procedure OnWindowClosed(AHandler: TWebviewNotifyMethod); overload; virtual;
    procedure OnWindowClosed(AHandler: TWebviewNotifyProc); overload; virtual;
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

    { DPI 驱动：改 scale 并触发 OnScaleChanged }
    procedure SetScale(ANewScale: Double);

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
  统一存储范式（design-conventions §8）：内部只存 reference 形态。 }

function NotifyMethodToRef(AHandler: TWebviewNotifyMethod): TWebviewNotifyHandler;
begin
  Result :=
    procedure
    begin
      AHandler;
    end;
end;

function NotifyProcToRef(AHandler: TWebviewNotifyProc): TWebviewNotifyHandler;
begin
  Result :=
    procedure
    begin
      AHandler;
    end;
end;

function NavMethodToRef(
  AHandler: TWebviewNavEventMethod): TWebviewNavEventHandler;
begin
  Result :=
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end;
end;

function NavProcToRef(
  AHandler: TWebviewNavEventProc): TWebviewNavEventHandler;
begin
  Result :=
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end;
end;

function NavFailedMethodToRef(
  AHandler: TWebviewNavFailedMethod): TWebviewNavFailedHandler;
begin
  Result :=
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end;
end;

function NavFailedProcToRef(
  AHandler: TWebviewNavFailedProc): TWebviewNavFailedHandler;
begin
  Result :=
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end;
end;

function ScaleMethodToRef(
  AHandler: TWebviewScaleMethod): TWebviewScaleHandler;
begin
  Result :=
    procedure(ANewScale: Double)
    begin
      AHandler(ANewScale);
    end;
end;

function ScaleProcToRef(
  AHandler: TWebviewScaleProc): TWebviewScaleHandler;
begin
  Result :=
    procedure(ANewScale: Double)
    begin
      AHandler(ANewScale);
    end;
end;

{ ---- TFakeDispatcher：互斥保护的环形 FIFO ---- }

type
  TFakeDispatcher = class(TInterfacedObject, IWebviewDispatcher)
  private
    FLck: ILock;
    FRing: array of TWebviewProcRef;
    FHead: Integer;
    FCount: Integer;
    FOwnerThread: UInt64;
    procedure Grow;
  public
    constructor Create;
    destructor Destroy; override;
    procedure PostRef(AProc: TWebviewProcRef);
    function IsOnMainThread: Boolean;
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

procedure TFakeDispatcher.Grow;
var
  LNewCap, I: Integer;
  LNew: array of TWebviewProcRef;
begin
  LNewCap := Length(FRing) * 2;
  if LNewCap = 0 then
    LNewCap := 16;
  SetLength(LNew, LNewCap);
  for I := 0 to FCount - 1 do
    LNew[I] := FRing[(FHead + I) mod Length(FRing)];
  FRing := LNew;
  FHead := 0;
end;

procedure TFakeDispatcher.PostRef(AProc: TWebviewProcRef);
begin
  FLck.Acquire;
  try
    if FCount = Length(FRing) then
      Grow;
    FRing[(FHead + FCount) mod Length(FRing)] := AProc;
    FCount := FCount + 1;
  finally
    FLck.Release;
  end;
end;

function TFakeDispatcher.IsOnMainThread: Boolean;
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
  { 闭包在 completion 释放后才由主线程泵执行，因此只捕获局部值拷贝
    （字符串随闭包帧存活），不捕获 Self 字段——对象指针不受引用计数保护 }
  LCmd := FCmd;
  LFrameId := FFrameId;
  LWin := FWin as TFakeWebview;
  LWin.GetDispatcher.Post(
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

function FakeLiveWindowCount: Integer;
var
  I, LCnt: Integer;
begin
  LCnt := 0;
  for I := 0 to High(GLiveWindows) do
    if not GLiveWindows[I].FClosed then
      LCnt := LCnt + 1;
  Result := LCnt;
end;

procedure FakePumpAll;
var
  I: Integer;
begin
  for I := 0 to High(GLiveWindows) do
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

constructor TFakeWebview.Create(const AOptions: TWebviewOptions);
var
  LReg: TFakeInvokeRegistry;
  LAssets: TFakeAssets;
begin
  inherited Create;
  FLck := TMutex.Create as ILock;
  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FMaximized := False;
  FMinimized := False;
  FTitle := AOptions.Title;
  FWidth := AOptions.Width;
  FHeight := AOptions.Height;
  FZoom := 1.0;
  FUserAgent := '';
  FScale := 1.0;
  FBridgeReady := False;
  FDebugTools := AOptions.DebugTools;
  FDispatcher := TFakeDispatcher.Create;
  LReg := TFakeInvokeRegistry.Create;
  LAssets := TFakeAssets.Create(AOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;    { 拥有（引用计数） }
  FAssetsIntf := LAssets;
  FInvokes := LReg;        { 非拥有别名（同类私有访问） }
  FAssets := LAssets;
  FDroppedEmits := 0;
  FNavigateCount := 0;
  FHistIdx := -1;
  SetLength(GLiveWindows, Length(GLiveWindows) + 1);
  GLiveWindows[High(GLiveWindows)] := Self;

  { Initial* 启动加载：构造即导航。资产/桥请求都在主循环泵里才发生，
    Build 返回后的挂载先于任何请求，无时序竞态（§3.4） }
  if AOptions.InitialHtml <> '' then
    NavigateToString(AOptions.InitialHtml)
  else if AOptions.InitialUrl <> '' then
    Navigate(AOptions.InitialUrl);
end;

destructor TFakeWebview.Destroy;
var
  I: Integer;
begin
  for I := High(GLiveWindows) downto 0 do
    if GLiveWindows[I] = Self then
    begin
      GLiveWindows[I] := GLiveWindows[High(GLiveWindows)];
      SetLength(GLiveWindows, Length(GLiveWindows) - 1);
    end;
  inherited Destroy;
end;

procedure TFakeWebview.RequireOpen;
begin
  if FClosed then
    raise EWebviewClosed.Create('webview window is closed');
end;

procedure TFakeWebview.RecordOutcome(const ACmd: string; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
begin
  FLck.Acquire;
  try
    SetLength(FOutcomes, Length(FOutcomes) + 1);
    FOutcomes[High(FOutcomes)].Cmd := ACmd;
    FOutcomes[High(FOutcomes)].IsError := AIsError;
    FOutcomes[High(FOutcomes)].ResultJson := AResultJson;
    FOutcomes[High(FOutcomes)].Code := ACode;
    FOutcomes[High(FOutcomes)].Message := AMessage;
  finally
    FLck.Release;
  end;
end;

procedure TFakeWebview.PushHistory(const AUrl: string);
begin
  SetLength(FHistory, FHistIdx + 2);
  FHistory[FHistIdx + 1] := AUrl;
  FHistIdx := FHistIdx + 1;
end;

procedure TFakeWebview.FireReadyHandlers;
var
  I: Integer;
begin
  for I := 0 to High(FOnReady) do
    FOnReady[I]();
end;

procedure TFakeWebview.AppendEvalScript(const AScript: string);
begin
  SetLength(FEvalScripts, Length(FEvalScripts) + 1);
  FEvalScripts[High(FEvalScripts)].Script := AScript;
  FEvalScripts[High(FEvalScripts)].Answered := False;
end;

procedure TFakeWebview.Close;
var
  I: Integer;
  LErrObj: EWebviewEvalFailed;
  LErrors: array of TWebviewEvalErrorCallback;
  LClosed: array of TWebviewNotifyHandler;
begin
  FLck.Acquire;
  try
    if FClosed then
      Exit;
    FClosed := True;
    { 在途 Eval 统一失败收尾（CONTRACT §3.2 / INV-7 恰好一次） }
    SetLength(LErrors, Length(FPendingEvals));
    for I := 0 to High(FPendingEvals) do
    begin
      FEvalScripts[FPendingEvals[I].ScriptIdx].Answered := True;
      FEvalScripts[FPendingEvals[I].ScriptIdx].ErrorMessage := 'window closed';
      LErrors[I] := FPendingEvals[I].OnError;
    end;
    SetLength(FPendingEvals, 0);
  finally
    FLck.Release;
  end;
  { 解锁后触发回调：错误收尾 + 关闭通知（回调内再入 Close 是幂等安全）；
    异常实例同上：框架创建并释放 }
  for I := 0 to High(LErrors) do
  begin
    LErrObj := EWebviewEvalFailed.Create('window closed');
    try
      LErrors[I](LErrObj);
    finally
      LErrObj.Free;
    end;
  end;
  SetLength(LClosed, Length(FOnWindowClosed));
  for I := 0 to High(FOnWindowClosed) do
    LClosed[I] := FOnWindowClosed[I];
  { 关闭后投递静默丢弃（契约 §3.1） }
  (FDispatcher as TFakeDispatcher).DropAll;
  for I := 0 to High(LClosed) do
    LClosed[I]();
end;

function TFakeWebview.IsClosed: Boolean;
begin
  Result := FClosed;
end;

procedure TFakeWebview.Show;
begin
  RequireOpen;
  FVisible := True;
end;

procedure TFakeWebview.Hide;
begin
  RequireOpen;
  FVisible := False;
end;

function TFakeWebview.IsVisible: Boolean;
begin
  RequireOpen;
  Result := FVisible;
end;

procedure TFakeWebview.Focus;
begin
  RequireOpen;
end;

procedure TFakeWebview.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
end;

function TFakeWebview.GetTitle: string;
begin
  RequireOpen;
  Result := FTitle;
end;

procedure TFakeWebview.SetBounds(AWidth, AHeight: Integer);
begin
  RequireOpen;
  if AWidth < 0 then
    AWidth := 0;
  if AHeight < 0 then
    AHeight := 0;
  FWidth := AWidth;
  FHeight := AHeight;
end;

function TFakeWebview.GetWidth: Integer;
begin
  RequireOpen;
  Result := FWidth;
end;

function TFakeWebview.GetHeight: Integer;
begin
  RequireOpen;
  Result := FHeight;
end;

procedure TFakeWebview.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
end;

procedure TFakeWebview.Maximize;
begin
  RequireOpen;
  FMaximized := True;
  FMinimized := False;
end;

procedure TFakeWebview.Unmaximize;
begin
  RequireOpen;
  FMaximized := False;
end;

function TFakeWebview.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := FMaximized;
end;

procedure TFakeWebview.Minimize;
begin
  RequireOpen;
  FMinimized := True;
end;

procedure TFakeWebview.Restore;
begin
  RequireOpen;
  FMinimized := False;
  FMaximized := False;
end;

function TFakeWebview.IsMinimized: Boolean;
begin
  RequireOpen;
  Result := FMinimized;
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

function TFakeWebview.GetScaleFactor: Double;
begin
  RequireOpen;
  Result := FScale;
end;

procedure TFakeWebview.OnScaleChanged(AHandler: TWebviewScaleHandler);
begin
  RequireOpen;
  SetLength(FOnScaleChanged, Length(FOnScaleChanged) + 1);
  FOnScaleChanged[High(FOnScaleChanged)] := AHandler;
end;

procedure TFakeWebview.OnScaleChanged(AHandler: TWebviewScaleMethod);
begin
  OnScaleChanged(ScaleMethodToRef(AHandler));
end;

procedure TFakeWebview.OnScaleChanged(AHandler: TWebviewScaleProc);
begin
  OnScaleChanged(ScaleProcToRef(AHandler));
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
  for I := 0 to High(FOnNavStarted) do
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
  Result := FHistIdx < High(FHistory);
end;

function TFakeWebview.GoForward: Boolean;
begin
  RequireOpen;
  if FHistIdx >= High(FHistory) then
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
  LIdx := High(FEvalScripts);
  LHasQueued := False;
  LIsError := False;
  LValue := '';
  FLck.Acquire;
  try
    if Length(FEvalQueue) > 0 then
    begin
      LIsError := FEvalQueue[0];
      LValue := FEvalResults[0];
      ShiftEvalQueue;
      LHasQueued := True;
    end
    else
    begin
      SetLength(FPendingEvals, Length(FPendingEvals) + 1);
      FPendingEvals[High(FPendingEvals)].ScriptIdx := LIdx;
      FPendingEvals[High(FPendingEvals)].Callback := ACallback;
      FPendingEvals[High(FPendingEvals)].OnError := AOnError;
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
  for I := 0 to High(FEvalQueue) - 1 do
  begin
    FEvalQueue[I] := FEvalQueue[I + 1];
    FEvalResults[I] := FEvalResults[I + 1];
  end;
  SetLength(FEvalQueue, Length(FEvalQueue) - 1);
  SetLength(FEvalResults, Length(FEvalResults) - 1);
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
  RequireOpen;
  if not FBridgeReady then
  begin
    FDroppedEmits := FDroppedEmits + 1;
    Exit;
  end;
  SetLength(FEmits, Length(FEmits) + 1);
  FEmits[High(FEmits)].Event := AEvent;
  FEmits[High(FEmits)].PayloadJson := APayloadJson;
end;

function TFakeWebview.GetDispatcher: IWebviewDispatcher;
begin
  Result := FDispatcher;
end;

function TFakeWebview.NativeHandle: TWebviewNativeHandle;
begin
  Result := nil;
end;

procedure TFakeWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  RequireOpen;
  SetLength(FOnNavStarted, Length(FOnNavStarted) + 1);
  FOnNavStarted[High(FOnNavStarted)] := AHandler;
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
  SetLength(FOnNavFinished, Length(FOnNavFinished) + 1);
  FOnNavFinished[High(FOnNavFinished)] := AHandler;
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
  SetLength(FOnNavFailed, Length(FOnNavFailed) + 1);
  FOnNavFailed[High(FOnNavFailed)] := AHandler;
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(NavFailedMethodToRef(AHandler));
end;

procedure TFakeWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(NavFailedProcToRef(AHandler));
end;

procedure TFakeWebview.OnWindowClosed(AHandler: TWebviewNotifyHandler);
begin
  SetLength(FOnWindowClosed, Length(FOnWindowClosed) + 1);
  FOnWindowClosed[High(FOnWindowClosed)] := AHandler;
end;

procedure TFakeWebview.OnWindowClosed(AHandler: TWebviewNotifyMethod);
begin
  OnWindowClosed(NotifyMethodToRef(AHandler));
end;

procedure TFakeWebview.OnWindowClosed(AHandler: TWebviewNotifyProc);
begin
  OnWindowClosed(NotifyProcToRef(AHandler));
end;

procedure TFakeWebview.OnReady(AHandler: TWebviewNotifyHandler);
begin
  RequireOpen;
  SetLength(FOnReady, Length(FOnReady) + 1);
  FOnReady[High(FOnReady)] := AHandler;
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
  Result := (FDispatcher as TFakeDispatcher).PumpOnce;
end;

procedure TFakeWebview.PumpAll;
begin
  (FDispatcher as TFakeDispatcher).PumpAll;
end;

function TFakeWebview.PendingPosts: Integer;
begin
  Result := (FDispatcher as TFakeDispatcher).PendingCount;
end;

procedure TFakeWebview.QueueEvalResult(const AResultJson: string);
var
  LPending: TFakePendingEval;
  LHadPending: Boolean;
begin
  LHadPending := False;
  FLck.Acquire;
  try
    if Length(FPendingEvals) > 0 then
    begin
      LPending := FPendingEvals[0];
      ShiftEvalList;
      LHadPending := True;
    end
    else
    begin
      SetLength(FEvalQueue, Length(FEvalQueue) + 1);
      FEvalQueue[High(FEvalQueue)] := False;
      SetLength(FEvalResults, Length(FEvalResults) + 1);
      FEvalResults[High(FEvalResults)] := AResultJson;
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
    if Length(FPendingEvals) > 0 then
    begin
      LPending := FPendingEvals[0];
      ShiftEvalList;
      LHadPending := True;
    end
    else
    begin
      SetLength(FEvalQueue, Length(FEvalQueue) + 1);
      FEvalQueue[High(FEvalQueue)] := True;
      SetLength(FEvalResults, Length(FEvalResults) + 1);
      FEvalResults[High(FEvalResults)] := AMessage;
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
  for I := 0 to High(FPendingEvals) - 1 do
    FPendingEvals[I] := FPendingEvals[I + 1];
  SetLength(FPendingEvals, Length(FPendingEvals) - 1);
end;

procedure TFakeWebview.FireNavigationStarted(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to High(FOnNavStarted) do
    FOnNavStarted[I](LEvent);
end;

procedure TFakeWebview.FireNavigationFinished(const AUrl: string);
var
  LEvent: TWebviewNavigationEvent;
  I: Integer;
begin
  RequireOpen;
  LEvent.Url := AUrl;
  for I := 0 to High(FOnNavFinished) do
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
  for I := 0 to High(FOnNavFailed) do
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

procedure TFakeWebview.SetScale(ANewScale: Double);
var
  I: Integer;
begin
  RequireOpen;
  if ANewScale <= 0 then
    raise EWebviewInvalidState.Create('scale factor must be > 0');
  FScale := ANewScale;
  for I := 0 to High(FOnScaleChanged) do
    FOnScaleChanged[I](ANewScale);
end;

procedure TFakeWebview.EnqueueReceipt(AFrameId: Int64; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
begin
  SetLength(FCapturedEvals, Length(FCapturedEvals) + 1);
  if AIsError then
    FCapturedEvals[High(FCapturedEvals)] :=
      BuildRejectScript(AFrameId, ACode, AMessage)
  else
    FCapturedEvals[High(FCapturedEvals)] :=
      BuildResolveScript(AFrameId, AResultJson);
end;

function TFakeWebview.CaptureEvalCount: Integer;
begin
  Result := Length(FCapturedEvals);
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
          RecordOutcome(ACmd, True, '',
            MapInvokeCode(EWebviewInvokeError(E).Code), E.Message)
        else
          RecordOutcome(ACmd, True, '', NPW_CODE_HANDLER_ERROR, E.Message);
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
  Result := Length(FOutcomes);
end;

function TFakeWebview.OutcomeAt(AIndex: Integer): TFakeInvokeOutcome;
begin
  Result := FOutcomes[AIndex];
end;

function TFakeWebview.LastOutcome: TFakeInvokeOutcome;
begin
  if Length(FOutcomes) = 0 then
    raise EWebviewInvalidState.Create('no invoke outcomes recorded');
  Result := FOutcomes[High(FOutcomes)];
end;

function TFakeWebview.EmitCount: Integer;
begin
  Result := Length(FEmits);
end;

function TFakeWebview.DroppedEmitCount: Integer;
begin
  Result := FDroppedEmits;
end;

function TFakeWebview.LastEmitEvent: string;
begin
  if Length(FEmits) = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits[High(FEmits)].Event;
end;

function TFakeWebview.LastEmitPayloadJson: string;
begin
  if Length(FEmits) = 0 then
    raise EWebviewInvalidState.Create('no emits recorded');
  Result := FEmits[High(FEmits)].PayloadJson;
end;

function TFakeWebview.NavigateCount: Integer;
begin
  Result := FNavigateCount;
end;

function TFakeWebview.EvalRecordCount: Integer;
begin
  Result := Length(FEvalScripts);
end;

function TFakeWebview.EvalRecordAt(AIndex: Integer): TFakeEvalRecord;
begin
  Result := FEvalScripts[AIndex];
end;

initialization

finalization

end.
