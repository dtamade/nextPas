unit nextpas.core.simd.cpuinfo.diagnostic;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{$IFDEF WINDOWS}
  {$CODEPAGE UTF8}
{$ENDIF}

interface

uses
  Classes, SysUtils,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base;

type
  { TCPUInfoDiagnosticReport - Comprehensive CPU diagnostics }
  TCPUInfoDiagnosticReport = record
    CPUInfo: TCPUInfo;
    DetectionTime: Double;        // Time in milliseconds for detection
    CacheLatency: Double;         // Average cache access latency
    MemoryBandwidth: Double;      // Memory bandwidth estimate MB/s
    ValidationPassed: Boolean;    // Self-validation checks
    AdditionalNotes: string;      // Any diagnostic notes
  end;

  { TCPUPerformanceCounter - Performance measurement helper }
  TCPUPerformanceCounter = record
    StartTime: Int64;
    EndTime: Int64;
    Frequency: Int64;
  end;

// Diagnostic functions
function GenerateDiagnosticReport: TCPUInfoDiagnosticReport;
procedure PrintCPUInfo(const Info: TCPUInfo);
procedure ExportDiagnosticReport(const Report: TCPUInfoDiagnosticReport; const FileName: string);

// Performance measurement helpers
function StartCounter: TCPUPerformanceCounter; inline;
function StopCounter(const Counter: TCPUPerformanceCounter): Double; inline;
function MeasureCPUInfoDetectionTime: Double;

// Validation helpers
function ValidateCPUInfo(const Info: TCPUInfo): Boolean;
function BenchmarkCacheLatency: Double;
function EstimateMemoryBandwidth: Double;

// Helper function for architecture string
function GetArchName(arch: TCPUArch): string;

implementation

{$IFDEF WINDOWS}
uses
  Windows;
{$ENDIF}

// Local helpers for OS enablement on x86
{$IFDEF SIMD_X86_AVAILABLE}
function X86XCR0_EnablesAVX_Local(const Info: TCPUInfo): Boolean; inline;
begin
  Result := ((Info.XCR0 and (UInt64(1) shl 1)) <> 0) and // XMM state
            ((Info.XCR0 and (UInt64(1) shl 2)) <> 0);    // YMM state
end;

function X86XCR0_EnablesAVX512_Local(const Info: TCPUInfo): Boolean; inline;
begin
  // AVX-512 requires XMM (bit1), YMM (bit2), OPMASK (bit5), ZMM_Hi256 (bit6), Hi16_ZMM (bit7)
  Result := ((Info.XCR0 and (UInt64(1) shl 1)) <> 0) and
            ((Info.XCR0 and (UInt64(1) shl 2)) <> 0) and
            ((Info.XCR0 and (UInt64(1) shl 5)) <> 0) and
            ((Info.XCR0 and (UInt64(1) shl 6)) <> 0) and
            ((Info.XCR0 and (UInt64(1) shl 7)) <> 0);
end;
{$ENDIF}

function GetArchName(arch: TCPUArch): string;
begin
  case arch of
    caX86: Result := 'x86';
    caARM: Result := 'ARM';
    caRISCV: Result := 'RISC-V';
    caLoongArch: Result := 'LoongArch';
    else Result := 'Unknown';
  end;
end;

function StartCounter: TCPUPerformanceCounter; inline;
begin
  {$IFDEF WINDOWS}
  QueryPerformanceFrequency(Result.Frequency);
  QueryPerformanceCounter(Result.StartTime);
  {$ELSE}
  // Simple fallback using GetTickCount64 equivalent
  Result.Frequency := 1000;  // milliseconds
  Result.StartTime := GetTickCount64;
  {$ENDIF}
end;

function StopCounter(const Counter: TCPUPerformanceCounter): Double; inline;
var
  EndTime: Int64;
begin
  {$IFDEF WINDOWS}
  QueryPerformanceCounter(EndTime);
  Result := ((EndTime - Counter.StartTime) * 1000.0) / Counter.Frequency;
  {$ELSE}
  EndTime := GetTickCount64;
  Result := (EndTime - Counter.StartTime);
  {$ENDIF}
end;

function MeasureCPUInfoDetectionTime: Double;
var
  Counter: TCPUPerformanceCounter;
  Info: TCPUInfo;
begin
  // Force re-detection to measure first-time initialization
  ResetCPUInfo;
  Counter := StartCounter;
  Info := GetCPUInfo;
  Result := StopCounter(Counter);
end;

