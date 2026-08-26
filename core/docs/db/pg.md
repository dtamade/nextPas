# nextpas.core.db.pg 代码契约

**模块路径**：`core/src/nextpas.core.db.pg*.pas`（5 个源文件，nextpas.core.db 家族 PostgreSQL 后端子模块）
**层级**：L2 实现（挂在 L3 `nextpas.core.db` 家族下；依赖 L0-L1: platform.dl, exception, text.conv）
**Owner**：token888 反哺；与 proxy888 联合评审；2026-08-23 起由 core-db lane 收编维护
**最后更新**：2026-08-25（G2 收口：旧名 nextpas.core.pg.* shim 已删除，仅存 nextpas.core.db.pg.*）
**版本**：1.1（收编版）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| pg.base | 公共常量（ConnStatusType/ExecStatusType/PG_DIAG_*）+ 类型别名 + `EPgError` |
| pg.ffi | libpq C ABI 声明（**cdecl 过程类型**，非 external——运行时 dlopen） |
| pg.loader | `dlopen('libpq.so.5')` + dlsym 绑定全部符号（复用 `platform.dl.TPlatformLibrary`） |
| pg.conn | 友好表面：`TPgConn` / `TPgQuery`（对齐 `TSqliteDb`/`TSqliteQuery` 形态） |
| pg.listen | V3-B7 LISTEN/NOTIFY 订阅会话：TPgListener 专用连接独占 + 单工泵线程投递（见 CONTRACT §2.18） |
| pg.pas | 门面：re-export 全部公共 API |

### 1.2 核心 API

```pascal
Conn := PgOpen('host=/var/run/postgresql dbname=myapp user=app');  // 失败抛 EPgError

TPgConn:
  constructor Create(const AConnInfo: string);   // libpq key=value 连接串
  procedure Exec(const ASql: string);            // 多语句 DDL/DML（PQexec）
  function Query(const ASql: string): TPgQuery;  // 参数化查询（PQexecParams，服务端推断类型）
  function Changes: Int64;                       // 最近一次写入影响行数
  function Version: string;                      // libpq 版本（如 '170010'）
  function ServerVersion: Integer;
  function ErrorMessage: string;

TPgQuery:
  procedure BindText/Int64/Double/Blob/Null(AIndex, ...);  // 绑定 1-based，与 $N 编号对应
  function Step: Boolean;                            // True=有行；首次调用触发执行
  procedure Reset;                                   // 释放结果，可重新 Step
  function ColumnCount / ColumnName(AIndex): ...
  function ColumnFieldOid(AIndex): Cardinal;         // PQftype；未执行 = 0
  function IsNull(AIndex): Boolean;
  function GetInt64/GetDouble/GetText(AIndex): ...   // 列 0-based；NULL -> 0 / ''
  function GetBlob(AIndex): TBytes;                  // bytea hex 输出解码；非 \x 前缀抛 EPgError
```

> **1.1 收编新增（2026-08-23）**：`BindBlob` 将二进制编码为 `\x…` hex 文本参数，
> `ExecuteOnce` 对相应 `$N` 追加 `::bytea` cast（服务端按 bytea 解析）；
> `GetBlob` 解码 bytea 的 hex 文本输出。真机门禁见
> `core/tests/nextpas.core.db/test_db_pg` 的 `blob hex+cast roundtrip` 用例。

### 1.3 绑定与取值索引约定

- **绑定参数索引 1-based**，与 SQL 中 `$1..$N` 一一对应（参数个数在 `Query` 时
  从 SQL 解析，跳过字符串字面量/标识符/注释）。
- **列索引 0-based**（对应 libpq `PQgetvalue` 语义）。
- 文本为 UTF-8；参数以 **文本格式** 传给服务端（`PQexecParams` resultFormat=0），
  类型由服务端推断；整数/浮点经 `nextpas.core.text.conv` 往返。

### 1.4 EPgError

- 携带 `SqlState`（SQLSTATE，如 `23505` unique_violation）、`Severity`、`Detail`
  （取自 `PQresultErrorField`）；MessagePrimary 为 `Message`。
- 连接失败/库加载失败同样抛 `EPgError`（`SqlState` 为空）。

---

## 2. 不变量

- **[INV-1]** 所有错误路径抛 `EPgError`；绝不静默吞错（连接、执行、绑定、取值一致）。
- **[INV-2]** 每个 `PGresult` 用完即 `PQclear`（Exec/Query 生命周期内成对），
  heaptrc 0 unfreed 锁定。
- **[INV-3]** `TPgConn`/`TPgQuery` 析构释放底层句柄（`PQfinish`）；`PQfinish` 对
  坏连接安全（libpq 契约）。
- **[INV-4]** 单连接**线程独占**（libpq 非线程安全）；并发写由调用方串行化
  （token888 db 层单写者策略，与 sqlite FULLMUTEX 语义对齐）。
- **[INV-5]** 加载失败（缺 `libpq.so.5`）在首次 `PgOpen`/`Query` 时立刻抛可读错误
  （fail-fast），不静默降级。
- **[INV-6]**（V3-B7）`PQnotifies` 返回的每条 PGnotify 用后即
  `PQfreemem`（heaptrc 0 锁定）；`TPGnotify` 字段序镜像 libpq C 布局
  （relname/be_pid/extra），改动即 ABI 漂移——真机自发自收往返门禁
  （test_db_pg_listen）钉死。

## 3. 依赖

- `nextpas.core.platform.dl`（`TPlatformLibrary`，dlopen/dlsym/close）
- `nextpas.core.exception`（`ENextPasError`）
- `nextpas.core.text.conv`（IntToStr/StrToInt64Def/TryStrToInt64/FloatToStr）
- 系统 `libpq.so.5`（PostgreSQL 客户端库；dlopen 加载，无需编译期链接）

> 为何 dlopen 而非 `external 'pq'`：构建主机只有版本化 soname `libpq.so.5`
> （无 `libpq.so` 开发符号链接），编译期链接会失败；dlopen 模式与
> `tls.openssl.loader` 一致，且库缺失时可在运行时给出可读诊断。

## 4. 测试

- `tests/nextpas.core.db.pg/test_pg/`：10 契约用例，全部 `TestSeq`（共享测试库串行）：
  连接与版本、建插查 roundtrip、NULL 绑定、多语句 exec、参数化 step-through、
  唯一约束 → SQLSTATE 23505、坏连接报错、Changes、错误字段、自管事务
  （BEGIN/ROLLBACK/COMMIT）+ heaptrc 泄漏门禁。
- 前置：本地 PostgreSQL（默认 `host=/var/run/postgresql dbname=nextpas_pg_test
  user=$USER`，可用 `NEXTPAS_PG_TEST_CONN` 覆盖）；`ensure-db` 幂等建测试库。

## 5. 已知边界（不承诺）

- 不做 SQL 解析/构造（调用方拼接，参数一律 bind；`Query` 只统计参数个数）。
- 不提供连接池（调用方 db 层职责）。
- 不封装事务 begin/commit（调用方用 `Exec` 直发，短事务由调用方保证）。
- 取值走文本格式（文本协议），无二进制编解码；大结果集一次性缓冲
  （无可流式游标）。
- 仅 libpq 提供的能力；原生 wire protocol 驱动留作后续演进（见 token888
  `wiki/storage.md` §PG 驱动选型）。