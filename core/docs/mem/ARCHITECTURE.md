# nextpas.core.mem 架构设计

## 设计哲学

### 核心原则
1. **性能优先**：所有热路径必须极致优化
2. **零虚分发**：record 类型优于 class 类型（TVirtualArena 是 record）
3. **接口优雅**：遵循 Rust trait / Go interface 风格
4. **生产级质量**：完整的测试覆盖和基准对照

### 设计约束
- IAllocator 接口有 40+ 模块引用，不能轻易改动
- TAllocator 基类提供 DoGetMem/DoFreeMem 虚方法
- 用户要求"质量标准与 Go/Rust 对齐"

## 架构分层

### L0: 基础类型
- `nextpas.core.mem.base` — AlignUp, IsPowerOfTwo, TArenaMarker (deprecated), TAllocatorKind
- `nextpas.core.mem.intf` — IAllocator 接口
- `nextpas.core.mem.error` — EAllocError, EOutOfMemory
- `nextpas.core.mem.mutex` — TMemMutex (简单互斥锁)
- `nextpas.core.mem.rwlock` — TMemRWLock (读写锁)

### L1: Arena 子系统
- `nextpas.core.mem.arena.base` — TArenaMark, TArenaConfig, TArenaStats, TArenaGrowthKind
- `nextpas.core.mem.arena.intf` — IArena 接口
- `nextpas.core.mem.arena.local` — TLocalArena (GetMem-backed, IArena, AllocFast/AllocAlignedFast)
- `nextpas.core.mem.arena.chunked` — TChunkedArena (分段可增长, Go-style chunk cache, IArena)
- `nextpas.core.mem.arena.virtual` — TVirtualArena (mmap-backed, 零虚分发 record, AllocUnsafe)
- `nextpas.core.mem.arena.concurrent` — TArenaConcurrent (IArena 线程安全包装, mutex-protected)
- `nextpas.core.mem.arena.growable` — TGrowingArena (main legacy, configurable growth policy)
- `nextpas.core.mem.arena.pas` — 纯 facade, re-export 核心类型

### L2: 分配器包装
- `nextpas.core.mem.allocator.arena` — TFastArenaAllocator/TVirtualArenaAllocator (IAllocator 包装)
- `nextpas.core.mem.allocator.tracking` — TTrackingAllocator (泄漏检测)
- `nextpas.core.mem.allocator.leak_check` — RunTestWithLeakCheck (测试便利)
- `nextpas.core.mem.allocator.mimalloc` — TMimallocAllocator (mimalloc FFI)

### L2: Pool 子系统
- `nextpas.core.mem.blockpool` — TBlockPool (IBlockPool 实现, 固定大小块分配)
- `nextpas.core.mem.blockpool.concurrent` — TBlockPoolConcurrent (线程安全包装)
- `nextpas.core.mem.blockpool.sharded` — TShardedBlockPool (分片, 高并发)
- `nextpas.core.mem.blockpool.growable` — TGrowingBlockPool (可增长)
- `nextpas.core.mem.pool.slab` — TSlabPool (slab 分配, IMemoryPool/IAllocator)
- `nextpas.core.mem.pool.slab.concurrent` — TSlabPoolConcurrent
- `nextpas.core.mem.pool.slab.sharded` — TSlabPoolSharded
- `nextpas.core.mem.pool.fixed_slab` — TFixedSlabPool (单页 slab)
- `nextpas.core.mem.pool.fixed` — TFixedPool
- `nextpas.core.mem.pool.object_pool` — TObjectPool

### L3: 门面
- `nextpas.core.mem.pas` — 门面, re-export 核心 Arena + 默认分配器
  - 高级子模块（pool/blockpool/concurrent）需直接 uses 对应单元

## 核心设计

### IArena 接口
```pascal
IArena = interface
  function Alloc(aSize: SizeUInt): Pointer;
  function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
  function AllocZeroed(aSize: SizeUInt): Pointer;
  function SaveMark: TArenaMark;
  procedure RestoreToMark(aMark: TArenaMark);
  procedure Reset;
  function UsedSize: SizeUInt;
  function RemainingSize: SizeUInt;
  function Stats: TArenaStats;
end;
```

### IAllocator 接口
```pascal
IAllocator = interface
  function GetMem(aSize: SizeUInt): Pointer;
  function AllocMem(aSize: SizeUInt): Pointer;   // zero-initialized
  function ReallocMem(aPtr: Pointer; aSize: SizeUInt): Pointer;
  function FreeMem(aPtr: Pointer): SizeUInt;
  function MemSize(aPtr: Pointer): SizeUInt;
  function AllocAligned(aSize, aAlign: SizeUInt): Pointer;
  function Traits: TAllocatorTraits;
end;
```

### TVirtualArena (record, 零虚分发)
- 预留 256MB 虚拟地址空间（platform_virtual_reserve）
- 延迟提交物理页（platform_virtual_commit, 2MB chunk, true const）
- 双向 bump pointer（含指针从前往后，无指针从后往前）
- 大对象（>=64KB）独立 mmap（independent lifecycle, 不受 mark/reset 影响）
- Linux THP advisory（MADV_HUGEPAGE）
- AllocUnsafe: 纯 bump pointer, 2ns, 476M ops/s（前提：页面已提交）

### TChunkedArena (class, IArena)
- 分段可增长 bump allocator
- Go-style chunk cache（Reset 缓存 freed segments, 最多 8 个）
- AddSegment 优先从缓存复用（reuse→ready→new）
- FSegments 几何扩容（2x growth）

### TLocalArena (class, IArena)
- 固定容量 bump allocator
- 预分配 GetMem-backed buffer
- AllocFast/AllocAlignedFast: DEBUG Assert 保护, Release 零额外分支

### TArenaConcurrent (class, IArena)
- mutex-protected IArena 包装
- 所有读写方法均持锁（包括 UsedSize/RemainingSize）

## 性能基准 (2026-06-22)

64B alloc, Reset+Reuse:
| 分配器 | ns/op | ops/s |
|--------|-------|-------|
| VirtualArena AllocUnsafe | 2 | 476M |
| LocalArena | 3 | 307M |
| ChunkedArena | 15 | 68M |
| VirtualArena Alloc | 37 | 27M |
| RTL GetMem+FreeMem | 64 | 15M |

## 虚拟内存 API

platform.memory 提供跨平台虚拟内存管理：
- `platform_virtual_reserve` — 预留虚拟地址空间（POSIX: mmap PROT_NONE; Windows: VirtualAlloc MEM_RESERVE）
- `platform_virtual_commit` — 提交物理页（POSIX: mmap MAP_FIXED; Windows: VirtualAlloc MEM_COMMIT）
- `platform_virtual_decommit` — 释放物理页（POSIX: madvise MADV_DONTNEED; Windows: VirtualFree MEM_DECOMMIT）
- `platform_virtual_release` — 释放预留（POSIX: munmap; Windows: VirtualFree MEM_RELEASE）
- `platform_madvise_thp` — THP advisory（Linux: madvise MADV_HUGEPAGE）

## AllocUnsafe 前提

- 调用方必须确保页面已提交（如先调用 Alloc 提交页面后 Reset）
- 统计值不完整（不更新 TotalUsed/PeakUsed/AllocCount）
- 不保证对齐
- 适用场景：编译器热路径的"已知安全"分配

## 大对象生命周期

- 大对象（>= ARENA_LARGE_THRESHOLD = 64KB）通过独立 mmap 分配
- Reset/SaveMark/RestoreToMark **不回收**大对象
- 大对象在 Release 时统一释放
- 这是有意设计：大对象通常是长期存活的配置/缓冲区
