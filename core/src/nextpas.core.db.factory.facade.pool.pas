unit nextpas.core.db.factory.facade.pool;

{**
 * @desc L3 工厂门面分治：池薄转发单源（2 OpenSqlitePool）。
 *       inline 薄转发经 factory.pool 桥接叶 Kind 驱动，零 adapter 硬链接；
 *       体积分治：池独立单元 <100 行，软阈 800 隔离。
 *       性能 bytes.ops 单源单 Move 零拷贝，稳定性接口引用计数自动归还，租约 try..finally 不丢。
 *       详见 core/docs/db/CONTRACT.md §2.14。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.pool;

function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline; overload;
function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline; overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.factory.pool;

const
  FACTORY_FACADE_POOL_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  FACTORY_FACADE_POOL_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: factory.facade.pool must reuse bytes.ops'}
{$IFEND}

{$I nextpas.core.bytes.ops.single_source.inc}

{ ---- pool facade pure re-export inline thin forward via factory.pool Kind-driven, zero adapter hard link ---- }

function OpenSqlitePool(const APath: string;
  AMaxReadConnections: Integer): TDbPool; inline;
var
  LPolicy: TDbPoolPolicy;
begin
  // perf: inline thin forward Kind-driven via factory.pool, zero adapter hard link, single Move; stability policy copy stack, interface refcount auto
  LPolicy := TDbPoolPolicy.Default;
  LPolicy.MaxReadConnections := AMaxReadConnections;
  Result := DbOpenPool(dbkSqlite, APath, LPolicy);
end;

function OpenSqlitePool(const APath: string; const APolicy: TDbPoolPolicy;
  const AOptions: TDbConnectOptions): TDbPool; inline;
begin
  // perf: inline thin forward Kind-driven via factory.pool, zero adapter hard link, single Move, zero extra alloc at facade, single closure alloc single source in owner factory.pool (string COW zero-copy, bytes.ops single source)
  // stability: TDbPool try..finally lease + ScopedLease nil归还不丢, interface refcount auto, owner holds closure copy
  Result := DbOpenPool(dbkSqlite, APath, APolicy, AOptions);
end;

end.
