unit nextpas.core.webview.webview2.ffi;

{** @desc WebView2 COM/Loader ABI 声明层。

       只含不透明句柄、COM 接口前向声明与 Loader 函数指针——无逻辑、
       无 external；绑定真相归 webview2.loader（经 platform.dl）。

       签名对照源：WebView2 SDK 1.0.2903.40 WebView2.h + WebView2Loader.dll
       导出表（CreateCoreWebView2EnvironmentWithOptions）。调用约定
       统一 stdcall（Win64 与 Linux 交叉编译均可）。RECT 单源复用
       platform.windows.base（window/win32 host owner），Linux 交叉编译
       仍可（platform.windows.base 为纯类型无 external）；除此之外
       禁止 uses 家族其他单元与 Windows 单元。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.windows.base;

type
  HRESULT = LongInt;
  ULONG = Cardinal;
  ULONGLONG = QWord;
  BOOL = LongBool;
  PWSTR = PWideChar;
  PCWSTR = PWideChar;

const
  S_OK    = HRESULT(0);
  E_FAIL  = HRESULT($80004005);
  E_NOTIMPL = HRESULT($80004001);

type
  { RECT/TagRECT 单源：复用 platform.windows.base host owner（与 window.win32.ffi 同源），消除 ABI 双源；16B 值类型 inline 零拷贝 }
  tagRECT = nextpas.core.platform.windows.base.tagRECT;
  TRect = tagRECT;
  RECT = tagRECT;
  PRECT = nextpas.core.platform.windows.base.PRECT;
  PRect = PRECT;

type
  { COM 前向（FPC System 已有 IUnknown，但为自包含声明） }
  ICoreWebView2Settings = interface(IUnknown)
    ['{9E1570B0-BF5E-4A4E-A0D0-9C00A5E1F46C}']
    function get_IsScriptEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_IsScriptEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_IsWebMessageEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_IsWebMessageEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_AreDefaultScriptDialogsEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_AreDefaultScriptDialogsEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_IsStatusBarEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_IsStatusBarEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_AreDevToolsEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_AreDevToolsEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_AreDefaultContextMenusEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_AreDefaultContextMenusEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_AreHostObjectsAllowed(out allowed: BOOL): HRESULT; stdcall;
    function put_AreHostObjectsAllowed(allowed: BOOL): HRESULT; stdcall;
    function get_IsZoomControlEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_IsZoomControlEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_IsBuiltInErrorPageEnabled(out enabled: BOOL): HRESULT; stdcall;
    function put_IsBuiltInErrorPageEnabled(enabled: BOOL): HRESULT; stdcall;
    function get_UserAgent(out userAgent: PWSTR): HRESULT; stdcall;
    function put_UserAgent(userAgent: PCWSTR): HRESULT; stdcall;
  end;
  ICoreWebView2 = interface(IUnknown)
    ['{76ECEACB-0462-4D94-AC83-45A67937797C}']
    function get_Settings(out Settings: ICoreWebView2Settings): HRESULT; stdcall;
    function get_Source(out uri: PWSTR): HRESULT; stdcall;
    function Navigate(uri: PCWSTR): HRESULT; stdcall;
    function NavigateToString(htmlContent: PCWSTR): HRESULT; stdcall;
    function add_NavigationStarting(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_NavigationStarting(token: Int64): HRESULT; stdcall;
    function add_ContentLoading(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_ContentLoading(token: Int64): HRESULT; stdcall;
    function add_SourceChanged(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_SourceChanged(token: Int64): HRESULT; stdcall;
    function add_HistoryChanged(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_HistoryChanged(token: Int64): HRESULT; stdcall;
    function add_NavigationCompleted(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_NavigationCompleted(token: Int64): HRESULT; stdcall;
    function ExecuteScript(javaScript: PCWSTR; handler: IUnknown): HRESULT; stdcall;
    function CapturePreview(imageFormat: Integer; imageStream: IUnknown; handler: IUnknown): HRESULT; stdcall;
    function Reload: HRESULT; stdcall;
    function PostWebMessageAsJson(webMessageAsJson: PCWSTR): HRESULT; stdcall;
    function PostWebMessageAsString(webMessageAsString: PCWSTR): HRESULT; stdcall;
    function add_WebMessageReceived(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_WebMessageReceived(token: Int64): HRESULT; stdcall;
    function CallDevToolsProtocolMethod(methodName: PCWSTR; parametersAsJson: PCWSTR; handler: IUnknown): HRESULT; stdcall;
    function get_BrowserProcessId(out value: Cardinal): HRESULT; stdcall;
    function get_CanGoBack(out canGoBack: BOOL): HRESULT; stdcall;
    function get_CanGoForward(out canGoForward: BOOL): HRESULT; stdcall;
    function GoBack: HRESULT; stdcall;
    function GoForward: HRESULT; stdcall;
    function Stop: HRESULT; stdcall;
    function AddScriptToExecuteOnDocumentCreated(javaScript: PCWSTR; out id: PWSTR): HRESULT; stdcall;
    function RemoveScriptToExecuteOnDocumentCreated(id: PCWSTR): HRESULT; stdcall;
    function AddHostObjectToScript(name: PCWSTR; disp: Pointer): HRESULT; stdcall;
    function RemoveHostObjectFromScript(name: PCWSTR): HRESULT; stdcall;
    function OpenDevToolsWindow: HRESULT; stdcall;
  end;
  ICoreWebView2Controller = interface(IUnknown)
    ['{F5605730-6D9E-4A94-934E-BCC76A9DC29B}']
    function get_IsVisible(out isVisible: BOOL): HRESULT; stdcall;
    function put_IsVisible(isVisible: BOOL): HRESULT; stdcall;
    function get_Bounds(out bounds: TRect): HRESULT; stdcall;
    function put_Bounds(bounds: TRect): HRESULT; stdcall;
    function get_ZoomFactor(out zoomFactor: Double): HRESULT; stdcall;
    function put_ZoomFactor(zoomFactor: Double): HRESULT; stdcall;
    function add_ZoomFactorChanged(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_ZoomFactorChanged(token: Int64): HRESULT; stdcall;
    function SetBoundsAndZoomFactor(bounds: TRect; zoomFactor: Double): HRESULT; stdcall;
    function MoveFocus(reason: Integer): HRESULT; stdcall;
    function add_GotFocus(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_GotFocus(token: Int64): HRESULT; stdcall;
    function add_LostFocus(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_LostFocus(token: Int64): HRESULT; stdcall;
    function add_AcceleratorKeyPressed(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_AcceleratorKeyPressed(token: Int64): HRESULT; stdcall;
    function get_ParentWindow(out parentWindow: Pointer): HRESULT; stdcall;
    function put_ParentWindow(parentWindow: Pointer): HRESULT; stdcall;
    function NotifyParentWindowPositionChanged: HRESULT; stdcall;
    function Close: HRESULT; stdcall;
    function get_CoreWebView2(out coreWebView2: ICoreWebView2): HRESULT; stdcall;
  end;
  ICoreWebView2Environment = interface(IUnknown)
    ['{B86C1050-D6DB-4E45-A4E0-99E94D043751}']
    function get_BrowserVersionString(out versionInfo: PWSTR): HRESULT; stdcall;
    function CreateCoreWebView2Controller(parentWindow: Pointer; handler: IUnknown): HRESULT; stdcall;
    function CreateCoreWebView2CompositionController(parentWindow: Pointer; handler: IUnknown): HRESULT; stdcall;
    function add_NewBrowserVersionAvailable(eventHandler: IUnknown; out token: Int64): HRESULT; stdcall;
    function remove_NewBrowserVersionAvailable(token: Int64): HRESULT; stdcall;
  end;
  ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler = interface(IUnknown)
    ['{4E8A3389-C9D8-4BD2-B6B5-124FEE6CC14D}']
    function Invoke(errorCode: HRESULT; createdEnvironment: ICoreWebView2Environment): HRESULT; stdcall;
  end;
  ICoreWebView2CreateCoreWebView2ControllerCompletedHandler = interface(IUnknown)
    ['{6C4819F3-C9B7-4260-8127-C9F5BDE7F68C}']
    function Invoke(errorCode: HRESULT; createdController: ICoreWebView2Controller): HRESULT; stdcall;
  end;
  ICoreWebView2ExecuteScriptCompletedHandler = interface(IUnknown)
    ['{49511172-CC67-4BCA-9923-137112F4C4CC}']
    function Invoke(errorCode: HRESULT; resultObjectAsJson: PWideChar): HRESULT; stdcall;
  end;
  ICoreWebView2WebMessageReceivedEventArgs = interface(IUnknown)
    ['{E950C629-0D2B-4CC6-9580-7605C714A22D}']
    function get_Source(out uri: PWSTR): HRESULT; stdcall;
    function get_WebMessageAsJson(out webMessageAsJson: PWSTR): HRESULT; stdcall;
    function TryGetWebMessageAsString(out webMessageAsString: PWSTR): HRESULT; stdcall;
  end;
  ICoreWebView2WebMessageReceivedEventHandler = interface(IUnknown)
    ['{57213F19-00E6-49FA-8E07-898EA01ECBD2}']
    function Invoke(sender: ICoreWebView2; args: ICoreWebView2WebMessageReceivedEventArgs): HRESULT; stdcall;
  end;
  ICoreWebView2NavigationStartingEventArgs = interface(IUnknown)
    ['{5A6B3574-8B26-4F4B-8B6E-8D279BA2A741}']
    function get_Uri(out uri: PWSTR): HRESULT; stdcall;
    function get_IsUserInitiated(out isUserInitiated: BOOL): HRESULT; stdcall;
    function get_IsRedirected(out isRedirected: BOOL): HRESULT; stdcall;
  end;
  ICoreWebView2NavigationStartingEventHandler = interface(IUnknown)
    ['{E97F0E24-0A1E-4A2E-8A4A-8F0E24A2E8A4}']
    function Invoke(sender: ICoreWebView2; args: ICoreWebView2NavigationStartingEventArgs): HRESULT; stdcall;
  end;
  ICoreWebView2NavigationCompletedEventArgs = interface(IUnknown)
    ['{30D68B7D-C6D9-4069-9C4B-9A2B5A2A3B4C}']
    function get_IsSuccess(out isSuccess: BOOL): HRESULT; stdcall;
    function get_WebErrorStatus(out status: Integer): HRESULT; stdcall;
    function get_NavigationId(out id: ULONGLONG): HRESULT; stdcall;
  end;
  ICoreWebView2NavigationCompletedEventHandler = interface(IUnknown)
    ['{8A149193-2C34-4A8B-8A5D-8F0E24A2E8A5}']
    function Invoke(sender: ICoreWebView2; args: ICoreWebView2NavigationCompletedEventArgs): HRESULT; stdcall;
  end;

type
  { Loader 导出：CreateCoreWebView2EnvironmentWithOptions }
  TCreateCoreWebView2EnvironmentWithOptions = function(
    browserExecutableFolder: PCWSTR;
    userDataFolder: PCWSTR;
    environmentOptions: Pointer;
    createdEnvironmentCompletedHandler: ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler
  ): HRESULT; stdcall;

var
  { WebView2Loader.dll 导出（loader 动态绑定后落位） }
  CreateCoreWebView2EnvironmentWithOptions: TCreateCoreWebView2EnvironmentWithOptions = nil;

implementation

end.
