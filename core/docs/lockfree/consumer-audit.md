# Atomic & Lockfree Consumer Audit (R7 + H2-6)

> **日期**: 2026-07-17
> **范围**: `core/` 内 `uses nextpas.core.lockfree*` / `uses nextpas.core.atomic*`
> **方法**: ripgrep 扫描 `core/src/**/*.pas` 的 uses 子句；抽样查看 Close/Destroy 与 legacy CAS 调用形态
> **主线**: R7 完成；H2-6 增加最小真实消费者证据
> **状态**: **R7 DONE** + **H2-6 consumer proof**

---

## 1. 结论摘要

| 面 | 结论 |
|----|------|
| **lockfree 跨模块生产消费者** | **无**。`core/src` 中除 `nextpas.core.lockfree*` 自身与注释提及外，没有其它生产单元 `uses nextpas.core.lockfree*` |
| **atomic 跨模块生产消费者** | **有**。约 20+ 个 L0–L2 单元直接依赖 `nextpas.core.atomic`（见 §3） |
| **Close → join → Free 误用** | **未发现**需一刀切修复的跨模块误用（因为没有跨模块 lockfree 容器消费者） |
| **legacy CAS** | lockfree 与部分 sync/id 热路径大量使用 `AtomicCompareExchange*`（返回观测值）；文档标记首选 `atomic_*` / `TAtomic*`，**不删 API** |
| **T2 命名诚实** | `deque_lf` 等已注明；本轮扩充命名脚注表（CONTRACT / README） |

**生命周期纪律（advisory）**：T1 有界队列/通道仍要求 `Close → join producers/waiters → Free`；`Destroy` 的 Close+drain 不能替代 join。未来若其它模块接入 T1 容器，应先读 [`CONTRACT.md`](CONTRACT.md) 与本审计。

---

## 2. lockfree 消费者

### 2.1 生产源码（`core/src`）

| 单元 | 关系 | 说明 |
|------|------|------|
| `nextpas.core.lockfree*`（门面 + T1–T3 子单元） | **owner / 自用** | 内部 uses `lockfree.base` / `wait` / `ebr` / `deque` 等 |
| `nextpas.core.bench.run.pas` | **注释 only** | `@see nextpas.core.lockfree.ebr`；无 uses |
| `nextpas.core.collections.hashmap.pas` | **注释 only** | 文档指向 `TShardedHashMap`；无 uses |
| `nextpas.core.collections.concurrent.hashmap.pas` | **同名异实现** | 自有 `TConcurrentHashMap`，**不是** lockfree 门面别名 |

**判定**：当前 core 生产树把 lockfree 当作 **可复用库 + 自测主体**，尚未被 HTTP/async/net 等上层模块直接拉入队列/通道类型。

### 2.2 测试 / 基准 / 示例

| 区域 | 角色 |
|------|------|
| `core/tests/nextpas.core.lockfree/**` | 主消费者：T1 `test_lockfree` / `test_lockfree_stress` + 大量 T2 单测 `.lpr` |
| `core/benchmarks/nextpas.core.lockfree/**` | 性能证据；须带 H2-4 信封（见 [`bench-envelope.md`](bench-envelope.md)） |
| `core/examples/lockfree_example.lpr` | 教学示例（单线程 API 面） |
| `core/examples/nextpas.core.lockfree/t1_close_join_free/` | **H2-6**：多线程 `Close → join → Free` 真实消费者证明 |
| `nextpas.core.lockfree.workstealing` | **模块内** T1 消费者：`TWorkStealingPool` 持有 `TWorkStealingDeque` |

### 2.4 H2-6 最小真实消费者

| 路径 | 证明点 |
|------|--------|
| `core/examples/nextpas.core.lockfree/t1_close_join_free/` | 1 producer + 1 consumer + `TLockFreeChannel`；`Try*Ex`；**Close → join → Free** |
| `test_lockfree_stress` `TestChannelCloseJoinFree` | 2P+2C stress 加深同一生命周期（H2-5） |
| `lockfree.workstealing` | 生产单元级消费 `TWorkStealingDeque`（仍属 lockfree 模块内） |

**跨模块**（http/async/net）仍无 lockfree 容器 uses；H2-6 **不**为证明而强行改上层模块。若未来接入，遵守 Close→join→Free。

> **R8 脚注**：R8 轴（NUMA / RTM / formal，见 [`r8-research-status.md`](r8-research-status.md)）**无**跨模块生产依赖——这是**预期**状态（Experimental / T3 direct import only），不是审计缺口。

### 2.3 Close / Destroy 纪律抽检

抽检 T1 实现单元（`spsc` / `mpmc` / `mpsc` / `spmc` / `segqueue` / `msqueue` / `stack` / `deque` / `channel*`）：均实现 `Close`；`Destroy` 路径与 R1/R2 契约（Close+drain 或 Close 唤醒）一致。

**未发现** core 生产代码在持有活跃 producer 时仅 `Free` 而不 `Close` 的模式——因为 **没有** 跨模块 lockfree 容器字段/局部变量。

**Advisory（给未来接入方）**：

