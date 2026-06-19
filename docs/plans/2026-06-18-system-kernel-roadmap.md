# system 模块内核战略路线图

> **文档版本**: v6.0 — 2026-06-18
> **状态**: 4 轮 Codex 审查通过，进入 Phase 0 实现
> **范围**: nextpas.core.system 内核架构设计，对标 Go/Rust，覆盖自举全路径
> **质量标准**: 虐哭 FPC，拳打 Go，脚踢 Rust

---

## 1. 愿景总览

nextPas system 内核的目标是：**在保持 FPC 源码兼容的前提下，构建一个架构先进、性能对齐 Go/Rust 的运行时内核**。

这不是重写 FPC System，而是在 FPC 自举完成后，用 5 个结构性支柱替换运行时核心，
使 nextPas 编译出的程序在内存管理、异常处理、并发调度、类型系统四个维度达到工业级水准。

### 核心架构原则：编译器是 nextpas.core 的消费者

**nextpas.core 是通用基础设施，nextPas 编译器是它的第一个重度用户。**

```
nextpas.core (通用基础设施，零应用逻辑)
├── mem: TCache / Arena / Pool
├── text: TString (SSO + CoW) / intern
├── sync: TAtomic / TLS / Mutex / RwLock
├── collections: HashMap / Vec / BTree
└── ...
         ↑ 所有应用复用，编译器只是其中之一
    nextPas compiler (消费者，不搞特殊)
    ├── AST 节点: nextpas.core.mem TCache 分配
    ├── 标识符: nextpas.core.text TString + intern
    ├── 符号表: nextpas.core.collections HashMap
    ├── 并行编译: nextpas.core.sync TAtomic + RwLock
    └── 阶段 arena: nextpas.core.mem Arena 批量分配/释放
```

**这是 Go / Rust / Swift 的最佳实践**:
- Go 编译器用 Go runtime 的内存分配器，不用特殊的编译器分配器
- rustc 用 Rust 标准库的 Vec/String/HashMap，不自己造轮子
- Swift 编译器用 Swift stdlib，编译器和运行时共享基础设施

**禁止**:
- ❌ 编译器内部搞一套专用的分配器/字符串/容器
- ❌ 编译器绕过 nextpas.core 直接调用平台 API
- ❌ "编译器是特殊的所以需要简化方案"

**要求**:
- ✅ 编译器是 nextpas.core 最严格的测试用例
- ✅ 编译器发现的性能问题推动 nextpas.core 优化
- ✅ 编译器验证 nextpas.core 的 API 设计是否足够好

### 5 支柱概览

| # | 支柱 | 一句话 | 对标 |
|---|------|--------|------|
| P1 | Custom TString | SSO + CoW + UTF-8 原生，24 字节 record | Rust `String`, Go `string` |
| P2 | TCache 3 级分配器（纯 Pascal） | per-thread mcache → mcentral → mheap | Go `runtime.malloc` |
| P3 | Table-based exceptions | DWARF `.eh_frame` 展开，正常路径零开销 | Rust panic, C++ exception |
| P4 | Per-thread 内核 | G-M-P 调度模型 + seq_cst 原子 + sync.Pool | Go `runtime` |
| P5 | RAII for records | 编译器在作用域出口自动插入 Finalize | Rust `Drop` |

### 优先级矩阵

| 优先级 | 支柱 | 阻塞自举? | 理由 | 对应阶段 |
|--------|------|-----------|------|----------|
| **高** | P1 (TString) + P5 (RAII) + P4a (原子) | 部分 | 语言核心改进，自举编译器直接受益 | Phase 1a |
| **中** | P2 (TCache) | ❌ | 自举后性能优化首要目标，有前置依赖 | Phase 1b |
| **低** | P4b (G-M-P) + P3 (table-based) | ❌ | 需 LLVM 后端稳定 | Phase 3 |

---

## 2. 当前状态审计

### 2.1 契约层 (S0-S6)

`nextpas.core.system` 已完成 6 个阶段的**纯文档/契约/门面**工作：

| 阶段 | 内容 | 状态 |
|------|------|------|
| S0 | 映射文档 + 源码边界测试 | ✅ |
| S1 | 最小门面 (re-export base/exception/errors) | ✅ |
| S2 | 19 个 `np.system.*` 契约名登记 | ✅ |
| S3 | 异常/RTTI/单元生命周期契约 | ✅ |
| S4 | SysUtils/TypInfo/Classes 兼容门面 | ✅ (Classes 仅 stream shim) |
| S5 | 编译器/运行时集成就绪审计 | ✅ |
| S6 | 自举就绪门 + 契约最终审计 | **S6.1/S6.3/S6.4 ✅, S6.2 部分完成** |

> **S6.2 说明**: Leak-sensitive test fill 受编译器 managed record 支持限制，部分测试标记为 TODO。Gate 0-4 的 PARTIAL 状态反映的是运行时实现缺口，不是契约层缺陷。

**关键事实**：19 个契约全部是 **vocabulary-only**，无运行时实现。
`runtime-contracts.md` 明确记录："system contract, runtime implementation deferred"。

### 2.2 自举就绪门 (2026-06-18 验证)

| Gate | 优先级 | 状态 | 关键缺口 |
|------|--------|------|----------|
| 0: Classes 门面 | Blocker | Partial | stream-core + interface 基础类型有效 (7 symbols)，file-compat 缺失 |
| 1: RTTI 形状一致性 | Critical | **PASS** | 验证通过：TypeKind 枚举、KindOf、ManagedKinds 正确映射 |
| 2: 单元生命周期 | Critical | **PARTIAL** | `SeedUnitLifecycleBodies` (sema:14887-14972) 已生成 `np_unit_init/fini` LLVM 函数并注册 `@llvm.global_ctors/dtors` (emitter:1258-1304)。缺口：优先级同为 65535，LLVM 不保证同优先级内顺序 |
| 3: 进程生命周期 | Important | **PARTIAL** | `'process-init-runtime'` → `hnkProcessInitRuntime` (hir_types:259)，emit 侧就绪 (hir_builder:7430-7452)。缺口：运行时实现缺失 |
| 4: 堆管理器 | Important | **PARTIAL** | @np_alloc/@np_free 未连接 nextpas.core.mem |
| 5: 异常展开 | Normal | **PASS** | setjmp/longjmp freestanding asm 完整 |

