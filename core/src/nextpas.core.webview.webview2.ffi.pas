unit nextpas.core.webview.webview2.ffi;

{** @desc WebView2 COM/Loader ABI 声明层。

       只含不透明句柄、COM 接口前向声明与 Loader 函数指针——无逻辑、
       无 external；绑定真相归 webview2.loader（经 platform.dl）。

       签名对照源：WebView2 SDK 1.0.2903.40 WebView2.h + WebView2Loader.dll
       导出表（CreateCoreWebView2EnvironmentWithOptions）。调用约定
       统一 stdcall（Win64 与 Linux 交叉编译均可）。本单元禁止 uses
       家族其他单元；不依赖 Windows 单元以保持 Linux 编译。 *}

{$I nextpas.core.settings.inc}

interface

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
  { COM IUnknown 最小前向（FPC System 已有 IUnknown，但为自包含声明） }
  ICoreWebView2Environment = interface(IUnknown)
    ['{B86C1050-D6DB-4E45-A4E0-99E94D043751}']
  end;
  ICoreWebView2Controller = interface(IUnknown)
    ['{F5605730-6D9E-4A94-934E-BCC76A9DC29B}']
  end;
  ICoreWebView2 = interface(IUnknown)
    ['{76ECEACB-0462-4D94-AC83-45A67937797C}']
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
  ICoreWebView2WebMessageReceivedEventHandler = interface(IUnknown)
    ['{57213F19-00E6-49FA-8E07-898EA01ECBD2}']
    function Invoke(sender: ICoreWebView2; args: IUnknown): HRESULT; stdcall;
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
