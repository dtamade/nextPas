unit nextpas.core.webview.gtk;

{** @desc Linux 后端：GTK3 窗口壳（经 gtk.win 内缝）+ WebKitGTK 内容 +
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
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
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
    FIdleTags: array of guint;
    FIdleCount: Integer;
    FPendingEvals: array of PEvalRec;
    FPendingCount: Integer;
    FOnNavStarted: array of TWebviewNavEventHandler;
    FOnNavStartedCount: Integer;
    FOnNavFinished: array of TWebviewNavEventHandler;
    FOnNavFinishedCount: Integer;
    FOnNavFailed: array of TWebviewNavFailedHandler;
    FOnNavFailedCount: Integer;
    FOnWindowClosed: array of TWebviewNotifyHandler;
    FOnWindowClosedCount: Integer;
    FOnReady: array of TWebviewNotifyHandler;
    FOnReadyCount: Integer;
    FOnScaleChanged: array of TWebviewScaleHandler;
    FOnScaleChangedCount: Integer;

    procedure RequireOpen;
    procedure GrowPendingEvals; inline;
    procedure GrowIdleTags; inline;
    procedure GrowOnNavStarted; inline;
    procedure GrowOnNavFinished; inline;
    procedure GrowOnNavFailed; inline;
    procedure GrowOnWindowClosed; inline;
    procedure GrowOnReady; inline;
    procedure GrowOnScaleChanged; inline;
    procedure RemovePending(ARec: PEvalRec);
    procedure SetupSessionContext;
    function ResolveContext: Pointer;
    procedure SetupSchemeAndShell;
    procedure FireNotifyHandlers(var AList: array of TWebviewNotifyHandler);
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
    procedure HandleNativeDestroy;
  protected
    { IWebviewDispatcher —— Self 双身份实现 }
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
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
  nextpas.core.webview.gtk.win;

var
  GLiveWindows: array of TGtkWebview;
  { scheme 按 context 去重：默认 context 是进程级单例，多窗口重复注册
    会被 GLib CRITICAL 拒绝，且后到处理器无法接管——必须首注册独占 }
  GRegisteredSchemeCtxs: array of Pointer;
  GGtkDebugChecked: Boolean = False;
  GGtkDebugEnabled: Boolean = False;

{ 环境门控诊断轨迹（NPW_GTK_DEBUG=1 时写 stderr），默认零开销：
  覆盖 nav/scheme/eval 三条异步轴，用于现场问题定位 }
procedure GtkTrace(const AMsg: string);
begin
  if not GGtkDebugChecked then
  begin
    GGtkDebugChecked := True;
    GGtkDebugEnabled := GetEnvironmentVariable('NPW_GTK_DEBUG') = '1';
  end;
  if GGtkDebugEnabled then
    WriteLn(StdErr, '[npw-gtk] ', AMsg);
end;

function SchemeContextRegistered(ACtx: Pointer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(GRegisteredSchemeCtxs) do
    if GRegisteredSchemeCtxs[I] = ACtx then
      Exit(True);
  Result := False;
end;

procedure RememberSchemeContext(ACtx: Pointer);
begin
  SetLength(GRegisteredSchemeCtxs, Length(GRegisteredSchemeCtxs) + 1);
  GRegisteredSchemeCtxs[High(GRegisteredSchemeCtxs)] := ACtx;
end;

procedure ForgetSchemeContext(ACtx: Pointer);
var
  I, J: Integer;
begin
  for I := 0 to High(GRegisteredSchemeCtxs) do
    if GRegisteredSchemeCtxs[I] = ACtx then
    begin
      for J := I to High(GRegisteredSchemeCtxs) - 1 do
        GRegisteredSchemeCtxs[J] := GRegisteredSchemeCtxs[J + 1];
      SetLength(GRegisteredSchemeCtxs, Length(GRegisteredSchemeCtxs) - 1);
      Exit;
    end;
end;

function GtkLiveWindowCount: Integer;
var
  I, LCnt: Integer;
begin
  LCnt := 0;
  for I := 0 to High(GLiveWindows) do
    if not GLiveWindows[I].FClosed then
      Inc(LCnt);
  Result := LCnt;
end;

procedure RegisterLive(AWin: TGtkWebview);
begin
  SetLength(GLiveWindows, Length(GLiveWindows) + 1);
  GLiveWindows[High(GLiveWindows)] := AWin;
end;

procedure UnregisterLive(AWin: TGtkWebview);
var
  I, J: Integer;
begin
  for I := 0 to High(GLiveWindows) do
    if GLiveWindows[I] = AWin then
    begin
      for J := I to High(GLiveWindows) - 1 do
        GLiveWindows[J] := GLiveWindows[J + 1];
      SetLength(GLiveWindows, Length(GLiveWindows) - 1);
      Exit;
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
  Dispose(PIdleRec(AUserData));
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
    LJson := StrPas(LRaw);
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
        for I := 0 to LSelf.FOnNavStartedCount - 1 do
          LSelf.FOnNavStarted[I](LEv);
      end;
    WEBKIT_LOAD_FINISHED:
      begin
        GtkTrace('nav finished: ' + LSelf.CurrentUri);
        LEv := Default(TWebviewNavigationEvent);
        LEv.Url := LSelf.CurrentUri;
        for I := 0 to LSelf.FOnNavFinishedCount - 1 do
          LSelf.FOnNavFinished[I](LEv);
        LSelf.FireReadyOnce;
      end;
    WEBKIT_LOAD_FAILED:
      begin
        GtkTrace('nav failed(load-changed): ' + LSelf.CurrentUri);
        LEv := Default(TWebviewNavigationEvent);
        LEv.Url := LSelf.CurrentUri;
        LEv.IsError := True;
        for I := 0 to LSelf.FOnNavFailedCount - 1 do
          LSelf.FOnNavFailed[I](LEv);
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
  GtkTrace('nav failed: ' + StrPas(AFailingUri));
  LEv := Default(TWebviewNavigationEvent);
  LEv.Url := StrPas(AFailingUri);
  LEv.IsError := True;
  if AErr <> nil then
  begin
    LEv.ErrorCode := PGError(AErr)^.Code;
    if PGError(AErr)^.Message <> nil then
      LEv.ErrorMessage := StrPas(PGError(AErr)^.Message);
  end;
  for I := 0 to LSelf.FOnNavFailedCount - 1 do
    LSelf.FOnNavFailed[I](LEv);
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
    for I := 0 to LSelf.FOnScaleChangedCount - 1 do
      LSelf.FOnScaleChanged[I](LNew);
  end;
end;

var
  GSchemeErrQuark: GQuark = 0;

{ scheme 请求的 owner 解析（S5）：context 级注册只能绑一个 trampoline，
  但请求可精确归属发起视图——webkit_uri_scheme_request_get_web_view
  对回 GLiveWindows 的 FView 指针即得所属窗口，多窗口资产命名空间
  硬隔离。service worker 等无视图请求回落"最新活跃窗口"。 }
function LiveWindowForView(AView: Pointer): TGtkWebview; inline;
var
  I: Integer;
begin
  if AView <> nil then
  begin
    { 单窗快路径：95% 场景 single-window 零扫描，牺牲 2 次比较换线性遍历 }
    if Length(GLiveWindows) = 1 then
    begin
      if (not GLiveWindows[0].FClosed) and (GLiveWindows[0].FView = AView) then
        Exit(GLiveWindows[0]);
      Exit(nil);
    end;
    for I := 0 to High(GLiveWindows) do
      if (not GLiveWindows[I].FClosed) and
         (GLiveWindows[I].FView = AView) then
        Exit(GLiveWindows[I]);
  end;
  Result := nil;
end;

function LatestLiveWebview: TGtkWebview; inline;
var
  I: Integer;
begin
  for I := High(GLiveWindows) downto 0 do
    if not GLiveWindows[I].FClosed then
      Exit(GLiveWindows[I]);
  Result := nil;
end;

{ finish_error 的 GError 所有权移交 WebKit（源码 adoptGRef 模式），
  调用方不 free；误判会在 live 门禁以 double-free 可见地暴露 }
procedure SchemeFinishNotFound(ARequest: Pointer); inline;
begin
  if GSchemeErrQuark = 0 then
    GSchemeErrQuark := G_quark_from_static_string('nextpas-webview');
  WEBKIT_uri_scheme_request_finish_error(ARequest,
    G_error_new_literal(GSchemeErrQuark, 404, 'resource not found'));
end;

procedure SchemeRequestCb(ARequest, AUserData: Pointer); cdecl;
var
  LSelf: TGtkWebview;
  LPath, LMime: string;
  LBytes: TBytes;
  LBuf, LStream: Pointer;
begin
  LSelf := LiveWindowForView(
    WEBKIT_uri_scheme_request_get_web_view(ARequest));
  if LSelf = nil then
    LSelf := LatestLiveWebview;   { 无视图请求（service worker）回退 }
  if LSelf = nil then
  begin
    GtkTrace('scheme request, no live window: ' +
      StrPas(WEBKIT_uri_scheme_request_get_path(ARequest)));
    SchemeFinishNotFound(ARequest);
    Exit;
  end;
  LPath := NormalizeWebviewAssetPath(StrPas(WEBKIT_uri_scheme_request_get_path(ARequest)));
  if LSelf.FAssetsIntf.TryResolve(LPath, LBytes, LMime) then
  begin
    GtkTrace('scheme hit ' + LPath + ' (' + IntToStr(Length(LBytes)) + 'B)');
    if LMime = '' then
      LMime := 'application/octet-stream';
    { GLib 侧分配（g_malloc）配对 G_free 销毁器——字节所有权随流移交
      WebKit；禁止 GetMem：FPC 堆指针经 C free 释放属跨分配器未定义行为 }
    LBuf := G_malloc(Length(LBytes) + 1);
    if Length(LBytes) > 0 then
      Move(LBytes[0], LBuf^, Length(LBytes));
    LStream := G_memory_input_stream_new_from_data(
      LBuf, Length(LBytes), TGDestroyNotify(@G_free));
    WEBKIT_uri_scheme_request_finish(ARequest, LStream,
      Length(LBytes), PAnsiChar(LMime));
  end
  else
  begin
    GtkTrace('scheme miss ' + LPath + ' -> 404');
    SchemeFinishNotFound(ARequest);
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
  Dispose(PCompletionMarshal(AUserData));
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
    Result := StrPas(LRaw);
    G_free(LRaw);
  end
  else
  begin
    { 不可 JSON 化（如 symbol）：诚实降级为 JS toString 文本 }
    LRaw := JSC_value_to_string(AJscValue);
    Result := StrPas(LRaw);
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
    LText := StrPas(LErr^.Message);
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
    窗口存活由 keep-alive 保证 }
  New(LRec);
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
  if not WinShellInit then
    raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)');

  FOwnerThread := platform_thread_id;
  FScale := 1.0;
  FInvokesIntf := TWebviewInvokeRegistry.Create;
  FInvokes := FInvokesIntf as TObject;
  FAssetsIntf := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FAssets := FAssetsIntf as TObject;
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

