# nextpas.core.db 代码契约（家族）

**模块路径**：`core/src/nextpas.core.db*.pas`
**层级**：L3 家族（依赖 L0-L2；SQLite/PostgreSQL 后端实现为 L2 子模块）
**Owner**：core-db lane
**最后更新**：2026-09-01（V4.3 BulkCopy 5× 单源详 §2.22；ROADMAP 20260828 R1-R5 冻结）
**版本**：4.3（自 1.0 起累计：A5 redis+统一工厂、B1 能力矩阵、B2 查询级超时、B3 观测钩子、C1 语句缓存、C2 数组绑定、C5 调优预设、B6 异步挂载、B7 LISTEN/NOTIFY、B8 Redis SUBSCRIBE、C6 SQL词法共享引擎、DM DPI 原生第六后端；V4.3 BulkCopy 5/6 universal 单事务批量详 §2.22）

---

## 1. 家族布局

> 家族 39 单元 `uses SysUtils` 12→0（见 §7），6 后端对齐（sqlite/pg/mysql/odbc/redis/dm），5/6 `IDbBulkCopy` universal详 §2.22。

| 单元 | 层 | 职责 |
|------|----|------|
| `nextpas.core.db.base` | L0 依赖根 | TDbKind / TDbColumnType / EDbError / EDbNotSupported / `DbBulkEscape`/`DbBulkQuoteIdent`/`DbBulkLiteralText`（单引号/标识符转义单遍，零 `SysUtils`，`text.sql` 单源） |
| `nextpas.core.db.intf` | 接口 | IDbConnection / IDbQuery / IDbTxControl / IDbSavepointControl / IDbBatchExecutor / IDbStmtCacheControl / IDbCapabilities / IDbTraceControl / IDbArrayBinding / IDbBulkCopy / IDbBlobStream/`IDbLargeObjectControl`/`IDbRowBlobControl`（大对象流能力面，含 `largeobject` 语义） |
| `nextpas.core.db.err` | 归一 | `ClassifySqlite/ClassifyPg/ClassifyMy/ClassifyOdbc/ClassifyRedis/ClassifyDm` 纯函数表 → `Category/Constraint`（宁可欠归一不错归一，原始码位并存） |
| `nextpas.core.db.trace` | 观测 | `TDbTraceHub` + `IDbTraceListener`/`IDbTraceControl` 实现（§2.12，默认零成本） |
| `nextpas.core.db.pool` | L3 池 | `TDbPool` 通用池（任意后端 `IDbConnection`，读池+单写者，策略九字段，见 §2.7） |
| `nextpas.core.db.factory` | L3 工厂 | `IDbDriver` 注册表 + `DbOpen/DbOpenPool` 统一入口（6 驱动 sqlite/pg/mysql/odbc/redis/dm 自注册，见 §2.14） |
| `nextpas.core.db.sqlscan` | L1 共享引擎 | 单遍词法扫描：`SqlScanTranslateQuestion/SqlScanRenderDollar/SqlScanMaxPlaceholderIndex/SqlScanDecorate`（pg/mysql/odbc/dm 占位符同源，依托 `text.builder`，见 §2.20） |
| `nextpas.core.db.capprobe` | L0 探针 | `ParseServerVersion` + `ProbeNativeVector/ProbeJsonPath/ProbeRangeTypes/ProbeBulkCopy`（`ServerVersion 0→false` honest，`PG≥140000` 仅 `COPY BINARY` 预留，当前 5/6 bulk hard-coded `true`，见 §2.22） |
| `nextpas.core.db.bulk` | L3 家族复用件 | `TDbBulkBuffer` + `DbBulkEscape`/`DbBulkFlushChunked` 单源（5 后端共用，依托 `db.base`/`text.sql` 单源，详 §2.22） |
| `nextpas.core.db.async` | L3 异步 | `TDbAsyncExecutor` 单飞 + 令牌→`IDbCancelControl`（`PQcancel`/中断，见 §2.17，不进门面） |
| `nextpas.core.db.sqlite.*` | L2 后端 | SQLite 实现：base/ffi/conn/pool/tx + 门面 `sqlite`（7 单元，含适配） |
| `nextpas.core.db.sqlite.adapter` | 适配 | IDbConnection/IDbQuery 的 SQLite 包装（`ConnectSqlite`） |
| `nextpas.core.db.pg.*` | L2 后端 | PostgreSQL 实现：base/ffi/loader/conn/listen + 门面 `pg`（7 单元，含适配） |
| `nextpas.core.db.pg.adapter` | 适配 | 同上 PG 包装（`ConnectPostgres`）+ `? → $N` 占位符翻译 |
| `nextpas.core.db.mysql.*` | L2 后端 | MySQL/MariaDB 实现：base/ffi/loader/adapter（4 单元，Oracle 72B vs MariaDB 112B `MYSQL_BIND_*_OFF_*` 单点，见 §2.6） |
| `nextpas.core.db.odbc.*` | L2 后端 | ODBC 网关实现：base/ffi/loader/adapter（4 单元，ANSI 最小面 22 符号，见 §2.11） |
| `nextpas.core.db.redis.*` | L2 后端 | Redis RESP2 实现：base/resp/transport/adapter/subscribe + 门面 `redis`（6 单元，含 `SUBSCRIBE` 推送会话，见 §2.13/§2.19） |
| `nextpas.core.db.dm.*` | L2 后端 | 达梦 DM8 DPI 原生实现：base/ffi/loader/adapter + 门面 `dm`（5 单元，`libdmdpi.so` dlopen，见 §2.21） |
| `nextpas.core.db.tx` | 泛化助手 | `WithTransaction/WithTransactionRetry` over IDbConnection（savepoint 混合 + 段位重试，见 §2.3） |
| `nextpas.core.db.migrate` | 泛化助手 | schema 版本化 over IDbConnection（`schema_migrations` + checksum/dry-run，见 §2.4） |
| `nextpas.core.db.pas` | 门面 | 聚合 re-export 全部公共 API（6 后端 + 5/6 `IDbBulkCopy` universal详 §2.22） |

依赖方向严格单向：`db.base ← db.intf ← {err, trace, pool, factory, sqlscan, capprobe, bulk, async, tx, migrate, 后端} ← 门面`。
**db.base 与 db.intf 禁止 uses 任何具体后端单元。** 家族 `uses SysUtils` 0 行（§7 词汇表收口，`grep "^\s*SysUtils"` 0，注释豁免；`DbBulkEscape`/`TDbBulkBuffer` 单源复用，`InTransaction` 分支保留，`heaptrc 0` 门禁见 §5）。

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

#### TLS（V3-B4 成文）

责任表：TLS 建立与证书校验归各自传输栈，统一层不二次包装、不提供
跨后端证书面（诚实边界——强校验模式由消费方在 DSN/选项中显式选择）。

