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
  SysUtils,
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge,
  nextpas.core.webview.webview2.ffi;

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
    FWin: Pointer;
    FVisible: Boolean;
    FZoom: Double;
    FScale: Double;
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
    FScaleHandlersRef: array of TWebviewScaleHandler;
    FScaleHandlersRefCount: Integer;
    FScaleHandlersMethod: array of TWebviewScaleMethod;
    FScaleHandlersMethodCount: Integer;
    FScaleHandlersProc: array of TWebviewScaleProc;
    FScaleHandlersProcCount: Integer;
    {$IFDEF MSWINDOWS}
    FEnv: ICoreWebView2Environment;
    FController: ICoreWebView2Controller;
    FWebView: ICoreWebView2;
    FWebMessageToken: Int64;
    FNavStartingToken: Int64;
    FNavCompletedToken: Int64;
    FBridgeScriptId: WideString;
    {$ENDIF}
    procedure RequireOpen;
    procedure DoScaleChanged(ANewScale: Double);
    procedure EnsureScaleHook;
    procedure EnsureResizeHook;
    procedure UpdateControllerBounds;
    procedure DispatchFrame(const AFrame: TWebviewFrame);
    procedure SendReceipt(AFrameId: Int64; AIsError: Boolean; const AResultJson, ACode, AMessage: string);
    procedure FireReadyOnce;
    procedure FireNotifyHandlers(var AList: array of TWebviewNotifyHandler);
    procedure SettlePendingOnClose; inline;
    procedure HandleNativeDestroy;
    procedure TryCreateEnvironment;
    procedure GrowPendingEvals; inline;
    procedure GrowOnNavStarted; inline;
    procedure GrowOnNavFinished; inline;
    procedure GrowOnNavFailed; inline;
    procedure GrowOnWindowClosed; inline;
    procedure GrowOnReady; inline;
    procedure GrowScaleRef; inline;
    procedure GrowScaleMethod; inline;
    procedure GrowScaleProc; inline;
    procedure RemovePending(ARec: PEvalRec);
    {$IFDEF MSWINDOWS}
    procedure OnEnvironmentCreated(errorCode: LongInt; const AEnv: ICoreWebView2Environment);
    procedure OnControllerCreated(errorCode: LongInt; const ACtrl: ICoreWebView2Controller);
    procedure OnWebMessageReceived(const AJson: string);
    {$ENDIF}
    class function MapInvokeCodeSafe(E: Exception): string; static;
  public
    constructor Create(const AOptions: TWebviewOptions);
    destructor Destroy; override;
    { IWebviewDispatcher — inline 薄转发保留接口 }
    procedure Post(AProc: TWebviewProcRef); overload; inline;
    procedure Post(AProc: TWebviewProcMethod); overload; inline;
    procedure Post(AProc: TWebviewProc); overload; inline;
    function IsOnMainThread: Boolean; inline;
    { IWebviewWindow }
    procedure Close;
    function IsClosed: Boolean;
    procedure Show; procedure Hide; function IsVisible: Boolean;
    procedure Focus;
    procedure SetTitle(const ATitle: string); function GetTitle: string;
    procedure SetBounds(AWidth, AHeight: Integer); function GetWidth: Integer; function GetHeight: Integer;
    procedure SetResizable(AResizable: Boolean);
    procedure Maximize; procedure Unmaximize; function IsMaximized: Boolean;
    procedure Minimize; procedure Restore; function IsMinimized: Boolean;
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
  nextpas.core.sync.mutex,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.webview2.win;

{$IFDEF MSWINDOWS}
procedure CoTaskMemFree(pv: Pointer); stdcall; external 'ole32.dll' name 'CoTaskMemFree';
{$ENDIF}

var
  GLive: Integer = 0;
  GLiveList: array of TWebView2Webview;
  GLiveListCount: Integer = 0;
  GScaleHookInstalled: Boolean = False;
  GResizeHookInstalled: Boolean = False;

procedure GrowLiveList; inline;
begin
  if GLiveListCount = Length(GLiveList) then
    SetLength(GLiveList, WebviewGrowCapacity(Length(GLiveList)));
end;

