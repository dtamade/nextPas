unit nextpas.core.webview.webview2;

{** @desc Windows 后端桩（Wave 2 预备）。

       当前为“编译期占位 + 运行时不可用”语义：TryLoadWebView2 失败即
       抛 EWebviewBackendUnavailable；成功路径预留 COM 窗口壳接入位，
       与 gtk 后端同生命周期纪律（FSelfKeepAlive、Close 幂等、
       Eval exactly-one、Dispatcher.Post 主线程等）但暂不实现真实
       WebView2 controller——为 wine 交叉验证与源码契约冻结提供
       可编译、可探测的锚点。

       后续真实实现接线位：
       - WebView2Loader CreateCoreWebView2EnvironmentWithOptions
       - ICoreWebView2Environment.CreateCoreWebView2Controller
       - ExecuteScript / WebMessageReceived 桥接
       本单元禁止直接 uses Windows 以保持 Linux 交叉编译。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.bridge;

type
  TWebView2Webview = class(TInterfacedObject, IWebviewWindow, IWebviewDispatcher)
  private
    FOptions: TWebviewOptions;
    FClosed: Boolean;
  public
    constructor Create(const AOptions: TWebviewOptions);
    destructor Destroy; override;
    { IWebviewDispatcher }
    procedure Post(AProc: TWebviewProcRef); overload;
    procedure Post(AProc: TWebviewProcMethod); overload;
    procedure Post(AProc: TWebviewProc); overload;
    function IsOnMainThread: Boolean;
    { IWebviewWindow — 桩：除标题/几何本地回显外，其余抛 Closed 或不可用 }
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
  nextpas.core.webview.webview2.loader;

var
  GLive: Integer = 0;

function WebView2LiveWindowCount: Integer;
begin
  Result := GLive;
end;

constructor TWebView2Webview.Create(const AOptions: TWebviewOptions);
var
  LInfo: TWebView2LoadInfo;
begin
  CheckWebviewOptions(AOptions);
  if not TryLoadWebView2(LInfo) then
    raise EWebviewBackendUnavailable.Create(
      'WebView2 runtime not found (probed WebView2Loader.dll)');
  FOptions := AOptions;
  FClosed := False;
  Inc(GLive);
  { 真实 controller 创建位：Environment → Controller → WebView，
    绑定 bridge 脚本、scheme、ExecuteScript 回调。当前桩不创建
    原生窗口，RunLoop 侧不阻塞；factory 已保证仅 Windows/wine 分支
    进入，Linux 原生此构造永不触达（WebviewBackendAvailable 为 False）。 }
end;

destructor TWebView2Webview.Destroy;
begin
  if not FClosed then Dec(GLive);
  inherited Destroy;
end;

procedure TWebView2Webview.Post(AProc: TWebviewProcRef);
begin
  if Assigned(AProc) then AProc();
end;
procedure TWebView2Webview.Post(AProc: TWebviewProcMethod);
begin
  if Assigned(AProc) then AProc();
end;
procedure TWebView2Webview.Post(AProc: TWebviewProc);
begin
  if Assigned(AProc) then AProc();
end;
function TWebView2Webview.IsOnMainThread: Boolean;
begin
  Result := True;
end;

procedure TWebView2Webview.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  Dec(GLive);
end;
function TWebView2Webview.IsClosed: Boolean;
begin
  Result := FClosed;
end;
procedure TWebView2Webview.Show;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
procedure TWebView2Webview.Hide;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
function TWebView2Webview.IsVisible: Boolean;
begin
  Result := not FClosed;
end;
procedure TWebView2Webview.Focus;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
procedure TWebView2Webview.SetTitle(const ATitle: string);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
  FOptions.Title := ATitle;
end;
function TWebView2Webview.GetTitle: string;
begin
  Result := FOptions.Title;
end;
procedure TWebView2Webview.SetBounds(AWidth, AHeight: Integer);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
  FOptions.Width := AWidth; FOptions.Height := AHeight;
end;
function TWebView2Webview.GetWidth: Integer;
begin
  Result := FOptions.Width;
end;
function TWebView2Webview.GetHeight: Integer;
begin
  Result := FOptions.Height;
end;
procedure TWebView2Webview.SetResizable(AResizable: Boolean);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
  FOptions.Resizable := AResizable;
end;
procedure TWebView2Webview.Maximize;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
  FOptions.Maximized := True;
end;
procedure TWebView2Webview.Unmaximize;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
  FOptions.Maximized := False;
end;
function TWebView2Webview.IsMaximized: Boolean;
begin
  Result := FOptions.Maximized;
end;
procedure TWebView2Webview.Minimize;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
procedure TWebView2Webview.Restore;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
function TWebView2Webview.IsMinimized: Boolean;
begin
  Result := False;
end;
procedure TWebView2Webview.SetZoom(AFactor: Double);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
function TWebView2Webview.GetZoom: Double;
begin
  Result := 1.0;
end;
procedure TWebView2Webview.SetUserAgent(const AUserAgent: string);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
function TWebView2Webview.GetUserAgent: string;
begin
  Result := '';
end;
function TWebView2Webview.GetScaleFactor: Double;
begin
  Result := 1.0;
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleHandler);
begin
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleMethod);
begin
end;
procedure TWebView2Webview.OnScaleChanged(AHandler: TWebviewScaleProc);
begin
end;
procedure TWebView2Webview.Navigate(const AUrl: string);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
procedure TWebView2Webview.NavigateToString(const AHtml: string);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
procedure TWebView2Webview.Reload;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
procedure TWebView2Webview.Stop;
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
function TWebView2Webview.CanGoBack: Boolean;
begin
  Result := False;
