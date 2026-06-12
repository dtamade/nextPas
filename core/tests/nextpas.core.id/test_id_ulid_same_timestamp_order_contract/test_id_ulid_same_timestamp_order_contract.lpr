program test_id_ulid_same_timestamp_order_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.id,
  nextpas.core.id.rng,
  nextpas.core.platform.random;

var
  T: TTestRunner;

procedure TestSameTimestampSortsByRandomTail;
const
  TS = UInt64(12345678);
var
  LHighTail: TUlidString;
  LLowTail: TUlidString;
begin
  TestRandomReset;
  TestRandomSetPattern($FF, $00);
  IdRngReseed;

  LHighTail := UlidFromTimestamp(TS);
  LLowTail := UlidFromTimestamp(TS);

  Check(UlidIsValid(LHighTail), 'high-tail ULID must be valid');
  Check(UlidIsValid(LLowTail), 'low-tail ULID must be valid');
  CheckEqual(Copy(LHighTail, 1, 10), Copy(LLowTail, 1, 10),
    'same timestamp prefix must match');
  Check(LLowTail < LHighTail,
    'same timestamp tail order: lower random tail must sort before higher random tail');
  CheckEqual(Int64(TS), Int64(UlidTimestampMs(LHighTail)),
    'high-tail timestamp roundtrip');
  CheckEqual(Int64(TS), Int64(UlidTimestampMs(LLowTail)),
    'low-tail timestamp roundtrip');
  CheckEqual(Int64(1), Int64(TestRandomCallCount),
    'same timestamp test should consume one rng refill');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.ulid.same_timestamp_order_contract');
  T.Run('same timestamp ULIDs sort by tail order', @TestSameTimestampSortsByRandomTail);
  T.Summary;
end.