procedure GlobalWinScaleChanged(AWin: Pointer; AScale: Double);
var I: Integer;
begin
  for I := 0 to GLiveListCount - 1 do
    if (GLiveList[I] <> nil) and (GLiveList[I].FWin = AWin) then
      GLiveList[I].DoScaleChanged(AScale);
end;

procedure GlobalWinResizeChanged(AWin: Pointer; AWidth, AHeight: Integer);
var I: Integer;
begin
  for I := 0 to GLiveListCount - 1 do
    if (GLiveList[I] <> nil) and (GLiveList[I].FWin = AWin) then
      GLiveList[I].UpdateControllerBounds;
end;

procedure RegisterLive(AInst: TWebView2Webview);
begin
  GrowLiveList;
  GLiveList[GLiveListCount] := AInst;
  Inc(GLiveListCount);
end;

procedure UnregisterLive(AInst: TWebView2Webview);
var I, J: Integer;
begin
  for I := 0 to GLiveListCount - 1 do
    if GLiveList[I] = AInst then
    begin
      for J := I to GLiveListCount - 2 do
        GLiveList[J] := GLiveList[J + 1];
      Dec(GLiveListCount);
      if GLiveListCount < Length(GLiveList) then
        GLiveList[GLiveListCount] := nil;
      Break;
    end;
end;

function WebView2LiveWindowCount: Integer;
begin
  Result := GLive;
end;

{$IFDEF MSWINDOWS}
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
{$ENDIF}

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

{$IFDEF MSWINDOWS}

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
{$ENDIF}

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

var
  GPostRefPool: array of PPostRefRec;
  GPostRefPoolCount: Integer = 0;
  GPostMethodPool: array of PPostMethodRec;
  GPostMethodPoolCount: Integer = 0;
  GPostProcPool: array of PPostProcRec;
  GPostProcPoolCount: Integer = 0;
  GPostPoolLock: Pointer = nil;

function PostPoolLock: TMutex; inline;
begin
  if GPostPoolLock = nil then
    GPostPoolLock := TMutex.Create;
  Result := TMutex(GPostPoolLock);
end;

function AcquirePostRefRec: PPostRefRec; inline;
begin
  PostPoolLock.Acquire;
  try
    if GPostRefPoolCount > 0 then
    begin Dec(GPostRefPoolCount); Result := GPostRefPool[GPostRefPoolCount]; GPostRefPool[GPostRefPoolCount]:=nil; end else New(Result);
  finally PostPoolLock.Release; end;
end;

procedure ReleasePostRefRec(A: PPostRefRec); inline;
begin
  if A=nil then Exit; A^.Ref:=nil;
  PostPoolLock.Acquire;
  try if GPostRefPoolCount=Length(GPostRefPool) then SetLength(GPostRefPool, WebviewGrowCapacity(Length(GPostRefPool)));
    GPostRefPool[GPostRefPoolCount]:=A; Inc(GPostRefPoolCount); finally PostPoolLock.Release; end;
end;

function AcquirePostMethodRec: PPostMethodRec; inline;
begin PostPoolLock.Acquire;
  try if GPostMethodPoolCount>0 then begin Dec(GPostMethodPoolCount); Result:=GPostMethodPool[GPostMethodPoolCount]; GPostMethodPool[GPostMethodPoolCount]:=nil; end else New(Result); finally PostPoolLock.Release; end;
end;

procedure ReleasePostMethodRec(A: PPostMethodRec); inline;
begin if A=nil then Exit; A^.Method:=nil;
  PostPoolLock.Acquire;
  try if GPostMethodPoolCount=Length(GPostMethodPool) then SetLength(GPostMethodPool, WebviewGrowCapacity(Length(GPostMethodPool)));
    GPostMethodPool[GPostMethodPoolCount]:=A; Inc(GPostMethodPoolCount); finally PostPoolLock.Release; end;
end;

function AcquirePostProcRec: PPostProcRec; inline;
begin PostPoolLock.Acquire;
  try if GPostProcPoolCount>0 then begin Dec(GPostProcPoolCount); Result:=GPostProcPool[GPostProcPoolCount]; GPostProcPool[GPostProcPoolCount]:=nil; end else New(Result); finally PostPoolLock.Release; end;