procedure TGtkWebview.GrowPendingEvals; inline;
begin
  if FPendingCount = Length(FPendingEvals) then
    SetLength(FPendingEvals, WebviewGrowCapacity(Length(FPendingEvals)));
end;

procedure TGtkWebview.GrowIdleTags; inline;
begin
  if FIdleCount = Length(FIdleTags) then
    SetLength(FIdleTags, WebviewGrowCapacity(Length(FIdleTags)));
end;

procedure TGtkWebview.GrowOnNavStarted; inline;
begin
  if FOnNavStartedCount = Length(FOnNavStarted) then
    SetLength(FOnNavStarted, WebviewGrowCapacity(Length(FOnNavStarted)));
end;

procedure TGtkWebview.GrowOnNavFinished; inline;
begin
  if FOnNavFinishedCount = Length(FOnNavFinished) then
    SetLength(FOnNavFinished, WebviewGrowCapacity(Length(FOnNavFinished)));
end;

procedure TGtkWebview.GrowOnNavFailed; inline;
begin
  if FOnNavFailedCount = Length(FOnNavFailed) then
    SetLength(FOnNavFailed, WebviewGrowCapacity(Length(FOnNavFailed)));
end;

procedure TGtkWebview.GrowOnWindowClosed; inline;
begin
  if FOnWindowClosedCount = Length(FOnWindowClosed) then
    SetLength(FOnWindowClosed, WebviewGrowCapacity(Length(FOnWindowClosed)));
