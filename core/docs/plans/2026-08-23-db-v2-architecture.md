# nextpas.core.db v2 架构设计——超越 fafafa.dbman（2026-08-23）

> 定位：本文是 `nextpas.core.db` 的目标架构设计。对标对象 `~/projects/fafafa.dbman`
> （下称 dbman，约 97k 行，JDBC 风格多数据库框架）提供了完整的反面教材与部分
> 可借鉴需求目录。原则：**吸收其证明过的需求，替换其过时的架构形态**。
>
> 本文不修改任何已落地行为；v1 统一层（2026-08-23 收编版）继续有效，
> v2 是它的演进设计。落地节奏见 §8。

---

## 1. 对标对象的实证批评

以下每条都有源码证据，不是印象分。

### P1 God Interface：接口隔离全面失守

| 接口 | 方法数 | 证据 |
|---|---|---|
| IResultSet | **108** | interfaces.pas |
| IDatabaseMetaData | 64 | 同上 |
| IConnection | 60 | 同上 |
| IPreparedStatement | 46 | 同上 |

单一 `interfaces.pas` 3960 行。后果：消费方为了 5 个方法被迫依赖 100+；
mock 一个 IResultSet 要写上百个空方法；驱动作者要为永远用不到的能力负责
（sqlserver driver 单文件 4743 行就是这么长出来的）。

根因：1997 年 JDBC 的接口 taxonomy 被 1:1 直译到 Pascal，连同
`ICallableStatement`/`IBlob`/`IClob`/`IArray` 这些 90% 应用永不触碰的面。

### P2 类型安全形同虚设

- 高层配置 `TDatabaseConfig.Driver: string`——拼错驱动名运行时才炸。
- 参数系统 `TDictionary<string, Variant>`；`GetValue(...): Variant`
  （highlevel.pas 出现 42 处 Variant）。
- `TQueryBuilder.FParameters: TObject`——类型擦除到 object。
- 驱动注册 `RegisterDriver(const ADriver: string; ADriverClass: TClass)`
  ——字符串键 + 裸类引用，双重无检查。

### P3 异常继承树代替不了错误语义

`exceptions.pas` 定义了 20+ 个异常类的深层继承树
（EConnectionTimeoutException / EDeadlockException / ESyntaxException…）。
问题不在"分类多"，而在**分类靠类层次表达**：每个驱动都要自己决定抛哪棵
枝上的哪个叶子，跨后端同语义错误（unique violation）落在不同叶子上时，
消费方的 `except on EDeadlockException` 就成了赌运气。类层次是编译期封闭的，
无法携带结构化的诊断载荷（SqlState、约束列名、死锁对象等）。

### P4 四套 API 面互相叠加

`interfaces.pas`（JDBC 全家桶）+ `enhanced.interfaces.pas` +
`highlevel.pas`（TDatabaseManager/TQueryBuilder/TQueryResult 又包一层
缓冲结果）+ `driver.manager.simple`——学习面 ×4，文档面 ×4，bug 面 ×4。
`TQueryResult` 把本来就是流式的 IResultSet 读进内存再模拟游标，
是纯倒退。

### P5 生命周期混合制

COM 接口（IConnection…）与普通 class（TQueryResult/TDatabaseManager）
混用两套所有权模型；`FreeAndNil(FParameters)` 式手工清理与引用计数并存。
Pascal 里这正是悬垂指针与 double-free 的温床。

### P6 async 是平行宇宙

`interfaces.async.pas` 自定义 `ICancellationToken/IFuture<T>/IContext`，
注释自述"可由 fafafa.core.async 替换"——因为 dbman 没有自己的底层平台，
只能先发明一套占位类型，将来靠 `{$IFDEF FAFAFA_CORE}` 缝合。

### P7 测试各驱动各自为政

"75 个 SQLite 测试、14 个 MySQL 测试、9 个 PG 测试"——每个驱动一套私用
用例，没有共享一致性契约。MySQL 93% 通过率意味着没有门禁强制行为对齐。

### dbman 仍然值得吸收的需求目录

保存点、语句缓存、LOB、批处理、连接池管理器、schema 迁移、查询统计。
这些是真实需求；错的是承载它们的架构形态。

---

## 2. 设计原则（七条）

1. **能力接口隔离**：小接口按能力切分，核心面极小，其余经 QueryInterface
   探测的可选能力。消费方只依赖用到的契约。（反 P1）
2. **所有权即类型**：对外一律 COM 引用计数，零手工 Free，零 class/interface
   混合生命周期。（反 P5）
3. **错误是数据不是类层次**：单一 EDbError + 结构化载荷字段；跨后端语义
   归一走**受控枚举字段**，原始码位永远并存。（反 P3）
4. **类型化边界**：后端是枚举不是字符串；绑定是显式重载不是 Variant；
   工厂是函数不是注册表。（反 P2）
5. **流式为唯一结果形态**：Step 游标直读数据库缓冲，禁止缓冲包装层。
   （反 P4）
6. **站在自家底座上**：同步/互斥用 core.sync，时间用 core.time，未来的
   异步用 core.async 的真实类型体系，绝不自造平行宇宙。（反 P6）
7. **一致性契约即门禁**：所有后端共享同一套行为用例集，新后端接入 =
   跑通 conformance suite，无例外。（反 P7）

---

## 3. 架构总览

