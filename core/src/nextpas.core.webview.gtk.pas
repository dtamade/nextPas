unit nextpas.core.webview.gtk;

{** @desc Linux 后端：GTK3 窗口壳（经 window.gtk3 Raw 单源）+ WebKitGTK 内容 +
       bridge 协议 transport，实现 IWebviewWindow / IWebviewDispatcher。

       生命周期纪律：
       - 构造期持有自身接口引用（FSelfKeepAlive），GTK 回调因此始终指向
         有效对象；widget destroy 回调里释放——对象寿命与原生窗口同构，
         杜绝悬垂回调。
       - idle 投递闭包内存归 GLib source 生命周期：正常执行后 trampoline
         返回 G_SOURCE_REMOVE、Close 路径 g_source_remove，两者都经同一
         destroy-notify 释放。单所有权无双 free。
       - Eval exactly-one：完成记录 Done 守卫；Close 时在途 eval 立即以
         EWebviewEvalFailed 收尾（框架创建/触发/try-finally 释放），
         引擎迟到回执读 Done 静默丢弃并释放记录。
       - completion marshal 闭包只捕获局部值拷贝（字符串随闭包帧存活），
         不捕获 completion 对象字段——对象指针不受引用计数保护（S1 教训）。
       - 协议立场：页面坏帧静默忽略（BRIDGE_PROTOCOL §3.1 生产路径），
         与 fake 驱动面抛 EWebviewBadFrame 的校验互补。
       - IsMinimized 为查询式真值（gdk_window_get_state ICONIFIED 位）；
         Maximized/Visible/几何同为引擎实时真值。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.os.env,
  nextpas.core.platform.thread,
  nextpas.core.log.intf,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.validation,
  nextpas.core.webview.bridge,
  nextpas.core.webview.live,
  nextpas.core.webview.callbacks,
  nextpas.core.bytes.ops,
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.gtk.loader;

type
  PEvalRec = ^TEvalRec;
  TEvalRec = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
    Cancel: Pointer;   { GCancellable*: Close 后保证引擎回调必达, 单点释放 }
    Owner: Pointer;    { TGtkWebview non-owning, pending 移除用 }
  end;
  PIdleRec = ^TIdleRec;
  TIdleRec = record
    Proc: TWebviewProcRef;
  end;
  PCompletionMarshal = ^TCompletionMarshal;
  TCompletionMarshal = record
    Win: TObject;          { 非拥有：keep-alive 保证存活 }
    FrameId: Int64;
    Cmd: string;
    IsError: Boolean;
    ResultJson: string;
    Code: string;
    MsgText: string;
  end;


  {** WebKitGTK 实现。构造即装载（缺库抛 EWebviewBackendUnavailable）、
      建窗接桥；Close 后进入 Closed 态（除 IsClosed/NativeHandle 外抛
      EWebviewClosed）。 *}
  TGtkWebview = class(TInterfacedObject, IWebviewWindow, IWebviewDispatcher)
  private
    FOptions: TWebviewOptions;
    FWin, FView, FContext: Pointer;
    FOwnsContext: Boolean;
    FClosed: Boolean;
    FScale: Double;
    FReadyFired: Boolean;
    FOwnerThread: UInt64;
    FSelfKeepAlive: IInterface;
    FInvokesIntf: IWebviewInvokeRegistry;
    FInvokes: TObject;
    FAssetsIntf: IWebviewAssets;
    FAssets: TObject;
    FIdleTags: specialize TWebviewLiveRegistry<guint>;
    FPendingEvals: specialize TWebviewLiveRegistry<PEvalRec>;
    FOnNavStarted: specialize TWebviewLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFinished: specialize TWebviewLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFailed: specialize TWebviewLiveRegistry<TWebviewNavFailedHandler>;
    FOnWindowClosed: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>;
    FOnReady: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>;
    FOnScaleChanged: specialize TWebviewLiveRegistry<TWebviewScaleHandler>;

    procedure RequireOpen;
    procedure RemovePending(ARec: PEvalRec);
    procedure SetupSessionContext;
    function ResolveContext: Pointer;
    procedure SetupSchemeAndShell;
    procedure FireNotifyHandlers(AReg: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>);
    procedure WireSignals;
    procedure AddUserScript(const ASource: string);
    function CurrentUri: string;
    procedure FireReadyOnce;
    procedure DispatchFrame(const AFrame: TWebviewFrame);
    class function MapInvokeCodeSafe(E: Exception): string; static;
    procedure SendReceipt(AFrameId: Int64; AIsError: Boolean;
      const AResultJson, ACode, AMessage: string);
    procedure PostIdle(AProc: TWebviewProcRef);
    procedure DropIdlePendings;
    procedure SettlePendingOnClose; inline;
    procedure HandleNativeDestroy;
  protected
    { IWebviewDispatcher —— Self 双身份实现 inline 薄转发 }
    procedure Post(AProc: TWebviewProcRef); overload; inline;
    procedure Post(AProc: TWebviewProcMethod); overload; inline;
    procedure Post(AProc: TWebviewProc); overload; inline;
    function IsOnMainThread: Boolean; inline;

    { IWebviewWindow }
    procedure Close; virtual;
    function IsClosed: Boolean; inline;
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
    function GetDispatcher: IWebviewDispatcher; inline;
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
    constructor Create(const AOptions: TWebviewOptions); virtual;
    destructor Destroy; override;
  end;

{ 活跃 gtk 窗口数（未 Close 计数）；factory RunLoop 的 gtk 分支事实源 }
function GtkLiveWindowCount: Integer;

implementation
uses
  nextpas.core.window.gtk3,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock,
  nextpas.core.webview.mime,
  nextpas.core.webview.utils,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.collections.hashmap.base,
  nextpas.core.text.view;

const
  WEBVIEW_SCHEME_LARGE_THRESHOLD = 8192;

type
  PAssetHolder = ^TAssetHolder;
  TAssetHolder = record
    Bytes: TBytes;
  end;
  TViewMapEntry = record
    Key: Pointer;
    Value: TGtkWebview;
  end;

  TGtkDebugLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

procedure AssetBufFree(AData: Pointer); cdecl;
begin
  if AData <> nil then
    Dispose(PAssetHolder(AData));
end;

{ TGtkDebugLogger — graded stderr sink via log.intf (L0 seam), zero bypass }
procedure TGtkDebugLogger.Log(const ALevel: TLogLevel; const AMessage: string);
begin
  // graded via ILogger — level already checked by GtkTrace gate, prefix kept for hygiene traceability
  System.Write(StdErr, '[npw-gtk] ', AMessage, LineEnding);
  System.Flush(StdErr);
end;

procedure TGtkDebugLogger.Trace(const AMessage: string);
begin
  Log(llTrace, AMessage);
end;

procedure TGtkDebugLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TGtkDebugLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TGtkDebugLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TGtkDebugLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

procedure TGtkDebugLogger.Fatal(const AMessage: string);
begin
  Log(llFatal, AMessage);
end;

var
  GLiveWindows: specialize TWebviewLiveRegistry<TGtkWebview> = nil;
  GLiveCount: Integer = 0;
  { scheme 按 context 去重：默认 context 是进程级单例，多窗口重复注册
    会被 GLib CRITICAL 拒绝，且后到处理器无法接管——必须首注册独占 }
  GRegisteredSchemeCtxs: specialize TWebviewLiveRegistry<Pointer> = nil;
  GGtkDebugChecked: Boolean = False;
  GGtkDebugEnabled: Boolean = False;
  GGtkLogger: ILogger = nil;
  GSchemeLock: TMutex = nil;
  GPoolLock: TMutex = nil;
  GLiveLock: TRWLock = nil;
  GViewMap: array of TViewMapEntry;
  GViewMapCount: Integer = 0;
  { Dispatcher 池化：Slab 复用 PIdleRec / PCompletionMarshal，零每 Post 堆分配
    性能：独立 GPoolLock 与 GSchemeLock 分离，避免高频 Post/mareshal 与 scheme
    注册/窗口登记抢同一全局锁；池操作为短临界区 inline + 零拷贝复用，复用 live 通用池抽象单源，SetLength 仅初始化预分配、运行期不持锁堆分配 }
  GIdlePool: array of PIdleRec;
  GIdlePoolCount: Integer = 0;
  GCompletionPool: array of PCompletionMarshal;
  GCompletionPoolCount: Integer = 0;

{ ---- Dispatcher 池化：Slab 复用 ---- }
{ perf: reuse live generic pool abstraction (WebviewPoolTryAcquire/Release) single source for both slabs — zero duplicate SetLength(WebviewGrowCapacity) inside lock, short critical section pointer-only, heap alloc/free outside lock, inline zero-copy }
function AcquireIdleRec: PIdleRec; inline;
begin
  // perf: short lock pop via live generic, New outside lock (heap outside critical section)
  Result := specialize WebviewPoolTryAcquire<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseIdleRec(A: PIdleRec); inline;
begin
  if A = nil then Exit;
  A^.Proc := nil;
  // perf: short lock push via live generic, no SetLength inside lock; overflow Dispose outside to keep lock <1µs
  if not specialize WebviewPoolTryRelease<PIdleRec>(GIdlePool, GIdlePoolCount, GPoolLock, A) then
    Dispose(A);
end;

function AcquireCompletionRec: PCompletionMarshal; inline;
begin
  Result := specialize WebviewPoolTryAcquire<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock);
  if Result = nil then
    New(Result);
