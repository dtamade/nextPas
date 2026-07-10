{**
 * @desc Adaptive Warmup 测试套件
 *}
program test_bench_adaptive_warmup;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.time.base;

{ --------------------------------------------------------------------- }
{  TBenchConfig Adaptive Warmup Tests }
{ --------------------------------------------------------------------- }

procedure Test_AdaptiveWarmup_DefaultDisabled;
var
  LConfig: TBenchConfig;
begin
  LConfig := DefaultBenchConfig;
  Check(not LConfig.AdaptiveWarmup, 'AdaptiveWarmup disabled by default');
  Check(Abs(LConfig.WarmupCVThreshold - 0.05) < 0.001, 'CV threshold=0.05');
  Check(LConfig.WarmupMaxIterations = 100, 'max iters=100');
end;

procedure Test_AdaptiveWarmup_SetEnabled;
var
  LConfig: TBenchConfig;
begin
  LConfig := DefaultBenchConfig;
  LConfig.AdaptiveWarmup := True;
  LConfig.WarmupCVThreshold := 0.10;
  LConfig.WarmupMaxIterations := 50;
  Check(LConfig.AdaptiveWarmup, 'AdaptiveWarmup enabled');
  Check(Abs(LConfig.WarmupCVThreshold - 0.10) < 0.001, 'CV threshold=0.10');
  Check(LConfig.WarmupMaxIterations = 50, 'max iters=50');
end;

{ --------------------------------------------------------------------- }
{  TBenchSuite Adaptive Warmup Integration }
{ --------------------------------------------------------------------- }

procedure StableBench(const ACtx: IBenchContext);
var
  LSum: Int64;
  I: Integer;
begin
  LSum := 0;
  for I := 0 to 999 do
    LSum := LSum + I;
end;

procedure Test_Suite_SetAdaptiveWarmup;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResultArray: TBenchResultArray;
begin
  LSuite := TBenchSuite.Create('AdaptiveTest')
    .SetAdaptiveWarmup(True, 0.10, 50)
    .Add('Stable', @StableBench)
    .SetMinSamples(10)
    .SetMinDuration(TDuration.FromMilliseconds(100));

  LResults := LSuite.Run;
  Check(LResults <> nil, 'results not nil');
  Check(LResults.Count = 1, 'count=1');
  LResultArray := LResults.GetAll;
  Check(not LResultArray[0].Skipped, 'not skipped');
  Check(LResultArray[0].NsPerOp > 0, 'NsPerOp > 0');
end;

procedure Test_Suite_FixedWarmupFallback;
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LResultArray: TBenchResultArray;
begin
  LSuite := TBenchSuite.Create('FixedWarmup')
    .SetAdaptiveWarmup(False)
    .SetWarmupIters(3)
    .Add('Stable', @StableBench)
    .SetMinSamples(10)
    .SetMinDuration(TDuration.FromMilliseconds(100));

  LResults := LSuite.Run;
  Check(LResults <> nil, 'results not nil');
  Check(LResults.Count = 1, 'count=1');
  LResultArray := LResults.GetAll;
  Check(not LResultArray[0].Skipped, 'not skipped');
end;

{ --------------------------------------------------------------------- }
{  Main }
{ --------------------------------------------------------------------- }

var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  T := TTestSuite.Create('nextpas.core.bench.adaptive_warmup');

  { Config tests }
  T.Test('Config.DefaultDisabled', @Test_AdaptiveWarmup_DefaultDisabled);
  T.Test('Config.SetEnabled', @Test_AdaptiveWarmup_SetEnabled);

  { Integration tests }
  T.Test('Suite.SetAdaptiveWarmup', @Test_Suite_SetAdaptiveWarmup);
  T.Test('Suite.FixedWarmupFallback', @Test_Suite_FixedWarmupFallback);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
