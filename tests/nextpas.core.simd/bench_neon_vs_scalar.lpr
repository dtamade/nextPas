program bench_neon_vs_scalar;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.neon,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.bench;

type
  TBackendBenchResult = record
    Name: string;
    Size: SizeUInt;
    ScalarOpsPerSec: Double;
    NEONOpsPerSec: Double;
    Speedup: Double;
  end;

  TBackendBenchResults = array of TBackendBenchResult;

function GetArchName: string; forward;

function RunBackendComparison: TBackendBenchResults;
var
  ScalarResults, NEONResults: TBenchResults;
  LIndex: Integer;
  LSkipReason: string;
begin
  Result := nil;

  WriteLn('=== NEON vs Scalar Performance Benchmark ===');
  WriteLn;
  SetVectorAsmEnabled(True);
  try
    WriteLn('Running Scalar backend tests...');
    LSkipReason := '';
    if not TryActivateBenchmarkBackend(sbScalar, LSkipReason) then
    begin
      WriteLn('[SKIP] ', LSkipReason);
      Exit;
    end;
    ScalarResults := RunAllBenchmarks;

    WriteLn('Running NEON backend tests...');
    LSkipReason := '';
    if not TryActivateBenchmarkBackend(sbNEON, LSkipReason) then
    begin
      WriteLn('[SKIP] ', LSkipReason);
      Exit;
    end;
    NEONResults := RunAllBenchmarks;

    // Combine results
    SetLength(Result, Length(ScalarResults));
    for LIndex := 0 to High(ScalarResults) do
    begin
      Result[LIndex].Name := ScalarResults[LIndex].Name;
      Result[LIndex].Size := ScalarResults[LIndex].Size;
      Result[LIndex].ScalarOpsPerSec := ScalarResults[LIndex].ActiveOpsPerSec;
      Result[LIndex].NEONOpsPerSec := NEONResults[LIndex].ActiveOpsPerSec;
      if Result[LIndex].ScalarOpsPerSec > 0 then
        Result[LIndex].Speedup := Result[LIndex].NEONOpsPerSec / Result[LIndex].ScalarOpsPerSec
      else
        Result[LIndex].Speedup := 0;
    end;
  finally
    ResetToAutomaticBackend;
  end;
end;

function FormatOps(Ops: Double): string;
begin
  if Ops >= 1e9 then
    Result := Format('%.2f G', [Ops / 1e9])
  else if Ops >= 1e6 then
    Result := Format('%.2f M', [Ops / 1e6])
  else if Ops >= 1e3 then
    Result := Format('%.2f K', [Ops / 1e3])
  else
    Result := Format('%.0f  ', [Ops]);
end;

procedure PrintResults(const Results: TBackendBenchResults);
var
  i: Integer;
  SizeStr: string;
  TotalSpeedup: Double;
  Count: Integer;
begin
  WriteLn;
  WriteLn('=== NEON vs Scalar Performance Comparison ===');
  WriteLn;
  WriteLn('Operation        Size     Scalar ops/s   NEON ops/s     Speedup');
  WriteLn('------------------------------------------------------------------');

  TotalSpeedup := 0;
  Count := 0;

  for i := 0 to High(Results) do
  begin
    if Results[i].Size > 0 then
      SizeStr := Format('%4d B', [Results[i].Size])
    else
      SizeStr := '     -';

    WriteLn(Format('%-15s  %s  %12s  %12s  %6.2fx', [
      Results[i].Name,
      SizeStr,
      FormatOps(Results[i].ScalarOpsPerSec),
      FormatOps(Results[i].NEONOpsPerSec),
      Results[i].Speedup
    ]));

    if Results[i].Speedup > 0 then
    begin
      TotalSpeedup := TotalSpeedup + Results[i].Speedup;
      Inc(Count);
    end;
  end;

  WriteLn('------------------------------------------------------------------');
  if Count > 0 then
    WriteLn(Format('Average Speedup: %.2fx', [TotalSpeedup / Count]));
  WriteLn;
end;

procedure GenerateMarkdownReport(const Results: TBackendBenchResults; const FileName: string);
var
  F: TextFile;
  LIndex: Integer;
  LSizeStr: string;
  TotalSpeedup: Double;
  Count: Integer;
