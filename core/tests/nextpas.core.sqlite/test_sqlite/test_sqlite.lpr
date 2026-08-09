program test_sqlite;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.sqlite;

var
  T: TTestSuite;
  GDbPath: string;

{ ==== helpers ==== }

function TempDbPath: string;
begin
  Result := GDbPath;
end;

{ ===== in-memory basics ===== }

procedure TestMemoryCreateTableInsertSelect;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
  LId: Int64;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, score REAL, data BLOB)');
    Q := Db.Query('INSERT INTO t (name, score, data) VALUES (?, ?, ?)');
    try
      Q.BindText(1, 'hello');
      Q.BindDouble(2, 3.5);
      Q.BindBlob(3, TBytes.Create(1, 2, 3, 4));
      Check(not Q.Step, 'insert step terminates');
    finally
      Q.Free;
    end;
    LId := Db.LastInsertRowId;
    Check(LId > 0, 'last_insert_rowid positive');
    Check(Db.Changes = 1, 'changes = 1 after insert');
    Q := Db.Query('SELECT id, name, score, data FROM t WHERE id = ?');
    try
      Q.BindInt64(1, LId);
      Check(Q.Step, 'select returns one row');
      CheckEqual(LId, Q.GetInt64(0), 'id roundtrip');
      CheckEqual('hello', Q.GetText(1), 'text roundtrip');
      Check(abs(Q.GetDouble(2) - 3.5) < 1e-9, 'double roundtrip');
      CheckEqual(Int64(4), Int64(Length(Q.GetBlob(3))), 'blob length');
      Check(Q.GetBlob(3)[0] = 1, 'blob byte 0');
      Check(Q.GetBlob(3)[3] = 4, 'blob byte 3');
      Check(not Q.Step, 'no second row');
    finally
      Q.Free;
    end;
  finally
    Db.Free;
  end;
end;

procedure TestNullBind;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE n (id INTEGER PRIMARY KEY, v TEXT)');
    Q := Db.Query('INSERT INTO n (v) VALUES (?)');
    try
      Q.BindNull(1);
      while Q.Step do ;
    finally
      Q.Free;
    end;
    Q := Db.Query('SELECT v FROM n WHERE id = 1');
    try
      Check(Q.Step, 'null row present');
      CheckEqual(SQLITE_NULL, Q.ColumnType(0), 'column type is NULL');
      Check(not Q.Step, 'only one row');
    finally
      Q.Free;
    end;
  finally
    Db.Free;
  end;
end;

procedure TestExecMultiStatements;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE a (x INTEGER); CREATE TABLE b (y TEXT);');
    Db.Exec('INSERT INTO a VALUES (1); INSERT INTO b VALUES (''one'');');
    Q := Db.Query('SELECT x FROM a');
    try
      Check(Q.Step, 'a has row');
      CheckEqual(Int64(1), Q.GetInt64(0), 'a value');
    finally
      Q.Free;
    end;
    Q := Db.Query('SELECT y FROM b');
    try
      Check(Q.Step, 'b has row');
      CheckEqual('one', Q.GetText(0), 'b value');
    finally
      Q.Free;
    end;
  finally
    Db.Free;
  end;
end;

procedure TestStepReturnsNoRowForDml;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    Q := Db.Query('INSERT INTO t VALUES (10)');
    try
      Check(not Q.Step, 'DML step returns False');
    finally
      Q.Free;
    end;
    Q := Db.Query('UPDATE t SET id = 20 WHERE id = 10');
    try
      Check(not Q.Step, 'UPDATE step returns False');
      CheckEqual(Int64(1), Db.Changes, 'update changes = affected rows');
    finally
      Q.Free;
    end;
  finally
    Db.Free;
  end;
end;

procedure TestExecErrorRaises;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    LRaised := False;
    try
      Db.Exec('THIS IS NOT SQL');
    except
      on E: ESqliteError do
      begin
        LRaised := True;
        Check(E.ErrorCode <> SQLITE_OK, 'error code set');
      end;
    end;
    Check(LRaised, 'exec error raised ESqliteError');
  finally
    Db.Free;
  end;
end;

procedure TestQueryErrorRaises;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    LRaised := False;
    try
      Db.Query('SELECT * FROM no_such_table');
    except
      on E: ESqliteError do
        LRaised := True;
    end;
    Check(LRaised, 'prepare error raised ESqliteError');
  finally
    Db.Free;
  end;
end;

procedure TestConstraintViolationRaises;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, u TEXT UNIQUE)');
    Q := Db.Query('INSERT INTO t (u) VALUES (?)');
    try
      Q.BindText(1, 'dup');
      while Q.Step do ;
      Q.Reset;
      Q.BindText(1, 'dup');
      LRaised := False;
      try
        while Q.Step do ;
      except
        on E: ESqliteError do
          LRaised := True;
      end;
      Check(LRaised, 'UNIQUE violation raised ESqliteError');
    finally
      Q.Free;
    end;
  finally
    Db.Free;
  end;
end;

{ ===== persistence on disk ===== }

procedure TestDiskPersistence;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
begin
  DeleteFile(TempDbPath);
  Db := SqliteOpen(TempDbPath);
  try
    Db.Exec('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)');
    Q := Db.Query('INSERT INTO t (v) VALUES (?)');
    try
      Q.BindText(1, 'persist-me');
      while Q.Step do ;
    finally
      Q.Free;
    end;
    Db.Checkpoint;
  finally
    Db.Free;
  end;
  { reopen and verify }
  Db := SqliteOpen(TempDbPath);
  try
    Q := Db.Query('SELECT v FROM t WHERE id = 1');
    try
      Check(Q.Step, 'reopened row present');
      CheckEqual('persist-me', Q.GetText(0), 'persisted value');
    finally
      Q.Free;
    end;
  finally
    Db.Free;
  end;
  DeleteFile(TempDbPath);
end;

procedure TestBusyTimeout;
var
  Db: TSqliteDb;
begin
  Db := SqliteOpen(':memory:');
  try
    Db.BusyTimeout(100);
    Db.Exec('CREATE TABLE t (x INTEGER)');
    Db.Exec('INSERT INTO t VALUES (1)');
    CheckEqual(Int64(1), Db.Changes, 'busy timeout insert ok');
  finally
    Db.Free;
  end;
end;

procedure TestVersion;
var
  Db: TSqliteDb;
begin
  Db := SqliteOpen(':memory:');
  try
    Check(Pos('3.', Db.Version) = 1, 'sqlite version starts with 3.x: ' + Db.Version);
  finally
    Db.Free;
  end;
end;

begin
  GDbPath := GetTempDir + 'pp888_sqlite_test' + IntToStr(GetProcessID) + '.db';
  T := TTestSuite.Create('nextpas.core.sqlite');
  T.Test('memory create/insert/select roundtrip', @TestMemoryCreateTableInsertSelect);
  T.Test('NULL bind and column type', @TestNullBind);
  T.Test('multi-statement exec', @TestExecMultiStatements);
  T.Test('DML step returns false', @TestStepReturnsNoRowForDml);
  T.Test('exec error raises ESqliteError', @TestExecErrorRaises);
  T.Test('prepare error raises ESqliteError', @TestQueryErrorRaises);
  T.Test('UNIQUE violation raises ESqliteError', @TestConstraintViolationRaises);
  T.Test('disk persistence + WAL checkpoint', @TestDiskPersistence);
  T.Test('busy timeout', @TestBusyTimeout);
  T.Test('version string', @TestVersion);
  if not T.Run then Halt(1);
end.