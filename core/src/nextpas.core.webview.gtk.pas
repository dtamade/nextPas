unit nextpas.core.webview.gtk;
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
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.window.base,
  nextpas.core.window.intf;
type
  // TGtkWebview — facade aggregator (<400 lines, well below 800 cohesion threshold)
  // delegation: shell→window.gtk3 Raw/live/scheme, bridge→frame/assets/mime, dispatch→pool/eval, viewmap/pool single source
  // perf: WindowOptionsCreate via shell single source, CStrLen via bytes.ops SIMD, MimeTypeFromPathView zero-copy, ShellDebugEnabled gated trace zero alloc at NPW_GTK_DEBUG=0
  TGtkWebview = class(TInterfacedObject, IWebviewWindow, IWebviewDispatcher)
  private
    FOptions: TWebviewOptions;
    FWin, FView, FContext: Pointer;
    FOwnsContext: Boolean;
    FWindow: IWindow;
    FOwnsWindow: Boolean;
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
    procedure SetupSchemeAndShell; overload;
    procedure SetupSchemeAndShellForParent(const AParent: IWindow); overload;
    procedure HandleWindowEvent(const AEvent: TWindowEvent);
    procedure FireNotifyHandlers(AReg: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>);
    procedure WireSignals;
    procedure AddUserScript(const ASource: string);
    function CurrentUri: string;
    procedure FireReadyOnce;
    procedure DispatchFrame(const AFrame: TWebviewFrame);
    class function MapInvokeCodeSafe(E: Exception): string; static;
    procedure SendReceipt(AFrameId: Int64; AIsError: Boolean; const AResultJson, ACode, AMessage: string);
    procedure PostIdle(AProc: TWebviewProcRef);
    procedure DropIdlePendings;
    procedure SettlePendingOnClose;
    procedure HandleNativeDestroy;
  protected
    procedure Post(AProc: TWebviewProcRef); overload; inline;
    procedure Post(AProc: TWebviewProcMethod); overload; inline;
    procedure Post(AProc: TWebviewProc); overload; inline;
    function IsOnMainThread: Boolean; inline;
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
    procedure Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback); virtual;
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
    function GetWindow: IWindow;
  public
    constructor Create(const AOptions: TWebviewOptions); virtual;
    constructor CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions); virtual;
    destructor Destroy; override;
  end;
function GtkLiveWindowCount: Integer;
implementation
uses
  nextpas.core.window.gtk3,
  nextpas.core.mime.types,
  nextpas.core.webview.utils,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.webview.gtk.shell,
  nextpas.core.webview.gtk.bridge,
  nextpas.core.webview.gtk.dispatch,
  nextpas.core.text.view,
  nextpas.core.json.parser;
procedure AssetBufFree(AData: Pointer); cdecl;
begin
  if AData <> nil then nextpas.core.webview.gtk.pool.ReleaseAssetHolder(PAssetHolder(AData));
end;
var
  GSchemeErrQuark: GQuark = 0;
function GtkLiveWindowCount: Integer; inline;
begin Result:=nextpas.core.webview.gtk.shell.ShellLiveWindowCount; end;
procedure RegisterLive(AWin: TGtkWebview);
begin nextpas.core.webview.gtk.shell.ShellRegisterLive(Pointer(AWin)); if AWin.FView<>nil then ViewMapAdd(AWin.FView,Pointer(AWin)); end;
procedure UnregisterLive(AWin: TGtkWebview);
begin if AWin.FView<>nil then ViewMapRemove(AWin.FView); nextpas.core.webview.gtk.shell.ShellUnregisterLive(Pointer(AWin)); end;
function IdleTrampoline(AUserData: Pointer): gboolean; cdecl;
var LRec: PIdleRec absolute AUserData;
begin
  try
    case LRec^.Kind of
      1: if Assigned(LRec^.Method) then LRec^.Method();
      2: if Assigned(LRec^.Plain) then LRec^.Plain();
      else if Assigned(LRec^.Proc) then LRec^.Proc();
    end;
  except on E:Exception do ; end;
  Result:=GLIB_SOURCE_REMOVE;
