# RTL 解耦与可抽取新模块完整规划 (2026-08-28)

> Owner: nextpas.core.window lane · worktree `.worktrees/core-gtk` branch `codex/core-gtk`
> 目标: 彻底消除 `nextpas.core.*` 对 FPC RTL (`SysUtils`/`Math`/`TypInfo`/`Classes`) 的直引，改为经 `nextpas.core` 反哺；同时识别项目内可抽取为新 `nextpas.core` 模块的复用代码，完成实现-迁移-验证闭环。

## 1. 现状与问题

- 已完成 window 首切片：`window.base` 去 `SysUtils`，`window.gtk.impl.inc` `Math→math`，`window.factory` `SysUtils/TypInfo→system.sysutils/system.typinfo`，6 个后端清理未用 `SysUtils`，新增 `INV-RTL` 门禁并通过。
- 仍存在大规模 `PAnsiChar(AnsiString(...))` 直铸（121 处，覆盖 `db`/`tls`/`window`/`platform` 等）与 `Format/BoolToStr` 经 `system.sysutils` 的间接依赖；`audio.*` 仍直引 `Math`，`gtk.impl.inc` 标题仍裸铸。
- 成因：此前 `text.ansi` / `diagnostics` 等 L1 能力未抽取，导致 L2 只能直引或重复样板。

## 2. 原则

- **唯一目标**：`nextpas.core.*` 不提供 FPC 兼容层；`uses SysUtils/Math/TypInfo/Classes` 仅出现在 `nextpas.core.system.*` 与 `nextpas.core.math.*` 等 owner 内，其余一律经 owner 委派。
- **反哺优先**：不满足时补 `nextpas.core` 能力，而非加 `{$IFDEF}` 分叉或裸直引。
- **四件套与分层**：新模块遵循 `base←intf←impl←门面` 单向依赖，L1 仅依赖 L0，L2 可依赖 L0-L1。
- **门禁先行**：所有迁移由 `check_window_source_contracts.sh` 的 `INV-RTL` 拦住，未绿不落地。

## 3. 新模块抽取 (P0/P1)

### P0 — `nextpas.core.text.ansi` (L1)

- **痛点**：`PAnsiChar(AnsiString(s))` 在 `db.pg/sqlite/mysql/odbc`、`tls.*`、`window.gtk/sdl2/win32`、`platform.dl` 等 30+ 单元重复；裸铸在托管记录返回场景会破坏临时管理（`db` 实证）。
- **职责**：FFI 边界 Ansi 互转统一入口，提供：
  - `function StrToAnsi(const S: string): AnsiString; inline`
  - `function AnsiToStr(const A: AnsiString): string; inline`
  - `function AnsiPtrToStr(const P: PAnsiChar): string;`（复用 `text.conv` 语义，nil 安全）
  - `function HoldAnsi(const S: string; out Hold: AnsiString): PAnsiChar; inline` — 将 `string→AnsiString` 的 Hold 显式化，替代裸 `PAnsiChar(AnsiString(...))`。
  - `function StrToPAnsi(const S: string; out Hold: AnsiString): PAnsiChar; inline` 别名。
- **依赖**：仅 `base`，无 `SysUtils`。
- **迁移首批**：`window.gtk.impl.inc` 标题、`window.sdl2/win32/wasm`、`audio` 暂不涉但为后续 FFI 统一做准备。
- **门面**：`nextpas.core.text` 重导出 `AnsiToStr/StrToAnsi`（可选），保持兼容。

### P0 — `nextpas.core.diagnostics` (L1)

- **痛点**：`WindowBackendDiagnostics` 手写 `Format`+`BoolToStr`+`LineEnding` 拼接，`ProbeGtk4/3/2` 等探针重复；同类“后端可用性诊断”在 `tls`/`db` 亦有潜在复用。
- **职责**：轻量诊断构建器，不依赖 `SysUtils`：
  - `type TDiagnosticsBuilder = record` with `Add(const AName: string; AAvailable: Boolean; const ADetail: string)`; `AddProbe(...)`; `Build: string`。
  - 内部经 `nextpas.core.text.format` 与 `text.utils.BoolToStr` 组合，不触 `SysUtils.Format`。
