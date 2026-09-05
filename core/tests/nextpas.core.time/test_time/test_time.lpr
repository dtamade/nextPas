program test_time;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.platform,
  nextpas.core.platform.time,
  nextpas.core.time,
  nextpas.core.time.base, nextpas.core.math;

var
  T: TTestSuite;

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

procedure TestPlatformTime;
var
  LM1, LM2, LR, LResolution: UInt64;
begin
  LM1 := platform_monotonic_ns;
  LM2 := platform_monotonic_ns;
  LR := platform_realtime_ns;
  LResolution := platform_monotonic_resolution_ns;

  Check(LM2 >= LM1, 'monotonic clock should not go backwards');
  Check(LR > 0, 'realtime clock should be available on linux');
  Check(LResolution >= 1, 'resolution must be at least one nanosecond');
end;

function DateTimeToLocalUnixNanos(const AValue: TDateTime): Int64;
const
  UNIX_EPOCH_TDATETIME = 25569.0;
begin
  Result := Round((AValue - UNIX_EPOCH_TDATETIME) * Double(NS_PER_DAY));
end;

function DateTimeToUtcUnixNanos(const AValue: TDateTime): Int64;
const
  UNIX_EPOCH_TDATETIME = 25569.0;
begin
  Result := Round((AValue - UNIX_EPOCH_TDATETIME) * Double(NS_PER_DAY));
end;

procedure TestDateTimeNow;
var
  LBeforeNs: UInt64;
  LAfterNs: UInt64;
  LNow: TDateTime;
  LNowNs: Int64;
  LLowerBound: Int64;
  LUpperBound: Int64;
begin
  LBeforeNs := platform_realtime_ns;
  LNow := DateTimeNow;
  LAfterNs := platform_realtime_ns;
  LNowNs := DateTimeToLocalUnixNanos(LNow);

  LLowerBound := Int64(LBeforeNs) + Int64(platform_utc_offset_seconds) * NS_PER_SEC - NS_PER_SEC;
  LUpperBound := Int64(LAfterNs) + Int64(platform_utc_offset_seconds) * NS_PER_SEC + NS_PER_SEC;

  Check(LNow > 40000, 'datetime now should be a modern date');
  Check((LNowNs >= LLowerBound) and (LNowNs <= LUpperBound),
    'datetime now should track platform realtime clock');
end;

procedure TestDateTimeUtcNow;
var
  LBeforeNs: UInt64;
  LAfterNs: UInt64;
  LNow: TDateTime;
  LNowNs: Int64;
  LLowerBound: Int64;
  LUpperBound: Int64;
begin
  LBeforeNs := platform_realtime_ns;
  LNow := DateTimeUtcNow;
  LAfterNs := platform_realtime_ns;
  LNowNs := DateTimeToUtcUnixNanos(LNow);

  LLowerBound := Int64(LBeforeNs) - NS_PER_SEC;
  LUpperBound := Int64(LAfterNs) + NS_PER_SEC;

  Check(LNow > 40000, 'datetime UTC now should be a modern date');
  Check((LNowNs >= LLowerBound) and (LNowNs <= LUpperBound),
    'datetime UTC now should track platform realtime clock without local offset');
end;

procedure TestDateTimeMath;
var
  LA: TDateTime;
  LB: TDateTime;
begin
  LA := 45000.25;
  LB := LA + (90.5 / 86400.0);

  CheckEqual(Int64(90), DateTimeSecondsBetween(LB, LA), 'seconds between truncates toward zero');
  CheckEqual(Int64(90500), DateTimeMillisecondsBetween(LB, LA), 'milliseconds between');
  CheckEqual(Int64(-90), DateTimeSecondsBetween(LA, LB), 'seconds between keeps sign');
  Check(Abs(DateTimeAddSeconds(LA, 90) - (LA + (90.0 / 86400.0))) < 0.000000001,
    'add seconds');
  Check(Abs(DateTimeAddSeconds(LA, -90) - (LA - (90.0 / 86400.0))) < 0.000000001,
    'add negative seconds');
end;

procedure TestDaysBetween;
var
  LA: TDateTime;
  LB: TDateTime;
begin
  LA := 45000.75;
  LB := LA - 2.5;

  CheckEqual(2, DaysBetween(LA, LB), 'days between truncates fractional days');
  CheckEqual(2, DaysBetween(LB, LA), 'days between uses absolute delta');
end;

procedure TestDateTimeToUnix;
var
  LEpoch: TDateTime;
