# nextpas.core.webview 代码契约（家族）

**模块路径**：`core/src/nextpas.core.webview*.pas`
**层级**：L3 家族（依赖 L0-L2；后端实现子单元随家族落位）
**Owner**：core-webview lane
**最后更新**：2026-08-25
**版本**：0（Design——本文档为 S0 阶段设计契约，源码家族落地时版本升至 1.0）

---

## 1. 家族布局

| 单元 | 层 | 职责 | 波次 |
|------|----|------|------|
| `nextpas.core.webview.base` | 类型根 | options/events/kinds/错误分类（含 `EWebviewError` 族） | W1 |
| `nextpas.core.webview.intf` | 接口 | `IWebviewWindow` / `IWebviewDispatcher` / `IWebviewAssets` / invoke 契约类型 | W1 |
| `nextpas.core.webview.bridge` | 协议 | 桥协议 v1 编解码 + pending 表 + 注入脚本常量（后端无关，唯一实现） | W1 |
| `nextpas.core.webview.fake` | 测试后端 | 无头脚本化后端：记录调用、手动驱动回调，契约测试全走它 | W1 |
| `nextpas.core.webview.gtk.ffi` | ABI | WebKitGTK/GLib/GTK3 类型与函数指针变量声明（无 external） | W1 |
| `nextpas.core.webview.gtk.loader` | 装载 | dlopen 探测与符号装载（经 `platform.dl`），版本探测 4.1→4.0 | W1 |
| `nextpas.core.webview.gtk` | 后端 | Linux 实现：窗口壳、scheme、idle dispatch、WebKitGTK 信号桥接 | W1 |
| `nextpas.core.webview.factory` | 工厂 | 后端注册/探测/选择 + `TWebviewBuilder` | W1 |
| `nextpas.core.webview` | 门面 | 聚合 re-export 全部公共 API | W1 |
| `nextpas.core.webview.webview2.*` | 后端 | Windows WebView2（base/ffi/loader/backend），COM 头移植 | W2 |
| `nextpas.core.webview.wk.*` | 后端 | macOS WKWebView（base/ffi/backend） | W3 |

### 依赖方向

```
base ← intf ← bridge ← {gtk, fake} ← factory ← 门面
                    └── (webview2/wk 同 gtk 位)
gtk.ffi ← gtk.loader ← gtk        （loader 装载 ffi 函数指针）
```

- **`base` 与 `intf` 禁止 uses 任何后端、bridge、factory 单元。**
- `bridge` 禁止 uses 任何后端单元；它只认识 `intf` 的契约。
- `*.ffi` 只含 ABI 类型与函数指针声明，不含逻辑、不含 `external`。
- `*.loader` 只做装载与探测，是唯一允许触碰动态加载设施的后端侧单元；
  动态加载原语一律来自 `nextpas.core.platform.dl`，
  **禁止使用 FPC `DynLibs` 单元**（gate policy：raw host units 仅限 owner path）。

### 注册表时机

module registry 条目必须与首个源码家族同批落地（S1）：注册表门禁
`check_architecture_source_contracts.py` 会拒绝没有 source family 的注册行。
S0 文档 slice 不改注册表。

---

## 2. 核心类型（webview.base）

### 2.1 后端种类与可用性

```pascal
TWebviewKind = (wvGtk, wvWebview2, wvWk, wvFake);
```

### 2.2 窗口选项

```pascal
TWebviewOptions = record
  Title: string;            // 默认 ''
  Width: Integer;           // 默认 1024；<=0 时用引擎默认
  Height: Integer;          // 默认 768
  MinWidth: Integer;        // 0 = 不设限制
  MinHeight: Integer;
  MaxWidth: Integer;        // 0 = 不设限制
  MaxHeight: Integer;
  Resizable: Boolean;       // 默认 True
  DebugTools: Boolean;      // 默认 False；True 打开 inspector/devtools
  SchemeName: string;       // 默认 'npres'；资源 scheme 名
  InitialHtml: string;      // 非空则启动加载该 HTML（优先级低于 InitialUrl）
  InitialUrl: string;       // 非空则启动导航；DevServerUrl 存在时通常填它
  DevServerUrl: string;     // 非空 = 开发模式：资源服务整体让位给该 http 地址
end;

function DefaultWebviewOptions: TWebviewOptions;
```