> **⚠️ LLVM global_ctors 顺序限制**：当前所有 `np_unit_init_<unit>` 注册到 `@llvm.global_ctors` 时优先级同为 65535。LLVM 不保证同优先级内的初始化顺序，跨翻译单元顺序由链接器决定（通常按 .o 文件链接顺序）。这意味着当前实现无法保证拓扑排序的单元初始化顺序。未来需要实现 S6 的 `_start` 驱动初始化方案来替代。

### 2.3 编译器运行时基础设施

当前 LLVM emitter 中已有的 backend-private helpers：

- **分配**: `@np_alloc`, `@np_free`, `@np_object_alloc` (mmap/munmap, bump allocator)
- **异常**: `@np_try_push`, `@np_try_pop`, `@np_raise` (setjmp/longjmp)
- **接口**: `@np_intf_addref`, `@np_intf_release`
- **对象**: `@np_object_free_release`, `@np_object_release_valid/invalid`
- **内存**: `@np_memcpy`, `@np_memzero`
- **进程**: `_start` 入口 (halt syscall)

**这些都是 backend-private，不是 public ABI**。P2 支柱的任务是用工业级实现替换它们。

---

## 3. 支柱 1: Custom TString

### 3.1 设计目标

```
TString = record
  case Boolean of
    False: (SSO: packed record Len: Byte; Buf: array[0..15] of AnsiChar end);
    True:  (Heap: record Ref: PStringHeader; Len: SizeUInt; Flags: SizeUInt end);
    // Flags: reserved for future use (encoding hints, small-buffer reclaim, etc.)
end;
// SizeOf(TString) = 24 bytes, 8-byte aligned
```

| 属性 | 规格 |
|------|------|
| 小串优化 (SSO) | ≤ 16 字节内联存储，零堆分配 |
| CoW 堆串 | > 16 字节，引用计数 + Copy-on-Write |
| UTF-8 原生 | 内部存储 UTF-8，不维护 UTF-16 伴生 |
| 空串 | 零初始化 = 空串 (SSO 路径) |
| record 语义 | 赋值 = CoW bump refcount，不是指针拷贝 |

### 3.2 与 Go/Rust 对标

| 维度 | Go `string` | Rust `String` | nextPas `TString` |
|------|-------------|---------------|-------------------|
| 内部表示 | (ptr, len) 16B | Vec\<u8\> (ptr, len, cap) 24B | SSO/CoW variant 24B |
| 可变性 | 不可变 | 可变 (所有权) | CoW (refcount) |
| UTF-8 | 是 | 是 | 是 |
| 小串优化 | 无 | 无 | ✅ (≤16B inline) |
| 分配策略 | 每次新分配 | 所有权转移 | CoW + SSO |

**nextPas 优势**: SSO 在短字符串密集场景 (标识符、路径、数字串) 避免堆分配，
Go 标准库没有 SSO 优化。代价是 variant record 的 case 判断分支。

> **⚠️ Rust SSO 生态补充**: Rust 标准库无 SSO，但社区有成熟方案 (smartstring, compact_str, smallstr 等)。
> **⚠️ CoW 引用计数代价**: 每次赋值操作需 bump refcount (atomic)，Go/Rust 通过不可变语义/所有权转移避免了这一开销。nextPas 的 CoW 模型在赋值密集场景有 atomic 开销。

### 3.3 ABI 变更影响范围

24 字节 variant record 布局变更影响以下 LLVM emitter helpers：

| Helper | 变更类型 | 说明 |
|--------|----------|------|
| `@np_memcpy` | 参数适配 | 字符串拷贝目标/源改为 24B |
| `@np_memzero` | 参数适配 | 字符串清零目标改为 24B |
| `string_cleanup` | 重写 | 从 FPC `fpc_ansistr_decr_ref` 改为 CoW refcount decr |
| `string_assign` (intrinsic) | 重写 | 从 FPC 赋值改写为 CoW bump + 条件 copy |
| `@np_object_alloc` | 间接影响 | 若字符串走堆分配，需对接 TCache |
| `EmitStringLiteral` | 适配 | 字面量 emit 改为 SSO 内联或 CoW 堆 |
| `EmitManagedTypeFinalize` | 适配 | 字符串 finalize 路径改为 CoW decr |

**迁移策略**: 逐步替换，先实现 SSO 路径 (无 refcount)，再实现 CoW 路径。

### 3.4 实现计划

**S7.1: TString 基础 layout**
- 定义 `TStringHeader` (refcount + capacity + flags)
- 定义 `TString` variant record
- 实现 `StringInit`/`StringFini` (对应 `np.system.string_init/fini`)
- 空串 = 零初始化验证

**S7.2: SSO 路径**
- `Len ≤ 16` 时直接内联，不走堆
- 拷贝 = record 拷贝 (memcpy 24B)
- 比较 = memcmp 24B

**S7.3: CoW 路径**
- `Len > 16` 时分配 PStringHeader + payload
- 赋值 = refcount bump (不拷贝 payload)
- 写时拷贝 (需要唯一引用检测)

**S7.4: 与 nextpas.core.text 集成**
- `TString` 替换当前 `AnsiString` 作为 text 模块主力
- `np.system.string_assign` 实现 CoW 赋值
- 现有 16 个 text suites (58 个 T.Run 测试用例) 必须全部通过

### 3.5 验收标准

- [ ] `SizeOf(TString) = 24`
- [ ] 空串零初始化有效
- [ ] SSO (≤16B) 无堆分配
- [ ] CoW refcount 正确 (赋值 bump，修改时 copy)
- [ ] UTF-8 透传 (不转码)
- [ ] text 模块 16 suites (58 tests) 全绿
- [ ] heaptrc 0 leak

---

## 4. 支柱 2: TCache 3 级分配器（纯 Pascal，零外部依赖）

> **纯 Pascal 实现**: 参照 Go runtime malloc 的 3 级层次 + tcmalloc 的 bitmap span 管理，全部用 Pascal 实现，不链接任何 C/C++ 分配器库。OS 层直接使用 `platform_mmap_*` API。
> **性能目标**: 小对象分配必须对齐 tcmalloc。双轨路径：编译器直连快路径 (≤15ns) + IAllocator 通用路径 (≤25ns)。
> **不阻塞自举**: 当前 `@np_alloc`/`@np_free` 已有 bump 分配器，TCache 是自举后首要优化目标。

