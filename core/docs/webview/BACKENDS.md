# nextpas.core.webview 后端绑定策略

**状态**: Design（S0）
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
> - eval 结果文本：null/undefined 诚实序列化为 'null'；不可 JSON 化
>   值降级 JSC toString 文本。
> - scheme 404 当前以正文诚实返回（finish text/html），HTTP 级错误码
>   语义留待 GError 路径 S4 精化。
> - IsMinimized 为本地跟踪（window-state-event 解析 S4 精化）；
>   Maximized/Visible/几何均为引擎实时真值。

### 2.3 主线程唤醒

`g_idle_add_full(G_PRIORITY_DEFAULT, callback, user_data, destroy)`：
投递闭包堆分配 → idle 回调执行并释放。关闭路径上用 `g_source_remove`
清理未执行的 pending 投递（owner 计数保护）。

## 3. webview2 后端（Wave 2，Windows）

- 入口 `CreateCoreWebView2EnvironmentWithOptions` 来自
  `WebView2Loader.dll`（dlopen）；COM 接口头移植自 fafafa
  `src/fafafa.webview.webview2.interfaces.pas`（GUID/stdcall/token/v2 接口，
  该文件是全项目最难重做的资产，近乎原样搬运后按本仓命名规范改写）。
- 主线程唤醒：隐藏 message-only window + `PostMessage(WM_APP+N)`，
  WndProc 泵出闭包。STA 一致性由"创建线程=泵线程"保证。
- `ExecuteScript` 天然异步（completion handler），直接映射 `Eval` 契约。
- 窗口壳经 Win32 直出（`CreateWindowEx` + 内嵌 controller `put_Bounds`）；
  Maximize/Minimize/Restore/Focus 走 ShowWindow/SetForegroundWindow 族。
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
| GTK GetScaleFactor 仅整数（X11 典型 1/2） | HiDpi 小数缩放读不到 | 诚实表已标注；Wayland/GTK4 时代再评 |
