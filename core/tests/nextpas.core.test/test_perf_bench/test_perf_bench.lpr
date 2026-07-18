{**
 * @desc 性能回归基准 — test 模块关键路径吞吐量
 *
 * 测量：
 *   1. Check* 断言吞吐量（纯开销）
 *   2. IExpectation 流式 API 吞吐量
 *   3. TMock 注册+验证开销
 *   4. 对象池分配/回收速率
 *
 * 用法：
 *   nextpas.core.test.perf_bench --bench
 *   nextpas.core.test.perf_bench --bench --baseline baseline.json
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
  nextpas.core.test.mock;

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
begin
  LSuite := TBenchSuite.Create('test.perf')
    .SetMinDuration(TDuration.FromMilliseconds(500))
    .SetMinSamples(10)

    .Add('CheckEqual<Int>', @BenchCheckIntEq)
    .Add('CheckEqual<Str>', @BenchCheckStrEq)
    .Add('CheckTrue', @BenchCheckTrue)

    .Add('Expect<Int>.ToEqual', @BenchExpectInt)
    .Add('Expect<Str>.ToEqual', @BenchExpectStr)
    .Add('Expect<Int>.chain', @BenchExpectChain)
    .Add('Expect<Int>.negated', @BenchExpectNegated)

    .Add('Mock.Setup+Verify', @BenchMockSetup)
    .Add('Expect<ObjPool>', @BenchExpectObjPool);

  LSuite.Run;
end.
