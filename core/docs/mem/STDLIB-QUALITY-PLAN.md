# mem 标准库质量计划

**状态**: Active — **product dual-track CLOSED**（2026-07-16）；维护与 landing 候选，不再开 dynarray→TVec 产品表冲刺
**Owner**: mem lane
**创建**: 2026-07-14
**目标**: 把 `nextpas.core.mem` 从“分配器平台/博物馆”收敛为 **对标并在关键维度超过 Go runtime / Rust Allocator 生态** 的标准库级内存底座。

相关文档：

- [README.md](README.md) — 模块入口与选择指南
- [ARCHITECTURE.md](ARCHITECTURE.md) — 分层与 owner
- [CONTRACT.md](CONTRACT.md) — 运行时契约
- [API-GUIDE.md](API-GUIDE.md) — 决策树
- [BENCHMARKS.md](BENCHMARKS.md) — 历史基准
- [SCORECARD.md](SCORECARD.md) — SC1–SC4 权威性能入口
- [DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md) — DEBUG 包装链（M2-5）
- [USABILITY-SCORE.md](USABILITY-SCORE.md) — **权威**可用性评分（post-S5 / lane 收口）
- [USABILITY-AUDIT.md](USABILITY-AUDIT.md) — 历史可用性长报告（SUPERSEDED）

---

## 1. 成功定义（超过 Go/Rust 的可验收标准）

不是“拥有更多分配器类”，而是同时满足：

| # | 标准 | 验收信号 | 状态（2026-07-15） |
|---|------|----------|-------------------|
| S1 | **默认路径无聊且正确** | 新人 10 分钟会选；99% 场景只用 Default + Arena + Pool | ✅ README 手册 + 决策树 |
| S2 | **契约全平台一致** | Tier-0/1 全部通过同一 Contract Matrix | ✅ `test_contract_matrix` |
| S3 | **性能可信** | Scorecard 持续对照 system；不全靠 ns/op | ✅ SC1–SC7 + RELEASE 基线 |
| S4 | **诊断零成本默认、一键打开** | DEBUG/env 可叠 Sentinel/Leak/Stats，不改业务代码 | ✅ `NEXTPAS_MEM_DEBUG` |
| S5 | **运行时集成** | 上层 IAllocator 默认吃 DefaultHeap（collections 等） | ✅ 2026-07-15（Growing IAllocator 根；compiler/HTTP 直热路径另议） |
| S6 | **确定性生命周期优势** | Arena/Pool 在延迟敏感场景可证明 | ✅ SC4；外部对照扩展中 |
| S7 | **API 面小、长期兼容** | 门面只暴露 Tier-0 + 精选 Tier-1；Experimental 无兼容承诺 | ✅ 门面瘦身 |

**不做成功标准**：allocator 文件数、测试目录数、roadmap phase 序号。

---

## 2. 现状审计摘要（2026-07-14）

| 指标 | 现状 | 判断 |
|------|------|------|
| 源文件 | ~105 | 过大，需分层而非继续膨胀 |
| 测试目录 | ~145 | 覆盖面广，但“每类 7 测”不等于契约一致 |
| `IAllocator` | 5 方法 + Traits | 接口形状正确，应冻结 |
| 门面 re-export | Tier-0/1/2 精选（Tier-3 已出门面） | 收敛中；见 §3 |
| `DefaultHeap` / 过程式 `GetMem` | **Growing 原生**（D1 已切） | 热路径无 IAllocator |
| `DefaultAllocator` | **Growing IAllocator 根 + 可选 DEBUG 链**（S5） | 组合器/诊断/collections 注入；同堆非热路径 |
| 外部消费者 | 多数 niche allocator ≈ 0 | 证明门面膨胀无生态刚需 |
| 微基准 | Growing/Arena 亮眼 | 需补跨线程 free、RSS、p99、真实路径 |
| 并发正确性 | Growing 已修 MPSC 等深坑 | 仍需作为长期回归主轴 |

结论：

1. **能力已经够用**，甚至过度。
2. **缺的是 stdlib 纪律**：默认栈、契约矩阵、门面瘦身、Scorecard、上层集成。
3. 下一阶段 **禁止** 无 consumer 的新 allocator phase。

---

## 3. Tier 分层（产品表面）

### 3.1 分层规则

| Tier | 含义 | 门面 | 兼容 | 测试要求 |
|------|------|------|------|----------|
| **0** | 标准库默认，必须极致 | **必须** re-export | 强兼容 | Contract Matrix + soak + scorecard |
| **1** | 生产组合器/场景 | 精选 re-export | 强兼容 | Contract Matrix + 单元 |
| **2** | 诊断/故障注入 | 精选 re-export | 兼容 | 单元 + 可选 property |
| **3** | Experimental / 历史库存 | **禁止** 进门面 | 无承诺 | 现有测试可保留，不扩张 |

规则：

- 新类型默认进 Tier-3，除非有明确上层 consumer 与验收用例。
- Tier-3 只可通过子单元 `uses`（例如 `nextpas.core.mem.allocator.prediction`）。
- 组合器不得改变底层 nil/0/OOM 契约。

### 3.2 Tier-0 — 默认栈（主攻）

#### 契约与入口

