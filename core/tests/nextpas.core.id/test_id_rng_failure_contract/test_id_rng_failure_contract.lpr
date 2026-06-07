program test_id_rng_failure_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id.rng,
  nextpas.core.platform.random;

var
  T: TTestRunner;

procedure TestEntropyFailureRaisesIoErrorAndUnlocks;
var
  LByte: Byte;
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  TestRandomSetFailure(True);
  LRaised := False;
  LByte := 0;
  try
    IdRngFillBytes(@LByte, 1);
  except
    on E: EIOError do
    begin
      LRaised := True;
      Check(E.Category = ecIO, 'entropy failure must be categorized as IO');
    end;
    on E: Exception do
      Fail('expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'entropy failure must be catchable');

  TestRandomSetFailure(False);
  LByte := 0;
  IdRngFillBytes(@LByte, 1);
  Check(LByte <> 0, 'success after failure proves the rng lock was released');
end;

procedure TestNilNonZeroRaisesArgumentNil;
var
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  LRaised := False;
  try
    IdRngFillBytes(nil, 1);
  except
    on E: EArgumentNil do
      LRaised := True;
    on E: Exception do
      Fail('expected EArgumentNil, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'nil destination with nonzero length must be rejected');
  CheckEqual(Int64(0), Int64(TestRandomCallCount), 'argument validation before entropy call');
end;

procedure TestNilZeroIsNoop;
begin
  TestRandomReset;
  TestRandomSetFailure(True);
  IdRngFillBytes(nil, 0);
  CheckEqual(Int64(0), Int64(TestRandomCallCount), 'zero length does not touch entropy');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.rng.failure_contract');
  T.Run('entropy failure raises EIOError and unlocks', @TestEntropyFailureRaisesIoErrorAndUnlocks);
  T.Run('nil nonzero raises EArgumentNil', @TestNilNonZeroRaisesArgumentNil);
  T.Run('nil zero is noop', @TestNilZeroIsNoop);
  T.Summary;
end.
