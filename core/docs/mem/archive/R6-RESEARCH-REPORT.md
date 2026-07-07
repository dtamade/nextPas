# nextpas.core.mem R6 可用性问题调研报告

**调研日期**: 2026-07-05
**调研范围**: 评估报告 R6 发现的 6 项问题
**调研方法**: 根因分析 + Go/Rust/Redis 方案对标

---

## 问题总览

| ID | 问题 | 优先级 | 类型 | 状态 |
|----|------|--------|------|------|
| F-R6-01 | MPSC inbox 并发崩溃 | P0 | 并发安全 | **根因确认** |
| F-R6-02 | TGrowingAllocator.FreeMem 双参数 | P1 | API 一致性 | **方案确定** |
| F-R6-03 | 两套 IAllocator 定义 | P1 | 架构债务 | **方案确定** |
| F-R6-04 | Acquire/GetMem 命名分裂 | P2 | API 一致性 | **方案确定** |
| F-R6-05 | platform.sync 编译错误 | P2 | 外部依赖 | **非 mem 模块** |
| F-R6-06 | SecureZeroString COW | P2 | 已知限制 | **已文档化** |

---

## F-R6-01: MPSC Inbox 并发崩溃 [P0]

### 根因分析

**崩溃位置**: `cache.thread.pas:314` — `MpscInboxPush` 中 `AtomicStorePtr(LPrev^.FNext, ...)`

**根因**: 三层问题叠加。

#### 层 1: Inbox 从未被消费

`TThreadCache.FInbox` (MPSC inbox) 的生命周期：

- ✅ 初始化: `ThreadCacheInit` → `MpscInboxInit(ACache.FInbox)`
- ✅ 生产: `ThreadCacheInboxPush` → `MpscInboxPush(ACache.FInbox, APtr)`
- ❌ **消费: 从未调用 `MpscInboxDrain`**

`TGrowingAllocator.GetMem` 的热路径只检查 `FHeads`（TLS free list），从不检查 `FInbox`。跨线程释放的块推入 inbox 后永远不被取出。

#### 层 2: 线程退出时 Inbox 未排空

`ThreadExitFlush` 的清理路径：

```pascal
procedure ThreadExitFlush(AData: Pointer); cdecl;
begin
  ThreadCacheFlushAll(GThreadCache, @FlushToCentral);  // 只排空 FHeads
  UnregisterThreadCache;                                 // 从全局注册表移除
  // ❌ GThreadCache.FInbox 未排空 — 跨线程释放的块泄漏
end;
```

`ThreadCacheFlushAll` 只遍历 `FHeads[0..N]`，完全忽略 `FInbox`。

#### 层 3: FindThreadCache 返回悬空指针

```pascal
function FindThreadCache(AThreadId: QWord): Pointer;
begin
  // 返回指向其他线程 TThreadCache 的原始指针
  if GThreadRegistry[LSlot].FActive then
    Result := GThreadRegistry[LSlot].FCache  // ← 悬空指针风险
  else
    Result := nil;
end;
```

**TOCTOU 窗口**:
1. Thread B 调用 `FindThreadCache(A_ID)` → 返回有效指针
2. Thread A 退出 → `UnregisterThreadCache` → `GThreadCache` TLS 内存释放
3. Thread B 调用 `ThreadCacheInboxPush` → 写入已释放内存 → **SIGSEGV**

### 崩溃路径复现

```
test_stability → TestRapidThreadCreation (100 rounds × 16 threads)

Round 1: Thread-1 allocates 16 blocks, frees locally, exits
Round 2: Thread-2 starts, gets SAME thread ID (pthread 复用), allocates
  → 但如果 Thread-1 的 UnregisterThreadCache 尚未完成
  → Thread-2 的 FindSpanOwnerThreadId 返回 Thread-1 的 owner ID
  → FindThreadCache 返回 Thread-1 的已释放 cache 指针
  → MpscInboxPush 写入悬空指针 → SIGSEGV
```

### 对标分析

| 系统 | 方案 | 优势 | 劣势 |
|------|------|------|------|
| **Go mcache** | GC 保护 + 全局 central | 无悬空指针 | 依赖 GC |
| **Redis** | 单线程 + IO threads 无共享 | 无并发问题 | 不适用 |
| **snmalloc** | 消息传递 + epoch-based | 无锁、无悬空 | 实现复杂 |
| **jemalloc** | TCACHE_NSLOTS 固定 + epoch | 简单 | 需要 ticker |
| **tcmalloc** | 独立 freelist + 延迟清理 | 高并发 | 内存开销大 |

**推荐方案**: 采用 **jemalloc 风格的 fixed-slot + epoch 方案**，具体如下。

### 修复策略

