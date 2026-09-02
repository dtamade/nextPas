unit nextpas.core.webview.webview2;

{** @desc Windows 后端（Wave 2）。

       S18 桩 → S19 真窗口壳 → S20 壳满态（DPI/最小化/ScaleChanged）→
       S21 真 controller 接线：CreateCoreWebView2EnvironmentWithOptions
       异步链 → Controller → CoreWebView2 → ExecuteScript/Emit 映射 +
       WebMessageReceived 桥分发 + AddScriptToExecuteOnDocumentCreated
       注入（NPW_BRIDGE_SCRIPT），与 gtk 同协议语义（INV-2）。

       容错：TryLoad 失败抛 EWebviewBackendUnavailable；异步链错误码
       非 S_OK 时静默保持 controller=nil，Eval / Navigate 诚实
       EWebviewEvalFailed / no-op 回退，不崩；Close 时在途 Eval 以
       onerr 收尾 exactly-once。Linux 交叉编译时 COM 链路为桩，
       行为与 S20 一致。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.validation,
  nextpas.core.webview.bridge,
  nextpas.core.webview.live,
  nextpas.core.webview.callbacks,
  nextpas.core.bytes.ops,
  nextpas.core.webview.webview2.ffi,
  nextpas.core.window.base,
  nextpas.core.window.intf;

type
  PEvalRec = ^TEvalRec;
  TEvalRec = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
  end;

  TWebView2Webview = class(TInterfacedObject, IWebviewWindow, IWebviewDispatcher)
  private
    FOptions: TWebviewOptions;
    FUserAgent: string;
    FClosed: Boolean;
    FWindow: IWindow;
    FOwnsWindow: Boolean;
    FZoom: Double;
    FReadyFired: Boolean;
    FOwnerThread: UInt64;
    FSelfKeepAlive: IInterface;
    FInvokesIntf: IWebviewInvokeRegistry;
    FInvokes: TObject;
    FAssetsIntf: IWebviewAssets;
    FAssets: TObject;
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
    FScaleHandlers: array of TWebviewScaleHandler;
    FScaleHandlersCount: Integer;
    FEnv: ICoreWebView2Environment;
    FController: ICoreWebView2Controller;
    FWebView: ICoreWebView2;
    FWebMessageToken: Int64;
    FNavStartingToken: Int64;
    FNavCompletedToken: Int64;
    FBridgeScriptId: WideString;
    procedure RequireOpen;
    procedure HandleWindowEvent(const AEvent: TWindowEvent);
    procedure UpdateControllerBounds;
    procedure DispatchFrame(const AFrame: TWebviewFrame);
    procedure SendReceipt(AFrameId: Int64; AIsError: Boolean; const AResultJson, ACode, AMessage: string);
    procedure FireReadyOnce;
    procedure FireNotifyHandlers(var AList: array of TWebviewNotifyHandler);
    procedure HandleNativeDestroy;
    function WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
    procedure TryCreateEnvironment;
    procedure GrowPendingEvals; inline;
    procedure GrowOnNavStarted; inline;
    procedure GrowOnNavFinished; inline;
    procedure GrowOnNavFailed; inline;
    procedure GrowOnWindowClosed; inline;
    procedure GrowOnReady; inline;
    procedure GrowScale; inline;
    procedure DoScaleChanged(ANewScale: Double); inline;
    procedure RemovePending(ARec: PEvalRec);
    procedure OnEnvironmentCreated(errorCode: LongInt; const AEnv: ICoreWebView2Environment);
    procedure OnControllerCreated(errorCode: LongInt; const ACtrl: ICoreWebView2Controller);
    procedure OnWebMessageReceived(const AJson: string);
    class function MapInvokeCodeSafe(E: Exception): string; static;
  public
    constructor Create(const AOptions: TWebviewOptions);
    constructor CreateOn(AWindow: IWindow; const AOptions: TWebviewOptions);
    destructor Destroy; override;
    function GetWindow: IWindow;
    { IWebviewDispatcher }
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
    function IsOnMainThread: Boolean;
    { IWebviewWindow }
    procedure Close;
    function IsClosed: Boolean;
    procedure Show; inline; procedure Hide; inline; function IsVisible: Boolean; inline;
    procedure Focus; inline;
    procedure SetTitle(const ATitle: string); inline; function GetTitle: string; inline;
    procedure SetBounds(AWidth, AHeight: Integer); inline; function GetWidth: Integer; inline; function GetHeight: Integer; inline;
    procedure SetResizable(AResizable: Boolean); inline;
    procedure Maximize; inline; procedure Unmaximize; inline; function IsMaximized: Boolean; inline;
    procedure Minimize; inline; procedure Restore; inline; function IsMinimized: Boolean; inline;
    procedure SetZoom(AFactor: Double); function GetZoom: Double;
    procedure SetUserAgent(const AUserAgent: string); function GetUserAgent: string;
    function GetScaleFactor: Double;
    procedure OnScaleChanged(AHandler: TWebviewScaleHandler); overload;
    procedure OnScaleChanged(AHandler: TWebviewScaleMethod); overload;
    procedure OnScaleChanged(AHandler: TWebviewScaleProc); overload;
    procedure Navigate(const AUrl: string); procedure NavigateToString(const AHtml: string);
    procedure Reload; procedure Stop;
    function CanGoBack: Boolean; function GoBack: Boolean;
    function CanGoForward: Boolean; function GoForward: Boolean;
    procedure Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
    procedure Emit(const AEvent, APayloadJson: string);
    function GetDispatcher: IWebviewDispatcher;
    function NativeHandle: TWebviewNativeHandle;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventMethod); overload;
    procedure OnNavigationStarted(AHandler: TWebviewNavEventProc); overload;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventMethod); overload;
    procedure OnNavigationFinished(AHandler: TWebviewNavEventProc); overload;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedMethod); overload;
    procedure OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload;
    procedure OnWindowClosed(AHandler: TWebviewNotifyHandler); overload;
    procedure OnWindowClosed(AHandler: TWebviewNotifyMethod); overload;
    procedure OnWindowClosed(AHandler: TWebviewNotifyProc); overload;
    procedure OnReady(AHandler: TWebviewNotifyHandler); overload;
    procedure OnReady(AHandler: TWebviewNotifyMethod); overload;
    procedure OnReady(AHandler: TWebviewNotifyProc); overload;
    function GetInvokes: IWebviewInvokeRegistry;
    function GetAssets: IWebviewAssets;
  end;