end;

procedure ReleasePostProcRec(A: PPostProcRec); inline;
begin if A=nil then Exit; A^.Proc:=nil;
  PostPoolLock.Acquire;
  try if GPostProcPoolCount=Length(GPostProcPool) then SetLength(GPostProcPool, WebviewGrowCapacity(Length(GPostProcPool)));
    GPostProcPool[GPostProcPoolCount]:=A; Inc(GPostProcPoolCount); finally PostPoolLock.Release; end;
end;

procedure PostRefTrampoline(AData: Pointer); stdcall;
var R: PPostRefRec;
begin
  R := PPostRefRec(AData);
  try if Assigned(R^.Ref) then R^.Ref(); except end;
  ReleasePostRefRec(R);
end;

procedure PostMethodTrampoline(AData: Pointer); stdcall;
var R: PPostMethodRec;
begin
  R := PPostMethodRec(AData);
  try if Assigned(R^.Method) then R^.Method(); except end;
  ReleasePostMethodRec(R);
end;

procedure PostProcTrampoline(AData: Pointer); stdcall;
var R: PPostProcRec;
begin
  R := PPostProcRec(AData);
  try if Assigned(R^.Proc) then R^.Proc(); except end;
  ReleasePostProcRec(R);
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
  if FPendingCount = Length(FPendingEvals) then
    SetLength(FPendingEvals, WebviewGrowCapacity(Length(FPendingEvals)));
end;

procedure TWebView2Webview.GrowOnNavStarted; inline;
begin
  if FOnNavStartedCount = Length(FOnNavStarted) then
    SetLength(FOnNavStarted, WebviewGrowCapacity(Length(FOnNavStarted)));
end;

procedure TWebView2Webview.GrowOnNavFinished; inline;
begin
  if FOnNavFinishedCount = Length(FOnNavFinished) then
    SetLength(FOnNavFinished, WebviewGrowCapacity(Length(FOnNavFinished)));
end;

procedure TWebView2Webview.GrowOnNavFailed; inline;
begin
  if FOnNavFailedCount = Length(FOnNavFailed) then
    SetLength(FOnNavFailed, WebviewGrowCapacity(Length(FOnNavFailed)));
end;

procedure TWebView2Webview.GrowOnWindowClosed; inline;
begin
  if FOnWindowClosedCount = Length(FOnWindowClosed) then
    SetLength(FOnWindowClosed, WebviewGrowCapacity(Length(FOnWindowClosed)));
end;

procedure TWebView2Webview.GrowOnReady; inline;
begin
  if FOnReadyCount = Length(FOnReady) then
    SetLength(FOnReady, WebviewGrowCapacity(Length(FOnReady)));
end;

procedure TWebView2Webview.GrowScaleRef; inline;
begin
  if FScaleHandlersRefCount = Length(FScaleHandlersRef) then
    SetLength(FScaleHandlersRef, WebviewGrowCapacity(Length(FScaleHandlersRef)));
end;

procedure TWebView2Webview.GrowScaleMethod; inline;
begin
  if FScaleHandlersMethodCount = Length(FScaleHandlersMethod) then
    SetLength(FScaleHandlersMethod, WebviewGrowCapacity(Length(FScaleHandlersMethod)));
end;

procedure TWebView2Webview.GrowScaleProc; inline;
begin
  if FScaleHandlersProcCount = Length(FScaleHandlersProc) then
    SetLength(FScaleHandlersProc, WebviewGrowCapacity(Length(FScaleHandlersProc)));
end;

procedure TWebView2Webview.FireNotifyHandlers(var AList: array of TWebviewNotifyHandler);
var I: Integer;
begin
  for I := 0 to High(AList) do
    if Assigned(AList[I]) then
      AList[I]();
end;

procedure TWebView2Webview.SettlePendingOnClose; inline;
var
  I: Integer;
  LRec: PEvalRec;
  LErr: EWebviewEvalFailed;
begin
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
          try
            LRec^.OnError(LErr);
          except
          end;
        finally
          LErr.Free;
        end;
      end;
    end;
  end;