**核心思路**: 消除跨线程 inbox，改为直接归还 central pool。

```
当前路径 (有 bug):
  Thread B FreeMem → FindOwnerThread(A) → Push to A's Inbox → A never drains

修改后路径:
  Thread B FreeMem → FindOwnerThread(A) → A's cache active?
    → Yes: Push to A's Inbox (简化 MPSC, 正确 drain)
    → No:  Direct return to CentralPool (绕过 inbox)
```

#### 修复 1: ThreadExitFlush 排空 Inbox

```pascal
procedure ThreadExitFlush(AData: Pointer); cdecl;
begin
  // 新增: 先排空 MPSC inbox
  DrainInboxToCentral(GThreadCache);
  // 原有: 排空 FHeads
  ThreadCacheFlushAll(GThreadCache, @FlushToCentral);
  UnregisterThreadCache;
end;
```

#### 修复 2: FindThreadCache 增加安全检查

```pascal
function FindThreadCache(AThreadId: QWord): Pointer;
begin
  // 原子读取 + 活跃检查（无锁）
  Result := AtomicLoadPtr(GThreadRegistry[LSlot].FCache);
  if Result <> nil then
    if not AtomicLoadBool(@GThreadRegistry[LSlot].FActive) then
      Result := nil;
end;
```

#### 修复 3: 跨线程释放降级路径

当 `FindThreadCache` 返回 nil（目标线程已退出）时，直接归还 central pool：

```pascal
if LOwnerCache <> nil then
  ThreadCacheInboxPush(...)
else
  CentralPoolFree(FCentrals[LIndex], 1, @APtr, GThreadCache.FOpCount);
```

#### 修复 4: 简化 MPSC Inbox

当前的 Vyukov MPSC 队列 drain 逻辑过于复杂（sentinel re-insertion 有竞态窗口）。改用 **Treiber stack**（CAS singly-linked list）：

```pascal
// Push: single CAS
repeat
  LOldHead := AtomicLoadPtr(FHead);
  LNode^.FNext := LOldHead;
until AtomicCmpExchange(FHead, LNode, LOldHead) = LOldHead;

// Pop all: single atomic exchange
LHead := AtomicExchangePtr(FHead, nil);
// reverse and return
```

Treiber stack 的优势：
- Push 1 次 CAS（vs MPSC 的 1 次 exchange + 1 次 store）
- Pop all 1 次 atomic exchange（vs MPSC 的复杂 drain + sentinel re-insertion）
- 无 sentinel 节点 → 无生命周期问题
- LIFO 顺序 → 更好的缓存局部性

### 影响范围

- `cache.thread.pas`: MPSC inbox 重写为 Treiber stack
- `allocator.growing.pas`: ThreadExitFlush + FreeMem 降级路径
- `test_stability`: 验证修复

### 风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| Treiber stack ABA | 低 | 高 | 64 位指针 + epoch（或直接用 tagged pointer） |
| Drain 时序窗口 | 中 | 中 | atomic exchange 保证原子性 |
| 性能回退 | 低 | 低 | Treiber push 同样是 1 次 CAS |

---

## F-R6-02: TGrowingAllocator.FreeMem 双参数 [P1]

### 根因分析

`TGrowingAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt)` 要求调用方传入分配大小。这是有意的性能优化：通过 `ASize` 直接计算 size class index，避免查表。

对比 `IAllocator.FreeMem(ADst: Pointer)` 不需要 size——因为 RTL allocator 的 `FreeMem` 可以从堆头部读取大小。

### 对标分析

| 系统 | FreeMem 签名 | 原因 |
|------|-------------|------|
| Rust `GlobalAlloc` | `dealloc(ptr, layout)` | Layout 包含 size + align |
| Rust `Allocator` | `deallocate(ptr, layout)` | 同上 |
| Go `runtime` | 内部 free(mspan, x) | mspan 知道 size class |
| jemalloc | `je_free(ptr)` | ptr → extent → size |
| tcmalloc | `tc_free(ptr)` | span 知道 size |

**关键观察**: Rust 也需要 size，但通过 `Layout` 封装。Go 不需要是因为 GC + mspan 自动关联。jemalloc/tcmalloc 不需要是因为通过 span/extent 元数据反查。

### 方案对比

| 方案 | 改动量 | 性能影响 | 兼容性 |
|------|--------|----------|--------|
| A: 实现 IAllocator（反查 size） | 中 | +2-5ns/free | 完全兼容 |
| B: 提供 Wrapper 类 | 小 | +3-8ns/free | 完全兼容 |
| C: 文档说明"有意设计" | 最小 | 无 | 不兼容 IAllocator |
| D: 保留双参数 + 增加单参数重载 | 小 | 0 (inline) | 部分兼容 |

