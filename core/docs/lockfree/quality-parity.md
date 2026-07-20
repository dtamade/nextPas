# Atomic / Lockfree — Q 线（Quality / Parity）

> **状态**: **Q0–Q5 done** · **Q1-b/c done** · Maintenance
> **日期**: 2026-07-20
> **Owner**: atomic-lockfree lane（全权）
> **目标**: 对标 Go/Rust 的 **质量与可用规模**，并保持清洁
> **编号**: **Q0–Q5**（**不是** R9；R8 仍为研究 opt-in）
> **对标矩阵**: [`parity-go-rust.md`](parity-go-rust.md)

权威契约仍是 [`CONTRACT.md`](CONTRACT.md)。状态入口 [`READY.md`](READY.md)。

---

## 0. 对标定义

| 维度 | 含义 |
|------|------|
| **质量** | 契约诚实、测试硬、首选 API 清晰、生命周期可教 |
| **规模** | T1「写 runtime 够用」+ T2 精炼可导航；**不是**源文件最多 |
| **清洁** | 门面精、progress 诚实、有信封证据、无产物污染、小步 commit |

**对标面**（精神，非抄 API）：

- Go：`sync/atomic`、buffered `chan`、`select`、`sync.Map` 级工具箱
- Rust：`std::sync::atomic`、channel/flume 精神、dashmap 级分片 map

---

## 1. 阶段

| 阶段 | 名称 | 状态 |
|------|------|------|
| **Q0** | 清洁基线 + reconverge 评估 | **done** |
| **Q1** | Atomic 首选路径与质量加固 | **done**（a 扫描；b 边界测已覆盖；c 交叉链接） |
| **Q2** | T1 深度（首选路径 + stress） | **done** — T1 preferred path 全量；verify-t1 绿；已 land main |
| **Q3** | Map/Channel 体验对标 | **Q3-a/b/c done**（Selector 钉死 + Channel 对标表 + HashMap progress 诚实） |
| **Q4** | T2 精炼（审计 / 降档 / 可选生产子集） | **done** — inventory + **不扩** H3-2 |
| **Q5** | 有信封 Go/Rust 同机对照常青 | **done** — compare-matched C1/C2 + envelope |

```
H3 complete → Q0 → Q1 → Q2 → Q3 → Q4 → Q5 → Maintenance 循环
```

### Q0 通过标准

- `verify-t1` + `verify-h3-consumers` + `test_worksteal` 绿
- `make hygiene` 绿
- reconverge 评估写入本文件 §2
- READY/roadmap 指向 Q 线

### 非目标（全 Q 线）

- invent **R9**
- R8 生产化 / T2 默认门面 / 删 legacy CAS / 改 Closed 语义
- 无信封绝对 Mops 营销
- 为「文件数」堆 T2 算法

---

## 2. Reconverge 评估（Q0）

| 项 | 值（2026-07-19） |
|----|------------------|
| HEAD | `e4761b7fc` |
| vs `origin/main` | 领先 13 / 落后 63 |
| main 触及 atomic/lockfree 源 | **无**（路径空） |
| main 触及 async 消费者 | **有**（PostEx/OnDiscard 等） |
| main 触及 thread.worksteal | **无** |

**结论**：atomic/lockfree 本体与 main 无直接冲突面；已 **merge origin/main**（Q0），post-merge `verify-h3-consumers` + `test_worksteal` + hygiene 绿。

---

