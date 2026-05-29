program fafafa_core_simd_darwin_link_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.time.cpu,
  nextpas.core.time.tick,
  nextpas.core.time.stopwatch;

var
  LBackend: TSimdBackend;
  LTick: ITick;
  LStopwatch: TStopwatch;
begin
  SchedYield;
  NanoSleep(1);
  LTick := MakeBestTick;
  LBackend := GetActiveBackend;
  if (LBackend = sbScalar) and (LTick.Resolution = 0) then
    Halt(1);
  LStopwatch := TStopwatch.StartNew;
  LStopwatch.Stop;
end.