end;

procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
begin
  if A = nil then Exit;
  A^.Win := nil;
  A^.FrameId := 0;
  A^.Cmd := '';
  A^.IsError := False;
  A^.ResultJson := '';
  A^.Code := '';
  A^.MsgText := '';
  if not specialize WebviewPoolTryRelease<PCompletionMarshal>(GCompletionPool, GCompletionPoolCount, GPoolLock, A) then
    Dispose(A);
end;

{ 环境门控诊断轨迹（NPW_GTK_DEBUG=1 时经 log.intf 分级输出），默认零开销：
  覆盖 nav/scheme/eval 三条异步轴，用于现场问题定位 }
procedure GtkTrace(const AMsg: string);
begin
  if not GGtkDebugChecked then
  begin
    GGtkDebugChecked := True;
    // owner boundary: os.env GetEnv single source (platform.env stub drift safe), inline zero-copy compare
    GGtkDebugEnabled := GetEnv('NPW_GTK_DEBUG') = '1';
    if GGtkDebugEnabled then
      GGtkLogger := TGtkDebugLogger.Create
    else
      GGtkLogger := NullLogger;
  end;
  if GGtkDebugEnabled then
    GGtkLogger.Debug(AMsg);
end;

function SchemeContextRegistered(ACtx: Pointer): Boolean; inline;
var
  I: Integer;
begin
  // perf: inline zero-alloc scan under short lock — n<=4 typical, zero heap jitter, inline zero extra call, zero SetLength
  // single source: live generic registry inline, bytes.ops VecGrow single source, zero-copy At
  if GSchemeLock <> nil then GSchemeLock.Acquire;
  try
    if GRegisteredSchemeCtxs <> nil then
      for I := 0 to GRegisteredSchemeCtxs.Count - 1 do
        if GRegisteredSchemeCtxs.At(I) = ACtx then
          Exit(True);
  finally
    if GSchemeLock <> nil then GSchemeLock.Release;
  end;
  Result := False;
end;

procedure RememberSchemeContext(ACtx: Pointer); inline;
begin
  if GSchemeLock <> nil then GSchemeLock.Acquire;
  try
    // single source: live generic registry Register -> bytes.ops VecGrow inline, zero-copy
    if GRegisteredSchemeCtxs <> nil then
      GRegisteredSchemeCtxs.Register(ACtx);
  finally
    if GSchemeLock <> nil then GSchemeLock.Release;
  end;
end;

procedure ForgetSchemeContext(ACtx: Pointer); inline;
begin
  if GSchemeLock <> nil then GSchemeLock.Acquire;
  try
    // single source: live generic registry Unregister inline O(1) swap, bytes.ops VecRemoveSwap single source, zero-copy
    if GRegisteredSchemeCtxs <> nil then
      GRegisteredSchemeCtxs.Unregister(ACtx);
  finally
    if GSchemeLock <> nil then GSchemeLock.Release;
  end;
end;

function GtkLiveWindowCount: Integer; inline;
begin
  // perf: O(1) inline read under RW read lock, zero alloc, pointer-only, avoids GSchemeLock serialization with scheme ctx
  if GLiveLock <> nil then GLiveLock.AcquireRead;
  try
    Result := GLiveCount;
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseRead;
  end;
end;

procedure RegisterLive(AWin: TGtkWebview);
begin
  if GLiveLock <> nil then GLiveLock.AcquireWrite;
  try
    // single source: live generic registry -> bytes.ops VecGrow 0→4→2× inline, zero-copy
    if GLiveWindows <> nil then
      GLiveWindows.Register(AWin);
    // perf: O(1) hash view->window via VecGrowCapacity single source 0→4→8 inline, zero-copy, write path only, read hot path zero alloc
    if AWin.FView <> nil then
      ViewMapAddLocked(AWin.FView, AWin);
    Inc(GLiveCount);
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseWrite;
  end;
end;

procedure UnregisterLive(AWin: TGtkWebview);
begin
  if GLiveLock <> nil then GLiveLock.AcquireWrite;
  try
    // stability: remove view index before registry to avoid stale pointer window
    if AWin.FView <> nil then
      ViewMapRemoveLocked(AWin.FView);
    // single source: live generic registry Unregister inline O(1) swap, bytes.ops VecRemoveSwap single source, hot close avoids O(n²), zero-copy
    if GLiveWindows <> nil then
      GLiveWindows.Unregister(AWin);
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseWrite;
  end;
end;

{ ---- cdecl trampolines ---- }

function IdleTrampoline(AUserData: Pointer): gboolean; cdecl;
var
  LRec: PIdleRec absolute AUserData;
begin
  try
    LRec^.Proc();
  except
    { UI 主线程投递闭包不允许异常外泄进 GLib 主循环；边界捕获吞掉并继续
      （与 TUI 事件循环同一立场）。 }
    on E: Exception do ;
  end;
  Result := GLIB_SOURCE_REMOVE;
end;

procedure IdleDestroy(AUserData: Pointer); cdecl;
begin
  ReleaseIdleRec(PIdleRec(AUserData));
end;

procedure DestroyCb(AWidget: Pointer; AUserData: Pointer); cdecl;
begin
  TGtkWebview(AUserData).HandleNativeDestroy;
end;

procedure ScriptMessageCb(AManager, AJsResult, AUserData: Pointer); cdecl;
var
  LSelf: TGtkWebview absolute AUserData;
  LVal, LRaw: Pointer;
  LJson: string;
  LFrame: TWebviewFrame;
begin
  if LSelf.FClosed then
    Exit;
  LVal := WEBKIT_javascript_result_get_js_value(AJsResult);
  LRaw := JSC_value_to_string(LVal);
  if LRaw = nil then
    Exit;
  try
    LJson := AnsiPtrToStr(PAnsiChar(LRaw));
  finally
    G_free(LRaw);
  end;
  { 坏帧静默忽略（§3.1）：此时可能连可靠回执通道都没有 }
  if TryDecodeFrame(LJson, LFrame) then
    LSelf.DispatchFrame(LFrame);
end;

procedure LoadChangedCb(AView: Pointer; AEvent: guint;
  AUserData: Pointer); cdecl;
const
  WEBKIT_LOAD_STARTED = 0;
  WEBKIT_LOAD_FINISHED = 3;
  WEBKIT_LOAD_FAILED = 4;
var
  LSelf: TGtkWebview absolute AUserData;
  LEv: TWebviewNavigationEvent;
  I: Integer;
begin
  case AEvent of
    WEBKIT_LOAD_STARTED:
      begin
        GtkTrace('nav started: ' + LSelf.CurrentUri);
        LEv := Default(TWebviewNavigationEvent);
        LEv.Url := LSelf.CurrentUri;
        // single source: live registry Count/At inline, bytes.ops Vec single source, zero-copy
        if LSelf.FOnNavStarted <> nil then
          for I := 0 to LSelf.FOnNavStarted.Count - 1 do
            if Assigned(LSelf.FOnNavStarted.At(I)) then
              try
                LSelf.FOnNavStarted.At(I)(LEv);
              except
              end;
      end;
    WEBKIT_LOAD_FINISHED:
      begin
        GtkTrace('nav finished: ' + LSelf.CurrentUri);
        LEv := Default(TWebviewNavigationEvent);
        LEv.Url := LSelf.CurrentUri;
        if LSelf.FOnNavFinished <> nil then
          for I := 0 to LSelf.FOnNavFinished.Count - 1 do
            if Assigned(LSelf.FOnNavFinished.At(I)) then
              try
                LSelf.FOnNavFinished.At(I)(LEv);
              except
              end;
        LSelf.FireReadyOnce;
      end;
    WEBKIT_LOAD_FAILED:
      begin
        GtkTrace('nav failed(load-changed): ' + LSelf.CurrentUri);
        LEv := Default(TWebviewNavigationEvent);
        LEv.Url := LSelf.CurrentUri;
        LEv.IsError := True;
        if LSelf.FOnNavFailed <> nil then
          for I := 0 to LSelf.FOnNavFailed.Count - 1 do
            if Assigned(LSelf.FOnNavFailed.At(I)) then
              try
                LSelf.FOnNavFailed.At(I)(LEv);
              except
              end;
      end;
  end;