### 4.1 架构概览

```
Thread → TThreadCache (lock-free 快路径, per-thread, 纯 Pascal)
           ↓ (cache miss)
       TCentralCache (per-sizeclass, spinlock)
           ↓ (central exhausted)
       THeap (global, radix tree, platform_mmap_*)
           ↓ (heap exhausted)
       OS (mmap/munmap via nextpas.core.platform)
```

> **层次来源**: 3 级层次参照 Go (mcache→mcentral→mheap)，span 内管理参照 tcmalloc (CTZ bitmap)。
> **注意**: Go 原版 mcache 是 per-P (per-processor)，nextPas 简化版为 per-thread，依赖 TLS。

### 4.2 与 Go/Rust 对标

| 维度 | Go `runtime.malloc` | Rust `GlobalAlloc` | nextPas 目标 |
|------|---------------------|--------------------| ------------ |
| 线程缓存 | mcache (per-P, lock-free, Go) | 无 (用 jemalloc/mimalloc) | TThreadCache (per-thread) |
| 大小类 | 67 classes (8B-32KB) | 取决于分配器 | 67 classes (参照 Go) |
| 小对象快路径 | CTZ bitmap ~15ns | ~20ns (mimalloc) | CTZ bitmap ~15ns |
| 大对象 | THeap direct | 直接 mmap | THeap direct (>32KB) |
| 元数据开销 | 每 span 一个 page map | 0 (分配器管理) | radix tree page map |
| 线程安全 | per-P 无锁 + central 锁 | 分配器内部 | per-thread 无锁 + central 锁 |

### 4.3 性能 SLA（对齐 tcmalloc，双轨路径）

**快路径 (编译器直连，绕过 IAllocator)**:
```
@np_alloc(size) → TLS lookup → sizeclass → CTZ bitmap → 返回指针
// 纯函数调用，无 interface dispatch，无 virtual dispatch
// 预期: ≤ 15ns (与 tcmalloc 对齐)
```

**慢路径 (IAllocator 通用 API)**:
```
IAllocator.GetMem(size) → TAllocator.GetMem → virtual DoGetMem
  → TThreadCacheAllocator.DoGetMem → TLS + CTZ
// 有 interface + virtual dispatch 开销 (~5-8ns)
// 预期: ≤ 25ns (仍比 FPC RTL ~100ns 快 4x)
```

| 操作 | tcmalloc 参考 | TCache 快路径 | TCache 慢路径 (IAllocator) |
|------|--------------|--------------|---------------------------|
| 小对象分配 (8-64B) | ~15ns | ≤ 15ns | ≤ 25ns |
| 小对象释放 | ~10ns | ≤ 10ns | ≤ 18ns |
| 中对象分配 (64B-32KB) | ~30ns | ≤ 30ns | ≤ 38ns |
| 大对象分配 (>32KB) | ~200ns | ≤ 200ns (platform_mmap_*) | ≤ 200ns |

**关键实现要求**:
- `@np_alloc` 的 Pascal 实现直接内联 TLS+CTZ 逻辑，不经过 IAllocator
- `BsfQWord` FPC 编译器内联函数 (`[internproc:fpc_in_bsf_x]`) → x86 BSF 指令，~3 周期
- ARM64: `RBIT` + `CLZ` 内联汇编
- TLS lookup: 使用 `platform_tls_get` (~3-5ns)，评估是否可优化到 ~1ns (如 Go 的 `%gs:` 方案)

### 4.3 与现有 IAllocator 的关系

当前 `nextpas.core.mem` 已有：

```
IAllocator (interface)
  └── TAllocator (base class)
        ├── DoGetMem / DoAllocMem / DoReallocMem / DoFreeMem (virtual)
        ├── Traits: ZeroInitialized, ThreadSafe, HasMemSize, SupportsAligned
        └── AlignUpPtr / AllocAligned / FreeAligned
```

已有后端：RTL 默认, mimalloc, mmap, callback。

**TCache 架构不替换 IAllocator 接口**，而是新增一个 TThreadCacheAllocator 后端（纯 Pascal 实现）：

```
IAllocator
  └── TAllocator
        ├── TRtlAllocator        (现有, FPC RTL)
        ├── TMimallocAllocator   (现有, mimalloc binding)
        ├── TThreadCacheAllocator (新增, TCache 3 级架构 (纯 Pascal))
        │     ├── TThreadCacheCtx (per-thread TThreadCache, CTZ bitmap)
        │     ├── TCentralCache (per-sizeclass, spinlock)
        │     └── THeap (radix tree, mmap)
        └── ...
```

### 4.4 实现计划

**S8.1: Size classes 定义**
- 67 个大小类 (8B-32KB)，参照 Go 的 `size_classes.go` 生成规则
  - 小 class (≤32B): 每 8B 一档
  - 中 class (32B-2KB): 每 12.5% 增长，rounded to 8B
  - 大 class (2KB-32KB): 每 256B 一档
- Size→class 路由: 查表法 (256 entries, 1 byte each, 覆盖 8B-2KB) + 大 class 除法
- 每个 class 的 span 大小、pages 数、元素数、CTZ bitmap 宽度
- 对齐: 所有 sizeclass 保证 8-byte alignment；>16-byte 对齐需求走 page-aligned mmap

**S8.2: TThreadCache (per-thread)**
- **TLS 方案已确定**: 使用已有的 `platform_tls_*` API (`nextpas.core.platform.thread`)
  - 不使用 FPC `threadvar` (依赖 FPC RTL)
  - 不自研 TLS 抽象层 (platform 层已有)
  - **需扩展**: `platform_tls_create` 增加 destructor callback 参数
    - Linux: `pthread_key_create` 的 destructor
    - Windows: `FlsAlloc` callback (TlsAlloc 不支持 destructor)
- **S8.2.1: Thread cache destructor**
  - 线程退出时将 TThreadCache 中所有非空 span 归还 TCentralCache
  - 防止线程退出导致的内存泄漏
- **CTZ 原语** (前置，放 `nextpas.core.mem.bitscan`):
  - x86-64: `BsfQWord` FPC 编译器内联函数 → BSF 指令 (~3 周期)
  - ARM64: `RBIT` + `CLZ` 内联汇编
  - 封装为 `function FindFirstSetBit(v: QWord): SizeUInt; inline;`