**推荐方案 D**: 增加 `FreeMem(APtr: Pointer)` 重载，内部通过 span 元数据反查 size。热路径保持双参数版本不变。

```pascal
// 保留: 高性能路径（调用方已知 size）
procedure FreeMem(APtr: Pointer; ASize: SizeUInt); inline;

// 新增: IAllocator 兼容路径（通过 span 反查 size）
procedure FreeMem(APtr: Pointer); // 查 span → size class → size
```

### 影响范围

- `allocator.growing.pas`: 新增 `FreeMem(APtr)` 重载
- 可选: 实现 `IAllocator` 接口适配器

---

## F-R6-03: 两套 IAllocator 定义 [P1]

### 根因分析

两条继承链：

```
链 1 (mem.intf.pas):
  IAllocator = interface [GUID: 1CEB691D...]
  ← 5 methods (GetMem/AllocMem/ReallocMem/FreeMem/Traits)

链 2 (allocator.base.pas):
  IAllocator = nextpas.core.mem.intf.IAllocator  ← alias，同一个 GUID
  TAllocator = class(TInterfacedObject, IAllocator)
  TMemAllocator = class(TAllocator)              ← 额外基类
```

实际上 `allocator.base.pas` 的 `IAllocator` 是 `mem.intf.pas` 的 alias，GUID 相同。但 `TAllocator` / `TMemAllocator` 基类只在 `allocator.*` 体系中使用，`mem.*` 体系的类直接实现接口。

### 方案

**推荐**: 统一文档，明确 canonical 入口。不做代码合并（改动太大，收益太小）。

1. 在 `allocator.base.pas` 头注释说明 "canonical IAllocator 在 mem.intf.pas，此处仅为基类便利"
2. 在门面 `mem.pas` 中只 re-export `mem.intf.pas` 的 IAllocator（当前已是如此）

---

## F-R6-04: Acquire/GetMem 命名分裂 [P2]

### 根因分析

| 接口 | 方法 | 语义 |
|------|------|------|
| IPool | `Acquire(out P): Boolean` | 分配固定大小槽位 |
| IMemoryPool | 继承 IPool + `GetMem(Size): Pointer` | 分配任意大小 |
| IAllocator | `GetMem(Size): Pointer` | 通用分配 |

`TFixedSlabPool` 同时实现 `IMemoryPool` 和 `IAllocator`，但 `Acquire` 分配最小 slab 单元，`GetMem` 走 size-class 路由。

### 方案

**推荐**: 文档增强，不改代码。

1. 在门面决策表增加 "固定大小 vs 通用" 场景对照表
2. 在 `IPool` 接口注释说明 "Acquire 分配固定槽位，不等同于 GetMem"

---

## F-R6-05: platform.sync 编译错误 [P2]

### 根因

`nextpas.core.platform.sync.pas:1261` 使用 `L'kernel32'` 宽字符串字面量，当前 FPC 版本不支持此语法。

### 方案

**非 mem 模块问题**。标记为外部依赖，由 platform 模块 owner 修复。

---

## F-R6-06: SecureZeroString COW 限制 [P2]

### 根因

Pascal 字符串使用引用计数 + COW。`UniqueString` 创建新副本后清零，但原始缓冲区（可能被其他引用持有）数据仍在内存中。

### 方案

**已文档化，无法在不破坏语义的前提下修复**。保持现状。

---

## 依赖关系图

```
F-R6-01 (P0) ─── 独立，最高优先级
    │
    ├── 修复 1: ThreadExitFlush drain inbox
    ├── 修复 2: FindThreadCache 安全检查
    ├── 修复 3: FreeMem 降级路径
    └── 修复 4: MPSC → Treiber stack

F-R6-02 (P1) ─── 依赖 F-R6-01 完成（同一文件 growing.pas）
    │
    └── 新增 FreeMem(APtr) 重载

F-R6-03 (P1) ─── 独立，仅文档
F-R6-04 (P2) ─── 独立，仅文档
F-R6-05 (P2) ─── 外部依赖
F-R6-06 (P2) ─── 无需处理
```

---

## 测试验证计划

| 测试 | 验证内容 | 预期 |
|------|----------|------|
| test_stability | MPSC 并发 crash | 0 crash, 0 leaks |
| test_concurrent | 跨线程释放 | 通过 |
| test_thread_arena | 线程退出清理 | 通过 |
| 新增: test_inbox_stress | 8T × 100K inbox push/drain | 0 crash |
| 新增: test_cross_thread_exit | 分配→线程退出→跨线程释放 | 0 crash, 0 leaks |
| test_mem ~ test_sharded_pools (全量) | 回归测试 | 全绿 |
