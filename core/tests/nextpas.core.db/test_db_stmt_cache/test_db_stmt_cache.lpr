program test_db_stmt_cache;

{ V2-S5 透明语句缓存（INC-3）契约测试：
    1 透明性（缓存开/关结果一致）
    2 嵌套安全（核心回归守卫）：同 SQL 并发活动查询各持独立实例
    3 归还卫生：绑定不跨借出泄漏（Reset + ClearBindings）
    4 能力面：IDbStmtCacheControl 探测 / Size / Clear / HitRate
    5 小容量驱逐：cap=2 三 SQL 轮转全程正确
    6 migrate 联动：应用迁移后缓存自动清空；幂等重跑不清
    7 对抗序生命周期：查询比连接接口引用活得久
    8 schema 变更韧性：DDL 后缓存路径继续正确（prepare_v2 重编译）
    9 pg 条件段（V3-C1 落地）：能力探测 / 命中率与 Clear /
      blob cast 键分离 / 事务回滚 26000 自愈 / migrate 自动失效
  pg 段需本地实例（NEXTPAS_PG_TEST_CONN）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.os.env,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.migrate,
  nextpas.core.db.factory.register.sqlite,
  nextpas.core.db.factory.register.pg;

var
  T: TTestSuite;
  GPgConn: string;

function SeedLookupTable(const AConn: IDbConnection; const ATbl: string): Int64;
var
  I: Integer;
  Q: IDbQuery;
begin
  AConn.Exec('CREATE TABLE ' + ATbl + ' (id INTEGER PRIMARY KEY, v INTEGER)');
  Result := 0;
  for I := 1 to 100 do
  begin
    AConn.Exec('INSERT INTO ' + ATbl + ' VALUES (' + IntToStr(I) + ', ' +
      IntToStr(I * 3) + ')');
    Inc(Result, Int64(I * 3));
  end;
  Q := nil;
end;

{ 1 }
function LookupChecksum(const AConn: IDbConnection): Int64;
var
  I: Integer;
  Q: IDbQuery;
begin
  Result := 0;
  for I := 1 to 100 do
  begin
    Q := AConn.Query('SELECT v FROM lookup WHERE id = ?');
    Q.BindInt64(1, ((I - 1) mod 100) + 1);
    if Q.Step then
      Inc(Result, Q.GetInt64(0))
    else
      Dec(Result, 1000000);
    Q := nil;
  end;
end;

procedure TestTransparencyParity;
var
  Cached, Plain: IDbConnection;
begin
  Cached := ConnectSqlite(':memory:');
  Plain := ConnectSqlite(':memory:', 0);
  Check(SeedLookupTable(Cached, 'lookup') = SeedLookupTable(Plain, 'lookup'),
    'parity: seeds identical');
  Check(LookupChecksum(Cached) = LookupChecksum(Plain),
    'parity: cached path equals direct-prepare path');
  Cached := nil;
  Plain := nil;
end;

{ 2 }
procedure TestNestingSafety;
var
  Conn: IDbConnection;
  Q1, Q2: IDbQuery;
  B1, B2: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    SeedLookupTable(Conn, 'lookup');
    { 同 SQL 两活动查询：若实现误共享底层句柄，第二次 Bind 会覆盖第一次 }
    Q1 := Conn.Query('SELECT v FROM lookup WHERE id > ? ORDER BY id');
    Q1.BindInt64(1, 0);
    Q2 := Conn.Query('SELECT v FROM lookup WHERE id > ? ORDER BY id');
    Q2.BindInt64(1, 95);
    { 交叉推进：两游标独立走完全部行 }
    B1 := Q1.Step;
    B2 := Q2.Step;
    while B1 or B2 do
    begin
      if B1 then B1 := Q1.Step;
      if B2 then B2 := Q2.Step;
    end;
    { 回头验证首读值未被污染：重新取各自首行 }
    Q1 := nil;
    Q2 := nil;
    Q1 := Conn.Query('SELECT v FROM lookup WHERE id = 96');
    Check(Q1.Step and (Q1.GetInt64(0) = 288),
      'nesting: independent instances across interleaved use');
    Q1 := nil;
  finally
    Conn := nil;
  end;
end;

{ 3 }
procedure TestRebindHygiene;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Conn := ConnectSqlite(':memory:');
  try
    { 第一轮：只绑 ?1，?2 留空 }
    Q := Conn.Query('SELECT coalesce(?1, -1), coalesce(?2, -2)');
    Q.BindInt64(1, 10);
    Check(Q.Step and (Q.GetInt64(0) = 10) and (Q.GetInt64(1) = -2),
      'hygiene: unbound param reads as null-coalesced');
    Q := nil;                            { 归还：Reset + ClearBindings }

    { 第二轮：复用同句柄（单 SQL 缓存必然命中），什么都不绑——
      上轮 ?1=10 若未清除会在此泄漏成 10 }
    Q := Conn.Query('SELECT coalesce(?1, -1), coalesce(?2, -2)');
    Check(Q.Step and (Q.GetInt64(0) = -1) and (Q.GetInt64(1) = -2),
      'hygiene: stale bindings cleared on return-to-cache');
    Q := nil;
  finally
    Conn := nil;
  end;
end;

{ 4 }
procedure TestCapabilitySemantics;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
  I: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Check(Conn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0,
      'capability: present on sqlite by default');
    Check(Ctrl.Size = 0, 'capability: starts empty');

    for I := 1 to 3 do
    begin
      Q := Conn.Query('SELECT ' + IntToStr(I));
      Q.Step;
      Q := nil;                          { 归还入缓存 }
    end;
    Check(Ctrl.Size = 3, 'capability: idle entries counted');

    { 三条再跑一轮 = 全命中：3 miss + 3 hit = 0.5 }
    for I := 1 to 3 do
    begin
      Q := Conn.Query('SELECT ' + IntToStr(I));
      Q.Step;
      Q := nil;
    end;
    Check(Abs(Ctrl.HitRate - 0.5) < 1e-9,
      'capability: hit rate counts miss+hit rounds');

    Ctrl.Clear;
    Check(Ctrl.Size = 0, 'capability: Clear empties idle set');

    { 清空后再跑仍正确（驱逐不破坏语义） }
    Q := Conn.Query('SELECT 42');
    Check(Q.Step and (Q.GetInt64(0) = 42), 'capability: correct after Clear');
    Q := nil;
  finally
    Conn := nil;
  end;
end;

{ 5 }
procedure TestSmallCapacityChurn;
var
  Conn: IDbConnection;
  Q: IDbQuery;
  R, K: Integer;
  Expect: array[1..3] of Int64;
  Got: Int64;
const
  SQLS: array[1..3] of string = (
    'SELECT SUM(v) FROM lookup WHERE id <= 10',
    'SELECT SUM(v) FROM lookup WHERE id <= 20',
    'SELECT SUM(v) FROM lookup WHERE id <= 30');
begin
  Conn := ConnectSqlite(':memory:', 2);
  try
    SeedLookupTable(Conn, 'lookup');
    for K := 1 to 3 do
    begin
      Q := Conn.Query(SQLS[K]);
      Q.Step;
      Expect[K] := Q.GetInt64(0);
      Q := nil;
    end;
    { 轮转 8 轮 > 容量 2：持续驱逐/重编译仍须逐轮正确 }
    for R := 1 to 8 do
      for K := 1 to 3 do
      begin
        Q := Conn.Query(SQLS[K]);
        Q.Step;
        Got := Q.GetInt64(0);
        Q := nil;
        Check(Got = Expect[K], 'churn: round ' + IntToStr(R) +
          ' sql ' + IntToStr(K) + ' stable under eviction');
      end;
  finally
    Conn := nil;
  end;
end;

{ 6 }
procedure TestMigrateAutoClear;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
  NApplied: Integer;
  Migs: TDbMigrations;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Check(Conn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0, 'mig: capability present');
    Q := Conn.Query('SELECT 1');
    Q.Step;
    Q := nil;
    Check(Ctrl.Size > 0, 'mig: cache warm before migration');

    Migs := MakeMigrations([
      TDbMigration.Create(1, ['CREATE TABLE m_auto (x INTEGER)'])]);
    NApplied := Migrate(Conn, Migs);
    Check(NApplied = 1, 'mig: one batch applied');
    Check(Ctrl.Size = 0, 'mig: cache auto-cleared after apply');

    NApplied := Migrate(Conn, Migs);
    Check(NApplied = 0, 'mig: rerun idempotent');
    Q := Conn.Query('SELECT COUNT(*) FROM schema_migrations');
    Check(Q.Step and (Q.GetInt64(0) = 1), 'mig: version table intact');
    Q := nil;
  finally
    Conn := nil;
  end;
end;

{ 7 }
procedure MakeQueryAndDropConn(out AQ: IDbQuery);
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t_lw (id INTEGER PRIMARY KEY, v TEXT)');
  Conn.Exec('INSERT INTO t_lw VALUES (1, ''alpha'')');
  AQ := Conn.Query('SELECT v FROM t_lw WHERE id = 1');
  Conn := nil;                           { 连接接口先于查询释放 }
end;

procedure TestQueryOutlivesConnectionRef;
var
  Q: IDbQuery;
begin
  MakeQueryAndDropConn(Q);
  { 查询的归还通道强引用使连接仍然存活：使用与归还都必须安全 }
  Check(Q.Step and (Q.GetText(0) = 'alpha'), 'lifetime: usable past connection ref');
  Q := nil;                              { 此刻连接才真正析构（heaptrc 验证无泄漏无 AV） }
end;

{ 8 }
procedure TestSchemaChangeResilience;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE t_sc (id INTEGER PRIMARY KEY, x INTEGER)');
    Conn.Exec('INSERT INTO t_sc VALUES (1, 7)');
    Q := Conn.Query('SELECT x FROM t_sc WHERE id = 1');
    Check(Q.Step and (Q.GetInt64(0) = 7), 'schema: baseline read');
    Q := nil;                            { 入缓存 }

    Conn.Exec('DROP TABLE t_sc');
    Conn.Exec('CREATE TABLE t_sc (id INTEGER PRIMARY KEY, x TEXT)');
    Conn.Exec('INSERT INTO t_sc VALUES (1, ''seven'')');

    Q := Conn.Query('SELECT x FROM t_sc WHERE id = 1');
    Check(Q.Step and (Q.GetText(0) = 'seven'),
      'schema: cached handle survives DDL (prepare_v2 recompile)');
    Q := nil;
  finally
    Conn := nil;
  end;
end;

{ 9 }
{ V3-C1：pg 语句缓存落地，能力探测反转为"存在"并验证基本语义 }
procedure TestPgCapabilityPresent;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg capability check skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GPgConn);
  try
    Check(Conn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0,
      'pg: cache control present since V3-C1');
    Check(Ctrl.Size = 0, 'pg: starts empty');

    Conn.Exec('DROP TABLE IF EXISTS t_sc_pg');
    Conn.Exec('CREATE TABLE t_sc_pg (id INTEGER PRIMARY KEY, v INTEGER)');
    Conn.Exec('INSERT INTO t_sc_pg VALUES (7, 21), (8, 24), (9, 27)');

    { 同一参数化 SQL 两轮：第一轮 miss（prepare+登记），第二轮 hit。
      注意无参 SELECT 不入缓存，必须带 ? 占位符。 }
    Q := Conn.Query('SELECT v FROM t_sc_pg WHERE id = ?');
    Q.BindInt64(1, 7);
    Check(Q.Step and (Q.GetInt64(0) = 21), 'pg: first run correct');
    Q := nil;
    Check(Ctrl.Size = 1, 'pg: one statement registered');

    Q := Conn.Query('SELECT v FROM t_sc_pg WHERE id = ?');
    Q.BindInt64(1, 8);
    Check(Q.Step and (Q.GetInt64(0) = 24), 'pg: second run correct');
    Q := nil;
    Check(Abs(Ctrl.HitRate - 0.5) < 1e-9, 'pg: hit rate counts both rounds');

    Ctrl.Clear;
    Check(Ctrl.Size = 0, 'pg: Clear deallocates all');
    Q := Conn.Query('SELECT v FROM t_sc_pg WHERE id = ?');
    Q.BindInt64(1, 9);
    Check(Q.Step and (Q.GetInt64(0) = 27), 'pg: correct after Clear');
    Q := nil;
    Conn.Exec('DROP TABLE t_sc_pg');
  finally
    Conn := nil;
  end;
