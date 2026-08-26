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
uses nextpas.core.db.factory;

var Conn: IDbConnection;
begin
  // 注册制驱动入口：内建五驱动 sqlite/postgres/mysql/odbc/redis 自注册
  Conn := DbOpen('sqlite', ':memory:');
  Conn := DbOpen(dbkPostgres, 'host=/var/run/postgresql dbname=myapp user=app');

  // Open 即池：返回工业级连接池（Go *sql.DB 形态）
  var P := DbOpenPool('postgres',
    'host=/var/run/postgresql dbname=myapp user=app', TDbPoolPolicy.Default);
end.
```

第三方驱动实现 `IDbDriver` 后 `DbRegisterDriver` 注入即接入
DbOpen/DbOpenPool 全套；契约见 CONTRACT §2.14。

## 特性矩阵

| 能力 | sqlite | PostgreSQL | 契约 |
|---|---|---|---|
| 参数化查询（? → $N 翻译） | ✅ | ✅ | §2.1 |
| 事务（IDbTxControl 手动计数面） | ✅ | ✅ | §2.3 |
| savepoint 混合嵌套（WithTransaction 自动） | ✅ | ✅ | §2.3 |
| 瞬时错误重试（WithTransactionRetry + 自定义段位谓词） | ✅ | ✅ | §2.3 |
| 手动 SAVEPOINT/RollbackTo/ReleaseTo | ✅ | ✅ | §2.3 |
| 批执行 IDbBatchExecutor | ✅ | ✅ 单次往返 | §2.5* |
| 透明语句缓存 | ✅ LRU | —（G8 排期） | INC-3 |
| 连接池（读池+单写者） | ✅ | ✅ | §2.7 |
| 池泄漏检测 + 获取栈采样（默认关） | ✅ | ✅ | §2.7 |
| 迁移 checksum 防篡改 + dry-run | ✅ | ✅ | §2.4 |
| 大对象流 | 行内 blob 区间读写 | lo_* 句柄模型 | §2.9 |
| 列类型 dbcBool / NULL 行级信号 | ✅ | ✅ | §2.1 |
| 查询/锁超时（TDbConnectOptions） | busy_timeout | connect/statement_timeout | INC-7 |
| 查询级超时（Exec/Query + TDbExecOptions，advisory） | 忽略（诚实登记） | ✅ exec/query 双路径 | §2.6b |
| 观测钩子（IDbTraceListener/IDbTraceControl，四后端同构接线） | ✅ | ✅ | §2.12 |
| Redis 原生后端（RESP2 无 C 库依赖，键值面映射统一层） | ✅ | ✅ | §2.13 |
| 错误归一（Category+Constraint 双码位） | ✅ | ✅ 含定位字段 | §2.2 |
| 统一驱动工厂（注册制 DbOpen + Open 即池 DbOpenPool） | ✅ | ✅ 五后端+可插拔 | §2.14 |
| sqlite 调优预设（WAL+NORMAL+FK 安全缺省，journal 回读校验 fail-closed） | ✅ | — | §2.15 |
| TLS 契约成文（责任表 + 各后端样例；pg conninfo/redis UseTls 透传） | N/A | ✅ | §2.1-TLS |
| 参数级批量绑定（IDbArrayBinding，unnest 单语句单往返；NULL 掩码+fail-fast 对齐校验） | 降级通用批路径 | ✅ pg | §2.16 |
| 异步挂载与取消（TDbAsyncExecutor 单飞执行线程；令牌级联 → PQcancel / progress handler；归一 decTimeout） | ✅ | ✅ | §2.17 |
| LISTEN/NOTIFY 订阅会话（专用连接独占 + 泵线程投递；Token 取消；断线自动重连重放订阅；at-most-once 如实上报） | N/A | ✅ | §2.18 |

上表已运行时自述化（V3-B1）：`DbCapabilities(Conn)` 返回
`IDbCapabilities`，消费方按能力探测降级而非按后端名分支；契约语义见
CONTRACT §2.10。

MySQL/MariaDB：基础三件套（base 常量词汇 / ffi 双方言 ABI 镜像 /
loader 多 soname 探测 + flavor 自动识别）与适配器（prepared stmt
二进制协议、错误归一、savepoint、多语句批执行）已落地（V3-A1/A2）；
统一工厂 `ConnectMysql(dsn[, opts])` 已透出。真机 roundtrip 冒烟设
`NEXTPAS_MYSQL_TEST_CONN` 启用。

ODBC（第四后端网关，服务任意 DSN 与国产库 ODBC 路径）：base 常量
词汇 / ffi 22 符号最小面 / loader 多候选探测（V3-A3）与适配器
IDbConnection over DSN、prepared 参数化、GetData 惰性物化 + 截断
重取、AUTOCOMMIT+SQLEndTran 事务面、ClassifyOdbc SQLSTATE 归一、
GetInfo 能力降级矩阵（V3-A4）均已落地；统一工厂 `ConnectOdbc(connstr[,
opts])` 已透出。契约见 CONTRACT §2.11。门禁仅驱动管理器
（unixODBC libodbc.so.2）即可全绿——负连接走管理器 IM002 真实诊断
链路；真库往返设 `NEXTPAS_ODBC_TEST_CONN` 启用。

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
# 全部门禁清单见 CONTRACT §5；每个含 heaptrc 0 unfreed 硬门槛
```

pg/mysql 相关门禁需要本地实例（Makefile `ensure-db` 自动建测试库，
`NEXTPAS_PG_TEST_CONN` 覆盖连接串）。

## 兼容 shim（恢复为最小面，2026-08-25）

旧入口名 `nextpas.core.sqlite` / `nextpas.core.pg` 曾在 G2 全量删除；
因并行存量项目仍 uses 旧名无法编译，同日恢复为两个薄 re-export shim
（CONTRACT §3）。迁移窗口重开：存量项目零改动即可编译，**新代码一律
使用 `nextpas.core.db.*` 家族单元名**。