| 后端 | 路径 | 配置样例 | 校验责任 |
|---|---|---|---|
| postgres | libpq conninfo 原文透传（适配器零 TLS 代码） | `sslmode=verify-full sslrootcert=/etc/ca.pem host=db.example.com` | libpq 按所选模式执行；推荐 verify-full |
| redis | `ConnectRedis(addr, TDbRedisConnectOptions)` UseTls/TlsServerName（A5.1b，TLSDial 一体阻塞） | `UseTls=True; TlsServerName='db.example.com'` | nextpas.core.tls 栈标准校验；SNI 取显式名否则 Host |

> **pg 段真机实证（2026-08-26）**：本机 PG17.11 + 自签 CA（CN=localhost，
> SAN 含 127.0.0.1）临时实例。`sslmode=verify-full` 正路径经完整栈
> （adapter/listen 门禁 13+11 组全绿，heaptrc 0）；负路径错误 CA 被
> libpq 证书校验拒绝（certificate verify failed）；`sslmode=require`
> 加密通道经 pg_stat_ssl 确认 ssl=t。注意 localhost 双栈解析下
> libpq 多地址回退可能掩盖证书错误诊断——负路径验证建议显式 IP。
> redis 段 live 冒烟维持 NEXTPAS_REDIS_TEST_TLS_CONN env 门控惯例。
| odbc | connstr 原文透传，加密键随驱动 | `Encrypt=yes;TrustServerCertificate=no`（MS 驱动系） | 各 ODBC 驱动 |
| mysql | **v1 未支持**：DSN 解析器不识别 ssl 键，透传不生效——升级路径已登记（B4 余项），不假装支持 | — | — |
| sqlite | N/A（进程内库） | — | — |

诚实注记：pg 的 `sslmode=require` 只加密不验证书（libpq 语义），
生产环境应显式 verify-full + rootcert。redis TLS 负路径（不可达/
握手失败）桥接为 EDbError decConnection、ErrType='NET'（§2.13）。

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
  租约（尤其单写者槽位）被滞留过语句边界。池化连接一律用参数化形态
  `WithTransaction(Conn, procedure(const C: IDbConnection) ...)`
  （框架传实参、零捕获、语句结束即归还）；捕获形态仅限非池化/专用
  连接。`WithTransactionRetry` 同样提供参数化重载，租约在重试结束
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

> conformance 真机覆盖：sqlite 段常驻；pg / mysql / odbc / dm 真机段分别由 `NEXTPAS_PG_TEST_CONN` / `NEXTPAS_MYSQL_TEST_CONN` / `NEXTPAS_ODBC_TEST_CONN` / `NEXTPAS_DM_TEST_CONN` 门控，缺席时该段自动 Skip（离线契约段照常全绿；redis 为键值非关系模型不入本套件），见 §5 门禁。

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

`TDbPool` 对任意后端 `IDbConnection` 池化，后端特化经连接工厂闭包注入，
池体不懂方言：

- **开箱工厂（B13 配套）**：`OpenSqlitePool(Path, MaxRead)`（便利形态：
  缺省策略仅覆盖读上限，busy_timeout 烘入生产级缺省）与
  `OpenSqlitePool(Path, Policy, Options)`（全控形态：策略与连接选项
  逐字采用），组合 db.pool × sqlite 统一适配器，经 nextpas.core.db
  再导出；消费方不再各自手拼策略与连接选项。
- **租约绑定纪律（B13 续）**：FPC 接口临时量为例程级生命周期——
  `Pool.Acquire` / `Pool.Writer` 的函数结果若**直接内联传参**
  （const 形参绑定，如 `Migrate(Pool.Writer, …)`）或经**全局托管
  变量**中转，隐藏引用会把租约拖过语句边界、直至所在例程退出
  （单写者槽位期间不可再借；五格矩阵实证）。合规形态：
  租约先绑定局部变量、用毕显式置空；或直接用作用域助手
  `Pool.WithRead(…)` / `Pool.WithWriter(…)`——租约约束在实现内
  局部变量上（try..finally 归还），消费方从结构上不可能滞留。
  池化连接上的事务一律走参数化形态（§2.3）。

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
  `TDbPool.FlushDiagnostics`（= `IDbPoolCore.FlushDiagnostics` / 内部
  `FlushLeaksSafePoint`）排空。归还路径发生在代理析构链内，
  只入账不触发用户代码——回调永不在析构链内执行（硬边界）。报告
  经 `OnLeakDetected` 回调（nil 则写 StdErr）；回调在池调用线程同步
  执行且不得重入本池。诚实模型：发现依赖下一次池活动或显式冲刷，
  无看门狗线程；可达性矛盾已消除——检测无后台轮询，空闲期需显式
  `FlushDiagnostics`（FreshDiagnostics 调用点）或下次 Acquire/Writer
  才能观察到积压报告。`DebugAcquireStack` 开启时报告附 ≤16 帧原始
  地址行（BackTraceStrFunc 格式化，符号解析取决于链接信息），默认
  关零成本。
- **单写者**：Writer 全池唯一专用槽位；占用期再取按 AcquireTimeoutMs
  排队或抛错。写连接身份恒定（寿命到期才重建）。
- **线程模型**：池方法线程安全（簿记互斥 + 槽位信号量）；单条底层连接
  同一时刻仍只服务一个逻辑线程（§2.1），池化不改变该契约。

### 2.8 语句缓存（INC-3，多后端 LRU 64）

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
- **与 Bulk 字面量路径正交**：`IDbBulkCopy` 经 `DbBulkMultiInsertSql` 生成的字面量 `INSERT`（`'→''` 单遍转义，`500 行/chunk`）每次产生长度唯一的 SQL 文本，故意 bypass 本节 LRU——每个 chunk 指纹不同无法命中，缓存收益不适用于 bulk；这是预期行为非缺陷（横向对照见 §2.22 与 benchmarks.md `bench_db_bulk_copy` `0.52–0.55×` live-verified 仅 sqlite vs `bench_db_stmt_cache` `2.1–2.4×`）。

