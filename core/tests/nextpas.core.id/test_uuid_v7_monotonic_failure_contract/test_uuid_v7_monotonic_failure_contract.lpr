program test_uuid_v7_monotonic_failure_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id.base,
  nextpas.core.id.rng,
  nextpas.core.id.uuid,
  nextpas.core.id.v7.monotonic,
  nextpas.core.platform.random;

var
  T: TTestRunner;

procedure ExpectIoErrorFromMonotonicString;
var
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  GlobalV7Gen.Init;
  TestRandomSetFailure(True);
  LRaised := False;
  try
    UuidV7Monotonic;
  except
    on E: EIOError do
    begin
      LRaised := True;
      Check(E.Category = ecIO, 'entropy failure must be categorized as IO');
    end;
    on E: Exception do
      Fail('expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'monotonic string entropy failure must be catchable');
end;

procedure ExpectIoErrorFromMonotonicRaw;
var
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  GlobalV7Gen.Init;
  TestRandomSetFailure(True);
  LRaised := False;
  try
    UuidV7MonotonicRaw;
  except
    on E: EIOError do
      LRaised := True;
    on E: Exception do
      Fail('expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'monotonic raw entropy failure must be catchable');
end;

procedure TestMonotonicStringUnlocksAfterEntropyFailure;
var
  LId: string;
begin
  ExpectIoErrorFromMonotonicString;
  TestRandomSetFailure(False);
  LId := UuidV7Monotonic;
  CheckEqual(Int64(UUID_LENGTH), Int64(Length(LId)), 'retry after failure returns UUID string');
  Check(TestRandomCallCount > 1, 'retry must reach random source');
end;

procedure TestMonotonicRawUnlocksAfterEntropyFailure;
var
  LUuid: TUuid;
begin
  ExpectIoErrorFromMonotonicRaw;
  TestRandomSetFailure(False);
  LUuid := UuidV7MonotonicRaw;
  CheckEqual(Int64(7), Int64(LUuid.Version), 'retry after failure returns UUIDv7');
  CheckEqual(Int64(2), Int64(LUuid.Variant), 'retry after failure returns RFC variant');
  Check(TestRandomCallCount > 1, 'retry must reach random source');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.uuid.v7_monotonic_failure_contract');
  T.Run('monotonic string unlocks after entropy failure', @TestMonotonicStringUnlocksAfterEntropyFailure);
  T.Run('monotonic raw unlocks after entropy failure', @TestMonotonicRawUnlocksAfterEntropyFailure);
  T.Summary;
end.