- CTZ bitmap 空闲 slot 查找
- Cache hit: 无锁快路径 (~15ns)
- Cache miss: 从 TCentralCache batch refill (一个完整 span, ~128 对象)
- Per-thread 内存预算: 67 × ~64 bytes ≈ 4KB per thread

**S8.3: TCentralCache (per-sizeclass)**
- 自旋锁保护
- 管理 span 列表 (empty/partial/non-empty)
- 从 THeap 获取新 span
- Batch refill: 一次向 TThreadCache 提供一个完整 span (~128 对象)

**S8.4: THeap (global)**
- **OS 层直接使用 `platform_mmap_*`** (不经过 TMemoryMap)
  - TMemoryMap 是文件映射封装器，不适合堆管理
  - `platform_mmap_anonymous` 按需分配大块 (如 64MB region)
  - `platform_munmap` 部分释放
  - `platform_mprotect` 用于 guard page (P4b 栈溢出检测)
- Radix tree page map (5 级, 每级 8-bit, 覆盖 1TB 虚拟地址)
  - **支持 address→span 反查**: ReallocMem 需要从指针反查 sizeclass
- 大对象直分配 (>32KB, page-aligned mmap 天然对齐)
- **Span 合并 (buddy system)**:
  - 释放 span 时检查 buddy span 是否空闲，是则合并
  - 合并递归进行直到无法合并
  - 参考 `TFixedSlabPool` 中 `ngx_slab_free_pages` 的实现
- **Scavenge (向 OS 归还)**:
  - 空闲 span 通过 `madvise(MADV_DONTNEED)` (Linux) / `VirtualFree(MEM_DECOMMIT)` (Windows) 延迟归还
  - 比激进 `munmap` 更优 (避免重新 mmap 的 syscall 开销)
  - 定期扫描或阈值触发

**S8.5: ReallocMem 优化**
- 如果新 size 和旧 size 属于同一 sizeclass → 原地返回 (零拷贝)
- 如果跨 sizeclass → 分配新块 + 拷贝 + 释放旧块
- 需要 radix tree 的 address→span 反查支持

**S8.6: 替换 @np_alloc/@np_free — 双轨路径**
- **编译器内部路径** (快路径):
  - `@np_alloc` 的 Pascal 实现直接内联 TLS+CTZ 逻辑
  - 不经过 IAllocator 接口，无 interface/virtual dispatch
  - 预期 ≤ 15ns
- **用户 API 路径** (慢路径):
  - `IAllocator.GetMem` → `TThreadCacheAllocator.DoAllocMem` (有 dispatch)
  - 预期 ≤ 25ns
- `np.system.heap_alloc/free` 契约从 vocabulary 变为 live

**S8.7: TCache 统计接口**
- `TCacheStats` record: per-sizeclass 分配/释放计数, cache hit/miss 率
- Central fill 次数, total committed/resident 内存, fragmentation 率
- 与现有 `nextpas.core.mem.stats` 快照机制集成

### 4.5 验收标准

- [ ] 67 大小类定义完整 + size→class 查表路由
- [ ] `FindFirstSetBit` (BSF/TZCNT) 原语: x86-64 + ARM64
- [ ] TLS: platform_tls_* + destructor callback 扩展
- [ ] TThreadCache 快路径 (编译器直连): 分配 ≤ 15ns, 释放 ≤ 10ns
- [ ] TThreadCache 慢路径 (IAllocator): 分配 ≤ 25ns, 释放 ≤ 18ns
- [ ] TCentralCache miss 填充 ≤ 30ns, batch refill 正确
- [ ] THeap radix tree 5 级 page map + address→span 反查
- [ ] THeap 大对象 page-aligned mmap ≤ 200ns
- [ ] Span 合并 (buddy system) 正确性
- [ ] Scavenge: madvise(MADV_DONTNEED) / VirtualFree(MEM_DECOMMIT)
- [ ] ReallocMem: 同 sizeclass 原地返回 (零拷贝)
- [ ] 线程退出: TLS destructor 归还 span 到 central
- [ ] @np_alloc 快路径绕过 IAllocator dispatch
- [ ] 多线程分配无竞态 (TSAN clean)
- [ ] heaptrc 0 leak
- [ ] 基准测试：快路径对齐 tcmalloc (~15ns)，慢路径比 FPC RTL 快 4x
- [ ] 与 TMimallocAllocator 性能对比报告
- [ ] TCache 统计接口可用 (hit/miss, fragmentation)

---

## 5. 支柱 3: Table-based Exceptions

### 5.1 当前状态

Gate 5 (Exception Unwind) 已 PASS：
- setjmp/longjmp freestanding x86_64 asm 完整
- try/except/finally HIR 模型完整
- 异常状态全局变量: `@__np_exc_stack`, `@__np_exc_pending`, `@__np_exc_object`

### 5.2 为什么需要 table-based

| 维度 | setjmp/longjmp (当前) | Table-based (目标) |
|------|----------------------|-------------------|
| 正常路径开销 | setjmp 保存寄存器 (~10ns) | **零开销** (查表) |
| 异常路径开销 | longjmp 恢复 (~20ns) | .eh_frame 遍历 (~100ns) |
| 代码膨胀 | 每个 try 块 +setjmp | 无额外代码 |
| 与 C++ 互操作 | 不兼容 | 兼容 (相同 unwind) |
| 调试器支持 | 无栈展开信息 | 完整栈展开 |

### 5.3 与 Go/Rust 对标

| 维度 | Go | Rust | nextPas 目标 |
|------|-----|------|-------------|
| 异常模型 | panic + recover | panic + unwind | try/except/finally |
| 展开机制 | DWARF .eh_frame | DWARF .eh_frame / panic=abort | DWARF .eh_frame |
| 正常路径 | 零开销 | 零开销 (unwind 模式) | 零开销 |
| 元数据 | .gopclntab | .gcc_except_table | .gcc_except_table |

### 5.4 实现计划

**前置条件**: LLVM 后端管线稳定 (P2 阶段)

**S9.1: DWARF 展开表生成**
- 编译器为每个函数生成 `.cfi` 指令
- try/except/finally 生成 landingpad 条目
- `.eh_frame` section 输出

