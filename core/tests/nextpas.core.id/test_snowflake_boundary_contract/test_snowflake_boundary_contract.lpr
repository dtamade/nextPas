program test_snowflake_boundary_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.id.snowflake,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

var
  T: TTestRunner;

procedure TestFirstIdAtEpochUsesSequenceZero;
const
  TEST_EPOCH_MS = Int64(5000);
var
  LGen: TSnowflakeGenerator;
  LId: TSnowflakeId;
  LTimestampMs: Int64;
  LWorker: UInt16;
  LSeq: UInt16;
begin
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeMs(UInt64(TEST_EPOCH_MS));

  LGen.Init(7, TEST_EPOCH_MS);
  LId := LGen.Next;

  Check(TSnowflakeGenerator.Extract(LId, TEST_EPOCH_MS, LTimestampMs, LWorker, LSeq),
    'first snowflake at epoch must extract');
  CheckEqual(TEST_EPOCH_MS, LTimestampMs, 'first snowflake timestamp mismatch');
  CheckEqual(Int64(7), Int64(LWorker), 'first snowflake worker mismatch');
  CheckEqual(Int64(0), Int64(LSeq), 'first snowflake sequence must start at zero');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'first snowflake at epoch must not yield');
end;

procedure TestDefaultEpochExtractsUnixTimestamp;
const
  TEST_DELTA_MS = Int64(1234);
var
  LGen: TSnowflakeGenerator;
  LId: TSnowflakeId;
  LTimestampMs: Int64;
  LWorker: UInt16;
  LSeq: UInt16;
begin
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeMs(UInt64(SNOWFLAKE_EPOCH_TWITTER + TEST_DELTA_MS));

  LGen.Init(7);
  LId := LGen.Next;

  Check(TSnowflakeGenerator.Extract(LId, 0, LTimestampMs, LWorker, LSeq),
    'default epoch snowflake must extract');
  CheckEqual(SNOWFLAKE_EPOCH_TWITTER + TEST_DELTA_MS, LTimestampMs,
    'default epoch extract must return Unix timestamp');
  CheckEqual(Int64(7), Int64(LWorker), 'default epoch worker mismatch');
  CheckEqual(Int64(0), Int64(LSeq), 'default epoch sequence must start at zero');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'default epoch extraction must not yield');
end;

procedure TestUninitializedGeneratorFailsFast;
var
  LGen: TSnowflakeGenerator;
  LRaised: Boolean;
begin
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeMs(UInt64(SNOWFLAKE_EPOCH_TWITTER + 1234));

  FillChar(LGen, SizeOf(LGen), 0);
  LRaised := False;
  try
    LGen.Next;
  except
    on E: EInvalidOperationError do
      LRaised := True;
    on E: Exception do
      Fail('expected EInvalidOperationError, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, 'uninitialized snowflake generator must fail fast');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'uninitialized snowflake generator must not yield');
end;

procedure TestFutureEpochFailsFast;
var
  LGen: TSnowflakeGenerator;
  LRaised: Boolean;
begin
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeMs(5000);

  LGen.Init(7, 5001);
  LRaised := False;
  try
    LGen.Next;
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;

  Check(LRaised, 'snowflake must reject realtime values before epoch');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'future epoch must fail without wait loop');
end;

procedure TestTimestampDeltaAbove41BitsRejected;
const
  DELTA_ABOVE_41_BITS = UInt64(1) shl 41;
var
  LGen: TSnowflakeGenerator;
  LRaised: Boolean;
begin
  TestClockReset;
  TestThreadReset;
  TestClockSetRealtimeMs(UInt64(SNOWFLAKE_EPOCH_TWITTER) + DELTA_ABOVE_41_BITS);

  LGen.Init(7, SNOWFLAKE_EPOCH_TWITTER);
  LRaised := False;
  try
    LGen.Next;
  except
    on E: EOutOfRange do
      LRaised := True;
  end;

  Check(LRaised, 'snowflake must reject timestamp deltas above 41 bits');
  CheckEqual(Int64(0), Int64(TestThreadYieldCount), 'timestamp overflow must fail without wait loop');
end;

procedure TestExtractRejectsNegativeEpoch;
var
  LTimestampMs: Int64;
  LWorker: UInt16;
  LSeq: UInt16;
begin
  Check(not TSnowflakeGenerator.Extract(0, -1, LTimestampMs, LWorker, LSeq),
    'snowflake extract must reject negative epoch');
end;

procedure TestExtractRejectsTimestampAddOverflow;
const
  TIMESTAMP_SHIFT = 22;
  MAX_TIMESTAMP_DELTA_MS = (Int64(1) shl 41) - 1;
var
  LId: TSnowflakeId;
  LEpochMs: Int64;
  LTimestampMs: Int64;
  LWorker: UInt16;
  LSeq: UInt16;
begin
  LId := TSnowflakeId(MAX_TIMESTAMP_DELTA_MS shl TIMESTAMP_SHIFT);
  LEpochMs := High(Int64) - MAX_TIMESTAMP_DELTA_MS + 1;
  Check(not TSnowflakeGenerator.Extract(LId, LEpochMs, LTimestampMs, LWorker, LSeq),
    'snowflake extract must reject timestamp add overflow');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.snowflake.boundary_contract');
  T.Run('first id at epoch uses sequence zero', @TestFirstIdAtEpochUsesSequenceZero);
  T.Run('default epoch extracts Unix timestamp', @TestDefaultEpochExtractsUnixTimestamp);
  T.Run('uninitialized generator fails fast', @TestUninitializedGeneratorFailsFast);
  T.Run('future epoch fails fast', @TestFutureEpochFailsFast);
  T.Run('timestamp delta above 41 bits is rejected', @TestTimestampDeltaAbove41BitsRejected);
  T.Run('extract rejects negative epoch', @TestExtractRejectsNegativeEpoch);
  T.Run('extract rejects timestamp add overflow', @TestExtractRejectsTimestampAddOverflow);
  T.Summary;
end.
