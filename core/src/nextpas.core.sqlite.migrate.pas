unit nextpas.core.sqlite.migrate;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.sqlite.migrate。
       跨后端迁移助手见 nextpas.core.db.migrate。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn,
  nextpas.core.db.sqlite.migrate;

const
  SQLITE_MIGRATIONS_TABLE = nextpas.core.db.sqlite.migrate.SQLITE_MIGRATIONS_TABLE;

type
  ESqliteMigrateError = nextpas.core.db.sqlite.migrate.ESqliteMigrateError;
  TSqliteMigration    = nextpas.core.db.sqlite.migrate.TSqliteMigration;
  TSqliteMigrations   = nextpas.core.db.sqlite.migrate.TSqliteMigrations;

function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations; inline;
function Migrate(const ADb: TSqliteDb; const AMigrations: TSqliteMigrations): Integer; inline;
function MigrationVersion(const ADb: TSqliteDb): Int64; inline;

implementation

function MakeMigrations(const AMigrations: array of TSqliteMigration): TSqliteMigrations;
begin
  Result := nextpas.core.db.sqlite.migrate.MakeMigrations(AMigrations);
end;

function Migrate(const ADb: TSqliteDb; const AMigrations: TSqliteMigrations): Integer;
begin
  Result := nextpas.core.db.sqlite.migrate.Migrate(ADb, AMigrations);
end;

function MigrationVersion(const ADb: TSqliteDb): Int64;
begin
  Result := nextpas.core.db.sqlite.migrate.MigrationVersion(ADb);
end;

end.