**mysql/odbc/dm 侧（V3-C1 扩展）**：同款透明 LRU 64 空闲句柄池（键 = 原始 SQL 文本，容量经 `Connect*(..., capacity)` 注入，默认 64；<=0 关闭），借出即移除、归还回插、Reset/Clear 语义与 sqlite/pg 对齐，point-query 收益同 bench_db_stmt_cache 2.1–2.4×，诚实 SupportsStmtCacheControl=True。

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
| SupportsStmtCacheControl | ✅ | ✅ | ✅ LRU 64 | ✅ LRU 64 | ⇔ IDbStmtCacheControl |
| SupportsLargeObjects | ❌ | ✅ | ❌ | ❌ 无跨驱动 LO 语义 | ⇔ IDbLargeObjectControl；sqlite 行内模型走 IDbRowBlobControl |
| SupportsNativeBool | ❌ 声明亲和 | ✅ OID16 | ❌ TINYINT(1) 约定 | ❌ 异构网关欠归一 | INC-6 |
| SupportsMultiStatementExec | ✅ | ✅ | ✅ 连接期请求位 | ❌ 分号批因驱动而异 | mysql 需 CLIENT_MULTI_STATEMENTS，工厂默认携带 |
| SupportsStatementTimeout | ❌ 诚实不支持 | ✅ 会话级 | 建连期探测定格 | ✅ QUERY_TIMEOUT 逐语句 | INC-7；mysql 仅 Oracle 库且 server ≥8.0；odbc 秒粒度向上取整 |
| CaseSensitiveIdentifiers | ✅ 保留形式 | ❌ 折叠小写 | ❌ 列名不敏感 | 探测 IC_SENSITIVE，失败保守 False | §2.6 差异的运行时化 |
| MaxPlaceholders | 999 保守下界 | 65535 协议上限 | 65535 uint16 | 999 保守下界 | libsqlite3 ≥3.32 实际更高；ISO CLI 无参数上限 InfoType |
| SupportsBulkCopy | ✅ 单事务批量 | ✅ 单事务批量 | ✅ 单事务批量 | ✅ 单事务批量 | ⇔ IDbBulkCopy；V4.3 universal详 §2.22 |
| ProductName / Version / Kind | 'SQLite' | 'PostgreSQL' | 按 flavor 'MySQL'/'MariaDB' | GetInfo(DBMS_NAME/VER) 原文 | 版本串原文透出，诊断展示用 |

边界：能力矩阵**不覆盖 SQL 方言差异**——DDL 类型名、约束子码细分
（PK 归并）、错误定位深度、NULL 排序等仍是 §2.6 的文档域。两套机制
职责不同：能力矩阵回答"这个连接支持什么统一面"，§2.6 回答"跨后端
SQL 与错误语义怎么写才可移植"。

### 2.11 ODBC 网关（V3-A3/A4）

`nextpas.core.db.odbc.*` 是第四统一后端：ISO CLI 之上的网关适配器，
任何提供 ODBC 驱动的数据库均可接入——这也是国产库（达梦/openGauss/
KingbaseES 等）的 D4 备选接入路径。契约要点：

- **DSN 原文透传 + 离线词法校验**：connstr（`DSN=name;UID=...;PWD=...` 或 DSN-less
  `Driver=...;Server=...`）原样交给 SQLDriverConnect，本层不改写；
  空串/`malformed`/`unterminated`（含 `Driver={...` 未闭合）经
  `text.kv` `ParseKV` 离线 fail-fast（`test_text_kv` 16 组 + `test_db_odbc_adapter` 4b/4c），
  未触驱动管理器即抛 `EDbError(dbkOdbc)`。BusyTimeoutMs 映射 SQL_ATTR_LOGIN_TIMEOUT
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
  53,54 容量/58 系统错误）；NativeError 跨驱动无可移植语义，默认只
  透传 BackendCode 不参与分类（宁可欠归一不错归一）。唯一例外：
  建连期经 SQL_DRIVER_NAME / SQL_DBMS_NAME 探测命中 mysql/mariadb
  词元的 MySQL 系驱动启用 ClassifyOdbcEx 码位单调提精——基础欠归一
  时采纳码位类目、同类泛约束只补细分、永不降级矛盾；原 HY000+1062
  → decUnknown 缺口就此收口，非 MySQL 驱动行为不变。
- **事务控制面**：Begin = AUTOCOMMIT OFF，Commit/Rollback =
  SQLEndTran + 恢复 AUTOCOMMIT ON（先恢复状态再上抛，防连接卡死在
  手动提交）；TXN_CAPABLE=SQL_TC_NONE 的驱动 BeginTxn fail-fast
  （decNotSupported）。AImmediate 无 ISO 对应语义，接受为 no-op。
- **能力降级矩阵**：见 §2.10 表 ODBC 列与 adapter 单元头注（同文）。
  Savepoints 因 ISO CLI 无发现机制整体降级且不实现
  IDbSavepointControl（互证契约一致）。**达梦 DM8 备注（ADR 0002）**：
  经 `ConnectOdbc(Driver=DM8 ODBC DRIVER;…)` 的 P1 ODBC 网关为 Tier-1
  路径，`SupportsSavepoints=False` 为契约性诚实降级（嵌套
  `WithTransaction` 将 fail-fast `decNotSupported`），`SupportsBatchExecutor
  =True`（逐条+单事务、精确到步），`SupportsNativeBool=False`；约束违约等
  归一依赖驱动的 SqlState 质量（多数报 `HY000` 欠归一、`NativeError`
  仅透传，不经 `ClassifyOdbcEx` MySQL 提精——达梦自成体系码位不参与
  提精，宁可欠归一不错归一），语句超时秒粒度向上取整。P2 `libdmdpi`
  专用适配器（`dpi_*`/`ClassifyDm`/`dbkDm`）仅当触发条件满足时再议。
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

### 2.13 Redis 原生后端（V3-A5）

`nextpas.core.db.redis` 家族：RESP2 协议原生客户端（无 C 库依赖，
传输经 `nextpas.core.net` 阻塞 TCP，接口化可注入）。分层 L2→L2
同层单向依赖（design-conventions 允许）。

- **命令面**：命令文本 = 空白分词命令行；? 顺序槽 / ?N 显式槽替换
  为独立 bulk 参数——RESP 长度前缀二进制安全，注入安全由协议构造
  保证。'...' 引号包裹剥壳取内容；'?x' 非占位符语法按字面键保留。
- **回复 → 行映射**：array 每元素一行；simple/bulk/integer 一行；
  null（$-1 / *-1 / RESP3 `_`）零行；error 回复在执行点抛。
  单列，列名 'reply'，integer 回复列型 dbcInteger 其余文本。
- **执行模型**：IDbQuery 惰性执行（首个 Step 发命令）；Reset 重臂
  重发（对齐 odbc Reset 语义）；错误类目经 db.err ClassifyRedis
  （ERR→syntax、WRONGPASS/NOAUTH→auth、MOVED/ASK/CLUSTERDOWN/
  READONLY→connection、LOADING/BUSY/MASTERDOWN→capacity、
  EXECABORT→transaction、NOSCRIPT→not-supported、未识别欠归一）；
  错误首词存 SqlState 槽，RESP 无数字码位 BackendCode 恒 0。
- **事务控制面**：MULTI/EXEC/DISCARD 直映；MULTI 期间消费方收到
  +QUEUED 标记（Redis 固有语义）；CommitTxn 校验 EXEC 数组内错误
  元素后丢弃载荷；EXECABORT → decTransaction；AImmediate no-op。
- **能力降级矩阵**：Savepoints/StmtCache/LargeObjects/NativeBool/
  MultiStatementExec/StatementTimeout=False 不假装；
  BatchExecutor=True（真流水线：单次写 burst + N 读，精确到步错误
  定位）；CaseSensitiveIdentifiers=True；MaxPlaceholders=999 保守
  下界。TimeoutMs advisory 忽略（§2.6b 惯例）。
