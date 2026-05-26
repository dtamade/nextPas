program test_time;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time,
  nextpas.core.time.base;

var
  T: TTestRunner;

procedure TestDurationZero;
var
  LD: TDuration;
begin
  LD := TDuration.Zero;
  Check(LD.IsZero);
  Check(not LD.IsPositive);
  Check(not LD.IsNegative);
  CheckEqual(Int64(0), LD.AsNanoseconds);
end;

procedure TestDurationFromUnits;
begin
  CheckEqual(Int64(1000), TDuration.FromMicroseconds(1).AsNanoseconds, 'us->ns');
  CheckEqual(Int64(1000000), TDuration.FromMilliseconds(1).AsNanoseconds, 'ms->ns');
  CheckEqual(Int64(1000000000), TDuration.FromSeconds(1).AsNanoseconds, 'sec->ns');
  CheckEqual(Int64(60000000000), TDuration.FromMinutes(1).AsNanoseconds, 'min->ns');
  CheckEqual(Int64(3600000000000), TDuration.FromHours(1).AsNanoseconds, 'hour->ns');
end;

procedure TestDurationArithmetic;
var
  LA, LB, LC: TDuration;
begin
  LA := TDuration.FromSeconds(3);
  LB := TDuration.FromSeconds(2);
  LC := LA + LB;
  CheckEqual(Int64(5000000000), LC.AsNanoseconds, 'add');

  LC := LA - LB;
  CheckEqual(Int64(1000000000), LC.AsNanoseconds, 'sub');

  LC := LA * 4;
  CheckEqual(Int64(12000000000), LC.AsNanoseconds, 'mul');

  LC := LA.DivBy(3);
  CheckEqual(Int64(1000000000), LC.AsNanoseconds, 'div');
end;

procedure TestDurationSaturation;
var
  LD: TDuration;
begin
  LD := TDuration.FromDays(Int64(500) * 365);
  Check(LD = TDuration.MaxValue, 'should saturate to max');

  LD := TDuration.FromDays(Int64(-500) * 365);
  Check(LD = TDuration.MinValue, 'should saturate to min');

  LD := TDuration.MaxValue + TDuration.FromSeconds(1);
  Check(LD = TDuration.MaxValue, 'add overflow saturates');
end;

procedure TestDurationComparison;
var
  LA, LB: TDuration;
begin
  LA := TDuration.FromMilliseconds(100);
  LB := TDuration.FromMilliseconds(200);
  Check(LA < LB);
  Check(LB > LA);
  Check(LA <= LB);
  Check(LB >= LA);
  Check(LA = LA);
  Check(not (LA = LB));
end;

procedure TestDurationNegate;
var
  LD: TDuration;
begin
  LD := TDuration.FromSeconds(5).Negate;
  Check(LD.IsNegative);
  CheckEqual(Int64(-5000000000), LD.AsNanoseconds);

  LD := LD.Abs;
  Check(LD.IsPositive);
  CheckEqual(Int64(5000000000), LD.AsNanoseconds);
end;

procedure TestDurationToString;
begin
  CheckEqual('500ns', TDuration.FromNanoseconds(500).ToString);
  CheckEqual('1.500us', TDuration.FromNanoseconds(1500).ToString);
  CheckEqual('2.500ms', TDuration.FromMicroseconds(2500).ToString);
  CheckEqual('1.000s', TDuration.FromSeconds(1).ToString);
end;

procedure TestInstantNow;
var
  LA, LB: TInstant;
  LD: TDuration;
begin
  LA := TInstant.Now;
  LB := TInstant.Now;
  LD := LB - LA;
  Check(LD.AsNanoseconds >= 0, 'monotonic: B >= A');
end;

procedure TestInstantElapsed;
var
  LI: TInstant;
  LD: TDuration;
begin
  LI := TInstant.Now;
  LD := LI.Elapsed;
  Check(LD.AsNanoseconds >= 0, 'elapsed >= 0');
end;

procedure TestStopwatch;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  Check(LSw.IsRunning);
  LSw.Stop;
  Check(not LSw.IsRunning);
  Check(LSw.Elapsed.AsNanoseconds >= 0);
end;

procedure TestStopwatchAccumulate;
var
  LSw: TStopwatch;
  LE1, LE2: TDuration;
begin
  LSw := TStopwatch.Create;
  LSw.Start;
  LSw.Stop;
  LE1 := LSw.Elapsed;

  LSw.Start;
  LSw.Stop;
  LE2 := LSw.Elapsed;

  Check(LE2 >= LE1, 'accumulated should grow');
end;

procedure TestStopwatchReset;
var
  LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  LSw.Stop;
  LSw.Reset;
  Check(LSw.Elapsed.IsZero, 'reset should zero');
  Check(not LSw.IsRunning);
end;

begin
  T := TTestRunner.Create('nextpas.core.time');
  T.Run('Duration zero', @TestDurationZero);
  T.Run('Duration from units', @TestDurationFromUnits);
  T.Run('Duration arithmetic', @TestDurationArithmetic);
  T.Run('Duration saturation', @TestDurationSaturation);
  T.Run('Duration comparison', @TestDurationComparison);
  T.Run('Duration negate', @TestDurationNegate);
  T.Run('Duration toString', @TestDurationToString);
  T.Run('Instant now', @TestInstantNow);
  T.Run('Instant elapsed', @TestInstantElapsed);
  T.Run('Stopwatch basic', @TestStopwatch);
  T.Run('Stopwatch accumulate', @TestStopwatchAccumulate);
  T.Run('Stopwatch reset', @TestStopwatchReset);
  T.Summary;
end.
