program test_id_facade_ulid_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.id;

var
  T: TTestSuite;

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

procedure TestUlidFromTimestampRejectsOverflowTimestamp;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    UlidFromTimestamp(UInt64($1000000000000));
  except
    on E: EOutOfRange do
      LRaised := True;
    on E: Exception do
      Fail('expected EOutOfRange, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'UlidFromTimestamp overflow timestamp must raise EOutOfRange');
end;

procedure TestUlidTryTimestampDistinguishesEpochZeroFromMalformedInput;
var
  LTimestamp: UInt64;
  LUlid: TUlidString;
begin
  LUlid := UlidFromTimestamp(0);
  LTimestamp := UInt64(42);
  Check(UlidTryTimestampMs(LUlid, LTimestamp),
    'UlidTryTimestampMs returns True for a valid epoch-zero ULID');
  CheckEqual(Int64(0), Int64(LTimestamp),
    'UlidTryTimestampMs extracts epoch-zero timestamp');

  LTimestamp := UInt64(42);
  Check(not UlidTryTimestampMs('not-a-ulid', LTimestamp),
    'UlidTryTimestampMs returns False for malformed input');
  CheckEqual(Int64(42), Int64(LTimestamp),
    'UlidTryTimestampMs must not rewrite the output on malformed input');
end;

begin
  T := TTestSuite.Create('nextpas.core.id.facade_ulid_contract');
  T.Test('ULID helpers are available from facade', @TestUlidHelpersAreAvailableFromFacade);
  T.Test('UlidFromTimestamp rejects overflow timestamp', @TestUlidFromTimestampRejectsOverflowTimestamp);
  T.Test('UlidTryTimestampMs distinguishes epoch zero from malformed input',
    @TestUlidTryTimestampDistinguishesEpochZeroFromMalformedInput);
  if not T.Run then Halt(1);
end.
