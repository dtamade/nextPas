unit nextpas.core.db.sqlscan.base;

{$I nextpas.core.settings.inc}

interface

type
  TDbSqlScanDialectKind = (sskPg, sskMysql, sskOdbc);

const
  DBSQLSCAN_PG_KIND = sskPg;
  DBSQLSCAN_MYSQL_KIND = sskMysql;
  DBSQLSCAN_ODBC_KIND = sskOdbc;

implementation

end.
