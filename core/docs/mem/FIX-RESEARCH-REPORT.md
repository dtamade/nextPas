# nextpas.core.mem 问题修复 — 专题调研报告

**调研日期**: 2026-07-05
**调研范围**: 审查发现的 27 项问题（5 P1 + 12 P2 + 11 P3 - 1 已验证安全 = 26 有效）
**方法**: 根因分析 + Go/mimalloc/Rust 同类方案对标

---

## 一、问题分类与根因分析

### 1.1 Guard 分配器防御不完整 (CODE-001 / ARCH-002 / TEST-002)

**根因**: `TGuardAllocator` 的三个防御路径不一致：
- `DoGetMem`: 正常分配 → OK
- `DoFreeMem`: Magic 校验 → DEBUG 抛异常，Release 静默 Exit
- `DoReallocMem`: **未校验 Magic**，直接读 header

**对标分析**:

| 实现 | FreeMem 非法指针 | ReallocMem 非法指针 |
|------|-----------------|-------------------|
| mimalloc guard | SIGSEGV (unmapped) | 同上 |
| ASan | 报告 error | 报告 error |
| **nextpas Guard** | Release 静默 | **未校验 → SIGSEGV** |

**结论**: Guard 分配器的设计定位是**调试/安全检测**，性能不是首要目标。Release 模式静默吞掉错误违背了这个定位。

**深入分析** (agent 调研补充):

- `DoFreeMem` 的 Magic 检查在 Release 模式下静默 Exit 的设计意图是：Guard 分配器的 double-free 由 OS 级 SIGSEGV 检测（释放后页面变为 PROT_NONE），Magic 检查只是二级防御
- 但 `DoReallocMem` 完全绕过了 Magic 检查，且读取 header 后如果 Magic 不匹配，`LOldSize` 会是垃圾值，导致后续 `Move` 复制错误字节数
- mimalloc 的 guard page 实现：free 后直接 munmap，realloc 通过 new alloc + copy + free 实现，不读旧 header

**修复方案**:
1. `DoReallocMem` 在读 header 前校验 Magic，不匹配时返回 nil
2. `DoFreeMem` Release 模式改为始终抛异常（Guard 本身是调试用途）
3. 补充 ReallocMem + 非法指针测试

**风险评估**: 低。Guard 分配器是调试用途，改动不影响生产路径。

---

### 1.2 TBlockPool 架构问题 (ARCH-001 / ARCH-004)

**根因**: `TBlockPool` 是早期实现，直接用 `System.GetMem` 分配底层缓冲区。后续 `TFixedPool`、`TChunkedArena` 已改为支持 `IAllocator`，但 `TBlockPool` 未同步更新。

**双重数据结构分析** (agent 调研补充):
- `FFreeBits`: 位图，用于 O(1) double-free 检测
- `FFreeHead`: 侵入式 free-list，用于 O(1) 分配

两者各司其职，但必须保持一致。`TLocalBlockPool`（pool.pas 中）已采用同样的位图+free-list 设计，说明这是有意为之。与 `TFixedPool` 的 `FIsFree + FFreeStack` 设计思路一致，只是实现细节不同（QWord 位图 vs Boolean 数组）。

**agent 调研结论**: 位图+free-list 双数据结构是**设计权衡**而非技术债务。位图提供 O(1) double-free 检测（位操作 vs 数组索引），free-list 提供 O(1) 分配（指针操作 vs 位扫描）。两者配合是 O(1) + O(1) 的最优组合。建议保留并文档化。

**对标分析**:
- Go `mcentral`: 用 bitmap span（TSpan 的设计来源），纯位图 + BSF 分配
- mimalloc: 用 page bitmap + free-list
- **nextpas**: 位图（检测）+ free-list（分配），双数据结构

**修复方案**:
1. ARCH-001: 添加 `AAllocator: IAllocator` 构造参数，默认回退 `GetRtlAllocator`
2. ARCH-004: 保持双数据结构（已验证正确性），添加文档说明设计理由
3. 同步修改 `Destroy` 使用 `FAllocator.FreeMem`

