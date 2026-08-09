# nextpas.core.sqlite 代码契约

**模块路径**：`core/src/nextpas.core.sqlite*.pas`（4 个源文件）
**层级**：L2（依赖 L0-L1: base, exception, errors）
**Owner**：proxy888 反哺（Claude 负责）
**最后更新**：2026-08-09
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| sqlite.base | 公共常量（SQLITE_OK/ROW/DONE、OPEN flags、列类型）+ 类型别名 |
| sqlite.ffi | 原生 sqlite3.h ABI 声明（系统 libsqlite3，cdecl external） |
| sqlite.conn | 友好表面：TSqliteDb / TSqliteQuery / ESqliteError |
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

TSqliteQuery:
  procedure BindText/Int64/Double/Blob/Null(AIndex, ...);  // 1-based
  function Step: Boolean;                               // True=有行, False=完成
  procedure Reset;
  function ColumnCount / ColumnName(AIndex) / ColumnType(AIndex): ...
  function GetInt64/GetDouble/GetText/GetBlob(AIndex): ...  // 0-based 列

ESqliteError: 携带原生 SQLite 结果码（ErrorCode 属性）
```

### 1.3 绑定与取值索引约定

- **绑定参数索引 1-based**（SQLite 惯例，`?1`/`?` 占位符）。
- **列索引 0-based**（sqlite3_column_* 惯例）。
- 文本为 UTF-8（SQLite 原生编码）。

---

## 2. 不变量

- **[INV-1]** 所有错误路径抛 `ESqliteError`（含 `ErrorCode`）；绝不静默吞错。
- **[INV-2]** `Exec` 失败时 sqlite3_exec 分配的 errmsg 由本模块 `sqlite3_free` 释放，无泄漏（heaptrc 0 unfreed 锁定）。
- **[INV-3]** TSqliteDb/TSqliteQuery 析构必须关闭底层句柄（close_v2 / finalize），重复 Free 由 FPC 引用语义保证安全。
- **[INV-4]** 连接默认 FULLMUTEX，可跨线程使用；写串行化由调用方负责（proxy888 db 层单写者策略）。
- **[INV-5]** WAL 模式由调用方开启（`PRAGMA journal_mode=WAL`），`Checkpoint` 只做检查点。

## 3. 依赖

- `nextpas.core.base`（TBytes）
- `nextpas.core.exception`（ENextPasError 派生 ESqliteError）
- 系统 libsqlite3.so（Linux；`sqlite3_open_v2` 等符号已确认 3.46.1）

## 4. 测试

- `tests/nextpas.core.sqlite/test_sqlite/`：10 契约用例
  （内存建表插查、NULL 绑定、多语句 exec、DML step、exec/prepare/约束错误路径、
  磁盘持久化+WAL checkpoint、busy timeout、版本号）+ heaptrc 泄漏门禁。

## 5. 已知边界（不承诺）

- 不做 SQL 解析/构造（调用方拼接，参数一律 bind）。
- 不提供连接池（proxy888 db 层职责）。
- 不封装事务 begin/commit（调用方用 Exec 直发，事务短小由调用方保证）。
