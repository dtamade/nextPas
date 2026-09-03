# nextpas.core.db

统一数据库访问层。接口隔离的能力接口族 + 引用计数所有权 + 跨后端
一致性契约门禁。设计目标：超越 VCL/LCL 数据栈（FireDAC/SQLdb 的
能力面对比见基线文档 §12），架构对标 Go database/sql / Rust sqlx /
ADO.NET 的工业形态。

## 30 秒上手

```pascal
uses nextpas.core.db;

var Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  // Conn := ConnectPostgres('host=/var/run/postgresql dbname=myapp user=app');

  // DDL/DML 原文透传
  Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');

  // 参数化查询：一律顺序 ? 占位符（pg 侧自动翻译 $N）
  var Q := Conn.Query('INSERT INTO t (id, v) VALUES (?, ?)');
  Q.BindInt64(1, 42);
  Q.BindText(2, 'hello');
  while Q.Step do;   { 接口引用计数自动释放 }

  // 事务：嵌套安全，内层失败只撤销内层（savepoint 混合模型）
  WithTransaction(Conn, procedure
  begin
    Conn.Exec('UPDATE t SET v = ''x''');
  end);
end;
```

所有权模型：对外一律 interface（COM 引用计数），消费方不手写 Free；
连接不可跨线程并发使用，并发经 `nextpas.core.db.pool` 分发。

### 统一入口（Go sql.Open 形态，V3-A5 收口）

```pascal
uses nextpas.core.db.factory; // DbOpen 注册表零 L2 可独立构建
// uses nextpas.core.db.factory.pool; // DbOpenPool 池化需另按需 uses 桥接叶

var Conn: IDbConnection;
begin
  // 注册制驱动入口：内建六驱动 sqlite/postgres/mysql/odbc/redis/dm 自注册
  Conn := DbOpen('sqlite', ':memory:');
  Conn := DbOpen(dbkPostgres, 'host=/var/run/postgresql dbname=myapp user=app');

  // Open 即池：返回工业级连接池（Go *sql.DB 形态，需 factory.pool 桥接叶）
  var P := DbOpenPool('postgres',
    'host=/var/run/postgresql dbname=myapp user=app', TDbPoolPolicy.Default);
end.
```

第三方驱动实现 `IDbDriver` 后 `DbRegisterDriver` 注入即接入
DbOpen/DbOpenPool 全套；契约见 CONTRACT §2.14 单源。L3 门面
`nextpas.core.db` 实现段零硬链接后端适配器，未使用后端零编译期耦合；
可裁剪零耦合与 inline 薄转发正交分流，裁剪边界与显式注册以 CONTRACT
§1/§2.14 为单源（单后端裁剪直连 `nextpas.core.db.{sqlite|pg|mysql|odbc|redis|dm}.adapter`
或按需 `factory.register.*` 单后端注册单元，全量亦显式注册不依赖隐式
聚合叶；`factory` 注册表完全独立构建隔离（接口/实现均零 L2 导入 `db.pool`，`DbOpenPool` 已抽离至 `factory.pool` 桥接叶），`factory.builtin` 零逻辑聚合叶已物理删除(2026-09-02) 不再计入模块节点（零 L2/零 initialization 侧效隔离已闭环，可裁剪性债务已闭环，新代码禁止 uses），
bytes.ops 单源单 Move 零拷贝与接口引用计数自动归还见 owner，inline
薄转发与资源释放不丢由实现层承载）；业务以 CONTRACT 为准，缺能力先
反哺 owner。

## 特性矩阵（六后端对齐）

> 列：`sqlite` / `pg` / `mysql`（含 MariaDB，112B 绑定）/ `odbc`（网关，含国产库）/ `redis`（RESP2）/ `dm`（DM8 DPI 原生）。`—` = 诚实缺席（不冒充），`N/A` = 模型无关。

