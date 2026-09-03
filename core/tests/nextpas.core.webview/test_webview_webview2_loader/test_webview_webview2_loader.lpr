program test_webview_webview2_loader;
{** @desc WebView2 loader 门禁：Linux 原生不可用（无 DLL）与 wine 交叉
       可用性探测一致性；factory 的 wvWebview2 事实源与 loader 探针
       保持一致；桩后端创建语义（不可用抛 EWebviewBackendUnavailable，
       可用时桩窗口本地回显）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.webview2,
  nextpas.core.webview.factory;

procedure TestLoaderProbeMatchesFactory;
var
  LInfo: TWebView2LoadInfo;
  LProbe, LFact: Boolean;
begin
  LProbe := TryLoadWebView2(LInfo);
  LFact := WebviewBackendAvailable(wvWebview2);
  CheckEqual(LProbe, LFact, 'factory wvWebview2 must match loader probe');
  if not LProbe then
    Check(not LInfo.Loaded, 'not loaded when probe false')
  else
    Check(LInfo.Loaded and (LInfo.DllName <> ''), 'loaded with DllName');
end;

procedure TestLoaderIdempotent;
var
  A, B: TWebView2LoadInfo;
  RA, RB: Boolean;
begin
  RA := TryLoadWebView2(A);
  RB := TryLoadWebView2(B);
  CheckEqual(RA, RB, 'idempotent probe');
  CheckEqual(A.Loaded, B.Loaded, 'idempotent loaded flag');
  CheckEqual(A.DllName, B.DllName, 'idempotent DllName');
end;

procedure TestFactoryCreateSemantics;
var
  LInfo: TWebView2LoadInfo;
  LAvail: Boolean;
  LWin: IWebviewWindow;
begin
  LAvail := TryLoadWebView2(LInfo);
  if not LAvail then
  begin
    try
      LWin := CreateWebviewOf(wvWebview2, DefaultWebviewOptions);
      Fail('expected EWebviewBackendUnavailable when loader unavailable');
    except
      on E: EWebviewBackendUnavailable do
        Check(True, 'raised unavailable as expected')
      else
        Fail('wrong exception for unavailable wvWebview2');
    end;
  end
  else
  begin
    { loader 可用（wine + DLL）：桩窗口应可创建且本地几何回显 — 标题壳已收敛至 Window }
    LWin := CreateWebviewOf(wvWebview2, DefaultWebviewOptions);
    Check(LWin <> nil, 'stub window created when loader available');
    CheckEqual(DefaultWebviewOptions.Title, LWin.Window.GetTitle, 'stub title default');
    LWin.Window.SetTitle('w2');
    CheckEqual('w2', LWin.Window.GetTitle, 'stub title echo');
    Check(not LWin.IsClosed, 'not closed initially');
    LWin.Close;
    Check(LWin.IsClosed, 'closed after Close');
    LWin.Close; // idempotent
    Check(LWin.IsClosed, 'idempotent close');
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.webview2.loader');
  T.Test('probe matches factory', @TestLoaderProbeMatchesFactory);
  T.Test('loader idempotent', @TestLoaderIdempotent);
  T.Test('factory create semantics', @TestFactoryCreateSemantics);
  if not T.Run then Halt(1);
end.