1. 多线程：先 `Close`，再 join 所有 producer/waiter，再 `Free`。
2. 不要依赖 `Destroy` 作为并发停机屏障。
3. 诊断路径优先 `Try*Ex`（R3/R4），避免把 full/empty/closed 糊成单一 Boolean。

---

## 3. atomic 消费者

### 3.1 模块内

| 单元 | 角色 |
|------|------|
| `nextpas.core.atomic` / `.core` / `.types` / `.compat` | owner |
| `nextpas.core.lockfree.*` | **最大生产消费者**：队列/回收/分片锁/T2 结构热路径 |

### 3.2 跨模块生产消费者（`core/src`，非 atomic / 非 lockfree）

按领域归类（uses `nextpas.core.atomic`）：

| 领域 | 单元 | 典型用法 |
|------|------|----------|
| **sync** | `sync.spinlock`, `sync.semaphore`, `sync.once`, `sync.event`, `sync.barrier` | `AtomicCompareExchange32` / 原子计数 |
| **simd** | `simd.cpuinfo`, `simd.dispatch`, `simd.dataplane`, `simd.runtime`, `simd.pas` | `atomic_load/store` 指针发布；部分路径仍用 `Interlocked*` |
| **io** | `io.reactor`, `io.reactor.epoll`, `io.reactor.iocp`, `io.mapped.ring_buffer` | 状态机 CAS；ring sequence 用 `atomic_*_64` + `mo_*`（**首选形态**） |
| **mem** | `mem.blockpool.sharded`, `mem.allocator.growing`, `mem.cache.thread` | 计数/链表头 CAS |
| **id** | `id.xid`, `id.v7.monotonic`, `id.rng` | 初始化 once / 自旋锁式 CAS |
| **async / thread / net** | `async.loop`, `thread.future`, `net.server.threaded` | 完成态 / 并发标志 |
| **stopwatch** | `stopwatch.tick.x86_64`, `stopwatch.tick.aarch64` | 校准 once-CAS |
| **test / bench 框架** | `test.output`, `test.runner`, `bench.run` | 结果槽位/输出同步 |

### 3.3 API 形态观察（legacy vs preferred）

| 形态 | 代表 | 偏好 |
|------|------|------|
| `atomic_load` / `atomic_store` / `atomic_compare_exchange_*` + `mo_*` | `io.mapped.ring_buffer`, `simd.cpuinfo` | **首选** |
| `TAtomic*` record | 测试与新代码 | **首选**（类型边界清晰时） |
| `AtomicCompareExchange32/64/Ptr`（返回观测值） | lockfree 热路径、sync.*、id.* | **legacy 兼容**；勿在新代码扩散 |
| FPC `InterlockedCompareExchange` | `simd.dispatch` 等历史路径 | 模块外遗留；新路径应走 atomic 门面 |

**H2-3 脚注**：测试/审计中出现 legacy CAS **不等于** preferred。新代码与触达修改必须 `atomic_*` / `TAtomic*`。
详见 [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) §1.4（**不删符号**）。

---

## 4. 风险与命名（T2）

| 项 | 级别 | 说明 |
|----|------|------|
| 名称含 LockFree / lf 但实现为自旋锁 | **文档** | `deque_lf`、`hashmap`（T1 诚实别名）、radix/trees/caches 等 — 见 CONTRACT 命名例外扩充表 |
| 跨模块误用 Close/Destroy | **当前低** | 无生产跨模块容器消费者 |
| legacy CAS 返回值误读为 Boolean | **中（学习成本）** | `AtomicCompareExchange*` 返回 **旧值/观测值**，成功条件为 `= Expected`；与 `atomic_compare_exchange_strong` 的 Boolean 不同 |
| collections 与 lockfree 同名 `TConcurrentHashMap` | **中（命名碰撞）** | 不同单元、不同实现；不要混用 |

---

## 5. R7 交付勾选

- [x] core 内 lockfree / atomic uses 扫描
- [x] 本审计文档
- [x] atomic legacy CAS 偏好写入 CONTRACT（+ README 交叉引用）
- [x] T2 命名诚实脚注扩充
- [x] roadmap R7 = DONE；H2 为后续主线（见 [`roadmap-h2.md`](roadmap-h2.md)）
- [x] 无强制代码删除 / 无大 refactor
- [x] H2-6：`t1_close_join_free` 示例 + stress Close-join-Free

---

## 6. 复现扫描命令

```bash
# lockfree：非 lockfree 单元文件中的提及
rg -l 'nextpas\.core\.lockfree' core/src --glob '*.pas' | while read f; do
  case "$(basename "$f")" in nextpas.core.lockfree*) ;; *) echo "$f";; esac
done

# atomic：uses 行（示例）
rg -n 'nextpas\.core\.atomic' core/src --glob '*.pas' | head

# legacy CAS 调用点
rg -n 'AtomicCompareExchange(32|64|Ptr)' core/src --glob '*.pas'
```

证据目录（本机 scratch，不入仓）：`/tmp/grok-goal-0949884ba05c/implementer/r7-audit/`
