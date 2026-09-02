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
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.dl,
  nextpas.core.sync.mutex,
  nextpas.core.text.utils,
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

uses
  nextpas.core.atomic,
  nextpas.core.sync;

type
  PPlatformLibrary = ^TPlatformLibrary;

  TGtkBindEntry = record
    VarAddr: Pointer;
    Name: PAnsiChar;
  end;

var
  GLoaded: Boolean = False;
  GLoading: Boolean = False;
  GProbed: Int32 = 0; { atomic 0/1, mo_acquire/mo_release 保证弱内存可见性，零撕裂 }
  GInfo: TGtkLoadInfo;
  GWebkitLib, GGtkLib, GGobjectLib, GGlibLib, GJscLib: TPlatformLibrary;
  GWebkitSoname, GJscSoname: string;
  GGtkLock: TMutex; { L3→L1 sync owner 复用：TMutex 单源，替代 FPC TRTLCriticalSection 直连 RTL，守分层抽象 }
  GGtkLockOnce: IOnce; { L1 sync.once 单源：EnsureGtkLock 惰性创建零双分配零泄漏 }
  GGtkBindOnce: IOnce; { L1 sync.once 单源：Bind 表单次初始化，热点零分配 }
  GGtkBindTable: array[0..86] of TGtkBindEntry; { 单源表驱动：87 必需符号单表，I-Cache 单调用点 }

procedure EnsureGtkLock; inline;
begin
  { perf: inline 零额外调用；Once 单源保护懒创建，双线程并发零重复 New 零泄漏，platform.sync futex 去重 }
  if GGtkLock <> nil then
    Exit;
  if GGtkLockOnce = nil then
  begin
    { startup fallback：initialization 主路径已创建 Once，此分支仅兜底单线程启动期 }
    GGtkLock := TMutex.Create;
    Exit;
  end;
  GGtkLockOnce.DoOnce(procedure
  begin
    if GGtkLock = nil then
      GGtkLock := TMutex.Create;
  end);
end;

