unit nextpas.core.pg.loader;

{** @desc DEPRECATED 兼容 shim —— 已迁入 nextpas.core.db.pg.loader。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.pg.loader;

procedure PgEnsureLoaded; inline;

implementation

procedure PgEnsureLoaded;
begin
  nextpas.core.db.pg.loader.PgEnsureLoaded;
end;

end.
