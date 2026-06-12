program test_id_facade_ksuid_xid_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.id;

var
  T: TTestRunner;

procedure TestKsuidHelpersAreAvailableFromFacade;
const
  KSUID_TEST_TIMESTAMP = UInt32(12345);
var
  LId: string;
  LTimestampUnix: UInt64;
begin
  LId := KsuidNew;
  CheckEqual(Int64(KSUID_STRING_LENGTH), Int64(Length(LId)),
    'KSUID_STRING_LENGTH must be available from nextpas.core.id');
  Check(KsuidIsValid(LId), 'KsuidIsValid must accept generated ids from facade');
  Check(not KsuidIsValid(StringOfChar('z', KSUID_STRING_LENGTH)),
    'KsuidIsValid must reject malformed maximum base62 overflow');
  CheckEqual(Int64(0), Int64(KsuidTimestampUnix('not-a-ksuid')),
    'KsuidTimestampUnix must return 0 for malformed input');
  CheckEqual(Int64(1400012345),
    Int64(KsuidTimestampUnix(TKsuid.NewAt(KSUID_TEST_TIMESTAMP).ToString)),
    'KsuidTimestampUnix must extract the Unix timestamp from facade input');
  CheckEqual(Int64(UInt64(1400000000) + UInt64(High(UInt32))),
    Int64(KsuidTimestampUnix(TKsuid.NewAt(High(UInt32)).ToString)),
    'KsuidTimestampUnix must expose the full KSUID Unix timestamp range');

  LTimestampUnix := 42;
  Check(KsuidTryTimestampUnix(TKsuid.NewAt(0).ToString, LTimestampUnix),
    'KsuidTryTimestampUnix returns True for valid KSUID epoch');
  CheckEqual(Int64(1400000000), Int64(LTimestampUnix),
    'KsuidTryTimestampUnix extracts the KSUID Unix epoch');

  LTimestampUnix := 42;
  Check(not KsuidTryTimestampUnix('not-a-ksuid', LTimestampUnix),
    'KsuidTryTimestampUnix returns False for malformed input');
  CheckEqual(Int64(42), Int64(LTimestampUnix),
    'KsuidTryTimestampUnix must not rewrite the output on malformed input');
end;

procedure TestXidHelpersAreAvailableFromFacade;
const
  XID_TEST_TIMESTAMP = UInt32(1700000123);
var
  LXid: TXid;
  LId: string;
  LTimestamp: UInt32;
begin
  LId := XidNew;
  CheckEqual(Int64(XID_STRING_LENGTH), Int64(Length(LId)),
    'XID_STRING_LENGTH must be available from nextpas.core.id');
  Check(XidIsValid(LId), 'XidIsValid must accept generated ids from facade');
  Check(not XidIsValid(StringOfChar('0', XID_STRING_LENGTH - 1) + 'v'),
    'XidIsValid must reject malformed high padding bits');
  CheckEqual(Int64(0), Int64(XidTimestamp('not-an-xid')),
    'XidTimestamp must return 0 for malformed input');

  FillChar(LXid.FBytes, SizeOf(LXid.FBytes), 0);
  LXid.FBytes[0] := Byte((XID_TEST_TIMESTAMP shr 24) and $FF);
  LXid.FBytes[1] := Byte((XID_TEST_TIMESTAMP shr 16) and $FF);
  LXid.FBytes[2] := Byte((XID_TEST_TIMESTAMP shr 8) and $FF);
  LXid.FBytes[3] := Byte(XID_TEST_TIMESTAMP and $FF);
  CheckEqual(Int64(XID_TEST_TIMESTAMP), Int64(XidTimestamp(LXid.ToString)),
    'XidTimestamp must extract the Unix timestamp from facade input');

  LXid := TXid.Nil_;
  LTimestamp := 42;
  Check(XidTryTimestamp(LXid.ToString, LTimestamp),
    'XidTryTimestamp returns True for valid epoch-zero XID');
  CheckEqual(Int64(0), Int64(LTimestamp),
    'XidTryTimestamp extracts epoch-zero timestamp');

  LTimestamp := 42;
  Check(not XidTryTimestamp('not-an-xid', LTimestamp),
    'XidTryTimestamp returns False for malformed input');
  CheckEqual(Int64(42), Int64(LTimestamp),
    'XidTryTimestamp must not rewrite the output on malformed input');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.facade_ksuid_xid_contract');
  T.Run('KSUID helpers are available from facade', @TestKsuidHelpersAreAvailableFromFacade);
  T.Run('XID helpers are available from facade', @TestXidHelpersAreAvailableFromFacade);
  T.Summary;
end.
