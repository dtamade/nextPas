# nextpas.core.db.sqlite 代码契约

**模块路径**：`core/src/nextpas.core.db.sqlite*.pas`（7 个源文件，nextpas.core.db 家族 SQLite 后端子模块）
**层级**：L2 实现（挂在 L3 `nextpas.core.db` 家族下；依赖 L0-L1: base, exception, errors, sync）
**Owner**：proxy888 反哺（Claude 负责）；2026-08-23 起由 core-db lane 收编维护
**最后更新**：2026-08-25（G2 收口：旧名 nextpas.core.sqlite.* shim 已删除，仅存 nextpas.core.db.sqlite.*）
**版本**：1.2（收编版；新增 SetTxnDepth 簿记原语供泛化事务层使用）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| sqlite.base | 公共常量（SQLITE_OK/ROW/DONE、OPEN flags、列类型）+ 类型别名 |
| sqlite.ffi | 原生 sqlite3.h ABI 声明（系统 libsqlite3，cdecl external） |
| sqlite.conn | 友好表面：TSqliteDb / TSqliteQuery / ESqliteError；`Handle` 暴露原生句柄 |
| sqlite.tx | **B7**：事务助手（WithTransaction + Begin/Commit/RollbackTxn + 嵌套深度计数 + autocommit 守卫） |
| sqlite.pas | 门面：re-export conn/tx 公共 API（G2 起 pool/migrate 已退役出家族——连接池走 `nextpas.core.db.pool`，迁移走 `nextpas.core.db.migrate`） |

### 1.2 核心 API

```pascal
function SqliteOpen(const APath: string): TSqliteDb;   // ':memory:' 支持

TSqliteDb:
  constructor Create(const APath: string);              // RW+CREATE+FULLMUTEX
  constructor Create(const APath: string; const AFlags: Integer);
  procedure Exec(const ASql: string);                   // 多语句 DDL/DML
  function Query(const ASql: string): TSqliteQuery;     // 预编译语句
  function Changes: Integer;                            // 最近变更行数
  function LastInsertRowId: Int64;
  procedure BusyTimeout(const AMs: Integer);
  procedure Checkpoint;                                 // WAL checkpoint
  function Version: string;                             // libsqlite3 版本
  property Handle: TSqliteHandle;                       // 原生 sqlite3*（tx 守卫等 FFI 用途）

TSqliteQuery:
  procedure BindText/Int64/Double/Blob/Null(AIndex, ...);  // 1-based
  function Step: Boolean;                               // True=有行, False=完成
  procedure Reset;
  function ColumnCount / ColumnName(AIndex) / ColumnType(AIndex): ...
  function GetInt64/GetDouble/GetText/GetBlob(AIndex): ...  // 0-based 列

ESqliteError: 携带原生 SQLite 结果码（ErrorCode 属性）
```

### 1.3 助手 API（B7；池与迁移已移交统一层，详见 docs/db/CONTRACT.md §2.4/§2.7）

```pascal
sqlite.tx:
  procedure WithTransaction(ADb; AProc: TSqliteTxProc);  // 自动 BEGIN/COMMIT/ROLLBACK
  procedure BeginTxn(ADb; AImmediate=False);             // 计数式，嵌套加深
  procedure CommitTxn(ADb); / procedure RollbackTxn(ADb);
  function InTransaction(ADb): Boolean; / function TxDepth(ADb): Integer;
  ESqliteTxError: 不配对 Begin/Commit/Rollback、混用裸 BEGIN、nil 回调

连接池（G2 起 = nextpas.core.db.pool 的 TDbPool）:
  跨后端读池 + 单写者、接口代理租约（置空归还）、等待队列、泄漏检测。
  sqlite 工厂：ConnectSqlite(path[, TDbConnectOptions])。

迁移（G2 起 = nextpas.core.db.migrate）:
  MakeMigrations/Migrate/MigrateDryRun/MigrationVersion on IDbConnection，
  checksum 防篡改 + dry-run + 上下限校验；DB_MIGRATIONS_TABLE =
  'schema_migrations'。
```

### 1.4 绑定与取值索引约定

- **绑定参数索引 1-based**（SQLite 惯例，`?1`/`?` 占位符）。
- **列索引 0-based**（sqlite3_column_* 惯例）。
- 文本为 UTF-8（SQLite 原生编码）。

---

## 2. 不变量

- **[INV-1]** 所有错误路径抛 `ESqliteError`（含 `ErrorCode`）；绝不静默吞错。
- **[INV-2]** `Exec` 失败时 sqlite3_exec 分配的 errmsg 由本模块 `sqlite3_free` 释放，无泄漏（heaptrc 0 unfreed 锁定）。
- **[INV-3]** TSqliteDb/TSqliteQuery 析构必须关闭底层句柄（close_v2 / finalize），重复 Free 由 FPC 引用语义保证安全。
- **[INV-4]** 连接默认 FULLMUTEX，可跨线程使用；写串行化由调用方负责——单写者形式化由
  `nextpas.core.db.pool` 的专用写连接承担（池内所有连接指向同一 DB 文件，写走 `Writer`）。
- **[INV-5]** WAL 模式：裸连接仍由调用方开启（`PRAGMA journal_mode=WAL`），`Checkpoint` 只做
  检查点；经 `ConnectSqlite(path, opts)` 建连的按需自行设置（WAL 对内存库无意义）。
- **[INV-6]** 事务助手向系统注册了每连接深度计数（并发环境经互斥锁保护）；`WithTransaction` 在所有路径（成功/异常）保证簿记清账，绝不留悬空状态。
- **[INV-7]** 迁移完整性语义由统一层 `db.migrate` 承担并钉死（test_db_migrate_v2 真机双后端）。

## 3. 依赖

- `nextpas.core.base`（TBytes）
- `nextpas.core.exception`（ENextPasError 派生 ESqliteError / ESqliteTxError）
- 系统 libsqlite3.so（Linux；`sqlite3_open_v2` 等符号已确认 3.46.1）

## 4. 测试

- `tests/nextpas.core.db/test_db_sqlite/`：sqlite 后端门禁
- `tests/nextpas.core.db/test_db_tx/`：事务助手用例
- 池/迁移语义由统一层门禁覆盖：`test_db_pool_v2` / `test_db_migrate_v2` / conformance §7、§9
- 全部含 heaptrc 泄漏门禁

## 5. 已知边界（不承诺）

- 不做 SQL 解析/构造（调用方拼接，参数一律 bind）。
- 事务助手要求**一条连接同时只被一个线程做事务控制**（FULLMUTEX 保证语句安全，但跨线程共享事务状态本模块不协调——读多写少、单写者语义下天然满足）。
- 迁移列表只增不改的校验由统一层 `db.migrate` 执行（删旧迁移/库超前都被拒绝）。