```
L3 nextpas.core.db 家族
├── db.base            错误模型（EDbError 字段化 + 归一枚举）、TDbKind、
│                      TDbColumnType、能力 GUID 常量
├── db.intf            能力接口族（§4.1）
│    ├── 核心面      IDbConnection / IDbQuery                    [必实现]
│    ├── 事务面      IDbTxControl / IDbSavepointControl          [tx 必实现/sp 可选]
│    ├── 批量面      IDbBatchExecutor                            [可选]
│    ├── 语句缓存    IDbPreparedCache                            [可选]
│    └── 大对象      IDbLargeObject                              [可选，roadmap]
├── db.err             错误归一表（码位 ↔ ErrorCategory/ConstraintKind）
├── db.tx              WithTransaction（savepoint 感知混合模型，§5.1）
├── db.migrate         版本化迁移（+ 批次 checksum，§8 S6）
├── db.pool            类型化工厂池 + 策略 record（§4.5）
├── db.sqlite.*        SQLite 后端（base/ffi/conn/pool/tx/adapter/门面）
├── db.pg.*            PostgreSQL 后端（base/ffi/loader/conn/adapter/门面）
└── db.pas             门面：re-export 核心 + 工厂三件套
```

依赖方向严格单向：`db.base ← (db.intf, db.err) ← {tx, migrate, pool, 后端}
← 门面`。`db.base/db.intf/db.err` 禁止 uses 任何后端单元（source-contract
gate 锁定）。

与 v1 落地版的差异：新增 `db.err`（归一表）、`IDbSavepointControl`、
`IDbBatchExecutor`、`IDbPreparedCache`、`db.pool`；`db.tx` 嵌套语义从
计数模型升级为 savepoint 混合模型（§5.1，这是唯一的破坏性语义变更，
理由与迁移见 §7）。

---

## 4. 核心决策

### D1 能力接口族（反 God Interface）

核心面收敛到消费方 95% 场景：

```pascal
IDbConnection = interface
  function Kind: TDbKind;
  procedure Exec(const ASql: string);
  function Query(const ASql: string): IDbQuery;      // 流式游标
  function Changes: Int64;
  function Raw: Pointer;                             // 逃生舱（纪律见 CONTRACT）
end;

IDbQuery = interface
  // 绑定：显式类型重载（1-based），永无 Variant
  procedure BindText(AIndex: Integer; const AValue: string);
  procedure BindInt64(AIndex: Integer; const AValue: Int64);
  procedure BindDouble(AIndex: Integer; const AValue: Double);
  procedure BindBlob(AIndex: Integer; const AValue: TBytes);
  procedure BindNull(AIndex: Integer);
  // 流式读取
  function Step: Boolean;
  function ColumnCount: Integer;
  function ColumnName(AIndex: Integer): string;
  function ColumnType(AIndex: Integer): TDbColumnType;
  function IsNull(AIndex: Integer): Boolean;
  function GetInt64/GetDouble/GetText/GetBlob(AIndex: Integer): ...;
  procedure Reset;
end;
```

对比：核心面 ~20 个方法 vs dbman IConnection+IPreparedStatement+IResultSet
合计 214 个。元数据只留 Count/Name/Type/IsNull 四件——
GetPrecision/GetScale/IsCaseSensitive 这类展示期元数据**明确不做**
（YAGNI；真需要走 Raw 逃生舱）。

扩展能力全部走探测协议：

```pascal
var Tx: IDbTxControl;
if Conn.QueryInterface(IDbTxControl, Tx) = 0 then ...
```

| 能力接口 | 职责 | sqlite | pg |
|---|---|---|---|
| IDbTxControl | Begin/Commit/Rollback/Depth | ✓（委托 sqlite.tx） | ✓ |
| IDbSavepointControl | Savepoint/Release/RollbackTo | ✓ 原生 | ✓ 原生 |
| IDbBatchExecutor | ExecBatch(sqls)/BindBatch | ✓ 事务包裹 | ✓ COPY 可选加速 |
| IDbPreparedCache | Prepare(sql): 缓存语句句柄 | ✓（价值大） | ✓（PQprepare） |
| IDbLargeObject | LOB 流读写 | —（blob 即足） | roadmap |

为什么比 God interface 好：能力缺失是**编译期不可知、运行期可优雅降级**
的事实（老版本 libpq 没有 COPY），探测协议把"支持什么"从文档承诺变成
运行时可查询；驱动实现按能力增量交付，不用一次性填 100 个空方法。

### D2 错误 = 单类 + 字段化载荷 + 受控归一

```pascal
TDbErrorCategory = (
  decUnknown, decConnection, decSyntax, decConstraint,
  decTransaction, decTimeout, decAuth, decCapacity, decNotSupported);

TDbConstraintKind = (
  dckNone, dckUnique, dckPrimaryKey, dckForeignKey,
  dckNotNull, dckCheck, dckExclusion);

EDbError = class(ENextPasError)
  property Category: TDbErrorCategory;        // 归一语义（查 db.err 表）
  property Constraint: TDbConstraintKind;     // 约束细分
  property SqlState: string;                  // PG 原样
  property BackendCode: Integer;              // sqlite 原样
  property ExtendedCode: Integer;
  property Severity: string;
  property Detail: string;
  property SchemaName/TableName/ColumnName: string;  // 约束定位（可得则填）
end;
```

要点：
- **只有一个异常类**。消费方写 `on E: EDbError do case E.Category of`，
  分支是数据驱动的 switch，不是继承树 lottery。
- 归一逻辑集中在 `db.err` 单元的纯函数表里（sqlite extended code →
  category/constraint；SqlState 前缀+精确码 → 同一目标），**表本身有
  单测**——dbman 把这张表打散进每个驱动的 throw 语句里，我们把它做成
  一等可测试资产。
- 原始码位字段永远并存：归一只做增量，不做有损替换。修正 v1 的
  "暂不归一"立场——有了 dbman 对照与真实多后端消费需求，受控归一的
  收益（消费方一次 catch 跨后端成立）大于维护成本（一张带测试的表）。

### D3 所有权即类型

对外表面 100% COM 接口：`Conn.Query` 返回的游标随引用归零自毁；
`WithTransaction` 回调持引用即可，无 try/finally 负担。适配器内部持有
后端原生对象并在析构链释放（heaptrc 门禁锁定 0 泄漏）。禁止出现
TQueryResult 式"class 包 interface 再手动 Free"的混合体。