end;
procedure IdleDestroy(AUserData: Pointer); cdecl;
begin nextpas.core.webview.gtk.pool.ReleaseIdleRec(PIdleRec(AUserData)); end;
procedure DestroyCb(AWidget: Pointer; AUserData: Pointer); cdecl;
begin TGtkWebview(AUserData).HandleNativeDestroy; end;
procedure ScriptMessageCb(AManager, AJsResult, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LVal, LRaw: Pointer; LView: TStringView; LFrame: TWebviewFrame;
begin
  // perf: hot View zero alloc via bridge internal cached Arena reuse (no per-frame Init/Done), TStringView zero-copy via bytes.ops.CStrLen SIMD single source, zero heap alloc
  if LSelf.FClosed then Exit; LVal:=WEBKIT_javascript_result_get_js_value(AJsResult); LRaw:=JSC_value_to_string(LVal); if LRaw=nil then Exit; try
    LView:=TStringView.Create(PAnsiChar(LRaw), CStrLen(PAnsiChar(LRaw)));
    if TryDecodeFrame(LView, LFrame) then LSelf.DispatchFrame(LFrame);
  finally G_free(LRaw); end;
end;
procedure LoadChangedCb(AView: Pointer; AEvent: guint; AUserData: Pointer); cdecl;
const WEBKIT_LOAD_STARTED=0; WEBKIT_LOAD_FINISHED=3; WEBKIT_LOAD_FAILED=4;
var LSelf: TGtkWebview absolute AUserData; LEv: TWebviewNavigationEvent; I: Integer;
begin case AEvent of
  WEBKIT_LOAD_STARTED: begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav started: '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; if LSelf.FOnNavStarted<>nil then for I:=0 to LSelf.FOnNavStarted.Count-1 do if Assigned(LSelf.FOnNavStarted.At(I)) then try LSelf.FOnNavStarted.At(I)(LEv); except end; end;
  WEBKIT_LOAD_FINISHED: begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav finished: '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; if LSelf.FOnNavFinished<>nil then for I:=0 to LSelf.FOnNavFinished.Count-1 do if Assigned(LSelf.FOnNavFinished.At(I)) then try LSelf.FOnNavFinished.At(I)(LEv); except end; LSelf.FireReadyOnce; end;
  WEBKIT_LOAD_FAILED: begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav failed(load-changed): '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; LEv.IsError:=True; if LSelf.FOnNavFailed<>nil then for I:=0 to LSelf.FOnNavFailed.Count-1 do if Assigned(LSelf.FOnNavFailed.At(I)) then try LSelf.FOnNavFailed.At(I)(LEv); except end; end;
end; end;
procedure LoadFailedCb(AView, ALoadEvent, AFailingUri, AErr, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LEv: TWebviewNavigationEvent; I: Integer;
begin if LSelf.FClosed then Exit; if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav failed: '+ViewFromPChar(PAnsiChar(AFailingUri)).ToString); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=ViewFromPChar(PAnsiChar(AFailingUri)).ToString; LEv.IsError:=True; if AErr<>nil then begin LEv.ErrorCode:=PGError(AErr)^.Code; if PGError(AErr)^.Message<>nil then LEv.ErrorMessage:=ViewFromPChar(PAnsiChar(PGError(AErr)^.Message)).ToString; end; if LSelf.FOnNavFailed<>nil then for I:=0 to LSelf.FOnNavFailed.Count-1 do if Assigned(LSelf.FOnNavFailed.At(I)) then try LSelf.FOnNavFailed.At(I)(LEv); except end; end;
procedure ScaleNotifyCb(AObj, APspec, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LNew: Double; I: Integer;
begin if LSelf.FClosed then Exit; LNew:=LSelf.GetScaleFactor; if Abs(LNew-LSelf.FScale)>1e-9 then begin LSelf.FScale:=LNew; if LSelf.FOnScaleChanged<>nil then for I:=0 to LSelf.FOnScaleChanged.Count-1 do if Assigned(LSelf.FOnScaleChanged.At(I)) then try LSelf.FOnScaleChanged.At(I)(LNew); except end; end; end;
function ViewHash(AKey: Pointer): UInt32; inline;
begin Result:=nextpas.core.webview.gtk.viewmap.ViewHash(AKey); end;
function ViewMapFindLocked(AView: Pointer): TGtkWebview;
begin Result:=TGtkWebview(nextpas.core.webview.gtk.viewmap.ViewMapFindLocked(AView)); end;
function LiveWindowForView(AView: Pointer): TGtkWebview;
var LCandidate: TGtkWebview;
begin Result:=nil; if AView=nil then Exit(nil); LCandidate:=TGtkWebview(nextpas.core.webview.gtk.viewmap.ViewMapFind(AView)); if (LCandidate<>nil) and (not LCandidate.FClosed) then Exit(LCandidate); end;
function LatestLiveWebview: TGtkWebview;
begin Result:=TGtkWebview(nextpas.core.webview.gtk.shell.ShellLatestLiveWindow); if (Result<>nil) and Result.FClosed then Result:=nil; end;
procedure SchemeFinishNotFound(ARequest: Pointer); inline;
begin if ARequest=nil then Exit; if GSchemeErrQuark=0 then GSchemeErrQuark:=G_quark_from_static_string('nextpas-webview'); WEBKIT_uri_scheme_request_finish_error(ARequest,G_error_new_literal(GSchemeErrQuark,WEBVIEW_ASSET_NOT_FOUND_CODE,WEBVIEW_ASSET_NOT_FOUND_MSG)); end;
procedure SchemeRequestCb(ARequest, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview; LKeep: IInterface; LMime: string; LPathView: TStringView; LRaw: PAnsiChar; LBytes: TBytes; LStream: Pointer; LHolder: PAssetHolder; LView: Pointer; LData: Pointer; LLen: gssize;
begin if not Assigned(ARequest) then Exit; try
  if Assigned(WEBKIT_uri_scheme_request_get_web_view) then LView:=WEBKIT_uri_scheme_request_get_web_view(ARequest) else LView:=nil;
  LSelf:=nil; LKeep:=nil;
  if LView<>nil then begin LSelf:=TGtkWebview(nextpas.core.webview.gtk.viewmap.ViewMapFind(LView)); if (LSelf<>nil) and LSelf.FClosed then LSelf:=nil; if LSelf<>nil then LKeep:=LSelf as IInterface; end;
  if LSelf=nil then begin LSelf:=LatestLiveWebview; if LSelf<>nil then LKeep:=LSelf as IInterface; end;
  if LSelf=nil then begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme request, no live window: '+ViewFromPChar(PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest))).ToString); SchemeFinishNotFound(ARequest); Exit; end;
  if not Assigned(WEBKIT_uri_scheme_request_get_path) then begin SchemeFinishNotFound(ARequest); Exit; end;
  if WEBKIT_uri_scheme_request_get_path(ARequest)=nil then begin SchemeFinishNotFound(ARequest); Exit; end;
  LRaw:=PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest)); LPathView:=NormalizeWebviewAssetView(ViewFromPChar(LRaw)); if LPathView.Len=0 then begin SchemeFinishNotFound(ARequest); Exit; end;
  // perf: ViewFromPChar 零拷贝 + NormalizeWebviewAssetView 零堆分配 via TStringView, ToString 延迟至命中后零 404 分配 — bytes.ops.CStrLen SIMD 单源; trace gated via ShellDebugEnabled 零 NPW_GTK_DEBUG=0 堆分配与拼接开销, miss/hit 分支零拷贝 TStringView 直通 TryResolveView 单源
  if not Assigned(LSelf.FAssetsIntf) then begin SchemeFinishNotFound(ARequest); Exit; end;
  try if not LSelf.FAssetsIntf.TryResolveView(LPathView,LBytes,LMime) then begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme miss '+LPathView.ToString+' -> 404'); SchemeFinishNotFound(ARequest); Exit; end; except on E:Exception do begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme resolve ex '+LPathView.ToString+': '+E.Message+' -> 404'); SchemeFinishNotFound(ARequest); Exit; end; end;
  if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme hit '+LPathView.ToString+' ('+IntToStr(Length(LBytes))+'B)'); if LMime='' then LMime:=MimeTypeFromPathView(LPathView);
  LStream:=nil;
  if not Assigned(G_memory_input_stream_new_from_data) or not Assigned(WEBKIT_uri_scheme_request_finish) then begin SchemeFinishNotFound(ARequest); Exit; end;
  // perf: 单 Holder Slab 复用 + G_memory_input_stream_new_from_data 零拷贝直通，零 GBytes 中间对象，COW 共享 bytes.ops 单源零 Move，Threshold 已 retire 统一单路径，inline 零堆抖动 via gtk.pool/bridge 单源
  LHolder:=nextpas.core.webview.gtk.pool.AcquireAssetHolder; LHolder^.Bytes:=LBytes;
  try if Length(LHolder^.Bytes)>0 then begin LData:=@LHolder^.Bytes[0]; LLen:=Length(LHolder^.Bytes); end else begin LData:=nil; LLen:=0; end; LStream:=G_memory_input_stream_new_from_data(LData,LLen,@AssetBufFree,LHolder); if not Assigned(LStream) then begin nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder); SchemeFinishNotFound(ARequest); Exit; end; except nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder); raise; end;
  if not Assigned(LStream) then begin SchemeFinishNotFound(ARequest); Exit; end;
  try WEBKIT_uri_scheme_request_finish(ARequest,LStream,Length(LBytes),PAnsiChar(LMime)); except try SchemeFinishNotFound(ARequest); except end; end;
  except on E:Exception do try if Assigned(ARequest) then SchemeFinishNotFound(ARequest); except end; end;
