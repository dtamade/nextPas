# nextpas.core.mem — 双编译器可行性审查

> 审查日期: 2026-06-29
> 审查范围: 49 个 mem 模块源文件 (core/src/nextpas.core.mem*.pas)
> 目标: 验证 mem 模块能否在 FPC trunk 和 nextPas stage0 (LLVM) 下同时编译运行

## 总览

| 状态 | 文件数 | 占比 |
|------|--------|------|
| GREEN — 无需改动 | 38 | 78% |
| RED — 编译器 blocker | 8 | 16% |
| YELLOW — 需关注 | 3 | 6% |

**核心结论: 所有 RED 均为编译器能力缺口，mem 模块架构设计正确。**

## 1. 依赖链解析 — GREEN

13 个外部 `nextpas.core.*` 依赖全部存在，有完整 `implementation` 段：

| 依赖 | 行数 | 被谁用 |
|------|------|--------|
| nextpas.core.base | 677 | base, 多数文件 |
| nextpas.core.base.utils | 138 | 多数文件 |
| nextpas.core.errors | 72 | allocator.crt/rtl, rwlock, slab |
| nextpas.core.exception | 602 | error |
| nextpas.core.math | 939 | utils, stack_pool |
| nextpas.core.atomic | 4239 | blockpool.sharded |
| nextpas.core.os.env | 236 | mimalloc.loader |
| nextpas.core.path | 220 | mimalloc.loader |
| nextpas.core.platform.sync | 1553 | mutex, rwlock, allocator.crt/rtl, mimalloc |
| nextpas.core.platform.thread | 691 | mutex, rwlock, blockpool.sharded, pool.slab* |
| nextpas.core.platform.mmap | 846 | arena.virtual, memory_map |
| nextpas.core.platform.dl | 214 | mimalloc, mimalloc.loader |
| nextpas.core.platform.memory | 411 | arena.virtual, secure |

无循环依赖。

## 2. 平台抽象层 — GREEN

4 个平台单元都有完整实现（非 stub）：

- `platform.sync`: `platform_mutex_init/lock/unlock`, `platform_rwlock_*`, `platform_condvar_*`
- `platform.thread`: `platform_thread_create/join/self/id`, `platform_tls_*`, `platform_cpu_count`
- `platform.mmap`: `platform_mmap_create_anonymous`, `platform_mmap_close`
- `platform.dl`: `platform_dl_open/sym/close/error`

底层用 POSIX 原语 (pthread_mutex, mmap, dlopen)，nextPas 只要能发 `external` 声明就能用。

## 3. Blocker 清单

### Blocker 1: System.pas stub 缺少基础函数声明

`units/linux-x86_64/System.pas` 未声明: `GetMem`, `FreeMem`, `AllocMem`, `ReallocMem`, `Move`, `FillChar`, `CompareByte`, `CompareWord`, `CompareDWord`。

裸调用 `FillChar()`/`Move()` 可以（编译器识别为 builtin），但 `System.GetMem(ASize)` 限定调用会失败。

**影响文件:** `allocator.rtl.pas` (4 调用), `utils.pas` (5 调用)
**修复:** 补 stub 声明，映射到 nextPas runtime 函数
**复杂度:** 低

### Blocker 2: Interlocked* intrinsics 不完整

nextPas sema 识别 `InterlockedCompareExchange`/`InterlockedIncrement`/`InterlockedDecrement`，但缺失:
- `InterlockedExchange` — mutex.pas, rwlock.pas, pool.fixed_slab.pas
- `InterlockedExchangeAdd64` — arena.virtual.pas
- `InterlockedCompareExchange64` — arena.virtual.pas

且 LLVM emitter 对所有 interlocked 操作无 codegen 路径。

**影响文件:** mutex.pas, rwlock.pas, arena.virtual.pas, pool.fixed_slab.pas
**修复:** sema 补 builtin + LLVM emitter 实现 cmpxchg/atomicrmw
**复杂度:** 中

### Blocker 3: threadvar 无 TLS codegen

Parser 对 `threadvar` 和 `var` 一视同仁 (gnkVarSection)，LLVM emitter 发出 `@g_X = internal global` 无 `thread_local` 属性。运行时所有线程共享同一变量。