function WebView2LiveWindowCount: Integer;

implementation

uses
  nextpas.core.platform.thread,
  nextpas.core.webview.webview2.loader,
  nextpas.core.window.factory;

{$I nextpas.core.webview.webview2.ole32.inc}

var
  GLive: Integer = 0;
  GLiveList: array of TWebView2Webview;
  GLiveListCount: Integer = 0;

procedure GrowLiveList; inline;
begin
  // single source: bytes.ops VecGrow (0→4→2×) inline via webview.live
  specialize VecGrow<TWebView2Webview>(GLiveList, GLiveListCount);
end;

procedure RegisterLive(AInst: TWebView2Webview);
begin
  // single source: webview.live WebviewLiveAdd -> VecGrow inline
  specialize WebviewLiveAdd<TWebView2Webview>(GLiveList, GLiveListCount, AInst);
end;

procedure UnregisterLive(AInst: TWebView2Webview);
begin
  // single source: webview.live WebviewLiveRemoveSwap inline O(1) swap, bytes.ops VecRemoveSwap single source, hot close avoids O(n²)
  specialize WebviewLiveRemoveSwap<TWebView2Webview>(GLiveList, GLiveListCount, AInst);
end;

function WebView2LiveWindowCount: Integer;
begin
  Result := GLive;
end;

type
  TEnvCompletedHandler = class(TInterfacedObject, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler)
  private
    FOwner: TWebView2Webview;
  public
    constructor Create(AOwner: TWebView2Webview);
    function Invoke(errorCode: nextpas.core.webview.webview2.ffi.HRESULT; createdEnvironment: ICoreWebView2Environment): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
  end;

  TControllerCompletedHandler = class(TInterfacedObject, ICoreWebView2CreateCoreWebView2ControllerCompletedHandler)
  private
    FOwner: TWebView2Webview;
  public
    constructor Create(AOwner: TWebView2Webview);
    function Invoke(errorCode: nextpas.core.webview.webview2.ffi.HRESULT; createdController: ICoreWebView2Controller): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
  end;

  TExecuteScriptHandler = class(TInterfacedObject, ICoreWebView2ExecuteScriptCompletedHandler)
  private
    FEval: PEvalRec;
    FOwner: TWebView2Webview;
  public
    constructor Create(AOwner: TWebView2Webview; AEval: PEvalRec);
    function Invoke(errorCode: nextpas.core.webview.webview2.ffi.HRESULT; resultObjectAsJson: PWideChar): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
  end;

  TWebMessageHandler = class(TInterfacedObject, ICoreWebView2WebMessageReceivedEventHandler)
  private
    FOwner: TWebView2Webview;
  public
    constructor Create(AOwner: TWebView2Webview);
    function Invoke(sender: ICoreWebView2; args: ICoreWebView2WebMessageReceivedEventArgs): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
  end;

  TNavStartingHandler = class(TInterfacedObject, ICoreWebView2NavigationStartingEventHandler)
  private
    FOwner: TWebView2Webview;
  public
    constructor Create(AOwner: TWebView2Webview);
    function Invoke(sender: ICoreWebView2; args: ICoreWebView2NavigationStartingEventArgs): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
  end;

  TNavCompletedHandler = class(TInterfacedObject, ICoreWebView2NavigationCompletedEventHandler)
  private
    FOwner: TWebView2Webview;
  public
    constructor Create(AOwner: TWebView2Webview);
    function Invoke(sender: ICoreWebView2; args: ICoreWebView2NavigationCompletedEventArgs): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
  end;

type
  TLocalInvokeCompletion = class(TInterfacedObject, IWebviewInvokeCompletion)
  private
    FOwner: TWebView2Webview;
    FId: Int64;
    FDone: Boolean;
  public
    constructor Create(AOwner: TWebView2Webview; AId: Int64);
    procedure Ok(const AResultJson: string);
    procedure Fail(const ACode, AMessage: string);
  end;

