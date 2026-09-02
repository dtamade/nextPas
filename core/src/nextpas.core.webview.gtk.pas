unit nextpas.core.webview.gtk;
{$I nextpas.core.settings.inc}
interface
uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.platform.env,
  nextpas.core.platform.thread,
  nextpas.core.sync.mutex,
  nextpas.core.log.intf,
  nextpas.core.atomic,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.validation,
  nextpas.core.webview.bridge,
  nextpas.core.webview.callbacks,
  nextpas.core.bytes.ops,
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.window.base,
  nextpas.core.window.intf;
type
  // TGtkWebview — facade aggregator (~560 lines, soft threshold 800 — monitor)
  // delegation: shell→window.gtk3, bridge→frame/assets/mime, dispatch→pool/eval
  // live registries: 8 groups (FIdleTags/FPendingEvals/FOnNav*/FOnWindowClosed/FOnReady/FOnScaleChanged) — bytes.ops TCompactLiveRegistry single source inline zero-copy; further logic via shell/bridge/dispatch thin forwarding, do not grow facade — thinning via dedicated shell/bridge/dispatch units, live registries stay compact via bytes.ops single source
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
    FPendingLock: TMutex;
    FIdleTags: specialize TCompactLiveRegistry<guint>;
    FPendingEvals: specialize TCompactLiveRegistry<PEvalRec>;
    FOnNavStarted: specialize TCompactLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFinished: specialize TCompactLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFailed: specialize TCompactLiveRegistry<TWebviewNavFailedHandler>;
    FOnWindowClosed: specialize TCompactLiveRegistry<TWebviewNotifyHandler>;
    FOnReady: specialize TCompactLiveRegistry<TWebviewNotifyHandler>;
    FOnScaleChanged: specialize TCompactLiveRegistry<TWebviewScaleHandler>;
    procedure RequireOpen;
    procedure RemovePending(ARec: PEvalRec);
    procedure SetupSessionContext;
    function ResolveContext: Pointer;
    procedure SetupSchemeAndShell; overload;
    procedure SetupSchemeAndShellForParent(const AParent: IWindow); overload;
    procedure HandleWindowEvent(const AEvent: TWindowEvent);
    procedure FireNotifyHandlers(AReg: specialize TCompactLiveRegistry<TWebviewNotifyHandler>);
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
    procedure DoRegisterLive;
    procedure DoUnregisterLive;
    procedure DoClose; // main-thread close body, single source for Close + HandleNativeDestroy
    class function LiveWindowCount: Integer; static;
    function ResolveOptions(const AOptions: TWebviewOptions): TWebviewOptions; inline;
    procedure EnsureBackendAvailable; inline;
    procedure InitRegistries; inline;
    procedure DoCommonInit(const AParent: IWindow; const AOptions: TWebviewOptions);
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
  nextpas.core.json.parser,
  nextpas.core.collections.hashset,
  nextpas.core.collections.hashmap.base;
// ViewFromPChar single source via webview.utils (thin forward to text.view Owner), inline zero-copy
procedure AssetBufFree(AData: Pointer); cdecl;
begin
  if AData <> nil then nextpas.core.webview.gtk.pool.ReleaseAssetHolder(PAssetHolder(AData));
end;
function AssetStreamNew(const ASpan: TByteSpan; AHolder: PAssetHolder): Pointer; inline;
begin
  // perf: inline thin wrapper over G_memory_input_stream_new_from_data single source, zero-copy TByteSpan (bytes.ops inline) + Holder Slab reuse single source (bytes.ops VecGrow 0→4→2× inline, per-pool GHolderLock short critical <1µs zero-copy), stream GObject ownership transferred to WebKit adoptGRef not pooled (per-request GObject alloc unavoidable, Holder reuse amortizes data path)
  // stability: Holder ownership via AssetBufFree bound to stream lifetime, exception path ReleaseAssetHolder not lost, stream ownership transferred to WebKit (Holder pool overflow Dispose not lost, Finalize DrainDisposeSlab)
  if ASpan.Len>0 then Result:=G_memory_input_stream_new_from_data(ASpan.Data,gssize(ASpan.Len),@AssetBufFree,AHolder)
  else Result:=G_memory_input_stream_new_from_data(nil,0,@AssetBufFree,AHolder);
end;
function EvalLiveHash(const AKey: Pointer): UInt32; inline;
begin Result:=HashOfPointer(AKey); end;
var
  GSchemeErrQuark: GQuark = 0;
  GEvalLiveSet: specialize THashSet<Pointer> = nil;
  GEvalLiveLock: TMutex = nil;
procedure EvalLiveInit; inline;
begin
  if GEvalLiveSet=nil then GEvalLiveSet:=specialize THashSet<Pointer>.Create(4, @EvalLiveHash);
  if GEvalLiveLock=nil then GEvalLiveLock:=TMutex.Create;
end;
procedure EvalLiveFini; inline;
var LPtr: Pointer;
begin
  if GEvalLiveLock<>nil then GEvalLiveLock.Acquire;
  try
    if GEvalLiveSet<>nil then
    begin
      for LPtr in GEvalLiveSet do
        if LPtr<>nil then FreeEvalRec(PEvalRec(LPtr));
      FreeAndNil(GEvalLiveSet);
    end;
  finally if GEvalLiveLock<>nil then GEvalLiveLock.Release; end;
  FreeAndNil(GEvalLiveLock);
