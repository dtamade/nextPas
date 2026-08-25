# webview × Go / Rust 对标纲领

**状态**: Design（S0）
**Owner**: core-webview lane
**活入口**: [README.md](README.md) · [CONTRACT.md](CONTRACT.md) · [BRIDGE_PROTOCOL.md](BRIDGE_PROTOCOL.md) · [BACKENDS.md](BACKENDS.md)

原则：对标的是 **生产级同类库的抽象质量、语义诚实度与可证测量**，
不是 API 数量或营销特性。方法论对齐 `core/docs/tui/PARITY-GO-RUST.md`
（公平口径、禁止假胜）。

---

## 1. 对标对象（公平口径）

| 维度 | Rust | Go | nextpas.core.webview |
|------|------|-----|------------------|
| 引擎抽象 | **wry**（WebKitGTK / WKWebView / WebView2 三后端，Tauri 底座） | **Wails v2/v3**（系统引擎，Windows/macOS/Linux） | 同一三引擎集合，dlopen 自声明 ABI |
| 窗口壳 | **tao**（winit 分支：WindowBuilder/EventLoop/ControlFlow/DPI） | Wails WebviewWindow options | IWebviewWindow 最小集 + 诚实表 |
| 应用框架 | **Tauri v2**（invoke 命令宏、capabilities ACL、插件、asset 协议） | Wails Bind 反射绑定 / Events / AssetServer middleware | 显式注册 handler + 统一桥协议 v1 |
| IPC 心智 | `invoke(cmd,args) → Promise` | `$backend.Call` / 生成绑定 | `__npw.invoke(cmd,payload) → Promise` |
| 测量 | criterion micro-bench | testing.B | `nextpas.core.bench`（禁自定义计时） |
| 错误模型 | Result/panic | error 返回值 | 异常（仓库统一策略），桥层转 reject |

版本口径：以写作时点的稳定版能力为准（wry 现行稳定系、Tauri v2、Wails v2 +
v3 alpha），不追 nightly 特性；引用具体行为时在 BACKENDS.md 附头文件/文档核对注记。

## 2. 特性矩阵

图例：✅ Wave 1 · 🔵 Wave 2/3（标 W2/W3）· 🟡 Deferred（CONTRACT §9 登记簿有触发条件）· ⛔ Not planned（§5 有理由）· ❌ 明确不做且不登记

| 能力 | wry/tao | Tauri v2 | Wails | 本模块 | 备注 |
|------|---------|----------|-------|--------|------|
| 三引擎统一抽象 | ✅ | ✅ | ✅ | ✅ W1-W3 | 波次 gtk→webview2→wk |
| 无头契约后端 | ❌ | ❌ | ❌ | ✅ W1 | **本模块独有优势**：fake 走完整协议栈，CI 无图形依赖 |
| 窗口标题/尺寸/resize | ✅ | ✅ | ✅ | ✅ W1 | |
| min/max 尺寸约束 | ✅ | ✅ | ✅ | ✅ W1 | |
| 最大化/最小化/还原/focus | ✅ | ✅ | ✅ | ✅ W1 | tao 对齐最小集 |
| 焦点/标题变化事件回调 | ✅ WindowEvent | ✅ | ✅ | ⛔ | 无已知消费场景；需要时随 deferred-Win 批次评估 |
| 全屏/decorations/透明/图标/always-on-top | ✅ | ✅ | ✅ | 🟡 deferred-Win | 触发条件见登记簿 |
| 无边框拖动区 | ✅ | ✅ | ✅ | 🟡 deferred-Win | |
| close-request veto（关闭前确认） | ✅ CloseRequested | ✅ prevent_close | ✅ OnBeforeClose | 🟡 deferred-Sec | GTK 信号绑定预留，Pascal 出口待触发 |
| drag-drop（文件/文本拖入页面） | ➖ 经页面事件 | ✅ 插件化 | ✅ | ⛔ | 页面自身 HTML5 DnD 即可覆盖；native 拖出窗口场景未出现 |
| DPI scale factor 只读 + 变化事件 | ✅（一等公民） | ✅ | ✅ | ✅ W1 最小集 | GTK 整数限制诚实标注 |
| 异步 eval 取结果 | ✅ | ✅ | ✅ | ✅ W1 | exactly-one 回调语义 |
| 同步 eval | ❌ | ❌ | ❌ | ❌ | 设计红线；三家正规军同样不做 |
| js→native IPC | ✅ ipc_handler | ✅ invoke+宏 | ✅ Bind 反射 | ✅ W1 显式注册 | 见 §5.1 |
| native→js 事件 | ➖ 经 eval | ✅ emit | ✅ EventsEmit | ✅ W1 Emit | |
| 自定义协议资源服务 | ✅ 完整 Response | ✅ 含 Range | ✅ 含 middleware | ✅ W1 最简 200/404；🟡 deferred-Res 扩展 | 见 §5.4 |
| 初始化脚本注入 | ✅ | ✅ | ➖ | ✅ W1 InitScripts | 主帧 only |
| UA 读写 | 平台属性散装 | ✅ | ✅ | ✅ W1 统一面 | |
| zoom 读写 | ✅ | ✅ | ✅ | ✅ W1 | |
| devtools 开关 | ✅ | ✅ | ✅ | ✅ W1 | |
| 会话目录/隐私会话 | 平台属性散装 | ✅ | 部分 | ✅ W1 DataDirectory/EphemeralSession | 互斥校验入 base |
| 多窗口 | ✅ | ✅ | ✅ | ✅ W1（共享 UI 线程） | 单窗单 webview |
| 多 webview 单窗 | ➖ | ✅ | ❌ | 🟡 deferred-Arch | |
| 导航拦截/veto/allowlist | 部分 | ✅ | ✅ | 🟡 deferred-Sec | 安全模型先立牌（CONTRACT §6） |
| 权限模型 capabilities/ACL | ➖ | ✅ | ❌ | ⛔ | §5.2 |
| 事件循环细粒度控制 ControlFlow | ✅ tao | ➖ | ➖ | 🟡 deferred-LI（IterateOnce） | 防 fafafa 式半成品调度器 |
| 打包/bundler/installer | ➖ | ✅ | ✅ | ❌ | §5.6 |
| 自动更新/live reload 工具链 | ➖ | ✅ | ✅ | ❌ | 非本模块职责 |

