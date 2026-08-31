# nextpas.core.db 模块边界设计（2026-08-23）

> **执行状态更新（2026-08-23，同日）**：总控升级授权——lane 在 worktree 内
> 直接完成阶段 B 的物理收编，"完全做好再合并到 main"。原两阶段计划合并为
> 单批执行；本文 D2 的"阶段 A/B 拆分"保留为决策记录。实际落地形态：
> sqlite/pg 全部单元物理迁入 `nextpas.core.db.sqlite.*` / `nextpas.core.db.pg.*`，
> 旧单元名保留 deprecated re-export shim（删除条件见 `core/docs/db/CONTRACT.md`
> §3），统一层（base/intf/adapters/tx/migrate/门面）同批交付。
> pg Blob 经 hex + `::bytea` cast 真机验证通过，未触发 fail-closed 降级。

## 背景

core 现有两个数据库模块是各自反哺时落在顶层的：

- `nextpas.core.sqlite`（L2，proxy888 反哺）：`base/ffi/conn/pool/tx/migrate` + 门面，
  带 pool（薄读池 + 专用写连接）、tx（计数式嵌套事务助手）、migrate（schema 版本化）。
- `nextpas.core.pg`（L2，token888 反哺）：`base/ffi/loader/conn` + 门面，
  API 形态对齐 sqlite（`TPgConn`/`TPgQuery`），但无 pool/tx/migrate——其 CONTRACT
  明确写"连接池留在消费应用的 db 层"。

**总控拍板的架构方向**：数据库相关模块的终态归属是 `nextpas.core.db.*` 家族；
现有顶层 `nextpas.core.sqlite` / `nextpas.core.pg` 单元名属于过渡形态。为不破坏
既有消费方与并行 lane，顶层单元暂不物理移动；本设计从零建立真正的
`nextpas.core.db` 家族，并把物理收编作为显式的后续治理阶段。

消费方现状：`http.middleware.session.sqlite`（直接用 sqlite.pool）、
mailGateway888/proxy888 存储层、token888 db 层。

## 决策

### D1：L3 统一抽象层；registry 本批补行

`nextpas.core.db` 是 L3 模块：统一连接/查询/事务表面 + 后端适配器，向下依赖
L2 的 sqlite/pg owner（合法向下依赖）。registry 补行：

```
| `db` | L3 | unified database access (connection/query/tx over sqlite+pg adapters) | yes | L0-L2 plus sqlite/pg owners | focused-runtime |
```

终态家族布局（标注哪些本批落地）：

```
nextpas.core.db.pas              ← 门面 re-export                    【S1】
nextpas.core.db.base.pas         ← 公共类型：TDbKind/TDbColumnType/EDbError 【S1】
nextpas.core.db.intf.pas         ← IDbConnection / IDbQuery          【S1】
nextpas.core.db.sqlite.pas       ← sqlite 适配器（包装 TSqliteDb）     【S1】
nextpas.core.db.pg.pas           ← pg 适配器（包装 TPgConn）           【S3】
nextpas.core.db.tx.pas           ← 事务泛化 WithTransaction/BeginTxn…  【S2】
nextpas.core.db.migrate.pas      ← 迁移泛化 Migrate/MigrationVersion   【S4】
nextpas.core.db.pool.pas         ← 连接工厂池                          【S5，形态待 token888 需求输入】
```

依赖方向（严格单向）：`db.base ← db.intf ← db.<backend> / db.tx / db.migrate ← 门面`。
**关键边界约束**：`db.base` 与 `db.intf` 禁止 uses 任何具体后端单元；只有适配器与
门面允许依赖 `nextpas.core.sqlite*` / `nextpas.core.pg*`。

### D2：两阶段迁移策略；本批只增不改

- **阶段 A（S1-S5，本 lane）**：只新增 `nextpas.core.db.*` 单元，适配器包装既有
  L2 门面的公共 API（`TSqliteDb`/`TSqliteQuery`/`TPgConn`/`TPgQuery`），不改任何
  现有单元、不动任何消费方。
- **阶段 B（G，独立 landing slice）**：物理收编——顶层 `nextpas.core.sqlite*.pas`
  / `nextpas.core.pg*.pas` 改名迁入 `db.sqlite.*` / `db.pg.*` 家族命名，旧单元名
  降级为纯 re-export shim（标记 deprecated），消费方按节奏切换后删 shim。
  阶段 B 触碰所有 db 消费方路径且与多个活跃 lane 相关，动工前必须报
  `Needs Review` 由总控定时机，不在本授权范围内。

