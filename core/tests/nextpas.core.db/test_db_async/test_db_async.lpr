program test_db_async;

{ V3-B6 / INC-4 异步挂载门禁（nextpas.core.db.async）：
  离线段（sqlite :memory:）
    1  提交/等待往返：状态位 + 结果落库可见
    2  错误传播：工作体 EDbError 经 ErrorObj 透传（Category 保留）
    3  单飞拒绝：在途再提交抛 EDbError；收尾后恢复
    4  令牌级联取消：子令牌回调 → progress handler 中断 →
       IsCanceled=True + Category=decTimeout + interrupted 消息
    5  句柄直呼 Cancel（无令牌路径）同归一
    6  完成后 Cancel 无害 no-op
    7  WaitFor 超时分支返回 False，续等得 True
    8  消费方先行丢句柄不悬（op 托管保活，heaptrc 兜底）
    9  executor 析构等在途自然收尾（诚实语义，不留孤儿线程）
    10 异步收尾后同连接同步直调照常（Arm 不常驻的零成本证据）
  pg 真机段（NEXTPAS_PG_TEST_CONN 门控，缺省静默跳过）
    11 提交/等待 SELECT 往返
    12 PQcancel 真中断服务端长查询 → 57014 → decTimeout → IsCanceled
    13 单飞拒绝 + 恢复
  heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.async,
  nextpas.core.async.cancellation;

const
  { 中等时长递归 CTE：门禁节奏 ~0.5s，够取消窗口也够析构等待 }
  LongCteSql =
    'WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM c ' +
    'LIMIT 8000000) SELECT count(*) FROM c';

var
  T: TTestSuite;
  GPgConn: string;

{ ---- 共享：新建执行器绑定 :memory: 连接并建表 ---- }

function NewSqliteExec(out AConn: IDbConnection): TDbAsyncExecutor;
begin
  AConn := ConnectSqlite(':memory:');
  AConn.Exec('CREATE TABLE t (v INTEGER)');
  Result := TDbAsyncExecutor.Create(AConn);
end;

{ ---- 1 提交/等待往返 ---- }

procedure TestRoundtrip;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LQ: IDbQuery;
  LH: IDbAsyncHandle;
begin
  LExec := NewSqliteExec(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('INSERT INTO t VALUES (7)');
      end);
    Check(not LH.IsDone, 'fresh handle not done');
    Check(LH.WaitFor(5000), 'roundtrip completes');
    Check(LH.IsDone, 'done after wait');
    Check(not LH.IsCanceled, 'not canceled');
    Check(LH.ErrorObj = nil, 'no error object');
    LQ := LConn.Query('SELECT count(*) FROM t WHERE v = 7');
    Check(LQ.Step and (LQ.GetInt64(0) = 1), 'work effect visible');
    LQ := nil;
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 2 错误传播 ---- }

procedure TestErrorPropagation;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LE: EDbError;
begin
  LExec := NewSqliteExec(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('SELECT * FROM no_such_table');
      end);
    Check(LH.WaitFor(5000), 'failing op still completes');
    Check(LH.ErrorObj <> nil, 'error object surfaced');
    Check(not LH.IsCanceled, 'natural failure is not cancel');
    Check(LH.ErrorObj is EDbError, 'EDbError type preserved');
    if LH.ErrorObj is EDbError then
    begin
      LE := EDbError(LH.ErrorObj);
      Check(LE.Backend = dbkSqlite, 'backend kind = sqlite');
      { 不存在表 → 归一 decSyntax 族（非超时） }
      Check(LE.Category <> decTimeout,
        'non-cancel failure keeps own category');
    end;
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 3 单飞拒绝 + 恢复 ---- }

procedure TestSingleFlight;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LRejected: Boolean;
begin
  LExec := NewSqliteExec(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec(LongCteSql);
      end);
    LRejected := False;
    try
      LExec.Submit(procedure begin end);
    except
      on E: EDbError do
      begin
        LRejected := True;
        Check(Pos('单飞', E.Message) > 0, 'rejection names single-flight');
      end;
    end;
    Check(LRejected, 'concurrent submit rejected');
    Check(LExec.InFlight, 'in-flight flag set during op');
    Check(LH.WaitFor(30000), 'first op finishes');
    Check(not LExec.InFlight, 'in-flight clear after finalize');
    { 收尾后恢复提交 }
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('INSERT INTO t VALUES (1)');
      end);
    Check(LH.WaitFor(5000), 'resubmit after finalize works');
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 4 令牌级联取消 ---- }

