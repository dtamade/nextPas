# nextpas.core.app — 应用壳（Tauri App 级）

`nextpas.core.app` 是 L3 应用编排层：在 `nextpas.core.webview`（wry）之上提供 Tauri/Wails 心智的 `App / AppBuilder`。

## 定位

- **webview 已达 wry 水位**：`IWebviewWindow` 13 方法 + bridge v1 + `npres://` VFS + 多后端（Gtk/WebView2/Wk/Fake）`CONTRACT 1.93`
- **app 补 Tauri App 水位**：应用持有窗口集合与主循环；`Builder → App → Window` 三层与 `tauri::Builder` 对齐
- **薄封装**：所有校验/分发复用 `webview.base/factory` 单源，不产生重复逻辑

## P3 能力（0.3）

- `TAppBuilder.New.Title().Size()...MountEmbedded/MountDirectory...Build` 首窗聚合资产挂载（`npres://` 最长前缀唯一命中）
- `IApp.MainWindow / WindowCount / GetWindow / GetWindows / NewWindowBuilder / NewWindow / AddWindow / RemoveWindow / OnWindowClosed×3 / Run / Quit / Close` 自动摘除（`HandleAnyWindowClosed` 弱闭包 + `CompactClosed` 惰性回收，快照不含已关窗）
- `Kind(wvFake)` 钉测试确定性；缺省 `DefaultAppKind` 能力探测驱动；多窗经 `AddWindow` 聚合，共享同一 `WebviewRunLoop`，`OnWindowClosed` 聚合所有窗口关闭事件
- 示例：`demo_app --selftest` 事件驱动矩阵 + 非自检双窗展示；`test_app_factory` 9/9 heaptrc 0

P4 预留：托盘/菜单、窗口事件更细聚合、ACL、CLI/respack 深度集成

## 快速开始

```pascal
uses nextpas.core.app;

TAppBuilder.New
  .Title('My App')
  .Size(1040, 700)
  .MountEmbedded('', MyProvider)          // 聚合挂载，Build 时批量落盘
  .RegisterInvoke('ping', function(const P: string): string begin Result:='{"pong":true}'; end)
  .RunHtml('<h1>Hello</h1>');
```

多窗（精确计数）：

```pascal
var App: IApp; W2, W3: IWebviewWindow;
App := TAppBuilder.New.Title('Hub').Build;               // Count=1
W2 := App.NewWindowBuilder.Title('Second').Build; App.AddWindow(W2); // Count=2
W3 := App.NewWindow.Title('Third').Build;   App.AddWindow(W3);      // Count=3
W2.Close; // Count→2（IsClosed 过滤）
App.Run;  // 阻塞至所有窗口关闭或 App.Quit
```
