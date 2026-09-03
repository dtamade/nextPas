unit nextpas.core.db.factory.facade.sqlite;

{**
 * @desc L3 工厂门面分治：sqlite 薄转发单源（2 ConnectSqlite）。
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

function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer = 64): IDbConnection; inline;
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = 64): IDbConnection; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.factory;




{ ---- sqlite facade pure re-export inline thin forward via Kind-driven table, zero adapter hard link ---- }
{ Perf inline/bytes.ops single-source single Move zero-copy; stability interface refcount auto. See CONTRACT §2.14. }

function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  // perf: inline thin forward Kind-driven, zero-copy string COW, bytes.ops single source, interface refcount auto
  Result := DbOpen(dbkSqlite, APath, TDbConnectOptions.Default, AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection; inline;
begin
  Result := DbOpen(dbkSqlite, APath, AOptions, AStmtCacheCapacity);
end;

end.
