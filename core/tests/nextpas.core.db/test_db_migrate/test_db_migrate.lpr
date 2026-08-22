program test_db_migrate;

{ nextpas.core.db.sqlite.migrate 契约测试（B7）：
  首次迁移/幂等（跑两遍同结果）/按版本有序应用/失败批次整批回滚/
  版本上下限校验/列表乱序拒绝/无迁移版本=0。走门面 re-export。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.sqlite;

var
  T: TTestSuite;

function CountRows(const ADb: TSqliteDb; const ATbl: string): Int64;
var
  Q: TSqliteQuery;
begin
  Q := ADb.Query('SELECT COUNT(*) FROM ' + ATbl);
  try
    Q.Step;
    Result := Q.GetInt64(0);
  finally
    Q.Free;
  end;
end;

procedure TestMigrateFirstRun;
var
  Db: TSqliteDb;
  LApplied: Integer;
begin
  Db := SqliteOpen(':memory:');
  try
    CheckEqual(Int64(0), MigrationVersion(Db), 'fresh DB version is 0');
    LApplied := Migrate(Db, MakeMigrations([
      TSqliteMigration.Create(1,
        ['CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
         'INSERT INTO t (v) VALUES (''seed'')']) ]));
    CheckEqual(Int64(1), Int64(LApplied), 'first run applies one batch');
    CheckEqual(Int64(1), CountRows(Db, 't'), 'migration SQL executed');
    CheckEqual(Int64(1), MigrationVersion(Db), 'version row records applied version');
  finally
    Db.Free;
  end;
end;

procedure TestMigrateIdempotentSecondRun;
var
  Db: TSqliteDb;
  LApplied: Integer;
begin
  Db := SqliteOpen(':memory:');
  try
    Migrate(Db, MakeMigrations([
      TSqliteMigration.Create(1,
        ['CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
         'INSERT INTO t (v) VALUES (''one'')']),
      TSqliteMigration.Create(2, ['INSERT INTO t (v) VALUES (''two'')']) ]));
    LApplied := Migrate(Db, MakeMigrations([
      TSqliteMigration.Create(1,
        ['CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
         'INSERT INTO t (v) VALUES (''one'')']),
      TSqliteMigration.Create(2, ['INSERT INTO t (v) VALUES (''two'')']) ]));
    CheckEqual(Int64(0), Int64(LApplied), 'second run applies nothing');
    CheckEqual(Int64(2), CountRows(Db, 't'), 'rows not duplicated by re-run');
    CheckEqual(Int64(2), MigrationVersion(Db), 'version stays at max');
  finally
    Db.Free;
  end;
end;

procedure TestMigrateOrderedMigrations;
var
  Db: TSqliteDb;
  Q: TSqliteQuery;
  LApplied: Integer;
  LMax: Int64;
begin
  Db := SqliteOpen(':memory:');
  try
    LApplied := Migrate(Db, MakeMigrations([
      TSqliteMigration.Create(1, ['CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)']),
      TSqliteMigration.Create(2, ['INSERT INTO t (v) VALUES (''v2'')']),
      TSqliteMigration.Create(3, ['INSERT INTO t (v) VALUES (''v3'')']) ]));
    CheckEqual(Int64(3), Int64(LApplied), 'all three batches applied in one pass');
    Q := Db.Query('SELECT v FROM t ORDER BY id');
    try
      Check(Q.Step, 'first row present');
      CheckEqual('v2', Q.GetText(0), 'migration 2 ran before 3');
      Check(Q.Step, 'second row present');
      CheckEqual('v3', Q.GetText(0), 'migration 3 applied last');
    finally
      Q.Free;
    end;
    Q := Db.Query('SELECT MAX(version) FROM ' + SQLITE_MIGRATIONS_TABLE);
    try
      Q.Step;
      LMax := Q.GetInt64(0);
    finally
      Q.Free;
    end;
    CheckEqual(Int64(3), LMax, 'version table holds max version');
  finally
    Db.Free;
  end;
end;

procedure TestMigrateFailedBatchRollsBack;
var
  Db: TSqliteDb;
  LRaised: Boolean;
  LApplied: Integer;
begin
  Db := SqliteOpen(':memory:');
  try
    LRaised := False;
    try
      LApplied := Migrate(Db, MakeMigrations([
        TSqliteMigration.Create(1,
          ['CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
           'INSERT INTO t (v) VALUES (''kept'')']),
        TSqliteMigration.Create(2,
          ['INSERT INTO t (v) VALUES (''will-rollback'')',
           'INSERT INTO missing_table (x) VALUES (1)']) ]));
    except
      on E: ESqliteError do
        LRaised := True;
    end;
    Check(LRaised, 'failing batch raises ESqliteError');
    CheckEqual(Int64(1), MigrationVersion(Db), 'failed batch version not recorded');
    CheckEqual(Int64(1), CountRows(Db, 't'), 'failed batch rolled back entirely');

    { 修复列表后重跑：缺失批次补上，已应用批次保持幂等跳过 }
    LApplied := Migrate(Db, MakeMigrations([
      TSqliteMigration.Create(1,
        ['CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
         'INSERT INTO t (v) VALUES (''kept'')']),
      TSqliteMigration.Create(2, ['INSERT INTO t (v) VALUES (''fixed'')']) ]));
    CheckEqual(Int64(1), Int64(LApplied), 're-run applies only the missing batch');
    CheckEqual(Int64(2), CountRows(Db, 't'), 'table state after successful re-run');
    CheckEqual(Int64(2), MigrationVersion(Db), 'version advances after successful re-run');
  finally
    Db.Free;
  end;
end;

procedure TestMigrateUpperBound;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    { 库已应用版本高于列表最大 ⇒ 库超前于代码 }
    Db.Exec('CREATE TABLE ' + SQLITE_MIGRATIONS_TABLE +
      ' (version INTEGER PRIMARY KEY, applied_at TEXT)');
    Db.Exec('INSERT INTO ' + SQLITE_MIGRATIONS_TABLE + ' (version) VALUES (99)');
    LRaised := False;
    try
      Migrate(Db, MakeMigrations([
        TSqliteMigration.Create(1, ['CREATE TABLE t1 (x INTEGER)']) ]));
    except
      on E: ESqliteMigrateError do
      begin
        LRaised := True;
        CheckEqual(Int64(99), E.Version, 'error carries offending version');
        Check(Pos('ahead', E.Message) > 0, 'upper-bound message says ahead');
      end;
    end;
    Check(LRaised, 'applied version above list raises ESqliteMigrateError');
  finally
    Db.Free;
  end;
end;

procedure TestMigrateLowerBound;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    { 已应用版本低于列表最小 ⇒ 旧迁移被删过 }
    Db.Exec('CREATE TABLE ' + SQLITE_MIGRATIONS_TABLE +
      ' (version INTEGER PRIMARY KEY, applied_at TEXT)');
    Db.Exec('INSERT INTO ' + SQLITE_MIGRATIONS_TABLE + ' (version) VALUES (0)');
    LRaised := False;
    try
      Migrate(Db, MakeMigrations([
        TSqliteMigration.Create(10, ['CREATE TABLE t1 (x INTEGER)']) ]));
    except
      on E: ESqliteMigrateError do
      begin
        LRaised := True;
        CheckEqual(Int64(0), E.Version, 'error carries offending version');
        Check(Pos('below', E.Message) > 0, 'lower-bound message says below');
      end;
    end;
    Check(LRaised, 'applied version below list raises ESqliteMigrateError');
  finally
    Db.Free;
  end;
end;

procedure TestMigrateUnsortedListRejected;
var
  Db: TSqliteDb;
  LRaised: Boolean;
begin
  Db := SqliteOpen(':memory:');
  try
    LRaised := False;
    try
      Migrate(Db, MakeMigrations([
        TSqliteMigration.Create(2, ['CREATE TABLE t2 (x INTEGER)']),
        TSqliteMigration.Create(1, ['CREATE TABLE t1 (x INTEGER)']) ]));
    except
      on E: ESqliteMigrateError do
        LRaised := True;
    end;
    Check(LRaised, 'non-ascending list raises ESqliteMigrateError');
    CheckEqual(Int64(0), MigrationVersion(Db), 'nothing applied on an invalid list');
  finally
    Db.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.db.sqlite.migrate');
  T.Test('first run applies migrations + records version', @TestMigrateFirstRun);
  T.Test('idempotent: second run applies nothing', @TestMigrateIdempotentSecondRun);
  T.Test('ordered migrations applied in version order', @TestMigrateOrderedMigrations);
  T.Test('failed batch rolls back entirely', @TestMigrateFailedBatchRollsBack);
  T.Test('upper-bound version validation', @TestMigrateUpperBound);
  T.Test('lower-bound version validation', @TestMigrateLowerBound);
  T.Test('unsorted list rejected', @TestMigrateUnsortedListRejected);
  if not T.Run then Halt(1);
end.