**影响范围**: `TBlockPool` 构造签名变化 → `blockpool.concurrent.pas`、`blockpool.sharded.pas`、`blockpool.growable.pas` 的构造函数需同步更新。可通过添加重载构造函数保持向后兼容。

**风险评估**: 中。涉及 4 个文件的构造函数变更，需全面回归测试。

---

### 1.3 ThreadArena 全局单例限制 (ARCH-003 / CODE-004)

**根因**: `TThreadArenaManager` 使用 `GActiveManager: Pointer` 全局变量 + `pthread_key`/`FlsAlloc` 回调实现线程退出清理。回调中通过 `TLSCurrentManager` 查找 manager，但 `GActiveManager` 限制只能有一个活跃 manager。

**对标分析**:

| 方案 | 多实例支持 | 性能 | 复杂度 |
|------|-----------|------|--------|
| Go per-P mcache | ✅ (P 绑定) | ~5ns | 高（调度器集成） |
| mimalloc TLS page | ✅ (threadvar) | ~5ns | 中 |
| **nextpas threadvar** | ❌ 单实例 | ~2ns | 低 |

**深入分析** (agent 调研补充):
- `TGrowingAllocator` 的 `GThreadCache: threadvar` 也有同样限制
- 但 `TGrowingAllocator` 本身就是全局单例（`GGrowingAllocator`），设计如此
- `TThreadArenaManager` 的单例限制更严重：如果编译器和用户代码各自需要独立的 arena manager，无法共存
- agent 调研发现：`ThreadArenaCleanup` 回调中通过 `TLSCurrentManager` 查找 manager，但如果 manager 已被 Free，`TLSCurrentManager` 成为悬垂指针。`GActiveManager` 的存在是为了防止这种情况——它在 `Destroy` 时置 nil，回调检查后跳过
- 因此 `GActiveManager` 不仅是单例限制，更是安全机制。消除它需要同时解决悬垂指针问题

**修复方案对比**:

**方案 A: pthread_key per-key data**（推荐）
- 每个 `TThreadArenaManager` 创建独立的 `pthread_key`
- 回调通过 `pthread_getspecific(key)` 获取 manager 指针
- 消除全局单例限制
- 性能影响：热路径不变（TLS 读取仍是 O(1)）

**方案 B: 全局 manager 数组**
- 维护 `array[0..MAX_MANAGERS-1] of Pointer`
- 回调遍历数组清理
- 复杂度高，不推荐

**方案 C: 推迟**
- 当前编译器场景只需一个 arena manager
- `TGrowingAllocator` 单实例是设计决定
- 可文档化约束，推迟到真正需要多实例时再改

**推荐**: 方案 C（推迟）。当前无实际多实例需求，文档化约束即可。如果未来需要，方案 A 的改动范围可控（~50 行）。

**风险评估**: 方案 A 低风险（只改 arena.thread.pas），但需更新所有测试。

---

### 1.4 TrackingAllocator 异常路径 (CODE-002)

**根因**: `DoFreeMem` 的操作顺序是：
1. `MapDelete`（删除跟踪记录）
2. `FInner.FreeMem(ADst)`（实际释放）

如果步骤 2 抛异常（例如 RTL corruption），步骤 1 已执行，跟踪记录丢失。

**注意**: 原始 findings 描述为"先释放后记录"，但实际代码是"先删记录后释放"。问题本质相同：异常路径下记录和实际状态不一致。

**深入分析**:
- FPC 的 `System.FreeMem` 在正常情况下不会抛异常
- 只有在堆损坏（heap corruption）时才可能触发异常
- `TTrackingAllocator` 是测试/诊断用途，堆损坏本身就是测试失败
- 实际触发概率极低

**修复方案**: 交换操作顺序——先 `FInner.FreeMem`，成功后再 `MapDelete`。但这引入新问题：释放后到删除记录之间，如果另一个线程释放同一指针，会误判为合法操作。

**更优方案**: 保持当前顺序（先删记录后释放），但在 except 中恢复记录：
```pascal
procedure TTrackingAllocator.DoFreeMem(ADst: Pointer);
begin
  FLock.Acquire;
  try
    if not MapDelete(...) then raise EDoubleFree;
    try
      FInner.FreeMem(ADst);
    except
      MapInsert(...); // 恢复记录
      raise;
    end;
  finally
    FLock.Release;
  end;
end;
```

