# mem Scorecard

**状态**: Active（SC1–SC5 脚手架已落地）
**权威入口**: `core/tests/nextpas.core.mem/scorecard/`
**计划引用**: [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §7

Ready 报告的性能证据以本 Scorecard 为准；历史微基准博物馆数据见 [BENCHMARKS.md](BENCHMARKS.md)。

---

## 运行

```bash
# focused gate（含 heaptrc，偏正确性/可复现）
make focused FOCUS=core/tests/nextpas.core.mem/scorecard

# 或：
make -C core/tests/nextpas.core.mem/scorecard clean test

# 发布用数字（关闭 heaptrc，更接近生产）
make -C core/tests/nextpas.core.mem/scorecard clean test RELEASE=1
```

---

## 场景

| ID | 场景 | Subject | 指标 |
|----|------|---------|------|
| SC1 | small_64B alloc+free | `growing`, `default_heap`, `system` | ns/op, Mops/s |
| SC2 | mixed sizes 16B–4KB | `growing`, `system` | ns/op, **p99** (batch) |
| SC3 | cross-thread free | `growing` | 正确性 + ns/op |
| SC4 | arena reset+reuse | `local_arena` | ns/op |
| SC5 | long-run scavenge | `growing` (DefaultGrowing) | peak/final **LiveBytes**, delta **ReleasedBytes**/Spans, ns/op |

规则：

- 禁止为 SC1 优化破坏 SC3 / 契约 C08。
- 默认堆或热路径改动至少附 SC1–SC4。
- 触达 scavenge / 归还 OS 时再附 SC5。
- SC5 可移植：用 `TGrowingAllocator.GetHeapStats`，不依赖 `/proc` RSS（RSS 对照可选）。
- SC6/SC7（compiler / HTTP 真实路径）随上层集成落地。

---

## 基线快照

**环境**: Linux x86_64, FPC 3.3.1
**日期**: 2026-07-14

### RELEASE=1（发布对照，无 heaptrc）

| ID | subject | ns/op | p99 | Mops/s | 备注 |
|----|---------|-------|-----|--------|------|
| SC1 | growing | 8 | — | 125 | ~3× system |
| SC1 | default_heap | 16 | — | 62.5 | Growing 单例（D1） |
| SC1 | system | 24 | — | 41.7 | glibc via System.GetMem |
| SC2 | growing | 23 | 22 | 43.5 | 6 size classes |
| SC2 | system | 41 | 42 | 24.4 | |
| SC3 | growing | 106 | — | 9.4 | producer alloc / consumer free |
| SC4 | local_arena | 2 | — | 500 | AllocFast reset+reuse 64B |
| SC5 | growing | 71 | — | 14.1 | peak LiveBytes≈417KB; delta Released≈513KB / 35 spans |

SC5 说明：40 rounds × 256 × 64B churn + 周期 `Scavenge`；`final LiveBytes` 可保留少量 TLS/active 结构，门禁要求 **delta ReleasedSpans ≥ 1** 且 final ≤ peak。

### focused 默认（`-O2 -gl -gh`，CI 门禁）

带 `-gh` 时 system 路径会被 heaptrc 显著放大，**不可**与 RELEASE 数字横比。门禁只认 PASS/FAIL 与 0 leak。

说明：对比默认堆切换（D3）时，必须同一套 flags（建议 `RELEASE=1`）前后对照。

---

## 可观测 API（SC5 / 运维）

| API | 单元 | 含义 |
|-----|------|------|
| `TGrowingHeapStats` / `GetHeapStats` | `allocator.growing` | LiveBytes, Released*, Decommit* |
| `TCentralPoolStats` / `CentralPoolGetStats` | `central` | 单 size-class 快照 |
| `Scavenge: Int32` | `allocator.growing` | 强制 scavenge；返回本轮 hard-release 数；先 flush TLS |
| `ScavengeCentralPools` | `central` | soft decommit（`SCAVENGER_DECOMMIT_THRESHOLD`）→ hard release（`AIdleThreshold`） |

---

## 扩展计划

| ID | 状态 | 说明 |
|----|------|------|
| SC1–SC4 | **脚手架绿** | 本目录 |
| SC5 | **脚手架绿** | GetHeapStats 可移植基线；可选 RSS 对照后续补 |
| SC6 | pending | compiler-like AST churn |
| SC7 | pending | http-like per-request arena |
