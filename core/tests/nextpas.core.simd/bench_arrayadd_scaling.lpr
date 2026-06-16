program bench_arrayadd_scaling;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  nextpas.core.simd,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.base,
  nextpas.core.time.stopwatch,
  nextpas.core.text.conv;

const
  WARMUP = 5;
  REPEATS = 20;

  SIZES: array[0..6] of Integer = (16, 64, 256, 1024, 4096, 16384, 65536);

// ---------------------------------------------------------------------------
// Scalar baselines (no SIMD dispatch)
// ---------------------------------------------------------------------------

procedure ScalarAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;

procedure ScalarAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var
  i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;

procedure ScalarAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var
  i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function FmtFloat(aVal: Double; aDec: Integer): string;
begin
  Str(aVal:0:aDec, Result);
end;

function FmtMBs(aMBs: Double): string;
begin
  Result := FmtFloat(aMBs, 1) + ' MB/s';
end;

function FmtRatio(aRatio: Double): string;
begin
  Result := FmtFloat(aRatio, 2) + 'x';
end;

function FmtSize(aSize: Integer): string;
var
  Ls: string;
begin
  Str(aSize, Ls);
  Result := Ls;
end;

procedure PrintHeader;
begin
  WriteLn('=== G18 ArrayAdd Scaling Benchmark ===');
  WriteLn;
  WriteLn('  Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('  Warmup: ', WARMUP, '  Repeats: ', REPEATS);
  WriteLn;
  WriteLn('  Format:  size | scalar MB/s | simd MB/s | speedup');
  WriteLn('  ---------------------------------------------------');
end;

procedure PrintRow(aSize: Integer; aScalarMBs, aSimdMBs, aRatio: Double);
begin
  WriteLn('  ', FmtSize(aSize):6, ' | ',
    FmtFloat(aScalarMBs, 1):10, ' | ',
    FmtFloat(aSimdMBs, 1):9, ' | ',
    FmtFloat(aRatio, 2):6, 'x');
end;

// ---------------------------------------------------------------------------
// Benchmark kernel: measures MB/s for a given procedure call
// ---------------------------------------------------------------------------

type
  TAddProcF32 = procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
  TAddProcF64 = procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
  TAddProcI32 = procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);

function BenchF32(Proc: TAddProcF32; aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt): Double;
var
  LSw: TStopwatch;
  i, r: Integer;
  LElapsedNs: Int64;
  LBytes: Double;
begin
  for i := 1 to WARMUP do
    Proc(aSrc1, aSrc2, aDst, aCount);
  LSw := TStopwatch.StartNew;
  for r := 1 to REPEATS do
    Proc(aSrc1, aSrc2, aDst, aCount);
  LSw.Stop;
  LElapsedNs := LSw.Elapsed.AsNanoseconds;
  if LElapsedNs = 0 then LElapsedNs := 1;
  // 2 reads + 1 write = 3 * sizeof(Single) * count per iteration
  LBytes := 3.0 * SizeOf(Single) * aCount * REPEATS;
  Result := (LBytes / (LElapsedNs * 1e-9)) / (1024.0 * 1024.0);
end;

function BenchF64(Proc: TAddProcF64; aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt): Double;
var
  LSw: TStopwatch;
  i, r: Integer;
  LElapsedNs: Int64;
  LBytes: Double;
begin
  for i := 1 to WARMUP do
    Proc(aSrc1, aSrc2, aDst, aCount);
  LSw := TStopwatch.StartNew;
  for r := 1 to REPEATS do
    Proc(aSrc1, aSrc2, aDst, aCount);
  LSw.Stop;
  LElapsedNs := LSw.Elapsed.AsNanoseconds;
  if LElapsedNs = 0 then LElapsedNs := 1;
  LBytes := 3.0 * SizeOf(Double) * aCount * REPEATS;
  Result := (LBytes / (LElapsedNs * 1e-9)) / (1024.0 * 1024.0);
end;

function BenchI32(Proc: TAddProcI32; aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt): Double;
var
  LSw: TStopwatch;
  i, r: Integer;
  LElapsedNs: Int64;
  LBytes: Double;
