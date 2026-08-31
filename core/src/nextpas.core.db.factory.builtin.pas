unit nextpas.core.db.factory.builtin;

{** @desc 内建驱动自注册聚合 — side-effect import，等价 Go driver 隐式注册。
       薄聚合 6 后端 adapter（sqlite/pg/mysql/odbc/redis/dm），零业务逻辑，
       `uses nextpas.core.db.factory.builtin` 即得全量字典序快照与 DbOpen 全覆盖。
       裁剪场景改直用单 backend adapter 的 Connect*。 *}

{$I nextpas.core.settings.inc}

interface

implementation

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.factory,
  nextpas.core.db.sqlite.adapter,
  nextpas.core.db.pg.adapter,
  nextpas.core.db.mysql.adapter,
  nextpas.core.db.odbc.adapter,
  nextpas.core.db.redis.adapter,
  nextpas.core.db.dm.adapter;

function OpenSqlite(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin Result := ConnectSqlite(ADsn, AOptions); end;
function OpenPg(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin Result := ConnectPostgres(ADsn, AOptions); end;
function OpenMysql(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin Result := ConnectMysql(ADsn, AOptions); end;
function OpenOdbc(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin Result := ConnectOdbc(ADsn, AOptions); end;
function OpenRedis(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin Result := ConnectRedis(ADsn); end;
function OpenDm(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin Result := ConnectDm(ADsn, AOptions); end;

procedure RegisterBuiltins;
begin
  DbRegisterDriver(TBuiltinDriver.Create('sqlite', dbkSqlite, @OpenSqlite));
  DbRegisterDriver(TBuiltinDriver.Create('postgres', dbkPostgres, @OpenPg));
  DbRegisterDriver(TBuiltinDriver.Create('mysql', dbkMysql, @OpenMysql));
  DbRegisterDriver(TBuiltinDriver.Create('odbc', dbkOdbc, @OpenOdbc));
  DbRegisterDriver(TBuiltinDriver.Create('redis', dbkRedis, @OpenRedis));
  DbRegisterDriver(TBuiltinDriver.Create('dm', dbkDm, @OpenDm));
end;

initialization
  RegisterBuiltins;

end.
