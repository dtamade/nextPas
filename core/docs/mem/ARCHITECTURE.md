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
- `nextpas.core.mem.base` - AlignUp, IsPowerOfTwo, TArenaMarker
- `nextpas.core.mem.intf` - IAllocator 接口
- `nextpas.core.mem.error` - EAllocError, EOutOfMemory

### L1: Arena 子系统
- `nextpas.core.mem.arena.base` - TArenaMark, TArenaConfig, TArenaStats, TArenaGrowthKind
- `nextpas.core.mem.arena.intf` - IArena 接口
- `nextpas.core.mem.arena.local` - TLocalArena (GetMem-backed, IArena)
- `nextpas.core.mem.arena.chunked` - TChunkedArena (分段可增长, Go-style chunk cache, IArena)
- `nextpas.core.mem.arena.virtual` - TVirtualArena (mmap-backed, 零虚分发 record)
- `nextpas.core.mem.arena.pas` - 纯 facade，re-export 所有类型

### L2: 分配器包装
- `nextpas.core.mem.allocator.arena` - TVirtualArenaAllocator (IAllocator 包装)
- `nextpas.core.mem.allocator.tracking` - TTrackingAllocator (泄漏检测)
- `nextpas.core.mem.allocator.leak_check` - RunTestWithLeakCheck (测试便利)

### L3: 门面
- `nextpas.core.mem.pas` - 门面，re-export 所有类型

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

### TVirtualArena (record, 零虚分发)
- 预留 256MB 虚拟地址空间（platform_virtual_reserve）
- 延迟提交物理页（platform_virtual_commit, 2MB chunk）
- 双向 bump pointer（含指针从前往后，无指针从后往前）
- 大对象（>=64KB）独立 mmap
- Linux THP advisory（MADV_HUGEPAGE）

### TChunkedArena (class, IArena)
- 分段可增长 bump allocator
- Go-style chunk cache（Reset 缓存 freed segments, 最多 8 个）
- AddSegment 优先从缓存复用（reuse→ready→new）
- 支持几何增长和线性增长策略

### TLocalArena (class, IArena)
- 固定容量 bump allocator
- 预分配 GetMem-backed buffer
- 最简单的 arena 实现

## 性能基准 (2026-06-22)

64B alloc x10000:
| 分配器 | ns/op | 备注 |
|--------|-------|------|
| LocalArena | 5 | 预分配 bump pointer |
| ChunkedArena (reuse) | 17 | Go-style chunk cache |
| VirtualArena | 41 | mmap-backed, 安全 bounds check |
| RTL GetMem | 66 | FPC heap alloc+free |
| Go BumpArena | 5 | 对标 LocalArena |
| Go unsafe | 1 | 零开销 pointer bump |
| Rust Vec | 2 | 对标 Go unsafe |
| Rust BumpArena | 0 | 编译器完全优化掉 |

## 虚拟内存 API

platform.memory 提供跨平台虚拟内存管理：
- `platform_virtual_reserve` — 预留虚拟地址空间（POSIX: mmap PROT_NONE; Windows: VirtualAlloc MEM_RESERVE）
- `platform_virtual_commit` — 提交物理页（POSIX: mmap MAP_FIXED; Windows: VirtualAlloc MEM_COMMIT）
- `platform_virtual_decommit` — 释放物理页（POSIX: madvise MADV_DONTNEED; Windows: VirtualFree MEM_DECOMMIT）
- `platform_virtual_release` — 释放预留（POSIX: munmap; Windows: VirtualFree MEM_RELEASE）
- `platform_madvise_thp` — THP advisory（Linux: madvise MADV_HUGEPAGE）
