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
| 错误归一（Category+Constraint 双码位） | ✅ | ✅ 含定位字段 | §2.2 |

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
| [sqlite.md](sqlite.md) / [pg.md](pg.md) | 后端单元参考 |
| [../plans/2026-08-23-db-v2-architecture.md](../plans/2026-08-23-db-v2-architecture.md) | v2 架构基线（设计决策、对标批评、缺口账本） |
| [../plans/2026-08-23-db-v2-increment-go-rust.md](../plans/2026-08-23-db-v2-increment-go-rust.md) | Go/Rust 对标增量（INC 清单与落地注记） |
| [../plans/2026-08-23-db-v3-industrial-roadmap.md](../plans/2026-08-23-db-v3-industrial-roadmap.md) | **V3 工业级路线图**：后端扩张/架构收口/性能工业化三主线 |

## 门禁速查

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_conformance  # 跨后端一致性契约
make focused FOCUS=core/tests/nextpas.core.db/test_db_v2           # 统一层全 API 面
# 全部门禁清单见 CONTRACT §5；每个含 heaptrc 0 unfreed 硬门槛
```

pg/mysql 相关门禁需要本地实例（Makefile `ensure-db` 自动建测试库，
`NEXTPAS_PG_TEST_CONN` 覆盖连接串）。

## 兼容 shim（deprecated）

`nextpas.core.sqlite.*` 与 `nextpas.core.pg.*` 为纯 re-export shim，
新代码禁止使用（CONTRACT §3）；删除条件 = 消费方全部切换（G2 窗口）
+ 总控批准。
