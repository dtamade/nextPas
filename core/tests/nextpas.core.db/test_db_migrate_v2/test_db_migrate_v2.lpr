program test_db_migrate_v2;

{ V2-S6 migrate 增强（INC-6）契约测试：
    1 fresh 应用记录 checksum：三列表齐全，值 = 规范形 CRC32，
      applied_at 显式写入
    2 幂等重跑：二次 Migrate 应用 0 批
    3 篡改检测：SQL 被改后 Migrate 抛 EDbMigrateError 且携带版本号
    4 dry-run 全新库零副作用：全 drsApply，版本表/目标表均不存在；
      乱序列表在 dry-run 上同样拒绝且不留表
    5 dry-run 三态上报：drsChecksumMismatch 不抛出；同一输入上
      Migrate 抛错（预览/应用的校验语义分野）
    6 legacy 两列表自愈：手工旧表经 Migrate 自动 ADD COLUMN 并按当前
      列表回填空 checksum，回填后篡改可检
    7 越界拒绝：空列表撞已应用行 = 拒绝并携带版本号
    8 乱序列表拒绝（回归）：严格升序校验在建表前执行
    9 pg 条件段：同核心用例 + 跨后端 checksum 确定性
  pg 段需本地实例（NEXTPAS_PG_TEST_CONN）。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.checksum.crc32,
  nextpas.core.db.factory.register.sqlite,
  nextpas.core.db.factory.register.pg;

const
  { 单一事实源：SQL 常量在迁移列表与期望 checksum 间共享。
    INSERT 显式给 id：pg 的 INTEGER PRIMARY KEY 无 rowid 别名语义，
    显式值保证同一列表两引擎通用（checksum 跨后端确定）。 }
  C_SQL_1 = 'CREATE TABLE t_items (id INTEGER PRIMARY KEY, v TEXT)';
  C_SQL_1_TAMPERED = 'CREATE TABLE t_items (id INTEGER PRIMARY KEY, v TEXT NOT NULL)';
  C_SQL_2 = 'INSERT INTO t_items (id, v) VALUES (1, ''one'')';
  C_SQL_3 = 'INSERT INTO t_items (id, v) VALUES (2, ''two'')';

var
  T: TTestSuite;
  GPgConn: string;
  GChecksumSqlite: string;               { 组 1 记录 v2 值，供 pg 段比对确定性 }

{ 规范形的独立实现：LF 连接后 CRC32 八位小写十六进制。
  与单元内部 ComputeChecksumOf 互为对照，防实现间静默漂移。 }
function ExpectedChecksum(const ASql: array of string): string;
var
  I: Integer;
  LJoined: string;
begin
  LJoined := '';
  if Length(ASql) > 0 then
  begin
    LJoined := ASql[0];
    for I := 1 to High(ASql) do
      LJoined := LJoined + #10 + ASql[I];
  end;
  Result := LowerCase(IntToHex(
    Crc32Of(Pointer(LJoined)^, SizeUInt(Length(LJoined))), 8));
end;

procedure ReadVersionRow(const AConn: IDbConnection; const AVersion: Int64;
  out AAppliedAt: string; out AChecksum: string);
var
  Q: IDbQuery;
begin
  AAppliedAt := '';
  AChecksum := '<row-missing>';
  Q := AConn.Query('SELECT applied_at, checksum FROM schema_migrations' +
    ' WHERE version = ' + IntToStr(AVersion));
  try
    if Q.Step then
    begin
      if not Q.IsNull(0) then
        AAppliedAt := Q.GetText(0);
      if not Q.IsNull(1) then
        AChecksum := Q.GetText(1);
    end;
  finally
    Q := nil;
  end;
end;

function TableExists(const AConn: IDbConnection; const AName: string): Boolean;
var
  Q: IDbQuery;
begin
  Q := AConn.Query('SELECT name FROM sqlite_master WHERE type = ''table''' +
    ' AND name = ''' + AName + '''');
  try
    Result := Q.Step;
  finally
    Q := nil;
  end;
end;

{ 1 }
procedure TestFreshApplyRecordsChecksums;
var
  Conn: IDbConnection;
  N: Integer;
  LAt1, LCs1, LAt2: string;
begin
  Conn := ConnectSqlite(':memory:');
  try
    N := Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(N = 2, 'fresh: both batches applied');
    Check(MigrationVersion(Conn) = 2, 'fresh: version at max');
    ReadVersionRow(Conn, 1, LAt1, LCs1);
    ReadVersionRow(Conn, 2, LAt2, GChecksumSqlite);
    Check(LCs1 = ExpectedChecksum([C_SQL_1]),
      'fresh: v1 checksum equals canonical form');
    Check(GChecksumSqlite = ExpectedChecksum([C_SQL_2]),
      'fresh: v2 checksum equals canonical form');
    Check(LAt1 <> '', 'fresh: v1 applied_at recorded');
    Check(LAt2 <> '', 'fresh: v2 applied_at recorded');
  finally
    Conn := nil;
  end;
end;

{ 2 }
procedure TestIdempotentRerun;
var
  Conn: IDbConnection;
  N: Integer;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    N := Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(N = 0, 'idempotent: second run applies nothing');
    Check(MigrationVersion(Conn) = 2, 'idempotent: version unchanged');
  finally
    Conn := nil;
  end;
end;

{ 3 }
procedure TestTamperedSqlRaises;
var
  Conn: IDbConnection;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Raised := False;
    try
      Migrate(Conn, MakeMigrations([
        TDbMigration.Create(1, [C_SQL_1_TAMPERED]),
        TDbMigration.Create(2, [C_SQL_2]) ]));
    except
      on E: EDbMigrateError do
      begin
        Raised := True;
        Check(E.Version = 1, 'tamper: error carries offending version');
        Check(Pos('checksum mismatch', E.Message) > 0,
          'tamper: message names the mismatch');
      end;
    end;
    Check(Raised, 'tamper: modified SQL rejected on Migrate');
  finally
    Conn := nil;
  end;
end;

{ 4 }
procedure TestDryRunZeroSideEffects;
var
  Conn: IDbConnection;
  Plan: TDbDryRunPlan;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Plan := MigrateDryRun(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(Length(Plan) = 2, 'dry-fresh: plan covers every batch');
    Check(Plan[0].Version = 1, 'dry-fresh: entry keeps version order');
    Check(Plan[0].Status = drsApply, 'dry-fresh: v1 reported as apply');
    Check(Plan[1].Status = drsApply, 'dry-fresh: v2 reported as apply');
    Check(not TableExists(Conn, 'schema_migrations'),
      'dry-fresh: version table not created');
    Check(not TableExists(Conn, 't_items'),
      'dry-fresh: target table not created');

    { 乱序输入对 dry-run 同样拒绝，且拒绝发生在建表前 }
    Raised := False;
    try
      MigrateDryRun(Conn, MakeMigrations([
        TDbMigration.Create(5, ['CREATE TABLE z (x INTEGER)']),
        TDbMigration.Create(3, ['CREATE TABLE y (x INTEGER)']) ]));
    except
      on E: EDbMigrateError do
      begin
        Raised := True;
        Check(E.Version = 3, 'dry-fresh: ordering violation carries version');
      end;
    end;
    Check(Raised, 'dry-fresh: descending list still raises');
    Check(not TableExists(Conn, 'schema_migrations'),
      'dry-fresh: rejection leaves no table behind');
  finally
    Conn := nil;
  end;
end;

{ 5 }
procedure TestDryRunReportsMismatchWithoutRaising;
var
  Conn: IDbConnection;
  Plan: TDbDryRunPlan;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));

    { 预览：被改批次上报不匹配而非抛错；未改批次报已应用；
      未应用的新批次报将应用 }
    Plan := MigrateDryRun(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1_TAMPERED]),
      TDbMigration.Create(2, [C_SQL_2]),
      TDbMigration.Create(3, [C_SQL_3]) ]));
    Check(Length(Plan) = 3, 'dry-mixed: full plan returned');
    Check(Plan[0].Status = drsChecksumMismatch,
      'dry-mixed: tampered batch reported as mismatch');
    Check(Plan[1].Status = drsApplied,
      'dry-mixed: untouched batch reported as applied');
    Check(Plan[2].Status = drsApply,
      'dry-mixed: new batch reported as apply');

    { 语义分野：同一输入上 Migrate 必须拒绝 }
    Raised := False;
    try
      Migrate(Conn, MakeMigrations([
        TDbMigration.Create(1, [C_SQL_1_TAMPERED]),
        TDbMigration.Create(2, [C_SQL_2]),
        TDbMigration.Create(3, [C_SQL_3]) ]));
    except
      on EDbMigrateError do
        Raised := True;
    end;
    Check(Raised, 'dry-mixed: same input rejected by real Migrate');
  finally
    Conn := nil;
  end;
end;

{ 6 }
procedure TestLegacyTableSelfHeals;
var
  Conn: IDbConnection;
  N: Integer;
  LAt1, LCs1: string;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    { 手工构造 S6 前旧库形态：两列版本表 + 已应用行无 checksum }
    Conn.Exec('CREATE TABLE schema_migrations' +
      ' (version INTEGER PRIMARY KEY, applied_at TEXT)');
    Conn.Exec('CREATE TABLE t_items (id INTEGER PRIMARY KEY, v TEXT)');
    Conn.Exec('INSERT INTO schema_migrations (version, applied_at)' +
      ' VALUES (1, ''2020-01-01T00:00:00Z'')');

    N := Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(N = 1, 'legacy: only the new batch applied');
    ReadVersionRow(Conn, 1, LAt1, LCs1);
    Check(LCs1 = ExpectedChecksum([C_SQL_1]),
      'legacy: empty checksum backfilled from current list');
    Check(LAt1 = '2020-01-01T00:00:00Z',
      'legacy: original applied_at preserved');

    { 回填生效的直接证明：此后篡改可检。
      列表须含全部已应用批次，否则越界守卫先于篡改守卫触发。 }
    Raised := False;
    try
      Migrate(Conn, MakeMigrations([
        TDbMigration.Create(1, [C_SQL_1_TAMPERED]),
        TDbMigration.Create(2, [C_SQL_2]) ]));
    except
      on E: EDbMigrateError do
      begin
        Raised := True;
        Check(E.Version = 1, 'legacy: post-backfill tamper carries version');
      end;
    end;
    Check(Raised, 'legacy: tamper detectable after self-heal');
  finally
    Conn := nil;
  end;
end;

{ 7 }
procedure TestEmptyListAgainstRowsRejected;
var
  Conn: IDbConnection;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Conn.Exec('CREATE TABLE schema_migrations' +
      ' (version INTEGER PRIMARY KEY, applied_at TEXT, checksum TEXT)');
    Conn.Exec('INSERT INTO schema_migrations (version) VALUES (7)');
    Raised := False;
    try
      Migrate(Conn, MakeMigrations([]));
    except
      on E: EDbMigrateError do
      begin
        Raised := True;
        Check(E.Version = 7, 'empty-guard: error carries stranded version');
        Check(Pos('empty', E.Message) > 0,
          'empty-guard: message names the empty list');
      end;
    end;
    Check(Raised, 'empty-guard: applied row with empty list rejected');
  finally
    Conn := nil;
  end;
end;

{ 8 }
procedure TestDescendingListRejected;
var
  Conn: IDbConnection;
  Raised: Boolean;
begin
  Conn := ConnectSqlite(':memory:');
  try
    Raised := False;
    try
      Migrate(Conn, MakeMigrations([
        TDbMigration.Create(5, ['CREATE TABLE z (x INTEGER)']),
        TDbMigration.Create(3, ['CREATE TABLE y (x INTEGER)']) ]));
    except
      on E: EDbMigrateError do
      begin
        Raised := True;
        Check(E.Version = 3, 'ordering: violation carries offending version');
      end;
    end;
    Check(Raised, 'ordering: strictly ascending enforced');
    Check(not TableExists(Conn, 'schema_migrations'),
      'ordering: validation precedes table creation');
  finally
    Conn := nil;
  end;
end;

{ 9 }
procedure TestPooledWriterLeaseReacquirable;
var
  Pool: TDbPool;
  Policy: TDbPoolPolicy;
  Conn, Again: IDbConnection;
  DbPath: string;
begin
  { 回归锁（反哺 B13/F-9）：把池写租约传入 Migrate，返回后租约必须
    立即可再借。缺陷形态：迁移批事务以匿名闭包捕获连接参数，租约
    引用随闭包存活超出 Migrate 生命周期，单写者槽位随之滞留——
    消费方在 Migrate 之后立即借 writer（如会话存储建表）即超时。 }
  DbPath := GetTempDir + 'db_migrate_lease_' + IntToStr(GetProcessID) + '.db';
  DeleteFile(DbPath);
  Policy := TDbPoolPolicy.Default;
  Policy.MaxReadConnections := 1;
  Policy.AcquireTimeoutMs := 1000;
  Pool := TDbPool.Create(
    function: IDbConnection
    begin
      Result := ConnectSqlite(DbPath);
    end, Policy);
  try
    Conn := Pool.Writer;
    try
      Migrate(Conn, MakeMigrations([
        TDbMigration.Create(1, [C_SQL_1, C_SQL_2]) ]));
      Check(MigrationVersion(Conn) = 1, 'lease: migration applied');
    finally
      Conn := nil;                       { 归还写租约 }
    end;
    { 缺陷下此处超时抛 EDbError：写槽位仍被滞留引用占用 }
    Again := Pool.Writer;
    try
      Check(MigrationVersion(Again) = 1, 'slot reacquired and version visible');
    finally
      Again := nil;
    end;
  finally
    Pool.Free;
    DeleteFile(DbPath);
  end;
end;

procedure TestPostgresParity;
var
  Conn: IDbConnection;
  N: Integer;
  Plan: TDbDryRunPlan;
  LAt1, LCs1, LAt2, LCs2: string;
  Raised: Boolean;
begin
  if GPgConn = '' then
  begin
    WriteLn('pg migrate tests skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  Conn := ConnectPostgres(GPgConn);
  try
    Conn.Exec('DROP TABLE IF EXISTS schema_migrations');
    Conn.Exec('DROP TABLE IF EXISTS t_items');

    { fresh 应用 + checksum 与 sqlite 同值（跨后端确定性） }
    N := Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(N = 2, 'pg: both batches applied');
    ReadVersionRow(Conn, 1, LAt1, LCs1);
    ReadVersionRow(Conn, 2, LAt2, LCs2);
    Check(LCs1 = ExpectedChecksum([C_SQL_1]), 'pg: v1 checksum canonical');
    Check(LCs2 = GChecksumSqlite, 'pg: checksum identical across backends');

    { 幂等 }
    N := Migrate(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(N = 0, 'pg: re-run idempotent');

    { dry-run 三态 + 语义分野 }
    Plan := MigrateDryRun(Conn, MakeMigrations([
      TDbMigration.Create(1, [C_SQL_1_TAMPERED]),
      TDbMigration.Create(2, [C_SQL_2]) ]));
    Check(Plan[0].Status = drsChecksumMismatch, 'pg: dry reports mismatch');
    Check(Plan[1].Status = drsApplied, 'pg: dry reports applied');
    Raised := False;
    try
      Migrate(Conn, MakeMigrations([
        TDbMigration.Create(1, [C_SQL_1_TAMPERED]) ]));
    except
      on EDbMigrateError do
        Raised := True;
    end;
    Check(Raised, 'pg: tampered Migrate rejected');

    Conn.Exec('DROP TABLE IF EXISTS schema_migrations');
    Conn.Exec('DROP TABLE IF EXISTS t_items');
  finally
    Conn := nil;
  end;
end;

begin
  RegisterSqliteDriver;
  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.migrate_v2');
  T.Test('fresh apply records checksums', @TestFreshApplyRecordsChecksums);
  T.Test('idempotent re-run', @TestIdempotentRerun);
  T.Test('tampered sql raises with version', @TestTamperedSqlRaises);
  T.Test('dry run zero side effects', @TestDryRunZeroSideEffects);
  T.Test('dry run reports mismatch without raising',
    @TestDryRunReportsMismatchWithoutRaising);
  T.Test('legacy table self-heals', @TestLegacyTableSelfHeals);
  T.Test('empty list against rows rejected', @TestEmptyListAgainstRowsRejected);
  T.Test('descending list rejected', @TestDescendingListRejected);
  T.Test('pooled writer lease reacquirable', @TestPooledWriterLeaseReacquirable);
  T.Test('postgres parity', @TestPostgresParity);
  if not T.Run then Halt(1);
end.
