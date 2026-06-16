program test_xid_counter_wrap_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id.xid,
  nextpas.core.platform.random,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

var
  T: TTestRunner;

procedure TestCounterWrapDoesNotRegressOrdering;
var
  LFirst, LSecond, LThird: TXid;
begin
  TestRandomReset;
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeSeconds(1700000000);

  LFirst := TXid.New;
  LSecond := TXid.New;
  LThird := TXid.New;

  Check(LFirst < LSecond, 'XID counter seed must produce ascending ids before wrap');
  Check(LSecond < LThird, 'XID counter wrap must not return a lower id in the same second');
  CheckEqual(Int64(1700000001), Int64(LThird.Timestamp),
    'counter wrap must advance logical timestamp when realtime is frozen');
  CheckEqual(Int64(3), Int64(TestClockCallCount), 'wrap must not wait on realtime progress');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'wrap must not yield or busy-wait');
end;

procedure TestRealtimeAboveXidRangeFailsFast;
var
  LRaised: Boolean;
begin
  TestRandomReset;
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeSeconds(UInt64(High(UInt32)) + 1);

  LRaised := False;
  try
    TXid.New;
  except
    on E: EOutOfRange do
      LRaised := True;
    on E: Exception do
      Fail('expected EOutOfRange, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'XID realtime beyond UInt32 seconds must not truncate');
  CheckEqual(Int64(1), Int64(TestClockCallCount), 'range failure should read realtime once');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'range failure must not yield or busy-wait');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.xid.counter_wrap_contract');
  T.Run('counter wrap preserves ordering', @TestCounterWrapDoesNotRegressOrdering);
  T.Run('realtime above XID range fails fast', @TestRealtimeAboveXidRangeFailsFast);
  T.Summary;
end.
