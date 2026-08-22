unit nextpas.core.db.migrate;

{** @desc 跨后端 schema 版本化迁移（IDbConnection 上的 sqlite.migrate
       泛化版）。

       - 版本表：schema_migrations(version INTEGER PRIMARY KEY,
         applied_at TEXT)。DDL 两引擎通用；applied_at 由本单元显式
         写入 ISO8601 UTC 文本（不再依赖后端专属默认值表达式）。
       - 有序迁移列表：TDbMigration = 版本号 + 顺序 SQL 步骤数组。
       - 幂等应用：已记录版本跳过，同列表重复调用结果一致。
       - 每批迁移在单个事务内执行（经 nextpas.core.db.tx，版本行同批
         写入）：任一步失败整批回滚、不记版本。
       - 版本校验：列表必须严格升序且无重复；任何已应用版本不在列表
         中即拒绝（低于最小 = 迁移被删过；高于最大 = 库超前于代码）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf;

const
  DB_MIGRATIONS_TABLE = 'schema_migrations';

type
  { 迁移错误：Version 为引发错误的版本号（0 = 与版本无关，如列表乱序）。 }
  EDbMigrateError = class(EDbError)
  private
    FVersion: Int64;
  public
    constructor Create(const ABackend: TDbKind; const AVersion: Int64;
      const AMessage: string);
    property Version: Int64 read FVersion;
  end;

  { 一批迁移：Version 升序唯一；Sql 步骤在同一事务内顺序执行。 }
  TDbMigration = record
    Version: Int64;
    Sql: array of string;
    class function Create(const AVersion: Int64;
      const ASql: array of string): TDbMigration; static;
  end;

  TDbMigrations = array of TDbMigration;

  { 构造有序迁移列表糖（内联数组 → 动态数组）。 }
  function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations;
  { 应用未执行的迁移，返回本次应用的批数；重复调用幂等。 }
  function Migrate(const AConn: IDbConnection; const AMigrations: TDbMigrations): Integer;
  { 数据库当前版本（schema_migrations 最高已应用版本；无表/空表 = 0）。 }
  function MigrationVersion(const AConn: IDbConnection): Int64;

implementation

uses
  nextpas.core.db.tx,
  nextpas.core.time;

constructor EDbMigrateError.Create(const ABackend: TDbKind;
  const AVersion: Int64; const AMessage: string);
begin
  inherited CreateSimple(ABackend, AMessage);
  FVersion := AVersion;
end;

class function TDbMigration.Create(const AVersion: Int64;
  const ASql: array of string): TDbMigration;
var
  I: Integer;
begin
  Result.Version := AVersion;
  SetLength(Result.Sql, Length(ASql));
  for I := 0 to High(ASql) do
    Result.Sql[I] := ASql[I];
end;

function MakeMigrations(const AMigrations: array of TDbMigration): TDbMigrations;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AMigrations));
  for I := 0 to High(AMigrations) do
    Result[I] := AMigrations[I];
end;

procedure EnsureVersionTable(const AConn: IDbConnection);
begin
  AConn.Exec('CREATE TABLE IF NOT EXISTS ' + DB_MIGRATIONS_TABLE +
    ' (version INTEGER PRIMARY KEY, applied_at TEXT)');
end;

{ 读已应用版本（PK 升序）；表缺失返回空。 }
type
  TDbVersionList = array of Int64;

function LoadAppliedVersions(const AConn: IDbConnection): TDbVersionList;
var
  Q: IDbQuery;
  LCount: Integer;
begin
  Result := nil;
  try
    Q := AConn.Query('SELECT version FROM ' + DB_MIGRATIONS_TABLE +
      ' ORDER BY version ASC');
  except
    on EDbError do
      Exit(nil);
  end;
  try
    LCount := 0;
    while Q.Step do
    begin
      Inc(LCount);
      SetLength(Result, LCount);
      Result[LCount - 1] := Q.GetInt64(0);
    end;
  finally
    Q := nil;
  end;
