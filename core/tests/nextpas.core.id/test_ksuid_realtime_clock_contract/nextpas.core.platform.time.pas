unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

procedure TestClockSetRealtimeSeconds(const ASeconds: UInt64);
function platform_realtime_ns: UInt64;

implementation

var
  GSeconds: UInt64 = 1400000000;

procedure TestClockSetRealtimeSeconds(const ASeconds: UInt64);
begin
  GSeconds := ASeconds;
end;

function platform_realtime_ns: UInt64;
begin
  Result := GSeconds * 1000000000;
end;

end.
