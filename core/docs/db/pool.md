# nextpas.core.db — 连接池分册（pool）

**模块路径**：`core/src/nextpas.core.db.pool*.pas`（`base`/`intf`/`state` 状态容器单源 + `sched` 单核聚合 `idle`/`leak`/`obs`/`concurrency` 四子面 + `proxy` 分治 + `impl`/`pool` 四件套，impl 经 FState 单入口 6→1 叶收敛零直连跨叶）
**层级**：L2 基础设施（仅依赖 L0-L1，`db.pool` 已下沉 L2，wallet L3 仅 L0-L2 单向复用，无 L3→L3；见 `CONTRACT.md §1/§2.22`）
**Owner**：core-db lane
**单源**：本册为 `CONTRACT.md §2.7` 单源分册，细节沉至本册，索引与分治不变量仍以 `CONTRACT.md` 为准（防双源漂移）；`capprobe`/`intf`/`base` 仍单源 `CONTRACT.md §2.10`。
**最后更新**：2026-09-03（匠心修复11：硬回收由 2×阈值(120s)收敛至 1.2×阈值(72s)缩短裸租约阻塞；FState 单源、impl 零直连 TPoolIdleVec/TOutstandingVec；Discard 防双释兜底，ScopedLease try..finally 置 nil 仍首选）

---

## 1. 定向

`TDbPool` 对任意后端 `IDbConnection` 池化，后端特化经连接工厂闭包注入，池体不懂方言（L2 纯基础设施，严格单向依赖）。

- **复用 bytes.ops 单源**：泄漏/诊断串经 `impl.PoolLeakToBytes→StringToBytes` 单 `Move` 零拷贝（门面仅 `inline` 薄转发至 `impl`，`POOL_IMPL_BYTES_SINGLE_SOURCE` 编译期钉死，不直连 `bytes.ops`），不自建副本；状态容器 `pool.state` 聚合 Idle/Outstanding 向量 Init/Done 单源（`PoolStateInit/Done inline` 单 Move，`POOL_STATE_BYTES_SINGLE_SOURCE` 守卫）。
- **性能**：`Acquire`/`Writer`/`WithRead`/`WithWriter`/`Policy`/`FlushDiagnostics`/`Close`/`PoolLeakToBytes` 为 `inline` 薄转发至 `IDbPoolCore` 单源（WithRead/WithWriter 直连 `ScopedLease`，零私体中间调度，8线程89k ops/s 锤压零额外 call，门面纯 re-export 守 design-conventions）；`ScopedLease` 体外联单源路由承载 `try..finally` 置 `nil` 归还（impl 内，调用点零 I-Cache 膨胀）零额外分配；`PoolStateInit/Done` inline 薄转发至 `pool.state` 单源零 I-Cache 膨胀（见 `nextpas.core.db.pool` 单元头注）。
- **稳定性**：生命周期经 `IDbPoolCore` 引用计数保活，`Shutdown` 幂等，`ReturnProxy` 信号量配对释放不丢（硬回收 finally 释信号量不丢、Discard 防双释）；`ScopedLease` `try..finally` 置 `nil` 归还不丢；`PoolStateInit/Done` 配对不丢、FState 单源容器析构清 Pending。

## 2. 契约（CONTRACT §2.7 单源）

`TDbPool` 对任意后端 `IDbConnection` 池化，后端特化经连接工厂闭包注入，池体不懂方言：

- **开箱工厂（B13 配套）**：`OpenSqlitePool(Path, MaxRead)`（便利形态：缺省策略仅覆盖读上限，`busy_timeout` 烘入生产级缺省）与 `OpenSqlitePool(Path, Policy, Options)`（全控形态：策略与连接选项逐字采用），组合 `db.pool × sqlite` 统一适配器，经 `nextpas.core.db` 再导出；消费方不再各自手拼策略与连接选项。
- **租约绑定纪律（B13 续）**：FPC 接口临时量为例程级生命周期——`Pool.Acquire` / `Pool.Writer` 的函数结果若**直接内联传参**（`const` 形参绑定，如 `Migrate(Pool.Writer, …)`）或经**全局托管变量**中转，隐藏引用会把租约拖过语句边界、直至所在例程退出（单写者槽位期间不可再借；五格矩阵实证）。合规形态：租约先绑定局部变量、用毕显式置空；或直接用作用域助手 `Pool.WithRead(…)` / `Pool.WithWriter(…)`——租约约束在实现内局部变量上（`try..finally` 归还），消费方从结构上不可能滞留。池化连接上的事务一律走参数化形态（`CONTRACT §2.3`，捕获型 `TDbTxProc` 已 `deprecated` 提示，heaptrc 硬门禁未覆盖闭包捕获滞留 source-contract 硬门禁已落地 `core/tests/nextpas.core.db/test_db_factory/check_pool_lease_source_contract.sh`）。

