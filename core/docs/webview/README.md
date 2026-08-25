# nextpas.core.webview

**状态**: **Design**（S0 文档阶段；尚无源码家族）
**层级**: L3 家族（依赖 L0-L2）
**目标形态**: Tauri / Wails 式桌面应用外壳——系统自带浏览器引擎 + 原生窗口壳 + 统一 IPC 桥，
接口抽象在前、后端实现在后。

## 模块定位

`nextpas.core.webview` 为桌面 GUI 应用提供"宿主窗口内嵌浏览器引擎"的最小完整抽象：

- **窗口壳**：标题、尺寸、resize、close 等最小原生窗口操作（模块自己拥有窗口）。
- **内容承载**：导航到 URL / HTML 字符串；通过自定义 URL scheme 提供内嵌资源；
  开发模式可直连 dev server。
- **双向 IPC**：前端 `invoke(cmd, payload) → Promise`，Pascal 侧注册命名 handler；
  Pascal → 前端事件 `Emit`。
- **异步 eval**：向页面执行 JavaScript 并异步取回结果。不提供同步 eval（设计红线，
  见 [CONTRACT.md](CONTRACT.md) 的线程模型章节）。

引擎一律使用系统安装的浏览器引擎（WebKitGTK / WebView2 / WKWebView），
不捆绑、不改写引擎本身。

## 后端矩阵

| 后端 | 平台 | 引擎 | 绑定方式 | 波次 |
|------|------|------|----------|------|
| `gtk` | Linux | WebKitGTK 4.1（探测降级 4.0） | 运行时 dlopen，自声明 ABI | **Wave 1** |
| `fake` | 全平台（无头） | 无引擎，脚本化驱动 | 纯 Pascal | **Wave 1**（测试支撑） |
| `webview2` | Windows | Microsoft WebView2 (Edge) | COM 头移植 + WebView2Loader.dll 动态加载 | Wave 2 |
| `wk` | macOS | WKWebView | ObjC runtime / objcclass（待编译器能力确认） | Wave 3 |

平台能力差异以"语义诚实表"记录在 [CONTRACT.md](CONTRACT.md)，不做跨平台假装。

## 文档导航

| 文档 | 内容 |
|------|------|
| [CONTRACT.md](CONTRACT.md) | 代码契约：单元布局、依赖方向、核心类型与接口签名、线程模型、错误分类、不变量、测试门禁 |
| [BRIDGE_PROTOCOL.md](BRIDGE_PROTOCOL.md) | IPC 注入桥协议 v1 完整规范（帧格式、握手时序、错误码表） |
| [BACKENDS.md](BACKENDS.md) | 各后端绑定策略、版本矩阵、fafafa.webview 资产移植清单 |

活动计划见 `core/docs/plans/2026-08-25-webview-module.md`（slice 划分、验证与 landing 约定）。

## 使用示例（目标形态示意）

> 以下为设计目标 API 形状，Wave 1 实现完成后以 CONTRACT.md 为准更新。

```pascal
uses
  nextpas.core.webview;

begin
  TWebviewBuilder.New
    .Title('Demo')
    .Size(1200, 800)
    .DebugTools(True)
    .RegisterInvoke('ping',
      procedure(const APayloadJson: string): string
      begin
        Result := '{"pong":true}';
      end)
    .OnReady(procedure begin end)
    .Run('npres://app/index.html');   // 或 .NavigateToString('<h1>hi</h1>')
end.
```

前端侧（协议细节见 BRIDGE_PROTOCOL.md）：

```js
const result = await window.__npw.invoke('ping', { hello: 'world' });
window.__npw.listen('tick', (payload) => { /* native → js 事件 */ });
```

## 设计红线（继承自 fafafa.webview 的教训）

1. **eval 一律异步回调**，禁止提供同步语义及任何消息泵/忙轮询伪造。
2. **所有用户回调统一在 UI 主线程触发**；跨线程投递只经各后端的
   `IWebviewDispatcher.Post`。
3. **handler 错误走异常**，桥负责转成协议 reject；禁止 `(out Ok; out Result)` 三态签名。
4. **桥协议全后端唯一一份实现**（`webview.bridge`），后端只是薄 transport；
   禁止每后端各解析各的帧。
5. **`base`/`intf` 禁止 uses 任何后端单元**；后端经工厂注册进入。