| 能力 | sqlite | pg | mysql | odbc | redis | dm | 契约 |
|---|---|---|---|---|---|---|---|
| 参数化查询（? 参数化即注入安全） | ✅ `?` | ✅ `?→$N` | ✅ `?N→?+槽位` | ✅ `SQLBindParameter` | ✅ `?→bulk` | ✅ `?→$N` | §2.1 / §2.21 |
| 事务（IDbTxControl 手动计数面） | ✅ | ✅ | ✅ | ✅ `AUTOCOMMIT+EndTran` | ✅ `MULTI/EXEC` | ✅ `dpi_commit` | §2.3 |
| savepoint 混合嵌套（WithTransaction 自动） | ✅ | ✅ | ✅ | —（ISO 无发现） | — | ✅ 原生 | §2.3 / §2.21 |
| 瞬时错误重试（WithTransactionRetry + 段位谓词） | ✅ | ✅ | ✅ `1205/1213` | ✅ `40001` | ✅ `EXECABORT` | ✅ `ClassifyDm` | §2.3 |
| 手动 SAVEPOINT/RollbackTo/ReleaseTo | ✅ | ✅ | ✅ `SAVEPOINT` | — | — | ✅ | §2.3 |
| 批执行 IDbBatchExecutor | ✅ | ✅ 单次往返 | ✅ `MULTI_STATEMENTS` | ✅ 逐条+事务 | ✅ 真流水线 | ✅ 逐条+事务 | §2.5* |
| 透明语句缓存 | ✅ LRU | ✅ LRU | —（排期） | — | — | ✅ LRU | INC-3 |
| 连接池（读池+单写者） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | §2.7 |
| 池泄漏检测 + 获取栈采样（默认关） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | §2.7 |
| 迁移 checksum 防篡改 + dry-run | ✅ | ✅ | ✅ | ✅ | —（键值无 DDL） | ✅ | §2.4 |
| 大对象流 | 行内区间 | `lo_*` 句柄 | — | — | — | — | §2.9 |
| 列类型 `dbcBool` / `NULL` 行级信号 | ✅ 亲和 | ✅ OID16 | ✅ `TINYINT(1)→dbcInteger` | — | ✅ `reply→dbcText` | — | §2.1 |
| 查询/锁超时（TDbConnectOptions） | `busy_timeout` | `connect/statement` | `connect_timeout` + `max_exec≥8.0` | `LOGIN_TIMEOUT` | — | — | INC-7 |
| 查询级超时（`TDbExecOptions` advisory） | — | ✅ 双路径 | ✅ `Exec` 定格 | ✅ 秒粒度 | — | — | §2.6b |
| 观测钩子（`IDbTrace` 四后端同构） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | §2.12 |
| 错误归一（`Category+Constraint`） | ✅ | ✅ +定位 | ✅ `CR_*/ER_*` | ✅ `SQLSTATE`+`OdbcEx` | ✅ 词元表 | ✅ `ClassifyDm` | §2.2 / §2.21 |
| 统一驱动工厂（`DbOpen/DbOpenPool`） | ✅ | ✅ | ✅ | ✅ | ✅ 可插拔 | ✅ | §2.14 |
| sqlite 调优预设（WAL+NORMAL+FK + 回读校验） | ✅ | — | — | — | — | — | §2.15 |
| TLS 契约成文（责任表；pg/redis 透传；mysql 诚实缺席） | N/A | ✅ `verify-full` | — 诚实缺席 v1（`CLIENT_SSL=2048` 已声明，升级经 `MYSQL_OPT_SSL_*`+`nextpas.core.tls` 反哺，不假装） | 驱动透传 | N/A（进程内） | — 诚实缺席 v1（见 §2.21 闭环） | §2.1-TLS/§2.21 |
| 参数级批量绑定（`IDbArrayBinding`） | — | ✅ `unnest` 6× | — | — | — | — | §2.16 | 探测 DbCapabilities 或 DbArrayBinding(Q) 是否为 nil 再构建 unnest 方言（见 §2.16）
| 异步挂载与取消（`TDbAsync` 单飞 + 令牌→`PQcancel`） | ✅ | ✅ | ✅ | — | — | — | §2.17 |
| LISTEN/NOTIFY 订阅（专用连接+泵线程；重连重放） | N/A | ✅ | N/A | N/A | — | — | §2.18 |
| SUBSCRIBE/PSUBSCRIBE（RESP2 推送+确认簿记） | — | — | — | — | ✅ | — | §2.19 |

上表已运行时自述化（V3-B1）：`DbCapabilities(Conn)` 返回
`IDbCapabilities`，消费方按能力探测降级而非按后端名分支；契约语义见
CONTRACT §2.10。