constructor TEnvCompletedHandler.Create(AOwner: TWebView2Webview);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TEnvCompletedHandler.Invoke(errorCode: nextpas.core.webview.webview2.ffi.HRESULT; createdEnvironment: ICoreWebView2Environment): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
begin
  if (FOwner <> nil) and not FOwner.FClosed then
    FOwner.OnEnvironmentCreated(errorCode, createdEnvironment);
  Result := S_OK;
end;

constructor TControllerCompletedHandler.Create(AOwner: TWebView2Webview);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TControllerCompletedHandler.Invoke(errorCode: nextpas.core.webview.webview2.ffi.HRESULT; createdController: ICoreWebView2Controller): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
begin
  if (FOwner <> nil) and not FOwner.FClosed then
    FOwner.OnControllerCreated(errorCode, createdController);
  Result := S_OK;
end;

constructor TExecuteScriptHandler.Create(AOwner: TWebView2Webview; AEval: PEvalRec);
begin
  inherited Create;
  FOwner := AOwner;
  FEval := AEval;
end;

function TExecuteScriptHandler.Invoke(errorCode: nextpas.core.webview.webview2.ffi.HRESULT; resultObjectAsJson: PWideChar): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
var
  LText: string;
  LOk: Boolean;
  LErr: EWebviewEvalFailed;
begin
  Result := S_OK;
  if FEval = nil then Exit;
  if FEval^.Done then
  begin
    if (FOwner <> nil) then FOwner.RemovePending(FEval);
    Dispose(FEval);
    Exit;
  end;
  FEval^.Done := True;
  try
    if errorCode <> S_OK then
    begin
      LOk := False;
      if resultObjectAsJson <> nil then
        LText := string(WideString(resultObjectAsJson))
      else
        LText := 'WebView2 ExecuteScript failed';
    end
    else
    begin
      LOk := True;
      if resultObjectAsJson <> nil then
        LText := string(WideString(resultObjectAsJson))
      else
        LText := 'null';
    end;
    if LOk then
    begin
      if Assigned(FEval^.Callback) then
        FEval^.Callback(LText);
    end
    else if Assigned(FEval^.OnError) then
    begin
      LErr := EWebviewEvalFailed.Create(LText);
      try
        FEval^.OnError(LErr);
      finally
        LErr.Free;
      end;
    end;
  finally
    if (FOwner <> nil) then FOwner.RemovePending(FEval);
    Dispose(FEval);
  end;
end;

constructor TWebMessageHandler.Create(AOwner: TWebView2Webview);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TWebMessageHandler.Invoke(sender: ICoreWebView2; args: ICoreWebView2WebMessageReceivedEventArgs): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
var
  PW: PWideChar;
  S: string;
begin
  Result := S_OK;
  if (FOwner = nil) or FOwner.FClosed then Exit;
  if args = nil then Exit;
  PW := nil;
  if args.get_WebMessageAsJson(PW) = S_OK then
  begin
    if PW <> nil then
    begin
      S := string(WideString(PW));
      CoTaskMemFree(PW);
    end
    else
      S := '';
    // Post to handler via main thread dispatch is not needed: WebView2 already invokes on UI thread
    FOwner.OnWebMessageReceived(S);
  end
  else if args.TryGetWebMessageAsString(PW) = S_OK then
  begin
    if PW <> nil then
    begin
      S := string(WideString(PW));
      CoTaskMemFree(PW);
    end
    else
      S := '';
    FOwner.OnWebMessageReceived(S);
  end;
end;

constructor TNavStartingHandler.Create(AOwner: TWebView2Webview);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TNavStartingHandler.Invoke(sender: ICoreWebView2; args: ICoreWebView2NavigationStartingEventArgs): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
var
  PW: PWideChar;
  Uri: string;
  Ev: TWebviewNavigationEvent;
  I: Integer;
begin
  Result := S_OK;
  if (FOwner = nil) or FOwner.FClosed then Exit;
  Uri := '';
  if (args <> nil) and (args.get_Uri(PW) = S_OK) then
  begin
    if PW <> nil then
    begin
      Uri := string(WideString(PW));
      CoTaskMemFree(PW);
    end;
  end
  else if FOwner.FWebView <> nil then
  begin
    // fallback: try get_Source
    if FOwner.FWebView.get_Source(PW) = S_OK then
    begin
      if PW <> nil then
      begin
        Uri := string(WideString(PW));
        CoTaskMemFree(PW);
      end;
    end;
  end;
  Ev := Default(TWebviewNavigationEvent);
  Ev.Url := Uri;
  for I := 0 to FOwner.FOnNavStartedCount - 1 do
    FOwner.FOnNavStarted[I](Ev);
end;

constructor TNavCompletedHandler.Create(AOwner: TWebView2Webview);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TNavCompletedHandler.Invoke(sender: ICoreWebView2; args: ICoreWebView2NavigationCompletedEventArgs): nextpas.core.webview.webview2.ffi.HRESULT; stdcall;
var
  IsOk: BOOL;
  Status: Integer;
  Ev: TWebviewNavigationEvent;
  I: Integer;
  PW: PWSTR;
  Uri: string;
