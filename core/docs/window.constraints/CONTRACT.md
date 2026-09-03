# nextpas.core.window.constraints 代码契约

**模块路径**：`core/src/nextpas.core.window.constraints*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.constraints`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.constraints` 行；依赖 L0-L1 + `window.base` + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.constraints`（core-window lane；`base` 仅纯数据，`impl` 单源校验/扩容 direct `bytes.ops`，window.impl 已去 L2→L2 薄转发本地校验守 L0-L3）
**Public facade**：yes（`nextpas.core.window.constraints` 门面纯 re-export + inline 转发，四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（INV-13 匠心修复：`window.impl` <50行保留核心抽离至独立四件套，守 800行分治阈值，单源 `bytes.ops` inline 零拷贝）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-13` 为家族总览，本文件为 `window.constraints` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops` owner）

---

## 1. 模块定位

`window.constraints` 承载 INV-13 运行期 SetMin/Max 最小闭包（`MinWidth/MinHeight/MaxWidth/MaxHeight` 约束校验与运行时修改），为 `window` 家族提供 `TWindowConstraints/IWindowConstraints` 最小闭包。独立 L2 公共模块，不经 `nextpas.core.window` 门面 re-export，约束诚实表不变量由本模块承载，window.impl 已去薄转发本地校验守 L0-L3。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.constraints.base` | `TWindowConstraints` / `EWindowConstraintsError` 纯数据类型，零行为，`DefaultWindowConstraints` inline 零拷贝 |
| `nextpas.core.window.constraints.intf` | `IWindowConstraints` 接口（`GetConstraints/SetConstraints/SetMinSize/SetMaxSize/Apply`） |
| `nextpas.core.window.constraints.impl` | `TWindowConstraintsImpl` 端到端载体 + `CheckWindowConstraints/CheckWindowConstraintsForOptions/ValidateWindowMinMax` + `WindowConstraintsGrowCapacity` 单源 `bytes.ops` + `CreateWindowConstraints` 工厂 |
| `nextpas.core.window.constraints` | 门面：纯 re-export `TWindowConstraints/IWindowConstraints/TWindowConstraintsImpl` + `inline` 转发校验/扩容/工厂 |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端；`impl` 仅依赖 `window.base` + `bytes.ops` direct L2→L1，不经 `window.impl` cross-Owner，`WindowConstraintsGrowCapacity` 单源 `bytes.ops 0→32→2×` inline 零拷贝 O(1)均摊。

---

## 3. 核心类型（base）

```pascal
TWindowConstraints = record
  MinWidth: Integer;  // 0 = 不设限制
  MinHeight: Integer;
  MaxWidth: Integer;  // 0 = 不设限制
  MaxHeight: Integer;
end;
function DefaultWindowConstraints: TWindowConstraints; inline; // 零值构造 inline

EWindowConstraintsError = class(ENextPasError); // ecInternal
EWindowConstraintInvalid = class(EWindowConstraintsError); // 校验失败
```

校验规则（与 `window.base.CheckWindowOptions` 同源，单源复用）：
- `Min/Max >=0`，`Max>0 且 Min>0 时 Max>=Min`，违例抛 `EWindowConstraintInvalid`；`inline` 薄分支 O(1) 零堆分配。

---

## 4. 接口契约（intf）

```pascal
IWindowConstraints = interface
  ['{C1D2E3F4-1003-4F60-9A8B-C0D1E2F3A103}']
  function GetConstraints: TWindowConstraints;
  procedure SetConstraints(const AConstraints: TWindowConstraints);
  procedure SetMinSize(AWidth, AHeight: Integer);
  procedure SetMaxSize(AWidth, AHeight: Integer);
  procedure Apply(const AConstraints: TWindowConstraints);
  property Constraints: TWindowConstraints read GetConstraints write SetConstraints;