end;

procedure TWebView2Webview.FireReadyOnce;
var I: Integer;
begin
  if FReadyFired or FClosed then Exit;
  FReadyFired := True;
  for I := 0 to FOnReadyCount - 1 do
    FOnReady[I]();
end;

procedure TWebView2Webview.DoScaleChanged(ANewScale: Double);
var I: Integer;
begin
  FScale := ANewScale;
  for I := 0 to FScaleHandlersRefCount - 1 do
    if Assigned(FScaleHandlersRef[I]) then FScaleHandlersRef[I](ANewScale);
  for I := 0 to FScaleHandlersMethodCount - 1 do
    if Assigned(FScaleHandlersMethod[I]) then FScaleHandlersMethod[I](ANewScale);
  for I := 0 to FScaleHandlersProcCount - 1 do
    if Assigned(FScaleHandlersProc[I]) then FScaleHandlersProc[I](ANewScale);
end;

procedure TWebView2Webview.RemovePending(ARec: PEvalRec);
var I, J: Integer;
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

procedure TWebView2Webview.EnsureScaleHook;
begin
  if GScaleHookInstalled then Exit;
  GScaleHookInstalled := True;
  Win32ShellOnScaleChanged(@GlobalWinScaleChanged);
end;

procedure TWebView2Webview.EnsureResizeHook;
begin
  if GResizeHookInstalled then Exit;
  GResizeHookInstalled := True;
  Win32ShellOnResize(@GlobalWinResizeChanged);
end;

procedure TWebView2Webview.UpdateControllerBounds;
{$IFDEF MSWINDOWS}
var
  R: tagRECT;
  W, H: Integer;
begin
  if FController = nil then Exit;
  if FWin = nil then Exit;
  if Win32ShellClientSize(FWin, W, H) then
  begin
    R.Left := 0;
    R.Top := 0;
    R.Right := W;
    R.Bottom := H;
    FController.put_Bounds(R);
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

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
  // fire-and-forget：跳 pending，直接底层 ExecuteScript（零 pending）
{$IFDEF MSWINDOWS}
  if FWebView <> nil then
    FWebView.ExecuteScript(PWideChar(WideString(LJs)), nil);
{$ELSE}
  // 非 Windows 桩：无 controller，丢弃（与 gtk fire-and-forget 对称）
{$ENDIF}
end;

{$IFDEF MSWINDOWS}
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
begin
  if FClosed then Exit;
  if (errorCode <> S_OK) or (AEnv = nil) then Exit;
  FEnv := AEnv;
  LHandler := TControllerCompletedHandler.Create(Self);
  FEnv.CreateCoreWebView2Controller(FWin, LHandler);
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
{$ENDIF}

procedure TWebView2Webview.TryCreateEnvironment;
{$IFDEF MSWINDOWS}
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
{$ELSE}
begin
end;
{$ENDIF}

constructor TWebView2Webview.Create(const AOptions: TWebviewOptions);
var
  LInfo: TWebView2LoadInfo;
  LGeo: TWin32ShellGeometry;
begin
  CheckWebviewOptions(AOptions);
  if not TryLoadWebView2(LInfo) then
    raise EWebviewBackendUnavailable.Create('WebView2 runtime not found (probed WebView2Loader.dll)');
  FOptions := AOptions;
  FClosed := False;
  FZoom := 1.0;
  FScale := 1.0;
  Inc(GLive);
  FOwnerThread := platform_thread_id;
  FInvokesIntf := TWebviewInvokeRegistry.Create;
  FInvokes := FInvokesIntf as TObject;
  FAssetsIntf := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FAssets := FAssetsIntf as TObject;
  LGeo.Title := FOptions.Title;
  LGeo.Width := FOptions.Width;
  LGeo.Height := FOptions.Height;
  LGeo.Resizable := FOptions.Resizable;
  LGeo.StartMaximized := FOptions.Maximized;
  FWin := Win32ShellCreate(LGeo);
  RegisterLive(Self);
  EnsureScaleHook;
  EnsureResizeHook;
  FSelfKeepAlive := Self;
  TryCreateEnvironment;
  if FOptions.InitialUrl = '' then
  begin
    // InitialHtml path handled after controller ready; if no controller, also try direct navigate fallback (will no-op until ready)
  end;
