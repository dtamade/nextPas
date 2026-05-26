program platform_time_clock;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time;

procedure RequireNonZero(const AName: string; const AValue: UInt64);
begin
  if AValue = 0 then
  begin
    WriteLn(AName, '-status=zero');
    Halt(1);
  end;
end;

var
  LStart: UInt64;
  LFinish: UInt64;
  LRealtime: UInt64;
  LResolution: UInt64;

begin
  WriteLn('platform-time-clock=ready');

  LStart := platform_monotonic_ns;
  LFinish := platform_monotonic_ns;
  if LFinish < LStart then
  begin
    WriteLn('platform-time-monotonic-status=went-backward');
    Halt(1);
  end;

  LRealtime := platform_realtime_ns;
  LResolution := platform_monotonic_resolution_ns;
  RequireNonZero('platform-time-monotonic', LFinish);
  RequireNonZero('platform-time-realtime', LRealtime);
  RequireNonZero('platform-time-resolution', LResolution);

  WriteLn('platform-time-monotonic-ns=', LFinish);
  WriteLn('platform-time-realtime-ns=', LRealtime);
  WriteLn('platform-time-resolution-ns=', LResolution);
  WriteLn('platform-time-clock-status=pass');
end.
