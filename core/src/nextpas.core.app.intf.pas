unit nextpas.core.app.intf;

{** @desc nextpas.core.app L3 家族：应用壳接口。
       P2：App 持有窗口集合（精确 WindowCount + Add/Remove + GetWindow）、
       app-aware NewWindow（Build 自动注册并钩 OnWindowClosed 自摘）、
       Builder 聚合资产挂载（MountEmbedded/MountDirectory）与 webview 同语义。

       线程契约：Add/Remove/Count 仅主线程；P2 仍单线程精确，P3 再上 GSchemeLock。 *}

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
    function GetWindow(AIdx: Integer): IWebviewWindow;
    function NewWindowBuilder: IWebviewBuilder;
    function NewWindow: IWebviewBuilder; // alias, app-aware
    procedure AddWindow(AWin: IWebviewWindow);
    procedure RemoveWindow(AWin: IWebviewWindow);
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
    function MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider): IAppBuilder;
    function MountDirectory(const APrefix, ARootDir: string): IAppBuilder;
    function Kind(AKind: TWebviewKind): IAppBuilder;
    function Build: IApp;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

implementation

end.