- **观测钩子**：§2.12 同构接线（attach-catch-up、首执行窗口、错误
  类目透传）。
- **连接选项重载（A5.1b）**：`ConnectRedis(AAddr,
  TDbRedisConnectOptions)`——Host/Port/Password/DbIndex/
  ConnectTimeoutMs/IoTimeoutMs 之外新增 UseTls 与 TlsServerName；
  地址串解析结果与选项字段合并时选项侧非默认值优先。
- **TLS 变体**：UseTls=True 走 `nextpas.core.tls.TLSDial`（DNS+TCP+
  TLS 一体阻塞），SNI 取 TlsServerName 否则 Host；传输拨号失败
  （TCP/TLS，含证书类）统一桥接为 EDbError(dbkRedis) decConnection，
  ErrType 槽放 'NET' 标记非服务端回复。
- **INFO 版本探测（A5.1）**：真实建连默认发 INFO server 尽力取
  `redis_version`（valkey 回退 `valkey_version`），经
  IDbCapabilities.ProductVersion 暴露；探测失败保守降级为空版本、
  连接不受影响。离线门控 live env：NEXTPAS_REDIS_TEST_TLS_CONN /
  NEXTPAS_REDIS_TEST_TLS_PASSWORD。

### 2.14 统一驱动工厂与 Open 即池（V3-A5 收口）

`nextpas.core.db.factory`：Go `database/sql` 的
`sql.Register`/`sql.Open` 与 ADO.NET `DbProviderFactory` 的对位物。

- **IDbDriver**：Name（注册键，注册时归一小写）/ Kind（内建枚举
  归属；第三方适配器诚实返回 dbkUnknown，不冒充内建后端）/
  Open(Dsn, TDbConnectOptions)。
- **注册制**：内建五驱动 sqlite/postgres/mysql/odbc/redis 单元
  初始化自注册；第三方 `DbRegisterDriver` 注入即接入全套入口。
  nil/空名/重复名 fail-closed 抛 EDbError(dbkUnknown)（对齐
  sql.Register 同名 panic 防静默覆盖）。`DbRegisteredDrivers`
  返回排序快照供诊断。实现注记：参数托管传参、锁内单出口——
  规避 FPC trunk「const 接口临时实参 + 锁内提前退出」的临时值
  生命周期缺陷（该组合实测泄漏调用方临时对象）。
- **入口**：`DbOpen(name|kind, dsn[, opts])`；kind 先按内建规范名
  命中、再按注册表 Kind 声明兜底扫描；dbkUnknown 且无第三方声明
  时 EDbNotSupported fail-closed。DSN 形态沿用各后端现行约定
  （pg conninfo / mysql dsn / odbc connstr 原文透传、sqlite 路径、
  redis addr）；redis:// 富 URL 解析不进本版，细控走 ConnectRedis
  options 重载。
- **Open 即池**：`DbOpenPool(name|kind, dsn, policy)` 以 DbOpen 为
  工厂闭包构建既有 V3-C3 池 TDbPool——对齐 Go "*sql.DB 天生是池"
  核心体验；连接选项取 Default（细控场景直接 TDbPool.Create 自组
  工厂闭包）。
- **错误透传**：后端连接错误原样上抛保留各自 Backend 归属；
  pg 建连失败恒带 SQLSTATE '08000'（connection_exception）→
  decConnection。TDbConnectOptions 为 advisory 语义（§2.6b 惯例）。

### 2.15 sqlite 调优预设（V3-C5）

`ConnectSqlite(path, opts, TDbSqlitePragmas[, cacheCap])` 新重载；
类型在 `nextpas.core.db.sqlite.base`。**不带 pragmas 的旧入口行为
零变化**（全 unset = sqlite 原生缺省）。

- **词汇**：JournalMode（sjmUnset/Delete/Truncate/Persist/Memory/Wal）、
  Synchronous（sysUnset/Off/Normal/Full）、ForeignKeys 三态
  （fkUnset/Off/On——sqlite 缺省 OFF 是著名陷阱，但默认改写会惊吓
  存量语义，故显式表达）、CacheSize（0=不设置；负=KiB）、MmapSize
  （<0=不设置；0=显式禁用）。
- **安全缺省**（`TDbSqlitePragmas.Default`，文件库）：WAL +
  synchronous=NORMAL + foreign_keys=ON——仅在显式传入时生效。
- **:memory: 过滤**：journal_mode 恒跳过（WAL 对内存库无意义），
  其余 PRAGMA 照常。
- **fail-closed 回读校验**：journal_mode 应用后回读比对，不符抛
  EDbError decNotSupported——网络 FS 等场景下 sqlite 会静默保持
  原模式，静默降级 = 消费方误信读写并发安全。mmap_size 为 advisory
  （部分构建编译期禁用 SQLITE_MAX_MMAP_SIZE，设置无效不报错）。
- **工厂边界**：`DbOpen` 的内建 sqlite 驱动不烘入任何 PRAGMA
  （journal_mode=WAL 会持久化进文件头，统一入口静默改写会波及
  非本模块工具）；调优走本节直接入口。

### 2.16 参数级批量绑定（V3-C2，IDbArrayBinding）

单条参数化 SQL 的每个 `?` 绑一个**列数组**（非标量），一次执行由
服务端展开为 N 行。pg 走 unnest 数组展开路径：10K 行单次往返，
实测 pg batch_insert 四路对照中 array ≈ batch（见 benchmarks.md）。
与 IDbBatchExecutor 分工：那是"多语句往返压缩"的通用路径（任意
SQL 序列、全后端可用）；本面是"单语句参数级批量"的快路径（v1 仅
pg）。探测对象是 **IDbQuery**（门面 `DbArrayBinding(Q)`，未支持
返回 nil）；能力布尔 `SupportsArrayBinding ⇔ 接口存在性` 互证。

```pascal
Q := Conn.Query('INSERT INTO t(a, b) SELECT * FROM unnest(?::bigint[], ?::text[])');
B := DbArrayBinding(Q);
B.BeginBind(N);                 // 先声明行数，必填
B.BindInt64Column(1, Ids);
B.BindTextColumn(2, Names, Masks);   // NULL 掩码可选重载
Q.Step;                          // 单次往返完成 N 行
```

- **目标类型 cast 写在消费方 SQL 里**（`?::bigint[]` 等）：显式、
  可审计；适配器只做 `? → $N` 翻译，不改写语义。