procedure InitGtkBindTable;
begin
  { 单源表驱动初始化：87 必需符号单表，新增仅此一处登记，bytes.ops 单源思想，零双表漂移 }
  GGtkBindTable[0].VarAddr := @G_idle_add_full; GGtkBindTable[0].Name := 'g_idle_add_full';
  GGtkBindTable[1].VarAddr := @G_source_remove; GGtkBindTable[1].Name := 'g_source_remove';
  GGtkBindTable[2].VarAddr := @G_signal_connect_data; GGtkBindTable[2].Name := 'g_signal_connect_data';
  GGtkBindTable[3].VarAddr := @G_memory_input_stream_new_from_data; GGtkBindTable[3].Name := 'g_memory_input_stream_new_from_data';
  GGtkBindTable[4].VarAddr := @G_memory_input_stream_new_from_bytes; GGtkBindTable[4].Name := 'g_memory_input_stream_new_from_bytes';
  GGtkBindTable[5].VarAddr := @G_bytes_new_with_free_func; GGtkBindTable[5].Name := 'g_bytes_new_with_free_func';
  GGtkBindTable[6].VarAddr := @G_bytes_unref; GGtkBindTable[6].Name := 'g_bytes_unref';
  GGtkBindTable[7].VarAddr := @G_malloc; GGtkBindTable[7].Name := 'g_malloc';
  GGtkBindTable[8].VarAddr := @G_free; GGtkBindTable[8].Name := 'g_free';
  GGtkBindTable[9].VarAddr := @G_quark_from_static_string; GGtkBindTable[9].Name := 'g_quark_from_static_string';
  GGtkBindTable[10].VarAddr := @G_cancellable_new; GGtkBindTable[10].Name := 'g_cancellable_new';
  GGtkBindTable[11].VarAddr := @G_cancellable_cancel; GGtkBindTable[11].Name := 'g_cancellable_cancel';
  GGtkBindTable[12].VarAddr := @G_error_new_literal; GGtkBindTable[12].Name := 'g_error_new_literal';
  GGtkBindTable[13].VarAddr := @G_main_loop_new; GGtkBindTable[13].Name := 'g_main_loop_new';
  GGtkBindTable[14].VarAddr := @G_main_loop_run; GGtkBindTable[14].Name := 'g_main_loop_run';
  GGtkBindTable[15].VarAddr := @G_main_loop_quit; GGtkBindTable[15].Name := 'g_main_loop_quit';
  GGtkBindTable[16].VarAddr := @G_main_loop_unref; GGtkBindTable[16].Name := 'g_main_loop_unref';
  GGtkBindTable[17].VarAddr := @G_timeout_add; GGtkBindTable[17].Name := 'g_timeout_add';
  GGtkBindTable[18].VarAddr := @G_main_context_default; GGtkBindTable[18].Name := 'g_main_context_default';
  GGtkBindTable[19].VarAddr := @G_main_context_find_source_by_id; GGtkBindTable[19].Name := 'g_main_context_find_source_by_id';
  GGtkBindTable[20].VarAddr := @G_object_unref; GGtkBindTable[20].Name := 'g_object_unref';
  GGtkBindTable[21].VarAddr := @G_object_set; GGtkBindTable[21].Name := 'g_object_set';
  GGtkBindTable[22].VarAddr := @G_object_get; GGtkBindTable[22].Name := 'g_object_get';
  GGtkBindTable[23].VarAddr := @GTK_init_check; GGtkBindTable[23].Name := 'gtk_init_check';
  GGtkBindTable[24].VarAddr := @GTK_window_new; GGtkBindTable[24].Name := 'gtk_window_new';
  GGtkBindTable[25].VarAddr := @GTK_window_set_title; GGtkBindTable[25].Name := 'gtk_window_set_title';
  GGtkBindTable[26].VarAddr := @GTK_window_get_title; GGtkBindTable[26].Name := 'gtk_window_get_title';
  GGtkBindTable[27].VarAddr := @GTK_window_set_default_size; GGtkBindTable[27].Name := 'gtk_window_set_default_size';
  GGtkBindTable[28].VarAddr := @GTK_window_set_resizable; GGtkBindTable[28].Name := 'gtk_window_set_resizable';
  GGtkBindTable[29].VarAddr := @GTK_window_resize; GGtkBindTable[29].Name := 'gtk_window_resize';
  GGtkBindTable[30].VarAddr := @GTK_window_maximize; GGtkBindTable[30].Name := 'gtk_window_maximize';
  GGtkBindTable[31].VarAddr := @GTK_window_unmaximize; GGtkBindTable[31].Name := 'gtk_window_unmaximize';
  GGtkBindTable[32].VarAddr := @GTK_window_iconify; GGtkBindTable[32].Name := 'gtk_window_iconify';
  GGtkBindTable[33].VarAddr := @GTK_window_deiconify; GGtkBindTable[33].Name := 'gtk_window_deiconify';
  GGtkBindTable[34].VarAddr := @GTK_window_is_maximized; GGtkBindTable[34].Name := 'gtk_window_is_maximized';
  GGtkBindTable[35].VarAddr := @GTK_widget_show_all; GGtkBindTable[35].Name := 'gtk_widget_show_all';
  GGtkBindTable[36].VarAddr := @GTK_widget_hide; GGtkBindTable[36].Name := 'gtk_widget_hide';
  GGtkBindTable[37].VarAddr := @GTK_widget_get_visible; GGtkBindTable[37].Name := 'gtk_widget_get_visible';
  GGtkBindTable[38].VarAddr := @GTK_widget_get_scale_factor; GGtkBindTable[38].Name := 'gtk_widget_get_scale_factor';
  GGtkBindTable[39].VarAddr := @GTK_widget_grab_focus; GGtkBindTable[39].Name := 'gtk_widget_grab_focus';
  GGtkBindTable[40].VarAddr := @GTK_widget_get_window; GGtkBindTable[40].Name := 'gtk_widget_get_window';
  GGtkBindTable[41].VarAddr := @GTK_widget_destroy; GGtkBindTable[41].Name := 'gtk_widget_destroy';
  GGtkBindTable[42].VarAddr := @GTK_widget_get_allocated_width; GGtkBindTable[42].Name := 'gtk_widget_get_allocated_width';
  GGtkBindTable[43].VarAddr := @GTK_widget_get_allocated_height; GGtkBindTable[43].Name := 'gtk_widget_get_allocated_height';
  GGtkBindTable[44].VarAddr := @GTK_widget_set_size_request; GGtkBindTable[44].Name := 'gtk_widget_set_size_request';
  GGtkBindTable[45].VarAddr := @GDK_window_get_state; GGtkBindTable[45].Name := 'gdk_window_get_state';
  GGtkBindTable[46].VarAddr := @GTK_container_add; GGtkBindTable[46].Name := 'gtk_container_add';
  GGtkBindTable[47].VarAddr := @GTK_main; GGtkBindTable[47].Name := 'gtk_main';
  GGtkBindTable[48].VarAddr := @GTK_main_quit; GGtkBindTable[48].Name := 'gtk_main_quit';
  GGtkBindTable[49].VarAddr := @GTK_main_iteration_do; GGtkBindTable[49].Name := 'gtk_main_iteration_do';
  GGtkBindTable[50].VarAddr := @WEBKIT_web_context_get_default; GGtkBindTable[50].Name := 'webkit_web_context_get_default';
  GGtkBindTable[51].VarAddr := @WEBKIT_web_view_new_with_context; GGtkBindTable[51].Name := 'webkit_web_view_new_with_context';
  GGtkBindTable[52].VarAddr := @WEBKIT_web_view_get_user_content_manager; GGtkBindTable[52].Name := 'webkit_web_view_get_user_content_manager';
  GGtkBindTable[53].VarAddr := @WEBKIT_web_view_get_uri; GGtkBindTable[53].Name := 'webkit_web_view_get_uri';
  GGtkBindTable[54].VarAddr := @WEBKIT_web_view_new_with_user_content_manager; GGtkBindTable[54].Name := 'webkit_web_view_new_with_user_content_manager';
  GGtkBindTable[55].VarAddr := @WEBKIT_web_view_load_uri; GGtkBindTable[55].Name := 'webkit_web_view_load_uri';
  GGtkBindTable[56].VarAddr := @WEBKIT_web_view_load_html; GGtkBindTable[56].Name := 'webkit_web_view_load_html';
  GGtkBindTable[57].VarAddr := @WEBKIT_web_view_reload; GGtkBindTable[57].Name := 'webkit_web_view_reload';
  GGtkBindTable[58].VarAddr := @WEBKIT_web_view_stop_loading; GGtkBindTable[58].Name := 'webkit_web_view_stop_loading';
  GGtkBindTable[59].VarAddr := @WEBKIT_web_view_go_back; GGtkBindTable[59].Name := 'webkit_web_view_go_back';
  GGtkBindTable[60].VarAddr := @WEBKIT_web_view_go_forward; GGtkBindTable[60].Name := 'webkit_web_view_go_forward';
  GGtkBindTable[61].VarAddr := @WEBKIT_web_view_can_go_back; GGtkBindTable[61].Name := 'webkit_web_view_can_go_back';
  GGtkBindTable[62].VarAddr := @WEBKIT_web_view_can_go_forward; GGtkBindTable[62].Name := 'webkit_web_view_can_go_forward';
  GGtkBindTable[63].VarAddr := @WEBKIT_web_view_set_zoom_level; GGtkBindTable[63].Name := 'webkit_web_view_set_zoom_level';
  GGtkBindTable[64].VarAddr := @WEBKIT_web_view_get_zoom_level; GGtkBindTable[64].Name := 'webkit_web_view_get_zoom_level';
  GGtkBindTable[65].VarAddr := @WEBKIT_web_view_get_inspector; GGtkBindTable[65].Name := 'webkit_web_view_get_inspector';
  GGtkBindTable[66].VarAddr := @WEBKIT_web_view_get_settings; GGtkBindTable[66].Name := 'webkit_web_view_get_settings';
  GGtkBindTable[67].VarAddr := @WEBKIT_settings_set_enable_developer_extras; GGtkBindTable[67].Name := 'webkit_settings_set_enable_developer_extras';
  GGtkBindTable[68].VarAddr := @WEBKIT_web_context_new_ephemeral; GGtkBindTable[68].Name := 'webkit_web_context_new_ephemeral';
  GGtkBindTable[69].VarAddr := @WEBKIT_web_context_new_with_website_data_manager; GGtkBindTable[69].Name := 'webkit_web_context_new_with_website_data_manager';
  GGtkBindTable[70].VarAddr := @WEBKIT_website_data_manager_new; GGtkBindTable[70].Name := 'webkit_website_data_manager_new';
  GGtkBindTable[71].VarAddr := @WEBKIT_web_context_register_uri_scheme; GGtkBindTable[71].Name := 'webkit_web_context_register_uri_scheme';
  GGtkBindTable[72].VarAddr := @WEBKIT_user_content_manager_new; GGtkBindTable[72].Name := 'webkit_user_content_manager_new';
  GGtkBindTable[73].VarAddr := @WEBKIT_user_content_manager_add_script; GGtkBindTable[73].Name := 'webkit_user_content_manager_add_script';
  GGtkBindTable[74].VarAddr := @WEBKIT_user_content_manager_register_script_message_handler; GGtkBindTable[74].Name := 'webkit_user_content_manager_register_script_message_handler';
  GGtkBindTable[75].VarAddr := @WEBKIT_user_script_new; GGtkBindTable[75].Name := 'webkit_user_script_new';
  GGtkBindTable[76].VarAddr := @WEBKIT_user_script_unref; GGtkBindTable[76].Name := 'webkit_user_script_unref';
  GGtkBindTable[77].VarAddr := @WEBKIT_javascript_result_get_js_value; GGtkBindTable[77].Name := 'webkit_javascript_result_get_js_value';
  GGtkBindTable[78].VarAddr := @WEBKIT_uri_scheme_request_get_uri; GGtkBindTable[78].Name := 'webkit_uri_scheme_request_get_uri';
  GGtkBindTable[79].VarAddr := @WEBKIT_uri_scheme_request_get_path; GGtkBindTable[79].Name := 'webkit_uri_scheme_request_get_path';
  GGtkBindTable[80].VarAddr := @WEBKIT_uri_scheme_request_get_web_view; GGtkBindTable[80].Name := 'webkit_uri_scheme_request_get_web_view';
  GGtkBindTable[81].VarAddr := @WEBKIT_uri_scheme_request_finish; GGtkBindTable[81].Name := 'webkit_uri_scheme_request_finish';
  GGtkBindTable[82].VarAddr := @WEBKIT_uri_scheme_request_finish_error; GGtkBindTable[82].Name := 'webkit_uri_scheme_request_finish_error';
  GGtkBindTable[83].VarAddr := @JSC_value_is_null; GGtkBindTable[83].Name := 'jsc_value_is_null';
  GGtkBindTable[84].VarAddr := @JSC_value_is_undefined; GGtkBindTable[84].Name := 'jsc_value_is_undefined';
  GGtkBindTable[85].VarAddr := @JSC_value_to_json; GGtkBindTable[85].Name := 'jsc_value_to_json';
  GGtkBindTable[86].VarAddr := @JSC_value_to_string; GGtkBindTable[86].Name := 'jsc_value_to_string';
