# nextpas.core.webview 后端绑定策略

**状态**: **Production Ready**（Wave 1 gtk/fake 全量 + S4-S20 打磨；bench 双基线刷新；W2 Win32 真窗口壳 via wine 已验证且壳满态（DPI 分数/WM_DPICHANGED/最小化）、WebView2 controller 待 Edge S21；W3 待平台）
本文档记录各后端的 ABI 绑定方式、版本矩阵、主线程唤醒原语、
eval 结果语义矩阵，以及从 fafafa.webview 移植资产的清单与边界。

---

## 1. 通用绑定纪律

1. **自声明 ABI，运行时装载**：所有后端 `*.ffi` 单元自带类型/常量/函数指针声明，
   以官方头文件为核对权威；不 include 引擎开发头，不要求 dev 包。
   装载一律经 `nextpas.core.platform.dl`（dlopen/LoadLibrary 语义），
   禁 FPC `DynLibs`。
2. **失败降级诚实**：装载失败 → `WebviewBackendAvailable(kind)=False`；
   强行创建抛 `EWebviewBackendUnavailable`，消息带探测过的 soname 列表。
3. **`*.ffi` 无逻辑**：只有类型、常量、函数指针变量；换算/包装进 `*.loader`
   或实现单元。
4. **回调统一 cdecl + 用户指针**：C 回调必须携带 owner 指针（gpointer /
   void*），禁止全局变量当上下文（fafafa 的 `GProtocolHandler` 教训）。

## 2. gtk 后端（Wave 1，Linux）

### 2.1 装载目标

| 库 | 探测顺序 | 说明 |
|----|----------|------|
| `libwebkit2gtk-4.1.so.0` | 1 | libsoup3 系，当前发行版主流 |
| `libwebkit2gtk-4.0.so.0` | 2 | libsoup2 遗留，能力子集 |
| `libgtk-3.so.0` / `libgobject-2.0.so.0` / `libglib-2.0.so.0` | 并列 | GTK3 栈 |

- WebKitGTK 6.0（GTK4 API）**不在 Wave 1**：API 面完全不同
  （GtkWebView 新控件、URI scheme 机制变化），留待独立评估。
- 版本能力差异（如 `webkit_user_content_manager_register_script_message_handler`
  的 handler 参数在 2.36+ 变化）在 loader 内以符号存在性探测分支，
  不做版本号字符串猜测。

### 2.2 最小函数面（S3 装载清单草案）

窗口壳：`gtk_init_check`、`gtk_window_new/set_title/set_default_size/
set_resizable/set_size_request/resize/maximize/unmaximize/iconify/
deiconify/present/close/show_all/hide`、状态查询
`gtk_window_is_maximized/gtk_widget_get_visible/gtk_widget_get_scale_factor`、
`g_signal_connect_data`（close-event/scale 变化）、
`gtk_widget_get_window`（句柄）、
`gtk_main/main_quit`、`g_idle_add_full/g_source_remove`（dispatcher）。

内容：`webkit_web_view_new`、`load_uri/load_html/reload/stop/go_back/go_forward/
can_go_back/can_go_forward`、eval 双路径：≥2.40 用 `evaluate_javascript`
（`run_javascript` 自该版废弃）；更老版本用 `run_javascript` +
`run_javascript_finish`——两者都能取回结果（自 2.4 起即成对存在），
不存在"老版本无回执"的悬崖，loader 只按符号存在性选路径、
`evaluate_javascript` 缺席时静默用旧对、
`set_zoom_level/get_zoom_level`（zoom-level property 访问函数组）、
WebKitSettings `user-agent` property 读写、
`webkit_settings_set_enable_developer_extras`（DebugTools）、
`webkit_web_view_get_inspector`、`gtk_widget_grab_focus`（Focus）。

会话：默认 context 为共享单例；`DataDirectory` 非空或 `EphemeralSession` 时
自建 context——`webkit_web_context_new_ephemeral`（ephemeral）或
`g_object_new(WEBKIT_TYPE_WEB_CONTEXT, "local-storage-directory", ...)` +
website-data-manager 路径组（持久化自定义目录；具体属性名 S3 对照头文件冻结）。
context 必须先于 view 创建，scheme 注册挂在对应 context 上。

