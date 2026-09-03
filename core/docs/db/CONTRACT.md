# nextpas.core.db 代码契约（家族）

**模块路径**：`core/src/nextpas.core.db*.pas`
**层级**：L3 家族（门面/适配 L3；base/intf/trace/后端/池/迁移/batch/perf 皆 L2 基础设施，严格依赖 L0-L2 单向，无上向，物理层级与目录隔离一致经 module-registry 自动目录校验非文档豁免；可裁剪边界=直连 adapter Connect* 或按需 factory.register.* 单后端注册单元，显式锁定于 module-registry，见 §1/§2.14；wallet 业务已独立 Owner=wallet lane，复用 L2 infra 零同层耦合）
**Owner**：core-db lane
**最后更新**：2026-09-03（匠心修复11：PG N≥500 MUST走IDbArrayBinding unnest fail-closed防6×误用 + 母册瘦身 <500薄索引分治 + DM J1 nightly live 证据闭环）

**版本**：1.5（自 1.0 起累计：A5 redis+统一工厂、B1 能力矩阵、B2 查询级超时 … 详见 `ROADMAP_FINAL_20260828.md`；1.5 瘦身分治单源收敛）

> **维护注记**：家族布局/能力矩阵以 `capprobe`/`intf` 为单源，母册薄索引 <500 行无双处制表。

> **分册索引**：见 `pool.md`/`trace.md`/`redis.md`/`batch.md`/`perf.md`/`migrate.md`/`nightly-live.md`/`wallet/CONTRACT.md`（仅索引不双处制表）。

---

## 1. 家族布局

| 单元 | 层 | 职责 |
|------|----|------|
| `nextpas.core.db.base` | L2 家族依赖根（仅依赖 L0-L1，L3 严格下向 L2，无上向/同层依赖；物理层级与目录隔离一致，自动目录校验，非文档豁免/白名单） | TDbKind / TDbColumnType / EDbError / EDbNotSupported |
| `nextpas.core.db.intf` | L2 契约（仅依赖 base，同层单向） | IDbConnection / IDbQuery / IDbTxControl 等统一面 |
| `nextpas.core.db.sqlite.*` | L2 后端 | SQLite 实现：base/ffi/conn/pool/tx + 门面 |
| `nextpas.core.db.pg.*` | L2 后端 | PostgreSQL 实现：base/ffi/loader/conn/listen + 门面 |
| `nextpas.core.db.mysql.*` | L2 后端 | MySQL/MariaDB 实现：base/ffi/loader/adapter（双方言 72B/112B） |
| `nextpas.core.db.odbc.*` | L2 后端 | ODBC 网关：base/ffi/loader/adapter（ISO CLI，含国产库） |
| `nextpas.core.db.redis.*` | L2 后端 | Redis RESP2 实现：base/resp/transport/pipeline/recv/adapter/subscribe + 门面（recv+pipeline 体积分治，adapter <800 行软阈内，环形缓冲+分块流水线单源 bytes.ops 零拷贝，详 §2.13） |
| `nextpas.core.db.dm.*` | L2 后端 | 达梦 DM8 DPI 原生：base/ffi/loader/adapter + adapter.synthetic 独立 helper（`libdmdpi.so`，§2.21） |
| `nextpas.core.db.sqlite.adapter` | L3 适配（严格下向 L2 后端，无上向） | SQLite 包装（ConnectSqlite） |
| `nextpas.core.db.pg.adapter` | L3 适配（严格下向 L2 后端，无上向） | PG 包装（ConnectPostgres）+ ? → $N 翻译 |
| `nextpas.core.db.mysql.adapter` | L3 适配（严格下向 L2 后端，无上向） | MySQL 包装（ConnectMysql）+ `?N→?+槽位` 翻译 |
| `nextpas.core.db.mysql.tls` | L2 桥接 | MySQL TLS 校验桥接（`bytes.ops` 单源 `inline` 零拷贝 + `nextpas.core.tls` 标准校验 Owner=tls，`ParseMysqlSslMode/MysqlTlsToVerifyMode/ValidateMysqlTlsOptions` 单源，`CLIENT_SSL=2048` + `MYSQL_OPT_SSL_*` 单源于 `db.mysql.base`，经 `ConnectMysql` `my_options` 直达建连已闭环 `verify-full`/`verify-ca`（`bytes.ops` 单源 inline 零拷贝，Owner=tls，见 §2.1）） |
| `nextpas.core.db.odbc.adapter` | L3 适配（严格下向 L2 后端，无上向） | ODBC 包装（ConnectOdbc）+ SQLBindParameter |
| `nextpas.core.db.redis.adapter` | L3 适配（严格下向 L2 后端，无上向） | Redis 包装（ConnectRedis）+ `?→bulk` |
| `nextpas.core.db.dm.adapter` | L3 适配（严格下向 L2 后端，无上向） | DM 包装（ConnectDm）+ `?→$N` 翻译（§2.21） |
| `nextpas.core.db.dm.adapter.synthetic` | L3 适配子模块（严格下向 L2 dm.base + L1 text/bytes/collections/sync，无上向） | DM 合成代理 surrounding cost 独立 helper（DmSyntheticDpiProxy/E2EProxy 单源，bytes.ops 单源 inline 零拷贝，已抽离 common，见 §2.21） |
| `nextpas.core.wallet` | L3 业务 | Wallet 账本域已独立（Owner=wallet lane，四件套已迁至 wallet.impl，见 `wallet/CONTRACT.md` 单源；§2.22 仅薄索引） |
| `nextpas.core.billing` | L3 业务 | 通用计费域已独立（Owner=billing lane，四件套 billing.base←billing.intf←billing.impl←billing 已落地，独立于 wallet，L0-L2 严格单向，bytes.ops/text 单源 inline/零拷贝） |
| `nextpas.core.db.wallet` | 已移除(2026-09-02) | 兼容别名已物理删除，统一使用 `nextpas.core.wallet`（见 `wallet/CONTRACT.md`）；db 家族不再占用 wallet 命名，可裁剪性债务已闭环（原 deprecated 窗口至 2026-Q4，现提前物理删除） |
| `nextpas.core.db.bulk` | 泛化助手 | BulkCopy 单事务批量行复制（V4.3 universal） |
| `nextpas.core.db.batch` | L2 基础设施 | 统一批量/流工厂（`batch` 单源，见 `batch.md` §2.9/§2.16） |
| `nextpas.core.db.perf` | L2 基础设施 | 独立性能契约单源（见 `perf.md`/`perf.pas` 单源，`nightly-live.md` 三级闸门） |
| `nextpas.core.db.factory` | 泛化助手 | 统一驱动注册表 `DbOpen`（注册表零 L2 导入，可独立构建，见 §2.14） |
| `nextpas.core.db.factory.pool` | 桥接叶 | 工厂-池桥接 `DbOpenPool`（见 §2.14） |
| `nextpas.core.db.factory.builtin` | 已移除(2026-09-02) | 已物理删除（见 §2.14） |
| `nextpas.core.db.pool` | L2 基础设施 | 通用连接池 TDbPool（读池+单写者，跨后端；L2 下沉后 wallet 仅 L0-L2 单向复用，无 L3→L3） |
| `nextpas.core.db.async` | 泛化助手 | 异步挂载与取消 `TDbAsyncExecutor`（单飞 + 令牌→PQcancel） |
| `nextpas.core.db.trace` | L2 观测（仅依赖 base/intf） | IDbTraceListener 同步回调面（四后端同构） |
| `nextpas.core.db.sqlscan` | 共享引擎(已物理删除) | 已物理删除（缺失强制迁移，历史 deprecated 薄别名及类型/常量别名已删除无残留；单真相 `text.sqlscan`，见 §2.20） |
| `nextpas.core.db.pg.listen` | 订阅 | PG LISTEN/NOTIFY 专用连接+泵线程（B7） |
| `nextpas.core.db.redis.subscribe` | 订阅 | Redis SUBSCRIBE/PSUBSCRIBE 推送会话（B8） |
| `nextpas.core.db.tx` | 泛化助手 | WithTransaction / WithTransactionRetry over IDbConnection |
| `nextpas.core.db.migrate` | L2 基础设施 | schema 版本化 over IDbConnection（L2 下沉后 wallet 仅 L0-L2 单向复用，无 L3→L3） |
| `nextpas.core.db.savepoint` | L2 基础设施 | Savepoint 拼串单源（Validate+`TBufStringBuilder` 单分配单 Move 零拷贝，`bytes.ops` 单源 inline，被 `bulk/pg/mysql/dm/batch` 复用，已收敛） |
| `nextpas.core.db.err` | 归一 | Classify* 错误归一表（sqlite/pg/mysql/odbc/redis/dm） |
| `nextpas.core.db.capprobe` | 探针 | 能力探针与版本解析（ServerVersion / Supports*） |
| `nextpas.core.db.pas` | 门面 | 聚合 re-export 全部公共 API（六后端工厂 + 能力探测 + 事务/迁移；可裁剪，经 `factory` 驱动表可插拔，未使用后端零编译期耦合） |

