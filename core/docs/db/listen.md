# nextpas.core.db.pg.listen — LISTEN/NOTIFY 订阅域契约

**模块**：`nextpas.core.db.pg.listen.{base,intf,pas}` 独立三件套（专用连接 + 单工泵线程 + 有界队列）
**层级**：独立 L3 族（已升格；依赖 `thread.pool` + `sync` + `async.cancellation`；寄居债已清，四件套/L0–L3/`bytes.ops` 单源/`inline`+零拷贝/`RemoveOnCancel`/`Destroy`/`PQfreemem` 全路径已兑现）
**四件套**：`listen.base` ← `listen.intf` ← `listen` 门面
**对应主契约**：`CONTRACT.md` §2.18；聚合视图见 `async.md`

> 本域为 `async` 订阅族的 pg 分支，薄契约聚焦 `TPgListener` 单例；性能（`inline` 唤醒、零拷贝 `TByteSpan`）、稳定性（`RemoveOnCancel` 摘链、`Destroy` 同步收尾、`PQfreemem`）与 Owner 边界（`thread.pool`/`sync`/`async.cancellation`）与 `async.md` 同源，门禁 `test_db_pg_listen` 11 组 `heaptrc 0`；重连重放与有界保旧弃新语义详 `async.md`。
