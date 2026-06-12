program test_uuid_v7_same_timestamp_order_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.id.uuid,
  nextpas.core.id.rng,
  nextpas.core.platform.random;

var
  T: TTestRunner;

procedure TestSameTimestampSortsByRandomTail;
const
  TS = UInt64(1717200000000);
var
  LHighTail: TUuid;
  LLowTail: TUuid;
begin
  TestRandomReset;
  TestRandomSetPattern($FF, $00);
  IdRngReseed;

  LHighTail := TUuid.NewV7At(TS);
  LLowTail := TUuid.NewV7At(TS);

  CheckEqual(Int64(7), Int64(LHighTail.Version), 'high-tail UUIDv7 version');
  CheckEqual(Int64(7), Int64(LLowTail.Version), 'low-tail UUIDv7 version');
  CheckEqual(Int64(2), Int64(LHighTail.Variant), 'high-tail UUIDv7 variant');
  CheckEqual(Int64(2), Int64(LLowTail.Variant), 'low-tail UUIDv7 variant');
  CheckEqual(Int64(TS), Int64(LHighTail.TimestampMs), 'high-tail timestamp roundtrip');
  CheckEqual(Int64(TS), Int64(LLowTail.TimestampMs), 'low-tail timestamp roundtrip');
  Check(LLowTail < LHighTail,
    'same timestamp UUIDv7 tail order: lower random tail must sort before higher random tail');
  Check(not (LHighTail < LLowTail),
    'ordinary UUIDv7 same timestamp values are tail-ordered, not call-order monotonic');
  CheckEqual(Int64(1), Int64(TestRandomCallCount),
    'same timestamp UUIDv7 test should consume one rng refill');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.uuidv7.same_timestamp_order_contract');
  T.Run('same timestamp UUIDv7 values sort by tail order', @TestSameTimestampSortsByRandomTail);
  T.Summary;
end.
