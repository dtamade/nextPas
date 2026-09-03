# nextpas.core.db — Redis 分册（redis）

**模块路径**：`core/src/nextpas.core.db.redis.*`（`base`/`resp`/`transport`/`pipeline`/`recv`/`adapter`/`subscribe` + 门面 `nextpas.core.db.redis`）
**层级**：L2 后端（`base`/`resp`/`transport`/`pipeline`/`recv`/`adapter`/`subscribe` 皆 L2，同层单向，无上向；`adapter` 严格下向 L2 后端）
**Owner**：core-db lane
**单源**：本册为 `CONTRACT.md §2.13` + `§2.19` 单源分册（`redis` 原生 + `SUBSCRIBE` 推送会话），细节沉至本册，索引与分治不变量仍以 `CONTRACT.md` 为准；分治不变量见 `CONTRACT.md §1/§2.10`。
**最后更新**：2026-09-03（匠心修复：`recv` 碎片化小帧守稳 4K + 满利用率按需倍增至 64K + 压实 LEff 16K 限幅，`bytes.ops` 单源零拷贝 `inline` 守层）

---

## 1. 家族与体积分治

| 单元 | 职责 |
|------|------|
| `nextpas.core.db.redis.base` | 常量/类型（`TDbRedisConnectOptions`、`DB_REDIS_READ_*` 单源上界） |
| `nextpas.core.db.redis.resp` | RESP2 帧解析/编码（`RespTryParse`/`RespEncodeCommand`，零平行解析器） |
| `nextpas.core.db.redis.transport` | 传输抽象 `IRedisTransport`（`NewNetRedisTransport` 经 `nextpas.core.net` + `nextpas.core.tls.TLSDial`） |
| `nextpas.core.db.redis.pipeline` | 批执行流水线分块（`RedisExecuteBatch`，`bytes.ops` 单源零拷贝，64K 分块有界峰值） |
| `nextpas.core.db.redis.recv` | 接收环形缓冲（`TRedisRecvBuffer.ReadReply`，`bytes.ops` 单源零拷贝，环形偏移视图） |
| `nextpas.core.db.redis.adapter` | `IDbConnection` 适配（<800 行，环形缓冲/流水线已抽 `recv`/`pipeline` 单源 `bytes.ops` 零拷贝，见 §2） |
| `nextpas.core.db.redis.subscribe` | `SUBSCRIBE`/`PSUBSCRIBE` 推送会话（专用连接+泵线程+有界记录队列，`§3`） |
| `nextpas.core.db.redis.addr` | 地址解析单源 `ParseRedisAddr`（`text.kv` 单源 `O(n)` 零分配，`bytes.ops` 单源） |

分层 L2→L2 同层单向依赖（`design-conventions` 允许）；`adapter`/`subscribe` 仅依赖 L2 契约与 `base`/`resp`/`transport`，严格下向。

- **复用 bytes.ops 单源**：环形缓冲零拷贝视图（`TByteSpan`）、`BytesEnsureCapacity`/`BytesAppend` 单 `Move` 零拷贝（`BYTES_OPS_SINGLE_SOURCE` 守卫）、`StringToBytes` 常量缓存 `CoW` 共享；`redis.addr`/`pipeline`/`recv` 均 `inline` 零拷贝。
- **性能**：`recv` 环形零拷贝偏移视图（`FOff` 滑动窗口，`amortized` 单次 `Move` 压实）、4K 守稳 + 满利用率才指数倍增至 64K（碎片化小帧禁盲目 `shl 1`，压实阈值用 LEff 16K 限幅防 64K 误触发 Move）、`RespPeekFrameLength` 预分配单次 `Recv` 收敛；`subscribe` 滑动窗口 `amortized` 搬移阈值 `2*MIN/半容`；`adapter` 委托 `recv` 薄转发 `inline` 零拷贝。
- **稳定性**：`FTransport.Close` + `FRing.Free` + `TDbTraceHub.NotifyRelease` 析构链不丢；`subscribe` 泵线程 `WaitAll` + `Shutdown` 不留后台线程；半帧残料断线丢弃、已完整帧尾窗口投递不丢。

## 2. Redis 原生后端（CONTRACT §2.13 单源）

`nextpas.core.db.redis` 家族：RESP2 协议原生客户端（无 C 库依赖，传输经 `nextpas.core.net` 阻塞 TCP，接口化可注入）。分层 L2→L2 同层单向依赖（`design-conventions` 允许）。

