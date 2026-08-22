program test_db_pool;

{ nextpas.core.db.sqlite.pool 契约测试（B7）：
  池复用/容量上限/WAL+busy_timeout PRAGMA 断言/写连接身份与守卫/
  关闭语义/写读一致。全部走门面 nextpas.core.db.sqlite（验证 re-export）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.db.sqlite;

var
  T: TTestSuite;
  GDbPath: string;

function TempDbPath: string;
begin
  Result := GDbPath;
end;

{ WAL 会在文件旁留 -wal/-shm 侧车文件，一起清。 }
procedure ResetDbFiles;
begin
  DeleteFile(GDbPath);
  DeleteFile(GDbPath + '-wal');
  DeleteFile(GDbPath + '-shm');
end;

procedure TestPoolReuse;
var
  Pool: TSqlitePool;
  A, B, C: TSqliteDb;
begin
  ResetDbFiles;
  Pool := TSqlitePool.Create(TempDbPath, 2);
  try
    A := Pool.Acquire;
    B := Pool.Acquire;
    CheckNotNil(A, 'first acquire returns connection');
    CheckNotNil(B, 'second acquire returns connection');
    Pool.Release(B);
    Check(Pool.IdleCount = 1, 'release puts connection back to idle');
    C := Pool.Acquire;
    CheckSame(B, C, 'acquire reuses the released connection');
    Pool.Release(A);
    Pool.Release(C);
    Pool.Close;
    Check(Pool.IdleCount = 0, 'close drains idle connections');
  finally
    Pool.Free;
  end;
end;

procedure TestPoolCapacityCap;
var
  Pool: TSqlitePool;
  A, B: TSqliteDb;
  LRaised: Boolean;
begin
  ResetDbFiles;
  Pool := TSqlitePool.Create(TempDbPath, 2);
  try
    A := Pool.Acquire;
    B := Pool.Acquire;
    LRaised := False;
    try
      Pool.Acquire;
    except
      on E: ESqlitePoolError do
      begin
        LRaised := True;
        Check(Pos('exhausted', E.Message) > 0, 'exhausted error mentions the cap');
      end;
    end;
    Check(LRaised, 'acquire beyond cap raises ESqlitePoolError');
    Pool.Release(A);
    Pool.Release(B);
    Check(Pool.TotalConnections = 2, 'no extra connections created at the cap');
  finally
    Pool.Close;
    Pool.Free;
  end;
end;

procedure TestPoolWalAndBusyTimeout;
var
  Pool: TSqlitePool;
  Db, W: TSqliteDb;
  Q: TSqliteQuery;
begin
  ResetDbFiles;
  Pool := TSqlitePool.Create(TempDbPath, 2, 1234, True);
  try
    Db := Pool.Acquire;
    Q := Db.Query('PRAGMA journal_mode');
    try
      Check(Q.Step, 'journal_mode pragma returns a row');
      CheckEqual('wal', Q.GetText(0), 'WAL enabled on pooled connection');
    finally
      Q.Free;
    end;
    Q := Db.Query('PRAGMA busy_timeout');
    try
      Check(Q.Step, 'busy_timeout pragma returns a row');
      CheckEqual(Int64(1234), Q.GetInt64(0), 'configured busy_timeout applied');
    finally
      Q.Free;
    end;
    W := Pool.Writer;
    Q := W.Query('PRAGMA journal_mode');
    try
      Check(Q.Step, 'writer journal_mode pragma returns a row');
      CheckEqual('wal', Q.GetText(0), 'WAL enabled on writer connection');
    finally
      Q.Free;
    end;
    Pool.Release(Db);
  finally
    Pool.Close;
    Pool.Free;
  end;
end;

procedure TestPoolWriterIdentity;
var
  Pool: TSqlitePool;
  W1, W2, R: TSqliteDb;
  LRaised: Boolean;
begin
  ResetDbFiles;
  Pool := TSqlitePool.Create(TempDbPath, 2);
  try
    W1 := Pool.Writer;
    W2 := Pool.Writer;
    CheckSame(W1, W2, 'writer is a single dedicated connection');
    R := Pool.Acquire;
    Check(W1 <> R, 'reader is a distinct connection from the writer');
    LRaised := False;
    try
      Pool.Release(W1);
    except
      on E: ESqlitePoolError do
        LRaised := True;
    end;
    Check(LRaised, 'releasing the writer raises ESqlitePoolError');
    Pool.Release(R);
  finally
    Pool.Close;
    Pool.Free;
  end;
end;

procedure TestPoolCloseAndClosedAcquire;
var
  Pool: TSqlitePool;
  D: TSqliteDb;
  LRaised: Boolean;
begin
  ResetDbFiles;
  Pool := TSqlitePool.Create(TempDbPath);
  D := Pool.Acquire;
  CheckNotNil(D, 'acquire before close works');
  Pool.Release(D);
  Pool.Close;
  Pool.Close;
  LRaised := False;
  try
    Pool.Acquire;
  except
    on E: ESqlitePoolError do
      LRaised := True;
  end;
  Check(LRaised, 'acquire after close raises ESqlitePoolError');
  LRaised := False;
  try
    Pool.Writer;
  except
    on E: ESqlitePoolError do
      LRaised := True;
  end;
  Check(LRaised, 'writer after close raises ESqlitePoolError');
  Pool.Free;
end;

procedure TestPoolWritesViaWriterReadsConsistent;
var
  Pool: TSqlitePool;
  W, R1, R2: TSqliteDb;
  Q: TSqliteQuery;
  I: Integer;
begin
  ResetDbFiles;
  Pool := TSqlitePool.Create(TempDbPath, 3);
  try
    W := Pool.Writer;
    W.Exec('CREATE TABLE kv (k INTEGER PRIMARY KEY, v TEXT)');
    for I := 1 to 3 do
      W.Exec('INSERT INTO kv (k, v) VALUES (' + IntToStr(I) + ', ''v' +
        IntToStr(I) + ''')');
    R1 := Pool.Acquire;
    R2 := Pool.Acquire;
    Q := R1.Query('SELECT COUNT(*) FROM kv');
    try
      Check(Q.Step, 'count row via pooled connection');
      CheckEqual(Int64(3), Q.GetInt64(0), 'reader sees writer commits (WAL)');
    finally
      Q.Free;
    end;
    Q := R2.Query('SELECT v FROM kv WHERE k = 2');
    try
      Check(Q.Step, 'second reader returns writer data');
      CheckEqual('v2', Q.GetText(0), 'value roundtrip via writer connection');
    finally
      Q.Free;
    end;
    Pool.Release(R1);
    Pool.Release(R2);
  finally
    Pool.Close;
    Pool.Free;
  end;
end;

procedure TestPoolForeignKeys;
var
  PoolOff, PoolOn: TSqlitePool;
  Db, W: TSqliteDb;
  Q: TSqliteQuery;
  LRaised: Boolean;
begin
  { 默认 off = SQLite 引擎默认, 既有行为不变 }
  ResetDbFiles;
  PoolOff := TSqlitePool.Create(TempDbPath, 2);
  try
    Db := PoolOff.Acquire;
    Q := Db.Query('PRAGMA foreign_keys');
    try
      Check(Q.Step, 'default fk pragma returns a row');
      CheckEqual(Int64(0), Q.GetInt64(0), 'foreign_keys off by default');
    finally
      Q.Free;
    end;
    PoolOff.Release(Db);
  finally
    PoolOff.Close;
    PoolOff.Free;
  end;

  { on: 读连接与写连接统一生效; 违反约束抛错; ON DELETE CASCADE 生效 }
  ResetDbFiles;
  PoolOn := TSqlitePool.Create(TempDbPath, 2, 5000, True, True);
  try
    Check(PoolOn.ForeignKeys, 'ForeignKeys property reflects the option');
    W := PoolOn.Writer;
    W.Exec('CREATE TABLE parent (id INTEGER PRIMARY KEY)');
    W.Exec('CREATE TABLE child (id INTEGER PRIMARY KEY, ' +
      'pid INTEGER NOT NULL REFERENCES parent(id) ON DELETE CASCADE)');
    W.Exec('INSERT INTO parent (id) VALUES (1)');
    W.Exec('INSERT INTO child (id, pid) VALUES (10, 1)');

    LRaised := False;
    try
      W.Exec('INSERT INTO child (id, pid) VALUES (11, 99)');
    except
      on E: ESqliteError do
        LRaised := True;
    end;
    Check(LRaised, 'fk violation raises on writer connection');

    Db := PoolOn.Acquire;
    Q := Db.Query('PRAGMA foreign_keys');
    try
      Check(Q.Step, 'fk pragma returns a row on reader');
      CheckEqual(Int64(1), Q.GetInt64(0), 'foreign_keys on for readers');
    finally
      Q.Free;
    end;

    W.Exec('DELETE FROM parent WHERE id = 1');
    Q := Db.Query('SELECT COUNT(*) FROM child');
    try
      Check(Q.Step, 'count after cascade returns a row');
      CheckEqual(Int64(0), Q.GetInt64(0), 'ON DELETE CASCADE removed child rows');
    finally
      Q.Free;
    end;
    PoolOn.Release(Db);
  finally
    PoolOn.Close;
    PoolOn.Free;
  end;
end;

begin
  GDbPath := GetTempDir + 'pp888_sqlite_pool_test' + IntToStr(GetProcessID) + '.db';
  T := TTestSuite.Create('nextpas.core.db.sqlite.pool');
  T.Test('pool reuse (acquire/release/re-acquire)', @TestPoolReuse);
  T.Test('pool capacity cap raises', @TestPoolCapacityCap);
  T.Test('WAL + busy_timeout applied uniformly (PRAGMA)', @TestPoolWalAndBusyTimeout);
  T.Test('dedicated writer identity + release guard', @TestPoolWriterIdentity);
  T.Test('close idempotent + acquire/writer guard', @TestPoolCloseAndClosedAcquire);
  T.Test('writer writes / pooled readers consistent', @TestPoolWritesViaWriterReadsConsistent);
  T.Test('foreign_keys option (default off / on enforces + cascades)', @TestPoolForeignKeys);
  ResetDbFiles;
  if not T.Run then Halt(1);
end.