**S9.2: Personality routine**
- 实现 Pascal personality routine (`__nextpas_personality_v0`)
- 处理 try/except/finally 的匹配逻辑
- 与异常对象模型集成

**S9.3: 替换 setjmp/longjmp**
- 删除 `@__np_exc_*` 全局状态
- `_Unwind_RaiseException` 替代 longjmp
- 保持 HIR 层不变 (只改 LLVM emission)

### 5.5 验收标准

- [ ] .eh_frame section 正确生成
- [ ] 正常路径零开销 (无 setjmp)
- [ ] try/except/finally 语义不变
- [ ] 与 C++ 异常互操作 (catch C++ exception)
- [ ] 异常路径栈展开正确

---

## 6. 支柱 4: Per-thread 内核（分两阶段）

> **Codex 建议拆分**: Go GMP 调度器本质上是一个 mini-Go runtime，Phase 2 时间线 (2026-Q4→2027-Q1) 无法承载。拆为：
> - **P4a**: 原子基础设施 + sync.Pool/Mutex (Phase 1，与 TString 并行)
> - **P4b**: G-M-P 调度器 + 工作窃取 (Phase 3+，LLVM 后端稳定后)

### 6.1 设计目标

为 nextPas 提供 Go 级别的并发基础设施：

```
OS Thread (M)
  └── Logical Processor (P)
        └── Goroutine-like Task (G)
              ├── runnext (快速路径)
              ├── local run queue
              └── stack (可增长)
```

### 6.2 与 Go/Rust 对标

| 维度 | Go GMP | Rust std::thread | nextPas 目标 |
|------|--------|-----------------|-------------|
| 调度模型 | GMP (Goroutine/M/Processor) | OS thread | P/M 分离 |
| 栈管理 | 可增长栈 (2KB 初始) | OS 默认 (8MB) | 可增长栈 |
| 同步原语 | channel + sync.Mutex | Mutex + RwLock | channel + mutex |
| 内存模型 | DRF-SC (2022 修订) | 所有权 + Send/Sync | DRF-SC |
| 原子操作 | seq_cst (全部) | 可选 ordering | seq_cst |

### 6.3 内存模型

采用 Go 2022 修订的内存模型：

```
happens-before = synchronizes-before ∪ sequenced-before (传递闭包)

DRF-SC 保证：
- 无数据竞争的程序 → 顺序一致性执行
- 数据竞争 = 未定义行为
```

**原子操作编译映射**:

| 操作 | x86-64 | ARM64 |
|------|--------|-------|
| Load(seq_cst) | MOV | LDAR |
| Store(seq_cst) | XCHG (implicit LOCK) | STLR |
| CAS(seq_cst) | LOCK CMPXCHG | CASAL (LSE) |

> **⚠️ ARM64 seq_cst 性能注意**: `STLR` (seq_cst store) 比 relaxed/acquire/release 重量级得多。Go 能承受全 seq_cst 是因为 goroutine 调度器的优化。nextPas 初期采用全 seq_cst（简化模型），未来可能需要更细粒度的 ordering 选项。

### 6.4 sync.Pool 设计

参照 Go 的 per-P pool:

```
// P4a 阶段 (简化版): P = OS 线程数
TSyncPool
  ├── FPrivate: array of Pointer           // per-thread 私有缓存 (无锁)
  ├── FShared: array of TLockFreeQueue     // per-thread 共享缓存 (无锁)
  └── FVictim / FVictimSize                // epoch 翻转时回收

// P4b 阶段 (完整版): P = 逻辑处理器数 (TProcessor)
TSyncPool
  ├── FPrivate: array[TProcessor] of Pointer
  ├── FShared: array[TProcessor] of TLockFreeQueue
  └── FVictim / FVictimSize
```

> **⚠️ 无 GC 的淘汰策略**: Go 的 victim flip 依赖 GC 周期。nextPas 无 GC，需替代方案：
> - **方案 A**: 时间驱动淘汰 — 每 N 秒执行 victim flip (timer callback)
> - **方案 B**: 显式 `Clear()` — 应用代码主动调用
> - **方案 C**: 每 epoch 回收 — 配合分配器 epoch 计数 (类似 Go tcmalloc 的 epoch reclaim)
> - 初期推荐方案 A (最简单)，后期可升级到方案 C

### 6.5 实现计划

**P4a (Phase 1): 原子与同步原语**

**S10.1: 原子基础设施**
- `TAtomic<T>` 泛型封装
- seq_cst load/store/CAS 原始操作
- x86-64 + ARM64 内联 asm

**S10.4a: sync.Pool / sync.Mutex (简化版)**
- per-thread 私有+共享缓存 (不依赖 GMP)
- 时间驱动 victim 回收 (替代 GC 翻转)
- Mutex 基于 futex (Linux) / WaitOnWindows (Windows)

**P4b (Phase 3+): G-M-P 调度器**

**S10.2: P/M 分离**
- `TProcessor` (P) — 逻辑处理器
- `TMachine` (M) — OS 线程绑定
- 工作窃取调度器

**S10.3: Task 栈管理**
- 可增长栈 (初始 4KB)
- 栈溢出检测 (guard page)
- 栈拷贝/迁移

**S10.4b: sync.Pool 升级**
- 从 per-thread 升级为 per-P 架构
- victim flip 与 GC/epoch 同步

### 6.6 验收标准

**P4a 验收**:
- [ ] TAtomic<T> seq_cst 正确性 (litmus test)
- [ ] sync.Pool 无锁快路径 + 时间驱动淘汰
- [ ] sync.Mutex 基于 futex/WaitOnWindows
- [ ] DRF-SC litmus test 全绿

**P4b 验收**:
- [ ] P/M 调度器可运行并发任务
- [ ] 工作窃取正确性 (所有任务完成)
- [ ] sync.Pool 升级为 per-P 架构
- [ ] 栈增长/收缩正确

---

## 7. 支柱 5: RAII for Records

### 7.1 设计目标

编译器在作用域出口自动插入 managed record 的 Finalize 调用，无需 try/finally：

```pascal
procedure Foo;
var
  LBuf: TManagedBuffer;  // 有 IAllocator 字段
begin
  LBuf := TManagedBuffer.Create(1024);
  // ... 使用 LBuf ...
end;  // ← 编译器自动插入 LBuf.Finalize
```

### 7.2 与 Go/Rust 对标