**风险评估**: 低。只影响异常路径，正常路径无变化。

---

### 1.5 SpinLock 无 backoff (CODE-003)

**根因**: `SpinLock` 使用紧密 CAS 循环，无退避机制。注释说"争用罕见"。

**争用分析**:
- TLS cache 吸收大部分流量（热路径 ~5ns）
- Central pool 仅在 TLS cache 满/空时访问（每 ~64 次操作一次）
- 4 线程场景：争用概率极低
- 32+ 线程场景：TLS cache miss 频率增加，争用概率上升

**对标分析**:

| 实现 | 退避策略 | 适用场景 |
|------|---------|---------|
| Go runtime | notesleep/notewakeup | 调度器级 |
| mimalloc | exponential backoff | 通用 |
| Linux kernel | exponential backoff + yield | 通用 |
| **nextpas** | 无 | TLS 已吸收 |

**修复方案** (agent 调研推荐): 添加简单 exponential backoff（~10 行代码）：

agent 调研指出：FPC 的 `AtomicCmpExchange` 不提供 pause/yield 语义（x86 的 `PAUSE` 指令）。纯 busy-wait 循环在超线程 CPU 上会浪费大量调度槽。推荐使用 `YieldProcessor` 或 `platform_thread_yield` 作为退避的最后手段。

```pascal
procedure SpinLock(var ALock: SizeUInt);
var
  LBackoff: UInt32;
begin
  LBackoff := 1;
  while AtomicCmpExchange(ALock, 1, 0) <> 0 do
  begin
    var I: UInt32;
    for I := 0 to LBackoff - 1 do
      ; // busy wait
    if LBackoff < 256 then
      LBackoff := LBackoff shl 1;
  end;
end;
```

**风险评估**: 低。backoff 只在争用时生效，无争用时零额外开销。但需注意：backoff 增加了最坏情况下的获取延迟（256 次循环 ≈ 几百纳秒），在极端延迟敏感场景需评估。

---

### 1.6 FindSpanIndex O(N) 扫描 (BENCH-001)

**根因**: `FindSpanIndex` 在 MRU cache miss 时线性扫描所有 entries。

**MRU cache 分析**:
- 连续 free 通常命中 MRU cache（同一 span 的连续释放）
- 跨 span 释放时 miss，触发 O(N) 扫描
- N = span 数量，通常很小（每个 size class 几个 span）

**修复方案**: page-indexed lookup
- 将地址右移 16 位（64KB 页）作为索引
- 维护 `array[0..65535] of Int32`（256KB 内存）
- O(1) 查找，消除线性扫描

**但**: 当前 span 数量通常 < 16，MRU cache 命中率 > 90%。O(N) 扫描的实际影响很小。

**推荐**: 推迟到有性能数据证明此路径是瓶颈时再优化。

---

### 1.7 TGrowingAllocator 未实现 IAllocator (BENCH-002)

**根因**: `TGrowingAllocator` 是独立 class，`FreeMem` 需要 `ASize` 参数（用于 size class 路由），但 `IAllocator.FreeMem` 不传 size。

**接口适配问题**:
```pascal
// TGrowingAllocator 的 FreeMem 需要 size
procedure FreeMem(APtr: Pointer; ASize: SizeUInt);

// IAllocator 的 FreeMem 不传 size
procedure FreeMem(ADst: Pointer);
```

**修复方案**: 提供 `TGrowingAllocatorAdapter: TAllocator` 包装类：
- 内部维护 `ptr → size` hash map（类似 TTrackingAllocator）
- `DoFreeMem` 查 map 获取 size，委托给 `TGrowingAllocator.FreeMem`
- 性能开销：每次 free 多一次 hash lookup (~10ns)

**但**: 当前 `TGrowingAllocator` 通过 `DefaultGrowingAllocator` 全局单例使用，无需多态。适配器只在需要传给 `TTrackingAllocator`/`TFallbackAllocator` 时才需要。