### D4 类型化边界（反 string/Variant/注册表）

```pascal
// 后端 = 枚举；工厂 = 函数；配置 = record 字段
function DbOpen(const ABackend: TDbKind; const ATarget: string): IDbConnection;
function ConnectSqlite(const APath: string): IDbConnection;
function ConnectPostgres(const AConnInfo: string): IDbConnection;
```

不做字符串驱动注册表：编译期就保证只有存在的后端可被选择。配置驱动的
场景（从 ini/json 读后端名）由消费方做一次 string→TDbBackend 映射，
映射失败即刻 fail-fast——把 dbman 的运行时惊喜提前到接线处。

明确拒绝 QueryBuilder DSL：字符串拼接 SQL 的"便利"是注入漏洞与方言
碎片化的来源。参数化 + 占位符翻译（? → $N，已落地）是统一层的全部
SQL 加工面。

### D5 流式为唯一结果形态

`Step` 直读引擎游标（libpq 逐行、sqlite3_step 逐行），无中间缓冲。
大数据集导出 = while Step do 写管道，内存 O(1)。dbman 的 TQueryResult
缓冲模型（FFields/FRowCount/FCurrentRow）不引入。需要物化时消费方自己
收集——显式决策优于隐式拷贝。

### D6 池：类型化工厂 + 策略 record（吸收 poolmanager 思想）

```pascal
TDbPoolPolicy = record
  MaxReadConnections: Integer;   // 读连接硬上限（非阻塞耗尽即抛，同 v1 sqlite 池）
  AcquireTimeoutMs: Integer;     // >0 启用等待队列（v1 sqlite 池没有的增强）
  ValidateOnAcquire: Boolean;    // 取出前轻量探活
  MaxLifetimeSec: Integer;       // 连接最长寿命（防库端踢线）
  IdleTimeoutSec: Integer;       // 空闲超时回收（Go SetConnMaxIdleTime / sqlx idle_timeout 同款）
  MinConnections: Integer;       // 预热下限（0 = 惰性建连）
end;

TDbPool = class                 // 对任意后端的通用池
  constructor Create(ABackend: TDbBackend; const AConnect: TDbConnectFunc;
    const APolicy: TDbPoolPolicy);
  function Acquire: IDbConnection;             // 读连接
  function Writer: IDbConnection;              // 单写连接（单写者形式化）
  procedure Close;
end;
```

- 通用池只管连接生命周期与策略，**不懂方言**：WAL/busy_timeout 等
  特化经由后端连接工厂闭包注入——dbman 的 per-driver connectionpool
  ×N 份复制代码在这里收敛为一份。
- sqlite 现有 `db.sqlite.pool` 保留为薄兼容面，内部转调通用池 +
  sqlite 工厂（消重）。
- 等待队列（AcquireTimeoutMs）修复 v1"薄池非阻塞"的已知边界。
- 底座复用（2026-08-23 审计核实，见 §6.2）：等待队列 =
  `sync.semaphore`；空闲连接列表 = `collections.deque`（LIFO 复用
  提命中率）；簿记临界区 = `sync.scoped.ILockGuard`（RAII）。
  池体不新造任何同步/容器原语。

### D7 一致性契约测试套件（结构性优势）

新建 `core/tests/nextpas.core.db/conformance/`：一套与后端无关的行为
用例（类型往返/NULL/约束/事务/savepoint/迁移/泄漏），以
`{BACKEND}` 抽象连接工厂参数化，sqlite 与 pg 各实例化一次。新后端
（未来 mysql/mongo）接入 = 实现 adapter + 跑通同一套件。CI 里
"conformance 绿"就是后端准入门禁——dbman 的 93% 通过率问题在此
结构性消失。

### D8 异步的诚实路径（不画饼）

libpq/libsqlite3 都是同步 C API。诚实的异步 = 经 `core.async/thread`
的执行器卸载 + 取消令牌（取消令牌用已存在的 `async.cancellation`，
2026-08-23 审计确认该单元已在——D8 的预留位不需要等任何新底座；
绝不自造 IFuture）。v2 只预留契约位（async 能力接口不进本期），待
core.async 执行器成熟后按 D1 探测协议增量挂载。dbman 的自定义
IFuture 平行宇宙不复制。Go database/sql 的教训在此收紧成硬规则：
context 贯穿是它 v2 才补救的（v1 无 ctx，升级破坏全部签名）——
本家族的取消/超时能力**永远以新增能力接口（IDbAsync*）挂载，
绝不扩宽核心方法签名**（§10.2）。

---

## 5. 关键语义规格

### 5.1 事务嵌套：savepoint 混合模型（本设计的核心语义升级）

现状（v1 计数模型）的痛点：内层失败只能"恢复计数"，无法真正只撤销
内层写入；回调内捕获内层异常后继续外层时，内层写入其实还在事务里
（要么一起提交要么一起亡）。

v2 混合模型（业界验证过的标准做法）：

```
深度 1（最外层）:  BEGIN / COMMIT / ROLLBACK          （真事务边界）
深度 ≥ 2（内层）:  SAVEPOINT sp<N> /
                   RELEASE sp<N>（成功）/
                   ROLLBACK TO sp<N>; RELEASE sp<N>（失败）
```

- 内层成功：RELEASE——并入父事务。
- **内层失败：ROLLBACK TO——真正只撤销内层写入**，重抛后外层可选择
  捕获并继续（这是 v1 做不到的部分提交语义）。
- 外层失败：ROLLBACK 整体撤销，savepoint 自动随之消亡。
- savepoint 命名 `np_db_sp_<depth>` 固定格式；深度簿记沿用互斥锁保护
  的连接级计数（复用 v1 资产）。
- 两后端原生都支持 SAVEPOINT，无需方言分支。

语义对照表：

