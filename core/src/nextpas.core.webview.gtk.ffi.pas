unit nextpas.core.webview.gtk.ffi;

{** @desc GTK3/GLib/GObject/WebKitGTK/JSC 的 ABI 声明层。
       只含不透明句柄类型、回调类型与函数指针变量——无逻辑、无 external；
       绑定真相归 gtk.loader（经 nextpas.core.platform.dl 动态装载）。

       签名对照源：/usr/include/webkitgtk-4.1/webkit2 官方头
       （WebKitUserContent.h / WebKitWebView.h / WebKitWebContext.h /
       WebKitJavascriptResult.h），S3 冻结；枚举值取自同头 GEnum 定义序。
       调用约定统一 cdecl。本单元禁止 uses 家族其他单元。 *}

{$I nextpas.core.settings.inc}

interface

type
  { GLib 基础标量（LP64 Linux ABI） }
  gboolean = Int32;
  guint = Cardinal;
  gulong = QWord;
  gssize = Int64;
  gchar = AnsiChar;
  Pgchar = ^gchar;
  PPAnsiChar = ^PAnsiChar;
  GQuark = Cardinal;

const
  { GdkWindowState 位（gdkevents.h GEnum 序） }
  GDK_WINDOW_STATE_ICONIFIED = 1 shl 1;

const
  { GLib 主循环源返回值 }
  GLIB_SOURCE_REMOVE = 0;      { gboolean False：执行后移除源 }
  GLIB_SOURCE_CONTINUE = 1;
  G_PRIORITY_DEFAULT = 0;

  { WebKitUserContentInjectedFrames / InjectionTime（GEnum 序） }
  WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES = 0;
  WEBKIT_USER_CONTENT_INJECT_TOP_FRAME = 1;
  WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START = 0;
  WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END = 1;

type
  { ---- 回调类型 ---- }

  TGCallback = procedure(AFirst: Pointer); cdecl;   { 信号 handler 擦除形态：
    实际参数由连接处按具体签名解释（var 参数表首参 self） }
  TGDestroyNotify = procedure(AData: Pointer); cdecl;
  TGIdleFunc = function(AUserData: Pointer): gboolean; cdecl;
  TGAsyncReadyCallback = procedure(ASource: Pointer; ARes: Pointer;
    AUserData: Pointer); cdecl;

  { script-message-received：manager, js_result, user_data }
  TGtkScriptMessageReceived = procedure(AManager: Pointer;
    AJsResult: Pointer; AUserData: Pointer); cdecl;
  { load-changed：webview, load_event(guint), user_data }
  TGtkLoadChanged = procedure(AView: Pointer; AEvent: guint;
    AUserData: Pointer); cdecl;
  { notify::xxx：obj, pspec, user_data }
  TGtkNotify = procedure(AObj: Pointer; APspec: Pointer;
    AUserData: Pointer); cdecl;
  { uri scheme：request, user_data }
  TGtkURISchemeRequest = procedure(ARequest: Pointer;
    AUserData: Pointer); cdecl;

  { GError 只读布局（取 finish 错误消息用） }
  PGError = ^TGError;
  TGError = record
    Domain: Cardinal;
    Code: Int32;
    Message: PAnsiChar;
  end;