end;
```

---

## 5. 实现契约（impl）

- `TWindowConstraintsImpl = class(TInterfacedObject, IWindowConstraints)`：INV-13 端到端载体，`FConstraints: TWindowConstraints` 值类型持有，`Create` 默认 `DefaultWindowConstraints`、`Create(AConstraints)` 校验后持有、`Apply/SetConstraints/SetMinSize/SetMaxSize` 校验后 record 单次 Move/单字段写、`GetConstraints: inline` 单次 record 拷贝零拷贝 O(1)；COM 引用计数自动释放，无手写 Free。
- `CreateWindowConstraints(: TWindowConstraints): IWindowConstraints; inline`：`TWindowConstraintsImpl.Create` 薄转发，门面同签名 `inline` 转发，零额外堆。
- `CheckWindowConstraints(const AConstraints: TWindowConstraints); inline`：校验 `Min/Max >=0` 且 `Max>=Min`，违例抛 `EWindowConstraintInvalid`（`CreateFmt`），`inline` 薄分支 O(1) 零拷贝。
- `CheckWindowConstraintsForOptions(const AOptions: TWindowOptions); inline`：`TWindowOptions` Min/Max 投影至 `TWindowConstraints` 后单源复用 `CheckWindowConstraints`，零重复。
- `ValidateWindowMinMax(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer); inline`：标量重载构造 `TWindowConstraints` 后单源复用校验，`inline` 薄分支。
- `WindowConstraintsGrowCapacity(ACurrent: Integer): Integer; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `bytes.ops 0→32→2×` 幂二 direct (no `window.impl`), `inline` 零额外调用 O(1) 均摊；门面同签名 `inline` 转发 L2→L1。
- `window.impl` 本地校验：`CheckWindowConstraints/ValidateWindowMinMax` 在 `window.impl` 本地 inline 零拷贝校验已去 L2→L2 薄转发守 L0-L3，无循环依赖。

---

## 6. 不变量

- **INV-13**（本模块）：运行期 SetMin/Max 最小闭包，约束校验单源 `CheckWindowConstraints` inline 零拷贝 O(1) 薄分支，`WindowConstraintsGrowCapacity` 单源 `bytes.ops 0→32→2×`，`TWindowConstraintsImpl` `heaptrc 0` 无泄漏；window.impl 已去薄转发本地校验守 L0-L3。
- **INV-3**：`base/intf` 零后端。
- 单源：`WindowConstraintsGrowCapacity` 唯一源 `bytes.ops` direct；校验唯一源 `CheckWindowConstraints`。

---

## 7. 性能

- `WindowConstraintsGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1) 均摊，零拷贝（纯算术）；`CheckWindowConstraints/ValidateWindowMinMax` 为 `inline` 薄分支 O(1) 零堆分配。
- `TWindowConstraintsImpl.Apply/GetConstraints/SetMin/Max/SetConstraints`：`inline` O(1) zero-copy（record 单次 Move/单字段写，零堆分配，`GetConstraints` 直返 `FConstraints`，`Apply/Set*` 薄分支校验）；`CreateWindowConstraints` 为 `inline` 单次 `TWindowConstraintsImpl.Create` 零额外调用。
- 证据：`core/src/nextpas.core.window.constraints.impl.pas:20-110` 与门面 `window.constraints.pas` `inline` 转发，`bytes.ops` 单源。

---

## 8. 稳定性

- `TWindowConstraintsImpl` 无句柄/堆数组，仅值类型 `FConstraints`，COM 引用计数自动释放，无手写 Free，析构继承不丢；校验失败抛 `EWindowConstraintInvalid` 由边界捕获；`heaptrc 0`（家族门禁）；`finalization` 无残留。
- 资源释放：`Apply/Set*` 失败不改 `FConstraints`，强抛后状态一致；`WindowConstraintsGrowCapacity` 纯算术无资源。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` | 四件套、零后端、单源 inline、TWindowConstraintsImpl 载体 |
| 契约测试 | `tests/nextpas.core.window/test_*` | 无效 Min/Max 抛 `EWindowConstraintInvalid`、标量 Validate、GrowCapacity 单源、Apply/SetMin/Max 端到端、window.impl 薄转发一致性 |

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，INV-13 从 `window.impl` <50行保留核心抽离为四件套，守 800行分治，单源 `bytes.ops` inline 零拷贝 |
