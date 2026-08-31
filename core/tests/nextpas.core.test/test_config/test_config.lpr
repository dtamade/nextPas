{ test_config — TTestConfig, TTestConfigBuilder, TTestCache tests
  =========================================================
  Covers: nextpas.core.test.config }

program test_config;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.test.helpers;

{ ── DefaultConfig tests ────────────────────────────────────────────────────── }

procedure TestDefaultConfigFilter;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual('', LConfig.FilterPattern, 'Default filter should be empty');
end;

procedure TestDefaultConfigTag;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual('', LConfig.TagFilter, 'Default tag should be empty');
end;

procedure TestDefaultConfigTimeout;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(0, LConfig.TimeoutMs, 'Default timeout should be 0');
end;

procedure TestDefaultConfigRetry;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(0, LConfig.RetryCount, 'Default retry should be 0');
end;

procedure TestDefaultConfigWorkers;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(0, LConfig.MaxParallelWorkers, 'Default workers should be 0');
end;

procedure TestDefaultConfigRepeat;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(0, LConfig.RepeatAllCount, 'Default repeat should be 0');
end;

procedure TestDefaultConfigSlowCount;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(5, LConfig.SlowTestCount, 'Default slow count should be 5');
end;

procedure TestDefaultConfigFailFast;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(False, LConfig.FailFast, 'Default fail-fast should be false');
end;

procedure TestDefaultConfigShuffleSeed;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(0, LConfig.ShuffleSeed, 'Default shuffle seed should be 0');
end;

procedure TestDefaultConfigAnsiMode;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  CheckEqual(Ord(amAuto), Ord(LConfig.AnsiMode), 'Default ANSI mode should be auto');
end;

{ ── TTestConfigBuilder tests ───────────────────────────────────────────────── }

procedure TestBuilderFilter;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithFilter('mytest*').Build;
  CheckEqual('mytest*', LConfig.FilterPattern);
end;

procedure TestBuilderTag;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithTag('slow').Build;
  CheckEqual('slow', LConfig.TagFilter);
end;

procedure TestBuilderTimeout;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithTimeout(5000).Build;
  CheckEqual(5000, LConfig.TimeoutMs);
end;

procedure TestBuilderRetry;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithRetry(3).Build;
  CheckEqual(3, LConfig.RetryCount);
end;

procedure TestBuilderWorkers;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithWorkers(4).Build;
  CheckEqual(4, LConfig.MaxParallelWorkers);
end;

procedure TestBuilderRepeat;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithRepeat(10).Build;
  CheckEqual(10, LConfig.RepeatAllCount);
end;

procedure TestBuilderSlowCount;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithSlowCount(20).Build;
  CheckEqual(20, LConfig.SlowTestCount);
end;

procedure TestBuilderShuffle;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithShuffle(42).Build;
  CheckEqual(42, LConfig.ShuffleSeed);
end;

procedure TestBuilderFailFast;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithFailFast(True).Build;
  CheckEqual(True, LConfig.FailFast);
end;

procedure TestBuilderListMode;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithListMode(True).Build;
  CheckEqual(True, LConfig.ListMode);
end;

procedure TestBuilderShortMode;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithShortMode(True).Build;
  CheckEqual(True, LConfig.ShortMode);
end;

procedure TestBuilderProgress;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithProgress(False).Build;
  CheckEqual(False, LConfig.ShowProgress);
end;

procedure TestBuilderMaxFailures;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithMaxFailures(100).Build;
  CheckEqual(100, LConfig.MaxFailures);
end;

procedure TestBuilderJsonOutput;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithJsonOutput(True).Build;
  CheckEqual(True, LConfig.JsonOutput);
end;

procedure TestBuilderVerbose;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithVerbose(True).Build;
  CheckEqual(True, LConfig.VerboseMode);
end;

procedure TestBuilderRunTimeout;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithRunTimeout(60).Build;
  CheckEqual(60, LConfig.RunTimeoutSec);
end;

procedure TestBuilderBench;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithBench(True).Build;
  CheckEqual(True, LConfig.BenchEnabled);
end;

procedure TestBuilderBenchTime;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithBenchTime(2000).Build;
  CheckEqual(2000, LConfig.BenchTimeMs);
end;

procedure TestBuilderBenchMem;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithBenchMem(True).Build;
  CheckEqual(True, LConfig.BenchMem);
end;

procedure TestBuilderCache;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithCache(True).Build;
  CheckEqual(True, LConfig.CacheEnabled);
end;

procedure TestBuilderCacheDir;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create.WithCacheDir('/tmp/cache').Build;
  CheckEqual('/tmp/cache', LConfig.CacheDir);
end;

procedure TestBuilderChaining;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create
    .WithFilter('test*')
    .WithTimeout(1000)
    .WithRetry(2)
    .WithWorkers(4)
    .WithFailFast(True)
    .Build;
  CheckEqual('test*', LConfig.FilterPattern);
  CheckEqual(1000, LConfig.TimeoutMs);
  CheckEqual(2, LConfig.RetryCount);
  CheckEqual(4, LConfig.MaxParallelWorkers);
  CheckEqual(True, LConfig.FailFast);
