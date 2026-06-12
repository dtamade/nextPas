program test_snowflake_clock_regression_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.id.snowflake,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

var
  T: TTestRunner;

procedure TestSequenceOverflowWaitsThroughClockRegression;
const
  TEST_EPOCH_MS = Int64(1);
  BASE_MS = UInt64(5000);
  REGRESSION_MS = UInt64(4999);
  ADVANCE_MS = UInt64(5001);
var
  LGen: TSnowflakeGenerator;
  LPrev, LNext: TSnowflakeId;
  LPrevMs, LNextMs: Int64;
  LWorker: UInt16;
  LSeq: UInt16;
  LI: Integer;
begin
  TestClockReset;
  TestThreadReset;
  TestClockSetOverflowRegression(BASE_MS, REGRESSION_MS, ADVANCE_MS);

  LGen.Init(7, TEST_EPOCH_MS);
  LPrev := 0;
  for LI := 1 to 4096 do
    LPrev := LGen.Next;
  LNext := LGen.Next;

  Check(TSnowflakeGenerator.Extract(LPrev, TEST_EPOCH_MS, LPrevMs, LWorker, LSeq),
    'previous snowflake must extract');
  Check(TSnowflakeGenerator.Extract(LNext, TEST_EPOCH_MS, LNextMs, LWorker, LSeq),
    'next snowflake must extract');
  Check(LPrev < LNext, 'sequence overflow must not return a lower snowflake id after clock regression');
  Check(LPrevMs < LNextMs, 'sequence overflow must wait for a timestamp newer than the previous id');
  Check(TestThreadYieldCount > 0, 'sequence overflow path must exercise clock waiting');
  Check(TestClockCallCount > 4096, 'test must exercise overflow realtime reads');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.snowflake.clock_regression_contract');
  T.Run('sequence overflow waits through clock regression', @TestSequenceOverflowWaitsThroughClockRegression);
  T.Summary;
end.
