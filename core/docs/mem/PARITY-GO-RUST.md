# mem × Go / Rust 对标纲领（Era E）

**状态**: Active（2026-07-19）
**Owner**: mem lane（全权）
**活路线图**: [ROADMAP.md](ROADMAP.md) 时代 E
**原则**: 对标的是 **stdlib 质量与生产规模**，不是「分配器文件数」或「博物馆广度」。

---

## 1. 对标对象（公平口径）

| 维度 | Go | Rust | nextpas.core.mem 目标 |
|------|----|------|------------------------|
| 默认堆 | runtime mallocgc + GC | GlobalAlloc / 系统分配器 | `DefaultHeap` Growing（无 GC，显式 free） |
| 生命周期 | GC；手写 bump 在业务里 | bumpalo / arena crates | `IArena` Local/Chunked/Virtual（一等公民） |
| 注入面 | 少见；池用 sync.Pool | `Allocator` trait | `IAllocator` + `DefaultAllocator`（插件，非热路径） |
| 诊断 | `ReadMemStats` / pprof | miri / sanitizer / heap profiling | `GetMemStats` / DEBUG wrap / HEAP_SAFETY |
| 契约 | runtime 内部 | `Layout` + dealloc size 强制 | Contract Matrix + sized free（SC8） |
| 表面规模 | **小而硬** | std + 精选 crate | Tier-0/1 精选；Tier-3 可删 |

**不做假对标**：

- 不把 Rust `Bump` 被 DCE 掉的 0 ns/op 当胜利。
- 不把 Go `make` 无 free 与我们的 alloc+free 直接横比而不写清口径。
- 不新增无 consumer 的 allocator 当「规模」。

---

## 2. 成功标准（Era E 验收）

| ID | 标准 | 证据 |
|----|------|------|
| **P1** | 交叉语言方法论一致的可复现数字 | `core/benchmarks/nextpas.core.mem/bench_arena_go_rust` `make compare` |
| **P2** | 默认堆相对 system/glibc 保持优势；相对 Go batch malloc 有说明性对照 | Scorecard SC1/SC8/SC9 + compare 输出 |
| **P3** | Arena reset+reuse 与 Go 手写 bump **同量级**（通常 ≤2×，争 1×） | LocalArena vs Go BumpArena 行 |
| **P4** | 产品表面 stdlib 化：Tier-3 博物馆不挡可发现性 | P-a prune 执行或明确保留理由 |
| **P5** | 契约/诊断不回退 | `lane-focused` + contract_matrix 常绿 |
| **P6** | 大规模负载：跨线程 free、scavenge、长跑 | SC3/SC5；可选 soak |
| **P7** | 真实 consumer 采用 sized free / Arena 生命周期 | D3 持续；CO 观测更新 |

综合：**质量** = P2+P3+P5+P6；**规模** = P4（表面收敛）+ P6/P7（生产路径覆盖面），不是单元文件数。

---

## 3. 工作流切片

| Slice | 内容 | 状态 |
|-------|------|------|
| E0 | 本纲领 + ROADMAP 时代 E | **本批** |
| E1 | 修复 `bench_arena_go_rust` API 漂移；`make compare` | **本批** |
| E2 | 执行 [P-a prune](PRUNE-P-a-DESIGN-2026-07-19.md)（10 Tier-3 + 测试） | **本批优先** |
| E3 | SCORECARD / BENCHMARKS 链到 live compare；刷新 RELEASE 注记 | 随 E1 |
| E4 | D3：高价值 consumer sized free（tls/simd 已部分） | 持续 |
| E5 | 可选 SC10：scorecard 内嵌「仅文档引用 compare」或 shell 包装 | 按需 |

---

## 4. 命令

```bash
# 交叉语言（同方法论）
make -C core/benchmarks/nextpas.core.mem/bench_arena_go_rust compare

# 权威 mem 门禁数字
make -C core/tests/nextpas.core.mem/scorecard clean test RELEASE=1
make lane-focused LANE=mem
```

### 4.1 本机快照（2026-07-19，同方法论 64B ×10000）

| 场景 | nextPas | Go | 解读 |
|------|---------|-----|------|
| Bump AllocFast / BumpArena | **3 ns/op** | 5 ns/op | **领先**（P3 达标） |
| reset+reuse | **3 ns/op** | 4 ns/op | **领先** |
| batch heap (alloc 保留) | DefaultHeap sized **~102** | runtime batch make **~99** | 同量级；Go 无显式 free |
| System/glibc free 环 | System **~11** | — | Scorecard SC1 以 RELEASE=1 为准 |

Rust Bump 常报 0 ns（DCE）— **不作假胜利**。权威 Ready 仍用 scorecard。

---

## 5. 与 Steady 的关系

时代 D Steady **禁止无 consumer 新 allocator** 仍然有效。
时代 E **不是** 再开 Phase 29；是：

1. **证明** 对标数字（E1）
2. **收敛** 表面规模（E2 prune）
3. **加固** 生产路径（E4/E6）

冲突时：Era E 验收表优先于「Steady 默认不删」——prune 在总控/全权 owner 批准下 path-limited 执行。