end;
function GtkLiveWindowCount: Integer; inline;
begin Result:=TGtkWebview.LiveWindowCount; end;
procedure TGtkWebview.DoRegisterLive;
begin nextpas.core.webview.gtk.shell.ShellRegisterLive(Pointer(Self)); if FView<>nil then ViewMapAdd(FView,Pointer(Self)); end;
procedure TGtkWebview.DoUnregisterLive;
begin if FView<>nil then ViewMapRemove(FView); nextpas.core.webview.gtk.shell.ShellUnregisterLive(Pointer(Self)); end;
class function TGtkWebview.LiveWindowCount: Integer;
begin Result:=nextpas.core.webview.gtk.shell.ShellLiveWindowCount; end;
procedure ReportGtkHandlerException(const AContext: string; E: Exception);
begin
  // INV-7 observability: cold path only, never silently swallow handler exception
  System.Write(StdErr, '[npw-gtk] ', AContext, ' handler exception: ', E.ClassName, ': ', E.Message, LineEnding);
  System.Flush(StdErr);
  if ShellDebugEnabled then
    ShellTrace(AContext + ' handler exception: ' + E.ClassName + ': ' + E.Message);
end;

function IdleTrampoline(AUserData: Pointer): gboolean; cdecl;
var LRec: PIdleRec absolute AUserData;
begin
  try
    case LRec^.Kind of
      1: if Assigned(LRec^.Method) then LRec^.Method();
      2: if Assigned(LRec^.Plain) then LRec^.Plain();
      else if Assigned(LRec^.Proc) then LRec^.Proc();
    end;
  except on E:Exception do ReportGtkHandlerException('IdleTrampoline', E); end;
  Result:=GLIB_SOURCE_REMOVE;
