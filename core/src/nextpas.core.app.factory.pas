unit nextpas.core.app.factory;

{** @desc nextpas.core.app 工厂与 Builder：薄封装 webview 工厂，
       提供 App 心智的 fluent 入口。所有校验复用 webview.base
       单源，不产生重复逻辑。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.factory,
  nextpas.core.app.base,
  nextpas.core.app.intf;

type
  TAppBuilder = record
    class function New: IAppBuilder; static;
  end;

function DefaultAppKind: TAppKind; inline;
function AppBackendAvailable(AKind: TAppKind): Boolean; inline;

implementation

type
  TAppImpl = class(TInterfacedObject, IApp)
  private
    FMain: IWebviewWindow;
  public
    constructor Create(const AWindow: IWebviewWindow);
    function GetMainWindow: IWebviewWindow;
    function WindowCount: Integer;
    function NewWindowBuilder: IWebviewBuilder;
    procedure Run;
    procedure Quit;
    procedure Close;
    function IsClosed: Boolean;
  end;

  TAppBuilderImpl = class(TInterfacedObject, IAppBuilder)
  private
    FBuilder: IWebviewBuilder;
  public
    constructor Create;
    function Title(const ATitle: string): IAppBuilder;
    function Size(AWidth, AHeight: Integer): IAppBuilder;
    function MinSize(AWidth, AHeight: Integer): IAppBuilder;
    function MaxSize(AWidth, AHeight: Integer): IAppBuilder;
    function Resizable(AResizable: Boolean): IAppBuilder;
    function StartMaximized: IAppBuilder;
    function DebugTools(AEnabled: Boolean): IAppBuilder;
    function Scheme(const ASchemeName: string): IAppBuilder;
    function DataDirectory(const APath: string): IAppBuilder;
    function Ephemeral: IAppBuilder;
    function AddInitScript(const AJavascript: string): IAppBuilder;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler): IAppBuilder; overload;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncMethod): IAppBuilder; overload;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncProc): IAppBuilder; overload;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler): IAppBuilder; overload;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncMethod): IAppBuilder; overload;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncProc): IAppBuilder; overload;
    function OnReady(AHandler: TWebviewNotifyHandler): IAppBuilder; overload;
    function OnReady(AHandler: TWebviewNotifyMethod): IAppBuilder; overload;
    function OnReady(AHandler: TWebviewNotifyProc): IAppBuilder; overload;
    function InitialUrl(const AUrl: string): IAppBuilder;
    function InitialHtml(const AHtml: string): IAppBuilder;
    function DevServerUrl(const AUrl: string): IAppBuilder;
    function Kind(AKind: TWebviewKind): IAppBuilder;
    function Build: IApp;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

class function TAppBuilder.New: IAppBuilder;
begin
  Result := TAppBuilderImpl.Create;
end;

function DefaultAppKind: TAppKind;
begin
  Result := nextpas.core.webview.factory.DefaultWebviewKind;
end;

function AppBackendAvailable(AKind: TAppKind): Boolean;
begin
  Result := nextpas.core.webview.factory.WebviewBackendAvailable(AKind);
end;

{ TAppImpl }

constructor TAppImpl.Create(const AWindow: IWebviewWindow);
begin
  inherited Create;
  FMain := AWindow;
end;

function TAppImpl.GetMainWindow: IWebviewWindow;
begin
  Result := FMain;
end;

function TAppImpl.WindowCount: Integer;
begin
  if (FMain <> nil) and (not FMain.IsClosed) then
    Result := 1
  else
    Result := 0;
end;

function TAppImpl.NewWindowBuilder: IWebviewBuilder;
begin
  Result := nextpas.core.webview.factory.TWebviewBuilder.New;
end;

procedure TAppImpl.Run;
begin
  nextpas.core.webview.factory.WebviewRunLoop;
end;

procedure TAppImpl.Quit;
begin
  nextpas.core.webview.factory.WebviewExitLoop;
end;

procedure TAppImpl.Close;
begin
  if (FMain <> nil) and (not FMain.IsClosed) then
    FMain.Close;
end;

function TAppImpl.IsClosed: Boolean;
begin
  Result := (FMain = nil) or FMain.IsClosed;
end;

{ TAppBuilderImpl }

constructor TAppBuilderImpl.Create;
begin
  inherited Create;
  FBuilder := nextpas.core.webview.factory.TWebviewBuilder.New;