- **fail-fast 全客户端侧**（不触网执行）：BeginBind 缺失 / 负行数 /
  任一列长度 ≠ 声明行数 / 掩码长度失配 / 同批同列重复绑定 / 文本
  元素含 NUL(#0)——文本协议在 NUL 截断，拒绝静默损坏。
- **全覆盖检查**：数组模式激活后 Step 强制所有占位符已绑定（标量
  与列绑定并集），防 unnest(NULL) 静默零行；标量+数组可混绑（常量
  列 × 展开列），标量后绑替换同位列绑定（last-wins）。
- **NULL 掩码**：True = 该行 NULL，值被忽略；空串与 NULL 可区分
  （text 元素恒加引号转义，NULL 用裸令牌）。
- **编码**：int64 十进制；bool t/f；double 经 core.text.number
  Schubfach 最短往返（区域设置无关，NaN/±Inf 原生输出）；文本双引号
  包裹 + `\`/`"` 转义。字面量形态对消费方透明。
- **执行语义与既有面正交**：Reset + Step 同批重执行；RETURNING 正常
  读回展开行；语句缓存/事务/观测钩子路径不受影响（数组参数就是普通
  文本参数）。
- **使用前置**：先探能力（`Cap.SupportsArrayBinding` 或探测 nil）
  再构建方言 SQL——sqlite 的 Query 急切 prepare，pg 方言 SQL 在
  不支持后端会于构建期抛语法错（诚实失败，但应避免）。
- **后端矩阵**：pg = True；sqlite/mysql/odbc/redis = False（诚实缺
  席，conformance 钉死互证；后续若实现须走同一契约面）。

### 2.17 异步挂载与取消（V3-B6 / INC-4，nextpas.core.db.async）

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

- **不经 db 门面**：本面是 class 直构入口（`nextpas.core.db.async`
  直接 uses），不进门面 re-export——避免把执行线程依赖传染给不用
  异步的门面消费者（默认零成本）。

- **底座零平行宇宙**：执行线程 = `nextpas.core.thread.pool` 单工池；
  运行时初始化 = `nextpas.core.thread.init`（cthreads 的正替，消费方
  程序须将其放 uses 首位）；等待/互斥 = `nextpas.core.sync`；取消 =
  `nextpas.core.async.cancellation` 子令牌级联；异常基座 =
  `nextpas.core.errors`。本单元不直接引任何 FPC RTL 单元。
- **取消链路**：消费方令牌 `Submit(Work, Token)` → 执行器创建子令牌并
  注册回调桥 → `IDbCancelControl`（可选能力，`QueryInterface` 探测，
  pg = `PQcancel`，sqlite = progress handler 中断）→ 后端中断引发的
  失败统一归一 **decTimeout**（"查询取消"语义位，pg SQLSTATE 57014 /
  sqlite SQLITE_INTERRUPT 同归一）。句柄直呼 `Cancel` 走同一取消面，
  不需要令牌。
- **时序不变式**：子令牌回调注册与取消面挂载先于工作体入队——否则
  极小工作体可能在注册完成前已跑完并释放 op 记录。取消面只在异步
  操作期间安装、finalize 即摘除：同连接的同步直调路径不受进度回调
  污染（默认零成本）。
- **状态语义**：`IsDone` = 已终态；`ErrorObj` 非 nil 即失败，对象由
  句柄持有并在句柄析构时销毁（消费方不得手动 Free）；`IsCanceled`
  = 请求过取消**且以失败收场**——仅请求但自然成功时不置位。
- **生命周期契约**：连接必须活得比执行器久；执行器析构先
  `WaitAll` 等在途调用自然收尾（诚实语义，不半途丢弃），再关停工作
  线程，不留后台线程；消费方可先行丢弃句柄（op 记录托管保活至
  finalize）。
- **单飞纪律**：上一调用未收尾前再提交抛 EDbError（"单飞模型"）。
  并发读应使用 db.pool 的多连接读池，每连接各自挂执行器。
- **性能事实与使用指引**（benchmarks.md 入册）：异步挂载每次往返的
  固定成本 ≈ 两次跨线程唤醒（实测 ~15–20µs）。操作本身耗时与此同
  量级（内存库微查询 ~2µs）时劣化显著（10×+），**不要为此类负载
  异步挂载**；适用域是长查询/阻塞场景的主线程让出与取消能力（真机
  pg 取消 50M 行聚合 ~200ms 内中断，自然完成需秒级）。

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

- **Token 生命周期**：`Token.Cancel` 经回调桥协同停泵；监听器析构
  首步即 `RemoveOnCancel` 摘链（async.cancellation V3-B7 反哺新增的
  幂等注销面）——消费方可安全持有 Token 越过监听器生命周期，此后
  取消树级联不再触达已释放对象。
- **不经 db 门面**（§2.17 同纪律）：独立单元显式 uses，避免把泵线程
  依赖传染给只用同步面的门面消费者（默认零成本）；消费方程序须将
  `nextpas.core.thread.init` 放 uses 首位。
- **底座零平行宇宙**：泵线程 = `nextpas.core.thread.pool` 单工池；
  互斥/事件 = `nextpas.core.sync`；取消 =
  `nextpas.core.async.cancellation`。本单元不直接引 FPC RTL 单元。
- **投递面与路线图偏差**：原案 "async.channel 投递"落为监听器内建有界
  **记录队列**（互斥 + 自动复位事件）——IAsyncChannel 是字节通道，
  托管串记录需手工扁平化/释放，且 db.async 已确立 thread.pool +
  core.sync 的家族线程惯例；为队列引入不运行的 TAsyncLoop 得不偿失。
  取消语义按承诺经 `IAsyncCancellationToken`：Token 属性外露可挂子
  令牌级联，Cancel 即协同停泵（桥接唤醒事件即时惊动，不等节拍）。
- **诚实语义（at-most-once，不假装 at-least-once）**：
  - 断线窗口内的通知丢失不补发，`GapCount` 如实记断线次数；
  - 自动重连（间隔 = 4×节拍；建连在 conninfo 无 connect_timeout 键时
    追加 connect_timeout=2——首连同款护栏，防坏网络把"fail-fast"
    拖成 OS 级分钟级阻塞；键判定按关键字边界匹配而非子串），成功
    后按订阅快照逐通道重放 LISTEN；重放中途失败则新连接不接管
    （FConn 保持 nil 由恢复机器统一重试），杜绝半配置连接常驻与
    Connected 读数失真；
  - 投递队列满**保旧弃新**并计 `DroppedCount`（FIFO 顺序不打断）。
- **延迟事实**：通知延迟上界 ≈ 泵节拍（默认 50ms）+ 服务端 RTT。
  无 OS poller 依赖的诚实折中；PQsocket 已绑定，event-loop 级集成
  （平台轮询器）留待有判据的需求立项。
- **所有权/线程模型**：PGconn 仅泵线程触碰（Listen/Unlisten 经命令
  队列跨线程投递）；`PQnotifies` 产物逐条 `PQfreemem`（heaptrc 0
  锁定）；`TPGnotify` 按 libpq C 布局逐字段镜像
  （relname/be_pid/extra），布局错位 = 把 PID 解引用当指针——真机
  自发自收往返门禁钉死此漂移。
- **服务端语义透传**：同事务内同频道+同载荷的 NOTIFY 服务端去重
  只投递一条（pg 文档明示）——需要逐条可达的消费方自行让载荷唯一；
  本面不伪造重复通知。
- **频道名校验**：客户端先行 `[A-Za-z0-9_]` 且长度 ≤63（pg 标识符
  NAMEDATALEN-1 上界），非法 fail-fast 不触网；未订阅频道 Unlisten
  拒绝（编程错误早暴露）。
- 门禁：test_db_pg_listen 十一组真机全绿 heaptrc 0（自发自收往返/
  无载 NOTIFY/FIFO 保序/静默超时/频道名拒绝/unlisten↔relisten/
  UNLISTEN */溢出保旧弃新/令牌取消/坏 conninfo fail-fast 干净析构/
  pg_terminate_backend 真断线→自动重连重订阅再达）。

### 2.19 Redis SUBSCRIBE 订阅会话（V3-B8，nextpas.core.db.redis.subscribe）

redis 原生 pub/sub 一等公民化（B8），骨架自 pg.listen（§2.18）直接泛化：
专用连接独占的订阅会话 + 单工泵线程 + 有界记录队列。RESP2 订阅态独占
约束（进入订阅态后仅 SUBSCRIBE/UNSUBSCRIBE/PSUBSCRIBE/PUNSUBSCRIBE/
RESET/QUIT 合法）由结构保证——本类不暴露任何普通命令面，PUBLISH 由
消费方经 db.redis 适配器另路发送。

```pascal
S := RedisOpenSubscriber(Opts);
S.Subscribe('events'); S.PSubscribe('news.*');  // 客户端校验先行，异步应用
M := S.Receive(2000);                           // 阻塞至 ≥1 条；一次带回全部积压（FIFO）
{ TDbRedisMessage: Channel / Payload / Pattern——message 帧 Pattern 为空串，
  pmessage 帧携带命中 pattern }
S.Token.Cancel;                                 // 协同停泵；Destroy 同步收尾不留后台线程
```

- **与 pg.listen 的词汇差异（有意为之）**：方法名用协议本词
  Subscribe/PSubscribe/UnsubscribeAll 而非 Listen/Unlisten 别名——提案原
  案 Listen 同形在实现期改为 redis 本词，降低跨协议误读；属性面同形
  （Token/Connected/GapCount/DroppedCount/LastError/SubscribedChannels/
  SubscribedPatterns）。不进统一接口（§2.18 同决策）：频道确认帧/pattern/
  独占强度语义差异大，等第二实证再议抽象。
- **确认帧簿记回执**：subscribe/psubscribe 确认帧吸收为簿记回执不投递；
  SubscribedChannels/Patterns 快照记已发出命令的条目；重复 Subscribe 同
  频道幂等去重不重发命令。
- **不经 db 门面**（§2.17/§2.18 同纪律）：独立单元显式 uses，
  thread.init 放 uses 首位。
- **底座零平行宇宙**：thread.pool 单工池 + core.sync 互斥/事件 +
  async.cancellation 取消桥（析构首步 RemoveOnCancel 摘链，消费方可安全
  持 Token 越过订阅器生命周期）；RESP 解析复用 db.redis.resp 的
  RespTryParse/TRespValue，零平行解析器。
- **传输工厂 DI 缝**：`TRedisTransportFactory = reference to function:
  IRedisTransport`；live 构造内部工厂 = NewNetRedisTransport +
  AUTH/SELECT 握手（坏地址/口令消费方线程 fail-fast）；注入构造（门禁
  离线回放、自定义 TLS dial）握手责任随注入方。
- **诚实语义（at-most-once，与 §2.18 同口径）**：
  - 断线窗口推送丢失不补发，GapCount 如实记断线次数；自动重连间隔 =
    4×节拍，成功后按订阅快照逐条重放；重放中途失败则新连接不接管
    （FConn 保持 nil 由恢复机器统一重试），杜绝半配置连接常驻与
    Connected 读数失真；LastError 在恢复成功时清空（成功即无错的设计
    语义，消费方勿假设其跨恢复存活）。
  - 投递队列满保旧弃新计 DroppedCount（FIFO 不打断）；默认容量 1024。
  - 服务端错误帧记 LastError 诊断但不断线（订阅态内错误非连接致命）。
- **停泵时延上界 = IO deadline 而非节拍**（与 §2.18 差异，如实登记）：
  连接在途时泵阻塞于带 deadline 的 Recv（IRedisTransport 无中断面），
  取消最迟一个 EffectiveIoTimeoutMs = max(2×节拍, 1000)ms（钳 3600000）
  内生效；空闲/退避期等事件即时惊动。PING 保活默认关
  （AKeepAliveMs=0），开启按周期发 PING 维持中间件活性。
- **协议护栏**：单帧上限 MAX_FRAME_BYTES=16MB，超限判协议错走断线重连；
  解析以精确有效长度视图喂 RespTryParse（防陈旧字节误扫成幽灵帧）。
- 门禁：test_db_redis_subscribe 十组全绿 heaptrc 0（确认簿记+幂等/
  pmessage 分派/静默超时/校验 fail-fast 不触网/溢出保旧弃新/令牌取消/
  错误帧可见不断线/断线自动重连重放再达/重放失败不接管/live 自发自收
  NEXTPAS_REDIS_TEST_CONN 门控）。吞吐基准段待 live redis 环境可用后补采
  入册（诚实缺席登记）。

### 2.20 SQL 词法扫描共享引擎（V3-C6，nextpas.core.db.sqlscan）

家族内五份复制的"字符串/标识符/注释状态机"（pg/mysql/odbc 三份占位符
翻译 + pg.conn 参数计数 + bytea 装饰）收敛为单一纯函数单元；四消费方
薄委托、公开签名零变化。**换牙零漂移由黄金语料实证**：原实现 30 案例
输出落盘 → 新引擎重放逐字节全等（含混合编号槽位 [2,1,3,2]、超 Int32
编号回绕、未终止字面量等酷刑样本）。

- **方言词法集记录化**：双引号/反引号/方括号标识符与 `#` 行注释四布尔
  （DBSQLSCAN_PG/MYSQL/ODBC 常量）；词素互斥即方言隔离——pg 方言下
  反引号是代码字符、mysql 下双引号是代码字符，与各后端历史行为一致。
- **四公开面共享单遍引擎**：`SqlScanTranslateQuestion`（'?' 保形改写 +
  物理序→逻辑号槽位计划）/`SqlScanRenderDollar`（?→$N，裸 ? 走顺序
  计数、显式 ?N 不扰动）/`SqlScanMaxPlaceholderIndex`（原始编号计数，
  零输出分配）/`SqlScanDecorate`（命中原位追加后缀如 ::bytea cast，
  源数字回显不改写）。
- **受控边界（历史行为成文保留，非缺陷）**：dollar-quote 体不识别；
  行注释仅 #10 终止（#13 归注释体）；占位符数字累加无溢出防护
  （回绕值如实入槽）；块注释起始 `/` 不落输出；mysql 方言不处理双引号
  定界（默认 SQL_MODE 语义）。
- **性能契约**：单遍扫 + StringBuilder 追加，dollar/count 路径不建槽数组
  （pg 热路径零额外分配）；J1 开销比判据沿用。
- 门禁：test_db_sqlscan 十二组离线全绿 heaptrc 0；回归七门
  （pg/mysql_adapter/odbc_adapter/array_bind/stmt_cache/unified/
  conformance）全绿。设计记录：
  core/docs/plans/2026-08-26-db-v3-c6-sqlscan-extract-plan.md。

### 2.21 达梦 DM8 DPI 原生后端（V3-DM，`nextpas.core.db.dm.*`）

第六统一后端：`libdmdpi.so` dlopen 原生（A3/A4 ODBC 网关为备选，P2 真原生为推荐）。

- **形态**：`dm.base` 码位词汇（-1007 唯一/-1048 非空/-1216 外键/-3819 检查/-1213 死锁/-1205 超时 等，见 `db.dm.base`）/ `dm.ffi` 22 必选 + 2 可选 `dpi_*` 原型 + `dm.loader` 三候选探测（`libdmdpi.so` / `libdmdpi.so.8` / `libdodbc.so`）/ `dm.adapter` 参数化 `dpi_prepare/bind_param/execute/fetch/get_data` + 原生 `SAVEPOINT`/`dpi_commit/rollback` + `BatchExecutor` 逐条+单事务。`text.kv` DSN 校验 + `db.sqlscan` 占位符同构 + `TDbTraceHub` 观测同构。
- **DSN**：`Server/Host + Port + Database/Db + UID/User + PWD/Password` 空白/分号分隔，`ValidateKV` 离线 fail-fast（`test_text_kv` + `test_db_dm_adapter` 4b/4c，空串/malformed/unterminated 均 dbkDm），`Port 1..65535`，未知键不拦截（DM 驱动原文透传，`DsnToDpiConnStr` 零改写仅 DPI 原生路径 `ConnectDm→dpi_connect` 原样透传；ODBC 网关路径 `ConnectOdbc('Driver={DM8 ODBC DRIVER};…')` 遵循 ODBC 驱动管理器语义不经该函数，见 `national-db-guide §2.4`）。
- **错误归一**：`ClassifyDm` 按负整数码位精确归一（见 `db.err`），未识别 `decUnknown`，`NativeError` 不经 `ClassifyOdbcEx`（自成体系）；`CreateFullDm` 存 `BackendCode=DM负码`。
- **能力矩阵**：`SupportsSavepoints=True` 真原生（`SAVEPOINT` 语法）/ `SupportsBatchExecutor=True` / 其余 `StmtCache/LargeObjects/NativeBool/MultiStatement/StatementTimeout=False` honest false（`SupportsArrayBinding=False` v1），`MaxPlaceholders=999` 保守下界，见 §2.10 与 adapter 头注同文。
- **事务**：`BeginTxn` 仅簿记（DPI 侧隐式开启，`dpi_commit/rollback` 驱动）；`Savepoint/RollbackTo/ReleaseTo` 直映 `SAVEPOINT` 语法，`ValidateDbSavepointName` 同族守卫；嵌套 `WithTransaction` 要求 `IDbSavepointControl`（本后端实现，满足）。
- **绑定缓冲托管**：参数化延迟求值要求稳定缓冲——`TDbDmQuery` 字段 `FParamAnsi/FIsNullInt` 托管 `PAnsiChar` 与 `PInteger` 生命周期，禁止表达式临时地址（对齐 ODBC 适配器同纪律）。
- **门禁**：`test_db_dm_adapter` 七组离线全绿 heaptrc 0（DSN 空/malformed/unterminated、归一全表、能力矩阵、工厂负路径 `decConnection`、savepoint 守卫 + live `NEXTPAS_DM_TEST_CONN` 门控）；回归 `factory 15 / sqlscan 12` 全绿。
- **工厂**：`ConnectDm(dsn[, opts])` / `DbOpen('dm', dsn)` 已自注册（`dbkDm` 尾部追加序号钉死）。

### 2.22 版本探针与未来能力预留（V3-E.1，`nextpas.core.db.capprobe` + `IDbCapabilities.ServerVersion`）

`ParseServerVersion('17.1.2'→170102, '8.0.33'→80033, '3.46.0'→34600)` 单源解析（L2 纯函数，`major*10000+minor*100+patch`，兼容 `PostgreSQL 17.1` 前缀与 `-beta` 后缀）。`ServerVersion` 0 = 未探测/网关（`odbc/redis`）honest 0；`odbc/redis` 的 `SupportsNativeVector/JsonPath/RangeTypes` 经 `capprobe.Probe*` 同源判定恒 `false`（`Probe*(0)=false` honest）；`SupportsBulkCopy` 除外详下（5/6 hard-coded `true`，`redis` honest `—`）。

探针阈值（`capprobe` 纯函数，调用方按整数判断，`HasExtension` 另参）：
- `NativeVector: PG≥150000 && HasExtension`（`pgvector` ≥0.5，需扩展已装）/ `MySQL≥80017`（`VECTOR` 类型）
- `JsonPath: PG≥120000`（`jsonb_path_query`）
- `RangeTypes: PG≥140000`（`multirange`）
- `BulkCopy (universal 单事务批量): sqlite/pg/mysql/odbc/dm true`（`BeginCopy→WriteRow→EndCopy` 单事务批量 V4.3 单源：`TDbBulkBuffer+DbBulkEscape+DbBulkFlushChunked`，`InTransaction` 分支，`builder Tail/AdvanceLen` 直写单扫零 `SysUtils`，`500 行/chunk`；`redis` honest `—`；`COPY BINARY` `PG≥140000` 为 `ProbeBulkCopy` 500k 次探针微基准未来高速路径预留、与 data bulk 正交已隔离——single-txn vs COPY BINARY 已隔离）

`IDbCapabilities` 增 `ServerVersion` + 4 新布尔（`SupportsBulkCopy` 详上段 V4.3 单源；`redis` honest `—` via `ProbeBulkCopy(0)=false`；`sqlite` 解析 `sqlite3_libversion`，`pg/mysql/dm` 解析 `ProductVersion` 并缓存，`odbc/redis` 0 honest；`ROADMAP 20260828` R1-R5 冻结，`COPY BINARY` `PG≥140000` 为 `ProbeBulkCopy` 500k 次探针微基准未来预留、与 data bulk 正交已隔离，当前 bulk 已 hard-coded `true`，`J4 ≤1.5×` `0.52–0.55×` 见 benchmarks.md（J4 live-verified 仅 sqlite 11 ms vs 21 ms 同机 N=10000，TDbBulkBuffer+DbBulkEscape+InTransaction heaptrc0 0 SysUtils；pg/mysql/odbc/dm 需 NEXTPAS_*_TEST_CONN live roundtrip 方为异构真测、CI 缺省 Skip，heterogeneity incomplete honest，offline synthetic 已移除防 false 0.52× parity））。门禁 `test_db_version_probe` 10 组 + `test_db_bulk_copy` 8 组离线（live-verified 仅 sqlite，offline synthetic 已移除，pg/mysql/odbc/dm 需 NEXTPAS_*_TEST_CONN live roundtrip，CI 缺省 Skip，heterogeneity incomplete honest）。`MySQL VECTOR` 阈值 `80017` 已实现；`IDbBulkCopy` 事务感知详 `nextpas.core.db.intf`。

> **Bulk 字面量路径与语句缓存正交**：`IDbBulkCopy.EndCopy` 经 `DbBulkMultiInsertSql` 生成的字面量 `INSERT`（`'→''` 单遍转义、`500 行/chunk`）每次产生长度唯一的 SQL 文本，故意 bypass `IDbStmtCacheControl` LRU——每个 chunk SQL 指纹不同无法命中，缓存收益不适用于 bulk；这是预期行为非缺陷。横向对照：`bench_db_stmt_cache` `2.1–2.4×` vs `bench_db_bulk_copy` `0.52–0.55×` live-verified 仅 sqlite 见 benchmarks.md（pg/mysql/odbc/dm 需 NEXTPAS_*_TEST_CONN live roundtrip，offline synthetic 已移除，single-txn vs COPY BINARY 已隔离）。

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
make focused FOCUS=core/tests/nextpas.core.db/test_db_tx        # sqlite 事务助手（低层，v1 计数语义）
make focused FOCUS=core/tests/nextpas.core.db/test_db_tx_v2     # 统一层 savepoint 混合模型（V2-S2）
make focused FOCUS=core/tests/nextpas.core.db/test_db_retry     # 瞬时错误重试助手（V3-B5）
make focused FOCUS=core/tests/nextpas.core.db/test_db_pool_v2   # db.pool 通用池（INC-1；v1 TSqlitePool 已随 G2 退役）
make focused FOCUS=core/tests/nextpas.core.db/test_db_migrate_v2  # 迁移完整性：checksum + dry-run（真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_pg        # pg 后端（真机，需本地 PG）
make focused FOCUS=core/tests/nextpas.core.db/test_db_v2        # 统一层 v2 门面（真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_conformance  # 跨后端一致性契约（sqlite 常驻 + pg/mysql/odbc/dm 真机段 env 门控，缺席 Skip；redis 非关系不入）
make focused FOCUS=core/tests/nextpas.core.db/test_db_stmt_cache   # 透明语句缓存（INC-3，sqlite）
make focused FOCUS=core/tests/nextpas.core.db/test_db_largeobject # 大对象流（INC-8，真机双后端）
make focused FOCUS=core/tests/nextpas.core.db/test_db_mysql      # MySQL 基础三件套 loader 门禁（V3-A1，离线可跑）
make focused FOCUS=core/tests/nextpas.core.db/test_db_mysql_adapter  # MySQL 适配器（V3-A2，七组离线 + 2 live env 门控，含偏移/DSN 校验自证）
make focused FOCUS=core/tests/nextpas.core.db/test_db_odbc_base  # ODBC base/ffi/loader（V3-A3，仅驱动管理器即可全绿；live 段 NEXTPAS_ODBC_TEST_CONN 门控）
make focused FOCUS=core/tests/nextpas.core.db/test_db_odbc_adapter  # ODBC 适配器（V3-A4，八组离线全绿 + 1 live env 门控：含 DSN 词法 fail-fast 2 组）
make focused FOCUS=core/tests/nextpas.core.db/test_db_trace      # 观测钩子（V3-B3，sqlite 全量离线 + pg 真机段 + mysql/odbc live 探针）
make focused FOCUS=core/tests/nextpas.core.db/test_db_redis_base    # Redis 帧级/解析/归一表（V3-A5，离线）
make focused FOCUS=core/tests/nextpas.core.db/test_db_redis_adapter  # Redis 适配器（V3-A5/A5.1b，离线全契约 + TLS 负路径 + live env 门控）
make focused FOCUS=core/tests/nextpas.core.db/test_db_factory     # 统一驱动工厂（V3-A5 收口，离线）
make focused FOCUS=core/tests/nextpas.core.db/test_db_sqlite_pragmas  # C5 调优预设（离线）
make focused FOCUS=core/tests/nextpas.core.db/test_db_array_bind  # C2 参数级批量绑定（sqlite 离线诚实契约 + pg 真机段）
make focused FOCUS=core/tests/nextpas.core.db/test_db_async      # B6 异步挂载与取消（sqlite 离线 + pg 真机 PQcancel 段）
make focused FOCUS=core/tests/nextpas.core.db/test_db_pg_listen  # B7 LISTEN/NOTIFY 订阅（真机，NEXTPAS_PG_TEST_CONN 门控）
make focused FOCUS=core/tests/nextpas.core.db/test_db_sqlscan  # C6 SQL 词法共享引擎（12组离线）
make focused FOCUS=core/tests/nextpas.core.db/test_db_redis_subscribe  # B8 Redis SUBSCRIBE（10组 V3-B8）
make focused FOCUS=core/tests/nextpas.core.db/test_db_dm_adapter  # DM DPI 适配器（V3-DM，离线归一+DSN校验；live 需 NEXTPAS_DM_TEST_CONN）
make focused FOCUS=core/tests/nextpas.core.db/test_db_version_probe  # 版本探针（V3-E.1，10组离线，ParseServerVersion + Probe* + sqlite caps详 §2.22）
make focused FOCUS=core/tests/nextpas.core.db/test_db_bulk_copy  # 批量复制（V4.3 universal详 §2.22，8组离线，live-verified 仅 sqlite 11 ms vs 21 ms，offline synthetic 已移除，pg/mysql/odbc/dm 需 NEXTPAS_*_TEST_CONN live roundtrip，CI 缺省 Skip，single-txn vs COPY BINARY 已隔离，heterogeneity incomplete honest）
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
经 `NEXTPAS_ODBC_TEST_CONN`（ODBC connstr）门控。test_db_conformance 中
sqlite 段常驻全量；pg / mysql / odbc / redis 真机段分别由
`NEXTPAS_PG_TEST_CONN` / `NEXTPAS_MYSQL_TEST_CONN` /
`NEXTPAS_ODBC_TEST_CONN` / `NEXTPAS_REDIS_TEST_CONN` 门控，缺席该段自动
Skip（离线契约段照常全绿）。

## 6. 设计文档

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