## 3. 验证入口

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make -C core/tests/nextpas.core.lockfree verify-h3-consumers
make -C core/tests/nextpas.core.thread/test_worksteal clean test
make hygiene
```

Bench 信封：[`bench-envelope.md`](bench-envelope.md)。

---

## 4. 进度记录

| 日期 | 事件 |
|------|------|
| 2026-07-19 | Q 线章程入仓；Q0 门绿；merge origin/main；post-merge 门绿 → **Q0 done** |
| 2026-07-19 | **Q1-a** legacy 消费者扫描入仓（§5）；不删 API；迁移按热点分批 |
| 2026-07-19 | **parity-go-rust.md** 入仓；`lockfree.wait` 迁 `atomic_*`+`mo_*` 示范 |
| 2026-07-19 | **Q2-a**：`lockfree.ebr` 全量迁 preferred path（Boolean CAS + mo_*）；test_lockfree 178 绿 |
| 2026-07-19 | **Q2-a**：`lockfree.stack` 迁 preferred path；source-contract 同步 |
| 2026-07-19 | **Q2-a**：`lockfree.deque` 迁 preferred path（seq_cst 仲裁保留）；source-contract 同步 |
| 2026-07-19 | **Q2-a**：`lockfree.spsc` 迁 preferred path（load/store） |
| 2026-07-19 | **Q2-a**：`lockfree.mpmc` 迁 preferred path（active enqueue + pos CAS） |
| 2026-07-19 | **Q2-a**：`lockfree.spmc` 迁 preferred path（单产 + 多消 CAS） |
| 2026-07-19 | **Q2-a**：`lockfree.mpsc` 迁 preferred path（节点指针 helpers 保留，标量用 atomic_*） |
| 2026-07-19 | **Q2-a**：`lockfree.channel` + `channel.spsc` 迁 preferred path（notifier 锁 + sequence CAS） |
| 2026-07-19 | **Q2-a**：`lockfree.hazard` + `segqueue` 迁 preferred path（回收域 / 无界 segment） |
| 2026-07-20 | **Q2-a**：`lockfree.msqueue` + `hashmap` 迁 preferred path（MS 无界队列 / 分片锁 map） |
| 2026-07-20 | **Q2-b**：`verify-t1` 全门绿（atomic + main + stress 17） |
| 2026-07-20 | **Land** H3-4/H3-5 + Q0–Q2 → main `1e535bfb4`；archive tag |
| 2026-07-20 | **Q3-a**：Selector preferred atomics；TrySelect≡default；Add 序；wait 文档修正；钉测试 |
| 2026-07-20 | **Q3-b/c**：Channel 对标表 + Close 幂等测；HashMap api-ref 诚实 progress / 去假对比 |
| 2026-07-20 | **Q4**：[`t2-inventory.md`](t2-inventory.md)；**否决**本波扩 H3-2；CONTRACT/selection-guide 指针 |
| 2026-07-20 | **Q5**：matched C1/C2 multi-thread channel；`compare-matched`；envelope 脚本增强 |
| 2026-07-20 | **Land Q3–Q5** → main `4447ae001`；tag `archive/atomic-lockfree-q3q5-landed-20260720` |
| 2026-07-20 | **Q1-b/c**：审计关闭（alignment/GetMut/wait 已覆盖；交叉链接） |

### Q4 checklist

- [x] T2 inventory（档位 + progress + tests）
- [x] 书面否决 H3-2 扩子集
- [x] CONTRACT §0.2 / selection-guide 指向 inventory
- [x] 无 T2 进门面、无算法大改

### Q5 checklist

- [x] matched C1/C2 多线程 Pascal + Go + Rust
- [x] envelope 可填 command/measured/stats；`compare-matched` 入口
- [x] bench-envelope.md Q5 节 + 非公平声明
- [x] formal samples≥3：`compare-matched-formal` / `run-q5-matched-formal.sh`

### Maintenance preferred-path 进度

- **done**：`async.cancellation`、`sync.once`、`sync.barrier`、`thread.future`、`id.xid`、`async.combinators`、`bench.run`
- **done**：`sync.event` / `semaphore` / `spinlock`、`stopwatch.tick.*`、`io.reactor`+`epoll`+`kqueue`
- **H4-1 done**：`thread.pool` → SegQueue
- **done**：`net.async.resolve/dial`、`net.server.threaded`、`io.reactor.iocp`、`async.loop`、`mem.debug_wrap`/`central`/`allocator.growing`/`cache.thread`
- **done**：id.rng/v7.monotonic、worksteal owner-lock、taskgroup；**H3-2** bag/multimap；**T2 sync** mutex/rwlock/semaphore/countdown
- **done**：T2 大户 preferred — elimination_stack、stampedlock、hashtable、phaser、exchanger、flatcombining、lfu、leftright、dag、graph
- **done**：T2 簇 D–G preferred — 树族（trie/treap/skiplist/radix/scapegoat/rbtree/bplus/btree/trie_map/skiplist_map）、cowarray/rcu/snapshot/lru、crdt/ringbuffer/timeoutqueue/bitset/forkjoin、bloom/counting_bloom/scalable_bloom + hyperloglog/tdigest/spacesaving/countminsketch
- **done**：T2 长尾收口 — 全部 `lockfree*.pas` 热路径 preferred；`mpsc` 私有 `LoadNode/StoreNode/ExchangeNode`（去 Atomic 前缀）；residual **0**
- **M6 done**：生产 residual 回归钉 `test_lockfree_preferred_path`；§5 Q1-a 扫描刷新；Q3-b Close 幂等正文对齐
- **M7 done**：lockfree 测试/bench harness preferred `atomic_*`（`test_lockfree` / stress / 各 T2 gate 协调标志）；source-contract 对齐 Q5 Go/Rust 对照源
- **V1 done**：`verify-t1` + `verify-h3-consumers` 绿；`test_atomic` source-contract 对齐 bench platform 字段（`OSName/CPUName`）
- **I1 done**：`t2-inventory` progress 诚实抽检 + 关键误标修正（elim stack / cow / rcu / hashtable…）
- **C1 done**：core 生产 `Atomic*(`（排除 `atomic*` 自身）再扫 **0**；`test_lockfree_preferred_path` 绿
- **Ready 收口 done**：`READY.md` 三句话交付 + selection-guide「任务投递四选一」
- **Polish P1 done**：inventory 全表 progress 诚实；EN selection-guide；`t1_segqueue_workers` + verify-h3
- **Polish P2–P5 done**：api-ref/README.en 同步 preferred+示例；`t2_bag_close_join_free`；CONTRACT/README 假 LF 再扫；formal 能/不能声称；verify-h3 绿证
- **Polish P2b done**：api-reference.en 展开 Stack/Deque/Bag/MultiMap/SegQueue；bag 示例挂入 `verify-h3-consumers`
- **Polish P2c done**：EN README 命名诚实；api-ref.en T2 索引表；`t2_multimap_close_join_free` + verify-h3
- **Polish P2d done**：api-ref.en T2 短 prose 与中文对齐；`t1_msqueue_close_join_free`；`t2_hashmap_join_free`（无 Close 诚实）；Skiplist 不 invent Close
- **剩余（本模块内）**：可选更多 T2 教学示例；legacy public API 仍可在 `atomic.compat` 保留

### Q3-a checklist

- [x] `selector.impl` → `atomic_*`+`mo_*`
- [x] 头注释 / CONTRACT §1.2a / api-ref / README / selection-guide 语义一致
- [x] 测试：case 序、TrySelect-as-default、closed-empty recv
- [x] source-contract：preferred atomics + LockFreeWaitData；禁 legacy AtomicLoad32/FetchAdd32

### Q3-b — Channel 体验对标

| Go / Rust 精神 | nextpas | 备注 |
|----------------|---------|------|
| buffered `chan` | `TLockFreeChannel<T>(capacity)` | capacity 上取整 2^n |
| unbuffered 精神 | capacity=1（R5） | 非运行时 rendezvous 全语义 |
| close + drain | `Close`；已入队仍可 `TryReceive` | CONTRACT §1.3 |
| send on closed | `Send` 抛错；`TrySend`=False | 与 Go panic / ok 差不同 |
| select default | `TLockFreeSelector.TrySelect` | Q3-a |
| 1P1C 快路径 | `TLockFreeChannelSpsc` | 无 MPMC 竞争 |
| 诊断 full/empty/closed | `TrySendEx` / `TryReceiveEx` | Boolean 热路径不变 |
| 动态容量 | `TryResize` | 有测；closed 拒绝 |

**测试面**（已有）：basic/close/timeout/stress/cap=1/resize 系列/`Try*Ex`/SPSC 变体；**Close 幂等** — `TestChannelCloseIdempotent`（done）。

### Q3-c — HashMap 导航 + progress 诚实

| 项 | 状态 |
|----|------|
| Progress：分片锁非 LF | README / selection-guide **已有**；api-ref 去掉误导「vs ConcurrentHashMap 性能」假对比 |
| 别名诚实 | `TConcurrentHashMap` ≡ `TShardedHashMap` |
| 对标表 | api-ref 增 sync.Map / dashmap 精神表 |
| 不扩算法 | 本切片无 HashMap 实现改动 |

---

## 5. Q1-a — Legacy atomic 消费者扫描

### 方法

`rg` 扫描生产 `.pas` 中 **调用形** `Atomic*(`（名 + 可选 32/64/Ptr + `(`），排除 `nextpas.core.atomic*` 自身实现。

### 结果摘要（2026-07-20 刷新，T2 长尾收口后）

| 模式 | 约略规模 | 含义 |
|------|----------|------|
| lockfree 生产 `Atomic*(` | **0** | T1 + T2 热路径已 preferred（Boolean CAS + `mo_*`） |
| core 其它生产（排除 atomic/lockfree） | **0 调用**（注释假阳性另计） | 跨模块 consumers 已迁 preferred |
| `atomic.compat` / legacy API | **保留** | H2-3：不删；新代码勿扩散 |
| 测试/fixture PascalCase | 仍常见（协调标志等） | **可选**另波；非生产 residual |

### 回归钉（M6）

```bash
make focused FOCUS=core/tests/nextpas.core.lockfree/test_lockfree_preferred_path
# 或：
# rg -n '\bAtomic(Load|Store|Exchange|CompareExchange|FetchAdd|FetchSub)\w*\s*\(' \
#   core/src/nextpas.core.lockfree*.pas
# 期望：无匹配
```

### T1 / T2 热路径观察（现状）

| 单元 | 倾向 |
|------|------|
| T1 queues / stack / deque / ebr / channel / hazard / msqueue / segqueue | **preferred** `atomic_*` |
| T2 全量生产单元 | **preferred**（长尾收口后 residual 0） |
| 测试 harness | 仍可用 legacy 协调标志 |

**对标 Go/Rust**：生产 API 一致性已收口；剩余差距在测试示范与文档导航，不是缺 CAS。

### 策略（Maintenance）

1. **不删** legacy / PascalCase API（H2-3 锁定）。
2. **新代码** 只写 `atomic_*` + `mo_*` 或 `TAtomic*`。
3. **生产 lockfree** 由 `test_lockfree_preferred_path` 钉死 residual=0。
4. **CAS 迁移注意**（若再触碰测试）：`AtomicCompareExchange*` 返回 **old**；`atomic_compare_exchange_strong` 返回 **Boolean** 且写回 `var Expected`。

### Q1-b/c — **done**（2026-07-20 审计）

**Q1-b**（抽检，不硬造用例）：

| 主题 | 证据 |
|------|------|
| natural alignment | `TestAtomicTypedNaturalAlignmentContract` + direct_types_ptr 运行时钉 |
| GetMut / IntoInner | runtime + source-contract + forced-compile fixture |
| wait/notify | atomic README + source-contract 钉 `atomic_wait` / platform wait seams；fallback 谓词循环文档化 |

结论：边界面 **已具备**；本波不追加重复测试。

**Q1-c**：`core/docs/atomic/README.md` 已链 `consumer-audit` + CONTRACT §1.4；本文件 §5 为 legacy 扫描表；README 补链本 Q 线入口（见同 commit）。