procedure TestTokenCancelCascade;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LTok: IAsyncCancellationToken;
  LE: EDbError;
begin
  LExec := NewSqliteExec(LConn);
  try
    LTok := CreateCancellationToken;
    LH := LExec.Submit(procedure
      begin
        LConn.Exec(LongCteSql);
      end, LTok);
    Sleep(50);                          { 让 worker 进入工作体 }
    Check(not LH.WaitFor(30), 'wait timeout branch returns False');
    LTok.Cancel;                        { 子令牌回调 → progress 中断 }
    Check(LH.WaitFor(10000), 'canceled op completes promptly');
    Check(LH.IsCanceled, 'cancel surfaced on handle');
    Check(LH.ErrorObj <> nil, 'cancel carries error object');
    if LH.ErrorObj is EDbError then
    begin
      LE := EDbError(LH.ErrorObj);
      Check(LE.Category = decTimeout,
        'cancel normalized to decTimeout ("query canceled")');
      Check(Pos('interrupt', LowerCase(String(LE.Message))) > 0,
        'message mentions interrupt');
    end
    else
      Check(False, 'cancel error is EDbError');
    LTok := nil;
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 5 句柄直呼 Cancel（无令牌路径）---- }

procedure TestHandleCancelDirect;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LE: EDbError;
begin
  LExec := NewSqliteExec(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec(LongCteSql);
      end);
    Sleep(50);
    LH.Cancel;                          { 不经令牌，直达取消面 }
    Check(LH.WaitFor(10000), 'direct-cancel op completes');
    Check(LH.IsCanceled, 'direct cancel flagged');
    if LH.ErrorObj is EDbError then
    begin
      LE := EDbError(LH.ErrorObj);
      Check(LE.Category = decTimeout, 'direct cancel also decTimeout');
    end
    else
      Check(False, 'direct cancel error is EDbError');
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 6 完成后 Cancel 无害 ---- }

procedure TestCancelAfterDoneNoop;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
begin
  LExec := NewSqliteExec(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('INSERT INTO t VALUES (2)');
      end);
    Check(LH.WaitFor(5000), 'short op done');
    LH.Cancel;                          { 终态后必须 no-op }
    Check(LH.IsDone and not LH.IsCanceled,
      'post-done cancel leaves terminal state');
    Check(LH.ErrorObj = nil, 'success result untouched');
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 8 消费方先行丢句柄不悬 ---- }

procedure TestConsumerDropsHandleEarly;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
begin
  LExec := NewSqliteExec(LConn);
  try
    { 句柄引用立即丢弃。op 记录的 HandleRef 必须保活到 finalize
      （UAF 回归钉）。 }
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('INSERT INTO t VALUES (3)');
      end);
    LH := nil;
    { 析构内 WaitAll 等自然收尾；heaptrc 兜底泄漏/UAF }
  finally
    LExec.Free;
    LConn := nil;
  end;
  Check(True, 'dropped-handle path survived');
end;

{ ---- 9 析构等在途自然收尾（诚实语义）---- }

procedure TestDestroyWaitsInflight;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LQ: IDbQuery;
begin
  LExec := NewSqliteExec(LConn);
  LH := LExec.Submit(procedure
    begin
      LConn.Exec(LongCteSql);
    end);
  LH := nil;
  { 不等待直接析构：Destroy 必须 WaitAll 至自然完成 }
  LExec.Free;
  { 连接仍可用（未被半途丢弃破坏） }
  LQ := LConn.Query('SELECT 40+2');
  Check(LQ.Step and (LQ.GetInt64(0) = 42), 'conn healthy after destroy');
  LQ := nil;
  LConn := nil;
end;

{ ---- 10 异步收尾后同步直调照常 ---- }

procedure TestSyncPathUnaffected;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LQ: IDbQuery;
begin
  LExec := NewSqliteExec(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('INSERT INTO t VALUES (4)');
      end);
    Check(LH.WaitFor(5000), 'async op done');
    LH := nil;
  finally
    LExec.Free;                         { Disarm 已随 finalize 发生 }
  end;
  { 取消面不得常驻：同步直调与从未用过异步的连接逐字节一致 }
  LQ := LConn.Query('SELECT sum(v) FROM t');
  Check(LQ.Step and (LQ.GetInt64(0) = 4), 'sync query after async OK');
  LQ := nil;
  LConn := nil;
