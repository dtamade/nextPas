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
  计数同一受控边界）。`?N` 显式编号直接映射 `$N`。Exec 不翻译。
- **IsNull 统一**：sqlite 侧经列类型 SQLITE_NULL 判定；pg 侧透传 PQgetisnull。
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

v1 **不做跨后端错误码语义归一**（如 unique violation：sqlite extended 2067 vs
PG `23505`）。出现真实消费需求时再评估映射表。非后端异常原样穿透。

### 2.3 事务（IDbTxControl + db.tx）

- 计数式嵌套，语义照搬 `db.sqlite.tx`：Begin 加深、内层 Commit 只降计数、
  最外层 Commit/Rollback 决定一切；外层回滚撤销内层已"提交"内容。
- `WithTransaction(Conn, Proc)`：成功自动提交；异常自动回滚并重抛原异常。
- 内层失败只恢复簿记计数（RestoreDepth），由最外层定夺——回调内捕获内层
  异常可继续外层事务。内层已整事务回滚清账时，外层提交得到明确错误。
- **pg 差异**：libpq 无 autocommit 探针，裸 BEGIN 混用守卫仅 sqlite 提供；
  pg 侧误用由簿记守卫（无 Begin 的 Commit/Rollback 抛错）兜底。

### 2.4 迁移（db.migrate）

`Migrate(AConn, Migrations)` 为 `db.sqlite.migrate` 的跨后端泛化版：
版本表 `schema_migrations(version INTEGER PRIMARY KEY, applied_at TEXT)`，
DDL 两引擎通用；applied_at 由本单元显式写入 ISO8601 UTC 文本。幂等、每批
一个事务（走泛化 WithTransaction）、上下限校验同 sqlite 版。

### 2.5 逃生舱纪律

`IDbConnection.Raw` 暴露 sqlite3*（pg 侧返回 nil，需 PGconn* 时直用
`nextpas.core.db.pg` 门面）。仅限抽象层未覆盖的特性（LastInsertRowId、
BusyTimeout、Checkpoint、LISTEN/NOTIFY 等）。使用逃生舱的代码即放弃
跨后端可移植性，须在调用点注释说明。

## 3. 兼容 shim（deprecated）

以下旧单元名保留为纯 re-export shim，新代码禁止使用：

```
nextpas.core.sqlite{,.base,.conn,.pool,.tx,.migrate}
nextpas.core.pg{,.base,.loader,.conn}
```

- **例外**：`nextpas.core.sqlite.ffi` / `nextpas.core.pg.ffi` 无 shim——
  cdecl external 函数与 dlsym 变量无法用类型别名忠实转出口；仓内无直接
  消费者。外部若有直连 FFI 的代码必须改用新单元名。
- **删除条件**：仓内消费方全部切换 + 并行 lane 的活跃工作不再引用旧名 +
  总控批准治理 slice。

## 4. 消费方路由

| 需求 | 用哪个 |
|---|---|
| 可移植存储访问（推荐默认） | `nextpas.core.db` 门面 |
| sqlite 连接池（读池 + 单写连接） | `nextpas.core.db.sqlite.pool` |
| savepoint 式精细事务控制 | `nextpas.core.db.sqlite.tx`（sqlite 专属） |
| libpq 原生能力（$N 原生语法等） | `nextpas.core.db.pg` 门面 |

## 5. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_unified   # 统一层全 API 面 + heaptrc
make focused FOCUS=core/tests/nextpas.core.db/test_db_sqlite    # sqlite 后端
make focused FOCUS=core/tests/nextpas.core.db/test_db_tx        # sqlite 事务助手
make focused FOCUS=core/tests/nextpas.core.db/test_db_pool      # sqlite 连接池
make focused FOCUS=core/tests/nextpas.core.db/test_db_migrate   # sqlite 迁移助手
make focused FOCUS=core/tests/nextpas.core.db/test_db_pg        # pg 后端（真机，需本地 PG）
make focused FOCUS=core/tests/nextpas.core.http.middleware/test_session_sqlite  # 消费方回归
```

每个 gate 含 heaptrc `0 unfreed memory blocks` 硬门禁。test_db_pg 需要
本地 PostgreSQL（`ensure-db` 自动建测试库；可用 `NEXTPAS_PG_TEST_CONN`
覆盖连接串）。

## 6. 设计文档

两阶段收编决策与路线图：`core/docs/plans/2026-08-23-db-module-boundary.md`。
