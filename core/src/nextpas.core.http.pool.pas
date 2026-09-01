unit nextpas.core.http.pool;
{**
 * @desc Client connection pool facade (L3 http domain extracted per CONTRACT §1.1).
 *       Aggregates impl.h1.pool + impl.h2.client.pool; four-piece: pool.base ← pool.intf ← pool ← impl.*.
 *       L0-L3: depends only on L0-L2 (bytes.ops single source, net, sync). Hot helpers inline, zero-copy key view.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.pool.base,
  nextpas.core.http.pool.intf,
  nextpas.core.http.impl.h1.pool,
  nextpas.core.http.impl.h2.client.pool;

type
  THttpPoolKey = nextpas.core.http.pool.base.THttpPoolKey;
  IHttpPool = nextpas.core.http.pool.intf.IHttpPool;
  IHttpPoolH2 = nextpas.core.http.pool.intf.IHttpPoolH2;

  TH1IdleConnectionPool = nextpas.core.http.impl.h1.pool.TH1IdleConnectionPool;
  TH2IdleConnectionPool = nextpas.core.http.impl.h2.client.pool.TH2IdleConnectionPool;

function CanonicalPoolHostKey(const AHost: string): string; inline;
function HttpPoolDefaultMaxSize: Int32; inline;
function HttpPoolDefaultIdleTTL: Int64; inline;

implementation

uses
  nextpas.core.bytes.ops;

function CanonicalPoolHostKey(const AHost: string): string; inline;
begin
  { perf: inline thin forward to bytes.ops single source (LowerCase via text.conv → bytes.ops); zero-copy view, no duplicate impl }
  Result := nextpas.core.http.impl.h1.pool.CanonicalPoolHostKey(AHost);
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
