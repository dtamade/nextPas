unit nextpas.core.webview.gtk;

{** @desc Linux 后端：GTK3 WebKit 组合后端（has-a IWindow）。

       M4 重构：TGtkWebview 持有 FWindow: IWindow（由 window.factory
       自建或由 CreateWebviewOn 复用 Parent），WebKitWebView 作为
       child 通过 gtk_container_add(FWindow GtkWidget*, FView) 挂载。
       窗口事件经 FWindow.OnEvent 转译（weResized→同步大小、
       weScaleChanged→OnScaleChanged、weCloseRequested→Close）。
       引擎 child 挂载在 FWindow 之后；Show 前 NativeHandle 为 nil
       场景下延迟至首个 weResized 挂载（风险1）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.webview.base,
  nextpas.core.window.base,
  nextpas.core.window.intf,
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
    FWindow: IWindow;
    FOwnsWindow: Boolean;
    FView, FContext: Pointer;
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
    FViewAttached: Boolean;

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
    function GetGtkContainer: Pointer;
    procedure EnsureViewAttached;
    procedure HandleWindowEvent(const AEvent: TWindowEvent);
    procedure CommonInit(const AOptions: TWebviewOptions; AParent: IWindow; AOwnsWindow: Boolean);
  protected
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
    function IsOnMainThread: Boolean; inline;
    function GetWindow: IWindow; virtual;
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
    procedure OnScaleChanged(AHandler: TWebviewScaleHandler); overload; virtual;
    procedure OnScaleChanged(AHandler: TWebviewScaleMethod); overload; virtual;
    procedure OnScaleChanged(AHandler: TWebviewScaleProc); overload; virtual;
    function GetInvokes: IWebviewInvokeRegistry;
    function GetAssets: IWebviewAssets;
  public
    constructor Create(const AOptions: TWebviewOptions); virtual;
    constructor CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions); virtual;
    destructor Destroy; override;
  end;

function GtkLiveWindowCount: Integer;

implementation
uses
  nextpas.core.window.factory;

var
  GLiveWindows: array of TGtkWebview;
  GLiveWindowsCount: Integer = 0;
  GRegisteredSchemeCtxs: array of Pointer;
  GRegisteredSchemeCtxsCount: Integer = 0;
  GGtkDebugChecked: Boolean = False;
  GGtkDebugEnabled: Boolean = False;

procedure GrowLiveWindows; inline;
begin
  if GLiveWindowsCount = Length(GLiveWindows) then
    SetLength(GLiveWindows, WebviewGrowCapacity(Length(GLiveWindows)));
end;

procedure GrowSchemeCtxs; inline;
begin
  if GRegisteredSchemeCtxsCount = Length(GRegisteredSchemeCtxs) then
    SetLength(GRegisteredSchemeCtxs, WebviewGrowCapacity(Length(GRegisteredSchemeCtxs)));
end;

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
  for I := 0 to GRegisteredSchemeCtxsCount - 1 do
    if GRegisteredSchemeCtxs[I] = ACtx then
      Exit(True);
  Result := False;
end;

procedure RememberSchemeContext(ACtx: Pointer);
begin
  GrowSchemeCtxs;
  GRegisteredSchemeCtxs[GRegisteredSchemeCtxsCount] := ACtx;
  Inc(GRegisteredSchemeCtxsCount);
end;

procedure ForgetSchemeContext(ACtx: Pointer);
var
  I, J: Integer;
begin
  for I := 0 to GRegisteredSchemeCtxsCount - 1 do
    if GRegisteredSchemeCtxs[I] = ACtx then
    begin
      for J := I to GRegisteredSchemeCtxsCount - 2 do
        GRegisteredSchemeCtxs[J] := GRegisteredSchemeCtxs[J + 1];
      Dec(GRegisteredSchemeCtxsCount);
      if GRegisteredSchemeCtxsCount < Length(GRegisteredSchemeCtxs) then
        GRegisteredSchemeCtxs[GRegisteredSchemeCtxsCount] := nil;
      Exit;
    end;
end;

function GtkLiveWindowCount: Integer;
var
  I, LCnt: Integer;
begin
  LCnt := 0;
  for I := 0 to GLiveWindowsCount - 1 do
    if not GLiveWindows[I].FClosed then
      Inc(LCnt);
  Result := LCnt;
end;

procedure RegisterLive(AWin: TGtkWebview);
begin
  GrowLiveWindows;
  GLiveWindows[GLiveWindowsCount] := AWin;
  Inc(GLiveWindowsCount);
end;