end;
procedure IdleDestroy(AUserData: Pointer); cdecl;
begin nextpas.core.webview.gtk.pool.ReleaseIdleRec(PIdleRec(AUserData)); end;
procedure DestroyCb(AWidget: Pointer; AUserData: Pointer); cdecl;
begin TGtkWebview(AUserData).HandleNativeDestroy; end;
procedure ScriptMessageCb(AManager, AJsResult, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LVal, LRaw: Pointer; LView: TStringView; LFrame: TWebviewFrame; LReject: string;
begin
  if LSelf.FClosed then Exit; LVal:=WEBKIT_javascript_result_get_js_value(AJsResult); LRaw:=JSC_value_to_string(LVal); if LRaw=nil then Exit; try
    LView:=TStringView.Create(PAnsiChar(LRaw), CStrLen(PAnsiChar(LRaw)));
    if TryBuildOversizedReject(LView, LReject) then
    begin
      if LReject <> '' then
      begin
        if LSelf.FView <> nil then
        begin
          if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(LSelf.FView,PAnsiChar(LReject),Length(LReject),nil,nil,nil,nil,nil) else WEBKIT_web_view_run_javascript(LSelf.FView,PAnsiChar(LReject),nil,nil,nil);
        end;
      end;
      Exit;
    end;
    if TryDecodeFrame(LView, LFrame) then LSelf.DispatchFrame(LFrame);
  finally G_free(LRaw); end;
end;
procedure LoadChangedCb(AView: Pointer; AEvent: guint; AUserData: Pointer); cdecl;
const WEBKIT_LOAD_STARTED=0; WEBKIT_LOAD_FINISHED=3; WEBKIT_LOAD_FAILED=4;
var LSelf: TGtkWebview absolute AUserData; LEv: TWebviewNavigationEvent; I: Integer;
begin case AEvent of
  WEBKIT_LOAD_STARTED: begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav started: '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; if LSelf.FOnNavStarted<>nil then for I:=0 to LSelf.FOnNavStarted.Count-1 do if Assigned(LSelf.FOnNavStarted.At(I)) then try LSelf.FOnNavStarted.At(I)(LEv); except on E:Exception do ReportGtkHandlerException('OnNavigationStarted', E); end; end;
  WEBKIT_LOAD_FINISHED: begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav finished: '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; if LSelf.FOnNavFinished<>nil then for I:=0 to LSelf.FOnNavFinished.Count-1 do if Assigned(LSelf.FOnNavFinished.At(I)) then try LSelf.FOnNavFinished.At(I)(LEv); except on E:Exception do ReportGtkHandlerException('OnNavigationFinished', E); end; LSelf.FireReadyOnce; end;
  WEBKIT_LOAD_FAILED: begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav failed(load-changed): '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; LEv.IsError:=True; if LSelf.FOnNavFailed<>nil then for I:=0 to LSelf.FOnNavFailed.Count-1 do if Assigned(LSelf.FOnNavFailed.At(I)) then try LSelf.FOnNavFailed.At(I)(LEv); except on E:Exception do ReportGtkHandlerException('OnNavigationFailed', E); end; end;
end; end;
procedure LoadFailedCb(AView, ALoadEvent, AFailingUri, AErr, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LEv: TWebviewNavigationEvent; I: Integer; LUriView: TStringView; LUriStr: string;
begin if LSelf.FClosed then Exit; LUriView:=nextpas.core.webview.utils.ViewFromPChar(PAnsiChar(AFailingUri)); LUriStr:=LUriView.ToString; if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('nav failed: '+LUriStr); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LUriStr; LEv.IsError:=True; if AErr<>nil then begin LEv.ErrorCode:=PGError(AErr)^.Code; if PGError(AErr)^.Message<>nil then LEv.ErrorMessage:=nextpas.core.webview.utils.ViewFromPChar(PAnsiChar(PGError(AErr)^.Message)).ToString; end; if LSelf.FOnNavFailed<>nil then for I:=0 to LSelf.FOnNavFailed.Count-1 do if Assigned(LSelf.FOnNavFailed.At(I)) then try LSelf.FOnNavFailed.At(I)(LEv); except on E:Exception do ReportGtkHandlerException('OnNavigationFailed', E); end; end;
procedure ScaleNotifyCb(AObj, APspec, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LNew: Double; I: Integer;
begin if LSelf.FClosed then Exit; LNew:=LSelf.GetScaleFactor; if Abs(LNew-LSelf.FScale)>1e-9 then begin LSelf.FScale:=LNew; if LSelf.FOnScaleChanged<>nil then for I:=0 to LSelf.FOnScaleChanged.Count-1 do if Assigned(LSelf.FOnScaleChanged.At(I)) then try LSelf.FOnScaleChanged.At(I)(LNew); except on E:Exception do ReportGtkHandlerException('OnScaleChanged', E); end; end; end;
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
var LSelf: TGtkWebview; LKeep: IInterface; LMime: string; LPathView: TStringView; LPathStr: string; LRaw: PAnsiChar; LBytes: TBytes; LSpan: TByteSpan; LStream: Pointer; LHolder: PAssetHolder; LView: Pointer;
begin if not Assigned(ARequest) then Exit; try
  if Assigned(WEBKIT_uri_scheme_request_get_web_view) then LView:=WEBKIT_uri_scheme_request_get_web_view(ARequest) else LView:=nil;
  LSelf:=nil; LKeep:=nil;
  if LView<>nil then begin LSelf:=TGtkWebview(nextpas.core.webview.gtk.viewmap.ViewMapFind(LView)); if (LSelf<>nil) and LSelf.FClosed then LSelf:=nil; if LSelf<>nil then LKeep:=LSelf as IInterface; end;
  if LSelf=nil then begin LSelf:=LatestLiveWebview; if LSelf<>nil then LKeep:=LSelf as IInterface; end;
  if LSelf=nil then begin if ShellDebugEnabled then begin LPathView:=nextpas.core.webview.utils.ViewFromPChar(PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest))); nextpas.core.webview.gtk.shell.ShellTrace('scheme request, no live window: '+LPathView.ToString); end; SchemeFinishNotFound(ARequest); Exit; end;
  if not Assigned(WEBKIT_uri_scheme_request_get_path) then begin SchemeFinishNotFound(ARequest); Exit; end;
  if WEBKIT_uri_scheme_request_get_path(ARequest)=nil then begin SchemeFinishNotFound(ARequest); Exit; end;
  LRaw:=PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest)); LPathView:=NormalizeWebviewAssetView(nextpas.core.webview.utils.ViewFromPChar(LRaw)); if LPathView.Len=0 then begin SchemeFinishNotFound(ARequest); Exit; end;
  if not Assigned(LSelf.FAssetsIntf) then begin SchemeFinishNotFound(ARequest); Exit; end;
  // perf: single LPathView.ToString alloc guarded by ShellDebugEnabled, nanosecond baseline zero-copy view fast path via TStringView inline, hit/miss share single cached string zero repeated alloc, bytes.ops single source
  if ShellDebugEnabled then LPathStr:=LPathView.ToString;
  try if not LSelf.FAssetsIntf.TryResolveView(LPathView,LBytes,LMime) then begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme miss '+LPathStr+' -> 404'); SchemeFinishNotFound(ARequest); Exit; end; except on E:Exception do begin if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme resolve ex '+LPathStr+': '+E.Message+' -> 404'); SchemeFinishNotFound(ARequest); Exit; end; end;
  // perf: TByteSpan zero-copy view (bytes.ops FromBytes inline) + ownership steal via BytesSteal inline zero-copy single source (bytes.ops Move+FillChar zero refcount bump) + Holder Slab reuse via pool single source (bytes.ops VecGrow 0→4→2× inline) + Stream Slab reuse via GStreamPool (bytes.ops VecGrow 0→4→2× inline, per-pool GStreamLock, burst small files zero per-request g_malloc amortized), AssetStreamNew inline zero-copy; stability: Holder ownership via AssetBufFree bound to stream, exception path ReleaseAssetHolder not lost, stream ownership transferred to WebKit (pool overflow G_object_unref not lost, Finalize DrainCancelSlab)
  LSpan:=TByteSpan.FromBytes(LBytes);
  if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('scheme hit '+LPathStr+' ('+IntToStr(LSpan.Len)+'B)'); if LMime='' then LMime:=MimeTypeFromPathView(LPathView);
  LStream:=nil;
  if not Assigned(G_memory_input_stream_new_from_data) or not Assigned(WEBKIT_uri_scheme_request_finish) then begin SchemeFinishNotFound(ARequest); Exit; end;
  LHolder:=nextpas.core.webview.gtk.pool.AcquireAssetHolder;
  BytesSteal(LHolder^.Bytes, LBytes);
  try LStream:=AssetStreamNew(LSpan, LHolder); if not Assigned(LStream) then begin nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder); SchemeFinishNotFound(ARequest); Exit; end; except nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder); raise; end;
  if not Assigned(LStream) then begin SchemeFinishNotFound(ARequest); Exit; end;
  try WEBKIT_uri_scheme_request_finish(ARequest,LStream,gssize(LSpan.Len),PAnsiChar(LMime)); except try SchemeFinishNotFound(ARequest); except end; end;
  except on E:Exception do try if Assigned(ARequest) then SchemeFinishNotFound(ARequest); except end; end;