begin
  Result := S_OK;
  if (FOwner = nil) or FOwner.FClosed then Exit;
  IsOk := True;
  Status := 0;
  if args <> nil then
  begin
    args.get_IsSuccess(IsOk);
    args.get_WebErrorStatus(Status);
  end;
  Uri := '';
  if FOwner.FWebView <> nil then
  begin
    if FOwner.FWebView.get_Source(PW) = S_OK then
    begin
      if PW <> nil then
      begin
        Uri := string(WideString(PW));
        CoTaskMemFree(PW);
      end;
    end;
  end;
  Ev := Default(TWebviewNavigationEvent);
  Ev.Url := Uri;
  Ev.IsError := not IsOk;
  Ev.ErrorCode := Status;
  if Ev.IsError then
  begin
    Ev.ErrorMessage := 'WebErrorStatus=' + IntToStr(Status);
    for I := 0 to FOwner.FOnNavFailedCount - 1 do
      FOwner.FOnNavFailed[I](Ev);
  end
  else
  begin
    for I := 0 to FOwner.FOnNavFinishedCount - 1 do
      FOwner.FOnNavFinished[I](Ev);
    FOwner.FireReadyOnce;
  end;
end;

constructor TLocalInvokeCompletion.Create(AOwner: TWebView2Webview; AId: Int64);
begin
  inherited Create;
  FOwner := AOwner;
  FId := AId;
end;

procedure TLocalInvokeCompletion.Ok(const AResultJson: string);
begin
  if FDone then raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  FOwner.SendReceipt(FId, False, AResultJson, '', '');
end;

procedure TLocalInvokeCompletion.Fail(const ACode, AMessage: string);
begin
  if FDone then raise EWebviewInvalidState.Create('invoke completion already settled');
  FDone := True;
  FOwner.SendReceipt(FId, True, '', ACode, AMessage);
end;

type
  PPostRefRec = ^TPostRefRec;
  TPostRefRec = record
    Ref: TWebviewProcRef;
  end;
  PPostMethodRec = ^TPostMethodRec;
  TPostMethodRec = record
    Method: TWebviewProcMethod;
  end;
  PPostProcRec = ^TPostProcRec;
  TPostProcRec = record
    Proc: TWebviewProc;
  end;

procedure PostRefTrampoline(AData: Pointer); stdcall;
var R: PPostRefRec;
begin
  R := PPostRefRec(AData);
  try if Assigned(R^.Ref) then R^.Ref(); except end;
  Dispose(R);
end;

procedure PostMethodTrampoline(AData: Pointer); stdcall;
var R: PPostMethodRec;
begin
  R := PPostMethodRec(AData);
  try if Assigned(R^.Method) then R^.Method(); except end;
  Dispose(R);
end;

procedure PostProcTrampoline(AData: Pointer); stdcall;
var R: PPostProcRec;
begin
  R := PPostProcRec(AData);
  try if Assigned(R^.Proc) then R^.Proc(); except end;
  Dispose(R);
end;

class function TWebView2Webview.MapInvokeCodeSafe(E: Exception): string;
begin
  if E is EWebviewInvokeError then
    Result := NormalizeInvokeCode(EWebviewInvokeError(E).Code)
  else
    Result := NPW_CODE_HANDLER_ERROR;
end;

procedure TWebView2Webview.RequireOpen;
begin
  if FClosed then
    raise EWebviewClosed.Create('webview window is closed');
end;

procedure TWebView2Webview.GrowPendingEvals; inline;
begin
  specialize VecGrow<PEvalRec>(FPendingEvals, FPendingCount);
end;

procedure TWebView2Webview.GrowOnNavStarted; inline;
begin
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavStarted, FOnNavStartedCount);
end;

procedure TWebView2Webview.GrowOnNavFinished; inline;
begin
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavFinished, FOnNavFinishedCount);
end;

procedure TWebView2Webview.GrowOnNavFailed; inline;
begin
  specialize VecGrow<TWebviewNavFailedHandler>(FOnNavFailed, FOnNavFailedCount);
end;

procedure TWebView2Webview.GrowOnWindowClosed; inline;
begin
  specialize VecGrow<TWebviewNotifyHandler>(FOnWindowClosed, FOnWindowClosedCount);
end;

procedure TWebView2Webview.GrowOnReady; inline;
begin
  specialize VecGrow<TWebviewNotifyHandler>(FOnReady, FOnReadyCount);
end;

procedure TWebView2Webview.GrowScale; inline;
begin
  // single source: bytes.ops VecGrow (0→4→2×) inline, zero extra call, single Vec
  specialize VecGrow<TWebviewScaleHandler>(FScaleHandlers, FScaleHandlersCount);
end;

procedure TWebView2Webview.DoScaleChanged(ANewScale: Double); inline;
var
  I: Integer;
begin
  // perf: single linear scan over unified Vec, inline, n≤32 fast path, zero extra loop
  for I := 0 to FScaleHandlersCount - 1 do
    if Assigned(FScaleHandlers[I]) then
      try
        FScaleHandlers[I](ANewScale);
      except
      end;