begin
  AssignFile(F, FileName);
  Rewrite(F);
  try
    WriteLn(F, '# NEON vs Scalar Performance Benchmark Report');
    WriteLn(F);
    WriteLn(F, '**Generated**: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn(F, '**Platform**: ', GetArchName);
    WriteLn(F);

    // CPU Info
    WriteLn(F, '## CPU Information');
    WriteLn(F);
    {$IFDEF CPUAARCH64}
    WriteLn(F, '- Architecture: AArch64 (ARM 64-bit)');
    WriteLn(F, '- NEON Support: Available');
    {$ELSE}
    WriteLn(F, '- Architecture: ', GetArchName);
    WriteLn(F, '- NEON Support: Not available on this platform');
    {$ENDIF}
    WriteLn(F);

    // Results Table
    WriteLn(F, '## Performance Results');
    WriteLn(F);
    WriteLn(F, '| Operation | Size | Scalar ops/s | NEON ops/s | Speedup |');
    WriteLn(F, '|-----------|------|--------------|------------|---------|');

    TotalSpeedup := 0;
    Count := 0;

    for LIndex := 0 to High(Results) do
    begin
      if Results[LIndex].Size > 0 then
        LSizeStr := Format('%d B', [Results[LIndex].Size])
      else
        LSizeStr := '-';

      WriteLn(F, Format('| %s | %s | %s | %s | %.2fx |', [
        Results[LIndex].Name,
        LSizeStr,
        FormatOps(Results[LIndex].ScalarOpsPerSec),
        FormatOps(Results[LIndex].NEONOpsPerSec),
        Results[LIndex].Speedup
      ]));

      if Results[LIndex].Speedup > 0 then
      begin
        TotalSpeedup := TotalSpeedup + Results[LIndex].Speedup;
        Inc(Count);
      end;
    end;

    WriteLn(F);
    WriteLn(F, '## Summary');
    WriteLn(F);
    if Count > 0 then
      WriteLn(F, Format('- **Average Speedup**: %.2fx', [TotalSpeedup / Count]))
    else
      WriteLn(F, '- **Average Speedup**: N/A');
    WriteLn(F, Format('- **Total Operations Tested**: %d', [Length(Results)]));
    WriteLn(F);

    // Analysis
    WriteLn(F, '## Analysis');
    WriteLn(F);
    WriteLn(F, '### Memory Operations');
    WriteLn(F);
    WriteLn(F, 'Memory operations (MemEqual, MemFindByte, SumBytes, etc.) show significant speedup with NEON:');
    WriteLn(F);
    for LIndex := 0 to High(Results) do
    begin
      if (Results[LIndex].Size > 0) and (Results[LIndex].Speedup > 1.5) then
        WriteLn(F, Format('- **%s**: %.2fx speedup', [Results[LIndex].Name, Results[LIndex].Speedup]));
    end;
    WriteLn(F);

    WriteLn(F, '### Vector Operations');
    WriteLn(F);
    WriteLn(F, 'Vector operations (VecF32x4Add, VecI32x4Add, etc.) benefit from NEON SIMD instructions:');
    WriteLn(F);
    for LIndex := 0 to High(Results) do
    begin
      if (Results[LIndex].Size = 0) and (Results[LIndex].Speedup > 1.5) then
        WriteLn(F, Format('- **%s**: %.2fx speedup', [Results[LIndex].Name, Results[LIndex].Speedup]));
    end;
    WriteLn(F);

    WriteLn(F, '## Conclusion');
    WriteLn(F);
    if Count > 0 then
    begin
      if TotalSpeedup / Count >= 2.0 then
        WriteLn(F, 'NEON backend provides **excellent** performance improvement over Scalar backend.')
      else if TotalSpeedup / Count >= 1.5 then
        WriteLn(F, 'NEON backend provides **good** performance improvement over Scalar backend.')
      else if TotalSpeedup / Count >= 1.2 then
        WriteLn(F, 'NEON backend provides **moderate** performance improvement over Scalar backend.')
      else
        WriteLn(F, 'NEON backend provides **minimal** performance improvement over Scalar backend.');
    end;
    WriteLn(F);

  finally
    CloseFile(F);
  end;

  WriteLn('Markdown report generated: ', FileName);
end;

function GetArchName: string;
begin
  {$IF defined(CPUX86_64)}
  Result := 'x86_64';
  {$ELSEIF defined(CPUI386)}
  Result := 'i386';
  {$ELSEIF defined(CPUAARCH64)}
  Result := 'arm64';
  {$ELSEIF defined(CPURISCV64)}
  Result := 'riscv64';
  {$ELSEIF defined(CPURISCV32)}
  Result := 'riscv32';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
end;

var
  Results: TBackendBenchResults;
  ReportFileName: string;
begin
  WriteLn('NEON vs Scalar Performance Benchmark');
  WriteLn('=====================================');
  WriteLn;

  // Check platform
  {$IFNDEF CPUAARCH64}
  WriteLn('WARNING: This benchmark is designed for AArch64 (ARM 64-bit) platforms.');
  WriteLn('NEON backend may not be available on this platform.');
  WriteLn;
  {$ENDIF}

  // Run benchmark
  Results := RunBackendComparison;

  if Length(Results) > 0 then
  begin
    // Print results to console
    PrintResults(Results);

    // Generate Markdown report
    ReportFileName := 'NEON_vs_Scalar_Benchmark_Report.md';
    GenerateMarkdownReport(Results, ReportFileName);

    WriteLn('[BENCH] Benchmark completed successfully.');
  end
  else
  begin
    WriteLn('[SKIP] No NEON benchmark results produced on this host.');
    Halt(0);
  end;
end.
