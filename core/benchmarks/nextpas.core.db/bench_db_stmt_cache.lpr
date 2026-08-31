program bench_db_stmt_cache;

{ 语句缓存对照基准（INC-3 性能门禁，§12.4 数据源）：
    nocache : ConnectSqlite(path, 0) / ConnectPostgres(conn, opts, 0)
              ——每次 Query 全新 prepare+finalize / PQexecParams
    cached  : 默认容量 LRU 空闲语句池 / 服务端 prepared 注册表
  工作负载：参数化单行查找 × N（热路径典型形态），另附多行扫描形态。
  输出行格式：mode=<m> workload=<w> n=<n> ms=<ms> ops_per_sec=<n>
              [hit_rate=<r>]
  sqlite :memory: 总是执行；pg 段需本地实例（NEXTPAS_PG_TEST_CONN，
  V3-C1 起输出 pg 对照组）。 }

{$mode ObjFPC}{$H+}
{$modeswitch functionreferences}{$modeswitch anonymousfunctions}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.bulk,
  nextpas.core.db.intf;

const
  N_POINT = 50000;                       { 单行查找轮数 }
  N_SCAN = 2000;                         { 多行扫描轮数 }
  KEYS = 512;

var
  GK: Integer;

procedure Seed(const AConn: IDbConnection);
var
  I: Integer;
begin
  AConn.Exec('DROP TABLE IF EXISTS t');
  AConn.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER)');
  AConn.Exec('INSERT INTO t VALUES (0, 0)');
  for I := 1 to KEYS do
    AConn.Exec('INSERT INTO t VALUES (' + IntToStr(I) + ', ' +
      IntToStr(I * 7) + ')');
end;

function BenchPointLookups(const AConn: IDbConnection): QWord;
var
  Q: IDbQuery;
  Sum: Int64;
  T0, T1: QWord;
begin
  Sum := 0;
  T0 := GetTickCount64;
  for GK := 1 to N_POINT do
  begin
    Q := AConn.Query('SELECT v FROM t WHERE id = ?');
    Q.BindInt64(1, (GK mod KEYS) + 1);
    if Q.Step then
      Inc(Sum, Q.GetInt64(0));
    Q := nil;
  end;
  T1 := GetTickCount64;
  if Sum < 0 then WriteLn;               { 结果参与消费，抑制死代码消除 }
  Result := T1 - T0;
end;

function BenchRowScans(const AConn: IDbConnection): QWord;
var
  Q: IDbQuery;
  Rows, Sum: Int64;
  T0, T1: QWord;
begin
  Sum := 0;
  T0 := GetTickCount64;
  for GK := 1 to N_SCAN do
  begin
    Q := AConn.Query('SELECT v FROM t WHERE id > ? ORDER BY id');
    Q.BindInt64(1, GK mod 64);
    Rows := 0;
    while Q.Step do
      Inc(Rows);
    Inc(Sum, Rows);
    Q := nil;
  end;
  T1 := GetTickCount64;
  if Sum < 0 then WriteLn;               { 抑制警告：Sum 参与消费 }
  Result := T1 - T0;
end;

procedure RunMode(const AMode: string; const AConn: IDbConnection);
var
  Ctrl: IDbStmtCacheControl;
  Ms: QWord;
begin
  Ms := BenchPointLookups(AConn);
  Write('mode=', AMode, ' workload=point n=', N_POINT, ' ms=', Ms);
  if Ms > 0 then
    Write(' ops_per_sec=', Int64(N_POINT) * 1000 div PtrInt(Ms));
  if (AMode = 'cached') and
     (AConn.QueryInterface(IDbStmtCacheControl, Ctrl) = 0) then
    Write(' hit_rate=', Ctrl.HitRate:0:4);
  WriteLn;

  Ms := BenchRowScans(AConn);
  Write('mode=', AMode, ' workload=scan n=', N_SCAN, ' ms=', Ms);
  if Ms > 0 then
    Write(' ops_per_sec=', Int64(N_SCAN) * 1000 div PtrInt(Ms));
  WriteLn;
end;

var
  Cached, Plain: IDbConnection;
  Opts: TDbConnectOptions;
  GPgConn: string;
begin
  Plain := ConnectSqlite(':memory:', 0);
  Seed(Plain);
  RunMode('nocache', Plain);
  Plain := nil;

  Cached := ConnectSqlite(':memory:');
  Seed(Cached);
  { 预热一轮，使命中率进入稳态后再计量 }
  BenchPointLookups(Cached);
  RunMode('cached', Cached);
  Cached := nil;

  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  if GPgConn <> '' then
  begin
    Opts := TDbConnectOptions.Default;
    Plain := ConnectPostgres(GPgConn, Opts, 0);
    Seed(Plain);
    RunMode('pg-nocache', Plain);
    Plain := nil;

    Cached := ConnectPostgres(GPgConn, Opts, DEFAULT_PG_STMT_CACHE_CAPACITY);
    Seed(Cached);
    BenchPointLookups(Cached);           { 预热进稳态 }
    RunMode('pg-cached', Cached);
    Cached := nil;
  end
  else
    WriteLn('pg section skipped (NEXTPAS_PG_TEST_CONN not set)');
  WriteLn('stmt-cache-bench=pass');
end.
