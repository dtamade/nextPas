# nextpas.core.db.factory — 驱动工厂 / Open 即池域契约

**模块**：`nextpas.core.db.factory.{base,intf,pas}` 聚合内建五驱动自注册 + 第三方注入
**层级**：独立 L3 族（已升格；依赖 L0–L2，不触后端 FFI 细节；`factory.builtin` side-effect 聚合；寄居债已清，四件套/L0–L3/`bytes.ops` 单源/`inline`+零拷贝/`Close`/`Shutdown` 全路径已兑现）
**四件套**：`factory.base` ← `factory.intf` ← `factory` 门面 ← `factory.builtin` 聚合实现
**对应主契约**：`CONTRACT.md` §1.1 驱动工厂行 + §2.14 `IDbDriver`/`DbOpen`/`DbOpenPool`

## 职责

- `IDbDriver(Name/Kind/Open)` 抽象；`DbRegisterDriver`  nil/空名/重复名 `fail-closed`（大小写归一小写，`dbkUnknown` 可诚实占位第三方）
- `DbOpen(name|kind, dsn[, opts])` 统一打开：内建五驱动 `sqlite/postgres/mysql/odbc/redis` 单元初始化自注册，`uses factory.builtin` 即得字典序快照 `DbRegisteredDrivers`
- `DbOpenPool(name|kind, dsn, policy)` 以 `DbOpen` 为工厂闭包构建 V3-C3 池 `TDbPool`（Go `*sql.DB` 即池），连接选项取 `Default`

## 性能

- 复用 `bytes.ops`/`text.kv` 单源：DSN 词法 `ParseKV` 零分配，`NormalizeLowerTrim` 单源，不复制 `LowerCase(Trim)`
- `inline` 注册表查找：`FindEntryLocked` 线性扫描（个位数量级）+ 快照插入排序，`DbDriverExists` `inline` 探活
- 工厂闭包 `reference to function` 零额外句柄；`Open` 在锁外执行，不持锁做建连

## 稳定性

- `DbOpenPool` 租约释放不丢：池 `Close`/`Shutdown` 空闲清零、在途归还直接销毁（排空语义），`heaptrc 0 unfreed`：`test_db_factory` 15 组 + `test_db_pool_v2` 回归
- 锁内单出口规避 FPC trunk「`const` 接口临时实参 + 锁内 `try-finally` 提前退出」泄漏（托管传参 + 异常移锁外）
- 预热 `MinConnections` `fail-fast` 建连错原样上抛，不给半可用池

## Owner 边界

- 缺能力先反哺 `text.kv`（`ParseKV/ScanKV/ValidateKV` 单源）、`bytes.ops`（归一）、`sync`（mutex），不绕边界直连 `libpq`/`libmysql`
