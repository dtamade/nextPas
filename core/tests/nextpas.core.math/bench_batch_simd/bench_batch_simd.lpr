program bench_batch_simd;

{**
 * Performance benchmark: SIMD vs Scalar batch math operations.
 *
 * Compares pure Pascal loop implementations against SIMD-optimized
 * (BatchXxxSimdF32) versions for different array sizes (64, 1024, 16384).
 *
 * Uses nextpas.core.bench framework.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.text.conv,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.math.base,
  nextpas.core.math.trig,
  nextpas.core.math.scalar,
  nextpas.core.math.batch.simd;

const
  NUM_OPS = 16;
  NUM_SIZES = 3;

  OP_NAMES: array[0..NUM_OPS - 1] of string = (
    'Sin', 'Cos', 'Tan', 'SinCos', 'Sqrt', 'Abs', 'Neg', 'Exp',
    'Log2', 'Log10', 'Ceil', 'Floor', 'Round', 'Trunc', 'Lerp', 'Clamp'
  );

  SIZES: array[0..NUM_SIZES - 1] of Int64 = (
    64, 1024, 16384
  );

type
  { Stores scalar and simd ns/op for one (op, size) pair }
  TSpeedupEntry = record
    ScalarNs: Double;
    SimdNs: Double;
    Speedup: Double;
  end;

var
  GInputA: array of Single;
  GInputB: array of Single;
  GOutput: array of Single;
  GOutput2: array of Single;  // For SinCos

{ --- Pure Pascal scalar reference implementations --- }

procedure ScalarBatchSinF32(const AInput: array of Single;
                            var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Sin(AInput[I]);
end;

procedure ScalarBatchCosF32(const AInput: array of Single;
                            var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Cos(AInput[I]);
end;

procedure ScalarBatchSqrtF32(const AInput: array of Single;
                             var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Sqrt(AInput[I]);
end;

procedure ScalarBatchAbsF32(const AInput: array of Single;
                            var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Abs(AInput[I]);
end;

procedure ScalarBatchExpF32(const AInput: array of Single;
                            var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Exp(AInput[I]);
end;

procedure ScalarBatchLerpF32(const AStart, AEnd: array of Single;
                             const AT: Single;
                             var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AStart);
  if LCount > Length(AEnd) then
    LCount := Length(AEnd);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := AStart[I] + AT * (AEnd[I] - AStart[I]);
end;

procedure ScalarBatchClampF32(const AInput: array of Single;
                              const AMin, AMax: Single;
                              var AOutput: array of Single);
var
  I, LCount: SizeInt;
  LV: Single;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
  begin
    LV := AInput[I];
    if LV < AMin then
      LV := AMin
    else if LV > AMax then
      LV := AMax;
    AOutput[I] := LV;
  end;
end;

procedure ScalarBatchTanF32(const AInput: array of Single;
                            var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Tan(AInput[I]);
end;

procedure ScalarBatchSinCosF32(const AInput: array of Single;
                               var ASinOut, ACosOut: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(ASinOut) then
    LCount := Length(ASinOut);
  if LCount > Length(ACosOut) then
    LCount := Length(ACosOut);
  for I := 0 to LCount - 1 do
  begin
    ASinOut[I] := Sin(AInput[I]);
    ACosOut[I] := Cos(AInput[I]);
  end;
end;

procedure ScalarBatchNegF32(const AInput: array of Single;
                            var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := -AInput[I];
end;

procedure ScalarBatchLog2F32(const AInput: array of Single;
                             var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Ln(AInput[I]) * 1.4426950408889634; // 1/ln(2)
end;

procedure ScalarBatchLog10F32(const AInput: array of Single;
                              var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Ln(AInput[I]) * 0.4342944819032518; // 1/ln(10)
end;

procedure ScalarBatchCeilF32(const AInput: array of Single;
                             var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Ceil(AInput[I]);
end;

procedure ScalarBatchFloorF32(const AInput: array of Single;
                              var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Floor(AInput[I]);
end;

procedure ScalarBatchRoundF32(const AInput: array of Single;
                              var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Round(AInput[I]);
end;

procedure ScalarBatchTruncF32(const AInput: array of Single;
                              var AOutput: array of Single);
var
  I, LCount: SizeInt;
begin
  LCount := Length(AInput);
  if LCount > Length(AOutput) then
    LCount := Length(AOutput);
  for I := 0 to LCount - 1 do
    AOutput[I] := Trunc(AInput[I]);
end;

{ --- Test data initialization --- }

procedure InitTestData(ASize: SizeInt);
var
  I: SizeInt;
begin
  SetLength(GInputA, ASize);
  SetLength(GInputB, ASize);
  SetLength(GOutput, ASize);
  SetLength(GOutput2, ASize);
  for I := 0 to ASize - 1 do
  begin
    GInputA[I] := 0.1 + Single(I) * 0.001;
    GInputB[I] := 1.0 + Single(I) * 0.002;
  end;
end;

{ --- Benchmark callbacks --- }

procedure BenchSinScalar(const ACtx: IBenchContext);
begin
  ScalarBatchSinF32(GInputA, GOutput);
end;

procedure BenchSinSimd(const ACtx: IBenchContext);
begin
  BatchSinSimdF32(GInputA, GOutput);
end;

procedure BenchCosScalar(const ACtx: IBenchContext);
begin
  ScalarBatchCosF32(GInputA, GOutput);
end;

procedure BenchCosSimd(const ACtx: IBenchContext);
begin
  BatchCosSimdF32(GInputA, GOutput);
end;

procedure BenchSqrtScalar(const ACtx: IBenchContext);
begin
  ScalarBatchSqrtF32(GInputA, GOutput);
end;

procedure BenchSqrtSimd(const ACtx: IBenchContext);
begin
  BatchSqrtSimdF32(GInputA, GOutput);
end;

procedure BenchAbsScalar(const ACtx: IBenchContext);
begin
  ScalarBatchAbsF32(GInputA, GOutput);
end;

procedure BenchAbsSimd(const ACtx: IBenchContext);
begin
  BatchAbsSimdF32(GInputA, GOutput);
end;

procedure BenchExpScalar(const ACtx: IBenchContext);
begin
  ScalarBatchExpF32(GInputA, GOutput);
end;

procedure BenchExpSimd(const ACtx: IBenchContext);
begin
  BatchExpSimdF32(GInputA, GOutput);
end;

procedure BenchLerpScalar(const ACtx: IBenchContext);
begin
  ScalarBatchLerpF32(GInputA, GInputB, 0.5, GOutput);
end;

procedure BenchLerpSimd(const ACtx: IBenchContext);
begin
  BatchLerpSimdF32(GInputA, GInputB, 0.5, GOutput);
end;

procedure BenchClampScalar(const ACtx: IBenchContext);
begin
  ScalarBatchClampF32(GInputA, 0.0, 1.0, GOutput);
end;

procedure BenchClampSimd(const ACtx: IBenchContext);
begin
  BatchClampSimdF32(GInputA, 0.0, 1.0, GOutput);
end;

procedure BenchTanScalar(const ACtx: IBenchContext);
begin
  ScalarBatchTanF32(GInputA, GOutput);
end;

procedure BenchTanSimd(const ACtx: IBenchContext);
begin
  BatchTanSimdF32(GInputA, GOutput);
end;

procedure BenchSinCosScalar(const ACtx: IBenchContext);
begin
  ScalarBatchSinCosF32(GInputA, GOutput, GOutput2);
end;

procedure BenchSinCosSimd(const ACtx: IBenchContext);
begin
  BatchSinCosSimdF32(GInputA, GOutput, GOutput2);
end;

procedure BenchNegScalar(const ACtx: IBenchContext);
begin
  ScalarBatchNegF32(GInputA, GOutput);
end;

procedure BenchNegSimd(const ACtx: IBenchContext);
begin
  BatchNegSimdF32(GInputA, GOutput);
end;

procedure BenchLog2Scalar(const ACtx: IBenchContext);
begin
  ScalarBatchLog2F32(GInputA, GOutput);
end;

procedure BenchLog2Simd(const ACtx: IBenchContext);
begin
  BatchLog2SimdF32(GInputA, GOutput);
end;

procedure BenchLog10Scalar(const ACtx: IBenchContext);
begin
  ScalarBatchLog10F32(GInputA, GOutput);
end;

procedure BenchLog10Simd(const ACtx: IBenchContext);
begin
  BatchLog10SimdF32(GInputA, GOutput);
end;

procedure BenchCeilScalar(const ACtx: IBenchContext);
begin
  ScalarBatchCeilF32(GInputA, GOutput);
end;

procedure BenchCeilSimd(const ACtx: IBenchContext);
begin
  BatchCeilSimdF32(GInputA, GOutput);
end;

procedure BenchFloorScalar(const ACtx: IBenchContext);
begin
  ScalarBatchFloorF32(GInputA, GOutput);
end;

procedure BenchFloorSimd(const ACtx: IBenchContext);
begin
  BatchFloorSimdF32(GInputA, GOutput);
end;

procedure BenchRoundScalar(const ACtx: IBenchContext);
begin
  ScalarBatchRoundF32(GInputA, GOutput);
end;

procedure BenchRoundSimd(const ACtx: IBenchContext);
begin
  BatchRoundSimdF32(GInputA, GOutput);
end;

procedure BenchTruncScalar(const ACtx: IBenchContext);
begin
  ScalarBatchTruncF32(GInputA, GOutput);
end;

procedure BenchTruncSimd(const ACtx: IBenchContext);
begin
  BatchTruncSimdF32(GInputA, GOutput);
end;

{ --- Helper --- }

function FindNsPerOp(const AAll: TBenchResultArray;
                     const AName: string): Double;
var
  I: Integer;
begin
  for I := 0 to High(AAll) do
    if AAll[I].Name = AName then
      Exit(AAll[I].NsPerOp);
  Result := 0;
end;

{ --- Main --- }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  LSpeedupGrid: array[0..NUM_OPS - 1, 0..NUM_SIZES - 1] of TSpeedupEntry;
  LScalarNs, LSimdNs, LSpeedup: Double;
  LSuffix, LScalarName, LSimdName: string;
  LOpIdx, LSizeIdx: Integer;
begin
  WriteLn('Batch Math Operations: SIMD vs Scalar Benchmark');
  WriteLn('================================================');
  WriteLn;

  { --- Run per-size benchmarks --- }

  for LSizeIdx := 0 to NUM_SIZES - 1 do
  begin
    InitTestData(SIZES[LSizeIdx]);
    LSuffix := '/' + IntToStr(SIZES[LSizeIdx]);

    LSuite := TBenchSuite.Create('batch' + LSuffix)
      .SetMinDuration(TDuration.FromMilliseconds(200))
      .SetMaxIterations(100000)
      .SetMinSamples(10)
      .SetWarmupIters(1000);

    LSuite
      .Add('Sin/scalar' + LSuffix, @BenchSinScalar)
      .Add('Sin/simd' + LSuffix, @BenchSinSimd)
      .Add('Cos/scalar' + LSuffix, @BenchCosScalar)
      .Add('Cos/simd' + LSuffix, @BenchCosSimd)
      .Add('Tan/scalar' + LSuffix, @BenchTanScalar)
      .Add('Tan/simd' + LSuffix, @BenchTanSimd)
      .Add('SinCos/scalar' + LSuffix, @BenchSinCosScalar)
      .Add('SinCos/simd' + LSuffix, @BenchSinCosSimd)
      .Add('Sqrt/scalar' + LSuffix, @BenchSqrtScalar)
      .Add('Sqrt/simd' + LSuffix, @BenchSqrtSimd)
      .Add('Abs/scalar' + LSuffix, @BenchAbsScalar)
      .Add('Abs/simd' + LSuffix, @BenchAbsSimd)
      .Add('Neg/scalar' + LSuffix, @BenchNegScalar)
      .Add('Neg/simd' + LSuffix, @BenchNegSimd)
      .Add('Exp/scalar' + LSuffix, @BenchExpScalar)
      .Add('Exp/simd' + LSuffix, @BenchExpSimd)
      .Add('Log2/scalar' + LSuffix, @BenchLog2Scalar)
      .Add('Log2/simd' + LSuffix, @BenchLog2Simd)
      .Add('Log10/scalar' + LSuffix, @BenchLog10Scalar)
      .Add('Log10/simd' + LSuffix, @BenchLog10Simd)
      .Add('Ceil/scalar' + LSuffix, @BenchCeilScalar)
      .Add('Ceil/simd' + LSuffix, @BenchCeilSimd)
      .Add('Floor/scalar' + LSuffix, @BenchFloorScalar)
      .Add('Floor/simd' + LSuffix, @BenchFloorSimd)
      .Add('Round/scalar' + LSuffix, @BenchRoundScalar)
      .Add('Round/simd' + LSuffix, @BenchRoundSimd)
      .Add('Trunc/scalar' + LSuffix, @BenchTruncScalar)
      .Add('Trunc/simd' + LSuffix, @BenchTruncSimd)
      .Add('Lerp/scalar' + LSuffix, @BenchLerpScalar)
      .Add('Lerp/simd' + LSuffix, @BenchLerpSimd)
      .Add('Clamp/scalar' + LSuffix, @BenchClampScalar)
      .Add('Clamp/simd' + LSuffix, @BenchClampSimd);

    LResults := LSuite.Run;
    LAll := LResults.GetAll;

    { Print per-size detail table }
    WriteLn('--- N = ', SIZES[LSizeIdx], ' ---');
    WriteLn;
    WriteLn('  Operation       Scalar ns/op   SIMD ns/op     Speedup');
    WriteLn('  --------------------------------------------------------');

    for LOpIdx := 0 to NUM_OPS - 1 do
    begin
      LScalarName := OP_NAMES[LOpIdx] + '/scalar' + LSuffix;
      LSimdName := OP_NAMES[LOpIdx] + '/simd' + LSuffix;
      LScalarNs := FindNsPerOp(LAll, LScalarName);
      LSimdNs := FindNsPerOp(LAll, LSimdName);

      if LSimdNs > 0 then
        LSpeedup := LScalarNs / LSimdNs
      else
        LSpeedup := 0;

      { Store for summary }
      LSpeedupGrid[LOpIdx, LSizeIdx].ScalarNs := LScalarNs;
      LSpeedupGrid[LOpIdx, LSizeIdx].SimdNs := LSimdNs;
      LSpeedupGrid[LOpIdx, LSizeIdx].Speedup := LSpeedup;

      WriteLn(Format('  %-14s  %10.1f      %10.1f      %6.2fx',
        [OP_NAMES[LOpIdx], LScalarNs, LSimdNs, LSpeedup]));
    end;

    WriteLn('  --------------------------------------------------------');
    WriteLn;
  end;

  { --- Cross-size summary table --- }
  WriteLn('=== Speedup Summary Table ===');
  WriteLn;
  Write('  Operation     ');
  for LSizeIdx := 0 to NUM_SIZES - 1 do
    Write(Format('  N=%-6d', [SIZES[LSizeIdx]]));
  WriteLn;
  WriteLn('  -----------------------------------------------');

  for LOpIdx := 0 to NUM_OPS - 1 do
  begin
    Write(Format('  %-14s', [OP_NAMES[LOpIdx]]));
    for LSizeIdx := 0 to NUM_SIZES - 1 do
    begin
      LSpeedup := LSpeedupGrid[LOpIdx, LSizeIdx].Speedup;
      if LSpeedup > 0 then
        Write(Format('  %6.2fx', [LSpeedup]))
      else
        Write('     N/A');
    end;
    WriteLn;
  end;

  WriteLn('  -----------------------------------------------');
  WriteLn;
  WriteLn('Note: All operations use SIMD dispatch via Array* functions.');
  WriteLn('      Sin/Cos/Tan/Exp/Log2/Log10 use lookup tables or approximations.');
  WriteLn('      Ceil/Floor/Round/Trunc use SSE4.1 roundps instruction.');
  WriteLn('      SinCos computes both sin and cos in a single pass.');
  WriteLn;
  WriteLn('Done.');
end.