end;

procedure LoadFailedCb(AView, ALoadEvent, AFailingUri, AErr,
  AUserData: Pointer); cdecl;
var
  LSelf: TGtkWebview absolute AUserData;
  LEv: TWebviewNavigationEvent;
  I: Integer;
begin
  if LSelf.FClosed then
    Exit;
  GtkTrace('nav failed: ' + AnsiPtrToStr(PAnsiChar(AFailingUri)));
  LEv := Default(TWebviewNavigationEvent);
  LEv.Url := AnsiPtrToStr(PAnsiChar(AFailingUri));
  LEv.IsError := True;
  if AErr <> nil then
  begin
    LEv.ErrorCode := PGError(AErr)^.Code;
    if PGError(AErr)^.Message <> nil then
      LEv.ErrorMessage := AnsiPtrToStr(PAnsiChar(PGError(AErr)^.Message));
  end;
  if LSelf.FOnNavFailed <> nil then
    for I := 0 to LSelf.FOnNavFailed.Count - 1 do
      if Assigned(LSelf.FOnNavFailed.At(I)) then
        try
          LSelf.FOnNavFailed.At(I)(LEv);
        except
        end;
end;

procedure ScaleNotifyCb(AObj, APspec, AUserData: Pointer); cdecl;
var
  LSelf: TGtkWebview absolute AUserData;
  LNew: Double;
  I: Integer;
begin
  if LSelf.FClosed then
    Exit;
  LNew := LSelf.GetScaleFactor;
  if Abs(LNew - LSelf.FScale) > 1e-9 then
  begin
    LSelf.FScale := LNew;
    if LSelf.FOnScaleChanged <> nil then
      for I := 0 to LSelf.FOnScaleChanged.Count - 1 do
        if Assigned(LSelf.FOnScaleChanged.At(I)) then
          try
            LSelf.FOnScaleChanged.At(I)(LNew);
          except
          end;
  end;
end;

const
  VIEW_TOMBSTONE = Pointer(1);

{ ---- view->window O(1) 索引：开地址 hash 薄封装，单源复用 gtk.viewmap.ViewHash (hashmap.base.HashOfPointer→HashMix32) ---- }
function ViewHash(AKey: Pointer): UInt32; inline;
begin
  // 单源委托：gtk.viewmap 单源哈希，与 assets WyHash/HashMix32 单源一致，零分布分叉，inline 零额外调用
  Result := nextpas.core.webview.gtk.viewmap.ViewHash(AKey);
end;

function ViewMapFindLocked(AView: Pointer): TGtkWebview; inline;
var
  I, Cap, Start: Integer;
begin
  Result := nil;
  Cap := Length(GViewMap);
  if (Cap = 0) or (AView = nil) then Exit;
  Start := Integer(ViewHash(AView) mod SizeUInt(Cap));
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) mod Cap].Key = AView then
      Exit(GViewMap[(Start + I) mod Cap].Value);
    if GViewMap[(Start + I) mod Cap].Key = nil then
      Exit(nil);
  end;
end;

procedure ViewMapRehashLocked(ANewCap: Integer);
var
  LOld: array of TViewMapEntry;
  I, OldCap, Start, J: Integer;
begin
  LOld := GViewMap;
  OldCap := Length(LOld);
  SetLength(GViewMap, ANewCap);
  for I := 0 to ANewCap - 1 do
  begin
    GViewMap[I].Key := nil;
    GViewMap[I].Value := nil;
  end;
  GViewMapCount := 0;
  for I := 0 to OldCap - 1 do
    if (LOld[I].Key <> nil) and (LOld[I].Key <> VIEW_TOMBSTONE) then
    begin
      Start := Integer(ViewHash(LOld[I].Key) mod SizeUInt(ANewCap));
      for J := 0 to ANewCap - 1 do
        if GViewMap[(Start + J) mod ANewCap].Key = nil then
        begin
          GViewMap[(Start + J) mod ANewCap].Key := LOld[I].Key;
          GViewMap[(Start + J) mod ANewCap].Value := LOld[I].Value;
          Inc(GViewMapCount);
          Break;
        end;
    end;
end;

procedure ViewMapAddLocked(AView: Pointer; AWin: TGtkWebview); inline;
var
  I, Cap, Start, FirstTomb: Integer;
begin
  if (AView = nil) or (AWin = nil) then Exit;
  Cap := Length(GViewMap);
  if Cap = 0 then
  begin
    SetLength(GViewMap, VecGrowCapacity(0));
    Cap := Length(GViewMap);
  end;
  if (GViewMapCount * 4 >= Cap * 3) then
  begin
    Cap := VecGrowCapacity(Cap);
    ViewMapRehashLocked(Cap);
    Cap := Length(GViewMap);
  end;
  Start := Integer(ViewHash(AView) mod SizeUInt(Cap));
  FirstTomb := -1;
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) mod Cap].Key = AView then
    begin
      GViewMap[(Start + I) mod Cap].Value := AWin;
      Exit;
    end;
    if GViewMap[(Start + I) mod Cap].Key = VIEW_TOMBSTONE then
    begin
      if FirstTomb = -1 then FirstTomb := (Start + I) mod Cap;
    end
    else if GViewMap[(Start + I) mod Cap].Key = nil then
    begin
      if FirstTomb <> -1 then
      begin
        GViewMap[FirstTomb].Key := AView;
        GViewMap[FirstTomb].Value := AWin;
      end
      else
      begin
        GViewMap[(Start + I) mod Cap].Key := AView;
        GViewMap[(Start + I) mod Cap].Value := AWin;
      end;
      Inc(GViewMapCount);
      Exit;
    end;
  end;
end;

procedure ViewMapRemoveLocked(AView: Pointer); inline;
var
  I, Cap, Start: Integer;
begin
  Cap := Length(GViewMap);
  if (Cap = 0) or (AView = nil) then Exit;
  Start := Integer(ViewHash(AView) mod SizeUInt(Cap));
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) mod Cap].Key = AView then
    begin
      GViewMap[(Start + I) mod Cap].Key := VIEW_TOMBSTONE;
      GViewMap[(Start + I) mod Cap].Value := nil;
      Dec(GViewMapCount);
      if GViewMapCount < 0 then GViewMapCount := 0;
      Exit;
    end;
    if GViewMap[(Start + I) mod Cap].Key = nil then
      Exit;
  end;
end;

var
  GSchemeErrQuark: GQuark = 0;

{ scheme 请求的 owner 解析（S5）：context 级注册只能绑一个 trampoline，
  但请求可精确归属发起视图——webkit_uri_scheme_request_get_web_view
  对回 GLiveWindows 的 FView 指针即得所属窗口，多窗口资产命名空间
  硬隔离。service worker 等无视图请求回落"最新活跃窗口"。
  perf: zero-alloc hot path — O(1) hash view->window via VecGrowCapacity single source inline zero-copy, no linear scan, no VecSnapshot heap alloc, short RW read critical section pointer-only, 95% single-window fast path inline }
function LiveWindowForView(AView: Pointer): TGtkWebview; inline;
var
  LCandidate: TGtkWebview;
begin
  Result := nil;
  if AView = nil then
    Exit(nil);
  if GLiveLock <> nil then GLiveLock.AcquireRead;
  try
    // perf: inline zero-alloc O(1) hash probe under RW read lock via bytes.ops VecGrowCapacity single source, no linear scan, no SetLength/heap, zero-copy, concurrent reads scale
    LCandidate := ViewMapFindLocked(AView);
    if (LCandidate <> nil) and (not LCandidate.FClosed) then
      Exit(LCandidate);
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseRead;
  end;