**语义诚实表**（跨平台差异显式声明，不做假装）：

| 字段 | GTK (WebKitGTK) | webview2 (W2) | wk (W3) |
|------|-----------------|----------------|---------|
| MinWidth/MinHeight | `gtk_window_set_geometry_hints` 生效 | `SetBounds` 夹取生效 | `contentMinSize` 生效 |
| DebugTools | 需要 WebKit ≥ 2.24（4.x 均满足） | `AreDevToolsEnabled` | `isInspectable`（macOS 13+ 才可编程开启） |
| SchemeName | 必须在创建第一个 webview 前 register_uri_scheme，否则静默失效 | `WebResourceRequested` 可后挂但首帧前生效最稳 | WKURLSchemeHandler 随 configuration 创建 |
| DevServerUrl | 直接 Navigate 到 http URL | 同左 | ATS 例外由调用方自行负责（W3 再议） |

### 2.3 事件 record

```pascal
TWebviewNavigationEvent = record
  Url: string;          // UTF-8 绝对地址
  IsError: Boolean;     // Failed 事件专用
  ErrorCode: Integer;   // 引擎原生码；未知为 0
  ErrorMessage: string; // 引擎原文或 ''
end;
```

### 2.4 错误分类

错误族基类派生自框架根异常：

```pascal
EWebviewError              = class(ENextPasError);  // 族基类，category=ecInternal
EWebviewBackendUnavailable = class(EWebviewError);  // dlopen/探测失败；ecResourceExhausted? 否→ecInternal
EWebviewNotInitialized     = class(EWebviewError);  // 未创建即使用；ecInvalidState 类目
EWebviewInvalidState       = class(EWebviewError);  // 重复 Create / Close 后操作等
EWebviewClosed             = class(EWebviewError);  // Close 之后仍发起 Eval/Emit 等
EWebviewTimeout            = class(EWebviewError);  // invoke pending 超时（若启用）
EWebviewBadFrame           = class(EWebviewError);  // bridge 收到无法解析的帧；ecParse
EWebviewInvokeError        = class(EWebviewError);  // handler 内抛出的包装；携带 code/message 回传前端 reject
```

- 具体类目值在 S1 实现时对照 `nextpas.core.exception.TErrorCategory` 定值并写测试。
- `EWebviewInvokeError` 额外携带稳定字符串 `Code`（见 BRIDGE_PROTOCOL.md 错误码表），
  桥捕获它转 reject；其他异常一律转 `npw.handler_error` 且消息原文透传。

---

## 3. 接口契约（webview.intf）

对外一律 interface（COM 引用计数），消费方不手写释放。

### 3.1 主线程投递

```pascal
IWebviewDispatcher = interface
  { 从任意线程把闭包投递到 UI 主线程执行；窗口关闭后投递被静默丢弃 }
  procedure Post(AProc: TWebviewProcRef); overload;
  procedure Post(AProc: TWebviewProcMethod); overload;
  procedure Post(AProc: TWebviewProc); overload;
  property IsOnMainThread: Boolean read GetIsOnMainThread;
end;

TWebviewProcRef    = reference to procedure;
TWebviewProcMethod = procedure of object;
TWebviewProc       = procedure;
```

- 三种回调形式并存是仓库统一范式（design-conventions §8）。
- **一切用户回调（invoke handler 完成、eval 完成、事件通知）都在 UI 主线程触发。**
- 后端各自提供主线程唤醒原语：GTK = `g_idle_add_full`；webview2 = 隐藏 hwnd
  `PostMessage`；wk = `dispatch_async(main)`。这是后端接口的一部分（BACKENDS.md）。

### 3.2 窗口 + 内容

