unit nextpas.core.app.intf;

{** @desc nextpas.core.app L3 家族：应用壳接口。
       IApp 拥有窗口集合与主循环；IAppBuilder 提供 fluent 链。
       单例语义：每个 Build 出一个 IApp（持有首窗），后续窗口经
       IApp.NewWindowBuilder 再 Build 独立窗口，共享同一 RunLoop。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.factory;

type
  IApp = interface
    ['{A1B2C3D4-E5F6-47A8-9B0C-112233445501}']
    function GetMainWindow: IWebviewWindow;
    property MainWindow: IWebviewWindow read GetMainWindow;
    function WindowCount: Integer;
    function NewWindowBuilder: IWebviewBuilder;
    procedure Run;
    procedure Quit;
    procedure Close;
    function IsClosed: Boolean;
  end;

  IAppBuilder = interface
    ['{A1B2C3D4-E5F6-47A8-9B0C-112233445502}']
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

implementation

end.
