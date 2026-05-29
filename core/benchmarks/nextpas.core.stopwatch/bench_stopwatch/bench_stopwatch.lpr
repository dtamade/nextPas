program bench_stopwatch;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.stopwatch,
  nextpas.core.stopwatch.tick,
  nextpas.core.stopwatch.tick.unix,
  nextpas.core.stopwatch.tick.x86_64;

const
  ITERS = 1000000;

procedure BenchTickCall(const AName: string; const ATick: ITick);
var
  LI: Integer;
  LStart, LEnd: UInt64;
  LNsPerOp: Double;
begin
  LStart := ATick.Tick;
  for LI := 1 to ITERS do
    ATick.Tick;
  LEnd := ATick.Tick;
  LNsPerOp := ((LEnd - LStart) / ATick.GetResolution) * 1000000000.0 / ITERS;
  WriteLn(Format('  %-30s %8.1f ns/op  (%s, %d Hz)',
    [AName, LNsPerOp,
     BoolToStr(ATick.GetIsMonotonic, 'monotonic', 'non-monotonic'),
     ATick.GetResolution]));
end;

procedure BenchStopwatchOverhead;
var
  LSw: TStopwatch;
  LI: Integer;
  LStart: TInstant;
  LNs: Int64;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
  begin
    LSw := TStopwatch.StartNew;
    LSw.Stop;
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  %-30s %8.1f ns/op',
    ['StartNew+Stop overhead', LNs / Double(ITERS)]));
end;

procedure BenchFpcGetTickCount64;
var
  LI: Integer;
  LStart: TInstant;
  LNs: Int64;
  LDummy: UInt64;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERS do
    LDummy := GetTickCount64;
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  %-30s %8.1f ns/op  (FPC RTL baseline)',
    ['FPC GetTickCount64', LNs / Double(ITERS)]));
end;

begin
  WriteLn('=== nextpas.core.stopwatch 基准 (1M iterations) ===');
  WriteLn;
  WriteLn('  Tick() 调用开销:');
  if nextpas.core.stopwatch.tick.x86_64.IsAvailable then
    BenchTickCall('RDTSC (Hardware)', nextpas.core.stopwatch.tick.x86_64.CreateHWTick);
  BenchTickCall('clock_gettime (HD)', nextpas.core.stopwatch.tick.unix.CreateHDTick);
  BenchTickCall('MakeBestTick', MakeBestTick);
  WriteLn;
  WriteLn('  Stopwatch 开销:');
  BenchStopwatchOverhead;
  BenchFpcGetTickCount64;
  WriteLn;
  WriteLn('  参考 (公开数据):');
  WriteLn('    Go time.Now()              ~20-50 ns/op');
  WriteLn('    Rust Instant::now()        ~20 ns/op');
  WriteLn('    Linux clock_gettime vDSO   ~20-25 ns/op');
  WriteLn;
  WriteLn('Done.');
end.