end;

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
  var
    I: Integer;
  begin
    { perf: 表驱动单源，单调用点循环 87 项，零拷贝 PAnsiChar 直通 Sym，单次 Sym 查找 O(1)，I-Cache 单点 vs 60+ and 链膨胀，bytes.ops 单源思想 }
    if not GGtkBindOnce.Done then
      GGtkBindOnce.DoOnce(procedure
      begin
        InitGtkBindTable;
      end);
    for I := Low(GGtkBindTable) to High(GGtkBindTable) do
      if not Sym(GGtkBindTable[I].Name, PPointer(GGtkBindTable[I].VarAddr)^) then
        Exit(False);
    Result := True;
  end;

begin
  { atomic acquire 零撕裂可见性，弱内存下防重复探测 }
  if atomic_load(GProbed, mo_acquire) <> 0 then
  begin
    AInfo := GInfo;
    Exit(GLoaded);
  end;
  EnsureGtkLock;
  GGtkLock.Acquire;
  try
    if atomic_load(GProbed, mo_acquire) <> 0 then
    begin
      AInfo := GInfo;
      Exit(GLoaded);
    end;
    if GLoading then
      Exit(False);
    AInfo := Default(TGtkLoadInfo);
    GLoading := True;
    try
      { webkit 主库按 soname 探测序命中其一 }
      if not TryDlOpen(GWebkitLib,
          ['libwebkit2gtk-4.1.so.0', 'libwebkit2gtk-4.0.so.0'],
          GWebkitSoname) then
      begin
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;
      { GTK3 栈并列必需 }
      if not (TryDlOpen(GGtkLib, ['libgtk-3.so.0'], LHit) and
          TryDlOpen(GGobjectLib, ['libgobject-2.0.so.0'], LHit) and
          TryDlOpen(GGlibLib, ['libglib-2.0.so.0'], LHit)) then
      begin
        ReleaseAll;
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;
      { JSC 与 webkit 同代：4.1 → jsc-4.1，4.0 → jsc-4.0 }
      if PosEx('4.0', GWebkitSoname) > 0 then
        GJscSoname := 'libjavascriptcoregtk-4.0.so.0'
      else
        GJscSoname := 'libjavascriptcoregtk-4.1.so.0';
      if not TryDlOpen(GJscLib, [GJscSoname], LHit) then
      begin
        ReleaseAll;
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;

      if not BindAll then
      begin
        ReleaseAll;
        GInfo.Loaded := False;
        atomic_store(GProbed, 1, mo_release);
        Exit(False);
      end;

      if Sym('g_cancellable_reset', LTmp) then PPointer(@G_cancellable_reset)^ := LTmp;
      if Sym('g_cancellable_is_cancelled', LTmp) then PPointer(@G_cancellable_is_cancelled)^ := LTmp;
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
      atomic_store(GProbed, 1, mo_release);
      AInfo := GInfo;
      Result := True;
    finally
      GLoading := False;
    end;
  finally
    GGtkLock.Release;
  end;
end;

procedure UnloadGtkWebkit;
begin
  EnsureGtkLock;
  GGtkLock.Acquire;
  try
    if atomic_load(GProbed, mo_acquire) = 0 then Exit;
    ReleaseAll;
    GLoaded := False;
    atomic_store(GProbed, 0, mo_release);
    GInfo := Default(TGtkLoadInfo);
  finally
    GGtkLock.Release;
  end;
end;

function GtkLoadInfo: TGtkLoadInfo; inline;
begin
  Result := GInfo;
end;

initialization
  GGtkLockOnce := Once;
  GGtkBindOnce := Once;
  EnsureGtkLock;

finalization
  if GGtkLock <> nil then
  begin
    GGtkLock.Free;
    GGtkLock := nil;
  end;
  GGtkLockOnce := nil;
  GGtkBindOnce := nil;

end.
