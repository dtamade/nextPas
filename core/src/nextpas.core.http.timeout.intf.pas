unit nextpas.core.http.timeout.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.timeout.base;

type
  IHttpTimeoutPolicy = interface
    ['{E1F2A3B4-C5D6-4E7F-8A9B-5678901234EF}']
    function Policy: THttpTimeoutPolicy;
    function EffectiveConnectTimeoutMs: Int64;
    function IsExpiredIdle(const AIdleAtMs, ANowMs: Int64): Boolean;
  end;

function HttpTimeoutIsExpired(const AIdleAtMs, ANowMs, ATTLMs: Int64): Boolean; inline;
function HttpTimeoutShouldCloseServerIdle(const AElapsedMs, AIdleTimeoutMs: Int64): Boolean; inline;
function HttpTimeoutEffectiveConnect(const AClientMs, AConnectMs: Int64): Int64; inline;

implementation

function HttpTimeoutIsExpired(const AIdleAtMs, ANowMs, ATTLMs: Int64): Boolean; inline;
begin
  { perf: inline int compare, no alloc, wall-clock check for IdleTTL }
  if ATTLMs = HTTP_TIMEOUT_INFINITE then
    Exit(False);
  Result := (ANowMs - AIdleAtMs) >= ATTLMs;
end;

function HttpTimeoutShouldCloseServerIdle(const AElapsedMs, AIdleTimeoutMs: Int64): Boolean; inline;
begin
  { perf: inline, server gap timeout vs mid-request distinction }
  if AIdleTimeoutMs = HTTP_TIMEOUT_INFINITE then
    Exit(False);
  Result := AElapsedMs >= AIdleTimeoutMs;
end;

function HttpTimeoutEffectiveConnect(const AClientMs, AConnectMs: Int64): Int64; inline;
begin
  { perf: inline branch single source, zero-copy }
  if AConnectMs > 0 then
    Result := AConnectMs
  else
    Result := AClientMs;
end;

end.
