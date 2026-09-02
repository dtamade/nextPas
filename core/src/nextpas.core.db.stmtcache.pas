unit nextpas.core.db.stmtcache;

{** @desc 语句缓存域门面（L3 家族 thin 聚合 per CONTRACT §1.1 §2.8）。
       四件套：stmtcache.base ← stmtcache.intf ← stmtcache 门面 ← 后端实现（sqlite LRU + pg 注册表）。
       L0-L3 ok（依赖 L0-L2 only，bytes.ops 单源复用）。热点 inline + 零拷贝键视图。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.stmtcache.base,
  nextpas.core.db.stmtcache.intf,
  nextpas.core.db.intf;

type
  TDbStmtCacheKind = nextpas.core.db.stmtcache.base.TDbStmtCacheKind;
  IDbStmtCacheStats = nextpas.core.db.stmtcache.intf.IDbStmtCacheStats;
  IDbStmtCacheControl = nextpas.core.db.intf.IDbStmtCacheControl;

function DbStmtCacheEnabled(const ACap: Integer): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

function DbStmtCacheEnabled(const ACap: Integer): Boolean; inline;
begin
  { perf: inline thin forward to intf single source, zero-copy, no duplicate impl }
  Result := nextpas.core.db.stmtcache.intf.DbStmtCacheIsEnabled(ACap);
end;

end.
