program test_db_tx_v2;

{ V2-S2 统一层事务助手 savepoint 混合模型契约测试：
    1 核心新语义：内层失败被捕获后真正只撤销内层写入，外层继续并提交
      （v1 计数模型下内层写入会悬在外层事务里随外层提交）
    2 三层嵌套：中层失败撤销中层与其后全部更深 savepoint 效果
    3 手动外层事务 + 助手内层组合：内层走 savepoint，失败被捕获后
      手动 COMMIT 成功（两入口分工的协作面）
    4 TxDepth = 真实 SQL 事务深度：savepoint 层不计入；手动嵌套
      计数语义保持 v1
    5 同层兄弟内层顺序复用同名 savepoint 安全
    6 嵌套要求 savepoint 能力：无该能力的连接 fail-fast，
      且外层照常回滚收尾（TFakeTxConn mock）
    7 守卫回归：nil 连接 / nil 回调 / 无事务控制能力
    8 参数化回调形态零捕获：池化写租约即时归还（B13）
    9 参数化重试形态：重试结束即归还池化租约（B13）
  pg 侧同核心语义由 test_db_conformance 双后端覆盖。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf;

var
  T: TTestSuite;

function CountRows(const AConn: IDbConnection; const ATag: string): Int64;
var
  Q: IDbQuery;
begin
  Q := AConn.Query('SELECT COUNT(*) FROM t_nx WHERE tag = ''' + ATag + '''');
  try
    Q.Step;
    Result := Q.GetInt64(0);
  finally
    Q := nil;
  end;
end;

procedure MakeTable(const AConn: IDbConnection);
begin
  AConn.Exec('CREATE TABLE t_nx (id INTEGER PRIMARY KEY, tag TEXT)');
end;

{ 1 }
procedure TestInnerFailurePartialRollback;
var
  Conn: IDbConnection;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    MakeTable(Conn);
    Raised := False;
    try
      WithTransaction(Conn, procedure(const C: IDbConnection)
      begin
        Conn.Exec('INSERT INTO t_nx (tag) VALUES (''outer-keep'')');
        try
          WithTransaction(Conn, procedure(const C: IDbConnection)
          begin
            Conn.Exec('INSERT INTO t_nx (tag) VALUES (''inner-doomed'')');
            raise Exception.Create('inner boom');
          end);
        except
          on E: Exception do
            if E.Message = 'inner boom' then
              Raised := True;
        end;
        Conn.Exec('INSERT INTO t_nx (tag) VALUES (''after-inner'')');
      end);
    finally
      Check(Raised, 'partial: inner exception surfaced to caller');
    end;
    Check(CountRows(Conn, 'outer-keep') = 1,
      'partial: outer write kept');
    Check(CountRows(Conn, 'after-inner') = 1,
      'partial: post-capture write committed');
    Check(CountRows(Conn, 'inner-doomed') = 0,
      'partial: inner write truly undone (not deferred to outer commit)');
  finally
    Conn := nil;
  end;
end;

{ 2 }
procedure TestThreeLevelNesting;
var
  Conn: IDbConnection;
begin
  Conn := ConnectSqlite(':memory:');
  try
    MakeTable(Conn);
    WithTransaction(Conn, procedure(const C: IDbConnection)
    begin
      Conn.Exec('INSERT INTO t_nx (tag) VALUES (''lv1-keep'')');
      try
        WithTransaction(Conn, procedure(const C: IDbConnection)
        begin
          WithTransaction(Conn, procedure(const C: IDbConnection)
          begin
            Conn.Exec('INSERT INTO t_nx (tag) VALUES (''lv3-swallowed'')');
          end);
          Conn.Exec('INSERT INTO t_nx (tag) VALUES (''lv2-doomed'')');
          raise Exception.Create('mid boom');
        end);
      except
        on E: Exception do ;
      end;
      Conn.Exec('INSERT INTO t_nx (tag) VALUES (''lv1-after'')');
    end);
    Check(CountRows(Conn, 'lv1-keep') = 1, 'nested3: lv1 first write kept');
    Check(CountRows(Conn, 'lv1-after') = 1, 'nested3: lv1 later write kept');
    Check(CountRows(Conn, 'lv2-doomed') = 0, 'nested3: mid write undone');
    Check(CountRows(Conn, 'lv3-swallowed') = 0,
      'nested3: deeper savepoint effects die with mid rollback');
  finally
    Conn := nil;
  end;
end;

{ 3 }
procedure TestManualOuterWithHelperInner;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    MakeTable(Conn);
    Check(Conn.QueryInterface(IDbTxControl, Tx) = 0, 'manual: tx control');
    Tx.BeginTxn(False);
    Conn.Exec('INSERT INTO t_nx (tag) VALUES (''manual-outer'')');
    Raised := False;
    try
      WithTransaction(Conn, procedure(const C: IDbConnection)
      begin
        Conn.Exec('INSERT INTO t_nx (tag) VALUES (''helper-doomed'')');
        raise Exception.Create('inner boom under manual outer');
      end);
    except
      on E: Exception do
        Raised := True;
    end;
    Check(Raised, 'manual: inner failure re-raised');
    Check(Tx.TxDepth = 1, 'manual: helper left real depth untouched');
    Tx.CommitTxn;
    Check(CountRows(Conn, 'manual-outer') = 1,
      'manual: outer commit persists');
    Check(CountRows(Conn, 'helper-doomed') = 0,
      'manual: helper scope rolled back via savepoint, not the outer txn');
  finally
    Conn := nil;
  end;
end;

{ 4 }
procedure TestTxDepthReflectsRealTransaction;
var
  Conn: IDbConnection;
  Tx: IDbTxControl;
  LObserved: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Check(Conn.QueryInterface(IDbTxControl, Tx) = 0, 'depth: tx control');
    Check(Tx.TxDepth = 0, 'depth: zero before any scope');

    WithTransaction(Conn, procedure(const C: IDbConnection)
    begin
      Check(Tx.TxDepth = 1, 'depth: one inside outermost helper scope');
      WithTransaction(Conn, procedure(const C: IDbConnection)
      begin
        Check(Tx.TxDepth = 1,
          'depth: still one in nested scope (savepoint is not a transaction)');
      end);
    end);
    Check(Tx.TxDepth = 0, 'depth: back to zero after outer commit');

    { 手动嵌套保持 v1 计数语义 }
    Tx.BeginTxn(False);
    Tx.BeginTxn(False);
    Check(Tx.TxDepth = 2, 'depth: manual nesting counts up as before');
    LObserved := -1;
    WithTransaction(Conn, procedure(const C: IDbConnection)
    begin
      LObserved := Tx.TxDepth;
    end);
    Check(LObserved = 2,
      'depth: helper under manual nesting takes savepoint route (no depth bump)');
    Tx.CommitTxn;                          { 降计数 }
    Check(Tx.TxDepth = 1, 'depth: manual inner commit decrements only');
    Tx.CommitTxn;
    Check(Tx.TxDepth = 0, 'depth: manual outer commit closes');
  finally
    Conn := nil;
  end;
end;

{ 5 }
procedure TestSiblingInnerScopesReuseNameSafely;
var
  Conn: IDbConnection;
  I: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  try
    MakeTable(Conn);
    I := 0;
    while I < 3 do                          { 兄弟层级顺序执行，固定名安全复用 }
    begin
      WithTransaction(Conn, procedure(const C: IDbConnection)
      begin
        WithTransaction(Conn, procedure(const C: IDbConnection)
        begin
          Conn.Exec('INSERT INTO t_nx (tag) VALUES (''sib'')');
        end);
      end);
      Inc(I);
    end;
    Check(CountRows(Conn, 'sib') = 3,
      'siblings: sequential same-depth scopes all land');
  finally
    Conn := nil;
  end;
end;

type
  { 仅实现 IDbTxControl、拒绝 IDbSavepointControl 的假连接：
    锁定"嵌套必须 savepoint 否则 fail-fast"契约与顶层可用性。 }
  TFakeTxConn = class(TInterfacedObject, IDbConnection, IDbTxControl)
  private
    FDepth: Integer;
    FLog: string;
  public
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    property Log: string read FLog;
  end;

function TFakeTxConn.Kind: TDbKind;
begin
  Result := dbkUnknown;
end;

procedure TFakeTxConn.Exec(const ASql: string);
begin
  raise EDbError.CreateSimple(dbkUnknown, 'fake conn: no SQL surface');
end;

function TFakeTxConn.Query(const ASql: string): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'fake conn: no SQL surface');
end;

procedure TFakeTxConn.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  raise EDbError.CreateSimple(dbkUnknown, 'fake conn: no SQL surface');
end;

function TFakeTxConn.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'fake conn: no SQL surface');
end;

function TFakeTxConn.Changes: Int64;
begin
  Result := 0;
end;

function TFakeTxConn.Raw: Pointer;
begin
  Result := nil;
end;

procedure TFakeTxConn.BeginTxn(const AImmediate: Boolean);
begin
  Inc(FDepth);
  FLog := FLog + 'B';
end;

procedure TFakeTxConn.CommitTxn;
begin
  if FDepth = 0 then
    raise EDbError.CreateSimple(dbkUnknown, 'fake conn: commit without begin');
  Dec(FDepth);
  FLog := FLog + 'C';
end;

procedure TFakeTxConn.RollbackTxn;
begin
  if FDepth = 0 then
    raise EDbError.CreateSimple(dbkUnknown, 'fake conn: rollback without begin');
  FDepth := 0;
  FLog := FLog + 'R';
end;

function TFakeTxConn.InTransaction: Boolean;
begin
  Result := FDepth > 0;
end;

function TFakeTxConn.TxDepth: Integer;
begin
  Result := FDepth;
end;

{ 只实现 IDbConnection、无事务控制能力的假连接：锁定守卫路径。 }
type
  TFakeNoTxConn = class(TInterfacedObject, IDbConnection)
  public
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
  end;

function TFakeNoTxConn.Kind: TDbKind;
begin
  Result := dbkUnknown;
end;

procedure TFakeNoTxConn.Exec(const ASql: string);
begin
  raise EDbError.CreateSimple(dbkUnknown, 'plain conn: no SQL surface');
end;

function TFakeNoTxConn.Query(const ASql: string): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'plain conn: no SQL surface');
end;

procedure TFakeNoTxConn.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  raise EDbError.CreateSimple(dbkUnknown, 'plain conn: no SQL surface');
end;

function TFakeNoTxConn.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := nil;
  raise EDbError.CreateSimple(dbkUnknown, 'plain conn: no SQL surface');
end;

function TFakeNoTxConn.Changes: Int64;
begin
  Result := 0;
end;

function TFakeNoTxConn.Raw: Pointer;
begin
  Result := nil;
end;

{ 6 }
procedure TestNestedRequiresSavepointCapability;
var
  LObj: TFakeTxConn;
  Fake: IDbConnection;
  Tx: IDbTxControl;
  Raised: Boolean;
begin
  LObj := TFakeTxConn.Create;
  Fake := LObj;                            { 引用计数接管生命周期 }
  try
    { 顶层在无 savepoint 能力的连接上照常工作（真 BEGIN 路径） }
    Tx := Fake as IDbTxControl;
    WithTransaction(Fake, procedure(const C: IDbConnection)
    begin
      Check(Tx.TxDepth = 1, 'cap: top-level works');
    end);
    Check(LObj.Log = 'BC', 'cap: top-level began and committed once');

    { 嵌套 fail-fast：拒绝异常在外层回调内被捕获 ⇒ 外层照常提交
      （内层尚未做任何事，外层数据完好） }
    Raised := False;
    try
      WithTransaction(Fake, procedure(const C: IDbConnection)
      begin
        try
          WithTransaction(Fake, procedure(const C: IDbConnection)
          begin
          end);
        except
          on E: EDbError do
            Raised := Pos('savepoint', E.Message) > 0;
        end;
      end);
    finally
      Check(Raised, 'cap: nesting without capability fails fast with message');
      Check(LObj.Log = 'BCBC',
        'cap: outer commits after catching the refusal');
    end;

    { 拒绝异常不被捕获穿出外层 ⇒ 外层自动回滚收尾 }
    Raised := False;
    try
      WithTransaction(Fake, procedure(const C: IDbConnection)
      begin
        WithTransaction(Fake, procedure(const C: IDbConnection)
        begin
        end);
      end);
    except
      on E: EDbError do
        Raised := Pos('savepoint', E.Message) > 0;
    end;
    Check(Raised, 'cap: refusal propagates when not caught');
    Check(LObj.Log = 'BCBCBR',
      'cap: unwound outer scope rolled back');
  finally
    Fake := nil;
  end;
end;

{ 8 B13 回归锁 }
{ 参数化形态零捕获——池化写租约在调用语句结束即可再借。
  缺陷形态（捕获式回调引用连接）会把租约保持到闭包销毁，单写者池
  上后续 Writer 借用超时。 }
procedure TestParameterizedFormReleasesPooledLease;
var
  Policy: TDbPoolPolicy;
  Pool: TDbPool;
  W, Again: IDbConnection;
begin
  Policy := TDbPoolPolicy.Default;
  Policy.MaxReadConnections := 1;
  Policy.AcquireTimeoutMs := 1000;
  Pool := TDbPool.Create(
    function: IDbConnection
    begin
      Result := ConnectSqlite(':memory:');
    end, Policy);
  try
    W := Pool.Writer;
    WithTransaction(W,
      procedure(const C: IDbConnection)
      begin
        C.Exec('CREATE TABLE t_b13 (a int)');
      end);
    W := nil;
    Again := Pool.Writer;
    try
      Check(Assigned(Again), 'param form: writer reacquirable immediately');
    finally
      Again := nil;
    end;
  finally
    Pool.Free;
  end;
end;

{ 9 B13 回归锁：参数化重试形态同样在重试结束即归还池化租约。 }
procedure TestParameterizedRetryReleasesPooledLease;
var
  Policy: TDbPoolPolicy;
  Pool: TDbPool;
  W, Again: IDbConnection;
begin
  Policy := TDbPoolPolicy.Default;
  Policy.MaxReadConnections := 1;
  Policy.AcquireTimeoutMs := 1000;
  Pool := TDbPool.Create(
    function: IDbConnection
    begin
      Result := ConnectSqlite(':memory:');
    end, Policy);
  try
    W := Pool.Writer;
    WithTransactionRetry(W,
      procedure(const C: IDbConnection)
      begin
        C.Exec('CREATE TABLE t_b13r (a int)');
      end);
    W := nil;
    Again := Pool.Writer;
    try
      Check(Assigned(Again), 'param retry: writer reacquirable immediately');
    finally
      Again := nil;
    end;
  finally
    Pool.Free;
  end;
end;

{ 7 守卫回归 }
procedure TestGuards;
var
  Conn: IDbConnection;
  Itf: IDbConnection;
  Raised: Boolean;
begin
  Raised := False;
  try
    WithTransaction(nil, procedure(const C: IDbConnection) begin end);
  except
    on E: EDbError do
      Raised := Pos('nil connection', E.Message) > 0;
  end;
  Check(Raised, 'guards: nil connection rejected');

  Conn := ConnectSqlite(':memory:');
  try
    Raised := False;
    try
      WithTransaction(Conn, TDbConnProc(nil));
    except
      on E: EDbError do
        Raised := Pos('nil transaction callback', E.Message) > 0;
    end;
    Check(Raised, 'guards: nil callback rejected');

    Itf := TFakeNoTxConn.Create as IDbConnection;
    Raised := False;
    try
      WithTransaction(Itf, procedure(const C: IDbConnection) begin end);
    except
      on E: EDbError do
        Raised := Pos('transaction control', E.Message) > 0;
    end;
    Check(Raised, 'guards: connection without tx control rejected');
    Itf := nil;
  finally
    Conn := nil;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.tx.v2');
  T.Test('inner failure partial rollback', @TestInnerFailurePartialRollback);
  T.Test('three level nesting', @TestThreeLevelNesting);
  T.Test('manual outer with helper inner', @TestManualOuterWithHelperInner);
  T.Test('tx depth reflects real transaction', @TestTxDepthReflectsRealTransaction);
  T.Test('sibling inner scopes reuse name safely', @TestSiblingInnerScopesReuseNameSafely);
  T.Test('nested requires savepoint capability', @TestNestedRequiresSavepointCapability);
  T.Test('guards', @TestGuards);
  T.Test('parameterized form releases pooled lease',
    @TestParameterizedFormReleasesPooledLease);
  T.Test('parameterized retry releases pooled lease',
    @TestParameterizedRetryReleasesPooledLease);
  if not T.Run then Halt(1);
end.
