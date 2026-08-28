# nextpas.core.webview

**状态**: **Production Ready · focused-runtime · 冻结**（Wave 1 双后端落地——fake 测试支撑 + GTK/WebKitGTK；
S4 后端打磨、S5 多窗口隔离与事件驱动门禁、S6 GetTitle 与会话三形态
live 覆盖、S7 DataDirectory 修复、S8 可运行 demo 与 idle 清理修正、
S9 DevServerUrl/构造期导航与导航失败接线、S10 Builder 补齐与 respack
资产集成示例、S11 VFS 适配器抽离与 bench 基线、S12 高级感/性能/稳定性打磨、S13 复用/稳定性/可访问性收口、S14 bench_bridge 与文档闭环、S15 MIME 65 项与骨架屏收口、S16 生产就绪收口、S17 respack 高级感对齐与 bench 刷新、S18 W2 桩+loader via wine 交叉验证、S19 W2 Win32 真窗口壳、S20 满态壳（DPI 分数/最小化/WM_DPICHANGED）、S21 真 controller（Env→Controller/Eval/桥/WMS bounds）均已进主线；S22 导航真事件、S23 调度与稳定、S24 门禁与 bench 收口、S25 W3 WKWebView 桩（13 门全绿）、S26 终极封版（hints 洁净/Closed 守卫）、S27 bench 基线刷新、S28 警告洁净/双跑自检、S29 主循环 4 后端完整、S30 静态审计、S31 类型设计冻结、S32 注册表 focused-runtime、S33 零负载一致性抛光、S34 零开销与复用抛光（Builder 去重 + VFS 零 Delete）、S35 契约与稳定性收口（__npw 早筛）、S36 热点 inline 与早期互斥（13 链路 inline + Fail Fast）、S37 容量与 Fail-Fast 完整性（IsValidWebviewSchemeToken 复用 + 倍增预分配 + Scheme/几何早筛） — CONTRACT 1.31，wine 可交互，W3 wk 桩已冻结，Darwin 真实现待编译器 ObjC 探通）
**层级**: L3 家族（依赖 L0-L2）
**目标形态**: Tauri / Wails 式桌面应用外壳——系统自带浏览器引擎 + 原生窗口壳 + 统一 IPC 桥，
接口抽象在前、后端实现在后。
**对标基准**: [PARITY-GO-RUST.md](PARITY-GO-RUST.md)（Rust wry/tao/Tauri v2 · Go Wails v2/v3）

## 模块定位

`nextpas.core.webview` 为桌面 GUI 应用提供"宿主窗口内嵌浏览器引擎"的最小完整抽象：

- **窗口壳**：标题、尺寸、min/max、最大化/最小化/还原、focus 等原生窗口操作
  （模块自己拥有窗口）。
- **内容承载**：导航到 URL / HTML 字符串；zoom 与 UA 控制；通过自定义 URL scheme
  提供内嵌资源；开发模式可直连 dev server。
- **双向 IPC**：前端 `invoke(cmd, payload) → Promise`，Pascal 侧注册命名 handler；
  Pascal → 前端事件 `Emit`。
- **异步 eval**：向页面执行 JavaScript 并异步取回结果。不提供同步 eval（设计红线，
  见 [CONTRACT.md](CONTRACT.md) 的线程模型章节）。

与同类库的分工口径：**对标的是 wry/Tauri/Wails 的抽象质量与语义诚实度，
不是命令面数量**。Tauri 的 os/fs/http 全家桶 API、Wails 的 struct 反射绑定
都不在 Wave 1 范围（见 PARITY-GO-RUST.md 的"不抄清单"）。

引擎一律使用系统安装的浏览器引擎（WebKitGTK / WebView2 / WKWebView），
不捆绑、不改写引擎本身。

## 后端矩阵