**推荐**: 推迟到有实际需求时再实现。

---

### 1.8 ChunkedArena Reset StartOffset 不一致 (CODE-007)

**根因**: `Reset(KeepSegments=True)` 时清零所有 segment 的 `StartOffset`，但 `FTotalSize` 只设为 `FSegments[0].Size`。

**影响分析**:
- `Alloc` 路径：只用 `LSegPtr^.Used` 和 `LSegPtr^.Size`，不依赖 `StartOffset` → 功能正确
- `CurrentUsed`：`FSegments[FActive].StartOffset + FSegments[FActive].Used` → Reset 后返回 0（因为 StartOffset 被清零）→ `UsedSize` 和 `Stats` 不准确
- `Stats.TotalUsed` 在 Reset 后首次调用返回 0 → 这是正确行为（Reset 后确实无使用）

**重新评估**: Reset 后 `UsedSize` 返回 0 是**正确语义**（没有分配任何内存）。`StartOffset` 被清零恰好使 `CurrentUsed` 返回 0，这不是 bug 而是巧合的正确行为。

**降级**: CODE-007 从 P3 降级为**非问题**（设计如此）。

---

### 1.9 TMemMutex.Init 无超时 (CODE-008)

**根因**: `Init` 中 `while True` 等待 `INITIALIZING` 状态完成。

**分析**:
- `INITIALIZING` 状态只在 `platform_mutex_init` 调用期间存在
- `platform_mutex_init` 是内核调用，通常 < 1μs
- 如果内核调用卡死，整个进程都会卡死（不仅仅是这个 mutex）
- 超时机制的实际价值很低

**对标**: Go `sync.Mutex` 也没有初始化超时。mimalloc 的 spinlock 也没有。

**降级**: CODE-008 从 P3 降级为**不修复**（设计如此，内核调用卡死是 OS 级问题）。

---

### 1.10 FallbackArena Reset 语义 (ARCH-005)

**根因**: `TFallbackArena.Reset` 只重置主 Arena，fallback 分配不受影响。

**分析**: 这是设计决定，文档已说明。`FreeFallbacks` 提供手动释放能力。

**对标**: Rust `bumpalo::Bump` 的 reset 也只重置 bump 区域，不处理外部分配。

**降级**: ARCH-005 保持 P3，不修复（设计如此）。

---

### 1.11 FallbackAllocator MapGrow tombstone (CODE-009)

**根因**: `MapGrow` rehash 时跳过 tombstone，但 `FFill`（包含 tombstone）在 rehash 后未重置为只计 live entries。

**实际影响**: 极低。Fallback 分配器使用频率不高，且 `FFill` 只影响 grow 触发时机。

**降级**: CODE-009 从 P3 降级为**不修复**（影响可忽略）。

---

### 1.12 规范类问题 (NORM-001/002/003/004)

**NORM-001**: `FAF_MEM_DEBUG` → `NEXTPAS_MEM_DEBUG`
- 影响 4 个文件：pool.fixed.pas, blockpool.pas, blockpool.sharded.pas, blockpool.growable.pas
- agent 调研结论：`FAF_MEM_DEBUG` 在 pool/blockpool 子系统内使用一致，且与 `NEXTPAS_ARENA_LEAK_CHECK`（arena 子系统）形成对称命名。重命名为 `NEXTPAS_MEM_DEBUG` 是规范统一，但当前命名并非 bug
- 纯重命名，零风险

**NORM-003**: sizeclass.pas 注释 "0..59" → "0..61"
- 2 处注释更新，零风险

**NORM-002**: 核心内部模块文档注释
- central/cache.thread/span/shuffle/sizeclass 的公开函数
- 纯文档，零风险

**NORM-004**: pool 门面 re-export 完整性
- 需要对照 ARCHITECTURE.md 类型清单验证
- 可能需要添加几个 re-export

---

### 1.13 测试类问题 (TEST-001/003/004)

**TEST-001**: GrowingAllocator.ReallocMem 边界
- 已有：same class / diff class / nil / to-zero
- 缺失：`ReallocMem(nil, 0, 0)` → nil、large→small resize、cross-boundary (>53KB)
- 补充 3-4 个测试

