unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

procedure TestClockReset;
procedure TestClockSetRealtimeMs(const AMs: UInt64);
function TestClockCallCount: SizeUInt;

function platform_realtime_ns: UInt64;

implementation

var
  GMs: UInt64 = 0;
  GCallCount: SizeUInt = 0;

procedure TestClockReset;
begin
  GMs := 0;
  GCallCount := 0;
end;

procedure TestClockSetRealtimeMs(const AMs: UInt64);
begin
  GMs := AMs;
  GCallCount := 0;
end;

function TestClockCallCount: SizeUInt;
begin
  Result := GCallCount;
end;

function platform_realtime_ns: UInt64;
begin
  Inc(GCallCount);
  Result := GMs * 1000000;
end;

end.
