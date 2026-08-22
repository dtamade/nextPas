unit nextpas.core.db.sqlite.migrate;

{** @desc SQLite L2 migration helper (B7).
       - 版本表：schema_migrations（version INTEGER PRIMARY KEY,
         applied_at TEXT 默认当前时间）。
       - 有序迁移列表：TSqliteMigration = 版本号 + 顺序 SQL 步骤数组。
       - 幂等应用：已记录的版本跳过，同列表跑两次结果一致。
       - 每批迁移在单个事务内执行（经 tx 助手，版本行同批写入）：
         任一步失败整批回滚。
       - 版本校验：列表必须严格升序且无重复；任何已应用版本不在列表中
         即拒绝（低于列表最小 = 迁移被删过；高于列表最大 = 库超前于代码）。*}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.db.sqlite.tx;

const
  SQLITE_MIGRATIONS_TABLE = 'schema_migrations';

type
  { 迁移错误：MVVersion 为引发错误的版本号（0 = 与版本无关，如列表乱序）。 }
  ESqliteMigrateError = class(ENextPasError)
  private
    FVersion: Int64;
  public
    constructor Create(const AVersion: Int64; const AMessage: string);
    property Version: Int64 read FVersion;
  end;

  { 一批迁移：Version 升序唯一；Sql 步骤在同一事务内顺序执行。 }
  TSqliteMigration = record
    Version: Int64;
    Sql: array of string;
    class function Create(const AVersion: Int64;
      const ASql: array of string): TSqliteMigration; static;
  end;

  TSqliteMigrations = array of TSqliteMigration;

  { 构造有序迁移列表糖（内联数组 → 动态数组）。 }
  function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations;
  { 应用未执行的迁移，返回本次应用的批数；重复调用幂等。 }
  function Migrate(const ADb: TSqliteDb; const AMigrations: TSqliteMigrations): Integer;
  { 数据库当前版本（schema_migrations 最高已应用版本；无表/空表 = 0）。 }
  function MigrationVersion(const ADb: TSqliteDb): Int64;

implementation

uses
  nextpas.core.db.sqlite.ffi;

constructor ESqliteMigrateError.Create(const AVersion: Int64;
  const AMessage: string);
begin
  inherited Create(AMessage);
  FVersion := AVersion;
end;

class function TSqliteMigration.Create(const AVersion: Int64;
  const ASql: array of string): TSqliteMigration;
var
  I: Integer;
begin
  Result.Version := AVersion;
  SetLength(Result.Sql, Length(ASql));
  for I := 0 to High(ASql) do
    Result.Sql[I] := ASql[I];
end;

function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AMigrations));
  for I := 0 to High(AMigrations) do
    Result[I] := AMigrations[I];
end;

procedure EnsureVersionTable(const ADb: TSqliteDb);
begin
  ADb.Exec('CREATE TABLE IF NOT EXISTS ' + SQLITE_MIGRATIONS_TABLE +
    ' (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT ' +
    '(strftime(''%Y-%m-%dT%H:%M:%fZ'', ''now'')))');
end;

{ 读已应用版本（PK 升序）；表缺失返回空。 }
type
  TSqliteVersionList = array of Int64;

function LoadAppliedVersions(const ADb: TSqliteDb): TSqliteVersionList;
var
  Q: TSqliteQuery;
  LCount: Integer;
begin
  Result := nil;
  try
    Q := ADb.Query('SELECT version FROM ' + SQLITE_MIGRATIONS_TABLE);
  except
    on ESqliteError do
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
    Q.Free;
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

procedure ValidateMigrations(const AMigrations: TSqliteMigrations);
var
  I: Integer;
begin
  for I := 1 to High(AMigrations) do
    if AMigrations[I].Version <= AMigrations[I - 1].Version then
      raise ESqliteMigrateError.Create(AMigrations[I].Version,
        'migration list must be strictly ascending, violated at index ' +
        IntToStr(I));
end;

{ 列表里是否存在该版本。 }
function HasMigrationVersion(const AMigrations: TSqliteMigrations;
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
procedure ValidateAppliedVersions(const AMigrations: TSqliteMigrations;
  const AApplied: array of Int64);
var
  I: Integer;
begin
  for I := 0 to High(AApplied) do
    if not HasMigrationVersion(AMigrations, AApplied[I]) then
    begin
      if Length(AMigrations) = 0 then
        raise ESqliteMigrateError.Create(AApplied[I],
          'database has applied version ' + IntToStr(AApplied[I]) +
          ' but the migration list is empty');
      if AApplied[I] > AMigrations[High(AMigrations)].Version then
        raise ESqliteMigrateError.Create(AApplied[I],
          'applied version ' + IntToStr(AApplied[I]) +
          ' is ahead of the migration list (upper bound ' +
          IntToStr(AMigrations[High(AMigrations)].Version) + ')')
      else if AApplied[I] < AMigrations[0].Version then
        raise ESqliteMigrateError.Create(AApplied[I],
          'applied version ' + IntToStr(AApplied[I]) +
          ' is below the migration list (lower bound ' +
          IntToStr(AMigrations[0].Version) +
          '); older migrations were likely removed')
      else
        raise ESqliteMigrateError.Create(AApplied[I],
          'applied version ' + IntToStr(AApplied[I]) +
          ' is missing from the migration list');
    end;
end;

function Migrate(const ADb: TSqliteDb; const AMigrations: TSqliteMigrations): Integer;
var
  LApplied: array of Int64;
  I: Integer;
  LM: TSqliteMigration;
begin
  if ADb = nil then
    raise ESqliteMigrateError.Create(0, 'Migrate on a nil connection');
  EnsureVersionTable(ADb);
  ValidateMigrations(AMigrations);
  LApplied := LoadAppliedVersions(ADb);
  ValidateAppliedVersions(AMigrations, LApplied);
  Result := 0;
  for I := 0 to High(AMigrations) do
  begin
    if IsApplied(AMigrations[I].Version, LApplied) then
      Continue;               { 幂等：同版本跳过 }
    LM := AMigrations[I];
    WithTransaction(ADb, procedure
      var
        K: Integer;
      begin
        for K := 0 to High(LM.Sql) do
          ADb.Exec(LM.Sql[K]);
        ADb.Exec('INSERT INTO ' + SQLITE_MIGRATIONS_TABLE +
          ' (version) VALUES (' + IntToStr(LM.Version) + ')');
      end);
    Inc(Result);
  end;
end;

function MigrationVersion(const ADb: TSqliteDb): Int64;
var
  Q: TSqliteQuery;
begin
  if ADb = nil then
    raise ESqliteMigrateError.Create(0, 'MigrationVersion on a nil connection');
  try
    Q := ADb.Query('SELECT MAX(version) FROM ' + SQLITE_MIGRATIONS_TABLE);
  except
    on ESqliteError do
      Exit(0);
  end;
  try
    if Q.Step then
      Result := Q.GetInt64(0)
    else
      Result := 0;
  finally
    Q.Free;
  end;
end;

end.