end;

procedure TGtkWebview.GrowOnReady; inline;
begin
  if FOnReadyCount = Length(FOnReady) then
    SetLength(FOnReady, WebviewGrowCapacity(Length(FOnReady)));
end;

procedure TGtkWebview.GrowOnScaleChanged; inline;
begin
  if FOnScaleChangedCount = Length(FOnScaleChanged) then
    SetLength(FOnScaleChanged, WebviewGrowCapacity(Length(FOnScaleChanged)));
end;

procedure TGtkWebview.RemovePending(ARec: PEvalRec);
var
  I, J: Integer;
begin
  for I := 0 to FPendingCount - 1 do
    if FPendingEvals[I] = ARec then
    begin
      for J := I to FPendingCount - 2 do
        FPendingEvals[J] := FPendingEvals[J + 1];
      Dec(FPendingCount);
      if FPendingCount < Length(FPendingEvals) then
        FPendingEvals[FPendingCount] := nil;
      Exit;
    end;
end;

procedure TGtkWebview.FireNotifyHandlers(var AList: array of TWebviewNotifyHandler);
var
  I: Integer;
begin
  for I := 0 to High(AList) do
    AList[I]();
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
  LGeo: TWinShellGeometry;
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

  LGeo.Title := FOptions.Title;
  LGeo.Width := FOptions.Width;
  LGeo.Height := FOptions.Height;
  LGeo.Resizable := FOptions.Resizable;
  LGeo.StartMaximized := FOptions.Maximized;
  FWin := WinShellCreate(LGeo);
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
    Result := StrPas(LP)
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
  for I := 0 to FOnReadyCount - 1 do
    FOnReady[I]();
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
  New(LRec);
  LRec^.Proc := AProc;
  LTag := G_idle_add_full(G_PRIORITY_DEFAULT, @IdleTrampoline, LRec,
    @IdleDestroy);
  GrowIdleTags;
  FIdleTags[FIdleCount] := LTag;
  Inc(FIdleCount);
