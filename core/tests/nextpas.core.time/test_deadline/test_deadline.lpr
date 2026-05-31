program test_deadline;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.sleep,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

procedure TestAfterPositive;
var
  LD: TDeadline;
begin
  LD := TDeadline.After(TDuration.FromMilliseconds(500));
  Check(not LD.IsExpired, 'future deadline should not be expired');
  Check(not LD.IsInfinite, 'finite deadline should not be infinite');
end;

procedure TestAfterZero;
var
  LD: TDeadline;
begin
  LD := TDeadline.After(TDuration.Zero);
  Check(LD.IsExpired, 'After(0) should be expired');
end;

procedure TestAfterNegative;
var
  LD: TDeadline;
begin
  LD := TDeadline.After(TDuration.FromMilliseconds(-100));
  Check(LD.IsExpired, 'After(negative) should be expired');
end;

procedure TestInfiniteNeverExpires;
var
  LD: TDeadline;
begin
  LD := TDeadline.Infinite;
  Check(LD.IsInfinite, 'should be infinite');
  Check(not LD.IsExpired, 'infinite should never expire');
end;

procedure TestExpiredAlwaysExpired;
var
  LD: TDeadline;
begin
  LD := TDeadline.Expired;
  Check(LD.IsExpired, 'Expired should always be expired');
  Check(not LD.IsInfinite, 'Expired should not be infinite');
end;

procedure TestIsExpiredTransition;
var
  LD: TDeadline;
begin
  LD := TDeadline.After(TDuration.FromMilliseconds(10));
  Check(not LD.IsExpired, 'should not be expired yet');
  platform_thread_sleep_ns(UInt64(20) * 1000000); { sleep 20ms }
  Check(LD.IsExpired, 'should be expired after sleep');
end;

procedure TestTimeUntilFuture;
var
  LD: TDeadline;
  LDur: TDuration;
begin
  LD := TDeadline.After(TDuration.FromMilliseconds(200));
  LDur := LD.TimeUntil;
  Check(LDur.AsNanoseconds > 0, 'TimeUntil for future should be positive');
  Check(LDur.AsMilliseconds <= 200, 'TimeUntil should not exceed original');
end;

procedure TestTimeUntilPast;
var
  LD: TDeadline;
  LDur: TDuration;
begin
  LD := TDeadline.Expired;
  LDur := LD.TimeUntil;
  Check(LDur.AsNanoseconds <= 0, 'TimeUntil for expired should be <= 0');
end;

procedure TestTimeUntilInfinite;
var
  LD: TDeadline;
  LDur: TDuration;
begin
  LD := TDeadline.Infinite;
  LDur := LD.TimeUntil;
  Check(LDur = TDuration.MaxValue, 'TimeUntil for infinite should be MaxValue');
end;

procedure TestRemainingExpired;
var
  LD: TDeadline;
  LDur: TDuration;
begin
  LD := TDeadline.Expired;
  LDur := LD.Remaining;
  Check(LDur.IsZero, 'Remaining for expired should be zero');
end;

procedure TestRemainingFuture;
var
  LD: TDeadline;
  LDur: TDuration;
begin
  LD := TDeadline.After(TDuration.FromMilliseconds(200));
  LDur := LD.Remaining;
  Check(LDur.AsNanoseconds > 0, 'Remaining for future should be positive');
  Check(LDur.AsMilliseconds <= 200, 'Remaining should not exceed original');
end;

procedure TestRemainingInfinite;
var
  LD: TDeadline;
  LDur: TDuration;
begin
  LD := TDeadline.Infinite;
  LDur := LD.Remaining;
  Check(LDur = TDuration.MaxValue, 'Remaining for infinite should be MaxValue');
end;

procedure TestToInstantFinite;
var
  LD: TDeadline;
  LInst: TInstant;
  LOk: Boolean;
begin
  LD := TDeadline.After(TDuration.FromMilliseconds(100));
  LOk := LD.ToInstant(LInst);
  Check(LOk, 'ToInstant should return True for finite');
end;

procedure TestToInstantInfinite;
var
  LD: TDeadline;
  LInst: TInstant;
  LOk: Boolean;
begin
  LD := TDeadline.Infinite;
  LOk := LD.ToInstant(LInst);
  Check(not LOk, 'ToInstant should return False for infinite');
end;

procedure TestMinPicksEarliest;
var
  LA, LB, LResult: TDeadline;