依赖方向严格单向：L2 `db.base ← db.intf/trace ← 后端实现`；L3 `adapter/tx 严格下向 L2 契约与后端（无上向，无同层依赖，严格下向分层）` + L2 infra{pool,migrate} ← L3 门面`（pool/migrate 已下沉为 L2，wallet L3 仅 L0-L2 单向复用，无 L3→L3 同层耦合；家族内受控上向例外已消除，分治后零上向；物理层级与目录隔离一致经 `core/docs/module-registry.md` 与 `core/docs/db/CONTRACT.md §1/§2.14` 双源锁定，由 `test_db_facade_source_contract` 与 `module-registry` 自动目录校验持续校验防回退，非文档豁免/白名单）。
**db.base 与 db.intf 禁止 uses 任何具体后端单元。**
**门面可裁剪纯转发（硬门禁锁定）**：`nextpas.core.db.pas` 未使用后端零编译期耦合（实现段仅 factory 驱动表，零 adapter/addr 硬链接）；可裁剪零耦合与 inline 薄转发正交：单后端裁剪直连对应 adapter，全量显式注册不依赖隐式聚合叶（`factory.builtin` 已物理删除，显式注册为准，裁剪边界 = 直连 `Connect*` 或按需 `factory.register.*`，由 `test_db_facade_source_contract` 硬门禁锁定零硬链+inline 纪律，非文档约束；能力误用时诚实降级经 `capprobe`/`Supports*⇔接口` 互证硬门禁）。业务以 CONTRACT 为准、缺能力先反哺 owner。性能与资源释放由各 owner 承载（`bytes.ops` 单源 `BYTES_OPS_SINGLE_SOURCE`、接口自动归还，见 adapter/factory/`batch`）。

## 2. 统一层契约

### 2.1 连接与查询

```pascal
Conn := ConnectSqlite(':memory:');            // 或 ConnectPostgres(conninfo)
Conn.Exec('CREATE TABLE t (...)');            // 多语句 DDL/DML，原文透传不翻译
Q := Conn.Query('SELECT ... WHERE id = ?');   // 参数化 SQL 一律用顺序 ?
Q.BindInt64(1, 42);
while Q.Step do ...;                          // 接口引用计数自动释放
```

- **所有权**：对外一律 interface（COM 引用计数）；消费方不手写 Free。
  适配器持有后端对象并在析构时释放。
- **索引**：绑定参数 1-based，列 0-based（两后端原生约定一致，直接统一）。
- **占位符**：参数化 SQL 一律顺序 `?`。pg 适配器翻译为 `$N`（跳过字符串
  字面量/双引号标识符/行块注释；dollar-quote 体不识别——与 pg.conn 参数
  计数同一受控边界）。`?N` 显式编号直接映射 `$N`。mysql 适配器把 `?N`
  经槽位计划重写为顺序 `?`（携带物理槽→逻辑号映射，构造期与服务端参数
  计数互证；扫描隔离字面量/反引号标识符/`--`、`#` 行注释/块注释）。
  Exec 不翻译。
- **IsNull 统一**：sqlite 侧经列类型 SQLITE_NULL 判定；pg 侧透传 PQgetisnull。
- **NULL 读取语义**：`IsNull(AIndex)` 是判空唯一途径；`GetInt64/GetText/
  GetDouble/GetBlob` 对 NULL 列静默返回零值（0/''/nil），不抛错——消费方
  必须先 IsNull 再取值。不引入 Optional/可空包装类型（仓库错误处理策略）。
- **列类型（INC-6）**：`TDbColumnType = dbcNull/dbcInteger/dbcFloat/
  dbcText/dbcBlob/dbcBool`。NULL 值一律报 `dbcNull`（行级信号，优先于
  声明类型）；bool 两后端自然映射——pg 原生 bool(OID 16) 与 sqlite
  声明亲和含 BOOL 的列。bool 值读取经 `GetInt64` 归一 1/0；pg `GetText`
  保持 libpq 原文 't'/'f'。时间/JSON 暂走 dbcText + 消费方解析
  （time.iso8601），出现真实需求再按 INC-6 决策规则评估加值。
- **连接选项（INC-7）**：`TDbConnectOptions` 经工厂重载传入
  （`ConnectSqlite(path, opts[, cacheCap])` /
  `ConnectPostgres(conninfo, opts)` / `ConnectMysql(dsn, opts)`）。
  语义诚实表：BusyTimeoutMs 在 sqlite 是锁等待上限（busy_timeout）、
  在 pg 映射建连超时（connect_timeout）、在 mysql 映射建连超时
  （MYSQL_OPT_CONNECT_TIMEOUT，秒粒度向上取整）——都不是语句超时；
  StatementTimeoutMs 仅 pg（会话级 statement_timeout）与 mysql
  （Oracle 库且服务端 ≥8.0 的 max_execution_time，SELECT 域，版本探测
  后静默降级）有对应机制；sqlite 非 0 被忽略不冒充。0 = 不设置。
  mysql DSN 形态：空格分隔 key=value（host/port/user/password/db/database/socket，
  值可用引号包裹），socket 存在时优先于 host；port 取值 1..65535（非范围 fail-fast decConnection，未知键提示候选 host/port/user/password/db/database/socket），缺省 host 127.0.0.1 port 3306（MYSQL_DEFAULT_* 单点常量，SameText 零分配比较）。
  **F-10 提示**：sqlite 文件库的并发读写靠 busy_timeout 排队，缺省
  0 = 立即 SQLITE_BUSY——生产文件库建议显式非零（工厂 OpenSqlitePool
  便利形态缺省烘入 `DefaultSqliteBusyTimeoutMs`）；`:memory:` 库无
  文件锁竞争，0 无害。
