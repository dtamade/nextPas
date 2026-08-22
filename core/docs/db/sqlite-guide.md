# nextpas.core.db.sqlite 助手模块（B7：pool / tx / migrate）

本级文档面向**消费方**（如 mailGateway888 proxy888 存储层）。先读完[代码契约](./CONTRACT.md)，
这里只讲三个助手的用法、边界与典型组合。

## 1. 概览

B7 之前 core 只提供连接表面（`TSqliteDb`/`TSqliteQuery`）。B7 新增三个 L2 助手，全部经
`nextpas.core.db.sqlite` 门面 re-export：

| 模块 | 资产 | 解决什么 |
|------|------|----------|
| `sqlite.pool` | `TSqlitePool` | 读连接按需创建/复用、硬容量上限、统一 WAL+busy_timeout、单写者形式化 |
| `sqlite.tx` | `WithTransaction`/`BeginTxn`… | procedure 式事务体自动提交/回滚、嵌套保护、防裸事务混用 |
| `sqlite.migrate` | `Migrate`/`TSqliteMigration` | schema 版本化：幂等迁移、每批一个事务、版本上下限校验 |

三个助手之间的组合约定：

- **写**：`pool.Writer` 拿专用写连接，事务用 `WithTransaction`（写连接上天然单写者，无需额外锁）。
- **读**：`pool.Acquire`…`pool.Release`，读不包事务（WAL 快照下读到一致数据）。
- **建库**：启动时 `Migrate(writer, migrations)` 跑 schema 版本。

## 2. 连接池 `TSqlitePool`

```pascal
var
  Pool: TSqlitePool;
  R: TSqliteDb;
begin
  Pool := TSqlitePool.Create('/var/data/gw.db',  { 路径 }
    16,        { 读连接硬上限（容量） }
    5000,      { busy_timeout ms，对所有连接统一设置 }
    True);     { 统一开启 WAL }
  try
    R := Pool.Acquire;
    try
      Q := R.Query('SELECT ...'); ...
    finally
      Pool.Release(R);
    end;
    { 写走专用写连接： }
    WithTransaction(Pool.Writer, procedure
      begin
        Pool.Writer.Exec('INSERT INTO ...');
      end);
  finally
    Pool.Close;
    Pool.Free;
  end;
end;
```

边界（务必知道）：

- `Acquire` **非阻塞**：达到 `AMaxConnections` 且无空闲连接时抛 `ESqlitePoolError`（消息含
  `exhausted`）。薄池不做等待队列入池——请按读并发度配容量，读密集场景配足。
- 写连接由池所有、懒创建，**不可 `Release`**（会抛错），只能随 `Pool.Close` 释放。
- `Close` 幂等：释放空闲连接与写连接；关闭后 `Acquire`/`Writer` 抛错。**已借出的连接**仍归
  调用方所有，`Release` 时被直接销毁——所以借出后务必归还。
- `Release` 只接受 `Acquire` 借出的连接（池不追踪身份，误传给陌生连接会造成 double-use）。
- `TotalConnections` 只统计读连接（不含写连接）。
- WAL 对 `':memory:'` 无意义，自动跳过；`AWal=False` 可整体关掉。
- 单写者语义：池内所有连接指向**同一 DB 文件**；并发写必须在同一时刻只有一个事务持有者。
  `WithTransaction(Pool.Writer, …)` 天然满足——不同线程同时对该连接做事务控制是不支持的
  （FULLMUTEX 保证语句安全，不保证事务状态协调）。

## 3. 事务助手 `sqlite.tx`

```pascal
WithTransaction(Db, procedure
  begin
    Db.Exec('INSERT INTO a ...');
    Db.Exec('INSERT INTO b ...');   { 与上面同生共死 }
  end);
```

语义：

- 成功 → 自动 `COMMIT`；**任何异常 → 自动 `ROLLBACK` 并重抛原异常**（原异常消息不被吞）。
- **"procedure 式 Exec" 隔离**：回调内任意次 `Exec` 原子（all-or-nothing）。
- **嵌套保护（计数式）**：同一连接上内层 `WithTransaction` 只加深深度计数，不另开 SQLite
  事务；最外层 `COMMIT`/`ROLLBACK` 决定一切。外层回滚时内层已“提交”的内容一并撤销。

```pascal
WithTransaction(Db, procedure
  begin
    Db.Exec('INSERT INTO t (v) VALUES (''outer'')');
    WithTransaction(Db, procedure     { 内层：只加深计数 }
      begin
        Db.Exec('INSERT INTO t (v) VALUES (''inner'')');
      end);
    raise Exception.Create('oops');   { 外层失败 ⇒ 内外全部回滚 }
  end);
```