**TEST-003**: TArenaConcurrent 压力
- 已有：4 线程 wrapper、Reset vs Alloc 竞争、Mark vs Alloc 竞争
- 缺失：8-16 线程长时间压力、死锁检测
- 补充 1-2 个压力测试

**TEST-004**: SlabPoolSharded 并发
- 已有：9 个基本测试
- 缺失：多分片争用、路由均匀性
- 补充 2-3 个并发测试

---

## 二、影响范围评估

| 问题 | 影响文件数 | 向后兼容 | 测试影响 |
|------|-----------|---------|---------|
| CODE-001 | 1 (guard) | ✅ | 需新增测试 |
| ARCH-002 | 1 (guard) | ⚠️ 行为变化 | 需更新测试 |
| ARCH-001 | 4 (blockpool*) | ✅ 重载构造 | 需回归测试 |
| ARCH-003 | 1 (thread) | ✅ | 需更新测试 |
| CODE-002 | 1 (tracking) | ✅ | 需新增测试 |
| CODE-003 | 1 (central) | ✅ | 无需变更 |
| NORM-001 | 4 (pool/blockpool*) | ✅ | 无需变更 |
| NORM-003 | 1 (sizeclass) | ✅ | 无需变更 |
| NORM-002 | 5 (内部模块) | ✅ | 无需变更 |
| TEST-* | 3-4 测试文件 | N/A | 新增测试 |

---

## 三、修复策略与风险评估

### 策略一：最小修复（推荐）

只修复有实际影响的问题，推迟理论性问题：

| 优先级 | 问题 | 修复量 | 风险 |
|--------|------|--------|------|
| P1a | CODE-001 Guard ReallocMem Magic | 3 行 | 极低 |
| P1b | ARCH-002 Guard FreeMem 行为 | 1 行 | 低 |
| P1c | CODE-002 Tracking 异常路径 | 8 行 | 低 |
| P2a | NORM-003 注释更新 | 2 行 | 零 |
| P2b | NORM-001 命名统一 | 4 文件 | 极低 |
| P2c | CODE-003 SpinLock backoff | 10 行 | 低 |
| P3a | TEST-001 ReallocMem 边界 | ~40 行 | 零 |
| P3b | TEST-002 Guard ReallocMem | ~30 行 | 零 |

**总改动量**: ~100 行代码 + ~70 行测试
**预计时间**: 1 轮实施

### 策略二：全面修复

在策略一基础上增加：

| 优先级 | 问题 | 修复量 | 风险 |
|--------|------|--------|------|
| P4a | ARCH-001 TBlockPool IAllocator | ~80 行 + 4 文件 | 中 |
| P4b | NORM-002 文档注释 | ~100 行 | 零 |
| P4c | NORM-004 门面验证 | ~20 行 | 低 |
| P5a | TEST-003 压力测试 | ~80 行 | 零 |
| P5b | TEST-004 Sharded 测试 | ~60 行 | 零 |

**总改动量**: ~440 行代码 + ~140 行测试
**预计时间**: 2 轮实施

### 不修复项（已降级/推迟）

| 问题 | 原因 |
|------|------|
| ARCH-003 ThreadArena 单例 | 当前无多实例需求，文档化约束 |
| CODE-004 TLS cache | 当前单实例够用 |
| CODE-006 AllocUnsafe 溢出 | 设计契约（Unsafe 方法） |
| CODE-007 StartOffset | 非问题（Reset 后 UsedSize=0 是正确语义） |
| CODE-008 Mutex Init 超时 | 内核调用卡死是 OS 级问题 |
| CODE-009 MapGrow tombstone | 影响可忽略 |
| ARCH-005 FallbackArena Reset | 设计如此 |
| ARCH-006 模块膨胀 | 长期架构问题 |
| ARCH-007 RingBuffer 定位 | 长期迁移问题 |
| BENCH-001 FindSpanIndex | 当前 span 数量少，无性能问题 |
| BENCH-002 GrowingAllocator IAllocator | 当前无多态需求 |
| BENCH-003/004 基准对照 | 低优先级 |
