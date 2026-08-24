# nextpas.core.db 代码契约（家族）

**模块路径**：`core/src/nextpas.core.db*.pas`
**层级**：L3 家族（依赖 L0-L2；SQLite/PostgreSQL 后端实现为 L2 子模块）
**Owner**：core-db lane
**最后更新**：2026-08-23
**版本**：1.0

---

## 1. 家族布局

| 单元 | 层 | 职责 |
|------|----|------|
| `nextpas.core.db.base` | L0 依赖根 | TDbKind / TDbColumnType / EDbError / EDbNotSupported |
| `nextpas.core.db.intf` | 接口 | IDbConnection / IDbQuery / IDbTxControl |
| `nextpas.core.db.sqlite.*` | L2 后端 | SQLite 实现：base/ffi/conn/pool/tx/migrate + 门面 |
| `nextpas.core.db.pg.*` | L2 后端 | PostgreSQL 实现：base/ffi/loader/conn + 门面 |
| `nextpas.core.db.sqlite.adapter` | 适配 | IDbConnection/IDbQuery 的 SQLite 包装（ConnectSqlite） |
| `nextpas.core.db.pg.adapter` | 适配 | 同上 PG 包装（ConnectPostgres）+ ? → $N 占位符翻译 |
| `nextpas.core.db.tx` | 泛化助手 | WithTransaction over IDbConnection |
| `nextpas.core.db.migrate` | 泛化助手 | schema 版本化 over IDbConnection |
| `nextpas.core.db.pas` | 门面 | 聚合 re-export 全部公共 API |

依赖方向严格单向：`db.base ← db.intf ← {adapter, tx, migrate, 后端} ← 门面`。
**db.base 与 db.intf 禁止 uses 任何具体后端单元。**

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
  mysql DSN 形态：空格分隔 key=value（host/port/user/password/db/socket，
  值可用引号包裹），socket 存在时优先于 host。
- **线程亲和性**：一个 IDbConnection 同时只能被一个逻辑线程使用
  （Exec/Query/Step 无并发防护，互斥锁只保护事务簿记）；跨线程并发
  访问经 db.pool 分发（每线程独占 Acquire 的连接）。IDbQuery 生命周期
  不得超出其创建所在连接的使用周期。
- **Changes 统一为 Int64**。
- **Blob**：接口含 BindBlob/GetBlob。pg 侧经 hex 文本 + `::bytea` cast 实现，
  真机门禁覆盖；sqlite 侧原生透传。

### 2.2 错误模型——双码位并存

适配器把后端异常转译为 `EDbError`：

| 字段 | sqlite 引发时 | postgres 引发时 |
|---|---|---|
| Backend | dbkSqlite | dbkPostgres |
| BackendCode / ExtendedCode | 原生结果码 / extended 码 | 0 |
| SqlState / Severity / Detail | 空串 | libpq 诊断字段 |
| Message | 原始消息 | 原始消息 |

**v2 起语义归一经 `db.err` 受控映射**：Category/Constraint 枚举由
ClassifySqlite/ClassifyPg 纯函数表产出（宁可欠归一不错归一），原始码位
字段永远并存。非后端异常原样穿透。

### 2.3 事务（IDbTxControl + db.tx + IDbSavepointControl）

两个入口，分工明确（V2-S2 savepoint 混合模型）：

| 入口 | 模型 | 语义 |
|---|---|---|
| `WithTransaction(Conn, Proc)` | 自动 savepoint 混合 | 深度 1 = 真 BEGIN/COMMIT/ROLLBACK；深度 ≥2 = `SAVEPOINT np_db_sp_<N>`，成功 RELEASE 并入父事务，失败 ROLLBACK TO **真正只撤销内层写入**后 RELEASE——外层捕获异常可继续（部分提交语义）。 |
| 手动 `BeginTxn/CommitTxn/RollbackTxn` | v1 计数（精细控制面） | Begin 加深、内层 Commit 只降计数、**任意深度 Rollback 回滚整个事务并清簿记**（pg 侧 V2-S2 起对齐 sqlite：此前深度 >1 只降簿记不真回滚）。 |

