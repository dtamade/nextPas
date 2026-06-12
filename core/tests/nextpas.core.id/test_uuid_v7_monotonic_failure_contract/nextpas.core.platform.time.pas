unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

procedure TestClockReset;
procedure TestClockSetRealtimeMs(const AMs: UInt64);
function platform_realtime_ns: UInt64;

implementation

var
  GRealtimeMs: UInt64 = 1000;

procedure TestClockReset;
begin
  GRealtimeMs := 1000;
end;

procedure TestClockSetRealtimeMs(const AMs: UInt64);
begin
  GRealtimeMs := AMs;
end;

function platform_realtime_ns: UInt64;
begin
  Result := GRealtimeMs * 1000000;
end;

end.
