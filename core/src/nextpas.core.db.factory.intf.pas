unit nextpas.core.db.factory.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.factory.base,
  nextpas.core.db.base;

type
  IDbFactoryDriverView = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE022}']
    function DriverName: string;
    function DriverKind: TDbKind;
  end;

function DbFactoryIsBuiltinName(const AName: string): Boolean; inline;

implementation

uses
  nextpas.core.text.utils;

function DbFactoryIsBuiltinName(const AName: string): Boolean; inline;
begin
  { perf: inline single source normalize, zero-copy via bytes.ops text.utils }
  Result := (NormalizeLowerTrim(AName) = DB_FACTORY_DRIVER_NAME_SQLITE) or
            (NormalizeLowerTrim(AName) = DB_FACTORY_DRIVER_NAME_POSTGRES) or
            (NormalizeLowerTrim(AName) = DB_FACTORY_DRIVER_NAME_MYSQL) or
            (NormalizeLowerTrim(AName) = DB_FACTORY_DRIVER_NAME_ODBC) or
            (NormalizeLowerTrim(AName) = DB_FACTORY_DRIVER_NAME_REDIS) or
            (NormalizeLowerTrim(AName) = DB_FACTORY_DRIVER_NAME_DM);
end;

end.