| 后端 | 平台 | 引擎 | 绑定方式 | 波次 |
|------|------|------|----------|------|
| `gtk` | Linux | WebKitGTK 4.1（探测降级 4.0） | 运行时 dlopen，自声明 ABI | **Wave 1** |
| `fake` | 全平台（无头） | 无引擎，脚本化驱动 | 纯 Pascal | **Wave 1**（测试支撑） |
| `webview2` | Windows (wine 10.0 可交叉验证) | Microsoft WebView2 (Edge) | COM 完整 vtable + WebView2Loader.dll 动态加载（platform.dl；Linux 不可用，wine 可用） | **Wave 2 真 controller 已落地**（ffi 含 WebMessageArgs + loader + Win32 满态壳 WM_SIZE + 真 controller 链 Env→Controller/ExecuteScript/WebMessage/注入/bounds；wine 仿真可交互） |
| `wk` | macOS | WKWebView | ObjC runtime / objcclass（待编译器能力确认） | **Wave 3 桩已冻结**（S25 三件套 + S26 hints/Closed 封版；Linux 恒 False，Darwin 探针待 ObjC） |

平台能力差异以"语义诚实表"记录在 [CONTRACT.md](CONTRACT.md)，不做跨平台假装。

## 文档导航

| 文档 | 内容 |
|------|------|
| [CONTRACT.md](CONTRACT.md) | 代码契约：单元布局、依赖方向、核心类型与接口签名、线程模型、安全模型、不变量、Deferred 登记簿、测试门禁 |
| [BRIDGE_PROTOCOL.md](BRIDGE_PROTOCOL.md) | IPC 注入桥协议 v1 完整规范（帧格式、握手时序、错误码表、iframe 立场） |
| [BACKENDS.md](BACKENDS.md) | 各后端绑定策略、版本矩阵、eval 结果语义矩阵、fafafa.webview 资产移植清单 |
| [PARITY-GO-RUST.md](PARITY-GO-RUST.md) | 对标纲领：wry/tao/Tauri v2/Wails v2-v3 特性矩阵、可比项、"禁止假胜"清单 |

活动计划见 `core/docs/plans/2026-08-25-webview-module.md`（slice 划分、验证与 landing 约定）。

## 可运行演示

`core/tests/nextpas.core.webview/examples/demo_webview` 是完整消费侧示例：
真实 WebKitGTK 窗口 + 深色 UI，覆盖全 IPC 矩阵（eval 往返 / 同步 invoke /
有状态 handler / 异步 completion / native→web 事件推送全环），
只依赖公共门面 `nextpas.core.webview`。

```bash
# 人工演示：打开窗口，点按交互，stdout 记录桥流量
make -C core/tests/nextpas.core.webview/examples/demo_webview run

# 自检门：同一页面事件驱动跑完矩阵，双跑（plain + heaptrc），0 unfreed 硬门
make focused FOCUS=core/tests/nextpas.core.webview/examples/demo_webview
```

`core/tests/nextpas.core.webview/examples/demo_webview_respack` 是
CONTRACT §3.4 推荐的 respack 集成路径示例：同一份前端资源在
`embedded (prod) → os (dev) → http dev-server` 三形态间切换，演示
`IVfs → IWebviewAssetProvider` 适配与 `DevServerUrl` 开发模式：

```bash
make -C core/tests/nextpas.core.webview/examples/demo_webview_respack run           # prod：pack blob 零拷贝
make -C core/tests/nextpas.core.webview/examples/demo_webview_respack run-dev       # dev：wwwroot 热重载
make -C core/tests/nextpas.core.webview/examples/demo_webview_respack run-dev-server # dev-server：http 直连（惰性资产）
```

两演示在无 GTK 环境时均打印 `demo-skip no-gtk-backend` 优雅通过。

## 使用示例

可运行版本见演示；以下为门面最简形态（与 CONTRACT §2-§3 一致）：

```pascal
uses
  nextpas.core.webview;

type
  TDemo = class
  public
    function OnPing(const APayloadJson: string): string;
    procedure OnReady;
  end;

function TDemo.OnPing(const APayloadJson: string): string;
begin
  Result := '{"pong":true}';
end;

procedure TDemo.OnReady;
begin
  // 桥就绪：可以开始 Emit 事件
end;

var
  LDemo: TDemo;
  LWin: IWebviewWindow;
begin
  LDemo := TDemo.Create;
  try
    // Builder 链式构造 + 构造期导航（InitialUrl 优先于 InitialHtml）
    // Dev 模式：再加 .DevServerUrl('http://127.0.0.1:5173')
    LWin := TWebviewBuilder.New
      .Title('Demo')
      .Size(1200, 800)
      .DebugTools(True)
      .InitialUrl('npres://app/index.html')
      // .InitialHtml('<h1>hi</h1>') // 二选一
      .RegisterInvoke('ping', @LDemo.OnPing)
      .OnReady(@LDemo.OnReady)
      .Build;
    LWin.Assets.MountEmbedded('', TMyRespackProvider.Create);
    LWin.Show;
    WebviewRunLoop;
    LWin := nil;
  finally
    LDemo.Free;
  end;
end.
```

