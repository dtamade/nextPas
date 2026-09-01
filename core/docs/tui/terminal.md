# nextpas.core.tui.terminal — 终端/后端/输入域契约

**模块**：`nextpas.core.tui.terminal.{base,intf,pas}` 四件套（已落地；独立子家族，不寄居主包）
**层级**：L3 tui（`platform.console/signal/time` owner 反哺）
**四件套**：`terminal.base` ← `terminal.intf` ← `terminal` 门面；实现聚合 `terminal` + `backend.ansi` + `input` + `ansi.parse` + `cap.base`
**依赖**：L0–L2 only（`bytes.ops` 单源 + `platform.console/signal/time/env`）
**对应主契约**：`CONTRACT.md` §1.1 Terminal/runtime truth + §5.1–5.6 DECSET + §4 线程安全
**门禁**：`heaptrc 0`（`EnterTui`/`LeaveTui` 配对 + `Destroy` 幂等释放）

## 职责

- `TTerminal`：双缓冲 `prev/curr/merged/overlay` + `TAnsiBackend` + 输入队列 + termios/raw 状态 + 信号 `SIGWINCH`/`SIGTERM`
- 帧生命周期：`BeginFrame` → 渲染 → `EndFrame`（`Diff` + `DrawPatches` + `Swap`）
- Capability 协商：`Truecolor` env-attested + `KittyKeyboard` `CSI = 5 ; 1 u` push / `CSI ? u` query (`TryParseKittyKeyboardFlagsReply`) + `ImageProtocol`
- DECSET 会话：`1004` focus (`CSI I/O`) + `2004` bracketed paste (`CSI 200~/201~` → `evPaste`) + `2026` synchronized update + `7` DECAWM (`CSI ? 7 l/h`)
- `EnterTui: Boolean` 兼容 + `TryEnterTui: TTuiEnterResult`（`not-a-terminal`/`set-raw-failed`/`session-setup-failed`）+ `LastEnterResult`

## 性能

- 复用 `bytes.ops` 单源（ANSI 转义 `Encode` 零分配，`TByteSpan` 视图）
- 热点 `inline`：`TerminalNeedsMouseTracking`/`TerminalAnsiEscSpan`（`terminal.base`）+ `GetHasTruecolor`/`GetHasKittyKeyboard` + `EffectiveMouseMode`/`RequestsMouseTracking`
- 零拷贝 `TByteSpan` cell/ANSI 视图（`BytesCopy` 单源 Move，不复制尾巴）

## 稳定性

- `DoLeaveTui` 幂等+异常安全：`LeaveAlternate` + `ShowCursor` + `RestoreRaw` + `UnhookSignal`，任一步失败继续释放
- `EnterTui` 失败路径 `LeaveTui` 回滚 + `LastEnterResult` 诊断，`Destroy` 兜底 `DoLeaveTui`
- `IAllocator` 下传 `prev/curr/merged/overlay` + `TAnsiBackend`（`InitWith`），生命周期 ⊆ allocator

## Owner 边界

- 缺能力先反哺 `text.width`/`bytes.ops`（ANSI/width）/`platform.console`/`platform.signal`/`platform.time`/`platform.env`，不绕 OS 单元
- 平台能力：`platform_console_is_terminal`/`platform_console_set_raw`/`platform_signal_set`/`platform_monotonic_ns` 为唯一来源

## 四件套落地证据

- `terminal.base`：基础类型/常量 + `inline` `TerminalNeedsMouseTracking`/`TerminalAnsiEscSpan`（`TByteSpan` 零拷贝 + `bytes.ops` 单源）
- `terminal.intf`：`ITerminal` 接口契约（`BeginFrame`/`EndFrame`/`PollEvent`），不持有实现
- `terminal`：`TTerminal` 实现（`EnterTui`/`LeaveTui`/`PollEvent`/`HasPendingImageTransmit`），依赖 `base←intf`
- 门面：`nextpas.core.tui.terminal` re-export（`terminal.base`/`terminal.intf`/`terminal` 聚合），消费者按需 `uses`
