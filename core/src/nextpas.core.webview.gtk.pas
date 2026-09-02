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
  PEvalRec = ^TEvalRec;
  TEvalRec = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
    Cancel: Pointer;
    Owner: Pointer;
  end;
  PIdleRec = ^TIdleRec;
  TIdleRec = record
    Proc: TWebviewProcRef;
  end;
  PCompletionMarshal = ^TCompletionMarshal;
  TCompletionMarshal = record
    Win: TObject;
    FrameId: Int64;
    Cmd: string;
    IsError: Boolean;
    ResultJson: string;
    Code: string;
    MsgText: string;
  end;
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
    function WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
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
  nextpas.core.webview.mime,
  nextpas.core.webview.utils,
  nextpas.core.webview.gtk.viewmap,
  nextpas.core.webview.gtk.pool,
  nextpas.core.webview.gtk.shell,
  nextpas.core.webview.gtk.bridge,
  nextpas.core.webview.gtk.dispatch,
  nextpas.core.text.view;
const
  WEBVIEW_SCHEME_LARGE_THRESHOLD = 8192;
type
  PAssetHolder = nextpas.core.webview.gtk.pool.PAssetHolder;
  TAssetHolder = nextpas.core.webview.gtk.pool.TAssetHolder;
procedure AssetBufFree(AData: Pointer); cdecl;
begin
  if AData <> nil then nextpas.core.webview.gtk.pool.ReleaseAssetHolder(PAssetHolder(AData));
end;
var
  GSchemeErrQuark: GQuark = 0;