`TWebviewBuilder` 全链路（见 CONTRACT §2.2 与 factory 单元）：

| 方法 | 作用 |
|------|------|
| `Title/Size/MinSize/MaxSize/Resizable/StartMaximized` | 窗口几何与状态 |
| `DebugTools/Scheme/DataDirectory/Ephemeral` | 引擎会话与 scheme |
| `AddInitScript` | document-start 注入（不得触 __npw） |
| `InitialUrl/InitialHtml` | 构造期导航（Url 优先） |
| `DevServerUrl` | 开发模式：资产惰性、scheme 惰注册 |
| `RegisterInvoke/RegisterAsyncInvoke/OnReady/Kind` | IPC 与后端选型 |
| `Build` | 创建窗口（多窗共享同一主循环） |
| `Run(url)/RunHtml(html)` | 单窗便捷封装（Build+Navigate+RunLoop） |

respack 集成形态见 `demo_webview_respack` 与 `nextpas.core.webview.vfs`
（`IVfs → IWebviewAssetProvider` 唯一收口，CONTRACT §3.4）：

```pascal
uses nextpas.core.vfs, nextpas.core.webview.vfs;
LVfs := CreateEmbeddedVfs(@DEMO_ASSETS[0], DEMO_ASSETS_SIZE, False);
LProvider := CreateVfsAssetProvider(LVfs); // 前缀容错双试 + MIME 共享快表（webview.mime）
LWin.Assets.MountEmbedded('', LProvider);
```

性能基线（`core/benchmarks/nextpas.core.webview/bench_vfs`，`nextpas.core.bench` 框架，过滤均值 1.22 GB/s 级，S27 实测）：

| 场景 | ns/op (过滤均值) | ops/s | 吞吐 |
|------|-------|-------|------|
| SmallHit/index.html | 681 ns | 1.47M | 199 MB/s |
| Fallback/app/index.html | 894 ns | 1.12M | 213 MB/s |
| Miss404 | 217 ns | 4.60M | 123 MB/s |
| LargeHit/1M | 800 µs | 1.25k | 1.22 GB/s |

桥协议基线（`core/benchmarks/nextpas.core.webview/bench_bridge`，过滤均值，S27 实测）：

| 场景 | ns/op | ops/s | 备注 |
|------|-------|-------|------|
| TryDecodeFrame | 4.18 µs | 239k | JSON 解析 + 校验 + 规范化 |
| BuildResolveScript | 622 ns | 1.61M | JsStringLit + 拼接 |
| BuildRejectScript | 2.37 µs | 422k | 错误码归一 + 对象构造 |
| BuildEmitScript | 1.06 µs | 943k | 事件名校验 + 双 Json |

前端侧（协议细节见 BRIDGE_PROTOCOL.md）：

```js
await window.__npw.ready;                       // 消除注入竞态
const result = await window.__npw.invoke('ping', { hello: 'world' });
window.__npw.listen('tick', (payload) => { /* native → js 事件 */ });
```

## 设计红线（继承自 fafafa.webview 的教训）

1. **eval 一律异步回调**，禁止提供同步语义及任何消息泵/忙轮询伪造。
2. **所有用户回调统一在 UI 主线程触发**；应用侧跨线程投递只走
   `IWebviewDispatcher.Post`。契约明列的例外仅两处：`Close` 与 invoke
   completion 的 `Ok/Fail` 可跨线程调用（内部 marshal，CONTRACT §4.4）。
3. **handler 错误走异常**，桥负责转成协议 reject；禁止 `(out Ok; out Result)` 三态签名。
4. **桥协议全后端唯一一份实现**（`webview.bridge`），后端只是薄 transport；
   禁止每后端各解析各的帧。
5. **`base`/`intf` 禁止 uses 任何后端单元**；后端经工厂注册进入。
6. **Deferred 能力不留占位**：登记簿里每一项都有触发条件，触发前接口不预埋
   （fafafa 死代码调度器的教训）。