```pascal
IWebviewWindow = interface
  { 生命周期 }
  procedure Close;                       // 幂等；Close 后其他方法抛 EWebviewClosed
  function IsClosed: Boolean;

  { 窗口壳 }
  procedure Show;  procedure Hide;
  function IsVisible: Boolean;
  procedure SetTitle(const ATitle: string);
  procedure SetBounds(AWidth, AHeight: Integer);
  function GetWidth: Integer;  function GetHeight: Integer;
  procedure SetResizable(AResizable: Boolean);

  { 导航 }
  procedure Navigate(const AUrl: string);
  procedure NavigateToString(const AHtml: string);
  procedure Reload;  procedure Stop;
  function CanGoBack: Boolean;   function GoBack: Boolean;
  function CanGoForward: Boolean; function GoForward: Boolean;

  { 异步 eval —— 唯一入口，禁止同步形态 }
  { ACallback 在 UI 主线程收到 JSON 结果文本；失败以异常进入 AOnError }
  procedure Eval(const AJavascript: string;
    ACallback: TWebviewEvalCallback;
    AOnError: TWebviewEvalErrorCallback);

  { IPC：native → js 事件 }
  procedure Emit(const AEvent, APayloadJson: string);

  { 主线程投递（转发到本窗口后端的 dispatcher） }
  function Dispatcher: IWebviewDispatcher;

  { 句柄（平台原生指针，仅供嵌入场景；语义见 BACKENDS.md） }
  function NativeHandle: TWebviewNativeHandle;

  { 事件注册：三种回调形式各一重载（此处列匿名形，method/proc 形省略） }
  procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
  procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload;
  procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload;
  procedure OnWindowClosed(AHandler: TWebviewNotifyHandler); overload;
  procedure OnReady(AHandler: TWebviewNotifyHandler); overload; // 注入桥就绪（每导航一次）
end;

TWebviewEvalCallback     = reference to procedure(const AResultJson: string);
TWebviewEvalErrorCallback= reference to procedure(const AError: Exception);
TWebviewNavEventHandler  = reference to procedure(const AEvent: TWebviewNavigationEvent);
TWebviewNavFailedHandler = reference to procedure(const AEvent: TWebviewNavigationEvent);
TWebviewNotifyHandler    = reference to procedure;
```

- `Eval` 结果文本是 JS 值的 JSON 序列化（引擎行为：`undefined` 序列化为 `"null"`
  或空串按后端诚实记录于 BACKENDS.md）。
- 事件注册返回句柄用于反注册的需求推迟到出现真实用例再扩展（YAGNI）。

### 3.3 invoke 契约

```pascal
{ 同步 handler：直接返回结果 JSON；抛异常 = reject }
TWebviewInvokeSyncHandler = reference to function(
  const APayloadJson: string): string;

{ 异步 handler：稍后调 ACompletion.Ok / Fail；ACompletion 只能调用一次 }
TWebviewInvokeAsyncHandler = reference to procedure(
  const APayloadJson: string;
  const ACompletion: IWebviewInvokeCompletion);

IWebviewInvokeCompletion = interface
  procedure Ok(const AResultJson: string);
  procedure Fail(const ACode, AMessage: string);
end;
```

注册 API 在 `IWebviewInvokeRegistry`（由 window 暴露 `Invokes` 属性），
同样提供 method-pointer / proc 三重载。handler 抛出的一切异常：
`EWebviewInvokeError` 按其 Code/Message reject，其余按 `npw.handler_error` reject。

### 3.4 资源服务

```pascal
IWebviewAssets = interface
  { 解析失败返回 False，不抛异常（404 是正常业务路径） }
  function TryResolve(const ASchemeRelativePath: string;
    out ABytes: TBytes; out AMimeType: string): Boolean;
  procedure MountEmbedded(const APrefix: string; AProvider: IWebviewAssetProvider);
  procedure MountDirectory(const APrefix, ARootDir: string);
end;

IWebviewAssetProvider = interface
  function TryResolve(const APath: string;
    out ABytes: TBytes; out AMimeType: string): Boolean;
end;
```

- 解析顺序 = mount 顺序（先挂先查）；默认建议 embedded 优先。
- MIME 表内置 ~30 条常见映射，未命中回退 `application/octet-stream`。
- scheme 名默认 `npres`；URL 形态 `npres://<mount>/<path>`。
- DevServerUrl 非空时不注册 scheme 路径处理（开发模式直连 http）。
- 内嵌 provider 的字节来源推荐复用 `respack` 家族产物（集成点在 examples 论证，
  intf 不依赖 respack）。

---

## 4. 线程模型

1. **UI 主线程** = 创建窗口并驱动后端主循环的线程。一个进程内可以有多个窗口，
   但 Wave 1 所有窗口共享同一 UI 主线程与同一个 GLib/Win32/Foundation 主循环。
2. **引擎回调天然在主线程到达**（WebKitGTK 信号在 default main context 触发；
   WebView2 事件在创建它的 STA 线程）。后端不得把它们抛到别的线程。
