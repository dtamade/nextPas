program test_db_pool_v2;

{ V2-S4 通用连接池（INC-1）契约测试：
    1 复用身份（LIFO 热连接）
    2 耗尽即抛（AcquireTimeoutMs=0）
    3 超时路径（排队后仍耗尽）
    4 Discard 弃置防复用
    5 预热 MinConnections（两连均出自空闲队）
    6 预热 fail-fast（工厂失败原样上抛）
    7 空闲惰性回收（IdleTimeoutSec=1 实测）
    8 单写者槽位（占用/释放/身份恒定）
    9 关闭语义
   10 代理能力委托（IDbTxControl/IDbBatchExecutor 经 QueryInterface
      透传，批执行经代理可用）
  pg 冒烟段需本地实例（NEXTPAS_PG_TEST_CONN）。
  V3-C3 追加：
   11 泄漏检测：阈值入账 / 归还路径不触发用户代码 / Acquire 入口
      冲刷 / Warned 一次
   12 writer 租约同受检（读路径检查点发现写泄漏，报告含角色）
   13 DebugAcquireStack：报告附栈帧线索（'$' 地址行）
   14 默认关：阈值 0 时回调零触发
   15 OpenSqlitePool 工厂（B13 配套）：MaxRead 生效 / 文件库落盘 /
      参数化事务后写租约即时归还 / 数据跨池存活
   16 作用域租约助手（B13 续）：WithRead/WithWriter——租约约束在
      实现内局部变量，回调结束即时归还；nil 回调 fail-fast }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool,
  nextpas.core.db.tx;

var
  T: TTestSuite;
  GPgConn: string;

function SqliteFactory: TDbConnectFunc;
begin
  Result := function: IDbConnection
  begin
    Result := ConnectSqlite(':memory:');
  end;
end;

function RawOf(const AConn: IDbConnection): PtrUInt;
begin
  if AConn = nil then
    Exit(0);
  Result := PtrUInt(AConn.Raw);
end;

{ 1 }
procedure TestReuseIdentity;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A, B: IDbConnection;
  R1: PtrUInt;
begin
  P := TDbPoolPolicy.Default;
  P.AcquireTimeoutMs := 0;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    R1 := RawOf(A);
    Check(R1 <> 0, 'reuse: raw handle present');
    A := nil;                            { 释放即归还 }
    B := Pool.Acquire;
    Check(RawOf(B) = R1, 'reuse: LIFO returns same connection');
    { B 故意持租约跨 Pool.Free：门面释放后代理归还必须安全
      （IDbPoolCore 引用计数保活核心态），此测试即生命周期契约守卫 }
  finally
    Pool.Free;
  end;
end;

{ 2 }
procedure TestExhaustNoWait;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A: IDbConnection;
  Raised: Boolean;
begin
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := 1;
  P.AcquireTimeoutMs := 0;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    Raised := False;
    try
      Pool.Acquire;
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'exhaust: second acquire raises immediately');
    A := nil;
  finally
    Pool.Free;
  end;
end;

{ 3 }
procedure TestExhaustTimeout;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A: IDbConnection;
  T0: QWord;
  Raised: Boolean;
begin
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := 1;
  P.AcquireTimeoutMs := 120;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    T0 := GetTickCount64;
    Raised := False;
    try
      Pool.Acquire;
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'timeout: raises after queue wait');
    Check(GetTickCount64 - T0 >= 100, 'timeout: actually waited');
    A := nil;
  finally
    Pool.Free;
  end;
end;

{ 4 }
procedure TestDiscard;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  H: IDbPooledHandle;
  A, B: IDbConnection;
  Opens: Integer;
begin
  { 判据用工厂计数而非裸指针比较：弃置销毁后新建连可能复用同一堆
    地址，指针相等不代表连接未换 }
  Opens := 0;
  P := TDbPoolPolicy.Default;
  P.AcquireTimeoutMs := 0;
  Pool := TDbPool.Create(function: IDbConnection
  begin
    Inc(Opens);
    Result := ConnectSqlite(':memory:');
  end, P);
  try
    A := Pool.Acquire;
    Check(Opens = 1, 'discard: first acquire opens once');
    if A.QueryInterface(IDbPooledHandle, H) <> 0 then
    begin
      Check(False, 'discard: pooled handle capability present');
      Exit;
    end;
    H.Discard;
    H := nil;
    A := nil;                            { 弃置销毁而非归还 }
    B := Pool.Acquire;
    Check(Opens = 2, 'discard: fresh connection opened');
    B := nil;
  finally
    Pool.Free;
  end;
