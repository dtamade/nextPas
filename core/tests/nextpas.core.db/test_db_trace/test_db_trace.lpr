program test_db_trace;

{ V3-B3 观测钩子门禁：IDbTraceListener/IDbTraceControl 契约钉死。
  覆盖面（CONTRACT §2.12 同文）：
    1  摘要纯函数（折叠空白/截断 ≤ DB_TRACE_SQL_SUMMARY_MAX）
    2  sqlite 全量（离线）：挂载补发 OnAcquire、计数契约
       （3 Exec + 2 Query = 5 OnQuery）、多 Step 只计一次、Reset
       重武装、错误类目直透且不发 OnQuery、摘要保真/折叠/截断、
       SetListener(nil) 归零、Acquire/Release 1:1 配对、零监听冒烟
    3  pg 真机段（NEXTPAS_PG_TEST_CONN 门控）：decSyntax 直透、
       占位符原文保留进摘要、Exec(opts) 超时路径也发 OnError
    4  mysql/odbc live 探针（各自 env 门控）：能力面存在性

  heaptrc 0 unfreed 为硬门槛：监听器以接口引用持有，枢纽随连接
  析构释放。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db,
  nextpas.core.db.trace;

type
  { 记录型监听器：计数 + 事件序列留痕。对象生命周期由测试持有的
    接口引用管理（TInterfacedObject 引用计数）。 }
  TRecordingListener = class(TInterfacedObject, IDbTraceListener)
  private
    FAcquire, FRelease, FQuery, FError: Integer;
    FSums: array of string;      { OnQuery 摘要按序 }
    FDurs: array of Int64;       { OnQuery 时长按序 }
    FErrSums: array of string;   { OnError 摘要按序 }
    FCats: array of TDbErrorCategory;
    function GetSum(AIdx: Integer): string;
    function GetDur(AIdx: Integer): Int64;
    function GetErrSum(AIdx: Integer): string;
    function GetCat(AIdx: Integer): TDbErrorCategory;
  public
    procedure OnAcquire;
    procedure OnRelease;
    procedure OnQuery(const ADurationMs: Int64;
      const ASqlSummary: string);
    procedure OnError(const ACategory: TDbErrorCategory;
      const ASqlSummary: string);
    property AcquireCount: Integer read FAcquire;
    property ReleaseCount: Integer read FRelease;
    property QueryCount: Integer read FQuery;
    property ErrorCount: Integer read FError;
    property Sum[AIdx: Integer]: string read GetSum;
    property Dur[AIdx: Integer]: Int64 read GetDur;
    property ErrSum[AIdx: Integer]: string read GetErrSum;
    property Cat[AIdx: Integer]: TDbErrorCategory read GetCat;
  end;

var
  T: TTestSuite;

procedure TRecordingListener.OnAcquire;
begin
  Inc(FAcquire);
end;

procedure TRecordingListener.OnRelease;
begin
  Inc(FRelease);
end;

procedure TRecordingListener.OnQuery(const ADurationMs: Int64;
  const ASqlSummary: string);
begin
  Inc(FQuery);
  SetLength(FSums, Length(FSums) + 1);
  FSums[High(FSums)] := ASqlSummary;
  SetLength(FDurs, Length(FDurs) + 1);
  FDurs[High(FDurs)] := ADurationMs;
end;

procedure TRecordingListener.OnError(const ACategory: TDbErrorCategory;
  const ASqlSummary: string);
begin
  Inc(FError);
  SetLength(FErrSums, Length(FErrSums) + 1);
  FErrSums[High(FErrSums)] := ASqlSummary;
  SetLength(FCats, Length(FCats) + 1);
  FCats[High(FCats)] := ACategory;
end;

function TRecordingListener.GetSum(AIdx: Integer): string;
begin
  Result := FSums[AIdx];
end;

function TRecordingListener.GetDur(AIdx: Integer): Int64;
begin
  Result := FDurs[AIdx];
end;

function TRecordingListener.GetErrSum(AIdx: Integer): string;
begin
  Result := FErrSums[AIdx];
end;

function TRecordingListener.GetCat(AIdx: Integer): TDbErrorCategory;
begin
  Result := FCats[AIdx];
end;

{ ==== 1. 摘要纯函数 ==== }

procedure TestSummaryFunction;
var
  LS: string;
begin
  CheckEqual(DbTraceSqlSummary(''), '', 'summary: empty stays empty');
  CheckEqual(DbTraceSqlSummary('SELECT 1'), 'SELECT 1',
    'summary: verbatim single-spaced');
  CheckEqual(DbTraceSqlSummary('  a '#9#10#13' b  '), 'a b',
    'summary: folds whitespace and trims both ends');
  { 截断边界：恰等于上限原样保留；超限截到上限 }
  LS := StringOfChar('a', DB_TRACE_SQL_SUMMARY_MAX);
  CheckEqual(DbTraceSqlSummary(LS), LS, 'summary: exact cap kept');
  LS := StringOfChar('a', DB_TRACE_SQL_SUMMARY_MAX + 100);
  CheckEqual(Int64(Length(DbTraceSqlSummary(LS))),
    Int64(DB_TRACE_SQL_SUMMARY_MAX), 'summary: over-long truncated to cap');
end;

{ ==== 2. sqlite 全量 ==== }

procedure TestSqliteTrace;
var
  Conn, CPair: IDbConnection;
  TC, TCPair: IDbTraceControl;
  L, LPair: TRecordingListener;
  LI, LPairI: IDbTraceListener;   { 对象存活锚：防枢纽侧唯一强引用提前释放 }
  Q: IDbQuery;
  LOpts: TDbExecOptions;
  LRaised: Boolean;
  LLong: string;
  I, LQ0, LE0: Integer;
begin
  { 零监听冒烟：未挂监听器全功能可用，HasListener 如实为 False }
  Conn := ConnectSqlite(':memory:');
  TC := DbTraceControl(Conn);
  Check(TC <> nil, 'sqlite: DbTraceControl probe non-nil');
  Check(not TC.HasListener, 'sqlite: fresh conn has no listener');
  TC.SetListener(nil);   { 幂等：无监听器时关闭无副作用 }
  Check(not TC.HasListener, 'sqlite: nil-off idempotent');

  { 挂载即补发 OnAcquire（§2.12）}
  L := TRecordingListener.Create;
  LI := L;
  TC.SetListener(LI);
  Check(TC.HasListener, 'sqlite: listener active after attach');
  Check(L.AcquireCount = 1, 'sqlite: attach fires exactly one OnAcquire');

  { 计数契约：3 Exec + 2 Query = 5 次 OnQuery；查询多 Step 只计一次 }
  Conn.Exec('CREATE TABLE t (v INTEGER)');
  Conn.Exec('INSERT INTO t VALUES (1)');
  Conn.Exec('INSERT INTO t VALUES (2)');
  Q := Conn.Query('SELECT v FROM t');
  Check(Q.Step and Q.Step and not Q.Step, 'sqlite: three rows stepped');
  Q.Reset;                                   { 重执行周期重新计时 }
  Check(Q.Step and Q.Step and not Q.Step, 'sqlite: post-reset rows');
  Q := nil;
  Check(L.QueryCount = 5,
    'sqlite: 3 exec + 2 exec-cycles = 5 OnQuery, got ' +
    IntToStr(L.QueryCount));
  CheckEqual(L.Sum[0], 'CREATE TABLE t (v INTEGER)', 'sqlite: summary #0');
  CheckEqual(L.Sum[3], 'SELECT v FROM t', 'sqlite: multi-step one summary');

  { 时长如实记录且非负（单调时钟换算）}
  for I := 0 to L.QueryCount - 1 do
    Check(L.Dur[I] >= 0, 'sqlite: duration #' + IntToStr(I) + ' >= 0');

  { 折叠：字面量外连续空白归一 }
  Conn.Exec('INSERT'#13#10#9'INTO t'#9'VALUES '#10'(3)');
  CheckEqual(L.Sum[L.QueryCount - 1], 'INSERT INTO t VALUES (3)',
    'sqlite: whitespace folded in summary');

  { 错误直透：失败发 OnError 不发 OnQuery；类目 = EDbError.Category；
    sqlite 无细粒度码 → decUnknown（与 conformance §5 同表）}
  LQ0 := L.QueryCount;
  LE0 := L.ErrorCount;
  LRaised := False;
  try
    Conn.Exec('SELEC 1');
  except
    on E: EDbError do
    begin
      LRaised := True;
      Check(E.Category = decUnknown, 'sqlite: syntax classed decUnknown');
    end;
  end;
  Check(LRaised, 'sqlite: bad SQL raised');
  Check(L.ErrorCount = LE0 + 1, 'sqlite: OnError fired once');
  Check(L.QueryCount = LQ0, 'sqlite: failed exec sends no OnQuery');
  CheckEqual(L.ErrSum[LE0], 'SELEC 1', 'sqlite: error summary text');
  Check(L.Cat[LE0] = decUnknown, 'sqlite: error category passthrough');

  { 截断：超长 SQL 摘要钉在上限内，与纯函数输出一致 }
  LLong := 'SELECT ''' + StringOfChar('x', 2000) + '''';
  Conn.Exec(LLong);
  Check(Int64(Length(L.Sum[L.QueryCount - 1])) <= DB_TRACE_SQL_SUMMARY_MAX,
    'sqlite: live summary within cap');
  CheckEqual(L.Sum[L.QueryCount - 1], DbTraceSqlSummary(LLong),
    'sqlite: live summary equals pure function');

  { SetListener(nil) 关闭归零 }
  TC.SetListener(nil);
  Check(not TC.HasListener, 'sqlite: listener off');
  LQ0 := L.QueryCount;
  Conn.Exec('INSERT INTO t VALUES (4)');
  Check(L.QueryCount = LQ0, 'sqlite: no events after detach');

  { 重挂载再次补发 OnAcquire（新监听会话）}
  TC.SetListener(LI);
  Check(L.AcquireCount = 2, 'sqlite: re-attach fires OnAcquire again');

  { 查询级选项 advisory 与追踪共存（opts<=0 委托路径无双发）}
  LOpts := TDbExecOptions.Default;
  LQ0 := L.QueryCount;
  Conn.Exec('SELECT 1', LOpts);
  Check(L.QueryCount = LQ0 + 1, 'sqlite: opts exec traced once');

  { 配对：专用连接 + 专听者，1 挂载对 1 析构释放。
    注意先清控制面引用再清连接引用——IDbTraceControl 也是强引用 }
  CPair := ConnectSqlite(':memory:');
  TCPair := DbTraceControl(CPair);
  LPair := TRecordingListener.Create;
  LPairI := LPair;
  TCPair.SetListener(LPairI);
  Check(LPair.AcquireCount = 1, 'pair: acquire on attach');
  TCPair := nil;
  CPair := nil;
  Check((LPair.AcquireCount = 1) and (LPair.ReleaseCount = 1),
    'pair: destroy fires matching release');

  { 主连接析构 → OnRelease }
  TC := nil;
  Conn := nil;
  Check(L.ReleaseCount = 1,
    'sqlite: destroy fires one OnRelease, got ' +
    IntToStr(L.ReleaseCount));
end;

{ ==== 3. pg 真机段 ==== }

procedure TestPgTrace;
var
  Conn: IDbConnection;
  TC: IDbTraceControl;
  L: TRecordingListener;
  LI: IDbTraceListener;
  Q: IDbQuery;
  LOpts: TDbExecOptions;
  LRaised: Boolean;
begin
  if GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN') = '' then
  begin
    WriteLn('pg section skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN'));
  TC := DbTraceControl(Conn);
  Check(TC <> nil, 'pg: DbTraceControl probe non-nil');
  L := TRecordingListener.Create;
  LI := L;
  TC.SetListener(LI);
  Check(L.AcquireCount = 1, 'pg: attach fires OnAcquire');

  Conn.Exec('DROP TABLE IF EXISTS np_trace_pg');
  Conn.Exec('CREATE TABLE np_trace_pg (v INTEGER)');
  Q := Conn.Query('SELECT ?::int4');          { 占位符原文保留进摘要 }
  Q.BindInt64(1, 7);
  Check(Q.Step and (Q.GetInt64(0) = 7), 'pg: parametrized query works');
  Q := nil;
  Check(L.QueryCount = 3, 'pg: 2 exec + 1 query = 3 OnQuery, got ' +
    IntToStr(L.QueryCount));
  CheckEqual(L.Sum[2], 'SELECT ?::int4', 'pg: placeholder kept in summary');

  { 真机 decSyntax 直透（SQLSTATE 42 类）}
  LRaised := False;
  try
    Conn.Exec('SELEC 1');
  except
    on E: EDbError do
    begin
      LRaised := True;
      Check(E.Category = decSyntax, 'pg: syntax classed decSyntax');
    end;
  end;
  Check(LRaised and (L.ErrorCount = 1), 'pg: OnError fired once');
  Check(L.Cat[0] = decSyntax, 'pg: category passthrough decSyntax');

  { 查询级选项超时路径同样直透（opts>0 非委托分支插桩验证）}
  LOpts := TDbExecOptions.Default;
  LOpts.TimeoutMs := 100;
  LRaised := False;
  try
    Conn.Exec('SELECT pg_sleep(1)', LOpts);
  except
    on E: EDbError do
      LRaised := E.Category = decTimeout;
  end;
  Check(LRaised, 'pg: opts exec timeout decTimeout');
  Check(L.ErrorCount = 2, 'pg: opts-path error also traced');

  Conn.Exec('DROP TABLE IF EXISTS np_trace_pg');
  TC := nil;   { 控制面引用先清，再放连接 }
  Conn := nil;
  Check((L.ReleaseCount = 1) and (L.ReleaseCount = L.AcquireCount),
    'pg: acquire/release pair 1:1');
end;

{ ==== 4. mysql / odbc live 探针（各 env 门控）==== }

procedure TestMysqlProbe;
var
  Conn: IDbConnection;
  TC: IDbTraceControl;
begin
  if GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN') = '' then
  begin
    WriteLn('mysql section skipped (NEXTPAS_MYSQL_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectMysql(GetEnvironmentVariable('NEXTPAS_MYSQL_TEST_CONN'));
  TC := DbTraceControl(Conn);
  Check(TC <> nil, 'mysql: DbTraceControl probe non-nil');
  Check(not TC.HasListener, 'mysql: fresh conn has no listener');
  Conn := nil;
end;

procedure TestOdbcProbe;
var
  Conn: IDbConnection;
  TC: IDbTraceControl;
begin
  if GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN') = '' then
  begin
    WriteLn('odbc section skipped (NEXTPAS_ODBC_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectOdbc(GetEnvironmentVariable('NEXTPAS_ODBC_TEST_CONN'));
  TC := DbTraceControl(Conn);
  Check(TC <> nil, 'odbc: DbTraceControl probe non-nil');
  Check(not TC.HasListener, 'odbc: fresh conn has no listener');
  Conn := nil;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.trace');
  T.Test('sql summary pure function', @TestSummaryFunction);
  T.Test('sqlite trace contract', @TestSqliteTrace);
  T.Test('postgres trace live', @TestPgTrace);
  T.Test('mysql live probe', @TestMysqlProbe);
  T.Test('odbc live probe', @TestOdbcProbe);
  if not T.Run then Halt(1);
end.
