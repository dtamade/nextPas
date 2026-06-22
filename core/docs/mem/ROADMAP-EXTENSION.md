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

**目标**: SSE2/SSSE3 加速内存操作，热路径直接收益。

**设计**:
- `core/src/nextpas.core.mem.simd.pas` — SIMD 内存操作
  - `SimdFillChar(P, Count, Value)` — SSE2 零填充 (64B/次)
  - `SimdMove(Src, Dst, Count)` — SSE2 拷贝 (前向/后向)
  - `SimdCompare(A, B, Count): Boolean` — SSE2 比较
  - 运行时 CPUID 检测，non-SSE2 fallback 到 RTL
- 集成到 TVirtualArena.AllocZeroed / TLocalArena.AllocZeroed
- Prefetch hints 在 arena 批量分配时使用

**文件**:
- `core/src/nextpas.core.mem.simd.pas`
- `core/tests/nextpas.core.mem/test_mem_simd/...`

**依赖**: platform.info (CPUID detection), base (TBytes/Pointer)

---

## 时间线

| Phase | 预估工作量 | 依赖 |
|-------|-----------|------|
| 1. Thread-Local Arena | ~3h | 无 |
| 2. Size-Class Slab | ~3h | 无 |
| 3. Fallback Chain | ~2h | Phase 1+2 可选集成 |
| 4. SIMD memset | ~3h | platform.simd 已有 SSE2 |

## 测试策略

每个 Phase:
1. 独立测试套件 (功能 + 边界 + 并发 + 泄漏)
2. Codex 审查
3. 全套 mem 测试回归 (270+ tests)
4. 基准对照 (Go/Rust)