- **线程亲和性**：一个 IDbConnection 同时只能被一个逻辑线程使用
  （Exec/Query/Step 无并发防护，互斥锁只保护事务簿记）；跨线程并发
  访问经 db.pool 分发（每线程独占 Acquire 的连接）。IDbQuery 生命周期
  不得超出其创建所在连接的使用周期。
- **Changes 统一为 Int64**。
- **Blob**：接口含 BindBlob/GetBlob。pg 侧经 hex 文本 + `::bytea` cast 实现，
  真机门禁覆盖；sqlite 侧原生透传。

#### TLS（V3-B4 成文，单源分治）

TLS 建立与校验归各自传输栈，统一层不二次包装（诚实边界）。**责任单源**：`postgres` libpq 原文透传 `sslmode=verify-full`（libpq 执行，`require` 仅加密不验）；`redis` `UseTls/TlsServerName` 经 `nextpas.core.tls TLSDial` 标准校验（`ErrType='NET'`→`decConnection`）；`mysql` 经 `nextpas.core.db.mysql.tls` 复用 `nextpas.core.tls` 标准校验 + `my_options` 直达建连已闭环（`bytes.ops` 单源 `inline` 零拷贝，`CLIENT_SSL=2048`/`MYSQL_OPT_SSL_*` 单源于 `db.mysql.base`，`ParseMysqlSslMode/ValidateMysqlTlsOptions` 单源 inline 零拷贝视图比对，`verify-ca/verify-full` 落地 `MYSQL_OPT_SSL_CA/CAPATH/CERT/KEY/CIPHER/CRL` + `MYSQL_OPT_SSL_VERIFY_SERVER_CERT` + `CLIENT_SSL`，Owner=tls，不自建平行校验器；性能 inline/零拷贝，稳定性 `try..finally` 句柄不丢）；`odbc` 驱运透传；`sqlite` N/A。细节与真机实证已沉至 `tls` owner 与 `redis.md`/`db.mysql.tls` 单源，本册不双处索引。

### 2.2 错误模型——判别联合单源

适配器把后端异常转译为 `EDbError`（`TDbNativePayload` 判别联合，`Payload.Kind` 单源）：

| 判别分支 | 有效字段 | 语义 |
|---|---|---|
| `dbkSqlite` | `SqliteCode / SqliteExt` | 原生结果码 / extended 码 |
| `dbkPostgres` | `State=SqlState, Severity, Detail` | libpq 诊断字段 |
| `dbkMysql/dbkOdbc/dbkDm` | `NativeCode + State` | 服务端码位 + SQLSTATE |
| `dbkRedis` | `State=ErrType` | RESP 首词 |
| `dbkUnknown` | （无原生码位） | 统一层错误 |
| 公共 | `Message` | 原始消息（全分支） |

兼容属性 `BackendCode/ExtendedCode/SqlState/Severity/Detail` 为 `inline` 判别转发（非分支返回 0/空串，fail-closed）；新代码优先 `Payload.Kind` 分支访问。**v2 起语义归一经 `db.err` 受控映射**：Category/Constraint 枚举由 Classify* 纯函数表产出（宁可欠归一不错归一），判别载荷与归一枚举并存。非后端异常原样穿透。

### 2.3 事务（IDbTxControl + db.tx + IDbSavepointControl）

两个入口，分工明确（V2-S2 savepoint 混合模型）：

| 入口 | 模型 | 语义 |
|---|---|---|
| `WithTransaction(Conn, Body: TDbConnProc)` **B13 推荐** | 自动 savepoint 混合 | 连接由框架作实参传入回调，回调体零捕获。深度/savepoint 语义见下行；池化租约在本调用语句结束即归还。 |
| `WithTransaction(Conn, Proc: TDbTxProc)` ⚠ | 自动 savepoint 混合 | 深度 1 = 真 BEGIN/COMMIT/ROLLBACK；深度 ≥2 = `SAVEPOINT np_db_sp_<N>`，成功 RELEASE 并入父事务，失败 ROLLBACK TO **真正只撤销内层写入**后 RELEASE——外层捕获异常可继续（部分提交语义）。⚠ 捕获纪律见下。 |
| 手动 `BeginTxn/CommitTxn/RollbackTxn` | v1 计数（精细控制面） | Begin 加深、内层 Commit 只降计数、**任意深度 Rollback 回滚整个事务并清簿记**（pg 侧 V2-S2 起对齐 sqlite：此前深度 >1 只降簿记不真回滚）。 |

- 嵌套的 `WithTransaction` 要求连接实现 `IDbSavepointControl`（两内置
  后端都实现）；无该能力时 fail-fast 抛错，绝不静默退化为计数并入。
- `TxDepth` = 真实 SQL 事务深度；savepoint 层不计入。手动嵌套计数语义
  保持 v1 不变。
- 外层回滚撤销一切（含已 RELEASE 的内层）；savepoint 名格式固定
  （`np_db_sp_<层级>`），兄弟层级顺序复用安全。
- 手动 savepoint 面不变：`IDbSavepointControl.Savepoint/RollbackTo/
  ReleaseTo`，命名 `[A-Za-z0-9_]+`，违规抛 EDbError。
- **池化租约纪律（B13）**：闭包对托管变量（含连接）的真实捕获会把该
  引用保持到闭包销毁——实测可迟至外层例程退出，期间 db.pool 出借的
  租约（尤其单写者槽位）被滞留过语句边界（heaptrc 未覆盖闭包捕获非堆泄漏，source-contract 硬门禁已落地 `core/tests/nextpas.core.db/test_db_factory/check_pool_lease_source_contract.sh`）。池化连接一律用参数化形态
  `WithTransaction(Conn, procedure(const C: IDbConnection) ...)`
  （框架传实参、零捕获、语句结束即归还）；捕获形态仅限非池化/专用
  连接（已 `deprecated`，见 `nextpas.core.db.pas:148-152`）。`WithTransactionRetry` 同样提供参数化重载，租约在重试结束
  归还。