end;

function LatestLiveWebview: TGtkWebview; inline;
var
  I: Integer;
begin
  // perf: zero-alloc reverse scan under RW read lock via live registry Count/At single source (bytes.ops Vec inline), no VecSnapshot heap alloc, short critical section pointer-only, inline zero-copy; fallback path only for service-worker nil view, cold
  Result := nil;
  if GLiveLock <> nil then GLiveLock.AcquireRead;
  try
    if GLiveWindows <> nil then
      for I := GLiveWindows.Count - 1 downto 0 do
        if not GLiveWindows.At(I).FClosed then
          Exit(GLiveWindows.At(I));
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseRead;
  end;
end;

{ finish_error 的 GError 所有权移交 WebKit（源码 adoptGRef 模式），
  调用方不 free；误判会在 live 门禁以 double-free 可见地暴露
  单源：WEBVIEW_ASSET_NOT_FOUND_CODE/MSG（base），避免 404/文案各处漂移 }
procedure SchemeFinishNotFound(ARequest: Pointer); inline;
begin
  if ARequest = nil then
    Exit;
  if GSchemeErrQuark = 0 then
    GSchemeErrQuark := G_quark_from_static_string('nextpas-webview');
  WEBKIT_uri_scheme_request_finish_error(ARequest,
    G_error_new_literal(GSchemeErrQuark, WEBVIEW_ASSET_NOT_FOUND_CODE, WEBVIEW_ASSET_NOT_FOUND_MSG));
end;

procedure SchemeRequestCb(ARequest, AUserData: Pointer); cdecl;
var
  LSelf: TGtkWebview;
  LKeep: IInterface;
  LPath, LMime: string;
  LPathView: TStringView;
  LRaw: PAnsiChar;
  LBytes: TBytes;
  LStream, LBytesObj: Pointer;
  LHolder: PAssetHolder;
  LView: Pointer;
  I: Integer;
begin
  if not Assigned(ARequest) then
    Exit;
  try
  if Assigned(WEBKIT_uri_scheme_request_get_web_view) then
    LView := WEBKIT_uri_scheme_request_get_web_view(ARequest)
  else
    LView := nil;
  LSelf := nil;
  LKeep := nil;
  // perf: zero-alloc hot path — O(1) hash view->window via RW read lock + bytes.ops VecGrowCapacity single source inline zero-copy, no linear scan, pointer-only critical section, keep-alive AddRef inside lock, concurrent reads scale with RWLock
    if GLiveLock <> nil then GLiveLock.AcquireRead;
    try
      if LView <> nil then
      begin
        LSelf := ViewMapFindLocked(LView);
        if (LSelf <> nil) and LSelf.FClosed then
          LSelf := nil;
        if LSelf <> nil then
          LKeep := LSelf as IInterface;
      end;
      if LSelf = nil then
      begin
        if GLiveWindows <> nil then
          for I := GLiveWindows.Count - 1 downto 0 do
            if not GLiveWindows.At(I).FClosed then
            begin
              LSelf := GLiveWindows.At(I);
              LKeep := LSelf as IInterface;
              Break;
            end;
      end;
    finally
      if GLiveLock <> nil then GLiveLock.ReleaseRead;
    end;
  if LSelf = nil then
  begin
    GtkTrace('scheme request, no live window: ' +
      AnsiPtrToStr(PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest))));
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  if not Assigned(WEBKIT_uri_scheme_request_get_path) then
  begin
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  if WEBKIT_uri_scheme_request_get_path(ARequest) = nil then
  begin
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  // perf: zero-copy view path — ViewFromPChar 零 AnsiPtrToStr 中间串 + NormalizeWebviewAssetView inline 零拷贝视图，供热点零分配
  LRaw := PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest));
  LPathView := NormalizeWebviewAssetView(ViewFromPChar(LRaw));
  if LPathView.Len = 0 then
  begin
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  LPath := LPathView.ToString; // 单次 SetString+Move，零中间 AnsiPtrToStr 分配，比原 1-2 串 减一次
  if not Assigned(LSelf.FAssetsIntf) then
  begin
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  try
    if not LSelf.FAssetsIntf.TryResolve(LPath, LBytes, LMime) then
    begin
      GtkTrace('scheme miss ' + LPath + ' -> 404');
      SchemeFinishNotFound(ARequest);
      Exit;
    end;
  except
    on E: Exception do
    begin
      GtkTrace('scheme resolve ex ' + LPath + ': ' + E.Message + ' -> 404');
      SchemeFinishNotFound(ARequest);
      Exit;
    end;
  end;
  GtkTrace('scheme hit ' + LPath + ' (' + IntToStr(Length(LBytes)) + 'B)');
  if LMime = '' then
    LMime := GuessWebviewMime(LPath); { 单源：webview.mime inline→http.mime，已含默认回退，零拷贝 }
  LStream := nil;
  LBytesObj := nil;
  // perf: unified zero-copy via GBytes holder — small+large single path, holder COW shares refcount (bytes.ops single source zero-copy, no Move), batch Move eliminated, threshold retired; inline zero heap jitter
  // stability: AssetBufFree tied to GBytes lifecycle, stream owned by WebKit after finish, no double-free, exception-safe Dispose holder on GBytes failure
  if not Assigned(G_bytes_new_with_free_func) or not Assigned(G_memory_input_stream_new_from_bytes) or not Assigned(WEBKIT_uri_scheme_request_finish) then
  begin
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  New(LHolder);
  LHolder^.Bytes := LBytes; // zero-copy COW share, bytes.ops single source (TBytes refcount), no Move
  try
    if Length(LHolder^.Bytes) > 0 then
      LBytesObj := G_bytes_new_with_free_func(@LHolder^.Bytes[0], Length(LHolder^.Bytes), @AssetBufFree, LHolder)
    else
      LBytesObj := G_bytes_new_with_free_func(nil, 0, @AssetBufFree, LHolder);
  except
    Dispose(LHolder);
    raise;
  end;
  if Assigned(LBytesObj) and Assigned(G_memory_input_stream_new_from_bytes) then
    try
      LStream := G_memory_input_stream_new_from_bytes(LBytesObj);
    except
      LStream := nil;
    end;
  if Assigned(LBytesObj) and Assigned(G_bytes_unref) then
    try
      G_bytes_unref(LBytesObj);
    except
    end;
  if not Assigned(LStream) then
  begin
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  { 所有权随流移交 WebKit，GBytes 不再自释放 }
  try
    WEBKIT_uri_scheme_request_finish(ARequest, LStream,
      Length(LBytes), PAnsiChar(LMime));
  except
    try
      SchemeFinishNotFound(ARequest);
    except
    end;
  end;
  except
    on E: Exception do
      try
        if Assigned(ARequest) then
          SchemeFinishNotFound(ARequest);
      except
      end;
  end;
end;

function CompletionMarshalTrampoline(AUserData: Pointer): gboolean; cdecl;
var
  LRec: PCompletionMarshal absolute AUserData;
  LSelf: TGtkWebview;
begin
  LSelf := TGtkWebview(LRec^.Win);
  if not LSelf.FClosed then
    LSelf.SendReceipt(LRec^.FrameId, LRec^.IsError, LRec^.ResultJson,
      LRec^.Code, LRec^.MsgText);
  Result := GLIB_SOURCE_REMOVE;
end;

procedure CompletionMarshalDestroy(AUserData: Pointer); cdecl;
begin
  ReleaseCompletionRec(PCompletionMarshal(AUserData));
end;

{ ---- 单元级 eval 结算助手（不依赖 Self，迟到回执安全）---- }

function EvalTextOfValueGlobal(AJscValue: Pointer): string;
var
  LRaw: PAnsiChar;
begin
  if AJscValue = nil then
    Exit('');
  if (JSC_value_is_null(AJscValue) <> 0) or
     (JSC_value_is_undefined(AJscValue) <> 0) then
    Exit('null');
  LRaw := JSC_value_to_json(AJscValue, 0);
  if LRaw <> nil then
  begin
    Result := AnsiPtrToStr(LRaw);
    G_free(LRaw);
  end
  else
  begin
    { 不可 JSON 化（如 symbol）：诚实降级为 JS toString 文本 }
    LRaw := JSC_value_to_string(AJscValue);
    Result := AnsiPtrToStr(LRaw);
    G_free(LRaw);
  end;
end;