| 符号 | 单元 | 角色 |
|------|------|------|
| `IAllocator` / `TAllocatorTraits` | `mem.intf` | 通用堆契约 |
| `IArena` / `TArenaMark` / `TArenaStats` | `arena.intf` / `arena.base` | 线性生命周期契约 |
| `DefaultHeap` / 过程式 `GetMem`/`FreeMem`/... | `mem` / `mem.default` | **热路径**默认堆（Growing） |
| `DefaultAllocator` | `mem` / `mem.default` | **插件面**（Growing IAllocator + 可选 DEBUG 链） |
| `TMemStats` / `GetMemStats` | `mem` / `mem.default` | 进程级快照（见可观测表） |
| `CreateDefaultArena` / `CreateChunkedArena` | `mem` | 工厂 |
| `EAllocError` 族 | `mem.error` | 错误词汇 |
| `SecureZero*` | `mem.secure` | 安全清零 |

#### 默认堆与后端

| 符号 | 单元 | 角色 | 备注 |
|------|------|------|------|
| `TGrowingAllocator` | `allocator.growing` | **热路径默认堆**（`DefaultHeap`） | TLS + central；性能主轴 |
| `TRtlAllocator` | `allocator.rtl` | FPC RTL 后端 | 显式 `GetRtlAllocator`；bootstrap/fallback |
| `TGrowingIAllocator` | `allocator.growing_ia` | Growing 的 IAllocator 适配 | `DefaultAllocator` 根（S5）；`ResolveAllocator(nil)` |
| `TCrtAllocator` | `allocator.crt` | CRT 后端 | 条件编译 |
| `TMimallocAllocator` | `allocator.mimalloc` | 第三方后端 | 优雅降级 |
| `TMemoryMapAllocator` | `allocator.mmap` | 匿名映射后端 | 大对象/特殊场景 |

#### Arena

| 符号 | 单元 | 场景 |
|------|------|------|
| `TLocalArena` | `arena.local` | 固定容量请求/帧 |
| `TChunkedArena` | `arena.chunked` | 可增长批量 |
| `TVirtualArena` (+ Adapter) | `arena.virtual` / `allocator.arena` | 大地址空间 / 编译器热路径 |
| `TArenaConcurrent` | `arena.concurrent` | 显式并发包装 |
| `TThreadArena*` | `arena.thread` | 线程本地 arena 管理 |

#### Pool / BlockPool（保留最小充分集）

| 符号 | 单元 | 场景 |
|------|------|------|
| `IPool` / `IMemoryPool` | `pool.base` | 池契约 |
| `TLocalBlockPool` / `TBlockPool` | `pool` / `blockpool` | 固定块 |
| `TFixedPool` | `pool.fixed` | 固定容量池 |
| `TFixedSlabPool` | `pool.fixed_slab` | nginx-style slab |
| `TSlabPool` | `pool.slab` | 可变 size-class slab |
| `TSizeClassPool` | `pool.sizeclass` | 多尺寸自动选池 |
| `CreateFixedSlabPool` / `CreatePoolAllocator` | `mem` | 工厂 |

并发变体（`*Concurrent` / `*Sharded`）留在 Tier-0 **实现集**，但文档标注为“并发场景专家路径”，门面可保留类型、不进默认决策树首行。

#### 可观测 / 压力（运行时级）

| 符号 | 单元 | 角色 |
|------|------|------|
| `TMemStats` / `GetMemStats` | `mem.default` / `mem` | **进程级统一快照**（DefaultHeap + 可选 DEBUG） |
| `TGrowingHeapStats` / `GetHeapStats` | `allocator.growing` | Growing 原生 scavenger 字段 |
| `TAllocSnapshot` / `TAllocHistogram` / `TAllocStatsCollector` | `mem.stats` | IAllocator 包装器统计原料 |
| `TOomHandler` / `TOomEvent` | `mem.oom` | OOM 回调 |
| `TMemoryBudget` / `TBudgetAllocator` | `mem.budget` | 任务预算 |
| `TMemoryMap` / `TSharedMemory` | `mem.memory_map` | 映射载体（匿名/共享原语） |

#### Growing 内部构建块（不单独推广）

`sizeclass` / `span` / `cache.thread` / `central` / `shuffle` — **实现细节**，门面可不 re-export，或仅高级文档提及。

### 3.3 Tier-1 — 生产组合器（门面精选）

| 符号 | 理由 |
|------|------|
| `TFallbackAllocator` / `TFallbackArena` | 多后端降级，生产刚需 |
| `TBoundedAllocator` | 上限控制 |
| `TThreadSafeAllocator` | 非线程安全后端包装 |
| `TScopedAllocator` | 作用域批量释放 |
| `TAlignedAllocator` | 对齐策略包装 |
| `TZeroedAllocator` | 强制零初始化策略 |
| `TStatsAllocator` / `TAllocStatsAllocator` | 统计包装 |
| `THotswapAllocator` | 运行时切换后端 |
| `TPoolAllocator` | Pool → IAllocator 桥 |
| `TArenaAllocator` (`TFastArenaAllocator`) | Arena → IAllocator 桥 |
| `TBatchAllocator` | 批量 API，性能路径 |
| `TCallbackAllocator` | 嵌入式/自定义后端 |

### 3.4 Tier-2 — 诊断与故障注入（门面精选）

| 符号 | 理由 |
|------|------|
| `TTrackingAllocator` | 泄漏检测 |
| `TLeakCheckResult` / `TLeakReportAllocator` | 报告 |
| `TSentinelAllocator` | 越界/double-free |
| `TGuardAllocator` | guard page |
| `TDebugAllocator` | 来源记录 |
| `TFailAllocator` / `TOomAllocator` | 故障注入 |
| `TLoggingAllocator` | 追踪日志 |
| `TSamplingAllocator` | 采样画像 |
| `TCountingAllocator` | 简单活跃计数 |

