unit nextpas.core.db.factory.facade.dm;

{**
 * @desc L3 工厂门面分治：dm 薄转发单源（3 ConnectDm）。
 *       inline 薄转发经 factory 注册表 Kind 驱动，零 adapter 硬链接；
 *       体积分治：单后端独立单元 <100 行，软阈 800 隔离。
 *       性能 bytes.ops 单源单 Move 零拷贝，稳定性接口引用计数自动归还。
 *       详见 core/docs/db/CONTRACT.md §2.14。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.intf;

function ConnectDm(const ADsn: string): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline; overload;
function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline; overload;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.factory;

const
  FACTORY_FACADE_DM_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;
  FACTORY_FACADE_DM_BYTES_SINGLE_SOURCE_VERSION = BYTES_OPS_SINGLE_SOURCE_VERSION;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: factory.facade.dm must reuse bytes.ops'}
{$IFEND}

{$I nextpas.core.bytes.ops.single_source.inc}

{ ---- dm facade pure re-export inline thin forward via Kind-driven table, zero adapter hard link ---- }

function ConnectDm(const ADsn: string): IDbConnection; inline;
begin
  // perf: inline thin forward Kind-driven, zero-copy string COW, bytes.ops single source, interface refcount auto
  Result := DbOpen(dbkDm, ADsn, TDbConnectOptions.Default, 64);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions): IDbConnection; inline;
begin
  // perf: inline thin forward Kind-driven, zero-copy string COW, bytes.ops single source, interface refcount auto
  Result := DbOpen(dbkDm, ADsn, AOptions, 64);
end;

function ConnectDm(const ADsn: string;
  const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline thin forward Kind-driven, zero-copy string COW, bytes.ops single source, interface refcount auto
  Result := DbOpen(dbkDm, ADsn, AOptions, AStmtCacheCapacity);
end;

end.