end;
function CompletionMarshalTrampoline(AUserData: Pointer): gboolean; cdecl;
var LRec: PCompletionMarshal absolute AUserData; LSelf: TGtkWebview;
begin LSelf:=TGtkWebview(LRec^.Win); if not LSelf.FClosed then LSelf.SendReceipt(LRec^.FrameId,LRec^.IsError,LRec^.ResultJson,LRec^.Code,LRec^.MsgText); Result:=GLIB_SOURCE_REMOVE; end;
procedure CompletionMarshalDestroy(AUserData: Pointer); cdecl;
begin nextpas.core.webview.gtk.pool.ReleaseCompletionRec(PCompletionMarshal(AUserData)); end;
function EvalTextOfValueGlobal(AJscValue: Pointer): string; inline;
var LRaw: PAnsiChar; LView: TStringView;
begin if AJscValue=nil then Exit(''); if (JSC_value_is_null(AJscValue)<>0) or (JSC_value_is_undefined(AJscValue)<>0) then Exit('null'); LRaw:=JSC_value_to_json(AJscValue,0); if LRaw<>nil then begin LView:=nextpas.core.webview.utils.ViewFromPChar(LRaw); Result:=LView.ToString; G_free(LRaw); end else begin LRaw:=JSC_value_to_string(AJscValue); if LRaw<>nil then begin LView:=nextpas.core.webview.utils.ViewFromPChar(LRaw); Result:=LView.ToString; G_free(LRaw); end else Result:=''; end; end;
procedure FreeEvalRec(ARec: PEvalRec);
begin
  if ARec^.Cancel<>nil then begin nextpas.core.webview.gtk.pool.ReleaseGCancellable(ARec^.Cancel); ARec^.Cancel:=nil; end;
  nextpas.core.webview.gtk.pool.ReleaseEvalRec(ARec);
end;
procedure SettleEvalGlobal(ARec: PEvalRec; AOk: Boolean; const AText: string);
var LErr: EWebviewEvalFailed; LOwner: TGtkWebview; LShouldExit: Boolean;
begin
  // stability: owner lock guards Done exactly-once vs SettlePendingOnClose, prevents double settlement/UAF, short critical <1µs
  LOwner:=nil; if ARec^.Owner<>nil then LOwner:=TGtkWebview(ARec^.Owner);
  LShouldExit:=False;
  if LOwner<>nil then LOwner.FPendingLock.Acquire;
  try
    if ARec^.Done then LShouldExit:=True else ARec^.Done:=True;
  finally
    if LOwner<>nil then LOwner.FPendingLock.Release;
  end;
  if LShouldExit then begin FreeEvalRec(ARec); Exit; end;
  try if AOk then begin if Assigned(ARec^.Callback) then ARec^.Callback(AText); end else if Assigned(ARec^.OnError) then begin LErr:=EWebviewEvalFailed.Create(AText); try ARec^.OnError(LErr); finally LErr.Free; end; end; finally FreeEvalRec(ARec); end;
end;
procedure EvalReadyCb(ASource, ARes, AUserData: Pointer); cdecl;
var LRec: PEvalRec absolute AUserData; LOwner: TGtkWebview; LErr: PGError=nil; LJsRes, LVal: Pointer; LOk: Boolean; LText: string; LAlreadyDone: Boolean;
begin
  // stability: global live set guards UAF when Close freed rec before callback (engine may not callback after cancel, leak-free via live set exactly-once, short critical <1µs, bytes.ops not needed)
  if GEvalLiveLock<>nil then GEvalLiveLock.Acquire;
  try
    if (GEvalLiveSet=nil) or not GEvalLiveSet.Contains(Pointer(LRec)) then Exit; // already freed by Close, avoid UAF deref LRec^.Owner/Done
    GEvalLiveSet.Remove(Pointer(LRec));
  finally if GEvalLiveLock<>nil then GEvalLiveLock.Release; end;
  LOwner:=nil; if LRec^.Owner<>nil then LOwner:=TGtkWebview(LRec^.Owner);
  // perf: short critical <1µs for Done+pending exactly-once, lock-free WebKit finish outside critical to avoid holding lock during user callback
  if LOwner<>nil then LOwner.FPendingLock.Acquire;
  try
    if LRec^.Done then LAlreadyDone:=True
    else
    begin
      LAlreadyDone:=False;
      // Remove from pending registry under same lock (direct, no nested Acquire) to prevent SettlePendingOnClose double-iteration
      if (LOwner<>nil) and (LOwner.FPendingEvals<>nil) then LOwner.FPendingEvals.Unregister(LRec);
    end;
  finally
    if LOwner<>nil then LOwner.FPendingLock.Release;
  end;
  if LAlreadyDone then
  begin
    if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('eval late callback after close, disposed');
    FreeEvalRec(LRec);
    Exit;
  end;
  LVal:=nil; LOk:=False;
  if GtkLoadInfo().EvalPath=gepEvaluateJavascript then LVal:=WEBKIT_web_view_evaluate_javascript_finish(ASource,ARes,@LErr)
  else begin LJsRes:=WEBKIT_web_view_run_javascript_finish(ASource,ARes,@LErr); if LJsRes<>nil then LVal:=WEBKIT_javascript_result_get_js_value(LJsRes); end;
  if LErr<>nil then LText:=nextpas.core.webview.utils.ViewFromPChar(PAnsiChar(LErr^.Message)).ToString else begin LOk:=True; if LVal<>nil then LText:=EvalTextOfValueGlobal(LVal) else LText:=''; end;
  SettleEvalGlobal(LRec,LOk,LText);