var
  { ---- GLib（libglib-2.0）---- }
  G_idle_add_full: function(APriority: Int32; AFunc: TGIdleFunc;
    AUserData: Pointer; ANotify: TGDestroyNotify): guint; cdecl;
  G_source_remove: function(ATag: guint): gboolean; cdecl;
  G_signal_connect_data: function(AInstance: Pointer; ADetailedSignal: PAnsiChar;
    AHandler: Pointer; AData: Pointer; ADestroyData: TGDestroyNotify;
    AConnectFlags: guint): gulong; cdecl;
  G_memory_input_stream_new_from_data: function(AData: Pointer;
    ALen: gssize; ADestroy: TGDestroyNotify): Pointer; cdecl;
  G_memory_input_stream_new_from_bytes: function(ABytes: Pointer): Pointer; cdecl;
  G_bytes_new_with_free_func: function(AData: Pointer; ASize: NativeUInt;
    ADestroy: TGDestroyNotify; AUserData: Pointer): Pointer; cdecl;
  G_bytes_unref: procedure(ABytes: Pointer); cdecl;
  G_malloc: function(ASize: NativeUInt): Pointer; cdecl;
  G_free: procedure(AMem: Pointer); cdecl;
  G_quark_from_static_string: function(AString: PAnsiChar): GQuark; cdecl;
  G_cancellable_new: function: Pointer; cdecl;
  G_cancellable_cancel: procedure(ACancellable: Pointer); cdecl;
  G_error_new_literal: function(ADomain: GQuark; ACode: Int32;
    AMessage: PAnsiChar): PGError; cdecl;
  G_main_loop_new: function(AContext: Pointer; ARunning: gboolean)
    : Pointer; cdecl;
  G_main_loop_run: procedure(ALoop: Pointer); cdecl;
  G_main_loop_quit: procedure(ALoop: Pointer); cdecl;
  G_main_loop_unref: procedure(ALoop: Pointer); cdecl;
  G_timeout_add: function(AInterval: guint; AFunc: TGIdleFunc;
    AData: Pointer): guint; cdecl;
  G_main_context_default: function: Pointer; cdecl;
  G_main_context_find_source_by_id: function(AContext: Pointer;
    ASourceId: guint): Pointer; cdecl;

  { ---- GObject（libgobject-2.0）---- }
  G_object_unref: procedure(AObj: Pointer); cdecl;
  G_object_set: procedure(AObj: Pointer; AFirstProp: PAnsiChar); cdecl; varargs;
  G_object_get: procedure(AObj: Pointer; AFirstProp: PAnsiChar); cdecl; varargs;

  { ---- GTK3（libgtk-3）窗口壳 ---- }
  GTK_init_check: function(AArgc: PInt32; AArgv: PPAnsiChar): gboolean; cdecl;
  GTK_window_new: function(ATyp: Int32): Pointer; cdecl;
  GTK_window_set_title: procedure(AWin: Pointer; ATitle: PAnsiChar); cdecl;
  GTK_window_get_title: function(AWin: Pointer): PAnsiChar; cdecl;
  GTK_window_set_default_size: procedure(AWin: Pointer;
    AW, AH: Int32); cdecl;
  GTK_window_set_resizable: procedure(AWin: Pointer; AResizable: gboolean); cdecl;
  GTK_window_resize: procedure(AWin: Pointer; AW, AH: Int32); cdecl;
  GTK_window_maximize: procedure(AWin: Pointer); cdecl;
  GTK_window_unmaximize: procedure(AWin: Pointer); cdecl;
  GTK_window_iconify: procedure(AWin: Pointer); cdecl;
  GTK_window_deiconify: procedure(AWin: Pointer); cdecl;
  GTK_window_is_maximized: function(AWin: Pointer): gboolean; cdecl;
  GTK_widget_show_all: procedure(AWidget: Pointer); cdecl;
  GTK_widget_hide: procedure(AWidget: Pointer); cdecl;
  GTK_widget_get_visible: function(AWidget: Pointer): gboolean; cdecl;
  GTK_widget_get_scale_factor: function(AWidget: Pointer): Int32; cdecl;
  GTK_widget_grab_focus: procedure(AWidget: Pointer); cdecl;
  GTK_widget_get_window: function(AWidget: Pointer): Pointer; cdecl;
  GTK_widget_destroy: procedure(AWidget: Pointer); cdecl;
  GTK_widget_get_allocated_width: function(AWidget: Pointer): Int32; cdecl;
  GTK_widget_get_allocated_height: function(AWidget: Pointer): Int32; cdecl;
  GTK_widget_set_size_request: procedure(AWidget: Pointer; AWidth, AHeight: Int32); cdecl;
  GDK_window_get_state: function(AWindow: Pointer): guint; cdecl;
  GTK_container_add: procedure(AContainer: Pointer; AWidget: Pointer); cdecl;
  GTK_main: procedure; cdecl;
  GTK_main_quit: procedure; cdecl;
  GTK_main_iteration_do: function(ABlocking: gboolean): gboolean; cdecl;

  { ---- WebKitGTK 核心（libwebkit2gtk-4.x）----
    视图与加载；context 统一路径：视图一律 new_with_context 创建，
    自定义会话（ephemeral/data-dir）与默认共享 context 同构处理 }
  WEBKIT_web_context_get_default: function: Pointer; cdecl;
  WEBKIT_web_view_new_with_context: function(ACtx: Pointer): Pointer; cdecl;
  WEBKIT_web_view_get_user_content_manager: function(AView: Pointer)
    : Pointer; cdecl;
  WEBKIT_web_view_get_uri: function(AView: Pointer): PAnsiChar; cdecl;
  WEBKIT_web_view_new_with_user_content_manager: function(
    AManager: Pointer): Pointer; cdecl;
  WEBKIT_web_view_load_uri: procedure(AView: Pointer; AUri: PAnsiChar); cdecl;
  WEBKIT_web_view_load_html: procedure(AView: Pointer;
    AHtml, ABaseUri: PAnsiChar); cdecl;
  WEBKIT_web_view_reload: procedure(AView: Pointer); cdecl;
  WEBKIT_web_view_stop_loading: procedure(AView: Pointer); cdecl;
  WEBKIT_web_view_go_back: procedure(AView: Pointer); cdecl;
  WEBKIT_web_view_go_forward: procedure(AView: Pointer); cdecl;
  WEBKIT_web_view_can_go_back: function(AView: Pointer): gboolean; cdecl;
  WEBKIT_web_view_can_go_forward: function(AView: Pointer): gboolean; cdecl;
  WEBKIT_web_view_set_zoom_level: procedure(AView: Pointer;
    ALevel: Double); cdecl;
  WEBKIT_web_view_get_zoom_level: function(AView: Pointer): Double; cdecl;
  WEBKIT_web_view_get_inspector: function(AView: Pointer): Pointer; cdecl;
  { eval 双路径（loader 按符号存在性选择，BACKENDS §2.2） }
  WEBKIT_web_view_evaluate_javascript: procedure(AView: Pointer;
    AScript: PAnsiChar; ALength: gssize; AWorldName, ASourceUri: PAnsiChar;
    ACancellable: Pointer; ACallback: TGAsyncReadyCallback;
    AUserData: Pointer); cdecl;
  WEBKIT_web_view_evaluate_javascript_finish: function(AView: Pointer;
    ARes: Pointer; AErr: PPointer): Pointer; cdecl;
  WEBKIT_web_view_run_javascript: procedure(AView: Pointer;
    AScript: PAnsiChar; ACancellable: Pointer;
    ACallback: TGAsyncReadyCallback; AUserData: Pointer); cdecl;
  WEBKIT_web_view_run_javascript_finish: function(AView: Pointer;
    ARes: Pointer; AErr: PPointer): Pointer; cdecl;

  { Settings 与 inspector }
  WEBKIT_web_view_get_settings: function(AView: Pointer): Pointer; cdecl;
  WEBKIT_settings_set_enable_developer_extras: procedure(
    ASettings: Pointer; AEnabled: gboolean); cdecl;

  { 会话 context }
  WEBKIT_web_context_new_ephemeral: function: Pointer; cdecl;
  WEBKIT_web_context_new_with_website_data_manager: function(
    AManager: Pointer): Pointer; cdecl;
  WEBKIT_website_data_manager_new: function(AFirstProp: PAnsiChar)
    : Pointer; cdecl varargs;
  WEBKIT_web_context_register_uri_scheme: procedure(AContext: Pointer;
    AScheme: PAnsiChar; ACallback: TGtkURISchemeRequest;
    AUserData: Pointer; ADestroy: TGDestroyNotify); cdecl;

  { 用户内容与桥 transport }
  WEBKIT_user_content_manager_new: function: Pointer; cdecl;
  WEBKIT_user_content_manager_add_script: procedure(
    AManager: Pointer; AScript: Pointer); cdecl;
  WEBKIT_user_content_manager_register_script_message_handler: function(
    AManager: Pointer; AName: PAnsiChar): gboolean; cdecl;
  WEBKIT_user_script_new: function(ASource: PAnsiChar;
    AInjectedFrames: Int32; AInjectionTime: Int32;
    AAllowList, ABlockList: PPointer): Pointer; cdecl;
  WEBKIT_user_script_unref: procedure(AScript: Pointer); cdecl;
  WEBKIT_javascript_result_get_js_value: function(AJsResult: Pointer)
    : Pointer; cdecl;
  WEBKIT_uri_scheme_request_get_uri: function(ARequest: Pointer)
    : PAnsiChar; cdecl;
  WEBKIT_uri_scheme_request_get_path: function(ARequest: Pointer)
    : PAnsiChar; cdecl;
  WEBKIT_uri_scheme_request_get_web_view: function(ARequest: Pointer)
    : Pointer; cdecl;
  WEBKIT_uri_scheme_request_finish: procedure(ARequest: Pointer;
    AStream: Pointer; AStreamLength: gssize; AMimeType: PAnsiChar); cdecl;
  WEBKIT_uri_scheme_request_finish_error: procedure(ARequest: Pointer;
    AErr: Pointer); cdecl;

  { ---- JSC GLib（libjavascriptcoregtk-4.x，eval 结果解包）---- }
  JSC_value_is_null: function(AValue: Pointer): gboolean; cdecl;
  JSC_value_is_undefined: function(AValue: Pointer): gboolean; cdecl;
  JSC_value_to_json: function(AValue: Pointer; AIndent: guint)
    : PAnsiChar; cdecl;
  JSC_value_to_string: function(AValue: Pointer): PAnsiChar; cdecl;

implementation

end.
