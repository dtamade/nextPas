unit nextpas.core.webview.gtk.loader;

{** @desc GTK/WebKitGTK 动态装载与符号解析（家族内唯一触碰动态装载
       设施的单元；原语来自 nextpas.core.platform.dl，禁用 FPC DynLibs）。

       探测顺序（BACKENDS §2.1）：libwebkit2gtk-4.1.so.0 → 4.0.so.0；
       并列装载 libgtk-3/libgobject-2.0/libglib-2.0 与匹配版本的
       libjavascriptcoregtk。能力分支以符号存在性判定、不做版本号
       字符串猜测：evaluate_javascript 对（≥2.40）缺席时静默退回
       run_javascript 对（自 2.4 起成对存在，同样可取回结果）。

       装载状态进程级幂等：TryLoadGtkWebkit 首次成功后缓存，
       后续调用直接复用；UnloadGtkWebkit 全量释放。 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.dl,
  nextpas.core.webview.base,
  nextpas.core.webview.gtk.ffi;

type
  { eval 结果取回路径选择 }
  TGtkEvalPath = (gepEvaluateJavascript, gepRunJavascript);

  { 装载结果快照（诊断/测试断言用） }
  TGtkLoadInfo = record
    Loaded: Boolean;
    WebkitSoname: string;      { 实际命中的 webkit 库 soname }
    EvalPath: TGtkEvalPath;
  end;

{ 幂等装载：成功返回 True 并填充 ffi 函数指针；缺库/关键符号缺失
  返回 False（不抛异常——可用性探测是正常业务路径）。 }
function TryLoadGtkWebkit(out AInfo: TGtkLoadInfo): Boolean;

{ 已装载则全量释放并复位状态；未装载为 no-op。 }
procedure UnloadGtkWebkit;

{ 当前装载快照（不触发装载）。 }
function GtkLoadInfo: TGtkLoadInfo; inline;

implementation

type
  PPlatformLibrary = ^TPlatformLibrary;

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GInfo: TGtkLoadInfo;
  GWebkitLib, GGtkLib, GGobjectLib, GGlibLib, GJscLib: TPlatformLibrary;
  GWebkitSoname, GJscSoname: string;

function TryDlOpen(var ALib: TPlatformLibrary; const ASonames: array of string;
  out AHit: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  AHit := '';
  for I := 0 to High(ASonames) do
  begin
    { Lazy|Global：GTK/GObject 类型系统要求跨库共享 GType 注册 }
    if platform_dl_load(ASonames[I], [dlfLazy, dlfGlobal], ALib) then
    begin
      AHit := ASonames[I];
      Exit(True);
    end;
  end;
end;

function Sym(const AName: PAnsiChar; out AAddr: Pointer): Boolean;
var
  LLibs: array[0..4] of PPlatformLibrary;
  I: Integer;
begin
  LLibs[0] := @GWebkitLib;
  LLibs[1] := @GGtkLib;
  LLibs[2] := @GGobjectLib;
  LLibs[3] := @GGlibLib;
  LLibs[4] := @GJscLib;
  for I := 0 to High(LLibs) do
    if LLibs[I]^.IsValid then
      if LLibs[I]^.Sym(AName, AAddr) = 0 then
        Exit(True);
  Result := False;
end;

{ 绑定单个必需符号：缺失直接 False（由调用方统一报错释放）。
  经 PPointer 写入——@procvar 是地址值，需二级解引用落位。 }
function BindReq(AVarAddr: Pointer; const AName: string): Boolean;
begin
  Result := Sym(PAnsiChar(AName), PPointer(AVarAddr)^);
end;

procedure ReleaseAll;
begin
  platform_dl_release(GWebkitLib);
  platform_dl_release(GGtkLib);
  platform_dl_release(GGobjectLib);
  platform_dl_release(GGlibLib);
  platform_dl_release(GJscLib);
end;

function TryLoadGtkWebkit(out AInfo: TGtkLoadInfo): Boolean;
var
  LHit: string;
  LTmp: Pointer = nil;
  LHasEvalPair: Boolean;

  function BindAll: Boolean;
  begin
    Result :=
      { GLib }
      BindReq(@G_idle_add_full, 'g_idle_add_full') and
      BindReq(@G_source_remove, 'g_source_remove') and
      BindReq(@G_signal_connect_data, 'g_signal_connect_data') and
      BindReq(@G_memory_input_stream_new_from_data,
        'g_memory_input_stream_new_from_data') and
      BindReq(@G_malloc, 'g_malloc') and
      BindReq(@G_free, 'g_free') and
      BindReq(@G_quark_from_static_string, 'g_quark_from_static_string') and
      BindReq(@G_cancellable_new, 'g_cancellable_new') and
      BindReq(@G_cancellable_cancel, 'g_cancellable_cancel') and
      BindReq(@G_error_new_literal, 'g_error_new_literal') and
      BindReq(@G_main_loop_new, 'g_main_loop_new') and
      BindReq(@G_main_loop_run, 'g_main_loop_run') and
      BindReq(@G_main_loop_quit, 'g_main_loop_quit') and
      BindReq(@G_main_loop_unref, 'g_main_loop_unref') and
      BindReq(@G_timeout_add, 'g_timeout_add') and
      BindReq(@G_main_context_default, 'g_main_context_default') and
      BindReq(@G_main_context_find_source_by_id,
        'g_main_context_find_source_by_id') and
      { GObject }
      BindReq(@G_object_unref, 'g_object_unref') and
      BindReq(@G_object_set, 'g_object_set') and
      BindReq(@G_object_get, 'g_object_get') and
      { GTK3 窗口壳 }
      BindReq(@GTK_init_check, 'gtk_init_check') and
      BindReq(@GTK_window_new, 'gtk_window_new') and
      BindReq(@GTK_window_set_title, 'gtk_window_set_title') and
      BindReq(@GTK_window_get_title, 'gtk_window_get_title') and
      BindReq(@GTK_window_set_default_size, 'gtk_window_set_default_size') and
      BindReq(@GTK_window_set_resizable, 'gtk_window_set_resizable') and
      BindReq(@GTK_window_resize, 'gtk_window_resize') and
      BindReq(@GTK_window_maximize, 'gtk_window_maximize') and
      BindReq(@GTK_window_unmaximize, 'gtk_window_unmaximize') and
      BindReq(@GTK_window_iconify, 'gtk_window_iconify') and
      BindReq(@GTK_window_deiconify, 'gtk_window_deiconify') and
      BindReq(@GTK_window_is_maximized, 'gtk_window_is_maximized') and
      BindReq(@GTK_widget_show_all, 'gtk_widget_show_all') and
      BindReq(@GTK_widget_hide, 'gtk_widget_hide') and
      BindReq(@GTK_widget_get_visible, 'gtk_widget_get_visible') and
      BindReq(@GTK_widget_get_scale_factor, 'gtk_widget_get_scale_factor') and
      BindReq(@GTK_widget_grab_focus, 'gtk_widget_grab_focus') and
      BindReq(@GTK_widget_get_window, 'gtk_widget_get_window') and
      BindReq(@GTK_widget_destroy, 'gtk_widget_destroy') and
      BindReq(@GTK_widget_get_allocated_width,
        'gtk_widget_get_allocated_width') and
      BindReq(@GTK_widget_get_allocated_height,
        'gtk_widget_get_allocated_height') and
      BindReq(@GDK_window_get_state, 'gdk_window_get_state') and
      BindReq(@GTK_container_add, 'gtk_container_add') and
      BindReq(@GTK_main, 'gtk_main') and
      BindReq(@GTK_main_quit, 'gtk_main_quit') and
      BindReq(@GTK_main_iteration_do, 'gtk_main_iteration_do') and
      { WebKit 视图与加载 }
      BindReq(@WEBKIT_web_context_get_default, 'webkit_web_context_get_default') and
      BindReq(@WEBKIT_web_view_new_with_context, 'webkit_web_view_new_with_context') and
      BindReq(@WEBKIT_web_view_get_user_content_manager,
        'webkit_web_view_get_user_content_manager') and
      BindReq(@WEBKIT_web_view_get_uri, 'webkit_web_view_get_uri') and
      BindReq(@WEBKIT_web_view_new_with_user_content_manager,
        'webkit_web_view_new_with_user_content_manager') and
      BindReq(@WEBKIT_web_view_load_uri, 'webkit_web_view_load_uri') and
      BindReq(@WEBKIT_web_view_load_html, 'webkit_web_view_load_html') and
      BindReq(@WEBKIT_web_view_reload, 'webkit_web_view_reload') and
      BindReq(@WEBKIT_web_view_stop_loading, 'webkit_web_view_stop_loading') and
      BindReq(@WEBKIT_web_view_go_back, 'webkit_web_view_go_back') and
      BindReq(@WEBKIT_web_view_go_forward, 'webkit_web_view_go_forward') and
      BindReq(@WEBKIT_web_view_can_go_back, 'webkit_web_view_can_go_back') and
      BindReq(@WEBKIT_web_view_can_go_forward,
        'webkit_web_view_can_go_forward') and
      BindReq(@WEBKIT_web_view_set_zoom_level,
        'webkit_web_view_set_zoom_level') and
      BindReq(@WEBKIT_web_view_get_zoom_level,
        'webkit_web_view_get_zoom_level') and
      BindReq(@WEBKIT_web_view_get_inspector, 'webkit_web_view_get_inspector') and
      BindReq(@WEBKIT_web_view_get_settings, 'webkit_web_view_get_settings') and
      BindReq(@WEBKIT_settings_set_enable_developer_extras,
        'webkit_settings_set_enable_developer_extras') and
      { 会话 context 与 scheme }
      BindReq(@WEBKIT_web_context_new_ephemeral,
        'webkit_web_context_new_ephemeral') and
      BindReq(@WEBKIT_web_context_new_with_website_data_manager,
        'webkit_web_context_new_with_website_data_manager') and
      BindReq(@WEBKIT_website_data_manager_new,
        'webkit_website_data_manager_new') and
      BindReq(@WEBKIT_web_context_register_uri_scheme,
        'webkit_web_context_register_uri_scheme') and
      { 用户内容与桥 transport }
      BindReq(@WEBKIT_user_content_manager_new,
        'webkit_user_content_manager_new') and
      BindReq(@WEBKIT_user_content_manager_add_script,
        'webkit_user_content_manager_add_script') and
      BindReq(@WEBKIT_user_content_manager_register_script_message_handler,
        'webkit_user_content_manager_register_script_message_handler') and
      BindReq(@WEBKIT_user_script_new, 'webkit_user_script_new') and
      BindReq(@WEBKIT_user_script_unref, 'webkit_user_script_unref') and
      BindReq(@WEBKIT_javascript_result_get_js_value,
        'webkit_javascript_result_get_js_value') and
      BindReq(@WEBKIT_uri_scheme_request_get_uri,
        'webkit_uri_scheme_request_get_uri') and
      BindReq(@WEBKIT_uri_scheme_request_get_path,
        'webkit_uri_scheme_request_get_path') and
      BindReq(@WEBKIT_uri_scheme_request_get_web_view,
        'webkit_uri_scheme_request_get_web_view') and
      BindReq(@WEBKIT_uri_scheme_request_finish,
        'webkit_uri_scheme_request_finish') and
      BindReq(@WEBKIT_uri_scheme_request_finish_error,
        'webkit_uri_scheme_request_finish_error') and
      { JSC }
      BindReq(@JSC_value_is_null, 'jsc_value_is_null') and
      BindReq(@JSC_value_is_undefined, 'jsc_value_is_undefined') and
      BindReq(@JSC_value_to_json, 'jsc_value_to_json') and
      BindReq(@JSC_value_to_string, 'jsc_value_to_string');
  end;

begin
  if GLoaded then
  begin
    AInfo := GInfo;
    Exit(True);
  end;
  if GLoading then
    Exit(False);   { 重入保护：并发首装只允许一个赢家走完流程 }

  FillChar(AInfo, SizeOf(AInfo), 0);
  GLoading := True;
  try
    { webkit 主库按 soname 探测序命中其一 }
    if not TryDlOpen(GWebkitLib,
        ['libwebkit2gtk-4.1.so.0', 'libwebkit2gtk-4.0.so.0'],
        GWebkitSoname) then
      Exit(False);
    { GTK3 栈并列必需 }
    if not (TryDlOpen(GGtkLib, ['libgtk-3.so.0'], LHit) and
        TryDlOpen(GGobjectLib, ['libgobject-2.0.so.0'], LHit) and
        TryDlOpen(GGlibLib, ['libglib-2.0.so.0'], LHit)) then
    begin
      ReleaseAll;
      Exit(False);
    end;
    { JSC 与 webkit 同代：4.1 → jsc-4.1，4.0 → jsc-4.0 }
    if Pos('4.0', GWebkitSoname) > 0 then
      GJscSoname := 'libjavascriptcoregtk-4.0.so.0'
    else
      GJscSoname := 'libjavascriptcoregtk-4.1.so.0';
    if not TryDlOpen(GJscLib, [GJscSoname], LHit) then
    begin
      ReleaseAll;
      Exit(False);
    end;

    if not BindAll then
    begin
      ReleaseAll;
      Exit(False);
    end;

    { 能力分支：eval 双路径按符号存在性（BACKENDS §2.2） }
    LHasEvalPair :=
      Sym('webkit_web_view_evaluate_javascript', LTmp) and
      Sym('webkit_web_view_evaluate_javascript_finish', LTmp);
    if LHasEvalPair then
    begin
      BindReq(@WEBKIT_web_view_evaluate_javascript,
        'webkit_web_view_evaluate_javascript');
      BindReq(@WEBKIT_web_view_evaluate_javascript_finish,
        'webkit_web_view_evaluate_javascript_finish');
      GInfo.EvalPath := gepEvaluateJavascript;
    end
    else
    begin
      BindReq(@WEBKIT_web_view_run_javascript, 'webkit_web_view_run_javascript');
      BindReq(@WEBKIT_web_view_run_javascript_finish,
        'webkit_web_view_run_javascript_finish');
      GInfo.EvalPath := gepRunJavascript;
    end;

    GLoaded := True;
    GInfo.Loaded := True;
    GInfo.WebkitSoname := GWebkitSoname;
    AInfo := GInfo;
    Result := True;
  finally
    GLoading := False;
  end;
end;

procedure UnloadGtkWebkit;
begin
  if not GLoaded then
    Exit;
  ReleaseAll;
  GLoaded := False;
  GInfo := Default(TGtkLoadInfo);
end;

function GtkLoadInfo: TGtkLoadInfo; inline;
begin
  Result := GInfo;
end;

end.