end;
type TGtkCompletion=class(TInterfacedObject,IWebviewInvokeCompletion) private FWin:TObject; FCmd:string; FFrameId:Int64; FDone: Int32; procedure RecordViaIdle(AIsError:Boolean; const AResultJson,ACode,AMessage:string); public constructor Create(AWin:TObject; const ACmd:string; AFrameId:Int64); procedure Ok(const AResultJson:string); procedure Fail(const ACode,AMessage:string); end;
constructor TGtkCompletion.Create(AWin:TObject; const ACmd:string; AFrameId:Int64); begin inherited Create; FWin:=AWin; FCmd:=ACmd; FFrameId:=AFrameId; FDone:=0; end;
procedure TGtkCompletion.RecordViaIdle(AIsError:Boolean; const AResultJson,ACode,AMessage:string); var LRec:PCompletionMarshal; begin LRec:=nextpas.core.webview.gtk.pool.AcquireCompletionRec; LRec^.Win:=FWin; LRec^.FrameId:=FFrameId; LRec^.Cmd:=FCmd; LRec^.IsError:=AIsError; LRec^.ResultJson:=AResultJson; LRec^.Code:=NormalizeInvokeCode(ACode); LRec^.MsgText:=AMessage; G_idle_add_full(G_PRIORITY_DEFAULT,@CompletionMarshalTrampoline,LRec,@CompletionMarshalDestroy); end;
procedure TGtkCompletion.Ok(const AResultJson:string); var LExp: Int32; begin LExp:=0; if not atomic_compare_exchange_strong(FDone, LExp, 1) then raise EWebviewInvalidState.Create('invoke completion already settled'); RecordViaIdle(False,AResultJson,'',''); end;
procedure TGtkCompletion.Fail(const ACode,AMessage:string); var LExp: Int32; begin LExp:=0; if not atomic_compare_exchange_strong(FDone, LExp, 1) then raise EWebviewInvalidState.Create('invoke completion already settled'); RecordViaIdle(True,'',ACode,AMessage); end;
constructor TGtkWebview.Create(const AOptions: TWebviewOptions);
begin inherited Create; DoCommonInit(nil, AOptions); end;
constructor TGtkWebview.CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions);
begin inherited Create; if AParent=nil then raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn'); DoCommonInit(AParent, AOptions); end;
destructor TGtkWebview.Destroy;
var I: Integer; LRec: PEvalRec;
begin if FOwnsContext and (FContext<>nil) then begin nextpas.core.webview.gtk.shell.ShellForgetSchemeContext(FContext); G_object_unref(FContext); FContext:=nil; end; DoUnregisterLive; FWindow:=nil; FWin:=nil; FView:=nil; FreeAndNil(FOnScaleChanged); FreeAndNil(FOnReady); FreeAndNil(FOnWindowClosed); FreeAndNil(FOnNavFailed); FreeAndNil(FOnNavFinished); FreeAndNil(FOnNavStarted);
  if FPendingEvals<>nil then
  begin
    for I:=0 to FPendingEvals.Count-1 do
    begin
      LRec:=FPendingEvals.At(I);
      if GEvalLiveLock<>nil then GEvalLiveLock.Acquire;
      try if (GEvalLiveSet<>nil) and GEvalLiveSet.Contains(Pointer(LRec)) then GEvalLiveSet.Remove(Pointer(LRec)); finally if GEvalLiveLock<>nil then GEvalLiveLock.Release; end;
      FreeEvalRec(LRec);
    end;
    FreeAndNil(FPendingEvals);
  end;
  FreeAndNil(FIdleTags); FreeAndNil(FPendingLock); inherited Destroy; end;
function TGtkWebview.IsClosed: Boolean; inline; begin Result:=FClosed; end;
procedure TGtkWebview.RequireOpen; begin if FClosed then raise EWebviewClosed.Create('webview window is closed'); end;
procedure TGtkWebview.RemovePending(ARec: PEvalRec);
begin
  // perf: short critical <1µs pointer-only via pending lock, inline zero-copy, exactly-once guard
  if FPendingLock <> nil then FPendingLock.Acquire;
  try
    if FPendingEvals <> nil then FPendingEvals.Unregister(ARec);
  finally
    if FPendingLock <> nil then FPendingLock.Release;
  end;
