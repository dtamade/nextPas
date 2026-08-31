unit nextpas.core.webview.wk;

{** @desc macOS WKWebView 后端桩（Wave 3）。

       当前阶段为桩：构造即检查 TryLoadWk，不可用时抛
       EWebviewBackendUnavailable（消息含探针名），与 webview2 桩同语义。
       Darwin 真实现待 stage0 ObjC 能力探通后接入（WKWebView +
       WKUserContentController + WKScriptMessageHandler）。

       桩的窗口语义：为保持 factory/builder 链路可测，桩在 loader 可用时
       提供最小窗口回显（复用 Win32/Gtk 壳的几何回显思想），当前 loader
       恒不可用，故所有路径均为 fail-fast。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
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
    FScaleHandlersRef: array of TWebviewScaleHandler;
    FScaleHandlersRefCount: Integer;
    FScaleHandlersMethod: array of TWebviewScaleMethod;
    FScaleHandlersMethodCount: Integer;
    FScaleHandlersProc: array of TWebviewScaleProc;
    FScaleHandlersProcCount: Integer;
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
    procedure GrowOnNavStarted; inline;
    procedure GrowOnNavFinished; inline;
    procedure GrowOnNavFailed; inline;
    procedure GrowOnWindowClosed; inline;
    procedure GrowOnReady; inline;
    procedure GrowScaleRef; inline;
    procedure GrowScaleMethod; inline;
    procedure GrowScaleProc; inline;
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
  nextpas.core.webview.wk.loader,
  nextpas.core.window.factory;

var
  GLive: Integer = 0;
  GLiveList: array of TWkWebview;
  GLiveListCount: Integer = 0;
  GWkEmptyInvokes: IWebviewInvokeRegistry = nil;
  GWkEmptyAssets: IWebviewAssets = nil;

procedure GrowLiveList; inline;
begin
  if GLiveListCount = Length(GLiveList) then
    SetLength(GLiveList, WebviewGrowCapacity(Length(GLiveList)));
end;

procedure RegisterLive(AWin: TWkWebview); inline;
begin
  GrowLiveList;
  GLiveList[GLiveListCount] := AWin;
  Inc(GLiveListCount);
end;

procedure UnregisterLive(AWin: TWkWebview);
var
  I, J: Integer;
begin
  for I := 0 to GLiveListCount - 1 do
    if GLiveList[I] = AWin then
    begin
      for J := I to GLiveListCount - 2 do
        GLiveList[J] := GLiveList[J + 1];
      Dec(GLiveListCount);
      if GLiveListCount < Length(GLiveList) then
        GLiveList[GLiveListCount] := nil;
      Break;
    end;
end;

function WkLiveWindowCount: Integer;
var
  I, LCnt: Integer;
begin
  LCnt := 0;
  for I := 0 to GLiveListCount - 1 do
    if (GLiveList[I] <> nil) and not GLiveList[I].FClosed then
      Inc(LCnt);
  Result := LCnt;
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
begin
  CheckWebviewOptions(AOptions);
  if not TryLoadWk(LInfo) then
    raise EWebviewBackendUnavailable.Create('WKWebView runtime not available on this platform (requires macOS)');
  FOptions := AOptions;
  FOwnerThread := platform_thread_id;
  FUserAgent := ''; FZoom := 1.0; FClosed := False;
  FWindow := CreateWindowOf(wkFake, WindowOptionsOf(AOptions));
  FOwnsWindow := True;
  FWindow.OnEvent(@HandleWindowEvent);
  Inc(GLive);
  RegisterLive(Self);
end;

constructor TWkWebview.CreateOn(AWindow: IWindow; const AOptions: TWebviewOptions);
var LInfo: TWkLoadInfo;
begin
  if AWindow=nil then raise EWebviewInvalidState.Create('Parent window is nil');
  CheckWebviewOptions(AOptions);
  if not TryLoadWk(LInfo) then raise EWebviewBackendUnavailable.Create('WKWebView runtime not available');
  FOptions:=AOptions; FOwnerThread:=platform_thread_id; FUserAgent:=''; FZoom:=1.0; FClosed:=False;
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
procedure TWkWebview.GrowScaleRef; inline;
begin
  if FScaleHandlersRefCount = Length(FScaleHandlersRef) then
    SetLength(FScaleHandlersRef, WebviewGrowCapacity(Length(FScaleHandlersRef)));
end;

procedure TWkWebview.GrowScaleMethod; inline;
begin
  if FScaleHandlersMethodCount = Length(FScaleHandlersMethod) then
    SetLength(FScaleHandlersMethod, WebviewGrowCapacity(Length(FScaleHandlersMethod)));
end;

procedure TWkWebview.GrowScaleProc; inline;
begin
  if FScaleHandlersProcCount = Length(FScaleHandlersProc) then
    SetLength(FScaleHandlersProc, WebviewGrowCapacity(Length(FScaleHandlersProc)));
end;

procedure TWkWebview.GrowPendingEvals; inline;
begin
  if FPendingCount = Length(FPendingEvals) then
    SetLength(FPendingEvals, WebviewGrowCapacity(Length(FPendingEvals)));
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
  if FOnNavStartedCount = Length(FOnNavStarted) then
    SetLength(FOnNavStarted, WebviewGrowCapacity(Length(FOnNavStarted)));
end;

procedure TWkWebview.GrowOnNavFinished; inline;
begin
  if FOnNavFinishedCount = Length(FOnNavFinished) then
    SetLength(FOnNavFinished, WebviewGrowCapacity(Length(FOnNavFinished)));
end;

procedure TWkWebview.GrowOnNavFailed; inline;
begin
  if FOnNavFailedCount = Length(FOnNavFailed) then
    SetLength(FOnNavFailed, WebviewGrowCapacity(Length(FOnNavFailed)));
end;

procedure TWkWebview.GrowOnWindowClosed; inline;
begin
  if FOnWindowClosedCount = Length(FOnWindowClosed) then
    SetLength(FOnWindowClosed, WebviewGrowCapacity(Length(FOnWindowClosed)));
end;

procedure TWkWebview.GrowOnReady; inline;
begin
  if FOnReadyCount = Length(FOnReady) then
    SetLength(FOnReady, WebviewGrowCapacity(Length(FOnReady)));
end;

procedure TWkWebview.DoScaleChanged(ANewScale: Double);
var
  I: Integer;
begin
  for I := 0 to FScaleHandlersRefCount - 1 do
    if Assigned(FScaleHandlersRef[I]) then FScaleHandlersRef[I](ANewScale);
  for I := 0 to FScaleHandlersMethodCount - 1 do
    if Assigned(FScaleHandlersMethod[I]) then FScaleHandlersMethod[I](ANewScale);
  for I := 0 to FScaleHandlersProcCount - 1 do
    if Assigned(FScaleHandlersProc[I]) then FScaleHandlersProc[I](ANewScale);
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleHandler); overload;
begin
  if not Assigned(AHandler) then Exit;
  GrowScaleRef;
  FScaleHandlersRef[FScaleHandlersRefCount] := AHandler;
  Inc(FScaleHandlersRefCount);
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleMethod); overload;
begin
  if not Assigned(AHandler) then Exit;
  GrowScaleMethod;
  FScaleHandlersMethod[FScaleHandlersMethodCount] := AHandler;
  Inc(FScaleHandlersMethodCount);
