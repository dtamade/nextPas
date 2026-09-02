# nextpas.core.db.redis.subscribe — Redis SUBSCRIBE 订阅域契约

**模块**：`nextpas.core.db.redis.subscribe.{base,intf,pas}` 独立三件套（专用连接 + 单工泵线程 + 有界队列）  
**层级**：L3 家族（依赖 `thread.pool` + `sync` + `async.cancellation` + `db.redis.resp`）  
**四件套**：`subscribe.base` ← `subscribe.intf` ← `subscribe` 门面  
**对应主契约**：`CONTRACT.md` §2.19；聚合视图见 `async.md`

> 本域为 `async` 订阅族的 redis 分支，薄契约聚焦 `RedisOpenSubscriber`；性能（`inline` 判定、零拷贝 `TRespValue` 视图、`RespTryParse` 单源）、稳定性（`RemoveOnCancel` 摘链、`Destroy` 同步收尾、传输工厂可注入、`MAX_FRAME_BYTES=16MB` 护栏）与 Owner 边界（`thread.pool`/`sync`/`async.cancellation`）与 `async.md` 同源，门禁 `test_db_redis_subscribe` 10 组 `heaptrc 0`。