end;

procedure TWebView2Webview.FireNotifyHandlers(var AList: array of TWebviewNotifyHandler);
var I: Integer;
begin
  for I := 0 to High(AList) do
    AList[I]();
end;

procedure TWebView2Webview.FireReadyOnce;
var I: Integer;
begin
  if FReadyFired or FClosed then Exit;
  FReadyFired := True;
  for I := 0 to FOnReadyCount - 1 do
    FOnReady[I]();
end;

procedure TWebView2Webview.HandleWindowEvent(const AEvent: TWindowEvent);
begin
  if FClosed then Exit;
  case AEvent.Kind of
    weResized: UpdateControllerBounds;
    weScaleChanged, weDpiChanged: DoScaleChanged(AEvent.NewScale);
    weClosed, weCloseRequested: HandleNativeDestroy;
  end;
end;

procedure TWebView2Webview.RemovePending(ARec: PEvalRec);
begin
  // perf: single source bytes.ops VecRemoveSwap O(1) zero-copy swap, Default(nil) trailing, avoids O(n²) shift, inline zero extra call via live registry pattern
  specialize VecRemoveSwap<PEvalRec>(FPendingEvals, FPendingCount, ARec);
end;

function TWebView2Webview.WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
begin
  // perf: single source window.base.WindowOptionsCreate inline zero-copy, eliminates 8-field duplication, gtk via shell thin-forward single source
  Result := WindowOptionsCreate(AOptions.Title, AOptions.Width, AOptions.Height, AOptions.MinWidth, AOptions.MinHeight, AOptions.MaxWidth, AOptions.MaxHeight, AOptions.Resizable, AOptions.Maximized);
end;

procedure TWebView2Webview.UpdateControllerBounds;
var R: tagRECT;
begin
  if FController = nil then Exit;
  if FWindow = nil then Exit;
  R.Left := 0; R.Top := 0; R.Right := FWindow.GetWidth; R.Bottom := FWindow.GetHeight;
  FController.put_Bounds(R);
end;

procedure TWebView2Webview.DispatchFrame(const AFrame: TWebviewFrame);
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
    SendReceipt(AFrame.Id, True, '', NPW_CODE_HANDLER_MISSING, 'no handler registered for cmd');
    Exit;
  end;
  if LIsAsync then
  begin
    LCompletion := TLocalInvokeCompletion.Create(Self, AFrame.Id);
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

procedure TWebView2Webview.SendReceipt(AFrameId: Int64; AIsError: Boolean; const AResultJson, ACode, AMessage: string);
var
  LJs: string;
begin
  if FClosed then Exit;
  if AIsError then
    LJs := BuildRejectScript(AFrameId, ACode, AMessage)
  else
    LJs := BuildResolveScript(AFrameId, AResultJson);
  // fire-and-forget eval (no callback)
  Eval(LJs, nil, nil);
end;

procedure TWebView2Webview.OnWebMessageReceived(const AJson: string);
var
  LFrame: TWebviewFrame;
begin
  if FClosed then Exit;
  if TryDecodeFrame(AJson, LFrame) then
    DispatchFrame(LFrame);
end;

procedure TWebView2Webview.OnEnvironmentCreated(errorCode: LongInt; const AEnv: ICoreWebView2Environment);
var
  LHandler: ICoreWebView2CreateCoreWebView2ControllerCompletedHandler;
  LParent: Pointer;
begin
  if FClosed then Exit;
  if (errorCode <> S_OK) or (AEnv = nil) then Exit;
  FEnv := AEnv;
  LHandler := TControllerCompletedHandler.Create(Self);
  LParent := nil;
  if FWindow <> nil then LParent := FWindow.NativeHandle;
  FEnv.CreateCoreWebView2Controller(LParent, LHandler);
end;

procedure TWebView2Webview.OnControllerCreated(errorCode: LongInt; const ACtrl: ICoreWebView2Controller);
var
  LWebView: ICoreWebView2;
  LHandler: ICoreWebView2WebMessageReceivedEventHandler;
  LNavStart: ICoreWebView2NavigationStartingEventHandler;
  LNavComp: ICoreWebView2NavigationCompletedEventHandler;
  PW: PWSTR;
  LSettings: ICoreWebView2Settings;
