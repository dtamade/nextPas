# mem 标准库质量计划

**状态**: Active
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
- [USABILITY-AUDIT.md](USABILITY-AUDIT.md) — 可用性审计

---

## 1. 成功定义（超过 Go/Rust 的可验收标准）

不是“拥有更多分配器类”，而是同时满足：

| # | 标准 | 验收信号 |
|---|------|----------|
| S1 | **默认路径无聊且正确** | 新人 10 分钟会选；99% 场景只用 Default + Arena + Pool |
| S2 | **契约全平台一致** | Tier-0/1 全部通过同一 Contract Matrix |
| S3 | **性能可信** | Scorecard 7 项持续对照 glibc / Go / Rust，不全靠 ns/op |
| S4 | **诊断零成本默认、一键打开** | DEBUG/env 可叠 Sentinel/Leak/Stats，不改业务代码 |
| S5 | **运行时集成** | 至少 2 条上层热路径（compiler / HTTP 或等价）默认吃 mem |
| S6 | **确定性生命周期优势** | Arena/Pool 在延迟敏感场景 p99 优于 GC 语言对照 |
| S7 | **API 面小、长期兼容** | 门面只暴露 Tier-0 + 精选 Tier-1；Experimental 无兼容承诺 |

**不做成功标准**：allocator 文件数、测试目录数、roadmap phase 序号。

---

## 2. 现状审计摘要（2026-07-14）

| 指标 | 现状 | 判断 |
|------|------|------|
| 源文件 | ~105 | 过大，需分层而非继续膨胀 |
| 测试目录 | ~145 | 覆盖面广，但“每类 7 测”不等于契约一致 |
| `IAllocator` | 5 方法 + Traits | 接口形状正确，应冻结 |
| 门面 re-export | 几乎全量 allocator | **失败点**：产品感像博物馆 |
| `DefaultHeap` / 过程式 `GetMem` | **Growing 原生**（D1 已切） | 热路径无 IAllocator |
| `DefaultAllocator` | **RTL (`IAllocator` 注入面）** | 组合器/诊断后端，非热路径 |
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
| `DefaultAllocator` / `GetMem`/`FreeMem`/... | `mem` / `mem.default` | 全局默认 |
| `CreateDefaultArena` / `CreateChunkedArena` | `mem` | 工厂 |
| `EAllocError` 族 | `mem.error` | 错误词汇 |
| `SecureZero*` | `mem.secure` | 安全清零 |

#### 默认堆与后端

| 符号 | 单元 | 角色 | 备注 |
|------|------|------|------|
| `TGrowingAllocator` | `allocator.growing` | **目标默认堆** | TLS + central；性能主轴 |
| `TRtlAllocator` | `allocator.rtl` | FPC RTL 后端 | 当前 Default；保留为 fallback/bootstrap |
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
| `TAllocSnapshot` / `TAllocHistogram` / `TAllocStatsCollector` | `mem.stats` | MemStats 原料 |
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

目标体验（后续实现）：

```text
NEXTPAS_MEM_DEBUG=sentinel,leak,stats
```

等价于自动包装 `DefaultAllocator`，业务代码无感。

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
         否 → DefaultAllocator（目标：Growing）
诊断？ → 包装 Tracking / Sentinel / Guard（或 env 一键）
OOM/预算？ → Fallback / Bounded / Budget / OomHandler
```

### 4.2 Default 双轨（关键 slice）

**设计原则**（与 IAllocator 性能立场一致）：

| 轨道 | API | 实现 | 用途 |
|------|-----|------|------|
| **热路径** | `DefaultHeap` / 过程式 `GetMem`·`FreeMem`·`AllocMem`·`ReallocMem` | `TGrowingAllocator` 原生（直接调用） | 框架默认堆 |
| **插件面** | `DefaultAllocator: IAllocator` | 当前 RTL | 组合器/诊断/外部注入 |

**不**把 Growing 包成 `IAllocator` 再当默认热路径。

分阶段：

| 阶段 | 行为 | 门槛 | 状态 |
|------|------|------|------|
| D0 | 过程式 GetMem 也走 RTL IAllocator | — | 历史 |
| D1 双轨 | 过程式 GetMem → `DefaultHeap`（Growing）；`DefaultAllocator` 仍 RTL | contract + default tests | ✅ 2026-07-14 |
| D2 可切换 | env 可选把插件面/对照后端切到 Growing 适配（若需要） | 上层 1 条路径 | pending |
| D3 固化文档 | 示例/上层全部按 DefaultHeap | Scorecard + consumer | pending |
| D4 | 可选：删除误导性“Default=RTL”旧说法 | 无回归 | pending |

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

| 实现 | C01–C05 | C06 OOM | C07 Zero | C08 Thread | C09 NoRealloc | C10 Leak | C11 Align | C12 Mark |
|------|---------|---------|----------|------------|---------------|----------|-----------|----------|
| RTL (`IAllocator`) | PASS | PASS (via Fail) | PASS | PASS smoke | N/A | PASS (Track) | N/A | N/A |
| `TVirtualArenaAllocator` | — | — | — | — | PASS | — | — | — |
| `TGrowingAllocator` (native) | PASS* | — | PASS* | PASS smoke | N/A | PASS* | N/A | N/A |
| `TLocalArena` | N/A | N/A | N/A | N/A | N/A | N/A | PASS | PASS |

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
| M2-3 | Default 双轨 D1→D2 | D1 ✅；D2 改为 DEBUG 链（见 M2-5），不再把热路径切回 RTL | D1 ✅ / D2→M2-5 |
| M2-4 | Arena 接入至少 1 条真实路径（compiler 或 HTTP） | 集成测试 | pending |
| M2-5 | DEBUG 包装链设计（不一定一次做完实现） | [DEBUG-WRAP-DESIGN.md](DEBUG-WRAP-DESIGN.md) | ✅ 设计 2026-07-14 |

**出口**：Growing 可被选为默认；真实路径有证据；长跑 RSS 有数字。

### Month 3 — 运行时集成与超越点（P1）

| ID | 工作 | 验收 |
|----|------|------|
| M3-1 | Default 迁移 D3（若门槛满足） | 默认 Growing |
| M3-2 | `MemStats` 统一导出 | 一函数/一结构体 |
| M3-3 | 容器/字符串或 collections 注入 IAllocator（最小切片） | 跨模块报告 |
| M3-4 | Windows/FreeBSD 契约与 Linux 同门禁 | 交叉/目标 gate |
| M3-5 | 文档重写为标准库手册口吻 | README/API-GUIDE 以 Tier 为纲 |

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
5. **Default dual-track D1** — ✅ 过程式 GetMem→DefaultHeap(Growing)；DefaultAllocator 仍为 IAllocator/RTL
6. **Default D2 / 上层集成** — next

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