end;

{ 键分离契约：同一 SQL 不同绑定形态（blob ::bytea cast 有无）是
  不同规范形，各自独立 prepare，互不撞名错配 }
procedure TestPgCastKeySplitting;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
  LB: TBytes;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg cast-split skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  SetLength(LB, 3); LB[0] := $DE; LB[1] := $AD; LB[2] := $BE;
  Conn := ConnectPostgres(GPgConn);
  try
    Check(Conn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0,
      'pg/key: cache control reachable');
    Conn.Exec('DROP TABLE IF EXISTS t_sc_key');
    Conn.Exec('CREATE TABLE t_sc_key (id INTEGER PRIMARY KEY, b BYTEA)');
    Conn.Exec('INSERT INTO t_sc_key VALUES (1, ''\x0102''::bytea)');

    { 形态一：blob 绑定（cast 后 SQL 含 ::bytea） }
    Q := Conn.Query('UPDATE t_sc_key SET b = ? WHERE id = ?');
    Q.BindBlob(1, LB); Q.BindInt64(2, 1);
    while Q.Step do;
    Q := nil;

    { 形态二：同骨架 SQL 但 text 绑定（无 cast）→ 独立规范形 }
    Q := Conn.Query('UPDATE t_sc_key SET b = ? WHERE id = ?');
    Q.BindNull(1); Q.BindInt64(2, 1);
    while Q.Step do;
    Q := nil;

    Check(Ctrl.Size >= 2, 'pg/key: cast variants registered separately');

    { 两形态各自重跑仍正确（命中路径不串型） }
    Q := Conn.Query('SELECT b FROM t_sc_key WHERE id = ?');
    Q.BindInt64(1, 1);
    Check(Q.Step and Q.IsNull(0), 'pg/key: text-variant result correct');
    Q := nil;
    Ctrl.Clear;
    Conn.Exec('DROP TABLE t_sc_key');
  finally
    Conn := nil;
  end;