function ValidateCPUInfo(const Info: TCPUInfo): Boolean;
begin
  Result := True;
  
  // Basic validation checks
  if Info.Vendor = '' then Result := False;
  if Info.Model = '' then Result := False;
  if Info.Arch = caUnknown then Result := False;
  
  // Core count should be reasonable
  if (Info.PhysicalCores < 1) or (Info.PhysicalCores > 256) then Result := False;
  if (Info.LogicalCores < Info.PhysicalCores) or (Info.LogicalCores > 512) then Result := False;
  
  // Cache sizes should be reasonable (if detected)
  if Info.Cache.L1DataKB > 256 then Result := False;  // L1 usually <= 256KB
  if Info.Cache.L2KB > 64*1024 then Result := False;  // L2 usually <= 64MB
end;

function BenchmarkCacheLatency: Double;
const
  ITERATIONS = 1000000;
var
  i: Integer;
  Counter: TCPUPerformanceCounter;
  buffer: array[0..1023] of Byte;  // 1KB buffer for L1 cache test
  sum: Integer;
begin
  // Warm up
  for i := 0 to 999 do
    buffer[i and 1023] := i and $FF;
    
  Counter := StartCounter;
  
  sum := 0;
  for i := 1 to ITERATIONS do
  begin
    sum := sum + buffer[i and 1023];
  end;
  
  Result := StopCounter(Counter) * 1000000 / ITERATIONS;  // nanoseconds per access
  
  // Prevent optimization
  if sum = MaxInt then
    WriteLn('Impossible');
end;

function EstimateMemoryBandwidth: Double;
const
  BUFFER_SIZE = 1024 * 1024;  // 1MB
  ITERATIONS = 100;
var
  i, j: Integer;
  Counter: TCPUPerformanceCounter;
  buffer: array of Byte;
  sum: Int64;
begin
  SetLength(buffer, BUFFER_SIZE);
  
  // Initialize buffer
  for i := 0 to BUFFER_SIZE - 1 do
    buffer[i] := i and $FF;
    
  Counter := StartCounter;
  
  sum := 0;
  for i := 1 to ITERATIONS do
  begin
    for j := 0 to BUFFER_SIZE - 1 do
      sum := sum + buffer[j];
  end;
  
  Result := StopCounter(Counter);
  if Result > 0 then
    Result := (BUFFER_SIZE * ITERATIONS / 1024.0 / 1024.0) / (Result / 1000.0)  // MB/s
  else
    Result := 0;
    
  // Prevent optimization  
  if sum = MaxInt then
    WriteLn('Impossible');
end;

function GenerateDiagnosticReport: TCPUInfoDiagnosticReport;
begin
  Result.CPUInfo := GetCPUInfo;
  Result.DetectionTime := MeasureCPUInfoDetectionTime;
  Result.CacheLatency := BenchmarkCacheLatency;
  Result.MemoryBandwidth := EstimateMemoryBandwidth;
  Result.ValidationPassed := ValidateCPUInfo(Result.CPUInfo);
  Result.AdditionalNotes := '';
  
  // Add diagnostic notes
  if not Result.ValidationPassed then
    Result.AdditionalNotes := Result.AdditionalNotes + 'Validation failed; ';
    
  if Result.DetectionTime > 10.0 then
    Result.AdditionalNotes := Result.AdditionalNotes + 'Detection unusually slow; ';
end;

