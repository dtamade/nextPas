program bench_db_batch_insert;

{ 批量写入四路基准（§12.4 验收判据的数据源）：
    autocommit : 每行独立隐式事务（最差基线）
    txloop     : 单事务内逐条参数化执行
    batch      : IDbBatchExecutor（pg=单次往返合并；sqlite=单事务逐条）
    array      : IDbArrayBinding 参数级批量（pg unnest 单语句单次
                 往返；V3-C2。后端不支持则静默跳过）
  输出行格式：backend=<k> mode=<m> n=<rows> ms=<ms>
  sqlite 段总是执行；pg 段需要 NEXTPAS_PG_TEST_CONN。 }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.os.env,
  nextpas.core.base.utils,
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

{ V3-C2：参数级批量（unnest 数组展开）。绑定/编码计入计时口径——
  消费方真实成本包含构造列数组与一次 BeginBind。
  注意先探能力再建查询：sqlite Query 急切 prepare，pg 方言 SQL
  会在构建期抛语法错。 }
function BenchArrayInsert(const AConn: IDbConnection): Double;
var
  Q: IDbQuery;
  B: IDbArrayBinding;
  Cap: IDbCapabilities;
  Ids: TDbInt64Array;
  Vals: TDbInt64Array;
  K: Integer;
  T0, T1: QWord;
begin
  Supports(AConn, IDbCapabilities, Cap);
  if (Cap = nil) or (not Cap.SupportsArrayBinding) then
    Exit(-1);                            { 后端未支持：静默跳过 }
  ResetTable(AConn);
  SetLength(Ids, N);
  SetLength(Vals, N);
  for K := 0 to N - 1 do
  begin
    Ids[K] := K + 1;
    Vals[K] := (K + 1) * 2;
  end;
  Q := AConn.Query(
    'INSERT INTO t_bi SELECT * FROM unnest(?::bigint[], ?::bigint[])');
  B := DbArrayBinding(Q);
  T0 := GetTickCount64;
  B.BeginBind(N);
  B.BindInt64Column(1, Ids);
  B.BindInt64Column(2, Vals);
  while Q.Step do ;
  T1 := GetTickCount64;
  B := nil;
  Q := nil;
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
  LMs: Double;
begin
  Report(AName, 'autocommit', BenchAutocommit(AConn));
  Report(AName, 'txloop', BenchTxLoop(AConn));
  if AConn.QueryInterface(IDbBatchExecutor, Bx) = 0 then
    Report(AName, 'batch', BenchBatch(AConn, Bx));
  LMs := BenchArrayInsert(AConn);       { <0 = 后端未支持，静默跳过 }
  if LMs >= 0 then
    Report(AName, 'array', LMs);
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
  { mysql 段：N=10000 在回环 TCP 上 ~3.6s/10k（adapter_overhead 实测），
    batch 四路全开总计 >10s，不进默认 bench 以免掩盖 pg 核心口径。
    需单独评估时设 NEXTPAS_MYSQL_TEST_CONN 并单跑 adapter_overhead。 }
end.
