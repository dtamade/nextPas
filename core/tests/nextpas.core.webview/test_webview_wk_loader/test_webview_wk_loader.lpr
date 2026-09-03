program test_webview_wk_loader;
{** @desc WK loader 门禁：当前阶段恒不可用（Linux/Windows 桩），与 factory
       的 wvWk 事实源保持一致；桩后端创建语义为不可用抛错。 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.wk.loader,
  nextpas.core.webview.wk,
  nextpas.core.webview.factory;

procedure TestLoaderAlwaysUnavailableOnThisHost;
var
  LInfo: TWkLoadInfo;
  LProbe, LFact: Boolean;
begin
  LProbe := TryLoadWk(LInfo);
  LFact := WebviewBackendAvailable(wvWk);
  CheckEqual(LProbe, LFact, 'factory wvWk must match loader probe');
  // 当前桩在 Linux/Windows 恒 false；Darwin 真实现接入后此断言需按平台分支
  Check(not LProbe, 'Wk loader unavailable on this host (expected for Linux)');
  Check(not LInfo.Loaded, 'not loaded when probe false');
end;

procedure TestLoaderIdempotent;
var
  A, B: TWkLoadInfo;
  RA, RB: Boolean;
begin
  RA := TryLoadWk(A);
  RB := TryLoadWk(B);
  CheckEqual(RA, RB, 'idempotent probe');
  CheckEqual(A.Loaded, B.Loaded, 'idempotent loaded flag');
  CheckEqual(A.DllName, B.DllName, 'idempotent DllName');
end;

procedure TestFactoryCreateSemantics;
var
  LInfo: TWkLoadInfo;
  LAvail: Boolean;
  LWin: IWebviewWindow;
begin
  LAvail := TryLoadWk(LInfo);
  if not LAvail then
  begin
    try
      LWin := CreateWebviewOf(wvWk, DefaultWebviewOptions);
      Fail('expected EWebviewBackendUnavailable when loader unavailable');
    except
      on E: EWebviewBackendUnavailable do
        Check(True, 'raised unavailable as expected')
      else
        Fail('wrong exception for unavailable wvWk');
    end;
  end
  else
  begin
    LWin := CreateWebviewOf(wvWk, DefaultWebviewOptions);
    Check(LWin <> nil, 'wk window created when loader available');
    LWin.Close;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.wk.loader');
  T.Test('loader probe matches factory', @TestLoaderAlwaysUnavailableOnThisHost);
  T.Test('loader idempotent', @TestLoaderIdempotent);
  T.Test('factory create semantics', @TestFactoryCreateSemantics);
  if not T.Run then Halt(1);
end.