procedure UnregisterLive(AWin: TGtkWebview);
var
  I, J: Integer;
begin
  for I := 0 to GLiveWindowsCount - 1 do
    if GLiveWindows[I] = AWin then
    begin
      for J := I to GLiveWindowsCount - 2 do
        GLiveWindows[J] := GLiveWindows[J + 1];
      Dec(GLiveWindowsCount);
      if GLiveWindowsCount < Length(GLiveWindows) then
        GLiveWindows[GLiveWindowsCount] := nil;
      Exit;
    end;
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

function IdleTrampoline(AUserData: Pointer): gboolean; cdecl;
var
  LRec: PIdleRec absolute AUserData;
begin
  try
    LRec^.Proc();
  except
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
  LNew := LSelf.GetZoom;
  if Abs(LNew - LSelf.FScale) > 1e-9 then
  begin
    LSelf.FScale := LNew;
    for I := 0 to LSelf.FOnScaleChangedCount - 1 do
      LSelf.FOnScaleChanged[I](LNew);
  end;
end;

var
  GSchemeErrQuark: GQuark = 0;

function LiveWindowForView(AView: Pointer): TGtkWebview; inline;
var
  I: Integer;
begin
  if AView <> nil then
  begin
    if GLiveWindowsCount = 1 then
    begin
      if (not GLiveWindows[0].FClosed) and (GLiveWindows[0].FView = AView) then
        Exit(GLiveWindows[0]);
      Exit(nil);
    end;
    for I := 0 to GLiveWindowsCount - 1 do
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
  for I := GLiveWindowsCount - 1 downto 0 do
    if not GLiveWindows[I].FClosed then
      Exit(GLiveWindows[I]);
  Result := nil;
end;

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
    LSelf := LatestLiveWebview;
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
    LRaw := JSC_value_to_string(AJscValue);
    Result := StrPas(LRaw);
    G_free(LRaw);
  end;
end;

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

procedure TGtkWebview.CommonInit(const AOptions: TWebviewOptions; AParent: IWindow; AOwnsWindow: Boolean);
var
  LInfo: TGtkLoadInfo;
  LResolved: TWebviewOptions;
begin
  LResolved := AOptions;
  if LResolved.SchemeName = '' then
    LResolved.SchemeName := DEFAULT_WEBVIEW_SCHEME;
  CheckWebviewOptions(LResolved);
  FOptions := LResolved;
  if not TryLoadGtkWebkit(LInfo) then
    raise EWebviewBackendUnavailable.Create(
      'WebKitGTK runtime not found (probed libwebkit2gtk-4.1.so.0 / 4.0.so.0)');
  FOwnerThread := platform_thread_id;
  FScale := 1.0;
  FInvokesIntf := TWebviewInvokeRegistry.Create;
  FInvokes := FInvokesIntf as TObject;
  FAssetsIntf := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FAssets := FAssetsIntf as TObject;
  if FOptions.DevServerUrl <> '' then
    GtkTrace('dev mode: assets inert, scheme deferred (' +
      FOptions.DevServerUrl + ')');
  if AParent <> nil then
  begin
    FWindow := AParent;
    FOwnsWindow := False;
  end
  else
  begin
    FWindow := CreateWindowOf(DefaultWindowKind, WindowOptionsOf(FOptions));
    FOwnsWindow := AOwnsWindow;
  end;
  FWindow.OnEvent(@HandleWindowEvent);
  SetupSessionContext;
  SetupSchemeAndShell;
  WireSignals;
  RegisterLive(Self);
  FSelfKeepAlive := Self;
  if FOptions.InitialUrl <> '' then
    Navigate(FOptions.InitialUrl)
  else if FOptions.InitialHtml <> '' then
    NavigateToString(FOptions.InitialHtml);
end;

constructor TGtkWebview.Create(const AOptions: TWebviewOptions);
begin
  inherited Create;
  CommonInit(AOptions, nil, True);
end;

constructor TGtkWebview.CreateOn(const AParent: IWindow; const AOptions: TWebviewOptions);
begin
  inherited Create;
  if AParent = nil then
    raise EWebviewInvalidState.Create('CreateOn: AParent must not be nil');
  CommonInit(AOptions, AParent, False);
end;

destructor TGtkWebview.Destroy;
begin
  if FOwnsContext and (FContext <> nil) then
  begin
    ForgetSchemeContext(FContext);
    G_object_unref(FContext);
    FContext := nil;
  end;
  UnregisterLive(Self);
  inherited Destroy;
end;