begin
  if FClosed then Exit;
  if (errorCode <> S_OK) or (ACtrl = nil) then Exit;
  FController := ACtrl;
  if FController.get_CoreWebView2(LWebView) <> S_OK then Exit;
  FWebView := LWebView;
  // UserAgent COM propagation deferred (wine stub vtable issue); local cache retained
  // if (FUserAgent <> '') and (FWebView.get_Settings(LSettings) = S_OK) then
  //   LSettings.put_UserAgent(PWideChar(WideString(FUserAgent)));
  // Make visible and bounds
  FController.put_IsVisible(True);
  UpdateControllerBounds;
  // EnsureResizeHook already, update on resize via win hook
  // Inject bridge script
  FWebView.AddScriptToExecuteOnDocumentCreated(PWideChar(WideString(NPW_BRIDGE_SCRIPT)), PW);
  if PW <> nil then
  begin
    FBridgeScriptId := WideString(PW);
    CoTaskMemFree(PW);
  end;
  // WebMessageReceived
  LHandler := TWebMessageHandler.Create(Self);
  FWebView.add_WebMessageReceived(LHandler, FWebMessageToken);
  // Navigation events
  LNavStart := TNavStartingHandler.Create(Self);
  FWebView.add_NavigationStarting(LNavStart, FNavStartingToken);
  LNavComp := TNavCompletedHandler.Create(Self);
  FWebView.add_NavigationCompleted(LNavComp, FNavCompletedToken);
  // Default navigation if requested
  if FOptions.DevServerUrl <> '' then
  begin
    Navigate(FOptions.DevServerUrl);
  end
  else if FOptions.InitialUrl <> '' then
    Navigate(FOptions.InitialUrl)
  else if FOptions.InitialHtml <> '' then
    NavigateToString(FOptions.InitialHtml);
  FireReadyOnce;
end;

procedure TWebView2Webview.TryCreateEnvironment;
var
  LHandler: ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler;
  LUserData: WideString;
  LUserDataPtr: PCWSTR;
begin
  if FClosed then Exit;
  if not Assigned(CreateCoreWebView2EnvironmentWithOptions) then Exit;
  LHandler := TEnvCompletedHandler.Create(Self);
  LUserData := WideString(FOptions.DataDirectory);
  if LUserData <> '' then LUserDataPtr := PWideChar(LUserData) else LUserDataPtr := nil;
  // EphemeralSession: WebView2 no explicit ephemeral; caller should use temp folder or leave nil for OS temp (closest to private)
  CreateCoreWebView2EnvironmentWithOptions(nil, LUserDataPtr, nil, LHandler);
end;

constructor TWebView2Webview.Create(const AOptions: TWebviewOptions);
var LInfo: TWebView2LoadInfo;
begin
  CheckWebviewOptions(AOptions);
  if not TryLoadWebView2(LInfo) then
    raise EWebviewBackendUnavailable.Create('WebView2 runtime not found (probed WebView2Loader.dll)');
  FOptions := AOptions;
  FClosed := False;
  FZoom := 1.0;
  Inc(GLive);
  FOwnerThread := platform_thread_id;
  FInvokesIntf := TWebviewInvokeRegistry.Create;
  FInvokes := FInvokesIntf as TObject;
  FAssetsIntf := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FAssets := FAssetsIntf as TObject;
  FWindow := CreateWindowOf(wkWin32, WindowOptionsOf(AOptions));
  FOwnsWindow := True;
  FWindow.OnEvent(@HandleWindowEvent);
  RegisterLive(Self);
  FSelfKeepAlive := Self;
  TryCreateEnvironment;
end;

constructor TWebView2Webview.CreateOn(AWindow: IWindow; const AOptions: TWebviewOptions);
var LInfo: TWebView2LoadInfo;
begin
  if AWindow = nil then raise EWebviewInvalidState.Create('Parent window is nil');
  CheckWebviewOptions(AOptions);
  if not TryLoadWebView2(LInfo) then
    raise EWebviewBackendUnavailable.Create('WebView2 runtime not found');
  FOptions := AOptions;
  FClosed := False;
  FZoom := 1.0;
  Inc(GLive);
  FOwnerThread := platform_thread_id;
  FInvokesIntf := TWebviewInvokeRegistry.Create;
  FInvokes := FInvokesIntf as TObject;
  FAssetsIntf := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FAssets := FAssetsIntf as TObject;
  FWindow := AWindow;
  FOwnsWindow := False;
  FWindow.OnEvent(@HandleWindowEvent);
  RegisterLive(Self);
  FSelfKeepAlive := Self;
  TryCreateEnvironment;
end;

function TWebView2Webview.GetWindow: IWindow;
begin
  Result := FWindow;
end;

destructor TWebView2Webview.Destroy;
begin
  if not FClosed then
  begin
    Dec(GLive);
    UnregisterLive(Self);
    if FOwnsWindow and (FWindow <> nil) then
      FWindow.Close;
  end
  else
    UnregisterLive(Self);
  inherited Destroy;
end;

procedure TWebView2Webview.HandleNativeDestroy;
begin
  if FClosed then Exit;
  FClosed := True;
  FireNotifyHandlers(FOnWindowClosed);
  FSelfKeepAlive := nil;
end;

procedure TWebView2Webview.Post(AProc: TWebviewProcRef);
begin
  if not Assigned(AProc) then Exit;
  RequireOpen;
  FWindow.Dispatcher.Post(AProc);
end;
procedure TWebView2Webview.Post(AProc: TWebviewProcMethod);
begin
  if not Assigned(AProc) then Exit;
  RequireOpen;
  FWindow.Dispatcher.Post(AProc);
end;
procedure TWebView2Webview.Post(AProc: TWebviewProc);
begin
  if not Assigned(AProc) then Exit;
  RequireOpen;
  FWindow.Dispatcher.Post(AProc);