**影响文件:** arena.thread.pas (2 TLS 变量), blockpool.sharded.pas (4 TLS 变量)
**修复:** Parser 区分 threadvar，emitter 加 `thread_local` 属性
**复杂度:** 低

### Blocker 4: nextpas.core.atomic 内联 asm 被跳过

`nextpas.core.atomic.pas` (4239 行) 所有 CAS/fetch-add/exchange 用 x86 内联 asm。nextPas parser 跳过 `asm...end` 块（只进 cursor 不生成代码），函数体为空。

**影响文件:** blockpool.sharded.pas (间接依赖)
**修复:** 迁移 atomic 模块到 LLVM atomic intrinsics
**复杂度:** 高

### Blocker 5: external 函数声明不生成 LLVM declare

LLVM emitter 对 `IsExternal=True` 的函数直接 Exit，不生成 LLVM `declare` 语句。

**影响文件:** allocator.crt.pas (malloc/free), utils.pas (memcpy/memmove)
**修复:** emitter 对 external 函数生成 LLVM `declare` + calling convention 映射
**复杂度:** 中

## 4. 不受影响的维度

| 维度 | 状态 | 说明 |
|------|------|------|
| 内存布局/ABI | GREEN | 无 `{$IFDEF CPU64}`，无内联 asm，用 `SizeOf(Pointer)` 自适应 |
| 异常处理 | GREEN | 异常类自包含于 nextpas.core，不依赖 FPC 异常层级 |
| FPC RTL 显式导入 | GREEN | 0 处（刚清理完 6 个 TRTLCriticalSection） |
| FPC RTL 隐式引用 | GREEN | 仅编译器内建函数（Interlocked*/System.Move/GetMem） |

## 5. 文件分类

### GREEN (38 文件, 78%)

allocator.arena, allocator.base, allocator.callback, allocator.fallback, allocator.foundation,
allocator.leak_check, allocator.mimalloc.loader, allocator.mmap, allocator.pas, allocator.tracking,
arena.base, arena.chunked, arena.concurrent, arena.intf, arena.local, arena.pas, base,
blockpool.concurrent, blockpool.growable, blockpool.pas, default, error, intf,
mapped_slab_pool, memory_map, pas (facade), pool.allocator, pool.base, pool.fixed.growable,
pool.fixed.pas, pool.memory_pool, pool.object_pool, pool.pas, pool.sizeclass,
pool.slab.concurrent, pool.slab.pas, pool.slab.sharded, ring_buffer, secure, stack_pool

### RED (8 文件, 16%)

| 文件 | Blocker |
|------|---------|
| allocator.rtl.pas | #1 System.GetMem/FreeMem/AllocMem/ReallocMem |
| utils.pas | #1 System.Move/CompareByte + #5 external memcpy/memmove |
| mutex.pas | #2 InterlockedCompareExchange/Exchange |
| rwlock.pas | #2 InterlockedCompareExchange/Exchange |
| arena.virtual.pas | #2 InterlockedCompareExchange64/ExchangeAdd64 |
| pool.fixed_slab.pas | #2 InterlockedCompareExchange/Exchange |
| arena.thread.pas | #3 threadvar |
| blockpool.sharded.pas | #3 threadvar + #4 nextpas.core.atomic |

### YELLOW (3 文件, 6%)

| 文件 | 问题 |
|------|------|
| allocator.crt.pas | #5 external 'c' name 'malloc' |
| allocator.mimalloc.pas | #5 external decls (仅 NEXTPAS_CORE_MIMALLOC_STATIC) |
| secure.pas | UniqueString 不在 builtin 列表 |

## 6. 修复路线图

| 阶段 | 工作 | 解锁文件 | 覆盖率 |
|------|------|----------|--------|
| 当前 | — | — | 78% (38/49) |
| Phase 1 | #1 System.pas stub + #5 external decl + #3 threadvar | +5 | 88% (43/49) |
| Phase 2 | #2 Interlocked* intrinsics + codegen | +3 | 94% (46/49) |
| Phase 3 | #4 atomic asm → LLVM intrinsics | +1 | 98% (47/49) |
| Phase 4 | secure.pas UniqueString + 遗留 | +2 | 100% (49/49) |
