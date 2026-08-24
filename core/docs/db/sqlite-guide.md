# nextpas.core.db.sqlite 助手模块（B7：pool / tx / migrate）

本级文档面向**消费方**（如 mailGateway888 proxy888 存储层）。先读完[代码契约](./CONTRACT.md)，
这里只讲三个助手的用法、边界与典型组合。

## 1. 概览

B7 之前 core 只提供连接表面（`TSqliteDb`/`TSqliteQuery`）。B7 新增的 L2 助手中，
事务助手经 `nextpas.core.db.sqlite` 门面 re-export；连接池与迁移已分别由
统一层 `nextpas.core.db.pool` / `nextpas.core.db.migrate` 承担
（G2 起 v1 `TSqlitePool` 与 `db.sqlite.migrate` 后端类表面退役）：

| 模块 | 资产 | 解决什么 |
|------|------|----------|
| `db.pool` | `TDbPool` | 跨后端读池+单写者：接口租约代理、等待队列、惰性回收、探活、泄漏检测 |
| `sqlite.tx` | `WithTransaction`/`BeginTxn`… | procedure 式事务体自动提交/回滚、嵌套保护、防裸事务混用 |
| `db.migrate` | `Migrate`/`TDbMigration` | schema 版本化（跨后端）：幂等迁移、每批一个事务、checksum 防篡改 + dry-run |

组合约定：

- **写**：`pool.Writer` 拿单写连接代理，事务用统一层 `WithTransaction(AConn)`
  （写连接上天然单写者，无需额外锁）。
- **读**：`pool.Acquire` 取代理，用完置空接口引用即归还；读不包事务
  （WAL 快照下读到一致数据）。
- **建库**：启动时 `Migrate(writerConn, migrations)` 跑 schema 版本。

## 2. 连接池（`nextpas.core.db.pool`）

```pascal
var
  Pool: TDbPool;
  Conn: IDbConnection;
begin
  Pool := TDbPool.Create(
    function: IDbConnection               { 连接工厂 }
    begin
      Result := ConnectSqlite('/var/data/gw.db');
    end,
    TDbPoolPolicy.Default);
  try
    Conn := Pool.Acquire;                 { 读：接口代理租约 }
    try
      var Q := Conn.Query('SELECT ...');
      ...
      Q := nil;                           { 归还 = 置空引用 }
    finally
      Conn := nil;
    end;
    { 写走专用写连接：先取一次租约，回调内复用同一连接 }
    var W := Pool.Writer;
    try
      WithTransaction(W, procedure            { 统一层 savepoint 混合模型 }
        begin
          W.Exec('INSERT INTO ...');          { 回调内不得再取 Pool.Writer——会自等超时 }
        end);
    finally
      W := nil;
    end;
  finally
    Pool.Free;
  end;
end;
```

边界（务必知道）：

- 租约是**接口代理**：归还 = 置空接口引用，无手工 Release；误持长租会触发
  泄漏检测报告（可开关）。
- `Writer` 全池仅一条，被占用期间再次 `Writer` 按 `AcquireTimeoutMs` 排队或抛
  `decCapacity`。
- WAL/busy_timeout 经 `TDbConnectOptions` 在工厂里设置（`ConnectSqlite(path,
  opts)`），不再由池代设。
- 单写者语义：池内所有连接指向**同一 DB 文件**；并发写必须在同一时刻只有一个事务持有者。
  完整策略面（容量/等待队列/探活/泄漏检测）见 CONTRACT §2.7。

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

## 4. 迁移（`nextpas.core.db.migrate`，统一面）

```pascal
var
  Applied: Integer;
begin
  Applied := Migrate(WriterConn, MIGRATIONS);   { AConn: IDbConnection }
  if Applied > 0 then WriteLn(Applied, ' new migrations applied');
end;
```

构建迁移列表：

```pascal
var
  M: TDbMigrations;
begin
  M := MakeMigrations([
    TDbMigration.Create(1, ['CREATE TABLE messages (id INTEGER PRIMARY KEY, ...)']),
    TDbMigration.Create(2, ['CREATE INDEX idx_messages_mbox ON messages (mailbox_id)',
                                'INSERT INTO messages (id) VALUES (0)']),
    TDbMigration.Create(3, ['ALTER TABLE messages ADD COLUMN flags INT NOT NULL DEFAULT 0'])]);
end;
```

语义：

- 版本表固定名 `schema_migrations`（`version INTEGER PRIMARY KEY,
  applied_at TEXT, checksum TEXT`）。
- 列表必须**严格升序且无重复**，否则抛错。
- **幂等**：已应用版本跳过；同一列表跑两遍，第二次返回 0，库状态不变。
- **每批迁移在一个事务内**（经由统一层 WithTransaction），版本行同批写入：
  任一步失败整批回滚、版本不记录，修复后重跑即可。
- **checksum 防篡改**：已应用版本的记录校验和与当前列表不符即拒绝；
  历史空 checksum 条目自动自愈回填。
- **dry-run**：`MigrateDryRun` 返回结构化计划（将应用/已应用/不匹配），零写入。
- **版本校验（上下限）**：已应用版本不在列表即拒绝——
  - 高于列表最大 ⇒ 库超前于代码（防降级/忘带迁移）；
  - 低于列表最小 ⇒ 旧迁移被删过。

边界：

- 迁移列表**只增不改**：发布新代码只追加版本，不得改写旧版本内容。
- 版本号用 `Int64`（可用单调递增整数或时间戳），不承诺语义排序之外的任何约定。
- 完整契约见 CONTRACT §2.4；G2 起旧 `db.sqlite.migrate` 后端类表面已退役，
  一律走本统一面。

## 5. 组合示例（网关 storage 启动序列）

```pascal
var
  Opts: TDbConnectOptions;
begin
  Opts := TDbConnectOptions.Default;
  Opts.BusyTimeoutMs := 5000;
  Pool := TDbPool.Create(
    function: IDbConnection
    begin
      Result := ConnectSqlite(DataDir + 'gateway.db', Opts);
    end,
    TDbPoolPolicy.Default);
  try
    W := Pool.Writer;
    try
      W.Exec('PRAGMA foreign_keys = ON');   { 每连接会话级，写连接上设置即可 }
      Migrate(W, Migrations);               { 统一迁移面 }
    finally
      W := nil;
    end;
    { 之后：读用 Acquire（置空归还），脚本/投递写用 WithTransaction(Pool.Writer 取一次的租约, …) }
  finally
    Pool.Free;
  end;
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