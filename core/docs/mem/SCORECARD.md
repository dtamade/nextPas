# mem Scorecard

**状态**: Steady 基线（SC1–SC9 脚手架绿；RELEASE 数字 2026-07-17）
**权威入口**: `core/tests/nextpas.core.mem/scorecard/`
**计划引用**: [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §7 · [ROADMAP.md](ROADMAP.md) D4

Ready 报告的性能证据以本 Scorecard 为准；历史微基准博物馆数据见 [BENCHMARKS.md](BENCHMARKS.md)。

**Go/Rust 同方法论对照**（非本程序内嵌；人工并排）:

```bash
make -C core/benchmarks/nextpas.core.mem/bench_arena_go_rust compare
```

纲领与验收：[PARITY-GO-RUST.md](PARITY-GO-RUST.md)。

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
| SC6 | compiler-like AST churn | `virtual_arena` | ns/op, **peakUsed** / finalUsed after unit Reset |
| SC7 | http-like per-request | `local_arena`, `system` | mean request ns, **p99** request latency |
| SC8 | sized vs unsized FreeMem | `free_sized`, `free_unsized`, `try_block_size` | ns/op + TryBlockSize 正确性 |
| SC9 | dual-track hot vs plugin | `hot_heap`, `plugin_ia`, `same_heap` | ns/op + 同堆互释正确性 |

规则：

- 禁止为 SC1 优化破坏 SC3 / 契约 C08。
- 默认堆或热路径改动至少附 SC1–SC4。
- 触达 scavenge / 归还 OS 时再附 SC5。
- 触达 VirtualArena / 编译器路径时附 SC6。
- 触达请求级 Arena 时附 SC7。
- 触达 `FreeMem(ptr)` / `TryBlockSize` / sized free 叙事时附 SC8。
- 触达双轨 / DefaultAllocator 热路径争论时附 SC9。
- SC5 可移植：用 `TGrowingAllocator.GetHeapStats`，不依赖 `/proc` RSS（RSS 对照可选）。
- SC6/SC7 是 **mem 侧工作负载**；产品接线：`http.mem` + `RequestArenaMiddleware` / `compiler.mem`（compiler 源改用仍另 lane）；集成契约见 `test_stdlib_integration`。

---

## 基线快照

**环境**: Linux x86_64, FPC 3.3.1-19195
**日期**: 2026-07-17（Era D · D4-a；`RELEASE=1` 本机一次全 PASS）
**命令**: `make -C core/tests/nextpas.core.mem/scorecard clean test RELEASE=1`
**结果**: `SCORECARD: ALL PASS (17 rows)`

### RELEASE=1（发布对照，无 heaptrc）

| ID | subject | ns/op | p99 | Mops/s | 备注 |
|----|---------|-------|-----|--------|------|
| SC1 | growing | 8 | — | 125.0 | ~2.8× system |
| SC1 | default_heap | 17 | — | 58.8 | Growing 单例（DefaultHeap） |
| SC1 | system | 22 | — | 45.5 | glibc via System.GetMem |
| SC2 | growing | 24 | 21 | 41.7 | sizes 16..4K |
| SC2 | system | 38 | 35 | 26.3 | |
| SC3 | growing | 103 | — | 9.7 | producer alloc / consumer free |
| SC4 | local_arena | 2 | — | 500 | AllocFast reset+reuse 64B |
| SC5 | growing | 71 | — | 14.1 | peak LiveBytes≈393KB; final≈12KB; delta Released≈489KB / 35 spans |
| SC6 | virtual_arena | 12 | — | 83.3 | 200 units × 4000 mixed nodes; peakUsed=352KB; finalUsed=0 |
| SC7 | local_arena | 84 | 59 | 11.9 | per-request scope（hdr+body+temps） |
| SC7 | system | 272 | 257 | 3.7 | 同负载 GetMem/FreeMem 对照 |
| SC8 | free_sized | 14 | — | 71.4 | `FreeMem(ptr,size)` 优选热 free |
| SC8 | free_unsized | 125 | — | 8.0 | `FreeMem(ptr)` span 扫描；~**8.9×** 更慢 |
| SC8 | try_block_size | — | — | — | 正确性：size-class ≥ 请求 |
| SC9 | hot_heap | 15 | — | 66.7 | DefaultHeap sized path |
| SC9 | plugin_ia | 132 | — | 7.6 | DefaultAllocator vtable path；~**8.8×** 更慢 |
| SC9 | same_heap | — | — | — | 正确性：插件块可 hot sized free |

SC5 说明：40 rounds × 256 × 64B churn + 周期 `Scavenge`；`final LiveBytes` 可保留少量 TLS/active 结构，门禁要求 **delta ReleasedSpans ≥ 1** 且 final ≤ peak。

SC6 说明：`TVirtualArena` 混合 AST 节点尺寸，每 unit `Reset`；门禁要求 peakUsed > 0 且 finalUsed 远小于 peak。

SC7 说明：p99 是 **单次请求** 延迟（ns），不是单次 alloc；LocalArena 相对 system 约 **3.2×** mean / **4.4×** p99（本机 2026-07-17）。

SC8 说明：同 64B 负载对比 sized vs unsized free；本机 ~**8.9×** 税（14 vs 125 ns/op）。`try_block_size` 行是契约/正确性，ns/op 可为 0。

SC9 说明：同 64B 对比热路径 vs 插件面；本机 ~**8.8×** 税（15 vs 132 ns/op）。教学证据“为什么要双轨而不是处处 IAllocator”。`same_heap` 行锁 S5 同堆互释。

数字随机器抖动属正常；**Ready 证据以当次 `RELEASE=1` 输出 + PASS 为准**，本表是可复现参考点。

### focused 默认（`-O2 -gl -gh`，CI 门禁）

带 `-gh` 时 system 路径会被 heaptrc 显著放大，**不可**与 RELEASE 数字横比。门禁只认 PASS/FAIL 与 0 leak。

说明：对比默认堆切换（D3）时，必须同一套 flags（建议 `RELEASE=1`）前后对照。

---

## 可观测 API（SC5 / 运维）

| API | 单元 | 含义 |
|-----|------|------|
| `TGrowingHeapStats` / `GetHeapStats` | `allocator.growing` | LiveBytes, Released*, Decommit* |
| `TMemStats` / `GetMemStats` | `mem.default` / `mem` | 进程统一快照（含上列 + 可选 DEBUG） |
| `TCentralPoolStats` / `CentralPoolGetStats` | `central` | 单 size-class 快照 |
| `Scavenge: Int32` | `allocator.growing` | 强制 scavenge；返回本轮 hard-release 数；先 flush TLS |
| `ScavengeCentralPools` | `central` | soft decommit（`SCAVENGER_DECOMMIT_THRESHOLD`）→ hard release（`AIdleThreshold`） |

---

## 扩展计划

| ID | 状态 | 说明 |
|----|------|------|
| SC1–SC4 | **脚手架绿** | 本目录 |
| SC5 | **脚手架绿** | GetHeapStats 可移植基线；可选 RSS 对照后续补 |
| SC6 | **脚手架绿** | VirtualArena AST-like unit churn |
| SC7 | **脚手架绿** | LocalArena per-request + system 对照 p99 |
| SC8 | **脚手架绿** | sized vs unsized FreeMem + TryBlockSize |
| SC9 | **脚手架绿** | dual-track hot vs plugin + same-heap |
| 集成 | **mem 侧绿** | `test_stdlib_integration`（M2-4 模式）；真实 compiler/HTTP 接线仍跨模块 |