显式控制三件套（与 `WithTransaction` 同一计数体系，必须配对）：

```pascal
BeginTxn(Db);          // 或 BeginTxn(Db, True) → BEGIN IMMEDIATE（伊始取写锁）
try
  Db.Exec(...);
  CommitTxn(Db);
except
  RollbackTxn(Db);     // 已配对失败也可再 RollbackTxn 收拾
  raise;
end;
```

守卫与边界：

- 裸 `Exec('BEGIN')` 与助手混用被**拒绝**：连接上已有外来事务时 `BeginTxn` 抛
  `ESqliteTxError`；助手事务被外部偷偷关闭后 `CommitTxn` 抛错（`RollbackTxn` 可清簿记）。
- `CommitTxn`/`RollbackTxn` 没有对应 `BeginTxn` 时抛 `ESqliteTxError`。
- 一条连接的事务控制同一时刻只允许一个线程（见池的单写者约定）。
- 回调里 `Db` 必须活得比 `WithTransaction` 久；回调不得在事务中 `Free` 连接。

## 4. 迁移助手 `sqlite.migrate`

```pascal
const
  MIGRATIONS: TSqliteMigrations = ...  { 见下 }

var
  Applied: Integer;
begin
  Applied := Migrate(WriterDb, MIGRATIONS);
  if Applied > 0 then WriteLn(Applied, ' new migrations applied');
end;
```

构建迁移列表：

```pascal
var
  M: TSqliteMigrations;
begin
  M := MakeMigrations([
    TSqliteMigration.Create(1, ['CREATE TABLE messages (id INTEGER PRIMARY KEY, ...)']),
    TSqliteMigration.Create(2, ['CREATE INDEX idx_messages_mbox ON messages (mailbox_id)',
                                'INSERT INTO messages (id) VALUES (0)']),
    TSqliteMigration.Create(3, ['ALTER TABLE messages ADD COLUMN flags INT NOT NULL DEFAULT 0'])]);
end;
```

语义：

- 版本表固定名 `schema_migrations`（`version INTEGER PRIMARY KEY, applied_at TEXT`）。
- 列表必须**严格升序且无重复**，否则 `ESqliteMigrateError`。
- **幂等**：已应用版本跳过；同一列表跑两遍，第二次返回 0，库状态不变。
- **每批迁移在一个事务内**（经由 `WithTransaction`），版本行同批写入：任一步失败整批回滚、
  版本不记录，修复后重跑即可。
- **版本校验（上下限）**：已应用版本不在列表即拒绝——
  - 高于列表最大 ⇒ 库超前于代码（`ahead`，防降级/忘带迁移）；
  - 低于列表最小 ⇒ 旧迁移被删过（`below`）；
  - 中空 ⇒ 对应版本缺失（`missing`）。
  错误对象带 `Version` 属性（引发问题的版本号）。
- `MigrationVersion(ADb)` 返回当前最高已应用版本（无表/空表 = 0）。

边界：

- 迁移列表**只增不改**：发布新代码只追加版本，不得改写旧版本内容。
- 版本号用 `Int64`（可用单调递增整数或时间戳），不承诺语义排序之外的任何约定。

## 5. 组合示例（网关 storage 启动序列）

```pascal
Pool := TSqlitePool.Create(DataDir + 'gateway.db', 16, 5000, True);
try
  WithTransaction(Pool.Writer, procedure
    begin
      Pool.Writer.Exec('PRAGMA foreign_keys = ON');   { 每连接会话级，写连接上设置即可 }
    end);
  Migrate(Pool.Writer, Migrations);
  { 之后：读用 Acquire/Release，脚本/投递写用 WithTransaction(Pool.Writer, …) }
finally
  Pool.Close;
  Pool.Free;
end;
```

> 注意：`PRAGMA foreign_keys` 是**每连接**会话设置；池模式下应对每个 Acquire 出的连接设置
> （或用 `sqlite.compat` 层包一层）。B7 池只统一 WAL + busy_timeout，不越权设置其他 PRAGMA。

## 6. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db.sqlite/test_sqlite_pool
make focused FOCUS=core/tests/nextpas.core.db.sqlite/test_sqlite_tx
make focused FOCUS=core/tests/nextpas.core.db.sqlite/test_sqlite_migrate
```

每个目标含 heaptrc 泄漏门禁（`0 unfreed memory blocks`）。