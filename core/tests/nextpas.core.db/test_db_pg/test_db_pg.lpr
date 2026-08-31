program test_db_pg;

{ Contract tests for nextpas.core.db.pg against a live local PostgreSQL.
   Requires: PG server reachable via $NEXTPAS_PG_TEST_CONN (default
   'host=/var/run/postgresql dbname=nextpas_pg_test user=dtamade').
   All tests are TestSeq (serial) because they share one database. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.pg,
  nextpas.core.db,
  nextpas.core.db.base;

var
  T: TTestSuite;
  GConn: string;

function TestConnStr: string;
begin
  Result := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  if Result = '' then
    Result := 'host=/var/run/postgresql dbname=nextpas_pg_test user=dtamade';
end;

{ ===== connect & meta ===== }

procedure TestConnectAndVersion;
var
  Conn: TPgConn;
begin
  Conn := PgOpen(GConn);
  try
    Check(Conn.ServerVersion > 0, 'server version positive: ' + IntToStr(Conn.ServerVersion));
    Check(Conn.Version <> '', 'libpq version non-empty');
  finally
    Conn.Free;
  end;
end;

{ ===== create/insert/select roundtrip ===== }

procedure TestCreateInsertSelect;
var
  Conn: TPgConn;
  Q: TPgQuery;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_roundtrip CASCADE');
    Conn.Exec('CREATE TABLE t_pg_roundtrip (id BIGINT PRIMARY KEY, name TEXT, score DOUBLE PRECISION)');
    Conn.Exec('INSERT INTO t_pg_roundtrip VALUES (1, ''alice'', 2.5), (2, ''bob'', 3.75)');
    Q := Conn.Query('SELECT id, name, score FROM t_pg_roundtrip WHERE id = $1');
    try
      Q.BindInt64(1, 2);
      Check(Q.Step, 'row 2 present');
      CheckEqual(Int64(2), Q.GetInt64(0), 'int64 roundtrip');
      CheckEqual('bob', Q.GetText(1), 'text roundtrip');
      Check(Abs(Q.GetDouble(2) - 3.75) < 1e-9, 'double roundtrip');
      Check(not Q.Step, 'no second row');
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== NULL bind ===== }

procedure TestNullBind;
var
  Conn: TPgConn;
  Q: TPgQuery;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_null CASCADE');
    Conn.Exec('CREATE TABLE t_pg_null (id BIGINT PRIMARY KEY, v TEXT)');
    Q := Conn.Query('INSERT INTO t_pg_null (id, v) VALUES ($1, $2)');
    try
      Q.BindInt64(1, 1);
      Q.BindNull(2);
      while Q.Step do ;
    finally
      Q.Free;
    end;
    Q := Conn.Query('SELECT v FROM t_pg_null WHERE id = $1');
    try
      Q.BindInt64(1, 1);
      Check(Q.Step, 'NULL row present');
      Check(Q.IsNull(0), 'column is NULL');
      CheckEqual('', Q.GetText(0), 'GetText on NULL returns empty string');
      Check(not Q.Step, 'only one row');
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== multi-statement exec ===== }

procedure TestExecMultiStatements;
var
  Conn: TPgConn;
  Q: TPgQuery;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_a CASCADE; DROP TABLE IF EXISTS t_pg_b CASCADE;');
    Conn.Exec('CREATE TABLE t_pg_a (x BIGINT); CREATE TABLE t_pg_b (y TEXT);');
    Conn.Exec('INSERT INTO t_pg_a VALUES (7); INSERT INTO t_pg_b VALUES (''seven'');');
    Q := Conn.Query('SELECT x FROM t_pg_a');
    try
      Check(Q.Step, 't_pg_a has row');
      CheckEqual(Int64(7), Q.GetInt64(0), 't_pg_a value');
    finally
      Q.Free;
    end;
    Q := Conn.Query('SELECT y FROM t_pg_b');
    try
      Check(Q.Step, 't_pg_b has row');
      CheckEqual('seven', Q.GetText(0), 't_pg_b value');
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== prepared statement step-through ===== }

