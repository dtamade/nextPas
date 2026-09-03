program test_db_bulk_copy;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base.utils,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db,
  nextpas.core.db.bulk,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.dm.adapter,
  nextpas.core.os.env;

var
  T: TTestSuite;

procedure TestBasicBulk;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Cap: IDbCapabilities;
  Q: IDbQuery;
  Cnt: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id TEXT, v TEXT)');
  Cap := DbCapabilities(Conn);
  Check(Cap <> nil, 'caps present');
  Check(Cap.SupportsBulkCopy, 'sqlite bulk true');
  Check(Supports(Conn, IDbBulkCopy, Bulk), 'QI bulk');
  Check(Bulk <> nil, 'bulk not nil');
  Bulk.BeginCopy('t', ['id', 'v']);
  Bulk.WriteRow(['1', 'a']);
  Bulk.WriteRow(['2', 'b']);
  Bulk.WriteRow(['3', 'c']);
  Bulk.EndCopy;
  Q := Conn.Query('SELECT COUNT(*) FROM t');
  Check(Q.Step, 'step count');
  Cnt := Q.GetInt64(0);
  Check(Cnt = 3, 'count 3 bulk');
end;

procedure TestEscape;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Q: IDbQuery;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id TEXT, v TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t', ['id', 'v']);
  Bulk.WriteRow(['1', 'O''Brien']);
  Bulk.WriteRow(['2', 'a''b''c']);
  Bulk.EndCopy;
  Q := Conn.Query('SELECT v FROM t ORDER BY id');
  Check(Q.Step, 'row1');
  Check(Q.GetText(0) = 'O''Brien', 'escape 1');
  Check(Q.Step, 'row2');
  Check(Q.GetText(0) = 'a''b''c', 'escape 2');
end;

procedure TestAbort;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Q: IDbQuery;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t', ['id']);
  Bulk.WriteRow(['1']);
  Bulk.AbortCopy;
  Bulk.BeginCopy('t', ['id']);
  Bulk.WriteRow(['2']);
  Bulk.EndCopy;
  Q := Conn.Query('SELECT COUNT(*) FROM t');
  Check(Q.Step, 'step');
  Check(Q.GetInt64(0) = 1, 'abort cleared');
  Q := Conn.Query('SELECT id FROM t');
  Check(Q.Step, 'single row');
  Check(Q.GetText(0) = '2', 'only 2');
end;