end;

function TAppBuilderImpl.Title(const ATitle: string): IAppBuilder;
begin
  FBuilder.Title(ATitle);
  Result := Self;
end;

function TAppBuilderImpl.Size(AWidth, AHeight: Integer): IAppBuilder;
begin
  FBuilder.Size(AWidth, AHeight);
  Result := Self;
end;

function TAppBuilderImpl.MinSize(AWidth, AHeight: Integer): IAppBuilder;
begin
  FBuilder.MinSize(AWidth, AHeight);
  Result := Self;
end;

function TAppBuilderImpl.MaxSize(AWidth, AHeight: Integer): IAppBuilder;
begin
  FBuilder.MaxSize(AWidth, AHeight);
  Result := Self;
end;

function TAppBuilderImpl.Resizable(AResizable: Boolean): IAppBuilder;
begin
  FBuilder.Resizable(AResizable);
  Result := Self;
end;

function TAppBuilderImpl.StartMaximized: IAppBuilder;
begin
  FBuilder.StartMaximized;
  Result := Self;
end;

function TAppBuilderImpl.DebugTools(AEnabled: Boolean): IAppBuilder;
begin
  FBuilder.DebugTools(AEnabled);
  Result := Self;
end;

function TAppBuilderImpl.Scheme(const ASchemeName: string): IAppBuilder;
begin
  FBuilder.Scheme(ASchemeName);
  Result := Self;
end;

function TAppBuilderImpl.DataDirectory(const APath: string): IAppBuilder;
begin
  FBuilder.DataDirectory(APath);
  Result := Self;
end;

function TAppBuilderImpl.Ephemeral: IAppBuilder;
begin
  FBuilder.Ephemeral;
  Result := Self;
end;

function TAppBuilderImpl.AddInitScript(const AJavascript: string): IAppBuilder;
begin
  FBuilder.AddInitScript(AJavascript);
  Result := Self;
end;

function TAppBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncHandler): IAppBuilder;
begin
  FBuilder.RegisterInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncMethod): IAppBuilder;
begin
  FBuilder.RegisterInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncProc): IAppBuilder;
begin
  FBuilder.RegisterInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncHandler): IAppBuilder;
begin
  FBuilder.RegisterAsyncInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncMethod): IAppBuilder;
begin
  FBuilder.RegisterAsyncInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncProc): IAppBuilder;
begin
  FBuilder.RegisterAsyncInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.OnReady(AHandler: TWebviewNotifyHandler): IAppBuilder;
begin
  FBuilder.OnReady(AHandler);
  Result := Self;
end;

function TAppBuilderImpl.OnReady(AHandler: TWebviewNotifyMethod): IAppBuilder;
begin
  FBuilder.OnReady(AHandler);
  Result := Self;
end;

function TAppBuilderImpl.OnReady(AHandler: TWebviewNotifyProc): IAppBuilder;
begin
  FBuilder.OnReady(AHandler);
  Result := Self;
end;

function TAppBuilderImpl.InitialUrl(const AUrl: string): IAppBuilder;
begin
  FBuilder.InitialUrl(AUrl);
  Result := Self;
end;

function TAppBuilderImpl.InitialHtml(const AHtml: string): IAppBuilder;
begin
  FBuilder.InitialHtml(AHtml);
  Result := Self;
end;

function TAppBuilderImpl.DevServerUrl(const AUrl: string): IAppBuilder;
begin
  FBuilder.DevServerUrl(AUrl);
  Result := Self;
end;

function TAppBuilderImpl.Kind(AKind: TWebviewKind): IAppBuilder;
begin
  FBuilder.Kind(AKind);
  Result := Self;
end;

function TAppBuilderImpl.Build: IApp;
var
  LWin: IWebviewWindow;
begin
  LWin := FBuilder.Build;
  Result := TAppImpl.Create(LWin);
end;

procedure TAppBuilderImpl.Run(const AUrl: string);
var
  LApp: IApp;
begin
  LApp := Build;
  LApp.MainWindow.Navigate(AUrl);
  LApp.Run;
end;

procedure TAppBuilderImpl.RunHtml(const AHtml: string);
var
  LApp: IApp;
begin
  LApp := Build;
  LApp.MainWindow.NavigateToString(AHtml);
  LApp.Run;
end;

end.
