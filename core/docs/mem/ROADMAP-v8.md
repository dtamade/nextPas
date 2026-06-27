# mem 模块路线图 v8.0 — 对标 Go / mimalloc / snmalloc

> **目标**: 从"超越 Go chan"的专项能力，进化为通用内存分配器基础设施——在真实工作负载下与 Go runtime.mallocgc、mimalloc、snmalloc 正面对标。
>
> **原则**: 不做表面功夫。每个阶段交付可测量的性能数据，用 `nextpas.core.bench` 和对照基准说话。

## 当前位置

```
R1-R17:    打磨 + Bug 修复 + 测试 + 合并 main        ✅
Phase D:   测试覆盖 100%                               ✅
Phase E:   文档注释 80%+                                ✅
Phase F:   基准测试 + Go/Rust 对照                      ✅
R16-R17:   代码复用提炼 (MulHash64/Log2UInt/Growth/Align) ✅
当前位置:  → Phase G: 通用分配器基础设施
```

## 当前状态

- 49 源文件 / 19,920 行
- 30 suites / 398 tests / 0 leaks (R17 后)
- 核心热路径: Arena 2ns (476M ops/s), RingBuffer 2x 快于 Go chan
- 已有能力: Arena (bump/local/chunked), 固定块池 (block/slab/mapped), 分片锁, 线程局部, 无锁 CAS
- 缺失能力: 见下方差距分析

---

## 差距分析: nextpas.core.mem vs 竞品

### 分配器层次对比

| 层次 | Go (runtime) | mimalloc | snmalloc | nextpas.core.mem |
|------|-------------|----------|----------|-----------------|
| **TLS cache** | mcache (136 slots, ~5ns) | TLS page (48 bins) | thread-local chunk | ❌ 无 |
| **Central** | mcentral (lock-free spanSet) | OS page (delayed-free) | message queue | ❌ 无 |
| **Global** | mheap (radix tree 5-level) | OS page heap | shared allocator | ⚠️ 各后端独立 |
| **Size classes** | 68 (8B-32KB) | 48 (up to 64KB) | 16 (up to 64KB) | 7 (fixed pool) |
| **Span** | bitmap 64-bit, BSF 1 指令 | page segment 256×64KB | chunk 16 classes | slab 页级 |
| **X-thread free** | GC assist + mcentral | delayed-free list | message queue | mutex wrapper |
| **Huge alloc** | mheap 直接 mmap | 直接 mmap | 直接 mmap | mmap allocator ✅ |
| **OS 回收** | scavenger (2min) | eager purge bitmap | heartbeat | ❌ 无 |

### 关键差距 (按影响排序)

| # | 差距 | 影响 | 难度 |
|---|------|------|------|
| G1 | 无通用分配器 (IAllocator 实现) | 🔴 所有用户必须手动选后端 | 中 |
| G2 | Size class 不足 (7 vs 48-68) | 🔴 碎片率高、无法匹配 Go 的精细度 | 高 |
| G3 | 无 TLS free-list cache | 🔴 热路径 5-10ns 差距 | 中 |
| G4 | 无 bitmap-based span 分配 | 🟡 cache miss 多、无法 BSF 1 指令定位 | 高 |
| G5 | 无页面级管理 (scavenge) | 🟡 长时间运行内存只增不减 | 中 |
| G6 | X-thread free 路径太慢 | 🟡 多线程场景退化明显 | 中 |
| G7 | 无 scan/noscan 区分 | 🟢 GC 友好性（为未来准备） | 低 |

---

## Phase G: 通用分配器 (TGrowingAllocator)

**目标**: 用户只需 `uses nextpas.core.mem` + `DefaultAllocator`，自动获得 size-class + TLS cache + Arena fallback 的统一分配体验。

### G-1: Size Class 表设计

**对标**: Go 的 68 classes, mimalloc 的 48 classes

设计一个介于两者之间的 size class 表——足够精细控制碎片，又不增加元数据开销:

```
目标: 48 个 size classes, 覆盖 16B - 64KB
- 16B-256B:   16B 步长    (16 classes) — 小对象密集分配
- 256B-1KB:   64B 步长    (12 classes) — 中小对象
- 1KB-4KB:    256B 步长   (12 classes) — 中等对象
- 4KB-64KB:   4KB 步长    (8 classes)  — 大对象
- >64KB:      直接 mmap/page 分配
```

**交付物**:
- `nextpas.core.mem.sizeclass.pas` — Size class 查表 (O(1) 索引)
- `test_sizeclass` — 全覆盖测试 + Go 68-class 对照

**对标指标**:
- 查表开销: 必须 ≤ 1 条 shift + 1 条 lookup (对比 Go 的 `size_to_class8` 两步查表)
- 碎片率: 16B-256B 范围 internal fragmentation ≤ 12.5% (Go: ≤ 12.5%)

### G-2: Bitmap Span 分配器

**对标**: Go 的 `allocCache` (64-bit bitmap, BSF/TZCNT 单指令找空闲 slot)