procedure PrintCPUInfo(const Info: TCPUInfo);
begin
  WriteLn('CPU Information:');
  WriteLn('================');
  WriteLn('Vendor: ', Info.Vendor);
  WriteLn('Model: ', Info.Model);
  WriteLn('Architecture: ', GetArchName(Info.Arch));
  WriteLn('Physical Cores: ', Info.PhysicalCores);
  WriteLn('Logical Cores: ', Info.LogicalCores);
  WriteLn;
  WriteLn('Cache Information:');
  WriteLn('  L1 Data: ', Info.Cache.L1DataKB, ' KB');
  WriteLn('  L1 Instruction: ', Info.Cache.L1InstrKB, ' KB');
  WriteLn('  L2: ', Info.Cache.L2KB, ' KB');
  WriteLn('  L3: ', Info.Cache.L3KB, ' KB');
  WriteLn('  Cache Line Size: ', Info.Cache.LineSize, ' bytes');
  WriteLn;
  
  // OS enablement details
  WriteLn('OS-Enablement:');
  WriteLn('  OSXSAVE: ', BoolToStr(Info.OSXSAVE, True));
  WriteLn('  XCR0: $', IntToHex(Info.XCR0, 16));
  WriteLn;
  
  // Generic features (Raw / Usable)
  WriteLn('Generic Features (Raw / Usable):');
  WriteLn('  SIMD-128: ', BoolToStr(gfSimd128 in Info.GenericRaw, True), ' / ', BoolToStr(gfSimd128 in Info.GenericUsable, True));
  WriteLn('  SIMD-256: ', BoolToStr(gfSimd256 in Info.GenericRaw, True), ' / ', BoolToStr(gfSimd256 in Info.GenericUsable, True));
  WriteLn('  SIMD-512: ', BoolToStr(gfSimd512 in Info.GenericRaw, True), ' / ', BoolToStr(gfSimd512 in Info.GenericUsable, True));
  WriteLn('  AES: ', BoolToStr(gfAES in Info.GenericRaw, True), ' / ', BoolToStr(gfAES in Info.GenericUsable, True));
  WriteLn('  FMA: ', BoolToStr(gfFMA in Info.GenericRaw, True), ' / ', BoolToStr(gfFMA in Info.GenericUsable, True));
  {$if declared(gfSHA)}
  WriteLn('  SHA: ', BoolToStr(gfSHA in Info.GenericRaw, True), ' / ', BoolToStr(gfSHA in Info.GenericUsable, True));
  {$endif}
  WriteLn;

  // Usability reasons for x86
  {$IFDEF SIMD_X86_AVAILABLE}
  if Info.Arch = caX86 then
  begin
    if (gfSimd256 in Info.GenericRaw) and not (gfSimd256 in Info.GenericUsable) then
    begin
      WriteLn('Note: SIMD-256 not usable:');
      if not Info.OSXSAVE then WriteLn('  - OSXSAVE not enabled by OS/CPU');
      if not X86XCR0_EnablesAVX_Local(Info) then WriteLn('  - XCR0 lacks XMM/YMM enable (bits 1 and 2)');
    end;
    if (gfSimd512 in Info.GenericRaw) and not (gfSimd512 in Info.GenericUsable) then
    begin
      WriteLn('Note: SIMD-512 not usable:');
      if not Info.OSXSAVE then WriteLn('  - OSXSAVE not enabled by OS/CPU');
      if not X86XCR0_EnablesAVX512_Local(Info) then WriteLn('  - XCR0 lacks AVX-512 enable (bits 1,2,5,6,7)');
    end;

    // Summary line for quick grep
    if (gfSimd256 in Info.GenericRaw) and not (gfSimd256 in Info.GenericUsable) then
      WriteLn('Summary: SIMD-256 raw=true usable=false (OSXSAVE=', BoolToStr(Info.OSXSAVE, True), ', XCR0=$', IntToHex(Info.XCR0,16), ')');
    if (gfSimd512 in Info.GenericRaw) and not (gfSimd512 in Info.GenericUsable) then
      WriteLn('Summary: SIMD-512 raw=true usable=false (OSXSAVE=', BoolToStr(Info.OSXSAVE, True), ', XCR0=$', IntToHex(Info.XCR0,16), ')');
  end;
  {$ENDIF}
  
  {$IFDEF SIMD_X86_AVAILABLE}
  WriteLn('x86 Features:');
  with Info.X86 do
  begin
    WriteLn('  MMX: ', BoolToStr(HasMMX, True));
    WriteLn('  SSE: ', BoolToStr(HasSSE, True));
    WriteLn('  SSE2: ', BoolToStr(HasSSE2, True));
    WriteLn('  SSE3: ', BoolToStr(HasSSE3, True));
    WriteLn('  SSSE3: ', BoolToStr(HasSSSE3, True));
    WriteLn('  SSE4.1: ', BoolToStr(HasSSE41, True));
    WriteLn('  SSE4.2: ', BoolToStr(HasSSE42, True));
    WriteLn('  AVX: ', BoolToStr(HasAVX, True));
    WriteLn('  AVX2: ', BoolToStr(HasAVX2, True));
    WriteLn('  AES: ', BoolToStr(HasAES, True));
    WriteLn('  FMA: ', BoolToStr(HasFMA, True));
    WriteLn('  AVX-512F: ', BoolToStr(HasAVX512F, True));
  end;
  {$ENDIF}
  WriteLn;
end;

procedure ExportDiagnosticReport(const Report: TCPUInfoDiagnosticReport; const FileName: string);
var
  F: TextFile;
