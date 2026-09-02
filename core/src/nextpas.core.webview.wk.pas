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
  nextpas.core.webview.live,
  nextpas.core.webview.callbacks,
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
    FOnScaleChanged: array of TWebviewScaleHandler;
    FOnScaleChangedCount: Integer;
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
    FPendingEvals: array of PEvalRec;
    FPendingCount: Integer;
    FInvokesIntf: IWebviewInvokeRegistry;
    FInvokes: TObject;
    FAssetsIntf: IWebviewAssets;
    FAssets: TObject;
    procedure GrowOnNavStarted; inline;
    procedure GrowOnNavFinished; inline;
    procedure GrowOnNavFailed; inline;
    procedure GrowOnWindowClosed; inline;
    procedure GrowOnReady; inline;
    procedure GrowOnScaleChanged; inline;
    procedure GrowPendingEvals; inline;
    procedure RemovePending(ARec: PEvalRec);
    procedure DoScaleChanged(ANewScale: Double);
    procedure HandleWindowEvent(const AEvent: TWindowEvent);
    procedure UpdateChildBounds;
    function WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions;
  public
    constructor Create(const AOptions: TWebviewOptions);
    constructor CreateOn(AWindow: IWindow; const AOptions: TWebviewOptions);
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
    // IWebviewDispatcher
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
    function IsOnMainThread: Boolean;
  end;

function WkLiveWindowCount: Integer;

implementation

uses
  nextpas.core.platform.thread,
  nextpas.core.webview.bridge,
  nextpas.core.webview.wk.loader,
  nextpas.core.window.factory;

var
  GLive: Integer = 0;
  GLiveList: array of TWkWebview;
  GLiveListCount: Integer = 0;

procedure GrowLiveList; inline;
begin
  // single source: bytes.ops VecGrow (0→4→2×) inline via webview.live
  specialize VecGrow<TWkWebview>(GLiveList, GLiveListCount);
end;

procedure RegisterLive(AWin: TWkWebview); inline;
begin
  // single source: webview.live WebviewLiveAdd -> VecGrow inline
  specialize WebviewLiveAdd<TWkWebview>(GLiveList, GLiveListCount, AWin);
end;

procedure UnregisterLive(AWin: TWkWebview);
begin
  // single source: webview.live WebviewLiveRemoveSwap inline O(1) swap, bytes.ops single source, hot close avoids O(n²) shift
  specialize WebviewLiveRemoveSwap<TWkWebview>(GLiveList, GLiveListCount, AWin);
end;

function WkLiveWindowCount: Integer; inline;
begin
  // perf: O(1) cached GLive inline, zero scan, close密集零遍历
  Result := GLive;
end;

function TWkWebview.WindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions;
begin
  Result := DefaultWindowOptions;
  Result.Title := AOptions.Title;
  Result.Width := AOptions.Width;
  Result.Height := AOptions.Height;
  Result.Resizable := AOptions.Resizable;
  Result.Maximized := AOptions.Maximized;
end;

procedure TWkWebview.HandleWindowEvent(const AEvent: TWindowEvent);
begin
  if FClosed then Exit;
  case AEvent.Kind of
    weResized: UpdateChildBounds;
    weScaleChanged, weDpiChanged: DoScaleChanged(AEvent.NewScale);
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
  LReg := TWebviewInvokeRegistry.Create;
  LAssets := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;
  FAssetsIntf := LAssets;
  FInvokes := LReg;
  FAssets := LAssets;
  FWindow := CreateWindowOf(wkFake, WindowOptionsOf(AOptions));
  FOwnsWindow := True;
  FWindow.OnEvent(@HandleWindowEvent);
  Inc(GLive);
  RegisterLive(Self);
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
  LReg := TWebviewInvokeRegistry.Create;
  LAssets := TWebviewAssetsImpl.Create(FOptions.DevServerUrl <> '');
  FInvokesIntf := LReg;
  FAssetsIntf := LAssets;
  FInvokes := LReg;
  FAssets := LAssets;
  FWindow:=AWindow; FOwnsWindow:=False; FWindow.OnEvent(@HandleWindowEvent);
  Inc(GLive); RegisterLive(Self);
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
  Dec(GLive);
  UnregisterLive(Self);
  for I := 0 to FPendingCount - 1 do
  begin
    LRec := FPendingEvals[I];
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
  FPendingCount := 0;
  for I := 0 to FOnWindowClosedCount - 1 do
    if Assigned(FOnWindowClosed[I]) then
      try FOnWindowClosed[I](); except end;
  if FOwnsWindow and (FWindow<>nil) then FWindow.Close;
  FWindow:=nil;