function TGtkWebview.GetWindow: IWindow;
begin
  Result := FWindow;
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
    FOwnsContext := True
  else if FOptions.DataDirectory <> '' then
    FOwnsContext := True;
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
    LManager := WEBKIT_website_data_manager_new('base-data-directory',
      PAnsiChar(FOptions.DataDirectory), Pointer(nil));
    if LManager = nil then
      raise EWebviewNotInitialized.Create(
        'webkit_website_data_manager_new failed (data directory rejected)');
    Result := WEBKIT_web_context_new_with_website_data_manager(LManager);
    G_object_unref(LManager);
  end;
  FContext := Result;
end;

function TGtkWebview.GetGtkContainer: Pointer;
var
  LPriv: IWindowPrivateHandle;
begin
  Result := nil;
  if FWindow = nil then Exit(nil);
  if Supports(FWindow, IWindowPrivateHandle, LPriv) then
    Result := LPriv.GetHandle
  else
    Result := Pointer(FWindow.NativeHandle);
end;

procedure TGtkWebview.EnsureViewAttached;
var
  LContainer: Pointer;
begin
  if FViewAttached or (FView = nil) or (FWindow = nil) or FClosed then Exit;
  LContainer := GetGtkContainer;
  if LContainer = nil then Exit;
  GTK_container_add(LContainer, FView);
  FViewAttached := True;
  if FWindow.IsVisible then
    GTK_widget_show_all(FView);
end;

procedure TGtkWebview.HandleWindowEvent(const AEvent: TWindowEvent);
var
  I: Integer;
  LNew: Double;
begin
  if FClosed then Exit;
  case AEvent.Kind of
    weResized:
      begin
        EnsureViewAttached;
        if (FView <> nil) and Assigned(GTK_widget_set_size_request) then
          GTK_widget_set_size_request(FView, AEvent.Width, AEvent.Height);
      end;
    weScaleChanged:
      begin
        LNew := AEvent.NewScale;
        if Abs(LNew - FScale) > 1e-9 then
        begin
          FScale := LNew;
          for I := 0 to FOnScaleChangedCount - 1 do
            FOnScaleChanged[I](LNew);
        end;
      end;
    weCloseRequested:
      begin
        Close;
      end;
    else ;
  end;
end;

procedure TGtkWebview.SetupSchemeAndShell;
var
  LCtx: Pointer;
begin
  LCtx := ResolveContext;
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
  EnsureViewAttached;
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
  g_signal_connect_data(
    WEBKIT_web_view_get_user_content_manager(FView),
    'script-message-received::npw', @ScriptMessageCb, Self, nil, 0);
  WEBKIT_user_content_manager_register_script_message_handler(
    WEBKIT_web_view_get_user_content_manager(FView), 'npw');
  AddUserScript(NPW_BRIDGE_SCRIPT);
  g_signal_connect_data(FView, 'load-changed', @LoadChangedCb, Self, nil, 0);
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
  FSelfKeepAlive := nil;
end;

procedure TGtkWebview.Close;
var
  I: Integer;
  LRec: PEvalRec;
  LErr: EWebviewEvalFailed;
begin
  if FClosed then
    Exit;
  FClosed := True;
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
      if LRec^.Cancel <> nil then
      begin
        G_cancellable_cancel(LRec^.Cancel);
        LRec^.Cancel := nil;
      end;
    end;
  end;
  FPendingCount := 0;
  DropIdlePendings;
  FireNotifyHandlers(FOnWindowClosed);
  if (FView <> nil) then
  begin
    if not FOwnsWindow then
      GTK_widget_destroy(FView);
    FView := nil;
    FViewAttached := False;
  end;
  if FOwnsWindow and (FWindow <> nil) and not FWindow.IsClosed then
    FWindow.Close;
  FSelfKeepAlive := nil;
end;

procedure TGtkWebview.Post(AProc: TWebviewProcRef);
begin
  if (FWindow <> nil) and (FWindow.Dispatcher <> nil) then
    FWindow.Dispatcher.Post(AProc)
  else
    PostIdle(AProc);
end;

procedure TGtkWebview.Post(AProc: TWebviewProcMethod);
begin
  Post(
    procedure
    begin
      AProc();
    end);
end;

procedure TGtkWebview.Post(AProc: TWebviewProc);
begin
  Post(
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
  if FView <> nil then
    Result := TWebviewNativeHandle(FView)
  else if (FWindow <> nil) then
    Result := TWebviewNativeHandle(Pointer(FWindow.NativeHandle))
  else
    Result := nil;
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
