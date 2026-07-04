# nextpas.core.mem API 选择指南

**目的**: 帮助开发者在 mem 模块的三套 API 体系中选择正确的入口。
**最后更新**: 2026-07-03

---

## 三套 API 体系

mem 模块有三套命名体系，分别服务于不同语义场景：

| 体系 | 方法签名 | 适用场景 | 接口/类型 |
|------|----------|----------|-----------|
| **Alloc/Free** | `Alloc(ASize): Pointer` | Arena 线性分配（只前进，Reset 释放全部） | `IArena`, `TLocalArena`, `TChunkedArena` |
| **GetMem/FreeMem** | `GetMem(ASize): Pointer` | 通用分配器（单独释放每块） | `IAllocator`, `TAllocator`, `TSlabPool` |
| **Acquire/Release** | `Acquire(out APtr): Boolean` | 固定大小池（O(1) 分配/释放） | `IPool`, `IBlockPool`, `TLocalBlockPool` |

## 选择决策树

```
你的使用场景是什么？
│
├─ 请求/帧/文档等有限生命周期？
│  └─ 用 IArena (Alloc/Reset)
│     ├─ 单线程 → TLocalArena / TChunkedArena
│     └─ 多线程 → TArenaConcurrent
│
├─ 频繁分配/释放相同大小的对象？
│  └─ 用 IPool (Acquire/Release)
│     ├─ 单线程 → TLocalBlockPool / TFixedSlabPool
│     └─ 多线程 → TBlockPoolConcurrent / TShardedBlockPool
│
├─ 通用内存分配（大小不固定）？
│  └─ 用 IAllocator (GetMem/FreeMem)
│     ├─ 默认 → DefaultAllocator
│     ├─ 需要跟踪泄漏 → TTrackingAllocator
│     ├─ 需要 OOM 降级 → TFallbackAllocator
│     └─ 需要 slab 优化 → TSlabPool
│
└─ 不确定？→ 用 IAllocator (最通用)
```

## 命名约定速查

| 操作 | IAllocator | IArena | IPool |
|------|------------|--------|-------|
| 分配 | `GetMem(Size)` | `Alloc(Size)` | `Acquire(out Ptr)` |
| 分配+清零 | `AllocMem(Size)` | `AllocZeroed(Size)` | N/A |
| 释放 | `FreeMem(Ptr)` | N/A (用 Reset) | `Release(Ptr)` |
| 重分配 | `ReallocMem(Ptr, Size)` | N/A | N/A |
| 释放全部 | N/A | `Reset` | `Reset` |

## nil 和 0 的处理契约

所有分配器/池/Arena 统一遵守以下契约：

| 操作 | 行为 |
|------|------|
| `GetMem(0)` / `Alloc(0)` / `Acquire` with size=0 | 返回 nil |
| `FreeMem(nil)` / `Release(nil)` | 静默返回，无操作 |
| `ReallocMem(nil, Size)` | 等价于 `GetMem(Size)` |
| `ReallocMem(Ptr, 0)` | 等价于 `FreeMem(Ptr)` |
| `ReallocMem(nil, 0)` | 无操作，返回 nil |

**注意**: `STRICT_NULL_FREE` 调试模式下 `FreeMem(nil)` 会抛异常，仅用于检测调用方 bug。

## 错误处理策略

| 场景 | IAllocator | IArena | IPool |
|------|------------|--------|-------|
| OOM | 返回 nil | 返回 nil | 返回 nil / False |
| 非法参数 | 抛异常 | 返回 nil | 抛异常 |
| 双重释放 | 抛异常 | N/A | 抛异常 |
| 容量耗尽 | N/A | 返回 nil | 返回 nil / False |

**设计哲学**: Arena 的 `Alloc` 返回 nil 表示容量不足（正常运行时条件），Pool/Allocator 的非法操作抛异常（编程错误）。

## 常见误区

### ❌ 混用 Alloc 和 GetMem

```pascal
// 错误：Arena 分配的内存不能用 FreeMem 释放
var Arena: IArena;
Arena := CreateDefaultArena(4096);
var P := Arena.Alloc(128);
FreeMem(P);  // ❌ Arena 不支持单独释放
```

```pascal
// 正确：Arena 用 Reset 释放全部
var Arena: IArena;
Arena := CreateDefaultArena(4096);
var P := Arena.Alloc(128);
Arena.Reset;  // ✅ 一次性释放全部
```

### ❌ 在 Arena 上调用 ReallocMem

```pascal
// 错误：Arena 不支持重分配
var Arena: IArena;
Arena.Alloc(128);
// Arena 没有 ReallocMem 方法
```

```pascal
// 正确：需要重分配时用 IAllocator
var Alloc: IAllocator;
Alloc := DefaultAllocator;
var P := Alloc.GetMem(128);
P := Alloc.ReallocMem(P, 256);
```

### ❌ 用 IPool 分配不同大小的对象

```pascal
// 错误：固定大小池不支持可变大小
var Pool: TLocalBlockPool;
Pool := TLocalBlockPool.Create(64, 100);
Pool.Acquire;  // 只能分配 64 字节的块
```

```pascal
// 正确：可变大小用 IAllocator 或 IMemoryPool
var Pool: TSlabPool;
Pool := TSlabPool.Create(4096);
Pool.GetMem(32);   // ✅ 自动选择合适的 size class
Pool.GetMem(1024); // ✅ 大对象走 fallback
```