end;

procedure TGtkWebview.DropIdlePendings;
var
  I: Integer;
  LCtx, LSrc: Pointer;
begin
  { 已触发的 idle 在 fire 时即经 destroy-notify 自毁闭包；此处按
    find-by-id 判存再移除，避免对陈旧 Source ID 二次 remove 触发
    GLib-CRITICAL（Dispatcher.Post 后随即 Close 的路径） }
  LCtx := G_main_context_default();
  for I := 0 to FIdleCount - 1 do
  begin
    if LCtx = nil then
      Break;
    LSrc := G_main_context_find_source_by_id(LCtx, FIdleTags[I]);
    if LSrc <> nil then
      G_source_remove(FIdleTags[I]);
  end;
  FIdleCount := 0;
end;

procedure TGtkWebview.HandleNativeDestroy;
begin
  if FClosed then
    Exit;
  FClosed := True;
  DropIdlePendings;
  FireNotifyHandlers(FOnWindowClosed);
  if GtkLiveWindowCount = 0 then
    WinShellQuitMainLoop;
  FSelfKeepAlive := nil;   { 引用计数归零 → Destroy → UnregisterLive }
end;

procedure TGtkWebview.Close;
var
  I: Integer;
  LRec: PEvalRec;
  LErr: EWebviewEvalFailed;
begin
  { 幂等（CONTRACT §3 intf 承诺，与 fake 一致）；二次 Close 直接返回，
    避免对已销毁 widget 重复 destroy }
  if FClosed then
    Exit;
  FClosed := True;
  { 在途 eval 立即以 onerr 收尾（exactly-one）。记录不在此处释放：
    所有权单点在引擎必然到达的完成回调——迟到回执读 Done 后仅释放。
    异常实例由框架创建/触发/释放（§3.2 所有权语义）。 }
  for I := 0 to FPendingCount - 1 do
  begin
    LRec := FPendingEvals[I];
    if not LRec^.Done then
    begin
      LRec^.Done := True;
      if Assigned(LRec^.OnError) then
      begin
        LErr := EWebviewEvalFailed.Create('webview window is closed');
        try
          LRec^.OnError(LErr);
        finally
          LErr.Free;
        end;
      end;
      { 取消使引擎侧完成回执必达——记录按单点所有权在其内释放，
        进程生命周期内无悬挂分配（heaptrc 0 兑现） }
      if LRec^.Cancel <> nil then
      begin
        G_cancellable_cancel(LRec^.Cancel);
        LRec^.Cancel := nil;
      end;
    end;
  end;
  FPendingCount := 0;
  // 容量保留，待下次 Eval 复用，避免重复分配
  DropIdlePendings;
  FireNotifyHandlers(FOnWindowClosed);
  GTK_widget_destroy(FWin);
  if GtkLiveWindowCount = 0 then
    WinShellQuitMainLoop;
  FSelfKeepAlive := nil;
end;

{ ---- dispatcher 身份 ---- }

procedure TGtkWebview.Post(AProc: TWebviewProcRef);
begin
  PostIdle(AProc);
end;

procedure TGtkWebview.Post(AProc: TWebviewProcMethod);
begin
  PostIdle(
    procedure
    begin
      AProc();
    end);
end;

procedure TGtkWebview.Post(AProc: TWebviewProc);
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

{ ---- IWebviewWindow 表面：薄转发到 win 缝 / webkit ---- }

procedure TGtkWebview.Show;
begin
  RequireOpen;
  WinShellShow(FWin);
end;

procedure TGtkWebview.Hide;
begin
  RequireOpen;
  WinShellHide(FWin);
