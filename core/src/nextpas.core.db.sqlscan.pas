unit nextpas.core.db.sqlscan;

{** @desc db.sqlscan thin re-export：类型/常量/函数全部转自 L1 nextpas.core.text.sqlscan。
    本单元零逻辑，禁止重复实现；历史五份状态机已收敛至 L1 单遍引擎。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.sqlscan;

type
  TDbSqlScanDialect = TSqlScanDialect;
  TDbSqlSlotArray = TSqlScanSlotArray;

const
  DBSQLSCAN_PG = SQLSCAN_PG;
  DBSQLSCAN_MYSQL = SQLSCAN_MYSQL;
  DBSQLSCAN_ODBC = SQLSCAN_ODBC;

function SqlScanTranslateQuestion(const ASql: string; const ADialect: TDbSqlScanDialect; out ARewritten: string; out ASlots: TDbSqlSlotArray): Integer; inline;
function SqlScanRenderDollar(const ASql: string; const ADialect: TDbSqlScanDialect): string; inline;
function SqlScanMaxPlaceholderIndex(const ASql: string; const ADialect: TDbSqlScanDialect; const APhChar: AnsiChar): Integer; inline;
function SqlScanDecorate(const ASql: string; const ADialect: TDbSqlScanDialect; const APhChar: AnsiChar; const AIndexes: array of Integer; const ASuffix: string): string; inline;

implementation

function SqlScanTranslateQuestion(const ASql: string; const ADialect: TDbSqlScanDialect; out ARewritten: string; out ASlots: TDbSqlSlotArray): Integer;
begin
  Result := nextpas.core.text.sqlscan.SqlScanTranslateQuestion(ASql, ADialect, ARewritten, ASlots);
end;

function SqlScanRenderDollar(const ASql: string; const ADialect: TDbSqlScanDialect): string;
begin
  Result := nextpas.core.text.sqlscan.SqlScanRenderDollar(ASql, ADialect);
end;

function SqlScanMaxPlaceholderIndex(const ASql: string; const ADialect: TDbSqlScanDialect; const APhChar: AnsiChar): Integer;
begin
  Result := nextpas.core.text.sqlscan.SqlScanMaxPlaceholderIndex(ASql, ADialect, APhChar);
end;

function SqlScanDecorate(const ASql: string; const ADialect: TDbSqlScanDialect; const APhChar: AnsiChar; const AIndexes: array of Integer; const ASuffix: string): string;
begin
  Result := nextpas.core.text.sqlscan.SqlScanDecorate(ASql, ADialect, APhChar, AIndexes, ASuffix);
end;

end.