> 词汇表收口（V3-C8，2026-08-28）：家族 39 单元 `uses SysUtils` 12→0（仅注释豁免），`IntToStr/Trim/LowerCase/IntToHex/Format/FreeAndNil/GetTickCount64/Exception/AnsiPtrToStr` 全量收敛至 `nextpas.core.text.conv / text.format / base.utils / time / errors`，零反哺新增，见 `2026-08-28-db-v3-c8-rtl-convergence-proposal.md`。

MySQL/MariaDB（V3-A1/A2，含国产 MySQL 协议系代理）：`base` 常量词汇（含 `ER_TRUNCATED 1366 / DATA_TOO_LONG 1406` 等全量收口）/ `ffi` 双方言 ABI 镜像（Oracle 72B @68/70 vs MariaDB 112B @64/96/101，`MYSQL_BIND_*_OFF_*` 具名偏移单点复用 + 门禁 `sizeof`/`PtrUInt` 双钉死 + `initialization` 自证）/ `loader` 多 soname 探测 + `mariadb_connection` flavor 自动识别 + `libmariadb 112B` 真机双引擎（`mariadb:11.8 53306` + `mysql:8.0.46 53307` 7/7 `heaptrc 0`；`mysql_native_password` 兼容说明见 `national-db-guide §5`）/ `adapter` prepared stmt 二进制协议（`?N→?` 槽位计划、`MY_PT_*` 按声明类型绑定、截断 `fetch_column` 重取、`text.kv` 共享词法内核 `ParseKV/ScanKV` 委托 + `MYSQL_DEFAULT_HOST/PORT` 单点 + `SameText` 零分配 DSN 解析 + `port 1..65535` 校验/未知键候选提示）/ 错误归一 `CR_*/ER_*` 全表（`1062/1022→unique`、`1366/1406→constraint` 等）/ `savepoint` + `MULTI_STATEMENTS` 批执行。统一工厂 `ConnectMysql(dsn[, opts])` 已透出；`NEXTPAS_MYSQL_TEST_CONN='host=... port=53307 user=root password=... db=testdb'` 启用 live 2 组，真机全量 9 组（offline 7 + live 2，含 roundtrip/四分类/savepoint/能力自述/截断）。

ODBC（第四后端网关，`unixODBC libodbc.so.2` / `Windows odbc32`，国产库含 DM8 等，V3-A3/A4）：`base` 常量词汇 / `ffi` 22 符号最小面（仅 ANSI，规避 `SQLWCHAR` 宽度分歧）/ `loader` 多候选探测 / `adapter` `SQLDriverConnect` 原文透传 + `SQLPrepare/BindParameter/Execute` 参数化 + `SQLFetch/GetData` 惰性物化（`01004` 截断整值重取）+ `AUTOCOMMIT OFF + SQLEndTran` 计数式事务 + `ClassifyOdbc` `SQLSTATE` 归一 + `ClassifyOdbcEx` MySQL 系 `HY000+1062` 单调提精 / `GetInfo` 能力降级矩阵（`Savepoints=false` 等见 CONTRACT §2.11 + `national-db-guide §2.4/§4.5` DM8 ODBC 配方）。统一工厂 `ConnectOdbc(connstr[, opts])` 已透出；仅驱动管理器即可全绿（`IM002` 真实诊断链路），真库 `NEXTPAS_ODBC_TEST_CONN` 启用。

Redis（第五后端，`RESP2` 无 C 库依赖，经 `nextpas.core.net` 阻塞 TCP，V3-A5/A5.1b）：`RESP` 帧解析 + `?→bulk` 参数化 + `array→行` 映射 + `MULTI/EXEC` 事务直映 + `BatchExecutor` 真流水线 + `INFO` 版本探测（`redis_version→valkey_version` 回退）+ `UseTls/TlsServerName` 一体阻塞 `TLSDial` + `SUBSCRIBE/PSUBSCRIBE` 推送会话（确认簿记 + 传输工厂可注入离线回放）。`ClassifyRedis` 词元表 + `transport` 接口化。`ConnectRedis(addr[, opts])` / `RedisOpenSubscriber` 已透出；`NEXTPAS_REDIS_TEST_CONN` / `NEXTPAS_REDIS_TEST_TLS_CONN` 门控 live 15 组。

## 文档地图