- **瞬时错误重试（V3-B5）**：`WithTransactionRetry(Conn, Proc[,
  Policy])`（另有参数化 `Body: TDbConnProc` 重载，见上条）——仅整事务重跑，绝不部分重试；**幂等责任在回调**（同一
  副作用可能被执行多次）。缺省段位 `DbRetryableDefault`：死锁/序列化
  冲突（decTransaction）与 sqlite 锁竞争（decTimeout 且 BUSY/LOCKED
  码位）可重试；pg 语句超时（查询真慢）、连接断亡（需重连，池的
  领域）、约束违例不静默重试。策略词汇对齐 core.async.retry
  （MaxRetries/BaseDelayMs/MaxDelayMs/BackoffFactor 指数退避），
  自定义谓词经 `TDbRetryPolicy.ShouldRetry` 覆盖缺省段位。
  非 EDbError 业务异常永不重试直接穿出。
- **pg 差异**：libpq 无 autocommit 探针，裸 BEGIN 混用守卫仅 sqlite 提供；
  pg 侧误用由簿记守卫（无 Begin 的 Commit/Rollback 抛错）兜底。

### 2.4 迁移（db.migrate）

> **分册索引**：本节仅保留分治不变量，完整契约见 `migrate.md` 单源（`CONTRACT §2.4` 已分册，遵循单源分治复用不变量）。

`Migrate(AConn, Migrations)` 是唯一的迁移面（G2 起旧 `db.sqlite.migrate`
后端类表面已退役，消费方统一走本单元）：
版本表 `schema_migrations(version INTEGER PRIMARY KEY, applied_at TEXT,
checksum TEXT)`，DDL 两引擎通用；applied_at 由本单元显式写入 ISO8601
UTC 文本。幂等、每批一个事务（走泛化 WithTransaction）、上下限校验同
sqlite 版。

完整性契约（V2-S6）：

- **checksum 规范形**：批内 SQL 按 LF 连接后取 CRC32，八位小写十六进制。
  只依赖步骤序列本身，跨后端跨进程确定；消费方可用
  `nextpas.core.checksum.crc32` 独立复核。
- **防篡改**：已应用版本的记录 checksum 与当前列表计算值不符时，
  `Migrate` 抛 `EDbMigrateError`（携带版本号）拒绝继续。威胁模型 =
  意外漂移与误编辑，非对抗性攻击。
- **旧表自愈**：S6 前的两列旧表经探测自动 `ADD COLUMN` 升级（后端
  中立）；历史遗留的空 checksum 条目在下次 `Migrate` 时按当前列表
  回填（幂等 UPDATE），回填后篡改可检。
- **dry-run**：`MigrateDryRun` 返回逐批状态计划
  （`drsApply` / `drsApplied` / `drsChecksumMismatch`），严格零写入
  （不建版本表、不升级旧表）；结构性错误（乱序、越界）仍抛出。
  同一输入上 dry-run 上报 mismatch 而真实 `Migrate` 抛错——预览与
  应用的校验语义分野。
- **wallet/身份域前置依赖（已落地）**：`WalletMakeMigrations v15` 迁移清单仅含 wallet 四表，FK `wallet_balances(user_id)→user_profiles(id)` 指向已落地 `nextpas.core.identity` 的 `user_profiles`（`IdentityMakeMigrations v14` 单源，`core/docs/identity/CONTRACT.md`），**部署序 = IdentityMakeMigrations v14 → WalletMakeMigrations v15**（见 §2.22 前置依赖序与 `wallet/CONTRACT.md §1`）；能力矩阵不新增 wallet 位，测试以 `Migrate(IdentityMakeMigrations)` 真表 + `FOREIGN_KEYS=ON` 保障（stub 仅作语义回退验证）。

### 2.5 逃生舱纪律

`IDbConnection.Raw` 暴露 sqlite3*（pg 侧返回 nil，需 PGconn* 时直用
`nextpas.core.db.pg` 门面）。仅限抽象层未覆盖的特性（LastInsertRowId、
BusyTimeout、Checkpoint、LISTEN/NOTIFY 等）。使用逃生舱的代码即放弃
跨后端可移植性，须在调用点注释说明。

### 2.6 已知后端差异（conformance 套件登记）

以下差异经 `test_db_conformance` 双后端实证，消费方跨后端编码时必须
规避：

| 差异 | sqlite | postgres | 消费方守则 |
|---|---|---|---|
| NULL 排序 | ASC 时 NULL 排最前 | ASC 时 NULL 排最后 | 不依赖默认 NULL 位置；显式 `ORDER BY (col IS NULL), col` 或后端各自的 NULLS FIRST/LAST |
| 列元数据时机 | prepare 后即可读 | 首次 Step（执行）后才可靠 | 元数据统一在首次 Step 后读取；空结果集同样成立 |
| 列名大小写 | 保留声明形式 | 未加引号标识符折叠小写 | 列名比较一律不区分大小写（SameText） |
| 语法错误归一 | 无细粒度码，decUnknown | SQLSTATE '42' 类 → decSyntax | 跨后端只依赖 decConstraint/decTimeout 等可靠类目 |

配套实现决策：sqlite 列类型采用**声明亲和优先**（静态、空结果集可读，
对齐 pg 静态 OID 行为），表达式/聚合回落行值类型；`IsNull` 始终用
行值类型判定，与声明亲和无关。

MySQL/MariaDB 后端（V3-A2）方言差异：

| 差异 | 说明 | 消费方守则 |
|---|---|---|
| RELEASE 语法 | 必须带 SAVEPOINT 关键字 | 统一面 `IDbSavepointControl.ReleaseTo` 已封装差异，勿手写 SQL |
| BEGIN IMMEDIATE | InnoDB 无 IMMEDIATE 变体 | `BeginTxn(True)` 在本后端为 no-op；写锁语义不跨后端假设 |
| 布尔 | 无原生 bool；TINYINT(1) 为约定 | ColumnType 报 dbcInteger；GetInt64 读数值 |
| 列元数据时机 | 首次 Step（prepared 执行）后可读 | 与 pg 相同：统一在 Step 后读取 |
| 多语句 Exec | 依赖连接期 CLIENT_MULTI_STATEMENTS | 工厂已默认请求；Exec 内部逐结果排空，消费方无感 |
| 错误归一 | 码位优先（CR_*/ER_*），SQLSTATE 只做类兜底 | 只依赖 Category/Constraint 枚举，勿解析原始码位 |

执行模型注记：mysql 的 IDbQuery 走 prepared statement 二进制协议
（与 pg execParams 同级，参数化即注入安全）；DECIMAL 列经二进制协议
天然以文本形态返回（length-prefixed），GetText/GetDouble 直读。双方言
MYSQL_BIND 布局由 ffi 具名偏移常量 MYSQL_BIND_*_OFF_* 单点复用并经
initialization/离线门 PtrUInt 自证钉死（Oracle 72B @68/70 vs MariaDB 112B @64/96/101）。

### 2.6b 查询级选项（V3-B2，TDbExecOptions）

`Exec(sql, opts)` / `Query(sql, opts)` 的 `TimeoutMs` 是**建议值
（advisory）**：后端存在可安全应用的机制则生效（超时归一 decTimeout，
与 INC-7 同类目），否则忽略不报错——消费方代码跨后端可移植。逐后端
应用矩阵：

