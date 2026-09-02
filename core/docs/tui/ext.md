# nextpas.core.tui.ext — 扩展 Widget / App 编排域契约

**模块**：`nextpas.core.tui.ext.{base,intf,pas}` 四件套（聚合 `panel`/`scrollview`/`modal`/`dialog`/`split`/`select` + `app`/`screen`/`task`/`focus`/`keybind`/`frame_budget`）
**层级**：L3 tui（依赖 `sync` + `thread.pool`）
**四件套**：`ext.base` ← `ext.intf` ← `ext` 门面；实现聚合 app/runtime + 6 扩展控件
**依赖**：L0–L2 only（`bytes.ops` 单源 + `sync`/`async`）
**对应主契约**：`CONTRACT.md` §1.3 ext/full 分层 + §4 线程安全 + §5.6 Enter 诊断
**门禁**：`TApp.Destroy` + `TTaskManager` 同步收尾不留线程（`heaptrc 0` + `ThreadingAlreadyUsed` 确定性失败）

## 职责

- 扩展控件：`Panel` + `ScrollView` + `Modal` + `Dialog` + `SplitPane` + `Select` + `Gauge`/`Sparkline`/`Canvas`（PH33 解禁）
- App 编排：`TApp`/`TScreenStack`/`TTaskManager`/`TFocusManager`/`TKeybind`/`TFrameBudget`/`TAnimator`
- `app.screen`/`app.task` 闭包任务（`thread.init` 首位契约，C11 门禁）

## 性能

- 复用 `bytes.ops` 单源（文本/布局零拷贝）
- 热点 `inline`：`focus`/`keybind` 判定 + `FrameBudget` tick
- `Sync` 原语跨线程投递事件队列（`async.channel`），不阻塞 UI 线程

## 稳定性

- `TApp.Destroy` 幂等：`LeaveTui` + `TTaskManager` drain + `heaptrc 0`
- 闭包任务 miss `thread.init` 时 `runerror 211` 确定性失败（非 segfault）

## Owner 边界

- 缺能力先反哺 `sync`/`bytes.ops`/`platform.signal`/`mem`，不绕 `platform.console`
