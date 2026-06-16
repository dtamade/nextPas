program test_ksuid_realtime_clock_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id.ksuid,
  nextpas.core.platform.time;

var
  T: TTestRunner;

procedure TestRealtimeAtEpochUsesZeroTimestamp;
var
  LKsuid: TKsuid;
begin
  TestClockSetRealtimeSeconds(KSUID_EPOCH);
  LKsuid := TKsuid.New;
  CheckEqual(Int64(0), Int64(LKsuid.Timestamp),
    'realtime at KSUID epoch must use timestamp zero');
  CheckEqual(Int64(KSUID_EPOCH), Int64(LKsuid.TimestampUnix),
    'timestamp unix must roundtrip the KSUID epoch');
end;

procedure TestRealtimeBeforeEpochFailsFast;
var
  LRaised: Boolean;
begin
  TestClockSetRealtimeSeconds(KSUID_EPOCH - 1);
  LRaised := False;
  try
    TKsuid.New;
  except
    on E: EInvalidOperationError do
      LRaised := True;
    on E: Exception do
      Fail('expected EInvalidOperationError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'realtime before KSUID epoch must not wrap into a future timestamp');
end;

procedure TestRealtimeAboveKsuidRangeFailsFast;
const
  KSUID_MAX_UNIX_SECONDS = UInt64(KSUID_EPOCH) + UInt64(High(UInt32));
var
  LRaised: Boolean;
begin
  TestClockSetRealtimeSeconds(KSUID_MAX_UNIX_SECONDS + 1);
  LRaised := False;
  try
    TKsuid.New;
  except
    on E: EOutOfRange do
      LRaised := True;
    on E: Exception do
      Fail('expected EOutOfRange, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'realtime beyond KSUID timestamp range must not truncate');
end;

procedure TestTimestampUnixUsesWideUnixSeconds;
var
  LKsuid: TKsuid;
begin
  LKsuid := TKsuid.NewAt(High(UInt32));
  CheckEqual(Int64(UInt64(KSUID_EPOCH) + UInt64(High(UInt32))),
    Int64(LKsuid.TimestampUnix),
    'TimestampUnix must not wrap the full KSUID timestamp range');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.ksuid.realtime_clock_contract');
  T.Run('realtime at epoch uses zero timestamp', @TestRealtimeAtEpochUsesZeroTimestamp);
  T.Run('realtime before epoch fails fast', @TestRealtimeBeforeEpochFailsFast);
  T.Run('realtime above KSUID range fails fast', @TestRealtimeAboveKsuidRangeFailsFast);
  T.Run('timestamp unix uses wide unix seconds', @TestTimestampUnixUsesWideUnixSeconds);
  T.Summary;
end.
