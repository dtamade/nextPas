program test_db_tx;

{ nextpas.core.db.sqlite.tx 契约测试（B7）：
  提交/回滚重抛/嵌套计数/裸 Begin-Commit-Rollback/autocommit 守卫/
  事务内读己写。全部走门面 nextpas.core.db.sqlite（验证 re-export）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.sqlite;

var
  T: TTestSuite;

function CountRows(const ADb: TSqliteDb): Int64;
var
  Q: TSqliteQuery;
begin
  Q := ADb.Query('SELECT COUNT(*) FROM t');
  try
    Q.Step;
    Result := Q.GetInt64(0);
  finally
    Q.Free;
  end;
end;

procedure TestWithTransactionCommit;
var
  Db: TSqliteDb;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    Check(not InTransaction(Db), 'no transaction before WithTransaction');
    WithTransaction(Db, procedure
      begin
        Check(InTransaction(Db), 'transaction open inside callback');
        { procedure 式 Exec：三次 Exec 同一事务 }
        Db.Exec('INSERT INTO t (v) VALUES (''a'')');
        Db.Exec('INSERT INTO t (v) VALUES (''b'')');
        Db.Exec('INSERT INTO t (v) VALUES (''c'')');
      end);
    Check(not InTransaction(Db), 'transaction closed after WithTransaction');
    CheckEqual(Int64(3), CountRows(Db), 'three inserts committed atomically');
  finally
    Db.Free;
  end;
end;

procedure TestWithTransactionRollbackOnError;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    LRaised := False;
    try
      WithTransaction(Db, procedure
        begin
          Db.Exec('INSERT INTO t (v) VALUES (''x'')');
          Db.Exec('INSERT INTO t (v) VALUES (''y'')');
          raise Exception.Create('boom');
        end);
    except
      on E: Exception do
        LRaised := (E.Message = 'boom');  { 原异常被重抛，消息未被吞 }
    end;
    Check(LRaised, 'exception re-raised after automatic rollback');
    CheckEqual(Int64(0), CountRows(Db), 'inserts rolled back');
    CheckEqual(Int64(0), Int64(TxDepth(Db)), 'depth back to zero after rollback');
  finally
    Db.Free;
  end;
end;

procedure TestNestedWithTransaction;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    { 内层“提交”在外层回滚时一并撤销 }
    LRaised := False;
    try
      WithTransaction(Db, procedure
        begin
          Db.Exec('INSERT INTO t (v) VALUES (''outer'')');
          WithTransaction(Db, procedure
            begin
              Db.Exec('INSERT INTO t (v) VALUES (''inner'')');
            end);
          raise Exception.Create('outer-fails');
        end);
    except
      on E: Exception do
        LRaised := (E.Message = 'outer-fails');
    end;
    Check(LRaised, 'outer exception re-raised');
    CheckEqual(Int64(0), CountRows(Db), 'inner writes rolled back together with outer');

    { 内层 + 外层一起提交 }
    WithTransaction(Db, procedure
      begin
        Db.Exec('INSERT INTO t (v) VALUES (''outer2'')');
        WithTransaction(Db, procedure
          begin
            Db.Exec('INSERT INTO t (v) VALUES (''inner2'')');
          end);
      end);
    CheckEqual(Int64(2), CountRows(Db), 'inner writes committed with outer');
  finally
    Db.Free;
  end;
end;

procedure TestTxDepthCounting;
var
  Db: TSqliteDb;
  LDepth: Integer;
begin
  Db := SqliteOpen(':memory:');
  try
    CheckEqual(Int64(0), Int64(TxDepth(Db)), 'initial depth is 0');
    LDepth := -1;
    WithTransaction(Db, procedure
      begin
        CheckEqual(Int64(1), Int64(TxDepth(Db)), 'depth is 1 in outer scope');
        WithTransaction(Db, procedure
          begin
            CheckEqual(Int64(2), Int64(TxDepth(Db)), 'depth is 2 in innermost scope');
            LDepth := TxDepth(Db);
          end);
      end);
    CheckEqual(Int64(2), Int64(LDepth), 'observed nested depth was 2');
    CheckEqual(Int64(0), Int64(TxDepth(Db)), 'depth back to 0 after outer commit');
  finally
    Db.Free;
  end;
end;

procedure TestRawBeginCommitRollback;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    BeginTxn(Db);
    Check(InTransaction(Db), 'in transaction after BeginTxn');
    Db.Exec('INSERT INTO t (v) VALUES (''keep'')');
    CommitTxn(Db);
    CheckEqual(Int64(0), Int64(TxDepth(Db)), 'depth 0 after CommitTxn');
    CheckEqual(Int64(1), CountRows(Db), 'commit persisted row');

    BeginTxn(Db);
    Db.Exec('INSERT INTO t (v) VALUES (''drop'')');
    RollbackTxn(Db);
    CheckEqual(Int64(1), CountRows(Db), 'rollback dropped row');

    LRaised := False;
    try
      CommitTxn(Db);            { 无配对 Begin }
    except
      on E: ESqliteTxError do
        LRaised := True;
    end;
    Check(LRaised, 'CommitTxn without Begin raises ESqliteTxError');

    LRaised := False;
    try
      RollbackTxn(Db);          { 无配对 Begin }
    except
      on E: ESqliteTxError do
        LRaised := True;
    end;
    Check(LRaised, 'RollbackTxn without Begin raises ESqliteTxError');
  finally
    Db.Free;
  end;
end;

procedure TestTxHelperGuardsRawMixing;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    { 裸 BEGIN 之后 BeginTxn 拒绝（autocommit 守卫） }
    Db.Exec('BEGIN');
    LRaised := False;
    try
      BeginTxn(Db);
    except
      on E: ESqliteTxError do
        LRaised := True;
    end;
    Check(LRaised, 'BeginTxn rejects externally-opened transaction');
    Db.Exec('ROLLBACK');

    { 助手 BEGIN 后被裸 ROLLBACK 关掉 ⇒ CommitTxn 拒绝 }
    BeginTxn(Db);
    Db.Exec('ROLLBACK');
    LRaised := False;
    try
      CommitTxn(Db);
    except
      on E: ESqliteTxError do
        LRaised := True;
    end;
    Check(LRaised, 'CommitTxn rejects transaction closed outside the helper');
    { RollbackTxn 负责清掉被外部破坏的簿记 }
    RollbackTxn(Db);
    CheckEqual(Int64(0), Int64(TxDepth(Db)), 'rollback cleans up stale bookkeeping');
  finally
    Db.Free;
  end;
end;

procedure TestWithTransactionReadsOwnWrites;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
  LRow: string;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    WithTransaction(Db, procedure
      begin
        Db.Exec('INSERT INTO t (v) VALUES (''uncommitted'')');
        Q := Db.Query('SELECT v FROM t WHERE id = 1');
        try
          Check(Q.Step, 'own uncommitted write visible in the same transaction');
          LRow := Q.GetText(0);
        finally
          Q.Free;
        end;
        CheckEqual('uncommitted', LRow, 'row readable before commit');
      end);
  finally
    Db.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.sqlite.tx');
  T.Test('WithTransaction commits procedure-style Exec', @TestWithTransactionCommit);
  T.Test('WithTransaction rolls back + re-raises on error', @TestWithTransactionRollbackOnError);
  T.Test('nested WithTransaction protects the outer scope', @TestNestedWithTransaction);
  T.Test('nesting depth counting', @TestTxDepthCounting);
  T.Test('raw Begin/Commit/RollbackTxn + misuse guards', @TestRawBeginCommitRollback);
  T.Test('autocommit guards against raw BEGIN/ROLLBACK mixing', @TestTxHelperGuardsRawMixing);
  T.Test('transaction reads its own writes', @TestWithTransactionReadsOwnWrites);
  if not T.Run then Halt(1);
end.