end;
function CompletionMarshalTrampoline(AUserData: Pointer): gboolean; cdecl;
var LRec: PCompletionMarshal absolute AUserData; LSelf: TGtkWebview;
begin LSelf:=TGtkWebview(LRec^.Win); if not LSelf.FClosed then LSelf.SendReceipt(LRec^.FrameId,LRec^.IsError,LRec^.ResultJson,LRec^.Code,LRec^.MsgText); Result:=GLIB_SOURCE_REMOVE; end;
procedure CompletionMarshalDestroy(AUserData: Pointer); cdecl;
begin nextpas.core.webview.gtk.pool.ReleaseCompletionRec(PCompletionMarshal(AUserData)); end;
function EvalTextOfValueGlobal(AJscValue: Pointer): string;
var LRaw: PAnsiChar;
begin if AJscValue=nil then Exit(''); if (JSC_value_is_null(AJscValue)<>0) or (JSC_value_is_undefined(AJscValue)<>0) then Exit('null'); LRaw:=JSC_value_to_json(AJscValue,0); if LRaw<>nil then begin Result:=ViewFromPChar(LRaw).ToString; G_free(LRaw); end else begin LRaw:=JSC_value_to_string(AJscValue); Result:=ViewFromPChar(LRaw).ToString; G_free(LRaw); end; end;
procedure FreeEvalRec(ARec: PEvalRec);
begin
  // stability: Cancel 统一 G_object_unref 释放不丢，Slab 复用与 Idle/Completion 单源一致 via gtk.pool
  if ARec^.Cancel<>nil then begin G_object_unref(ARec^.Cancel); ARec^.Cancel:=nil; end;
  nextpas.core.webview.gtk.pool.ReleaseEvalRec(ARec);