- 嵌套的 `WithTransaction` 要求连接实现 `IDbSavepointControl`（两内置
  后端都实现）；无该能力时 fail-fast 抛错，绝不静默退化为计数并入。
- `TxDepth` = 真实 SQL 事务深度；savepoint 层不计入。手动嵌套计数语义
  保持 v1 不变。
- 外层回滚撤销一切（含已 RELEASE 的内层）；savepoint 名格式固定
  （`np_db_sp_<层级>`），兄弟层级顺序复用安全。
- 手动 savepoint 面不变：`IDbSavepointControl.Savepoint/RollbackTo/
  ReleaseTo`，命名 `[A-Za-z0-9_]+`，违规抛 EDbError。
- **瞬时错误重试（V3-B5）**：`WithTransactionRetry(Conn, Proc[,
  Policy])`——仅整事务重跑，绝不部分重试；**幂等责任在回调**（同一
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
天然以文本形态返回（length-prefixed），GetText/GetDouble 直读。

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

`TDbPool` 对任意后端 `IDbConnection` 池化，后端特化经连接工厂闭包注入，
池体不懂方言：

- **释放即归还**：Acquire/Writer 返回代理接口，消费方释放引用（出作用
  域或置 nil）即自动归还，零手工 Free。代理经 QueryInterface 透传底层
  连接全部能力面（IDbTxControl/IDbBatchExecutor 等），探测语义与直连
  一致。
- **坏连接弃置**：捕获数据库错误后经 `IDbPooledHandle.Discard` 弃置当前
  连接，释放引用时不回池而直接关闭，防坏连接复用。
- **生命周期安全**：持有租约时 Free 池合法——门面 Free 只停止出借并
  清空空闲队列；在途租约归还时直接销毁底层连接（排空语义，不等待，
  对齐 Go `DB.Close`），最后一个租约释放后池核心态自毁。Close 后
  Acquire/Writer 抛 EDbError。
- **策略**：TDbPoolPolicy 九字段（MaxReadConnections/AcquireTimeoutMs/
  ValidateOnAcquire/MaxLifetimeSec/IdleTimeoutSec/MinConnections +
  V3-C3 三招 LeakDetectionThresholdMs/OnLeakDetected/DebugAcquireStack）。
  空闲回收无看门狗线程（Acquire 检查点惰性执行）；预热 fail-fast
  （Create 内建满 MinConnections，失败原样上抛建连错误）。
- **泄漏检测（V3-C3，默认关）**：`LeakDetectionThresholdMs > 0` 时，
  持有超阈值的在途租约在任意检查点（Acquire/Writer 入口、归还路径）
  被扫描入账（Warned 一次，检测不干预所有权——租约仍归持有者）。
  报告只在安全点冲刷：Acquire/Writer 入口自动冲刷积压，或显式
  `TDbPool.FlushDiagnostics` 排空。归还路径发生在代理析构链内，
  只入账不触发用户代码——回调永不在析构链内执行（硬边界）。报告
  经 `OnLeakDetected` 回调（nil 则写 StdErr）；回调在池调用线程同步
  执行且不得重入本池。诚实模型：发现依赖下一次池活动或显式冲刷，
  无看门狗线程。`DebugAcquireStack` 开启时报告附 ≤16 帧原始地址行
  （BackTraceStrFunc 格式化，符号解析取决于链接信息），默认关零成本。
- **单写者**：Writer 全池唯一专用槽位；占用期再取按 AcquireTimeoutMs
  排队或抛错。写连接身份恒定（寿命到期才重建）。
- **线程模型**：池方法线程安全（簿记互斥 + 槽位信号量）；单条底层连接
  同一时刻仍只服务一个逻辑线程（§2.1），池化不改变该契约。

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

### 2.9 大对象流（INC-8）

统一流面 `IDbBlobStream`（Read/Write/Seek/Size，接口释放即关闭），
开启能力按存储模型分面，消费方经 QueryInterface 探测：

- **sqlite（IDbRowBlobControl）**：`OpenRowBlob(table, column, rowid,
  readwrite)` 打开既有行的 blob 单元。定长模型——Size 即单元字节数，
  写越过末尾抛错（占位经 `zeroblob(N)` 预留）；行更新/schema 变更使
  句柄失效，须重新 OpenRowBlob。单句柄操作上限 2GB（原生 API 契约）。