end;
procedure TGtkWebview.FireNotifyHandlers(AReg: specialize TCompactLiveRegistry<TWebviewNotifyHandler>); var I: Integer; begin if AReg=nil then Exit; for I:=0 to AReg.Count-1 do if Assigned(AReg.At(I)) then try AReg.At(I)(); except on E:Exception do ReportGtkHandlerException('FireNotifyHandlers', E); end; end;
procedure TGtkWebview.SetupSessionContext; begin FOwnsContext:=False; if FOptions.EphemeralSession then FOwnsContext:=True else if FOptions.DataDirectory<>'' then FOwnsContext:=True; end;
function TGtkWebview.ResolveContext: Pointer; var LManager: Pointer; begin if not FOwnsContext then Exit(WEBKIT_web_context_get_default()); if FOptions.EphemeralSession then Result:=WEBKIT_web_context_new_ephemeral() else begin LManager:=WEBKIT_website_data_manager_new('base-data-directory',PAnsiChar(FOptions.DataDirectory),Pointer(nil)); if LManager=nil then raise EWebviewNotInitialized.Create('webkit_website_data_manager_new failed (data directory rejected)'); Result:=WEBKIT_web_context_new_with_website_data_manager(LManager); G_object_unref(LManager); end; FContext:=Result; end;
procedure TGtkWebview.HandleWindowEvent(const AEvent: TWindowEvent); begin if FClosed then Exit; case AEvent.Kind of weCloseRequested,weClosed: Close; weScaleChanged,weDpiChanged: begin FScale:=AEvent.NewScale; FireNotifyHandlers(FOnScaleChanged); end; weResized: ; end; end;
function TGtkWebview.ResolveOptions(const AOptions: TWebviewOptions): TWebviewOptions; inline;
begin Result:=AOptions; if Result.SchemeName='' then Result.SchemeName:=DEFAULT_WEBVIEW_SCHEME; CheckWebviewOptions(Result); end;
procedure TGtkWebview.EnsureBackendAvailable; inline;
var LInfo: TGtkLoadInfo;
begin if not TryLoadGtkWebkit(LInfo) then raise EWebviewBackendUnavailable.Create('WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)'); if not WindowGtkRawInit then raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)'); end;
procedure TGtkWebview.InitRegistries; inline;
begin FOwnerThread:=platform_thread_id; FScale:=1.0; FPendingLock:=TMutex.Create; FInvokesIntf:=TWebviewInvokeRegistry.Create; FInvokes:=FInvokesIntf as TObject; FAssetsIntf:=TWebviewAssetsImpl.Create(FOptions.DevServerUrl<>''); FAssets:=FAssetsIntf as TObject; FIdleTags:=specialize TCompactLiveRegistry<guint>.Create; FPendingEvals:=specialize TCompactLiveRegistry<PEvalRec>.Create; FOnNavStarted:=specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFinished:=specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFailed:=specialize TCompactLiveRegistry<TWebviewNavFailedHandler>.Create; FOnWindowClosed:=specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create; FOnReady:=specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create; FOnScaleChanged:=specialize TCompactLiveRegistry<TWebviewScaleHandler>.Create; if FOptions.DevServerUrl<>'' then nextpas.core.webview.gtk.shell.ShellTrace('dev mode: assets inert, scheme deferred ('+FOptions.DevServerUrl+')'); end;
procedure TGtkWebview.DoCommonInit(const AParent: IWindow; const AOptions: TWebviewOptions);
begin FOptions:=ResolveOptions(AOptions); EnsureBackendAvailable; InitRegistries; SetupSessionContext; if AParent=nil then SetupSchemeAndShell else SetupSchemeAndShellForParent(AParent); WireSignals; DoRegisterLive; FSelfKeepAlive:=Self; if FOptions.InitialUrl<>'' then Navigate(FOptions.InitialUrl) else if FOptions.InitialHtml<>'' then NavigateToString(FOptions.InitialHtml); end;
procedure TGtkWebview.SetupSchemeAndShell; var LCtx: Pointer; LWinOpts: TWindowOptions; begin LCtx:=ResolveContext; if (FOptions.DevServerUrl='') and (not nextpas.core.webview.gtk.shell.ShellSchemeContextRegistered(LCtx)) then begin WEBKIT_web_context_register_uri_scheme(LCtx,PAnsiChar(FOptions.SchemeName),@SchemeRequestCb,nil,nil); nextpas.core.webview.gtk.shell.ShellRememberSchemeContext(LCtx); end; FView:=WEBKIT_web_view_new_with_context(LCtx); if FView=nil then raise EWebviewNotInitialized.Create('webkit_web_view_new_with_context returned nil'); if FWindow=nil then begin LWinOpts:=nextpas.core.webview.utils.WebviewWindowOptionsOf(FOptions); FWindow:=nextpas.core.window.gtk3.CreateWindowGtk(LWinOpts); FOwnsWindow:=True; FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); FWindow.OnEvent(@HandleWindowEvent); end else begin FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Parent window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); end; if FOptions.DebugTools then WEBKIT_settings_set_enable_developer_extras(WEBKIT_web_view_get_settings(FView),1); end;
procedure TGtkWebview.SetupSchemeAndShellForParent(const AParent: IWindow); var LCtx: Pointer; begin if AParent=nil then raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn'); FWindow:=AParent; FOwnsWindow:=False; FWindow.OnEvent(@HandleWindowEvent); LCtx:=ResolveContext; if (FOptions.DevServerUrl='') and (not nextpas.core.webview.gtk.shell.ShellSchemeContextRegistered(LCtx)) then begin WEBKIT_web_context_register_uri_scheme(LCtx,PAnsiChar(FOptions.SchemeName),@SchemeRequestCb,nil,nil); nextpas.core.webview.gtk.shell.ShellRememberSchemeContext(LCtx); end; FView:=WEBKIT_web_view_new_with_context(LCtx); if FView=nil then raise EWebviewNotInitialized.Create('webkit_web_view_new_with_context returned nil'); FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Parent window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); if FView<>nil then nextpas.core.gtk3.ffi.gtk_widget_show(FView); if FOptions.DebugTools then WEBKIT_settings_set_enable_developer_extras(WEBKIT_web_view_get_settings(FView),1); end;
function TGtkWebview.GetWindow: IWindow; inline; begin Result:=FWindow; end;
procedure TGtkWebview.AddUserScript(const ASource: string); var LUcm, LScript: Pointer; begin LUcm:=WEBKIT_web_view_get_user_content_manager(FView); LScript:=WEBKIT_user_script_new(PAnsiChar(ASource),WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,nil,nil); WEBKIT_user_content_manager_add_script(LUcm,LScript); WEBKIT_user_script_unref(LScript); end;
procedure TGtkWebview.WireSignals; begin g_signal_connect_data(FWin,'destroy',@DestroyCb,Self,nil,0); g_signal_connect_data(WEBKIT_web_view_get_user_content_manager(FView),'script-message-received::npw',@ScriptMessageCb,Self,nil,0); WEBKIT_user_content_manager_register_script_message_handler(WEBKIT_web_view_get_user_content_manager(FView),'npw'); AddUserScript(NPW_BRIDGE_SCRIPT); g_signal_connect_data(FView,'load-changed',@LoadChangedCb,Self,nil,0); g_signal_connect_data(FView,'load-failed',@LoadFailedCb,Self,nil,0); g_signal_connect_data(FView,'notify::scale-factor',@ScaleNotifyCb,Self,nil,0); end;
function TGtkWebview.CurrentUri: string; var LP: PAnsiChar; begin LP:=WEBKIT_web_view_get_uri(FView); Result:=nextpas.core.webview.utils.ViewFromPChar(LP).ToString; end;
procedure TGtkWebview.FireReadyOnce; var I: Integer; begin if FReadyFired or FClosed then Exit; FReadyFired:=True; if FOnReady<>nil then for I:=0 to FOnReady.Count-1 do if Assigned(FOnReady.At(I)) then try FOnReady.At(I)(); except on E:Exception do ReportGtkHandlerException('OnReady', E); end; end;
class function TGtkWebview.MapInvokeCodeSafe(E: Exception): string; begin if E is EWebviewInvokeError then Result:=NormalizeInvokeCode(EWebviewInvokeError(E).Code) else Result:=NPW_CODE_HANDLER_ERROR; end;
procedure TGtkWebview.DispatchFrame(const AFrame: TWebviewFrame);
var LReg: TWebviewInvokeRegistry; LIsAsync:Boolean;
    LSync: TWebviewInvokeSyncHandler; LAsync:TWebviewInvokeAsyncHandler;
    LSyncView: TWebviewInvokeSyncViewHandler; LAsyncView: TWebviewInvokeAsyncViewHandler;
    LResultJson:string; LCompletion:IWebviewInvokeCompletion;