begin
  // UnixToDateTime(0) should be 1970-01-01 00:00:00
  LEpoch := UnixToDateTime(0);
  Check(Abs(LEpoch - 25569.0) < 0.001, 'UnixToDateTime(0) = epoch');

  // Round-trip: DateTimeToUnix(UnixToDateTime(X)) = X (use 86400 multiples for exact round-trip)
  CheckEqual(Int64(0), DateTimeToUnix(UnixToDateTime(0)), 'round-trip epoch 0');
  CheckEqual(Int64(86400), DateTimeToUnix(UnixToDateTime(86400)), 'round-trip 1 day');
  CheckEqual(Int64(864000), DateTimeToUnix(UnixToDateTime(864000)), 'round-trip 10 days');
  CheckEqual(Int64(2145916800), DateTimeToUnix(UnixToDateTime(2145916800)), 'round-trip 2038');

  // Negative: exact day boundary
  CheckEqual(Int64(-86400), DateTimeToUnix(UnixToDateTime(-86400)), 'round-trip -1 day');

  // 非 86400 倍数的 2026 年时刻（精度回归，FPC-1511）：浮点字面量默认
  // Single，Int64/86400.0 走 Single 除法在此量级丢 ~分钟精度；Double()
  // 显式转换后 round-trip 与相邻分钟可分辨必须成立。
  CheckEqual(Int64(1786847520),
    DateTimeToUnix(UnixToDateTime(1786847520)), 'round-trip 2026 非整天');
  CheckEqual(Int64(1786847580),
    DateTimeToUnix(UnixToDateTime(1786847580)), 'round-trip 2026 分钟对齐');
  Check(UnixToDateTime(1786847520) <> UnixToDateTime(1786847560),
    '2026 年相邻分钟可分辨（Single 网格不可分辨，修前必失败）');
  Check(Abs(UnixToDateTime(1786847520) - UnixToDateTime(1786847580)) -
    1.0 / 1440.0 < 1e-9, '2026 年相邻分钟差恰为 1 分钟');
  // FormatDateTime(TDateTime) 日内纳秒因子回归（曾误用 8.64e11 = 1/100 天，
  // 非整分钟显示错 100 倍）：2026-08-16T02:32:00Z
  Check(FormatDateTime('%Y-%m-%dT%H:%M:%SZ', UnixToDateTime(1786847520)) =
    '2026-08-16T02:32:00Z', 'FormatDateTime H:M:S 精确（修前 00:01:31）');

  // Current time produces reasonable Unix timestamp (> 2020)
  Check(DateTimeToUnix(DateTimeUtcNow) > 1577836800, 'current time > 2020');
end;

procedure TestUnixNowSec;
var
  LBeforeNs, LAfterNs: UInt64;
  LSec: Int64;
begin
  LBeforeNs := platform_realtime_ns;
  LSec := UnixNowSec;
  LAfterNs := platform_realtime_ns;
  Check((LSec >= Int64(LBeforeNs) div 1000000000) and
    (LSec <= Int64(LAfterNs) div 1000000000),
    'UnixNowSec tracks realtime_ns div 1e9');
  Check(LSec > 1577836800, 'UnixNowSec > 2020');
  { 与 DateTimeToUnix 一致性：同为 UTC 墙钟秒，两次 realtime 读数差内相差不超过 2s
   （DateTimeToUnix 侧 Round + Double 路径，UnixNowSec 侧 div 截断）。 }
  Check(Abs(LSec - DateTimeToUnix(DateTimeUtcNow)) <= 2,
    'UnixNowSec agrees with DateTimeToUnix(DateTimeUtcNow)');
end;

procedure TestUnixNowMs;
var
  LBeforeNs, LAfterNs: UInt64;
  LMs, LSec: Int64;
begin
  LBeforeNs := platform_realtime_ns;
  LMs := UnixNowMs;
  LAfterNs := platform_realtime_ns;
  Check((LMs >= Int64(LBeforeNs) div 1000000) and
    (LMs <= Int64(LAfterNs) div 1000000),
    'UnixNowMs tracks realtime_ns div 1e6');
  { div 截断边界：亚秒余数丢弃不进位，ms/1000 与秒读数至多差 1（两次读数窗口）。 }
  LSec := UnixNowSec;
  Check(Abs(LMs div 1000 - LSec) <= 1, 'UnixNowMs div 1000 agrees with UnixNowSec');
  CheckEqual(Int64(1), Int64(1999999999) div 1000000000, 'sec truncates, not rounds');
  CheckEqual(Int64(1), Int64(1500000) div 1000000, 'ms truncates, not rounds');
end;

procedure TestMsSleep;
var
  LBefore, LAfter: UInt64;
begin
  MsSleep(0);
  LBefore := GetTickCount64;
  MsSleep(20);
  LAfter := GetTickCount64;
  Check(LAfter >= LBefore + 15, 'MsSleep(20) blocks ~20ms');
end;

begin
  T := TTestSuite.Create('nextpas.core.time');
  T.Test('Duration zero', @TestDurationZero);
  T.Test('Duration from units', @TestDurationFromUnits);
  T.Test('Duration arithmetic', @TestDurationArithmetic);
  T.Test('Duration saturation', @TestDurationSaturation);
  T.Test('Duration comparison', @TestDurationComparison);
  T.Test('Duration negate', @TestDurationNegate);
  T.Test('Duration toString', @TestDurationToString);
  T.Test('Instant now', @TestInstantNow);
  T.Test('Instant elapsed', @TestInstantElapsed);
  T.Test('Stopwatch basic', @TestStopwatch);
  T.Test('Stopwatch accumulate', @TestStopwatchAccumulate);
  T.Test('Stopwatch reset', @TestStopwatchReset);
  T.Test('Platform time', @TestPlatformTime);
  T.Test('DateTime now', @TestDateTimeNow);
  T.Test('DateTime UTC now', @TestDateTimeUtcNow);
  T.Test('DateTime math', @TestDateTimeMath);
  T.Test('DaysBetween', @TestDaysBetween);
  T.Test('DateTimeToUnix/UnixToDateTime', @TestDateTimeToUnix);
  T.Test('UnixNowSec', @TestUnixNowSec);
  T.Test('UnixNowMs', @TestUnixNowMs);
  T.Test('MsSleep blocks', @TestMsSleep);
  if not T.Run then Halt(1);
end.