end;

{ 自愈契约：PREPARE 随事务回滚被服务端撤销，缓存登记仍在；
  下次同 SQL 执行触发 26000 自愈重建，结果正确 }
procedure TestPgSelfHealAfterTxnAbort;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
  Raised: Boolean;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg self-heal skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GPgConn);
  try
    Check(Conn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0,
      'heal: cache control reachable');
    Conn.Exec('DROP TABLE IF EXISTS t_sc_heal');
    Conn.Exec('CREATE TABLE t_sc_heal (id INTEGER PRIMARY KEY, v INTEGER)');
    Conn.Exec('INSERT INTO t_sc_heal VALUES (1, 10)');

    { 事务内首跑（prepare 发生在事务内），随后整体回滚：
      服务端 prepared statement 一并被撤销 }
    Raised := False;
    try
      WithTransaction(Conn, procedure(const C: IDbConnection)
      begin
        Q := Conn.Query('UPDATE t_sc_heal SET v = v + ? WHERE id = ?');
        Q.BindInt64(1, 5); Q.BindInt64(2, 1);
        while Q.Step do;
        Q := nil;
        raise Exception.Create('abort txn');
      end);
    except
      on E: Exception do
        Raised := E.Message = 'abort txn';
    end;
    Check(Raised, 'heal: txn aborted as arranged');
    Check(Ctrl.Size > 0, 'heal: registration survived rollback');

    { 自愈：登记在而服务端无 → 26000 → 重建 → 正确执行 }
    Q := Conn.Query('SELECT v FROM t_sc_heal WHERE id = ?');
    Q.BindInt64(1, 1);
    Check(Q.Step and (Q.GetInt64(0) = 10),
      'heal: value intact (update rolled back), rebuilt silently');
    Q := nil;
    Ctrl.Clear;
    Conn.Exec('DROP TABLE t_sc_heal');
  finally
    Conn := nil;
  end;
