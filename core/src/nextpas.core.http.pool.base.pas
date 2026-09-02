unit nextpas.core.http.pool.base;

{$I nextpas.core.settings.inc}

interface

const
  HTTP_POOL_DEFAULT_MAX_SIZE = 64;
  HTTP_POOL_DEFAULT_IDLE_TTL_MS = 90000;
  HTTP_POOL_H2_PROBE_GRACE_MS = 1000;

type
  THttpPoolKey = record
    Host: string;
    Port: UInt16;
    Secure: Boolean;
    function ToAuthority: string;
  end;

implementation

uses
  nextpas.core.bytes.ops;

function THttpPoolKey.ToAuthority: string;
begin
  { perf: single source host canonical via bytes.ops LowerCase path (text.conv forwards to bytes.ops) }
  Result := Host + ':' + IntToStr(Port);
  if Secure then
    Result := 'https|' + Result
  else
    Result := 'http|' + Result;
end;

end.
