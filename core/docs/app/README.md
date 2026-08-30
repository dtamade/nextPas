# nextpas.core.app — 应用壳（Tauri App 级）

`nextpas.core.app` 是 L3 应用编排层：在 `nextpas.core.webview`（wry）之上提供 Tauri/Wails 心智的 `App / AppBuilder`。

## 定位

- **webview 已达 wry 水位**：`IWebviewWindow` 13 方法 + bridge v1 + `npres://` VFS + 多后端（Gtk/WebView2/Wk/Fake）`CONTRACT 1.93`
- **app 补 Tauri App 水位**：应用持有窗口集合与主循环；`Builder → App → Window` 三层与 `tauri::Builder` 对齐
- **薄封装**：所有校验/分发复用 `webview.base/factory` 单源，不产生重复逻辑

## P1 范围

- `TAppBuilder.New.Title().Size().Build` 单窗 + `Run/RunHtml` 便捷
- `IApp.MainWindow / NewWindowBuilder / Run / Quit / Close` 生命周期
- `Kind(wvFake)` 钉测试确定性；缺省 `DefaultAppKind` 能力探测驱动
- 多窗经 `NewWindowBuilder` 再 `Build` 独立窗口，共享同一 `WebviewRunLoop`

P2 预留：多窗计数、托盘/菜单、ACL、CLI/respack 集成（见 ROADMAP）

## 快速开始

```pascal
uses nextpas.core.app;

TAppBuilder.New
  .Title('My App')
  .Size(1040, 700)
  .RegisterInvoke('ping', function(const P: string): string begin Result:='{"pong":true}'; end)
  .RunHtml('<h1>Hello</h1>');
```

多窗：

```pascal
var App: IApp; W2: IWebviewWindow;
App := TAppBuilder.New.Title('Hub').Build;
W2 := App.NewWindowBuilder.Title('Second').Build;
App.Run; // 阻塞至所有窗口关闭或 App.Quit
```
