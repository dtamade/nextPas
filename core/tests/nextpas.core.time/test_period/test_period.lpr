program test_period;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time.period,
  nextpas.core.time.date,
  nextpas.core.time.datetime;

var
  T: TTestRunner;

procedure TestPeriodCreate;
var P: TPeriod;
begin
  P := TPeriod.Create(1, 2, 3);
  CheckEqual(Int64(1), Int64(P.GetYears), 'years');
  CheckEqual(Int64(2), Int64(P.GetMonths), 'months');
  CheckEqual(Int64(3), Int64(P.GetDays), 'days');

  P := TPeriod.OfYears(5);
  CheckEqual(Int64(5), Int64(P.GetYears), 'ofYears');
  CheckEqual(Int64(0), Int64(P.GetMonths), 'ofYears months');

  P := TPeriod.OfMonths(7);
  CheckEqual(Int64(7), Int64(P.GetMonths), 'ofMonths');

  P := TPeriod.OfDays(10);
  CheckEqual(Int64(10), Int64(P.GetDays), 'ofDays');
end;

procedure TestPeriodZero;
var P: TPeriod;
begin
  P := TPeriod.Zero;
  Check(P.IsZero, 'zero is zero');
  CheckEqual(Int64(0), Int64(P.GetYears), 'zero years');
  CheckEqual(Int64(0), Int64(P.GetMonths), 'zero months');
  CheckEqual(Int64(0), Int64(P.GetDays), 'zero days');

  P := TPeriod.Create(1, 0, 0);
  Check(not P.IsZero, 'non-zero');
end;

procedure TestPeriodNegate;
var P, N: TPeriod;
begin
  P := TPeriod.Create(1, 2, 3);
  N := P.Negate;
  CheckEqual(Int64(-1), Int64(N.GetYears), 'neg years');
  CheckEqual(Int64(-2), Int64(N.GetMonths), 'neg months');
  CheckEqual(Int64(-3), Int64(N.GetDays), 'neg days');
end;

procedure TestPeriodArithmetic;
var A, B, C: TPeriod;
begin
  A := TPeriod.Create(1, 2, 3);
  B := TPeriod.Create(4, 5, 6);
  C := A + B;
  CheckEqual(Int64(5), Int64(C.GetYears), 'add years');
  CheckEqual(Int64(7), Int64(C.GetMonths), 'add months');
  CheckEqual(Int64(9), Int64(C.GetDays), 'add days');

  C := B - A;
  CheckEqual(Int64(3), Int64(C.GetYears), 'sub years');
  CheckEqual(Int64(3), Int64(C.GetMonths), 'sub months');
  CheckEqual(Int64(3), Int64(C.GetDays), 'sub days');
end;

procedure TestPeriodISO8601;
var P: TPeriod; ok: Boolean;
begin
  ok := TPeriod.TryParseISO8601('P1Y2M3D', P);
  Check(ok, 'parse P1Y2M3D');
  CheckEqual(Int64(1), Int64(P.GetYears), 'iso years');
  CheckEqual(Int64(2), Int64(P.GetMonths), 'iso months');
  CheckEqual(Int64(3), Int64(P.GetDays), 'iso days');

  ok := TPeriod.TryParseISO8601('P1Y', P);
  Check(ok, 'parse P1Y');
  CheckEqual(Int64(1), Int64(P.GetYears), 'P1Y years');
  CheckEqual(Int64(0), Int64(P.GetMonths), 'P1Y months');

  ok := TPeriod.TryParseISO8601('P6M', P);
  Check(ok, 'parse P6M');
  CheckEqual(Int64(6), Int64(P.GetMonths), 'P6M months');

  ok := TPeriod.TryParseISO8601('P10D', P);
  Check(ok, 'parse P10D');
  CheckEqual(Int64(10), Int64(P.GetDays), 'P10D days');

  ok := TPeriod.TryParseISO8601('P0D', P);
  Check(ok, 'parse P0D');
  Check(P.IsZero, 'P0D is zero');

  // Invalid
  ok := TPeriod.TryParseISO8601('', P);
  Check(not ok, 'empty invalid');
  ok := TPeriod.TryParseISO8601('1Y2M', P);
  Check(not ok, 'no P prefix');
  ok := TPeriod.TryParseISO8601('P', P);
  Check(not ok, 'P alone');