设计思路:
```
TSpan = record
  FBitmap: UInt64;        // 64 个 slot 的位图
  FSlotSize: SizeUInt;    // 每个 slot 的字节数
  FBase: Pointer;         // span 起始地址
  FSlotCount: Byte;       // 实际 slot 数 (1-64)
end;

// 分配: 1 条 BSF 找到第一个空闲位
// 释放: 1 条位清除
// 适合 16B-1024B 的小对象 (slot 数 ≤ 64)
```

**交付物**:
- `nextpas.core.mem.span.pas` — TSpan + TSpanAllocator
- `test_span` — 分配/释放/碎片测试 + 对照 Go allocCache

**对标指标**:
- 分配: ≤ 5 条指令 (BSF + shift + mask + store) — 对标 Go allocCache
- 释放: ≤ 3 条指令 (mask + store)

### G-3: TLS Free-List Cache

**对标**: Go mcache (per-P, 136 slots, 0 锁), mimalloc TLS page

设计思路:
```
TThreadCache = record
  FFreeLists: array[0..47] of Pointer;  // 每个 size class 一条 free list
  FListSize: array[0..47] of Word;      // 每条 list 当前长度
  FMaxListSize: array[0..47] of Word;   // 每条 list 上限 (压力自适应)
end;

// 分配: 从 TLS free list pop → ~5ns (对标 Go mcache)
// 释放: push 到 TLS free list → ~5ns
// List 满: batch refill 从 central 取 (对标 Go refill)
// List 空: batch flush 到 central 归还
```

**关键设计**:
- 使用 `threadvar` 实现 TLS (FPC 原生支持)
- Free list 是侵入式单链表 (next pointer 存在已释放块内, 0 额外内存)
- Batch refill/flush 大小自适应 (对标 Go 的 `mcachesize` 调节)

**交付物**:
- `nextpas.core.mem.cache.thread.pas` — TThreadCache
- `test_thread_cache` — TLS 隔离测试 + refill/flush 测试

**对标指标**:
- 热路径分配: ≤ 8ns (Go mcache: ~5ns, mimalloc TLS: ~5ns)
- 热路径释放: ≤ 8ns
- TLS 隔离: 2 线程并发 0 争用

### G-4: Central Allocator (Span Pool)

**对标**: Go mcentral (lock-free spanSet), mimalloc OS page

设计思路:
```
TCentralPool = record
  FPartialSpans: TSpanStack;   // 有空闲 slot 的 span (lock-free stack)
  FFullSpans: TSpanStack;      // 已满 span (仅用于释放时查找)
  FMutex: TSpinLock;           // 低频操作用 spinlock
end;

// TLS cache miss → 从 central 取一个 partial span → refill cache
// 所有 span 满 → 分配新 span (mmap 64KB) → 切成 slot
// 释放: 找到所属 span → 位图清除 → span 从 full 变 partial
```

**交付物**:
- `nextpas.core.mem.central.pas` — TCentralPool
- `test_central` — 并发 refill/flush 测试

### G-5: TGrowingAllocator — 统一分配器

**对标**: Go `runtime.mallocgc` 的完整路径

组装 G-1 到 G-4:
```
TGrowingAllocator = class(TInterfacedObject, IAllocator)
  FSizeClass: TSizeClassTable;    // G-1
  FCentralPools: array of TCentralPool;  // G-4
  // TLS TThreadCache 通过 threadvar 访问 (G-3)

  function GetMem(ASize: SizeUInt): Pointer;
  // 路径:
  //   ASize ≤ 64KB → sizeclass lookup → TLS cache pop → (miss) central refill
  //   ASize > 64KB → direct mmap
  // 总计: 热路径 ~8ns, 冷路径 ~50ns, 大对象 ~200ns (mmap)
end;
```

**交付物**:
- `nextpas.core.mem.allocator.growing.pas` — TGrowingAllocator
- `test_growing_allocator` — 端到端测试 + Go/mimalloc 对照基准

**对标指标**:

| 场景 | Go mallocgc | mimalloc | 目标 |
|------|-------------|----------|------|
| 热路径小对象 | ~5ns | ~5ns | ≤ 8ns |
| TLS miss | ~50ns | ~30ns | ≤ 50ns |
| 大对象 | ~200ns | ~200ns | ≤ 200ns |
| 多线程 0 争用 | ✅ per-P | ✅ TLS | ✅ TLS threadvar |

---

## Phase H: 内存生命周期管理

**目标**: 解决"分配快但内存只增不减"的问题。对标 Go 的 scavenger 和 mimalloc 的 eager purge。

### H-1: OS 内存回收 (Scavenger)

**对标**: Go runtime scavenger (每 10ms 检查, 2min 后归还), mimalloc eager purge

设计思路:
```
TMemoryScavenger = class
  // 定期扫描 spans，将空闲 span 的物理页归还 OS
  // 使用 madvise(MADV_DONTNEED) / decommit / DiscardVirtualMemory
  // 阈值自适应: 空闲 > 50% 且 > 30s 未使用 → 归还
  // 避免过度回收: rate-limited (对标 Go 的 10ms heartbeat)
end;
```

