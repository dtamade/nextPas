procedure RegisterAVX2Backend;
var
  dispatchTable: TSimdDispatchTable;
  LEnableVectorAsm: Boolean;
  LHasHardwareFma: Boolean;
begin
  if not HasAVX2 then
    Exit;

  LEnableVectorAsm := IsVectorAsmEnabled;
  {$IFDEF WINDOWS}
  LEnableVectorAsm := False;
  {$ENDIF}
  LHasHardwareFma := HasFeature(gfFMA);

  // AVX2 inherits all 128-bit integer operations from SSE2.
  // 128-bit float ops are overridden because VEX-encoded versions have
  // different NaN propagation behavior (minps vs vminps).
  dispatchTable := Default(TSimdDispatchTable);
  if not CloneDispatchTable(sbSSE2, dispatchTable) then
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
    // === 128-bit Float Overrides (VEX encoding, NaN propagation) ===

    // F32x4 Arithmetic
    dispatchTable.CoreVectors.AddF32x4 := @AVX2AddF32x4;
    dispatchTable.CoreVectors.SubF32x4 := @AVX2SubF32x4;
    dispatchTable.CoreVectors.MulF32x4 := @AVX2MulF32x4;
    dispatchTable.CoreVectors.DivF32x4 := @AVX2DivF32x4;
    // F32x4 Comparison
    dispatchTable.CoreVectors.CmpEqF32x4 := @AVX2CmpEqF32x4;
    dispatchTable.CoreVectors.CmpLtF32x4 := @AVX2CmpLtF32x4;
    dispatchTable.CoreVectors.CmpLeF32x4 := @AVX2CmpLeF32x4;
    dispatchTable.CoreVectors.CmpGtF32x4 := @AVX2CmpGtF32x4;
    dispatchTable.CoreVectors.CmpGeF32x4 := @AVX2CmpGeF32x4;
    dispatchTable.CoreVectors.CmpNeF32x4 := @AVX2CmpNeF32x4;
    // F32x4 Math
    dispatchTable.CoreVectors.AbsF32x4 := @AVX2AbsF32x4;
    dispatchTable.CoreVectors.SqrtF32x4 := @AVX2SqrtF32x4;
    dispatchTable.CoreVectors.MinF32x4 := @AVX2MinF32x4;
    dispatchTable.CoreVectors.MaxF32x4 := @AVX2MaxF32x4;
    if LHasHardwareFma then
      dispatchTable.CoreVectors.FmaF32x4 := @AVX2FmaF32x4;
    dispatchTable.CoreVectors.RcpF32x4 := @AVX2RcpF32x4;
    dispatchTable.CoreVectors.RsqrtF32x4 := @AVX2RsqrtF32x4;
    dispatchTable.CoreVectors.FloorF32x4 := @AVX2FloorF32x4;
    dispatchTable.CoreVectors.CeilF32x4 := @AVX2CeilF32x4;
    dispatchTable.CoreVectors.RoundF32x4 := @AVX2RoundF32x4;
    dispatchTable.CoreVectors.TruncF32x4 := @AVX2TruncF32x4;
    dispatchTable.CoreVectors.ClampF32x4 := @AVX2ClampF32x4;
    // F32x4 Vector math
    dispatchTable.CoreVectors.DotF32x4 := @AVX2DotF32x4;
    dispatchTable.CoreVectors.DotF32x3 := @AVX2DotF32x3;
    dispatchTable.CoreVectors.CrossF32x3 := @AVX2CrossF32x3;
    dispatchTable.CoreVectors.LengthF32x4 := @AVX2LengthF32x4;
    dispatchTable.CoreVectors.LengthF32x3 := @AVX2LengthF32x3;
    dispatchTable.CoreVectors.NormalizeF32x4 := @AVX2NormalizeF32x4;
    dispatchTable.CoreVectors.NormalizeF32x3 := @AVX2NormalizeF32x3;
    // F32x4 Reduction
    dispatchTable.CoreVectors.ReduceAddF32x4 := @AVX2ReduceAddF32x4;
    dispatchTable.CoreVectors.ReduceMinF32x4 := @AVX2ReduceMinF32x4;
    dispatchTable.CoreVectors.ReduceMaxF32x4 := @AVX2ReduceMaxF32x4;
    dispatchTable.CoreVectors.ReduceMulF32x4 := @AVX2ReduceMulF32x4;
    // F32x4 Load/Store/Utility
    dispatchTable.CoreVectors.LoadF32x4 := @AVX2LoadF32x4;
    dispatchTable.CoreVectors.LoadF32x4Aligned := @AVX2LoadF32x4Aligned;
    dispatchTable.CoreVectors.StoreF32x4 := @AVX2StoreF32x4;
    dispatchTable.CoreVectors.StoreF32x4Aligned := @AVX2StoreF32x4Aligned;
    dispatchTable.CoreVectors.SplatF32x4 := @AVX2SplatF32x4;
    dispatchTable.CoreVectors.ZeroF32x4 := @AVX2ZeroF32x4;
    dispatchTable.CoreVectors.SelectF32x4 := @AVX2SelectF32x4;
    dispatchTable.CoreVectors.ExtractF32x4 := @AVX2ExtractF32x4;
    dispatchTable.CoreVectors.InsertF32x4 := @AVX2InsertF32x4;

    // F64x2 Arithmetic
    dispatchTable.CoreVectors.AddF64x2 := @AVX2AddF64x2;
    dispatchTable.CoreVectors.SubF64x2 := @AVX2SubF64x2;
    dispatchTable.CoreVectors.MulF64x2 := @AVX2MulF64x2;
    dispatchTable.CoreVectors.DivF64x2 := @AVX2DivF64x2;
    // F64x2 Comparison
    dispatchTable.CoreVectors.CmpEqF64x2 := @AVX2CmpEqF64x2;
    dispatchTable.CoreVectors.CmpLtF64x2 := @AVX2CmpLtF64x2;
    dispatchTable.CoreVectors.CmpLeF64x2 := @AVX2CmpLeF64x2;
    dispatchTable.CoreVectors.CmpGtF64x2 := @AVX2CmpGtF64x2;
    dispatchTable.CoreVectors.CmpGeF64x2 := @AVX2CmpGeF64x2;
    dispatchTable.CoreVectors.CmpNeF64x2 := @AVX2CmpNeF64x2;
    // F64x2 Math
    dispatchTable.CoreVectors.AbsF64x2 := @AVX2AbsF64x2;
    dispatchTable.CoreVectors.SqrtF64x2 := @AVX2SqrtF64x2;
    dispatchTable.CoreVectors.MinF64x2 := @AVX2MinF64x2;
    dispatchTable.CoreVectors.MaxF64x2 := @AVX2MaxF64x2;
    dispatchTable.CoreVectors.ClampF64x2 := @AVX2ClampF64x2;
    if LHasHardwareFma then
      dispatchTable.CoreVectors.FmaF64x2 := @AVX2FmaF64x2;
    dispatchTable.CoreVectors.FloorF64x2 := @AVX2FloorF64x2;
    dispatchTable.CoreVectors.CeilF64x2 := @AVX2CeilF64x2;
    dispatchTable.CoreVectors.RoundF64x2 := @AVX2RoundF64x2;
    dispatchTable.CoreVectors.TruncF64x2 := @AVX2TruncF64x2;
    // F64x2 Reduction
    dispatchTable.CoreVectors.ReduceAddF64x2 := @AVX2ReduceAddF64x2;
    dispatchTable.CoreVectors.ReduceMinF64x2 := @AVX2ReduceMinF64x2;
    dispatchTable.CoreVectors.ReduceMaxF64x2 := @AVX2ReduceMaxF64x2;
    dispatchTable.CoreVectors.ReduceMulF64x2 := @AVX2ReduceMulF64x2;
    // F64x2 Load/Store/Utility
    dispatchTable.CoreVectors.LoadF64x2 := @AVX2LoadF64x2;
    dispatchTable.CoreVectors.StoreF64x2 := @AVX2StoreF64x2;
    dispatchTable.CoreVectors.SplatF64x2 := @AVX2SplatF64x2;
    dispatchTable.CoreVectors.ZeroF64x2 := @AVX2ZeroF64x2;
    dispatchTable.CoreVectors.SelectF64x2 := @AVX2SelectF64x2;
    dispatchTable.CoreVectors.ExtractF64x2 := @AVX2ExtractF64x2;
    dispatchTable.CoreVectors.InsertF64x2 := @AVX2InsertF64x2;
    dispatchTable.CoreVectors.DotF64x2 := @AVX2DotF64x2;

    // I32x4/I64x2 Select/Extract/Insert (VEX utility)
    dispatchTable.CoreVectors.SelectI32x4 := @AVX2SelectI32x4;
    dispatchTable.CoreVectors.ExtractI32x4 := @AVX2ExtractI32x4;
    dispatchTable.CoreVectors.InsertI32x4 := @AVX2InsertI32x4;
    dispatchTable.CoreVectors.ExtractI64x2 := @AVX2ExtractI64x2;
    dispatchTable.CoreVectors.InsertI64x2 := @AVX2InsertI64x2;

    // === 256-bit Vector Operations (AVX2-unique) ===

    // F32x8 (256-bit float)
    dispatchTable.CoreVectors.AddF32x8 := @AVX2AddF32x8;
    dispatchTable.CoreVectors.SubF32x8 := @AVX2SubF32x8;
    dispatchTable.CoreVectors.MulF32x8 := @AVX2MulF32x8;
    dispatchTable.CoreVectors.DivF32x8 := @AVX2DivF32x8;
    dispatchTable.CoreVectors.CmpEqF32x8 := @AVX2CmpEqF32x8;
    dispatchTable.CoreVectors.CmpLtF32x8 := @AVX2CmpLtF32x8;
    dispatchTable.CoreVectors.CmpLeF32x8 := @AVX2CmpLeF32x8;
    dispatchTable.CoreVectors.CmpGtF32x8 := @AVX2CmpGtF32x8;
    dispatchTable.CoreVectors.CmpGeF32x8 := @AVX2CmpGeF32x8;
    dispatchTable.CoreVectors.CmpNeF32x8 := @AVX2CmpNeF32x8;
    dispatchTable.CoreVectors.AbsF32x8 := @AVX2AbsF32x8;
    dispatchTable.CoreVectors.SqrtF32x8 := @AVX2SqrtF32x8;
    dispatchTable.CoreVectors.MinF32x8 := @AVX2MinF32x8;
    dispatchTable.CoreVectors.MaxF32x8 := @AVX2MaxF32x8;
    dispatchTable.CoreVectors.ClampF32x8 := @AVX2ClampF32x8;
    if LHasHardwareFma then
      dispatchTable.CoreVectors.FmaF32x8 := @AVX2FmaF32x8;
    dispatchTable.CoreVectors.FloorF32x8 := @AVX2FloorF32x8;
    dispatchTable.CoreVectors.CeilF32x8 := @AVX2CeilF32x8;
    dispatchTable.CoreVectors.RoundF32x8 := @AVX2RoundF32x8;
    dispatchTable.CoreVectors.TruncF32x8 := @AVX2TruncF32x8;
    dispatchTable.CoreVectors.ReduceAddF32x8 := @AVX2ReduceAddF32x8;
    dispatchTable.CoreVectors.ReduceMinF32x8 := @AVX2ReduceMinF32x8;
    dispatchTable.CoreVectors.ReduceMaxF32x8 := @AVX2ReduceMaxF32x8;
    dispatchTable.CoreVectors.ReduceMulF32x8 := @AVX2ReduceMulF32x8;
    dispatchTable.CoreVectors.LoadF32x8 := @AVX2LoadF32x8;
    dispatchTable.CoreVectors.StoreF32x8 := @AVX2StoreF32x8;
    dispatchTable.CoreVectors.SplatF32x8 := @AVX2SplatF32x8;
    dispatchTable.CoreVectors.ZeroF32x8 := @AVX2ZeroF32x8;
    dispatchTable.CoreVectors.SelectF32x8 := @AVX2SelectF32x8;
    dispatchTable.CoreVectors.ExtractF32x8 := @AVX2ExtractF32x8;
    dispatchTable.CoreVectors.InsertF32x8 := @AVX2InsertF32x8;
    dispatchTable.CoreVectors.DotF32x8 := @AVX2DotF32x8;

    // F64x4 (256-bit double)
    dispatchTable.CoreVectors.AddF64x4 := @AVX2AddF64x4;
    dispatchTable.CoreVectors.SubF64x4 := @AVX2SubF64x4;
    dispatchTable.CoreVectors.MulF64x4 := @AVX2MulF64x4;
    dispatchTable.CoreVectors.DivF64x4 := @AVX2DivF64x4;
    dispatchTable.CoreVectors.CmpEqF64x4 := @AVX2CmpEqF64x4;
    dispatchTable.CoreVectors.CmpLtF64x4 := @AVX2CmpLtF64x4;
    dispatchTable.CoreVectors.CmpLeF64x4 := @AVX2CmpLeF64x4;
    dispatchTable.CoreVectors.CmpGtF64x4 := @AVX2CmpGtF64x4;
    dispatchTable.CoreVectors.CmpGeF64x4 := @AVX2CmpGeF64x4;
    dispatchTable.CoreVectors.CmpNeF64x4 := @AVX2CmpNeF64x4;
    dispatchTable.CoreVectors.AbsF64x4 := @AVX2AbsF64x4;
    dispatchTable.CoreVectors.SqrtF64x4 := @AVX2SqrtF64x4;
    dispatchTable.CoreVectors.MinF64x4 := @AVX2MinF64x4;
    dispatchTable.CoreVectors.MaxF64x4 := @AVX2MaxF64x4;
    dispatchTable.CoreVectors.ClampF64x4 := @AVX2ClampF64x4;
    if LHasHardwareFma then
      dispatchTable.CoreVectors.FmaF64x4 := @AVX2FmaF64x4;
    dispatchTable.CoreVectors.FloorF64x4 := @AVX2FloorF64x4;
    dispatchTable.CoreVectors.CeilF64x4 := @AVX2CeilF64x4;
    dispatchTable.CoreVectors.RoundF64x4 := @AVX2RoundF64x4;
    dispatchTable.CoreVectors.TruncF64x4 := @AVX2TruncF64x4;
    dispatchTable.CoreVectors.ReduceAddF64x4 := @AVX2ReduceAddF64x4;
    dispatchTable.CoreVectors.ReduceMinF64x4 := @AVX2ReduceMinF64x4;
    dispatchTable.CoreVectors.ReduceMaxF64x4 := @AVX2ReduceMaxF64x4;
    dispatchTable.CoreVectors.ReduceMulF64x4 := @AVX2ReduceMulF64x4;
    dispatchTable.CoreVectors.LoadF64x4 := @AVX2LoadF64x4;
    dispatchTable.CoreVectors.StoreF64x4 := @AVX2StoreF64x4;
    dispatchTable.CoreVectors.SplatF64x4 := @AVX2SplatF64x4;
    dispatchTable.CoreVectors.ZeroF64x4 := @AVX2ZeroF64x4;
    dispatchTable.CoreVectors.SelectF64x4 := @AVX2SelectF64x4;
    dispatchTable.CoreVectors.ExtractF64x4 := @AVX2ExtractF64x4;
    dispatchTable.CoreVectors.InsertF64x4 := @AVX2InsertF64x4;
    dispatchTable.CoreVectors.RcpF64x4 := @AVX2RcpF64x4;
    dispatchTable.CoreVectors.DotF64x4 := @AVX2DotF64x4;

    // I32x8 (256-bit AVX2 integer)
    dispatchTable.CoreVectors.AddI32x8 := @AVX2AddI32x8;
    dispatchTable.CoreVectors.SubI32x8 := @AVX2SubI32x8;
    dispatchTable.CoreVectors.MulI32x8 := @AVX2MulI32x8;
    dispatchTable.CoreVectors.AndI32x8 := @AVX2AndI32x8;
    dispatchTable.CoreVectors.OrI32x8 := @AVX2OrI32x8;
    dispatchTable.CoreVectors.XorI32x8 := @AVX2XorI32x8;
    dispatchTable.CoreVectors.NotI32x8 := @AVX2NotI32x8;
    dispatchTable.CoreVectors.AndNotI32x8 := @AVX2AndNotI32x8;
    dispatchTable.CoreVectors.ShiftLeftI32x8 := @AVX2ShiftLeftI32x8;
    dispatchTable.CoreVectors.ShiftRightI32x8 := @AVX2ShiftRightI32x8;
    dispatchTable.CoreVectors.ShiftRightArithI32x8 := @AVX2ShiftRightArithI32x8;
    dispatchTable.CoreVectors.CmpEqI32x8 := @AVX2CmpEqI32x8;
    dispatchTable.CoreVectors.CmpLtI32x8 := @AVX2CmpLtI32x8;
    dispatchTable.CoreVectors.CmpGtI32x8 := @AVX2CmpGtI32x8;
    dispatchTable.CoreVectors.CmpLeI32x8 := @AVX2CmpLeI32x8;
    dispatchTable.CoreVectors.CmpGeI32x8 := @AVX2CmpGeI32x8;
    dispatchTable.CoreVectors.CmpNeI32x8 := @AVX2CmpNeI32x8;
    dispatchTable.CoreVectors.MinI32x8 := @AVX2MinI32x8;
    dispatchTable.CoreVectors.MaxI32x8 := @AVX2MaxI32x8;
    dispatchTable.CoreVectors.ExtractI32x8 := @AVX2ExtractI32x8;

    dispatchTable.CoreVectors.InsertI32x8 := @AVX2InsertI32x8;

    // I64x4 (256-bit AVX2)
    dispatchTable.CoreVectors.AddI64x4 := @AVX2AddI64x4;
    dispatchTable.CoreVectors.SubI64x4 := @AVX2SubI64x4;
    dispatchTable.CoreVectors.AndI64x4 := @AVX2AndI64x4;
    dispatchTable.CoreVectors.OrI64x4 := @AVX2OrI64x4;
    dispatchTable.CoreVectors.XorI64x4 := @AVX2XorI64x4;
    dispatchTable.CoreVectors.NotI64x4 := @AVX2NotI64x4;
    dispatchTable.CoreVectors.AndNotI64x4 := @AVX2AndNotI64x4;
    dispatchTable.CoreVectors.ShiftLeftI64x4 := @AVX2ShiftLeftI64x4;
    dispatchTable.CoreVectors.ShiftRightI64x4 := @AVX2ShiftRightI64x4;
    dispatchTable.CoreVectors.CmpEqI64x4 := @AVX2CmpEqI64x4;
    dispatchTable.CoreVectors.CmpLtI64x4 := @AVX2CmpLtI64x4;
    dispatchTable.CoreVectors.CmpGtI64x4 := @AVX2CmpGtI64x4;
    dispatchTable.CoreVectors.CmpLeI64x4 := @AVX2CmpLeI64x4;
    dispatchTable.CoreVectors.CmpGeI64x4 := @AVX2CmpGeI64x4;
    dispatchTable.CoreVectors.CmpNeI64x4 := @AVX2CmpNeI64x4;
    dispatchTable.CoreVectors.LoadI64x4 := @AVX2LoadI64x4;
    dispatchTable.CoreVectors.StoreI64x4 := @AVX2StoreI64x4;
    dispatchTable.CoreVectors.SplatI64x4 := @AVX2SplatI64x4;
    dispatchTable.CoreVectors.ZeroI64x4 := @AVX2ZeroI64x4;
    dispatchTable.CoreVectors.ExtractI64x4 := @AVX2ExtractI64x4;

    dispatchTable.CoreVectors.InsertI64x4 := @AVX2InsertI64x4;

    // U32x8 (256-bit AVX2 unsigned)
    dispatchTable.CoreVectors.AddU32x8 := @AVX2AddU32x8;
    dispatchTable.CoreVectors.SubU32x8 := @AVX2SubU32x8;
    dispatchTable.CoreVectors.MulU32x8 := @AVX2MulU32x8;
    dispatchTable.CoreVectors.AndU32x8 := @AVX2AndU32x8;
    dispatchTable.CoreVectors.OrU32x8 := @AVX2OrU32x8;
    dispatchTable.CoreVectors.XorU32x8 := @AVX2XorU32x8;
    dispatchTable.CoreVectors.NotU32x8 := @AVX2NotU32x8;
    dispatchTable.CoreVectors.AndNotU32x8 := @AVX2AndNotU32x8;
    dispatchTable.CoreVectors.ShiftLeftU32x8 := @AVX2ShiftLeftU32x8;
    dispatchTable.CoreVectors.ShiftRightU32x8 := @AVX2ShiftRightU32x8;
    dispatchTable.CoreVectors.CmpEqU32x8 := @AVX2CmpEqU32x8;
    dispatchTable.CoreVectors.CmpLtU32x8 := @AVX2CmpLtU32x8;
    dispatchTable.CoreVectors.CmpGtU32x8 := @AVX2CmpGtU32x8;
    dispatchTable.CoreVectors.CmpLeU32x8 := @AVX2CmpLeU32x8;
    dispatchTable.CoreVectors.CmpGeU32x8 := @AVX2CmpGeU32x8;
    dispatchTable.CoreVectors.CmpNeU32x8 := @AVX2CmpNeU32x8;
    dispatchTable.CoreVectors.MinU32x8 := @AVX2MinU32x8;

    dispatchTable.CoreVectors.MaxU32x8 := @AVX2MaxU32x8;

    // U64x4 (256-bit AVX2 unsigned)
    dispatchTable.CoreVectors.AddU64x4 := @AVX2AddU64x4;
    dispatchTable.CoreVectors.SubU64x4 := @AVX2SubU64x4;
    dispatchTable.CoreVectors.AndU64x4 := @AVX2AndU64x4;
    dispatchTable.CoreVectors.OrU64x4 := @AVX2OrU64x4;
    dispatchTable.CoreVectors.XorU64x4 := @AVX2XorU64x4;
    dispatchTable.CoreVectors.NotU64x4 := @AVX2NotU64x4;
    dispatchTable.CoreVectors.ShiftLeftU64x4 := @AVX2ShiftLeftU64x4;
    dispatchTable.CoreVectors.ShiftRightU64x4 := @AVX2ShiftRightU64x4;
    dispatchTable.CoreVectors.CmpEqU64x4 := @AVX2CmpEqU64x4;

    dispatchTable.CoreVectors.CmpLtU64x4 := @AVX2CmpLtU64x4;

    dispatchTable.CoreVectors.CmpGtU64x4 := @AVX2CmpGtU64x4;

    dispatchTable.CoreVectors.CmpLeU64x4 := @AVX2CmpLeU64x4;

    dispatchTable.CoreVectors.CmpGeU64x4 := @AVX2CmpGeU64x4;

    dispatchTable.CoreVectors.CmpNeU64x4 := @AVX2CmpNeU64x4;

    // === 512-bit Emulation via 2x256-bit (AVX2-unique) ===

    // F32x16 (512-bit emulated)
    dispatchTable.CoreVectors.AddF32x16 := @AVX2AddF32x16;
    dispatchTable.CoreVectors.SubF32x16 := @AVX2SubF32x16;
    dispatchTable.CoreVectors.MulF32x16 := @AVX2MulF32x16;
    dispatchTable.CoreVectors.DivF32x16 := @AVX2DivF32x16;
    dispatchTable.CoreVectors.AbsF32x16 := @AVX2AbsF32x16;
    dispatchTable.CoreVectors.SqrtF32x16 := @AVX2SqrtF32x16;
    dispatchTable.CoreVectors.MinF32x16 := @AVX2MinF32x16;
    dispatchTable.CoreVectors.MaxF32x16 := @AVX2MaxF32x16;
    dispatchTable.CoreVectors.ClampF32x16 := @AVX2ClampF32x16;
    if LHasHardwareFma then
      dispatchTable.CoreVectors.FmaF32x16 := @AVX2FmaF32x16;
    dispatchTable.CoreVectors.FloorF32x16 := @AVX2FloorF32x16;
    dispatchTable.CoreVectors.CeilF32x16 := @AVX2CeilF32x16;
    dispatchTable.CoreVectors.RoundF32x16 := @AVX2RoundF32x16;
    dispatchTable.CoreVectors.TruncF32x16 := @AVX2TruncF32x16;
    dispatchTable.CoreVectors.ReduceAddF32x16 := @AVX2ReduceAddF32x16;
    dispatchTable.CoreVectors.ReduceMinF32x16 := @AVX2ReduceMinF32x16;
    dispatchTable.CoreVectors.ReduceMaxF32x16 := @AVX2ReduceMaxF32x16;
    dispatchTable.CoreVectors.ReduceMulF32x16 := @AVX2ReduceMulF32x16;
    dispatchTable.CoreVectors.LoadF32x16 := @AVX2LoadF32x16;
    dispatchTable.CoreVectors.StoreF32x16 := @AVX2StoreF32x16;
    dispatchTable.CoreVectors.SplatF32x16 := @AVX2SplatF32x16;
    dispatchTable.CoreVectors.ZeroF32x16 := @AVX2ZeroF32x16;
    dispatchTable.CoreVectors.SelectF32x16 := @AVX2SelectF32x16;
    dispatchTable.CoreVectors.CmpEqF32x16 := @AVX2CmpEqF32x16;
    dispatchTable.CoreVectors.CmpLtF32x16 := @AVX2CmpLtF32x16;
    dispatchTable.CoreVectors.CmpLeF32x16 := @AVX2CmpLeF32x16;
    dispatchTable.CoreVectors.CmpGtF32x16 := @AVX2CmpGtF32x16;
    dispatchTable.CoreVectors.CmpGeF32x16 := @AVX2CmpGeF32x16;
    dispatchTable.CoreVectors.CmpNeF32x16 := @AVX2CmpNeF32x16;
    dispatchTable.CoreVectors.ExtractF32x16 := @AVX2ExtractF32x16;

    dispatchTable.CoreVectors.InsertF32x16 := @AVX2InsertF32x16;

    // F64x8 (512-bit emulated)
    dispatchTable.CoreVectors.AddF64x8 := @AVX2AddF64x8;
    dispatchTable.CoreVectors.SubF64x8 := @AVX2SubF64x8;
    dispatchTable.CoreVectors.MulF64x8 := @AVX2MulF64x8;
    dispatchTable.CoreVectors.DivF64x8 := @AVX2DivF64x8;
    dispatchTable.CoreVectors.AbsF64x8 := @AVX2AbsF64x8;
    dispatchTable.CoreVectors.SqrtF64x8 := @AVX2SqrtF64x8;
    dispatchTable.CoreVectors.MinF64x8 := @AVX2MinF64x8;
    dispatchTable.CoreVectors.MaxF64x8 := @AVX2MaxF64x8;
    dispatchTable.CoreVectors.ClampF64x8 := @AVX2ClampF64x8;
    if LHasHardwareFma then
      dispatchTable.CoreVectors.FmaF64x8 := @AVX2FmaF64x8;
    dispatchTable.CoreVectors.FloorF64x8 := @AVX2FloorF64x8;
    dispatchTable.CoreVectors.CeilF64x8 := @AVX2CeilF64x8;
    dispatchTable.CoreVectors.RoundF64x8 := @AVX2RoundF64x8;
    dispatchTable.CoreVectors.TruncF64x8 := @AVX2TruncF64x8;
    dispatchTable.CoreVectors.ReduceAddF64x8 := @AVX2ReduceAddF64x8;
    dispatchTable.CoreVectors.ReduceMinF64x8 := @AVX2ReduceMinF64x8;
    dispatchTable.CoreVectors.ReduceMaxF64x8 := @AVX2ReduceMaxF64x8;
    dispatchTable.CoreVectors.ReduceMulF64x8 := @AVX2ReduceMulF64x8;
    dispatchTable.CoreVectors.LoadF64x8 := @AVX2LoadF64x8;
    dispatchTable.CoreVectors.StoreF64x8 := @AVX2StoreF64x8;
    dispatchTable.CoreVectors.SplatF64x8 := @AVX2SplatF64x8;
    dispatchTable.CoreVectors.ZeroF64x8 := @AVX2ZeroF64x8;
    dispatchTable.CoreVectors.SelectF64x8 := @AVX2SelectF64x8;
    dispatchTable.CoreVectors.CmpEqF64x8 := @AVX2CmpEqF64x8;

    dispatchTable.CoreVectors.CmpLtF64x8 := @AVX2CmpLtF64x8;

    dispatchTable.CoreVectors.CmpLeF64x8 := @AVX2CmpLeF64x8;

    dispatchTable.CoreVectors.CmpGtF64x8 := @AVX2CmpGtF64x8;

    dispatchTable.CoreVectors.CmpGeF64x8 := @AVX2CmpGeF64x8;

    dispatchTable.CoreVectors.CmpNeF64x8 := @AVX2CmpNeF64x8;

    // I32x16 (512-bit emulated)
    dispatchTable.CoreVectors.AddI32x16 := @AVX2AddI32x16;
    dispatchTable.CoreVectors.SubI32x16 := @AVX2SubI32x16;
    dispatchTable.CoreVectors.MulI32x16 := @AVX2MulI32x16;
    dispatchTable.CoreVectors.AndI32x16 := @AVX2AndI32x16;
    dispatchTable.CoreVectors.OrI32x16 := @AVX2OrI32x16;
    dispatchTable.CoreVectors.XorI32x16 := @AVX2XorI32x16;
    dispatchTable.CoreVectors.NotI32x16 := @AVX2NotI32x16;
    dispatchTable.CoreVectors.AndNotI32x16 := @AVX2AndNotI32x16;
    dispatchTable.CoreVectors.ShiftLeftI32x16 := @AVX2ShiftLeftI32x16;
    dispatchTable.CoreVectors.ShiftRightI32x16 := @AVX2ShiftRightI32x16;
    dispatchTable.CoreVectors.ShiftRightArithI32x16 := @AVX2ShiftRightArithI32x16;
    dispatchTable.CoreVectors.CmpEqI32x16 := @AVX2CmpEqI32x16;
    dispatchTable.CoreVectors.CmpLtI32x16 := @AVX2CmpLtI32x16;
    dispatchTable.CoreVectors.CmpGtI32x16 := @AVX2CmpGtI32x16;
    dispatchTable.CoreVectors.CmpLeI32x16 := @AVX2CmpLeI32x16;
    dispatchTable.CoreVectors.CmpGeI32x16 := @AVX2CmpGeI32x16;
    dispatchTable.CoreVectors.CmpNeI32x16 := @AVX2CmpNeI32x16;
    dispatchTable.CoreVectors.MinI32x16 := @AVX2MinI32x16;
    dispatchTable.CoreVectors.MaxI32x16 := @AVX2MaxI32x16;
    dispatchTable.CoreVectors.ExtractI32x16 := @AVX2ExtractI32x16;

    dispatchTable.CoreVectors.InsertI32x16 := @AVX2InsertI32x16;

    // I64x8 (512-bit emulated)
    dispatchTable.CoreVectors.AddI64x8 := @AVX2AddI64x8;
    dispatchTable.CoreVectors.SubI64x8 := @AVX2SubI64x8;
    dispatchTable.CoreVectors.AndI64x8 := @AVX2AndI64x8;
    dispatchTable.CoreVectors.OrI64x8 := @AVX2OrI64x8;
    dispatchTable.CoreVectors.XorI64x8 := @AVX2XorI64x8;
    dispatchTable.CoreVectors.NotI64x8 := @AVX2NotI64x8;
    dispatchTable.CoreVectors.CmpEqI64x8 := @AVX2CmpEqI64x8;

    dispatchTable.CoreVectors.CmpLtI64x8 := @AVX2CmpLtI64x8;

    dispatchTable.CoreVectors.CmpGtI64x8 := @AVX2CmpGtI64x8;

    dispatchTable.CoreVectors.CmpLeI64x8 := @AVX2CmpLeI64x8;

    dispatchTable.CoreVectors.CmpGeI64x8 := @AVX2CmpGeI64x8;

    dispatchTable.CoreVectors.CmpNeI64x8 := @AVX2CmpNeI64x8;

    // Benchmark-targeted 512-bit wide emulation
    dispatchTable.CoreVectors.AddI16x32 := @AVX2AddI16x32;
    dispatchTable.CoreVectors.MulU32x16 := @AVX2MulU32x16;
    dispatchTable.CoreVectors.AddU64x8 := @AVX2AddU64x8;
    dispatchTable.CoreVectors.MaxU8x64 := @AVX2MaxU8x64;
  end;
  // else: keep inherited SSE2 implementations from CloneDispatchTable

  {$IFNDEF WINDOWS}
  // Facade functions (AVX2-accelerated)
  dispatchTable.Memory.Equal := @MemEqual_AVX2;
  dispatchTable.Memory.FindByte := @MemFindByte_AVX2;
  dispatchTable.Memory.SumBytes := @SumBytes_AVX2;
  dispatchTable.Memory.CountByte := @CountByte_AVX2;
  dispatchTable.Memory.DiffRange := @MemDiffRange_AVX2;
  dispatchTable.Memory.Reverse := @MemReverse_AVX2;
  dispatchTable.Memory.MinMaxBytes := @MinMaxBytes_AVX2;
  dispatchTable.Memory.Utf8Validate := @Utf8Validate_AVX2;
  dispatchTable.Memory.AsciiIEqual := @AsciiIEqual_AVX2;
  dispatchTable.Memory.ToLowerAscii := @ToLowerAscii_AVX2;
  dispatchTable.Memory.ToUpperAscii := @ToUpperAscii_AVX2;
  dispatchTable.Memory.BytesIndexOf := @BytesIndexOf_AVX2;
  dispatchTable.Memory.BitsetPopCount := @BitsetPopCount_AVX2;
  dispatchTable.Memory.Copy := @MemCopy_AVX2;
  dispatchTable.Memory.Fill := @MemSet_AVX2;
  {$ENDIF}

  // Saturating arithmetic (VEX-encoded, always enabled)
  dispatchTable.CoreVectors.I8x16SatAdd := @AVX2I8x16SatAdd;
  dispatchTable.CoreVectors.I8x16SatSub := @AVX2I8x16SatSub;
  dispatchTable.CoreVectors.I16x8SatAdd := @AVX2I16x8SatAdd;
  dispatchTable.CoreVectors.I16x8SatSub := @AVX2I16x8SatSub;
  dispatchTable.CoreVectors.U8x16SatAdd := @AVX2U8x16SatAdd;
  dispatchTable.CoreVectors.U8x16SatSub := @AVX2U8x16SatSub;
  dispatchTable.CoreVectors.U16x8SatAdd := @AVX2U16x8SatAdd;
  dispatchTable.CoreVectors.U16x8SatSub := @AVX2U16x8SatSub;

  // Mask operations (native popcnt, always enabled)
  dispatchTable.Mask.Mask2All := @SharedMask2All;
  dispatchTable.Mask.Mask2Any := @SharedMask2Any;
  dispatchTable.Mask.Mask2None := @SharedMask2None;
  dispatchTable.Mask.Mask2PopCount := @AVX2Mask2PopCount;
  dispatchTable.Mask.Mask2FirstSet := @SharedMask2FirstSet;
  dispatchTable.Mask.Mask4All := @SharedMask4All;
  dispatchTable.Mask.Mask4Any := @SharedMask4Any;
  dispatchTable.Mask.Mask4None := @SharedMask4None;
  dispatchTable.Mask.Mask4PopCount := @AVX2Mask4PopCount;
  dispatchTable.Mask.Mask4FirstSet := @SharedMask4FirstSet;
  dispatchTable.Mask.Mask8All := @SharedMask8All;
  dispatchTable.Mask.Mask8Any := @SharedMask8Any;
  dispatchTable.Mask.Mask8None := @SharedMask8None;
  dispatchTable.Mask.Mask8PopCount := @AVX2Mask8PopCount;
  dispatchTable.Mask.Mask8FirstSet := @SharedMask8FirstSet;
  dispatchTable.Mask.Mask16All := @SharedMask16All;
  dispatchTable.Mask.Mask16Any := @SharedMask16Any;
  dispatchTable.Mask.Mask16None := @SharedMask16None;
  dispatchTable.Mask.Mask16PopCount := @AVX2Mask16PopCount;
  dispatchTable.Mask.Mask16FirstSet := @SharedMask16FirstSet;

  // Batch array operations (AVX2 256-bit)
  dispatchTable.BatchF32.ArrayAdd := @AVX2ArrayAddF32_Smart;
  dispatchTable.BatchF32.ArraySub := @AVX2ArraySubF32;
  dispatchTable.BatchF32.ArrayMul := @AVX2ArrayMulF32;
  dispatchTable.BatchF32.ArrayDiv := @AVX2ArrayDivF32;
  dispatchTable.BatchF32.ArrayMin := @AVX2ArrayMinF32;
  dispatchTable.BatchF32.ArrayMax := @AVX2ArrayMaxF32;
  dispatchTable.BatchF32.ArrayAbs := @AVX2ArrayAbsF32;
  dispatchTable.BatchF32.ArrayNeg := @AVX2ArrayNegF32;
  dispatchTable.BatchF32.ArraySqrt := @AVX2ArraySqrtF32;
  dispatchTable.BatchF32.ArrayRcp := @AVX2ArrayRcpF32;
  dispatchTable.BatchF32.ArrayRsqrt := @AVX2ArrayRsqrtF32;
  dispatchTable.BatchF32.ArrayRcpRefine := @AVX2ArrayRcpRefineF32;
  dispatchTable.BatchF32.ArrayRsqrtRefine := @AVX2ArrayRsqrtRefineF32;
  dispatchTable.BatchF32.ArrayAddScalar := @AVX2ArrayAddScalarF32;
  dispatchTable.BatchF32.ArrayMulScalar := @AVX2ArrayMulScalarF32;
  dispatchTable.BatchF32.ArrayClamp := @AVX2ArrayClampF32;
  if LHasHardwareFma then
    dispatchTable.BatchF32.ArrayFma := @AVX2ArrayFmaF32;
  dispatchTable.BatchF32.ArrayAxpy := @AVX2ArrayAxpyF32;
  dispatchTable.BatchF32.ReduceSum := @AVX2ReduceSumF32;
  dispatchTable.BatchF32.ReduceDot := @AVX2ReduceDotF32;
  dispatchTable.BatchF32.ReduceMin := @AVX2ReduceMinF32;
  dispatchTable.BatchF32.ReduceMax := @AVX2ReduceMaxF32;

  // Trig, log, rounding - use AVX2 256-bit implementations where available
  dispatchTable.BatchF32.ArraySin := @AVX2ArraySinF32;
  dispatchTable.BatchF32.ArrayCos := @AVX2ArrayCosF32;
  dispatchTable.BatchF32.ArrayExp := @AVX2ArrayExpF32;
  dispatchTable.BatchF32.ArrayLog := @AVX2ArrayLogF32;
  dispatchTable.BatchF32.ArrayPow := @AVX2ArrayPowF32;
  dispatchTable.BatchF32.ArrayCeil := @AVX2ArrayCeilF32;
  dispatchTable.BatchF32.ArrayFloor := @AVX2ArrayFloorF32;
  dispatchTable.BatchF32.ArrayRound := @AVX2ArrayRoundF32;
  dispatchTable.BatchF32.ArrayTrunc := @AVX2ArrayTruncF32;
  dispatchTable.BatchF32.ArrayLerp := @AVX2ArrayLerpF32;
  // These delegate to SSE2 but still use SIMD internally
  dispatchTable.BatchF32.ArrayTan := @AVX2ArrayTanF32;
  dispatchTable.BatchF32.ArraySinCos := @AVX2ArraySinCosF32;
  dispatchTable.BatchF32.ArrayLog2 := @AVX2ArrayLog2F32;
  dispatchTable.BatchF32.ArrayLog10 := @AVX2ArrayLog10F32;

  // F64 batch
  dispatchTable.BatchF64.ArrayAdd := @AVX2ArrayAddF64;
  dispatchTable.BatchF64.ArraySub := @AVX2ArraySubF64;
  dispatchTable.BatchF64.ArrayMul := @AVX2ArrayMulF64;
  dispatchTable.BatchF64.ArrayDiv := @AVX2ArrayDivF64;
  dispatchTable.BatchF64.ArrayAbs := @AVX2ArrayAbsF64;
  dispatchTable.BatchF64.ArrayNeg := @AVX2ArrayNegF64;
  dispatchTable.BatchF64.ArraySqrt := @AVX2ArraySqrtF64;
  dispatchTable.BatchF64.ArrayMulScalar := @AVX2ArrayMulScalarF64;
  dispatchTable.BatchF64.ArrayAddScalar := @AVX2ArrayAddScalarF64;
  dispatchTable.BatchF64.ArrayClamp := @AVX2ArrayClampF64;
  dispatchTable.BatchF64.ArrayLinear := @AVX2ArrayLinearF64;
  dispatchTable.BatchF64.ReduceSum := @AVX2ReduceSumF64;
  dispatchTable.BatchF64.ReduceDot := @AVX2ReduceDotF64;
  dispatchTable.BatchF64.ReduceMin := @AVX2ReduceMinF64;
  dispatchTable.BatchF64.ReduceMax := @AVX2ReduceMaxF64;
  dispatchTable.BatchF64.ArrayMin := @AVX2ArrayMinF64;
  dispatchTable.BatchF64.ArrayMax := @AVX2ArrayMaxF64;
  dispatchTable.BatchF64.ArrayFma := @AVX2ArrayFmaF64;

  // F64 extended batch
  dispatchTable.BatchF64.ArrayAxpy := @AVX2ArrayAxpyF64;
  dispatchTable.BatchF64.ArrayRcp := @AVX2ArrayRcpF64;
  dispatchTable.BatchF64.ArrayRsqrt := @AVX2ArrayRsqrtF64;
  dispatchTable.BatchF64.ArrayRcpRefine := @ScalarArrayRcpRefineF64;
  dispatchTable.BatchF64.ArrayRsqrtRefine := @ScalarArrayRsqrtRefineF64;
  dispatchTable.BatchF64.ArrayTan := @AVX2ArrayTanF64;
  dispatchTable.BatchF64.ArraySign := @AVX2ArraySignF64;
  dispatchTable.BatchF64.ArrayFract := @AVX2ArrayFractF64;
  dispatchTable.BatchF64.ArrayMod := @AVX2ArrayModF64;
  dispatchTable.BatchF64.ArrayPow := @AVX2ArrayPowF64;
  dispatchTable.BatchF64.ArrayLerp := @AVX2ArrayLerpF64;
  dispatchTable.BatchF64.ArrayReLU := @AVX2ArrayReLUF64;
  dispatchTable.BatchF64.ArrayAbsDiff := @AVX2ArrayAbsDiffF64;
  dispatchTable.BatchF64.ArrayNorm := @AVX2ArrayNormF64;
  dispatchTable.BatchF64.ArrayLinearReLU := @AVX2ArrayLinearReLUF64;
  dispatchTable.BatchF64.ArrayStep := @AVX2ArrayStepF64;
  dispatchTable.BatchF64.ArraySmoothstep := @AVX2ArraySmoothstepF64;
  dispatchTable.BatchF64.ArrayAtan2 := @AVX2ArrayAtan2F64;
  dispatchTable.BatchF64.ArrayHypot := @AVX2ArrayHypotF64;

  // F64 Transcendental (AVX2 with loop unrolling)
  dispatchTable.BatchF64.ArraySin := @AVX2ArraySinF64;
  dispatchTable.BatchF64.ArrayCos := @AVX2ArrayCosF64;
  dispatchTable.BatchF64.ArrayExp := @AVX2ArrayExpF64;
  dispatchTable.BatchF64.ArrayLog := @AVX2ArrayLogF64;
  dispatchTable.BatchF64.ArrayLog2 := @AVX2ArrayLog2F64;
  dispatchTable.BatchF64.ArrayLog10 := @AVX2ArrayLog10F64;

  // F64 Rounding (AVX2 vroundpd)
  dispatchTable.BatchF64.ArrayCeil := @AVX2ArrayCeilF64;
  dispatchTable.BatchF64.ArrayFloor := @AVX2ArrayFloorF64;
  dispatchTable.BatchF64.ArrayRound := @AVX2ArrayRoundF64;
  dispatchTable.BatchF64.ArrayTrunc := @AVX2ArrayTruncF64;

  // Integer batch
  dispatchTable.BatchInteger.ArrayAddI32 := @AVX2ArrayAddI32;
  dispatchTable.BatchInteger.ArraySubI32 := @AVX2ArraySubI32;
  dispatchTable.BatchInteger.ArrayMulI16 := @AVX2ArrayMulI16;
  dispatchTable.BatchInteger.ArrayPackSatI32toI16 := @AVX2ArrayPackSatI32toI16;

  // Type conversion
  dispatchTable.BatchInteger.ArrayF32toI32 := @AVX2ArrayF32toI32;
  dispatchTable.BatchInteger.ArrayI32toF32 := @AVX2ArrayI32toF32;

  // Bitwise batch
  dispatchTable.BatchInteger.ArrayAndI32 := @AVX2ArrayAndI32;
  dispatchTable.BatchInteger.ArrayOrI32 := @AVX2ArrayOrI32;
  dispatchTable.BatchInteger.ArrayXorI32 := @AVX2ArrayXorI32;
  dispatchTable.BatchInteger.ArrayShlI32 := @AVX2ArrayShlI32;
  dispatchTable.BatchInteger.ArrayShrI32 := @AVX2ArrayShrI32;

  // Transcendental (SIMD polynomial approximation)
  dispatchTable.BatchF32.ArrayExp := @AVX2ArrayExpF32;
  dispatchTable.BatchF32.ArrayLog := @AVX2ArrayLogF32;
  dispatchTable.BatchF32.ArraySin := @AVX2ArraySinF32;
  dispatchTable.BatchF32.ArrayCos := @AVX2ArrayCosF32;
  dispatchTable.BatchF32.ArrayPow := @AVX2ArrayPowF32;

  // Fused (single-pass, reduced memory traffic)
  dispatchTable.BatchF32.ArrayLinear := @AVX2ArrayLinearF32;
  dispatchTable.BatchF32.ArrayAbsDiff := @AVX2ArrayAbsDiffF32;
  dispatchTable.BatchF32.ArrayReLU := @AVX2ArrayReLUF32;
  dispatchTable.BatchF32.ArrayNorm := @AVX2ArrayNormF32;
  dispatchTable.BatchF32.ArrayLinearReLU := @AVX2ArrayLinearReLUF32;

  // Register the backend
  RegisterBackend(sbAVX2, dispatchTable);
end;

initialization
  RegisterAVX2Backend;
  // Register rebuilder callback for VectorAsmEnabled changes
  RegisterBackendRebuilder(sbAVX2, @RegisterAVX2Backend);
