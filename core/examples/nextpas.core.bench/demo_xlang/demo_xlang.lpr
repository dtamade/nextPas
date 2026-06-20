program demo_xlang;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils,
  nextpas.core.bench.base,
  nextpas.core.bench.xlang;

var
  LGoOutput: string;
  LRustOutput: string;
  LFPCOutput: string;
  LGoResults: TBenchResultArray;
  LRustResults: TBenchResultArray;
  LFPCResults: TBenchResultArray;
  LResult: TBenchResult;
begin
  WriteLn('=== nextpas.core.bench.xlang Demo ===');
  WriteLn('');

  // Go benchmark output
  LGoOutput :=
    'BenchmarkSort-8     1000000   1234 ns/op' + #10 +
    'BenchmarkHash-4      500000   2345 ns/op   456 B/op   7 allocs/op' + #10 +
    'BenchmarkParse-1     200000   5678 ns/op';

  // Rust benchmark output
  LRustOutput :=
    'sort    time:   [1.200 us 1.234 us 1.270 us]' + #10 +
    'hash    time:   [2.300 us 2.345 us 2.400 us]' + #10 +
    'parse   time:   [5.600 us 5.678 us 5.800 us]';

  // FPC benchmark output
  LFPCOutput :=
    'Name=Sort  Iterations=1000000  NsPerOp=1234.56' + #10 +
    'Name=Hash  Iterations=500000   NsPerOp=2345.67' + #10 +
    'Name=Parse Iterations=200000   NsPerOp=5678.90';

  // Parse outputs
  WriteLn('Parsing Go benchmarks...');
  LGoResults := ParseGoBenchOutput(LGoOutput);
  WriteLn('  Found ', Length(LGoResults), ' benchmarks');

  WriteLn('Parsing Rust benchmarks...');
  LRustResults := ParseRustBenchOutput(LRustOutput);
  WriteLn('  Found ', Length(LRustResults), ' benchmarks');

  WriteLn('Parsing FPC benchmarks...');
  LFPCResults := ParseFPCBenchOutput(LFPCOutput);
  WriteLn('  Found ', Length(LFPCResults), ' benchmarks');

  WriteLn('');
  WriteLn('=== Cross-Language Comparison ===');
  WriteLn('');

  // Compare Sort benchmark
  WriteLn('Sort Benchmark:');
  if Length(LGoResults) > 0 then
  begin
    LResult := LGoResults[0];
    WriteLn('  Go:   ', LResult.NsPerOp:0:2, ' ns/op');
  end;
  if Length(LRustResults) > 0 then
  begin
    LResult := LRustResults[0];
    WriteLn('  Rust: ', LResult.NsPerOp:0:2, ' ns/op');
  end;
  if Length(LFPCResults) > 0 then
  begin
    LResult := LFPCResults[0];
    WriteLn('  FPC:  ', LResult.NsPerOp:0:2, ' ns/op');
  end;

  WriteLn('');
  WriteLn('Hash Benchmark:');
  if Length(LGoResults) > 1 then
  begin
    LResult := LGoResults[1];
    WriteLn('  Go:   ', LResult.NsPerOp:0:2, ' ns/op, ',
            LResult.BytesPerOp, ' B/op, ',
            LResult.AllocsPerOp, ' allocs/op');
  end;
  if Length(LRustResults) > 1 then
  begin
    LResult := LRustResults[1];
    WriteLn('  Rust: ', LResult.NsPerOp:0:2, ' ns/op');
  end;
  if Length(LFPCResults) > 1 then
  begin
    LResult := LFPCResults[1];
    WriteLn('  FPC:  ', LResult.NsPerOp:0:2, ' ns/op');
  end;

  WriteLn('');
  WriteLn('Parse Benchmark:');
  if Length(LGoResults) > 2 then
  begin
    LResult := LGoResults[2];
    WriteLn('  Go:   ', LResult.NsPerOp:0:2, ' ns/op');
  end;
  if Length(LRustResults) > 2 then
  begin
    LResult := LRustResults[2];
    WriteLn('  Rust: ', LResult.NsPerOp:0:2, ' ns/op');
  end;
  if Length(LFPCResults) > 2 then
  begin
    LResult := LFPCResults[2];
    WriteLn('  FPC:  ', LResult.NsPerOp:0:2, ' ns/op');
  end;

  WriteLn('');
  WriteLn('=== Summary ===');
  WriteLn('Cross-language benchmark parsing complete!');
  WriteLn('All results are in TBenchResult format for unified comparison.');
end.
