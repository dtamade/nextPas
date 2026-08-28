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
  nextpas.core.webview.intf;

type
  TWkWebview = class(TInterfacedObject, IWebviewWindow, IWebviewDispatcher)
  private
    FOptions: TWebviewOptions;
    FClosed: Boolean;
    FOwnerThread: UInt64;
    FUserAgent: string;
    FZoom: Double;
    FScaleHandlersRef: array of TWebviewScaleHandler;
    FScaleHandlersRefCount: Integer;
    FScaleHandlersMethod: array of TWebviewScaleMethod;
    FScaleHandlersMethodCount: Integer;
    FScaleHandlersProc: array of TWebviewScaleProc;
    FScaleHandlersProcCount: Integer;
    procedure GrowScaleRef; inline;
    procedure GrowScaleMethod; inline;
    procedure GrowScaleProc; inline;
    procedure DoScaleChanged(ANewScale: Double);
  public
    constructor Create(const AOptions: TWebviewOptions);
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
  nextpas.core.webview.wk.loader;

var
  GLive: Integer = 0;
  GLiveList: array of TWkWebview;
  GLiveListCount: Integer = 0;

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

constructor TWkWebview.Create(const AOptions: TWebviewOptions);
var
  LInfo: TWkLoadInfo;
begin
  CheckWebviewOptions(AOptions);
  if not TryLoadWk(LInfo) then
    raise EWebviewBackendUnavailable.Create('WKWebView runtime not available on this platform (requires macOS)');
  // 桩：loader 可用时最小回显（当前分支不可达）
  FOptions := AOptions;
  FOwnerThread := platform_thread_id;
  FUserAgent := '';
  FZoom := 1.0;
  FClosed := False;
  Inc(GLive);
  RegisterLive(Self);
end;

procedure TWkWebview.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  Dec(GLive);
  UnregisterLive(Self);
end;

function TWkWebview.IsClosed: Boolean;
begin
  Result := FClosed;
end;

{$PUSH}{$HINTS OFF}
procedure TWkWebview.Show; begin end;
procedure TWkWebview.Hide; begin end;
function TWkWebview.IsVisible: Boolean; begin Result := not FClosed; end;
procedure TWkWebview.Focus; begin end;
procedure TWkWebview.SetTitle(const ATitle: string); begin FOptions.Title := ATitle; end;
function TWkWebview.GetTitle: string; begin Result := FOptions.Title; end;
procedure TWkWebview.SetBounds(AWidth, AHeight: Integer); begin FOptions.Width := AWidth; FOptions.Height := AHeight; end;
function TWkWebview.GetWidth: Integer; begin Result := FOptions.Width; end;
function TWkWebview.GetHeight: Integer; begin Result := FOptions.Height; end;
procedure TWkWebview.SetResizable(AResizable: Boolean); begin FOptions.Resizable := AResizable; end;
procedure TWkWebview.Maximize; begin end;
procedure TWkWebview.Unmaximize; begin end;
function TWkWebview.IsMaximized: Boolean; begin Result := False; end;
procedure TWkWebview.Minimize; begin end;
procedure TWkWebview.Restore; begin end;
function TWkWebview.IsMinimized: Boolean; begin Result := False; end;
procedure TWkWebview.SetZoom(AFactor: Double); begin FZoom := AFactor; end;
function TWkWebview.GetZoom: Double; begin Result := FZoom; end;
procedure TWkWebview.SetUserAgent(const AUserAgent: string); begin FUserAgent := AUserAgent; end;
function TWkWebview.GetUserAgent: string; begin Result := FUserAgent; end;
function TWkWebview.GetScaleFactor: Double; begin Result := 1.0; end;
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
var LErr: EWebviewEvalFailed;
begin
  if Assigned(AOnError) then
  begin
    LErr := EWebviewEvalFailed.Create('WKWebView not available');
    try AOnError(LErr); finally LErr.Free; end;
  end;
end;
procedure TWkWebview.Emit(const AEvent, APayloadJson: string); begin end;
function TWkWebview.GetDispatcher: IWebviewDispatcher; begin Result := Self as IWebviewDispatcher; end;
function TWkWebview.NativeHandle: TWebviewNativeHandle; begin Result := nil; end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload; begin end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventMethod); overload; begin end;
procedure TWkWebview.OnNavigationStarted(AHandler: TWebviewNavEventProc); overload; begin end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload; begin end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventMethod); overload; begin end;
procedure TWkWebview.OnNavigationFinished(AHandler: TWebviewNavEventProc); overload; begin end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload; begin end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod); overload; begin end;
procedure TWkWebview.OnNavigationFailed(AHandler: TWebviewNavFailedProc); overload; begin end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyHandler); overload; begin end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyMethod); overload; begin end;
procedure TWkWebview.OnWindowClosed(AHandler: TWebviewNotifyProc); overload; begin end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyHandler); overload; begin end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyMethod); overload; begin end;
procedure TWkWebview.OnReady(AHandler: TWebviewNotifyProc); overload; begin end;
function TWkWebview.GetInvokes: IWebviewInvokeRegistry; begin Result := nil; end;
function TWkWebview.GetAssets: IWebviewAssets; begin Result := nil; end;
{$POP}
procedure TWkWebview.Post(AProc: TWebviewProcRef); overload; begin if FClosed then Exit; if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProcMethod); overload; begin if FClosed then Exit; if Assigned(AProc) then AProc(); end;
procedure TWkWebview.Post(AProc: TWebviewProc); overload; begin if FClosed then Exit; if Assigned(AProc) then AProc(); end;
function TWkWebview.IsOnMainThread: Boolean; begin Result := platform_thread_id = FOwnerThread; end;

end.