procedure TestColumnMismatch;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (a TEXT, b TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t', ['a', 'b']);
  Raised := False;
  try
    Bulk.WriteRow(['only_one']);
  except
    on E: EDbError do Raised := True;
  end;
  Check(Raised, 'mismatch raised');
  Bulk.AbortCopy;
end;

procedure TestNotStarted;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (a TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Raised := False;
  try
    Bulk.WriteRow(['1']);
  except
    on E: EDbError do Raised := True;
  end;
  Check(Raised, 'not started raised');
end;

procedure TestConformanceCapsBulk;
var
  Conn: IDbConnection;
  Cap: IDbCapabilities;
  Bulk: IDbBulkCopy;
  Has: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  Cap := DbCapabilities(Conn);
  Has := Supports(Conn, IDbBulkCopy, Bulk);
  Check(Cap.SupportsBulkCopy = Has, 'caps ⇔ QI bulk');
  Check(Cap.SupportsBulkCopy, 'sqlite true');
  // empty EndCopy is no-op, not error
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t2', ['a']);
  Bulk.EndCopy;
  Check(True, 'empty EndCopy no-op');
end;

procedure TestBulkInsideTxn;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Q: IDbQuery;
  Ctl: IDbTxControl;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Supports(Conn, IDbTxControl, Ctl);
  Ctl.BeginTxn;
  try
    Bulk.BeginCopy('t', ['id']);
    Bulk.WriteRow(['1']);
    Bulk.WriteRow(['2']);
    Bulk.EndCopy;
    Check(Ctl.InTransaction, 'bulk inside txn still in txn (InTransaction branching)');
    Ctl.CommitTxn;
  except
    Ctl.RollbackTxn;
    raise;
  end;
  Q := Conn.Query('SELECT COUNT(*) FROM t');
  Check(Q.Step, 'inside txn step');
  Check(Q.GetInt64(0) = 2, 'inside txn 2 rows');
end;

procedure TestBulkRollbackOnError;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Q: IDbQuery;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id TEXT PRIMARY KEY)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t', ['id']);
  Bulk.WriteRow(['1']);
  Bulk.WriteRow(['1']); // PK 冲突
  Bulk.WriteRow(['2']);
  Raised := False;
  try
    Bulk.EndCopy;
  except
    on E: EDbError do Raised := True;
  end;
  Check(Raised, 'duplicate PK raised');
  Q := Conn.Query('SELECT COUNT(*) FROM t');
  Check(Q.Step, 'after rollback step');
  Check(Q.GetInt64(0) = 0, 'rollback empty 0 rows');
end;

procedure TestBulkRollbackOnErrorInsideTxn;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Ctl: IDbTxControl;
  Q: IDbQuery;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id TEXT PRIMARY KEY, v TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Supports(Conn, IDbTxControl, Ctl);
  Check(Ctl <> nil, 'tx control');
  Ctl.BeginTxn;
  try
    Conn.Exec('INSERT INTO t (id, v) VALUES (''pre'', ''a'')');
    Bulk.BeginCopy('t', ['id', 'v']);
    Bulk.WriteRow(['1', 'x']);
    Bulk.WriteRow(['1', 'y']);
    Bulk.WriteRow(['2', 'z']);
    Raised := False;
    try
      Bulk.EndCopy;
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'inside txn duplicate PK raised');
    Check(Ctl.InTransaction, 'inside txn still in txn after bulk error (savepoint rollback only)');
    Q := Conn.Query('SELECT COUNT(*) FROM t');
    Check(Q.Step, 'inside txn after savepoint step');
    Check(Q.GetInt64(0) = 1, 'savepoint rollback keeps outer pre only');
    Q := nil;
    Q := Conn.Query('SELECT id FROM t');
    Check(Q.Step, 'pre row present');
    Check(Q.GetText(0) = 'pre', 'pre intact');
    Q := nil;
    Conn.Exec('INSERT INTO t (id, v) VALUES (''post'', ''b'')');
    Ctl.CommitTxn;
  except
    try Ctl.RollbackTxn; except end;
    raise;
  end;
  Q := Conn.Query('SELECT COUNT(*) FROM t');
  Check(Q.Step, 'committed after savepoint step');
  Check(Q.GetInt64(0) = 2, 'committed 2 pre+post');
  Q := nil;
  Q := Conn.Query('SELECT COUNT(*) FROM t WHERE id IN (''1'',''2'')');
  Check(Q.Step, 'bulk rows absent step');
  Check(Q.GetInt64(0) = 0, 'bulk rows absent 0');
end;