| 维度 | Go | Rust | nextPas 目标 |
|------|-----|------|-------------|
| 值清理 | GC (无 RAII) | Drop trait (编译器插入) | 编译器插入 Finalize |
| 作用域出口 | 无操作 | 自动 drop | 自动 Finalize |
| 部分初始化 | N/A | 未初始化不 drop | 标记已初始化字段 |
| 异常安全 | N/A | drop on unwind | drop on exception |

> **⚠️ RAII vs Rust Drop 语义差异**: Rust Drop 基于所有权（exactly one owner），赋值触发 move 后原值不再有效。nextPas RAII 更接近 C++：值语义 + 自动析构。配合 CoW 语义，"赋值后原值是否还需要 finalize"是 Rust 不面对的问题——nextPas 需要明确 CoW refcount decr 与 RAII Finalize 的协作关系。

### 7.3 编译器集成

**语义分析**:
- 检测 record 是否含 managed fields (string, interface, dynamic array, managed record)
- 标记变量为 needs-finalize

**HIR 生成**:
- 作用域出口插入 `managed_record_fini` intrinsic
- 异常路径插入 cleanup landingpad
- 部分初始化追踪 (只 finalize 已初始化字段)

**LLVM emission**:
- 正常路径: scope exit → `@np_managed_record_fini`
- 异常路径: landingpad → cleanup → `@np_managed_record_fini`

### 7.4 实现计划

**S11.0: CoW refcount 与 RAII Finalize 协作协议**
- RAII finalize 时执行 refcount decr (decr 到 0 时释放堆内存)
- 赋值触发 CoW copy 时，旧值由赋值目标的 RAII 管理（不是源变量）
- 区分 move 语义 (refcount 转移，源置 nil) vs copy 语义 (refcount bump)

**S11.1: 编译器 managed field 检测**
- TypeDecl 分析: 标记含 managed 字段的 record
- VarDecl 分析: 标记需要 finalize 的局部变量

**S11.2: HIR scope exit 插入**
- THIRBuilder 在 block exit 插入 `managed_record_fini`
- 逆序插入 (后声明的先 finalize)

**S11.3: 异常路径 cleanup**
- Landingpad 生成
- Cleanup block 链
- 部分初始化 guard

**S11.4: np.system.managed_record_init/fini 实现**
- `managed_record_init`: 零初始化 managed fields
- `managed_record_fini`: 逆序 finalize 已初始化 fields

### 7.5 验收标准

- [ ] 含 string/interface/da 字段的 record 自动 finalize
- [ ] 部分初始化不 double-free
- [ ] 异常路径正确清理
- [ ] 嵌套 managed record 递归 finalize
- [ ] heaptrc 0 leak

---

## 8. 整合路线图

### 8.1 阶段总览

```
Phase 0: 自举完成 (当前 → 2026-Q3)
├── Gate 2: 单元生命周期 (global_ctors → topology-sorted _start)
├── Gate 3: 进程生命周期 (runtime 实现)
├── Gate 4: 堆管理器连接 (使用 bump allocator，不等 TCache)
├── Stage3≡Stage4 收敛
└── SysUtils.pas shim 管理

Phase 1a: 语言核心 (2026-Q3 → Q4)
├── P1: Custom TString
│   ├── S7.1: Layout
│   ├── S7.2: SSO
│   ├── S7.3: CoW
│   └── S7.4: text 集成
├── P5: RAII for Records (与 TString 并行)
│   ├── S11.0: CoW refcount 与 RAII Finalize 协议设计
│   ├── S11.1: managed field 检测
│   ├── S11.2: HIR scope exit
│   ├── S11.3: 异常 cleanup
│   └── S11.4: managed_record_init/fini
└── P4a: 原子 + 同步原语 (P4 拆分前半)
    ├── S10.1: TAtomic<T> 泛型封装
    └── S10.4a: sync.Pool/Mutex (简化版，per-thread)

Phase 1b: 性能基础 (2026-Q4 → 2027-Q1)
│ 前置条件:
│   ├── TLS destructor 扩展 (platform_tls_create + callback)
│   ├── BSF/TZCNT 原语 (nextpas.core.mem.bitscan)
│   └── compiler-arch-debt C5/C6 完成
├── P2: TCache (bump allocator → 3 级分配器替换)
│   ├── S8.1: Size classes + 查表路由
│   ├── S8.2: TThreadCache (TLS + CTZ bitmap)
│   ├── S8.3: TCentralCache (batch refill)
│   ├── S8.4: THeap (radix tree + buddy + scavenge)
│   ├── S8.5: ReallocMem 优化 (同 sizeclass 零拷贝)
│   ├── S8.6: 双轨路径 (编译器直连 + IAllocator)
│   └── S8.7: TCache 统计接口
└── Gate 4 闭合: @np_alloc 快路径 + IAllocator 慢路径

Phase 2: LLVM 后端巩固 (2027-Q1 → Q2)
├── Gate 1 闭合: RTTI 形状一致性深化
├── 泛型实例化完善
├── 编译器性能调优
└── Stage3→Stage4 差异验证

Phase 3: 并发调度 + 异常升级 (2027-Q2+)
├── P4b: G-M-P 调度器 (P4 拆分后半)
│   ├── S10.2: P/M 分离
│   ├── S10.3: Task 栈管理
│   └── S10.4b: sync.Pool 升级为 per-P
├── P3: Table-based exceptions (LLVM 后端稳定后)
│   ├── S9.1: DWARF 展开表
│   ├── S9.2: Personality routine
│   └── S9.3: 替换 setjmp/longjmp
└── 自举编译器性能调优
```

**Phase 1 拆分理由 (Codex Round 2)**:
- **Phase 1a**: 语言核心改进 (TString + RAII + P4a)，无外部前置依赖
  - P5 RAII 提前: 自举编译器大量使用 try/finally，无 RAII 显著增加负担
  - P4a 拆入: 原子+同步原语不依赖 GMP，可与 TString 并行
- **Phase 1b**: 性能基础 (TCache)，有明确前置条件 (Codex Round 3 细化)
  - TLS destructor 扩展: `platform_tls_create` 需增加 callback (pthread_key_create / FlsAlloc)
  - BSF/TZCNT 原语: `nextpas.core.mem.bitscan` (FPC `BsfQWord` 内联函数)
  - compiler-arch-debt C5 (lvalue 模型) / C6 (allocator) 必须先完成
  - THeap 直接用 `platform_mmap_*`，不经过 TMemoryMap (文件映射封装器)
  - Phase 0 使用 bump allocator 完成自举，Phase 1b 用 TCache 替换

