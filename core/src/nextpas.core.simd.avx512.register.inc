procedure RegisterAVX512Backend;
var
  dispatchTable: TSimdDispatchTable;
  isAvailable: Boolean;
  LEnableVectorAsm: Boolean;
begin
  // Always register so the dispatch table can be inspected (e.g. on non-AVX-512 machines).
  // Runtime dispatch/forcing still prevents executing AVX-512 on unsupported CPUs.
  isAvailable := HasAVX512 and X86HasAVX512BackendRequiredFeatures(GetX86CPUInfo);
  LEnableVectorAsm := IsVectorAsmEnabled;

  // ✅ AVX-512 inherits all 128-bit and 256-bit operations from AVX2
  // This provides full coverage for F32x4, F64x2, I32x4, I64x2, F32x8, F64x4, etc.
  // AVX-512 only needs to override 512-bit operations and AVX-512-specific optimizations.
  dispatchTable := Default(TSimdDispatchTable);
  if not CloneDispatchTable(sbAVX2, dispatchTable) then
    FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbAVX512;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbAVX512;
    Name := 'AVX-512';
    Description := 'x86-64 AVX-512 SIMD implementation (512-bit)';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction,
                     scLoadStore];
    Include(Capabilities, scMaskedOps);
    if LEnableVectorAsm then
      Include(Capabilities, scShuffle);
    if LEnableVectorAsm then
      Include(Capabilities, scIntegerOps);
    if LEnableVectorAsm then
      Include(Capabilities, sc512BitOps);
    if LEnableVectorAsm then
      Include(Capabilities, scFMA);
    Available := isAvailable and LEnableVectorAsm;
    Priority := GetSimdBackendPriorityValue(sbAVX512);
  end;

  // Keep the cloned fallback table when vector asm is disabled so runtime
  // toggle/rebuild paths do not retain stale AVX-512 slots or capabilities.
  if LEnableVectorAsm then
  begin
    // Override facade functions with AVX-512 accelerated versions
    dispatchTable.Memory.Equal := @MemEqual_AVX512;
    dispatchTable.Memory.FindByte := @MemFindByte_AVX512;
    dispatchTable.Memory.SumBytes := @SumBytes_AVX512;
    dispatchTable.Memory.CountByte := @CountByte_AVX512;
    dispatchTable.Memory.MinMaxBytes := @MinMaxBytes_AVX512;
    dispatchTable.Memory.BitsetPopCount := @BitsetPopCount_AVX512;
    dispatchTable.Memory.Copy := @MemCopy_AVX512;
    dispatchTable.Memory.Fill := @MemSet_AVX512;
    dispatchTable.Memory.ToLowerAscii := @ToLowerAscii_AVX512;
    dispatchTable.Memory.ToUpperAscii := @ToUpperAscii_AVX512;
    dispatchTable.Memory.AsciiIEqual := @AsciiIEqual_AVX512;
    // Utf8Validate/MemReverse/MemDiffRange/BytesIndexOf keep the cloned AVX2 slots.

  // === 512-bit Vector Type Operations ===

  // F32x16 (512-bit float)
  dispatchTable.CoreVectors.AddF32x16 := @AVX512AddF32x16;
  dispatchTable.CoreVectors.SubF32x16 := @AVX512SubF32x16;
  dispatchTable.CoreVectors.MulF32x16 := @AVX512MulF32x16;
  dispatchTable.CoreVectors.DivF32x16 := @AVX512DivF32x16;

  dispatchTable.CoreVectors.LoadF32x16 := @AVX512LoadF32x16;
  dispatchTable.CoreVectors.StoreF32x16 := @AVX512StoreF32x16;
  dispatchTable.CoreVectors.SplatF32x16 := @AVX512SplatF32x16;
  dispatchTable.CoreVectors.ZeroF32x16 := @AVX512ZeroF32x16;
  dispatchTable.CoreVectors.SelectF32x16 := @AVX512SelectF32x16;

  // F64x8 (512-bit double)
  dispatchTable.CoreVectors.AddF64x8 := @AVX512AddF64x8;
  dispatchTable.CoreVectors.SubF64x8 := @AVX512SubF64x8;
  dispatchTable.CoreVectors.MulF64x8 := @AVX512MulF64x8;
  dispatchTable.CoreVectors.DivF64x8 := @AVX512DivF64x8;

  dispatchTable.CoreVectors.LoadF64x8 := @AVX512LoadF64x8;
  dispatchTable.CoreVectors.StoreF64x8 := @AVX512StoreF64x8;
  dispatchTable.CoreVectors.SplatF64x8 := @AVX512SplatF64x8;
  dispatchTable.CoreVectors.ZeroF64x8 := @AVX512ZeroF64x8;
  dispatchTable.CoreVectors.SelectF64x8 := @AVX512SelectF64x8;

  // I32x16 (512-bit integer) - Arithmetic
  dispatchTable.CoreVectors.AddI32x16 := @AVX512AddI32x16;
  dispatchTable.CoreVectors.SubI32x16 := @AVX512SubI32x16;
  dispatchTable.CoreVectors.MulI32x16 := @AVX512MulI32x16;

  // I32x16 (512-bit integer) - Bitwise
  dispatchTable.CoreVectors.AndI32x16 := @AVX512AndI32x16;
  dispatchTable.CoreVectors.OrI32x16 := @AVX512OrI32x16;
  dispatchTable.CoreVectors.XorI32x16 := @AVX512XorI32x16;
  dispatchTable.CoreVectors.NotI32x16 := @AVX512NotI32x16;
  dispatchTable.CoreVectors.AndNotI32x16 := @AVX512AndNotI32x16;

  // I32x16 (512-bit integer) - Shift
  dispatchTable.CoreVectors.ShiftLeftI32x16 := @AVX512ShiftLeftI32x16;
  dispatchTable.CoreVectors.ShiftRightI32x16 := @AVX512ShiftRightI32x16;
  dispatchTable.CoreVectors.ShiftRightArithI32x16 := @AVX512ShiftRightArithI32x16;

  // I32x16 (512-bit integer) - Comparison
  dispatchTable.CoreVectors.CmpEqI32x16 := @AVX512CmpEqI32x16;
  dispatchTable.CoreVectors.CmpLtI32x16 := @AVX512CmpLtI32x16;
  dispatchTable.CoreVectors.CmpGtI32x16 := @AVX512CmpGtI32x16;
  dispatchTable.CoreVectors.CmpLeI32x16 := @AVX512CmpLeI32x16;  // ✅ P0-1: 补充缺失
  dispatchTable.CoreVectors.CmpGeI32x16 := @AVX512CmpGeI32x16;  // ✅ P0-1: 补充缺失
  dispatchTable.CoreVectors.CmpNeI32x16 := @AVX512CmpNeI32x16;  // ✅ P0-1: 补充缺失

  // I32x16 (512-bit integer) - Min/Max
  dispatchTable.CoreVectors.MinI32x16 := @AVX512MinI32x16;
  dispatchTable.CoreVectors.MaxI32x16 := @AVX512MaxI32x16;

  // === I64x8 (512-bit 64-bit integer) ===
  dispatchTable.CoreVectors.AddI64x8 := @AVX512AddI64x8;
  dispatchTable.CoreVectors.SubI64x8 := @AVX512SubI64x8;
  dispatchTable.CoreVectors.AndI64x8 := @AVX512AndI64x8;
  dispatchTable.CoreVectors.OrI64x8 := @AVX512OrI64x8;
  dispatchTable.CoreVectors.XorI64x8 := @AVX512XorI64x8;
  dispatchTable.CoreVectors.NotI64x8 := @AVX512NotI64x8;
  dispatchTable.CoreVectors.CmpEqI64x8 := @AVX512CmpEqI64x8;
  dispatchTable.CoreVectors.CmpLtI64x8 := @AVX512CmpLtI64x8;
  dispatchTable.CoreVectors.CmpGtI64x8 := @AVX512CmpGtI64x8;
  dispatchTable.CoreVectors.CmpLeI64x8 := @AVX512CmpLeI64x8;
  dispatchTable.CoreVectors.CmpGeI64x8 := @AVX512CmpGeI64x8;
  dispatchTable.CoreVectors.CmpNeI64x8 := @AVX512CmpNeI64x8;

  // === U32x16 (512-bit unsigned integer) ===
  dispatchTable.CoreVectors.AddU32x16 := @AVX512AddU32x16;
  dispatchTable.CoreVectors.SubU32x16 := @AVX512SubU32x16;
  dispatchTable.CoreVectors.MulU32x16 := @AVX512MulU32x16;
  dispatchTable.CoreVectors.AndU32x16 := @AVX512AndU32x16;
  dispatchTable.CoreVectors.OrU32x16 := @AVX512OrU32x16;
  dispatchTable.CoreVectors.XorU32x16 := @AVX512XorU32x16;
  dispatchTable.CoreVectors.NotU32x16 := @AVX512NotU32x16;
  dispatchTable.CoreVectors.AndNotU32x16 := @AVX512AndNotU32x16;
  dispatchTable.CoreVectors.ShiftLeftU32x16 := @AVX512ShiftLeftU32x16;
  dispatchTable.CoreVectors.ShiftRightU32x16 := @AVX512ShiftRightU32x16;
  dispatchTable.CoreVectors.CmpEqU32x16 := @AVX512CmpEqU32x16;
  dispatchTable.CoreVectors.CmpLtU32x16 := @AVX512CmpLtU32x16;
  dispatchTable.CoreVectors.CmpGtU32x16 := @AVX512CmpGtU32x16;
  dispatchTable.CoreVectors.CmpLeU32x16 := @AVX512CmpLeU32x16;
  dispatchTable.CoreVectors.CmpGeU32x16 := @AVX512CmpGeU32x16;
  dispatchTable.CoreVectors.CmpNeU32x16 := @AVX512CmpNeU32x16;
  dispatchTable.CoreVectors.MinU32x16 := @AVX512MinU32x16;
  dispatchTable.CoreVectors.MaxU32x16 := @AVX512MaxU32x16;

  // === U64x8 (512-bit unsigned integer) ===
  dispatchTable.CoreVectors.AddU64x8 := @AVX512AddU64x8;
  dispatchTable.CoreVectors.SubU64x8 := @AVX512SubU64x8;
  dispatchTable.CoreVectors.AndU64x8 := @AVX512AndU64x8;
  dispatchTable.CoreVectors.OrU64x8 := @AVX512OrU64x8;
  dispatchTable.CoreVectors.XorU64x8 := @AVX512XorU64x8;
  dispatchTable.CoreVectors.NotU64x8 := @AVX512NotU64x8;
  dispatchTable.CoreVectors.ShiftLeftU64x8 := @AVX512ShiftLeftU64x8;
  dispatchTable.CoreVectors.ShiftRightU64x8 := @AVX512ShiftRightU64x8;
  dispatchTable.CoreVectors.CmpEqU64x8 := @AVX512CmpEqU64x8;
  dispatchTable.CoreVectors.CmpLtU64x8 := @AVX512CmpLtU64x8;
  dispatchTable.CoreVectors.CmpGtU64x8 := @AVX512CmpGtU64x8;
  dispatchTable.CoreVectors.CmpLeU64x8 := @AVX512CmpLeU64x8;
  dispatchTable.CoreVectors.CmpGeU64x8 := @AVX512CmpGeU64x8;
  dispatchTable.CoreVectors.CmpNeU64x8 := @AVX512CmpNeU64x8;

  // === I16x32 (512-bit signed integer) ===
  dispatchTable.CoreVectors.AddI16x32 := @AVX512AddI16x32;
  dispatchTable.CoreVectors.SubI16x32 := @AVX512SubI16x32;
  dispatchTable.CoreVectors.AndI16x32 := @AVX512AndI16x32;
  dispatchTable.CoreVectors.OrI16x32 := @AVX512OrI16x32;
  dispatchTable.CoreVectors.XorI16x32 := @AVX512XorI16x32;
  dispatchTable.CoreVectors.NotI16x32 := @AVX512NotI16x32;
  dispatchTable.CoreVectors.AndNotI16x32 := @AVX512AndNotI16x32;
  dispatchTable.CoreVectors.ShiftLeftI16x32 := @AVX512ShiftLeftI16x32;
  dispatchTable.CoreVectors.ShiftRightI16x32 := @AVX512ShiftRightI16x32;
  dispatchTable.CoreVectors.ShiftRightArithI16x32 := @AVX512ShiftRightArithI16x32;
  dispatchTable.CoreVectors.CmpEqI16x32 := @AVX512CmpEqI16x32;
  dispatchTable.CoreVectors.CmpLtI16x32 := @AVX512CmpLtI16x32;
  dispatchTable.CoreVectors.CmpGtI16x32 := @AVX512CmpGtI16x32;
  dispatchTable.CoreVectors.CmpLeI16x32 := @AVX512CmpLeI16x32;
  dispatchTable.CoreVectors.CmpGeI16x32 := @AVX512CmpGeI16x32;
  dispatchTable.CoreVectors.CmpNeI16x32 := @AVX512CmpNeI16x32;
  dispatchTable.CoreVectors.MinI16x32 := @AVX512MinI16x32;
  dispatchTable.CoreVectors.MaxI16x32 := @AVX512MaxI16x32;

  // === I8x64 (512-bit signed integer) ===
  dispatchTable.CoreVectors.AddI8x64 := @AVX512AddI8x64;
  dispatchTable.CoreVectors.SubI8x64 := @AVX512SubI8x64;
  dispatchTable.CoreVectors.AndI8x64 := @AVX512AndI8x64;
  dispatchTable.CoreVectors.OrI8x64 := @AVX512OrI8x64;
  dispatchTable.CoreVectors.XorI8x64 := @AVX512XorI8x64;
  dispatchTable.CoreVectors.NotI8x64 := @AVX512NotI8x64;
  dispatchTable.CoreVectors.AndNotI8x64 := @AVX512AndNotI8x64;
  dispatchTable.CoreVectors.CmpEqI8x64 := @AVX512CmpEqI8x64;
  dispatchTable.CoreVectors.CmpLtI8x64 := @AVX512CmpLtI8x64;
  dispatchTable.CoreVectors.CmpGtI8x64 := @AVX512CmpGtI8x64;
  dispatchTable.CoreVectors.CmpLeI8x64 := @AVX512CmpLeI8x64;
  dispatchTable.CoreVectors.CmpGeI8x64 := @AVX512CmpGeI8x64;
  dispatchTable.CoreVectors.CmpNeI8x64 := @AVX512CmpNeI8x64;
  dispatchTable.CoreVectors.MinI8x64 := @AVX512MinI8x64;
  dispatchTable.CoreVectors.MaxI8x64 := @AVX512MaxI8x64;

  // === U8x64 (512-bit unsigned integer) ===
  dispatchTable.CoreVectors.AddU8x64 := @AVX512AddU8x64;
  dispatchTable.CoreVectors.SubU8x64 := @AVX512SubU8x64;
  dispatchTable.CoreVectors.AndU8x64 := @AVX512AndU8x64;
  dispatchTable.CoreVectors.OrU8x64 := @AVX512OrU8x64;
  dispatchTable.CoreVectors.XorU8x64 := @AVX512XorU8x64;
  dispatchTable.CoreVectors.NotU8x64 := @AVX512NotU8x64;
  dispatchTable.CoreVectors.CmpEqU8x64 := @AVX512CmpEqU8x64;
  dispatchTable.CoreVectors.CmpLtU8x64 := @AVX512CmpLtU8x64;
  dispatchTable.CoreVectors.CmpGtU8x64 := @AVX512CmpGtU8x64;
  dispatchTable.CoreVectors.CmpLeU8x64 := @AVX512CmpLeU8x64;
  dispatchTable.CoreVectors.CmpGeU8x64 := @AVX512CmpGeU8x64;
  dispatchTable.CoreVectors.CmpNeU8x64 := @AVX512CmpNeU8x64;
  dispatchTable.CoreVectors.MinU8x64 := @AVX512MinU8x64;
  dispatchTable.CoreVectors.MaxU8x64 := @AVX512MaxU8x64;

  // === F32x16 Comparison Operations ===
  dispatchTable.CoreVectors.CmpEqF32x16 := @AVX512CmpEqF32x16;
  dispatchTable.CoreVectors.CmpLtF32x16 := @AVX512CmpLtF32x16;
  dispatchTable.CoreVectors.CmpLeF32x16 := @AVX512CmpLeF32x16;
  dispatchTable.CoreVectors.CmpGtF32x16 := @AVX512CmpGtF32x16;
  dispatchTable.CoreVectors.CmpGeF32x16 := @AVX512CmpGeF32x16;
  dispatchTable.CoreVectors.CmpNeF32x16 := @AVX512CmpNeF32x16;

  // === F64x8 Comparison Operations ===
  dispatchTable.CoreVectors.CmpEqF64x8 := @AVX512CmpEqF64x8;
  dispatchTable.CoreVectors.CmpLtF64x8 := @AVX512CmpLtF64x8;
  dispatchTable.CoreVectors.CmpLeF64x8 := @AVX512CmpLeF64x8;
  dispatchTable.CoreVectors.CmpGtF64x8 := @AVX512CmpGtF64x8;
  dispatchTable.CoreVectors.CmpGeF64x8 := @AVX512CmpGeF64x8;
  dispatchTable.CoreVectors.CmpNeF64x8 := @AVX512CmpNeF64x8;

  // === F32x16 Math Functions ===
  dispatchTable.CoreVectors.AbsF32x16 := @AVX512AbsF32x16;
  dispatchTable.CoreVectors.SqrtF32x16 := @AVX512SqrtF32x16;
  dispatchTable.CoreVectors.MinF32x16 := @AVX512MinF32x16;
  dispatchTable.CoreVectors.MaxF32x16 := @AVX512MaxF32x16;
  dispatchTable.CoreVectors.ClampF32x16 := @AVX512ClampF32x16;
  dispatchTable.CoreVectors.FmaF32x16 := @AVX512FmaF32x16;
  dispatchTable.CoreVectors.FloorF32x16 := @AVX512FloorF32x16;
  dispatchTable.CoreVectors.CeilF32x16 := @AVX512CeilF32x16;
  dispatchTable.CoreVectors.RoundF32x16 := @AVX512RoundF32x16;
  dispatchTable.CoreVectors.TruncF32x16 := @AVX512TruncF32x16;

  // === F64x8 Math Functions ===
  dispatchTable.CoreVectors.AbsF64x8 := @AVX512AbsF64x8;
  dispatchTable.CoreVectors.SqrtF64x8 := @AVX512SqrtF64x8;
  dispatchTable.CoreVectors.MinF64x8 := @AVX512MinF64x8;
  dispatchTable.CoreVectors.MaxF64x8 := @AVX512MaxF64x8;
  dispatchTable.CoreVectors.ClampF64x8 := @AVX512ClampF64x8;
  dispatchTable.CoreVectors.FmaF64x8 := @AVX512FmaF64x8;
  dispatchTable.CoreVectors.FloorF64x8 := @AVX512FloorF64x8;
  dispatchTable.CoreVectors.CeilF64x8 := @AVX512CeilF64x8;
  dispatchTable.CoreVectors.RoundF64x8 := @AVX512RoundF64x8;
  dispatchTable.CoreVectors.TruncF64x8 := @AVX512TruncF64x8;

  // === F32x16 Reduction Operations ===
  dispatchTable.CoreVectors.ReduceAddF32x16 := @AVX512ReduceAddF32x16;
  dispatchTable.CoreVectors.ReduceMinF32x16 := @AVX512ReduceMinF32x16;
  dispatchTable.CoreVectors.ReduceMaxF32x16 := @AVX512ReduceMaxF32x16;
  dispatchTable.CoreVectors.ReduceMulF32x16 := @AVX512ReduceMulF32x16;

  // === F64x8 Reduction Operations ===
  dispatchTable.CoreVectors.ReduceAddF64x8 := @AVX512ReduceAddF64x8;
  dispatchTable.CoreVectors.ReduceMinF64x8 := @AVX512ReduceMinF64x8;
  dispatchTable.CoreVectors.ReduceMaxF64x8 := @AVX512ReduceMaxF64x8;
  dispatchTable.CoreVectors.ReduceMulF64x8 := @AVX512ReduceMulF64x8;

  // === Mask16 Operations (shared scalar, ABI-safe) ===
  dispatchTable.Mask.Mask16All := @SharedMask16All;
  dispatchTable.Mask.Mask16Any := @SharedMask16Any;
  dispatchTable.Mask.Mask16None := @SharedMask16None;
  dispatchTable.Mask.Mask16PopCount := @AVX512Mask16PopCount;
  dispatchTable.Mask.Mask16FirstSet := @AVX512Mask16FirstSet;

  // ✅ P2: Saturating Arithmetic (EVEX-encoded, always enabled)
  dispatchTable.CoreVectors.I8x16SatAdd := @AVX512I8x16SatAdd;
  dispatchTable.CoreVectors.I8x16SatSub := @AVX512I8x16SatSub;
  dispatchTable.CoreVectors.I16x8SatAdd := @AVX512I16x8SatAdd;
  dispatchTable.CoreVectors.I16x8SatSub := @AVX512I16x8SatSub;
  dispatchTable.CoreVectors.U8x16SatAdd := @AVX512U8x16SatAdd;
  dispatchTable.CoreVectors.U8x16SatSub := @AVX512U8x16SatSub;
  dispatchTable.CoreVectors.U16x8SatAdd := @AVX512U16x8SatAdd;
  dispatchTable.CoreVectors.U16x8SatSub := @AVX512U16x8SatSub;

  end;

  // === Batch Array Operations (512-bit) ===
  dispatchTable.BatchF32.ArrayAdd := @AVX512ArrayAddF32;
  dispatchTable.BatchF32.ArraySub := @AVX512ArraySubF32;
  dispatchTable.BatchF32.ArrayMul := @AVX512ArrayMulF32;
  dispatchTable.BatchF32.ArrayDiv := @AVX512ArrayDivF32;
  dispatchTable.BatchF32.ArrayAbs := @AVX512ArrayAbsF32;
  dispatchTable.BatchF32.ArrayNeg := @AVX512ArrayNegF32;
  dispatchTable.BatchF32.ArraySqrt := @AVX512ArraySqrtF32;
  dispatchTable.BatchF32.ArrayRcp := @AVX512ArrayRcpF32;
  dispatchTable.BatchF32.ArrayRsqrt := @AVX512ArrayRsqrtF32;
  dispatchTable.BatchF32.ArrayRcpRefine := @AVX512ArrayRcpRefineF32;
  dispatchTable.BatchF32.ArrayRsqrtRefine := @AVX512ArrayRsqrtRefineF32;

  // Transcendental (ZMM, 16 floats/iter)
  dispatchTable.BatchF32.ArrayExp := @AVX512ArrayExpF32;
  dispatchTable.BatchF32.ArrayLog := @AVX512ArrayLogF32;
  dispatchTable.BatchF32.ArraySin := @AVX512ArraySinF32;
  dispatchTable.BatchF32.ArrayCos := @AVX512ArrayCosF32;
  dispatchTable.BatchF32.ArrayPow := @AVX512ArrayPowF32;

  // Fused (ZMM, single-pass)
  dispatchTable.BatchF32.ArrayLinear := @AVX512ArrayLinearF32;
  dispatchTable.BatchF32.ArrayAbsDiff := @AVX512ArrayAbsDiffF32;
  dispatchTable.BatchF32.ArrayReLU := @AVX512ArrayReLUF32;
  dispatchTable.BatchF32.ArrayNorm := @AVX512ArrayNormF32;
  dispatchTable.BatchF32.ArrayLinearReLU := @AVX512ArrayLinearReLUF32;

  // Scalar/Affine (ZMM broadcast)
  dispatchTable.BatchF32.ArrayAddScalar := @AVX512ArrayAddScalarF32;
  dispatchTable.BatchF32.ArrayMulScalar := @AVX512ArrayMulScalarF32;
  dispatchTable.BatchF32.ArrayClamp := @AVX512ArrayClampF32;
  dispatchTable.BatchF32.ArrayFma := @AVX512ArrayFmaF32;
  dispatchTable.BatchF32.ArrayAxpy := @AVX512ArrayAxpyF32;

  // Min/Max (ZMM element-wise)
  dispatchTable.BatchF32.ArrayMin := @AVX512ArrayMinF32;
  dispatchTable.BatchF32.ArrayMax := @AVX512ArrayMaxF32;

  // Reductions (ZMM accumulators → horizontal reduce)
  dispatchTable.BatchF32.ReduceSum := @AVX512ReduceSumF32;
  dispatchTable.BatchF32.ReduceDot := @AVX512ReduceDotF32;
  dispatchTable.BatchF32.ReduceMin := @AVX512ReduceMinF32;
  dispatchTable.BatchF32.ReduceMax := @AVX512ReduceMaxF32;

  // === F64 Batch Array Operations (ZMM, 8 doubles/iter) ===
  dispatchTable.BatchF64.ArrayAdd := @AVX512ArrayAddF64;
  dispatchTable.BatchF64.ArraySub := @AVX512ArraySubF64;
  dispatchTable.BatchF64.ArrayMul := @AVX512ArrayMulF64;
  dispatchTable.BatchF64.ArrayDiv := @AVX512ArrayDivF64;
  dispatchTable.BatchF64.ArrayAbs := @AVX512ArrayAbsF64;
  dispatchTable.BatchF64.ArrayNeg := @AVX512ArrayNegF64;
  dispatchTable.BatchF64.ArraySqrt := @AVX512ArraySqrtF64;

  // F64 Reductions (ZMM accumulators)
  dispatchTable.BatchF64.ReduceSum := @AVX512ReduceSumF64;
  dispatchTable.BatchF64.ReduceDot := @AVX512ReduceDotF64;
  dispatchTable.BatchF64.ReduceMin := @AVX512ReduceMinF64;
  dispatchTable.BatchF64.ReduceMax := @AVX512ReduceMaxF64;

  // F64 Scalar/Affine (ZMM broadcast)
  dispatchTable.BatchF64.ArrayMulScalar := @AVX512ArrayMulScalarF64;
  dispatchTable.BatchF64.ArrayAddScalar := @AVX512ArrayAddScalarF64;
  dispatchTable.BatchF64.ArrayClamp := @AVX512ArrayClampF64;
  dispatchTable.BatchF64.ArrayLinear := @AVX512ArrayLinearF64;
  dispatchTable.BatchF64.ArrayMin := @AVX512ArrayMinF64;
  dispatchTable.BatchF64.ArrayMax := @AVX512ArrayMaxF64;
  dispatchTable.BatchF64.ArrayFma := @AVX512ArrayFmaF64;

  // === Integer Batch (512-bit / 16 x Int32) ===
  dispatchTable.BatchInteger.ArrayAddI32 := @AVX512ArrayAddI32;
  dispatchTable.BatchInteger.ArraySubI32 := @AVX512ArraySubI32;

  // Register the backend
  RegisterBackend(sbAVX512, dispatchTable);
end;

initialization
  RegisterAVX512Backend;
  // ✅ P1-D: Register rebuilder callback for VectorAsmEnabled changes
  RegisterBackendRebuilder(sbAVX512, @RegisterAVX512Backend);