| 后端 | Exec(opts) | Query(opts) | 机制 |
|---|---|---|---|
| postgres | ✅ 会话 SET/SHOW 恢复包裹（同步窗口） | ✅ 生效窗口=查询对象存活期（析构恢复原值） | statement_timeout；57014→decTimeout |
| mysql/MariaDB | 仅 Oracle 库 ≥8.0 探测通过；其余忽略 | 忽略（v1） | max_execution_time(ms)；3024→decTimeout |
| odbc 网关 | ✅ 逐语句 | ✅ 逐语句 | SQL_ATTR_QUERY_TIMEOUT 秒粒度向上取整；属性随句柄消亡无会话污染 |
| sqlite | 忽略 | 忽略 | 无语句级机制（连接级 busy_timeout 已有，INC-7） |

约束注记：
- pg/mysql 会话级机制的恢复以 SHOW/@@ 读回原值为准，但**同一连接上
  不嵌套使用带超时的查询对象**——后建对象会覆盖先建对象的会话值且
  基线互相污染（单连接单线程契约内的显式限制）。
- pg Query(opts) 的超时在查询对象存活期内持续有效：长生命周期游标
  = 长超时窗口；释放对象即恢复。池化场景查询对象随租约归还前释放
  （接口引用计数保证）。
- mysql Query(opts) 升级路径登记路线图（MariaDB `SET STATEMENT .. FOR`
  前缀 / 客户端 cancel watchdog）。

### 2.7 连接池（db.pool）

> **分册索引**：本节仅保留分治不变量，完整契约见 `pool.md` 单源（`CONTRACT §2.7` 已分册，遵循单源分治复用不变量）。

`TDbPool` 对任意后端 `IDbConnection` 池化（L2 基础设施，已下沉 L2，wallet 仅 L0-L2 单向复用，无 L3→L3），后端特化经连接工厂闭包注入，池体不懂方言。**租约绑定纪律（B13）**：池化连接一律用参数化形态 `WithTransaction(Conn, Body)` 或 `WithRead/WithWriter` 作用域助手，租约语句边界归还；**释放即归还**（代理接口引用计数自动归还，`QueryInterface` 透传全能力面）；**泄漏检测（V3-C3，默认 60s 开）**与**单写者**等细节见 `pool.md` 单源。性能 `inline` 薄转发/`bytes.ops` 单源零拷贝与稳定性资源释放不丢由 `pool.impl` 承载，证据见 `pool.md`。

### 2.8 语句缓存（INC-3，双后端）

**sqlite 侧（V2-S5）**：连接默认带透明预编译语句缓存（空闲 LRU，键 =
原始 SQL 文本，容量经 `ConnectSqlite(path, capacity)` 注入，默认 64；
<=0 关闭）：

- **完全透明**：Query() 内部复用空闲句柄；消费方零感知、零手工管理。
  语义与直连严格一致——**借出即移除**保证同 SQL 的并发活动查询各持
  独立实例，嵌套安全。
- **卫生保证**：归还路径执行 Reset + ClearBindings，绑定值不跨借用
  泄漏；复位失败的语句弃置不回池。
- **失效控制**：`IDbStmtCacheControl`（QueryInterface 探测）提供
  Clear/Size/HitRate。DDL 后 sqlite prepare_v2 自动重编译故不强制
  Clear；`Migrate()` 应用成功后自动调用 Clear（跨后端统一纪律）。

**pg 侧（V3-C1）**：连接默认带服务端 prepared statement 缓存（注册表
LRU，容量经 `ConnectPostgres(conninfo, options, capacity)` 注入，默认
64；<=0 关闭）：

- **键 = bytea cast 后的规范形 SQL**：同一 SQL 不同绑定形态（blob 有
  无 `::bytea` cast）自然分键，防撞名错配。仅参数化语句入缓存（无参
  DDL/DML 直通）。语句名 `np_db_stmt_<n>` 单调递增不复用。
- **自愈双保险**：PREPARE 是事务性的——事务回滚会撤销服务端语句而
  登记仍在，下次执行报 26000 时忘登记换名重建；驱逐 DEALLOCATE 同为
  事务性，若发生在已回滚事务内致语句复活，prepare 报 42P05 时先
  DEALLOCATE 再重试。两路径对消费方完全透明。
- **失效控制**：同 `IDbStmtCacheControl` 契约；Clear = DEALLOCATE ALL +
  簿记清零。连接关闭时会话结束，服务端语句自动消亡。
- **收益判据**：bench_db_stmt_cache pg 段点查对照（见 docs 基准册）。

### 2.9 大对象流（INC-8，`nextpas.core.db.batch` 统一流工厂）

> **分册索引**：本节仅薄索引，完整契约见 `batch.md §2` 单源。

`IDbBlobStream`（Read/Write/Seek/Size，接口释放即关闭）按存储模型分面经 `QueryInterface` 探测，已收敛至 `nextpas.core.db.batch` 统一流工厂（`batch.md §2` 单源，`bytes.ops` 单源 `inline` 零拷贝，接口自动归还）。

### 2.10 能力矩阵（V3-B1 单源，`capprobe`/`db.intf` 单源，无新模块候选）

六后端 `IDbCapabilities` 以 `core/src/nextpas.core.db.capprobe.pas`/`db.intf.pas` 为单源（`DbCapabilities(Conn)` 探测，`QueryInterface` 互证，`test_db_conformance` 钉死），本文仅索引不变量不双处制表（`pool`/`trace`/`redis`/`wallet` 不另制矩阵，防漂移）。分治：`SupportsArrayBinding⇔IDbArrayBinding`（pg-only `unnest`，见 §2.16）与 `SupportsBulkCopy⇔IDbBulkCopy` 正交（`db.bulk`）；方言差异见 §2.6，wallet 不新增位（见 `wallet/CONTRACT.md §1`）。

### 2.11 ODBC 网关（V3-A3/A4，`odbc.*` 单源）

`nextpas.core.db.odbc.*` ISO CLI 网关（D4 国产库备选）。单源契约：**DSN 原文透传** + `text.kv ParseKV` 离线 `fail-fast`（`test_text_kv` + `test_db_odbc_adapter`）；**执行** `SQLPrepare/Bind/Execute` 服务端 prepared + `SQLFetch/GetData` 惰性物化（`01004` 截断按指示符扩缓冲整值重取，`live` 钉死）；**参数缓冲**字段托管稳定缓冲（禁临时地址）；**错误** `ClassifyOdbc` 仅 SqlState（`IM002→decConnection` 等 + ISO 类前缀兜底，`NativeError` 仅透传，`ClassifyOdbcEx` 仅 MySQL 系提精）；**事务** `AUTOCOMMIT OFF/ON` + `TXN_CAPABLE` 守卫；**能力**见 §2.10 + `adapter` 头注（`Savepoints=False` 诚实降级，DM ODBC 网关 `Tier-1` 见 ADR 0002，`P2 libdmdpi` 另议）；**占位符** `?` 直通、`?N` 槽位同 pg/mysql，复用未绑 `fail-fast`。

### 2.12 观测钩子（V3-B3）

> **分册索引**：本节仅保留分治不变量，完整契约见 `trace.md` 单源（`CONTRACT §2.12` 已分册）。