### 8.2 与自举门的对应关系

| 支柱 | 影响的 Gate | 闭合方式 |
|------|-------------|----------|
| P2 TCache | Gate 4 (Heap Manager) | @np_alloc → TThreadCacheAllocator |
| P1 TString | 间接 (string_init/fini 实现) | np.system.string_* 变为 live |
| P5 RAII | 间接 (managed record cleanup) | managed_record_init/fini 实现 |
| P4a Atomics/Sync | 间接 (并发基础设施) | TAtomic + sync primitives |
| P4b G-M-P | Gate 2/3 间接 (lifecycle sequencing) | unit/process init/fini 在 P/M 中执行 |
| P3 Table-based | Gate 5 (Exception) | setjmp/longjmp → DWARF unwind |

### 8.3 Gate 2/3 独立推进 (不等支柱)

Gate 2 (单元生命周期) 和 Gate 3 (进程生命周期) 是自举硬阻塞，
必须在 Phase 0 完成，不依赖任何支柱。

**Gate 2 当前状态: PARTIAL** — 编译器管线已就绪，需完成：
1. ✅ `SeedUnitLifecycleBodies` 已实现 (sema:14887-14972)
2. ✅ LLVM emitter 已注册 `@llvm.global_ctors/dtors` (emitter:1258-1304)
3. ⬜ 优先级排序: 当前全为 65535，需实现 S6 的 `_start` 驱动拓扑排序
4. ⬜ 运行时: `_start` 驱动 (process_init → 拓扑序 unit_init → main → 逆序 unit_fini → process_fini → halt)

**Gate 3 当前状态: PARTIAL** — 编译器侧就绪，需完成：
1. ✅ `'process-init-runtime'` → `hnkProcessInitRuntime` (hir_types:259)
2. ✅ `EmitProcessInit`/`EmitProcessFini` 存在 (hir_builder:7430-7452)
3. ✅ LLVM emitter 声明 `@np_process_init`/`@np_process_fini` (emitter:1310-1311)
4. ⬜ 运行时: `np_process_init`/`np_process_fini` 实际实现 (nextpas.core.system 内)
5. ⬜ `_start` 改为: `process_init → main → process_fini → halt`

---

## 9. 风险分析

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| TString CoW 与 FPC AnsiString 不兼容 | 高 | 高 | 渐进迁移，保留 FPC string 作 stage0 |
| CoW refcount atomic 开销 | 中 | 中 | 赋值密集场景 profile，考虑 relaxed ordering |
| TCache ≤15ns 需绕过 IAllocator dispatch | 高 | 高 | 双轨路径: 编译器直连快路径 + IAllocator 慢路径 |
| TLS destructor 扩展 (platform_tls_*) | 高 | 高 | Linux pthread_key_create / Windows FlsAlloc callback |
| THeap OS 层: platform_mmap_* 而非 TMemoryMap | 中 | 低 | TMemoryMap 是文件映射，直接用 platform_mmap_* |
| TCache 跨平台 (Windows/macOS) | 中 | 中 | platform_mmap_* 已跨平台 |
| LLVM global_ctors 顺序不确定 | 高 | 中 | Phase 0 实现 _start 驱动拓扑排序替代 |
| RAII 改变语义分析复杂度 | 高 | 中 | 先支持 record，class 用现有 Free 机制 |
| Phase 1b 依赖 compiler-arch-debt C5/C6 | 高 | 高 | Phase 1b 前置条件明确，C5/C6 未完成则推迟 |
| G-M-P 调度器实现复杂度 | 高 | 高 | 拆为 P4a/P4b，Phase 3+ 才做完整调度器 |
| sync.Pool 无 GC 导致内存泄漏 | 中 | 中 | 时间驱动淘汰 (timer callback) |
| Table-based 需要 LLVM 成熟度 | 中 | 低 | setjmp/longjmp 可完成自举 |

---

## 10. 测试策略

### 10.1 每支柱独立测试

每个支柱必须有：
- **单元测试**: 该支柱核心逻辑
- **集成测试**: 与现有系统的交互
- **泄漏测试**: heaptrc 0 leak
- **性能基准**: 与对标系统的比较

### 10.2 回归测试保护

- 现有 24 个 mem suites (147 个 T.Run 用例，全绿)
- 现有 16 个 text suites (58 个 T.Run 用例)
- 现有 19 个契约源码边界检查
- 每次支柱变更必须通过 `make verify`

### 10.3 性能基准线（对齐 tcmalloc）

| 指标 | tcmalloc 参考 | FPC RTL 参考 | TCache 目标 |
|------|--------------|-------------|-------------|
| 小对象分配 (8-64B) | ~15ns | ~100ns | ≤ 15ns |
| 小对象释放 | ~10ns | ~50ns | ≤ 10ns |
| 中对象分配 (64B-32KB) | ~30ns | ~200ns | ≤ 30ns |
| 大对象分配 (>32KB) | ~200ns (mmap) | ~500ns | ≤ 200ns |
| 字符串赋值 (SSO) | N/A | ~30ns | ≤ 10ns |
| 字符串赋值 (CoW) | N/A | ~30ns | ≤ 15ns |
| 异常正常路径 | N/A | setjmp ~10ns | 0ns |
| 原子 CAS | N/A | ~15ns | ~15ns |

> **注**: "基准线"列中的 tcmalloc/FPC RTL 值为估算，实现时需实测校准。

---

## 11. 确认的讨论记录

### 11.1 分配器选型：TCache vs jemalloc vs mimalloc

**结论**: 采用 TCache 3 级架构（纯 Pascal 实现），不直接集成 tcmalloc/jemalloc/mimalloc 库。

理由:
- Go runtime malloc 的 mcache→mcentral→mheap 3 级分层清晰，与 IAllocator 接口兼容
- jemalloc 的 arena 模型在 Pascal 单线程默认假设下过度设计
- mimalloc 已有一个后端 (`TMimallocAllocator`)，可作对比基准
- 纯 Pascal 自研实现可完全控制内存布局和 nextPas 特定优化 (如对象头 magic)