procedure TestParameterizedStepThrough;
var
  Conn: TPgConn;
  Q: TPgQuery;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_rows CASCADE');
    Conn.Exec('CREATE TABLE t_pg_rows (n BIGINT)');
    Conn.Exec('INSERT INTO t_pg_rows VALUES (10), (20), (30)');
    Q := Conn.Query('SELECT n FROM t_pg_rows WHERE n >= $1 ORDER BY n');
    try
      Q.BindInt64(1, 20);
      Check(Q.Step, 'first row');
      CheckEqual(Int64(20), Q.GetInt64(0), 'first value');
      Check(Q.Step, 'second row');
      CheckEqual(Int64(30), Q.GetInt64(0), 'second value');
      Check(not Q.Step, 'no more rows');
    finally
      Q.Free;
    end;
    { Reset and re-execute with a different parameter }
    Q := Conn.Query('SELECT n FROM t_pg_rows WHERE n <= $1 ORDER BY n');
    try
      Q.BindInt64(1, 15);
      Check(Q.Step, 'reset rerun first row');
      CheckEqual(Int64(10), Q.GetInt64(0), 'reset rerun value');
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== constraint violation -> EPgError with SQLSTATE ===== }

procedure TestConstraintViolation;
var
  Conn: TPgConn;
  Q: TPgQuery;
  Raised: Boolean;
  State: string;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_unique CASCADE');
    Conn.Exec('CREATE TABLE t_pg_unique (id BIGINT PRIMARY KEY, u TEXT UNIQUE)');
    Raised := False;
    try
      Q := Conn.Query('INSERT INTO t_pg_unique (id, u) VALUES ($1, $2)');
      try
        Q.BindInt64(1, 1);
        Q.BindText(2, 'dup');
        while Q.Step do ;
        Q.Reset;
        Q.BindInt64(1, 2);
        Q.BindText(2, 'dup');
        while Q.Step do ;
      finally
        Q.Free;
      end;
    except
      on E: EPgError do
      begin
        Raised := True;
        State := E.SqlState;
      end;
    end;
    Check(Raised, 'UNIQUE violation raised EPgError');
    CheckEqual('23505', State, 'sqlstate is unique_violation');
  finally
    Conn.Free;
  end;
end;

{ ===== bad connection ===== }

procedure TestBadConnect;
begin
  try
    TPgConn.Create('host=127.0.0.1 port=1 dbname=xx user=xx').Free;
  except
    on E: EPgError do
    begin
      Check(E.Message <> '', 'bad connection message non-empty');
      Exit;
    end;
  end;
  Check(False, 'bad connection should have raised EPgError');
end;

{ ===== Changes ===== }

procedure TestChanges;
var
  Conn: TPgConn;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_changes CASCADE');
    Conn.Exec('CREATE TABLE t_pg_changes (id BIGINT PRIMARY KEY)');
    Conn.Exec('INSERT INTO t_pg_changes VALUES (1), (2)');
    CheckEqual(Int64(2), Conn.Changes, 'insert changes = 2');
    Conn.Exec('DELETE FROM t_pg_changes WHERE id <= 2');
    CheckEqual(Int64(2), Conn.Changes, 'delete changes = 2');
  finally
    Conn.Free;
  end;
end;

{ ===== error fields ===== }

procedure TestErrorFields;
var
  Conn: TPgConn;
begin
  Conn := PgOpen(GConn);
  try
    try
      Conn.Exec('SELECT * FROM no_such_table_xyz');
      Check(False, 'should have raised');
    except
      on E: EPgError do
      begin
        Check(E.Severity <> '', 'severity present');
        Check(E.Message <> '', 'message present');
      end;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== caller-managed transactions ===== }

procedure TestTransactionSelfManaged;
var
  Conn: TPgConn;
  Q: TPgQuery;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_tx CASCADE');
    Conn.Exec('CREATE TABLE t_pg_tx (id BIGINT PRIMARY KEY)');
    Conn.Exec('BEGIN');
    Conn.Exec('INSERT INTO t_pg_tx VALUES (1)');
    Conn.Exec('ROLLBACK');
    Q := Conn.Query('SELECT count(*) FROM t_pg_tx');
    try
      Check(Q.Step, 'count row');
      CheckEqual(Int64(0), Q.GetInt64(0), 'ROLLBACK removed row');
    finally
      Q.Free;
    end;
    Conn.Exec('BEGIN');
    Conn.Exec('INSERT INTO t_pg_tx VALUES (1)');
    Conn.Exec('COMMIT');
    Q := Conn.Query('SELECT count(*) FROM t_pg_tx');
    try
      Q.Step;
      CheckEqual(Int64(1), Q.GetInt64(0), 'COMMIT kept row');
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== blob（hex + ::bytea cast）===== }

procedure TestBlobRoundtrip;
var
  Conn: TPgConn;
  Q: TPgQuery;
  LB: TBytes;