3. **用户 handler 一律主线程内联执行**。handler 里做重活的正确姿势：
   post 给应用自己的 `TAsyncLoop`，完成后 `Dispatcher.Post` 回主线程收尾。
   本模块不代管 worker 线程池（那是 async/thread owner 的事）。
4. **跨线程安全面**只有三处，其余方法按"UI 线程亲和"对待（违例属编程错误，
   debug 构建下断言）：
   - `IWebviewDispatcher.Post`（任意线程 → 主线程）
   - `IWebviewWindow.Close`（内部 marshal 到主线程，幂等）
   - `IWebviewInvokeCompletion.Ok/Fail`（允许 worker 线程完成 invoke，桥内部 marshal）
5. **禁止同步 eval**。任何"等待页面结果"的需求都必须表达成异步回调链。
   不提供 `{$IFDEF}` 出口的同步变体，不给嵌套消息泵/忙轮询任何生存空间
   （fafafa 教训 #1）。
6. 与 `async.loop` 的关系：本模块不 uses `TAsyncLoop`；应用层自行把两者接起来
   （示例演示）。保持 webview 对 async owner 无编译期依赖，避免 L3 内部交叉。

## 5. 主循环

```pascal
{ factory 提供；阻塞直到所有窗口关闭或 ExitLoop }
procedure WebviewRunLoop;
procedure WebviewExitLoop;
```

- GTK：`gtk_main` / `gtk_main_quit`。
- RunLoop 期间宿主不得再占用该线程做长计算；后台工作走第 4 节姿势。
- fake 后端提供手动泵（`PumpOnce`）供确定性测试。

## 6. 不变量

- INV-1 `Close` 幂等；Close 后除 `IsClosed/NativeHandle` 外一切方法抛 `EWebviewClosed`。
- INV-2 pending invoke id 进程内单调递增，不复用；窗口销毁时全部 pending 以
  `npw.closed` reject。
- INV-3 `bridge` 对帧的编解码是无处不在的唯一权威；任何后端不得私自解析 payload。
- INV-4 `base`/`intf` 的 uses 闭包里不出现 `webview.gtk*`、`webview.fake`、
  `webview.factory`、`webview.bridge`（source-contract 门禁冻结）。
- INV-5 生产单元（非 loader）不出现 FPC host units（`DynLibs`/`Windows`/
  `BaseUnix`/`ctypes`…）；GTK/Win32/ObjC 真相全部收敛在后端 `ffi`+`loader`。
- INV-6 每个 public 异步入口都有超时或不超时的明确语义并写入注释；
  invoke pending 默认不限时（前端 Promise 天然有调用方语义），可选超时参数留待真实需求。

## 7. 测试门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| 契约测试（CI 必跑） | `tests/nextpas.core.webview/test_*`，全走 fake | base 校验、bridge 编解码 round-trip/坏帧/pending 生命周期、fake 全接口行为矩阵、factory 选择逻辑 |
| source-contract | `tests/architecture/source_contracts/` 扩展 | INV-4/INV-5 静态扫描；`*.ffi` 无逻辑检查 |
| 运行时冒烟（本地/Linux CI） | `test_webview_gtk_runtime` | 探测到 libwebkit2gtk 才跑；Xvfb 下建窗→NavigateToString→eval round-trip→invoke round-trip；未探测到输出 SKIP 并以 `NEXTPAS_WEBVIEW_GTK_REQUIRED=1` 强制 |
| compile-only | 非 Linux host | gtk/webview2 单元参与语法级编译门禁（不链接） |
| benchmark | `benchmarks/nextpas.core.webview/bench_bridge` | 帧编码/解码 ns/op、dispatcher Post 往返延迟（nextpas.core.bench 框架，禁自定义计时） |

runtime 冒烟允许的最大环境假设：存在 `libwebkit2gtk-4.1.so.0`（或 4.0）运行库
+ GTK3 运行库；不要求 dev 包（我们自声明 ABI）。

## 8. 稳定性

- 当前 `draft`；registry 条目随 S1 源码落地，truth level 记 `focused-runtime`
  （fake 面）/ `source-contract`（边界面），runtime 冒烟达标后升
  `focused-runtime` 全量。
- 公共 API 变更纪律：`intf` 单元视为冻结候选，改动必须过契约测试并更新本文档。