- **命令面**：命令文本 = 空白分词命令行；`?` 顺序槽 / `?N` 显式槽替换为独立 `bulk` 参数——RESP 长度前缀二进制安全，注入安全由协议构造保证。`'...'` 引号包裹剥壳取内容；`'?x'` 非占位符语法按字面键保留。
- **回复 → 行映射**：`array` 每元素一行；`simple`/`bulk`/`integer` 一行；`null`（`$-1` / `*-1` / RESP3 `_`）零行；`error` 回复在执行点抛。单列，列名 `'reply'`，`integer` 回复列型 `dbcInteger` 其余文本。
- **执行模型**：`IDbQuery` 惰性执行（首个 `Step` 发命令）；`Reset` 重臂重发（对齐 `odbc` `Reset` 语义）；错误类目经 `db.err` `ClassifyRedis`（`ERR→syntax`、`WRONGPASS/NOAUTH→auth`、`MOVED/ASK/CLUSTERDOWN/READONLY→connection`、`LOADING/BUSY/MASTERDOWN→capacity`、`EXECABORT→transaction`、`NOSCRIPT→not-supported`、未识别欠归一）；错误首词存 `SqlState` 槽，RESP 无数字码位 `BackendCode` 恒 `0`。
- **事务控制面**：`MULTI`/`EXEC`/`DISCARD` 直映；`MULTI` 期间消费方收到 `+QUEUED` 标记（Redis 固有语义）；`CommitTxn` 校验 `EXEC` 数组内错误元素后丢弃载荷；`EXECABORT → decTransaction`；`AImmediate` `no-op`。
- **能力矩阵单源**：本后端能力以 `CONTRACT §2.10` + `capprobe`/`intf` 为单源（`Supports*` 互证），本文不另制矩阵；`Savepoints/StmtCache/LargeObjects/NativeBool/MultiStatement/StatementTimeout=False`，`BatchExecutor=True`（流水线 `burst+N` 读），`CaseSensitive=True`，`MaxPlaceholders=999`。
- **观测钩子**：`trace.md` 同构接线（`attach-catch-up`、首执行窗口、错误类目透传）。
- **连接选项重载（A5.1b）**：`ConnectRedis(AAddr, TDbRedisConnectOptions)`——`Host`/`Port`/`Password`/`DbIndex`/`ConnectTimeoutMs`/`IoTimeoutMs` 之外新增 `UseTls` 与 `TlsServerName`；地址串解析结果与选项字段合并时选项侧非默认值优先。
- **TLS 变体**：`UseTls=True` 走 `nextpas.core.tls.TLSDial`（`DNS+TCP+TLS` 一体阻塞），`SNI` 取 `TlsServerName` 否则 `Host`；传输拨号失败（`TCP`/`TLS`，含证书类）统一桥接为 `EDbError(dbkRedis)` `decConnection`，`ErrType` 槽放 `'NET'` 标记非服务端回复。
- **INFO 版本探测（A5.1）**：真实建连默认发 `INFO server` 尽力取 `redis_version`（`valkey` 回退 `valkey_version`），经 `IDbCapabilities.ProductVersion` 暴露；探测失败保守降级为空版本、连接不受影响。离线门控 `live env`：`NEXTPAS_REDIS_TEST_TLS_CONN` / `NEXTPAS_REDIS_TEST_TLS_PASSWORD`。

## 3. SUBSCRIBE 订阅会话（CONTRACT §2.19 单源，V3-B8）

`redis` 原生 `pub/sub` 一等公民化（B8），骨架自 `pg.listen`（`CONTRACT §2.18`）直接泛化：专用连接独占的订阅会话 + 单工泵线程 + 有界记录队列。RESP2 订阅态独占约束（进入订阅态后仅 `SUBSCRIBE`/`UNSUBSCRIBE`/`PSUBSCRIBE`/`PUNSUBSCRIBE`/`RESET`/`QUIT` 合法）由结构保证——本类不暴露任何普通命令面，`PUBLISH` 由消费方经 `db.redis` 适配器另路发送。

```pascal
S := RedisOpenSubscriber(Opts);
S.Subscribe('events'); S.PSubscribe('news.*');  // 客户端校验先行，异步应用
M := S.Receive(2000);                           // 阻塞至 ≥1 条；一次带回全部积压（FIFO）
{ TDbRedisMessage: Channel / Payload / Pattern——message 帧 Pattern 为空串，
  pmessage 帧携带命中 pattern }
S.Token.Cancel;                                 // 协同停泵；Destroy 同步收尾不留后台线程
```

