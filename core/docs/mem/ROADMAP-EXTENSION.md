# mem 模块扩展路线图

## Phase 1: Thread-Local Arena (TLA)

**目标**: 每线程独享 Arena，零锁热路径，线程退出自动回收。

**设计**:
- `TThreadArenaManager` — 管理线程 Arena 池
  - threadvar 存储 per-thread Arena 指针
  - 全局池 (TRTLCriticalSection 保护) 回收空闲 Arena
  - Arena 是 TLocalArena (固定容量 bump pointer)
  - Get → TLS hit → 0ns; miss → pool hit → ~100ns; miss → new → ~1μs
- `TThreadArena` — 轻量 record 包装器 (一个 Pointer 大小)
  - `.Alloc` / `.AllocZeroed` / `.Reset` / `.SaveMark` / `.RestoreToMark`
  - `.DrainTLS` — 手动归还 Arena 到池
- 自动 DrainTLS: 支持 FPC threadvar cleanup hook
- 配置: Arena 容量 (默认 1MB), 最大池大小 (默认 CPU*2)

**文件**:
- `core/src/nextpas.core.mem.arena.thread.pas` — 实现
- `core/tests/nextpas.core.mem/test_thread_arena/test_thread_arena.lpr` — 测试
- `core/tests/nextpas.core.mem/test_thread_arena/Makefile`

**依赖**: mem.arena.local, mem.arena.base, platform.sync (TRTLCriticalSection)

---

## Phase 2: Size-Class Slab Pool

**目标**: 小对象 O(1) 分配释放，对标 jemalloc/tcmalloc。

**设计**:
- `TSizeClassPool` — 7 个大小类 (8/16/32/64/128/256/512 字节)
- 每个类维护一个 intrusive free list (next pointer 嵌入空闲块)
- 页级后备: 4KB 页从 GetMem 获取，切分为固定大小 slots
- O(1) Alloc: pop from free list; O(1) Free: push to free list
- 页耗尽时自动分配新页
- Reset: 批量回收所有页到 free list

**文件**:
- `core/src/nextpas.core.mem.pool.sizeclass.pas`
- `core/tests/nextpas.core.mem/test_sizeclass_pool/...`

**依赖**: mem.base, mem.error

---

## Phase 3: Fallback Allocator Chain

**目标**: Arena OOM 时自动降级到后备分配器。

**设计**:
- `TFallbackAllocator` — IAllocator 包装器
  - 主分配器 (Arena-based) + 后备分配器 (heap/RTL)
  - GetMem: try primary → EOutOfMemory → fallback
  - FreeMem: 记录来源 → free from correct allocator
  - 可选: OOM 事件回调
- `TFallbackArena` — IArena 包装器
  - Arena OOM 时降级到 IAllocator

**文件**:
- `core/src/nextpas.core.mem.allocator.fallback.pas`
- `core/tests/nextpas.core.mem/test_fallback_allocator/...`

**依赖**: mem.interfaces (IAllocator), mem.arena.intf (IArena)

---

## Phase 4: SIMD memset/memcpy 优化

**状态**: 已推迟 — Codex 架构审查结论 (2026-06-21)

**结论**: 不在 mem 模块内创建独立 SIMD 模块。

理由:
1. FPC `FillChar`/`Move` 已高度优化 (REP STOSB / SSE2/AVX2 内联)，mem.simd 无法做得更好
2. Arena `AllocZeroed` 热路径没有额外 SIMD 优化空间
3. `nextpas.core.simd.memutils` 已有 `AlignedMemFill`/`AlignedMemCopy`/`Prefetch`
4. 自建 CPUID 违反不重复原则 (`simd.cpuinfo` 已完整覆盖 x86/ARM/RISC-V)
5. mem 和 simd 同属 L0，单向依赖合法，但 simd.memutils 当前 API 不匹配 Arena 场景

**未来路线**:
- `nextpas.core.simd.memutils` 增加 `SimdFillZero(ptr, size)` (不带 alignment 参数)
- 大块清零 (>L2 cache) 用 non-temporal store
- mem 模块作为消费者调用

**依赖**: 未来 nextpas.core.simd.memutils 扩展

---

## 时间线

| Phase | 预估工作量 | 依赖 |
|-------|-----------|------|
| 1. Thread-Local Arena ✅ | done | 无 |
| 2. Size-Class Slab ✅ | done | 无 |
| 3. Fallback Chain ✅ | done | Phase 1+2 可选集成 |
| 4. SIMD memset | **推迟** | 等 simd.memutils 扩展 |

## 测试策略

每个 Phase:
1. 独立测试套件 (功能 + 边界 + 并发 + 泄漏)
2. Codex 审查
3. 全套 mem 测试回归 (270+ tests)
4. 基准对照 (Go/Rust)
