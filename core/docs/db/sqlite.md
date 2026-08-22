# nextpas.core.db.sqlite 代码契约

**模块路径**：`core/src/nextpas.core.db.sqlite*.pas`（7 个源文件，nextpas.core.db 家族 SQLite 后端子模块）
**层级**：L2 实现（挂在 L3 `nextpas.core.db` 家族下；依赖 L0-L1: base, exception, errors, sync）
**Owner**：proxy888 反哺（Claude 负责）；2026-08-23 起由 core-db lane 收编维护
**最后更新**：2026-08-23（物理收编进 db 家族；单元名 nextpas.core.sqlite.* → nextpas.core.db.sqlite.*）
**版本**：1.2（收编版；新增 SetTxnDepth 簿记原语供泛化事务层使用）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| sqlite.base | 公共常量（SQLITE_OK/ROW/DONE、OPEN flags、列类型）+ 类型别名 |
| sqlite.ffi | 原生 sqlite3.h ABI 声明（系统 libsqlite3，cdecl external） |
| sqlite.conn | 友好表面：TSqliteDb / TSqliteQuery / ESqliteError；`Handle` 暴露原生句柄 |
| sqlite.pool | **B7**：TSqlitePool 薄连接池（懒创建/复用/硬容量/统一 WAL+busy_timeout/专用写连接） |
| sqlite.tx | **B7**：事务助手（WithTransaction + Begin/Commit/RollbackTxn + 嵌套深度计数 + autocommit 守卫） |
| sqlite.migrate | **B7**：迁移助手（schema_migrations 版本表 + 有序迁移列表 + 幂等 + 每批事务 + 上下限校验） |
| sqlite.pas | 门面：re-export 全部公共 API |

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

### 1.3 助手 API（B7，详见 docs/sqlite/README.md）

```pascal
TSqlitePool:  // sqlite.pool
  constructor Create(APath; AMaxConnections=8; ABusyTimeoutMs=5000; AWal=True);
  function Acquire: TSqliteDb;      // 读连接；容量耗尽抛 ESqlitePoolError
  procedure Release(ADb);           // 归还；写连接不可 Release
  function Writer: TSqliteDb;       // 专用写连接（池所有）
  procedure Close;                  // 幂等；关闭后 Acquire/Writer 抛错
  IdleCount / TotalConnections / Path / MaxConnections / BusyTimeoutMs

sqlite.tx:
  procedure WithTransaction(ADb; AProc: TSqliteTxProc);  // 自动 BEGIN/COMMIT/ROLLBACK
  procedure BeginTxn(ADb; AImmediate=False);             // 计数式，嵌套加深
  procedure CommitTxn(ADb); / procedure RollbackTxn(ADb);
  function InTransaction(ADb): Boolean; / function TxDepth(ADb): Integer;
  ESqliteTxError: 不配对 Begin/Commit/Rollback、混用裸 BEGIN、nil 回调

sqlite.migrate:
  TSqliteMigration.Create(Version; Sql: array of string)  // 一批迁移
  TSqliteMigrations = array of TSqliteMigration;
  function MakeMigrations(AMigrations): TSqliteMigrations;
  function Migrate(ADb; AMigrations): Integer;           // 返回本次应用批数，幂等
  function MigrationVersion(ADb): Int64;                 // 未迁移 = 0
  ESqliteMigrateError: 列表乱序/重复、已应用版本越界（上下限）
  SQLITE_MIGRATIONS_TABLE = 'schema_migrations'
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
- **[INV-4]** 连接默认 FULLMUTEX，可跨线程使用；写串行化由调用方负责——**B7 起由 sqlite.pool 的专用写连接形式化**（池内所有连接指向同一 DB 文件，写走 `Writer`）。
- **[INV-5]** WAL 模式：B7 起由 `TSqlitePool` 初始化统一设置（`:memory:` 自动跳过，WAL 对内存库无意义）；裸连接仍由调用方开启（`PRAGMA journal_mode=WAL`），`Checkpoint` 只做检查点。
- **[INV-6]** 事务助手向系统注册了每连接深度计数（并发环境经互斥锁保护）；`WithTransaction` 在所有路径（成功/异常）保证簿记清账，绝不留悬空状态。
- **[INV-7]** 迁移助手保证：批次与版本行同事务；任一步失败整批回滚且不记版本；同列表重复调用结果相同（幂等）。

## 3. 依赖

- `nextpas.core.base`（TBytes）
- `nextpas.core.exception`（ENextPasError 派生 ESqliteError / ESqlitePoolError / ESqliteTxError / ESqliteMigrateError）
- `nextpas.core.sync`（Mutex，pool/tx 内部互斥）
- 系统 libsqlite3.so（Linux；`sqlite3_open_v2` 等符号已确认 3.46.1）

## 4. 测试

- `tests/nextpas.core.db.sqlite/test_sqlite/`：11 契约用例（conn/base 表面）
- `tests/nextpas.core.db.sqlite/test_sqlite_pool/`：6 用例（复用/上限/WAL+busy_timeout PRAGMA/写连接身份与守卫/关闭语义/写读一致）
- `tests/nextpas.core.db.sqlite/test_sqlite_tx/`：7 用例（提交/回滚重抛/嵌套/深度计数/裸 Begin-Commit-Rollback/守卫/事务内读己写）
- `tests/nextpas.core.db.sqlite/test_sqlite_migrate/`：7 用例（首迁/幂等/有序/失败批次回滚/上下限/乱序拒绝/无迁移=0）
- 全部含 heaptrc 泄漏门禁

## 5. 已知边界（不承诺）

- 不做 SQL 解析/构造（调用方拼接，参数一律 bind）。
- `TSqlitePool.Acquire` 为**非阻塞**：容量耗尽抛错（薄池不做等待队列入池；调用方需按并发度配 `AMaxConnections`）。
- 事务助手要求**一条连接同时只被一个线程做事务控制**（FULLMUTEX 保证语句安全，但跨线程共享事务状态本模块不协调——读多写少、单写者语义下天然满足）。
- 迁移助手要求迁移列表只增不改：已应用版本一旦不在列表即校验失败（删旧迁移/库超前都被拒绝）。