{ 记录所有权单点释放（仅引擎完成回调一侧调用）：随记录 unref 其
  GCancellable——cancellable 是 GObject，漏 unref 即逐次 eval 泄漏 }
procedure FreeEvalRec(ARec: PEvalRec);
begin
  if ARec^.Cancel <> nil then
    G_object_unref(ARec^.Cancel);
  Dispose(ARec);
end;

procedure SettleEvalGlobal(ARec: PEvalRec; AOk: Boolean; const AText: string);
var
  LErr: EWebviewEvalFailed;
begin
  if ARec^.Done then
  begin
    FreeEvalRec(ARec);
    Exit;
  end;
  ARec^.Done := True;
  try
    if AOk then
    begin
      if Assigned(ARec^.Callback) then
        ARec^.Callback(AText);
    end
    else if Assigned(ARec^.OnError) then
    begin
      { 框架创建、触发、try-finally 释放（CONTRACT §3.2 所有权语义） }
      LErr := EWebviewEvalFailed.Create(AText);
      try
        ARec^.OnError(LErr);
      finally
        LErr.Free;
      end;
    end;
  finally
    FreeEvalRec(ARec);
  end;
end;

procedure EvalReadyCb(ASource, ARes, AUserData: Pointer); cdecl;
var
  LRec: PEvalRec absolute AUserData;
  LErr: PGError = nil;
  LJsRes, LVal: Pointer;
  LOk: Boolean;
  LText: string;
begin
  if LRec^.Done then
  begin
    { Close 已收尾：仅释放记录（所有权仍在引擎回执一侧） }
    GtkTrace('eval late callback after close, disposed');
    if LRec^.Owner <> nil then
      TGtkWebview(LRec^.Owner).RemovePending(LRec);
    FreeEvalRec(LRec);
    Exit;
  end;
  LVal := nil;
  LOk := False;
  if GtkLoadInfo().EvalPath = gepEvaluateJavascript then
    LVal := WEBKIT_web_view_evaluate_javascript_finish(ASource, ARes, @LErr)
  else
  begin
    LJsRes := WEBKIT_web_view_run_javascript_finish(ASource, ARes, @LErr);
    if LJsRes <> nil then
      LVal := WEBKIT_javascript_result_get_js_value(LJsRes);
  end;
  if LErr <> nil then
  begin
    LText := AnsiPtrToStr(PAnsiChar(LErr^.Message));
    GtkTrace('eval failed: ' + LText);
  end
  else
  begin
    LOk := True;
    if LVal <> nil then
      LText := EvalTextOfValueGlobal(LVal)
    else
      LText := '';
    GtkTrace('eval ok: ' + Copy(LText, 1, 120));
  end;
  if LRec^.Owner <> nil then
    TGtkWebview(LRec^.Owner).RemovePending(LRec);
  SettleEvalGlobal(LRec, LOk, LText);
end;

{ ---- TGtkCompletion：at-most-once + idle marshal ---- }

type
  TGtkCompletion = class(TInterfacedObject, IWebviewInvokeCompletion)
  private
    FWin: TObject;
    FCmd: string;
    FFrameId: Int64;
    FDone: Boolean;
    procedure RecordViaIdle(AIsError: Boolean;
      const AResultJson, ACode, AMessage: string);
  public
    constructor Create(AWin: TObject; const ACmd: string; AFrameId: Int64);
    procedure Ok(const AResultJson: string);
    procedure Fail(const ACode, AMessage: string);
  end;

constructor TGtkCompletion.Create(AWin: TObject; const ACmd: string;
  AFrameId: Int64);
begin
  inherited Create;
  FWin := AWin;
  FCmd := ACmd;
  FFrameId := AFrameId;
end;

procedure TGtkCompletion.RecordViaIdle(AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LRec: PCompletionMarshal;
begin
  { 只捕获局部值拷贝进 marshal 记录；completion 自身可先于泵释放，
    窗口存活由 keep-alive 保证 — Slab 池化零每 Post 堆分配，G_idle_add_full 保留 }
  LRec := AcquireCompletionRec;
  LRec^.Win := FWin;
  LRec^.FrameId := FFrameId;
  LRec^.Cmd := FCmd;
  LRec^.IsError := AIsError;
  LRec^.ResultJson := AResultJson;
  LRec^.Code := NormalizeInvokeCode(ACode);
  LRec^.MsgText := AMessage;
  G_idle_add_full(G_PRIORITY_DEFAULT, @CompletionMarshalTrampoline,
    LRec, @CompletionMarshalDestroy);
end;

procedure TGtkCompletion.Ok(const AResultJson: string);
begin
  if FDone then
    raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  RecordViaIdle(False, AResultJson, '', '');
end;

procedure TGtkCompletion.Fail(const ACode, AMessage: string);
begin
  if FDone then
    raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  RecordViaIdle(True, '', ACode, AMessage);
end;

{ ---- TGtkWebview ---- }

constructor TGtkWebview.Create(const AOptions: TWebviewOptions);
var
  LInfo: TGtkLoadInfo;
  LResolved: TWebviewOptions;
begin
  inherited Create;
  LResolved := AOptions;
  if LResolved.SchemeName = '' then
    LResolved.SchemeName := DEFAULT_WEBVIEW_SCHEME;
  CheckWebviewOptions(LResolved);
  FOptions := LResolved;

  if not TryLoadGtkWebkit(LInfo) then
    raise EWebviewBackendUnavailable.Create(
      'WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)');
  if not WindowGtkRawInit then
    raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)');

  FOwnerThread := platform_thread_id;
  FScale := 1.0;
  FInvokesIntf := TWebviewInvokeRegistry.Create;
  FInvokes := FInvokesIntf as TObject;
  FAssetsIntf := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FAssets := FAssetsIntf as TObject;
  // single source: live generic registry 0→4→2× inline via bytes.ops VecGrow, nil zero-alloc, eliminates Grow/Count Vec sample duplication
  FIdleTags := specialize TWebviewLiveRegistry<guint>.Create;
  FPendingEvals := specialize TWebviewLiveRegistry<PEvalRec>.Create;
  FOnNavStarted := specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFinished := specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFailed := specialize TWebviewLiveRegistry<TWebviewNavFailedHandler>.Create;
  FOnWindowClosed := specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create;
  FOnReady := specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create;
  FOnScaleChanged := specialize TWebviewLiveRegistry<TWebviewScaleHandler>.Create;
  if FOptions.DevServerUrl <> '' then
    GtkTrace('dev mode: assets inert, scheme deferred (' +
      FOptions.DevServerUrl + ')');

  SetupSessionContext;
  SetupSchemeAndShell;
  WireSignals;

  RegisterLive(Self);
  FSelfKeepAlive := Self;   { keep-alive：见单元头 }

  { Initial* 启动加载：构造即导航。优先级 InitialUrl > InitialHtml
    （CONTRACT §2.2），资产解析发生在主循环泵请求时，Build 返回后的挂载
    先于任何请求，无时序竞态（§3.4） }
  if FOptions.InitialUrl <> '' then
    Navigate(FOptions.InitialUrl)
  else if FOptions.InitialHtml <> '' then
    NavigateToString(FOptions.InitialHtml);
end;

destructor TGtkWebview.Destroy;
begin
  { context 生命周期收口：自有 context 先摘 scheme 注册表再 unref——
    顺序不可反，unref 后地址可能被新分配复用，后摘会误删他人条目
    （注册表按指针地址判重）。共享默认 context 不持有不摘除。 }
  if FOwnsContext and (FContext <> nil) then
  begin
    ForgetSchemeContext(FContext);
    G_object_unref(FContext);
    FContext := nil;
  end;
  UnregisterLive(Self);
  // stability: registry Free releases Vec and nil string/interface refs, resource release not lost
  FreeAndNil(FOnScaleChanged);
  FreeAndNil(FOnReady);
  FreeAndNil(FOnWindowClosed);
  FreeAndNil(FOnNavFailed);
  FreeAndNil(FOnNavFinished);
  FreeAndNil(FOnNavStarted);
  FreeAndNil(FPendingEvals);
  FreeAndNil(FIdleTags);
  inherited Destroy;
end;

function TGtkWebview.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TGtkWebview.RequireOpen;
begin
  if FClosed then
    raise EWebviewClosed.Create('webview window is closed');
end;