end;

function IsApplied(const AVersion: Int64; const AApplied: array of Int64): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AApplied) do
    if AApplied[I] = AVersion then
      Exit(True);
  Result := False;
end;

procedure ValidateMigrations(const AConn: IDbConnection;
  const AMigrations: TDbMigrations);
var
  I: Integer;
begin
  for I := 1 to High(AMigrations) do
    if AMigrations[I].Version <= AMigrations[I - 1].Version then
      raise EDbMigrateError.Create(AConn.Kind, AMigrations[I].Version,
        'migration list must be strictly ascending, violated at index ' +
        IntToStr(I));
end;

{ 列表里是否存在该版本。 }
function HasMigrationVersion(const AMigrations: TDbMigrations;
  const AVersion: Int64): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AMigrations) do
    if AMigrations[I].Version = AVersion then
      Exit(True);
  Result := False;
end;

{ 上下限校验：已应用版本必须都在列表内。 }
procedure ValidateAppliedVersions(const AConn: IDbConnection;
  const AMigrations: TDbMigrations; const AApplied: array of Int64);
var
  I: Integer;
begin
  for I := 0 to High(AApplied) do
    if not HasMigrationVersion(AMigrations, AApplied[I]) then
    begin
      if Length(AMigrations) = 0 then
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I],
          'database has applied version ' + IntToStr(AApplied[I]) +
          ' but the migration list is empty');
      if AApplied[I] > AMigrations[High(AMigrations)].Version then
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I],
          'applied version ' + IntToStr(AApplied[I]) +
          ' is ahead of the migration list (upper bound ' +
          IntToStr(AMigrations[High(AMigrations)].Version) + ')')
      else if AApplied[I] < AMigrations[0].Version then
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I],
          'applied version ' + IntToStr(AApplied[I]) +
          ' is below the migration list (lower bound ' +
          IntToStr(AMigrations[0].Version) +
          '); older migrations were likely removed')
      else
        raise EDbMigrateError.Create(AConn.Kind, AApplied[I],
          'applied version ' + IntToStr(AApplied[I]) +
          ' is missing from the migration list');
    end;
end;

function Migrate(const AConn: IDbConnection; const AMigrations: TDbMigrations): Integer;
var
  LApplied: array of Int64;
  I: Integer;
  LM: TDbMigration;
begin
  if AConn = nil then
    raise EDbMigrateError.Create(dbkSqlite, 0, 'Migrate on a nil connection');
  EnsureVersionTable(AConn);
  ValidateMigrations(AConn, AMigrations);
  LApplied := LoadAppliedVersions(AConn);
  ValidateAppliedVersions(AConn, AMigrations, LApplied);
  Result := 0;
  for I := 0 to High(AMigrations) do
  begin
    if IsApplied(AMigrations[I].Version, LApplied) then
      Continue;               { 幂等：同版本跳过 }
    LM := AMigrations[I];
    WithTransaction(AConn, procedure
      var
        K: Integer;
      begin
        for K := 0 to High(LM.Sql) do
          AConn.Exec(LM.Sql[K]);
        AConn.Exec('INSERT INTO ' + DB_MIGRATIONS_TABLE +
          ' (version, applied_at) VALUES (' + IntToStr(LM.Version) +
          ', ''' + FormatISO8601UTC(DateTimeToUnix(DateTimeUtcNow())) + ''')');
      end);
    Inc(Result);
  end;
end;

function MigrationVersion(const AConn: IDbConnection): Int64;
var
  Q: IDbQuery;
begin
  if AConn = nil then
    raise EDbMigrateError.Create(dbkSqlite, 0,
      'MigrationVersion on a nil connection');
  try
    Q := AConn.Query('SELECT MAX(version) FROM ' + DB_MIGRATIONS_TABLE);
  except
    on EDbError do
      Exit(0);
  end;
  try
    if Q.Step then
      Result := Q.GetInt64(0)
    else
      Result := 0;
  finally
    Q := nil;
  end;
end;

end.