- **pg（IDbLargeObjectControl）**：OID 模型。事务耦合不对称且强制：
  CreateLO/OpenLO 要求活动事务（描述符事务末失效），UnlinkLO 反向
  要求**事务外**调用（libpq 自管 BEGIN/END）；两向 fail-fast。
  消费方以 WithTransaction 包裹读写、事务外删除。
- **内存判据**：流式路径 RSS 恒定（128MB blob 实测增量 0.2MB）；
  GetBlob 全量物化保留为小 blob 便捷路径（大 blob 有线性内存税）。

### 2.10 能力矩阵（V3-B1）

`IDbCapabilities` 是可选能力接口：经门面 `DbCapabilities(Conn)` 统一
探测，连接实现则返回之，否则 nil（无值用 nil 表达）。它只描述统一层
契约内的能力面；**布尔声明与对应可选接口的 QueryInterface 存在性互证**
（conformance 钉死，防声明漂移）：

| 能力项 | sqlite | PostgreSQL | MySQL/MariaDB | ODBC 网关 | 契约注记 |
|---|---|---|---|---|---|
| SupportsSavepoints | ✅ | ✅ | ✅ | ❌ ISO CLI 无发现机制 | ⇔ IDbSavepointControl |
| SupportsBatchExecutor | ✅ | ✅ | ✅ | ✅ 逐条+单事务 | ⇔ IDbBatchExecutor |
| SupportsStmtCacheControl | ✅ | ✅ | ❌（C 线排期） | ❌（C 线排期） | ⇔ IDbStmtCacheControl |
| SupportsLargeObjects | ❌ | ✅ | ❌ | ❌ 无跨驱动 LO 语义 | ⇔ IDbLargeObjectControl；sqlite 行内模型走 IDbRowBlobControl |
| SupportsNativeBool | ❌ 声明亲和 | ✅ OID16 | ❌ TINYINT(1) 约定 | ❌ 异构网关欠归一 | INC-6 |
| SupportsMultiStatementExec | ✅ | ✅ | ✅ 连接期请求位 | ❌ 分号批因驱动而异 | mysql 需 CLIENT_MULTI_STATEMENTS，工厂默认携带 |
| SupportsStatementTimeout | ❌ 诚实不支持 | ✅ 会话级 | 建连期探测定格 | ✅ QUERY_TIMEOUT 逐语句 | INC-7；mysql 仅 Oracle 库且 server ≥8.0；odbc 秒粒度向上取整 |
| CaseSensitiveIdentifiers | ✅ 保留形式 | ❌ 折叠小写 | ❌ 列名不敏感 | 探测 IC_SENSITIVE，失败保守 False | §2.6 差异的运行时化 |
| MaxPlaceholders | 999 保守下界 | 65535 协议上限 | 65535 uint16 | 999 保守下界 | libsqlite3 ≥3.32 实际更高；ISO CLI 无参数上限 InfoType |
| ProductName / Version / Kind | 'SQLite' | 'PostgreSQL' | 按 flavor 'MySQL'/'MariaDB' | GetInfo(DBMS_NAME/VER) 原文 | 版本串原文透出，诊断展示用 |

边界：能力矩阵**不覆盖 SQL 方言差异**——DDL 类型名、约束子码细分
（PK 归并）、错误定位深度、NULL 排序等仍是 §2.6 的文档域。两套机制
职责不同：能力矩阵回答"这个连接支持什么统一面"，§2.6 回答"跨后端
SQL 与错误语义怎么写才可移植"。

### 2.11 ODBC 网关（V3-A3/A4）

`nextpas.core.db.odbc.*` 是第四统一后端：ISO CLI 之上的网关适配器，
任何提供 ODBC 驱动的数据库均可接入——这也是国产库（达梦/openGauss/
KingbaseES 等）的 D4 备选接入路径。契约要点：