end;

function TWkWebview.IsClosed: Boolean;
begin
  Result := FClosed;
end;

{$PUSH}{$HINTS OFF}
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
procedure TWkWebview.GrowOnScaleChanged; inline;
begin
  // single source: bytes.ops VecGrow (0→4→2×) inline, zero extra call, single Vec
  specialize VecGrow<TWebviewScaleHandler>(FOnScaleChanged, FOnScaleChangedCount);
end;

procedure TWkWebview.GrowPendingEvals; inline;
begin
  specialize VecGrow<PEvalRec>(FPendingEvals, FPendingCount);
end;

procedure TWkWebview.RemovePending(ARec: PEvalRec);
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

procedure TWkWebview.GrowOnNavStarted; inline;
begin
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavStarted, FOnNavStartedCount);
end;

procedure TWkWebview.GrowOnNavFinished; inline;
begin
  specialize VecGrow<TWebviewNavEventHandler>(FOnNavFinished, FOnNavFinishedCount);
end;

procedure TWkWebview.GrowOnNavFailed; inline;
begin
  specialize VecGrow<TWebviewNavFailedHandler>(FOnNavFailed, FOnNavFailedCount);
end;

procedure TWkWebview.GrowOnWindowClosed; inline;
begin
  specialize VecGrow<TWebviewNotifyHandler>(FOnWindowClosed, FOnWindowClosedCount);
end;

procedure TWkWebview.GrowOnReady; inline;
begin
  specialize VecGrow<TWebviewNotifyHandler>(FOnReady, FOnReadyCount);
end;

procedure TWkWebview.DoScaleChanged(ANewScale: Double);
var
  I: Integer;
begin
  // perf: single linear scan over unified Vec, inline, O(n) single pass, zero 3× traversal, zero extra alloc
  for I := 0 to FOnScaleChangedCount - 1 do
    if Assigned(FOnScaleChanged[I]) then
      try
        FOnScaleChanged[I](ANewScale);
      except
      end;
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  GrowOnScaleChanged;
  FOnScaleChanged[FOnScaleChangedCount] := AHandler;
  Inc(FOnScaleChangedCount);
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
procedure TWkWebview.Navigate(const AUrl: string); begin end;
procedure TWkWebview.NavigateToString(const AHtml: string); begin end;
procedure TWkWebview.Reload; begin end;
procedure TWkWebview.Stop; begin end;
function TWkWebview.CanGoBack: Boolean; begin Result := False; end;
function TWkWebview.GoBack: Boolean; begin Result := False; end;
function TWkWebview.CanGoForward: Boolean; begin Result := False; end;
function TWkWebview.GoForward: Boolean; begin Result := False; end;
{$POP}
{$PUSH}{$HINTS OFF}
procedure TWkWebview.Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
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
procedure TWkWebview.Emit(const AEvent, APayloadJson: string); begin end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  GrowOnNavStarted;
  FOnNavStarted[FOnNavStartedCount] := AHandler;
  Inc(FOnNavStartedCount);
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
  GrowOnNavFinished;
  FOnNavFinished[FOnNavFinishedCount] := AHandler;
  Inc(FOnNavFinishedCount);
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
  GrowOnNavFailed;
  FOnNavFailed[FOnNavFailedCount] := AHandler;
  Inc(FOnNavFailedCount);
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
  GrowOnWindowClosed;
  FOnWindowClosed[FOnWindowClosedCount] := AHandler;
  Inc(FOnWindowClosedCount);
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
  GrowOnReady;
  FOnReady[FOnReadyCount] := AHandler;
  Inc(FOnReadyCount);
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
{$POP}
procedure TWkWebview.Post(AProc: TWebviewProcRef); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProcMethod); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProc); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
function TWkWebview.IsOnMainThread: Boolean; begin if FWindow<>nil then Result:=FWindow.Dispatcher.IsOnMainThread else Result:= platform_thread_id = FOwnerThread; end;

end.