end;

destructor TWebView2Webview.Destroy;
begin
  if not FClosed then
  begin
    Dec(GLive);
    UnregisterLive(Self);
    if FWin <> nil then
      Win32ShellDestroy(FWin);
  end
  else
    UnregisterLive(Self);
  inherited Destroy;
end;

procedure TWebView2Webview.HandleNativeDestroy;
begin
  if FClosed then Exit;
  FClosed := True;
  SettlePendingOnClose;
  FireNotifyHandlers(FOnWindowClosed);
  FSelfKeepAlive := nil;
end;

procedure TWebView2Webview.Post(AProc: TWebviewProcRef); inline;
var R: PPostRefRec;
begin
  if not Assigned(AProc) then Exit;
  RequireOpen;
  R := AcquirePostRefRec; R^.Ref := AProc;
  if not Win32ShellPost(@PostRefTrampoline, R) then
  begin ReleasePostRefRec(R); try AProc(); except end; end;
end;
procedure TWebView2Webview.Post(AProc: TWebviewProcMethod); inline;
var R: PPostMethodRec;
begin
  if not Assigned(AProc) then Exit;
  RequireOpen;
  R := AcquirePostMethodRec; R^.Method := AProc;
  if not Win32ShellPost(@PostMethodTrampoline, R) then
  begin ReleasePostMethodRec(R); try AProc(); except end; end;
end;
procedure TWebView2Webview.Post(AProc: TWebviewProc); inline;
var R: PPostProcRec;
begin
  if not Assigned(AProc) then Exit;
  RequireOpen;
  R := AcquirePostProcRec; R^.Proc := AProc;
  if not Win32ShellPost(@PostProcTrampoline, R) then
  begin ReleasePostProcRec(R); try AProc(); except end; end;
end;
function TWebView2Webview.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWebView2Webview.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  SettlePendingOnClose;
  // array kept for handler cleanup; Close does not clear to avoid dangling handler pointer
  FireNotifyHandlers(FOnWindowClosed);
  Dec(GLive);
  UnregisterLive(Self);
  {$IFDEF MSWINDOWS}
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
  {$ENDIF}
  if FWin <> nil then
  begin
    Win32ShellDestroy(FWin);
    FWin := nil;
  end;
  if GLive = 0 then
    Win32ShellQuitMainLoop;
  FSelfKeepAlive := nil;
end;

function TWebView2Webview.IsClosed: Boolean;
begin
  Result := FClosed;
end;

procedure TWebView2Webview.Show;
begin
  RequireOpen;
  FVisible := True;
  if FWin <> nil then Win32ShellShow(FWin);
  UpdateControllerBounds;
end;
procedure TWebView2Webview.Hide;
begin
  RequireOpen;
  FVisible := False;
  if FWin <> nil then Win32ShellHide(FWin);
end;
function TWebView2Webview.IsVisible: Boolean;
begin
  if FClosed then Exit(False);
  if FWin <> nil then Result := Win32ShellIsVisible(FWin)
  else Result := FVisible;
end;
procedure TWebView2Webview.Focus;
begin
  RequireOpen;
  if FWin <> nil then Win32ShellFocus(FWin);
end;
procedure TWebView2Webview.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FOptions.Title := ATitle;
  if FWin <> nil then Win32ShellSetTitle(FWin, ATitle);
end;
function TWebView2Webview.GetTitle: string;
begin
  RequireOpen;
  Result := FOptions.Title;
end;
procedure TWebView2Webview.SetBounds(AWidth, AHeight: Integer);
begin
  RequireOpen;
  FOptions.Width := AWidth; FOptions.Height := AHeight;
  if FWin <> nil then Win32ShellResize(FWin, AWidth, AHeight);
  UpdateControllerBounds;
end;
function TWebView2Webview.GetWidth: Integer;
begin
  RequireOpen;
  Result := FOptions.Width;
end;
function TWebView2Webview.GetHeight: Integer;
begin
  RequireOpen;
  Result := FOptions.Height;