## 3. 可比（做）

1. **bridge 帧编解码** — encode/decode `{v,id,cmd,payload}` ns/op；
   对照组：json owner 裸序列化同 payload（分离"协议开销"与"JSON 成本"）。
2. **dispatcher Post 往返延迟** — 投递→执行空闭包；三后端各测并记录
   （g_idle_add / PostMessage / dispatch_async），同机同负载协议。
3. **invoke round-trip**（fake 后端）— 帧 in → handler → 回执 out 全链路 ns/op。
4. **正确性语料** — 坏帧族（截断/深嵌套/超大串/坏 UTF-8/未知 v）、
   pending 生命周期（close 时批量 reject）、exactly-one 性质穷举。
5. **eval 结果语义矩阵**（BACKENDS.md §6）逐格 runtime 断言。

基准落点：`benchmarks/nextpas.core.webview/bench_bridge`，
nextpas.core.bench 框架，`-O2`，报告格式对齐仓库基准规范。

## 4. 不可比（禁止假胜）

- **渲染/JS 性能**：那是 WebKit/Chromium 的成绩，与我们无关；任何"接近原生
  引擎速度"的说法都属造假。
- **命令/API 数量对比 Tauri os/fs/http 插件全家桶**：范围不同，不比。
- **内存占用/启动时间跨引擎横比**：环境噪声主导；除非同机同引擎版本严格协议，
  否则只做同引擎下"有无本模块封装"的自比（开销应≈0）。
- **bundle 体积**：我们无打包器，无从比起。
- Rust 被 DCE 掉的 0 ns/op、Go 的编译期常量折叠——测量口径必须写明。

## 5. 刻意不抄清单（含理由）

### 5.1 Tauri command 宏 / Wails Bind 结构体反射绑定

显式 `Register(cmd, handler)` 起步。理由：(a) Pascal `reflect` 模块尚处 draft，
反射绑定会把 draft 依赖带进公共契约；(b) 显式注册的类型边界清晰、错误提前到
编译期；(c) 未来若需要，走 codegen 生成注册代码（编译期展开，等价宏效果），
接口不变。

### 5.2 Tauri v2 capabilities/ACL

单进程桌面应用的威胁模型与 Tauri（任意前端代码 + 插件市场）不同。Wave 1 用
CONTRACT §6 的最小威胁模型（桥主帧 only + 远程内容警示）顶住；导航 allowlist
（deferred-Sec）先行；完整 ACL 仅当出现"加载不可信远程内容"的真实场景再立项。

### 5.3 wry 完整自定义协议 Response（header/status/range）

静态资源 200/404 覆盖 90% 场景；range 请求是大文件媒体服务的需求，触发前
不做。intf 已预留扩展缝（加第二方法，不破坏现签名）。

### 5.4 tao 全量窗口属性

fullscreen/decoration/transparent/icon/always-on-top 属 deferred-Win 分批，
每批过诚实表复核。一次铺全会重演 fafafa"API 面领先验证面"的腐化路径。

**tao 的对应物规划**：本模块 Wave 1 只在内部养"最小窗口缝"
（`webview.gtk.win`，纯函数式、无 webview 概念）；当第二个 consumer
（gpu/font 渲染栈、IDE workbench）出现或 Wave 2 落地前，按受控跨模块流程
抽取为独立跨平台窗口模块（含 Android/iOS 的宿主 surface attach 模型——
那是与 tao 模型本质不同的部分，tao 无此负担，我们不能照抄它的形状）。
完整路线见 CONTRACT.md §1.1。

### 5.5 Tauri/Wails 的事件循环接管模式

两者都整体接管 main()。本模块提供 `WebviewRunLoop` 但把 `IterateOnce`
（融合进宿主循环）登记为 deferred-LI——因为循环所有权设计（gtk_main vs
自驱 g_main_context_iteration）必须与 TAsyncLoop 集成方案一起定，
半成品集成面就是 fafafa 死代码调度器的翻版。

### 5.6 打包器 / updater / devtool CLI

Tauri CLI、Wails CLI 属应用分发工具链，不是 webview 抽象的一部分。
nextPas 侧如需，独立立项。

## 6. 语义差异记录（有意为之的不同）

| 议题 | Go/Rust 同类 | 本模块 | 理由 |
|------|-------------|--------|------|
| 错误通道 | Result/error 返回值 | 异常直抛，桥转 reject | 仓库错误处理策略；handler 直线代码 |
| 回调线程承诺 | 未明示（实际基本主线程） | 契约写死：一切用户回调 UI 主线程 | fafafa 教训制度化；跨线程只有 Dispatcher.Post 一个口 |
| invoke id 方向 | 实现细节未公开承诺 | JS 侧分配、native 回显，写入协议文档 | 排查时序问题时双方都有同一事实源 |
| `undefined` eval 结果 | 各引擎不一致 | 归一 `"null"` 并逐格断言 | 跨后端行为可预期 |
| 无头测试 | 无 | fake 后端 = 一等交付物 | CI 无图形依赖；契约测试覆盖真实协议栈 |
