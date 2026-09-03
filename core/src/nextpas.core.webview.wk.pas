unit nextpas.core.webview.wk;

{** @desc macOS WKWebView 后端桩（Wave 3 桩→S106 探针闭环）。

       当前阶段为桩+探针闭环：构造即检查 TryLoadWk（经 platform.dl 真探
       WebKit.framework/libobjc，Linux诚实False，非恒False），不可用时抛
       EWebviewBackendUnavailable（消息含探针名），与 webview2 同语义。
       Darwin 真实现路径已闭环：复用 nextpas.core.window.cocoa L2 的
       IWindow（NSWindow+dispatch_async单源），WK以 WKWebView child
       addSubview 于其 NativeHandle，待 stage0 ObjC 能力探通后以纯C
       objc_msgSend 接 WKUserContentController/WKScriptMessageHandler。

       桩的窗口语义：为保持 factory/builder 链路可测，桩在 loader 可用时
       提供最小窗口回显（复用 window.cocoa 的几何回显思想），当前 Linux
       宿主探针诚实 False 故 fail-fast，Darwin 命中后同链路可进真窗口。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.validation,
  nextpas.core.webview.callbacks,
  nextpas.core.webview.utils,
  nextpas.core.bytes.ops,
  nextpas.core.window.base,
  nextpas.core.window.intf;

type
  PEvalRec = ^TEvalRec;
  TEvalRec = record
    Callback: TWebviewEvalCallback;
    OnError: TWebviewEvalErrorCallback;
    Done: Boolean;
  end;

  TWkWebview = class(TInterfacedObject, IWebviewWindow, IWebviewDispatcher)
  private
    FOptions: TWebviewOptions;
    FClosed: Boolean;
    FOwnerThread: UInt64;
    FWindow: IWindow;
    FOwnsWindow: Boolean;
    FUserAgent: string;
    FZoom: Double;
    FRegistered: Boolean;
    FOnScaleChanged: specialize TCompactLiveRegistry<TWebviewScaleHandler>;
    FOnNavStarted: specialize TCompactLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFinished: specialize TCompactLiveRegistry<TWebviewNavEventHandler>;
    FOnNavFailed: specialize TCompactLiveRegistry<TWebviewNavFailedHandler>;
    FOnWindowClosed: specialize TCompactLiveRegistry<TWebviewNotifyHandler>;
    FOnReady: specialize TCompactLiveRegistry<TWebviewNotifyHandler>;
    FPendingEvals: specialize TCompactLiveRegistry<PEvalRec>;
    FInvokesIntf: IWebviewInvokeRegistry;
    FInvokes: TObject;
    FAssetsIntf: IWebviewAssets;
    FAssets: TObject;
    procedure RemovePending(ARec: PEvalRec); inline;
    procedure DoScaleChanged(ANewScale: Double); inline;
    procedure HandleWindowEvent(const AEvent: TWindowEvent);
    procedure UpdateChildBounds;
    function WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
  public
    constructor Create(const AOptions: TWebviewOptions);
    constructor CreateOn(AWindow: IWindow; const AOptions: TWebviewOptions);
    destructor Destroy; override;
    function GetWindow: IWindow;
    procedure Close; function IsClosed: Boolean;
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
    procedure Navigate(const {%H-}AUrl: string); procedure NavigateToString(const {%H-}AHtml: string);
    procedure Reload; procedure Stop;
    function CanGoBack: Boolean; function GoBack: Boolean;
    function CanGoForward: Boolean; function GoForward: Boolean;
    procedure Eval(const {%H-}AJavascript: string; {%H-}ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
    procedure Emit(const {%H-}AEvent, {%H-}APayloadJson: string);
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
    // IWebviewDispatcher
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
    function IsOnMainThread: Boolean;
  end;

function WkLiveWindowCount: Integer;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.platform.thread,
  nextpas.core.webview.bridge,
  nextpas.core.webview.wk.loader,
  nextpas.core.window.cocoa;

var
  GLive: Integer = 0;
  GLiveWindows: specialize TCompactLiveRegistry<TWkWebview> = nil;

procedure RegisterLive(AWin: TWkWebview); inline;
begin
  // single source: live registry Register -> bytes.ops VecGrow inline (0→4→2×), zero extra call, zero-copy, single source
  if GLiveWindows <> nil then
    GLiveWindows.Register(AWin);
end;

procedure UnregisterLive(AWin: TWkWebview); inline;
begin
  // single source: live registry Unregister inline O(1) swap, bytes.ops VecRemoveSwap single source, hot close avoids O(n²) shift, trailing nil release
  if GLiveWindows <> nil then
    GLiveWindows.Unregister(AWin);
end;

function WkLiveWindowCount: Integer; inline;
begin
  // perf: O(1) cached GLive inline, zero scan, close密集零遍历
  Result := GLive;
end;

function TWkWebview.WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
begin
  // perf: thin forward to webview.utils single source WebviewWindowOptionsOf inline zero-copy, eliminates 8-field duplication with fake/gtk.shell via window.base single source, CONTRACT §2.2 8-field complete (Title/Width/Height/MinWidth/MinHeight/MaxWidth/MaxHeight/Resizable/Maximized)
  Result := nextpas.core.webview.utils.WebviewWindowOptionsOf(AOptions);
end;

procedure TWkWebview.HandleWindowEvent(const AEvent: TWindowEvent);
begin
  if FClosed then Exit;
  case AEvent.Kind of
    weResized: UpdateChildBounds;
    weScaleChanged: DoScaleChanged(AEvent.NewScale.Factor);
    weClosed, weCloseRequested: Close;
  end;
end;

procedure TWkWebview.UpdateChildBounds;
begin
  // WKWebView as child addSubview would be resized here (Darwin impl)
end;

constructor TWkWebview.Create(const AOptions: TWebviewOptions);
var LInfo: TWkLoadInfo;
    LReg: TWebviewInvokeRegistry;
    LAssets: TWebviewAssetsImpl;
begin
  CheckWebviewOptions(AOptions);
  if not TryLoadWk(LInfo) then
    raise EWebviewBackendUnavailable.Create('WKWebView runtime not available on this platform (requires macOS)');
  FOptions := AOptions;
  FOwnerThread := platform_thread_id;
  FUserAgent := ''; FZoom := 1.0; FClosed := False;
  // single source: live compact registry 0→4→2× inline via bytes.ops TCompactLiveRegistry single source inline zero-copy, nil zero-alloc, eliminates Grow/Count Vec sample duplication
  FOnScaleChanged := specialize TCompactLiveRegistry<TWebviewScaleHandler>.Create;
  FOnNavStarted := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFinished := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFailed := specialize TCompactLiveRegistry<TWebviewNavFailedHandler>.Create;
  FOnWindowClosed := specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create;
  FOnReady := specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create;
  FPendingEvals := specialize TCompactLiveRegistry<PEvalRec>.Create;
  LReg := TWebviewInvokeRegistry.Create;
  LAssets := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;
  FAssetsIntf := LAssets;
  FInvokes := LReg;
  FAssets := LAssets;
  // has-a L3→L2 cocoa window single source: direct CreateWindowCocoa, avoids wkFake test species invasion, owner boundary has-a inline zero-copy
  FWindow := CreateWindowCocoa(WindowOptionsOf(AOptions));
  FOwnsWindow := True;
  FWindow.OnEvent(@HandleWindowEvent);
  Inc(GLive);
  RegisterLive(Self);
  FRegistered := True;
end;

constructor TWkWebview.CreateOn(AWindow: IWindow; const AOptions: TWebviewOptions);
var LInfo: TWkLoadInfo;
    LReg: TWebviewInvokeRegistry;
    LAssets: TWebviewAssetsImpl;
begin
  if AWindow=nil then raise EWebviewInvalidState.Create('Parent window is nil');
  CheckWebviewOptions(AOptions);
  if not TryLoadWk(LInfo) then raise EWebviewBackendUnavailable.Create('WKWebView runtime not available');
  FOptions:=AOptions; FOwnerThread:=platform_thread_id; FUserAgent:=''; FZoom:=1.0; FClosed:=False;
  // single source: live compact registry 0→4→2× inline via bytes.ops TCompactLiveRegistry single source inline zero-copy, nil zero-alloc
  FOnScaleChanged := specialize TCompactLiveRegistry<TWebviewScaleHandler>.Create;
  FOnNavStarted := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFinished := specialize TCompactLiveRegistry<TWebviewNavEventHandler>.Create;
  FOnNavFailed := specialize TCompactLiveRegistry<TWebviewNavFailedHandler>.Create;
  FOnWindowClosed := specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create;
  FOnReady := specialize TCompactLiveRegistry<TWebviewNotifyHandler>.Create;
  FPendingEvals := specialize TCompactLiveRegistry<PEvalRec>.Create;
  LReg := TWebviewInvokeRegistry.Create;
  LAssets := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;
  FAssetsIntf := LAssets;
  FInvokes := LReg;
  FAssets := LAssets;
  FWindow:=AWindow; FOwnsWindow:=False; FWindow.OnEvent(@HandleWindowEvent);
  Inc(GLive); RegisterLive(Self); FRegistered:=True;
end;

destructor TWkWebview.Destroy;
begin
  // stability: has-a COM release + live registry free guarantees close idempotence, resource release not lost; FRegistered guards partial construction
  if FRegistered then
  begin
    if not FClosed then
    begin
      Dec(GLive);
      UnregisterLive(Self);
      if FOwnsWindow and (FWindow<>nil) then
        try FWindow.Close; except end;
    end
    else
      UnregisterLive(Self);
    FRegistered := False;
  end;
  FreeAndNil(FPendingEvals);
  FreeAndNil(FOnReady);
  FreeAndNil(FOnWindowClosed);
  FreeAndNil(FOnNavFailed);
  FreeAndNil(FOnNavFinished);
  FreeAndNil(FOnNavStarted);
  FreeAndNil(FOnScaleChanged);
  FWindow:=nil;
  inherited Destroy;
end;

function TWkWebview.GetWindow: IWindow;
begin Result:=FWindow; end;

procedure TWkWebview.Close;
var
  I: Integer;
  LRec: PEvalRec;
  LErr: EWebviewEvalFailed;
begin
  if FClosed then Exit;
  FClosed := True;
  if FRegistered then
  begin
    Dec(GLive);
    UnregisterLive(Self);
    FRegistered := False;
  end;
  // perf: live registry Count/At inline O(n) single pass, swap-free; bytes.ops VecRemoveSwap single source for RemovePending path
  if FPendingEvals <> nil then
    for I := 0 to FPendingEvals.Count - 1 do
    begin
      LRec := FPendingEvals.At(I);
      if (LRec <> nil) and not LRec^.Done then
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
        Dispose(LRec);
      end;
    end;
  if FPendingEvals <> nil then
    FPendingEvals.Clear;
  if FOnWindowClosed <> nil then
    for I := 0 to FOnWindowClosed.Count - 1 do
      if Assigned(FOnWindowClosed.At(I)) then
        try FOnWindowClosed.At(I)(); except end;
  if FOwnsWindow and (FWindow<>nil) then FWindow.Close;
  FWindow:=nil;
end;

function TWkWebview.IsClosed: Boolean;
begin
  Result := FClosed;
end;

procedure TWkWebview.Show; begin if FClosed then Exit; if FWindow<>nil then FWindow.Show; end;
procedure TWkWebview.Hide; begin if FClosed then Exit; if FWindow<>nil then FWindow.Hide; end;
function TWkWebview.IsVisible: Boolean; begin if FClosed then Exit(False); if FWindow<>nil then Result:=FWindow.IsVisible else Result:=not FClosed; end;
procedure TWkWebview.Focus; begin if not FClosed and (FWindow<>nil) then FWindow.Focus; end;
procedure TWkWebview.SetTitle(const ATitle: string); begin FOptions.Title := ATitle; if not FClosed and (FWindow<>nil) then FWindow.SetTitle(ATitle); end;
function TWkWebview.GetTitle: string; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.GetTitle else Result:=FOptions.Title; end;
procedure TWkWebview.SetBounds(AWidth, AHeight: Integer); begin FOptions.Width := AWidth; FOptions.Height := AHeight; if not FClosed and (FWindow<>nil) then FWindow.SetBounds(AWidth,AHeight); UpdateChildBounds; end;
function TWkWebview.GetWidth: Integer; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.GetWidth else Result:=FOptions.Width; end;
function TWkWebview.GetHeight: Integer; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.GetHeight else Result:=FOptions.Height; end;
procedure TWkWebview.SetResizable(AResizable: Boolean); begin FOptions.Resizable := AResizable; if not FClosed and (FWindow<>nil) then FWindow.SetResizable(AResizable); end;
procedure TWkWebview.Maximize; begin if not FClosed and (FWindow<>nil) then FWindow.Maximize; end;
procedure TWkWebview.Unmaximize; begin if not FClosed and (FWindow<>nil) then FWindow.Unmaximize; end;
function TWkWebview.IsMaximized: Boolean; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.IsMaximized else Result:=False; end;
procedure TWkWebview.Minimize; begin if not FClosed and (FWindow<>nil) then FWindow.Minimize; end;
procedure TWkWebview.Restore; begin if not FClosed and (FWindow<>nil) then FWindow.Restore; end;
function TWkWebview.IsMinimized: Boolean; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.IsMinimized else Result:=False; end;
procedure TWkWebview.SetZoom(AFactor: Double); begin FZoom := AFactor; end;
function TWkWebview.GetZoom: Double; begin Result := FZoom; end;
procedure TWkWebview.SetUserAgent(const AUserAgent: string); begin FUserAgent := AUserAgent; end;
function TWkWebview.GetUserAgent: string; begin Result := FUserAgent; end;
function TWkWebview.GetScaleFactor: Double; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.GetScaleFactor else Result:=1.0; end;
procedure TWkWebview.RemovePending(ARec: PEvalRec); inline;
begin
  // perf: single source live registry Unregister -> bytes.ops VecRemoveSwap inline O(1) zero-copy swap, Default(nil) trailing, avoids O(n) shift
  if FPendingEvals <> nil then
    FPendingEvals.Unregister(ARec);
end;

procedure TWkWebview.DoScaleChanged(ANewScale: Double); inline;
var
  I: Integer;
begin
  // perf: single linear scan over unified registry Vec, inline, O(n) single pass, zero 3× traversal, zero extra alloc, bytes.ops single source
  if FOnScaleChanged = nil then Exit;
  for I := 0 to FOnScaleChanged.Count - 1 do
    if Assigned(FOnScaleChanged.At(I)) then
      try
        FOnScaleChanged.At(I)(ANewScale);
      except
      end;
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  // single source: live compact registry Register -> bytes.ops VecGrow 0→4→2× inline, zero extra call, single source
  if FOnScaleChanged <> nil then
    FOnScaleChanged.Register(AHandler);
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  // single source: webview.callbacks inline, zero triple copy
  OnScaleChanged(WebviewScaleMethodToRef(AHandler));
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnScaleChanged(WebviewScaleProcToRef(AHandler));
end;
procedure TWkWebview.Navigate(const {%H-}AUrl: string); begin end;
procedure TWkWebview.NavigateToString(const {%H-}AHtml: string); begin end;
procedure TWkWebview.Reload; begin end;
procedure TWkWebview.Stop; begin end;
function TWkWebview.CanGoBack: Boolean; begin Result := False; end;
function TWkWebview.GoBack: Boolean; begin Result := False; end;
function TWkWebview.CanGoForward: Boolean; begin Result := False; end;
function TWkWebview.GoForward: Boolean; begin Result := False; end;
procedure TWkWebview.Eval(const {%H-}AJavascript: string; {%H-}ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
var
  LErr: EWebviewEvalFailed;
begin
  if FClosed then
  begin
    if Assigned(AOnError) then
    begin
      LErr := EWebviewEvalFailed.Create('webview window is closed');
      try AOnError(LErr); finally LErr.Free; end;
    end;
    Exit;
  end;
  // zero-allocation fast path: stub has no engine, exactly-once fail via OnError without New/Grow/Remove/Dispose churn (bytes.ops single source preserved)
  if Assigned(AOnError) then
  begin
    LErr := EWebviewEvalFailed.Create('WKWebView not available');
    try AOnError(LErr); finally LErr.Free; end;
  end;
end;
procedure TWkWebview.Emit(const {%H-}AEvent, {%H-}APayloadJson: string); begin end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  // single source: live compact registry Register -> bytes.ops VecGrow 0→4→2× inline
  if FOnNavStarted <> nil then
    FOnNavStarted.Register(AHandler);
end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationStarted(WebviewNavMethodToRef(AHandler));
end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationStarted(WebviewNavProcToRef(AHandler));
end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  if FOnNavFinished <> nil then
    FOnNavFinished.Register(AHandler);
end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationFinished(WebviewNavMethodToRef(AHandler));
end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationFinished(WebviewNavProcToRef(AHandler));
end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  if FOnNavFailed <> nil then
    FOnNavFailed.Register(AHandler);
end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationFailed(WebviewNavFailedMethodToRef(AHandler));
end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationFailed(WebviewNavFailedProcToRef(AHandler));
end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  if FOnWindowClosed <> nil then
    FOnWindowClosed.Register(AHandler);
end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnWindowClosed(WebviewNotifyMethodToRef(AHandler));
end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnWindowClosed(WebviewNotifyProcToRef(AHandler));
end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  if FOnReady <> nil then
    FOnReady.Register(AHandler);
end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnReady(WebviewNotifyMethodToRef(AHandler));
end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnReady(WebviewNotifyProcToRef(AHandler));
end;
function TWkWebview.GetInvokes: IWebviewInvokeRegistry; inline; begin Result := FInvokesIntf; end;
function TWkWebview.GetAssets: IWebviewAssets; inline; begin Result := FAssetsIntf; end;
function TWkWebview.NativeHandle: TWebviewNativeHandle; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.NativeHandle else Result:=nil; end;
function TWkWebview.GetDispatcher: IWebviewDispatcher; begin if FWindow<>nil then Result:=FWindow.Dispatcher as IWebviewDispatcher else Result:=nil; end;
procedure TWkWebview.Post(AProc: TWebviewProcRef); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProcMethod); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProc); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
function TWkWebview.IsOnMainThread: Boolean; begin if FWindow<>nil then Result:=FWindow.Dispatcher.IsOnMainThread else Result:= platform_thread_id = FOwnerThread; end;

initialization
  GLiveWindows := specialize TCompactLiveRegistry<TWkWebview>.Create;

finalization
  GLiveWindows.Free;

end.