| 场景 | v1 计数模型 | v2 savepoint 模型 |
|---|---|---|
| 内层成功 | 并入外层 | 相同 |
| 内层失败、外层也失败 | 全回滚 | 相同 |
| 内层失败、外层捕获后继续 | **做不到**（内层写入悬在外层事务里） | 内层写入已撤销，外层干净继续 |
| 无事务时调 WithTransaction | BEGIN | 相同（depth1 走 BEGIN） |

`db.sqlite.tx` 低层助手保持 v1 语义不变（精细控制面），统一层 `db.tx`
切换到 savepoint 模型——两个入口的分工在 CONTRACT 写清。

落地注记（V2-S2 已实现）：

- 编排放在 `db.tx`（探测 `IDbSavepointControl` 后发 SAVEPOINT/RELEASE），
  适配器零改动即获得混合模型；savepoint 名固定 `np_db_sp_<层级>`，
  兄弟层级顺序复用安全。
- 嵌套无 savepoint 能力 = fail-fast 拒绝，不静默退化计数并入——
  "假装嵌套"正是 v1 痛点根源，宁拒绝不撒谎。顶层无能力连接照常走真 BEGIN。
- `TxDepth` 收敛为真实 SQL 事务深度，savepoint 层不计入；
  `IDbTxControl.RestoreDepth` 随计数编排消亡而删除（接口瘦身，
  唯一消费者就是旧 db.tx）。
- **顺带修复跨后端裂缝**：pg `RollbackTxn` 此前深度 >1 只降簿记不真
  ROLLBACK（与 sqlite"任意深度整体回滚"不一致）；统一为任意深度真回滚。
  该裂缝属事务嵌套主题，在破坏性窗口内一并收敛。
- 联动增强：`IDbBatchExecutor.ExecuteBatch` 内部经 WithTransaction 实现，
  外层事务内调用时自动获得 savepoint 原子性——批失败不再把外层拖下水。

### 5.2 错误归一表（db.err）

| 后端信号 | Category | Constraint |
|---|---|---|
| SqlState 23xxx / SQLITE_CONSTRAINT(19)+extended | decConstraint | 按 23505→dckUnique、23503→dckForeignKey、23502→dckNotNull、23514→dckCheck、2067/1555→dckUnique/dckPrimaryKey … |
| SqlState 08xxx / 连接失败码 | decConnection | — |
| SqlState 42xxx / prepare 失败 | decSyntax | — |
| SqlState 40xxx / 死锁码 | decTransaction | — |
| 其余 | decUnknown | — |

表为纯函数 + 单测；未知码位落 decUnknown 并保留原始字段——宁可欠归一
不错归一。

### 5.3 能力探测协议

可选能力的获取只有一条路：`QueryInterface(能力GUID)`。CONTRACT 为每个
能力标注"哪些后端在哪个版本起保证支持"。禁止 is-operator 探测具体
适配器类（那会重新制造类型耦合）。

### 5.4 迁移完整性：checksum 规范形与 dry-run 语义（V2-S6 已落地）

migrate 在幂等应用之上叠加两层完整性保障，设计决策如下：

- **规范形只依赖 SQL 序列**：批内步骤按 LF 连接后取 CRC32
  （复用 `nextpas.core.checksum.crc32`），八位小写十六进制入版本行。
  不掺时间戳、主机、后端标识——同一列表跨 sqlite/pg 跨进程必同值，
  消费方可用任意 CRC32 实现独立复核。选 CRC32 而非 SHA：威胁模型 =
  意外漂移与误编辑，非对抗性攻击；碰撞概率对人工编辑尺度足够，
  换取零依赖与确定性。
- **校验语义分野**：`Migrate` 对 mismatch 抛错拒绝继续（写路径从严）；
  `MigrateDryRun` 把 mismatch 作为 `drsChecksumMismatch` 状态上报而非
  抛出（读路径如实呈现），结构性错误（乱序、越界）则两路都抛——
  预览的价值在于让人看见全部状态，而非在第一条坏数据处失明。
- **dry-run 严格零写入**：不建版本表、不升级旧表；表缺失按空库处理。
  预览不允许改变被预览的世界。
- **旧库自愈而非拒绝**：S6 前的两列旧表探测式 `ADD COLUMN` 升级
  （后端中立，不查方言元数据表）；历史空 checksum 条目由下次
  `Migrate` 按当前列表回填。回填依据 = "记录存在且 checksum 为空"
  这一可精确判定的历史形态，不会误伤真实篡改（篡改者改的是值不是
  空缺）。回填发生在应用循环之前，使用刚载入的新鲜已应用列表。

---

## 6. 框架资产复用矩阵（2026-08-23 审计）

原则六（站在自家底座上）的落实清单。审计方法：逐单元扫描
`core/src/nextpas.core.{sync,collections,time,text,encoding,checksum,async}.*`
公开面，与 db 家族需求逐项对表。结论：**db 家族不新造任何底座已
提供的能力**；已发现的重复实现当场收敛（§6.1）。

### 6.1 直接复用（本次已落地重构）

| db 需求 | core 资产 | 收敛掉的手搓实现 |
|---|---|---|
| bytea hex 编解码 | `encoding.hex` HexEncode/HexDecode（表驱动，奇长度/非法字符 fail-closed） | `db.pg.conn` 的 HexDigit/HexValue/BytesToPgHexText/PgHexToBytes 四函数整体删除 |
| SQL 重写缓冲（占位符翻译 / ::bytea cast 追加） | `text.builder` IStringBuilder（Reserve+AppendChar/AppendInt 摊销缓冲） | TranslatePlaceholders / AppendByteaCasts 的 `LB := LB + C` 逐步拼接 |
| savepoint 名契约守卫 | `db.err` ValidateDbSavepointName（家族级单份，按 Kind 参数化） | 两适配器逐字重复的局部 ValidateSavepointName |

复用要点：