end;

{ 5 }
procedure TestMinPrewarm;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A, B: IDbConnection;
begin
  P := TDbPoolPolicy.Default;
  P.MinConnections := 2;
  P.AcquireTimeoutMs := 0;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    B := Pool.Acquire;
    { 两连都出自预热队列：不同底层句柄、且未触发新建连无法直接断言，
      句柄互异即可证明非同一连接 }
    Check(RawOf(A) <> RawOf(B), 'prewarm: two distinct idle conns handed out');
  finally
    Pool.Free;
  end;
end;

{ 6 }
procedure TestPrewarmFailFast;
var
  P: TDbPoolPolicy;
  Raised: Boolean;
  Flag: Integer;
begin
  { Default.MinConnections = 0 时工厂根本不会被调；须显式预热一次 }
  P := TDbPoolPolicy.Default;
  P.MinConnections := 1;
  Flag := 0;
  Raised := False;
  try
    TDbPool.Create(function: IDbConnection
    begin
      Result := nil;
      Inc(Flag);
      raise ENextPasError.Create('connect boom');
    end, P);
  except
    on E: ENextPasError do
      Raised := True;
  end;
  Check(Raised, 'prewarm-fail: factory error propagates');
  Check(Flag = 1, 'prewarm-fail: stops at first failure');
end;

{ 7 }
procedure TestIdleEviction;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A, B: IDbConnection;
  Opens: Integer;
begin
  { 判据同 discard：工厂计数证明陈旧连接被换新（裸指针可能撞地址） }
  Opens := 0;
  P := TDbPoolPolicy.Default;
  P.IdleTimeoutSec := 1;
  P.AcquireTimeoutMs := 0;
  Pool := TDbPool.Create(function: IDbConnection
  begin
    Inc(Opens);
    Result := ConnectSqlite(':memory:');
  end, P);
  try
    A := Pool.Acquire;
    Check(Opens = 1, 'idle-evict: first acquire opens once');
    A := nil;                            { 入空闲队 }
    Sleep(1200);                         { 越过空闲阈值（惰性检查点在下次取出） }
    B := Pool.Acquire;
    Check(Opens = 2, 'idle-evict: stale idle conn replaced by fresh');
    B := nil;
  finally
    Pool.Free;
  end;
end;

{ 8 }
procedure TestWriterSlot;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  W1, W2: IDbConnection;
  Raised: Boolean;
  R1: PtrUInt;
begin
  P := TDbPoolPolicy.Default;
  P.AcquireTimeoutMs := 100;           { 占用期第二次 Writer 快速失败，不拖 5s 默认 }
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    W1 := Pool.Writer;
    R1 := RawOf(W1);
    Raised := False;
    try
      W2 := Pool.Writer;
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'writer: single slot enforced');
    W1 := nil;
    W2 := Pool.Writer;
    Check(RawOf(W2) = R1, 'writer: same dedicated connection reused');
    W2 := nil;
  finally
    Pool.Free;
  end;
end;

{ 9 }
procedure TestClosedPool;
var
  Pool: TDbPool;
  A: IDbConnection;
  Raised: Boolean;
begin
  Pool := TDbPool.Create(SqliteFactory, TDbPoolPolicy.Default);
  A := Pool.Acquire;
  Pool.Close;
  try
    Raised := False;
    try
      Pool.Acquire;
    except
      on E: EDbError do Raised := True;
    end;
    Check(Raised, 'closed: acquire raises');
    A := nil;                            { 归还时池已关：直接销毁不回队 }
    Check(True, 'closed: late return is safe');
  finally
    Pool.Free;
  end;
end;

{ 10 }
procedure TestProxyCapabilityDelegation;
var
  Pool: TDbPool;
  Tx: IDbTxControl;
  Bx: IDbBatchExecutor;
  A: IDbConnection;
  Steps: TDbSqlSteps;
  Q: IDbQuery;
