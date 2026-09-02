unit nextpas.core.db.sqlscan.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.sqlscan.base;

type
  IDbSqlScanDialectView = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE021}']
    function Kind: TDbSqlScanDialectKind;
  end;

function DbSqlScanNeedsDollar(const AKind: TDbSqlScanDialectKind): Boolean; inline;

implementation

function DbSqlScanNeedsDollar(const AKind: TDbSqlScanDialectKind): Boolean; inline;
begin
  { perf: inline branch, zero-copy view, single source dialect }
  Result := AKind = sskPg;
end;

end.