桥 transport：`webkit_user_content_manager_new`、
`register_script_message_handler`（main-frame-only 形态）、
`webkit_user_script_new` + `add_script`、`script_message_received` 信号、
`webkit_javascript_result_*`（eval 结果解包）。

资源：`webkit_web_context_register_uri_scheme`（须在首个 web view 创建前）。

> **S3 冻结注记**（落地实现对照 /usr/include/webkitgtk-4.1 官方头）：
> - eval 双路径按符号存在性选择已实现（loader 能力位 `TGtkEvalPath`），
>   `run_javascript_finish` 经 `WebKitJavascriptResult.get_js_value`
>   统一解包为 JSCValue，两路径同构取回结果。
> - 会话 context 三形态齐备：默认共享（get_default）/ ephemeral /
>   DataDirectory（website_data_manager "base-data-directory"）；
>   视图一律 `new_with_context` 创建，scheme 先于视图注册。
>   勘误（S7）：DataDirectory 形态自 S3 起即坏——manager 直传当
>   context 用，触发 WEBKIT_IS_WEB_CONTEXT CRITICAL；正确路径经
>   `web_context_new_with_website_data_manager` 包装并交还初始引用。
>   因零 live 覆盖从未暴露，datadir 门禁补齐后实锤修复。
> - eval 结果文本：null/undefined 诚实序列化为 'null'；不可 JSON 化
>   值降级 JSC toString 文本。
> - scheme 404 已走真实 GError 路径（S4）：`finish_error(quark
>   'nextpas-webview', 404)`，GError 所有权随调用移交 WebKit；
>   页面侧 `fetch` 以 reject 呈现，与 HTTP 语义对齐。
> - GetTitle（S6）：gtk_window_get_title 同步读 WM 级标题；未显式
>   设置过返回 ''（GTK 语义），fake 返回 options 初始值/SetTitle 痕迹。
> - 桥回执 eval（SendReceipt）为 fire-and-forget，不入在途登记：
>   回执无用户回调、无恰好一次语义；若与 Close 竞态，最坏即页面未
>   收到回执（与页面已销毁的观察一致），且不存在可悬挂的记录分配。
> - scheme 请求归属（S5）：context 级单 handler 限制下，经
>   `webkit_uri_scheme_request_get_web_view` 对回活跃窗口表按发起
>   视图精确路由——多窗口资产命名空间硬隔离（live 双窗门禁覆盖）；
>   service worker 等无视图请求回落"最新活跃窗口"。
> - 浮点异常屏蔽（S5）：gtk_init 前恢复 IEEE 全屏蔽。FPC RTL 默认
>   解封 FP 异常且内核 clone 的子线程继承创建者控制字——GDK/JSC 等
>   引擎代码里合法的除零值运算（预期 ±Inf）会陷阱成随机位置
>   EZeroDivide（gdb 实锤于 libgdk-3 主线程）。C 宿主默认带屏蔽，
>   我们对齐同一语义；仅本进程内生效。
> - 自有 context（ephemeral / DataDirectory）生命周期归窗口：析构时
>   先摘 scheme 注册表再 unref——顺序不可反，注册表按指针地址判重，
>   后摘会误删复用同址的新 context 条目。
> - IsMinimized 为查询式真值（S4）：`gdk_window_get_state` 与
>   `GDK_WINDOW_STATE_ICONIFIED` 位与，不做 C 结构布局解析；
>   Maximized/Visible/几何均为引擎实时真值。
> - idle 投递清理（S8）：已触发的 idle 在 fire 时即经 destroy-notify
>   自毁闭包，tag 随源一并失效；关闭路径对 FIdleTags 逐个
>   `g_main_context_find_source_by_id` 判存后再 remove——直接对陈旧
>   Source ID 二次 remove 会触发 GLib-CRITICAL（demo_webview 的
>   Dispatcher.Post → Close 路径首次实锤暴露）。
> - 导航失败接线（S9）：`OnNavigationFailed` 此前从未生效——
>   load-changed 只处理 STARTED/FINISHED，WEBKIT_LOAD_FAILED 静默
>   吞掉。改接官方 `load-failed` 信号（failing_uri + GError 错误码/
>   消息透传事件），load-changed 的 FAILED(4) 分支作同语义兜底。
> - DevServerUrl 开发模式（S9）：资产面整体惰性——挂载 no-op、解析
>   一律 404；DevServerUrl 窗口若为 context 首窗则跳过 npres 注册，
>   同 context 后续非 dev 窗口在各自构造期按需补注册（注册先于其
>   首次导航，时序安全）；GtkTrace 记录惰性诊断。

