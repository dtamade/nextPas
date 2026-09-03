unit nextpas.core.db.factory.pool;

{ Factory-pool bridge: fully independent build isolation.
  factory registry remains zero L2 imports; this leaf hard-links
  factory + pool to provide DbOpenPool (Go *sql.DB) composition.
  See CONTRACT §2.14. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.pool,
  nextpas.core.db.pool.base;

{ Open is pool: builds V3-C3 pool with factory DbOpen as factory closure.
  Pool integration isolated here for independent build isolation
  (factory zero L2, pool bridge opt-in). Single closure alloc single source:
  TDbPool.Create single source, string COW zero-copy, bytes.ops single source. }
function DbOpenPool(const ADriver: string; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload; inline;
function DbOpenPool(AKind: TDbKind; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload; inline;
function DbOpenPool(const ADriver: string; const ADsn: string;
  const APolicy: TDbPoolPolicy; const AOptions: TDbConnectOptions): TDbPool; overload; inline;
function DbOpenPool(AKind: TDbKind; const ADsn: string;
  const APolicy: TDbPoolPolicy; const AOptions: TDbConnectOptions): TDbPool; overload; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.factory,
  nextpas.core.db.intf;

const
  FACTORY_POOL_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  FACTORY_POOL_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$I nextpas.core.bytes.ops.single_source.inc}

function DbOpenPool(const ADriver: string; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload; inline;
begin
  // perf: inline thin forward to Options single source, zero extra alloc at facade, bytes.ops single source; stability interface refcount auto
  Result := DbOpenPool(ADriver, ADsn, APolicy, TDbConnectOptions.Default);
end;

function DbOpenPool(AKind: TDbKind; const ADsn: string;
  const APolicy: TDbPoolPolicy): TDbPool; overload; inline;
begin
  // perf: inline thin forward to Options single source (Kind dispatch), same cost model
  Result := DbOpenPool(AKind, ADsn, APolicy, TDbConnectOptions.Default);
end;

function DbOpenPool(const ADriver: string; const ADsn: string;
  const APolicy: TDbPoolPolicy; const AOptions: TDbConnectOptions): TDbPool; overload; inline;
begin
  // perf: single closure alloc capturing ADriver/ADsn COW zero-copy via factory, TDbPool.Create single source, bytes.ops single source single Move zero-copy; stability try..finally in TDbPoolCore + ScopedLease nil归还不丢, closure refcount holds copies, interface auto
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      Result := DbOpen(ADriver, ADsn, AOptions, 64);
    end, APolicy);
end;

function DbOpenPool(AKind: TDbKind; const ADsn: string;
  const APolicy: TDbPoolPolicy; const AOptions: TDbConnectOptions): TDbPool; overload; inline;
begin
  // perf: single closure alloc with Kind dispatch, zero-copy string COW, single source; stability factory Kind fallback fail-closed, pool try..finally not lost
  Result := TDbPool.Create(
    function: IDbConnection
    begin
      Result := DbOpen(AKind, ADsn, AOptions, 64);
    end, APolicy);
end;

end.
