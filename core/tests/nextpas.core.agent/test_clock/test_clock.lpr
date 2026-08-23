program test_clock;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.test;

{ IAgentClock 语义（API.md §3 构造入口；SELECTION C8）：
  fake 零睡眠记录 + Advance 推进；真实时钟 NowMs 单调 + 可取消睡眠 }

procedure TestFakeClockBasics;
var
  C: TFakeClock;
  Token: IAsyncCancellationToken;
begin
  C := TFakeClock.Create;
  try
    Check(C.NowMs = 0, 'fake starts at zero');
    Check(C.SleepMs(500, nil), 'fake sleep returns true');
    Check(C.LastSleepRequestMs = 500, 'sleep request recorded');
    Check(C.NowMs = 0, 'virtual time not moved by sleep');
    C.Advance(1200);
    Check(C.VirtualNowMs = 1200, 'advance moves virtual time');
    { 已取消令牌 → SleepMs 返回 False（ERRORS §5 取消语义）}
    Token := CreateCancellationToken;
    Token.Cancel;
    Check(not C.SleepMs(50, Token), 'sleep with cancelled token false');
    Check(C.LastSleepRequestMs = 50, 'cancel path also recorded');
  finally
    C.Free;
  end;
end;

procedure TestFakeClockAsInterface;
var
  Clock: IAgentClock;
begin
  { 门面形态可用：经接口引用驱动 }
  Clock := TFakeClock.Create;
  Check(Clock.SleepMs(10, nil), 'via interface sleep true');
  Check(Clock.NowMs = 0, 'via interface now zero until advance');
end;

procedure TestSystemClockMonotonic;
var
  Clock: IAgentClock;
  A, B: Int64;
begin
  Clock := NewSystemClock;
  A := Clock.NowMs;
  Check(A >= 0, 'now non-negative');
  B := Clock.NowMs;
  Check(B >= A, 'monotonic non-decreasing');
end;

procedure TestSystemClockSleep;
var
  Clock: IAgentClock;
  Token: IAsyncCancellationToken;
  T0: Int64;
begin
  Clock := NewSystemClock;
  Check(Clock.SleepMs(1, nil), 'tiny natural sleep true');
  Token := CreateCancellationToken;
  T0 := Clock.NowMs;
  Check(Clock.SleepMs(30, Token), 'natural sleep fullfills true');
  Check(Clock.NowMs - T0 >= 25, 'elapsed roughly matches request');
  Check(Clock.SleepMs(0, Token), 'zero sleep on live token true');
end;

procedure TestSystemClockCancelInterrupts;
var
  Clock: IAgentClock;
  Token: IAsyncCancellationToken;
begin
  Clock := NewSystemClock;
  Token := CreateCancellationToken;
  { 预取消令牌：长睡立即返回 False，绝不真等 }
  Token.Cancel;
  Check(not Clock.SleepMs(60000, Token), 'pre-cancelled sleep returns false');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.clock');
  T.Test('fake clock basics', @TestFakeClockBasics);
  T.Test('fake clock via interface', @TestFakeClockAsInterface);
  T.Test('system clock monotonic', @TestSystemClockMonotonic);
  T.Test('system clock sleep', @TestSystemClockSleep);
  T.Test('system clock cancel interrupts', @TestSystemClockCancelInterrupts);
  if not T.Run then Halt(1);
end.
