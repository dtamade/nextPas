unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

procedure TestClockReset;
procedure TestClockSetRealtimeSeconds(const ASeconds: UInt64);
function TestClockCallCount: SizeUInt;

function platform_realtime_ns: UInt64;

implementation

var
  GSeconds: UInt64 = 1700000000;
  GCallCount: SizeUInt = 0;

procedure TestClockReset;
begin
  GSeconds := 1700000000;
  GCallCount := 0;
end;

procedure TestClockSetRealtimeSeconds(const ASeconds: UInt64);
begin
  GSeconds := ASeconds;
  GCallCount := 0;
end;

function TestClockCallCount: SizeUInt;
begin
  Result := GCallCount;
end;

function platform_realtime_ns: UInt64;
begin
  Inc(GCallCount);
  Result := GSeconds * 1000000000;
end;

end.
