# nextpas.core.app 契约 P2

**模块路径**：`core/src/nextpas.core.app*.pas`
**层级**：L3（依赖 L0-L3 webview）
**Owner**：core-app lane
**版本**：0.2（P2 多窗精确计数 + Builder 资产挂载；复用 webview 1.93，heaptrc 0）

## 家族

- `nextpas.core.app.base` 类型根（`TAppOptions = TWebviewOptions` 别名，`EAppError` 族）
- `nextpas.core.app.intf` `IApp / IAppBuilder`（P2：`WindowCount/GetWindow/AddWindow/RemoveWindow/NewWindow` + `MountEmbedded/MountDirectory`）
- `nextpas.core.app.factory` Builder/App 实现（`WebviewGrowCapacity` 复用、`FWindows/FMounts` 零重复，`ApplyMounts` 单源）
- `nextpas.core.app` 门面（纯 re-export）

## 不变量

- `CheckAppOptions` = `CheckWebviewOptions` 单源；`DefaultAppKind` = `DefaultWebviewKind` 能力探测驱动
- `IApp` 持有窗口列表 `FWindows[0..FCount)`（`WebviewGrowCapacity(0→4→2×)` 单源），`WindowCount` 为存活 `not IsClosed` 计数，`GetWindow` 边界抛 `EAppInvalidState`
- `AddWindow` 要求 open 且未在列表；`RemoveWindow` 线性摘除零空洞；`HookWindowClose` P2 为显式去钩（避免 `App↔Window↔closure` 强循环），`Close` 幂等遍历全部存活窗
- `IAppBuilder.MountEmbedded/MountDirectory` 聚合至 `ApplyMounts`，`Build` 时批量挂载到首窗 `Assets`（与 `Assets.Mount*` 同语义，`npres://` 最长前缀唯一命中）
- `Run` 阻塞至所有窗口关闭或 `Quit`（`WebviewRunLoop/ExitLoop` 薄转发）

## P2 能力

- 精确多窗：`NewWindowBuilder/NewWindow` 产独立 `IWebviewBuilder`，`AddWindow` 后 `WindowCount=1→N`，`W.Close` 后 `WindowCount` 即时回落（`IsClosed` 计数）
- 资产聚合：Builder 级挂载，零重复；已覆盖 `test_app_factory` 7 用例 + `demo_app --selftest` 事件驱动矩阵
- 示例：`demo_app` 单窗自检（eval 6*7 + sum 42）+ 非自检双窗展示 `AddWindow` 多窗计数

## Deferred

- `HookWindowClose` 自动摘除真弱引用（P3：`GWeakTable` 或 `platform.sync` 守卫）、托盘/菜单、窗口事件聚合句柄、ACL 均 P3+