end;

{ ---- 11 pg 提交/等待往返 ---- }

procedure TestPgRoundtrip;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LV: Int64;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg roundtrip skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  LExec := TDbAsyncExecutor.Create(LConn);
  try
    LV := 0;
    LH := LExec.Submit(procedure
      var
        LQ: IDbQuery;
      begin
        LQ := LConn.Query('SELECT 6*7');
        if LQ.Step then
          LV := LQ.GetInt64(0);
        LQ := nil;
      end);
    Check(LH.WaitFor(10000), 'pg roundtrip completes');
    Check(LH.ErrorObj = nil, 'pg no error');
    Check(LV = 42, 'pg captured result visible across threads');
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 12 pg 真中断（PQcancel → 57014 → decTimeout）---- }

procedure TestPgRealCancel;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LTok: IAsyncCancellationToken;
  LE: EDbError;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg real-cancel skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  LExec := TDbAsyncExecutor.Create(LConn);
  try
    LTok := CreateCancellationToken;
    LH := LExec.Submit(procedure
      begin
        { 服务端真跑的长查询：PQcancel 中断目标 }
        LConn.Exec(
          'SELECT count(*) FROM generate_series(1, 50000000)');
      end, LTok);
    Sleep(200);                         { 确保查询已在服务端执行 }
    LTok.Cancel;                        { 子令牌桥 → PQcancel }
    Check(LH.WaitFor(10000), 'canceled query returns promptly');
    Check(LH.IsCanceled, 'pg cancel surfaced');
    Check(LH.ErrorObj is EDbError, 'pg cancel error typed');
    if LH.ErrorObj is EDbError then
    begin
      LE := EDbError(LH.ErrorObj);
      Check(LE.SqlState = '57014',
        'pg cancel SQLSTATE 57014 (query_canceled)');
      Check(LE.Category = decTimeout, 'pg cancel normalized decTimeout');
    end;
    LTok := nil;
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

{ ---- 13 pg 单飞拒绝 + 恢复 ---- }

procedure TestPgSingleFlight;
var
  LConn: IDbConnection;
  LExec: TDbAsyncExecutor;
  LH: IDbAsyncHandle;
  LRejected: Boolean;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg single-flight skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  LExec := TDbAsyncExecutor.Create(LConn);
  try
    LH := LExec.Submit(procedure
      begin
        LConn.Exec(
          'SELECT count(*) FROM generate_series(1, 50000000)');
      end);
    LRejected := False;
    try
      LExec.Submit(procedure begin end);
    except
      on E: EDbError do
        LRejected := True;
    end;
    Check(LRejected, 'pg concurrent submit rejected');
    LH.Cancel;                          { 收尾，免白等 50M 行 }
    Check(LH.WaitFor(10000), 'pg first op settles');
    LH := LExec.Submit(procedure
      begin
        LConn.Exec('SELECT 1');
      end);
    Check(LH.WaitFor(10000) and (LH.ErrorObj = nil),
      'pg resubmit after settle works');
    LH := nil;
  finally
    LExec.Free;
    LConn := nil;
  end;
end;

begin
  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.async');
  T.Test('sqlite submit wait roundtrip', @TestRoundtrip);
  T.Test('sqlite error propagation', @TestErrorPropagation);
  T.Test('sqlite single flight reject recover', @TestSingleFlight);
  T.Test('sqlite token cancel cascade', @TestTokenCancelCascade);
  T.Test('sqlite handle cancel direct', @TestHandleCancelDirect);
  T.Test('sqlite cancel after done noop', @TestCancelAfterDoneNoop);
  T.Test('sqlite consumer drops handle early', @TestConsumerDropsHandleEarly);
  T.Test('sqlite destroy waits inflight', @TestDestroyWaitsInflight);
  T.Test('sqlite sync path unaffected', @TestSyncPathUnaffected);
  T.Test('pg submit wait roundtrip', @TestPgRoundtrip);
  T.Test('pg real cancel 57014', @TestPgRealCancel);
  T.Test('pg single flight reject recover', @TestPgSingleFlight);
  if not T.Run then Halt(1);
end.
