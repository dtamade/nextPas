# nextpas.core.mem 代码契约

> 模块路径: `core/src/nextpas.core.mem.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

内存管理子系统。提供分层的分配器架构：基础工具 → 接口契约 → 多后端实现 → 门面聚合。
所有分配器遵守"空操作原则"：size=0 时不执行任何操作。

---

## 模块分层

### L0: 基础 (`mem.base`)

对齐、幂次、哈希等位操作工具。

```pascal
const
  MEM_DEFAULT_ALIGN = SizeOf(Pointer);  { 8 on 64-bit }
  MEM_CACHE_LINE_SIZE = 64;
  MEM_PAGE_SIZE = 4096;
  DEFAULT_ALIGNMENT = 16;  { SIMD-friendly }
  MEM_POISON_FREED = $DE;  { debug use-after-free detection }

function IsPowerOfTwo(AValue: SizeUInt): Boolean;
function NextPowerOfTwo(AValue: SizeUInt): SizeUInt;
function AlignUp(AValue, AAlignment: SizeUInt): SizeUInt;
function NormalizeAlignment(AAlignment: SizeUInt): SizeUInt;
function ValidateAlignArg(AAlignment: SizeUInt): Boolean;
function MulHash64(AValue: QWord): QWord;
function Log2UInt(AValue: SizeUInt): SizeUInt;
```

### L0: 接口 (`mem.intf`)

核心分配器契约。

```pascal
type
  TAllocatorTraits = record
    ZeroInitialized: Boolean;  { AllocMem 返回全零内存 }
    ThreadSafe: Boolean;       { 所有方法线程安全 }
  end;

  IAllocator = interface
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function Traits: TAllocatorTraits;
  end;
```

### L1: 后端实现

| 后端 | 单元 | 用途 |
|------|------|------|
| RTL | `allocator.rtl` | FPC 默认分配器包装 |
| CRT | `allocator.crt` | libc malloc/free 包装 |
| Callback | `allocator.callback` | 回调委托分配器 |
| MMap | `allocator.mmap` | mmap 直接映射 |
| Mimalloc | `allocator.mimalloc` | mimalloc 库集成 |
| Guard | `allocator.guard` | 带守卫页的调试分配器 |
| Fallback | `allocator.fallback` | 降级链 |
| Tracking | `allocator.tracking` | 分配追踪 |
| LeakCheck | `allocator.leak_check` | 泄漏检测 |
| Growing | `allocator.growing` | 自动增长缓冲区 |
| Arena | `allocator.arena` | 线性分配器 |

### L1: 门面聚合

| 门面 | 单元 | 聚合范围 |
|------|------|---------|
| Foundation | `allocator.foundation` | RTL + Callback (最小依赖) |
| Full | `allocator.pas` | Foundation + MMap + Mimalloc + Guard |

---

## 前置条件

1. `AlignUp`: AAlignment 必须是 2 的幂
2. `ReallocMem(ADst, ASize)`: ADst 必须是之前由同一分配器返回的有效指针，或 nil
3. `FreeMem(ADst)`: ADst 必须是之前由同一分配器返回的有效指针，或 nil
4. `ValidateAlignArg`: AAlignment 必须非零、>= 指针大小、2 的幂

---

## 后置条件

1. `GetMem(ASize)`: 返回 ASize 字节，对齐至少 DEFAULT_ALIGNMENT
2. `AllocMem(ASize)`: 返回 ASize 字节全零内存
3. `ReallocMem(ptr, newSize)`: 返回 newSize 字节，保留前 min(oldSize, newSize) 字节
4. `FreeMem(ptr)`: 释放内存，debug 模式写入 MEM_POISON_FREED
5. `Traits.ZeroInitialized`: true 仅保证 AllocMem 全零，GetMem 不保证

---

## 错误语义

| 场景 | 行为 |
|------|------|
| size=0 (所有方法) | 空操作（GetMem 返回 nil，FreeMem 不操作） |
| ReallocMem(nil, size) | 等价于 GetMem(size) |
| FreeMem(nil) | 空操作 |
| AlignUp 非 2 的幂对齐 | 未定义行为（调用方责任） |
| OOM | raise EOutOfMemory |

---

## 线程安全

- 由 `TAllocatorTraits.ThreadSafe` 声明
- 默认后端(RTL/CRT): 线程安全（依赖 libc/FPC 内部锁）
- Arena 后端: 不线程安全，需外部同步
- ConcurrentArena: 线程安全版本

---

## 内存管理

- 所有分配器遵循所有权原则：分配和释放必须通过同一分配器
- IAllocator 为接口类型，走引用计数
- Arena 支持批量释放（reset/free-all），单次分配不可单独释放
- Guard 后端在每次分配前后插入守卫页，用于检测越界

---

## 测试覆盖

| 套件 | 路径 | 范围 |
|------|------|------|
| test_mem_* | `core/tests/nextpas.core.mem/` | 分配器、Arena、pool、mmap |
| test_l0_dependency_boundaries | `core/tests/nextpas.core.mem/` | L0 依赖边界检查 |

---

## 依赖关系

- `mem.base` 依赖: `nextpas.core.base`
- `mem.intf` 依赖: `nextpas.core.mem.base`
- `mem.allocator` 依赖: 所有后端 + `mem.base`
- 被依赖: collections, fs, io, crypto, http 等

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
