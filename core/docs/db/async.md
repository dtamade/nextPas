# nextpas.core.db.async — 异步/订阅域契约

**模块**：`nextpas.core.db.async.{base,intf,pas}` + `nextpas.core.db.pg.listen` + `nextpas.core.db.redis.subscribe` 各三件套（`base/intf/门面` + 单工泵线程/有界队列）  
**层级**：L3 家族（依赖 `thread.pool` + `sync` + `async.cancellation`，仅 L0–L2）  
**四件套**：`async.base` ← `async.intf` ← `async` 门面 ← `thread.pool` 单工实现；`pg.listen`/`redis.subscribe` 同型三件套  
**对应主契约**：`CONTRACT.md` §1.1 异步/订阅行 + §2.17 `TDbAsyncExecutor` + §2.18 `TPgListener` + §2.19 `RedisOpenSubscriber`

## 职责

- `TDbAsyncExecutor`：阻塞 `db` 调用投递到专用单工执行线程，返回 `IDbAsyncHandle(IsDone/IsCanceled/WaitFor/ErrorObj/Cancel)`；单飞模型（一连接一实例一同时一在途），析构 `WaitAll` 诚实等待再 `Shutdown`
- `TPgListener`：专用连接 + 泵线程（默认 50ms 节拍）+ 有界记录队列（FIFO 保旧弃新，`DroppedCount`），`Listen/Unlisten/Receive/GapCount`，`Token.Cancel` 协同停泵；断线窗口 at-most-once（`GapCount` 计断线，自动重连 4×节拍、成功后重放 `LISTEN`）
- `RedisOpenSubscriber`：`RESP2` 订阅态独占、`Subscribe/PSubscribe/Receive/SubbedChannels/Patterns`，传输工厂 `IRedisTransport` 可注入，`PING` 保活默认关，暖机握手 `AUTH/SELECT`，单帧 16MB 上限

## 性能

- `inline` 事件唤醒判定（`atomic_load` 快路径）；零拷贝队列 `TByteSpan`/`TRespValue` 视图，不扁平化托管串
- 固定挂载成本 ~15–20µs/往返（两次跨线程唤醒），`bytes.ops` 单源复用，不复制调度
- 节拍 `inline` 整数比较，`EffectiveIoTimeoutMs = max(2×节拍,1000)` 钳 3600000，取消即时惊动

## 稳定性

- `Cancel` → `RemoveOnCancel` 摘链（`async.cancellation` V3-B7 幂等注销），`Destroy` 同步收尾不留线程；`FConn` 仅泵线程触碰，`PQnotifies` 逐条 `PQfreemem`（`heaptrc 0`）
- 句柄 `ErrorObj` 所有权在句柄、析构 `Free`，消费方不得手动 `Free`；`IsCanceled` 仅请求且失败时置位
- `heaptrc 0 unfreed`：`test_db_async` 12 组 + `test_db_pg_listen` 11 组 + `test_db_redis_subscribe` 10 组；`bench_db_async` 在册

## Owner 边界

- 底座零平行宇宙：执行/泵线程 = `thread.pool` 单工池；等待/互斥 = `sync`；取消 = `async.cancellation` 子令牌级联；运行时初始化 = `thread.init`（`uses` 首位）
- 缺能力先反哺 `thread.pool`/`sync`/`async.cancellation`/`text.kv`/`platform.random`，不绕边界自造线程原语
