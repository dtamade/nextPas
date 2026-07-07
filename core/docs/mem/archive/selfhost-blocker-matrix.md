# mem 自举 Blocker Matrix

> **状态**: 已归档 — A1 已完成，自举路径待 C6-A allocator 推进后重新评估。当前活跃路线图为 ROADMAP-v8.md。

> 日期：2026-06-25
> 基线：51 个源码单元
> 状态：A1 完成

## 统计

| 障碍类别 | 文件数 | Owner Lane | C6-A 前可推进 |
|----------|--------|------------|--------------|
| interface/refcount | 27 | 编译器接口支持 | ❌ 核心阻塞 |
| platform/runtime | 19 | FPC stub + runtime | ✅ A2 可推进 |
| external/ABI | 5 | 编译器 FFI 支持 | ❌ 核心阻塞 |
| TLS/threadvar | 2 | 编译器 TLS 支持 | ❌ 核心阻塞 |
| generic + reference-to | 2 | 编译器泛型+匿名函数 | ❌ 核心阻塞 |
| 无障碍 | 3 | — | ✅ 可编译 |

> 注：一个文件可能有多个障碍类别，总数 > 51。

## 无障碍叶子节点（自举起点）

| 文件 | 依赖 | 说明 |
|------|------|------|
| `nextpas.core.mem.base.pas` | 无 | 纯常量/类型定义 |
| `nextpas.core.mem.arena.base.pas` | `mem.base` | 纯 record 类型 |

## 详细 Blocker Matrix

### TLS/threadvar (2 文件)

| 文件 | 具体特征 | 最小复现 |
|------|----------|----------|
| `arena.thread.pas` | `threadvar TLSCurrentArena: TLocalArena` + `TLSCurrentManager: Pointer` | `threadvar` |
| `blockpool.sharded.pas` | 4 个 `threadvar` 变量 (cache/route/node/local) | `threadvar` |

**Owner**: 编译器 TLS 支持（C6-A 依赖）

### generic + reference-to (2 文件)

| 文件 | 具体特征 | 最小复现 |
|------|----------|----------|
| `pool.object_pool.pas` | `generic TObjectPool<T: TObject>` + 3 个 `reference to` 类型 | `generic` + `reference to` |
| `ring_buffer.pas` | `generic TTypedRingBuffer<T>` | `generic` |

**Owner**: 编译器泛型 + 匿名函数支持

### interface/refcount (27 文件)

| 文件 | 具体特征 |
|------|----------|
| `mem.intf.pas` | `IAllocator = interface` + GUID |
| `pool.base.pas` | `IPool = interface` + GUID |
| `pool.memory_pool.pas` | `IMemoryPool = interface(IPool)` |
| `arena.intf.pas` | `IArena = interface` + TGUID |
| `allocator.base.pas` | `TAllocator = class(TInterfacedObject, IAllocator)` |
| `allocator.rtl.pas` | `TRtlAllocator = class(TAllocator)` + `TRTLCriticalSection` |
| `allocator.crt.pas` | `TCrtAllocator = class(TAllocator)` + `TRTLCriticalSection` |
| `allocator.mimalloc.pas` | `TMimallocAllocator = class(TAllocator)` + `TRTLCriticalSection` |
| `allocator.mmap.pas` | `TMmapAllocator = class(TAllocator)` + `TRTLCriticalSection` + `packed record` |
| `allocator.tracking.pas` | `TTrackingAllocator = class(TAllocator)` + `TRTLCriticalSection` |
| `allocator.fallback.pas` | `TFallbackAllocator = class(TInterfacedObject, IAllocator)` |
| `allocator.leak_check.pas` | 继承 `TTrackingAllocator` |
| `arena.local.pas` | `TLocalArena = class(TInterfacedObject, IArena)` |
| `arena.chunked.pas` | `TChunkedArena = class(TInterfacedObject, IArena)` |
| `arena.concurrent.pas` | `TArenaConcurrent = class(TInterfacedObject, IArena)` |
| `blockpool.pas` | `TBlockPool = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)` |
| `blockpool.concurrent.pas` | `TBlockPoolConcurrent = class(TInterfacedObject, IBlockPool)` |
| `blockpool.growable.pas` | `TGrowingBlockPool = class(TInterfacedObject, IBlockPool)` |
| `blockpool.sharded.pas` | `TShardedBlockPool = class(TInterfacedObject, IBlockPool)` + threadvar |
| `pool.fixed.pas` | `TFixedPool = class(TInterfacedObject, IPool)` |
| `pool.fixed.growable.pas` | `TGrowingFixedPool = class(TInterfacedObject, IPool)` |
| `pool.fixed_slab.pas` | `TFixedSlabPool = class(TInterfacedObject, IFixedSlabPool, IMemoryPool, IAllocator)` |
| `pool.allocator.pas` | `TPoolAllocator = class(TInterfacedObject, IAllocator)` |
| `pool.object_pool.pas` | `generic TObjectPool<T: TObject> = class(TInterfacedObject, IPool)` |
| `pool.slab.pas` | `TSlabPool = class(TInterfacedObject, IMemoryPool, IAllocator)` |
| `pool.slab.concurrent.pas` | `TSlabPoolConcurrent = class(TInterfacedObject, IMemoryPool, IAllocator)` |
| `pool.slab.sharded.pas` | `TSlabPoolSharded = class(TInterfacedObject, IMemoryPool, IAllocator)` |