begin
  for i := 1 to WARMUP do
    Proc(aSrc1, aSrc2, aDst, aCount);
  LSw := TStopwatch.StartNew;
  for r := 1 to REPEATS do
    Proc(aSrc1, aSrc2, aDst, aCount);
  LSw.Stop;
  LElapsedNs := LSw.Elapsed.AsNanoseconds;
  if LElapsedNs = 0 then LElapsedNs := 1;
  LBytes := 3.0 * SizeOf(Int32) * aCount * REPEATS;
  Result := (LBytes / (LElapsedNs * 1e-9)) / (1024.0 * 1024.0);
end;

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
var
  LSizeIdx, i: Integer;
  LCount: SizeUInt;
  LScalarMBs, LSimdMBs, LRatio: Double;

  LF32Src1, LF32Src2, LF32Dst: array of Single;
  LF64Src1, LF64Src2, LF64Dst: array of Double;
  LI32Src1, LI32Src2, LI32Dst: array of Int32;

begin
  PrintHeader;

  // ======================================================================
  WriteLn;
  WriteLn('  -- ArrayAddF32 (Single) --');
  WriteLn;
  for LSizeIdx := Low(SIZES) to High(SIZES) do
  begin
    LCount := SIZES[LSizeIdx];
    SetLength(LF32Src1, LCount);
    SetLength(LF32Src2, LCount);
    SetLength(LF32Dst, LCount);
    for i := 0 to LCount - 1 do
    begin
      LF32Src1[i] := 1.0 + (i mod 7) * 0.1;
      LF32Src2[i] := 2.0 + (i mod 5) * 0.2;
    end;

    LScalarMBs := BenchF32(@ScalarAddF32, @LF32Src1[0], @LF32Src2[0], @LF32Dst[0], LCount);
    LSimdMBs   := BenchF32(@ArrayAddF32,  @LF32Src1[0], @LF32Src2[0], @LF32Dst[0], LCount);
    if LScalarMBs > 0 then
      LRatio := LSimdMBs / LScalarMBs
    else
      LRatio := 0.0;
    PrintRow(LCount, LScalarMBs, LSimdMBs, LRatio);
  end;

  // ======================================================================
  WriteLn;
  WriteLn('  -- ArrayAddF64 (Double) --');
  WriteLn;
  for LSizeIdx := Low(SIZES) to High(SIZES) do
  begin
    LCount := SIZES[LSizeIdx];
    SetLength(LF64Src1, LCount);
    SetLength(LF64Src2, LCount);
    SetLength(LF64Dst, LCount);
    for i := 0 to LCount - 1 do
    begin
      LF64Src1[i] := 1.0 + (i mod 7) * 0.1;
      LF64Src2[i] := 2.0 + (i mod 5) * 0.2;
    end;

    LScalarMBs := BenchF64(@ScalarAddF64, @LF64Src1[0], @LF64Src2[0], @LF64Dst[0], LCount);
    LSimdMBs   := BenchF64(@ArrayAddF64,  @LF64Src1[0], @LF64Src2[0], @LF64Dst[0], LCount);
    if LScalarMBs > 0 then
      LRatio := LSimdMBs / LScalarMBs
    else
      LRatio := 0.0;
    PrintRow(LCount, LScalarMBs, LSimdMBs, LRatio);
  end;

  // ======================================================================
  WriteLn;
  WriteLn('  -- ArrayAddI32 (Int32) --');
  WriteLn;
  for LSizeIdx := Low(SIZES) to High(SIZES) do
  begin
    LCount := SIZES[LSizeIdx];
    SetLength(LI32Src1, LCount);
    SetLength(LI32Src2, LCount);
    SetLength(LI32Dst, LCount);
    for i := 0 to LCount - 1 do
    begin
      LI32Src1[i] := 1 + (i mod 100);
      LI32Src2[i] := 2 + (i mod 50);
    end;

    LScalarMBs := BenchI32(@ScalarAddI32, @LI32Src1[0], @LI32Src2[0], @LI32Dst[0], LCount);
    LSimdMBs   := BenchI32(@ArrayAddI32,  @LI32Src1[0], @LI32Src2[0], @LI32Dst[0], LCount);
    if LScalarMBs > 0 then
      LRatio := LSimdMBs / LScalarMBs
    else
      LRatio := 0.0;
    PrintRow(LCount, LScalarMBs, LSimdMBs, LRatio);
  end;

  // ======================================================================
  WriteLn;
  WriteLn('=== Benchmark Complete ===');
end.