end;

function TGtkWebview.IsVisible: Boolean;
begin
  RequireOpen;
  Result := GTK_widget_get_visible(FWin) <> 0;
end;

procedure TGtkWebview.Focus;
begin
  RequireOpen;
  WinShellFocus(FView);
end;

procedure TGtkWebview.SetTitle(const ATitle: string);
begin
  RequireOpen;
  WinShellSetTitle(FWin, ATitle);
end;

function TGtkWebview.GetTitle: string;
var
  LRaw: PAnsiChar;
begin
  RequireOpen;
  { WM 级标题同步读：未显式设置过为空串（诚实表，见 BACKENDS §2） }
  LRaw := GTK_window_get_title(FWin);
  if LRaw <> nil then
    Result := StrPas(LRaw)
  else
    Result := '';
end;

procedure TGtkWebview.SetBounds(AWidth, AHeight: Integer);
begin
  RequireOpen;
  WinShellResize(FWin, AWidth, AHeight);
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
  WinShellMaximize(FWin);
end;

procedure TGtkWebview.Unmaximize;
begin
  RequireOpen;
  WinShellUnmaximize(FWin);
end;

function TGtkWebview.IsMaximized: Boolean;
begin
  RequireOpen;
  Result := WinShellIsMaximized(FWin);
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
    Result := StrPas(LRaw);
    G_free(LRaw);
  end
  else
    Result := '';
end;

function TGtkWebview.GetScaleFactor: Double;
begin
  RequireOpen;
  Result := WinShellScaleFactor(FView);
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
  Result := WinShellNativeHandle(FWin);
end;

function TGtkWebview.GetInvokes: IWebviewInvokeRegistry;
begin
  Result := FInvokesIntf;
end;

function TGtkWebview.GetAssets: IWebviewAssets;
begin
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
  GrowPendingEvals;
  FPendingEvals[FPendingCount] := LRec;
  Inc(FPendingCount);
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
  GrowOnScaleChanged;
  FOnScaleChanged[FOnScaleChangedCount] := AHandler;
  Inc(FOnScaleChangedCount);
end;

procedure TGtkWebview.OnScaleChanged(AHandler: TWebviewScaleMethod);
begin
  OnScaleChanged(
    procedure(ANewScale: Double)
    begin
      AHandler(ANewScale);
    end);
end;

procedure TGtkWebview.OnScaleChanged(AHandler: TWebviewScaleProc);
begin
  OnScaleChanged(
    procedure(ANewScale: Double)
    begin
      AHandler(ANewScale);
    end);
end;

procedure TGtkWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  GrowOnNavStarted;
  FOnNavStarted[FOnNavStartedCount] := AHandler;
  Inc(FOnNavStartedCount);
end;

procedure TGtkWebview.OnNavigationStarted(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationStarted(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;

procedure TGtkWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
  OnNavigationStarted(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;

procedure TGtkWebview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
  GrowOnNavFinished;
  FOnNavFinished[FOnNavFinishedCount] := AHandler;
  Inc(FOnNavFinishedCount);
end;

procedure TGtkWebview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;

procedure TGtkWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
  OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;

procedure TGtkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
  GrowOnNavFailed;
  FOnNavFailed[FOnNavFailedCount] := AHandler;
  Inc(FOnNavFailedCount);
end;

procedure TGtkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;

procedure TGtkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;

procedure TGtkWebview.OnWindowClosed(AHandler: TWebviewNotifyHandler);
begin
  GrowOnWindowClosed;
  FOnWindowClosed[FOnWindowClosedCount] := AHandler;
  Inc(FOnWindowClosedCount);
end;

procedure TGtkWebview.OnWindowClosed(AHandler: TWebviewNotifyMethod);
begin
  OnWindowClosed(
    procedure
    begin
      AHandler();
    end);
end;

procedure TGtkWebview.OnWindowClosed(AHandler: TWebviewNotifyProc);
begin
  OnWindowClosed(
    procedure
    begin
      AHandler();
    end);
end;

procedure TGtkWebview.OnReady(AHandler: TWebviewNotifyHandler);
begin
  GrowOnReady;
  FOnReady[FOnReadyCount] := AHandler;
  Inc(FOnReadyCount);
end;

procedure TGtkWebview.OnReady(AHandler: TWebviewNotifyMethod);
begin
  OnReady(
    procedure
    begin
      AHandler();
    end);
end;

procedure TGtkWebview.OnReady(AHandler: TWebviewNotifyProc);
begin
  OnReady(
    procedure
    begin
      AHandler();
    end);
end;

end.
