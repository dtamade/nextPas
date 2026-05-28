program bench_avx512_vs_avx2;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.avx2,
  nextpas.core.simd.avx512,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.bench;

type
  TBackendBenchResult = record
    Name: string;
    Size: SizeUInt;
    AVX2OpsPerSec: Double;
    AVX512OpsPerSec: Double;
    Speedup: Double;
  end;

  TBackendBenchResults = array of TBackendBenchResult;

function GetArchName: string; forward;

function RunBackendComparison: TBackendBenchResults;
var
  AVX2Results, AVX512Results: TBenchResults;
  LIndex: Integer;
  LSkipReason: string;
begin
  Result := nil;

  WriteLn('=== AVX-512 vs AVX2 Performance Benchmark ===');
  WriteLn;
  SetVectorAsmEnabled(True);
  try
    WriteLn('Running AVX2 backend tests...');
    LSkipReason := '';
    if not TryActivateBenchmarkBackend(sbAVX2, LSkipReason) then
    begin
      WriteLn('[SKIP] ', LSkipReason);
      Exit;
    end;
    AVX2Results := RunAllBenchmarks;

    WriteLn('Running AVX-512 backend tests...');
    LSkipReason := '';
    if not TryActivateBenchmarkBackend(sbAVX512, LSkipReason) then
    begin
      WriteLn('[SKIP] ', LSkipReason);
      Exit;
    end;
    AVX512Results := RunAllBenchmarks;

    // Combine results
    SetLength(Result, Length(AVX2Results));
    for LIndex := 0 to High(AVX2Results) do
    begin
      Result[LIndex].Name := AVX2Results[LIndex].Name;
      Result[LIndex].Size := AVX2Results[LIndex].Size;
      Result[LIndex].AVX2OpsPerSec := AVX2Results[LIndex].ActiveOpsPerSec;
      Result[LIndex].AVX512OpsPerSec := AVX512Results[LIndex].ActiveOpsPerSec;
      if Result[LIndex].AVX2OpsPerSec > 0 then
        Result[LIndex].Speedup := Result[LIndex].AVX512OpsPerSec / Result[LIndex].AVX2OpsPerSec
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
  WriteLn('=== AVX-512 vs AVX2 Performance Comparison ===');
  WriteLn;
  WriteLn('Operation        Size     AVX2 ops/s     AVX-512 ops/s  Speedup');
  WriteLn('--------------------------------------------------------------------');

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
      FormatOps(Results[i].AVX2OpsPerSec),
      FormatOps(Results[i].AVX512OpsPerSec),
      Results[i].Speedup
    ]));

    if Results[i].Speedup > 0 then
    begin
      TotalSpeedup := TotalSpeedup + Results[i].Speedup;
      Inc(Count);
    end;
  end;

  WriteLn('--------------------------------------------------------------------');
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
    WriteLn(F, '# AVX-512 vs AVX2 Performance Benchmark Report');
    WriteLn(F);
    WriteLn(F, '**Generated**: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn(F, '**Platform**: ', GetArchName);
    WriteLn(F);

    // CPU Info
    WriteLn(F, '## CPU Information');
    WriteLn(F);
    {$IFDEF CPUX86_64}
    WriteLn(F, '- Architecture: x86_64');
    WriteLn(F, '- AVX2 Backend Support: ', IsBackendAvailableOnCPU(sbAVX2));
    WriteLn(F, '- AVX-512 Backend Support: ', IsBackendAvailableOnCPU(sbAVX512));
    WriteLn(F, '- Usable AVX-512F: ', HasAVX512);
    {$ELSE}
    WriteLn(F, '- Architecture: ', GetArchName);
    WriteLn(F, '- AVX-512 Support: Not available on this platform');
    {$ENDIF}
    WriteLn(F);

    // Results Table
    WriteLn(F, '## Performance Results');
    WriteLn(F);
    WriteLn(F, '| Operation | Size | AVX2 ops/s | AVX-512 ops/s | Speedup |');
    WriteLn(F, '|-----------|------|------------|---------------|---------|');

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
        FormatOps(Results[LIndex].AVX2OpsPerSec),
        FormatOps(Results[LIndex].AVX512OpsPerSec),
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
    WriteLn(F, '### 512-bit Vector Operations');
    WriteLn(F);
    WriteLn(F, 'AVX-512 provides 512-bit vector registers (ZMM), doubling the width of AVX2''s 256-bit registers (YMM).');
    WriteLn(F, 'This allows processing twice as much data per instruction for operations that can utilize the full width.');
    WriteLn(F);

    WriteLn(F, '### Memory Operations');
    WriteLn(F);
    WriteLn(F, 'Memory operations benefit significantly from AVX-512''s wider registers:');
    WriteLn(F);
    for LIndex := 0 to High(Results) do
    begin
      if (Results[LIndex].Size > 0) and (Results[LIndex].Speedup > 1.3) then
        WriteLn(F, Format('- **%s**: %.2fx speedup (64 bytes/iteration vs 32 bytes)', [
          Results[LIndex].Name, Results[LIndex].Speedup]));
    end;
    WriteLn(F);

    WriteLn(F, '### Vector Operations');
    WriteLn(F);
    WriteLn(F, 'Vector operations show varying speedup depending on operation type:');
    WriteLn(F);
    for LIndex := 0 to High(Results) do
    begin
      if (Results[LIndex].Size = 0) and (Results[LIndex].Speedup > 1.2) then
        WriteLn(F, Format('- **%s**: %.2fx speedup', [Results[LIndex].Name, Results[LIndex].Speedup]));
    end;
    WriteLn(F);

    WriteLn(F, '## Conclusion');
    WriteLn(F);
    if Count > 0 then
    begin
      if TotalSpeedup / Count >= 1.8 then
        WriteLn(F, 'AVX-512 backend provides **excellent** performance improvement over AVX2 backend.')
      else if TotalSpeedup / Count >= 1.4 then
        WriteLn(F, 'AVX-512 backend provides **good** performance improvement over AVX2 backend.')
      else if TotalSpeedup / Count >= 1.2 then
        WriteLn(F, 'AVX-512 backend provides **moderate** performance improvement over AVX2 backend.')
      else
        WriteLn(F, 'AVX-512 backend provides **minimal** performance improvement over AVX2 backend.');
      WriteLn(F);
      WriteLn(F, 'Note: AVX-512 may have higher power consumption and can cause CPU frequency throttling on some processors.');
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
  WriteLn('AVX-512 vs AVX2 Performance Benchmark');
  WriteLn('======================================');
  WriteLn;

  // Check platform
  {$IFNDEF CPUX86_64}
  WriteLn('WARNING: This benchmark is designed for x86_64 platforms.');
  WriteLn('AVX-512 backend may not be available on this platform.');
  WriteLn;
  {$ENDIF}

  // Run benchmark
  Results := RunBackendComparison;

  if Length(Results) > 0 then
  begin
    // Print results to console
    PrintResults(Results);

    // Generate Markdown report
    ReportFileName := 'AVX512_vs_AVX2_Benchmark_Report.md';
    GenerateMarkdownReport(Results, ReportFileName);

    WriteLn('[BENCH] Benchmark completed successfully.');
  end
  else
  begin
    WriteLn('[SKIP] No AVX-512 benchmark results produced on this host.');
    Halt(0);
  end;
end.
