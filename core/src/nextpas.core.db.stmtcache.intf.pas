unit nextpas.core.db.stmtcache.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.stmtcache.base,
  nextpas.core.db.intf;

type
  IDbStmtCacheStats = interface
    ['{7C9D2E18-3A64-4B7F-9E25-D81C04FA67C0}']
    function Capacity: Integer;
    function Kind: TDbStmtCacheKind;
  end;

function DbStmtCacheIsEnabled(const ACapacity: Integer): Boolean; inline;

implementation

function DbStmtCacheIsEnabled(const ACapacity: Integer): Boolean; inline;
begin
  { perf: inline branch, zero alloc, single source capacity check }
  Result := ACapacity > DB_STMT_CACHE_DISABLED;
end;

end.