- **依赖**：`base` + `text.format` + `text.utils`，L1。
- **迁移首批**：`window.factory.WindowBackendDiagnostics` 全量改用 builder，消除对 `system.sysutils.Format/BoolToStr` 的直接依赖（仍间接经 text）。

### P1 — `nextpas.core.reflect.enum` 增强 (L1/L2)

- **现状**：`factory` 通过 `nextpas.core.system.typinfo.GetEnumName(TypeInfo(TWindowKind))` 拿名，已合规但语义绕经 `system`。
- **方案**：短期保留 `system.typinfo` 路径；中长期在 `reflect` 增 `EnumName<T>` 泛化，window 届时迁移。本期仅文档化，不卡 P0。

### P1 — audio/Math 回流 (已覆盖)

- `audio.mix/game/timeline/resample.sinc/codec.aiff/dsp.*` 直引 `Math` → 改 `nextpas.core.math`（`Pi/Cos/Sin/Sqrt/Abs` 均有）。本期 P0 完成后以 `audio.mix` 为样板落地，其余同批。

## 4. 迁移路线

1. **实现** `text.ansi.pas` + `diagnostics.pas(+base)`，补 `text` 门面转发，注册到 `core-module-registry.md`。
2. **迁移 window**：
   - `gtk.impl.inc`：`PAnsiChar(AnsiString(FTitle/ATitle))` → `HoldAnsi`/`StrToAnsi` 经 `text.ansi`。
   - `factory`：`WindowBackendDiagnostics` → `TDiagnosticsBuilder`，`Format/BoolToStr/GetEnumName` 均经 `diagnostics`/`text`/`system.typinfo`，不再直引 `SysUtils`。
   - `sdl2/win32/wasm` 标题同理（随 window 族一并）。
3. **迁移 audio**：`audio.mix` 为首，`uses Math → nextpas.core.math`，`Sqrt/Pi/Cos/Sin` 验证等价。
4. **门禁**：扩展 `check_window_source_contracts.sh` 覆盖 `text.ansi`/`diagnostics` 前缀豁免；`window-source-contracts=pass` 为硬门槛。
5. **文档**：`CONTRACT.md` `§1 家族布局` 增 `text.ansi/diagnostics`，`ARCHITECTURE.md` §2.2 增 RTL 解耦说明，`README` window 能力行补充诊断构建器来源。

## 5. 验证

- `make hygiene`（无 `core/src/*.o|ppu` 散落）
- `make focused FOCUS=core/tests/nextpas.core.window/test_window_source_contracts`（INV-3/4/5/RTL 均 pass）
- `make focused FOCUS=core/tests/nextpas.core.window/test_window_factory`（13 prints 0 leaks）
- `make focused FOCUS=core/tests/nextpas.core.window/test_window_gtk_runtime`（3 prints 0 leaks，無 GTK 时跳过）
- `bench_dispatcher` (`bench nextpas.core.window.dispatcher`) PostSingle ~380µs / ZeroPump ~170µs 无回归
- `audio` 抽样：`make focused FOCUS=core/tests/nextpas.core.audio/test_audio_mix`（若存在）或 `fpc -Mobjfpc -Sh core/src/nextpas.core.audio.mix.pas` 编译通过

## 6. 风险与回退

- `PAnsiChar` Hold 生命周期：`HoldAnsi` 显式 `out AnsiString` 保证 FFI 调用期间存活，避免裸临时被优化掉。
- `diagnostics` 不引入 `SysUtils.Format` 全量 printf，仅支持 `diagnostics` 需要的 `%s` 子集，经 `text.format.TextFormat` 已覆盖。
- 回退：任一门禁红则 `git checkout -- <file>` 回退薄包装，保持 `c905c7679` 可编译基线。