| 文档 | 内容 |
|---|---|
| [CONTRACT.md](CONTRACT.md) | **契约总纲**（必读）：家族布局、逐能力契约、后端差异登记、门禁清单 |
| [sqlite-guide.md](sqlite-guide.md) | sqlite 使用指南 |
| [national-db-guide.md](national-db-guide.md) | 国产数据库兼容指南：openGauss/KingbaseES/OceanBase/TiDB/DM8 等接入路径、能力预期与上线前验证清单 |
| [sqlite.md](sqlite.md) / [pg.md](pg.md) | 后端单元参考 |
| [benchmarks.md](benchmarks.md) | **基准口径册**（C4）：逐 bench 口径/判据/最近采集；复跑方法 |
| [../plans/2026-08-23-db-v2-architecture.md](../plans/2026-08-23-db-v2-architecture.md) | v2 架构基线（设计决策、对标批评、缺口账本） |
| [../plans/2026-08-23-db-v2-increment-go-rust.md](../plans/2026-08-23-db-v2-increment-go-rust.md) | Go/Rust 对标增量（INC 清单与落地注记） |
| [../plans/2026-08-23-db-v3-industrial-roadmap.md](../plans/2026-08-23-db-v3-industrial-roadmap.md) | **V3 工业级路线图**：后端扩张/架构收口/性能工业化三主线 |
| [../plans/2026-08-25-db-industrial-parity.md](../plans/2026-08-25-db-industrial-parity.md) | Go/Rust 能力对照矩阵与剩余缺口分片（P0/P1/P2） |

## 门禁速查

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_conformance  # 跨后端一致性契约
make focused FOCUS=core/tests/nextpas.core.db/test_db_v2           # 统一层全 API 面
make focused FOCUS=core/tests/nextpas.core.db/test_db_factory      # 统一驱动工厂
make focused FOCUS=core/tests/nextpas.core.db/test_db_array_bind   # 参数级批量绑定（pg 段需 NEXTPAS_PG_TEST_CONN）
make focused FOCUS=core/tests/nextpas.core.db/test_db_async        # 异步挂载与取消（pg 段需 NEXTPAS_PG_TEST_CONN）
make focused FOCUS=core/tests/nextpas.core.db/test_db_pg_listen    # LISTEN/NOTIFY 订阅（需 NEXTPAS_PG_TEST_CONN）
make focused FOCUS=core/tests/nextpas.core.db/test_db_redis_subscribe  # Redis SUBSCRIBE 订阅（V3-B8，离线回放；live 段需 NEXTPAS_REDIS_TEST_CONN）
make focused FOCUS=core/tests/nextpas.core.db/test_db_sqlscan     # SQL 词法扫描共享引擎（V3-C6，离线纯函数）
make focused FOCUS=core/tests/nextpas.core.db/test_db_mysql        # MySQL/MariaDB 基础探测（V3-A1，离线 7 组）
make focused FOCUS=core/tests/nextpas.core.db/test_db_mysql_adapter # MySQL 适配器（V3-A2，7 offline + 2 live；NEXTPAS_MYSQL_TEST_CONN='host=127.0.0.1 port=53307 user=root password=Test123@abc db=testdb'）
make focused FOCUS=core/tests/nextpas.core.db/test_db_odbc_base    # ODBC 网关探测（V3-A3，unixODBC 即可全绿）
make focused FOCUS=core/tests/nextpas.core.db/test_db_odbc_adapter  # ODBC 适配器（V3-A4，5+1 live；NEXTPAS_ODBC_TEST_CONN）
# 全部门禁清单见 CONTRACT §5；每个含 heaptrc 0 unfreed 硬门槛
```

pg/mysql/odbc 相关门禁需要本地实例（`ensure-db` 自动建测试库）：
`NEXTPAS_PG_TEST_CONN` / `NEXTPAS_MYSQL_TEST_CONN` / `NEXTPAS_ODBC_TEST_CONN` 覆盖连接串；缺席对应 live 段自动 Skip。

## 兼容 shim（恢复为最小面，2026-08-25）

旧入口名 `nextpas.core.sqlite` / `nextpas.core.pg` 曾在 G2 全量删除；
因并行存量项目仍 uses 旧名无法编译，同日恢复为两个薄 re-export shim
（CONTRACT §3）。迁移窗口重开：存量项目零改动即可编译，**新代码一律
使用 `nextpas.core.db.*` 家族单元名**。