end;
procedure TWebView2Webview.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FOptions.Resizable := AResizable;
end;
procedure TWebView2Webview.Maximize;
begin
  RequireOpen;
  FOptions.Maximized := True;
  if FWin <> nil then Win32ShellMaximize(FWin);
  UpdateControllerBounds;
end;
procedure TWebView2Webview.Unmaximize;
begin
  RequireOpen;
  FOptions.Maximized := False;
  if FWin <> nil then Win32ShellUnmaximize(FWin);
  UpdateControllerBounds;
end;
function TWebView2Webview.IsMaximized: Boolean;
begin
  if FWin <> nil then Result := Win32ShellIsMaximized(FWin)
  else Result := FOptions.Maximized;
end;
procedure TWebView2Webview.Minimize;
begin
  RequireOpen;
  if FWin <> nil then Win32ShellMinimize(FWin);
end;
procedure TWebView2Webview.Restore;
begin
  RequireOpen;
  if FWin <> nil then Win32ShellRestore(FWin);
  UpdateControllerBounds;
end;
function TWebView2Webview.IsMinimized: Boolean;
begin
  if FWin <> nil then Result := Win32ShellIsMinimized(FWin)
  else Result := False;
end;
procedure TWebView2Webview.SetZoom(AFactor: Double);
begin
  RequireOpen;
  FZoom := AFactor;
  {$IFDEF MSWINDOWS}
  if FController <> nil then
    FController.put_ZoomFactor(AFactor);
  {$ENDIF}
end;
function TWebView2Webview.GetZoom: Double;
begin
  {$IFDEF MSWINDOWS}
  if FController <> nil then
  begin
    if FController.get_ZoomFactor(FZoom) = S_OK then
      Result := FZoom
    else
      Result := FZoom;
    Exit;
  end;
  {$ENDIF}
  Result := FZoom;
end;
procedure TWebView2Webview.SetUserAgent(const AUserAgent: string);
begin
  RequireOpen;
  FUserAgent := AUserAgent;
  {$IFDEF MSWINDOWS}
  // COM propagation deferred to OnControllerCreated; direct put_UserAgent
  // via stub has known wine AV (investigate vtable layout), keep local cache
  // for now to ensure stability. OnControllerCreated will attempt once.
  {$ENDIF}
end;
function TWebView2Webview.GetUserAgent: string;
begin
  RequireOpen;
  Result := FUserAgent;
end;
function TWebView2Webview.GetScaleFactor: Double;
begin
  if FWin <> nil then Result := Win32ShellScaleFactor(FWin)
  else Result := FScale;
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleHandler);
begin
  if not Assigned(AHandler) then Exit;
  EnsureScaleHook;
  GrowScaleRef;
  FScaleHandlersRef[FScaleHandlersRefCount] := AHandler;
  Inc(FScaleHandlersRefCount);
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleMethod);
begin
  if not Assigned(AHandler) then Exit;
  EnsureScaleHook;
  GrowScaleMethod;
  FScaleHandlersMethod[FScaleHandlersMethodCount] := AHandler;
  Inc(FScaleHandlersMethodCount);
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleProc);
begin
  if not Assigned(AHandler) then Exit;
  EnsureScaleHook;
  GrowScaleProc;
  FScaleHandlersProc[FScaleHandlersProcCount] := AHandler;
  Inc(FScaleHandlersProcCount);
end;
procedure TWebView2Webview.Navigate(const AUrl: string);
begin
  RequireOpen;
  {$IFDEF MSWINDOWS}
  if FWebView <> nil then
    FWebView.Navigate(PWideChar(WideString(AUrl)));
  {$ENDIF}
end;
procedure TWebView2Webview.NavigateToString(const AHtml: string);
begin
  RequireOpen;
  {$IFDEF MSWINDOWS}
  if FWebView <> nil then
    FWebView.NavigateToString(PWideChar(WideString(AHtml)));
  {$ENDIF}
end;
procedure TWebView2Webview.Reload;
begin
  RequireOpen;
  {$IFDEF MSWINDOWS}
  if FWebView <> nil then
    FWebView.Reload;
  {$ENDIF}
