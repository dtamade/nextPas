program test_bench_xlang;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.scalar,
  nextpas.core.bench.base,
  nextpas.core.bench.xlang,
  nextpas.core.test;

type
  TBenchResult = nextpas.core.bench.base.TBenchResult;
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;

{ === Go Bench Parser Tests === }

procedure Test_ParseGoBenchLine_Basic;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkFoo-8   1000000   1234 ns/op');
  Check(LResult.Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
  Check(LResult.NsPerOp = 1234, 'NsPerOp = 1234');
  Check(LResult.Iterations = 1000000, 'Iterations = 1000000');
end;

procedure Test_ParseGoBenchLine_WithMemory;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkBar-4   500000   2345 ns/op   456 B/op   7 allocs/op');
  Check(LResult.Name = 'BenchmarkBar', 'Name = BenchmarkBar');
  Check(LResult.NsPerOp = 2345, 'NsPerOp = 2345');
  Check(LResult.BytesPerOp = 456, 'BytesPerOp = 456');
  Check(LResult.AllocsPerOp = 7, 'AllocsPerOp = 7');
end;

procedure Test_ParseGoBenchLine_Microseconds;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkBaz-1   100000   1.234 us/op');
  Check(LResult.Name = 'BenchmarkBaz', 'Name = BenchmarkBaz');
  CheckNear(1234, LResult.NsPerOp, 1, 'NsPerOp approx 1234 ns');
end;

procedure Test_ParseGoBenchLine_Milliseconds;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkQux-2   1000   5.678 ms/op');
  Check(LResult.Name = 'BenchmarkQux', 'Name = BenchmarkQux');
  CheckNear(5678000, LResult.NsPerOp, 1, 'NsPerOp approx 5678000 ns');
end;

procedure Test_ParseGoBenchOutput_Multiple;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  LOutput := 'BenchmarkFoo-8   1000000   1234 ns/op' + #10 +
             'BenchmarkBar-4   500000   2345 ns/op   456 B/op' + #10 +
             'BenchmarkBaz-1   100000   1.234 us/op';
  LResults := ParseGoBenchOutput(LOutput);
  Check(Length(LResults) = 3, 'Found 3 benchmarks');
  Check(LResults[0].Name = 'BenchmarkFoo', 'First = BenchmarkFoo');
  Check(LResults[1].Name = 'BenchmarkBar', 'Second = BenchmarkBar');
  Check(LResults[2].Name = 'BenchmarkBaz', 'Third = BenchmarkBaz');
end;

procedure Test_ParseGoBenchOutput_WithComments;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  LOutput := '# This is a comment' + #10 +
             '' + #10 +
             'BenchmarkFoo-8   1000000   1234 ns/op' + #10 +
             '# Another comment' + #10 +
             'BenchmarkBar-4   500000   2345 ns/op';
  LResults := ParseGoBenchOutput(LOutput);
  Check(Length(LResults) = 2, 'Found 2 benchmarks (skipped comments)');
end;

{ === Rust Bench Parser Tests === }

procedure Test_ParseRustBenchLine_Basic;
var
  LResult: TBenchResult;
begin
  LResult := ParseRustBenchLine('BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]');
  Check(LResult.Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
  CheckNear(1256, LResult.NsPerOp, 1, 'NsPerOp approx 1256 ns');
  CheckNear(1279, LResult.P95, 1, 'P95 approx 1279 ns');
end;

procedure Test_ParseRustBenchLine_Nanoseconds;
var
  LResult: TBenchResult;
begin
  LResult := ParseRustBenchLine('BenchmarkBar    time:   [100 ns 105 ns 110 ns]');
  Check(LResult.Name = 'BenchmarkBar', 'Name = BenchmarkBar');
  CheckNear(105, LResult.NsPerOp, 1, 'NsPerOp approx 105 ns');
end;

procedure Test_ParseRustBenchLine_Milliseconds;
var
  LResult: TBenchResult;
begin
  LResult := ParseRustBenchLine('BenchmarkBaz    time:   [1.234 ms 1.256 ms 1.279 ms]');
  Check(LResult.Name = 'BenchmarkBaz', 'Name = BenchmarkBaz');
  CheckNear(1256000, LResult.NsPerOp, 1000, 'NsPerOp approx 1256000 ns');
end;

procedure Test_RustBench_4TokenFormat;
var
  LResult: TBenchResult;
begin
  LResult := ParseRustBenchLine('BenchmarkSort    time:   [1.234 1.256 1.279 us]');
  CheckNear(1256.0, LResult.NsPerOp, 0.1, '4-token mean = 1256 ns');
  Check(LResult.Name = 'BenchmarkSort', '4-token name');
end;

procedure Test_ParseRustBenchOutput_Multiple;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  LOutput := 'BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]' + #10 +
             'BenchmarkBar    time:   [100 ns 105 ns 110 ns]' + #10 +
             'BenchmarkBaz    time:   [1.234 ms 1.256 ms 1.279 ms]';
  LResults := ParseRustBenchOutput(LOutput);
  Check(Length(LResults) = 3, 'Found 3 benchmarks');
  Check(LResults[0].Name = 'BenchmarkFoo', 'First = BenchmarkFoo');
  Check(LResults[1].Name = 'BenchmarkBar', 'Second = BenchmarkBar');
  Check(LResults[2].Name = 'BenchmarkBaz', 'Third = BenchmarkBaz');
end;

{ === FPC Bench Parser Tests === }

procedure Test_ParseFPCBenchLine_Basic;
var
  LResult: TBenchResult;
begin
  LResult := ParseFPCBenchLine('Name=Foo  Iterations=1000  NsPerOp=1234.56');
  Check(LResult.Name = 'Foo', 'Name = Foo');
  CheckNear(1234.56, LResult.NsPerOp, 0.01, 'NsPerOp = 1234.56');
  Check(LResult.Iterations = 1000, 'Iterations = 1000');
end;

procedure Test_ParseFPCBenchLine_Minimal;
var
  LResult: TBenchResult;
begin
  LResult := ParseFPCBenchLine('NsPerOp=100.0  Name=Bar');
  Check(LResult.Name = 'Bar', 'Name = Bar');
  Check(LResult.NsPerOp = 100.0, 'NsPerOp = 100.0');
end;

procedure Test_ParseFPCBenchOutput_Multiple;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  LOutput := 'Name=Foo  Iterations=1000  NsPerOp=1234.56' + #10 +
             'Name=Bar  Iterations=2000  NsPerOp=2345.67' + #10 +
             'Name=Baz  Iterations=500   NsPerOp=3456.78';
  LResults := ParseFPCBenchOutput(LOutput);
  Check(Length(LResults) = 3, 'Found 3 benchmarks');
  Check(LResults[0].Name = 'Foo', 'First = Foo');
  Check(LResults[1].Name = 'Bar', 'Second = Bar');
  Check(LResults[2].Name = 'Baz', 'Third = Baz');
end;

{ === ParseBenchOutput Dispatcher Tests === }

procedure Test_ParseBenchOutput_Go;
var
  LResults: TBenchResultArray;
begin
  LResults := ParseBenchOutput('BenchmarkFoo-8   1000000   1234 ns/op', xlGo);
  Check(Length(LResults) = 1, 'Found 1 benchmark');
  Check(LResults[0].Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
end;

procedure Test_ParseBenchOutput_Rust;
var
  LResults: TBenchResultArray;
begin
  LResults := ParseBenchOutput('BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]', xlRust);
  Check(Length(LResults) = 1, 'Found 1 benchmark');
  Check(LResults[0].Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
end;

procedure Test_ParseBenchOutput_FPC;
var
  LResults: TBenchResultArray;
begin
  LResults := ParseBenchOutput('Name=Foo  NsPerOp=1234.56', xlFPC);
  Check(Length(LResults) = 1, 'Found 1 benchmark');
  Check(LResults[0].Name = 'Foo', 'Name = Foo');
end;

{ === Error Handling Tests === }

procedure Test_ParseGoBenchLine_Invalid;
var
  LSuccess: Boolean;
begin
  LSuccess := False;
  try
    ParseGoBenchLine('Invalid line');
  except
    on E: EParseError do
      LSuccess := True;
  end;
  Check(LSuccess, 'Raises EParseError');
end;

procedure Test_ParseRustBenchLine_Invalid;
var
  LSuccess: Boolean;
begin
  LSuccess := False;
  try
    ParseRustBenchLine('Invalid line');
  except
    on E: EParseError do
      LSuccess := True;
  end;
  Check(LSuccess, 'Raises EParseError');
end;

procedure Test_ParseFPCBenchLine_Invalid;
var
  LSuccess: Boolean;
begin
  LSuccess := False;
  try
    ParseFPCBenchLine('Invalid line');
  except
    on E: EParseError do
      LSuccess := True;
  end;
  Check(LSuccess, 'Raises EParseError');
end;

procedure Test_ParseBenchOutput_Unknown;
var
  LSuccess: Boolean;
  LParser: TXLangParser;
begin
  LSuccess := False;
  try
    LParser := TXLangParser(99);
    ParseBenchOutput('test', LParser);
  except
    on E: EParseError do
      LSuccess := True;
  end;
  Check(LSuccess, 'Raises EParseError for unknown parser');
end;

procedure Test_GetLastParseSkippedCount;
var
  LResults: TBenchResultArray;
  LSkipped: Integer;
begin
  LResults := ParseGoBenchOutput(
    'BenchmarkGood-4   1000   100.0 ns/op' + #10 +
    'BenchmarkBad' + #10 +
    'BenchmarkGood2-4  2000   200.0 ns/op' + #10
  );
  LSkipped := GetLastParseSkippedCount;
  Check(LSkipped = 1, 'Skipped count = 1 (one unparseable benchmark line)');
  Check(Length(LResults) = 2, 'Parsed 2 valid results');
end;

procedure Test_GoBench_LargeOps;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkBig-4   1000000   5.0 ns/op   10000000000 B/op   50 allocs/op');
  Check(LResult.BytesPerOp = 10000000000, 'Large BytesPerOp');
  Check(LResult.AllocsPerOp = 50, 'AllocsPerOp');
end;

procedure Test_GoBench_UsPerOp;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkMicro-1   5000000   1.50 us/op');
  CheckNear(1500.0, LResult.NsPerOp, 1.0, 'us/op conversion');
end;

procedure Test_GoBench_MsPerOp;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkSlow-1   100   25.00 ms/op');
  CheckNear(25000000.0, LResult.NsPerOp, 1.0, 'ms/op conversion');
end;

procedure Test_GoBench_UnicodeMicroSign;
var
  LResult: TBenchResult;
begin
  { GL-01: Go's standard output uses µs/op (Unicode micro sign $B5), not us/op }
  LResult := ParseGoBenchLine('BenchmarkParseJSON-8   50000   24.5µs/op');
  CheckNear(24500.0, LResult.NsPerOp, 1.0, 'µs/op glued format (Unicode)');
  Check(LResult.Name = 'BenchmarkParseJSON', 'µs/op: name preserved');
  Check(LResult.Iterations = 50000, 'µs/op: iterations parsed');

  { Also test space-separated µs/op }
  LResult := ParseGoBenchLine('BenchmarkHTTP-4   10000   1.50 µs/op');
  CheckNear(1500.0, LResult.NsPerOp, 1.0, 'µs/op space-separated (Unicode)');
end;

procedure TestMultipleDashes;
var
  LResult: TBenchResult;
begin
  LResult := ParseGoBenchLine('BenchmarkFoo_Bar-8    1000    1234 ns/op');
  Check(LResult.Name = 'BenchmarkFoo_Bar', 'Foo_Bar-8: name = BenchmarkFoo_Bar (not BenchmarkFoo_Bar-8)');
  Check(LResult.NsPerOp = 1234, 'Foo_Bar-8: NsPerOp = 1234');

  LResult := ParseGoBenchLine('BenchmarkFoo-Bar_Baz-4    500    2000 ns/op');
  Check(LResult.Name = 'BenchmarkFoo-Bar_Baz', 'Foo-Bar_Baz-4: internal dash preserved');
  Check(LResult.NsPerOp = 2000, 'Foo-Bar_Baz-4: NsPerOp = 2000');

  LResult := ParseGoBenchLine('BenchmarkSingleDash-2    100    5000 ns/op');
  Check(LResult.Name = 'BenchmarkSingleDash', 'SingleDash-2: name = BenchmarkSingleDash');
  Check(LResult.NsPerOp = 5000, 'SingleDash-2: NsPerOp = 5000');
end;

{ === CR-17: TotalNs overflow protection === }

procedure Test_ParseGoBenchLine_OverflowSafe;
var
  LResult: TBenchResult;
begin
  { Safe upper bound: 1e9 ns/op * 1000 iters = 1e12 — should succeed }
  LResult := ParseGoBenchLine('BenchmarkSafe-1   1000   1000000000 ns/op');
  Check(LResult.TotalNs > 0, 'Safe TotalNs: > 0');
  Check(LResult.NsPerOp = 1000000000, 'Safe TotalNs: NsPerOp preserved');
end;

procedure Test_ParseGoBenchLine_Overflow;
var
  LResults: TBenchResultArray;
  LSkipped: Integer;
begin
  { Overflow: 9999999999 ns/op * 9999999999 iters would overflow.
    Multi-line parse should skip this line and continue. }
  LResults := ParseGoBenchOutput(
    'BenchmarkOK-1   100   1000 ns/op' + LineEnding +
    'BenchmarkOverflow-1   9999999999   9999999999.0 ns/op' + LineEnding +
    'BenchmarkOK2-1   200   2000 ns/op');
  LSkipped := GetLastParseSkippedCount;
  Check(LSkipped >= 1, 'Overflow line skipped (skipped count >= 1)');
  Check(Length(LResults) >= 2, 'Non-overflow lines parsed successfully');
end;

{ === Empty Input / Newline Tests === }

procedure Test_ParseGoBenchOutput_Empty;
var
  LResults: TBenchResultArray;
  LNoCrash: Boolean;
begin
  LNoCrash := True;
  try
    LResults := ParseGoBenchOutput('');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Go empty input does not raise exception');
  Check(Length(LResults) = 0, 'Go empty input returns empty array');
end;

procedure Test_ParseGoBenchOutput_NewlineOnly;
var
  LResults: TBenchResultArray;
  LNoCrash: Boolean;
begin
  LNoCrash := True;
  try
    LResults := ParseGoBenchOutput(#10);
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Go newline-only input does not raise exception');
  Check(Length(LResults) = 0, 'Go newline-only input returns empty array');
end;

procedure Test_ParseRustBenchOutput_Empty;
var
  LResults: TBenchResultArray;
  LNoCrash: Boolean;
begin
  LNoCrash := True;
  try
    LResults := ParseRustBenchOutput('');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'Rust empty input does not raise exception');
  Check(Length(LResults) = 0, 'Rust empty input returns empty array');
end;

procedure Test_ParseFPCBenchOutput_Empty;
var
  LResults: TBenchResultArray;
  LNoCrash: Boolean;
begin
  LNoCrash := True;
  try
    LResults := ParseFPCBenchOutput('');
  except
    LNoCrash := False;
  end;
  Check(LNoCrash, 'FPC empty input does not raise exception');
  Check(Length(LResults) = 0, 'FPC empty input returns empty array');
end;

{ === Rust Parser mean=0 Validation === }

procedure Test_ParseRustBenchLine_MeanZero;
var
  LSuccess: Boolean;
begin
  LSuccess := False;
  try
    ParseRustBenchLine('BenchmarkBad    time:   [0 ns 0 ns 0 ns]');
  except
    on E: EParseError do
      LSuccess := True;
  end;
  Check(LSuccess, 'Rust bench line with mean=0 raises EParseError');
end;

procedure Test_ParseRustBenchOutput_MeanZeroSkipped;
var
  LResults: TBenchResultArray;
  LSkipped: Integer;
begin
  LResults := ParseRustBenchOutput(
    'BenchmarkGood    time:   [100 ns 105 ns 110 ns]' + #10 +
    'BenchmarkZero    time:   [0 ns 0 ns 0 ns]' + #10 +
    'BenchmarkGood2   time:   [200 ns 205 ns 210 ns]' + #10
  );
  LSkipped := GetLastParseSkippedCount;
  Check(Length(LResults) = 2, 'Rust mean=0 line is excluded from results');
  Check(LSkipped = 1, 'Rust mean=0 line counted as skipped');
  Check(LResults[0].Name = 'BenchmarkGood', 'First valid result preserved');
  Check(LResults[1].Name = 'BenchmarkGood2', 'Second valid result preserved');
end;

{ === CRLF / Mixed Line Endings === }

procedure Test_ParseGoBenchOutput_CRLF;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  { Windows-style CRLF line endings }
  LOutput := 'BenchmarkFoo-8   1000000   1234 ns/op' + #13#10 +
             'BenchmarkBar-4   500000   2345 ns/op' + #13#10;
  LResults := ParseGoBenchOutput(LOutput);
  Check(Length(LResults) = 2, 'CRLF: parsed 2 results');
  Check(LResults[0].Name = 'BenchmarkFoo', 'CRLF: first name correct');
  Check(LResults[1].Name = 'BenchmarkBar', 'CRLF: second name correct');
end;

procedure Test_ParseGoBenchOutput_MixedLineEndings;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  { Mixed CR, LF, CRLF }
  LOutput := 'BenchmarkA-1   100   100 ns/op' + #13 +
             'BenchmarkB-2   200   200 ns/op' + #10 +
             'BenchmarkC-3   300   300 ns/op' + #13#10;
  LResults := ParseGoBenchOutput(LOutput);
  Check(Length(LResults) = 3, 'Mixed line endings: parsed 3 results');
end;

{ === Main === }

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.xlang');

  { Go Bench Parser }
  T.Test('go: parse basic line', @Test_ParseGoBenchLine_Basic);
  T.Test('go: parse line with memory', @Test_ParseGoBenchLine_WithMemory);
  T.Test('go: parse microseconds', @Test_ParseGoBenchLine_Microseconds);
  T.Test('go: parse milliseconds', @Test_ParseGoBenchLine_Milliseconds);
  T.Test('go: parse multiple output', @Test_ParseGoBenchOutput_Multiple);
  T.Test('go: skip comments', @Test_ParseGoBenchOutput_WithComments);
  T.Test('go: large ops values', @Test_GoBench_LargeOps);
  T.Test('go: us/op conversion', @Test_GoBench_UsPerOp);
  T.Test('go: ms/op conversion', @Test_GoBench_MsPerOp);
  T.Test('go: µs/op unicode', @Test_GoBench_UnicodeMicroSign);
  T.Test('go: multiple dashes in name', @TestMultipleDashes);

  { Rust Bench Parser }
  T.Test('rust: parse basic line', @Test_ParseRustBenchLine_Basic);
  T.Test('rust: parse nanoseconds', @Test_ParseRustBenchLine_Nanoseconds);
  T.Test('rust: parse milliseconds', @Test_ParseRustBenchLine_Milliseconds);
  T.Test('rust: 4-token format', @Test_RustBench_4TokenFormat);
  T.Test('rust: parse multiple output', @Test_ParseRustBenchOutput_Multiple);

  { FPC Bench Parser }
  T.Test('fpc: parse basic line', @Test_ParseFPCBenchLine_Basic);
  T.Test('fpc: parse minimal line', @Test_ParseFPCBenchLine_Minimal);
  T.Test('fpc: parse multiple output', @Test_ParseFPCBenchOutput_Multiple);

  { Dispatcher }
  T.Test('dispatch: go', @Test_ParseBenchOutput_Go);
  T.Test('dispatch: rust', @Test_ParseBenchOutput_Rust);
  T.Test('dispatch: fpc', @Test_ParseBenchOutput_FPC);

  { Error Handling }
  T.Test('error: go invalid line', @Test_ParseGoBenchLine_Invalid);
  T.Test('error: rust invalid line', @Test_ParseRustBenchLine_Invalid);
  T.Test('error: fpc invalid line', @Test_ParseFPCBenchLine_Invalid);
  T.Test('error: unknown parser', @Test_ParseBenchOutput_Unknown);
  T.Test('error: skipped count', @Test_GetLastParseSkippedCount);

  { Empty Input }
  T.Test('empty: go empty input', @Test_ParseGoBenchOutput_Empty);
  T.Test('empty: go newline only', @Test_ParseGoBenchOutput_NewlineOnly);
  T.Test('empty: rust empty input', @Test_ParseRustBenchOutput_Empty);
  T.Test('empty: fpc empty input', @Test_ParseFPCBenchOutput_Empty);

  { Rust mean=0 validation }
  T.Test('rust: mean=0 raises error', @Test_ParseRustBenchLine_MeanZero);
  T.Test('rust: mean=0 skipped in output', @Test_ParseRustBenchOutput_MeanZeroSkipped);

  { CRLF / Mixed line endings }
  T.Test('go: CRLF line endings', @Test_ParseGoBenchOutput_CRLF);
  T.Test('go: mixed line endings', @Test_ParseGoBenchOutput_MixedLineEndings);
  T.Test('go: TotalNs overflow safe', @Test_ParseGoBenchLine_OverflowSafe);
  T.Test('go: TotalNs overflow protection', @Test_ParseGoBenchLine_Overflow);

  T.Run;
  T.Summary;
end.