- **DSN 原文透传**：connstr（`DSN=name;UID=...;PWD=...` 或 DSN-less
  `Driver=...;Server=...`）原样交给 SQLDriverConnect，本层不解析不
  改写；空串 fail-fast。BusyTimeoutMs 映射 SQL_ATTR_LOGIN_TIMEOUT
  （建连窗口，秒粒度向上取整；个别驱动不认则容忍，诚实表见 db.base）。
- **执行模型**：SQLPrepare/SQLBindParameter/SQLExecute（服务端
  prepared，参数化即注入安全）；结果 SQLFetch + SQLGetData 惰性
  物化。整数族/BIT 以 SQL_C_SBIGINT 直取，浮点/DECIMAL/日期族以
  文本形态取（精度无损），二进制族 BINARY。截断（01004）按指示符
  扩缓冲同列整值重取——主流管理器/驱动的整值替换语义由 live 门禁
  长文本往返钉死，指示符不自洽 fail-fast 不静默产错。
- **参数缓冲所有权**：ODBC 绑定延迟求值（Execute 时才读缓冲），
  参数值必须先编组进对象字段托管的稳定缓冲，禁止表达式临时地址。
- **错误归一**：ClassifyOdbc 只消费 5 字符 SqlState——管理器族精确
  码（IM002→decConnection、IM001/HYC00→decNotSupported、HY001/
  HY013→decCapacity、HYT00/HYT01/HY008→decTimeout）+ ISO 类前缀
  兜底（08 连接/23 完整性/25,40 事务/28 授权/42 语法/0A 不支持/
  53,54 容量/58 系统错误）；NativeError 跨驱动无可移植语义，只透传
  BackendCode 不参与分类（宁可欠归一不错归一）。已知缺口：MySQL 系
  驱动把约束违约报 HY000+1062 → decUnknown，登记 D 线 flavor 感知
  细化。
- **事务控制面**：Begin = AUTOCOMMIT OFF，Commit/Rollback =
  SQLEndTran + 恢复 AUTOCOMMIT ON（先恢复状态再上抛，防连接卡死在
  手动提交）；TXN_CAPABLE=SQL_TC_NONE 的驱动 BeginTxn fail-fast
  （decNotSupported）。AImmediate 无 ISO 对应语义，接受为 no-op。
- **能力降级矩阵**：见 §2.10 表 ODBC 列与 adapter 单元头注（同文）。
  Savepoints 因 ISO CLI 无发现机制整体降级且不实现
  IDbSavepointControl（互证契约一致）。
- **占位符**：? 与统一契约同形直通；?N 槽位计划与 pg/mysql 同构
  （Seq 只对裸 ? 递增）。重复逻辑号（如 `?, ?1`）的执行层复用三后端
  一致不支持：服务端参数计数 = 占位符数，未绑定物理槽一律 fail-fast。

### 2.12 观测钩子（V3-B3）

`IDbTraceListener` 是连接级同步回调面（生命周期 + 执行事件），经可选
能力接口 `IDbTraceControl` 挂载；门面 `DbTraceControl(Conn)` 统一探测，
未实现返回 nil（无值用 nil 表达）。语义契约：

- **挂载即补发**：OnAcquire 在 SetListener 非 nil 时同步发出一次，
  语义 = "本连接已建立"——建连先于挂载的常驻场景（池内层连接等）
  由此可观测；OnRelease = 连接关闭（析构内）。同一监听器的一次挂载
  对应恰好一次 OnRelease。池化租约借还不在本面——池侧观测走
  db.pool 既有诊断（C3）。
- **执行窗口**：OnQuery(DurationMs, Summary) = 成功执行一次。Exec 计
  全程（查询级选项版的 SET/恢复机制开销不计入）；查询计"首个 Step
  全程"（绑定编组 + 服务端执行 + 首行——惰性执行模型的统一执行
  窗口，无结果集执行也是成功执行），同周期后续 Step 不再发，Reset
  后重新武装。
- **失败路径**：OnError(Category, Summary) 于执行路径抛 EDbError 时
  发出，此时不发 OnQuery；Category 直透 EDbError.Category 归一枚举。
  绑定索引/未绑定参数等编程错误不产生事件（fail-fast 先于观测窗口）。
