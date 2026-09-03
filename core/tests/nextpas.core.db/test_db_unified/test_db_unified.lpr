program test_db_unified;

{ nextpas.core.db 统一层契约测试：
  IDbConnection/IDbQuery 全类型往返、NULL/列类型、错误转译（EDbError
  双码位）、接口引用计数生命周期、泛化事务（提交/回滚重抛/嵌套恢复/
  误用守卫）、泛化迁移（幂等/乱序/上下限）。全部走门面
  nextpas.core.db，SQLite :memory: 后端。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db,
  nextpas.core.db.factory,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.redis.adapter,
  nextpas.core.db.dm.adapter;

var
  GBuiltinEnsured: Boolean = False;
  T: TTestSuite;

function OpenSqliteU(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := nextpas.core.db.sqlite.adapter.ConnectSqlite(ADsn, AOptions); end;
function OpenPgU(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := nextpas.core.db.pg.adapter.ConnectPostgres(ADsn, AOptions); end;
function OpenMysqlU(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := nextpas.core.db.mysql.adapter.ConnectMysql(ADsn, AOptions); end;
function OpenOdbcU(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := nextpas.core.db.odbc.adapter.ConnectOdbc(ADsn, AOptions); end;
function OpenRedisU(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := nextpas.core.db.redis.adapter.ConnectRedis(ADsn, '', 0, AOptions); end;
function OpenDmU(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; inline;
begin Result := nextpas.core.db.dm.adapter.ConnectDm(ADsn, AOptions); end;

procedure EnsureBuiltinDrivers; inline;
begin
  if GBuiltinEnsured then Exit;
  if not DbDriverExists('sqlite') then DbRegisterDriver(TBuiltinDriver.Create('sqlite', dbkSqlite, @OpenSqliteU));
  if not DbDriverExists('postgres') then DbRegisterDriver(TBuiltinDriver.Create('postgres', dbkPostgres, @OpenPgU));
  if not DbDriverExists('mysql') then DbRegisterDriver(TBuiltinDriver.Create('mysql', dbkMysql, @OpenMysqlU));
  if not DbDriverExists('odbc') then DbRegisterDriver(TBuiltinDriver.Create('odbc', dbkOdbc, @OpenOdbcU));
  if not DbDriverExists('redis') then DbRegisterDriver(TBuiltinDriver.Create('redis', dbkRedis, @OpenRedisU));
  if not DbDriverExists('dm') then DbRegisterDriver(TBuiltinDriver.Create('dm', dbkDm, @OpenDmU));
  GBuiltinEnsured := True;
end;

const
  { sqlite3.h SQLITE_CONSTRAINT }
  SQLITE_CONSTRAINT_CODE = 19;

{ ==== helpers ==== }

function CountRows(const AConn: IDbConnection; const ASql: string): Int64;
var
  Q: IDbQuery;
begin
  Q := AConn.Query(ASql);
  Check(Q.Step, 'count query returns a row');
  Result := Q.GetInt64(0);
end;

procedure ExpectDbError(const AProc: TProc; const AMsg: string);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc();
  except
    on E: EDbError do
      LRaised := True;
  end;
  Check(LRaised, AMsg);
end;

{ ==== connection basics ==== }

procedure TestKindAndRaw;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  Check(Conn.Kind = dbkSqlite, 'kind = dbkSqlite');
  Check(Conn.Raw <> nil, 'raw handle exposed');
  Conn := nil;
end;

procedure TestExecChangesRoundtrip;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
  Conn.Exec('INSERT INTO t (v) VALUES (''a'')');
  Conn.Exec('INSERT INTO t (v) VALUES (''b'')');
  CheckEqual(Int64(1), Conn.Changes, 'changes = 1 after last insert');
  CheckEqual(Int64(2), CountRows(Conn, 'SELECT COUNT(*) FROM t'), 'row count');
end;

{ ==== query surface ==== }

procedure TestAllTypesRoundtrip;
var
  Conn: IDbConnection;
  Q: IDbQuery;
  LB: TBytes;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (ti INTEGER, tr REAL, tt TEXT, tb BLOB)');
  Q := Conn.Query('INSERT INTO t (ti, tr, tt, tb) VALUES (?, ?, ?, ?)');
  Q.BindInt64(1, -1234567890123);
  Q.BindDouble(2, 2.5);
  Q.BindText(3, 'héllo-中文');
  LB := TBytes.Create($00, $FF, $7F, $80);
  Q.BindBlob(4, LB);
  Check(not Q.Step, 'insert step terminates');

  Q := Conn.Query('SELECT ti, tr, tt, tb FROM t');
  Check(Q.Step, 'select row');
  CheckEqual(Int64(-1234567890123), Q.GetInt64(0), 'int64 roundtrip');
  Check(abs(Q.GetDouble(1) - 2.5) < 1e-9, 'double roundtrip');
  CheckEqual('héllo-中文', Q.GetText(2), 'utf8 text roundtrip');
  CheckEqual(Length(LB), Length(Q.GetBlob(3)), 'blob length');
  Check(Q.GetBlob(3)[1] = $FF, 'blob byte content');
  Check(not Q.Step, 'single row only');
end;

procedure TestNullAndColumnMeta;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (n INTEGER, s TEXT)');
  Conn.Exec('INSERT INTO t VALUES (NULL, ''x'')');
  Q := Conn.Query('SELECT n, s FROM t');
  Check(Q.Step, 'row present');
  Check(Q.IsNull(0), 'null detected via IsNull');
  Check(Q.ColumnType(0) = dbcNull, 'column type dbcNull');
  Check(Q.ColumnType(1) = dbcText, 'column type dbcText');
  CheckEqual('', Q.GetText(0), 'NULL text reads as empty');
  CheckEqual(2, Q.ColumnCount, 'column count');
  CheckEqual('n', Q.ColumnName(0), 'column name 0');
  CheckEqual('s', Q.ColumnName(1), 'column name 1');
end;

procedure TestBindNullExplicit;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (v TEXT)');
  Q := Conn.Query('INSERT INTO t (v) VALUES (?)');
  Q.BindNull(1);
  Check(not Q.Step, 'insert with null bind');
  Q := Conn.Query('SELECT v FROM t');
  Check(Q.Step and Q.IsNull(0), 'explicit null roundtrips');
end;

{ ==== error translation ==== }

procedure TestConstraintRaisesEdbError;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY)');
  Conn.Exec('INSERT INTO t VALUES (1)');
  ExpectDbError(procedure
    begin
      Conn.Exec('INSERT INTO t VALUES (1)');
    end, 'unique violation surfaces as EDbError');
end;

procedure TestConstraintCarriesBackendCode;
var
  Conn: IDbConnection;
  GotCode: Integer;
begin
  GotCode := 0;
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY)');
  Conn.Exec('INSERT INTO t VALUES (7)');
  try
    Conn.Exec('INSERT INTO t VALUES (7)');
  except
    on E: EDbError do
    begin
      GotCode := E.BackendCode;
      Check(E.Backend = dbkSqlite, 'backend field = dbkSqlite');
      Check(E.ExtendedCode <> 0, 'extended code present');
    end;
  end;
  CheckEqual(SQLITE_CONSTRAINT_CODE, GotCode, 'backend code = sqlite constraint');
end;

procedure TestSyntaxErrorCarriesMessage;
var
  Conn: IDbConnection;
  LMsg: string;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('NOT VALID SQL');
  except
    on E: EDbError do
      LMsg := E.Message;
  end;
  Check(LMsg <> '', 'syntax error carries non-empty message');
end;

{ ==== transactions (unified) ==== }

procedure TestTxCommitPersists;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (v INTEGER)');
  WithTransaction(Conn, procedure
    begin
      Conn.Exec('INSERT INTO t VALUES (1)');
      Conn.Exec('INSERT INTO t VALUES (2)');
    end);
  CheckEqual(Int64(2), CountRows(Conn, 'SELECT COUNT(*) FROM t'), 'committed rows persist');
  Check(Conn.QueryInterface(IDbTxControl, Tx) = 0, 'tx control supported');
  Check(not Tx.InTransaction, 'no txn after commit');
  CheckEqual(0, Tx.TxDepth, 'depth back to zero');
end;

procedure TestTxRollbackRethrows;
var
  Conn: IDbConnection;
  LRolledBack: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (v INTEGER)');
  LRolledBack := False;
  try
    WithTransaction(Conn, procedure
      begin
        Conn.Exec('INSERT INTO t VALUES (1)');
        raise ENextPasError.Create('boom');
      end);
  except
    on E: ENextPasError do
      if E.Message = 'boom' then
        LRolledBack := True;
  end;
  Check(LRolledBack, 'original exception rethrown');
  CheckEqual(Int64(0), CountRows(Conn, 'SELECT COUNT(*) FROM t'), 'rollback undid writes');
end;

procedure TestNestedInnerFailureKeepsOuterCommitable;
var
  Conn: IDbConnection;
begin
  { V2-S2 savepoint 混合语义：内层失败真正只撤销内层写入（ROLLBACK TO）；
    回调内捕获内层异常后，外层可继续提交自己的写入。 }
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (v INTEGER)');
  WithTransaction(Conn, procedure
    begin
      Conn.Exec('INSERT INTO t VALUES (1)');
      try
        WithTransaction(Conn, procedure
          begin
            Conn.Exec('INSERT INTO t VALUES (2)');
            raise ENextPasError.Create('inner boom');
          end);
      except
        on ENextPasError do ;   { 吞掉内层异常，外层继续 }
      end;
      Conn.Exec('INSERT INTO t VALUES (3)');
    end);
  CheckEqual(Int64(2), CountRows(Conn, 'SELECT COUNT(*) FROM t'),
    'outer commit persists outer writes only; inner write undone by its own rollback');
end;

procedure TestNestedOuterRollbackUndoesInner;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (v INTEGER)');
  try
    WithTransaction(Conn, procedure
      begin
        Conn.Exec('INSERT INTO t VALUES (1)');
        WithTransaction(Conn, procedure
          begin
            Conn.Exec('INSERT INTO t VALUES (2)');
          end);
        raise ENextPasError.Create('outer boom');
      end);
  except
    on ENextPasError do ;
  end;
  CheckEqual(Int64(0), CountRows(Conn, 'SELECT COUNT(*) FROM t'),
    'outer rollback undoes inner-committed writes');
end;

procedure TestTxMisuseGuards;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
begin
  Conn := ConnectSqlite(':memory:');
  Check(Conn.QueryInterface(IDbTxControl, Tx) = 0, 'tx control available');
  ExpectDbError(procedure
    begin
      Tx.CommitTxn;
    end, 'commit without begin raises');
  ExpectDbError(procedure
    begin
      Tx.RollbackTxn;
    end, 'rollback without begin raises');
  ExpectDbError(procedure
    begin
      WithTransaction(Conn, TDbTxProc(nil));
    end, 'nil callback raises');
end;

procedure TestForeignBeginRejected;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
begin
  { 裸 Exec('BEGIN') 后助手拒绝混用（sqlite autocommit 守卫）。 }
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('BEGIN');
  Check(Conn.QueryInterface(IDbTxControl, Tx) = 0, 'tx control available');
  ExpectDbError(procedure
    begin
      Tx.BeginTxn(False);
    end, 'helper refuses to mix with naked BEGIN');
  Conn.Exec('ROLLBACK');
end;

{ ==== migrations (unified) ==== }

procedure TestMigrateIdempotentAndVersioned;
var
  Conn: IDbConnection;
  M: TDbMigrations;
  Applied: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  M := MakeMigrations([
    TDbMigration.Create(1, ['CREATE TABLE items (id INTEGER PRIMARY KEY, v TEXT)']),
    TDbMigration.Create(2, ['CREATE INDEX idx_items_v ON items (v)',
                            'INSERT INTO items (id, v) VALUES (0, ''seed'')'])]);
  Applied := Migrate(Conn, M);
  CheckEqual(2, Applied, 'both migrations applied');
  Applied := Migrate(Conn, M);
  CheckEqual(0, Applied, 'second run is idempotent');
  CheckEqual(Int64(2), MigrationVersion(Conn), 'version tracked');
  CheckEqual(Int64(1), CountRows(Conn, 'SELECT COUNT(*) FROM items'), 'seed row exists');
end;

procedure TestMigrateRejectsDisorder;
var
  Conn: IDbConnection;
  M: TDbMigrations;
begin
  Conn := ConnectSqlite(':memory:');
  { 显式构造降序列表；乱序在 Migrate 时被拒绝。 }
  SetLength(M, 2);
  M[0] := TDbMigration.Create(5, ['CREATE TABLE b (x INT)']);
  M[1] := TDbMigration.Create(4, ['CREATE TABLE c (x INT)']);
  ExpectDbError(procedure
    begin
      Migrate(Conn, M);
    end, 'descending list rejected');
end;

procedure TestMigrateRejectsAheadVersion;
var
  Conn: IDbConnection;
  M: TDbMigrations;
begin
  Conn := ConnectSqlite(':memory:');
  M := MakeMigrations([TDbMigration.Create(5, ['CREATE TABLE x (a INT)'])]);
  CheckEqual(1, Migrate(Conn, M), 'initial migration applied');
  { 模拟库超前：手写版本行超出列表上限。 }
  Conn.Exec('INSERT INTO schema_migrations (version, applied_at) VALUES (9, ''manual'')');
  ExpectDbError(procedure
    begin
      Migrate(Conn, M);
    end, 'ahead version rejected');
end;

procedure TestMigrateRejectsBelowVersion;
var
  Conn: IDbConnection;
  M: TDbMigrations;
begin
  Conn := ConnectSqlite(':memory:');
  { 直接写入高版本，使列表最小版本"低于"已应用版本集合。 }
  Conn.Exec('CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT)');
  Conn.Exec('INSERT INTO schema_migrations (version, applied_at) VALUES (10, ''old'')');
  M := MakeMigrations([TDbMigration.Create(20, ['CREATE TABLE y (a INT)'])]);
  ExpectDbError(procedure
    begin
      Migrate(Conn, M);
    end, 'below version rejected');
end;

{ ==== lifetime ==== }

procedure TestInterfaceAutoReleaseNoLeak;
var
  I: Integer;
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  { 大量建/弃连接与查询对象；heaptrc 门禁兜底无泄漏。 }
  for I := 1 to 50 do
  begin
    Conn := ConnectSqlite(':memory:');
    Conn.Exec('CREATE TABLE t (a INT)');
    Q := Conn.Query('SELECT * FROM t');
    Check(Q.ColumnCount = 1, 'query object live before release');
    Q := nil;
  end;
  Conn := nil;
  Check(True, 'lifetime loop completed');
end;

begin
  EnsureBuiltinDrivers;
  T := TTestSuite.Create('nextpas.core.db');
  T.Test('kind and raw handle', @TestKindAndRaw);
  T.Test('exec/changes roundtrip', @TestExecChangesRoundtrip);
  T.Test('all types bind/get roundtrip', @TestAllTypesRoundtrip);
  T.Test('null detection + column meta', @TestNullAndColumnMeta);
  T.Test('explicit null bind', @TestBindNullExplicit);
  T.Test('constraint violation -> EDbError', @TestConstraintRaisesEdbError);
  T.Test('error carries backend code fields', @TestConstraintCarriesBackendCode);
  T.Test('syntax error message preserved', @TestSyntaxErrorCarriesMessage);
  T.Test('unified tx commit persists', @TestTxCommitPersists);
  T.Test('unified tx rollback rethrows original', @TestTxRollbackRethrows);
  T.Test('nested inner failure keeps outer usable', @TestNestedInnerFailureKeepsOuterCommitable);
  T.Test('nested outer rollback undoes inner', @TestNestedOuterRollbackUndoesInner);
  T.Test('tx misuse guards', @TestTxMisuseGuards);
  T.Test('foreign BEGIN rejected', @TestForeignBeginRejected);
  T.Test('migrate idempotent + version', @TestMigrateIdempotentAndVersioned);
  T.Test('migrate rejects ahead version', @TestMigrateRejectsAheadVersion);
  T.Test('migrate rejects below version', @TestMigrateRejectsBelowVersion);
  T.Test('interface auto-release loop', @TestInterfaceAutoReleaseNoLeak);
  if not T.Run then Halt(1);
end.
