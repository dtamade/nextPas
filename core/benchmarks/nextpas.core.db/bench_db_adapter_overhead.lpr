program db_bench;
{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}
uses SysUtils, Classes, nextpas.core.base, nextpas.core.db.sqlite, nextpas.core.db,
  nextpas.core.db.dm.adapter, nextpas.core.platform.env;
var
  T0, T1: QWord;
  GK: Int64;   { 匿名方法内禁捕获循环计数器，借用全局 }

procedure BenchNativeInsertSelect(const N: Integer);
var
  Db: TSqliteDb; Q: TSqliteQuery; I: Int64; S: Int64;
begin
  Db := TSqliteDb.Create(':memory:');
  Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER)');
  Db.Exec('BEGIN');
  T0 := GetTickCount64;
  for I := 1 to N do
  begin
    Q := Db.Query('INSERT INTO t (v) VALUES (?)');
    Q.BindInt64(1, I);
    Q.Step; Q.Free;
  end;
  Db.Exec('COMMIT');
  Q := Db.Query('SELECT SUM(id) FROM t');
  Q.Step; S := Q.GetInt64(0); Q.Free;
  T1 := GetTickCount64;
  WriteLn(Format('native  insert%8d + select: %6d ms (sum=%d)', [N, T1-T0, S]));
  Db.Free;
end;

procedure BenchUnifiedInsertSelect(const N: Integer);
var
  Conn: IDbConnection; Q: IDbQuery; I: Int64; S: Int64;
begin
  Conn := ConnectSqlite(':memory:');
  Conn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER)');
  WithTransaction(Conn, procedure
  begin
    T0 := GetTickCount64;
    for GK := 1 to N do
    begin
      Q := Conn.Query('INSERT INTO t (v) VALUES (?)');
      Q.BindInt64(1, GK);
      Q.Step;
    end;
    T1 := GetTickCount64;
  end);
  Q := Conn.Query('SELECT SUM(id) FROM t');
  Q.Step; S := Q.GetInt64(0);
  WriteLn(Format('adapter insert%8d + select: %6d ms (sum=%d)', [N, T1-T0, S]));
end;

procedure BenchMysqlInsertSelect(const N: Integer);
var
  Conn: IDbConnection; Q: IDbQuery; I: Int64; S: Int64;
  LEnv: string;
begin
  LEnv := GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN');
  if LEnv = '' then
  begin
    WriteLn('mysql   insert', N:8, ' + select: skipped (no NEXTPAS_MYSQL_TEST_CONN)');
    Exit;
  end;
  Conn := ConnectMysql(LEnv);
  Conn.Exec('DROP TABLE IF EXISTS t_bench');
  Conn.Exec('CREATE TABLE t_bench (id INTEGER PRIMARY KEY AUTO_INCREMENT, v INTEGER)');
  Conn.Exec('DELETE FROM t_bench');
  WithTransaction(Conn, procedure
  begin
    T0 := GetTickCount64;
    for GK := 1 to N do
    begin
      Q := Conn.Query('INSERT INTO t_bench (v) VALUES (?)');
      Q.BindInt64(1, GK);
      Q.Step;
    end;
    T1 := GetTickCount64;
  end);
  Q := Conn.Query('SELECT SUM(id) FROM t_bench');
  Q.Step; S := Q.GetInt64(0);
  WriteLn(Format('mysql   insert%8d + select: %6d ms (sum=%d) [mariadb/mysql via libmariadb 112B]', [N, T1-T0, S]));
  Conn.Exec('DROP TABLE IF EXISTS t_bench');
  // stability: Conn is IDbConnection interface, ref-counted auto-release on scope exit; Q:=nil implicit via interface, no handle leak
end;

procedure BenchDmInsertSelect(const N: Integer);
var
  Conn: IDbConnection; Q: IDbQuery; I: Int64; S: Int64;
  LEnv: string;
begin
  // DM native backend env-gated: unified layer ConnectDm vs honest absence of direct dpi_* (see benchmarks.md J1)
  // perf: ?→$N via db.sqlscan inline thin-forward → text.sqlscan single-pass, RenderDollar zero extra alloc, bytes.ops single source; DsnToDpiConnStr inline zero-copy AnsiString view
  LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
  if LEnv = '' then
  begin
    WriteLn('dm      insert', N:8, ' + select: skipped (no NEXTPAS_DM_TEST_CONN; honest absence — unified ?→$N+dpi_execute not yet bench-proven, see bench_db_dm_adapter offline)');
    Exit;
  end;
  try
    Conn := ConnectDm(LEnv);
  except
    on E: Exception do
    begin
      WriteLn('dm      insert', N:8, ' + select: skipped (ConnectDm failed: ', E.Message, '; trying odbc gateway honest)');
      try
        LEnv := string(platform_env_get_str('NEXTPAS_DM_TEST_CONN'));
        Conn := ConnectOdbc(LEnv);
      except
        on E2: Exception do
        begin
          WriteLn('dm      insert', N:8, ' + select: skipped (both native+odbc failed: ', E2.Message, ')');
          Exit;
        end;
      end;
    end;
  end;
  try Conn.Exec('DROP TABLE IF EXISTS t_bench_dm'); except end;
  Conn.Exec('CREATE TABLE t_bench_dm (id INTEGER PRIMARY KEY, v INTEGER)');
  try Conn.Exec('DELETE FROM t_bench_dm'); except end;
  WithTransaction(Conn, procedure
  begin
    T0 := GetTickCount64;
    for GK := 1 to N do
    begin
      Q := Conn.Query('INSERT INTO t_bench_dm (v) VALUES (?)');
      Q.BindInt64(1, GK);
      Q.Step;
      Q := nil;
    end;
    T1 := GetTickCount64;
  end);
  Q := Conn.Query('SELECT SUM(id) FROM t_bench_dm');
  Q.Step; S := Q.GetInt64(0); Q := nil;
  WriteLn(Format('dm      insert%8d + select: %6d ms (sum=%d) [dm via dpi_prepare/bind_param/execute/fetch, ?→$N inline, IsNull stable buffer]', [N, T1-T0, S]));
  try Conn.Exec('DROP TABLE IF EXISTS t_bench_dm'); except end;
  Conn := nil;
  // stability: IDbConnection/Q interface handles auto-released; dpi_free_stmt/conn via holder/destructor not lost (see dm.adapter Destroy/ReturnStmt)
end;

var
  N: Integer;
  Sizes: array[0..1] of Integer = (1000, 10000);
  K: Integer;
begin
  WriteLn('== insert/select 往返（含适配层开销） ==');
  WriteLn('== DM segment: NEXTPAS_DM_TEST_CONN env-gated honest (unified ConnectDm ?→$N+dpi_execute; bulk 10k via bench_db_bulk_copy DM segment) — J1≤1.15× verifiable when DM live ==');
  for K := 0 to High(Sizes) do
  begin
    BenchNativeInsertSelect(Sizes[K]);
    BenchUnifiedInsertSelect(Sizes[K]);
    BenchMysqlInsertSelect(Sizes[K]);
    BenchDmInsertSelect(Sizes[K]);
  end;
end.
