program bench_hotspots;

{
  S25a hotspot remeasure harness.

  Reports ns/elem (or ns/byte for MemEqual) for:
    - TrueScalar: local element loop + volatile sink (anti FPC auto-vector / DCE)
    - ScalarLib: production ScalarArray* / MemEqual_Scalar
    - Dispatch: active backend via GetDispatchTable (vector-asm enabled path)

  Roadmap sizes:
    ArrayAddF32 @1024, ArrayAddF64 @1024, ArrayMulF32 @4096 (16KB), MemEqual @4096 (4KB)
}

{$I nextpas.core.settings.inc}
{$CODEPAGE UTF8}
{$Q-}{$R-}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init, BaseUnix, Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, Math,
  nextpas.core.text.conv,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.scalar,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.cpuinfo;

const
  WARMUP = 200;
  MIN_ITERS = 2000;
  TARGET_MS = 400;

var
  g_VolatileF32: Single = 0;
  g_VolatileF64: Double = 0;
  g_VolatileByte: Byte = 0;
  g_VolatileBool: LongBool = False;

function GetNanoTime: Int64;
{$IFDEF UNIX}
var
  tv: TTimeVal;
begin
  fpgettimeofday(@tv, nil);
  Result := Int64(tv.tv_sec) * 1000000000 + Int64(tv.tv_usec) * 1000;
end;
{$ELSE}
var
  f, c: Int64;
begin
  QueryPerformanceFrequency(f);
  QueryPerformanceCounter(c);
  Result := c * 1000000000 div f;
end;
{$ENDIF}

type
  TBenchProc = procedure;

function MeasureNsPerUnit(aProc: TBenchProc; aUnits: SizeUInt): Double;
var
  LWarm, LIter, LIters, i: Integer;
  t0, t1, elapsed: Int64;
begin
  if aUnits = 0 then
    Exit(0.0);

  for LWarm := 1 to WARMUP do
    aProc();

  LIters := MIN_ITERS;
  t0 := GetNanoTime;
  for i := 1 to MIN_ITERS do
    aProc();
  t1 := GetNanoTime;
  elapsed := t1 - t0;
  if elapsed > 0 then
  begin
    LIters := Trunc((Int64(MIN_ITERS) * Int64(TARGET_MS) * 1000000) / elapsed);
    if LIters < MIN_ITERS then
      LIters := MIN_ITERS;
  end
  else
    LIters := MIN_ITERS * 10;

  t0 := GetNanoTime;
  for LIter := 1 to LIters do
    aProc();
  t1 := GetNanoTime;
  elapsed := t1 - t0;
  if elapsed < 1 then
    elapsed := 1;
  Result := Double(elapsed) / Double(LIters) / Double(aUnits);
end;