**交付物**:
- `nextpas.core.mem.scavenger.pas` — TMemoryScavenger
- `test_scavenger` — OS 回收验证

**对标指标**:
- RSS 回收: 空闲 >50% 30s 后 RSS 降至实际使用量的 ≤120%
- CPU 开销: < 0.1% (rate-limited)

### H-2: X-Thread Free 优化

**对标**: mimalloc delayed-free list, snmalloc message queue

当前: mutex wrapper (TArenaConcurrent)。目标: 每个线程一个 inbox，其他线程释放时 push 到 inbox，本线程空闲时 drain。

```
TCrossThreadFree = record
  FInbox: array of TLockFreeStack;  // 每个线程一个 inbox
  // 释放: CAS push 到目标线程的 inbox → ~10ns
  // drain: 本线程分配前检查 inbox → batch 处理
end;
```

**交付物**:
- `nextpas.core.mem.xthread.pas` — TCrossThreadFree
- `test_xthread` — 多线程竞争测试

---

## Phase I: 精度与安全

### I-1: Free-List Shuffle (安全)

**对标**: mimalloc free-list shuffling (防 heap spraying)

释放时将块插入 free list 的随机位置而非头部，防止攻击者预测下一个分配地址。

### I-2: Guard Pages (调试)

**对标**: mimalloc guard pages, AddressSanitizer

在 span 两端放置不可读写的 guard page，检测 buffer overflow。

### I-3: Scan/NoScan 分离 (GC 准备)

为未来 GC 或 conservative scanning 准备: 指针类型对象和纯数据对象分开存储。

---

## Phase J: 基准与验证

### J-1: 对标基准套件

| 基准 | 对标 | 指标 |
|------|------|------|
| `bench_malloctorture` | Go malloctest | 多线程混合分配/释放 |
| `bench_sh6bench` | mimalloc sh6bench | 6 种 size 模式 |
| `bench_xmalloc-test` | standard xmalloc | stress test |
| `bench_mstress` | mimalloc mstress | 多线程压力 |
| `bench_rptest` |,rpTest | 真实应用模式 |

### J-2: 碎片率测量

- Long-running 碎片率测试: 1M 分配/释放循环后测量 RSS vs 实际使用
- 对标: Go < 1.5x, mimalloc < 1.2x

---

## 里程碑总览

| Phase | 内容 | 前置 | 预计规模 | 状态 |
|-------|------|------|----------|------|
| **G-1** | Size class 表 | — | 1 文件 + 1 测试 | 待实施 |
| **G-2** | Bitmap span | G-1 | 1 文件 + 1 测试 | 待实施 |
| **G-3** | TLS cache | G-1 | 1 文件 + 1 测试 | 待实施 |
| **G-4** | Central pool | G-2 | 1 文件 + 1 测试 | 待实施 |
| **G-5** | TGrowingAllocator | G-1~4 | 1 文件 + 1 测试 + 基准 | 待实施 |
| **H-1** | Scavenger | G-5 | 1 文件 + 1 测试 | 待实施 |
| **H-2** | X-thread free | G-3 | 1 文件 + 1 测试 | 待实施 |
| **I-1** | Free-list shuffle | G-3 | 小改 | 待实施 |
| **I-2** | Guard pages | G-2 | 1 文件 + 1 测试 | 待实施 |
| **I-3** | Scan/noscan | G-1 | 小改 | 待实施 |
| **J-1** | 对标基准套件 | G-5 | 5 基准项目 | 待实施 |
| **J-2** | 碎片率测量 | G-5, H-1 | 1 基准项目 | 待实施 |

## 预期最终能力

| 指标 | 当前 | Phase G 后 | Phase H+J 后 |
|------|------|-----------|-------------|
| 通用分配器 | ❌ 无 | ✅ TGrowingAllocator | ✅ |
| Size classes | 7 | 48 | 48 |
| 小对象分配延迟 | N/A | ≤ 8ns | ≤ 8ns |
| 多线程争用 | mutex | TLS 0 争用 | TLS 0 争用 |
| OS 内存回收 | ❌ | ❌ | ✅ scavenger |
| RSS 碎片率 | 无法测量 | ≤ 1.5x | ≤ 1.3x |
| 基准对标 | Arena/chan only | Go/mimalloc 全路径 | 含碎片率 |

---

## 实施节奏

采用 **小步迭代** 策略: 每个子阶段 (G-1, G-2, ...) 独立编码、独立测试、独立合并 main。不一次性写 5000 行。

- G-1 (size class): 预计 1 轮 (纯查表，无状态)
- G-2 (bitmap span): 预计 2 轮 (位图操作 + span 管理)
- G-3 (TLS cache): 预计 2 轮 (threadvar + free list + refill)
- G-4 (central): 预计 2 轮 (span pool + spinlock)
- G-5 (统一分配器): 预计 2 轮 (组装 + 端到端测试)
- H 系列: 预计 3 轮
- J 系列: 预计 2 轮

**总计**: ~16 轮迭代, 每轮独立可验证。