begin
  LA := TDeadline.After(TDuration.FromMilliseconds(100));
  LB := TDeadline.After(TDuration.FromMilliseconds(500));
  LResult := TDeadline.Min(LA, LB);
  { LA should be earlier since it was created first with shorter timeout }
  Check(LResult = LA, 'Min should pick earlier deadline');
end;

procedure TestMinInfiniteLoses;
var
  LA, LB, LResult: TDeadline;
begin
  LA := TDeadline.Infinite;
  LB := TDeadline.After(TDuration.FromMilliseconds(100));
  LResult := TDeadline.Min(LA, LB);
  Check(LResult = LB, 'Min: infinite should lose to finite');

  LResult := TDeadline.Min(LB, LA);
  Check(LResult = LB, 'Min: infinite should lose to finite (reversed)');
end;

procedure TestAtInstant;
var
  LNow: TInstant;
  LD: TDeadline;
  LInst: TInstant;
begin
  LNow := TInstant.Now;
  LD := TDeadline.At(LNow.Add(TDuration.FromMilliseconds(200)));
  Check(not LD.IsExpired, 'At(future) should not be expired');
  Check(LD.ToInstant(LInst), 'ToInstant should succeed');
end;

procedure TestSleepForDurationZero;
var
  LBefore, LAfter: TInstant;
  LElapsed: TDuration;
begin
  LBefore := TInstant.Now;
  TSleep.ForDuration(TDuration.Zero);
  LAfter := TInstant.Now;
  LElapsed := LAfter - LBefore;
  Check(LElapsed.AsMilliseconds < 5, 'ForDuration(0) should return immediately');
end;

procedure TestSleepForDurationPositive;
var
  LBefore, LAfter: TInstant;
  LElapsed: TDuration;
begin
  LBefore := TInstant.Now;
  TSleep.ForDuration(TDuration.FromMilliseconds(20));
  LAfter := TInstant.Now;
  LElapsed := LAfter - LBefore;
  Check(LElapsed.AsMilliseconds >= 15, 'ForDuration(20ms) should sleep at least 15ms');
end;

procedure TestSleepUntilExpired;
var
  LBefore, LAfter: TInstant;
  LElapsed: TDuration;
begin
  LBefore := TInstant.Now;
  TSleep.Until_(TDeadline.Expired);
  LAfter := TInstant.Now;
  LElapsed := LAfter - LBefore;
  Check(LElapsed.AsMilliseconds < 5, 'Until_(Expired) should return immediately');
end;

procedure TestEquality;
var
  LA, LB: TDeadline;
begin
  LA := TDeadline.Infinite;
  LB := TDeadline.Infinite;
  Check(LA = LB, 'two infinites should be equal');

  LA := TDeadline.Expired;
  LB := TDeadline.Expired;
  Check(LA = LB, 'two expired should be equal');
end;

begin
  T := TTestRunner.Create('nextpas.core.time.deadline');
  T.Run('After(positive) creates future', @TestAfterPositive);
  T.Run('After(zero) creates expired', @TestAfterZero);
  T.Run('After(negative) creates expired', @TestAfterNegative);
  T.Run('Infinite never expires', @TestInfiniteNeverExpires);
  T.Run('Expired always expired', @TestExpiredAlwaysExpired);
  T.Run('IsExpired transitions', @TestIsExpiredTransition);
  T.Run('TimeUntil future positive', @TestTimeUntilFuture);
  T.Run('TimeUntil past non-positive', @TestTimeUntilPast);
  T.Run('TimeUntil infinite MaxValue', @TestTimeUntilInfinite);
  T.Run('Remaining expired zero', @TestRemainingExpired);
  T.Run('Remaining future positive', @TestRemainingFuture);
  T.Run('Remaining infinite MaxValue', @TestRemainingInfinite);
  T.Run('ToInstant finite true', @TestToInstantFinite);
  T.Run('ToInstant infinite false', @TestToInstantInfinite);
  T.Run('Min picks earliest', @TestMinPicksEarliest);
  T.Run('Min infinite loses', @TestMinInfiniteLoses);
  T.Run('At(instant)', @TestAtInstant);
  T.Run('Sleep ForDuration(0) immediate', @TestSleepForDurationZero);
  T.Run('Sleep ForDuration(20ms) sleeps', @TestSleepForDurationPositive);
  T.Run('Sleep Until_(Expired) immediate', @TestSleepUntilExpired);
  T.Run('Equality', @TestEquality);
  T.Summary;
end.