begin
  AssignFile(F, FileName);
  Rewrite(F);
  try
    WriteLn(F, 'CPU Diagnostic Report');
    WriteLn(F, '====================');
    WriteLn(F, 'Generated: ', DateTimeToStr(Now));
    WriteLn(F);
    
    WriteLn(F, 'Detection Time: ', Format('%.3f ms', [Report.DetectionTime]));
    WriteLn(F, 'Cache Latency: ', Format('%.2f ns', [Report.CacheLatency]));
    WriteLn(F, 'Memory Bandwidth: ', Format('%.1f MB/s', [Report.MemoryBandwidth]));
    WriteLn(F, 'Validation Passed: ', BoolToStr(Report.ValidationPassed, True));
    if Report.AdditionalNotes <> '' then
      WriteLn(F, 'Notes: ', Report.AdditionalNotes);
    WriteLn(F);
    
    // Redirect PrintCPUInfo to file (simplified version)
    WriteLn(F, 'CPU Information:');
    WriteLn(F, 'Vendor: ', Report.CPUInfo.Vendor);
    WriteLn(F, 'Model: ', Report.CPUInfo.Model);
    WriteLn(F, 'Architecture: ', GetArchName(Report.CPUInfo.Arch));
    WriteLn(F, 'Physical Cores: ', Report.CPUInfo.PhysicalCores);
    WriteLn(F, 'Logical Cores: ', Report.CPUInfo.LogicalCores);
    WriteLn(F, 'L1 Data Cache: ', Report.CPUInfo.Cache.L1DataKB, ' KB');
    WriteLn(F, 'L2 Cache: ', Report.CPUInfo.Cache.L2KB, ' KB');
    WriteLn(F, 'L3 Cache: ', Report.CPUInfo.Cache.L3KB, ' KB');
    
    // OS enablement
    WriteLn(F, 'OSXSAVE: ', BoolToStr(Report.CPUInfo.OSXSAVE, True));
    WriteLn(F, 'XCR0: $', IntToHex(Report.CPUInfo.XCR0, 16));

    // Generic features (Raw / Usable)
    WriteLn(F, 'Generic Features (Raw / Usable):');
    WriteLn(F, '  SIMD-128: ', BoolToStr(gfSimd128 in Report.CPUInfo.GenericRaw, True), ' / ', BoolToStr(gfSimd128 in Report.CPUInfo.GenericUsable, True));
    WriteLn(F, '  SIMD-256: ', BoolToStr(gfSimd256 in Report.CPUInfo.GenericRaw, True), ' / ', BoolToStr(gfSimd256 in Report.CPUInfo.GenericUsable, True));
    WriteLn(F, '  SIMD-512: ', BoolToStr(gfSimd512 in Report.CPUInfo.GenericRaw, True), ' / ', BoolToStr(gfSimd512 in Report.CPUInfo.GenericUsable, True));
    WriteLn(F, '  AES: ', BoolToStr(gfAES in Report.CPUInfo.GenericRaw, True), ' / ', BoolToStr(gfAES in Report.CPUInfo.GenericUsable, True));
    WriteLn(F, '  FMA: ', BoolToStr(gfFMA in Report.CPUInfo.GenericRaw, True), ' / ', BoolToStr(gfFMA in Report.CPUInfo.GenericUsable, True));
    {$if declared(gfSHA)}
    WriteLn(F, '  SHA: ', BoolToStr(gfSHA in Report.CPUInfo.GenericRaw, True), ' / ', BoolToStr(gfSHA in Report.CPUInfo.GenericUsable, True));
    {$endif}

    // Usability reasons for x86
    {$IFDEF SIMD_X86_AVAILABLE}
    if Report.CPUInfo.Arch = caX86 then
    begin
      if (gfSimd256 in Report.CPUInfo.GenericRaw) and not (gfSimd256 in Report.CPUInfo.GenericUsable) then
      begin
        WriteLn(F, 'Note: SIMD-256 not usable:');
        if not Report.CPUInfo.OSXSAVE then WriteLn(F, '  - OSXSAVE not enabled by OS/CPU');
        if not X86XCR0_EnablesAVX_Local(Report.CPUInfo) then WriteLn(F, '  - XCR0 lacks XMM/YMM enable (bits 1 and 2)');
        WriteLn(F, 'Summary: SIMD-256 raw=true usable=false (OSXSAVE=', BoolToStr(Report.CPUInfo.OSXSAVE, True), ', XCR0=$', IntToHex(Report.CPUInfo.XCR0,16), ')');
      end;
      if (gfSimd512 in Report.CPUInfo.GenericRaw) and not (gfSimd512 in Report.CPUInfo.GenericUsable) then
      begin
        WriteLn(F, 'Note: SIMD-512 not usable:');
        if not Report.CPUInfo.OSXSAVE then WriteLn(F, '  - OSXSAVE not enabled by OS/CPU');
        if not X86XCR0_EnablesAVX512_Local(Report.CPUInfo) then WriteLn(F, '  - XCR0 lacks AVX-512 enable (bits 1,2,5,6,7)');
        WriteLn(F, 'Summary: SIMD-512 raw=true usable=false (OSXSAVE=', BoolToStr(Report.CPUInfo.OSXSAVE, True), ', XCR0=$', IntToHex(Report.CPUInfo.XCR0,16), ')');
      end;
    end;
    {$ENDIF}
    
  finally
    CloseFile(F);
  end;
end;

end.