阶段 A 的包装层成本是临时的：B 完成后适配器改为直连迁入的实现单元，包装消失。

### D3：接口面——statement/cursor 合一，COM 所有权

两后端现状都是 query 对象 = 预编译语句 + 行游标合一，v1 跟随现状不做分离：

```pascal
{ nextpas.core.db.intf }
IDbQuery = interface
  procedure BindText(AIndex: Integer; const AValue: string);
  procedure BindInt64(AIndex: Integer; const AValue: Int64);
  procedure BindDouble(AIndex: Integer; const AValue: Double);
  procedure BindBlob(AIndex: Integer; const AValue: TBytes);
  procedure BindNull(AIndex: Integer);
  function Step: Boolean;                       { True=有行 }
  procedure Reset;
  function ColumnCount: Integer;
  function ColumnName(AIndex: Integer): string;
  function ColumnType(AIndex: Integer): TDbColumnType;
  function IsNull(AIndex: Integer): Boolean;
  function GetInt64(AIndex: Integer): Int64;
  function GetDouble(AIndex: Integer): Double;
  function GetText(AIndex: Integer): string;
  function GetBlob(AIndex: Integer): TBytes;
end;

IDbConnection = interface
  function Kind: TDbKind;                       { dbkSqlite / dbkPostgres }
  procedure Exec(const ASql: string);           { 多语句 DDL/DML，原文透传 }
  function Query(const ASql: string): IDbQuery; { 参数化查询；COM 所有权 }
  function Changes: Int64;
  function InTransaction: Boolean;              { S2 起有意义 }
end;
```

- **所有权**：对外一律 interface（COM 引用计数），消费方不写 try/finally Free；
  适配器对象内部持有后端 class 的真实生命周期。符合 design-conventions §4
  （Builder/interface 自动释放）与"默认异常、直线代码"的错误策略。
- **绑定索引 1-based，列索引 0-based**：两后端现状一致，直接统一。
- **IsNull 统一进契约**：sqlite 侧经 `ColumnType=dbcNull` 实现，pg 侧透传。
- **Changes 用 Int64**：取两后端宽者。
- 工厂入口三件套（门面导出）：

```pascal
function DbOpen(const ABackend: TDbBackend; const ATarget: string): IDbConnection;
function ConnectSqlite(const APath: string): IDbConnection;      { ':memory:' 可用 }
function ConnectPostgres(const AConnInfo: string): IDbConnection; { libpq key=value }
```

### D4：语义差异调和

| 差异点 | sqlite 现状 | pg 现状 | db 层契约 |
|---|---|---|---|
| 参数占位符 | `?` / `?N` | `$N` | **参数化 SQL 一律写顺序 `?`**，适配器负责翻译（pg 侧把第 k 个 `?` 重写为 `$k`，扫描跳过字符串字面量/注释——复用 pg.conn 已验证的解析思路）。`Exec` 无参数绑定，SQL 原文透传不翻译。要写后端原生 SQL 走逃生舱（D6），不走抽象层 |
| Blob | BindBlob/GetBlob | 无（文本协议） | 接口保留 BindBlob/GetBlob。pg 侧意图实现为 hex 文本（`\x…`）+ `::bytea` cast 重写；S3 真机验证不过则降级 fail-closed 抛 `EDbNotSupported`，以 CONTRACT 记录为准 |
| 行 NULL 判定 | ColumnType | IsNull | 统一 IsNull |
| LastInsertRowId | 有 | 无（惯用 RETURNING） | 不进接口；sqlite 特性走逃生舱 |
| 错误载荷 | ErrorCode + ExtendedCode | SqlState/Severity/Detail | 见 D5 |

### D5：错误模型——一个异常类 + 双码位并存

```pascal
{ nextpas.core.db.base }
EDbError = class(ENextPasError)
  property Backend: TDbKind;          { 哪个后端引发 }
  property BackendCode: Integer;      { sqlite 结果码；pg 引发时 0 }
  property ExtendedCode: Integer;     { sqlite extended code；否则 0 }
  property SqlState: string;          { pg SQLSTATE；sqlite 引发时空串 }
  property Severity: string;          { pg；否则空串 }
  property Detail: string;            { pg；否则空串 }
end;
EDbNotSupported = class(EDbError);
```

v1 **不做跨后端错误码归一**（如 unique violation：sqlite 2067 vs PG `23505`）：
没有真实消费需求前先保留原始码位，避免发明一套映射表再背两次翻译负担。
适配器捕获后端异常（`ESqliteError`/`EPgError`）转抛 `EDbError`，原始消息进
Message，原始异常类型信息由 `Backend` 字段承载。