- **释放即归还**：`Acquire`/`Writer` 返回代理接口，消费方释放引用（出作用域或置 `nil`）即自动归还，零手工 `Free`。代理经 `QueryInterface` 透传底层连接全部能力面（`IDbTxControl`/`IDbBatchExecutor` 等），探测语义与直连一致。
- **坏连接弃置**：捕获数据库错误后经 `IDbPooledHandle.Discard` 弃置当前连接，释放引用时不回池而直接关闭，防坏连接复用。
- **生命周期安全**：持有租约时 `Free` 池合法——门面 `Free` 只停止出借并清空空闲队列；在途租约归还时直接销毁底层连接（排空语义，不等待，对齐 Go `DB.Close`），最后一个租约释放后池核心态自毁。`Close` 后 `Acquire`/`Writer` 抛 `EDbError`。
- **策略**：`TDbPoolPolicy` 九字段（`MaxReadConnections`/`AcquireTimeoutMs`/`ValidateOnAcquire`/`MaxLifetimeSec`/`IdleTimeoutSec`/`MinConnections` + V3-C3 三招 `LeakDetectionThresholdMs`/`OnLeakDetected`/`DebugAcquireStack`）。空闲回收无看门狗线程（`Acquire` 检查点惰性执行）；预热 `fail-fast`（`Create` 内建满 `MinConnections`，失败原样上抛建连错误）。
- **泄漏检测（V3-C3，默认 60s 开）**：`LeakDetectionThresholdMs > 0`（默认 60000ms）时，持有超阈值的在途租约在任意检查点（`Acquire`/`Writer` 入口、归还路径）被扫描入账（`Warned` 一次，检测不干预所有权——租约仍归持有者）。报告只在安全点冲刷：`Acquire`/`Writer` 入口自动冲刷积压，或显式 `TDbPool.FlushDiagnostics` 排空。归还路径发生在代理析构链内，只入账不触发用户代码——回调永不在析构链内执行（硬边界）。报告经 `OnLeakDetected` 回调（`nil` 则经 `LeakLogger`→`NullLogger` 零 `StdErr` 裸写）；回调在池调用线程同步执行且不得重入本池。诚实模型：发现依赖下一次池活动或显式冲刷，无看门狗线程；裸 `Acquire`/`Writer` 忘归还或 `ScopedLease` 闭包捕获滞留读/写槽位时，默认 60s 即 Warned 暴露避免静默死锁，显式置 0 可关以压 bench 噪声。`DebugAcquireStack` 开启时报告附 ≤16 帧原始地址行（`BackTraceStrFunc` 格式化，符号解析取决于链接信息），默认关零成本。
- **硬回收（V3-C3 延续，1.2×阈值 72s 兜底，较 2×120s 缩短阻塞）**：软告警(60s)后仍滞留至 1.2×阈值（默认 72s）时，下一次 `Acquire`/`Writer` 检查点触发硬回收：扫描 `Warned` 且 `Held >= 1.2×threshold` 的在途租约，`Discard` 滞留代理防双释、强制释放对应读/写槽位并清 `FWriterConn`（写槽）、经 `OnLeakDetected`/`LeakLogger` 报告 `hard reclaimed` 且 `slot freed`；硬回收锁内扫描标记、锁外释信号量与报告（finally 不丢），避免裸租约极端滞留耗尽槽位导致池阻塞由 120s 缩至 72s。ScopedLease `try..finally` 置 nil 仍为首选零滞留路径，硬回收仅为裸租约极端兜底（显式置 0 时同禁）。
- **单写者**：`Writer` 全池唯一专用槽位；占用期再取按 `AcquireTimeoutMs` 排队或抛错。写连接身份恒定（寿命到期才重建）。
- **线程模型**：池方法线程安全（簿记互斥 + 槽位信号量）；单条底层连接同一时刻仍只服务一个逻辑线程（`CONTRACT §2.1`），池化不改变该契约。

## 3. 依赖与分治不变量