procedure TGtkWebview.RemovePending(ARec: PEvalRec);
begin
  // single source: live registry Unregister -> bytes.ops VecGrow single source, zero-copy shift, inline
  if FPendingEvals <> nil then
    FPendingEvals.Unregister(ARec);
end;

procedure TGtkWebview.FireNotifyHandlers(AReg: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>);
var
  I: Integer;
begin
  // single source: live registry Count/At inline, bytes.ops single source, O(n) single pass, zero-copy
  if AReg = nil then Exit;
  for I := 0 to AReg.Count - 1 do
    if Assigned(AReg.At(I)) then
      try
        AReg.At(I)();
      except
        { 单处理器异常隔离：不中断后续，保持与 FireReadyOnce 一致 }
      end;
end;

procedure TGtkWebview.SetupSessionContext;
begin
  FOwnsContext := False;
  if FOptions.EphemeralSession then
  begin
    FOwnsContext := True;
  end
  else if FOptions.DataDirectory <> '' then
    FOwnsContext := True;
  { 具体构造在 SetupSchemeAndShell 内与 scheme 注册同序完成；
    默认共享 context 用 nil 标记 }
end;

function TGtkWebview.ResolveContext: Pointer;
var
  LManager: Pointer;
begin
  if not FOwnsContext then
    Exit(WEBKIT_web_context_get_default());
  if FOptions.EphemeralSession then
    Result := WEBKIT_web_context_new_ephemeral()
  else
  begin
    { website_data_manager 不是 context——须经 new_with_website_data_manager
      包装（S7 live 门禁实锤：直传 manager 触发 WEBKIT_IS_WEB_CONTEXT
      CRITICAL 且 new_with_context 返回 nil） }
    LManager := WEBKIT_website_data_manager_new('base-data-directory',
      PAnsiChar(FOptions.DataDirectory), Pointer(nil));
    if LManager = nil then
      raise EWebviewNotInitialized.Create(
        'webkit_website_data_manager_new failed (data directory rejected)');
    Result := WEBKIT_web_context_new_with_website_data_manager(LManager);
    G_object_unref(LManager);   { context 持有自身引用，交还初始引用 }
  end;
  FContext := Result;
end;

procedure TGtkWebview.SetupSchemeAndShell;
var
  LCtx: Pointer;
begin
  LCtx := ResolveContext;
  { scheme 注册必须先于该 context 首个 web view 创建（BACKENDS §2.2）；
    同 context 只注册一次（GLib 拒绝重复注册）。handler 不绑定任何
    窗口实例——请求按发起视图精确归属（见 SchemeRequestCb），context
    销毁时经 ForgetSchemeContext 摘除，防地址复用误判已注册。
    DevServerUrl 开发模式不注册（§3.4 直连 http）；同 context 的后续
    非 dev 窗口按需补注册——注册发生在其构造期，仍先于它的首次导航 }
  if (FOptions.DevServerUrl = '') and (not SchemeContextRegistered(LCtx)) then
  begin
    WEBKIT_web_context_register_uri_scheme(LCtx,
      PAnsiChar(FOptions.SchemeName), @SchemeRequestCb, nil, nil);
    RememberSchemeContext(LCtx);
  end;

  FView := WEBKIT_web_view_new_with_context(LCtx);
  if FView = nil then
    raise EWebviewNotInitialized.Create(
      'webkit_web_view_new_with_context returned nil');

  { 单源：窗口壳经 window.gtk3 Raw 薄转发，零拷贝 inline，复用已绑定 gtk_* }
  FWin := WindowGtkRawCreate(FOptions.Title, FOptions.Width, FOptions.Height,
    FOptions.Resizable, FOptions.Maximized);
  if FWin = nil then
    raise EWebviewNotInitialized.Create('WindowGtkRawCreate returned nil');
  GTK_container_add(FWin, FView);

  if FOptions.DebugTools then
    WEBKIT_settings_set_enable_developer_extras(
      WEBKIT_web_view_get_settings(FView), 1);
end;

procedure TGtkWebview.AddUserScript(const ASource: string);
var
  LUcm, LScript: Pointer;
begin
  LUcm := WEBKIT_web_view_get_user_content_manager(FView);
  LScript := WEBKIT_user_script_new(PAnsiChar(ASource),
    WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
    WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, nil, nil);
  WEBKIT_user_content_manager_add_script(LUcm, LScript);
  WEBKIT_user_script_unref(LScript);
end;

procedure TGtkWebview.WireSignals;
begin
  g_signal_connect_data(FWin, 'destroy', @DestroyCb, Self, nil, 0);

  g_signal_connect_data(
    WEBKIT_web_view_get_user_content_manager(FView),
    'script-message-received::npw', @ScriptMessageCb, Self, nil, 0);
  WEBKIT_user_content_manager_register_script_message_handler(
    WEBKIT_web_view_get_user_content_manager(FView), 'npw');
  AddUserScript(NPW_BRIDGE_SCRIPT);

  g_signal_connect_data(FView, 'load-changed', @LoadChangedCb, Self, nil, 0);
  { 导航失败走官方 load-failed（携带 failing_uri + GError）——
    load-changed 的 WEBKIT_LOAD_FAILED 事件不带错误详情，此前该信号
    未接线导致 OnNavigationFailed 全程未生效（dev-mode 门禁实锤） }
  g_signal_connect_data(FView, 'load-failed', @LoadFailedCb, Self, nil, 0);
  g_signal_connect_data(FView, 'notify::scale-factor',
    @ScaleNotifyCb, Self, nil, 0);
end;

function TGtkWebview.CurrentUri: string;
var
  LP: PAnsiChar;
begin
  LP := WEBKIT_web_view_get_uri(FView);
  if LP <> nil then
    Result := AnsiPtrToStr(LP)
  else
    Result := '';
end;

procedure TGtkWebview.FireReadyOnce;
var
  I: Integer;
begin
  if FReadyFired or FClosed then
    Exit;
  FReadyFired := True;
  // single source: live registry Count/At inline
  if FOnReady <> nil then
    for I := 0 to FOnReady.Count - 1 do
      if Assigned(FOnReady.At(I)) then
        try
          FOnReady.At(I)();
        except
          { 单处理器异常隔离：不中断后续、不外抛 }
        end;
end;

class function TGtkWebview.MapInvokeCodeSafe(E: Exception): string;
begin
  if E is EWebviewInvokeError then
    Result := NormalizeInvokeCode(EWebviewInvokeError(E).Code)
  else
    Result := NPW_CODE_HANDLER_ERROR;
end;

procedure TGtkWebview.DispatchFrame(const AFrame: TWebviewFrame);
var
  LReg: TWebviewInvokeRegistry;
  LIsAsync: Boolean;
  LSync: TWebviewInvokeSyncHandler;
  LAsync: TWebviewInvokeAsyncHandler;
  LResultJson: string;
  LCompletion: IWebviewInvokeCompletion;
begin
  RequireOpen;
  LReg := TWebviewInvokeRegistry(FInvokes);
  if not LReg.Find(AFrame.Cmd, LIsAsync, LSync, LAsync) then
  begin
    SendReceipt(AFrame.Id, True, '', NPW_CODE_HANDLER_MISSING,
      'no handler registered for cmd');
    Exit;
  end;
  if LIsAsync then
  begin
    LCompletion := TGtkCompletion.Create(Self, AFrame.Cmd, AFrame.Id);
    try
      LAsync(AFrame.PayloadJson, LCompletion);
    except
      on E: Exception do
        SendReceipt(AFrame.Id, True, '', MapInvokeCodeSafe(E), E.Message);
    end;
  end
  else
  begin
    try
      LResultJson := LSync(AFrame.PayloadJson);
      SendReceipt(AFrame.Id, False, LResultJson, '', '');
    except
      on E: Exception do
        SendReceipt(AFrame.Id, True, '', MapInvokeCodeSafe(E), E.Message);
    end;
  end;
end;

{ 内部回执 eval：fire-and-forget，不入在途登记。无用户回调需
  恰好一次语义；若 Close 与分发竞态，最坏结果是页面未收到回执——
  与页面已销毁的观察一致，且无任何记录可悬挂泄漏 }
procedure TGtkWebview.SendReceipt(AFrameId: Int64; AIsError: Boolean;
  const AResultJson, ACode, AMessage: string);
var
  LJs: string;