procedure ReportHost;
begin
  WriteLn('=== S25a hotspot remeasure ===');
  WriteLn('Date:          2026-07-17');
  WriteLn('Host OS:       Linux x86_64');
  WriteLn('FPC flags:     -MObjFPC -Sh -O3 -gl (bench Makefile)');
  WriteLn('Active backend:', ' ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('VectorAsm:     ', BoolToStr(IsVectorAsmEnabled, True));
  WriteLn('CPU model:     ', GetCPUInfo.Model);
  WriteLn;
  WriteLn('Method:');
  WriteLn('  TrueScalar = local element loop + volatile sink (blocks DCE / auto-vector)');
  WriteLn('  ScalarLib  = production ScalarArray* / MemEqual_Scalar');
  WriteLn('  Dispatch   = GetDispatchTable active leaf (SIMD when available)');
  WriteLn('  Speedup vs TrueScalar = TrueScalar_ns / Dispatch_ns');
  WriteLn('  Speedup vs ScalarLib  = ScalarLib_ns / Dispatch_ns  (historical style)');
  WriteLn;
end;

procedure PrintRow(const aName: string; aTrue, aLib, aDisp: Double; aUnit: string);
var
  LVsTrue, LVsLib: Double;
begin
  if aDisp > 0 then
  begin
    LVsTrue := aTrue / aDisp;
    LVsLib := aLib / aDisp;
  end
  else
  begin
    LVsTrue := 0;
    LVsLib := 0;
  end;
  WriteLn(Format('  %-22s  true=%7.3f  lib=%7.3f  disp=%7.3f  %s  |  vsTrue=%.2fx  vsLib=%.2fx',
    [aName, aTrue, aLib, aDisp, aUnit, LVsTrue, LVsLib]));
end;

// ---------- ArrayAddF32 @1024 ----------

const
  N_ADD_F32 = 1024;

var
  AddF32A, AddF32B, AddF32Dst: array[0..N_ADD_F32 - 1] of Single;
  g_Dispatch: PSimdDispatchTable;

procedure TrueScalarAddF32;
var
  i: SizeUInt;
begin
  for i := 0 to N_ADD_F32 - 1 do
  begin
    AddF32Dst[i] := AddF32A[i] + AddF32B[i];
    g_VolatileF32 := AddF32Dst[i];
  end;
end;

procedure ScalarLibAddF32;
begin
  ScalarArrayAddF32(@AddF32A[0], @AddF32B[0], @AddF32Dst[0], N_ADD_F32);
  g_VolatileF32 := AddF32Dst[N_ADD_F32 - 1];
end;

procedure DispatchAddF32;
begin
  g_Dispatch^.BatchF32.ArrayAdd(@AddF32A[0], @AddF32B[0], @AddF32Dst[0], N_ADD_F32);
  g_VolatileF32 := AddF32Dst[N_ADD_F32 - 1];
end;

// ---------- ArrayAddF64 @1024 ----------

const
  N_ADD_F64 = 1024;

var
  AddF64A, AddF64B, AddF64Dst: array[0..N_ADD_F64 - 1] of Double;

procedure TrueScalarAddF64;
var
  i: SizeUInt;
begin
  for i := 0 to N_ADD_F64 - 1 do
  begin
    AddF64Dst[i] := AddF64A[i] + AddF64B[i];
    g_VolatileF64 := AddF64Dst[i];
  end;
end;

procedure ScalarLibAddF64;
begin
  ScalarArrayAddF64(@AddF64A[0], @AddF64B[0], @AddF64Dst[0], N_ADD_F64);
  g_VolatileF64 := AddF64Dst[N_ADD_F64 - 1];
end;

procedure DispatchAddF64;
begin
  g_Dispatch^.BatchF64.ArrayAdd(@AddF64A[0], @AddF64B[0], @AddF64Dst[0], N_ADD_F64);
  g_VolatileF64 := AddF64Dst[N_ADD_F64 - 1];
end;

// ---------- ArrayMulF32 @4096 (16KB) ----------

const
  N_MUL_F32 = 4096; // 16KB of Single

var
  MulF32A, MulF32B, MulF32Dst: array[0..N_MUL_F32 - 1] of Single;

procedure TrueScalarMulF32;
var
  i: SizeUInt;
begin
  for i := 0 to N_MUL_F32 - 1 do
  begin
    MulF32Dst[i] := MulF32A[i] * MulF32B[i];
    g_VolatileF32 := MulF32Dst[i];
  end;
end;

procedure ScalarLibMulF32;
begin
  ScalarArrayMulF32(@MulF32A[0], @MulF32B[0], @MulF32Dst[0], N_MUL_F32);
  g_VolatileF32 := MulF32Dst[N_MUL_F32 - 1];
end;

procedure DispatchMulF32;
begin
  g_Dispatch^.BatchF32.ArrayMul(@MulF32A[0], @MulF32B[0], @MulF32Dst[0], N_MUL_F32);
  g_VolatileF32 := MulF32Dst[N_MUL_F32 - 1];
end;

// ---------- MemEqual @4096 (4KB) ----------

const
  N_MEM = 4096;

var
  MemA, MemB: array[0..N_MEM - 1] of Byte;

procedure TrueScalarMemEqual;
var
  i: SizeUInt;
  eq: LongBool;
begin
  eq := True;
  for i := 0 to N_MEM - 1 do
  begin
    if MemA[i] <> MemB[i] then
    begin
      eq := False;
      Break;
    end;
    g_VolatileByte := MemA[i];
  end;
  g_VolatileBool := eq;
end;

procedure ScalarLibMemEqual;
begin
  g_VolatileBool := MemEqual_Scalar(@MemA[0], @MemB[0], N_MEM);
end;

procedure DispatchMemEqual;
begin
  g_VolatileBool := g_Dispatch^.Memory.Equal(@MemA[0], @MemB[0], N_MEM);
end;

procedure InitData;
var
  i: SizeUInt;
begin
  for i := 0 to N_ADD_F32 - 1 do
  begin
    AddF32A[i] := Sin(i * 0.7) * 50.0;
    AddF32B[i] := Cos(i * 1.1) * 30.0 + 1.0;
    AddF32Dst[i] := 0.0;
  end;
  for i := 0 to N_ADD_F64 - 1 do
  begin
    AddF64A[i] := Sin(i * 0.7) * 50.0;
    AddF64B[i] := Cos(i * 1.1) * 30.0 + 1.0;
    AddF64Dst[i] := 0.0;
  end;
  for i := 0 to N_MUL_F32 - 1 do
  begin
    MulF32A[i] := (i mod 257) * 0.25 + 1.0;
    MulF32B[i] := (i mod 131) * 0.5 - 3.0;
    MulF32Dst[i] := 0.0;
  end;
  for i := 0 to N_MEM - 1 do
  begin
    MemA[i] := Byte(i * 17 + 3);
    MemB[i] := MemA[i];
  end;
end;

var
  tTrue, tLib, tDisp: Double;
begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  SetVectorAsmEnabled(True);
  g_Dispatch := GetDispatchTable;
  InitData;
  ReportHost;

  WriteLn('Hotspots (lower ns is faster):');
  tTrue := MeasureNsPerUnit(@TrueScalarAddF32, N_ADD_F32);
  tLib := MeasureNsPerUnit(@ScalarLibAddF32, N_ADD_F32);
  tDisp := MeasureNsPerUnit(@DispatchAddF32, N_ADD_F32);
  PrintRow('ArrayAddF32 @1024', tTrue, tLib, tDisp, 'ns/elem');

  tTrue := MeasureNsPerUnit(@TrueScalarAddF64, N_ADD_F64);
  tLib := MeasureNsPerUnit(@ScalarLibAddF64, N_ADD_F64);
  tDisp := MeasureNsPerUnit(@DispatchAddF64, N_ADD_F64);
  PrintRow('ArrayAddF64 @1024', tTrue, tLib, tDisp, 'ns/elem');

  tTrue := MeasureNsPerUnit(@TrueScalarMulF32, N_MUL_F32);
  tLib := MeasureNsPerUnit(@ScalarLibMulF32, N_MUL_F32);
  tDisp := MeasureNsPerUnit(@DispatchMulF32, N_MUL_F32);
  PrintRow('ArrayMulF32 @16KB', tTrue, tLib, tDisp, 'ns/elem');

  tTrue := MeasureNsPerUnit(@TrueScalarMemEqual, N_MEM);
  tLib := MeasureNsPerUnit(@ScalarLibMemEqual, N_MEM);
  tDisp := MeasureNsPerUnit(@DispatchMemEqual, N_MEM);
  PrintRow('MemEqual @4KB', tTrue, tLib, tDisp, 'ns/byte');

  WriteLn;
  if g_VolatileF32 <> 0 then;
  if g_VolatileF64 <> 0 then;
  if g_VolatileByte <> 0 then;
  if g_VolatileBool then;
  WriteLn('Done.');
end.