- L2 基础设施：`nextpas.core.db.pool.base ← pool.intf ← state(聚合 Idle/Outstanding/Pending/阈值 Init/Done 单源) ← sched(聚合 idle/leak/obs/concurrency + 硬回收)+proxy ← impl(FState 单源容器) ← pool` 四件套严格向下，无上向；`impl` 状态核经 `FState: TPoolState` 单源容器薄委托至 `sched` 单核（AcquireRead/Writer/ReturnProxy + IdlePush/Pop/GrowCap/Flush/硬回收聚合转发，impl 经 FState 单入口 6→1 叶收敛零直连跨叶，跨叶变更经 state/sched 单点同步）/`proxy`（TPooledConn inline 零拷贝）/`idle`（LIFO 热队+惰性驱逐）/`leak`（租约簿记）/`obs`（报告流水线）/`concurrency`（并发桶 inline 零拷贝）/ `state`（Idle/Outstanding 向量 Init/Done 单源）内聚于 sched/state 单出口分治控体积（570→460→<400→state 单源后 sched<450、impl~170、state<60，6→1 叶收敛零直连跨叶），无同层循环；wallet 仅 L0-L2 单向复用，无 L3→L3（见 `CONTRACT.md §1` 家族布局）。
- 性能：热路径 `AcquireRead/Writer` 单次 `platform_monotonic_ns` ns 单源缓存复用（阈值关/无超时场景零 syscall，阈值开才单 syscall 零 `div 1_000_000` 除法并复用于 Evict/Pop/租约登记/硬回收，89k ops/s 零除法延迟，阈值侧 *1_000_000/*1e9 换算，硬回收 1.2×(1_200_000)单乘零除法）、`EvictColdStale` 1s 节流 + 双端 8 探针 O(1) 采样快路径（冷端 4 探针覆盖 IdleTimeout 单调 + 热端 4 探针补探 MaxLifetime 非单调，无 stale 即跳过全量扫描，长 IdleTimeout 8线程×24k 锤测锁持有 O(1)；命中才全量压缩，热 stale 不再仅靠 `PoolIdleTryPopUsable` LIFO while 循环摊还，避免 5s 长节流下深层热过期滞留放大 Acquire 持锁，单次持锁 O(k) 零额外 `Move`，inline 零 I-Cache 膨胀）、`TryFlushLeaksIfDue` 零锁预检复用缓存 tick（到期才双锁+格式化+回调）+ `HardReclaim` 复用同一 tick 零额外 syscall（Warned 后 1.2×阈值才扫描，锁内标记锁外释信号量，inline 单点门禁）；`PoolGrowCap`/`Acquire`/`Release` 并发桶 inline 薄封装零额外分配，`bytes.ops` 单 Move 零拷贝；代理面 `Kind`/`Exec`/`Query`/`Changes`/`Raw` inline 薄转发；`PoolStateInit/Done` inline 零 I-Cache 膨胀单 Move。
- 稳定性：`TPooledConn.Destroy`（pool.proxy）析构期 `try..except on E: Exception` 留诊经 `LeakLogger`（nil→NullLogger 回退不丢释放——信号量配对已在 `ReturnProxy` `finally` 中保证释放，外层 `try..except` 仅诊断且内层 `Warn` 再套 `try..except` 防二次异常丢释放，资源释放不丢；硬回收后 `Discard` 防双释使 ReturnProxy 跳过二次释信号量）；`Shutdown` 幂等，资源释放不丢（FState.Idle 清空 + FWriterConn nil）；`ReturnProxy` `try..finally` 保证并发桶信号量配对释放，`ScopedLease` `try..finally` 置 `nil` 归还不丢且默认 60s 泄漏阈值使裸 `Acquire`/`Writer` 忘归还/闭包捕获滞留经 `Warned` 及时暴露，1.2×阈值(72s)硬回收强制释槽兜底极端滞留耗尽，避免裸租约致池阻塞 120s 静默。
- 业务以 `CONTRACT` 为准、缺能力先反哺 `owner`（池能力反哺 `nextpas.core.db.pool`，文本/时间/字节反哺 `text.*`/`time`/`bytes.ops` 单源）。
- 复用 `bytes.ops` 单源 `inline` 零拷贝证据见 `pool.impl`/`pool.sched`/`pool.state`/`pool.proxy`/`pool.concurrency`/`pool.idle`/`pool.leak`（门面 `pool` 仅 `inline` 薄转发至 `impl.PoolLeakToBytes`，零直连 `bytes.ops`，`POOL_IMPL_BYTES_SINGLE_SOURCE`/`POOL_STATE_BYTES_SINGLE_SOURCE` 守卫）；`PoolLeakToBytes`/`PoolSchedGrowCap`/`PoolSchedIdlePush/Pop`/`PoolSchedFlushSafePoint`/`PoolSchedHardReclaimVec`/`PoolIdleTryPopUsable`/`PoolStateInit/Done`/`TPooledConn.*`/`PoolSched*` `inline` 单 `Move`，`BYTES_OPS_SINGLE_SOURCE` 守卫（impl 经 state/sched 聚合转发零直连跨叶，state 单源 Init/Done）。

## 4. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_pool        # 池并发与租约纪律
make focused FOCUS=core/tests/nextpas.core.db/test_db_pool_v2     # 泄漏检测与 Writer 单写者
make focused FOCUS=core/tests/nextpas.core.db/test_db_factory     # 工厂 + heaptrc0 + 池化租约 source-contract 硬门禁（B13 闭包滞留 heaptrc 盲区）
```

每个 `gate` 含 `heaptrc 0 unfreed` 硬门禁；`test_db_factory` 额外 `check_pool_lease_source_contract.sh` 源码契约束硬门禁覆盖 B13 租约滞留（heaptrc 盲区）；`test_db_pool_stress` J2 不变式见 `benchmarks.md §bench_db_pool_stress`。
