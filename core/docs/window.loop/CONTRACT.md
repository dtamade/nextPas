# nextpas.core.window.loop 代码契约

**模块路径**：`core/src/nextpas.core.window.loop*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.loop`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.loop` 行；依赖 L0-L1 + `async` L1 + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.loop`（core-window lane；`base` 仅纯数据类型，`impl` 单源校验/扩容，所有权收口至本模块 `impl` direct `bytes.ops`）
**Public facade**：yes（`nextpas.core.window.loop` 门面纯 re-export + inline 转发，四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`（四件套齐、L0-L3 与 INV-3 零后端纪律、单源 `bytes.ops` 已落地，见 registry）
**最后更新**：2026-09-02（独立文档归属修复：12.5 `docs/<module>/CONTRACT.md`，原仅复用 `docs/window/CONTRACT.md:41`）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-10` 为家族总览，本文件为 `window.loop` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops`/`async` owner）

---

## 1. 模块定位

`window.loop` 承载 INV-10 事件循环融合（`IterateOnce` → `IWindowLoop` 融合 `TAsyncLoop`），为 `game/directui` tick 循环提供 `Tick/RequestExit` 幂等非阻塞泵。独立 L2 公共模块（`Public facade=yes`），不经 `nextpas.core.window` 门面 re-export；`impl` 直连 `bytes.ops` direct, 不经父 `window.impl` 跨 Owner 耦合，守 L0-L3 L2→L1 单源。

```
L0 base/errors ──► L1 bytes/async ──► L2 window.loop（本模块）
                                    ▲
                                    │ 单源复用 bytes.ops WindowLoopGrowCapacity 0→32→2×
```

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.loop.base` | `TWindowLoopOptions` / `TWindowLoopTickResult` / `EWindowLoopError` 纯数据类型，零行为 |
| `nextpas.core.window.loop.intf` | `IWindowLoop` / `TWindowLoopTickHandler/Method/Proc` 接口与回调命名类型 |
| `nextpas.core.window.loop.impl` | `CheckWindowLoopOptions` 校验 + `WindowLoopGrowCapacity` 单源转发 `bytes.ops` direct (no `window.impl`) |
| `nextpas.core.window.loop` | 门面：纯 re-export + `inline` 转发（`DefaultWindowLoopOptions`/`CheckWindowLoopOptions`/`WindowLoopGrowCapacity`） |

依赖方向 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端（INV-3），`impl` 仅 `uses base/intf + bytes.ops` direct, 禁 `window.impl` 跨 Owner。

---

## 3. 核心类型（base）

```pascal
TWindowLoopOptions = record
  TickIntervalMs: Integer; // >=0，默认 16ms
  PumpBudget: Integer;     // >=0，默认 0（不限）
end;
TWindowLoopTickResult = (wltrIdle, wltrWork, wltrClosed);
function DefaultWindowLoopOptions: TWindowLoopOptions; inline;

EWindowLoopError = class(ENextPasError); // ecInternal
EWindowLoopInvalidOptions = class(EWindowLoopError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowLoop = interface
  ['{A1B2C3D4-1001-4F60-9A8B-C0D1E2F3A100}']
  function Tick: TWindowLoopTickResult;
  function IsRunning: Boolean;
  procedure RequestExit;
  function GetOptions: TWindowLoopOptions;
  procedure SetOptions(const AOptions: TWindowLoopOptions);
  property Options: TWindowLoopOptions read GetOptions write SetOptions;
end;
TWindowLoopTickHandler = reference to procedure(const AResult: TWindowLoopTickResult);
TWindowLoopTickMethod = procedure(const AResult: TWindowLoopTickResult) of object;
TWindowLoopTickProc = procedure(const AResult: TWindowLoopTickResult);
```

`Tick`/`RequestExit` 幂等；与 `async` L1 协作，不直接 `uses TAsyncLoop`（接口隔离，业务组合在上层）。

---

## 5. 实现契约（impl）

- `CheckWindowLoopOptions`：校验 `TickIntervalMs>=0`、`PumpBudget>=0`，违例抛 `EWindowLoopInvalidOptions`（`CreateFmt` 富信息），`inline` 薄分支。
- `WindowLoopGrowCapacity(ACurrent: Integer/SizeUInt): Integer/SizeUInt; inline`：单重载单源 `Result := BytesGrowCapacity(ACurrent)`（`nextpas.core.bytes.ops` `0→32→2×` 幂二，`inline` 零额外调用，O(1) 均摊）；门面同签名 `inline` 转发，不分叉实现，守 `bytes.ops` 单源。
- 零拷贝：扩容计算纯算术，不涉及 `Move`；调用方缓冲增长经 `bytes.ops` 单源路径。

---

## 6. 不变量

- **INV-10**（本模块）：事件循环融合最小闭包，不污染 `window` 核心；`Tick` 单步非阻塞，可与 `async` 协作。
- **INV-3**：`base/intf` 不出现 `window.<backend>*`/`fake`/`factory`。
- 单源：`WindowLoopGrowCapacity` 唯一源 `bytes.ops.BytesGrowCapacity`，门面与 `impl` 均为 `inline` 转发（source-contract 可扫描）。

---

## 7. 性能

- `WindowLoopGrowCapacity`：`inline` 单次 `BytesGrowCapacity` 调用，`0→32→2×` 幂二增长，O(1) 均摊，零堆分配（仅返回容量值）；冷路径 `CheckWindowLoopOptions` 为 `inline` 薄分支，不膨胀 I-Cache。
- 证据：`core/src/nextpas.core.window.loop.impl.pas:20-28` 显式 `inline` + 单源转发 `BytesGrowCapacity` direct (no `window.impl`); `core/src/nextpas.core.window.loop.pas:39-47` 门面 `inline` 转发（`bytes.ops` direct L2→L1, 解耦父 `window.impl`）。

---

## 8. 稳定性

- 资源释放不丢：本模块无堆分配/句柄；校验失败抛异常由调用方边界统一捕获，`Tick`/`RequestExit` 幂等不泄漏；`heaptrc 0`（`make -C core/tests/nextpas.core.window clean test` 家族门禁，虚分配零残留）。
- 异常：仅校验抛 `EWindowLoopInvalidOptions`，其余路径无异常；线程模型复用 `window` 家族（`Tick` UI 线程亲和，跨线程仅经 `Dispatcher.Post`）。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `tests/nextpas.core.window/test_window_source_contracts` | INV-3 零后端、门面 `inline` 单源、allowed-uses 白名单 |
| 契约测试 | `tests/nextpas.core.window/test_*`（fake） | `CheckWindowLoopOptions` 边界、无效选项抛错、GrowCapacity 单源往返 |
| heaptrc | `heaptrc 0` | 无泄漏 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 `docs/<module>/CONTRACT.md` 归属；四件套与 L0-L3/单源/性能/稳定性收口 |