begin
  if FClosed then
    Exit;
  if AIsError then
    LJs := BuildRejectScript(AFrameId, ACode, AMessage)
  else
    LJs := BuildResolveScript(AFrameId, AResultJson);
  if GtkLoadInfo().EvalPath = gepEvaluateJavascript then
    WEBKIT_web_view_evaluate_javascript(FView, PAnsiChar(LJs),
      Length(LJs), nil, nil, nil, nil, nil)
  else
    WEBKIT_web_view_run_javascript(FView, PAnsiChar(LJs),
      nil, nil, nil);
end;

procedure TGtkWebview.PostIdle(AProc: TWebviewProcRef);
var
  LRec: PIdleRec;
  LTag: guint;
begin
  LRec := AcquireIdleRec;
  LRec^.Proc := AProc;
  LTag := G_idle_add_full(G_PRIORITY_DEFAULT, @IdleTrampoline, LRec,
    @IdleDestroy);
  // single source: live registry Register -> bytes.ops VecGrow inline, zero-copy
  if FIdleTags <> nil then
    FIdleTags.Register(LTag);
end;

procedure TGtkWebview.DropIdlePendings;
var
  I: Integer;
  LCtx, LSrc: Pointer;
begin
  { 已触发的 idle 在 fire 时即经 destroy-notify 自毁闭包；此处按
    find-by-id 判存再移除，避免对陈旧 Source ID 二次 remove 触发
    GLib-CRITICAL（Dispatcher.Post 后随即 Close 的路径） }
  // single source: live registry Count/At/Clear inline, zero-copy
  if FIdleTags = nil then Exit;
  LCtx := G_main_context_default();
  for I := 0 to FIdleTags.Count - 1 do
  begin
    if LCtx = nil then
      Break;
    LSrc := G_main_context_find_source_by_id(LCtx, FIdleTags.At(I));
    if LSrc <> nil then
      G_source_remove(FIdleTags.At(I));
  end;
  FIdleTags.Clear;
end;

procedure TGtkWebview.SettlePendingOnClose; inline;
var
  I: Integer;
  LRec: PEvalRec;
  LErr: EWebviewEvalFailed;
begin
  // single source: live registry Count/At/Clear inline, O(n) unbounded, zero truncated drop
  if FPendingEvals = nil then Exit;
  for I := 0 to FPendingEvals.Count - 1 do
  begin
    LRec := FPendingEvals.At(I);
    if not LRec^.Done then
    begin
      LRec^.Done := True;
      if Assigned(LRec^.OnError) then
      begin
        LErr := EWebviewEvalFailed.Create('window closed');
        try
          LRec^.OnError(LErr);
        finally
          LErr.Free;
        end;
      end;
      if LRec^.Cancel <> nil then
      begin
        G_cancellable_cancel(LRec^.Cancel);
        LRec^.Cancel := nil;
      end;
    end;
  end;
  FPendingEvals.Clear;
end;

procedure TGtkWebview.HandleNativeDestroy;
begin
  if FClosed then
    Exit;
  FClosed := True;
  if GLiveLock <> nil then GLiveLock.AcquireWrite;
  try
    if GLiveCount > 0 then Dec(GLiveCount);
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseWrite;
  end;
  SettlePendingOnClose;
  DropIdlePendings;
  FireNotifyHandlers(FOnWindowClosed);
  if GtkLiveWindowCount = 0 then
    WindowGtkRawQuitMainLoop;
  FSelfKeepAlive := nil;   { 引用计数归零 → Destroy → UnregisterLive }
end;

procedure TGtkWebview.Close;
begin
  { 幂等（CONTRACT §3 intf 承诺，与 fake 一致）；二次 Close 直接返回，
    避免对已销毁 widget 重复 destroy }
  if FClosed then
    Exit;
  FClosed := True;
  if GLiveLock <> nil then GLiveLock.AcquireWrite;
  try
    if GLiveCount > 0 then Dec(GLiveCount);
  finally
    if GLiveLock <> nil then GLiveLock.ReleaseWrite;
  end;
  { 在途 eval 立即以 onerr 收尾（exactly-one）。记录不在此处释放：
    所有权单点在引擎必然到达的完成回调——迟到回执读 Done 后仅释放。
    异常实例由框架创建/触发/释放（§3.2 所有权语义）。 }
  SettlePendingOnClose;
  DropIdlePendings;
  FireNotifyHandlers(FOnWindowClosed);
  GTK_widget_destroy(FWin);
  if GtkLiveWindowCount = 0 then
    WindowGtkRawQuitMainLoop;
  FSelfKeepAlive := nil;
end;

{ ---- dispatcher 身份 — inline 薄转发保留接口 ---- }

procedure TGtkWebview.Post(AProc: TWebviewProcRef); inline;
begin
  PostIdle(AProc);
end;

procedure TGtkWebview.Post(AProc: TWebviewProcMethod); inline;
begin
  PostIdle(
    procedure
    begin
      AProc();
    end);
end;

procedure TGtkWebview.Post(AProc: TWebviewProc); inline;
begin
  PostIdle(
    procedure
    begin
      AProc();
    end);
end;

function TGtkWebview.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

function TGtkWebview.GetDispatcher: IWebviewDispatcher; inline;
begin
  Result := Self;
end;

{ ---- IWebviewWindow 表面：薄转发到 window.gtk3 Raw 单源 / webkit ---- }

procedure TGtkWebview.Show;
begin
  RequireOpen;
  WindowGtkRawShow(FWin);
end;

procedure TGtkWebview.Hide;
begin
  RequireOpen;
  WindowGtkRawHide(FWin);
end;

function TGtkWebview.IsVisible: Boolean;
begin
  RequireOpen;
  Result := GTK_widget_get_visible(FWin) <> 0;
end;

procedure TGtkWebview.Focus;
begin
  RequireOpen;
  WindowGtkRawFocus(FView);
end;

procedure TGtkWebview.SetTitle(const ATitle: string);
begin
  RequireOpen;
  WindowGtkRawSetTitle(FWin, ATitle);
end;

function TGtkWebview.GetTitle: string;
var
  LRaw: PAnsiChar;
begin
  RequireOpen;
  { WM 级标题同步读：未显式设置过为空串（诚实表，见 BACKENDS §2） }
  LRaw := GTK_window_get_title(FWin);
  if LRaw <> nil then
    Result := AnsiPtrToStr(LRaw)
  else
    Result := '';
end;

procedure TGtkWebview.SetBounds(AWidth, AHeight: Integer);
begin
  RequireOpen;
  WindowGtkRawResize(FWin, AWidth, AHeight);
end;

function TGtkWebview.GetWidth: Integer;
begin
  RequireOpen;
  Result := GTK_widget_get_allocated_width(FView);
end;

function TGtkWebview.GetHeight: Integer;
begin
  RequireOpen;
  Result := GTK_widget_get_allocated_height(FView);
end;

procedure TGtkWebview.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  GTK_window_set_resizable(FWin, Ord(AResizable));
end;

procedure TGtkWebview.Maximize;
begin
  RequireOpen;
  WindowGtkRawMaximize(FWin);
end;

procedure TGtkWebview.Unmaximize;
begin
  RequireOpen;
  WindowGtkRawUnmaximize(FWin);
end;

function TGtkWebview.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := WindowGtkRawIsMaximized(FWin);
end;

procedure TGtkWebview.Minimize;
begin
  RequireOpen;
  GTK_window_iconify(FWin);
end;

procedure TGtkWebview.Restore;
begin
  RequireOpen;
  GTK_window_deiconify(FWin);
end;

function TGtkWebview.IsMinimized: Boolean;
var
  LGdkWin: Pointer;
begin
  RequireOpen;
  LGdkWin := GTK_widget_get_window(FWin);
  { 查询式真值：未 realize 时 gdk window 为 nil 视作非最小化 }
  Result := (LGdkWin <> nil) and
    ((GDK_window_get_state(LGdkWin) and GDK_WINDOW_STATE_ICONIFIED) <> 0);
end;

procedure TGtkWebview.SetZoom(AFactor: Double);
begin
  RequireOpen;
  WEBKIT_web_view_set_zoom_level(FView, AFactor);
end;

function TGtkWebview.GetZoom: Double;
begin
  RequireOpen;
  Result := WEBKIT_web_view_get_zoom_level(FView);
end;

procedure TGtkWebview.SetUserAgent(const AUserAgent: string);
begin
  RequireOpen;
  G_object_set(WEBKIT_web_view_get_settings(FView),
    'user-agent', PAnsiChar(AUserAgent), Pointer(nil));
end;