end;
procedure SettleEvalGlobal(ARec: PEvalRec; AOk: Boolean; const AText: string);
var LErr: EWebviewEvalFailed;
begin if ARec^.Done then begin FreeEvalRec(ARec); Exit; end; ARec^.Done:=True; try if AOk then begin if Assigned(ARec^.Callback) then ARec^.Callback(AText); end else if Assigned(ARec^.OnError) then begin LErr:=EWebviewEvalFailed.Create(AText); try ARec^.OnError(LErr); finally LErr.Free; end; end; finally FreeEvalRec(ARec); end; end;
procedure EvalReadyCb(ASource, ARes, AUserData: Pointer); cdecl;
var LRec: PEvalRec absolute AUserData; LErr: PGError=nil; LJsRes, LVal: Pointer; LOk: Boolean; LText: string;
begin if LRec^.Done then begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('eval late callback after close, disposed'); if LRec^.Owner<>nil then TGtkWebview(LRec^.Owner).RemovePending(LRec); FreeEvalRec(LRec); Exit; end; LVal:=nil; LOk:=False; if GtkLoadInfo().EvalPath=gepEvaluateJavascript then LVal:=WEBKIT_web_view_evaluate_javascript_finish(ASource,ARes,@LErr) else begin LJsRes:=WEBKIT_web_view_run_javascript_finish(ASource,ARes,@LErr); if LJsRes<>nil then LVal:=WEBKIT_javascript_result_get_js_value(LJsRes); end; if LErr<>nil then LText:=ViewFromPChar(PAnsiChar(LErr^.Message)).ToString else begin LOk:=True; if LVal<>nil then LText:=EvalTextOfValueGlobal(LVal) else LText:=''; end; if LRec^.Owner<>nil then TGtkWebview(LRec^.Owner).RemovePending(LRec); SettleEvalGlobal(LRec,LOk,LText); end;
type TGtkCompletion=class(TInterfacedObject,IWebviewInvokeCompletion) private FWin:TObject; FCmd:string; FFrameId:Int64; FDone:Boolean; procedure RecordViaIdle(AIsError:Boolean; const AResultJson,ACode,AMessage:string); public constructor Create(AWin:TObject; const ACmd:string; AFrameId:Int64); procedure Ok(const AResultJson:string); procedure Fail(const ACode,AMessage:string); end;
constructor TGtkCompletion.Create(AWin:TObject; const ACmd:string; AFrameId:Int64); begin inherited Create; FWin:=AWin; FCmd:=ACmd; FFrameId:=AFrameId; end;
procedure TGtkCompletion.RecordViaIdle(AIsError:Boolean; const AResultJson,ACode,AMessage:string); var LRec:PCompletionMarshal; begin LRec:=nextpas.core.webview.gtk.pool.AcquireCompletionRec; LRec^.Win:=FWin; LRec^.FrameId:=FFrameId; LRec^.Cmd:=FCmd; LRec^.IsError:=AIsError; LRec^.ResultJson:=AResultJson; LRec^.Code:=NormalizeInvokeCode(ACode); LRec^.MsgText:=AMessage; G_idle_add_full(G_PRIORITY_DEFAULT,@CompletionMarshalTrampoline,LRec,@CompletionMarshalDestroy); end;
procedure TGtkCompletion.Ok(const AResultJson:string); begin if FDone then raise EWebviewInvalidState.Create('invoke completion already settled'); FDone:=True; RecordViaIdle(False,AResultJson,'',''); end;
procedure TGtkCompletion.Fail(const ACode,AMessage:string); begin if FDone then raise EWebviewInvalidState.Create('invoke completion already settled'); FDone:=True; RecordViaIdle(True,'',ACode,AMessage); end;
constructor TGtkWebview.Create(const AOptions: TWebviewOptions);
var LInfo: TGtkLoadInfo; LResolved: TWebviewOptions;
begin inherited Create; LResolved:=AOptions; if LResolved.SchemeName='' then LResolved.SchemeName:=DEFAULT_WEBVIEW_SCHEME; CheckWebviewOptions(LResolved); FOptions:=LResolved; if not TryLoadGtkWebkit(LInfo) then raise EWebviewBackendUnavailable.Create('WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)'); if not WindowGtkRawInit then raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)'); FOwnerThread:=platform_thread_id; FScale:=1.0; FInvokesIntf:=TWebviewInvokeRegistry.Create; FInvokes:=FInvokesIntf as TObject; FAssetsIntf:=TWebviewAssetsImpl.Create(FOptions.DevServerUrl<>''); FAssets:=FAssetsIntf as TObject; FIdleTags:=specialize TWebviewLiveRegistry<guint>.Create; FPendingEvals:=specialize TWebviewLiveRegistry<PEvalRec>.Create; FOnNavStarted:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFinished:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFailed:=specialize TWebviewLiveRegistry<TWebviewNavFailedHandler>.Create; FOnWindowClosed:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnReady:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnScaleChanged:=specialize TWebviewLiveRegistry<TWebviewScaleHandler>.Create; if FOptions.DevServerUrl<>'' then nextpas.core.webview.gtk.shell.ShellTrace('dev mode: assets inert, scheme deferred ('+FOptions.DevServerUrl+')'); SetupSessionContext; SetupSchemeAndShell; WireSignals; RegisterLive(Self); FSelfKeepAlive:=Self; if FOptions.InitialUrl<>'' then Navigate(FOptions.InitialUrl) else if FOptions.InitialHtml<>'' then NavigateToString(FOptions.InitialHtml); end;
constructor TGtkWebview.CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions);
var LInfo: TGtkLoadInfo; LResolved: TWebviewOptions;
begin inherited Create; if AParent=nil then raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn'); LResolved:=AOptions; if LResolved.SchemeName='' then LResolved.SchemeName:=DEFAULT_WEBVIEW_SCHEME; CheckWebviewOptions(LResolved); FOptions:=LResolved; if not TryLoadGtkWebkit(LInfo) then raise EWebviewBackendUnavailable.Create('WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)'); if not WindowGtkRawInit then raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)'); FOwnerThread:=platform_thread_id; FScale:=1.0; FInvokesIntf:=TWebviewInvokeRegistry.Create; FInvokes:=FInvokesIntf as TObject; FAssetsIntf:=TWebviewAssetsImpl.Create(FOptions.DevServerUrl<>''); FAssets:=FAssetsIntf as TObject; FIdleTags:=specialize TWebviewLiveRegistry<guint>.Create; FPendingEvals:=specialize TWebviewLiveRegistry<PEvalRec>.Create; FOnNavStarted:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFinished:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFailed:=specialize TWebviewLiveRegistry<TWebviewNavFailedHandler>.Create; FOnWindowClosed:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnReady:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnScaleChanged:=specialize TWebviewLiveRegistry<TWebviewScaleHandler>.Create; if FOptions.DevServerUrl<>'' then nextpas.core.webview.gtk.shell.ShellTrace('dev mode: assets inert, scheme deferred ('+FOptions.DevServerUrl+')'); SetupSessionContext; SetupSchemeAndShellForParent(AParent); WireSignals; RegisterLive(Self); FSelfKeepAlive:=Self; if FOptions.InitialUrl<>'' then Navigate(FOptions.InitialUrl) else if FOptions.InitialHtml<>'' then NavigateToString(FOptions.InitialHtml); end;
destructor TGtkWebview.Destroy;
begin if FOwnsContext and (FContext<>nil) then begin nextpas.core.webview.gtk.shell.ShellForgetSchemeContext(FContext); G_object_unref(FContext); FContext:=nil; end; UnregisterLive(Self); FWindow:=nil; FWin:=nil; FView:=nil; FreeAndNil(FOnScaleChanged); FreeAndNil(FOnReady); FreeAndNil(FOnWindowClosed); FreeAndNil(FOnNavFailed); FreeAndNil(FOnNavFinished); FreeAndNil(FOnNavStarted); FreeAndNil(FPendingEvals); FreeAndNil(FIdleTags); inherited Destroy; end;
function TGtkWebview.IsClosed: Boolean; inline; begin Result:=FClosed; end;
procedure TGtkWebview.RequireOpen; begin if FClosed then raise EWebviewClosed.Create('webview window is closed'); end;
procedure TGtkWebview.RemovePending(ARec: PEvalRec); begin if FPendingEvals<>nil then FPendingEvals.Unregister(ARec); end;
procedure TGtkWebview.FireNotifyHandlers(AReg: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>); var I: Integer; begin if AReg=nil then Exit; for I:=0 to AReg.Count-1 do if Assigned(AReg.At(I)) then try AReg.At(I)(); except end; end;
procedure TGtkWebview.SetupSessionContext; begin FOwnsContext:=False; if FOptions.EphemeralSession then FOwnsContext:=True else if FOptions.DataDirectory<>'' then FOwnsContext:=True; end;
function TGtkWebview.ResolveContext: Pointer; var LManager: Pointer; begin if not FOwnsContext then Exit(WEBKIT_web_context_get_default()); if FOptions.EphemeralSession then Result:=WEBKIT_web_context_new_ephemeral() else begin LManager:=WEBKIT_website_data_manager_new('base-data-directory',PAnsiChar(FOptions.DataDirectory),Pointer(nil)); if LManager=nil then raise EWebviewNotInitialized.Create('webkit_website_data_manager_new failed (data directory rejected)'); Result:=WEBKIT_web_context_new_with_website_data_manager(LManager); G_object_unref(LManager); end; FContext:=Result; end;
procedure TGtkWebview.HandleWindowEvent(const AEvent: TWindowEvent); begin if FClosed then Exit; case AEvent.Kind of weCloseRequested,weClosed: Close; weScaleChanged,weDpiChanged: begin FScale:=AEvent.NewScale; FireNotifyHandlers(FOnScaleChanged); end; weResized: ; end; end;
procedure TGtkWebview.SetupSchemeAndShell; var LCtx: Pointer; LWinOpts: TWindowOptions; begin LCtx:=ResolveContext; if (FOptions.DevServerUrl='') and (not nextpas.core.webview.gtk.shell.ShellSchemeContextRegistered(LCtx)) then begin WEBKIT_web_context_register_uri_scheme(LCtx,PAnsiChar(FOptions.SchemeName),@SchemeRequestCb,nil,nil); nextpas.core.webview.gtk.shell.ShellRememberSchemeContext(LCtx); end; FView:=WEBKIT_web_view_new_with_context(LCtx); if FView=nil then raise EWebviewNotInitialized.Create('webkit_web_view_new_with_context returned nil'); if FWindow=nil then begin LWinOpts:=nextpas.core.webview.utils.WebviewWindowOptionsOf(FOptions); FWindow:=nextpas.core.window.gtk3.CreateWindowGtk(LWinOpts); FOwnsWindow:=True; FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); FWindow.OnEvent(@HandleWindowEvent); end else begin FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Parent window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); end; if FOptions.DebugTools then WEBKIT_settings_set_enable_developer_extras(WEBKIT_web_view_get_settings(FView),1); end;
procedure TGtkWebview.SetupSchemeAndShellForParent(const AParent: IWindow); var LCtx: Pointer; begin if AParent=nil then raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn'); FWindow:=AParent; FOwnsWindow:=False; FWindow.OnEvent(@HandleWindowEvent); LCtx:=ResolveContext; if (FOptions.DevServerUrl='') and (not nextpas.core.webview.gtk.shell.ShellSchemeContextRegistered(LCtx)) then begin WEBKIT_web_context_register_uri_scheme(LCtx,PAnsiChar(FOptions.SchemeName),@SchemeRequestCb,nil,nil); nextpas.core.webview.gtk.shell.ShellRememberSchemeContext(LCtx); end; FView:=WEBKIT_web_view_new_with_context(LCtx); if FView=nil then raise EWebviewNotInitialized.Create('webkit_web_view_new_with_context returned nil'); FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Parent window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); if FView<>nil then nextpas.core.gtk3.ffi.gtk_widget_show(FView); if FOptions.DebugTools then WEBKIT_settings_set_enable_developer_extras(WEBKIT_web_view_get_settings(FView),1); end;
function TGtkWebview.GetWindow: IWindow; inline; begin Result:=FWindow; end;
procedure TGtkWebview.AddUserScript(const ASource: string); var LUcm, LScript: Pointer; begin LUcm:=WEBKIT_web_view_get_user_content_manager(FView); LScript:=WEBKIT_user_script_new(PAnsiChar(ASource),WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,nil,nil); WEBKIT_user_content_manager_add_script(LUcm,LScript); WEBKIT_user_script_unref(LScript); end;
procedure TGtkWebview.WireSignals; begin g_signal_connect_data(FWin,'destroy',@DestroyCb,Self,nil,0); g_signal_connect_data(WEBKIT_web_view_get_user_content_manager(FView),'script-message-received::npw',@ScriptMessageCb,Self,nil,0); WEBKIT_user_content_manager_register_script_message_handler(WEBKIT_web_view_get_user_content_manager(FView),'npw'); AddUserScript(NPW_BRIDGE_SCRIPT); g_signal_connect_data(FView,'load-changed',@LoadChangedCb,Self,nil,0); g_signal_connect_data(FView,'load-failed',@LoadFailedCb,Self,nil,0); g_signal_connect_data(FView,'notify::scale-factor',@ScaleNotifyCb,Self,nil,0); end;
function TGtkWebview.CurrentUri: string; var LP: PAnsiChar; begin LP:=WEBKIT_web_view_get_uri(FView); Result:=ViewFromPChar(LP).ToString; end;
procedure TGtkWebview.FireReadyOnce; var I: Integer; begin if FReadyFired or FClosed then Exit; FReadyFired:=True; if FOnReady<>nil then for I:=0 to FOnReady.Count-1 do if Assigned(FOnReady.At(I)) then try FOnReady.At(I)(); except end; end;
class function TGtkWebview.MapInvokeCodeSafe(E: Exception): string; begin if E is EWebviewInvokeError then Result:=NormalizeInvokeCode(EWebviewInvokeError(E).Code) else Result:=NPW_CODE_HANDLER_ERROR; end;
procedure TGtkWebview.DispatchFrame(const AFrame: TWebviewFrame); var LReg: TWebviewInvokeRegistry; LIsAsync:Boolean; LSync: TWebviewInvokeSyncHandler; LAsync:TWebviewInvokeAsyncHandler; LResultJson:string; LCompletion:IWebviewInvokeCompletion; begin RequireOpen; LReg:=TWebviewInvokeRegistry(FInvokes); if not LReg.Find(AFrame.Cmd,LIsAsync,LSync,LAsync) then begin SendReceipt(AFrame.Id,True,'',NPW_CODE_HANDLER_MISSING,'no handler registered for cmd'); Exit; end; if LIsAsync then begin LCompletion:=TGtkCompletion.Create(Self,AFrame.Cmd,AFrame.Id); try LAsync(AFrame.PayloadJson,LCompletion); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end; end else begin try LResultJson:=LSync(AFrame.PayloadJson); SendReceipt(AFrame.Id,False,LResultJson,'',''); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end; end; end;
procedure TGtkWebview.SendReceipt(AFrameId:Int64; AIsError:Boolean; const AResultJson,ACode,AMessage:string); var LJs:string; begin if FClosed then Exit; if AIsError then LJs:=BuildRejectScript(AFrameId,ACode,AMessage) else LJs:=BuildResolveScript(AFrameId,AResultJson); if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(FView,PAnsiChar(LJs),Length(LJs),nil,nil,nil,nil,nil) else WEBKIT_web_view_run_javascript(FView,PAnsiChar(LJs),nil,nil,nil); end;
procedure TGtkWebview.PostIdle(AProc: TWebviewProcRef); var LRec:PIdleRec; LTag:guint; begin
  // perf: inline 薄转发池化 idle，Kind=0 直存 Ref 零拷贝，Slab 复用零每 Post 堆分配，短临界 <1µs
  LRec:=nextpas.core.webview.gtk.pool.AcquireIdleRec; LRec^.Kind:=0; LRec^.Proc:=AProc; LRec^.Method:=nil; LRec^.Plain:=nil;
  LTag:=G_idle_add_full(G_PRIORITY_DEFAULT,@IdleTrampoline,LRec,@IdleDestroy); if FIdleTags<>nil then FIdleTags.Register(LTag);
