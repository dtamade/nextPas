# nextpas.core.db.stmtcache — 语句缓存域契约

**模块**：`nextpas.core.db.stmtcache.{base,intf,pas}` 聚合 sqlite LRU + pg `np_db_stmt_<n>` 注册表  
**层级**：L3 家族 → L2 后端（`sqlite.conn`/`pg.conn` 透明缓存，依赖 L0–L2）  
**四件套**：`stmtcache.base` ← `stmtcache.intf` ← `stmtcache` 门面 ← 后端实现聚合  
**对应主契约**：`CONTRACT.md` §1.1 语句缓存行 + §2.8 INC-3 透明缓存

## 职责

- sqlite 侧：连接级空闲 LRU（键 = 原始 SQL 文本，默认 64，`<=0` 关闭），`Query` 内复用、借出即移除、嵌套安全；归还 `Reset+ClearBindings`，失败弃置
- pg 侧：服务端 prepared 注册表 LRU（键 = `::bytea` cast 后规范形 SQL，语句名 `np_db_stmt_<n>` 单调递增），`PREPARE` 双保险自愈（回滚 26000 + 42P05）
- 失效控制 `IDbStmtCacheControl.Clear/Size/HitRate`，`Migrate` 成功后自动 `Clear`，`DEALLOCATE ALL` 不丢

## 性能

- 零拷贝键视图：规范形 SQL 不复制额外缓冲；命中判定 `inline`，无额外分配
- `RenderDollar`/`MaxIndex` 不建槽数组（热路径零分配，复用 `bytes.ops`/`text.sqlscan` 单源状态机，不复制词法）
- `text.builder` 单遍追加，L1 `text.sqlscan` 单源复用

## 稳定性

- 缓存 `Clear` 在析构/连接关闭全路径：sqlite 句柄 `Finalize`，pg `DEALLOCATE ALL` + 簿记清零，会话结束服务端语句自消亡
- 复位失败弃置不回池，不泄漏坏句柄；`heaptrc 0 unfreed`：`test_db_stmt_cache` + `bench_db_stmt_cache` 2.1–2.4× 加速
- 线程亲和不变：单连接单线程，缓存不引入并发复用

## Owner 边界

- 缺能力先反哺 `text.sqlscan`（词法扫描 `bytes.ops` 单源）、`bytes.ops`（视图），不在本域复制状态机
