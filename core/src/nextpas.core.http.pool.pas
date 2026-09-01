unit nextpas.core.http.pool;
{**
 * @desc Client connection pool facade (L3 http domain extracted per CONTRACT §1.1).
 *       Four-piece: pool.base ← pool.intf ← pool (thin facade, NO umbrella re-export of impl pools).
 *       Impl pools stay owner-local (impl.h1.pool / impl.h2.client.pool) with per-domain PoolClear/CloseIdle + heaptrc 0 independent gate.
 *       L0-L3: depends only on L0-L2 (bytes.ops single source via text.conv, net). Hot helpers inline, zero-copy key view.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.pool.base,
  nextpas.core.http.pool.intf;

type
  THttpPoolKey = nextpas.core.http.pool.base.THttpPoolKey;
  IHttpPool = nextpas.core.http.pool.intf.IHttpPool;
  IHttpPoolH2 = nextpas.core.http.pool.intf.IHttpPoolH2;

function CanonicalPoolHostKey(const AHost: string): string; inline;
function HttpPoolDefaultMaxSize: Int32; inline;
function HttpPoolDefaultIdleTTL: Int64; inline;

implementation

uses
  nextpas.core.text.conv;

function CanonicalPoolHostKey(const AHost: string): string; inline;
begin
  { perf: inline zero-copy LowerCase via text.conv → bytes.ops single source; no duplicate impl, no umbrella coupling }
  Result := LowerCase(AHost);
end;

function HttpPoolDefaultMaxSize: Int32; inline;
begin
  Result := HTTP_POOL_DEFAULT_MAX_SIZE;
end;

function HttpPoolDefaultIdleTTL: Int64; inline;
begin
  Result := HTTP_POOL_DEFAULT_IDLE_TTL_MS;
end;

end.
