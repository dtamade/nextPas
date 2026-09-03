# nextpas.core.db.pool — 连接池域契约

**模块**：`nextpas.core.db.pool.{base,intf,pas}` 聚合通用池 + 单写者槽位 + 泄漏检测  
**层级**：L3 家族（后端无关，工厂闭包注入；依赖 L0–L2：`base`/`sync`/`bytes.ops`）  
**四件套**：`pool.base` ← `pool.intf` ← `pool` 门面 ← `pool` 实现（通用池核心）  
**对应主契约**：`CONTRACT.md` §1.1 连接池行 + §2.7 `TDbPool` + §2.3 租约纪律

## 职责

- 对任意后端 `IDbConnection` 池化，后端特化经 `TDbConnectFunc` 闭包注入，池体不懂方言
- 读池 `MaxReadConnections` / 单写者 `Writer` 独立槽位（信号量 1）；租约绑定纪律（参数化 `WithTransaction` 零捕获 + 作用域 `WithRead/WithWriter`）
- 策略 `TDbPoolPolicy` 九字段（`MaxRead/AcquireTimeout/ValidateOnAcquire/MaxLifetime/IdleTimeout/MinConnections` + V3-C3 `LeakDetectionThreshold/OnLeakDetected/DebugAcquireStack`）

## 性能

- 复用 `bytes.ops` 单源：DSN 键归一 `SameText`/`NormalizeLowerTrim` 零分配比较，不复制 `bytes.ops`/`text.kv`
- 热点 `inline`：`Stale/IdleStale/IdlePush/IdlePop/NowTick` 等策略判定 `inline`，无额外分配
- 零拷贝视图：租约簿记 `TOutstanding` 无托管字段裸搬移；空闲队列 `TIdleEntry` 接口托管正确搬移，不复制缓冲
- 无看门狗线程惰性回收（`EvictColdStaleLocked` 冷端清扫仅 Acquire 检查点），默认零成本（`LeakDetectionThreshold=0` 零成本关闭）

## 稳定性

- `PoolClear`/`Discard` 在 `destroy`/`Close`/`Shutdown` 全路径：空闲队列 `IdlePop` 引用清零即关闭；`FWriterConn:=nil`；在途租约归还后 `Discard` 直接销毁不再回池
- `Close` 后 `Acquire/Writer` 抛 `EDbError`，`Shutdown` 幂等；`TPooledConn.Destroy` 先 `ReturnProxy` 再 `FInner:=nil`
- `heaptrc 0 unfreed` 门禁：`test_db_pool_v2` 15 组（含五格租约滞留矩阵）；`FlushDiagnostics` 安全点冲刷，析构链内绝不触用户回调（硬边界）

## Owner 边界

- 缺能力先反哺 `bytes.ops`（DSN 归一）/`text.kv`（词法）/`sync`（mutex/semaphore）/`time`（单调时钟），不绕边界自造方言