procedure TestBulkOverestimateThreshold;
var
  Conn: IDbConnection;
  Bulk: IDbBulkCopy;
  Q8, Thr: Integer;
  I: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (a TEXT, b TEXT)');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t', ['a', 'b']);
  // worst '' heavy: Length*2+2 overestimate should stay within Q8 512 (2.0) CI gate; also test super-long guard via BULK_MAX_CHUNK_BYTES spill
  for I := 1 to 20 do
    Bulk.WriteRow([StringOfChar('''', 200), StringOfChar('x', 500)]);
  Bulk.EndCopy;
  Thr := DbBulkOverestimateThresholdQ8;
  Check(Thr = 512, 'threshold Q8 512');
  Q8 := DbBulkLastOverestimateRatioQ8;
  Check(Q8 > 0, 'Q8 monitored');
  Check(Q8 <= Thr, 'overestimate Q8 within threshold 2.0');
  Check(DbBulkIsOverestimateOk, 'IsOverestimateOk gate');
  Check(DbBulkLastEstimated >= DbBulkLastActual, 'estimated >= actual');
  // flat buffer path also gated
  Conn.Exec('DELETE FROM t');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t', ['a', 'b']);
  Bulk.WriteRow(['x', 'y']);
  Bulk.EndCopy;
  Check(DbBulkIsOverestimateOk, 'small row gate ok');
end;

procedure TestBulkBufferDirect;
var
  Buf: TDbBulkBuffer;
  S: string;
begin
  S := DbBulkEscape('a''b');
  Check(S = 'a''''b', 'DbBulkEscape single quote');
  S := DbBulkEscape('''');
  Check(S = '''''' , 'DbBulkEscape lone quote');
  S := DbBulkEscape('');
  Check(S = '', 'DbBulkEscape empty');
  S := DbBulkEscape('no quote');
  Check(S = 'no quote', 'DbBulkEscape no quote');
  Buf.Clear;
  Check(not Buf.IsActive, 'buf not active after clear');
  Buf.BeginCopy(dbkSqlite, 't', ['a', 'b']);
  Check(Buf.IsActive, 'buf active');
  Check(Buf.ColumnCount = 2, 'buf col 2');
  Check(Buf.RowCount = 0, 'buf rows 0');
  Check(Buf.TableName = 't', 'buf table');
  Buf.WriteRow(dbkSqlite, ['x', 'y']);
  Check(Buf.RowCount = 1, 'buf row 1');
  Buf.Clear;
  Check(not Buf.IsActive, 'buf cleared inactive');
  Check(Buf.RowCount = 0, 'buf cleared rows 0');
  // reuse after clear
  Buf.BeginCopy(dbkSqlite, 't2', ['c']);
  Buf.WriteRow(dbkSqlite, ['z']);
  Check(Buf.RowCount = 1, 'buf reuse row 1');
  Buf.Clear;
end;

procedure VerifyBulkOnLive(const AConn: IDbConnection; const P: string);
var
  Cap: IDbCapabilities;
  Bulk: IDbBulkCopy;
  Q: IDbQuery;
  Ctl: IDbTxControl;
  Cnt: Integer;
  Raised: Boolean;
begin
  Cap := DbCapabilities(AConn);
  Check(Cap <> nil, P + ': caps present');
  Check(Cap.SupportsBulkCopy, P + ': SupportsBulkCopy true');
  Check(Supports(AConn, IDbBulkCopy, Bulk), P + ': QI bulk');
  Check(Bulk <> nil, P + ': bulk not nil');
  // basic 3 rows
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_bulk');
  AConn.Exec('CREATE TABLE ' + P + '_bulk (id TEXT, v TEXT)');
  Bulk.BeginCopy(P + '_bulk', ['id', 'v']);
  Bulk.WriteRow(['1', 'a']);
  Bulk.WriteRow(['2', 'b']);
  Bulk.WriteRow(['3', 'c']);
  Bulk.EndCopy;
  Q := AConn.Query('SELECT COUNT(*) FROM ' + P + '_bulk');
  Check(Q.Step, P + ': count step');
  Cnt := Q.GetInt64(0);
  Check(Cnt = 3, P + ': count 3');
  Q := nil;
  // escape single quote via DbBulkEscape path
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_esc');
  AConn.Exec('CREATE TABLE ' + P + '_esc (id TEXT, v TEXT)');
  Supports(AConn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy(P + '_esc', ['id', 'v']);
  Bulk.WriteRow(['1', 'O''Brien']);
  Bulk.WriteRow(['2', 'a''b']);
  Bulk.EndCopy;
  Q := AConn.Query('SELECT v FROM ' + P + '_esc ORDER BY id');
  Check(Q.Step, P + ': esc row1');
  Check(Q.GetText(0) = 'O''Brien', P + ': esc 1 ok');
  Check(Q.Step, P + ': esc row2');
  Check(Q.GetText(0) = 'a''b', P + ': esc 2 ok');
  Q := nil;
  // empty EndCopy no-op on new table
  Supports(AConn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy(P + '_noop', ['a']);
  Bulk.EndCopy;
  Check(True, P + ': empty EndCopy no-op');
  // column mismatch raises
  Supports(AConn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy(P + '_esc', ['id', 'v']);
  Raised := False;
  try
    Bulk.WriteRow(['only_one']);
  except
    on E: EDbError do Raised := True;
  end;
  Check(Raised, P + ': mismatch raised');
  Bulk.AbortCopy;
  // abort clears buffer
  Bulk.BeginCopy(P + '_esc', ['id', 'v']);
  Bulk.WriteRow(['9', 'keep']);
  Bulk.AbortCopy;
  Bulk.BeginCopy(P + '_esc', ['id', 'v']);
  Bulk.WriteRow(['10', 'kept']);
  Bulk.EndCopy;
  Q := AConn.Query('SELECT COUNT(*) FROM ' + P + '_esc WHERE id = ''10''');
  Check(Q.Step, P + ': abort cleared step');
  Check(Q.GetInt64(0) = 1, P + ': abort cleared kept');
  Q := nil;
  // bulk inside txn commit preserves InTransaction branching (reuse outer)
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_txn');
  AConn.Exec('CREATE TABLE ' + P + '_txn (id TEXT)');
  Supports(AConn, IDbBulkCopy, Bulk);
  Supports(AConn, IDbTxControl, Ctl);
  Check(Ctl <> nil, P + ': tx control');
  Ctl.BeginTxn;
  try
    Bulk.BeginCopy(P + '_txn', ['id']);
    Bulk.WriteRow(['1']);
    Bulk.WriteRow(['2']);
    Bulk.EndCopy;
    Check(Ctl.InTransaction, P + ': still in txn after bulk endcopy');
    Ctl.CommitTxn;
  except
    Ctl.RollbackTxn;
    raise;
  end;
  Q := AConn.Query('SELECT COUNT(*) FROM ' + P + '_txn');
  Check(Q.Step, P + ': txn commit step');
  Check(Q.GetInt64(0) = 2, P + ': txn 2 rows');
  Q := nil;
  // bulk inside txn rollback atomicity
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_txrb');
  AConn.Exec('CREATE TABLE ' + P + '_txrb (id TEXT)');
  Ctl.BeginTxn;
  try
    Bulk.BeginCopy(P + '_txrb', ['id']);
    Bulk.WriteRow(['x']);
    Bulk.EndCopy;
    Check(Ctl.InTransaction, P + ': txrb still in txn');
    Ctl.RollbackTxn;
  except
    Ctl.RollbackTxn;
    raise;
  end;
  Q := AConn.Query('SELECT COUNT(*) FROM ' + P + '_txrb');
  Check(Q.Step, P + ': tx rollback step');
  Check(Q.GetInt64(0) = 0, P + ': tx rollback 0');
  Q := nil;
  // rollback on error (duplicate PK) — single-transaction atomicity
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_rb');
  AConn.Exec('CREATE TABLE ' + P + '_rb (id INTEGER PRIMARY KEY)');
  Supports(AConn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy(P + '_rb', ['id']);
  Bulk.WriteRow(['1']);
  Bulk.WriteRow(['1']);
  Bulk.WriteRow(['2']);
  Raised := False;
  try
    Bulk.EndCopy;
  except
    on E: EDbError do Raised := True;
  end;
  Check(Raised, P + ': duplicate PK raised');
  Q := AConn.Query('SELECT COUNT(*) FROM ' + P + '_rb');
  Check(Q.Step, P + ': after rollback step');
  Check(Q.GetInt64(0) = 0, P + ': rollback empty 0');
  Q := nil;
  // cleanup
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_bulk');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_esc');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_noop');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_txn');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_txrb');
  AConn.Exec('DROP TABLE IF EXISTS ' + P + '_rb');
end;

procedure TestBulkLivePg;
var
  Conn: IDbConnection;
  Env: string;
begin
  Env := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  if Env = '' then
  begin
    WriteLn('pg bulk skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(Env);
  VerifyBulkOnLive(Conn, 't_bulk_pg');
end;

procedure TestBulkLiveMysql;
var
  Conn: IDbConnection;
  Env: string;
begin
  Env := GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN');
  if Env = '' then
  begin
    WriteLn('mysql bulk skipped (NEXTPAS_MYSQL_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectMysql(Env);
  VerifyBulkOnLive(Conn, 't_bulk_my');
end;

procedure TestBulkLiveOdbc;
var
  Conn: IDbConnection;
  Env: string;
begin
  Env := GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN');
  if Env = '' then
  begin
    WriteLn('odbc bulk skipped (NEXTPAS_ODBC_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectOdbc(Env);
  VerifyBulkOnLive(Conn, 't_bulk_od');
end;

procedure TestBulkLiveDm;
var
  Conn: IDbConnection;
  Env: string;
begin
  Env := GetEnvironmentVariable('NEXTPAS_DM_TEST_CONN');
  if Env = '' then
  begin
    WriteLn('dm bulk skipped (NEXTPAS_DM_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectDm(Env);
  VerifyBulkOnLive(Conn, 't_bulk_dm');
end;

procedure TestBulkCacheBypassNoPollution;
var
  Conn: IDbConnection;
  Ctrl: IDbStmtCacheControl;
  Bulk: IDbBulkCopy;
  Q: IDbQuery;
  HitBefore, HitAfter: Double;
  K: Integer;
begin
  // perf: isolated point-query LRU64 hit_rate gate (500 rows/chunk bypass by design orthogonal to 2.39×/2.12×, bytes.ops single source, inline zero-copy via DbBulkChunkRows)
  // stability: try..finally via IDbBulkCopy EndCopy + Q:=nil interface release not lost
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t_cache (id INTEGER PRIMARY KEY, v TEXT)');
  for K := 1 to 200 do
    Conn.Exec('INSERT INTO t_cache VALUES (' + IntToStr(K) + ', ''v' + IntToStr(K) + ''')');
  Check(Supports(Conn, IDbStmtCacheControl, Ctrl), 'cache control QI');
  Check(Ctrl <> nil, 'cache control not nil');
  for K := 1 to 5000 do
  begin
    Q := Conn.Query('SELECT v FROM t_cache WHERE id = ?');
    Q.BindInt64(1, (K mod 200) + 1);
    while Q.Step do ;
    Q := nil;
  end;
  HitBefore := Ctrl.HitRate;
  Check(HitBefore > 0.99, 'hit before ~1.0');
  Supports(Conn, IDbBulkCopy, Bulk);
  Bulk.BeginCopy('t_cache_bulk', ['id', 'v']);
  for K := 1 to 1000 do
    Bulk.WriteRow([IntToStr(K), 'v' + IntToStr(K)]);
  Bulk.EndCopy;
  try Conn.Exec('DROP TABLE IF EXISTS t_cache_bulk'); except end;
  for K := 1 to 5000 do
  begin
    Q := Conn.Query('SELECT v FROM t_cache WHERE id = ?');
    Q.BindInt64(1, (K mod 200) + 1);
    while Q.Step do ;
    Q := nil;
  end;
  HitAfter := Ctrl.HitRate;
  // gate: drop>0.05 = regress Halt (500 rows/chunk literal bypass LRU64 by design must not pollute point 2.39×)
  Check(HitAfter >= HitBefore - 0.05, 'cache bypass no pollution hit_rate 0丢 gate');
end;

begin
  T := TTestSuite.Create('nextpas.core.db.bulk_copy');
  T.Test('basic bulk', @TestBasicBulk);
  T.Test('escape', @TestEscape);
  T.Test('abort', @TestAbort);
  T.Test('column mismatch', @TestColumnMismatch);
  T.Test('not started', @TestNotStarted);
  T.Test('conformance caps bulk', @TestConformanceCapsBulk);
  T.Test('bulk inside txn', @TestBulkInsideTxn);
  T.Test('rollback on error', @TestBulkRollbackOnError);
  T.Test('rollback on error inside txn (savepoint)', @TestBulkRollbackOnErrorInsideTxn);
  T.Test('bulk buffer direct (DbBulkEscape/TDbBulkBuffer reuse)', @TestBulkBufferDirect);
  T.Test('bulk overestimate threshold CI gate (Q8 512 + BULK_MAX_CHUNK_BYTES spill)', @TestBulkOverestimateThreshold);
  T.Test('bulk live pg (env-gated)', @TestBulkLivePg);
  T.Test('bulk live mysql (env-gated)', @TestBulkLiveMysql);
  T.Test('bulk live odbc (env-gated)', @TestBulkLiveOdbc);
  T.Test('bulk live dm (env-gated)', @TestBulkLiveDm);
  T.Test('bulk cache bypass no pollution (LRU64 orthogonal 2.39× gate)', @TestBulkCacheBypassNoPollution);
  if not T.Run then Halt(1);
end.