- 适配器既有临界区保持 `Acquire/try/finally/Release` 惯用法不改写；
  `sync.scoped` 的 Guard/WithLock 留给 S4 新池代码（改写存量无行为
  收益只添风险）。

- `{$H+}` 下 Char=AnsiChar（UTF-8 字节串），AppendChar 逐字节保真，
  含非 ASCII 字面量的 SQL 经翻译器不失真（基准 outlen=inlen 实证）。
- HexDecode 失败语义与原手搓版 fail-closed 等价；GetBlob 外层把
  EConvertError 折回 EPgError，保持"pg 层对外只抛 EPgError"边界契约。
- 两处扫描器 Reserve(Length(ASql))+16 起步，典型路径零再增长；
  重构后基准无回退（附录）。

### 6.2 Roadmap 复用（V2-S4..S6 直接采用现有单元）

| roadmap 需求 | core 资产（均已核实存在） | 决策 |
|---|---|---|
| 池等待队列（AcquireTimeoutMs） | `sync.semaphore.CreateSemaphore` | S4 直接用 |
| 连接空闲列表 | `collections.deque`（LIFO） | S4 实测弃用——泛型容器不管理 record 内接口字段的引用计数（悬垂指针实证），改编译器托管动态数组，LIFO 语义保留 |
| 预编译语句缓存（IDbPreparedCache） | `collections.lrucache` generic ILruCache<K,V>（自带 hit/miss 统计；swiss hashmap 家族打底） | S5 用 LRU 逐出，键=规范化 SQL |
| 获取超时/连接寿命 | `time.deadline.TDeadline` | S4 实际未引入：单段超时直传 `TryAcquireTimeout` 纳秒值 + `GetTickCount64` 惰性寿命检查已足，无组合截止需求；TDeadline 留给异步面 |
| migrate 批次 checksum | `checksum.crc32` | S6 记录在版本行防篡改 |
| tx/pool 簿记临界区 | `sync.scoped.ILockGuard` | tx 存量保持手工 try/finally 不改写；pool 归还路径因"先出锁、后放槽位"顺序约束同样保留 try/finally（增量文档 INC-1 注记 3） |
| 取消令牌（D8 预留位） | `async.cancellation` | 契约位直接引用该类型 |

### 6.3 例外自研（及理由）

| 自研物 | 为什么底座没有 |
|---|---|
| `db.err` 归一表 | 全仓无方言错误分类资产；且必须零后端依赖（自带 DB_SQLITE_* 码位常量），L2 db 层是唯一归属 |
| `IDbSavepointControl` | savepoint 是 db 域契约词汇，core 无对应概念 |
| 占位符/cast 两个 SQL 扫描状态机 | `text.scan` 是字节扫描原语，不识别 SQL 字面量/注释/dollar-quote；回调化通用扫描器为两处使用引入间接层，违背直线代码风格——保持显式双份 + 共享边界注释 |

### 6.4 反哺线索（非本 lane 范围，报备总控）

审计发现框架内 hex 手搓仍散布多处：`base.pas`、`mem.allocator.tracking`、
`http.url`、`http.base`、`tls.winssl.connection`、`tls.openssl.session`、
`tls.freepascal.earlydatareplay.dirstore` 各自维护 HexDigits 表或
HexValue 函数。`encoding.hex` 已能覆盖这些场景；建议各模块 lane 下次
触碰时顺手收敛，不值得专门开 slice。

同类收敛候选：`db.sqlite.migrate`（后端类表面）与 `db.migrate`
（IDbConnection 面）当前并存是收编过渡期的形态；G2 删 shim 后前者
由消费方迁移到统一层，即可整体退役。

---

## 7. 与 v1 落地版的差异与迁移

| 变更 | 性质 | 迁移 |
|---|---|---|
| 新增 db.err / 能力接口 / db.pool | 纯增量 | 无 |
| db.tx 嵌套语义 → savepoint 混合模型 | **唯一破坏性变更** | 见下 |
| EDbError 增加 Category/Constraint 字段 | 增量（v1 双码位字段保留） | 无 |
| TDbKind 增加 dbkUnknown（统一层自身错误，无后端归属） | 纯增量 | 无 |
| sqlite.pool 内部转调通用池 | 行为等价重构 | 门禁回归覆盖 |

savepoint 变更的影响面：统一层 `WithTransaction` 的既有消费者（当前仅
test_db_unified 与新消费方）——v1 落地至今无外部项目使用统一层事务
（9 个外部项目全部还在旧单元名 shim 上），因此变更窗口是免费的。
test_db_unified 的嵌套用例按 §5.1 新语义改写（"内层失败捕获后继续"
从"做不到"变为断言通过）。

## 8. Slice 路线图