end;

procedure TestPeriodToISO8601;
var P: TPeriod;
begin
  P := TPeriod.Create(1, 2, 3);
  CheckEqual('P1Y2M3D', P.ToISO8601, 'full');

  P := TPeriod.OfYears(2);
  CheckEqual('P2Y', P.ToISO8601, 'years only');

  P := TPeriod.OfMonths(6);
  CheckEqual('P6M', P.ToISO8601, 'months only');

  P := TPeriod.OfDays(15);
  CheckEqual('P15D', P.ToISO8601, 'days only');

  P := TPeriod.Zero;
  CheckEqual('P0D', P.ToISO8601, 'zero');
end;

procedure TestPeriodAddToDate;
var P: TPeriod; D: TDate;
begin
  // Normal addition
  D := TDate.Create(2024, 3, 15);
  P := TPeriod.Create(1, 2, 10);
  D := P.AddTo(D);
  CheckEqual(Int64(2025), Int64(D.GetYear), 'add year');
  CheckEqual(Int64(5), Int64(D.GetMonth), 'add month');
  CheckEqual(Int64(25), Int64(D.GetDay), 'add day');

  // Month-end clamping: Jan 31 + 1M = Feb 29 (2024 leap)
  D := TDate.Create(2024, 1, 31);
  P := TPeriod.OfMonths(1);
  D := P.AddTo(D);
  CheckEqual(Int64(2), Int64(D.GetMonth), 'clamp month');
  CheckEqual(Int64(29), Int64(D.GetDay), 'clamp day leap');

  // Jan 31 + 1M in non-leap = Feb 28
  D := TDate.Create(2023, 1, 31);
  P := TPeriod.OfMonths(1);
  D := P.AddTo(D);
  CheckEqual(Int64(2), Int64(D.GetMonth), 'clamp non-leap month');
  CheckEqual(Int64(28), Int64(D.GetDay), 'clamp non-leap day');

  // Leap day + 1Y = Feb 28 (non-leap)
  D := TDate.Create(2024, 2, 29);
  P := TPeriod.OfYears(1);
  D := P.AddTo(D);
  CheckEqual(Int64(2025), Int64(D.GetYear), 'leap+1y year');
  CheckEqual(Int64(2), Int64(D.GetMonth), 'leap+1y month');
  CheckEqual(Int64(28), Int64(D.GetDay), 'leap+1y day');

  // Negative period
  D := TDate.Create(2024, 3, 15);
  P := TPeriod.Create(0, 0, -20);
  D := P.AddTo(D);
  CheckEqual(Int64(2), Int64(D.GetMonth), 'neg days month');
  CheckEqual(Int64(24), Int64(D.GetDay), 'neg days day');
end;

procedure TestPeriodAddToDateTime;
var P: TPeriod; DT: TNaiveDateTime;
begin
  DT := TNaiveDateTime.Create(2024, 6, 15, 10, 30, 45, 0);
  P := TPeriod.Create(0, 1, 5);
  DT := P.AddTo(DT);
  CheckEqual(Int64(7), Int64(DT.GetDate.GetMonth), 'dt month');
  CheckEqual(Int64(20), Int64(DT.GetDate.GetDay), 'dt day');
  CheckEqual(Int64(10), Int64(DT.GetTime.GetHour), 'dt hour unchanged');
  CheckEqual(Int64(30), Int64(DT.GetTime.GetMinute), 'dt min unchanged');
end;

begin
  T := TTestRunner.Create('nextpas.core.time.period');
  T.Run('Create', @TestPeriodCreate);
  T.Run('Zero', @TestPeriodZero);
  T.Run('Negate', @TestPeriodNegate);
  T.Run('Arithmetic', @TestPeriodArithmetic);
  T.Run('ISO 8601 parse', @TestPeriodISO8601);
  T.Run('ISO 8601 format', @TestPeriodToISO8601);
  T.Run('AddTo date', @TestPeriodAddToDate);
  T.Run('AddTo datetime', @TestPeriodAddToDateTime);
  T.Summary;
end.