- **摘要**：Summary 折叠连续空白为单空格并截断到
  DB_TRACE_SQL_SUMMARY_MAX（512，防日志爆炸）；占位符原文保留，参数
  值从不进入摘要（注入安全）。
- **成本模型**：默认零成本——无监听器时不取时钟、不做摘要、不发
  事件。回调在调用线程同步执行（诚实模型，无后台线程）；实现不得
  重入本连接。枢纽内部锁范围内绝不触碰用户代码（C3 硬边界推广：
  锁内快照接口引用，锁外回调）。

四后端接线形态：sqlite/pg/mysql 逐路径插桩（Exec 两重载各单点、
查询对象首 Step；pg 的 B2 超时恢复钩与追踪互不影响），odbc 收敛于
DoExec/DoQuery 单点天然无双发。门禁 `test_db_trace`：离线 sqlite
全量契约 + 摘要纯函数 + pg 真机段（decSyntax 直透、占位符保真、
opts 超时路径）+ mysql/odbc live 探针（各自 env 门控）。

## 3. 兼容 shim（已删除，G2 收口）

旧单元名 `nextpas.core.sqlite{,.base,.conn,.pool,.tx,.migrate}` 与
`nextpas.core.pg{,.base,.loader,.conn}` 曾以纯 re-export shim 过渡
（G2 窗口）。2026-08-25 治理 slice 已将其删除：

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
make focused FOCUS=core/tests/nextpas.core.db/test_db_tx        # sqlite 事务助手（低层，v1 计数语义）
make focused FOCUS=core/tests/nextpas.core.db/test_db_tx_v2     # 统一层 savepoint 混合模型（V2-S2）
make focused FOCUS=core/tests/nextpas.core.db/test_db_retry     # 瞬时错误重试助手（V3-B5）
make focused FOCUS=core/tests/nextpas.core.db/test_db_pool_v2   # db.pool 通用池（INC-1；v1 TSqlitePool 已随 G2 退役）
make focused FOCUS=core/tests/nextpas.core.db/test_db_migrate_v2  # 迁移完整性：checksum + dry-run（真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_pg        # pg 后端（真机，需本地 PG）
make focused FOCUS=core/tests/nextpas.core.db/test_db_v2        # 统一层 v2 门面（真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_conformance  # 跨后端一致性契约（真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_stmt_cache   # 透明语句缓存（INC-3，sqlite）
make focused FOCUS=core/tests/nextpas.core.db/test_db_largeobject # 大对象流（INC-8，真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_mysql      # MySQL 基础三件套 loader 门禁（V3-A1，离线可跑）
make focused FOCUS=core/tests/nextpas.core.db/test_db_mysql_adapter  # MySQL 适配器（V3-A2，六组离线 + 真机组 env 门控）
make focused FOCUS=core/tests/nextpas.core.db/test_db_odbc_base  # ODBC base/ffi/loader（V3-A3，仅驱动管理器即可全绿；live 段 NEXTPAS_ODBC_TEST_CONN 门控）
make focused FOCUS=core/tests/nextpas.core.db/test_db_odbc_adapter  # ODBC 适配器（V3-A4，五组离线全绿；live 段 NEXTPAS_ODBC_TEST_CONN 门控）
make focused FOCUS=core/tests/nextpas.core.db/test_db_trace      # 观测钩子（V3-B3，sqlite 全量离线 + pg 真机段 + mysql/odbc live 探针）
make focused FOCUS=core/tests/nextpas.core.http.middleware/test_session_sqlite  # 消费方回归
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

## 6. 设计文档

- 模块入口与特性矩阵：[README.md](README.md)
- v2 架构基线（设计决策/对标/缺口账本）：
  `core/docs/plans/2026-08-23-db-v2-architecture.md`
- Go/Rust 对标增量（INC 清单）：`core/docs/plans/2026-08-23-db-v2-increment-go-rust.md`
- **V3 工业级路线图**（后端扩张/架构收口/性能工业化三主线，S9+ 排期）：
  `core/docs/plans/2026-08-23-db-v3-industrial-roadmap.md`
- 两阶段收编决策：`core/docs/plans/2026-08-23-db-module-boundary.md`