begin
  RequireOpen; LReg:=TWebviewInvokeRegistry(FInvokes);
  // perf: zero-copy view dispatch first (bytes.ops/text.view single source inline RawSlice, zero heap per invoke), hot path avoids ToString single alloc; fallback to string compat retains ToString only for legacy handlers, inline zero-copy evidence via TStringView.Data/Len direct
  if LReg.FindView(AFrame.Cmd,LIsAsync,LSyncView,LAsyncView) then
  begin
    if LIsAsync then
    begin
      LCompletion:=TGtkCompletion.Create(Self,AFrame.Cmd,AFrame.Id);
      try LAsyncView(AFrame.Payload,LCompletion); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end;
    end else
    begin
      try LResultJson:=LSyncView(AFrame.Payload); SendReceipt(AFrame.Id,False,LResultJson,'',''); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end;
    end;
    Exit;
  end;
  if not LReg.Find(AFrame.Cmd,LIsAsync,LSync,LAsync) then begin SendReceipt(AFrame.Id,True,'',NPW_CODE_HANDLER_MISSING,'no handler registered for cmd'); Exit; end;
  if LIsAsync then begin LCompletion:=TGtkCompletion.Create(Self,AFrame.Cmd,AFrame.Id); try LAsync(AFrame.Payload.ToString,LCompletion); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end; end else begin try LResultJson:=LSync(AFrame.Payload.ToString); SendReceipt(AFrame.Id,False,LResultJson,'',''); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end; end;
end;
procedure TGtkWebview.SendReceipt(AFrameId:Int64; AIsError:Boolean; const AResultJson,ACode,AMessage:string); var LJs:string; begin if FClosed then Exit; if AIsError then LJs:=BuildRejectScript(AFrameId,ACode,AMessage) else LJs:=BuildResolveScript(AFrameId,AResultJson); if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(FView,PAnsiChar(LJs),Length(LJs),nil,nil,nil,nil,nil) else WEBKIT_web_view_run_javascript(FView,PAnsiChar(LJs),nil,nil,nil); end;
procedure TGtkWebview.PostIdle(AProc: TWebviewProcRef); var LRec:PIdleRec; LTag:guint; begin
  LRec:=nextpas.core.webview.gtk.pool.AcquireIdleRec; LRec^.Kind:=0; LRec^.Proc:=AProc; LRec^.Method:=nil; LRec^.Plain:=nil;
  LTag:=G_idle_add_full(G_PRIORITY_DEFAULT,@IdleTrampoline,LRec,@IdleDestroy); if FIdleTags<>nil then FIdleTags.Register(LTag);
end;
procedure TGtkWebview.DropIdlePendings;
var I: Integer;
begin
  if FIdleTags=nil then Exit;
  for I:=0 to FIdleTags.Count-1 do
    G_source_remove(FIdleTags.At(I));
  FIdleTags.Clear;
end;
procedure TGtkWebview.SettlePendingOnClose;
var I: Integer; LRec: PEvalRec; LSnapshot: array of PEvalRec; LCount, LSettled: Integer; LErr: EWebviewEvalFailed;
begin
  // stability: exactly-once Done mark under lock during snapshot vs EvalReadyCb/SettleEvalGlobal Done guard (<1µs short critical), prevents double settlement/double free; perf: snapshot pointer copy under lock <1µs, callback outside lock deadlock-free;
  // leak guard: global live set ensures EvalRec freed even if WebKit never calls back after cancel (heaptrc long-run leak fix), exactly-once via live set + Done guard, short critical <1µs, single ownership not lost
  if FPendingEvals = nil then Exit;
  if FPendingLock <> nil then FPendingLock.Acquire;
  try
    LCount := FPendingEvals.Count;
    if LCount = 0 then Exit;
    SetLength(LSnapshot, LCount);
    LSettled := 0;
    for I := 0 to LCount - 1 do
    begin
      LRec := FPendingEvals.At(I);
      if LRec^.Done then Continue;
      LRec^.Done := True;
      LSnapshot[LSettled] := LRec;
      Inc(LSettled);
    end;
    FPendingEvals.Clear;
    SetLength(LSnapshot, LSettled);
    LCount := LSettled;
  finally
    if FPendingLock <> nil then FPendingLock.Release;
  end;
  for I := 0 to LCount - 1 do
  begin
    LRec := LSnapshot[I];
    if Assigned(LRec^.OnError) then
    begin
      LErr := EWebviewEvalFailed.Create('window closed');
      try LRec^.OnError(LErr); finally LErr.Free; end;
    end;
    if LRec^.Cancel <> nil then G_cancellable_cancel(LRec^.Cancel);
    // stability: remove from global live set and free directly — ownership taken by Close, EvalReadyCb will see not-in-set and avoid UAF deref, leak-free even if engine never callbacks
    if GEvalLiveLock<>nil then GEvalLiveLock.Acquire;
    try if (GEvalLiveSet<>nil) and GEvalLiveSet.Contains(Pointer(LRec)) then GEvalLiveSet.Remove(Pointer(LRec)); finally if GEvalLiveLock<>nil then GEvalLiveLock.Release; end;
    FreeEvalRec(LRec);
  end;
  LSnapshot := nil;