### D6：逃生舱显式化

`IDbConnection.Raw: Pointer` 暴露原生句柄（sqlite3* / PGconn*），配合 `Kind`
使用。仅限抽象层未覆盖的特性（LastInsertRowId、BusyTimeout、Checkpoint、
LISTEN/NOTIFY 等）；CONTRACT 写明使用纪律。有逃生舱在，抽象层就不需要为了
覆盖面提前膨胀接口。

### D7：tx / migrate / pool 泛化的分阶段

- **S2 tx**：`WithTransaction(AConn, AProc)` + `BeginTxn/CommitTxn/RollbackTxn`
  + 计数式嵌套，语义照搬 sqlite.tx（成功自动提交、异常回滚重抛、嵌套只加深
  计数）。sqlite 适配器委托既有 `sqlite.tx`（autocommit 守卫完整保留）；
  pg 适配器用 Exec BEGIN/COMMIT/ROLLBACK + 连接内簿记。深度簿记挂在适配器
  对象上，互斥锁保护（复用 `sync` 资产）。
- **S4 migrate**：`Migrate(AConn, AMigrations)` 泛化，版本表 DDL 两后端通用
  （INTEGER PRIMARY KEY + TEXT）；批次事务走 S2 的 WithTransaction 天然跨后端。
- **S5 pool**：泛化为"连接工厂上的池"。sqlite 侧 WAL/busy_timeout/单写连接等
  特化留在适配器的连接选项里；pg 侧池语义（多连接 + 会话状态注意项）待
  token888 反哺输入后再定形态，不预判。

### D8：测试门禁与 truth level

沿用仓库现行模式（heaptrc `0 unfreed memory blocks` 硬门禁）：

| gate | 内容 | 批次 |
|---|---|---|
| `core/tests/nextpas.core.db/test_db_sqlite` | ':memory:' 全 API 面 + COM 生命周期泄漏门禁 | S1 |
| `test_db_tx` | 嵌套/回滚/误用守卫 | S2 |
| `test_db_pg` | ensure-db 模式同 `nextpas.core.pg/test_pg`（本地 unix socket） | S3 |
| `test_db_migrate` | 幂等/越界/回滚 | S4 |

focused 入口：`make focused FOCUS=core/tests/nextpas.core.db/<gate>`。
truth level：focused-runtime；另加一个 source-contract 断言
（db.base/db.intf 的 uses 边界不含后端单元），可并入 test_db_sqlite 或独立
小 gate，S1 落地时定。

## Slice 路线图

| 批次 | 内容 | 验证 |
|---|---|---|
| S0（本批） | 设计文档 + registry `db` 行 | source-contract（文档评审） |
| S1 | base + intf + sqlite 适配器 + 门面 + test_db_sqlite | focused runtime + heaptrc |
| S2 | db.tx 泛化 | test_db_tx |
| S3 | pg 适配器（占位符翻译 + Blob 验证点） | test_db_pg（真机） |
| S4 | db.migrate 泛化 | test_db_migrate |
| S5 | db.pool（形态待外部输入） | 待定 |
| G（另行授权） | 物理收编顶层单元进家族 + deprecated shim + 消费方切换 | Needs Review → 总控排期 |

每个 slice 独立小提交、独立可 landing；lane 落后 main 超 50 commit 时按
worktree 纪律评估同步。

## 风险与边界

- **双 API 并存期**：新代码推荐走 `nextpas.core.db`；既有代码不动。CONTRACT
  （随 S1 写 `core/docs/db/`）把这点写成显式规则，避免认知混乱。
- **占位符翻译的正确性**：pg 侧重写扫描必须处理字符串字面量（含转义）、行/块
  注释、dollar-quoted 字符串；S3 用真机用例钉死，失败模式 fail-closed。
- **main 高速前进**：landing 一律走 cherry-pick 到一次性候选分支 +
  `make landing-check`，禁止 raw merge；不触碰其他成员已提交或未提交的工作。
- **明确不做**：ORM/查询构造器/方言 SQL 生成（不是本模块职责）；Result/Optional
  类型（违反仓库错误处理约定）；在阶段 B 授权前移动任何现有单元。

## 参考

- `core/docs/sqlite/CONTRACT.md`、`core/docs/sqlite/README.md`
- `core/docs/pg/CONTRACT.md`
- `core/docs/design-conventions.md`（§2 模块范式、§3 分层、§4 错误策略）
- `docs/worktrees.md`（landing 纪律）