end;

procedure TestBuilderDefaultsPreserved;
var
  LConfig: TTestConfig;
begin
  { Setting one field should not change others }
  LConfig := TTestConfigBuilder.Create.WithFilter('x').Build;
  CheckEqual('x', LConfig.FilterPattern);
  CheckEqual('', LConfig.TagFilter);
  CheckEqual(0, LConfig.TimeoutMs);
  CheckEqual(0, LConfig.RetryCount);
  CheckEqual(0, LConfig.MaxParallelWorkers);
  CheckEqual(0, LConfig.RepeatAllCount);
  CheckEqual(5, LConfig.SlowTestCount);
  CheckEqual(False, LConfig.FailFast);
end;

{ ── TBufferSink tests ──────────────────────────────────────────────────────── }

procedure TestBufferSinkWriteLn;
var
  LSink: TBufferSink;
begin
  LSink := TBufferSink.Create;
  LSink.WriteLn('hello');
  LSink.WriteLn('world');
  { WriteLn closes the line; GetOutput joins with LineEnding }
  CheckEqual('hello' + LineEnding + 'world', LSink.GetOutput);
  { FIX-C: no interface reference is ever taken on a plain object var, so
    refcounting never frees it — free explicitly. (Do NOT hold it in an
    IOutputSink var and class-cast back: this FPC trunk keeps interface
    pointers at obj+0x30 and hard casts don't adjust, reading garbage.) }
  LSink.Free;
end;

procedure TestBufferSinkWrite;
var
  LSink: TBufferSink;
begin
  LSink := TBufferSink.Create;
  LSink.Write('hello');
  LSink.Write(' ');
  LSink.Write('world');
  CheckEqual('hello world', LSink.GetOutput);
  LSink.Free;
end;

procedure TestBufferSinkClear;
var
  LSink: TBufferSink;
begin
  LSink := TBufferSink.Create;
  LSink.WriteLn('data');
  LSink.Clear;
  CheckEqual('', LSink.GetOutput);
  LSink.Free;
end;

procedure TestBufferSinkEmpty;
var
  LSink: TBufferSink;
begin
  LSink := TBufferSink.Create;
  CheckEqual('', LSink.GetOutput);
  LSink.Free;
end;

{ ── MakeBufferConfig tests ─────────────────────────────────────────────────── }

procedure TestMakeBufferConfig;
var
  LSink: TBufferSink;
  LConfig: TTestConfig;
begin
  LConfig := MakeBufferConfig(LSink);
  Check(LConfig.OutSink <> nil, 'OutSink should not be nil');
  Check(LConfig.ErrSink <> nil, 'ErrSink should not be nil');
  CheckEqual(False, LConfig.ShowProgress);
  { Don't free LSink — it's managed by interface reference counting }
end;

{ ── v8.26: config fingerprint fail-path (replaces B3 identity bulk) ───────── }
{ Data: kind|n  where kind is maxfail|shuffle|retry|workers|timeout
  Asserts builder writes field, and a wrong CheckEqual fails (fail-path). }

procedure TestConfigFingerprintCase(const AC: TTestCase);
var
  LPos: Integer;
  LKind: string;
  N: Integer;
  LCfg: TTestConfig;
begin
  LPos := Pos('|', AC.Data);
  CheckTrue(LPos > 0, 'fingerprint data kind|n');
  LKind := Copy(AC.Data, 1, LPos - 1);
  N := StrToInt(Copy(AC.Data, LPos + 1, MaxInt));
  if LKind = 'maxfail' then
  begin
    LCfg := TTestConfigBuilder.Create.WithMaxFailures(N).Build;
    CheckEqual(N, LCfg.MaxFailures, 'MaxFailures round-trip');
    ExpectFail(procedure
      begin
        CheckEqual(N + 1, LCfg.MaxFailures);
      end, IntToStr(N));
  end
  else if LKind = 'shuffle' then
  begin
    LCfg := TTestConfigBuilder.Create.WithShuffle(N).Build;
    CheckEqual(N, LCfg.ShuffleSeed, 'ShuffleSeed round-trip');
    ExpectFail(procedure
      begin
        CheckEqual(N + 1, LCfg.ShuffleSeed);
      end, IntToStr(N));
  end
  else if LKind = 'retry' then
  begin
    LCfg := TTestConfigBuilder.Create.WithRetry(N).Build;
    CheckEqual(N, LCfg.RetryCount, 'RetryCount round-trip');
    ExpectFail(procedure
      begin
        CheckEqual(N + 1, LCfg.RetryCount);
      end, IntToStr(N));
  end
  else if LKind = 'workers' then
  begin
    LCfg := TTestConfigBuilder.Create.WithWorkers(N).Build;
    CheckEqual(N, LCfg.MaxParallelWorkers, 'MaxParallelWorkers round-trip');
    ExpectFail(procedure
      begin
        CheckEqual(N + 1, LCfg.MaxParallelWorkers);
      end, IntToStr(N));
  end
  else if LKind = 'timeout' then
  begin
    LCfg := TTestConfigBuilder.Create.WithTimeout(UInt64(N)).Build;
    CheckEqual(Int64(N), Int64(LCfg.TimeoutMs), 'TimeoutMs round-trip');
    ExpectFail(procedure
      begin
        CheckEqual(Int64(N + 1), Int64(LCfg.TimeoutMs));
      end, IntToStr(N));
  end
  else
    Fail('unknown fingerprint kind: ' + LKind);
end;

{ ── Main ───────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LCases: specialize TArray<TTestCase>;
  I: Integer;
begin
  WriteLn('=== test_config ===');
  LSuite := TTestSuite.Create('config');

  { DefaultConfig }
  LSuite.Test('DefaultConfig filter',      @TestDefaultConfigFilter);
  LSuite.Test('DefaultConfig tag',         @TestDefaultConfigTag);
  LSuite.Test('DefaultConfig timeout',     @TestDefaultConfigTimeout);
  LSuite.Test('DefaultConfig retry',       @TestDefaultConfigRetry);
  LSuite.Test('DefaultConfig workers',     @TestDefaultConfigWorkers);
  LSuite.Test('DefaultConfig repeat',      @TestDefaultConfigRepeat);
  LSuite.Test('DefaultConfig slow count',  @TestDefaultConfigSlowCount);
  LSuite.Test('DefaultConfig fail-fast',   @TestDefaultConfigFailFast);
  LSuite.Test('DefaultConfig shuffle',     @TestDefaultConfigShuffleSeed);
  LSuite.Test('DefaultConfig ansi',        @TestDefaultConfigAnsiMode);

  { TTestConfigBuilder }
  LSuite.Test('Builder filter',            @TestBuilderFilter);
  LSuite.Test('Builder tag',               @TestBuilderTag);
  LSuite.Test('Builder timeout',           @TestBuilderTimeout);
  LSuite.Test('Builder retry',             @TestBuilderRetry);
  LSuite.Test('Builder workers',           @TestBuilderWorkers);
  LSuite.Test('Builder repeat',            @TestBuilderRepeat);
  LSuite.Test('Builder slow count',        @TestBuilderSlowCount);
  LSuite.Test('Builder shuffle',           @TestBuilderShuffle);
  LSuite.Test('Builder fail-fast',         @TestBuilderFailFast);
  LSuite.Test('Builder list mode',         @TestBuilderListMode);
  LSuite.Test('Builder short mode',        @TestBuilderShortMode);
  LSuite.Test('Builder progress',          @TestBuilderProgress);
  LSuite.Test('Builder max failures',      @TestBuilderMaxFailures);
  LSuite.Test('Builder JSON output',       @TestBuilderJsonOutput);
  LSuite.Test('Builder verbose',           @TestBuilderVerbose);
  LSuite.Test('Builder run timeout',       @TestBuilderRunTimeout);
  LSuite.Test('Builder bench',             @TestBuilderBench);
  LSuite.Test('Builder bench time',        @TestBuilderBenchTime);
  LSuite.Test('Builder bench mem',         @TestBuilderBenchMem);
  LSuite.Test('Builder cache',             @TestBuilderCache);
  LSuite.Test('Builder cache dir',         @TestBuilderCacheDir);
  LSuite.Test('Builder chaining',          @TestBuilderChaining);
  LSuite.Test('Builder defaults preserved', @TestBuilderDefaultsPreserved);

  { TBufferSink }
  LSuite.Test('BufferSink WriteLn',        @TestBufferSinkWriteLn);
  LSuite.Test('BufferSink Write',          @TestBufferSinkWrite);
  LSuite.Test('BufferSink Clear',          @TestBufferSinkClear);
  LSuite.Test('BufferSink empty',          @TestBufferSinkEmpty);

  { MakeBufferConfig }
  LSuite.Test('MakeBufferConfig',          @TestMakeBufferConfig);

  { v8.26: 500 config fingerprint fail-path (replaces identity bulk) }
  SetLength(LCases, 500);
  for I := 0 to High(LCases) do
  begin
    LCases[I].Name := 'cfg-fp-' + IntToStr(I);
    case I mod 5 of
      0: LCases[I].Data := 'maxfail|' + IntToStr(1 + (I mod 40));
      1: LCases[I].Data := 'shuffle|' + IntToStr(1 + (I mod 97));
      2: LCases[I].Data := 'retry|' + IntToStr(I mod 8);
      3: LCases[I].Data := 'workers|' + IntToStr(I mod 16);
    else
      LCases[I].Data := 'timeout|' + IntToStr(10 + (I mod 200));
    end;
  end;
  LSuite.TestTable('config fingerprint fail-path', LCases, @TestConfigFingerprintCase);

  if not LSuite.Run then
  begin
    Finalize(LSuite);
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
  LSuite.Config.OutSink := nil;
  LSuite.Config.ErrSink := nil;
  Finalize(LSuite);
end.
