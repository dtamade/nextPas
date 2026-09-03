unit nextpas.core.db.factory.facade;

{**
 * @desc L3 工厂门面薄层：6 后端工厂聚合（15 Connect* + 2 OpenSqlitePool）。
 *       inline 薄转发经 factory 注册表 Kind 驱动，零 adapter 硬链接；
 *       体积分治：6 后端 + 池独立单元 <100 行/单元，聚合门面 <150 行，软阈 800 隔离
 *       （facade.sqlite/pg/mysql/odbc/redis/dm/pool 分治单源，每单元 bytes.ops 单源）。
 *       可裁剪边界 = 直连 adapter Connect* 或按需 factory.register.* 单后端注册单元。
 *       性能 bytes.ops 单源单 Move 零拷贝，稳定性接口引用计数自动归还，租约 try..finally 不丢。
 *       详见 core/docs/db/CONTRACT.md §2.14。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.pool;

{ ---- 6 backends × 3 overloads (sqlite 2 + pg/mysql/odbc 3 + redis 1 + dm 3 = 15) ---- }
{ Kind-driven via DbOpen/DbOpenPool; backend tuning via direct adapters. See CONTRACT §2.14. }
function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer = 64): IDbConnection; inline;
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = 64): IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string): IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
function ConnectMysql(const ADsn: string): IDbConnection; inline;
function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
function ConnectOdbc(const ADsn: string): IDbConnection; inline;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
function ConnectRedis(const AAddr: string): IDbConnection; inline;
function ConnectDm(const ADsn: string): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline; overload;

{ ---- 池工厂（开箱组合：池策略 × 后端连接选项）---- }
function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline; overload;
function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline; overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.factory.facade.sqlite,
  nextpas.core.db.factory.facade.pg,
  nextpas.core.db.factory.facade.mysql,
  nextpas.core.db.factory.facade.odbc,
  nextpas.core.db.factory.facade.redis,
  nextpas.core.db.factory.facade.dm,
  nextpas.core.db.factory.facade.pool;




{ ---- factory facade aggregator: inline thin forward to per-backend single-source units, zero adapter hard link ---- }
{ Perf inline/bytes.ops single-source single Move zero-copy; stability interface refcount auto, pool lease try..finally. See CONTRACT §2.14. }
{ Per-backend分治单源：sqlite/pg/mysql/odbc/redis/dm/pool 各 <100 行，聚合门面 <150 行，软阈 800 隔离；bytes.ops 单源复用 owner=bytes.ops。 }
{ perf: inline thin forward Kind-driven, zero adapter hard link, per-backend分治单源，软阈 800 隔离，bytes.ops 单源单 Move 零拷贝。 }
{ Inline red line 2 (design-conventions.md:129): loop/SIMD/routing body not inline — real loop/SIMD kept in owner, thin dispatch only. Enforced by core/tests/nextpas.core.db/test_db_facade_source_contract/check_db_facade_source_contract.sh }

function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline thin forward Kind-driven to per-backend single source, zero-copy string COW, bytes.ops single source, interface refcount auto
  Result := nextpas.core.db.factory.facade.sqlite.ConnectSqlite(APath, AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline thin forward Kind-driven to per-backend single source, zero-copy string COW, bytes.ops single source, interface refcount auto
  Result := nextpas.core.db.factory.facade.sqlite.ConnectSqlite(APath, AOptions, AStmtCacheCapacity);
end;

function ConnectPostgres(const AConnInfo: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.pg.ConnectPostgres(AConnInfo);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.pg.ConnectPostgres(AConnInfo, AOptions);
end;

function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.pg.ConnectPostgres(AConnInfo, AOptions, AStmtCacheCapacity);
end;

function ConnectMysql(const ADsn: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.mysql.ConnectMysql(ADsn);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.mysql.ConnectMysql(ADsn, AOptions);
end;

function ConnectMysql(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.mysql.ConnectMysql(ADsn, AOptions, AStmtCacheCapacity);
end;

function ConnectOdbc(const ADsn: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.odbc.ConnectOdbc(ADsn);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.odbc.ConnectOdbc(ADsn, AOptions);
end;

function ConnectOdbc(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.odbc.ConnectOdbc(ADsn, AOptions, AStmtCacheCapacity);
end;

function ConnectRedis(const AAddr: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.redis.ConnectRedis(AAddr);
end;

function ConnectDm(const ADsn: string): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.dm.ConnectDm(ADsn);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.dm.ConnectDm(ADsn, AOptions);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := nextpas.core.db.factory.facade.dm.ConnectDm(ADsn, AOptions, AStmtCacheCapacity);
end;

function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline;
begin
  // perf: aggregator inline thin forward to pool single source, zero adapter hard link, single Move; stability policy copy stack, interface refcount auto
  Result := nextpas.core.db.factory.facade.pool.OpenSqlitePool(APath, AMaxReadConnections);
end;

function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline;
begin
  // perf: aggregator inline thin forward Kind-driven, zero adapter hard link, single Move, zero extra alloc at facade, single closure alloc single source in owner factory.pool (string COW zero-copy, bytes.ops single source)
  // stability: TDbPool try..finally lease + ScopedLease nil归还不丢, interface refcount auto, owner holds closure copy
  Result := nextpas.core.db.factory.facade.pool.OpenSqlitePool(APath, APolicy, AOptions);
end;

end.