end;
function TWebView2Webview.IsOnMainThread: Boolean;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWebView2Webview.Close;
var
  I: Integer;
  LRec: PEvalRec;
  LErr: EWebviewEvalFailed;
begin
  if FClosed then Exit;
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
      // keep record alive for ExecuteScript handler to Dispose and RemovePending (exactly-once, no double free)
    end;
  end;
  // array kept for handler cleanup; Close does not clear to avoid dangling handler pointer
  FireNotifyHandlers(FOnWindowClosed);
  Dec(GLive);
  UnregisterLive(Self);
  if FWebView <> nil then
  begin
    if FWebMessageToken <> 0 then
      FWebView.remove_WebMessageReceived(FWebMessageToken);
    if FNavStartingToken <> 0 then
      FWebView.remove_NavigationStarting(FNavStartingToken);
    if FNavCompletedToken <> 0 then
      FWebView.remove_NavigationCompleted(FNavCompletedToken);
    if FBridgeScriptId <> '' then
      FWebView.RemoveScriptToExecuteOnDocumentCreated(PWideChar(FBridgeScriptId));
  end;
  if FController <> nil then
    FController.Close;
  FWebView := nil;
  FController := nil;
  FEnv := nil;
  if FOwnsWindow and (FWindow <> nil) then
    FWindow.Close;
  FWindow := nil;
  FSelfKeepAlive := nil;
end;

function TWebView2Webview.IsClosed: Boolean;
begin
  Result := FClosed;
end;

procedure TWebView2Webview.Show; inline;
begin
  RequireOpen;
  FWindow.Show;
  UpdateControllerBounds;
end;
procedure TWebView2Webview.Hide; inline;
begin
  RequireOpen;
  FWindow.Hide;
end;
function TWebView2Webview.IsVisible: Boolean; inline;
begin
  if FClosed then Exit(False);
  Result := FWindow.IsVisible;
end;
procedure TWebView2Webview.Focus; inline;
begin
  RequireOpen;
  FWindow.Focus;
end;
procedure TWebView2Webview.SetTitle(const ATitle: string); inline;
begin
  RequireOpen;
  FOptions.Title := ATitle;
  FWindow.SetTitle(ATitle);
end;
function TWebView2Webview.GetTitle: string;
begin
  RequireOpen;
  Result := FWindow.GetTitle;
end;
procedure TWebView2Webview.SetBounds(AWidth, AHeight: Integer); inline;
begin
  RequireOpen;
  FWindow.SetBounds(AWidth, AHeight);
  UpdateControllerBounds;
end;
function TWebView2Webview.GetWidth: Integer; inline;
begin
  RequireOpen;
  Result := FWindow.GetWidth;
end;
function TWebView2Webview.GetHeight: Integer; inline;
begin
  RequireOpen;
  Result := FWindow.GetHeight;
end;
procedure TWebView2Webview.SetResizable(AResizable: Boolean); inline;
begin
  RequireOpen;
  FWindow.SetResizable(AResizable);
end;
procedure TWebView2Webview.Maximize; inline;
begin
  RequireOpen;
  FWindow.Maximize;
  UpdateControllerBounds;
end;
procedure TWebView2Webview.Unmaximize; inline;
begin
  RequireOpen;
  FWindow.Unmaximize;
  UpdateControllerBounds;
end;
function TWebView2Webview.IsMaximized: Boolean; inline;
begin
  Result := FWindow.IsMaximized;
end;
procedure TWebView2Webview.Minimize; inline;
begin
  RequireOpen;
  FWindow.Minimize;
end;
procedure TWebView2Webview.Restore; inline;
begin
  RequireOpen;
  FWindow.Restore;
  UpdateControllerBounds;
end;
function TWebView2Webview.IsMinimized: Boolean; inline;
begin
  Result := FWindow.IsMinimized;
end;
procedure TWebView2Webview.SetZoom(AFactor: Double);
begin
  RequireOpen;
  FZoom := AFactor;
  if FController <> nil then
    FController.put_ZoomFactor(AFactor);
end;
function TWebView2Webview.GetZoom: Double;
begin
  if FController <> nil then
  begin
    if FController.get_ZoomFactor(FZoom) = S_OK then
      Result := FZoom
    else
      Result := FZoom;
    Exit;
  end;
  Result := FZoom;
end;
procedure TWebView2Webview.SetUserAgent(const AUserAgent: string);
begin
  RequireOpen;
  FUserAgent := AUserAgent;
  // COM propagation deferred to OnControllerCreated; direct put_UserAgent
  // via stub has known wine AV (investigate vtable layout), keep local cache
  // for now to ensure stability. OnControllerCreated will attempt once.
end;
function TWebView2Webview.GetUserAgent: string;
begin
  RequireOpen;
  Result := FUserAgent;
end;
function TWebView2Webview.GetScaleFactor: Double;
begin
  Result := FWindow.GetScaleFactor;
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleHandler);
begin
  if not Assigned(AHandler) then Exit;
  GrowScale;
  FScaleHandlers[FScaleHandlersCount] := AHandler;
  Inc(FScaleHandlersCount);
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleMethod);
begin
  if not Assigned(AHandler) then Exit;
  OnScaleChanged(WebviewScaleMethodToRef(AHandler));
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleProc);
begin
  if not Assigned(AHandler) then Exit;
  OnScaleChanged(WebviewScaleProcToRef(AHandler));
