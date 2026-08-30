# nextpas.core.app 契约 P3

**模块路径**：`core/src/nextpas.core.app*.pas`
**层级**：L3（依赖 L0-L3 webview）
**Owner**：core-app lane
**版本**：0.3（P3 自动摘除 + OnWindowClosed 聚合 + GetWindows 快照；复用 webview 1.93，heaptrc 0）

## 家族

- `nextpas.core.app.base` 类型根（`TAppOptions = TWebviewOptions` 别名，`EAppError` 族）
- `nextpas.core.app.intf` `IApp / IAppBuilder`（P3：`WindowCount/GetWindow/GetWindows/AddWindow/RemoveWindow/NewWindow` + `Mount*` + `OnWindowClosed×3` + `TAppWindows`）
- `nextpas.core.app.factory` Builder/App 实现（`WebviewGrowCapacity` 复用、`FWindows/FMounts/FOnClosed*` 零重复，`ApplyMounts` 单源，`HandleAnyWindowClosed` 自动摘除）
- `nextpas.core.app` 门面（纯 re-export）

## 不变量

- `CheckAppOptions` = `CheckWebviewOptions` 单源；`DefaultAppKind` = `DefaultWebviewKind` 能力探测驱动
- `IApp` 持有窗口列表 `FWindows[0..FCount)`（`WebviewGrowCapacity(0→4→2×)` 单源），`WindowCount` 调用 `CompactClosed` 惰性回收已关窗后返回存活数；`GetWindow/GetWindows` 先 `Compact` 再边界/快照，保证不返回已关窗
- `AddWindow` 要求 open 且未在列表；`RemoveWindow` 线性摘除并 `FireWindowClosed`；`HookWindowClose` 以 `reference` 闭包弱持有 `Self`（`procedure begin HandleAnyWindowClosed; end`）注册到 `IWebviewWindow.OnWindowClosed`，`HandleAnyWindowClosed` 扫描 `IsClosed` 线性摘除并逐一 `Fire`，零强循环；`Close` 快照后关闭，幂等
- `OnWindowClosed` 三态：`reference/method/proc` 分三数组无包装直存，`FireWindowClosed` 按序触发 `try/except` 隔离
- `IAppBuilder.MountEmbedded/MountDirectory` 聚合至 `ApplyMounts`，`Build` 时批量挂载到首窗 `Assets`（与 `Assets.Mount*` 同语义，`npres://` 最长前缀唯一命中）
- `Run` 阻塞至所有窗口关闭或 `Quit`（`WebviewRunLoop/ExitLoop` 薄转发）；稳定性：`FireNotifyHandlers` 在 gtk/webview2 侧增 `Assigned` 守卫，跳过未初始化槽位

## P3 能力

- 自动摘除：`W.Close` 触发 `HandleAnyWindowClosed` 即时摘除并触发 `App.OnWindowClosed`；`WindowCount/GetWindow/GetWindows` 惰性 `CompactClosed`，`GetWindows` 返回存活快照（`TAppWindows`）
- 事件聚合：`IApp.OnWindowClosed` 聚合所有窗口关闭事件，`test_app_factory` 9 用例覆盖（含弱摘除快照与事件 1→2 次触发）
- 示例：`demo_app --selftest` 单窗 eval 矩阵 + `demo_app` 非自检双窗 `AddWindow` 多窗计数

## Deferred

- 托盘/菜单、窗口事件更细聚合、ACL 均 P4+