end;
procedure TWebView2Webview.Stop;
begin
  RequireOpen;
  {$IFDEF MSWINDOWS}
  if FWebView <> nil then
    FWebView.Stop;
  {$ENDIF}
end;
function TWebView2Webview.CanGoBack: Boolean;
{$IFDEF MSWINDOWS}
var B: BOOL;
begin
  if (FWebView <> nil) and (FWebView.get_CanGoBack(B) = S_OK) then
    Result := B else Result := False;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}
function TWebView2Webview.GoBack: Boolean;
begin
  Result := CanGoBack;
  {$IFDEF MSWINDOWS}
  if Result and (FWebView <> nil) then
    FWebView.GoBack;
  {$ENDIF}
end;
function TWebView2Webview.CanGoForward: Boolean;
{$IFDEF MSWINDOWS}
var B: BOOL;
begin
  if (FWebView <> nil) and (FWebView.get_CanGoForward(B) = S_OK) then
    Result := B else Result := False;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}
function TWebView2Webview.GoForward: Boolean;
begin
  Result := CanGoForward;
  {$IFDEF MSWINDOWS}
  if Result and (FWebView <> nil) then
    FWebView.GoForward;
  {$ENDIF}
end;
procedure TWebView2Webview.Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
{$IFDEF MSWINDOWS}
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
{$ELSE}
var
  LErr: EWebviewEvalFailed;
begin
  RequireOpen;
  if Assigned(AOnError) then
  begin
    LErr := EWebviewEvalFailed.Create('WebView2 Eval not available on this platform');
    try AOnError(LErr); finally LErr.Free; end;
  end;
end;
{$ENDIF}
procedure TWebView2Webview.Emit(const AEvent, APayloadJson: string);
begin
  RequireOpen;
  Eval(BuildEmitScript(AEvent, APayloadJson), nil, nil);
end;
function TWebView2Webview.GetDispatcher: IWebviewDispatcher;
begin
  Result := Self as IWebviewDispatcher;
end;
function TWebView2Webview.NativeHandle: TWebviewNativeHandle;
begin
  if FWin <> nil then Result := Win32ShellNativeHandle(FWin)
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
  OnNavigationStarted(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
  OnNavigationStarted(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
  GrowOnNavFinished;
  FOnNavFinished[FOnNavFinishedCount] := AHandler;
  Inc(FOnNavFinishedCount);
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
  OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
  OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
  GrowOnNavFailed;
  FOnNavFailed[FOnNavFailedCount] := AHandler;
  Inc(FOnNavFailedCount);
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
  OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
  OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyHandler);
begin
  GrowOnWindowClosed;
  FOnWindowClosed[FOnWindowClosedCount] := AHandler;
  Inc(FOnWindowClosedCount);
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyMethod);
begin
  OnWindowClosed(
    procedure
    begin
      AHandler();
    end);
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyProc);
begin
  OnWindowClosed(
    procedure
    begin
      AHandler();
    end);
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
  OnReady(
    procedure
    begin
      AHandler();
    end);
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyProc);
begin
  OnReady(
    procedure
    begin
      AHandler();
    end);
end;
function TWebView2Webview.GetInvokes: IWebviewInvokeRegistry;
begin
  Result := FInvokesIntf;
end;
function TWebView2Webview.GetAssets: IWebviewAssets;
begin
  Result := FAssetsIntf;
end;

initialization

finalization
  while GPostRefPoolCount > 0 do begin Dec(GPostRefPoolCount); Dispose(GPostRefPool[GPostRefPoolCount]); end;
  SetLength(GPostRefPool, 0);
  while GPostMethodPoolCount > 0 do begin Dec(GPostMethodPoolCount); Dispose(GPostMethodPool[GPostMethodPoolCount]); end;
  SetLength(GPostMethodPool, 0);
  while GPostProcPoolCount > 0 do begin Dec(GPostProcPoolCount); Dispose(GPostProcPool[GPostProcPoolCount]); end;
  SetLength(GPostProcPool, 0);
  if GPostPoolLock <> nil then begin TObject(GPostPoolLock).Free; GPostPoolLock := nil; end;

end.
