unit nextpas.core.http.timeout.base;

{$I nextpas.core.settings.inc}

interface

const
  HTTP_TIMEOUT_CLIENT_DEFAULT_MS = 30000;
  HTTP_TIMEOUT_CONNECT_DEFAULT_MS = 0;
  HTTP_TIMEOUT_SERVER_READ_DEFAULT_MS = 30000;
  HTTP_TIMEOUT_SERVER_WRITE_DEFAULT_MS = 30000;
  HTTP_TIMEOUT_SERVER_IDLE_DEFAULT_MS = 30000;
  HTTP_TIMEOUT_IDLE_TTL_DEFAULT_MS = 90000;
  HTTP_TIMEOUT_PING_DEFAULT_MS = 5000;
  HTTP_TIMEOUT_INFINITE = 0;

type
  THttpTimeoutPolicy = record
    ClientTimeoutMs: Int64;
    ConnectTimeoutMs: Int64;
    IdleTTLMs: Int64;
    ServerReadMs: Int64;
    ServerWriteMs: Int64;
    ServerIdleMs: Int64;
    class function Default: THttpTimeoutPolicy; static; inline;
    function EffectiveConnectTimeout: Int64; inline;
    function IsIdleTTLEnabled: Boolean; inline;
    function IsServerIdleEnabled: Boolean; inline;
    function IsClientTimeoutInfinite: Boolean; inline;
    function IsServerReadInfinite: Boolean; inline;
  end;

implementation

class function THttpTimeoutPolicy.Default: THttpTimeoutPolicy; static; inline;
begin
  Result.ClientTimeoutMs := HTTP_TIMEOUT_CLIENT_DEFAULT_MS;
  Result.ConnectTimeoutMs := HTTP_TIMEOUT_CONNECT_DEFAULT_MS;
  Result.IdleTTLMs := HTTP_TIMEOUT_IDLE_TTL_DEFAULT_MS;
  Result.ServerReadMs := HTTP_TIMEOUT_SERVER_READ_DEFAULT_MS;
  Result.ServerWriteMs := HTTP_TIMEOUT_SERVER_WRITE_DEFAULT_MS;
  Result.ServerIdleMs := HTTP_TIMEOUT_SERVER_IDLE_DEFAULT_MS;
end;

function THttpTimeoutPolicy.EffectiveConnectTimeout: Int64; inline;
begin
  { perf: inline branch, no alloc, single source connect fallback }
  if ConnectTimeoutMs > 0 then
    Result := ConnectTimeoutMs
  else
    Result := ClientTimeoutMs;
end;

function THttpTimeoutPolicy.IsIdleTTLEnabled: Boolean; inline;
begin
  Result := IdleTTLMs <> HTTP_TIMEOUT_INFINITE;
end;

function THttpTimeoutPolicy.IsServerIdleEnabled: Boolean; inline;
begin
  Result := ServerIdleMs <> HTTP_TIMEOUT_INFINITE;
end;

function THttpTimeoutPolicy.IsClientTimeoutInfinite: Boolean; inline;
begin
  Result := ClientTimeoutMs = HTTP_TIMEOUT_INFINITE;
end;

function THttpTimeoutPolicy.IsServerReadInfinite: Boolean; inline;
begin
  Result := ServerReadMs = HTTP_TIMEOUT_INFINITE;
end;

end.
