program test_timer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.timer,
  nextpas.core.time.ticker,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

{ === TTimer tests === }

procedure TestTimerCreateIdle;
var
  LT: TTimer;
begin
  LT := TTimer.Create;
  Check(not LT.IsArmed, 'Create should be idle');
end;

procedure TestTimerAfterArmed;
var
  LT: TTimer;
begin
  LT := TTimer.After(TDuration.FromMilliseconds(100));
  Check(LT.IsArmed, 'After should be armed');
end;

procedure TestTimerPollIdle;
var
  LT: TTimer;
begin
  LT := TTimer.Create;
  Check(not LT.Poll, 'Poll on idle should return false');
end;

procedure TestTimerPollNotExpired;
var
  LT: TTimer;
begin
  LT := TTimer.After(TDuration.FromMilliseconds(500));
  Check(not LT.Poll, 'Poll on armed-but-not-expired should return false');
  Check(LT.IsArmed, 'should still be armed');
end;

procedure TestTimerPollExpired;
var
  LT: TTimer;
begin
  LT := TTimer.After(TDuration.Zero);
  Check(LT.Poll, 'Poll on expired timer should return true');
end;

procedure TestTimerPollOneShot;
var
  LT: TTimer;
begin
  LT := TTimer.After(TDuration.Zero);
  Check(LT.Poll, 'first Poll should fire');
  Check(not LT.Poll, 'second Poll should return false (one-shot)');
  Check(not LT.IsArmed, 'should be idle after fire');
end;

procedure TestTimerArm;
var
  LT: TTimer;
begin
  LT := TTimer.Create;
  LT.Arm(TDuration.FromMilliseconds(10));
  Check(LT.IsArmed, 'Arm should make it armed');
  platform_thread_sleep_ns(UInt64(20) * 1000000);
  Check(LT.Poll, 'Poll after Arm+sleep should fire');
end;

procedure TestTimerRearm;
var
  LT: TTimer;
begin
  LT := TTimer.After(TDuration.Zero);
  Check(LT.Poll, 'first fire');
  LT.Arm(TDuration.Zero);
  Check(LT.Poll, 're-armed should fire again');
end;

procedure TestTimerCancel;
var
  LT: TTimer;
begin
  LT := TTimer.After(TDuration.Zero);
  LT.Cancel;
  Check(not LT.IsArmed, 'Cancel should disarm');
  Check(not LT.Poll, 'Poll after Cancel should return false');
end;

procedure TestTimerArmAt;
var
  LT: TTimer;
  LD: TDeadline;
begin
  LD := TDeadline.Expired;
  LT := TTimer.Create;
  LT.ArmAt(LD);
  Check(LT.IsArmed, 'ArmAt should arm');
  Check(LT.Poll, 'Poll on expired deadline should fire');
end;

{ === TTicker tests === }

procedure TestTickerEveryRunning;
var
  LTk: TTicker;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(50));
  Check(LTk.IsRunning, 'Every should create running ticker');
end;

procedure TestTickerPollBeforeInterval;
var
  LTk: TTicker;
  LTick: TTick;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(100));
  Check(not LTk.Poll(LTick), 'Poll before interval should return false');
end;

procedure TestTickerPollAfterInterval;
var
  LTk: TTicker;
  LTick: TTick;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(10));
  platform_thread_sleep_ns(UInt64(20) * 1000000);
  Check(LTk.Poll(LTick), 'Poll after interval should return true');
  Check(LTick.LateBy.AsNanoseconds >= 0, 'LateBy should be non-negative');
end;

procedure TestTickerSecondPollFalse;
var
  LTk: TTicker;
  LTick: TTick;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(10));
  platform_thread_sleep_ns(UInt64(20) * 1000000);
  Check(LTk.Poll(LTick), 'first Poll should fire');
  Check(not LTk.Poll(LTick), 'second Poll should return false');
end;

procedure TestTickerStop;
var
  LTk: TTicker;
  LTick: TTick;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(10));
  platform_thread_sleep_ns(UInt64(20) * 1000000);
  LTk.Stop;
  Check(not LTk.IsRunning, 'Stop should stop');
  Check(not LTk.Poll(LTick), 'Poll after Stop should return false');
end;

procedure TestTickerMissed;
var
  LTk: TTicker;
  LTick: TTick;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(5));
  platform_thread_sleep_ns(UInt64(25) * 1000000);
  Check(LTk.Poll(LTick), 'Poll should fire');
  Check(LTick.Missed >= 1, 'should have missed at least 1 tick');
end;

procedure TestTickerNextDeadline;
var
  LTk: TTicker;
  LD: TDeadline;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(50));
  LD := LTk.NextDeadline;
  Check(not LD.IsInfinite, 'running ticker NextDeadline should be finite');
  Check(not LD.IsExpired, 'NextDeadline should be in the future');
end;

procedure TestTickerNextDeadlineStopped;
var
  LTk: TTicker;
  LD: TDeadline;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(50));
  LTk.Stop;
  LD := LTk.NextDeadline;
  Check(LD.IsInfinite, 'stopped ticker NextDeadline should be infinite');
end;

procedure TestTickerGetInterval;
var
  LTk: TTicker;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(42));
  Check(LTk.GetInterval = TDuration.FromMilliseconds(42), 'GetInterval should match');
end;

procedure TestTickerStart;
var
  LTk: TTicker;
  LTick: TTick;
begin
  LTk := TTicker.Every(TDuration.FromMilliseconds(100));
  LTk.Stop;
  LTk.Start(TDuration.FromMilliseconds(10));
  platform_thread_sleep_ns(UInt64(20) * 1000000);
  Check(LTk.Poll(LTick), 'Poll after Start should fire');
  Check(LTk.GetInterval = TDuration.FromMilliseconds(10), 'interval should be updated');
end;

begin
  T := TTestRunner.Create('nextpas.core.time.timer+ticker');
  { TTimer }
  T.Run('Timer.Create returns idle', @TestTimerCreateIdle);
  T.Run('Timer.After creates armed', @TestTimerAfterArmed);
  T.Run('Timer.Poll on idle returns false', @TestTimerPollIdle);
  T.Run('Timer.Poll not expired returns false', @TestTimerPollNotExpired);
  T.Run('Timer.Poll expired returns true', @TestTimerPollExpired);
  T.Run('Timer.Poll one-shot', @TestTimerPollOneShot);
  T.Run('Timer.Arm arms timer', @TestTimerArm);
  T.Run('Timer.Arm re-arms', @TestTimerRearm);
  T.Run('Timer.Cancel disarms', @TestTimerCancel);
  T.Run('Timer.ArmAt with deadline', @TestTimerArmAt);
  { TTicker }
  T.Run('Ticker.Every creates running', @TestTickerEveryRunning);
  T.Run('Ticker.Poll before interval false', @TestTickerPollBeforeInterval);
  T.Run('Ticker.Poll after interval true', @TestTickerPollAfterInterval);
  T.Run('Ticker.Second poll false', @TestTickerSecondPollFalse);
  T.Run('Ticker.Stop stops', @TestTickerStop);
  T.Run('Ticker.Missed ticks', @TestTickerMissed);
  T.Run('Ticker.NextDeadline running', @TestTickerNextDeadline);
  T.Run('Ticker.NextDeadline stopped', @TestTickerNextDeadlineStopped);
  T.Run('Ticker.GetInterval', @TestTickerGetInterval);
  T.Run('Ticker.Start restarts', @TestTickerStart);
  T.Summary;
end.
