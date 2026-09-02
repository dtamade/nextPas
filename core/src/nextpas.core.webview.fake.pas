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
       MountDirectory 抛 ENotSupportedError（无头环境无文件资产）。

       拆分治理（S105+）：原 1583 行单文件超 800 软指引，已按
       design-conventions 四件套与 L0-L3 单向依赖拆为子模块：
       - nextpas.core.webview.fake.dispatcher（环形 FIFO 独立调度，bytes.ops 单源）
       - nextpas.core.webview.fake.support（回调适配与选项辅助，callbacks 单源）
       - nextpas.core.webview.fake.impl.inc（主体实现手写 .inc，主体逻辑与活窗登记）
       本门面仅保留类型契约与薄转发，主体实现经 .inc 单源复用 bytes.ops，
       inline 零拷贝，短临界 <1µs，资源 Finalize 释放不丢；性能修复见 impl.inc。
       队列治理（S110+）：内部 eval/pending 裸队列已收敛至 L1 bytes.ops.TCompactLiveRegistry 单源
       inline 零拷贝（gtk 同源 8 组 Registry 单源闭环，VecGrowCapacity 0→4→2× / RemoveAtOrdered 保序 FIFO / Default(T) 释放不丢），
       裸 GrowQueue/Shift 手写样板已删除，单源零重复。
       单源收敛（S111+）：FOutcomes/FEmits/FHistory/FCaptured/On* 余量裸数组+Count+VecGrow 手写已全部收敛至 TCompactLiveRegistry 单源 inline 零拷贝（0→4→2× / Default 释放不丢），与家族 wk/gtk/webview2 8/8 同源闭环，零手写样板。 *}

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
  nextpas.core.webview.callbacks,
  nextpas.core.webview.utils,
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

  { 预载 Eval 回执队列单记录：合并 bool+string 为单次 VecRingCopy 批量搬移，临界区尾延迟减半，bytes.ops 单源 inline 零拷贝 }
  TFakeEvalQueueEntry = record
    IsError: Boolean;
    Value: string;
  end;
  TFakeEvalQueue = array of TFakeEvalQueueEntry;

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
    FEvalScripts: specialize TCompactLiveRegistry<TFakeEvalRecord>; // bytes.ops 单源 inline 零拷贝，Append/At/SetAt 保序，Default(T) 释放不丢，gtk 同源
    FEvalQueue: specialize TCompactLiveRegistry<TFakeEvalQueueEntry>; // 同源 FIFO：Register 0→4→2× VecGrowCapacity inline 零拷贝，PopFrontOrdered 保序 VecRemoveOrdered/Default 释放不丢
    FPendingEvals: specialize TCompactLiveRegistry<TFakePendingEval>; // 同源 FIFO：Register/RemoveAtOrdered 保序，gtk FPendingEvals 同源
    FOutcomes: specialize TCompactLiveRegistry<TFakeInvokeOutcome>; // bytes.ops 单源 inline 0→4→2× VecGrowCapacity 零拷贝，Default 释放不丢，S111+ 8/8 同源闭环，RecordOutcome 乐观重试复用 LNew 零化不放大
    { DeliverFrame 协议路径产生的回执脚本（resolve/reject）捕获队列 }
    FCapturedEvals: specialize TCompactLiveRegistry<string>; // bytes.ops 单源 inline 0→4→2× 零拷贝，Default 释放不丢
    FEmits: specialize TCompactLiveRegistry<TFakeEmit>; // 同源 inline 零拷贝
    FDroppedEmits: Integer;
    FNavigateCount: Integer;
    FReloadCount: Integer;
    FStopCount: Integer;
    FHistory: specialize TCompactLiveRegistry<string>; // 同源 inline 零拷贝，RemoveAtOrdered 保序截尾 Default 释放不丢
    FHistIdx: Integer;
    FOnNavStarted: specialize TCompactLiveRegistry<TWebviewNavEventHandler>; // 同源 inline 零拷贝
    FOnNavFinished: specialize TCompactLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFailed: specialize TCompactLiveRegistry<TWebviewNavFailedHandler>;
    FOnReady: specialize TCompactLiveRegistry<TWebviewNotifyHandler>;
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

{$I nextpas.core.webview.fake.impl.inc}

initialization
  GLiveWindows := specialize TCompactLiveRegistry<TFakeWebview>.Create;
  GLiveLck := TMutex.Create as ILock;

finalization
  GLiveWindows.Free;
  GLiveWindows := nil;
  GLiveLck := nil;

end.