### 2.3 主线程唤醒

`g_idle_add_full(G_PRIORITY_DEFAULT, callback, user_data, destroy)`：
投递闭包堆分配 → idle 回调执行并释放。关闭路径上按
`g_main_context_find_source_by_id` 判存后 `g_source_remove`
清理未执行的 pending 投递（S8，见上）；闭包释放在 destroy-notify
单点，fire 与 remove 两路径同构。

## 3. webview2 后端（Wave 2，Windows）

- 入口 `CreateCoreWebView2EnvironmentWithOptions` 来自
  `WebView2Loader.dll`（dlopen）；COM 接口头移植自 fafafa
  `src/fafafa.webview.webview2.interfaces.pas`（GUID/stdcall/token/v2 接口，
  该文件是全项目最难重做的资产，近乎原样搬运后按本仓命名规范改写）。
- 主线程唤醒：隐藏 message-only window + `PostMessage(WM_APP+N)`，
  WndProc 泵出闭包。STA 一致性由"创建线程=泵线程"保证。
- `ExecuteScript` 天然异步（completion handler），直接映射 `Eval` 契约。
- 窗口壳经 Win32 直出（`CreateWindowEx` + 内嵌 controller `put_Bounds`）；
  Maximize/Minimize/Restore/Focus 走 ShowWindow/SetForegroundWindow 族；S20 壳已满态：
  Minimize/Restore/IsMinimized（IsIconic）、GetScaleFactor 分数值（GetDpiForWindow 动态绑定→回退
  GetDeviceCaps，返 Double）、WM_DPICHANGED → ScaleChanged 多播（GLiveList 多实例分发）。
- 会话：`EnvironmentOptions.UserDataFolder`（持久化自定义目录）/
  private 环境变体（Ephemeral）；W2 启动前对照当版文档定案。
- 运行时依赖 WebView2 Runtime（Evergreen）；缺失时降级语义同 §1.2。

## 4. wk 后端（Wave 3，macOS）

- 首选 FPC 原生 Objective-C 模式（`{$modeswitch objectivec1}` +
  `objcclass external ... message 'selector:'` + objcprotocol 子类做
  WKScriptMessageHandler delegate），模式参考 fafafa
  `src/fafafa.webview.wkwebview.pas`（selector 拼写已验证正确）。
- **前置风险**：stage0 对 objcclass/modeswitch objectivec1 的支持未经确认；
  Wave 3 启动前先做编译器能力 probe。不支持则退化为纯 C 形态
  （objc_msgSend 手工调用 + class_addMethod 注册回调），ffi 文件照常自声明。
- 主线程唤醒：`dispatch_async(dispatch_get_main_queue(), ...)` 经 libdispatch dlopen。
- `evaluateJavaScript:completionHandler:` 天然异步，直接映射 `Eval`。
- 会话：`WKWebsiteDataStore default`/`nonPersistent`/自定义 persistent store。

## 5. fake 后端（Wave 1，全平台）

- 纯 Pascal，无引擎无线程；完整走 bridge 协议栈（见 BRIDGE_PROTOCOL.md §8）。
- 提供确定性驱动入口（仅测试可见）：注入帧、捕获 eval 文本、手动触发事件、
  手动泵 dispatcher 队列、手动触发 scale 变化。
- 契约测试的唯一载体；CI 不需要任何图形环境。