**Owner**: 编译器接口支持（COM 风格 interface + TInterfacedObject 引用计数）

### external/ABI (5 文件)

| 文件 | 具体特征 | 最小复现 |
|------|----------|----------|
| `allocator.crt.pas` | `cdecl external` msvcrt malloc/calloc/realloc/free | `cdecl external` |
| `allocator.mimalloc.pas` | `cdecl; external` mimalloc 函数 | `cdecl external` |
| `allocator.mmap.pas` | `TMemoryMapBlockHeader = packed record` | `packed record` |
| `mapped_slab_pool.pas` | 3 个 `packed record` | `packed record` |
| `utils.pas` | `memcpy`/`memmove` via `cdecl external` | `cdecl external` |

**Owner**: 编译器 FFI 支持（cdecl external + packed record layout）

### platform/runtime (19 文件)

| 文件 | 依赖的 platform/runtime 单元 |
|------|------------------------------|
| `mutex.pas` | `platform.sync` + `platform.thread` |
| `rwlock.pas` | `platform.sync` + `platform.thread` |
| `memory_map.pas` | `platform.mmap` + `base.utils` |
| `arena.virtual.pas` | `platform.mmap` + `platform.memory` |
| `secure.pas` | `platform.memory` + `base` |
| `allocator.mimalloc.loader.pas` | `platform.dl` + `os.env` + `path` |
| `blockpool.sharded.pas` | `platform.thread` + `atomic` |
| `pool.slab.sharded.pas` | `platform.thread` |
| `error.pas` | `exception` |
| `utils.pas` | `base` + `math` |
| `allocator.rtl.pas` | `System.GetMem`/`System.FreeMem` + `TRTLCriticalSection` |
| `allocator.tracking.pas` | `base` + `TRTLCriticalSection` |
| `allocator.callback.pas` | `base` (EArgumentNil) |
| `pool.object_pool.pas` | `base` (TObject) |
| `ring_buffer.pas` | `base.utils` (CopyMem/ZeroMem) |
| `stack_pool.pas` | `base` + `math` |
| `blockpool.growable.pas` | `math` (Trunc) |
| `pool.fixed.growable.pas` | `math` (Trunc) |
| `pool.slab.pas` | `errors` + `base` |

**Owner**: FPC stub 补全 + nextpas.core.* 运行时单元

## 自举编译路径（建议）

```
Phase 1: mem.base → arena.base (无障碍叶子)
Phase 2: mem.error → mem.utils → mem.intf (需 FPC stub)
Phase 3: allocator.base → arena.intf → pool.base (需 interface 支持)
Phase 4: 实现类 (需 TInterfacedObject + FFI)
Phase 5: threadvar + generic (需 TLS + 泛型支持)
```

## 结论

- **真正零障碍**：仅 `mem.base` 和 `arena.base`
- **最大阻塞**：interface/refcount (27 文件)，需编译器 COM 接口支持
- **C6-A 前可推进**：A2 (FPC stub) + B1-B4 (回归测试)
- **C6-A 后推进**：A3/A4 (实际自举编译)