begin
  Conn := PgOpen(GConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS t_pg_blob CASCADE');
    Conn.Exec('CREATE TABLE t_pg_blob (id INT PRIMARY KEY, data BYTEA)');
    Q := Conn.Query('INSERT INTO t_pg_blob (id, data) VALUES ($1, $2)');
    try
      Q.BindInt64(1, 1);
      { 含 0x00 / 0xFF / 高位字节的二进制 }
      LB := TBytes.Create($00, $01, $7F, $80, $FF, $AB, $CD, $EF);
      Q.BindBlob(2, LB);
      while Q.Step do ;
    finally
      Q.Free;
    end;
    Q := Conn.Query('SELECT id, data FROM t_pg_blob WHERE id = $1');
    try
      Q.BindInt64(1, 1);
      Check(Q.Step, 'blob row present');
      CheckEqual(Length(LB), Length(Q.GetBlob(1)), 'blob length roundtrip');
      Check(Q.GetBlob(1)[0] = $00, 'blob byte 0x00');
      Check(Q.GetBlob(1)[4] = $FF, 'blob byte 0xFF');
      Check(Q.GetBlob(1)[7] = $EF, 'blob last byte');
      Check(not Q.IsNull(1), 'blob column not null');
      Check(Q.ColumnFieldOid(1) = 17, 'field oid = bytea');
    finally
      Q.Free;
    end;
    { NULL blob 与显式 NULL 绑定 }
    Q := Conn.Query('INSERT INTO t_pg_blob (id, data) VALUES ($1, $2)');
    try
      Q.BindInt64(1, 2);
      Q.BindNull(2);
      while Q.Step do ;
    finally
      Q.Free;
    end;
    Q := Conn.Query('SELECT data FROM t_pg_blob WHERE id = $1');
    try
      Q.BindInt64(1, 2);
      Check(Q.Step and Q.IsNull(0), 'null bytea reads as null');
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

{ ===== 统一层：连接与错误字段 ===== }

procedure TestUnifiedPgConnectAndRoundtrip;
var
  Conn: IDbConnection;
  Q: IDbQuery;
begin
  Conn := ConnectPostgres(GConn);
  Check(Conn.Kind = dbkPostgres, 'unified kind = dbkPostgres');
  Conn.Exec('DROP TABLE IF EXISTS t_db_unified_pg CASCADE');
  Conn.Exec('CREATE TABLE t_db_unified_pg (id INT PRIMARY KEY, v TEXT)');
  Q := Conn.Query('INSERT INTO t_db_unified_pg (id, v) VALUES (?, ?)');
  Q.BindInt64(1, 42);
  Q.BindText(2, 'unified');
  Check(not Q.Step, 'unified insert via ? placeholders');
  Q := Conn.Query('SELECT v FROM t_db_unified_pg WHERE id = ?');
  Q.BindInt64(1, 42);
  Check(Q.Step, 'unified select row');
  CheckEqual('unified', Q.GetText(0), 'unified text roundtrip');
end;

procedure TestUnifiedPgErrorFields;
var
  Conn: IDbConnection;
  LState: string;
  LBackend: TDbKind;
begin
  LState := '';
  Conn := ConnectPostgres(GConn);
  Conn.Exec('DROP TABLE IF EXISTS t_db_unified_err CASCADE');
  Conn.Exec('CREATE TABLE t_db_unified_err (id INT PRIMARY KEY)');
  Conn.Exec('INSERT INTO t_db_unified_err VALUES (1)');
  try
    Conn.Exec('INSERT INTO t_db_unified_err VALUES (1)');
  except
    on E: EDbError do
    begin
      LState := E.SqlState;
      LBackend := E.Backend;
    end;
  end;
  CheckEqual('23505', LState, 'EDbError carries pg sqlstate');
  Check(LBackend = dbkPostgres, 'EDbError backend field set');
end;

begin
  GConn := TestConnStr;
  T := TTestSuite.Create('nextpas.core.db.pg');
  T.TestSeq('connect & version', @TestConnectAndVersion);
  T.TestSeq('create/insert/select roundtrip', @TestCreateInsertSelect);
  T.TestSeq('NULL bind', @TestNullBind);
  T.TestSeq('multi-statement exec', @TestExecMultiStatements);
  T.TestSeq('parameterized step through', @TestParameterizedStepThrough);
  T.TestSeq('constraint violation -> sqlstate', @TestConstraintViolation);
  T.TestSeq('bad connection raises', @TestBadConnect);
  T.TestSeq('changes', @TestChanges);
  T.TestSeq('error fields', @TestErrorFields);
  T.TestSeq('caller-managed transactions', @TestTransactionSelfManaged);
  T.TestSeq('blob hex+cast roundtrip', @TestBlobRoundtrip);
  T.TestSeq('unified connect & ? placeholder roundtrip', @TestUnifiedPgConnectAndRoundtrip);
  T.TestSeq('unified error carries sqlstate', @TestUnifiedPgErrorFields);
  if not T.Run then Halt(1);
end.