- **与 `pg.listen` 的词汇差异（有意为之）**：方法名用协议本词 `Subscribe`/`PSubscribe`/`UnsubscribeAll` 而非 `Listen`/`Unlisten` 别名——提案原案 `Listen` 同形在实现期改为 `redis` 本词，降低跨协议误读；属性面同形（`Token`/`Connected`/`GapCount`/`DroppedCount`/`LastError`/`SubscribedChannels`/`SubscribedPatterns`）。不进统一接口（`CONTRACT §2.18` 同决策）：频道确认帧/`pattern`/独占强度语义差异大，等第二实证再议抽象。
- **确认帧簿记回执**：`subscribe`/`psubscribe` 确认帧吸收为簿记回执不投递；`SubscribedChannels`/`Patterns` 快照记已发出命令的条目；重复 `Subscribe` 同频道幂等去重不重发命令。
- **不经 `db` 门面**（`CONTRACT §2.17/§2.18` 同纪律）：独立单元显式 `uses`，`thread.init` 放 `uses` 首位。
- **底座零平行宇宙**：`thread.pool` 单工池 + `core.sync` 互斥/事件 + `async.cancellation` 取消桥（析构首步 `RemoveOnCancel` 摘链，消费方可安全持 `Token` 越过订阅器生命周期）；RESP 解析复用 `db.redis.resp` 的 `RespTryParse`/`TRespValue`，零平行解析器。
- **传输工厂 DI 缝**：`TRedisTransportFactory = reference to function: IRedisTransport`；`live` 构造内部工厂 = `NewNetRedisTransport` + `AUTH`/`SELECT` 握手（坏地址/口令消费方线程 `fail-fast`）；注入构造（门禁离线回放、自定义 `TLS dial`）握手责任随注入方。
- **诚实语义（`at-most-once`，与 `CONTRACT §2.18` 同口径）**：
  - 断线窗口推送丢失不补发，`GapCount` 如实记断线次数；自动重连间隔 = `4×`节拍，成功后按订阅快照逐条重放；重放中途失败则新连接不接管（`FConn` 保持 `nil` 由恢复机器统一重试），杜绝半配置连接常驻与 `Connected` 读数失真；`LastError` 在恢复成功时清空（成功即无错的设计语义，消费方勿假设其跨恢复存活）。
  - 投递队列满保旧弃新计 `DroppedCount`（`FIFO` 不打断）；默认容量 1024。
  - 服务端错误帧记 `LastError` 诊断但不断线（订阅态内错误非连接致命）。
- **停泵时延上界 = `IO deadline` 而非节拍**（与 `CONTRACT §2.18` 差异，如实登记）：连接在途时泵阻塞于带 `deadline` 的 `Recv`（`IRedisTransport` 无中断面），取消最迟一个 `EffectiveIoTimeoutMs = max(2×节拍, 1000)ms`（钳 `3600000`）内生效；空闲/退避期等事件即时惊动。`PING` 保活默认关（`AKeepAliveMs=0`），开启按周期发 `PING` 维持中间件活性。
- **协议护栏**：单帧上限 `MAX_FRAME_BYTES=16MB`，超限判协议错走断线重连；解析以精确有效长度视图喂 `RespTryParse`（防陈旧字节误扫成幽灵帧）。
- 门禁：`test_db_redis_subscribe` 十组全绿 `heaptrc 0`（确认簿记+幂等/`pmessage` 分派/静默超时/校验 `fail-fast` 不触网/溢出保旧弃新/令牌取消/错误帧可见不断线/断线自动重连重放再达/重放失败不接管/`live` 自发自收 `NEXTPAS_REDIS_TEST_CONN` 门控）。吞吐基准段待 `live redis` 环境可用后补采入册（诚实缺席登记）。

## 4. 依赖与分治不变量

- `L2` 后端七成员之一，`adapter` 严格下向 `L2` 后端，无上向；`recv`+`pipeline` 体积分治后 `adapter` <800 行软阈内（环形缓冲+分块流水线单源 `bytes.ops` 零拷贝，`CONTRACT.md §1` 家族布局）。
- 业务以 `CONTRACT` 为准、缺能力先反哺 `owner`（`redis` 能力反哺 `nextpas.core.db.redis.*`，`TLS` 反哺 `nextpas.core.tls`，文本反哺 `text.kv`/`text.conv` 单源）。
- 复用 `bytes.ops` 单源 `inline` 零拷贝证据见 `adapter`/`pipeline`/`recv`/`subscribe`/`addr` 单元头注与 `benchmarks.md §bench_db_redis_*`。