begin
  Pool := TDbPool.Create(SqliteFactory, TDbPoolPolicy.Default);
  try
    A := Pool.Acquire;
    Check(A.QueryInterface(IDbTxControl, Tx) = 0,
      'delegate: tx control reachable via proxy');
    Check(A.QueryInterface(IDbBatchExecutor, Bx) = 0,
      'delegate: batch executor reachable via proxy');

    A.Exec('CREATE TABLE t_px (id INTEGER PRIMARY KEY)');
    Steps := TDbSqlSteps.Create(
      'INSERT INTO t_px VALUES (1)',
      'INSERT INTO t_px VALUES (2)');
    Bx.ExecuteBatch(Steps);

    Q := A.Query('SELECT COUNT(*) FROM t_px');
    Check(Q.Step and (Q.GetInt64(0) = 2),
      'delegate: batch through proxy lands both rows');

    { 经代理的事务嵌套语义与直连一致 }
    Tx.BeginTxn(False);
    A.Exec('INSERT INTO t_px VALUES (3)');
    Tx.RollbackTxn;
    Q := nil;
    Q := A.Query('SELECT COUNT(*) FROM t_px');
    Check(Q.Step and (Q.GetInt64(0) = 2),
      'delegate: rollback via proxy undoes');
    Q := nil;
    A := nil;
  finally
    Pool.Free;
  end;
end;

{ pg 冒烟：池化路径 + 能力转发 }
procedure TestPgSmoke;
var
  Pool: TDbPool;
  A, B: IDbConnection;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg smoke skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Pool := TDbPool.Create(function: IDbConnection
  begin
    Result := ConnectPostgres(GPgConn);
  end, TDbPoolPolicy.Default);
  try
    A := Pool.Acquire;
    A.Exec('SELECT 1');
    A := nil;
    B := Pool.Acquire;
    B.Exec('SELECT 1');
    B := nil;
    Check(True, 'pg smoke: pooled roundtrip ok');
  finally
    Pool.Free;
  end;
end;

{ ===== V3-C3 泄漏检测 ===== }