## 6. eval 结果语义矩阵

| 页面表达式求值结果 | GTK (run_javascript_finish) | webview2 (ExecuteScript) | wk (completionHandler) | 契约归一 |
|------|------|------|------|------|
| 对象/数组/基本类型 | JSC value → JSON 序列化 | JSON 文本原样 | id/nil 判别后序列化 | JSON 文本透传 |
| `undefined` | undefined value → `"null"`（JSC→JSON 规则） | 字符串 `"null"` | nil → `"null"` | `"null"` |
| `null` | `"null"` | `"null"` | `"<null>"` | `"null"` |
| 抛异常 | finish 取 error → AOnError | completion errorInfo → AOnError | error → AOnError | AOnError(EWebviewEvalFailed) |

归一实现放在各后端 transport 尾部；bridge 不参与 eval 通道（INV-2 注记）。
矩阵在 runtime 冒烟里逐行断言（fake 侧另有等价用例）。

## 7. fafafa.webview 资产移植清单

| fafafa 资产 | 处置 |
|-------------|------|
| `src/fafafa.webview.webview2.interfaces.pas`（手写 COM 头） | **移植**（W2）：GUID/stdcall/v2 接口保留，命名按本仓规范改写 |
| `src/fafafa.webview.wkwebview.pas`（ObjC 绑定模式） | **参考**（W3）：selector 清单可信；结构按 probe 结果重建 |
| `src/fafafa.webview.window.linux.pas`（GTK3 函数清单 50+） | **对照表**（W1）：API→GTK 函数映射有参考价值；绑定本身全部重写（dynlibs 策略统一为本仓 loader 模式） |
| `src/fafafa.webview.webkitgtk.pas`（dynlibs 封装） | **部分参考**（W1)：LoadFunctions/版本探测思路可用；其 Pos/Copy JSON 解析、FIXME 空壳一律不搬 |
| 注入桥协议语义（id/cmd/payload + resolve/reject） | **语义继承**（W1）：收敛为单一协议模块 + 版本号，见 BRIDGE_PROTOCOL.md |
| customprotocol + assets.provider 分层 | **思路继承**（W1）：IWebviewAssets/IWebviewAssetProvider 即其对应物；全局变量上下文改为显式用户指针 |
| threadpool / promise / api.* 命令层 | **不移植**：worker 线程归 async/thread owner；Tauri 全命令面对齐推迟到真实需求出现 |
| 同步 ExecuteScript、嵌套消息泵、忙轮询、三态签名 | **抛弃**（设计红线，README.md） |

## 8. 平台缺口登记

| 缺口 | 影响 | 补位计划 |
|------|------|----------|
| WebKitGTK ≥2.40 弃用 `run_javascript`（被 `evaluate_javascript` 取代） | 双 API 并存期 | loader 按符号存在性选路径：新 API 优先，缺席静默回退旧对；两者均能取结果，无能力悬崖 |
| Wayland 下 NativeHandle 语义（无 XID） | 句柄嵌入场景受限 | Wave 1 文档标注"X11 下为 XID，Wayland 为 NULL"；嵌入场景非目标 |
| macOS ATS 对 http dev server 的限制 | DevServerUrl 在 wk 上可能被拦 | W3 设计时决策（NSAppTransportSecurity 或提示 https） |
| Windows WebView2 Evergreen 版本漂移 | COM v2 接口偶有新增 | 只绑定稳定子集；token 校验失败即 EWebviewBackendUnavailable |
| GTK GetScaleFactor 仅整数（X11 典型 1/2） | HiDpi 小数缩放读不到 | 诚实表已标注；Win32 S20 已真分数（GetDpiForWindow/96.0），Wayland/GTK4 时代再评 |
| 本机（2026-08-26 取证）WebKit 网络进程无法启动：http/file 导航零事件（连可达本地服务也不发起），仅进程内自定义 scheme 可用 | DevServerUrl 直连行为无法做引擎级 live 断言 | 门禁改用同步可观测面（资产惰性）+ scheme 404 覆盖失败接线；真机 http 行为待环境修复后补采 |
