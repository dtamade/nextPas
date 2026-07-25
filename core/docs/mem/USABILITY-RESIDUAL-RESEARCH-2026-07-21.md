# mem 可用性复评残余调研（P2）

**日期**: 2026-07-21 · **CLOSED**: 2026-07-26
**状态**: **CLOSED**
**输入**: 落地后复评 9.4/10；无 P0/P1
**范围**: P2-1 历史子类 raise；P2-2 坏 stem；P2-3 SAFETY 文档入口

## 量化（调研时）

| 项 | 数量 |
|----|------|
| 历史子类 bare raise | **40**（fixed 12、fixed.growable 16、slab 2、slab.sharded 4、stack 2、ring 3、arena.local EStackOverflow 1） |
| 坏 stem（`*.Raise` / `allocator_*`） | **~24 处** 跨 8 文件 |
| 主路径 EAllocError/EOutOfMemory | 137/137 已助手（门禁已钉） |

## 根因

1. `check_alloc_error_raises` 曾只匹配 `EAllocError|EOutOfMemory`，子类字面逃逸。
2. R-* 批量转换对非 Type.Method 字面量用了文件名 + `Raise`。
3. SAFETY 故意不进默认 lane，文档入口需可发现。

## 策略（已执行）

- 子类 raise → `FormatAllocErrorMsg`；保留子类类型（不删 API）。
- 门禁扩展：扫 `EMemFixed*` / `EStackPool*` / `ESlabPool*` / `EGrowingFixed*` / `ERingBuffer*` / `EStackOverflow` 等 alloc-domain raise（白名单 `error.pas`）。
- 坏 stem 改为真实 Type.Method。
- P2-3：README / MEM-HOST-RUNTIME-CI 钉 `test_heap_safety_profile`；**不**改 core-ci matrix / lane_gate。

## 关闭证据（2026-07-26）

| 项 | 证据 |
|----|------|
| P2-1 子类 raise | `bash …/check_alloc_error_raises.sh` → **OK**；源扫描 missing FormatAllocErrorMsg = **0** |
| P2-2 坏 stem | 同门禁 low-quality stem 规则 → **0** 命中 |
| P2-3 SAFETY 入口 | [README.md](README.md) DEBUG 表 + [MEM-HOST-RUNTIME-CI.md](MEM-HOST-RUNTIME-CI.md) 可选入口 |
| 回归 | `make lane-focused LANE=mem`（guardrails + contract_matrix） |

**残余非目标**（故意保留，非 P2 债）：

- `EArgumentNil` / `EInvalidArgument` / `ENextPasError` / utils `EOverflow` — 非 alloc-domain 消息助手范围
- 热路径双 free 默认 UB；SAFETY 仍 opt-in
- tui inject FreeMemOf WAIVE

## 风险

LOW。消息全文可能变；测试优先 Pos stem / 错误码。关闭后默认回 **Maintenance Idle**。
