unit nextpas.core.pg;

{** @desc 兼容 shim（2026-08-25 恢复）：旧单元名 → 统一层薄转发。
       G2 曾删除本 shim；应并行项目依赖紧急恢复。仅 re-export
       `nextpas.core.db.pg` 现存公开面；新代码一律 uses
       nextpas.core.db / nextpas.core.db.pg。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.conn;

type
  EPgError = nextpas.core.db.pg.EPgError;
  TPgConn = nextpas.core.db.pg.TPgConn;
  TPgQuery = nextpas.core.db.pg.TPgQuery;

const
  CONNECTION_OK = nextpas.core.db.pg.CONNECTION_OK;
  CONNECTION_BAD = nextpas.core.db.pg.CONNECTION_BAD;

function PgOpen(const AConnInfo: string): TPgConn; inline;

implementation

function PgOpen(const AConnInfo: string): TPgConn;
begin
  Result := nextpas.core.db.pg.PgOpen(AConnInfo);
end;

end.