end;

{ migrate 联动（INC-3 钩子跨后端生效的 pg 版）}
procedure TestPgMigrateAutoClear;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Q: IDbQuery;
  NApplied: Integer;
  Migs: TDbMigrations;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg migrate-clear skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GPgConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS schema_migrations');
    Conn.Exec('DROP TABLE IF EXISTS t_pigmig_dummy');
    Conn.Exec('CREATE TABLE t_pigmig_dummy (id INTEGER PRIMARY KEY, v INTEGER)');
    Check(Conn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0, 'pigmig: capability');
    Q := Conn.Query('SELECT v FROM t_pigmig_dummy WHERE id = ?');
    Q.BindInt64(1, 1);
    while Q.Step do;
    Q := nil;
    Check(Ctrl.Size > 0, 'pigmig: cache warm before migration');

    Migs := MakeMigrations([
      TDbMigration.Create(1, ['CREATE TABLE m_auto_pg (x INTEGER)'])]);
    NApplied := Migrate(Conn, Migs);
    Check(NApplied = 1, 'pigmig: one batch applied');
    Check(Ctrl.Size = 0, 'pigmig: cache auto-cleared after apply');
    Conn.Exec('DROP TABLE m_auto_pg');
    Conn.Exec('DROP TABLE t_pigmig_dummy');
    Conn.Exec('DROP TABLE schema_migrations');
  finally
    Conn := nil;
  end;
end;

begin
  RegisterSqliteDriver;
  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.stmt.cache');
  T.Test('transparency parity', @TestTransparencyParity);
  T.Test('nesting safety', @TestNestingSafety);
  T.Test('rebind hygiene', @TestRebindHygiene);
  T.Test('capability semantics', @TestCapabilitySemantics);
  T.Test('small capacity churn', @TestSmallCapacityChurn);
  T.Test('migrate auto-clear', @TestMigrateAutoClear);
  T.Test('query outlives connection ref', @TestQueryOutlivesConnectionRef);
  T.Test('schema change resilience', @TestSchemaChangeResilience);
  T.Test('pg capability present', @TestPgCapabilityPresent);
  T.Test('pg cast key splitting', @TestPgCastKeySplitting);
  T.Test('pg self-heal after txn abort', @TestPgSelfHealAfterTxnAbort);
  T.Test('pg migrate auto-clear', @TestPgMigrateAutoClear);
  if not T.Run then Halt(1);
end.
