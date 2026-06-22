# nextpas.core.test Round 3 — Codex 审查修复方案

> 审查日期: 2026-06-21
> 审查人: Codex (opus)
> 基于: test-findings.md (50 findings)

## 一、优先级调整

| Finding | 原始 | 调整后 | 原因 |
|---------|------|--------|------|
| C-01 | P0 | **P0 保持** | 仅超时路径 use-after-free，确认准确 |
| C-02 | P0 | **P2 降级** | 每个 worker 写独立 LResults[I] slot，不存在真正 data race |
| M-01 | P1 | **P2 降级** | finalization 注释 "intentionally leaked"，有意设计 |
| M-02 | P1 | **P0 升级** | 与 C-01 绑定，超时路径系统性问题 |
| M-04 | P1 | **P2 降级** | 仅 `{$IFDEF HASHEAPTRACE}` 生效，非生产问题 |
| M-11 | P2 | **P3 降级** | RunParallelWithResult 已被 RunParallel 间接覆盖 |

## 二、修复批次

### Batch 1 (P0): C-01 + M-02 — TimeoutWorker 堆分配

**文件**: `core/src/nextpas.core.test.runner.parallel.pas`

**方案**: LRec 改为 `New/Dispose` 堆分配。join 路径由调用方 Dispose，超时路径标记 `TimedOut` 后由 worker 自行 Dispose。

**竞态分析**: worker 在 `Done:=True` 后检查 `TimedOut`，主线程在 `Done=False` 时设置 `TimedOut`。两条路径无交集 — 如果 worker 在主线程设置 TimedOut 之前完成，主线程会看到 `Done=True` 走 join 路径。x86_64 TSO 保证 store 顺序安全。

**改动**:
- `RunTestWithTimeout`: `var LRec: TTimeoutRec` → `New(LRec)` / join 路径 `Dispose(LRec)`
- `TimeoutWorker`: 结尾检查 `if R^.TimedOut then Dispose(R)`
- TTimeoutRec 新增 `TimedOut: Boolean` 字段（已存在）

**风险**: 中 — 堆分配引入生命周期管理复杂性

### Batch 2 (P2 防御性): C-02 — Res^ 写入移入 mutex

**文件**: `core/src/nextpas.core.test.runner.parallel.pas`

**方案**: 将 L303-314 的 `R^.Res^` 写入移入 L265-299 的 mutex 保护区域。

**风险**: 极低 — 纯位置移动

### Batch 3 (P1): M-03 — TestTable 堆内存清理

**文件**: `core/src/nextpas.core.test.runner.pas`

**方案**: 添加 `CleanupTableAllocations` 方法，在 RunWithResult/RunParallelWithResult teardown 后调用。Dispose 前 nil-out 防止 double-dispose。

**风险**: 低 — 需注意 TTestSuite 是 record (COW)

### Batch 4 (P1): M-05 — Filter 不计为 skip

**文件**: `core/src/nextpas.core.test.runner.pas`

**方案**: Filter 排除的测试直接 `Continue`，不计入 pass/fail/skip。

**风险**: 低 — 可能影响依赖 skip 计数的 CI 脚本

### Batch 5 (P1): M-08 — Mock 注释修正

**文件**: `core/src/nextpas.core.test.mock.pas`

**方案**: 修正 header 注释为 "Manual mock helper"，删除 `Create<IFoo>` 泛型示例。

**风险**: 零

### Batch 6 (P2): L-02 — JsonEscape 完整转义

**文件**: `core/src/nextpas.core.test.output.json.pas`

**方案**: 补充 `\b` `\f` `\r` + `Ord(C) < 32` 的 `\u00XX` 兜底。

**风险**: 零

### Batch 7 (P2): L-21/L-22 — Mock 返回值健壮性

**文件**: `core/src/nextpas.core.test.mock.pas`

**方案**: `GetReturnInt` 用 `TryStrToInt64`；`GetReturnBool` 用 `SameText`。

**风险**: 低

## 三、不修项

| Finding | 理由 |
|---------|------|
| C-02 (降级后) | 无真正 data race，Batch 2 仅防御性 |
| M-01 (降级后) | 有意设计 |
| M-04 (降级后) | 仅 heap trace |
| M-06 | 运行时只读 |
| M-07 | 设计约定 |
| M-09 | 串行安全 |
| M-10 | 功能缺失，不阻塞 |
| L-01 | Breaking change |
| L-03 ~ L-22 | 低影响或 FPC 限制 |

## 四、测试策略

| Batch | 验证方法 |
|-------|---------|
| 1 | 100ms 超时 + 500ms 测试体，重复 100 次，heap trace 无 UAF |
| 2 | RunParallelWithResult 直接测试 AResult 内容 |
| 3 | table test + heap trace 无泄漏 |
| 4 | filter 模式下 Skip 计数验证 |
| 5 | N/A (注释) |
| 6 | JsonEscape 控制字符测试 |
| 7 | Mock GetReturnInt('abc') 返回 0 |

**总计**: 7 批次，~138 行改动，最高风险 Batch 1 (中)
