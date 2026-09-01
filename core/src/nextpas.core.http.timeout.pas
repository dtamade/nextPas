unit nextpas.core.http.timeout;
{**
 * @desc Timeout strategy thin facade (L3 http domain extracted per CONTRACT §1.1 §2.2).
 *       Aggregates timeout.base + timeout.intf helpers; four-piece base←intf←facade.
 *       L0-L3 ok (L3 http → L0-L2 only, plus http.base single source reuse). inline hot, zero-copy view.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.timeout.base,
  nextpas.core.http.timeout.intf,
  nextpas.core.http.base;

type
  THttpTimeoutPolicy = nextpas.core.http.timeout.base.THttpTimeoutPolicy;
  IHttpTimeoutPolicy = nextpas.core.http.timeout.intf.IHttpTimeoutPolicy;

function HttpTimeoutPolicyDefault: THttpTimeoutPolicy; inline;
function HttpTimeoutPolicyFromClient(const AOpts: THttpClientOptions): THttpTimeoutPolicy; inline;
function HttpTimeoutPolicyFromServer(const AOpts: THttpServerOptions): THttpTimeoutPolicy; inline;
function HttpTimeoutIsIdleExpired(const AIdleAtMs, ANowMs: Int64; const APolicy: THttpTimeoutPolicy): Boolean; inline;
function HttpTimeoutShouldCloseIdle(const AElapsedMs: Int64; const APolicy: THttpTimeoutPolicy): Boolean; inline;

implementation

function HttpTimeoutPolicyDefault: THttpTimeoutPolicy; inline;
begin
  { perf: inline single source defaults, no alloc }
  Result := THttpTimeoutPolicy.Default;
end;

function HttpTimeoutPolicyFromClient(const AOpts: THttpClientOptions): THttpTimeoutPolicy; inline;
begin
  { perf: inline thin copy, single source reuse of http.base fields, zero-copy }
  Result.ClientTimeoutMs := AOpts.Timeout;
  Result.ConnectTimeoutMs := AOpts.ConnectTimeout;
  Result.IdleTTLMs := AOpts.IdleTTL;
  Result.ServerReadMs := HTTP_TIMEOUT_SERVER_READ_DEFAULT_MS;
  Result.ServerWriteMs := HTTP_TIMEOUT_SERVER_WRITE_DEFAULT_MS;
  Result.ServerIdleMs := HTTP_TIMEOUT_SERVER_IDLE_DEFAULT_MS;
end;

function HttpTimeoutPolicyFromServer(const AOpts: THttpServerOptions): THttpTimeoutPolicy; inline;
begin
  { perf: inline thin copy, single source reuse }
  Result.ClientTimeoutMs := HTTP_TIMEOUT_CLIENT_DEFAULT_MS;
  Result.ConnectTimeoutMs := HTTP_TIMEOUT_CONNECT_DEFAULT_MS;
  Result.IdleTTLMs := HTTP_TIMEOUT_IDLE_TTL_DEFAULT_MS;
  Result.ServerReadMs := AOpts.ReadTimeout;
  Result.ServerWriteMs := AOpts.WriteTimeout;
  Result.ServerIdleMs := AOpts.IdleTimeout;
end;

function HttpTimeoutIsIdleExpired(const AIdleAtMs, ANowMs: Int64; const APolicy: THttpTimeoutPolicy): Boolean; inline;
begin
  { perf: inline delegates to intf single source, no heap }
  Result := nextpas.core.http.timeout.intf.HttpTimeoutIsExpired(AIdleAtMs, ANowMs, APolicy.IdleTTLMs);
end;

function HttpTimeoutShouldCloseIdle(const AElapsedMs: Int64; const APolicy: THttpTimeoutPolicy): Boolean; inline;
begin
  { perf: inline, no alloc }
  Result := nextpas.core.http.timeout.intf.HttpTimeoutShouldCloseServerIdle(AElapsedMs, APolicy.ServerIdleMs);
end;

end.
