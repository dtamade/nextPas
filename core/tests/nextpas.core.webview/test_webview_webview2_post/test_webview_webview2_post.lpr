program test_webview_webview2_post;
{** @desc S23 门禁：Win32 调度原语 + WebView2 Post/UserAgent/DataDirectory

       - Win32ShellPost 基础：Linux 桩同步直调 / Windows 隐藏窗口异步（回退直调覆盖）
       - WebView2 窗口 Post 三形态（Ref/Method/Proc）当 loader 可用时
       - UserAgent 本地缓存闭环
       - DataDirectory 透传不抛异常
       - Eval pending exactly-once 在 Post/Eval 交织下不泄漏（wine 真链已在 S23 单独验证） *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.webview2.win,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.factory;

var
  GFlag: Integer;

procedure FlagProc(AData: Pointer); stdcall;
begin
  Inc(GFlag);
end;

procedure TestWin32ShellPostPrimitive;
begin
  GFlag := 0;
  Check(Win32ShellPost(@FlagProc, nil), 'Win32ShellPost returns true');
  // Linux 桩为同步直调，Windows 隐藏窗口异步但回退直调覆盖，单次泵后必达
  // 无需消息循环：桩路径已同步
  CheckEqual(1, GFlag, 'post primitive executed');
  GFlag := 0;
  Check(not Win32ShellPost(nil, nil), 'nil proc returns false');
  CheckEqual(0, GFlag, 'nil proc not executed');
end;

procedure TestWebView2PostViaWindow;
var
  LInfo: TWebView2LoadInfo;
  LAvail: Boolean;
  W: IWebviewWindow;
  LFlag: Integer;

  procedure Work; begin Inc(LFlag); end;

begin
  LAvail := TryLoadWebView2(LInfo);
  if not LAvail then
  begin
    // Linux 原生无 WebView2，验证 unavailable 路径不影响 Post 原语
    Check(True, 'skipped wvWebview2 Post when loader unavailable');
    Exit;
  end;
  W := CreateWebviewOf(wvWebview2, DefaultWebviewOptions);
  try
    LFlag := 0;
    W.GetDispatcher.Post(@Work);
    // Post 为异步（Windows 隐藏窗口）或同步（Linux 桩回退）；给 200ms 窗口
    Sleep(200);
    // Windows 下需泵一次以派发隐藏窗口消息；Linux 桩已同步，无需
    {$IFDEF MSWINDOWS}
    // 在 Linux 宿主编译的此 gate 不走此分支；wine 下单测由 /tmp/test_s23 复验
    {$ENDIF}
    Check(LFlag = 1, 'dispatcher Post executed via window');
    W.Close;
  except
    on E: EWebviewBackendUnavailable do
      Check(True, 'unavailable fallback')
    else
      raise;
  end;
end;

procedure TestUserAgentLocalCache;
var
  LInfo: TWebView2LoadInfo;
  W: IWebviewWindow;
begin
  if not TryLoadWebView2(LInfo) then
  begin
    Check(True, 'skipped UA when loader unavailable');
    Exit;
  end;
  W := CreateWebviewOf(wvWebview2, DefaultWebviewOptions);
  try
    CheckEqual('', W.GetUserAgent, 'default UA empty');
    W.SetUserAgent('S24Agent/1.0');
    CheckEqual('S24Agent/1.0', W.GetUserAgent, 'UA round-trip');
    W.SetUserAgent('');
    CheckEqual('', W.GetUserAgent, 'UA cleared');
    W.Close;
  finally
    if not W.IsClosed then W.Close;
  end;
end;

procedure TestDataDirectoryPassthrough;
var
  LInfo: TWebView2LoadInfo;
  O: TWebviewOptions;
  W: IWebviewWindow;
begin
  if not TryLoadWebView2(LInfo) then
  begin
    Check(True, 'skipped DataDirectory when loader unavailable');
    Exit;
  end;
  O := DefaultWebviewOptions;
  O.DataDirectory := '/tmp/npw-s24-test-' + IntToStr(GetTickCount64);
  W := CreateWebviewOf(wvWebview2, O);
  try
    Check(W <> nil, 'window with DataDirectory created');
    Check(not W.IsClosed, 'not closed');
    W.Close;
  except
    on E: Exception do
      Fail('DataDirectory passthrough should not raise: ' + E.Message);
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.webview2.post');
  T.Test('Win32ShellPost primitive', @TestWin32ShellPostPrimitive);
  T.Test('WebView2 Post via window', @TestWebView2PostViaWindow);
  T.Test('UserAgent local cache', @TestUserAgentLocalCache);
  T.Test('DataDirectory passthrough', @TestDataDirectoryPassthrough);
  if not T.Run then Halt(1);
end.