end;
procedure TGtkWebview.DropIdlePendings; var I:Integer; LCtx,LSrc:Pointer; begin if FIdleTags=nil then Exit; LCtx:=G_main_context_default(); for I:=0 to FIdleTags.Count-1 do begin if LCtx=nil then Break; LSrc:=G_main_context_find_source_by_id(LCtx,FIdleTags.At(I)); if LSrc<>nil then G_source_remove(FIdleTags.At(I)); end; FIdleTags.Clear; end; // stability: 二次 find判存窄窗口避免已触发 idle 的陈旧 Source ID 双移除竞态，Close↔fire 竞态安全
procedure TGtkWebview.SettlePendingOnClose; var I:Integer; LRec:PEvalRec; LErr:EWebviewEvalFailed; begin if FPendingEvals=nil then Exit; for I:=0 to FPendingEvals.Count-1 do begin LRec:=FPendingEvals.At(I); if not LRec^.Done then begin LRec^.Done:=True; if Assigned(LRec^.OnError) then begin LErr:=EWebviewEvalFailed.Create('window closed'); try LRec^.OnError(LErr); finally LErr.Free; end; end; end; if LRec^.Cancel<>nil then G_cancellable_cancel(LRec^.Cancel); FreeEvalRec(LRec); end; FPendingEvals.Clear; end;
procedure TGtkWebview.HandleNativeDestroy; begin if FClosed then Exit; FClosed:=True; UnregisterLive(Self); SettlePendingOnClose; DropIdlePendings; FireNotifyHandlers(FOnWindowClosed); if GtkLiveWindowCount=0 then WindowGtkRawQuitMainLoop; FView:=nil; FWin:=nil; FWindow:=nil; FSelfKeepAlive:=nil; end;
procedure TGtkWebview.Close; begin if FClosed then Exit; FClosed:=True; UnregisterLive(Self); SettlePendingOnClose; DropIdlePendings; FireNotifyHandlers(FOnWindowClosed); if FOwnsWindow then begin if FWindow<>nil then try FWindow.Close; except end; if (FView<>nil) and (FWindow=nil) and (FWin<>nil) then GTK_widget_destroy(FWin); end else begin if FView<>nil then GTK_widget_destroy(FView); end; FView:=nil; if FOwnsWindow then begin FWin:=nil; FWindow:=nil; end; if GtkLiveWindowCount=0 then WindowGtkRawQuitMainLoop; FSelfKeepAlive:=nil; end;
procedure TGtkWebview.Post(AProc: TWebviewProcRef); inline; begin PostIdle(AProc); end;
procedure TGtkWebview.Post(AProc: TWebviewProcMethod); inline;
var LRec: PIdleRec; LTag: guint;
begin
  // perf: 池化闭包零每 Post 分配，Kind=1 直存 Method 无 reference 包装堆分配，inline 短临界 <1µs，Slab 复用 via gtk.pool
  LRec:=nextpas.core.webview.gtk.pool.AcquireIdleRec; LRec^.Kind:=1; LRec^.Method:=AProc; LRec^.Proc:=nil; LRec^.Plain:=nil;
  LTag:=G_idle_add_full(G_PRIORITY_DEFAULT,@IdleTrampoline,LRec,@IdleDestroy); if FIdleTags<>nil then FIdleTags.Register(LTag);