`IDbTraceListener` 是连接级同步回调面（L2 观测，仅依赖 `base`/`intf`，四后端同构），经 `IDbTraceControl` 挂载，`DbTraceControl(Conn)` 统一探测（`nil` = 未实现）。**挂载即补发** `OnAcquire`/`OnRelease`、`OnQuery` 首执行窗口、`OnError` 类目透传、`DB_TRACE_SQL_SUMMARY_MAX=512` 摘要与默认零成本细节见 `trace.md` 单源。枢纽 `TDbTraceHub` 锁内快照、锁外回调（C3 硬边界），性能 `inline`/`bytes.ops` 单源证据见 `trace.md`。

### 2.13 Redis 原生后端（V3-A5）

> **分册索引**：本节仅保留分治不变量，完整契约见 `redis.md` 单源（`CONTRACT §2.13` 已分册，recv+pipeline 体积分治 + `bytes.ops` 单源零拷贝单源收口）。

`nextpas.core.db.redis` 家族：RESP2 协议原生客户端（无 C 库依赖，传输经 `nextpas.core.net` 阻塞 TCP，接口化可注入；`base`/`resp`/`transport`/`pipeline`/`recv`/`adapter` <800 行环形缓冲+分块流水线单源 `bytes.ops` 零拷贝，见 `redis.md` 单源）。**命令面** `?`/`?N` → `bulk`、`回复→行映射`、**执行模型**惰性 `Step`/`Reset`、**事务直映**与能力降级矩阵等细节见 `redis.md` 单源；观测钩子同构 `trace.md`，`INFO` 版本探测与 `TLS` 变体见 `redis.md`。

### 2.14 统一驱动工厂与 Open 即池（V3-A5 收口，`factory`/`factory.pool` 单源，`factory.builtin` 已物理删除(2026-09-02) 不再计入模块节点，无可抽新模块候选）

`nextpas.core.db.factory` 对位 Go `database/sql`/`DbProviderFactory`：`IDbDriver(Name/Kind/Open)`，六驱动经 `DbRegisterDriver` 显式注入（`factory.builtin` 零逻辑聚合叶已物理删除(2026-09-02) 不再计入模块节点/家族布局，文件已移除，不再计入 src 模块清单，可裁剪性债务已闭环；`factory` 注册表本身完全独立构建隔离——实现段/接口段均零 L2 导入 `db.pool`，`DbOpenPool` 已抽离至 `factory.pool` 桥接叶；`nil/空/重复` `fail-closed`，`DbRegisteredDrivers` 排序快照）。**显式注册**：按需 `uses adapter.Connect*→IDbDriver→DbRegisterDriver` 或按需 `factory.register.*` 单后端注册单元，新代码禁止 uses `factory.builtin`，无隐式聚合；裁剪边界 = 直连 adapter Connect* 或单后端 register 单元，额外节点已收敛；`bytes.ops` 单源/引用计数归还见 `adapter`。入口 `DbOpen(name|kind,dsn[,opts])`（规范名→`Kind` 兜底，`dbkUnknown` 无声明→`EDbNotSupported`；DSN 沿用各后端透传，`redis://` 不进本版）/`DbOpenPool`（`factory.pool` 桥接叶 `DbOpen` 闭包建 `TDbPool`，对齐 `*sql.DB`，`bytes.ops` 单源 inline 零拷贝，接口引用计数自动归还，租约 try..finally 不丢）；错误透传 `Backend` 归属（`pg 08000→decConnection`），`advisory` 语义。

### 2.15 sqlite 调优预设（V3-C5，`sqlite.base` 单源）

`ConnectSqlite(path, opts, TDbSqlitePragmas[, cacheCap])`（`sqlite.base`）。旧入口行为零变化。词汇 `JournalMode/Synchronous/ForeignKeys三态/CacheSize/MmapSize`，安全缺省 `Default`（WAL+NORMAL+ON，仅显式生效），`:memory:` 跳 `journal_mode`，`fail-closed` 回读校验 `journal_mode`（`decNotSupported`），`mmap_size` advisory；`DbOpen` 不烘 `PRAGMA`（WAL 持久化头污染），调优走直接入口。

### 2.16 参数级批量绑定（V3-C2，`IDbArrayBinding` 单源，`nextpas.core.db.batch` 统一批量工厂）

> **分册索引**：本节仅薄索引，完整契约见 `batch.md §3` 单源（阈值/基线以 `nextpas.core.db.perf DB_PERF_BATCH_PG_*` 为代码单源、`benchmarks.md:106` 为文档单源，不双处制表）。

单 SQL 每 `?` 绑列数组一次展开 N 行（pg `unnest` 单次往返，与 `IDbBatchExecutor` 正交），探测 `DbArrayBinding(Q)`（`nil`=未支持）与 `SupportsArrayBinding⇔接口` 互证已收敛至 `nextpas.core.db.batch`（见 `batch.md §3`）；**PG N≥500 MUST走`IDbArrayBinding` unnest单往返防6.0×误用**（`batch.strategy DbBatchShouldUseArrayBinding inline`零拷贝 `bytes.ops`单源，误用 BulkFlush fail-closed 见 `db.batch`/`db.bulk`，门禁 `test_db_array_bind`，基线见 `perf.pas`/`benchmarks.md:106`）。

### 2.17 异步挂载与取消（V3-B6 / INC-4，nextpas.core.db.async，`execution.base` 单源，无可抽新模块候选）

把阻塞 db 调用投递到**专用执行线程**，立即返回可等待、可取消的句柄。
硬规则落地（路线图 D8/G3）：**连接仍一连接一线程**——一个执行器绑定
一个连接租约、单飞模型（同一时刻至多一个在途调用），异步的是"等待"
不是"并发复用"；不做连接内多路复用。

```pascal
Exec := TDbAsyncExecutor.Create(Conn);
H := Exec.Submit(procedure begin Conn.Exec(LongSql) end, Token);
{ 主线程让出：可做 UI/调度等他事 }
if H.WaitFor(30000) and (H.ErrorObj = nil) then ...   // 成功取结果
H.Cancel;                        // 任意线程；尽力中断在途查询
```

- **不经门面/底座**：`class` 直构，不进 `db` re-export（默认零成本）；底座 `thread.pool` 单工池 + `thread.init` + `core.sync` + `async.cancellation` + `errors`，零 RTL。
- **取消/状态/生命周期**：`Submit(Work, Token)`→子令牌桥→`IDbCancelControl`（`PQcancel`/progress）→`decTimeout`；`Cancel` 同面；`IsDone/ErrorObj/IsCanceled` 终态（`ErrorObj` 句柄持有）；连接活过执行器，析构 `WaitAll` 不丢线程，单飞违规抛 `EDbError`。
- **性能与护栏**：固定税 `EXECUTION_MOUNT_OVERHEAD_US=20`，阈值 `EXECUTION_MIN_WORTHWHILE_US=50` 单源 `execution.base`（`ExecutionShouldOffload` inline），`SubmitInline` 零唤醒零分配（成功单例 inline 零拷贝）；`Submit` 自适应护栏首轮保守同步零税（微查询免 20µs 放大，长查询首包需显式预估 >阈值）+ `platform_monotonic_ns` + `UpdateAdaptive` inline；`SubmitInline` 已 honor 取消（预取消零执行落 decTimeout，执行期子令牌桥接后端中断）；详见 `benchmarks.md`，本册仅索引。

