program test_stopwatch;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time.base,
  nextpas.core.stopwatch,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

procedure TestCreateStopped;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.Create;
  Check(not LSw.IsRunning, 'not running');
  CheckEqual(Int64(0), LSw.ElapsedNs, 'zero elapsed');
end;

procedure TestStartNew;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  Check(LSw.IsRunning, 'running');
  platform_thread_sleep_ns(1000000);
  Check(LSw.ElapsedNs > 0, 'elapsed > 0');
end;

procedure TestStartStop;
var
  LSw: TStopwatch;
  LNs: Int64;
begin
  LSw := TStopwatch.Create;
  LSw.Start;
  platform_thread_sleep_ns(5000000);
  LSw.Stop;
  LNs := LSw.ElapsedNs;
  Check(LNs >= 4000000, 'at least 4ms');
  Check(not LSw.IsRunning, 'stopped');
end;

procedure TestAccumulate;
var
  LSw: TStopwatch;
  LNs1, LNs2: Int64;
begin
  LSw := TStopwatch.Create;
  LSw.Start;
  platform_thread_sleep_ns(2000000);
  LSw.Stop;
  LNs1 := LSw.ElapsedNs;
  LSw.Start;
  platform_thread_sleep_ns(2000000);
  LSw.Stop;
  LNs2 := LSw.ElapsedNs;
  Check(LNs2 > LNs1, 'accumulated');
  Check(LNs2 >= 3000000, 'at least 3ms total');
end;

procedure TestReset;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(1000000);
  LSw.Reset;
  CheckEqual(Int64(0), LSw.ElapsedNs, 'zero after reset');
  Check(not LSw.IsRunning, 'not running after reset');
end;

procedure TestRestart;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(5000000);
  LSw.Restart;
  Check(LSw.IsRunning, 'running after restart');
  Check(LSw.ElapsedNs < 2000000, 'near zero after restart');
end;

procedure TestElapsedUnits;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(10000000);
  LSw.Stop;
  Check(LSw.ElapsedMs >= 9, 'ms >= 9');
  Check(LSw.ElapsedUs >= 9000, 'us >= 9000');
  Check(LSw.ElapsedSec >= 0.009, 'sec >= 0.009');
end;

procedure TestElapsedDuration;
var
  LSw: TStopwatch;
  LD: TDuration;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(5000000);
  LSw.Stop;
  LD := LSw.Elapsed;
  Check(LD.AsMilliseconds >= 4, 'duration >= 4ms');
end;

procedure TestLap;
var
  LSw: TStopwatch;
  LL1, LL2: TDuration;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(3000000);
  LL1 := LSw.Lap;
  platform_thread_sleep_ns(3000000);
  LL2 := LSw.Lap;
  Check(LL1.AsNanoseconds > 0, 'lap1 > 0');
  Check(LL2.AsNanoseconds > 0, 'lap2 > 0');
  CheckEqual(Int64(2), Int64(LSw.GetLapCount), '2 laps');
end;

procedure TestLapNotRunning;
var
  LSw: TStopwatch;
  LD: TDuration;
begin
  LSw := TStopwatch.Create;
  LD := LSw.Lap;
  Check(LD.IsZero, 'lap on stopped = zero');
end;

procedure TestGetLaps;
var
  LSw: TStopwatch;
  LLaps: TLapArray;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(1000000);
  LSw.Lap;
  platform_thread_sleep_ns(1000000);
  LSw.Lap;
  platform_thread_sleep_ns(1000000);
  LSw.Lap;
  LLaps := LSw.GetLaps;
  CheckEqual(Int64(3), Int64(Length(LLaps)), '3 laps');
  Check(LLaps[0].AsNanoseconds > 0, 'lap[0] > 0');
  Check(LLaps[2].AsNanoseconds > 0, 'lap[2] > 0');
end;

procedure TestClearLaps;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  LSw.Lap;
  LSw.Lap;
  LSw.ClearLaps;
  CheckEqual(Int64(0), Int64(LSw.GetLapCount), 'cleared');
end;

procedure TestToString;
var
  LSw: TStopwatch;
  LS: string;
begin
  LSw := TStopwatch.StartNew;
  platform_thread_sleep_ns(5000000);
  LSw.Stop;
  LS := LSw.ToString;
  Check(Length(LS) > 0, 'non-empty string');
  Check(Pos('ms', LS) > 0, 'contains ms');
end;

procedure TestScope;
var
  LScope: TStopwatchScope;
begin
  LScope := TStopwatchScope.Create('test_op');
  platform_thread_sleep_ns(3000000);
  LScope.Finish;
  Check(LScope.ElapsedMs >= 2, 'scope >= 2ms');
end;

procedure TestMeasureTime;
var
  LD: TDuration;
  LMs, LNs: Int64;
begin
  LD := MeasureTime(procedure begin platform_thread_sleep_ns(3000000); end);
  Check(LD.AsMilliseconds >= 2, 'measure duration >= 2ms');
  LMs := MeasureTimeMs(procedure begin platform_thread_sleep_ns(3000000); end);
  Check(LMs >= 2, 'measure ms >= 2');
  LNs := MeasureTimeNs(procedure begin platform_thread_sleep_ns(3000000); end);
  Check(LNs >= 2000000, 'measure ns >= 2M');
end;

begin
  T := TTestRunner.Create('nextpas.core.stopwatch');
  T.Run('Create stopped', @TestCreateStopped);
  T.Run('StartNew', @TestStartNew);
  T.Run('Start/Stop', @TestStartStop);
  T.Run('Accumulate', @TestAccumulate);
  T.Run('Reset', @TestReset);
  T.Run('Restart', @TestRestart);
  T.Run('Elapsed units', @TestElapsedUnits);
  T.Run('Elapsed duration', @TestElapsedDuration);
  T.Run('Lap', @TestLap);
  T.Run('Lap not running', @TestLapNotRunning);
  T.Run('GetLaps', @TestGetLaps);
  T.Run('ClearLaps', @TestClearLaps);
  T.Run('ToString', @TestToString);
  T.Run('Scope', @TestScope);
  T.Run('MeasureTime', @TestMeasureTime);
  T.Summary;
end.
