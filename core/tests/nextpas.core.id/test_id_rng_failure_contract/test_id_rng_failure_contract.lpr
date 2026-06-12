program test_id_rng_failure_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id,
  nextpas.core.id.rng,
  nextpas.core.id.v7.monotonic,
  nextpas.core.platform.random;

var
  T: TTestRunner;

procedure ExpectPublicGeneratorIoError(const AName: string; const AProc: TTestProc);
var
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  GlobalV7Gen.Init;
  TestRandomSetFailure(True);
  LRaised := False;
  try
    AProc;
  except
    on E: EIOError do
    begin
      LRaised := True;
      Check(E.Category = ecIO, AName + ': entropy failure must be categorized as IO');
      Check(Pos('platform_random_bytes', E.Message) > 0,
        AName + ': entropy failure message must name platform_random_bytes');
      Check(Pos('1234', E.Message) > 0,
        AName + ': entropy failure message must include platform random failure code');
    end;
    on E: Exception do
      Fail(AName + ': expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, AName + ': public generator entropy failure must be catchable');
  Check(TestRandomCallCount > 0, AName + ': public generator must reach entropy source');
end;

procedure CallUuidV4EntropyFailure;
begin
  UuidV4;
end;

procedure CallUuidV7EntropyFailure;
begin
  UuidV7;
end;

procedure CallTUuidNewV7AtEntropyFailure;
var
  LUuid: TUuid;
begin
  LUuid := TUuid.NewV7At(1700000000000);
  if LUuid.IsNil then
    Fail('TUuid.NewV7At unexpectedly returned nil UUID');
end;

procedure CallUlidEntropyFailure;
begin
  Ulid;
end;

procedure CallUlidFromTimestampEntropyFailure;
begin
  UlidFromTimestamp(1700000000000);
end;

procedure CallNanoIdEntropyFailure;
begin
  NanoId;
end;

procedure CallNanoIdCustomEntropyFailure;
begin
  NanoIdCustom('abcdef', 10);
end;

procedure CallKsuidNewEntropyFailure;
begin
  KsuidNew;
end;

procedure CallTKsuidNewAtEntropyFailure;
var
  LKsuid: TKsuid;
begin
  LKsuid := TKsuid.NewAt(1);
  if LKsuid.IsNil then
    Fail('TKsuid.NewAt unexpectedly returned nil KSUID');
end;

procedure CallXidNewEntropyFailure;
begin
  XidNew;
end;

procedure CallUuidV7MonotonicEntropyFailure;
begin
  UuidV7Monotonic;
end;

procedure CallUuidV7MonotonicRawEntropyFailure;
var
  LUuid: TUuid;
begin
  LUuid := UuidV7MonotonicRaw;
  if LUuid.IsNil then
    Fail('UuidV7MonotonicRaw unexpectedly returned nil UUID');
end;

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
      Check(Pos('platform_random_bytes', E.Message) > 0,
        'entropy failure message must name platform_random_bytes');
      Check(Pos('1234', E.Message) > 0,
        'entropy failure message must include platform random failure code');
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

procedure TestRefillFailureDoesNotPartiallyWriteDestination;
var
  LWarmup: array[0..4094] of Byte;
  LBuf: array[0..1] of Byte;
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  FillChar(LWarmup, SizeOf(LWarmup), 0);
  IdRngFillBytes(@LWarmup[0], SizeOf(LWarmup));
  CheckEqual(Int64(1), Int64(TestRandomCallCount), 'warmup should consume one cache refill');

  LBuf[0] := $AA;
  LBuf[1] := $BB;
  TestRandomSetFailure(True);
  LRaised := False;
  try
    IdRngFillBytes(@LBuf[0], SizeOf(LBuf));
  except
    on E: EIOError do
      LRaised := True;
    on E: Exception do
      Fail('expected EIOError, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'cross-refill entropy failure must be catchable');
  CheckEqual(Int64($AA), Int64(LBuf[0]), 'failure must not partially write first byte');
  CheckEqual(Int64($BB), Int64(LBuf[1]), 'failure must not write bytes after refill failure');
  CheckEqual(Int64(2), Int64(TestRandomCallCount), 'cross-refill failure should attempt one refill');
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

{$IFDEF CPU64}
procedure TestOversizedRequestFailsBeforeEntropy;
var
  LByte: Byte;
  LRaised: Boolean;
begin
  TestRandomReset;
  IdRngReseed;
  LByte := $A5;
  LRaised := False;
  try
    IdRngFillBytes(@LByte, SizeUInt(High(SizeInt)) + 1);
  except
    on E: EArgumentError do
      LRaised := True;
    on E: Exception do
      Fail('expected EArgumentError, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'oversized request must fail as invalid input');
  CheckEqual(Int64($A5), Int64(LByte), 'oversized request must not write destination');
  CheckEqual(Int64(0), Int64(TestRandomCallCount), 'oversized request must not touch entropy');
end;
{$ENDIF}

procedure TestPublicGeneratorEntropyFailures;
begin
  ExpectPublicGeneratorIoError('UuidV4', @CallUuidV4EntropyFailure);
  ExpectPublicGeneratorIoError('UuidV7', @CallUuidV7EntropyFailure);
  ExpectPublicGeneratorIoError('TUuid.NewV7At', @CallTUuidNewV7AtEntropyFailure);
  ExpectPublicGeneratorIoError('Ulid', @CallUlidEntropyFailure);
  ExpectPublicGeneratorIoError('UlidFromTimestamp', @CallUlidFromTimestampEntropyFailure);
  ExpectPublicGeneratorIoError('NanoId', @CallNanoIdEntropyFailure);
  ExpectPublicGeneratorIoError('NanoIdCustom', @CallNanoIdCustomEntropyFailure);
  ExpectPublicGeneratorIoError('KsuidNew', @CallKsuidNewEntropyFailure);
  ExpectPublicGeneratorIoError('TKsuid.NewAt', @CallTKsuidNewAtEntropyFailure);
  ExpectPublicGeneratorIoError('XidNew', @CallXidNewEntropyFailure);
  ExpectPublicGeneratorIoError('UuidV7Monotonic', @CallUuidV7MonotonicEntropyFailure);
  ExpectPublicGeneratorIoError('UuidV7MonotonicRaw', @CallUuidV7MonotonicRawEntropyFailure);
end;

begin
  T := TTestRunner.Create('nextpas.core.id.rng.failure_contract');
  T.Run('entropy failure raises EIOError and unlocks', @TestEntropyFailureRaisesIoErrorAndUnlocks);
  T.Run('refill failure does not partially write destination', @TestRefillFailureDoesNotPartiallyWriteDestination);
  T.Run('nil nonzero raises EArgumentNil', @TestNilNonZeroRaisesArgumentNil);
  T.Run('nil zero is noop', @TestNilZeroIsNoop);
  {$IFDEF CPU64}
  T.Run('oversized request fails before entropy', @TestOversizedRequestFailsBeforeEntropy);
  {$ENDIF}
  T.Run('public generator entropy failures', @TestPublicGeneratorEntropyFailures);
  T.Summary;
end.
