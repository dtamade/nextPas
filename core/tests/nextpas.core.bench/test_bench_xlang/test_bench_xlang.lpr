program test_bench_xlang;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.bench.base,
  nextpas.core.bench.xlang;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', ATestName);
  end;
end;

{ === Go Bench Parser Tests === }

procedure Test_ParseGoBenchLine_Basic;
var
  LResult: TBenchResult;
begin
  WriteLn('Test_ParseGoBenchLine_Basic:');
  LResult := ParseGoBenchLine('BenchmarkFoo-8   1000000   1234 ns/op');
  Check(LResult.Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
  Check(LResult.NsPerOp = 1234, 'NsPerOp = 1234');
  Check(LResult.Iterations = 1000000, 'Iterations = 1000000');
end;

procedure Test_ParseGoBenchLine_WithMemory;
var
  LResult: TBenchResult;
begin
  WriteLn('Test_ParseGoBenchLine_WithMemory:');
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
  WriteLn('Test_ParseGoBenchLine_Microseconds:');
  LResult := ParseGoBenchLine('BenchmarkBaz-1   100000   1.234 us/op');
  Check(LResult.Name = 'BenchmarkBaz', 'Name = BenchmarkBaz');
  Check(Abs(LResult.NsPerOp - 1234) < 1, 'NsPerOp ≈ 1234 ns');
end;

procedure Test_ParseGoBenchLine_Milliseconds;
var
  LResult: TBenchResult;
begin
  WriteLn('Test_ParseGoBenchLine_Milliseconds:');
  LResult := ParseGoBenchLine('BenchmarkQux-2   1000   5.678 ms/op');
  Check(LResult.Name = 'BenchmarkQux', 'Name = BenchmarkQux');
  Check(Abs(LResult.NsPerOp - 5678000) < 1, 'NsPerOp ≈ 5678000 ns');
end;

procedure Test_ParseGoBenchOutput_Multiple;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  WriteLn('Test_ParseGoBenchOutput_Multiple:');
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
  WriteLn('Test_ParseGoBenchOutput_WithComments:');
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
  WriteLn('Test_ParseRustBenchLine_Basic:');
  LResult := ParseRustBenchLine('BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]');
  Check(LResult.Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
  Check(Abs(LResult.NsPerOp - 1256) < 1, 'NsPerOp ≈ 1256 ns');
  Check(Abs(LResult.P95 - 1279) < 1, 'P95 ≈ 1279 ns');
end;

procedure Test_ParseRustBenchLine_Nanoseconds;
var
  LResult: TBenchResult;
begin
  WriteLn('Test_ParseRustBenchLine_Nanoseconds:');
  LResult := ParseRustBenchLine('BenchmarkBar    time:   [100 ns 105 ns 110 ns]');
  Check(LResult.Name = 'BenchmarkBar', 'Name = BenchmarkBar');
  Check(Abs(LResult.NsPerOp - 105) < 1, 'NsPerOp ≈ 105 ns');
end;

procedure Test_ParseRustBenchLine_Milliseconds;
var
  LResult: TBenchResult;
begin
  WriteLn('Test_ParseRustBenchLine_Milliseconds:');
  LResult := ParseRustBenchLine('BenchmarkBaz    time:   [1.234 ms 1.256 ms 1.279 ms]');
  Check(LResult.Name = 'BenchmarkBaz', 'Name = BenchmarkBaz');
  Check(Abs(LResult.NsPerOp - 1256000) < 1000, 'NsPerOp ≈ 1256000 ns');
end;

procedure Test_ParseRustBenchOutput_Multiple;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  WriteLn('Test_ParseRustBenchOutput_Multiple:');
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
  WriteLn('Test_ParseFPCBenchLine_Basic:');
  LResult := ParseFPCBenchLine('Name=Foo  Iterations=1000  NsPerOp=1234.56');
  Check(LResult.Name = 'Foo', 'Name = Foo');
  Check(Abs(LResult.NsPerOp - 1234.56) < 0.01, 'NsPerOp = 1234.56');
  Check(LResult.Iterations = 1000, 'Iterations = 1000');
end;

procedure Test_ParseFPCBenchLine_Minimal;
var
  LResult: TBenchResult;
begin
  WriteLn('Test_ParseFPCBenchLine_Minimal:');
  LResult := ParseFPCBenchLine('NsPerOp=100.0  Name=Bar');
  Check(LResult.Name = 'Bar', 'Name = Bar');
  Check(LResult.NsPerOp = 100.0, 'NsPerOp = 100.0');
end;

procedure Test_ParseFPCBenchOutput_Multiple;
var
  LResults: TBenchResultArray;
  LOutput: string;
begin
  WriteLn('Test_ParseFPCBenchOutput_Multiple:');
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
  WriteLn('Test_ParseBenchOutput_Go:');
  LResults := ParseBenchOutput('BenchmarkFoo-8   1000000   1234 ns/op', xlGo);
  Check(Length(LResults) = 1, 'Found 1 benchmark');
  Check(LResults[0].Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
end;

procedure Test_ParseBenchOutput_Rust;
var
  LResults: TBenchResultArray;
begin
  WriteLn('Test_ParseBenchOutput_Rust:');
  LResults := ParseBenchOutput('BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]', xlRust);
  Check(Length(LResults) = 1, 'Found 1 benchmark');
  Check(LResults[0].Name = 'BenchmarkFoo', 'Name = BenchmarkFoo');
end;

procedure Test_ParseBenchOutput_FPC;
var
  LResults: TBenchResultArray;
begin
  WriteLn('Test_ParseBenchOutput_FPC:');
  LResults := ParseBenchOutput('Name=Foo  NsPerOp=1234.56', xlFPC);
  Check(Length(LResults) = 1, 'Found 1 benchmark');
  Check(LResults[0].Name = 'Foo', 'Name = Foo');
end;

{ === Error Handling Tests === }

procedure Test_ParseGoBenchLine_Invalid;
var
  LSuccess: Boolean;
begin
  WriteLn('Test_ParseGoBenchLine_Invalid:');
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
  WriteLn('Test_ParseRustBenchLine_Invalid:');
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
  WriteLn('Test_ParseFPCBenchLine_Invalid:');
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
  WriteLn('Test_ParseBenchOutput_Unknown:');
  LSuccess := False;
  try
    // Force an invalid parser value
    LParser := TXLangParser(99);
    ParseBenchOutput('test', LParser);
  except
    on E: EParseError do
      LSuccess := True;
  end;
  Check(LSuccess, 'Raises EParseError for unknown parser');
end;

{ === Run All Tests === }

procedure RunAllTests;
begin
  WriteLn('=== Go Bench Parser Tests ===');
  Test_ParseGoBenchLine_Basic;
  Test_ParseGoBenchLine_WithMemory;
  Test_ParseGoBenchLine_Microseconds;
  Test_ParseGoBenchLine_Milliseconds;
  Test_ParseGoBenchOutput_Multiple;
  Test_ParseGoBenchOutput_WithComments;

  WriteLn('');
  WriteLn('=== Rust Bench Parser Tests ===');
  Test_ParseRustBenchLine_Basic;
  Test_ParseRustBenchLine_Nanoseconds;
  Test_ParseRustBenchLine_Milliseconds;
  Test_ParseRustBenchOutput_Multiple;

  WriteLn('');
  WriteLn('=== FPC Bench Parser Tests ===');
  Test_ParseFPCBenchLine_Basic;
  Test_ParseFPCBenchLine_Minimal;
  Test_ParseFPCBenchOutput_Multiple;

  WriteLn('');
  WriteLn('=== ParseBenchOutput Dispatcher Tests ===');
  Test_ParseBenchOutput_Go;
  Test_ParseBenchOutput_Rust;
  Test_ParseBenchOutput_FPC;

  WriteLn('');
  WriteLn('=== Error Handling Tests ===');
  Test_ParseGoBenchLine_Invalid;
  Test_ParseRustBenchLine_Invalid;
  Test_ParseFPCBenchLine_Invalid;
  Test_ParseBenchOutput_Unknown;
end;

begin
  WriteLn('=== nextpas.core.bench.xlang Test Suite ===');
  WriteLn('');

  RunAllTests;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestsPassed + GTestsFailed);
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
  begin
    WriteLn('');
    WriteLn('*** FAILED ***');
    Halt(1);
  end
  else
  begin
    WriteLn('');
    WriteLn('✓ All tests passed!');
  end;
end.