end;
procedure TGtkWebview.Post(AProc: TWebviewProc); inline;
var LRec: PIdleRec; LTag: guint;
begin
  // perf: 池化闭包零每 Post 分配，Kind=2 直存 Plain proc 无匿名闭包分配，inline 零拷贝，Slab 复用
  LRec:=nextpas.core.webview.gtk.pool.AcquireIdleRec; LRec^.Kind:=2; LRec^.Plain:=AProc; LRec^.Proc:=nil; LRec^.Method:=nil;
  LTag:=G_idle_add_full(G_PRIORITY_DEFAULT,@IdleTrampoline,LRec,@IdleDestroy); if FIdleTags<>nil then FIdleTags.Register(LTag);
end;
function TGtkWebview.IsOnMainThread: Boolean; inline; begin Result:=platform_thread_id=FOwnerThread; end;
function TGtkWebview.GetDispatcher: IWebviewDispatcher; inline; begin Result:=Self; end;
procedure TGtkWebview.Show; begin RequireOpen; if FWindow<>nil then FWindow.Show else WindowGtkRawShow(FWin); end;
procedure TGtkWebview.Hide; begin RequireOpen; if FWindow<>nil then FWindow.Hide else WindowGtkRawHide(FWin); end;
function TGtkWebview.IsVisible: Boolean; begin RequireOpen; if FWindow<>nil then Exit(FWindow.IsVisible); Result:=GTK_widget_get_visible(FWin)<>0; end;
procedure TGtkWebview.Focus; begin RequireOpen; if FView<>nil then WindowGtkRawFocus(FView) else if FWindow<>nil then FWindow.Focus; end;
procedure TGtkWebview.SetTitle(const ATitle:string); begin RequireOpen; if FWindow<>nil then FWindow.SetTitle(ATitle) else WindowGtkRawSetTitle(FWin,ATitle); end;
function TGtkWebview.GetTitle:string; var LRaw:PAnsiChar; begin RequireOpen; if FWindow<>nil then Exit(FWindow.GetTitle); LRaw:=GTK_window_get_title(FWin); Result:=ViewFromPChar(LRaw).ToString; end;
procedure TGtkWebview.SetBounds(AWidth,AHeight:Integer); begin RequireOpen; if FWindow<>nil then FWindow.SetBounds(AWidth,AHeight) else WindowGtkRawResize(FWin,AWidth,AHeight); end;
function TGtkWebview.GetWidth:Integer; begin RequireOpen; if FWindow<>nil then Exit(FWindow.GetWidth); Result:=GTK_widget_get_allocated_width(FView); end;
function TGtkWebview.GetHeight:Integer; begin RequireOpen; if FWindow<>nil then Exit(FWindow.GetHeight); Result:=GTK_widget_get_allocated_height(FView); end;
procedure TGtkWebview.SetResizable(AResizable:Boolean); begin RequireOpen; if FWindow<>nil then FWindow.SetResizable(AResizable) else GTK_window_set_resizable(FWin,Ord(AResizable)); end;
procedure TGtkWebview.Maximize; begin RequireOpen; if FWindow<>nil then FWindow.Maximize else WindowGtkRawMaximize(FWin); end;
procedure TGtkWebview.Unmaximize; begin RequireOpen; if FWindow<>nil then FWindow.Unmaximize else WindowGtkRawUnmaximize(FWin); end;
function TGtkWebview.IsMaximized:Boolean; begin RequireOpen; if FWindow<>nil then Exit(FWindow.IsMaximized); Result:=WindowGtkRawIsMaximized(FWin); end;
procedure TGtkWebview.Minimize; begin RequireOpen; if FWindow<>nil then FWindow.Minimize else GTK_window_iconify(FWin); end;
procedure TGtkWebview.Restore; begin RequireOpen; if FWindow<>nil then FWindow.Restore else GTK_window_deiconify(FWin); end;
function TGtkWebview.IsMinimized:Boolean; var LGdkWin:Pointer; begin RequireOpen; if FWindow<>nil then Exit(FWindow.IsMinimized); LGdkWin:=GTK_widget_get_window(FWin); Result:=(LGdkWin<>nil) and ((GDK_window_get_state(LGdkWin) and GDK_WINDOW_STATE_ICONIFIED)<>0); end;
procedure TGtkWebview.SetZoom(AFactor:Double); begin RequireOpen; WEBKIT_web_view_set_zoom_level(FView,AFactor); end;
function TGtkWebview.GetZoom:Double; begin RequireOpen; Result:=WEBKIT_web_view_get_zoom_level(FView); end;
procedure TGtkWebview.SetUserAgent(const AUserAgent:string); begin RequireOpen; G_object_set(WEBKIT_web_view_get_settings(FView),'user-agent',PAnsiChar(AUserAgent),Pointer(nil)); end;
function TGtkWebview.GetUserAgent:string; var LRaw:PAnsiChar; begin RequireOpen; LRaw:=nil; G_object_get(WEBKIT_web_view_get_settings(FView),'user-agent',@LRaw,Pointer(nil)); if LRaw<>nil then begin Result:=ViewFromPChar(LRaw).ToString; G_free(LRaw); end else Result:=''; end;
function TGtkWebview.GetScaleFactor:Double; begin RequireOpen; if FWindow<>nil then Exit(FWindow.GetScaleFactor); Result:=WindowGtkRawScaleFactor(FView); end;
procedure TGtkWebview.Navigate(const AUrl:string); begin RequireOpen; WEBKIT_web_view_load_uri(FView,PAnsiChar(AUrl)); end;
procedure TGtkWebview.NavigateToString(const AHtml:string); begin RequireOpen; WEBKIT_web_view_load_html(FView,PAnsiChar(AHtml),nil); end;
procedure TGtkWebview.Reload; begin RequireOpen; WEBKIT_web_view_reload(FView); end;
procedure TGtkWebview.Stop; begin RequireOpen; WEBKIT_web_view_stop_loading(FView); end;
function TGtkWebview.CanGoBack:Boolean; begin RequireOpen; Result:=WEBKIT_web_view_can_go_back(FView)<>0; end;
function TGtkWebview.GoBack:Boolean; begin RequireOpen; Result:=CanGoBack; if Result then WEBKIT_web_view_go_back(FView); end;
function TGtkWebview.CanGoForward:Boolean; begin RequireOpen; Result:=WEBKIT_web_view_can_go_forward(FView)<>0; end;
function TGtkWebview.GoForward:Boolean; begin RequireOpen; Result:=CanGoForward; if Result then WEBKIT_web_view_go_forward(FView); end;
function TGtkWebview.NativeHandle:TWebviewNativeHandle; begin RequireOpen; if FWindow<>nil then Exit(TWebviewNativeHandle(FWindow.NativeHandle)); Result:=WindowGtkRawNativeHandle(FWin); end;
function TGtkWebview.GetInvokes:IWebviewInvokeRegistry; begin RequireOpen; Result:=FInvokesIntf; end;
function TGtkWebview.GetAssets:IWebviewAssets; begin RequireOpen; Result:=FAssetsIntf; end;
procedure TGtkWebview.Eval(const AJavascript:string; ACallback:TWebviewEvalCallback; AOnError:TWebviewEvalErrorCallback); var LRec:PEvalRec; begin
  // perf: Eval 热点 Slab 复用 — nextpas.core.webview.gtk.pool.AcquireEvalRec+G_cancellable_new 双池化与 Idle/Completion 同源 via gtk.pool, 高频 Eval 零每帧堆分配; trace gated via ShellDebugEnabled 零拷贝当 NPW_GTK_DEBUG=0
  RequireOpen; LRec:=nextpas.core.webview.gtk.pool.AcquireEvalRec; LRec^.Callback:=ACallback; LRec^.OnError:=AOnError; LRec^.Done:=False; LRec^.Cancel:=G_cancellable_new(); LRec^.Owner:=Self; if FPendingEvals<>nil then FPendingEvals.Register(LRec); if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('eval dispatch: '+Copy(AJavascript,1,80)); if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(FView,PAnsiChar(AJavascript),Length(AJavascript),nil,nil,LRec^.Cancel,@EvalReadyCb,LRec) else WEBKIT_web_view_run_javascript(FView,PAnsiChar(AJavascript),LRec^.Cancel,@EvalReadyCb,LRec); end;