| 批次 | 内容 | 门禁 |
|---|---|---|
| V2-S1 | db.err 归一表 + EDbError 扩展字段 + conformance 骨架（✅ 已落地：test_db_conformance 双后端全绿） | conformance(sqlite+pg) ✅ |
| V2-S2 | savepoint 混合模型（IDbSavepointControl + db.tx 重写 + pg/sqlite 双实现）（✅ 已落地：db.tx 编排 savepoint、无能力 fail-fast、RestoreDepth 删除、pg RollbackTxn 深度裂缝修复；落地注记见 §5.1） | conformance×2 ✅ + test_db_tx_v2 ✅ |
| V2-S3 | IDbBatchExecutor：事务包裹批执行 + pg 侧评估流水线化（pgx.Batch 先例）/COPY 二选一实测（✅ Tier1 已落地：双后端能力接口 + conformance 原子性用例 + 三路基准；Tier2 视基准差距另立项） | conformance×2 ✅ |
| V2-S4 | db.pool 通用池 + 策略 + 等待队列（✅ 已落地：IDbPoolCore 引用计数生命周期安全 + 十一组门禁全绿；sqlite.pool 收编改判 G2 随消费方迁移删除，理由见增量文档 INC-1 落地注记） | test_db_pool_v2 ✅ + bench_db_pool_stress ✅ |
| V2-S5 | IDbPreparedCache（sqlite 复用优先；✅ 已落地：透明空闲语句池 + IDbStmtCacheControl + migrate 自动 Clear，见增量文档 INC-3 落地注记；pg 侧待 D1 探测后补） | test_db_stmt_cache ✅ + bench_db_stmt_cache ✅ |
| V2-S6 | migrate 增强：批次 checksum 防篡改 + dry-run（✅ 已落地：三列版本表 + 规范形 CRC32 防篡改 + 旧两列表探测升级与自愈回填 + MigrateDryRun 结构化预览零写入；语义规格见 §5.4） | test_db_migrate_v2 ✅ |
| V2-S7 | IDbLargeObject：pg lo_* + sqlite3_blob_* 增量读写（INC-8）（✅ 已落地：统一 IDbBlobStream 流面 + 按模型分面开启能力 + 事务耦合 fail-fast；见增量文档 INC-8 落地注记） | test_db_largeobject ✅ + bench_db_blob_stream RSS 探针 ✅ |
| V2-S8 | 完善性收尾：INC-6 dbcBool 列类型精化 + INC-7 连接选项/查询超时 + G5 pg 错误定位字段（✅ 已落地：NULL 行级信号两后端统一、bool GetInt64 归一 1/0、语义诚实表入契约；缺口账本 G1/G4/G5 关闭，新登记 G8-G10 及处置） | conformance×2 ✅（bool 往返 + 双后端超时用例） |
| G2 | 消费方重构窗口：9 项目切 `nextpas.core.db.*` → 删 shim | 全仓 focused sweep |

每片独立可 landing；lane 纪律与 landing 流程同仓库规范。

> **V2 路线图已全部完成（S1-S8 ✅）。后续演进见 V3 工业级路线图**
> `2026-08-23-db-v3-industrial-roadmap.md`：后端扩张（MySQL/ODBC）、
> 架构收口（统一工厂/能力矩阵/观测钩子/异步挂载）、性能工业化
> （pg 语句缓存/池硬化/基准门禁化）三条主线，分片 S9+ 排期。

## 9. 明确不做

- ORM / 实体映射 / 关系加载（record-mapper 若做也是独立可选单元，不进核心）
- SQL 方言生成器 / QueryBuilder DSL
- DatabaseMetaData 全家桶（精度/刻度/大小写敏感性等展示元数据）
- 自造 Future/CancellationToken（等 core.async）
- 缓冲结果集
- Variant 通道
- 反射式行映射 / 命名参数糖（sqlx StructScan / Named Query 类，理由见 §10.3）
- 客户端缓存增量包 / Edit-Post 状态机（TDataset ApplyUpdates 模式，理由见 §12.3）

---

## 10. 对标复核：Go 与 Rust 数据库生态（2026-08-23）

对标对象：Go `database/sql`（stdlib）、`sqlx`、`pgx`；Rust `rusqlite`、
`diesel`、`sqlx-rs`。方法：逐机制对照本设计决策，判定三档——**已验证**
（先例背书既有选择）、**采纳增强**（吸收进 roadmap）、**明确拒绝**
（记录理由防翻烧饼）。

### 10.1 已验证（先例背书的既有决策）

| 机制 | 生态先例 | 本设计 |
|---|---|---|
| 最小驱动接口 + 可选能力接口 | database/sql 的 driver.Conn + driver.Tx / ConnPrepareContext 等可选接口 | D1 能力接口族（QueryInterface 探测） |
| 占位符统一、驱动侧翻译 | database/sql 全后端统一 `?` | TranslatePlaceholders（pg 侧 ? → $N） |
| 流式游标为唯一结果形态 | Rows.Next 拉模型（database/sql）、rusqlite Statement、sqlx fetch 均流式 | D5 |
| 错误 = 结构化载荷非类层次 | sqlx-rs Error::Database 下转 PgError 取 code/constraint/schema/table/column 字段 | D2 双码位 + 归一枚举 + Schema/Table/Column 保留位——字段集合同构 |
| 嵌套事务 = savepoint 自动降级 | rust-sqlx 内层 begin() 自动 SAVEPOINT；JDBC 3.0 setSavepoint | §5.1 savepoint 混合模型（V2-S2），先例确凿 |
| 回调/Guard 式事务安全 | rust-sqlx Transaction drop 未提交即回滚（RAII） | WithTransaction 异常安全自动回滚——同保证、异机制 |
| 连接池策略字段 | Go SetMaxOpenConns/MaxIdleConns/ConnMaxLifetime/ConnMaxIdleTime；sqlx PoolOptions max_connections/acquire_timeout/test_before_acquire/max_lifetime | D6 TDbPoolPolicy 一一对应 |
| 所有权即类型 | rusqlite 以借用检查器把 Statement 绑死在 Connection 上 | D3 COM 引用计数所有权——同目标、无编译器强制下的替代实现 |

### 10.2 采纳增强（已吸收）

> 契约形状、语义细则与门禁矩阵的落地规格见增量设计文档
> `2026-08-23-db-v2-increment-go-rust.md`（INC-1..5）。

1. **池策略补两字段**：`IdleTimeoutSec`（Go/sqlx 都有而 v1 缺的空闲回收）、
   `MinConnections`（预热下限）。已并入 §4.5 record。
2. **S3 批执行升格双目标**：pgx.Batch 的价值在网络流水线化（攒多查询
   一次往返），不只是事务分组。IDbBatchExecutor = 事务包裹 + pg 侧
   流水线/COPY 实测二选一。
3. **语句缓存失效钩子**：DDL 使 prepared 失效。S5 IDbPreparedCache 增加：
   migrate 完成后显式 Clear（复用 lrucache 整表逐出）。
