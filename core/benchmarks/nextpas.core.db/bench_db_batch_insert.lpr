program bench_db_batch_insert;

{ 批量写入三路基准（§12.4 验收判据的数据源）：
    autocommit : 每行独立隐式事务（最差基线）
    txloop     : 单事务内逐条参数化执行
    batch      : IDbBatchExecutor（pg=单次往返合并；sqlite=单事务逐条）
  输出行格式：backend=<k> mode=<m> n=<rows> ms=<ms>
  sqlite 段总是执行；pg 段需要 NEXTPAS_PG_TEST_CONN。 }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf;

const
  N = 10000;

var
  GK: Int64;

procedure ResetTable(const AConn: IDbConnection);
begin
  AConn.Exec('DROP TABLE IF EXISTS t_bi');
  AConn.Exec('CREATE TABLE t_bi (id INTEGER PRIMARY KEY, v INTEGER)');
end;

function BenchAutocommit(const AConn: IDbConnection): Double;
var
  Q: IDbQuery;
  T0, T1: QWord;
begin
  ResetTable(AConn);
  T0 := GetTickCount64;
  for GK := 1 to N do
  begin
    Q := AConn.Query('INSERT INTO t_bi VALUES (?, ?)');
    Q.BindInt64(1, GK);
    Q.BindInt64(2, GK * 2);
    while Q.Step do ;
    Q := nil;
  end;
  T1 := GetTickCount64;
  Result := T1 - T0;
end;

function BenchTxLoop(const AConn: IDbConnection): Double;
var
  Tx: IDbTxControl;
  Q: IDbQuery;
  T0, T1: QWord;
begin
  ResetTable(AConn);
  if AConn.QueryInterface(IDbTxControl, Tx) <> 0 then
    Exit(-1);
  T0 := GetTickCount64;
  Tx.BeginTxn(False);
  try
    for GK := 1 to N do
    begin
      Q := AConn.Query('INSERT INTO t_bi VALUES (?, ?)');
      Q.BindInt64(1, GK);
      Q.BindInt64(2, GK * 2);
      while Q.Step do ;
      Q := nil;
    end;
    Tx.CommitTxn;
  except
    if Tx.InTransaction then
      Tx.RollbackTxn;
    raise;
  end;
  T1 := GetTickCount64;
  Result := T1 - T0;
end;

function BenchBatch(const AConn: IDbConnection; const ABatch: IDbBatchExecutor): Double;
var
  Steps: TDbSqlSteps;
  K: Integer;
  T0, T1: QWord;
begin
  ResetTable(AConn);
  SetLength(Steps, N);
  for K := 0 to N - 1 do
    Steps[K] := 'INSERT INTO t_bi VALUES (' + IntToStr(K + 1) + ', ' +
      IntToStr((K + 1) * 2) + ')';
  T0 := GetTickCount64;
  ABatch.ExecuteBatch(Steps);
  T1 := GetTickCount64;
  Result := T1 - T0;
end;

procedure Report(const ABackend, AMode: string; const AMs: Double);
begin
  WriteLn('backend=', ABackend, ' mode=', AMode, ' n=', N,
    ' ms=', Trunc(AMs));
end;

procedure BenchBackend(const AConn: IDbConnection; const AName: string);
var
  Bx: IDbBatchExecutor;
begin
  Report(AName, 'autocommit', BenchAutocommit(AConn));
  Report(AName, 'txloop', BenchTxLoop(AConn));
  if AConn.QueryInterface(IDbBatchExecutor, Bx) = 0 then
    Report(AName, 'batch', BenchBatch(AConn, Bx));
end;

var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  BenchBackend(Conn, 'sqlite');
  Conn := nil;

  if GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN') <> '' then
  begin
    Conn := ConnectPostgres(GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN'));
    BenchBackend(Conn, 'postgres');
    Conn := nil;
  end
  else
    WriteLn('backend=postgres skipped');
end.