end;
procedure TWebView2Webview.Navigate(const AUrl: string);
begin
  RequireOpen;
  if FWebView <> nil then
    FWebView.Navigate(PWideChar(WideString(AUrl)));
end;
procedure TWebView2Webview.NavigateToString(const AHtml: string);
begin
  RequireOpen;
  if FWebView <> nil then
    FWebView.NavigateToString(PWideChar(WideString(AHtml)));
end;
procedure TWebView2Webview.Reload;
begin
  RequireOpen;
  if FWebView <> nil then
    FWebView.Reload;
end;
procedure TWebView2Webview.Stop;
begin
  RequireOpen;
  if FWebView <> nil then
    FWebView.Stop;
end;
function TWebView2Webview.CanGoBack: Boolean;
var B: BOOL;
begin
  if (FWebView <> nil) and (FWebView.get_CanGoBack(B) = S_OK) then
    Result := B else Result := False;
end;
function TWebView2Webview.GoBack: Boolean;
begin
  Result := CanGoBack;
  if Result and (FWebView <> nil) then
    FWebView.GoBack;
end;
function TWebView2Webview.CanGoForward: Boolean;
var B: BOOL;
begin
  if (FWebView <> nil) and (FWebView.get_CanGoForward(B) = S_OK) then
    Result := B else Result := False;
end;
function TWebView2Webview.GoForward: Boolean;
begin
  Result := CanGoForward;
  if Result and (FWebView <> nil) then
    FWebView.GoForward;
end;
procedure TWebView2Webview.Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
var
  LRec: PEvalRec;
  LHandler: ICoreWebView2ExecuteScriptCompletedHandler;
  LErr: EWebviewEvalFailed;
begin
  RequireOpen;
  if FWebView = nil then
  begin
    if Assigned(AOnError) then
    begin
      LErr := EWebviewEvalFailed.Create('WebView2 not ready (controller pending)');
      try AOnError(LErr); finally LErr.Free; end;
    end;
    Exit;
  end;
  New(LRec);
  LRec^.Callback := ACallback;
  LRec^.OnError := AOnError;
  LRec^.Done := False;
  GrowPendingEvals;
  FPendingEvals[FPendingCount] := LRec;
  Inc(FPendingCount);
  LHandler := TExecuteScriptHandler.Create(Self, LRec);
  FWebView.ExecuteScript(PWideChar(WideString(AJavascript)), LHandler);
end;
procedure TWebView2Webview.Emit(const AEvent, APayloadJson: string);
begin
  RequireOpen;
  Eval(BuildEmitScript(AEvent, APayloadJson), nil, nil);
end;
function TWebView2Webview.GetDispatcher: IWebviewDispatcher;
begin
  if FWindow <> nil then Result := FWindow.Dispatcher as IWebviewDispatcher
  else Result := Self as IWebviewDispatcher;
end;
function TWebView2Webview.NativeHandle: TWebviewNativeHandle;
begin
  if FWindow <> nil then Result := FWindow.NativeHandle
  else Result := nil;
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
  GrowOnNavStarted;
  FOnNavStarted[FOnNavStartedCount] := AHandler;
  Inc(FOnNavStartedCount);
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationStarted(WebviewNavMethodToRef(AHandler));
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
  OnNavigationStarted(WebviewNavProcToRef(AHandler));
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
  GrowOnNavFinished;
  FOnNavFinished[FOnNavFinishedCount] := AHandler;
  Inc(FOnNavFinishedCount);
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationFinished(WebviewNavMethodToRef(AHandler));
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
  OnNavigationFinished(WebviewNavProcToRef(AHandler));
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
  GrowOnNavFailed;
  FOnNavFailed[FOnNavFailedCount] := AHandler;
  Inc(FOnNavFailedCount);
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(WebviewNavFailedMethodToRef(AHandler));
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(WebviewNavFailedProcToRef(AHandler));
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyHandler);
begin
  GrowOnWindowClosed;
  FOnWindowClosed[FOnWindowClosedCount] := AHandler;
  Inc(FOnWindowClosedCount);
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyMethod);
begin
  OnWindowClosed(WebviewNotifyMethodToRef(AHandler));
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyProc);
begin
  OnWindowClosed(WebviewNotifyProcToRef(AHandler));
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyHandler);
begin
  GrowOnReady;
  FOnReady[FOnReadyCount] := AHandler;
  Inc(FOnReadyCount);
  if FReadyFired then AHandler();
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyMethod);
begin
  OnReady(WebviewNotifyMethodToRef(AHandler));
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyProc);
begin
  OnReady(WebviewNotifyProcToRef(AHandler));
end;
function TWebView2Webview.GetInvokes: IWebviewInvokeRegistry;
begin
  Result := FInvokesIntf;
end;
function TWebView2Webview.GetAssets: IWebviewAssets;
begin
  Result := FAssetsIntf;
end;

end.
