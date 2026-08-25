program test_webview_gtk_loader;
{ gtk 装载门禁：真实 dlopen 探测（4.1→4.0 soname 序）、符号绑定抽查、
  eval 双路径能力位、幂等装载/卸载。缺库环境下两分支皆合法——
  断言的是"行为与探测结果一致"，不是"必须存在 WebKitGTK"。
  heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.webview.gtk.ffi,
  nextpas.core.webview.gtk.loader;

procedure TestProbeConsistency;
var
  LInfo: TGtkLoadInfo;
begin
  if TryLoadGtkWebkit(LInfo) then
  begin
    Check(LInfo.Loaded, 'info.Loaded on success');
    Check(Pos('libwebkit2gtk', LInfo.WebkitSoname) = 1,
      'soname shape: ' + LInfo.WebkitSoname);
    Check(Ord(LInfo.EvalPath) <= Ord(gepRunJavascript), 'eval path in range');
    { 符号落位抽查：主循环入口与 scheme 注册必绑 }
    Check(Assigned(GTK_main), 'GTK_main bound');
    Check(Assigned(WEBKIT_web_context_register_uri_scheme),
      'register_uri_scheme bound');
    Check(Assigned(G_signal_connect_data), 'g_signal_connect_data bound');
    Check(Assigned(JSC_value_to_json), 'jsc_value_to_json bound');
    if LInfo.EvalPath = gepEvaluateJavascript then
      Check(Assigned(WEBKIT_web_view_evaluate_javascript),
        'evaluate pair bound')
    else
      Check(Assigned(WEBKIT_web_view_run_javascript),
        'run_javascript pair bound');
  end
  else
  begin
    { 缺库环境：优雅 False，状态不残留半装载 }
    Check(not GtkLoadInfo().Loaded, 'graceful miss leaves clean state');
  end;
end;

procedure TestIdempotentReload;
var
  LA, LB: TGtkLoadInfo;
begin
  if not TryLoadGtkWebkit(LA) then
  begin
    Check(True, '');   { 缺库环境跳过幂等断言 }
    Exit;
  end;
  Check(TryLoadGtkWebkit(LB), 'second load succeeds');
  CheckEqual(LA.WebkitSoname, LB.WebkitSoname, 'same soname');
  CheckEqual(Ord(LA.EvalPath), Ord(LB.EvalPath), 'same eval path');

  UnloadGtkWebkit;
  Check(not GtkLoadInfo().Loaded, 'unload clears state');
  Check(TryLoadGtkWebkit(LB), 'reload after unload succeeds');
  UnloadGtkWebkit;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.gtk.loader');
  T.Test('probe consistency', @TestProbeConsistency);
  T.Test('idempotent reload', @TestIdempotentReload);
  if not T.Run then Halt(1);
end.