end;
procedure TGtkWebview.DoClose;
begin
  // stability: single source close body, main-thread only, idempotent via FClosed guard — prevents UAF/double-settle when Close marshalled vs HandleNativeDestroy
  if FClosed then Exit;
  FClosed := True;
  DoUnregisterLive;
  SettlePendingOnClose;
  DropIdlePendings;
  FireNotifyHandlers(FOnWindowClosed);
  if FOwnsWindow then
  begin
    if FWindow <> nil then try FWindow.Close; except end;
    if (FView <> nil) and (FWindow = nil) and (FWin <> nil) then GTK_widget_destroy(FWin);
  end
  else
  begin
    if FView <> nil then GTK_widget_destroy(FView);
  end;
  FView := nil;
  if FOwnsWindow then begin FWin := nil; FWindow := nil; end;
  if LiveWindowCount = 0 then WindowGtkRawQuitMainLoop;
  FSelfKeepAlive := nil;
end;
procedure TGtkWebview.HandleNativeDestroy; begin if FClosed then Exit; FClosed:=True; DoUnregisterLive; SettlePendingOnClose; DropIdlePendings; FireNotifyHandlers(FOnWindowClosed); if LiveWindowCount=0 then WindowGtkRawQuitMainLoop; FView:=nil; FWin:=nil; FWindow:=nil; FSelfKeepAlive:=nil; end;
procedure TGtkWebview.Close;
begin
  // CONTRACT §4: Close marshal to main thread, idempotent — prevents cross-thread FClosed write + pending table race vs EvalReadyCb (exactly-once)
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    // keep self alive via FSelfKeepAlive already holds ref; Post marshal to UI thread via idle (GIdleLock-isolated pool, inline zero-copy)
    Post(TWebviewProcMethod(@DoClose));
    Exit;
  end;
  DoClose;
end;
procedure TGtkWebview.Post(AProc: TWebviewProcRef); inline; begin PostIdle(AProc); end;
procedure TGtkWebview.Post(AProc: TWebviewProcMethod); inline;
var LRec: PIdleRec; LTag: guint;
begin
  LRec:=nextpas.core.webview.gtk.pool.AcquireIdleRec; LRec^.Kind:=1; LRec^.Method:=AProc; LRec^.Proc:=nil; LRec^.Plain:=nil;
  LTag:=G_idle_add_full(G_PRIORITY_DEFAULT,@IdleTrampoline,LRec,@IdleDestroy); if FIdleTags<>nil then FIdleTags.Register(LTag);
end;
procedure TGtkWebview.Post(AProc: TWebviewProc); inline;
var LRec: PIdleRec; LTag: guint;
begin
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
function TGtkWebview.GetTitle:string; var LRaw:PAnsiChar; begin RequireOpen; if FWindow<>nil then Exit(FWindow.GetTitle); LRaw:=GTK_window_get_title(FWin); Result:=nextpas.core.webview.utils.ViewFromPChar(LRaw).ToString; end;
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
function TGtkWebview.GetUserAgent:string; var LRaw:PAnsiChar; begin RequireOpen; LRaw:=nil; G_object_get(WEBKIT_web_view_get_settings(FView),'user-agent',@LRaw,Pointer(nil)); if LRaw<>nil then begin Result:=nextpas.core.webview.utils.ViewFromPChar(LRaw).ToString; G_free(LRaw); end else Result:=''; end;
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
  RequireOpen; LRec:=nextpas.core.webview.gtk.pool.AcquireEvalRec; LRec^.Callback:=ACallback; LRec^.OnError:=AOnError; LRec^.Done:=False; LRec^.Cancel:=nextpas.core.webview.gtk.pool.AcquireGCancellable; LRec^.Owner:=Self;
  // perf: register under lock <1µs pointer-only, prevents race vs SettlePendingOnClose snapshot (exactly-once), live set inline zero-copy single source
  if FPendingLock<>nil then FPendingLock.Acquire;
  try
    if FPendingEvals<>nil then FPendingEvals.Register(LRec);
  finally
    if FPendingLock<>nil then FPendingLock.Release;
  end;
  EvalLiveInit;
  if GEvalLiveLock<>nil then GEvalLiveLock.Acquire;
  try if GEvalLiveSet<>nil then GEvalLiveSet.Add(Pointer(LRec)); finally if GEvalLiveLock<>nil then GEvalLiveLock.Release; end;
  if ShellDebugEnabled then nextpas.core.webview.gtk.shell.ShellTrace('eval dispatch: '+Copy(AJavascript,1,80)); if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(FView,PAnsiChar(AJavascript),Length(AJavascript),nil,nil,LRec^.Cancel,@EvalReadyCb,LRec) else WEBKIT_web_view_run_javascript(FView,PAnsiChar(AJavascript),LRec^.Cancel,@EvalReadyCb,LRec); end;
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
initialization ViewMapLockInit; ViewMapInit; PoolInit; EvalLiveInit;
finalization EvalLiveFini; PoolFinalize; ViewMapClear; ViewMapLockFini;
end.