end;

procedure TWkWebview.OnScaleChanged(AHandler: TWebviewScaleProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  GrowScaleProc;
  FScaleHandlersProc[FScaleHandlersProcCount] := AHandler;
  Inc(FScaleHandlersProcCount);
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
  LRec: PEvalRec;
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
  New(LRec);
  LRec^.Callback := ACallback;
  LRec^.OnError := AOnError;
  LRec^.Done := False;
  GrowPendingEvals;
  FPendingEvals[FPendingCount] := LRec;
  Inc(FPendingCount);
  LRec^.Done := True;
  RemovePending(LRec);
  if Assigned(AOnError) then
  begin
    LErr := EWebviewEvalFailed.Create('WKWebView not available');
    try AOnError(LErr); finally LErr.Free; end;
  end;
  Dispose(LRec);
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
  OnNavigationStarted(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationStarted(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
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
  OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationFinished(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
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
  OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnNavigationFailed(
    procedure(const AEvent: TWebviewNavigationEvent)
    begin
      AHandler(AEvent);
    end);
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
  OnWindowClosed(
    procedure
    begin
      AHandler;
    end);
end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnWindowClosed(
    procedure
    begin
      AHandler;
    end);
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
  OnReady(
    procedure
    begin
      AHandler;
    end);
end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyProc); overload;
begin
  if not Assigned(AHandler) then Exit;
  OnReady(
    procedure
    begin
      AHandler;
    end);
end;
function TWkWebview.GetInvokes: IWebviewInvokeRegistry; begin Result := nil; end;
function TWkWebview.GetAssets: IWebviewAssets; begin Result := nil; end;
function TWkWebview.NativeHandle: TWebviewNativeHandle; begin if (FWindow<>nil) and not FClosed then Result:=FWindow.NativeHandle else Result:=nil; end;
function TWkWebview.GetDispatcher: IWebviewDispatcher; begin if FWindow<>nil then Result:=FWindow.Dispatcher as IWebviewDispatcher else Result:=nil; end;
{$POP}
procedure TWkWebview.Post(AProc: TWebviewProcRef); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProcMethod); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProc); overload; begin if FClosed then Exit; if FWindow<>nil then FWindow.Dispatcher.Post(AProc) else if Assigned(AProc) then AProc(); end;
function TWkWebview.IsOnMainThread: Boolean; begin if FWindow<>nil then Result:=FWindow.Dispatcher.IsOnMainThread else Result:= platform_thread_id = FOwnerThread; end;

end.