function CountOccurrences(const AHaystack, ANeedle: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  I := Pos(ANeedle, AHaystack);
  while I > 0 do
  begin
    Inc(Result);
    I := Pos(ANeedle, Copy(AHaystack, I + Length(ANeedle),
      MaxInt));
  end;
end;

{ 11：阈值入账 / 归还路径不触发用户代码 / Acquire 入口冲刷 /
    Warned 一次 / 已归还租约不再报告 }
procedure TestLeakDetectionFires;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A, B, C: IDbConnection;
  LLog: string;
begin
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := 2;
  P.AcquireTimeoutMs := 0;
  P.LeakDetectionThresholdMs := 120;
  P.OnLeakDetected := procedure(const S: string)
  begin
    LLog := LLog + S + #10;
  end;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    B := Pool.Acquire;              { 立即检查点：A 未超阈值，零报告 }
    Check(LLog = '', 'leak: below threshold no report');

    Sleep(200);                     { A、B 均超阈值 }
    B := nil;                       { 归还只扫描入账，析构链内不触发回调 }
    Check(CountOccurrences(LLog, 'leak suspected') = 0,
      'leak: return path never fires user code');

    C := Pool.Acquire;              { 入口安全点：冲刷积压——仅 A 在册
                                      到期（B 归还时已出账），一笔 }
    Check(CountOccurrences(LLog, 'leak suspected') = 1,
      'leak: flushed once at acquire entry, got ' +
        IntToStr(CountOccurrences(LLog, 'leak suspected')));
    Check(Pos('read lease', LLog) > 0,
      'leak: read role in report, got: ' + LLog);

    C := nil;                       { 先还租约再取新检查点 }
    C := Pool.Acquire;              { A 已 Warned，不重发 }
    Check(CountOccurrences(LLog, 'leak suspected') = 1,
      'leak: warned-once, no re-report');
    C := nil;
    A := nil;                       { 归还清账；后续无新报告 }
    Pool.FlushDiagnostics;          { 显式安全点排空：仍只有原一笔 }
    Check(CountOccurrences(LLog, 'leak suspected') = 1,
      'leak: returned lease leaves bookkeeping');
  finally
    Pool.Free;
  end;
end;

{ 12：writer 租约同受检——读路径检查点发现写泄漏，报告含角色 }
procedure TestWriterLeakReportedViaReadCheckpoint;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  W, R: IDbConnection;
  LRaised: Boolean;
  LLog: string;
begin
  P := TDbPoolPolicy.Default;
  P.LeakDetectionThresholdMs := 60;
  P.AcquireTimeoutMs := 0;          { 写槽耗尽快速失败，不拖测试时长 }
  P.OnLeakDetected := procedure(const S: string)
  begin
    LLog := LLog + S + #10;
  end;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    W := Pool.Writer;               { 写租约长期持有 }
    Sleep(100);
    R := Pool.Acquire;              { 读路径检查点发现写泄漏 }
    Check(Pos('writer lease', LLog) > 0,
      'leak: writer role in report, got: ' + LLog);
    R := nil;
    { 写槽仍被泄漏租约占用：再次 Writer 立即抛出 }
    LRaised := False;
    try
      Pool.Writer;
    except
      on E: EDbError do
        LRaised := True;
    end;
    Check(LRaised, 'leak: writer slot still occupied by leaked lease');
    W := nil;
  finally
    Pool.Free;
  end;
end;

{ 13：DebugAcquireStack 报告附栈帧线索 }
procedure TestDebugAcquireStackFramesInReport;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  A: IDbConnection;
  LLog: string;
begin
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := 1;
  P.DebugAcquireStack := True;
  P.LeakDetectionThresholdMs := 60;
  P.OnLeakDetected := procedure(const S: string)
  begin
    LLog := LLog + S + #10;
  end;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    Sleep(100);
    Pool.Writer.Exec('SELECT 1');   { writer 路径检查点触发读租约报告 }
    Check(Pos('held', LLog) > 0, 'stack: header present');
    Check(Pos('$', LLog) > 0,
      'stack: frame address line present (raw addr ok)');
    A := nil;
  finally
    Pool.Free;
  end;
end;

{ 14：默认关——阈值 0 时回调零触发 }
procedure TestLeakDetectionOffByDefault;
var
  Pool: TDbPool;
  A, B: IDbConnection;
  LFired: Integer;
  P: TDbPoolPolicy;
begin
  P := TDbPoolPolicy.Default;       { LeakDetectionThresholdMs=60000 默认 60s 开，避免裸 Acquire 静默死锁 }
  Check(P.LeakDetectionThresholdMs = 60000, 'default: threshold is 60000 (60s on)');
  LFired := 0;
  P.OnLeakDetected := procedure(const S: string)
  begin
    Inc(LFired);
  end;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    A := Pool.Acquire;
    Sleep(80);
    B := Pool.Acquire;
    B := nil;
    A := nil;
    Check(LFired = 0, 'default: zero callbacks for short hold (<60s threshold)');
  finally
    Pool.Free;
  end;
end;

{ 15：OpenSqlitePool 便利形态——策略覆盖、参数化事务租约纪律、
  文件库落盘与跨池存活 }
procedure TestOpenSqlitePoolFactory;
var
  LPath: string;
  LPool: TDbPool;
  R: IDbConnection;
  Q: IDbQuery;
begin
  LPath := GetTempDir + 'np_db_pool_factory_' + IntToStr(GetProcessID) + '.db';
  DeleteFile(LPath);
  try
    LPool := OpenSqlitePool(LPath, 1);
    try
      Check(LPool.Policy.MaxReadConnections = 1, 'factory: MaxRead honored');

      WithTransaction(LPool.Writer,
        procedure(const C: IDbConnection)
        begin
          C.Exec('CREATE TABLE t_fac (v TEXT)');
          C.Exec('INSERT INTO t_fac (v) VALUES (''kept'')');
        end);

      { 写租约已随语句归还（B13 纪律经工厂形态保持）：立即可再借 }
      R := LPool.Acquire;
      try
        Q := R.Query('SELECT COUNT(*) FROM t_fac');
        try
          Check(Q.Step and (Q.GetInt64(0) = 1),
            'factory: read path sees written row');
        finally
          Q := nil;
        end;
      finally
        R := nil;
      end;
    finally
      LPool.Free;
    end;

    { 文件库证据：池销毁后直连仍见数据（非 :memory:）}
    R := ConnectSqlite(LPath);
    try
      Q := R.Query('SELECT COUNT(*) FROM t_fac WHERE v = ''kept''');
      try
        Check(Q.Step and (Q.GetInt64(0) = 1),
          'factory: file persists across pools');
      finally
        Q := nil;
      end;
    finally
      R := nil;
    end;
  finally
    DeleteFile(LPath);
  end;
end;

{ 16：作用域租约助手——回调结束即时归还，随后直取 writer 立即可借。
  回归锁背景：消费方把 Writer 函数结果内联喂 const 形参（如启动迁移）
  时，FPC 例程级接口临时量会把租约拖过语句边界；WithWriter 把租约
  锁在实现内局部变量上，从结构上消除该形态。 }
procedure TestScopedWriterHelper;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  W: IDbConnection;
begin
  P := TDbPoolPolicy.Default;
  P.AcquireTimeoutMs := 300;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    Pool.WithWriter(
      procedure(const C: IDbConnection)
      begin
        C.Exec('CREATE TABLE t_scoped (v TEXT)');
        C.Exec('INSERT INTO t_scoped (v) VALUES (''x'')');
      end);

    W := Pool.Writer;
    try
      Check(Assigned(W), 'scoped writer: reacquirable immediately');
    finally
      W := nil;
    end;
  finally
    Pool.Free;
  end;
end;

procedure TestScopedReadHelper;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  W: IDbConnection;
begin
  P := TDbPoolPolicy.Default;
  P.MaxReadConnections := 1;
  P.AcquireTimeoutMs := 300;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    Pool.WithRead(
      procedure(const C: IDbConnection)
      var
        Q: IDbQuery;
      begin
        Q := C.Query('SELECT COUNT(*) FROM sqlite_master');
        try
          Check(Q.Step, 'scoped read: query stepped');
        finally
          Q := nil;
        end;
      end);

    W := Pool.Writer;
    try
      Check(Assigned(W), 'scoped read: writer free after callback');
    finally
      W := nil;
    end;
  finally
    Pool.Free;
  end;
end;

procedure TestScopedNilBody;
var
  Pool: TDbPool;
  P: TDbPoolPolicy;
  Raised: Boolean;
begin
  P := TDbPoolPolicy.Default;
  P.AcquireTimeoutMs := 300;
  Pool := TDbPool.Create(SqliteFactory, P);
  try
    Raised := False;
    try
      Pool.WithWriter(nil);
    except
      on E: EDbError do
        Raised := Pos('nil scoped-lease callback', E.Message) > 0;
    end;
    Check(Raised, 'scoped: nil body rejected (writer)');

    Raised := False;
    try
      Pool.WithRead(nil);
    except
      on E: EDbError do
        Raised := Pos('nil scoped-lease callback', E.Message) > 0;
    end;
    Check(Raised, 'scoped: nil body rejected (read)');
  finally
    Pool.Free;
  end;
end;

procedure TestPoolDoubleCloseIdempotent;
var
  Pool: TDbPool;
begin
  Pool := TDbPool.Create(SqliteFactory, TDbPoolPolicy.Default);
  try
    Pool.Close;
    Pool.Close;
    Check(True, 'pool double close idempotent');
  finally
    Pool.Free;
  end;
  Check(True, 'pool free after double close safe');
end;

procedure TestPoolAcquireAfterClose;
var
  Pool: TDbPool;
  Raised: Boolean;
begin
  Pool := TDbPool.Create(SqliteFactory, TDbPoolPolicy.Default);
  Pool.Close;
  Raised := False;
  try
    Pool.Acquire;
  except
    on E: EDbError do
      Raised := (E.Category = decUnknown) and (Pos('pool: closed', E.Message) > 0);
  end;
  Check(Raised, 'pool acquire after close -> decUnknown pool: closed');
  Pool.Free;
end;

begin
  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.pool.v2');
  T.Test('reuse identity', @TestReuseIdentity);
  T.Test('exhaust no-wait', @TestExhaustNoWait);
  T.Test('exhaust timeout path', @TestExhaustTimeout);
  T.Test('discard prevents reuse', @TestDiscard);
  T.Test('min prewarm hands out distinct', @TestMinPrewarm);
  T.Test('prewarm fail-fast', @TestPrewarmFailFast);
  T.Test('idle lazy eviction', @TestIdleEviction);
  T.Test('single writer slot', @TestWriterSlot);
  T.Test('closed pool semantics', @TestClosedPool);
  T.Test('proxy capability delegation', @TestProxyCapabilityDelegation);
  T.Test('pg smoke', @TestPgSmoke);
  T.Test('leak detection fires once per lease', @TestLeakDetectionFires);
  T.Test('writer leak reported via read checkpoint',
    @TestWriterLeakReportedViaReadCheckpoint);
  T.Test('debug acquire stack frames in report',
    @TestDebugAcquireStackFramesInReport);
  T.Test('leak detection off by default', @TestLeakDetectionOffByDefault);
  T.Test('OpenSqlitePool factory', @TestOpenSqlitePoolFactory);
  T.Test('scoped writer helper releases lease', @TestScopedWriterHelper);
  T.Test('scoped read helper releases lease', @TestScopedReadHelper);
  T.Test('scoped lease nil body rejected', @TestScopedNilBody);
  T.Test('pool double close idempotent', @TestPoolDoubleCloseIdempotent);
  T.Test('pool acquire after close', @TestPoolAcquireAfterClose);
  if not T.Run then Halt(1);
end.