目标体验（已落地，见 [DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md)）：

```text
NEXTPAS_MEM_DEBUG=sentinel,leak,stats
```

等价于自动包装 `DefaultAllocator`，业务代码无感；`DefaultHeap` 不受影响。

### 3.5 Tier-3 — Experimental / 库存（踢出门面）

以下 **保留源码与测试**，但应从 `nextpas.core.mem` 门面 **uses + type alias 移除**（破坏性收敛，见 §6 迁移策略）。

| 类别 | 符号 |
|------|------|
| 策略实验 | `TPredictionAllocator`, `TNumaAllocator`, `TReplayAllocator`, `TCowAllocator`, `TCascadeAllocator` |
| 与 Arena/Growing 重叠 | `TBumpAllocator`, `TArena2Allocator`, `TArenaGroupAllocator`, `TWatermarkAllocator`, `TSlidingAllocator`, `TStackAllocator`, `TFreelistAllocator`, `TGroupAllocator`, `TSizeClassAllocator`, `TSlabAllocator`（allocator 侧）, `TPool2Allocator`, `TCoalesceAllocator`, `TCompactAllocator`, `TDualAllocator`, `TPrefixAllocator`, `TPageAllocator`, `THugePageAllocator`, `TMappedFileAllocator`, `TThreadCacheAllocator`, `TBitmapAllocator` |
| 其他 | `TAllocatorRegistry`（若无稳定 consumer）, 以及任何仅测试使用的 wrapper |

**例外保留在门面的条件**（满足其一即可升到 Tier-1/2）：

1. core 外或非 mem 测试有真实 `uses`
2. 编译器 / HTTP / collections 明确依赖
3. Scorecard 证明其不可被 Tier-0 替代

### 3.6 边界注意

| 项 | 建议 |
|----|------|
| `TRingBuffer` | 通用 DS；中期迁出 mem 或明确“mem-local utility，不扩展” |
| `TMemMutex` / `TMemRwLock` | 保持 mem-local compatibility wrapper，不扩张为并发原语层 |
| `pressure` / `stack_guard` / `watermark` | 保留实现；门面只暴露稳定 API |
| mapped file vs anonymous map | 文件/共享 ring 归 `io`；mem 只匿名映射与载体 |

---

## 4. 默认路径冻结

### 4.1 决策树（用户可见）

```text
需要统一生命周期批量释放？
  是 → Arena
       容量可知且不大 → TLocalArena / CreateDefaultArena
       需要增长       → TChunkedArena
       超大/编译器热路径 → TVirtualArena
       多线程共享 arena → TArenaConcurrent（显式）
  否 → 固定大小高频对象？
         是 → BlockPool / FixedSlab / FixedPool
         否 → DefaultHeap / GetMem（Growing 热路径）
              需要 IAllocator 注入 → DefaultAllocator（Growing 根 ± DEBUG）
诊断？ → 包装 Tracking / Sentinel / Guard（或 env 一键；仅插件面）
OOM/预算？ → Fallback / Bounded / Budget / OomHandler
```

### 4.2 Default 双轨（关键 slice）

**设计原则**（与 IAllocator 性能立场一致）：

| 轨道 | API | 实现 | 用途 |
|------|-----|------|------|
| **热路径** | `DefaultHeap` / 过程式 `GetMem`·`FreeMem`·`AllocMem`·`ReallocMem` | `TGrowingAllocator` 原生（直接调用） | 框架默认堆 |
| **插件面** | `DefaultAllocator: IAllocator` | Growing IAllocator 根 + 可选 DEBUG 链 | 组合器/诊断/collections 注入（**同堆**） |

热路径 **不**经 IAllocator 虚调用。插件面适配器只服务注入签名（`FreeMem(ptr)`），不替代 `DefaultHeap`。

分阶段：

| 阶段 | 行为 | 门槛 | 状态 |
|------|------|------|------|
| D0 | 过程式 GetMem 也走 RTL IAllocator | — | 历史 |
| D1 双轨 | 过程式 GetMem → `DefaultHeap`（Growing）；`DefaultAllocator` 仍 RTL | contract + default tests | ✅ 2026-07-14 |
| D2 DEBUG 链 | `NEXTPAS_MEM_DEBUG` 叠诊断到 `DefaultAllocator`（不碰热路径） | `test_debug_wrap` | ✅ 2026-07-15 |
| D3 固化文档 | 示例/手册按 DefaultHeap 为热路径 | README + API-GUIDE + Scorecard | ✅ 文档 2026-07-15 |
| D4 / S5 | `DefaultAllocator` / `ResolveAllocator(nil)` → Growing IAllocator 根 | default + debug_wrap + usability + collections | ✅ 2026-07-15 |

**禁止**：为“统一接口”让热路径重新走 IAllocator 虚调用。

### 4.3 接口冻结

`IAllocator` 保持 5 方法，不再膨胀：

```pascal
GetMem / AllocMem / ReallocMem / FreeMem / Traits
```

扩展能力走独立接口（后续可加，但不塞回 IAllocator）：

- `IAllocatorStats`（已有 stats 原料）
- `IAlignedAllocator`（可选）
- `IBatchAllocator`（BatchGetMem/BatchFreeMem）
- `IMemoryPool.MemSizeOf`

Traits 可增量字段，但每个字段必须有 conformance 测试。

---

## 5. Contract Conformance Matrix

所有 Tier-0/1 实现必须接入同一测试 harness：

