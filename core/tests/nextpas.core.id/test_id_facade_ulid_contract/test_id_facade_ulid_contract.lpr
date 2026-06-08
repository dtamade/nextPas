program test_id_facade_ulid_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.id;

var
  T: TTestRunner;

procedure TestUlidHelpersAreAvailableFromFacade;
const
  TS1 = UInt64(12345678);
  TS2 = UInt64(12345679);
var
  LFirst: TUlidString;
  LSecond: TUlidString;
begin
  LFirst := UlidFromTimestamp(TS1);
  LSecond := UlidFromTimestamp(TS2);
  Check(UlidIsValid(LFirst), 'UlidIsValid must be available from nextpas.core.id');
  CheckEqual(Int64(TS1), Int64(UlidTimestampMs(LFirst)),
    'UlidTimestampMs must be available from nextpas.core.id');
  Check(LFirst < LSecond, 'timestamp-prefixed ULIDs must remain lexically ordered');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.facade_ulid_contract');
  T.Run('ULID helpers are available from facade', @TestUlidHelpersAreAvailableFromFacade);
  T.Summary;
end.