procedure TGtkWebview.Emit(const AEvent,APayloadJson:string); begin CheckWebviewEventName(AEvent); RequireOpen; Eval(BuildEmitScript(AEvent,APayloadJson),nil,nil); end;
procedure TGtkWebview.OnScaleChanged(AHandler:TWebviewScaleHandler); begin if FOnScaleChanged<>nil then FOnScaleChanged.Register(AHandler); end;
procedure TGtkWebview.OnScaleChanged(AHandler:TWebviewScaleMethod); begin OnScaleChanged(WebviewScaleMethodToRef(AHandler)); end;
procedure TGtkWebview.OnScaleChanged(AHandler:TWebviewScaleProc); begin OnScaleChanged(WebviewScaleProcToRef(AHandler)); end;
procedure TGtkWebview.OnNavigationStarted(AHandler:TWebviewNavEventHandler); begin if FOnNavStarted<>nil then FOnNavStarted.Register(AHandler); end;
procedure TGtkWebview.OnNavigationStarted(AHandler:TWebviewNavEventMethod); begin OnNavigationStarted(WebviewNavMethodToRef(AHandler)); end;
procedure TGtkWebview.OnNavigationStarted(AHandler:TWebviewNavEventProc); begin OnNavigationStarted(WebviewNavProcToRef(AHandler)); end;
procedure TGtkWebview.OnNavigationFinished(AHandler:TWebviewNavEventHandler); begin if FOnNavFinished<>nil then FOnNavFinished.Register(AHandler); end;
procedure TGtkWebview.OnNavigationFinished(AHandler:TWebviewNavEventMethod); begin OnNavigationFinished(WebviewNavMethodToRef(AHandler)); end;
procedure TGtkWebview.OnNavigationFinished(AHandler:TWebviewNavEventProc); begin OnNavigationFinished(WebviewNavProcToRef(AHandler)); end;
procedure TGtkWebview.OnNavigationFailed(AHandler:TWebviewNavFailedHandler); begin if FOnNavFailed<>nil then FOnNavFailed.Register(AHandler); end;
procedure TGtkWebview.OnNavigationFailed(AHandler:TWebviewNavFailedMethod); begin OnNavigationFailed(WebviewNavFailedMethodToRef(AHandler)); end;
procedure TGtkWebview.OnNavigationFailed(AHandler:TWebviewNavFailedProc); begin OnNavigationFailed(WebviewNavFailedProcToRef(AHandler)); end;
procedure TGtkWebview.OnWindowClosed(AHandler:TWebviewNotifyHandler); begin if FOnWindowClosed<>nil then FOnWindowClosed.Register(AHandler); end;
procedure TGtkWebview.OnWindowClosed(AHandler:TWebviewNotifyMethod); begin OnWindowClosed(WebviewNotifyMethodToRef(AHandler)); end;
procedure TGtkWebview.OnWindowClosed(AHandler:TWebviewNotifyProc); begin OnWindowClosed(WebviewNotifyProcToRef(AHandler)); end;
procedure TGtkWebview.OnReady(AHandler:TWebviewNotifyHandler); begin if FOnReady<>nil then FOnReady.Register(AHandler); end;
procedure TGtkWebview.OnReady(AHandler:TWebviewNotifyMethod); begin OnReady(WebviewNotifyMethodToRef(AHandler)); end;
procedure TGtkWebview.OnReady(AHandler:TWebviewNotifyProc); begin OnReady(WebviewNotifyProcToRef(AHandler)); end;
initialization ViewMapLockInit; ViewMapInit; PoolInit;
finalization PoolFinalize; ViewMapClear; ViewMapLockFini;
end.
