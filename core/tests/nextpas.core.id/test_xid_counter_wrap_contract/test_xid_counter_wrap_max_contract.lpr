program test_xid_counter_wrap_max_contract;

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

procedure TestCounterWrapAtMaxTimestampFailsFast;
var
  LFirst, LSecond, LThird: TXid;
  LRaised: Boolean;
begin
  TestRandomReset;
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeSeconds(UInt64(High(UInt32)));

  LFirst := TXid.New;
  LSecond := TXid.New;
  Check(LFirst < LSecond, 'XID counter seed must produce ascending ids before max wrap');

  LRaised := False;
  try
    LThird := TXid.New;
    Check(not LThird.IsNil, 'counter wrap at max timestamp must not silently emit an id');
  except
    on E: EOutOfRange do
      LRaised := True;
    on E: Exception do
      Fail('expected EOutOfRange, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'counter wrap at max timestamp must fail fast');
  CheckEqual(Int64(3), Int64(TestClockCallCount), 'max wrap should read realtime once per attempt');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'max wrap must not yield or busy-wait');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.xid.counter_wrap_max_contract');
  T.Run('counter wrap at max timestamp fails fast', @TestCounterWrapAtMaxTimestampFailsFast);
  T.Summary;
end.