4. **异步只经能力接口进入（Go 的教训制度化）**：见 D8 末条硬规则。

### 10.3 明确拒绝（记录理由）

| 生态特性 | 拒绝理由 |
|---|---|
| diesel 编译期查询 DSL | FPC 无宏设施可承载；类型安全由 D4 类型化绑定承担；SQL 保持字符串透明 |
| sqlx-rs query! 编译期校验 SQL | 同样依赖过程宏；最近似物 = conformance 套件 + CI 真库校验（D7） |
| sqlx/pgx 反射行映射（StructScan/RowToStruct） | 运行时类型错位面大，FPC RTTI 弱，违背 D4；record 映射若做也是独立可选单元 |
| sqlx Named Query（:name 重绑） | 违背位置参数契约；`:name` 解析对字符串字面量有误伤面 |
| pgx 原生二进制协议 | 文本协议无字节序/类型映射坑，本模块负载下性能不敏感；如需再按能力接口评估 |

---

## 11. 诚实缺口登记（2026-08-23 自审）

设计文档的完备性不等于实现完备性。本节登记已识别、尚未闭环的缺口与
处置，防止"文档看起来很全"掩盖真实边界。

| # | 缺口 | 影响 | 处置 |
|---|---|---|---|
| G1 | ~~`TDbColumnType` 无 Bool/时间/JSON~~ **已闭环（V2-S8）**：dbcBool 尾部追加 + 双后端自然映射 + NULL 行级信号统一；时间/JSON 按 INC-6 规则 3/4 维持 dbcText（无真实需求不加值） | 列类型信息粗粒度 | INC-6 决策规则驱动，conformance 红点先行 |
| G2 | NULL 读取语义此前只在代码注释里 | 消费方误用面 | 已成文进 CONTRACT §2.1（IsNull 先行，Get* 对 NULL 静默零值） |
| G3 | 线程亲和性契约此前未成文 | 并发误用无据可依 | 已成文进 CONTRACT §2.1（一连接一逻辑线程，跨线程经 pool 分发） |
| G4 | ~~查询级超时缺失~~ **已闭环（V2-S8）**：TDbConnectOptions + 工厂重载；pg statement_timeout / sqlite busy_timeout 各按原生语义落地，语义诚实表入 CONTRACT §2.1 | 长查询挂死无解 | INC-7 落地注记见增量文档 §6b |
| G5 | ~~Schema/Table/Column 错误定位字段恒空串~~ **已闭环（V2-S8）**：pg 经 PQresultErrorField('s'/'t'/'c') 填充并透传 EDbError；sqlite extended code 不携带定位信息，保持空（欠归一不错归一），conformance 断言钉住两侧 | 约束错误定位靠人肉 | 已兑现 |
| G6 | CONTRACT §2.2 曾残留"v1 不做归一"过时表述 | 文档漂移实锤 | 本次已修正；纪律：契约文档变更必须与代码同 slice landing |
| G7 | ~~conformance 套件尚不存在~~ **已兑现**：`test_db_conformance` 十套用例双后端全绿，并实证四项后端差异（CONTRACT §2.6） | "契约即门禁"从承诺变为事实 | 持续扩充；新差异一律先登记再修 |
| G8 | ~~pg 侧语句缓存缺失~~ **已闭环（V3-C1）**：PQprepare/PQexecPrepared 注册表 LRU，键 = bytea cast 后规范形；26000/42P05 双自愈覆盖 PREPARE 事务性；IDbStmtCacheControl 契约与 sqlite 侧一致，migrate 联动自动失效 | 高频点查场景 pg 侧无收益 | 已兑现；收益数据入基准册 |
| G9 | LISTEN/NOTIFY 无第一类封装（仅 Raw 逃生舱可达） | 推送订阅场景需裸 libpq | 处置 = 等 core.async 就绪随 INC-4 一并设计（通知是天然异步面）；同步模型下强行封装只会造出轮询假象 |
| G10 | COPY 批量装载未实现（INC-2 Tier2 遗留） | 大批量导入吞吐 | 处置 = 基准门控：现有批执行满足消费方前不立项；触发条件写入 INC-2 |

### 证伪条件（什么证据会推翻本设计）

架构支柱（能力接口/所有权/savepoint 混合/类型化边界/流式唯一）各有
独立生态背书，当前不推翻；但以下证据出现即触发重评：

1. S3 bulk-insert 三路基准显示文本协议在真实负载劣化 >2x → 重评二进制
   协议能力接口（§10.3 相应条目随之修订）。
2. conformance 套件暴露两后端语义无法经适配器弥合（如事务内 DDL 行为
   差异）→ 收窄统一契约面，而不是加方言开关。
3. G2 消费方迁移中发现占位符翻译器对真实 SQL 误伤 → 增加显式 $N 直通
   模式作为逃生舱。

---

## 12. 对标 VCL/LCL 数据栈：超越的定义与验收（2026-08-23）

总控要求：超越 Delphi VCL（TDataset 家族 + FireDAC）与 Lazarus LCL
（SQLdb/TSQLQuery）。**"超越"的操作定义**：不复制 TDataset 组件范式
（数据感知绑定属 UI 层职责，不在 core.db 非可视域内；未来 UI 模块/
消费层基于本家族自建），而是在数据访问工程实质的每个可测量轴上不低
于两者。

### 12.1 已超越的轴（当前即可主张）

| 轴 | VCL/LCL 现状 | 本设计 |
|---|---|---|
| 类型安全 | TField.Value = Variant，运行时类型错位 | D4 显式重载绑定，零 Variant |
| 错误语义 | EDatabaseError 单类 + 整型码 | D2 字段化载荷 + 受控归一 + 双码位并存 |
| 嵌套事务 | 标准 TDataset 无 savepoint 抽象 | §5.1 savepoint 混合模型 |
| 内存形态 | 缓冲 dataset 全量驻留 | D5 流式游标直读引擎缓冲 |
| 所有权 | Owner 树 + 手工 Free | D3 COM 引用计数，零手工释放 |
| 测试纪律 | 各驱动各测为主 | D7 conformance 即门禁（兑现 = S1，见 G7） |