end;
function TWebView2Webview.GoBack: Boolean;
begin
  Result := False;
end;
function TWebView2Webview.CanGoForward: Boolean;
begin
  Result := False;
end;
function TWebView2Webview.GoForward: Boolean;
begin
  Result := False;
end;
procedure TWebView2Webview.Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
var
  LErr: EWebviewEvalFailed;
begin
  if FClosed then
  begin
    if Assigned(AOnError) then
    begin
      LErr := EWebviewEvalFailed.Create('closed');
      try AOnError(LErr); finally LErr.Free; end;
    end;
    Exit;
  end;
  if Assigned(AOnError) then
  begin
    LErr := EWebviewEvalFailed.Create('WebView2 Eval not implemented in stub');
    try AOnError(LErr); finally LErr.Free; end;
  end;
end;
procedure TWebView2Webview.Emit(const AEvent, APayloadJson: string);
begin
  if FClosed then raise EWebviewClosed.Create('closed');
end;
function TWebView2Webview.GetDispatcher: IWebviewDispatcher;
begin
  Result := Self as IWebviewDispatcher;
end;
function TWebView2Webview.NativeHandle: TWebviewNativeHandle;
begin
  Result := nil;
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventHandler);
begin
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventMethod);
begin
end;
procedure TWebView2Webview.OnNavigationStarted(AHandler: TWebviewNavEventProc);
begin
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventHandler);
begin
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventMethod);
begin
end;
procedure TWebView2Webview.OnNavigationFinished(AHandler: TWebviewNavEventProc);
begin
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedHandler);
begin
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedMethod);
begin
end;
procedure TWebView2Webview.OnNavigationFailed(AHandler: TWebviewNavFailedProc);
begin
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyHandler);
begin
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyMethod);
begin
end;
procedure TWebView2Webview.OnWindowClosed(AHandler: TWebviewNotifyProc);
begin
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyHandler);
begin
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyMethod);
begin
end;
procedure TWebView2Webview.OnReady(AHandler: TWebviewNotifyProc);
begin
end;
function TWebView2Webview.GetInvokes: IWebviewInvokeRegistry;
begin
  Result := nil;
end;
function TWebView2Webview.GetAssets: IWebviewAssets;
begin
  Result := nil;
end;

end.
