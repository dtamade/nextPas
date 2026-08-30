# nextpas.core.app 契约 P1

**模块路径**：`core/src/nextpas.core.app*.pas`  
**层级**：L3（依赖 L0-L3 webview）  
**Owner**：core-app lane  
**版本**：0.1（P1 单窗封装；复用 webview 1.93）

## 家族

- `nextpas.core.app.base` 类型根（`TAppOptions = TWebviewOptions` 别名，`EAppError` 族）
- `nextpas.core.app.intf` `IApp / IAppBuilder`
- `nextpas.core.app.factory` Builder/App 实现（薄转发 webview.factory）
- `nextpas.core.app` 门面

## 不变量

- `CheckAppOptions` = `CheckWebviewOptions` 单源
- `DefaultAppKind` = `DefaultWebviewKind` 能力探测驱动
- `IApp.Close` 幂等；`IsClosed` 后除 `IsClosed/MainWindow` 外行为与 webview 一致
- `Run` 阻塞至所有窗口关闭或 `Quit`（`WebviewExitLoop`）

## Deferred

- 多窗计数精确、托盘/菜单、窗口事件聚合、ACL 均 P2+