### 12.2 未超越（差距 = 已排期工作量）

| 能力 | VCL/FireDAC 对应 | 现状 | 关闭路径 |
|---|---|---|---|
| 批量写入 | FireDAC Array DML | 无批执行面 | INC-2（S3）+ 三路基准 |
| 大对象流读写 | CreateBlobStream | 仅全量 TBytes | INC-8 已落地（IDbBlobStream 流面：RSS 恒定 0.2MB @128MB vs 物化 256MB） |
| 语句缓存 | FireDAC 资源选项 | 无 | INC-3（S5） |
| 连接池 | FireDAC FDManager 池 | sqlite 薄池非阻塞 | INC-1 已落地（db.pool：代理自动归还 + 六字段策略 + 等待队列 + 生命周期安全） |
| 后端一致性证明 | （无此概念） | 套件不存在 | V2-S1 最高优先 |

### 12.3 刻意分道（记录理由，防翻烧饼）

| TDataset 特性 | 不复制理由 |
|---|---|
| Edit/Post/Insert 状态机 + ApplyUpdates 客户端增量包 | 与 D5 冲突：客户端缓存是延迟写，失败语义复杂化；写路径走显式事务（含批量），一致性归数据库管 |
| Master-detail 自动联动 | 参数化查询直写即达；框架级隐式联动是魔法 |
| Lookup/Calculated 字段 | 数据集缓冲层之糖，无缓冲则无存在基础 |
| 设计期字段编辑器 / live data | IDE 域，core 非可视 |

### 12.4 超越验收指标（全绿才许说"超越了"）

| 判据 | 目标 | 门禁 |
|---|---|---|
| 批量写入 | 万行 insert 三路基准（逐条/事务循环/ExecuteBatch 合并）公开数据入附录，达 FireDAC Array DML 文献数量级 | S3 Tier1 ✅（pg batch 200ms vs autocommit 21846ms = 109×） |
| 大对象 | >64MB blob 流式读写内存恒定（RSS 不随体积线性涨） | S7 RSS+heaptrc 探针 ✅（0.2MB @128MB，物化对照 256MB） |
| 一致性 | conformance×2 全绿进常规门禁 | S1 起 ✅（test_db_conformance 已入列） |
| 性能税 | 适配层开销在真实负载基准 <5% | 附录持续跟踪 |
| 泄漏 | 全门禁 heaptrc 0 unfreed | 已达标，保持（十一门禁） |

---

## 附录：性能实测（2026-08-23，宿主 linux-x86_64，fpc 3.3.1 -O2）

| 探针 | 结果 | 结论 |
|---|---|---|
| 批量写入三路（万行 insert；2026-08-23） | sqlite: autocommit 50ms / txloop 32ms / batch 22ms；postgres: autocommit 21846ms / txloop 768ms / **batch 200ms（109× vs autocommit，3.8× vs txloop）** | 网络后端的往返税是数量级问题；IDbBatchExecutor 合并单次往返即达 Array-DML 同量级。源码 `bench_db_batch_insert.lpr` |
| 池并发压测（2026-08-23） | 读路径 8 线程 × 3000 轮锤 4 连接池：24000 ops / 403ms ≈ 59.5K ops/s，**工厂建连数恒等于 4**（零泄漏式新建，100% 经空闲队复用）；写槽 4 线程争用 800 轮零异常逃逸；heaptrc 0 unfreed | "释放即归还"在真实并发下成立且复用率不塌；生命周期安全（租约跨池 Free）由 test_db_pool_v2 契约守卫。源码 `bench_db_pool_stress.lpr` |
| 语句缓存对照（2026-08-23） | 点查 5 万次：nocache 316ms / cached 205ms = **1.54×**（hit_rate=1.0000）；多行扫描 2000 次：102ms / 98ms ≈ 1.04× | prepare 复用收益随语句复杂度增长；简单语句微基准是下界。嵌套安全由"借出即移除"语义保证（test_db_stmt_cache）。源码 `bench_db_stmt_cache.lpr` |
| 大对象 RSS 恒定（2026-08-23） | 128MB blob：全量物化 RSS 峰值增量 **256.2MB**（线性税对照）vs IDbBlobStream 分块流式 **0.2MB**（预算 16MB）；pg LO 64MB 客户端增量 **0.3MB** | §12.4"内存恒定不随体积线性涨"判据达标；VCL 式全量物化的内存税定量入册。源码 `bench_db_blob_stream.lpr` |
| 适配层 vs 原生直用（sqlite :memory: 万次 insert+select 微环） | native 20–25ms / adapter 23–27ms（两轮实测区间） | 单次操作开销 ≈0.2–0.3µs（~10%，且该微环被 sqlite3_prepare 主导；真实负载引擎时间占比更高，相对开销进一步稀释） |
| 占位符翻译器复杂度（text.builder 摊销缓冲，Reserve(Length)+16 起步） | 10KB→1ms、100KB→4ms、500KB→21ms、2MB→71ms（线性，outlen=inlen 零失真） | 复用 IStringBuilder 后较手搓逐步拼接（改前 2MB→77ms）略优且线性不变；≈28MB/s 扫描吞吐，KB 级真实 SQL 为微秒级 |
| 内存 | 全部十一门禁 heaptrc 0 unfreed（含池压测并发路径、RSS 探针） | 无泄漏税 |

源码：`core/benchmarks/nextpas.core.db/bench_db_adapter_overhead.lpr`、
`bench_db_translate_complexity.lpr`。后续：conformance 套件落地后把两探针
纳入常规门禁；db.pool 落地后补 pg 并发端到端基准。