### 11.2 TString CoW vs 不可变

**结论**: 采用 CoW (Copy-on-Write)，不是纯不可变。

理由:
- Pascal 的 `string` 语义允许原地修改 (`S[i] := 'x'`)
- 纯不可变需要每次修改都重新分配，对现有代码破坏太大
- CoW 保持 refcount 语义兼容 FPC AnsiString 行为
- SSO 在 ≤16B 时完全避免 refcount 开销

### 11.3 RAII 优先级

**结论**: RAII 提升到 Phase 1，与 TString 并行开发。

理由:
- **Codex 审查 (Round 1)**: 自举编译器大量使用 try/finally，无 RAII 显著增加认知负担和代码量
- RAII 与 TString 有天然协同：CoW string 是最常见的 managed field
- P4a (原子基础设施) 已从 G-M-P 中拆出，Phase 1 有足够容量
- 原 "Phase 2 不阻塞自举" 的判断仍然正确，但 "高优先级改进" 比 "延后" 更合理

### 11.4 内存模型选择

**结论**: 采用 Go 2022 修订版 (DRF-SC)。

理由:
- 比 C++11 memory model 简单 (全部 seq_cst)
- 比 Rust 所有权模型实现成本低 (无需 borrow checker)
- 与 Go 的互操作性好
- DRF-SC 保证对程序员友好

### 11.5 Per-thread 调度 vs goroutine

**结论**: P4 拆为 P4a (Phase 1) + P4b (Phase 3+)。

理由:
- **Codex 审查 (Round 1)**: Go GMP 调度器本质上是一个 mini-Go runtime，Phase 2 时间线无法承载
- P4a (TAtomic + sync.Pool/Mutex): 独立基础，不依赖 GMP，可与 TString 并行
- P4b (P/M 分离 + 工作窃取 + 栈管理): 需要 LLVM 后端稳定，Phase 3+ 才做
- goroutine 需要编译器深度集成 (栈增长点注入)，是更远期目标

### 11.6 TCache 分配器定位

**结论**: TCache 不阻塞自举，是自举后性能优化的首要目标。

理由:
- **Codex 审查 (Round 1)**: @np_alloc/@np_free 已有 mmap+free-list bump allocator，足以支撑自举
- 将 TCache 标记为 "阻塞自举" 会误导优先级判断
- 自举完成后，TCache 替换 bump allocator 是最高优先级性能优化
- 命名统一为 TCache，纯 Pascal 实现，零外部依赖

### 11.7 TLS 前置依赖

**结论**: 使用已有 `platform_tls_*` API + 扩展 destructor callback。

理由:
- **Codex 审查 (Round 3)**: `nextpas.core.platform.thread` 已有 `platform_tls_create/destroy/set/get`
- FPC `threadvar` 不可用 (依赖 FPC RTL)
- 不自研 TLS 抽象层 (platform 层已足够)
- **需扩展**: `platform_tls_create` 增加 destructor callback
  - Linux: `pthread_key_create` 的 destructor 回调
  - Windows: `FlsAlloc` callback (`TlsAlloc` 不支持 destructor)
- TLS lookup 开销: `pthread_getspecific` ~3-5ns，评估是否可优化
- 线程退出时 destructor 将 TThreadCache span 归还 TCentralCache

### 11.8 LLVM global_ctors 顺序

**结论**: 当前 unit_init 注册到 @llvm.global_ctors 的顺序不确定。

理由:
- **Codex 审查 (Round 1)**: 所有 unit 的优先级同为 65535，LLVM 不保证同优先级内顺序
- 跨翻译单元顺序由链接器决定（通常按 .o 文件链接顺序，非拓扑序）
- 需要 S6 的 `_start` 驱动初始化方案来替代 global_ctors 机制
- 这是 Gate 2 从 PARTIAL → PASS 的关键缺口

### 11.9 sync.Pool 无 GC 淘汰

**结论**: 采用时间驱动淘汰 (timer callback) 作为初期方案。

理由:
- **Codex 审查 (Round 1)**: Go 的 victim flip 依赖 GC 周期，nextPas 无 GC
- 无淘汰策略 → pool 无限增长 → 内存泄漏
- 时间驱动最简单：每 N 秒执行 victim flip
- 后期可升级为 per-epoch 回收 (类似 Go tcmalloc 的 epoch reclaim)

### 11.10 纯 Pascal 分配器

**结论**: TCache 3 级分配器全部用纯 Pascal 实现，零 C/C++ 外部依赖。

理由:
- 外部依赖 (tcmalloc/jemalloc/mimalloc) 增加构建复杂度和跨平台风险
- nextPas 已有 `TMemoryMap` (mmap/VirtualAlloc) 作为 OS 抽象层
- `IAllocator`/`TAllocator` 接口已成熟，TCache 作为新后端接入
- 纯 Pascal 实现可完全控制内存布局，便于 nextPas 特定优化 (对象头 magic, 编译器集成)
- 已有 `TMimallocAllocator` 可作性能对比基准

---

## 12. 修订记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-06-18 | v1.0 | 初稿：5 支柱 + 优先级矩阵 + 5 节讨论记录 |
| 2026-06-18 | v2.0 | Codex Round 1 审查整改：Gate 2/3 FAIL→PARTIAL；P4 拆 P4a/P4b；RAII 提前 Phase 1；TCache 纯 Pascal 重定位；补充 TLS/global_ctors/sync.Pool/seq_cst/RAII-Drop 差异等 |
| 2026-06-18 | v3.0 | Codex Round 2 审查整改；新增 S11.0 CoW+RAII 协议：Phase 1 拆 1a/1b；测试数量核实修正；S6 完成状态细化；Gate 0 描述精确化；新增 S11.0 协作协议；compiler-arch-debt 依赖入风险表；优先级矩阵重标 |
| 2026-06-18 | v4.0 | tcmalloc→TCache 重命名：纯 Pascal 实现，零外部依赖；性能 SLA 对齐 tcmalloc |
| 2026-06-18 | v5.0 | Codex Round 3 审查整改：双轨路径 (编译器直连 ≤15ns + IAllocator ≤25ns)；TLS 选 platform_tls_* + destructor；THeap 改用 platform_mmap_*；新增 S8.5-S8.7 (ReallocMem/统计/双轨)；sizeclass 路由 + span 合并 + scavenge 详化 |