### 2.18 LISTEN/NOTIFY 订阅（V3-B7，nextpas.core.db.pg.listen）

pg 原生 pub/sub 一等公民化收口（G9）。形态 = **专用连接独占的订阅
会话**：`TPgListener` 构造时私有建连并常驻单工泵线程，"LISTEN 会话
不能跑普通查询"的诚实约束由结构保证——本类不暴露任何查询面。

```pascal
L := PgOpenListener('host=/var/run/postgresql dbname=app user=app');
L.Listen('events');                    // 客户端校验先行，异步应用（典型 ≤1 节拍）
A := L.Receive(2000);                  // 阻塞至 ≥1 条；一次带回全部积压（FIFO）
{ TDbPgNotification: Channel / Payload / SenderPid }
L.Token.Cancel;                        // 协同停泵；Destroy 同步收尾不留后台线程
```

- **Token/门面/底座**：`Token.Cancel` 协同停泵，析构 `RemoveOnCancel` 幂等摘链；独立单元不经 `db` 门面（`thread.init` 置首位），底座 `thread.pool`+`core.sync`+`async.cancellation`。
- **投递/诚实语义**：有界记录队列（互斥+事件，`at-most-once`）；断线丢弃计 `GapCount`，自动重连 `4×`节拍+`connect_timeout=2` 护栏，重放 LISTEN 快照（失败不接管防半配置），队列满保旧弃新计 `DroppedCount`；延迟上界≈节拍+RTT，无 poller 诚实折中。
- **校验/门禁**：频道 `[A-Za-z0-9_]` ≤63 `fail-fast`，`PQnotifies` 逐条 `PQfreemem` + `TPGnotify` 布局镜像真机钉死，`test_db_pg_listen` 11组 `heaptrc 0`。

### 2.19 Redis SUBSCRIBE 订阅会话（V3-B8，nextpas.core.db.redis.subscribe）

> **分册索引**：本节已并入 `redis.md` 单源（`CONTRACT §2.19` 与 `§2.13` 同册，见 `redis.md §3`），本册仅保留分治不变量与单点变更隔离声明。

`redis` 原生 `pub/sub` 一等公民化（B8），骨架自 `pg.listen`（`CONTRACT §2.18`）直接泛化：专用连接独占的订阅会话 + 单工泵线程 + 有界记录队列（`RESP2` 订阅态独占，`PUBLISH` 经 `adapter` 另路）。完整语义（确认帧簿记、`at-most-once` 诚实、`IO deadline` 停泵上界、`16MB` 帧护栏）见 `redis.md` 单源，门禁 `test_db_redis_subscribe` 十组 `heaptrc 0`。

### 2.20 SQL 词法扫描共享引擎（V3-C6，`nextpas.core.text.sqlscan` L1 单源）

五份状态机已收敛 `nextpas.core.text.sqlscan`（`db.sqlscan` 已删，五消费方直连 L1，`text.builder` 单遍零分配，黄金语料 30 案例零漂移）。**方言**记录化四布尔 `SQLSCAN_PG/MYSQL/ODBC` 单源；**四面** `TranslateQuestion/RenderDollar/MaxIndex/Decorate` 共享单遍引擎；**边界** dollar-quote 不识、`#` 仅 `#10` 终、无溢出防护等历史保留；**性能**单遍+`StringBuilder`，`dollar` 零槽数组。门禁 `test_db_sqlscan` 12组 `heaptrc 0`，回归七门全绿。

### 2.21 达梦 DM8 DPI 原生后端（V3-D1，第六后端 `dbkDm`，契约薄纲）

> **薄索引**：完整契约见 `perf.md`/`nightly-live.md`/`benchmarks.md:40` 单源（阈值以 `nextpas.core.db.perf DB_PERF_J1_THRESHOLD=1.15 honest not J1/DB_PERF_DM_SYNTHETIC_*` 为代码单源，`DbPerfHasSilentGapIfNoNightly` 单源判定，三级闸门见 `nightly-live.md`）。

`nextpas.core.db.dm.*` 五单元（`base/ffi/loader/adapter` + `adapter.synthetic`，`libdmdpi.so`）为第六后端；`ConnectDm`/`?→$N`/`dpi_*` 同上，能力见 §2.10。**J1≤1.15× 仅 `NEXTPAS_DM_TEST_CONN` 真机可量化，CI 合成仅 surrounding cost honest not J1**（见 `perf.md`/`benchmarks.md:40` 单源，缺 nightly live 静默缺口已登记 `DbPerfHasSilentGapIfNoNightly` 需 `nightly-live.md` 证据闭环）。

### 2.22 Wallet 账本/核销/过期（E1 已独立，本文仅薄索引；单源 `wallet/CONTRACT.md`）

> **单源真相（薄索引零表零 DDL）**：完整不变量见 `core/docs/db/wallet/CONTRACT.md §0-§7`（Owner=wallet lane，四件套 `wallet.base←intf←impl←wallet`）；本册仅薄索引声明，零表/DDL/语义复述，防双源漂移（`nextpas.core.wallet` 已独立见 `wallet/CONTRACT.md §0`）。`db.pool`/`db.migrate` 为 L2 infra（无 L3→L3），`db.wallet`/`billing.wallet` 兼容别名已物理删除（文件已移除，不再计入 src 模块清单，可裁剪性闭环已收口），统一 `nextpas.core.wallet`；通用计费请用 `nextpas.core.billing` 独立家族。

## 3. 兼容 shim（恢复为最小面，2026-08-25 紧急回滚）

旧入口名 `nextpas.core.sqlite` / `nextpas.core.pg` 曾在 G2 全量删除；
因并行存量项目仍 uses 旧名无法编译，同日恢复**两个薄 re-export shim**
（转发到 db.sqlite / db.pg 门面现存公开面），迁移窗口重开——存量项目
零改动即可编译，新代码一律 uses nextpas.core.db 家族。G2 删除的
`.base/.conn/.tx/.pool/.migrate/.loader` 子单元名不恢复：
v1 TSqlitePool 与后端专用 migrate 面已退役，无处可指。原删除记录：

- **前置核查**：全仓扫描确认仓内消费方全部切至 `nextpas.core.db.*`
  （家族门面 `db.sqlite`/`db.pg` 自身的穿 shim 委托一并改为直连
  实现单元）；并行 lane 无活跃工作引用旧名（warning-hygiene 的命中
  经核实为陈旧基线文件、未做本地改动，收敛时自动继承新名）。
- **ffi 无过渡期**：`nextpas.core.db.sqlite.ffi` / `nextpas.core.db.pg.ffi`
  从未有过 shim——cdecl external 函数与 dlsym 变量无法用类型别名忠实
  转出口；直连 FFI 的代码从一开始就必须用新单元名。