function AcquireIdleRec: PIdleRec; inline;
begin Result:=PIdleRec(Pointer(nextpas.core.webview.gtk.pool.AcquireIdleRec)); end;
procedure ReleaseIdleRec(A: PIdleRec); inline;
begin nextpas.core.webview.gtk.pool.ReleaseIdleRec(PIdleRec(Pointer(A))); end;
function AcquireCompletionRec: PCompletionMarshal; inline;
begin Result:=PCompletionMarshal(Pointer(nextpas.core.webview.gtk.pool.AcquireCompletionRec)); end;
procedure ReleaseCompletionRec(A: PCompletionMarshal); inline;
begin nextpas.core.webview.gtk.pool.ReleaseCompletionRec(PCompletionMarshal(Pointer(A))); end;
procedure GtkTrace(const AMsg: string); inline;
begin nextpas.core.webview.gtk.shell.ShellTrace(AMsg); end;
function SchemeContextRegistered(ACtx: Pointer): Boolean; inline;
begin Result:=nextpas.core.webview.gtk.shell.ShellSchemeContextRegistered(ACtx); end;
procedure RememberSchemeContext(ACtx: Pointer); inline;
begin nextpas.core.webview.gtk.shell.ShellRememberSchemeContext(ACtx); end;
procedure ForgetSchemeContext(ACtx: Pointer); inline;
begin nextpas.core.webview.gtk.shell.ShellForgetSchemeContext(ACtx); end;
function GtkLiveWindowCount: Integer; inline;
begin Result:=nextpas.core.webview.gtk.shell.ShellLiveWindowCount; end;
procedure RegisterLive(AWin: TGtkWebview);
begin nextpas.core.webview.gtk.shell.ShellRegisterLive(Pointer(AWin)); if AWin.FView<>nil then ViewMapAdd(AWin.FView,Pointer(AWin)); end;
procedure UnregisterLive(AWin: TGtkWebview);
begin if AWin.FView<>nil then ViewMapRemove(AWin.FView); nextpas.core.webview.gtk.shell.ShellUnregisterLive(Pointer(AWin)); end;
function IdleTrampoline(AUserData: Pointer): gboolean; cdecl;
var LRec: PIdleRec absolute AUserData;
begin try LRec^.Proc(); except on E:Exception do ; end; Result:=GLIB_SOURCE_REMOVE; end;
procedure IdleDestroy(AUserData: Pointer); cdecl;
begin ReleaseIdleRec(PIdleRec(AUserData)); end;
procedure DestroyCb(AWidget: Pointer; AUserData: Pointer); cdecl;
begin TGtkWebview(AUserData).HandleNativeDestroy; end;
procedure ScriptMessageCb(AManager, AJsResult, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LVal, LRaw: Pointer; LJson: string; LFrame: TWebviewFrame;
begin if LSelf.FClosed then Exit; LVal:=WEBKIT_javascript_result_get_js_value(AJsResult); LRaw:=JSC_value_to_string(LVal); if LRaw=nil then Exit; try LJson:=AnsiPtrToStr(PAnsiChar(LRaw)); finally G_free(LRaw); end; if TryDecodeFrame(LJson,LFrame) then LSelf.DispatchFrame(LFrame); end;
procedure LoadChangedCb(AView: Pointer; AEvent: guint; AUserData: Pointer); cdecl;
const WEBKIT_LOAD_STARTED=0; WEBKIT_LOAD_FINISHED=3; WEBKIT_LOAD_FAILED=4;
var LSelf: TGtkWebview absolute AUserData; LEv: TWebviewNavigationEvent; I: Integer;
begin case AEvent of
  WEBKIT_LOAD_STARTED: begin GtkTrace('nav started: '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; if LSelf.FOnNavStarted<>nil then for I:=0 to LSelf.FOnNavStarted.Count-1 do if Assigned(LSelf.FOnNavStarted.At(I)) then try LSelf.FOnNavStarted.At(I)(LEv); except end; end;
  WEBKIT_LOAD_FINISHED: begin GtkTrace('nav finished: '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; if LSelf.FOnNavFinished<>nil then for I:=0 to LSelf.FOnNavFinished.Count-1 do if Assigned(LSelf.FOnNavFinished.At(I)) then try LSelf.FOnNavFinished.At(I)(LEv); except end; LSelf.FireReadyOnce; end;
  WEBKIT_LOAD_FAILED: begin GtkTrace('nav failed(load-changed): '+LSelf.CurrentUri); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=LSelf.CurrentUri; LEv.IsError:=True; if LSelf.FOnNavFailed<>nil then for I:=0 to LSelf.FOnNavFailed.Count-1 do if Assigned(LSelf.FOnNavFailed.At(I)) then try LSelf.FOnNavFailed.At(I)(LEv); except end; end;
end; end;
procedure LoadFailedCb(AView, ALoadEvent, AFailingUri, AErr, AUserData: Pointer); cdecl;
var LSelf: TGtkWebview absolute AUserData; LEv: TWebviewNavigationEvent; I: Integer;
begin if LSelf.FClosed then Exit; GtkTrace('nav failed: '+AnsiPtrToStr(PAnsiChar(AFailingUri))); LEv:=Default(TWebviewNavigationEvent); LEv.Url:=AnsiPtrToStr(PAnsiChar(AFailingUri)); LEv.IsError:=True; if AErr<>nil then begin LEv.ErrorCode:=PGError(AErr)^.Code; if PGError(AErr)^.Message<>nil then LEv.ErrorMessage:=AnsiPtrToStr(PAnsiChar(PGError(AErr)^.Message)); end; if LSelf.FOnNavFailed<>nil then for I:=0 to LSelf.FOnNavFailed.Count-1 do if Assigned(LSelf.FOnNavFailed.At(I)) then try LSelf.FOnNavFailed.At(I)(LEv); except end; end;
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
var LSelf: TGtkWebview; LKeep: IInterface; LPath, LMime: string; LPathView: TStringView; LRaw: PAnsiChar; LBytes: TBytes; LStream, LBytesObj: Pointer; LHolder: PAssetHolder; LView: Pointer;
begin if not Assigned(ARequest) then Exit; try
  if Assigned(WEBKIT_uri_scheme_request_get_web_view) then LView:=WEBKIT_uri_scheme_request_get_web_view(ARequest) else LView:=nil;
  LSelf:=nil; LKeep:=nil;
  if LView<>nil then begin LSelf:=TGtkWebview(nextpas.core.webview.gtk.viewmap.ViewMapFind(LView)); if (LSelf<>nil) and LSelf.FClosed then LSelf:=nil; if LSelf<>nil then LKeep:=LSelf as IInterface; end;
  if LSelf=nil then begin LSelf:=LatestLiveWebview; if LSelf<>nil then LKeep:=LSelf as IInterface; end;
  if LSelf=nil then begin GtkTrace('scheme request, no live window: '+AnsiPtrToStr(PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest)))); SchemeFinishNotFound(ARequest); Exit; end;
  if not Assigned(WEBKIT_uri_scheme_request_get_path) then begin SchemeFinishNotFound(ARequest); Exit; end;
  if WEBKIT_uri_scheme_request_get_path(ARequest)=nil then begin SchemeFinishNotFound(ARequest); Exit; end;
  LRaw:=PAnsiChar(WEBKIT_uri_scheme_request_get_path(ARequest)); LPathView:=NormalizeWebviewAssetView(ViewFromPChar(LRaw)); if LPathView.Len=0 then begin SchemeFinishNotFound(ARequest); Exit; end;
  LPath:=LPathView.ToString; if not Assigned(LSelf.FAssetsIntf) then begin SchemeFinishNotFound(ARequest); Exit; end;
  try if not LSelf.FAssetsIntf.TryResolve(LPath,LBytes,LMime) then begin GtkTrace('scheme miss '+LPath+' -> 404'); SchemeFinishNotFound(ARequest); Exit; end; except on E:Exception do begin GtkTrace('scheme resolve ex '+LPath+': '+E.Message+' -> 404'); SchemeFinishNotFound(ARequest); Exit; end; end;
  GtkTrace('scheme hit '+LPath+' ('+IntToStr(Length(LBytes))+'B)'); if LMime='' then LMime:=GuessWebviewMime(LPath);
  LStream:=nil; LBytesObj:=nil;
  if not Assigned(G_bytes_new_with_free_func) or not Assigned(G_memory_input_stream_new_from_bytes) or not Assigned(WEBKIT_uri_scheme_request_finish) then begin SchemeFinishNotFound(ARequest); Exit; end;
  LHolder:=nextpas.core.webview.gtk.pool.AcquireAssetHolder; LHolder^.Bytes:=LBytes;
  try if Length(LHolder^.Bytes)>0 then LBytesObj:=G_bytes_new_with_free_func(@LHolder^.Bytes[0],Length(LHolder^.Bytes),@AssetBufFree,LHolder) else LBytesObj:=G_bytes_new_with_free_func(nil,0,@AssetBufFree,LHolder); except nextpas.core.webview.gtk.pool.ReleaseAssetHolder(LHolder); raise; end;
  if Assigned(LBytesObj) and Assigned(G_memory_input_stream_new_from_bytes) then try LStream:=G_memory_input_stream_new_from_bytes(LBytesObj); except LStream:=nil; end;
  if Assigned(LBytesObj) and Assigned(G_bytes_unref) then try G_bytes_unref(LBytesObj); except end;
  if not Assigned(LStream) then begin SchemeFinishNotFound(ARequest); Exit; end;
  try WEBKIT_uri_scheme_request_finish(ARequest,LStream,Length(LBytes),PAnsiChar(LMime)); except try SchemeFinishNotFound(ARequest); except end; end;
  except on E:Exception do try if Assigned(ARequest) then SchemeFinishNotFound(ARequest); except end; end;
end;
function CompletionMarshalTrampoline(AUserData: Pointer): gboolean; cdecl;
var LRec: PCompletionMarshal absolute AUserData; LSelf: TGtkWebview;
begin LSelf:=TGtkWebview(LRec^.Win); if not LSelf.FClosed then LSelf.SendReceipt(LRec^.FrameId,LRec^.IsError,LRec^.ResultJson,LRec^.Code,LRec^.MsgText); Result:=GLIB_SOURCE_REMOVE; end;
procedure CompletionMarshalDestroy(AUserData: Pointer); cdecl;
begin ReleaseCompletionRec(PCompletionMarshal(AUserData)); end;
function EvalTextOfValueGlobal(AJscValue: Pointer): string;
var LRaw: PAnsiChar;
begin if AJscValue=nil then Exit(''); if (JSC_value_is_null(AJscValue)<>0) or (JSC_value_is_undefined(AJscValue)<>0) then Exit('null'); LRaw:=JSC_value_to_json(AJscValue,0); if LRaw<>nil then begin Result:=AnsiPtrToStr(LRaw); G_free(LRaw); end else begin LRaw:=JSC_value_to_string(AJscValue); Result:=AnsiPtrToStr(LRaw); G_free(LRaw); end; end;
procedure FreeEvalRec(ARec: PEvalRec);
begin if ARec^.Cancel<>nil then G_object_unref(ARec^.Cancel); Dispose(ARec); end;
procedure SettleEvalGlobal(ARec: PEvalRec; AOk: Boolean; const AText: string);
var LErr: EWebviewEvalFailed;
begin if ARec^.Done then begin FreeEvalRec(ARec); Exit; end; ARec^.Done:=True; try if AOk then begin if Assigned(ARec^.Callback) then ARec^.Callback(AText); end else if Assigned(ARec^.OnError) then begin LErr:=EWebviewEvalFailed.Create(AText); try ARec^.OnError(LErr); finally LErr.Free; end; end; finally FreeEvalRec(ARec); end; end;
procedure EvalReadyCb(ASource, ARes, AUserData: Pointer); cdecl;
var LRec: PEvalRec absolute AUserData; LErr: PGError=nil; LJsRes, LVal: Pointer; LOk: Boolean; LText: string;
begin if LRec^.Done then begin GtkTrace('eval late callback after close, disposed'); if LRec^.Owner<>nil then TGtkWebview(LRec^.Owner).RemovePending(LRec); FreeEvalRec(LRec); Exit; end; LVal:=nil; LOk:=False; if GtkLoadInfo().EvalPath=gepEvaluateJavascript then LVal:=WEBKIT_web_view_evaluate_javascript_finish(ASource,ARes,@LErr) else begin LJsRes:=WEBKIT_web_view_run_javascript_finish(ASource,ARes,@LErr); if LJsRes<>nil then LVal:=WEBKIT_javascript_result_get_js_value(LJsRes); end; if LErr<>nil then LText:=AnsiPtrToStr(PAnsiChar(LErr^.Message)) else begin LOk:=True; if LVal<>nil then LText:=EvalTextOfValueGlobal(LVal) else LText:=''; end; if LRec^.Owner<>nil then TGtkWebview(LRec^.Owner).RemovePending(LRec); SettleEvalGlobal(LRec,LOk,LText); end;
type TGtkCompletion=class(TInterfacedObject,IWebviewInvokeCompletion) private FWin:TObject; FCmd:string; FFrameId:Int64; FDone:Boolean; procedure RecordViaIdle(AIsError:Boolean; const AResultJson,ACode,AMessage:string); public constructor Create(AWin:TObject; const ACmd:string; AFrameId:Int64); procedure Ok(const AResultJson:string); procedure Fail(const ACode,AMessage:string); end;
constructor TGtkCompletion.Create(AWin:TObject; const ACmd:string; AFrameId:Int64); begin inherited Create; FWin:=AWin; FCmd:=ACmd; FFrameId:=AFrameId; end;
procedure TGtkCompletion.RecordViaIdle(AIsError:Boolean; const AResultJson,ACode,AMessage:string); var LRec:PCompletionMarshal; begin LRec:=AcquireCompletionRec; LRec^.Win:=FWin; LRec^.FrameId:=FFrameId; LRec^.Cmd:=FCmd; LRec^.IsError:=AIsError; LRec^.ResultJson:=AResultJson; LRec^.Code:=NormalizeInvokeCode(ACode); LRec^.MsgText:=AMessage; G_idle_add_full(G_PRIORITY_DEFAULT,@CompletionMarshalTrampoline,LRec,@CompletionMarshalDestroy); end;
procedure TGtkCompletion.Ok(const AResultJson:string); begin if FDone then raise EWebviewInvalidState.Create('invoke completion already settled'); FDone:=True; RecordViaIdle(False,AResultJson,'',''); end;
procedure TGtkCompletion.Fail(const ACode,AMessage:string); begin if FDone then raise EWebviewInvalidState.Create('invoke completion already settled'); FDone:=True; RecordViaIdle(True,'',ACode,AMessage); end;
constructor TGtkWebview.Create(const AOptions: TWebviewOptions);
var LInfo: TGtkLoadInfo; LResolved: TWebviewOptions;
begin inherited Create; LResolved:=AOptions; if LResolved.SchemeName='' then LResolved.SchemeName:=DEFAULT_WEBVIEW_SCHEME; CheckWebviewOptions(LResolved); FOptions:=LResolved; if not TryLoadGtkWebkit(LInfo) then raise EWebviewBackendUnavailable.Create('WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)'); if not WindowGtkRawInit then raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)'); FOwnerThread:=platform_thread_id; FScale:=1.0; FInvokesIntf:=TWebviewInvokeRegistry.Create; FInvokes:=FInvokesIntf as TObject; FAssetsIntf:=TWebviewAssetsImpl.Create(FOptions.DevServerUrl<>''); FAssets:=FAssetsIntf as TObject; FIdleTags:=specialize TWebviewLiveRegistry<guint>.Create; FPendingEvals:=specialize TWebviewLiveRegistry<PEvalRec>.Create; FOnNavStarted:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFinished:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFailed:=specialize TWebviewLiveRegistry<TWebviewNavFailedHandler>.Create; FOnWindowClosed:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnReady:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnScaleChanged:=specialize TWebviewLiveRegistry<TWebviewScaleHandler>.Create; if FOptions.DevServerUrl<>'' then GtkTrace('dev mode: assets inert, scheme deferred ('+FOptions.DevServerUrl+')'); SetupSessionContext; SetupSchemeAndShell; WireSignals; RegisterLive(Self); FSelfKeepAlive:=Self; if FOptions.InitialUrl<>'' then Navigate(FOptions.InitialUrl) else if FOptions.InitialHtml<>'' then NavigateToString(FOptions.InitialHtml); end;
constructor TGtkWebview.CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions);
var LInfo: TGtkLoadInfo; LResolved: TWebviewOptions;
begin inherited Create; if AParent=nil then raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn'); LResolved:=AOptions; if LResolved.SchemeName='' then LResolved.SchemeName:=DEFAULT_WEBVIEW_SCHEME; CheckWebviewOptions(LResolved); FOptions:=LResolved; if not TryLoadGtkWebkit(LInfo) then raise EWebviewBackendUnavailable.Create('WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)'); if not WindowGtkRawInit then raise EWebviewBackendUnavailable.Create('gtk_init_check failed (no display?)'); FOwnerThread:=platform_thread_id; FScale:=1.0; FInvokesIntf:=TWebviewInvokeRegistry.Create; FInvokes:=FInvokesIntf as TObject; FAssetsIntf:=TWebviewAssetsImpl.Create(FOptions.DevServerUrl<>''); FAssets:=FAssetsIntf as TObject; FIdleTags:=specialize TWebviewLiveRegistry<guint>.Create; FPendingEvals:=specialize TWebviewLiveRegistry<PEvalRec>.Create; FOnNavStarted:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFinished:=specialize TWebviewLiveRegistry<TWebviewNavEventHandler>.Create; FOnNavFailed:=specialize TWebviewLiveRegistry<TWebviewNavFailedHandler>.Create; FOnWindowClosed:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnReady:=specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create; FOnScaleChanged:=specialize TWebviewLiveRegistry<TWebviewScaleHandler>.Create; if FOptions.DevServerUrl<>'' then GtkTrace('dev mode: assets inert, scheme deferred ('+FOptions.DevServerUrl+')'); SetupSessionContext; SetupSchemeAndShellForParent(AParent); WireSignals; RegisterLive(Self); FSelfKeepAlive:=Self; if FOptions.InitialUrl<>'' then Navigate(FOptions.InitialUrl) else if FOptions.InitialHtml<>'' then NavigateToString(FOptions.InitialHtml); end;
destructor TGtkWebview.Destroy;
begin if FOwnsContext and (FContext<>nil) then begin ForgetSchemeContext(FContext); G_object_unref(FContext); FContext:=nil; end; UnregisterLive(Self); FWindow:=nil; FWin:=nil; FView:=nil; FreeAndNil(FOnScaleChanged); FreeAndNil(FOnReady); FreeAndNil(FOnWindowClosed); FreeAndNil(FOnNavFailed); FreeAndNil(FOnNavFinished); FreeAndNil(FOnNavStarted); FreeAndNil(FPendingEvals); FreeAndNil(FIdleTags); inherited Destroy; end;
function TGtkWebview.IsClosed: Boolean; inline; begin Result:=FClosed; end;
procedure TGtkWebview.RequireOpen; begin if FClosed then raise EWebviewClosed.Create('webview window is closed'); end;
procedure TGtkWebview.RemovePending(ARec: PEvalRec); begin if FPendingEvals<>nil then FPendingEvals.Unregister(ARec); end;
procedure TGtkWebview.FireNotifyHandlers(AReg: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>); var I: Integer; begin if AReg=nil then Exit; for I:=0 to AReg.Count-1 do if Assigned(AReg.At(I)) then try AReg.At(I)(); except end; end;
procedure TGtkWebview.SetupSessionContext; begin FOwnsContext:=False; if FOptions.EphemeralSession then FOwnsContext:=True else if FOptions.DataDirectory<>'' then FOwnsContext:=True; end;
function TGtkWebview.ResolveContext: Pointer; var LManager: Pointer; begin if not FOwnsContext then Exit(WEBKIT_web_context_get_default()); if FOptions.EphemeralSession then Result:=WEBKIT_web_context_new_ephemeral() else begin LManager:=WEBKIT_website_data_manager_new('base-data-directory',PAnsiChar(FOptions.DataDirectory),Pointer(nil)); if LManager=nil then raise EWebviewNotInitialized.Create('webkit_website_data_manager_new failed (data directory rejected)'); Result:=WEBKIT_web_context_new_with_website_data_manager(LManager); G_object_unref(LManager); end; FContext:=Result; end;
function TGtkWebview.WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline; begin Result:=DefaultWindowOptions; Result.Title:=AOptions.Title; Result.Width:=AOptions.Width; Result.Height:=AOptions.Height; Result.MinWidth:=AOptions.MinWidth; Result.MinHeight:=AOptions.MinHeight; Result.MaxWidth:=AOptions.MaxWidth; Result.MaxHeight:=AOptions.MaxHeight; Result.Resizable:=AOptions.Resizable; Result.Maximized:=AOptions.Maximized; Result.ParentHandle:=nil; end;
procedure TGtkWebview.HandleWindowEvent(const AEvent: TWindowEvent); begin if FClosed then Exit; case AEvent.Kind of weCloseRequested,weClosed: Close; weScaleChanged,weDpiChanged: begin FScale:=AEvent.NewScale; FireNotifyHandlers(FOnScaleChanged); end; weResized: ; end; end;
procedure TGtkWebview.SetupSchemeAndShell; var LCtx: Pointer; LWinOpts: TWindowOptions; begin LCtx:=ResolveContext; if (FOptions.DevServerUrl='') and (not SchemeContextRegistered(LCtx)) then begin WEBKIT_web_context_register_uri_scheme(LCtx,PAnsiChar(FOptions.SchemeName),@SchemeRequestCb,nil,nil); RememberSchemeContext(LCtx); end; FView:=WEBKIT_web_view_new_with_context(LCtx); if FView=nil then raise EWebviewNotInitialized.Create('webkit_web_view_new_with_context returned nil'); if FWindow=nil then begin LWinOpts:=WindowOptionsOf(FOptions); FWindow:=nextpas.core.window.gtk3.CreateWindowGtk(LWinOpts); FOwnsWindow:=True; FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); FWindow.OnEvent(@HandleWindowEvent); end else begin FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Parent window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); end; if FOptions.DebugTools then WEBKIT_settings_set_enable_developer_extras(WEBKIT_web_view_get_settings(FView),1); end;
procedure TGtkWebview.SetupSchemeAndShellForParent(const AParent: IWindow); var LCtx: Pointer; begin if AParent=nil then raise EWebviewInvalidState.Create('Parent window must not be nil for CreateOn'); FWindow:=AParent; FOwnsWindow:=False; FWindow.OnEvent(@HandleWindowEvent); LCtx:=ResolveContext; if (FOptions.DevServerUrl='') and (not SchemeContextRegistered(LCtx)) then begin WEBKIT_web_context_register_uri_scheme(LCtx,PAnsiChar(FOptions.SchemeName),@SchemeRequestCb,nil,nil); RememberSchemeContext(LCtx); end; FView:=WEBKIT_web_view_new_with_context(LCtx); if FView=nil then raise EWebviewNotInitialized.Create('webkit_web_view_new_with_context returned nil'); FWin:=nextpas.core.window.gtk3.WindowGtkRawHandleOf(FWindow); if FWin=nil then raise EWebviewNotInitialized.Create('Parent window handle is nil'); nextpas.core.window.gtk3.WindowGtkRawContainerAdd(FWin,FView); if FView<>nil then nextpas.core.gtk3.ffi.gtk_widget_show(FView); if FOptions.DebugTools then WEBKIT_settings_set_enable_developer_extras(WEBKIT_web_view_get_settings(FView),1); end;
function TGtkWebview.GetWindow: IWindow; inline; begin Result:=FWindow; end;
procedure TGtkWebview.AddUserScript(const ASource: string); var LUcm, LScript: Pointer; begin LUcm:=WEBKIT_web_view_get_user_content_manager(FView); LScript:=WEBKIT_user_script_new(PAnsiChar(ASource),WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,nil,nil); WEBKIT_user_content_manager_add_script(LUcm,LScript); WEBKIT_user_script_unref(LScript); end;
procedure TGtkWebview.WireSignals; begin g_signal_connect_data(FWin,'destroy',@DestroyCb,Self,nil,0); g_signal_connect_data(WEBKIT_web_view_get_user_content_manager(FView),'script-message-received::npw',@ScriptMessageCb,Self,nil,0); WEBKIT_user_content_manager_register_script_message_handler(WEBKIT_web_view_get_user_content_manager(FView),'npw'); AddUserScript(NPW_BRIDGE_SCRIPT); g_signal_connect_data(FView,'load-changed',@LoadChangedCb,Self,nil,0); g_signal_connect_data(FView,'load-failed',@LoadFailedCb,Self,nil,0); g_signal_connect_data(FView,'notify::scale-factor',@ScaleNotifyCb,Self,nil,0); end;
function TGtkWebview.CurrentUri: string; var LP: PAnsiChar; begin LP:=WEBKIT_web_view_get_uri(FView); if LP<>nil then Result:=AnsiPtrToStr(LP) else Result:=''; end;
procedure TGtkWebview.FireReadyOnce; var I: Integer; begin if FReadyFired or FClosed then Exit; FReadyFired:=True; if FOnReady<>nil then for I:=0 to FOnReady.Count-1 do if Assigned(FOnReady.At(I)) then try FOnReady.At(I)(); except end; end;
class function TGtkWebview.MapInvokeCodeSafe(E: Exception): string; begin if E is EWebviewInvokeError then Result:=NormalizeInvokeCode(EWebviewInvokeError(E).Code) else Result:=NPW_CODE_HANDLER_ERROR; end;
procedure TGtkWebview.DispatchFrame(const AFrame: TWebviewFrame); var LReg: TWebviewInvokeRegistry; LIsAsync:Boolean; LSync: TWebviewInvokeSyncHandler; LAsync:TWebviewInvokeAsyncHandler; LResultJson:string; LCompletion:IWebviewInvokeCompletion; begin RequireOpen; LReg:=TWebviewInvokeRegistry(FInvokes); if not LReg.Find(AFrame.Cmd,LIsAsync,LSync,LAsync) then begin SendReceipt(AFrame.Id,True,'',NPW_CODE_HANDLER_MISSING,'no handler registered for cmd'); Exit; end; if LIsAsync then begin LCompletion:=TGtkCompletion.Create(Self,AFrame.Cmd,AFrame.Id); try LAsync(AFrame.PayloadJson,LCompletion); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end; end else begin try LResultJson:=LSync(AFrame.PayloadJson); SendReceipt(AFrame.Id,False,LResultJson,'',''); except on E:Exception do SendReceipt(AFrame.Id,True,'',MapInvokeCodeSafe(E),E.Message); end; end; end;
procedure TGtkWebview.SendReceipt(AFrameId:Int64; AIsError:Boolean; const AResultJson,ACode,AMessage:string); var LJs:string; begin if FClosed then Exit; if AIsError then LJs:=BuildRejectScript(AFrameId,ACode,AMessage) else LJs:=BuildResolveScript(AFrameId,AResultJson); if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(FView,PAnsiChar(LJs),Length(LJs),nil,nil,nil,nil,nil) else WEBKIT_web_view_run_javascript(FView,PAnsiChar(LJs),nil,nil,nil); end;
procedure TGtkWebview.PostIdle(AProc: TWebviewProcRef); var LRec:PIdleRec; LTag:guint; begin LRec:=AcquireIdleRec; LRec^.Proc:=AProc; LTag:=G_idle_add_full(G_PRIORITY_DEFAULT,@IdleTrampoline,LRec,@IdleDestroy); if FIdleTags<>nil then FIdleTags.Register(LTag); end;
procedure TGtkWebview.DropIdlePendings; var I:Integer; LCtx,LSrc:Pointer; begin if FIdleTags=nil then Exit; LCtx:=G_main_context_default(); for I:=0 to FIdleTags.Count-1 do begin if LCtx=nil then Break; LSrc:=G_main_context_find_source_by_id(LCtx,FIdleTags.At(I)); if LSrc<>nil then G_source_remove(FIdleTags.At(I)); end; FIdleTags.Clear; end;
procedure TGtkWebview.SettlePendingOnClose; var I:Integer; LRec:PEvalRec; LErr:EWebviewEvalFailed; begin if FPendingEvals=nil then Exit; for I:=0 to FPendingEvals.Count-1 do begin LRec:=FPendingEvals.At(I); if not LRec^.Done then begin LRec^.Done:=True; if Assigned(LRec^.OnError) then begin LErr:=EWebviewEvalFailed.Create('window closed'); try LRec^.OnError(LErr); finally LErr.Free; end; end; if LRec^.Cancel<>nil then begin G_cancellable_cancel(LRec^.Cancel); LRec^.Cancel:=nil; end; end; end; FPendingEvals.Clear; end;
procedure TGtkWebview.HandleNativeDestroy; begin if FClosed then Exit; FClosed:=True; UnregisterLive(Self); SettlePendingOnClose; DropIdlePendings; FireNotifyHandlers(FOnWindowClosed); if GtkLiveWindowCount=0 then WindowGtkRawQuitMainLoop; FView:=nil; FWin:=nil; FWindow:=nil; FSelfKeepAlive:=nil; end;
procedure TGtkWebview.Close; begin if FClosed then Exit; FClosed:=True; UnregisterLive(Self); SettlePendingOnClose; DropIdlePendings; FireNotifyHandlers(FOnWindowClosed); if FOwnsWindow then begin if FWindow<>nil then try FWindow.Close; except end; if (FView<>nil) and (FWindow=nil) and (FWin<>nil) then GTK_widget_destroy(FWin); end else begin if FView<>nil then GTK_widget_destroy(FView); end; FView:=nil; if FOwnsWindow then begin FWin:=nil; FWindow:=nil; end; if GtkLiveWindowCount=0 then WindowGtkRawQuitMainLoop; FSelfKeepAlive:=nil; end;
procedure TGtkWebview.Post(AProc: TWebviewProcRef); inline; begin PostIdle(AProc); end;
procedure TGtkWebview.Post(AProc: TWebviewProcMethod); inline; begin PostIdle(procedure begin AProc(); end); end;
procedure TGtkWebview.Post(AProc: TWebviewProc); inline; begin PostIdle(procedure begin AProc(); end); end;
function TGtkWebview.IsOnMainThread: Boolean; inline; begin Result:=platform_thread_id=FOwnerThread; end;
function TGtkWebview.GetDispatcher: IWebviewDispatcher; inline; begin Result:=Self; end;
procedure TGtkWebview.Show; begin RequireOpen; if FWindow<>nil then FWindow.Show else WindowGtkRawShow(FWin); end;
procedure TGtkWebview.Hide; begin RequireOpen; if FWindow<>nil then FWindow.Hide else WindowGtkRawHide(FWin); end;
function TGtkWebview.IsVisible: Boolean; begin RequireOpen; if FWindow<>nil then Exit(FWindow.IsVisible); Result:=GTK_widget_get_visible(FWin)<>0; end;
procedure TGtkWebview.Focus; begin RequireOpen; if FView<>nil then WindowGtkRawFocus(FView) else if FWindow<>nil then FWindow.Focus; end;
procedure TGtkWebview.SetTitle(const ATitle:string); begin RequireOpen; if FWindow<>nil then FWindow.SetTitle(ATitle) else WindowGtkRawSetTitle(FWin,ATitle); end;
function TGtkWebview.GetTitle:string; var LRaw:PAnsiChar; begin RequireOpen; if FWindow<>nil then Exit(FWindow.GetTitle); LRaw:=GTK_window_get_title(FWin); if LRaw<>nil then Result:=AnsiPtrToStr(LRaw) else Result:=''; end;
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
function TGtkWebview.GetUserAgent:string; var LRaw:PAnsiChar; begin RequireOpen; LRaw:=nil; G_object_get(WEBKIT_web_view_get_settings(FView),'user-agent',@LRaw,Pointer(nil)); if LRaw<>nil then begin Result:=AnsiPtrToStr(LRaw); G_free(LRaw); end else Result:=''; end;
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
procedure TGtkWebview.Eval(const AJavascript:string; ACallback:TWebviewEvalCallback; AOnError:TWebviewEvalErrorCallback); var LRec:PEvalRec; begin RequireOpen; New(LRec); LRec^.Callback:=ACallback; LRec^.OnError:=AOnError; LRec^.Done:=False; LRec^.Cancel:=G_cancellable_new(); LRec^.Owner:=Self; if FPendingEvals<>nil then FPendingEvals.Register(LRec); GtkTrace('eval dispatch: '+Copy(AJavascript,1,80)); if GtkLoadInfo().EvalPath=gepEvaluateJavascript then WEBKIT_web_view_evaluate_javascript(FView,PAnsiChar(AJavascript),Length(AJavascript),nil,nil,LRec^.Cancel,@EvalReadyCb,LRec) else WEBKIT_web_view_run_javascript(FView,PAnsiChar(AJavascript),LRec^.Cancel,@EvalReadyCb,LRec); end;
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
