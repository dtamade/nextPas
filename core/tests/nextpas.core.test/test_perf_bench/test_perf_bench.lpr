{**
 * @desc 性能回归基准 — test 模块关键路径吞吐量
 *
 * 用法：
 *   test_perf_bench
 *   test_perf_bench --save-baseline perf-baseline.json
 *   test_perf_bench --baseline perf-baseline.json --threshold 0.30
 *
 * 阈值：相对基线 NsPerOp 增幅比例（0.30 = +30% 宽松门禁，对标 benchstat 防 flaky）
 *}
program test_perf_bench;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.test.check,
  nextpas.core.test.expect,
  nextpas.core.test.mock,
  nextpas.core.text.conv;

{ === Benchmarks === }

procedure BenchCheckIntEq(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    CheckEqual(42, 42);
end;

procedure BenchCheckStrEq(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    CheckEqual('hello', 'hello');
end;

procedure BenchCheckTrue(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    CheckTrue(True);
end;

procedure BenchExpectInt(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    ExpectInt(42).ToEqualInt(42);
end;

procedure BenchExpectStr(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    Expect('hello').ToEqual('hello');
end;

procedure BenchExpectChain(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    ExpectInt(42).ToBeGreaterThan(0).ToBeLessThan(100);
end;

procedure BenchExpectNegated(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    ExpectInt(42).Not_.ToEqualInt(99);
end;

procedure BenchMockSetup(const ACtx: IBenchContext);
var I: Integer;
    LMock: TMock;
begin
  LMock := TMock.Create;
  try
    LMock.Setup('Add').ReturnsInt(100);
    for I := 0 to 999 do
      LMock.Verify('Add').CalledExactly(0);
  finally
    LMock.Free;
  end;
end;

procedure BenchExpectObjPool(const ACtx: IBenchContext);
var I: Integer;
begin
  for I := 0 to 999 do
    ExpectInt(42).ToEqualInt(42);
end;

{ === Main === }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LSavePath, LBaselinePath: string;
  LThreshold: Double;
  I: Integer;
  LArg: string;
begin
  LSavePath := '';
  LBaselinePath := '';
  { HasRegression: fail when Ratio=current/baseline > threshold.
    Default 1.30 allows +30% slowdown (loose CI gate). }
  LThreshold := 1.30;

  I := 1;
  while I <= ParamCount do
  begin
    LArg := ParamStr(I);
    if (LArg = '--save-baseline') and (I < ParamCount) then
    begin
      Inc(I);
      LSavePath := ParamStr(I);
    end
    else if (LArg = '--baseline') and (I < ParamCount) then
    begin
      Inc(I);
      LBaselinePath := ParamStr(I);
    end
    else if (LArg = '--threshold') and (I < ParamCount) then
    begin
      Inc(I);
      LThreshold := StrToFloat(ParamStr(I));
      { 30 → 1.30 (percent); 1.30 stays ratio; 0.30 → 1.30 (delta) }
      if LThreshold > 5.0 then
        LThreshold := 1.0 + LThreshold / 100.0
      else if LThreshold < 1.0 then
        LThreshold := 1.0 + LThreshold;
    end;
    Inc(I);
  end;

  LSuite := TBenchSuite.Create('test.perf')
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMinSamples(5)

    .Add('CheckEqual<Int>', @BenchCheckIntEq)
    .Add('CheckEqual<Str>', @BenchCheckStrEq)
    .Add('CheckTrue', @BenchCheckTrue)

    .Add('Expect<Int>.ToEqual', @BenchExpectInt)
    .Add('Expect<Str>.ToEqual', @BenchExpectStr)
    .Add('Expect<Int>.chain', @BenchExpectChain)
    .Add('Expect<Int>.negated', @BenchExpectNegated)

    .Add('Mock.Setup+Verify', @BenchMockSetup)
    .Add('Expect<ObjPool>', @BenchExpectObjPool);

  if LBaselinePath <> '' then
  begin
    if not LSuite.TryLoadBaseline(LBaselinePath) then
      WriteLn('WARN: could not load baseline: ', LBaselinePath);
  end;

  LResults := LSuite.Run;

  if LSavePath <> '' then
  begin
    LResults.SaveBaseline(LSavePath);
    WriteLn('Saved baseline: ', LSavePath);
  end;

  if (LBaselinePath <> '') and LResults.HasRegression(LThreshold) then
  begin
    WriteLn('FAIL: performance regression (ratio threshold=',
      FloatToStr(LThreshold), ' = +',
      FloatToStr((LThreshold - 1.0) * 100), '%)');
    Halt(1);
  end;
end.