- **外部消费方**：若仓外代码仍引用旧名，迁移即改单元名——两代单元
  的公开 API 面完全一致（shim 时代保证），无行为差异。
- 设计记录：`core/docs/plans/2026-08-23-db-module-boundary.md`。

## 4. 消费方路由

| 需求 | 用哪个 |
|---|---|
| 可移植存储访问（推荐默认） | `nextpas.core.db` 门面 |
| 连接池（读池 + 单写者，跨后端） | `nextpas.core.db.pool`（G2 起 v1 `TSqlitePool` 已退役） |
| savepoint 式精细事务控制 | `nextpas.core.db.sqlite.tx`（sqlite 专属） |
| libpq 原生能力（$N 原生语法等） | `nextpas.core.db.pg` 门面 |

## 5. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_unified   # 统一层全 API 面 + heaptrc
make focused FOCUS=core/tests/nextpas.core.db/test_db_sqlite    # sqlite 后端
make focused FOCUS=core/tests/nextpas.core.db/test_db_facade_source_contract  # L3 门面 inline 薄转发 vs 循环/SIMD 体外联纪律（design-conventions.md:129 红线2）+ 零硬链可裁剪 + bytes.ops 单源
# 完整 30 gate 分治单源：29 gate 以 core/tests/nextpas.core.db/* 为单源（tx/pool/migrate/pg/mysql/odbc/redis/dm + facade-source-contract，工厂可裁剪零耦合已闭环）+ 1 gate wallet 业务以 core/tests/nextpas.core.wallet/* 为单源（identity 前置依赖随 wallet 分治，见 wallet/CONTRACT.md），db 族零拖业务域
# 例：test_db_conformance / test_db_factory 详见 db 目录；wallet 门禁详见 wallet 目录（core/tests/nextpas.core.wallet/test_wallet）；每个含 heaptrc 0；facade 纪律门禁见 core/tests/nextpas.core.db/test_db_facade_source_contract/check_db_facade_source_contract.sh
```

每个 gate 含 heaptrc `0 unfreed memory blocks` 硬门禁。test_db_pg 需要
本地 PostgreSQL（`ensure-db` 自动建测试库；可用 `NEXTPAS_PG_TEST_CONN`
覆盖连接串）。test_db_mysql / test_db_mysql_adapter（V3-A1/A2）主体
离线可跑：loader/负连接/ABI 尺寸钉死/归一表/DSN/槽位计划/编组字节级
不依赖服务器；真机 roundtrip 冒烟经 `NEXTPAS_MYSQL_TEST_CONN`
（mysql DSN 形态）门控，缺席自动 Skip。test_db_odbc_base /
test_db_odbc_adapter（V3-A3/A4）在仅有驱动管理器（unixODBC）而无任何
驱动的环境即可全绿——负连接走管理器 IM002 真实诊断链路；真库往返
经 `NEXTPAS_ODBC_TEST_CONN`（ODBC connstr）门控。

## 6. 设计文档与分册索引

- **分册索引**：`[pool.md](pool.md)`（`§2.7` 连接池单源）、`[trace.md](trace.md)`（`§2.12` 观测钩子单源）、`[redis.md](redis.md)`（`§2.13`/`§2.19` Redis 单源，`recv`+`pipeline` 体积分治 + `bytes.ops` 单源零拷贝）、`[batch.md](batch.md)`（`§2.9`/`§2.16` 批量/流单源，`inline` 薄转发 + `bytes.ops` 单源零拷贝）、`[perf.md](perf.md)`（`§2.21` 性能阈值单源，`DB_PERF_J1_THRESHOLD` honest not J1）、`[migrate.md](migrate.md)`（`§2.4` 迁移单源）、`[nightly-live.md](nightly-live.md)`（`§2.21` nightly live 强制闭环单源，三级闸门调度/门禁/证据）
- 模块入口与特性矩阵：[README.md](README.md)
- v2 架构基线（设计决策/对标/缺口账本）：
  `core/docs/plans/2026-08-23-db-v2-architecture.md`
- Go/Rust 对标增量（INC 清单）：`core/docs/plans/2026-08-23-db-v2-increment-go-rust.md`
- **V3 工业级路线图**（后端扩张/架构收口/性能工业化三主线，S9+ 排期）：
  `core/docs/plans/2026-08-23-db-v3-industrial-roadmap.md`
- 两阶段收编决策：`core/docs/plans/2026-08-23-db-module-boundary.md`
- V3-C6 词法扫描共享引擎：`core/docs/plans/2026-08-26-db-v3-c6-sqlscan-extract-plan.md`（五份状态机→单一 `db.sqlscan`，黄金语料零漂移）
- V3-C8 RTL 收敛 sweep：`core/docs/plans/2026-08-28-db-v3-c8-rtl-convergence-proposal.md`（家族 39 单元 12→0 `uses SysUtils`，`text.conv/text.format/base.utils/time/errors` 全量替换，零反哺新增，四切片独立 landing 全绿 heaptrc 0）

## 7. 词汇表收口（V3-C8，2026-08-28）

家族 39 单元 `uses SysUtils` 12→0（`grep -l "^\s*SysUtils"` 0，注释 3 行豁免），实现词汇表收口：

| FPC `SysUtils` | `nextpas.core` 对应 | 备注 |
|---|---|---|
| `IntToStr/IntToHex/Trim/LowerCase/StrToIntDef` | `nextpas.core.text.conv` | `Format` 仅 `%s/%d/%%` 走 `text.format.TextFormat` |
| `FreeAndNil/Supports` | `nextpas.core.base.utils` | 同实现逐字节一致 |
| `GetTickCount64` | `nextpas.core.time` | 单调源 `platform_monotonic_ns` |
| `Exception` | `nextpas.core.errors` | FPC 下同类型别名，ABI 零变化 |
| `string(AnsiString(PAnsiChar))` | `nextpas.core.text.conv.AnsiPtrToStr` | PAnsiChar 读回统一入口，规避托管记录数组内强转破坏 |

C8.5 扫尾（2026-08-28）：`string(AnsiString` 家族全量清零（`pg.conn/pg.adapter/pg.listen/sqlite.conn/sqlite.adapter/pg.loader/mysql.loader` 共 15 处 → `AnsiPtrToStr`，唯一剩余为 `odbc.loader` 注释内示例），`grep -rn "string(AnsiString" core/src/nextpas.core.db*.pas` 仅注释豁免。

* text.kv 共享词法内核（2026-08-28）：`nextpas.core.text.kv` L0 纯函数 `ParseKV/ScanKV/ValidateKV`（单遍 `O(n)`，零 `TextBuilder`/`ValidateKV` 零分配）。MySQL/PG/ODBC/redis/factory 均已零分配化，口径与零分配门以 `benchmarks.md §bench_text_kv` 为单源（`core/src/nextpas.core.db.*` 家族零分配不变量详该表）；DM 等同形态零新增词法；离线 `test_text_kv` 17 组自证，`bench_text_kv` 在册见 `benchmarks.md`。