```text
core/tests/nextpas.core.mem/test_contract_matrix/
```

**入口**（已落地骨架）：

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
```

当前登记：

| 实现 | C01–C05 | C06 OOM | C07 Zero | C08 Thread | C09 NoRealloc | C10 Leak | C11 Align | C12 Mark | 池 nil/双 free |
|------|---------|---------|----------|------------|---------------|----------|-----------|----------|----------------|
| RTL (`IAllocator`) | PASS | PASS (via Fail) | PASS | PASS smoke | N/A | PASS (Track) | N/A | N/A | N/A |
| `TVirtualArenaAllocator` | — | — | — | — | PASS | — | — | — | N/A |
| `TGrowingAllocator` (native) | PASS* | — | PASS* | PASS smoke | N/A | PASS* | N/A | N/A | N/A |
| `DefaultHeap` (process) | PASS* | — | PASS* | cross-thread free | N/A | — | N/A | N/A | N/A |
| `TLocalArena` | N/A | N/A | N/A | N/A | N/A | N/A | PASS | PASS | N/A |
| `TChunkedArena` | Alloc(0) | — | — | N/A | N/A | N/A | PASS | PASS | N/A |
| `TFixedSlabPool` as `IAllocator` | PASS | — | PASS | — | — | — | — | — | — |
| `TLocalBlockPool` | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | PASS |

\* Growing 非 `IAllocator`：`ReallocMem(ptr, old, new)` / `FreeMem(ptr, size)` 热路径；契约按原生表面适配。

### 5.1 必测用例

| ID | 用例 | 期望 |
|----|------|------|
| C01 | `GetMem(0)` / `AllocMem(0)` | nil |
| C02 | `FreeMem(nil)` | no-op |
| C03 | `ReallocMem(nil, n)` | ≡ GetMem(n) |
| C04 | `ReallocMem(p, 0)` | free + nil |
| C05 | `ReallocMem(nil, 0)` | nil |
| C06 | OOM / Fail 注入 | 返回 nil；Realloc 失败时原指针有效 |
| C07 | `Traits.ZeroInitialized` | 仅约束 AllocMem |
| C08 | `Traits.ThreadSafe=True` | 并发 stress 不崩、不丢块 |
| C09 | `Traits.SupportsRealloc=False` | 行为与文档一致（禁止 silently corrupt） |
| C10 | 写后读 / Free 后不泄漏（tracking 包装） | 0 leak |
| C11 | Arena `AllocAligned` | align 为 2 的幂；指针对齐 |
| C12 | Arena Reset / Mark-Restore | 可复用；不 UAF 于契约内 |

### 5.2 实现登记表（执行时维护）

每行一个实现，列 C01–C12：`PASS` / `N/A` / `FAIL`。

初始优先登记：

1. RTL / CRT / Mimalloc
2. Growing
3. Tracking / Sentinel / Fallback / Bounded / ThreadSafe
4. Local / Chunked / Virtual(+adapter) Arena
5. BlockPool / FixedPool / FixedSlab / SlabPool

Tier-3 不强制进矩阵；若保留门面资格则必须进。

---

## 6. 门面瘦身计划

### 6.1 目标形态

`nextpas.core.mem` 门面只包含：

1. Tier-0 契约与默认工厂
2. Tier-0 主实现类型
3. Tier-1 精选组合器
4. Tier-2 精选诊断
5. Secure / OOM / Stats / Budget 运行时 API

**移除**：§3.5 Tier-3 的 uses 与 type alias。

### 6.2 迁移策略（降低破坏面）

| 步骤 | 动作 |
|------|------|
| M1 | 文档标记 Tier-3 为 Experimental，更新 API-GUIDE |
| M2 | 门面头部注释给出 “std path vs expert path” |
| M3 | 从门面删除 Tier-3 re-export（源码保留） |
| M4 | 若有外部依赖，提供一版 deprecation 窗口（本仓库目前 niche ≈ 0） |
| M5 | `test_mem` 门面可达性测试改为只断言 Tier-0/1/2 |

### 6.3 明确不在本计划删除的

- Tier-3 **源文件**（除非后续证明死码且无测试价值）
- 已有 focused 测试目录（可保留，作回归）
- CONTRACT 语义

---

## 7. Scorecard（性能与可信度）

固定 7 项，写入 CI 或 `make focused` 旁路目标（实现切片另开）：

| ID | 场景 | 对照 | 关注指标 |
|----|------|------|----------|
| SC1 | small_64B alloc+free | glibc / Go / Rust | ns/op, Mops/s |
| SC2 | mixed sizes | 同上 | ns/op, p99 |
| SC3 | cross-thread free | 同上 | 正确性 + throughput |
| SC4 | arena reset+reuse | Go bump / Rust bumpalo | ns/op |
| SC5 | long-run RSS / fragmentation | glibc / mimalloc | RSS 斜率, ReleasedBytes |
| SC6 | compiler-like AST churn | 自研路径 | 总时间, peak RSS |
| SC7 | http-like per-request arena | Go 请求内 alloc 对照 | p99 latency |

规则：

- 微基准亮点可以写进 BENCHMARKS，但 **Ready 报告只认 Scorecard**。
- 禁止为 SC1 优化破坏 SC3/C08。
- 每次默认堆或热路径改动必须附 SC1–SC4 至少；触达 scavenge/归还则附 SC5。

历史数据入口：[BENCHMARKS.md](BENCHMARKS.md)。权威 Scorecard 入口与基线：[SCORECARD.md](SCORECARD.md)；程序：

```bash
make focused FOCUS=core/tests/nextpas.core.mem/scorecard
# 发布数字：
make -C core/tests/nextpas.core.mem/scorecard clean test RELEASE=1
```

---

## 8. 90 天执行路线

### Month 1 — 收口与证明（P0）

| ID | 工作 | 验收 |
|----|------|------|
| M1-1 | 合并本计划到文档导航；README 链接 | 文档可达 | ✅ 2026-07-14 |
| M1-2 | 完成 Tier 标注（本文 §3）并更新 API-GUIDE 决策树 | 用户只看 Tier-0/1 | ✅ 2026-07-14 |
| M1-3 | 实现 `test_contract_matrix` 骨架 + 至少 RTL/Growing/LocalArena | C01–C12 可跑 | ✅ 2026-07-14 |
| M1-4 | 门面瘦身 PR（移除 Tier-3 re-export） | test_mem 更新且绿 | ✅ 2026-07-14 |
| M1-5 | Scorecard 脚手架（SC1–SC4） | 可本地复现 | ✅ 2026-07-14 |

**出口**：门面变短；契约矩阵存在；默认路径文档与代码一致（Default 仍可暂为 RTL，但 Growing 入口清晰）。

### Month 2 — 默认堆与 Arena 深水区（P0/P1）

| ID | 工作 | 验收 |
|----|------|------|
| M2-1 | Growing：跨线程 free / thread-exit drain 回归固化 | `test_stability` + `test_concurrent` + matrix DefaultHeap cross-thread | ✅ 锁定门禁 2026-07-14 |
| M2-2 | Growing：scavenge / 归还 OS 策略 + 可观测字段 | SC5 基线 + GetHeapStats | ✅ 2026-07-14 |
| M2-3 | Default 双轨 D1→D2 | D1 ✅；D2 = DEBUG 链叠 `DefaultAllocator`（见 M2-5） | D1 ✅ / D2 ✅ 2026-07-15 |
| M2-4 | Arena 接入至少 1 条真实路径（compiler 或 HTTP） | 集成测试 | ✅ 2026-07-15 mem 侧 `test_stdlib_integration`（compiler/HTTP 模式）；源模块接线仍跨 lane |
| M2-5 | DEBUG 包装链 | [DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md) + `test_debug_wrap` | ✅ 设计+实现 2026-07-15 |

**出口**：Growing 可被选为默认；真实路径有证据；长跑 RSS 有数字。

### Month 3 — 运行时集成与超越点（P1）

| ID | 工作 | 验收 |
|----|------|------|
| M3-1 | Default 迁移 D3（文档/默认叙述） | README/API 以 DefaultHeap 为唯一热路径推荐 | ✅ 文档 2026-07-15；S5 后 API.md 对齐 |
| M3-2 | `MemStats` 统一导出 | `TMemStats` / `GetMemStats` + `test_get_mem_stats` | ✅ 2026-07-15 |
| M3-3 | 容器注入默认吃 process heap | S5：`DefaultAllocator`→Growing；collections 无改源 | ✅ 2026-07-15（`test_hashmap` + same-heap gates） |
| M3-4 | Windows/FreeBSD 契约与 Linux 同门禁 | 交叉/目标 gate | ✅ 2026-07-15 `test_mem_cross_os_compile_gate`（FORCE_HOST Windows+FreeBSD compile-only） |
| M3-5 | 文档重写为标准库手册口吻 | README/API-GUIDE 以 Tier 为纲 | ✅ 2026-07-15 |

**出口**：S1–S7 中至少 S1–S4、S6 可勾选；S5 有实质性进展。

---

## 9. 明确不做（本计划有效期内）

1. 无 consumer 的新 allocator Phase（28+）
2. 把 `MemSize`/`AllocAligned` 塞回 `IAllocator`
3. 扩大 ring buffer 为通用容器中心
4. 用测试数量替代契约矩阵
5. 为微基准牺牲跨线程 free / realloc 语义
6. 在 mem 内重新实现 platform 级同步原语语义

---

## 10. 验证纪律

每个落地 slice 至少：

```bash
git status --short --branch
make -C "$(git rev-parse --show-toplevel)" hygiene
# 相关 focused gates，例如：
make focused FOCUS=core/tests/nextpas.core.mem/test_contracts
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make focused FOCUS=core/tests/nextpas.core.mem/test_mem
make focused FOCUS=core/tests/nextpas.core.mem/test_default_allocator
# 触达 Growing/DefaultHeap/并发时：
make focused FOCUS=core/tests/nextpas.core.mem/test_stability
make focused FOCUS=core/tests/nextpas.core.mem/test_concurrent
make focused FOCUS=core/tests/nextpas.core.mem/scorecard
```

Ready 报告必须包含：

- 分支 / worktree / HEAD
- Tier 影响面（是否动门面）
- Contract / Scorecard 证据
- 禁止带入的临时文件清单

---

## 11. 首个落地切片建议（立即执行顺序）

按依赖从低到高：

1. **Doc**：本计划 + README/API-GUIDE 导航 — ✅
2. **Facade slim**：按 §3.5 移除 Tier-3 门面导出 + 修 test_mem — ✅
3. **Contract matrix**：RTL + Growing + LocalArena — ✅
4. **Scorecard SC1–SC4 脚手架** — ✅
5. **Default dual-track D1** — ✅ 过程式 GetMem→DefaultHeap(Growing)；DefaultAllocator 曾为 IAllocator/RTL
6. **Default D2 / S5 上层集成** — ✅ DEBUG 链 + DefaultAllocator→Growing IAllocator（collections 自动同堆）

第 2 步有编译面影响（任何 `uses nextpas.core.mem` 再写 Tier-3 类型名会挂）——本仓库外部引用近乎为零，风险可控，但仍需全量搜引用后改。

---

## 12. 变更日志

| 日期 | 变更 |
|------|------|
| 2026-07-14 | 初版：成功标准、Tier 分层、Default 迁移、契约矩阵、门面瘦身、Scorecard、90 天路线 |
| 2026-07-14 | **M1-4 门面瘦身落地**：`nextpas.core.mem` 仅 re-export Tier-0/1/2；移除 Tier-3 与 Growing 内部构建块（span/central/registry 等）门面导出；`test_mem` 改为按 Tier 断言可达性 |
| 2026-07-14 | **M1-3 契约矩阵落地**：`core/tests/nextpas.core.mem/test_contract_matrix` 覆盖 RTL C01–C10、C09（Arena SupportsRealloc=False）、Growing 原生 C01–C08、LocalArena C11–C12。**发现**：`TGrowingAllocator` 目前**不实现** `IAllocator`（`FreeMem`/`ReallocMem` 签名不同），Default 迁移前必须补 IAllocator 适配层或统一 API |
| 2026-07-14 | **M1-5 Scorecard 脚手架**：`core/tests/nextpas.core.mem/scorecard` 覆盖 SC1–SC4（Growing/System/LocalArena）；文档 [SCORECARD.md](SCORECARD.md)。Month 1 出口条件满足 |
| 2026-07-14 | **Default 双轨 D1**：`DefaultHeap`/`GetMem`→Growing 原生；`DefaultAllocator` 保持 IAllocator/RTL 注入面；Growing 增加 `TryBlockSize` 与 `ReallocMem(ptr,new)`；**不**经 IAllocator 适配器 |
| 2026-07-14 | **M2-1/M2-5**：contract_matrix 增加 DefaultHeap C01–C05/C07 + cross-thread free；Scorecard SC1 增加 `default_heap` 行；DEBUG 包装链设计见 [DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md)（只叠 IAllocator，不碰热路径） |
| 2026-07-14 | **回归门禁锁定**：`test_stability`、`test_concurrent`、`test_contract_matrix`、`scorecard` 为 Growing/DefaultHeap 变更必跑 |
| 2026-07-15 | **M2-5 DEBUG 包装链落地**：`nextpas.core.mem.debug_wrap`；`NEXTPAS_MEM_DEBUG` 惰性叠 fail/stats/tracking/sentinel 到 `DefaultAllocator`；`DefaultHeap` 不受影响；gate `test_debug_wrap` |
| 2026-07-15 | **M3-2 MemStats 统一导出**：`TMemStats` / `GetMemStats` 聚合 DefaultHeap（`TGrowingHeapStats`）+ 可选 DEBUG wrap 计数；门面 re-export；gate `test_get_mem_stats`（与既有 `test_mem_stats`/TAllocStats 分离） |
| 2026-07-15 | **M3-5 手册化 + Scorecard 重基线**：README 改写为 30 秒上手 / 双轨 / 决策树 / 契约 / 可观测 / DEBUG；API-GUIDE 对齐；SCORECARD RELEASE=1 数字刷新；S1–S4/S6–S7 文档勾选 |
| 2026-07-15 | **mem-only 规范化审计**：`ParseMemDebugEnv` Enabled 仅在已知 token 时为真（空白/纯分隔符不再误启用）；ARCHITECTURE/STDLIB/CONTRACT/DEBUG-WRAP/USABILITY 与双轨事实对齐 |
| 2026-07-15 | **可用性 P0 落地（mem-only）**：ERROR-POLICY 冻结；README/API-GUIDE 反例；契约矩阵扩 ChunkedArena/FixedSlab/LocalBlockPool；`test_usability_guardrails`（双轨+DEBUG 盲区+source-contract）；USABILITY-AUDIT superseded |
| 2026-07-15 | **S5 上层吃 DefaultHeap**：`TGrowingIAllocator`（`allocator.growing_ia`）作 `DefaultAllocator` / `ResolveAllocator(nil)` 根；DEBUG 链内层同；`GetRtlAllocator` 仍可显式；collections 无需改源即同堆；门禁 `test_default_allocator` / `test_debug_wrap` / `test_usability_guardrails` |
| 2026-07-15 | **可用性复评 post-S5**：[USABILITY-SCORE.md](USABILITY-SCORE.md) 权威分 **8.2 / HIGH**（7.3→8.2）；README S5 勾选；API.md / M3-3 对齐；guardrails 源契约盯 S5 同堆叙述 |
| 2026-07-15 | **SC6/SC7 + M2-4/M3-4**：Scorecard 补 compiler AST（VirtualArena）与 HTTP per-request（LocalArena p99）；`test_stdlib_integration` 锁定四模式；`test_mem_cross_os_compile_gate` Windows/FreeBSD FORCE_HOST；可用性复评见 [USABILITY-SCORE.md](USABILITY-SCORE.md) |
| 2026-07-15 | **HEAP_DEBUG opt-in**：`NEXTPAS_MEM_HEAP_DEBUG` 让过程式 GetMem/FreeMem 经 DefaultAllocator 诊断链（`DefaultHeap` 仍裸）；`TMemStats.HeapDebugEnabled`；gate `test_debug_wrap` / guardrails；可用性 **8.6** |
| 2026-07-15 | **SC8 + TryBlockSize 门面**：Scorecard SC8 对比 `FreeMem(ptr,size)` vs `FreeMem(ptr)`；过程式 `TryBlockSize` re-export；guardrails + docs；可用性 **8.7** |
| 2026-07-15 | **SC9 双轨税**：Scorecard SC9 `hot_heap` vs `plugin_ia` + `same_heap`；guardrail 同堆双向互释；可用性 **8.8** |
| 2026-07-15 | **冲 9.0**：`nextpas.core.http.mem` 产品接线 + facade re-export；`test_http_mem`；cross-OS 独立 FU + host runtime；FreeBSD `O_SYNC`/`pthread_setname` 修；可用性 **9.0** |
| 2026-07-15 | **冲 9.1**：`TLocalArenaAllocator`；`CreateArenaAllocator` 真正走 LocalArena 容量契约；`CreateVirtualArenaAllocator`；`nextpas.core.compiler.mem` + `test_compiler_mem`；可用性 **9.1** |
| 2026-07-15 | **冲 9.2**：`RequestArenaMiddleware` / `HttpRequestArenaOf` 真实 HTTP 生命周期；Arena 工厂契约写入 README/API-GUIDE + usability guardrails；rtl `TBumpArena` 标明继任；可用性 **9.2** |
| 2026-07-15 | **冲 9.3**：`HttpUseRequestArena`；hello 示例切 middleware 产品路径；stdlib P5 collections DefaultAllocator 同堆；可用性 **9.3** |
| 2026-07-15 | **冲 9.4**：`TCompilerUnitScope`；`unit_arena_demo` 示例；`FormatMemStats` 一行诊断；可用性 **9.4** |
| 2026-07-15 | **冲 9.5**：`TryGetMem`/`TryFreeMem`/`TryArenaAlloc` ERROR-POLICY 可操作面；`http_server_options_demo` RequestArena；可用性 **9.5** |
| 2026-07-15 | **冲 9.6**：`HttpWithRequestArena` / `NewHttpServerWithRequestArena` 服务端根接线；`HttpFormatProcessMemStats`；hello `/memstats`；可用性 **9.6** |
| 2026-07-15 | **冲 9.7**：`THttpServerOptions.WithRequestArena` 服务内核 carrier；`HttpRequestAllocatorOf`；hello 走 options 路径；可用性 **9.7** |
| 2026-07-15 | **冲 9.8**：H1 连接级 RequestArena（`InvokeHandler`/`HttpAttach`）+ registry 透传 + `TCompilerSessionScope`；可用性 **9.8** |
| 2026-07-15 | **冲 9.9**：H2 连接级 RequestArena + `TCompilationSession` mem 生命周期（`MemAlloc`）；可用性 **9.9** |
| 2026-07-15 | **冲 10.0**：`AnalyzeSyntax`/`ResolveUnits` `UnitBegin`+`MemAlloc` phase scratch + `UnitEnd`；`MemUnitCount`；`rebuild-compiler.sh` 对齐 main；可用性 **10.0** |
| 2026-07-15 | **冲 10.0+ AST**：`TGreenTree.Create(IAllocator)` + session `FAstAllocator`；`ReallocElements` 在 `SupportsRealloc=False` 时 alloc+copy；`TVec` 可在 VirtualArena 增长 |
| 2026-07-15 | **冲 10.0++ sema/scratch**：`FScratchAllocator` 供 `TUnitResolver` 依赖树与 `TSemanticAnalyzer` 工作 TVec；`MemFormatSessionStats`；AnalyzeSemantics/LowerToMir UnitBegin |
| 2026-07-15 | **冲 10.0+++ HIR/MIR**：`THIRBuilder`/`THirToMirLowering` 接 `FScratchAllocator`；`FValueMap`/`pending cleanup` TVec |
| 2026-07-16 | **冲 10.0++++ backend**：`np_backend_plan` `PhaseScratch` 接真实 LLVM HIR/MIR；`FBlockNames`/`FBlockIds` → TVec |
| 2026-07-16 | **冲 10.0+++++ allocas**：`FAllocas` → `THirAllocaVec` on phase allocator；`GetPtr` 就地更新 |
| 2026-07-16 | **冲 10.0++++++ builder tables**：globals/fwd/intf 工作表全迁 TVec；`RegisterGlobal`/`ClearGlobalRefs` |
| 2026-07-16 | **冲 10.0+++++++ LLVM emitter**：emit lines/refs/str/debug TVec + backend `PhaseScratch` |
| 2026-07-16 | **冲 10.0++++++++ MIR→LLVM**：`TMirToLlvmTranslator` 输出行表 TVec + PhaseScratch / FScratchAllocator |
| 2026-07-16 | **冲 10.0+++++++++ HIR printer**：`THIRPrinter` 行表 TVec + session FScratchAllocator |
| 2026-07-16 | **冲 10.0++++++++++ sema queues**：`FGenericWorkQueue`/`FCompilerProcNames` TVec on FScratchAllocator |
| 2026-07-16 | **冲 10.0+++++++++++ sema imports**：导入单元 trees/owners TVec；overload/HIR ctx 借用引用 |
| 2026-07-16 | **冲 10.0++++++++++++ sema pending sig**：`FPendingSignatures` TVec on FScratchAllocator |
| 2026-07-16 | **冲 10.0+++++++++++++ MIR pass mgr**：`TMirPassManager` pass registry TVec + PhaseScratch |
| 2026-07-16 | **冲 10.0++++++++++++++ MIR DCE/CSE**：`UsedRegs`/`CseTable` TVec + `AManager.Allocator` |
| 2026-07-16 | **冲 10.0+++++++++++++++ MIR pass 工作表**：deadarg/escape/licm/inline TVec + Allocator 透传 |
| 2026-07-16 | **冲 10.0++++++++++++++++ sema procedure bodies**：`FProcedureBodies` TVec + overload/ownership/HIR ctx 借用 |
| 2026-07-16 | **冲 10.0+++++++++++++++++ runtime vars**：`TSemaRuntimeVarRegistry` 全 string 表 TVec + FAllocator |
| 2026-07-16 | **冲 10.0++++++++++++++++++ HIR FSaved 快照**：`FSavedAllocas`/`FSavedBlockNames`/`FSavedBlockIds` TVec + SnapshotWorkTables |
| 2026-07-16 | **冲 10.0+++++++++++++++++++ HIR expr stack**：`TExprStack` Values/Types + ParseIntExpr 行表 TVec |
| 2026-07-16 | **冲 10.0++++++++++++++++++++ resolver/verifier**：resolution stack + HIR verifier FErrors/Seen/Defs TVec |
| 2026-07-16 | **冲 10.0+++++++++++++++++++++ sema validation**：CandidateNames/case SeenValues TVec on FAllocator |
| 2026-07-16 | **冲 10.0++++++++++++++++++++++ preprocessor**：条件栈 + 输出 token TVec；session/resolver/sema 注入 allocator |
| 2026-07-16 | **冲 10.0+++++++++++++++++++++++ unit graph**：resolved units/edges + topo work TVec；resolver 注入 FNodeAllocator |
| 2026-07-16 | **冲 10.0++++++++++++++++++++++++ define table**：FEntries TVec；session/resolver/sema 注入 allocator |
| 2026-07-16 | **冲 10.0+++++++++++++++++++++++++ search/root/include**：TSearchPathSet + FRootIndexes + include paths TVec |
| 2026-07-16 | **冲 10.0++++++++++++++++++++++++++ … product tables**：session/跨 phase 产品表 + type-metadata nested + HIR/MIR nested + lexer trivia → 默认堆 TVec；ELF 卫星单元 |
| 2026-07-16 | **冲 product-table dual-track 收敛**：intentional keepers 入 `USABILITY-SCORE`；`np_semantic_model` 禁止 nested type-meta specialize；主线不再以固定 arity / package DTO 整树为 mem 阻塞 |
| 2026-07-16 | **product-table dual-track CLOSED**：residual audit 清零可迁 nested；disk cache DTO/local scratch 入 keepers；mem 下一刀离开 dynarray→TVec 产品表冲刺 |
| 2026-07-16 | **冲 session/unit FormatStats**：`TCompilerSessionScope`/`TCompilerUnitScope` 一行诊断 + `CompilerFormat*Stats`；`MemFormatSessionStats` 复用 core 行；诊断可用性 9.6 |
| 2026-07-16 | **冲 doctor/ops mem stats**：build/query 投影 `mem-session-stats`←`MemFormatSessionStats`；doctor `mem-process-stats`←`FormatMemStats`；envelope JSON；诊断可用性 9.8 |
| 2026-07-16 | **冲 arena 契约回归**：`test_compiler_mem` 锁 AST/scratch 独立、SessionPeak、FreeMem no-op、entry-owned nested；guardrails 钉 `ResetScratchAllocator`/`ResetSyntaxState` |
| 2026-07-16 | **冲 HEAP_DEBUG/插件轨体验**：`FormatMemStats` 补 `debug_allocs`/`debug_frees`；门面 `IsMemHeapDebugEnabled`；guardrails 锁插件轨 vs 过程式轨；诊断 9.9 |
| 2026-07-16 | **冲 CI 常态化 rebuild-compiler**：`scripts/stage0-fpc-flags.sh` 单源；root CI tooling→rebuild→verify；verify smoke/doctor 钉 mem-session/process-stats |
| 2026-07-16 | **冲 HEAP_DEBUG CI 联调配方**：`scripts/stage0-heap-debug-env-recipe.sh`；`make stage0-heap-debug-recipe`；CI rebuild 后跑；verify 复用；诊断 10 |
| 2026-07-16 | **lane 收口**：默认 focused gate → `test_usability_guardrails`（`lane-focused LANE=mem`）；`docs/worktrees.md` 矩阵对齐；USABILITY-SCORE 待办收敛为 CLOSED 主线 + 独立演进项 |

## Lane Ready 证据包（收口后）

默认 first evidence：

```bash
make lane-focused LANE=mem
# ≡ make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
```

按表面追加：

| 表面 | 额外 evidence |
|------|----------------|
| compiler session/product tables / arena | `make focused FOCUS=core/tests/nextpas.core.compiler/test_compiler_mem` |
| DEBUG wrap 链 | `make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap` |
| doctor mem-process-stats / env 双轨 | `make stage0-heap-debug-recipe`（需先 `make rebuild-compiler`） |
| HTTP request arena | `make focused FOCUS=core/tests/nextpas.core.http/test_http_mem` |
| mapping / platform compile | `make focused FOCUS=core/tests/nextpas.core.mem/test_memory_map_compile_gate` |
| tooling / CI wiring | `make test-tooling` |

**禁止带入 landing**：临时 `task_plan.md` / chat 笔记；未验证的 keepers 反转；package DTO 整树迁移。
