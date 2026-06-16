program test_uuid_v7_monotonic_clock_contract;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.id.uuid,
  nextpas.core.id.v7.monotonic,
  nextpas.core.platform.random,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

type
  TUuidV7GeneratorState = record
    LastMs: UInt64;
    RandA: UInt16;
  end;
  PUuidV7GeneratorState = ^TUuidV7GeneratorState;

var
  T: TTestRunner;

procedure ForceGlobalV7GeneratorState(const ALastMs: UInt64; const ARandA: UInt16);
var
  LState: PUuidV7GeneratorState;
begin
  LState := PUuidV7GeneratorState(@GlobalV7Gen);
  LState^.LastMs := ALastMs;
  LState^.RandA := ARandA;
end;

procedure ResetScenario;
begin
  TestClockReset;
  TestThreadReset;
  GlobalV7Gen.Init;
end;

procedure TestRollbackUsesLogicalTimestamp;
var
  LFirst, LSecond: TUuid;
begin
  ResetScenario;
  TestClockSetSequence([2000, 1999]);

  LFirst := GlobalV7Gen.Next;
  LSecond := GlobalV7Gen.Next;

  Check(LFirst < LSecond, 'rollback must preserve strict UUID ordering');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'rollback must not busy-wait');
end;

procedure TestFrozenMsOverflowAdvancesLogicalTimestamp;
var
  LFirst, LSecond: TUuid;
begin
  ResetScenario;
  TestClockSetRealtimeMs(3000);

  LFirst := GlobalV7Gen.Next;
  LSecond := GlobalV7Gen.Next;

  Check(LFirst < LSecond, 'randA overflow must preserve strict UUID ordering');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'randA overflow must not busy-wait');
end;

procedure TestFrozenMaxTimestampRandAOverflowFailsFast;
var
  LRaised: Boolean;
begin
  ResetScenario;
  ForceGlobalV7GeneratorState(UInt64($FFFFFFFFFFFF), UInt16($0FFF));

  LRaised := False;
  try
    GlobalV7Gen.Next;
  except
    on E: EOutOfRange do
      LRaised := True;
    on E: Exception do
      Fail('expected EOutOfRange, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'max timestamp randA overflow must fail fast instead of wrapping timestamp');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.uuid.v7_monotonic_clock_contract');
  T.Run('rollback uses logical timestamp', @TestRollbackUsesLogicalTimestamp);
  T.Run('frozen ms overflow advances logical timestamp', @TestFrozenMsOverflowAdvancesLogicalTimestamp);
  T.Run('frozen max timestamp randA overflow fails fast', @TestFrozenMaxTimestampRandAOverflowFailsFast);
  T.Summary;
end.