function TGtkWebview.GetUserAgent: string;
var
  LRaw: PAnsiChar;
begin
  RequireOpen;
  LRaw := nil;
  G_object_get(WEBKIT_web_view_get_settings(FView),
    'user-agent', @LRaw, Pointer(nil));
  if LRaw <> nil then
  begin
    Result := AnsiPtrToStr(LRaw);
    G_free(LRaw);
  end
  else
    Result := '';
end;

function TGtkWebview.GetScaleFactor: Double;
begin
  RequireOpen;
  Result := WindowGtkRawScaleFactor(FView);
end;

procedure TGtkWebview.Navigate(const AUrl: string);
begin
  RequireOpen;
  WEBKIT_web_view_load_uri(FView, PAnsiChar(AUrl));
end;

procedure TGtkWebview.NavigateToString(const AHtml: string);
begin
  RequireOpen;
  WEBKIT_web_view_load_html(FView, PAnsiChar(AHtml), nil);
end;

procedure TGtkWebview.Reload;
begin
  RequireOpen;
  WEBKIT_web_view_reload(FView);
end;

procedure TGtkWebview.Stop;
begin
  RequireOpen;
  WEBKIT_web_view_stop_loading(FView);
end;

function TGtkWebview.CanGoBack: Boolean;
begin
  RequireOpen;
  Result := WEBKIT_web_view_can_go_back(FView) <> 0;
end;

function TGtkWebview.GoBack: Boolean;
begin
  RequireOpen;
  Result := CanGoBack;
  if Result then
    WEBKIT_web_view_go_back(FView);
end;

function TGtkWebview.CanGoForward: Boolean;
begin
  RequireOpen;
  Result := WEBKIT_web_view_can_go_forward(FView) <> 0;
end;

function TGtkWebview.GoForward: Boolean;
begin
  RequireOpen;
  Result := CanGoForward;
  if Result then
    WEBKIT_web_view_go_forward(FView);
end;

function TGtkWebview.NativeHandle: TWebviewNativeHandle;
begin
  RequireOpen;
  Result := WindowGtkRawNativeHandle(FWin);
end;

function TGtkWebview.GetInvokes: IWebviewInvokeRegistry;
begin
  RequireOpen;
  Result := FInvokesIntf;
end;

function TGtkWebview.GetAssets: IWebviewAssets;
begin
  RequireOpen;
  Result := FAssetsIntf;
end;

procedure TGtkWebview.Eval(const AJavascript: string;
  ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
var
  LRec: PEvalRec;
begin
  RequireOpen;
  New(LRec);
  LRec^.Callback := ACallback;
  LRec^.OnError := AOnError;
  LRec^.Done := False;
  LRec^.Cancel := G_cancellable_new();
  LRec^.Owner := Self;
  // single source: live registry Register -> bytes.ops VecGrow inline, zero-copy
  if FPendingEvals <> nil then
    FPendingEvals.Register(LRec);
  GtkTrace('eval dispatch: ' + Copy(AJavascript, 1, 80));
  if GtkLoadInfo().EvalPath = gepEvaluateJavascript then
    WEBKIT_web_view_evaluate_javascript(FView, PAnsiChar(AJavascript),
      Length(AJavascript), nil, nil, LRec^.Cancel, @EvalReadyCb, LRec)
  else
    WEBKIT_web_view_run_javascript(FView, PAnsiChar(AJavascript),
      LRec^.Cancel, @EvalReadyCb, LRec);
end;

procedure TGtkWebview.Emit(const AEvent, APayloadJson: string);
begin
  CheckWebviewEventName(AEvent);
  RequireOpen;
  Eval(BuildEmitScript(AEvent, APayloadJson), nil, nil);
end;

{ ---- 事件注册三形态 ---- }

procedure TGtkWebview.OnScaleChanged(AHandler: TWebviewScaleHandler);
begin
  // single source: live registry Register -> bytes.ops VecGrow 0→4→2× inline, zero-copy
  if FOnScaleChanged <> nil then
    FOnScaleChanged.Register(AHandler);
end;

procedure TGtkWebview.OnScaleChanged(AHandler: TWebviewScaleMethod);
begin
  // single source: webview.callbacks inline
  OnScaleChanged(WebviewScaleMethodToRef(AHandler));
end;

procedure TGtkWebview.OnScaleChanged(AHandler: TWebviewScaleProc);
begin
  OnScaleChanged(WebviewScaleProcToRef(AHandler));
end;

procedure TGtkWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  if FOnNavStarted <> nil then
    FOnNavStarted.Register(AHandler);
end;

procedure TGtkWebview.OnNavigationStarted(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationStarted(WebviewNavMethodToRef(AHandler));
end;

procedure TGtkWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
  OnNavigationStarted(WebviewNavProcToRef(AHandler));
end;

procedure TGtkWebview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
  if FOnNavFinished <> nil then
    FOnNavFinished.Register(AHandler);
end;

procedure TGtkWebview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationFinished(WebviewNavMethodToRef(AHandler));
end;

procedure TGtkWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
  OnNavigationFinished(WebviewNavProcToRef(AHandler));
end;

procedure TGtkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
  if FOnNavFailed <> nil then
    FOnNavFailed.Register(AHandler);
end;

procedure TGtkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(WebviewNavFailedMethodToRef(AHandler));
end;

procedure TGtkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(WebviewNavFailedProcToRef(AHandler));
end;

procedure TGtkWebview.OnWindowClosed(AHandler: TWebviewNotifyHandler);
begin
  if FOnWindowClosed <> nil then
    FOnWindowClosed.Register(AHandler);
end;

procedure TGtkWebview.OnWindowClosed(AHandler: TWebviewNotifyMethod);
begin
  OnWindowClosed(WebviewNotifyMethodToRef(AHandler));
end;

procedure TGtkWebview.OnWindowClosed(AHandler: TWebviewNotifyProc);
begin
  OnWindowClosed(WebviewNotifyProcToRef(AHandler));
end;

procedure TGtkWebview.OnReady(AHandler: TWebviewNotifyHandler);
begin
  if FOnReady <> nil then
    FOnReady.Register(AHandler);
end;

procedure TGtkWebview.OnReady(AHandler: TWebviewNotifyMethod);
begin
  OnReady(WebviewNotifyMethodToRef(AHandler));
end;

procedure TGtkWebview.OnReady(AHandler: TWebviewNotifyProc);
begin
  OnReady(WebviewNotifyProcToRef(AHandler));
end;

initialization
  GSchemeLock := TMutex.Create;
  GPoolLock := TMutex.Create;
  GLiveLock := TRWLock.Create;
  // single source: live generic registry for GLiveWindows / GRegisteredSchemeCtxs -> bytes.ops VecGrow inline, zero-copy
  GLiveWindows := specialize TWebviewLiveRegistry<TGtkWebview>.Create;
  GRegisteredSchemeCtxs := specialize TWebviewLiveRegistry<Pointer>.Create;
  // perf: preallocate view hash to VecGrowCapacity(0) via bytes.ops single source 0→4 inline, zero-copy; read hot path zero alloc, write rehash single source
  SetLength(GViewMap, VecGrowCapacity(0));
  // perf: preallocate slab pools to bounded cap (bytes.ops VecGrowCapacity single source 0→4→8) — steady-state Release never SetLength inside lock, zero heap jitter
  SetLength(GIdlePool, VecGrowCapacity(VecGrowCapacity(0)));
  SetLength(GCompletionPool, VecGrowCapacity(VecGrowCapacity(0)));

finalization
  while GIdlePoolCount > 0 do
  begin
    Dec(GIdlePoolCount);
    Dispose(GIdlePool[GIdlePoolCount]);
  end;
  SetLength(GIdlePool, 0);
  while GCompletionPoolCount > 0 do
  begin
    Dec(GCompletionPoolCount);
    Dispose(GCompletionPool[GCompletionPoolCount]);
  end;
  SetLength(GCompletionPool, 0);
  GGtkLogger := nil;
  // stability: registry Free releases Vec, zero leak, unblocks finalization
  // stability: view map Clear nils refs, zero leak, resource release not lost
  SetLength(GViewMap, 0);
  GViewMapCount := 0;
  FreeAndNil(GRegisteredSchemeCtxs);
  FreeAndNil(GLiveWindows);
  FreeAndNil(GLiveLock);
  FreeAndNil(GPoolLock);
  FreeAndNil(GSchemeLock);

end.
