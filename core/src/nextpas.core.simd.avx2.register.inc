procedure RegisterAVX2Backend;
var
  dispatchTable: TSimdDispatchTable;
  LEnableVectorAsm: Boolean;
  LHasHardwareFma: Boolean;
begin
  // Only register if AVX2 is available
  if not HasAVX2 then
    Exit;

  // You can enable AVX2 vector ops for experimentation via SetVectorAsmEnabled(True)
  // (note: AVX2 asm path is not yet fully validated under FPC's calling conventions).
  LEnableVectorAsm := IsVectorAsmEnabled;
  {$IFDEF WINDOWS}
  // Win64 lane: keep AVX2 registered, but avoid vector-asm path until ABI validation is complete.
  LEnableVectorAsm := False;
  {$ENDIF}
  LHasHardwareFma := HasFeature(gfFMA);

  // Fill with base scalar implementations (provides fallback for all operations)
  dispatchTable := Default(TSimdDispatchTable);
  FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbAVX2;
  dispatchTable.BackendInfo.Backend := sbAVX2;
  dispatchTable.BackendInfo.Name := 'AVX2';
  dispatchTable.BackendInfo.Description := 'x86-64 AVX2 SIMD implementation (256-bit)';
  dispatchTable.BackendInfo.Capabilities := [scBasicArithmetic, scComparison, scMathFunctions,
                                             scReduction, scLoadStore];
  Include(dispatchTable.BackendInfo.Capabilities, scMaskedOps);
  if LEnableVectorAsm then
    Include(dispatchTable.BackendInfo.Capabilities, scShuffle);
  if LEnableVectorAsm then
    Include(dispatchTable.BackendInfo.Capabilities, scIntegerOps);
  if LEnableVectorAsm and LHasHardwareFma then
    Include(dispatchTable.BackendInfo.Capabilities, scFMA);
  dispatchTable.BackendInfo.Available := LEnableVectorAsm;
  dispatchTable.BackendInfo.Priority := GetSimdBackendPriorityValue(sbAVX2);

  if LEnableVectorAsm then
  begin
    // Override with AVX2 arithmetic operations
    dispatchTable.AddF32x4 := @AVX2AddF32x4;
    dispatchTable.SubF32x4 := @AVX2SubF32x4;
    dispatchTable.MulF32x4 := @AVX2MulF32x4;
    dispatchTable.DivF32x4 := @AVX2DivF32x4;

    dispatchTable.AddF32x8 := @AVX2AddF32x8;
    dispatchTable.SubF32x8 := @AVX2SubF32x8;
    dispatchTable.MulF32x8 := @AVX2MulF32x8;
    dispatchTable.DivF32x8 := @AVX2DivF32x8;

    dispatchTable.AddF64x2 := @AVX2AddF64x2;
    dispatchTable.SubF64x2 := @AVX2SubF64x2;
    dispatchTable.MulF64x2 := @AVX2MulF64x2;
    dispatchTable.DivF64x2 := @AVX2DivF64x2;

    dispatchTable.AddI32x4 := @AVX2AddI32x4;
    dispatchTable.SubI32x4 := @AVX2SubI32x4;
    dispatchTable.MulI32x4 := @AVX2MulI32x4;
    // I32x4 Bitwise operations
    dispatchTable.AndI32x4 := @AVX2AndI32x4;
    dispatchTable.OrI32x4 := @AVX2OrI32x4;
    dispatchTable.XorI32x4 := @AVX2XorI32x4;
    dispatchTable.NotI32x4 := @AVX2NotI32x4;
    dispatchTable.AndNotI32x4 := @AVX2AndNotI32x4;
    // I32x4 Shift operations
    dispatchTable.ShiftLeftI32x4 := @AVX2ShiftLeftI32x4;
    dispatchTable.ShiftRightI32x4 := @AVX2ShiftRightI32x4;
    dispatchTable.ShiftRightArithI32x4 := @AVX2ShiftRightArithI32x4;
    // I32x4 Comparison operations
    dispatchTable.CmpEqI32x4 := @AVX2CmpEqI32x4;
    dispatchTable.CmpLtI32x4 := @AVX2CmpLtI32x4;
    dispatchTable.CmpGtI32x4 := @AVX2CmpGtI32x4;
    dispatchTable.CmpLeI32x4 := @AVX2CmpLeI32x4;
    dispatchTable.CmpGeI32x4 := @AVX2CmpGeI32x4;
    dispatchTable.CmpNeI32x4 := @AVX2CmpNeI32x4;
    // I32x4 Min/Max operations
    dispatchTable.MinI32x4 := @AVX2MinI32x4;
    dispatchTable.MaxI32x4 := @AVX2MaxI32x4;

    // I16x8 Arithmetic operations
    dispatchTable.AddI16x8 := @AVX2AddI16x8;
    dispatchTable.SubI16x8 := @AVX2SubI16x8;
    dispatchTable.MulI16x8 := @AVX2MulI16x8;
    // I16x8 Bitwise operations
    dispatchTable.AndI16x8 := @AVX2AndI16x8;
    dispatchTable.OrI16x8 := @AVX2OrI16x8;
    dispatchTable.XorI16x8 := @AVX2XorI16x8;
    dispatchTable.NotI16x8 := @AVX2NotI16x8;
    dispatchTable.AndNotI16x8 := @AVX2AndNotI16x8;
    // I16x8 Shift operations
    dispatchTable.ShiftLeftI16x8 := @AVX2ShiftLeftI16x8;
    dispatchTable.ShiftRightI16x8 := @AVX2ShiftRightI16x8;
    dispatchTable.ShiftRightArithI16x8 := @AVX2ShiftRightArithI16x8;
    // I16x8 Comparison operations
    dispatchTable.CmpEqI16x8 := @AVX2CmpEqI16x8;
    dispatchTable.CmpLtI16x8 := @AVX2CmpLtI16x8;
    dispatchTable.CmpGtI16x8 := @AVX2CmpGtI16x8;
    dispatchTable.CmpLeI16x8 := @AVX2CmpLeI16x8;
    dispatchTable.CmpGeI16x8 := @AVX2CmpGeI16x8;
    dispatchTable.CmpNeI16x8 := @AVX2CmpNeI16x8;
    // I16x8 Min/Max operations
    dispatchTable.MinI16x8 := @AVX2MinI16x8;
    dispatchTable.MaxI16x8 := @AVX2MaxI16x8;

    // I8x16 Arithmetic operations
    dispatchTable.AddI8x16 := @AVX2AddI8x16;
    dispatchTable.SubI8x16 := @AVX2SubI8x16;
    // I8x16 Bitwise operations
    dispatchTable.AndI8x16 := @AVX2AndI8x16;
    dispatchTable.OrI8x16 := @AVX2OrI8x16;
    dispatchTable.XorI8x16 := @AVX2XorI8x16;
    dispatchTable.NotI8x16 := @AVX2NotI8x16;
    dispatchTable.AndNotI8x16 := @AVX2AndNotI8x16;
    // I8x16 Comparison operations
    dispatchTable.CmpEqI8x16 := @AVX2CmpEqI8x16;
    dispatchTable.CmpLtI8x16 := @AVX2CmpLtI8x16;
    dispatchTable.CmpGtI8x16 := @AVX2CmpGtI8x16;
    dispatchTable.CmpLeI8x16 := @AVX2CmpLeI8x16;
    dispatchTable.CmpGeI8x16 := @AVX2CmpGeI8x16;
    dispatchTable.CmpNeI8x16 := @AVX2CmpNeI8x16;
    // I8x16 Min/Max operations
    dispatchTable.MinI8x16 := @AVX2MinI8x16;
    dispatchTable.MaxI8x16 := @AVX2MaxI8x16;

    // U32x4 Arithmetic operations
    dispatchTable.AddU32x4 := @AVX2AddU32x4;
    dispatchTable.SubU32x4 := @AVX2SubU32x4;
    dispatchTable.MulU32x4 := @AVX2MulU32x4;
    // U32x4 Bitwise operations
    dispatchTable.AndU32x4 := @AVX2AndU32x4;
    dispatchTable.OrU32x4 := @AVX2OrU32x4;
    dispatchTable.XorU32x4 := @AVX2XorU32x4;
    dispatchTable.NotU32x4 := @AVX2NotU32x4;
    dispatchTable.AndNotU32x4 := @AVX2AndNotU32x4;
    // U32x4 Shift operations
    dispatchTable.ShiftLeftU32x4 := @AVX2ShiftLeftU32x4;
    dispatchTable.ShiftRightU32x4 := @AVX2ShiftRightU32x4;
    // U32x4 Comparison operations
    dispatchTable.CmpEqU32x4 := @AVX2CmpEqU32x4;
    dispatchTable.CmpLtU32x4 := @AVX2CmpLtU32x4;
    dispatchTable.CmpGtU32x4 := @AVX2CmpGtU32x4;
    dispatchTable.CmpLeU32x4 := @AVX2CmpLeU32x4;
    dispatchTable.CmpGeU32x4 := @AVX2CmpGeU32x4;
    // U32x4 Min/Max operations
    dispatchTable.MinU32x4 := @AVX2MinU32x4;
    dispatchTable.MaxU32x4 := @AVX2MaxU32x4;

    // U16x8 Arithmetic operations
    dispatchTable.AddU16x8 := @AVX2AddU16x8;
    dispatchTable.SubU16x8 := @AVX2SubU16x8;
    dispatchTable.MulU16x8 := @AVX2MulU16x8;
    // U16x8 Bitwise operations
    dispatchTable.AndU16x8 := @AVX2AndU16x8;
    dispatchTable.OrU16x8 := @AVX2OrU16x8;
    dispatchTable.XorU16x8 := @AVX2XorU16x8;
    dispatchTable.NotU16x8 := @AVX2NotU16x8;
    dispatchTable.AndNotU16x8 := @AVX2AndNotU16x8;
    // U16x8 Shift operations
    dispatchTable.ShiftLeftU16x8 := @AVX2ShiftLeftU16x8;
    dispatchTable.ShiftRightU16x8 := @AVX2ShiftRightU16x8;
    // U16x8 Comparison operations
    dispatchTable.CmpEqU16x8 := @AVX2CmpEqU16x8;
    dispatchTable.CmpLtU16x8 := @AVX2CmpLtU16x8;
    dispatchTable.CmpGtU16x8 := @AVX2CmpGtU16x8;
    dispatchTable.CmpLeU16x8 := @AVX2CmpLeU16x8;
    dispatchTable.CmpGeU16x8 := @AVX2CmpGeU16x8;
    dispatchTable.CmpNeU16x8 := @AVX2CmpNeU16x8;
    // U16x8 Min/Max operations
    dispatchTable.MinU16x8 := @AVX2MinU16x8;
    dispatchTable.MaxU16x8 := @AVX2MaxU16x8;

    // U8x16 Arithmetic operations
    dispatchTable.AddU8x16 := @AVX2AddU8x16;
    dispatchTable.SubU8x16 := @AVX2SubU8x16;
    // U8x16 Bitwise operations
    dispatchTable.AndU8x16 := @AVX2AndU8x16;
    dispatchTable.OrU8x16 := @AVX2OrU8x16;
    dispatchTable.XorU8x16 := @AVX2XorU8x16;
    dispatchTable.NotU8x16 := @AVX2NotU8x16;
    dispatchTable.AndNotU8x16 := @AVX2AndNotU8x16;
    // U8x16 Comparison operations
    dispatchTable.CmpEqU8x16 := @AVX2CmpEqU8x16;
    dispatchTable.CmpLtU8x16 := @AVX2CmpLtU8x16;
    dispatchTable.CmpGtU8x16 := @AVX2CmpGtU8x16;
    dispatchTable.CmpLeU8x16 := @AVX2CmpLeU8x16;
    dispatchTable.CmpGeU8x16 := @AVX2CmpGeU8x16;
    dispatchTable.CmpNeU8x16 := @AVX2CmpNeU8x16;
    // U8x16 Min/Max operations
    dispatchTable.MinU8x16 := @AVX2MinU8x16;
    dispatchTable.MaxU8x16 := @AVX2MaxU8x16;

    // I64x2 arithmetic, bitwise, compare, shift, min/max
    dispatchTable.AddI64x2 := @AVX2AddI64x2;
    dispatchTable.SubI64x2 := @AVX2SubI64x2;
    dispatchTable.AndI64x2 := @AVX2AndI64x2;
    dispatchTable.OrI64x2 := @AVX2OrI64x2;
    dispatchTable.XorI64x2 := @AVX2XorI64x2;
    dispatchTable.NotI64x2 := @AVX2NotI64x2;
    dispatchTable.AndNotI64x2 := @AVX2AndNotI64x2;
    dispatchTable.ShiftLeftI64x2 := @AVX2ShiftLeftI64x2;
    dispatchTable.ShiftRightI64x2 := @AVX2ShiftRightI64x2;
    dispatchTable.ShiftRightArithI64x2 := @AVX2ShiftRightArithI64x2;
    dispatchTable.CmpEqI64x2 := @AVX2CmpEqI64x2;
    dispatchTable.CmpLtI64x2 := @AVX2CmpLtI64x2;
    dispatchTable.CmpGtI64x2 := @AVX2CmpGtI64x2;
    dispatchTable.CmpLeI64x2 := @AVX2CmpLeI64x2;
    dispatchTable.CmpGeI64x2 := @AVX2CmpGeI64x2;
    dispatchTable.CmpNeI64x2 := @AVX2CmpNeI64x2;
    dispatchTable.MinI64x2 := @AVX2MinI64x2;
    dispatchTable.MaxI64x2 := @AVX2MaxI64x2;

    // U64x2 arithmetic/bitwise/compare/minmax
    dispatchTable.AddU64x2 := @AVX2AddU64x2;
    dispatchTable.SubU64x2 := @AVX2SubU64x2;
    dispatchTable.AndU64x2 := @AVX2AndU64x2;
    dispatchTable.OrU64x2 := @AVX2OrU64x2;
    dispatchTable.XorU64x2 := @AVX2XorU64x2;
    dispatchTable.NotU64x2 := @AVX2NotU64x2;
    dispatchTable.AndNotU64x2 := @AVX2AndNotU64x2;
    dispatchTable.CmpEqU64x2 := @AVX2CmpEqU64x2;
    dispatchTable.CmpLtU64x2 := @AVX2CmpLtU64x2;
    dispatchTable.CmpGtU64x2 := @AVX2CmpGtU64x2;
    dispatchTable.MinU64x2 := @AVX2MinU64x2;
    dispatchTable.MaxU64x2 := @AVX2MaxU64x2;

    // F64x4 (256-bit AVX)
    dispatchTable.AddF64x4 := @AVX2AddF64x4;
    dispatchTable.SubF64x4 := @AVX2SubF64x4;
    dispatchTable.MulF64x4 := @AVX2MulF64x4;
    dispatchTable.DivF64x4 := @AVX2DivF64x4;

    // I32x8 (256-bit AVX2)
    dispatchTable.AddI32x8 := @AVX2AddI32x8;
    dispatchTable.SubI32x8 := @AVX2SubI32x8;
    dispatchTable.MulI32x8 := @AVX2MulI32x8;
    dispatchTable.AndI32x8 := @AVX2AndI32x8;
    dispatchTable.OrI32x8 := @AVX2OrI32x8;
    dispatchTable.XorI32x8 := @AVX2XorI32x8;
    dispatchTable.NotI32x8 := @AVX2NotI32x8;
    dispatchTable.AndNotI32x8 := @AVX2AndNotI32x8;
    dispatchTable.ShiftLeftI32x8 := @AVX2ShiftLeftI32x8;
    dispatchTable.ShiftRightI32x8 := @AVX2ShiftRightI32x8;
    dispatchTable.ShiftRightArithI32x8 := @AVX2ShiftRightArithI32x8;
    dispatchTable.CmpEqI32x8 := @AVX2CmpEqI32x8;
    dispatchTable.CmpLtI32x8 := @AVX2CmpLtI32x8;
    dispatchTable.CmpGtI32x8 := @AVX2CmpGtI32x8;
    dispatchTable.CmpLeI32x8 := @AVX2CmpLeI32x8;
    dispatchTable.CmpGeI32x8 := @AVX2CmpGeI32x8;
    dispatchTable.CmpNeI32x8 := @AVX2CmpNeI32x8;
    dispatchTable.MinI32x8 := @AVX2MinI32x8;
    dispatchTable.MaxI32x8 := @AVX2MaxI32x8;

    // I64x4 Operations (256-bit AVX2)
    dispatchTable.AddI64x4 := @AVX2AddI64x4;
    dispatchTable.SubI64x4 := @AVX2SubI64x4;
    dispatchTable.AndI64x4 := @AVX2AndI64x4;
    dispatchTable.OrI64x4 := @AVX2OrI64x4;
    dispatchTable.XorI64x4 := @AVX2XorI64x4;
    dispatchTable.NotI64x4 := @AVX2NotI64x4;
    dispatchTable.AndNotI64x4 := @AVX2AndNotI64x4;
    dispatchTable.ShiftLeftI64x4 := @AVX2ShiftLeftI64x4;
    dispatchTable.ShiftRightI64x4 := @AVX2ShiftRightI64x4;
    dispatchTable.CmpEqI64x4 := @AVX2CmpEqI64x4;
    dispatchTable.CmpLtI64x4 := @AVX2CmpLtI64x4;
    dispatchTable.CmpGtI64x4 := @AVX2CmpGtI64x4;
    dispatchTable.CmpLeI64x4 := @AVX2CmpLeI64x4;
    dispatchTable.CmpGeI64x4 := @AVX2CmpGeI64x4;
    dispatchTable.CmpNeI64x4 := @AVX2CmpNeI64x4;
    dispatchTable.LoadI64x4 := @AVX2LoadI64x4;
    dispatchTable.StoreI64x4 := @AVX2StoreI64x4;
    dispatchTable.SplatI64x4 := @AVX2SplatI64x4;
    dispatchTable.ZeroI64x4 := @AVX2ZeroI64x4;

    // U32x8 Operations (256-bit AVX2)
    dispatchTable.AddU32x8 := @AVX2AddU32x8;
    dispatchTable.SubU32x8 := @AVX2SubU32x8;
    dispatchTable.MulU32x8 := @AVX2MulU32x8;
    dispatchTable.AndU32x8 := @AVX2AndU32x8;
    dispatchTable.OrU32x8 := @AVX2OrU32x8;
    dispatchTable.XorU32x8 := @AVX2XorU32x8;
    dispatchTable.NotU32x8 := @AVX2NotU32x8;
    dispatchTable.AndNotU32x8 := @AVX2AndNotU32x8;
    dispatchTable.ShiftLeftU32x8 := @AVX2ShiftLeftU32x8;
    dispatchTable.ShiftRightU32x8 := @AVX2ShiftRightU32x8;
    dispatchTable.CmpEqU32x8 := @AVX2CmpEqU32x8;
    dispatchTable.CmpLtU32x8 := @AVX2CmpLtU32x8;
    dispatchTable.CmpGtU32x8 := @AVX2CmpGtU32x8;
    dispatchTable.CmpLeU32x8 := @AVX2CmpLeU32x8;
    dispatchTable.CmpGeU32x8 := @AVX2CmpGeU32x8;
    dispatchTable.CmpNeU32x8 := @AVX2CmpNeU32x8;
    dispatchTable.MinU32x8 := @AVX2MinU32x8;
    dispatchTable.MaxU32x8 := @AVX2MaxU32x8;

    // U64x4 Operations (256-bit AVX2)
    dispatchTable.AddU64x4 := @AVX2AddU64x4;
    dispatchTable.SubU64x4 := @AVX2SubU64x4;
    dispatchTable.AndU64x4 := @AVX2AndU64x4;
    dispatchTable.OrU64x4 := @AVX2OrU64x4;
    dispatchTable.XorU64x4 := @AVX2XorU64x4;
    dispatchTable.NotU64x4 := @AVX2NotU64x4;
    dispatchTable.ShiftLeftU64x4 := @AVX2ShiftLeftU64x4;
    dispatchTable.ShiftRightU64x4 := @AVX2ShiftRightU64x4;
    dispatchTable.CmpEqU64x4 := @AVX2CmpEqU64x4;
    dispatchTable.CmpLtU64x4 := @AVX2CmpLtU64x4;
    dispatchTable.CmpGtU64x4 := @AVX2CmpGtU64x4;
    dispatchTable.CmpLeU64x4 := @AVX2CmpLeU64x4;
    dispatchTable.CmpGeU64x4 := @AVX2CmpGeU64x4;
    dispatchTable.CmpNeU64x4 := @AVX2CmpNeU64x4;

    // Benchmark-targeted 512-bit wide emulation on AVX2
    dispatchTable.AddI16x32 := @AVX2AddI16x32;
    dispatchTable.MulU32x16 := @AVX2MulU32x16;
    dispatchTable.AddU64x8 := @AVX2AddU64x8;
    dispatchTable.MaxU8x64 := @AVX2MaxU8x64;

    // F64x4 Extended Math
    dispatchTable.RcpF64x4 := @AVX2RcpF64x4;

    // Override with AVX2 comparison operations
    dispatchTable.CmpEqF32x4 := @AVX2CmpEqF32x4;
    dispatchTable.CmpLtF32x4 := @AVX2CmpLtF32x4;
    dispatchTable.CmpLeF32x4 := @AVX2CmpLeF32x4;
    dispatchTable.CmpGtF32x4 := @AVX2CmpGtF32x4;
    dispatchTable.CmpGeF32x4 := @AVX2CmpGeF32x4;
    dispatchTable.CmpNeF32x4 := @AVX2CmpNeF32x4;

    // F32x8 Comparison (256-bit)
    dispatchTable.CmpEqF32x8 := @AVX2CmpEqF32x8;
    dispatchTable.CmpLtF32x8 := @AVX2CmpLtF32x8;
    dispatchTable.CmpLeF32x8 := @AVX2CmpLeF32x8;
    dispatchTable.CmpGtF32x8 := @AVX2CmpGtF32x8;
    dispatchTable.CmpGeF32x8 := @AVX2CmpGeF32x8;
    dispatchTable.CmpNeF32x8 := @AVX2CmpNeF32x8;

    // F64x4 Comparison (256-bit)
    dispatchTable.CmpEqF64x4 := @AVX2CmpEqF64x4;
    dispatchTable.CmpLtF64x4 := @AVX2CmpLtF64x4;
    dispatchTable.CmpLeF64x4 := @AVX2CmpLeF64x4;
    dispatchTable.CmpGtF64x4 := @AVX2CmpGtF64x4;
    dispatchTable.CmpGeF64x4 := @AVX2CmpGeF64x4;
    dispatchTable.CmpNeF64x4 := @AVX2CmpNeF64x4;

    // Override with AVX2 math functions
    dispatchTable.AbsF32x4 := @AVX2AbsF32x4;
    dispatchTable.SqrtF32x4 := @AVX2SqrtF32x4;
    dispatchTable.MinF32x4 := @AVX2MinF32x4;
    dispatchTable.MaxF32x4 := @AVX2MaxF32x4;

    // Override with AVX2 extended math functions
    if LHasHardwareFma then
      dispatchTable.FmaF32x4 := @AVX2FmaF32x4;
    dispatchTable.RcpF32x4 := @AVX2RcpF32x4;
    dispatchTable.RsqrtF32x4 := @AVX2RsqrtF32x4;
    dispatchTable.FloorF32x4 := @AVX2FloorF32x4;
    dispatchTable.CeilF32x4 := @AVX2CeilF32x4;
    dispatchTable.RoundF32x4 := @AVX2RoundF32x4;
    dispatchTable.TruncF32x4 := @AVX2TruncF32x4;
    dispatchTable.ClampF32x4 := @AVX2ClampF32x4;

    // Override with AVX2 vector math functions
    dispatchTable.DotF32x4 := @AVX2DotF32x4;
    dispatchTable.DotF32x3 := @AVX2DotF32x3;
    dispatchTable.CrossF32x3 := @AVX2CrossF32x3;
    dispatchTable.LengthF32x4 := @AVX2LengthF32x4;
    dispatchTable.LengthF32x3 := @AVX2LengthF32x3;
    dispatchTable.NormalizeF32x4 := @AVX2NormalizeF32x4;

    // FMA-optimized Dot Product
    dispatchTable.DotF32x8 := @AVX2DotF32x8;
    dispatchTable.DotF64x2 := @AVX2DotF64x2;
    dispatchTable.DotF64x4 := @AVX2DotF64x4;
    dispatchTable.NormalizeF32x3 := @AVX2NormalizeF32x3;

    // Override with AVX2 reduction operations
    dispatchTable.ReduceAddF32x4 := @AVX2ReduceAddF32x4;
    dispatchTable.ReduceMinF32x4 := @AVX2ReduceMinF32x4;
    dispatchTable.ReduceMaxF32x4 := @AVX2ReduceMaxF32x4;
    dispatchTable.ReduceMulF32x4 := @AVX2ReduceMulF32x4;

    // F64x2 Math (128-bit)
    dispatchTable.AbsF64x2 := @AVX2AbsF64x2;
    dispatchTable.SqrtF64x2 := @AVX2SqrtF64x2;
    dispatchTable.MinF64x2 := @AVX2MinF64x2;
    dispatchTable.MaxF64x2 := @AVX2MaxF64x2;
    dispatchTable.ClampF64x2 := @AVX2ClampF64x2;

    // F64x2 Reduction (128-bit)
    dispatchTable.ReduceAddF64x2 := @AVX2ReduceAddF64x2;
    dispatchTable.ReduceMinF64x2 := @AVX2ReduceMinF64x2;
    dispatchTable.ReduceMaxF64x2 := @AVX2ReduceMaxF64x2;
    dispatchTable.ReduceMulF64x2 := @AVX2ReduceMulF64x2;

    // F64x2 Comparison (128-bit)
    dispatchTable.CmpEqF64x2 := @AVX2CmpEqF64x2;
    dispatchTable.CmpLtF64x2 := @AVX2CmpLtF64x2;
    dispatchTable.CmpLeF64x2 := @AVX2CmpLeF64x2;
    dispatchTable.CmpGtF64x2 := @AVX2CmpGtF64x2;
    dispatchTable.CmpGeF64x2 := @AVX2CmpGeF64x2;
    dispatchTable.CmpNeF64x2 := @AVX2CmpNeF64x2;

    // F64x2 Extended Math (128-bit)
    if LHasHardwareFma then
      dispatchTable.FmaF64x2 := @AVX2FmaF64x2;
    dispatchTable.FloorF64x2 := @AVX2FloorF64x2;
    dispatchTable.CeilF64x2 := @AVX2CeilF64x2;
    dispatchTable.RoundF64x2 := @AVX2RoundF64x2;
    dispatchTable.TruncF64x2 := @AVX2TruncF64x2;

    // F64x2 Load/Store/Splat/Zero (128-bit)
    dispatchTable.LoadF64x2 := @AVX2LoadF64x2;
    dispatchTable.StoreF64x2 := @AVX2StoreF64x2;
    dispatchTable.SplatF64x2 := @AVX2SplatF64x2;
    dispatchTable.ZeroF64x2 := @AVX2ZeroF64x2;

    // F32x8 Math (256-bit AVX)
    dispatchTable.AbsF32x8 := @AVX2AbsF32x8;
    dispatchTable.SqrtF32x8 := @AVX2SqrtF32x8;
    dispatchTable.MinF32x8 := @AVX2MinF32x8;
    dispatchTable.MaxF32x8 := @AVX2MaxF32x8;
    dispatchTable.ClampF32x8 := @AVX2ClampF32x8;

    // F32x8 Reduction (256-bit AVX)
    dispatchTable.ReduceAddF32x8 := @AVX2ReduceAddF32x8;
    dispatchTable.ReduceMinF32x8 := @AVX2ReduceMinF32x8;
    dispatchTable.ReduceMaxF32x8 := @AVX2ReduceMaxF32x8;
    dispatchTable.ReduceMulF32x8 := @AVX2ReduceMulF32x8;

    // F32x8 Extended Math (256-bit AVX)
    if LHasHardwareFma then
      dispatchTable.FmaF32x8 := @AVX2FmaF32x8;
    dispatchTable.FloorF32x8 := @AVX2FloorF32x8;
    dispatchTable.CeilF32x8 := @AVX2CeilF32x8;
    dispatchTable.RoundF32x8 := @AVX2RoundF32x8;
    dispatchTable.TruncF32x8 := @AVX2TruncF32x8;

    // F32x8 Load/Store/Splat/Zero (256-bit AVX)
    dispatchTable.LoadF32x8 := @AVX2LoadF32x8;
    dispatchTable.StoreF32x8 := @AVX2StoreF32x8;
    dispatchTable.SplatF32x8 := @AVX2SplatF32x8;
    dispatchTable.ZeroF32x8 := @AVX2ZeroF32x8;

    // F64x4 Math (256-bit AVX)
    dispatchTable.AbsF64x4 := @AVX2AbsF64x4;
    dispatchTable.SqrtF64x4 := @AVX2SqrtF64x4;
    dispatchTable.MinF64x4 := @AVX2MinF64x4;
    dispatchTable.MaxF64x4 := @AVX2MaxF64x4;
    dispatchTable.ClampF64x4 := @AVX2ClampF64x4;

    // F64x4 Reduction (256-bit AVX)
    dispatchTable.ReduceAddF64x4 := @AVX2ReduceAddF64x4;
    dispatchTable.ReduceMinF64x4 := @AVX2ReduceMinF64x4;
    dispatchTable.ReduceMaxF64x4 := @AVX2ReduceMaxF64x4;
    dispatchTable.ReduceMulF64x4 := @AVX2ReduceMulF64x4;

    // F64x4 Extended Math (256-bit AVX)
    if LHasHardwareFma then
      dispatchTable.FmaF64x4 := @AVX2FmaF64x4;
    dispatchTable.FloorF64x4 := @AVX2FloorF64x4;
    dispatchTable.CeilF64x4 := @AVX2CeilF64x4;
    dispatchTable.RoundF64x4 := @AVX2RoundF64x4;
    dispatchTable.TruncF64x4 := @AVX2TruncF64x4;

    // F64x4 Load/Store/Splat/Zero (256-bit AVX)
    dispatchTable.LoadF64x4 := @AVX2LoadF64x4;
    dispatchTable.StoreF64x4 := @AVX2StoreF64x4;
    dispatchTable.SplatF64x4 := @AVX2SplatF64x4;
    dispatchTable.ZeroF64x4 := @AVX2ZeroF64x4;

    // 512-bit 向量的 AVX2 仿真实现 (2×256-bit 操作)

    // F32x16 Arithmetic (512-bit emulated via 2×F32x8)
    dispatchTable.AddF32x16 := @AVX2AddF32x16;
    dispatchTable.SubF32x16 := @AVX2SubF32x16;
    dispatchTable.MulF32x16 := @AVX2MulF32x16;
    dispatchTable.DivF32x16 := @AVX2DivF32x16;

    // F32x16 Math (512-bit)
    dispatchTable.AbsF32x16 := @AVX2AbsF32x16;
    dispatchTable.SqrtF32x16 := @AVX2SqrtF32x16;
    dispatchTable.MinF32x16 := @AVX2MinF32x16;
    dispatchTable.MaxF32x16 := @AVX2MaxF32x16;
    dispatchTable.ClampF32x16 := @AVX2ClampF32x16;

    // F32x16 Extended Math (512-bit)
    if LHasHardwareFma then
      dispatchTable.FmaF32x16 := @AVX2FmaF32x16;
    dispatchTable.FloorF32x16 := @AVX2FloorF32x16;
    dispatchTable.CeilF32x16 := @AVX2CeilF32x16;
    dispatchTable.RoundF32x16 := @AVX2RoundF32x16;
    dispatchTable.TruncF32x16 := @AVX2TruncF32x16;

    // F32x16 Reduction (512-bit)
    dispatchTable.ReduceAddF32x16 := @AVX2ReduceAddF32x16;
    dispatchTable.ReduceMinF32x16 := @AVX2ReduceMinF32x16;
    dispatchTable.ReduceMaxF32x16 := @AVX2ReduceMaxF32x16;
    dispatchTable.ReduceMulF32x16 := @AVX2ReduceMulF32x16;

    // F32x16 Load/Store/Splat/Zero (512-bit)
    dispatchTable.LoadF32x16 := @AVX2LoadF32x16;
    dispatchTable.StoreF32x16 := @AVX2StoreF32x16;
    dispatchTable.SplatF32x16 := @AVX2SplatF32x16;
    dispatchTable.ZeroF32x16 := @AVX2ZeroF32x16;

    // F32x16 Comparison (512-bit)
    dispatchTable.CmpEqF32x16 := @AVX2CmpEqF32x16;
    dispatchTable.CmpLtF32x16 := @AVX2CmpLtF32x16;
    dispatchTable.CmpLeF32x16 := @AVX2CmpLeF32x16;
    dispatchTable.CmpGtF32x16 := @AVX2CmpGtF32x16;
    dispatchTable.CmpGeF32x16 := @AVX2CmpGeF32x16;
    dispatchTable.CmpNeF32x16 := @AVX2CmpNeF32x16;
    dispatchTable.SelectF32x16 := @AVX2SelectF32x16;

    // F64x8 Arithmetic (512-bit emulated via 2×F64x4)
    dispatchTable.AddF64x8 := @AVX2AddF64x8;
    dispatchTable.SubF64x8 := @AVX2SubF64x8;
    dispatchTable.MulF64x8 := @AVX2MulF64x8;
    dispatchTable.DivF64x8 := @AVX2DivF64x8;

    // F64x8 Math (512-bit)
    dispatchTable.AbsF64x8 := @AVX2AbsF64x8;
    dispatchTable.SqrtF64x8 := @AVX2SqrtF64x8;
    dispatchTable.MinF64x8 := @AVX2MinF64x8;
    dispatchTable.MaxF64x8 := @AVX2MaxF64x8;
    dispatchTable.ClampF64x8 := @AVX2ClampF64x8;

    // F64x8 Extended Math (512-bit)
    if LHasHardwareFma then
      dispatchTable.FmaF64x8 := @AVX2FmaF64x8;
    dispatchTable.FloorF64x8 := @AVX2FloorF64x8;
    dispatchTable.CeilF64x8 := @AVX2CeilF64x8;
    dispatchTable.RoundF64x8 := @AVX2RoundF64x8;
    dispatchTable.TruncF64x8 := @AVX2TruncF64x8;

    // F64x8 Reduction (512-bit)
    dispatchTable.ReduceAddF64x8 := @AVX2ReduceAddF64x8;
    dispatchTable.ReduceMinF64x8 := @AVX2ReduceMinF64x8;
    dispatchTable.ReduceMaxF64x8 := @AVX2ReduceMaxF64x8;
    dispatchTable.ReduceMulF64x8 := @AVX2ReduceMulF64x8;

    // F64x8 Load/Store/Splat/Zero (512-bit)
    dispatchTable.LoadF64x8 := @AVX2LoadF64x8;
    dispatchTable.StoreF64x8 := @AVX2StoreF64x8;
    dispatchTable.SplatF64x8 := @AVX2SplatF64x8;
    dispatchTable.ZeroF64x8 := @AVX2ZeroF64x8;

    // F64x8 Comparison (512-bit)
    dispatchTable.CmpEqF64x8 := @AVX2CmpEqF64x8;
    dispatchTable.CmpLtF64x8 := @AVX2CmpLtF64x8;
    dispatchTable.CmpLeF64x8 := @AVX2CmpLeF64x8;
    dispatchTable.CmpGtF64x8 := @AVX2CmpGtF64x8;
    dispatchTable.CmpGeF64x8 := @AVX2CmpGeF64x8;
    dispatchTable.CmpNeF64x8 := @AVX2CmpNeF64x8;
    dispatchTable.SelectF64x8 := @AVX2SelectF64x8;

    // I32x16 Arithmetic (512-bit emulated via 2×I32x8)
    dispatchTable.AddI32x16 := @AVX2AddI32x16;
    dispatchTable.SubI32x16 := @AVX2SubI32x16;
    dispatchTable.MulI32x16 := @AVX2MulI32x16;

    // I32x16 Bitwise (512-bit)
    dispatchTable.AndI32x16 := @AVX2AndI32x16;
    dispatchTable.OrI32x16 := @AVX2OrI32x16;
    dispatchTable.XorI32x16 := @AVX2XorI32x16;
    dispatchTable.NotI32x16 := @AVX2NotI32x16;
    dispatchTable.AndNotI32x16 := @AVX2AndNotI32x16;

    // I32x16 Shift (512-bit)
    dispatchTable.ShiftLeftI32x16 := @AVX2ShiftLeftI32x16;
    dispatchTable.ShiftRightI32x16 := @AVX2ShiftRightI32x16;
    dispatchTable.ShiftRightArithI32x16 := @AVX2ShiftRightArithI32x16;

    // I32x16 Comparison (512-bit)
    dispatchTable.CmpEqI32x16 := @AVX2CmpEqI32x16;
    dispatchTable.CmpLtI32x16 := @AVX2CmpLtI32x16;
    dispatchTable.CmpGtI32x16 := @AVX2CmpGtI32x16;
    dispatchTable.CmpLeI32x16 := @AVX2CmpLeI32x16;
    dispatchTable.CmpGeI32x16 := @AVX2CmpGeI32x16;
    dispatchTable.CmpNeI32x16 := @AVX2CmpNeI32x16;

    // I32x16 Min/Max (512-bit)
    dispatchTable.MinI32x16 := @AVX2MinI32x16;
    dispatchTable.MaxI32x16 := @AVX2MaxI32x16;

    // I64x8 Operations (512-bit emulated via 2×I64x4)
    dispatchTable.AddI64x8 := @AVX2AddI64x8;
    dispatchTable.SubI64x8 := @AVX2SubI64x8;
    dispatchTable.AndI64x8 := @AVX2AndI64x8;
    dispatchTable.OrI64x8 := @AVX2OrI64x8;
    dispatchTable.XorI64x8 := @AVX2XorI64x8;
    dispatchTable.NotI64x8 := @AVX2NotI64x8;
    dispatchTable.CmpEqI64x8 := @AVX2CmpEqI64x8;
    dispatchTable.CmpLtI64x8 := @AVX2CmpLtI64x8;
    dispatchTable.CmpGtI64x8 := @AVX2CmpGtI64x8;
    dispatchTable.CmpLeI64x8 := @AVX2CmpLeI64x8;
    dispatchTable.CmpGeI64x8 := @AVX2CmpGeI64x8;
    dispatchTable.CmpNeI64x8 := @AVX2CmpNeI64x8;

    // Override with AVX2 memory operations
    dispatchTable.LoadF32x4 := @AVX2LoadF32x4;
    dispatchTable.LoadF32x4Aligned := @AVX2LoadF32x4Aligned;
    dispatchTable.StoreF32x4 := @AVX2StoreF32x4;
    dispatchTable.StoreF32x4Aligned := @AVX2StoreF32x4Aligned;

    // Override with AVX2 utility operations
    dispatchTable.SplatF32x4 := @AVX2SplatF32x4;
    dispatchTable.ZeroF32x4 := @AVX2ZeroF32x4;
    dispatchTable.SelectF32x4 := @AVX2SelectF32x4;
    dispatchTable.ExtractF32x4 := @AVX2ExtractF32x4;
    dispatchTable.InsertF32x4 := @AVX2InsertF32x4;

    // Extract/Insert Operations
    // F32x8 (256-bit)
    dispatchTable.ExtractF32x8 := @AVX2ExtractF32x8;
    dispatchTable.InsertF32x8 := @AVX2InsertF32x8;
    // F64x2 (128-bit)
    dispatchTable.ExtractF64x2 := @AVX2ExtractF64x2;
    dispatchTable.InsertF64x2 := @AVX2InsertF64x2;
    // F64x4 (256-bit)
    dispatchTable.ExtractF64x4 := @AVX2ExtractF64x4;
    dispatchTable.InsertF64x4 := @AVX2InsertF64x4;
    // I32x4 (128-bit)
    dispatchTable.ExtractI32x4 := @AVX2ExtractI32x4;
    dispatchTable.InsertI32x4 := @AVX2InsertI32x4;
    // I32x8 (256-bit)
    dispatchTable.ExtractI32x8 := @AVX2ExtractI32x8;
    dispatchTable.InsertI32x8 := @AVX2InsertI32x8;
    // I64x2 (128-bit)
    dispatchTable.ExtractI64x2 := @AVX2ExtractI64x2;
    dispatchTable.InsertI64x2 := @AVX2InsertI64x2;
    // I64x4 (256-bit)
    dispatchTable.ExtractI64x4 := @AVX2ExtractI64x4;
    dispatchTable.InsertI64x4 := @AVX2InsertI64x4;
    // F32x16 (512-bit)
    dispatchTable.ExtractF32x16 := @AVX2ExtractF32x16;
    dispatchTable.InsertF32x16 := @AVX2InsertF32x16;
    // I32x16 (512-bit)
    dispatchTable.ExtractI32x16 := @AVX2ExtractI32x16;
    dispatchTable.InsertI32x16 := @AVX2InsertI32x16;

    // SelectF64x2
    dispatchTable.SelectF64x2 := @AVX2SelectF64x2;

    // Missing select operations
    dispatchTable.SelectI32x4 := @AVX2SelectI32x4;
    dispatchTable.SelectF32x8 := @AVX2SelectF32x8;
    dispatchTable.SelectF64x4 := @AVX2SelectF64x4;
  end;
  // else: keep scalar implementations from FillBaseDispatchTable

  {$IFNDEF WINDOWS}
  // Override facade functions with AVX2-accelerated versions
  dispatchTable.MemEqual := @MemEqual_AVX2;
  dispatchTable.MemFindByte := @MemFindByte_AVX2;
  dispatchTable.SumBytes := @SumBytes_AVX2;
  dispatchTable.CountByte := @CountByte_AVX2;
  dispatchTable.MemDiffRange := @MemDiffRange_AVX2;
  dispatchTable.MemReverse := @MemReverse_AVX2;
  dispatchTable.MinMaxBytes := @MinMaxBytes_AVX2;
  dispatchTable.Utf8Validate := @Utf8Validate_AVX2;
  dispatchTable.AsciiIEqual := @AsciiIEqual_AVX2;
  dispatchTable.ToLowerAscii := @ToLowerAscii_AVX2;
  dispatchTable.ToUpperAscii := @ToUpperAscii_AVX2;
  dispatchTable.BytesIndexOf := @BytesIndexOf_AVX2;
  dispatchTable.BitsetPopCount := @BitsetPopCount_AVX2;
  // MemCopy, MemSet (使用 FPC 内置函数，已足够优化)
  dispatchTable.MemCopy := @MemCopy_AVX2;
  dispatchTable.MemSet := @MemSet_AVX2;
  {$ENDIF}

  // Override with AVX2 saturating arithmetic (VEX-encoded, always enabled)
  dispatchTable.I8x16SatAdd := @AVX2I8x16SatAdd;
  dispatchTable.I8x16SatSub := @AVX2I8x16SatSub;
  dispatchTable.I16x8SatAdd := @AVX2I16x8SatAdd;
  dispatchTable.I16x8SatSub := @AVX2I16x8SatSub;
  dispatchTable.U8x16SatAdd := @AVX2U8x16SatAdd;
  dispatchTable.U8x16SatSub := @AVX2U8x16SatSub;
  dispatchTable.U16x8SatAdd := @AVX2U16x8SatAdd;
  dispatchTable.U16x8SatSub := @AVX2U16x8SatSub;

  // Mask operations (native popcnt + bsf, always enabled)
  dispatchTable.Mask2All := @AVX2Mask2All;
  dispatchTable.Mask2Any := @AVX2Mask2Any;
  dispatchTable.Mask2None := @AVX2Mask2None;
  dispatchTable.Mask2PopCount := @AVX2Mask2PopCount;
  dispatchTable.Mask2FirstSet := @SharedMask2FirstSet;
  dispatchTable.Mask4All := @AVX2Mask4All;
  dispatchTable.Mask4Any := @AVX2Mask4Any;
  dispatchTable.Mask4None := @AVX2Mask4None;
  dispatchTable.Mask4PopCount := @AVX2Mask4PopCount;
  dispatchTable.Mask4FirstSet := @SharedMask4FirstSet;
  dispatchTable.Mask8All := @AVX2Mask8All;
  dispatchTable.Mask8Any := @AVX2Mask8Any;
  dispatchTable.Mask8None := @AVX2Mask8None;
  dispatchTable.Mask8PopCount := @AVX2Mask8PopCount;
  dispatchTable.Mask8FirstSet := @SharedMask8FirstSet;
  dispatchTable.Mask16All := @AVX2Mask16All;
  dispatchTable.Mask16Any := @AVX2Mask16Any;
  dispatchTable.Mask16None := @AVX2Mask16None;
  dispatchTable.Mask16PopCount := @AVX2Mask16PopCount;
  dispatchTable.Mask16FirstSet := @SharedMask16FirstSet;

  // Batch array operations (AVX2 256-bit)
  dispatchTable.ArrayAddF32 := @AVX2ArrayAddF32;
  dispatchTable.ArraySubF32 := @AVX2ArraySubF32;
  dispatchTable.ArrayMulF32 := @AVX2ArrayMulF32;
  dispatchTable.ArrayDivF32 := @AVX2ArrayDivF32;
  dispatchTable.ArrayMinF32 := @AVX2ArrayMinF32;
  dispatchTable.ArrayMaxF32 := @AVX2ArrayMaxF32;
  dispatchTable.ArrayAbsF32 := @AVX2ArrayAbsF32;
  dispatchTable.ArrayNegF32 := @AVX2ArrayNegF32;
  dispatchTable.ArraySqrtF32 := @AVX2ArraySqrtF32;
  dispatchTable.ArrayRcpF32 := @AVX2ArrayRcpF32;
  dispatchTable.ArrayRsqrtF32 := @AVX2ArrayRsqrtF32;
  dispatchTable.ArrayRcpRefineF32 := @AVX2ArrayRcpRefineF32;
  dispatchTable.ArrayRsqrtRefineF32 := @AVX2ArrayRsqrtRefineF32;
  dispatchTable.ArrayAddScalarF32 := @AVX2ArrayAddScalarF32;
  dispatchTable.ArrayMulScalarF32 := @AVX2ArrayMulScalarF32;
  dispatchTable.ArrayClampF32 := @AVX2ArrayClampF32;
  if LHasHardwareFma then
    dispatchTable.ArrayFmaF32 := @AVX2ArrayFmaF32;
  dispatchTable.ArrayAxpyF32 := @AVX2ArrayAxpyF32;
  dispatchTable.ReduceSumF32 := @AVX2ReduceSumF32;
  dispatchTable.ReduceDotF32 := @AVX2ReduceDotF32;
  dispatchTable.ReduceMinF32 := @AVX2ReduceMinF32;
  dispatchTable.ReduceMaxF32 := @AVX2ReduceMaxF32;

  // F64 batch
  dispatchTable.ArrayAddF64 := @AVX2ArrayAddF64;
  dispatchTable.ArraySubF64 := @AVX2ArraySubF64;
  dispatchTable.ArrayMulF64 := @AVX2ArrayMulF64;
  dispatchTable.ArrayDivF64 := @AVX2ArrayDivF64;
  dispatchTable.ReduceSumF64 := @AVX2ReduceSumF64;
  dispatchTable.ReduceDotF64 := @AVX2ReduceDotF64;
  dispatchTable.ReduceMinF64 := @AVX2ReduceMinF64;
  dispatchTable.ReduceMaxF64 := @AVX2ReduceMaxF64;
  dispatchTable.ArrayAbsF64 := @AVX2ArrayAbsF64;
  dispatchTable.ArrayNegF64 := @AVX2ArrayNegF64;
  dispatchTable.ArraySqrtF64 := @AVX2ArraySqrtF64;
  dispatchTable.ArrayMulScalarF64 := @AVX2ArrayMulScalarF64;
  dispatchTable.ArrayAddScalarF64 := @AVX2ArrayAddScalarF64;
  dispatchTable.ArrayClampF64 := @AVX2ArrayClampF64;
  dispatchTable.ArrayLinearF64 := @AVX2ArrayLinearF64;

  // Integer batch
  dispatchTable.ArrayAddI32 := @AVX2ArrayAddI32;
  dispatchTable.ArraySubI32 := @AVX2ArraySubI32;
  dispatchTable.ArrayMulI16 := @AVX2ArrayMulI16;
  dispatchTable.ArrayPackSatI32toI16 := @AVX2ArrayPackSatI32toI16;

  // Type conversion
  dispatchTable.ArrayF32toI32 := @AVX2ArrayF32toI32;
  dispatchTable.ArrayI32toF32 := @AVX2ArrayI32toF32;

  // Bitwise
  dispatchTable.ArrayAndI32 := @AVX2ArrayAndI32;
  dispatchTable.ArrayOrI32 := @AVX2ArrayOrI32;
  dispatchTable.ArrayXorI32 := @AVX2ArrayXorI32;
  dispatchTable.ArrayShlI32 := @AVX2ArrayShlI32;
  dispatchTable.ArrayShrI32 := @AVX2ArrayShrI32;

  // Transcendental (SIMD polynomial approximation)
  dispatchTable.ArrayExpF32 := @AVX2ArrayExpF32;
  dispatchTable.ArrayLogF32 := @AVX2ArrayLogF32;
  dispatchTable.ArraySinF32 := @AVX2ArraySinF32;
  dispatchTable.ArrayCosF32 := @AVX2ArrayCosF32;
  dispatchTable.ArrayPowF32 := @AVX2ArrayPowF32;

  // Fused (single-pass, reduced memory traffic)
  dispatchTable.ArrayLinearF32 := @AVX2ArrayLinearF32;
  dispatchTable.ArrayAbsDiffF32 := @AVX2ArrayAbsDiffF32;
  dispatchTable.ArrayReLUF32 := @AVX2ArrayReLUF32;
  dispatchTable.ArrayNormF32 := @AVX2ArrayNormF32;
  dispatchTable.ArrayLinearReLUF32 := @AVX2ArrayLinearReLUF32;

  // Register the backend
  RegisterBackend(sbAVX2, dispatchTable);
end;

initialization
  RegisterAVX2Backend;
  // Register rebuilder callback for VectorAsmEnabled changes
  RegisterBackendRebuilder(sbAVX2, @RegisterAVX2Backend);
