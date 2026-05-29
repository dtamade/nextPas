procedure RegisterSSE2Backend;
var
  dispatchTable: TSimdDispatchTable;
  LUseVectorAsm: Boolean;
begin
  // Only register if SSE2 is available
  if not HasSSE2 then
    Exit;

  LUseVectorAsm := IsVectorAsmEnabled;

  // Fill with base scalar implementations (provides fallback for all operations)
  dispatchTable := Default(TSimdDispatchTable);
  FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbSSE2;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbSSE2;
    Name := 'SSE2';
    Description := 'x86-64 SSE2 SIMD implementation';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction,
                     scLoadStore];
    Include(Capabilities, scMaskedOps);
    Include(Capabilities, scIntegerOps);
    if LUseVectorAsm then
      Include(Capabilities, scShuffle);
    Available := LUseVectorAsm;
    Priority := GetSimdBackendPriorityValue(sbSSE2);
  end;

  // Vector-related operations default to Scalar reference implementations.

  if LUseVectorAsm then
  begin
    // Override with SSE2 arithmetic operations
    dispatchTable.AddF32x4 := @SSE2AddF32x4;
    dispatchTable.SubF32x4 := @SSE2SubF32x4;
    dispatchTable.MulF32x4 := @SSE2MulF32x4;
    dispatchTable.DivF32x4 := @SSE2DivF32x4;

    dispatchTable.AddF32x8 := @SSE2AddF32x8;
    dispatchTable.SubF32x8 := @SSE2SubF32x8;
    dispatchTable.MulF32x8 := @SSE2MulF32x8;
    dispatchTable.DivF32x8 := @SSE2DivF32x8;

    // F32x8 扩展函数 (2026-02-05)
    dispatchTable.FmaF32x8 := @SSE2FmaF32x8;
    dispatchTable.FloorF32x8 := @SSE2FloorF32x8;
    dispatchTable.CeilF32x8 := @SSE2CeilF32x8;
    dispatchTable.RoundF32x8 := @SSE2RoundF32x8;
    dispatchTable.TruncF32x8 := @SSE2TruncF32x8;
    dispatchTable.AbsF32x8 := @SSE2AbsF32x8;
    dispatchTable.SqrtF32x8 := @SSE2SqrtF32x8;
    dispatchTable.MinF32x8 := @SSE2MinF32x8;
    dispatchTable.MaxF32x8 := @SSE2MaxF32x8;
    dispatchTable.ClampF32x8 := @SSE2ClampF32x8;
    dispatchTable.ReduceAddF32x8 := @SSE2ReduceAddF32x8;
    dispatchTable.ReduceMinF32x8 := @SSE2ReduceMinF32x8;
    dispatchTable.ReduceMaxF32x8 := @SSE2ReduceMaxF32x8;
    dispatchTable.ReduceMulF32x8 := @SSE2ReduceMulF32x8;
    dispatchTable.LoadF32x8 := @SSE2LoadF32x8;
    dispatchTable.StoreF32x8 := @SSE2StoreF32x8;
    dispatchTable.SplatF32x8 := @SSE2SplatF32x8;
    dispatchTable.ZeroF32x8 := @SSE2ZeroF32x8;

    // F32x8 comparison operations (2x F32x4)
    dispatchTable.CmpEqF32x8 := @SSE2CmpEqF32x8;
    dispatchTable.CmpLtF32x8 := @SSE2CmpLtF32x8;
    dispatchTable.CmpLeF32x8 := @SSE2CmpLeF32x8;
    dispatchTable.CmpGtF32x8 := @SSE2CmpGtF32x8;
    dispatchTable.CmpGeF32x8 := @SSE2CmpGeF32x8;
    dispatchTable.CmpNeF32x8 := @SSE2CmpNeF32x8;

    dispatchTable.AddF64x2 := @SSE2AddF64x2;
    dispatchTable.SubF64x2 := @SSE2SubF64x2;
    dispatchTable.MulF64x2 := @SSE2MulF64x2;
    dispatchTable.DivF64x2 := @SSE2DivF64x2;

    // F64x2 math operations
    dispatchTable.SqrtF64x2 := @SSE2SqrtF64x2;
    dispatchTable.MinF64x2 := @SSE2MinF64x2;
    dispatchTable.MaxF64x2 := @SSE2MaxF64x2;
    dispatchTable.AbsF64x2 := @SSE2AbsF64x2;

    // F64x2 comparison operations
    dispatchTable.CmpEqF64x2 := @SSE2CmpEqF64x2;
    dispatchTable.CmpLtF64x2 := @SSE2CmpLtF64x2;
    dispatchTable.CmpLeF64x2 := @SSE2CmpLeF64x2;
    dispatchTable.CmpGtF64x2 := @SSE2CmpGtF64x2;
    dispatchTable.CmpGeF64x2 := @SSE2CmpGeF64x2;
    dispatchTable.CmpNeF64x2 := @SSE2CmpNeF64x2;

    // F64x2 utility operations
    dispatchTable.LoadF64x2 := @SSE2LoadF64x2;
    dispatchTable.StoreF64x2 := @SSE2StoreF64x2;
    dispatchTable.SplatF64x2 := @SSE2SplatF64x2;
    dispatchTable.ZeroF64x2 := @SSE2ZeroF64x2;

    // F64x2 扩展函数 (2026-02-05)
    dispatchTable.FloorF64x2 := @SSE2FloorF64x2;
    dispatchTable.CeilF64x2 := @SSE2CeilF64x2;
    dispatchTable.RoundF64x2 := @SSE2RoundF64x2;
    dispatchTable.TruncF64x2 := @SSE2TruncF64x2;
    dispatchTable.FmaF64x2 := @SSE2FmaF64x2;
    dispatchTable.ClampF64x2 := @SSE2ClampF64x2;
    dispatchTable.ReduceAddF64x2 := @SSE2ReduceAddF64x2;
    dispatchTable.ReduceMinF64x2 := @SSE2ReduceMinF64x2;
    dispatchTable.ReduceMaxF64x2 := @SSE2ReduceMaxF64x2;
    dispatchTable.ReduceMulF64x2 := @SSE2ReduceMulF64x2;

    // F64x4 分解实现 (2026-02-05) - 使用 2x F64x2
    dispatchTable.AddF64x4 := @SSE2AddF64x4;
    dispatchTable.SubF64x4 := @SSE2SubF64x4;
    dispatchTable.MulF64x4 := @SSE2MulF64x4;
    dispatchTable.DivF64x4 := @SSE2DivF64x4;
    dispatchTable.FmaF64x4 := @SSE2FmaF64x4;
    dispatchTable.RcpF64x4 := @SSE2RcpF64x4;
    dispatchTable.FloorF64x4 := @SSE2FloorF64x4;
    dispatchTable.CeilF64x4 := @SSE2CeilF64x4;
    dispatchTable.RoundF64x4 := @SSE2RoundF64x4;
    dispatchTable.TruncF64x4 := @SSE2TruncF64x4;
    dispatchTable.AbsF64x4 := @SSE2AbsF64x4;
    dispatchTable.SqrtF64x4 := @SSE2SqrtF64x4;
    dispatchTable.MinF64x4 := @SSE2MinF64x4;
    dispatchTable.MaxF64x4 := @SSE2MaxF64x4;
    dispatchTable.ClampF64x4 := @SSE2ClampF64x4;
    dispatchTable.ReduceAddF64x4 := @SSE2ReduceAddF64x4;
    dispatchTable.ReduceMinF64x4 := @SSE2ReduceMinF64x4;
    dispatchTable.ReduceMaxF64x4 := @SSE2ReduceMaxF64x4;
    dispatchTable.ReduceMulF64x4 := @SSE2ReduceMulF64x4;
    dispatchTable.LoadF64x4 := @SSE2LoadF64x4;
    dispatchTable.StoreF64x4 := @SSE2StoreF64x4;
    dispatchTable.SplatF64x4 := @SSE2SplatF64x4;
    dispatchTable.ZeroF64x4 := @SSE2ZeroF64x4;

    // F64x4 comparison operations (2x F64x2)
    dispatchTable.CmpEqF64x4 := @SSE2CmpEqF64x4;
    dispatchTable.CmpLtF64x4 := @SSE2CmpLtF64x4;
    dispatchTable.CmpLeF64x4 := @SSE2CmpLeF64x4;
    dispatchTable.CmpGtF64x4 := @SSE2CmpGtF64x4;
    dispatchTable.CmpGeF64x4 := @SSE2CmpGeF64x4;
    dispatchTable.CmpNeF64x4 := @SSE2CmpNeF64x4;

    dispatchTable.AddI32x4 := @SSE2AddI32x4;
    dispatchTable.SubI32x4 := @SSE2SubI32x4;
    dispatchTable.MulI32x4 := @SSE2MulI32x4;

    // I32x4 bitwise operations
    dispatchTable.AndI32x4 := @SSE2AndI32x4;
    dispatchTable.OrI32x4 := @SSE2OrI32x4;
    dispatchTable.XorI32x4 := @SSE2XorI32x4;
    dispatchTable.NotI32x4 := @SSE2NotI32x4;
    dispatchTable.AndNotI32x4 := @SSE2AndNotI32x4;

    // I32x4 shift operations
    dispatchTable.ShiftLeftI32x4 := @SSE2ShiftLeftI32x4;
    dispatchTable.ShiftRightI32x4 := @SSE2ShiftRightI32x4;
    dispatchTable.ShiftRightArithI32x4 := @SSE2ShiftRightArithI32x4;

    // I32x4 comparison operations
    dispatchTable.CmpEqI32x4 := @SSE2CmpEqI32x4;
    dispatchTable.CmpLtI32x4 := @SSE2CmpLtI32x4;
    dispatchTable.CmpGtI32x4 := @SSE2CmpGtI32x4;
    dispatchTable.CmpLeI32x4 := @SSE2CmpLeI32x4;
    dispatchTable.CmpGeI32x4 := @SSE2CmpGeI32x4;
    dispatchTable.CmpNeI32x4 := @SSE2CmpNeI32x4;

    // I32x4 min/max operations
    dispatchTable.MinI32x4 := @SSE2MinI32x4;
    dispatchTable.MaxI32x4 := @SSE2MaxI32x4;

    // I32x8 分解实现 (2026-02-05) - 使用 2x I32x4
    dispatchTable.AddI32x8 := @SSE2AddI32x8;
    dispatchTable.SubI32x8 := @SSE2SubI32x8;
    dispatchTable.MulI32x8 := @SSE2MulI32x8;
    dispatchTable.AndI32x8 := @SSE2AndI32x8;
    dispatchTable.OrI32x8 := @SSE2OrI32x8;
    dispatchTable.XorI32x8 := @SSE2XorI32x8;
    dispatchTable.NotI32x8 := @SSE2NotI32x8;
    dispatchTable.AndNotI32x8 := @SSE2AndNotI32x8;
    dispatchTable.ShiftLeftI32x8 := @SSE2ShiftLeftI32x8;
    dispatchTable.ShiftRightI32x8 := @SSE2ShiftRightI32x8;
    dispatchTable.ShiftRightArithI32x8 := @SSE2ShiftRightArithI32x8;
    dispatchTable.CmpEqI32x8 := @SSE2CmpEqI32x8;
    dispatchTable.CmpLtI32x8 := @SSE2CmpLtI32x8;
    dispatchTable.CmpGtI32x8 := @SSE2CmpGtI32x8;
    dispatchTable.CmpLeI32x8 := @SSE2CmpLeI32x8;
    dispatchTable.CmpGeI32x8 := @SSE2CmpGeI32x8;
    dispatchTable.CmpNeI32x8 := @SSE2CmpNeI32x8;
    dispatchTable.MinI32x8 := @SSE2MinI32x8;
    dispatchTable.MaxI32x8 := @SSE2MaxI32x8;

    // 512-bit 向量的 SSE2 渐进降级实现 (2026-02-05)

    // F32x16 (16×Float32)
    dispatchTable.AddF32x16 := @SSE2AddF32x16;
    dispatchTable.SubF32x16 := @SSE2SubF32x16;
    dispatchTable.MulF32x16 := @SSE2MulF32x16;
    dispatchTable.DivF32x16 := @SSE2DivF32x16;
    dispatchTable.AbsF32x16 := @SSE2AbsF32x16;
    dispatchTable.SqrtF32x16 := @SSE2SqrtF32x16;
    dispatchTable.MinF32x16 := @SSE2MinF32x16;
    dispatchTable.MaxF32x16 := @SSE2MaxF32x16;
    dispatchTable.FmaF32x16 := @SSE2FmaF32x16;
    dispatchTable.FloorF32x16 := @SSE2FloorF32x16;
    dispatchTable.CeilF32x16 := @SSE2CeilF32x16;
    dispatchTable.RoundF32x16 := @SSE2RoundF32x16;
    dispatchTable.TruncF32x16 := @SSE2TruncF32x16;
    dispatchTable.ClampF32x16 := @SSE2ClampF32x16;
    dispatchTable.ReduceAddF32x16 := @SSE2ReduceAddF32x16;
    dispatchTable.ReduceMinF32x16 := @SSE2ReduceMinF32x16;
    dispatchTable.ReduceMaxF32x16 := @SSE2ReduceMaxF32x16;
    dispatchTable.ReduceMulF32x16 := @SSE2ReduceMulF32x16;
    dispatchTable.LoadF32x16 := @SSE2LoadF32x16;
    dispatchTable.StoreF32x16 := @SSE2StoreF32x16;
    dispatchTable.SplatF32x16 := @SSE2SplatF32x16;
    dispatchTable.ZeroF32x16 := @SSE2ZeroF32x16;
    dispatchTable.CmpEqF32x16 := @SSE2CmpEqF32x16;
    dispatchTable.CmpLtF32x16 := @SSE2CmpLtF32x16;
    dispatchTable.CmpLeF32x16 := @SSE2CmpLeF32x16;
    dispatchTable.CmpGtF32x16 := @SSE2CmpGtF32x16;
    dispatchTable.CmpGeF32x16 := @SSE2CmpGeF32x16;
    dispatchTable.CmpNeF32x16 := @SSE2CmpNeF32x16;
    dispatchTable.SelectF32x16 := @SSE2SelectF32x16;

    // F64x8 (8×Float64)
    dispatchTable.AddF64x8 := @SSE2AddF64x8;
    dispatchTable.SubF64x8 := @SSE2SubF64x8;
    dispatchTable.MulF64x8 := @SSE2MulF64x8;
    dispatchTable.DivF64x8 := @SSE2DivF64x8;
    dispatchTable.AbsF64x8 := @SSE2AbsF64x8;
    dispatchTable.SqrtF64x8 := @SSE2SqrtF64x8;
    dispatchTable.MinF64x8 := @SSE2MinF64x8;
    dispatchTable.MaxF64x8 := @SSE2MaxF64x8;
    dispatchTable.FmaF64x8 := @SSE2FmaF64x8;
    dispatchTable.FloorF64x8 := @SSE2FloorF64x8;
    dispatchTable.CeilF64x8 := @SSE2CeilF64x8;
    dispatchTable.RoundF64x8 := @SSE2RoundF64x8;
    dispatchTable.TruncF64x8 := @SSE2TruncF64x8;
    dispatchTable.ClampF64x8 := @SSE2ClampF64x8;
    dispatchTable.ReduceAddF64x8 := @SSE2ReduceAddF64x8;
    dispatchTable.ReduceMinF64x8 := @SSE2ReduceMinF64x8;
    dispatchTable.ReduceMaxF64x8 := @SSE2ReduceMaxF64x8;
    dispatchTable.ReduceMulF64x8 := @SSE2ReduceMulF64x8;
    dispatchTable.LoadF64x8 := @SSE2LoadF64x8;
    dispatchTable.StoreF64x8 := @SSE2StoreF64x8;
    dispatchTable.SplatF64x8 := @SSE2SplatF64x8;
    dispatchTable.ZeroF64x8 := @SSE2ZeroF64x8;
    dispatchTable.CmpEqF64x8 := @SSE2CmpEqF64x8;
    dispatchTable.CmpLtF64x8 := @SSE2CmpLtF64x8;
    dispatchTable.CmpLeF64x8 := @SSE2CmpLeF64x8;
    dispatchTable.CmpGtF64x8 := @SSE2CmpGtF64x8;
    dispatchTable.CmpGeF64x8 := @SSE2CmpGeF64x8;
    dispatchTable.CmpNeF64x8 := @SSE2CmpNeF64x8;
    dispatchTable.SelectF64x8 := @SSE2SelectF64x8;

    // I32x16 (16×Int32)
    dispatchTable.AddI32x16 := @SSE2AddI32x16;
    dispatchTable.SubI32x16 := @SSE2SubI32x16;
    dispatchTable.MulI32x16 := @SSE2MulI32x16;
    dispatchTable.AndI32x16 := @SSE2AndI32x16;
    dispatchTable.OrI32x16 := @SSE2OrI32x16;
    dispatchTable.XorI32x16 := @SSE2XorI32x16;
    dispatchTable.NotI32x16 := @SSE2NotI32x16;
    dispatchTable.AndNotI32x16 := @SSE2AndNotI32x16;
    dispatchTable.ShiftLeftI32x16 := @SSE2ShiftLeftI32x16;
    dispatchTable.ShiftRightI32x16 := @SSE2ShiftRightI32x16;
    dispatchTable.ShiftRightArithI32x16 := @SSE2ShiftRightArithI32x16;
    dispatchTable.CmpEqI32x16 := @SSE2CmpEqI32x16;
    dispatchTable.CmpLtI32x16 := @SSE2CmpLtI32x16;
    dispatchTable.CmpGtI32x16 := @SSE2CmpGtI32x16;
    dispatchTable.CmpLeI32x16 := @SSE2CmpLeI32x16;
    dispatchTable.CmpGeI32x16 := @SSE2CmpGeI32x16;
    dispatchTable.CmpNeI32x16 := @SSE2CmpNeI32x16;
    dispatchTable.MinI32x16 := @SSE2MinI32x16;
    dispatchTable.MaxI32x16 := @SSE2MaxI32x16;

    // I64x2 arithmetic and bitwise
    dispatchTable.AddI64x2 := @SSE2AddI64x2;
    dispatchTable.SubI64x2 := @SSE2SubI64x2;
    dispatchTable.AndI64x2 := @SSE2AndI64x2;
    dispatchTable.OrI64x2 := @SSE2OrI64x2;
    dispatchTable.XorI64x2 := @SSE2XorI64x2;
    dispatchTable.NotI64x2 := @SSE2NotI64x2;
    dispatchTable.AndNotI64x2 := @SSE2AndNotI64x2;

    // I64x2 comparison operations (SSE2 emulation)
    // SSE2 没有原生 64 位整数比较指令（PCMPGTQ 是 SSE4.2）
    // 使用 32 位比较的组合逻辑来模拟 64 位比较
    dispatchTable.CmpEqI64x2 := @SSE2CmpEqI64x2;
    dispatchTable.CmpNeI64x2 := @SSE2CmpNeI64x2;
    dispatchTable.CmpGtI64x2 := @SSE2CmpGtI64x2;
    dispatchTable.CmpLtI64x2 := @SSE2CmpLtI64x2;
    dispatchTable.CmpGeI64x2 := @SSE2CmpGeI64x2;
    dispatchTable.CmpLeI64x2 := @SSE2CmpLeI64x2;

    // Override with SSE2 comparison operations
    dispatchTable.CmpEqF32x4 := @SSE2CmpEqF32x4;
    dispatchTable.CmpLtF32x4 := @SSE2CmpLtF32x4;
    dispatchTable.CmpLeF32x4 := @SSE2CmpLeF32x4;
    dispatchTable.CmpGtF32x4 := @SSE2CmpGtF32x4;
    dispatchTable.CmpGeF32x4 := @SSE2CmpGeF32x4;
    dispatchTable.CmpNeF32x4 := @SSE2CmpNeF32x4;

    // Override with SSE2 math functions
    dispatchTable.AbsF32x4 := @SSE2AbsF32x4;
    dispatchTable.SqrtF32x4 := @SSE2SqrtF32x4;
    dispatchTable.MinF32x4 := @SSE2MinF32x4;
    dispatchTable.MaxF32x4 := @SSE2MaxF32x4;

    // Override with SSE2 extended math functions
    dispatchTable.FmaF32x4 := @SSE2FmaF32x4;
    dispatchTable.RcpF32x4 := @SSE2RcpF32x4;
    dispatchTable.RsqrtF32x4 := @SSE2RsqrtF32x4;
    dispatchTable.FloorF32x4 := @SSE2FloorF32x4;
    dispatchTable.CeilF32x4 := @SSE2CeilF32x4;
    dispatchTable.RoundF32x4 := @SSE2RoundF32x4;
    dispatchTable.TruncF32x4 := @SSE2TruncF32x4;
    dispatchTable.ClampF32x4 := @SSE2ClampF32x4;

    // Override with SSE2 vector math functions
    dispatchTable.DotF32x4 := @SSE2DotF32x4;
    dispatchTable.DotF32x3 := @SSE2DotF32x3;
    dispatchTable.CrossF32x3 := @SSE2CrossF32x3;
    dispatchTable.LengthF32x4 := @SSE2LengthF32x4;
    dispatchTable.LengthF32x3 := @SSE2LengthF32x3;
    dispatchTable.NormalizeF32x4 := @SSE2NormalizeF32x4;
    dispatchTable.NormalizeF32x3 := @SSE2NormalizeF32x3;

    // Override with SSE2 reduction operations
    dispatchTable.ReduceAddF32x4 := @SSE2ReduceAddF32x4;
    dispatchTable.ReduceMinF32x4 := @SSE2ReduceMinF32x4;
    dispatchTable.ReduceMaxF32x4 := @SSE2ReduceMaxF32x4;
    dispatchTable.ReduceMulF32x4 := @SSE2ReduceMulF32x4;

    // Override with SSE2 memory operations
    dispatchTable.LoadF32x4 := @SSE2LoadF32x4;
    dispatchTable.LoadF32x4Aligned := @SSE2LoadF32x4Aligned;
    dispatchTable.StoreF32x4 := @SSE2StoreF32x4;
    dispatchTable.StoreF32x4Aligned := @SSE2StoreF32x4Aligned;

    // Override with SSE2 utility operations
    dispatchTable.SplatF32x4 := @SSE2SplatF32x4;
    dispatchTable.ZeroF32x4 := @SSE2ZeroF32x4;
    dispatchTable.SelectF32x4 := @SSE2SelectF32x4;
    dispatchTable.ExtractF32x4 := @SSE2ExtractF32x4;
    dispatchTable.InsertF32x4 := @SSE2InsertF32x4;

    // SelectF64x2
    dispatchTable.SelectF64x2 := @SSE2SelectF64x2;

    // 缺失的 Select 操作
    dispatchTable.SelectI32x4 := @SSE2SelectI32x4;
    dispatchTable.SelectF32x8 := @SSE2SelectF32x8;
    dispatchTable.SelectF64x4 := @SSE2SelectF64x4;
  end;
  // else: keep scalar implementations from FillBaseDispatchTable

  // Override facade functions with SSE2-accelerated versions
  dispatchTable.MemEqual := @MemEqual_SSE2;
  dispatchTable.MemFindByte := @MemFindByte_SSE2;
  dispatchTable.SumBytes := @SumBytes_SSE2;
  dispatchTable.CountByte := @CountByte_SSE2;
  dispatchTable.MinMaxBytes := @MinMaxBytes_SSE2;
  dispatchTable.BitsetPopCount := @BitsetPopCount_SSE2;
  // Register SSE2 memory operations
  dispatchTable.MemCopy := @MemCopy_SSE2;
  dispatchTable.MemSet := @MemSet_SSE2;
  // Wide/helper facade overrides are applied below to keep SSE2-owned implementations active.

  // Override with SSE2 saturating arithmetic (always enabled, stable ops)
  dispatchTable.I8x16SatAdd := @SSE2I8x16SatAdd;
  dispatchTable.I8x16SatSub := @SSE2I8x16SatSub;
  dispatchTable.I16x8SatAdd := @SSE2I16x8SatAdd;
  dispatchTable.I16x8SatSub := @SSE2I16x8SatSub;
  dispatchTable.U8x16SatAdd := @SSE2U8x16SatAdd;
  dispatchTable.U8x16SatSub := @SSE2U8x16SatSub;
  dispatchTable.U16x8SatAdd := @SSE2U16x8SatAdd;
  dispatchTable.U16x8SatSub := @SSE2U16x8SatSub;

  // I16x8 operations (SSE2)
  dispatchTable.AddI16x8 := @SSE2AddI16x8;
  dispatchTable.SubI16x8 := @SSE2SubI16x8;
  dispatchTable.MulI16x8 := @SSE2MulI16x8;
  dispatchTable.AndI16x8 := @SSE2AndI16x8;
  dispatchTable.OrI16x8 := @SSE2OrI16x8;
  dispatchTable.XorI16x8 := @SSE2XorI16x8;
  dispatchTable.NotI16x8 := @SSE2NotI16x8;
  dispatchTable.AndNotI16x8 := @SSE2AndNotI16x8;
  dispatchTable.ShiftLeftI16x8 := @SSE2ShiftLeftI16x8;
  dispatchTable.ShiftRightI16x8 := @SSE2ShiftRightI16x8;
  dispatchTable.ShiftRightArithI16x8 := @SSE2ShiftRightArithI16x8;
  dispatchTable.CmpEqI16x8 := @SSE2CmpEqI16x8;
  dispatchTable.CmpLtI16x8 := @SSE2CmpLtI16x8;
  dispatchTable.CmpGtI16x8 := @SSE2CmpGtI16x8;
  dispatchTable.CmpLeI16x8 := @SSE2CmpLeI16x8;
  dispatchTable.CmpGeI16x8 := @SSE2CmpGeI16x8;
  dispatchTable.CmpNeI16x8 := @SSE2CmpNeI16x8;
  dispatchTable.MinI16x8 := @SSE2MinI16x8;
  dispatchTable.MaxI16x8 := @SSE2MaxI16x8;

  // I8x16 operations (SSE2)
  dispatchTable.AddI8x16 := @SSE2AddI8x16;
  dispatchTable.SubI8x16 := @SSE2SubI8x16;
  dispatchTable.AndI8x16 := @SSE2AndI8x16;
  dispatchTable.OrI8x16 := @SSE2OrI8x16;
  dispatchTable.XorI8x16 := @SSE2XorI8x16;
  dispatchTable.NotI8x16 := @SSE2NotI8x16;
  dispatchTable.CmpEqI8x16 := @SSE2CmpEqI8x16;
  dispatchTable.CmpLtI8x16 := @SSE2CmpLtI8x16;
  dispatchTable.CmpGtI8x16 := @SSE2CmpGtI8x16;
  dispatchTable.CmpLeI8x16 := @SSE2CmpLeI8x16;
  dispatchTable.CmpGeI8x16 := @SSE2CmpGeI8x16;
  dispatchTable.CmpNeI8x16 := @SSE2CmpNeI8x16;
  dispatchTable.MinI8x16 := @SSE2MinI8x16;
  dispatchTable.MaxI8x16 := @SSE2MaxI8x16;

  // U32x4 operations (SSE2)
  dispatchTable.AddU32x4 := @SSE2AddU32x4;
  dispatchTable.SubU32x4 := @SSE2SubU32x4;
  dispatchTable.MulU32x4 := @SSE2MulU32x4;
  dispatchTable.AndU32x4 := @SSE2AndU32x4;
  dispatchTable.OrU32x4 := @SSE2OrU32x4;
  dispatchTable.XorU32x4 := @SSE2XorU32x4;
  dispatchTable.NotU32x4 := @SSE2NotU32x4;
  dispatchTable.AndNotU32x4 := @SSE2AndNotU32x4;
  dispatchTable.ShiftLeftU32x4 := @SSE2ShiftLeftU32x4;
  dispatchTable.ShiftRightU32x4 := @SSE2ShiftRightU32x4;
  dispatchTable.CmpEqU32x4 := @SSE2CmpEqU32x4;
  dispatchTable.CmpLtU32x4 := @SSE2CmpLtU32x4;
  dispatchTable.CmpGtU32x4 := @SSE2CmpGtU32x4;
  dispatchTable.CmpLeU32x4 := @SSE2CmpLeU32x4;
  dispatchTable.CmpGeU32x4 := @SSE2CmpGeU32x4;
  // Note: CmpNeU32x4 not in dispatch table
  dispatchTable.MinU32x4 := @SSE2MinU32x4;
  dispatchTable.MaxU32x4 := @SSE2MaxU32x4;

  // U16x8 operations (SSE2)
  dispatchTable.AddU16x8 := @SSE2AddU16x8;
  dispatchTable.SubU16x8 := @SSE2SubU16x8;
  dispatchTable.MulU16x8 := @SSE2MulU16x8;
  dispatchTable.AndU16x8 := @SSE2AndU16x8;
  dispatchTable.OrU16x8 := @SSE2OrU16x8;
  dispatchTable.XorU16x8 := @SSE2XorU16x8;
  dispatchTable.NotU16x8 := @SSE2NotU16x8;
  dispatchTable.ShiftLeftU16x8 := @SSE2ShiftLeftU16x8;
  dispatchTable.ShiftRightU16x8 := @SSE2ShiftRightU16x8;
  dispatchTable.CmpEqU16x8 := @SSE2CmpEqU16x8;
  dispatchTable.CmpLtU16x8 := @SSE2CmpLtU16x8;
  dispatchTable.CmpGtU16x8 := @SSE2CmpGtU16x8;
  dispatchTable.CmpLeU16x8 := @SSE2CmpLeU16x8;
  dispatchTable.CmpGeU16x8 := @SSE2CmpGeU16x8;
  dispatchTable.CmpNeU16x8 := @SSE2CmpNeU16x8;
  dispatchTable.MinU16x8 := @SSE2MinU16x8;
  dispatchTable.MaxU16x8 := @SSE2MaxU16x8;

  // U8x16 operations (SSE2)
  dispatchTable.AddU8x16 := @SSE2AddU8x16;
  dispatchTable.SubU8x16 := @SSE2SubU8x16;
  dispatchTable.AndU8x16 := @SSE2AndU8x16;
  dispatchTable.OrU8x16 := @SSE2OrU8x16;
  dispatchTable.XorU8x16 := @SSE2XorU8x16;
  dispatchTable.NotU8x16 := @SSE2NotU8x16;
  dispatchTable.CmpEqU8x16 := @SSE2CmpEqU8x16;
  dispatchTable.CmpLtU8x16 := @SSE2CmpLtU8x16;
  dispatchTable.CmpGtU8x16 := @SSE2CmpGtU8x16;
  dispatchTable.CmpLeU8x16 := @SSE2CmpLeU8x16;
  dispatchTable.CmpGeU8x16 := @SSE2CmpGeU8x16;
  dispatchTable.CmpNeU8x16 := @SSE2CmpNeU8x16;
  dispatchTable.MinU8x16 := @SSE2MinU8x16;
  dispatchTable.MaxU8x16 := @SSE2MaxU8x16;

  // ============================================================================
  // I64x4 操作注册 (256-bit，使用 2×I64x2 仿真)
  // ============================================================================
  dispatchTable.AddI64x4 := @SSE2AddI64x4;
  dispatchTable.SubI64x4 := @SSE2SubI64x4;
  dispatchTable.AndI64x4 := @SSE2AndI64x4;
  dispatchTable.OrI64x4 := @SSE2OrI64x4;
  dispatchTable.XorI64x4 := @SSE2XorI64x4;
  dispatchTable.NotI64x4 := @SSE2NotI64x4;
  dispatchTable.AndNotI64x4 := @SSE2AndNotI64x4;
  dispatchTable.ShiftLeftI64x4 := @SSE2ShiftLeftI64x4;
  dispatchTable.ShiftRightI64x4 := @SSE2ShiftRightI64x4;
  dispatchTable.CmpEqI64x4 := @SSE2CmpEqI64x4;
  dispatchTable.CmpLtI64x4 := @SSE2CmpLtI64x4;
  dispatchTable.CmpGtI64x4 := @SSE2CmpGtI64x4;
  dispatchTable.CmpLeI64x4 := @SSE2CmpLeI64x4;
  dispatchTable.CmpGeI64x4 := @SSE2CmpGeI64x4;
  dispatchTable.CmpNeI64x4 := @SSE2CmpNeI64x4;
  dispatchTable.LoadI64x4 := @SSE2LoadI64x4;
  dispatchTable.StoreI64x4 := @SSE2StoreI64x4;
  dispatchTable.SplatI64x4 := @SSE2SplatI64x4;
  dispatchTable.ZeroI64x4 := @SSE2ZeroI64x4;

  // ============================================================================
  // U32x8 操作注册 (256-bit，使用 2×U32x4 仿真)
  // ============================================================================
  dispatchTable.AddU32x8 := @SSE2AddU32x8;
  dispatchTable.SubU32x8 := @SSE2SubU32x8;
  dispatchTable.MulU32x8 := @SSE2MulU32x8;
  dispatchTable.AndU32x8 := @SSE2AndU32x8;
  dispatchTable.OrU32x8 := @SSE2OrU32x8;
  dispatchTable.XorU32x8 := @SSE2XorU32x8;
  dispatchTable.NotU32x8 := @SSE2NotU32x8;
  dispatchTable.AndNotU32x8 := @SSE2AndNotU32x8;
  dispatchTable.ShiftLeftU32x8 := @SSE2ShiftLeftU32x8;
  dispatchTable.ShiftRightU32x8 := @SSE2ShiftRightU32x8;
  dispatchTable.CmpEqU32x8 := @SSE2CmpEqU32x8;
  dispatchTable.CmpLtU32x8 := @SSE2CmpLtU32x8;
  dispatchTable.CmpGtU32x8 := @SSE2CmpGtU32x8;
  dispatchTable.CmpLeU32x8 := @SSE2CmpLeU32x8;
  dispatchTable.CmpGeU32x8 := @SSE2CmpGeU32x8;
  dispatchTable.CmpNeU32x8 := @SSE2CmpNeU32x8;
  dispatchTable.MinU32x8 := @SSE2MinU32x8;
  dispatchTable.MaxU32x8 := @SSE2MaxU32x8;

  // ============================================================================
  // U64x4 操作注册 (256-bit，使用纯标量仿真)
  // ============================================================================
  dispatchTable.AddU64x4 := @SSE2AddU64x4;
  dispatchTable.SubU64x4 := @SSE2SubU64x4;
  dispatchTable.AndU64x4 := @SSE2AndU64x4;
  dispatchTable.OrU64x4 := @SSE2OrU64x4;
  dispatchTable.XorU64x4 := @SSE2XorU64x4;
  dispatchTable.NotU64x4 := @SSE2NotU64x4;
  dispatchTable.ShiftLeftU64x4 := @SSE2ShiftLeftU64x4;
  dispatchTable.ShiftRightU64x4 := @SSE2ShiftRightU64x4;
  dispatchTable.CmpEqU64x4 := @SSE2CmpEqU64x4;
  dispatchTable.CmpLtU64x4 := @SSE2CmpLtU64x4;
  dispatchTable.CmpGtU64x4 := @SSE2CmpGtU64x4;
  dispatchTable.CmpLeU64x4 := @SSE2CmpLeU64x4;
  dispatchTable.CmpGeU64x4 := @SSE2CmpGeU64x4;
  dispatchTable.CmpNeU64x4 := @SSE2CmpNeU64x4;

  // ============================================================================
  // I64x8 操作注册 (512-bit，使用 2×I64x4 仿真)
  // ============================================================================
  dispatchTable.AddI64x8 := @SSE2AddI64x8;
  dispatchTable.SubI64x8 := @SSE2SubI64x8;
  dispatchTable.AndI64x8 := @SSE2AndI64x8;
  dispatchTable.OrI64x8 := @SSE2OrI64x8;
  dispatchTable.XorI64x8 := @SSE2XorI64x8;
  dispatchTable.NotI64x8 := @SSE2NotI64x8;
  dispatchTable.CmpEqI64x8 := @SSE2CmpEqI64x8;
  dispatchTable.CmpLtI64x8 := @SSE2CmpLtI64x8;
  dispatchTable.CmpGtI64x8 := @SSE2CmpGtI64x8;
  dispatchTable.CmpLeI64x8 := @SSE2CmpLeI64x8;
  dispatchTable.CmpGeI64x8 := @SSE2CmpGeI64x8;
  dispatchTable.CmpNeI64x8 := @SSE2CmpNeI64x8;

  // ============================================================================
  // Extract/Insert 操作注册
  // ============================================================================
  dispatchTable.ExtractF64x2 := @SSE2ExtractF64x2;
  dispatchTable.InsertF64x2 := @SSE2InsertF64x2;
  dispatchTable.ExtractI32x4 := @SSE2ExtractI32x4;
  dispatchTable.InsertI32x4 := @SSE2InsertI32x4;
  dispatchTable.ExtractI64x2 := @SSE2ExtractI64x2;
  dispatchTable.InsertI64x2 := @SSE2InsertI64x2;
  dispatchTable.ExtractF32x8 := @SSE2ExtractF32x8;
  dispatchTable.InsertF32x8 := @SSE2InsertF32x8;
  dispatchTable.ExtractF64x4 := @SSE2ExtractF64x4;
  dispatchTable.InsertF64x4 := @SSE2InsertF64x4;
  dispatchTable.ExtractI32x8 := @SSE2ExtractI32x8;
  dispatchTable.InsertI32x8 := @SSE2InsertI32x8;
  dispatchTable.ExtractI64x4 := @SSE2ExtractI64x4;
  dispatchTable.InsertI64x4 := @SSE2InsertI64x4;
  dispatchTable.ExtractF32x16 := @SSE2ExtractF32x16;
  dispatchTable.InsertF32x16 := @SSE2InsertF32x16;
  dispatchTable.ExtractI32x16 := @SSE2ExtractI32x16;
  dispatchTable.InsertI32x16 := @SSE2InsertI32x16;

  // ============================================================================
  // Facade 函数注册
  // ============================================================================
  dispatchTable.MemDiffRange := @MemDiffRange_SSE2;
  dispatchTable.MemReverse := @MemReverse_SSE2;
  dispatchTable.ToLowerAscii := @ToLowerAscii_SSE2;
  dispatchTable.ToUpperAscii := @ToUpperAscii_SSE2;
  dispatchTable.AsciiIEqual := @AsciiIEqual_SSE2;
  dispatchTable.BytesIndexOf := @BytesIndexOf_SSE2;
  dispatchTable.Utf8Validate := @Utf8Validate_SSE2;

  // Mask operations (bsf + SWAR popcount, always enabled)
  dispatchTable.Mask2All := @SharedMask2All;
  dispatchTable.Mask2Any := @SharedMask2Any;
  dispatchTable.Mask2None := @SharedMask2None;
  dispatchTable.Mask2PopCount := @SSE2Mask2PopCount;
  dispatchTable.Mask2FirstSet := @SharedMask2FirstSet;
  dispatchTable.Mask4All := @SharedMask4All;
  dispatchTable.Mask4Any := @SharedMask4Any;
  dispatchTable.Mask4None := @SharedMask4None;
  dispatchTable.Mask4PopCount := @SSE2Mask4PopCount;
  dispatchTable.Mask4FirstSet := @SharedMask4FirstSet;
  dispatchTable.Mask8All := @SharedMask8All;
  dispatchTable.Mask8Any := @SharedMask8Any;
  dispatchTable.Mask8None := @SharedMask8None;
  dispatchTable.Mask8PopCount := @SSE2Mask8PopCount;
  dispatchTable.Mask8FirstSet := @SharedMask8FirstSet;
  dispatchTable.Mask16All := @SharedMask16All;
  dispatchTable.Mask16Any := @SharedMask16Any;
  dispatchTable.Mask16None := @SharedMask16None;
  dispatchTable.Mask16PopCount := @SSE2Mask16PopCount;
  dispatchTable.Mask16FirstSet := @SharedMask16FirstSet;

  // ============================================================================
  // Batch Array Operations (SSE2 SIMD loops)
  // ============================================================================
  dispatchTable.ArrayAddF32 := @SSE2ArrayAddF32;
  dispatchTable.ArraySubF32 := @SSE2ArraySubF32;
  dispatchTable.ArrayMulF32 := @SSE2ArrayMulF32;
  dispatchTable.ArrayDivF32 := @SSE2ArrayDivF32;
  dispatchTable.ArrayMinF32 := @SSE2ArrayMinF32;
  dispatchTable.ArrayMaxF32 := @SSE2ArrayMaxF32;
  dispatchTable.ArrayAbsF32 := @SSE2ArrayAbsF32;
  dispatchTable.ArrayNegF32 := @SSE2ArrayNegF32;
  dispatchTable.ArraySqrtF32 := @SSE2ArraySqrtF32;
  dispatchTable.ArrayRcpF32 := @SSE2ArrayRcpF32;
  dispatchTable.ArrayRsqrtF32 := @SSE2ArrayRsqrtF32;
  dispatchTable.ArrayAddScalarF32 := @SSE2ArrayAddScalarF32;
  dispatchTable.ArrayMulScalarF32 := @SSE2ArrayMulScalarF32;
  dispatchTable.ArrayClampF32 := @SSE2ArrayClampF32;
  dispatchTable.ArrayFmaF32 := @SSE2ArrayFmaF32;
  dispatchTable.ArrayAxpyF32 := @SSE2ArrayAxpyF32;
  dispatchTable.ReduceSumF32 := @SSE2ReduceSumF32;
  dispatchTable.ReduceDotF32 := @SSE2ReduceDotF32;

  // F64 batch unary
  dispatchTable.ArrayAbsF64 := @SSE2ArrayAbsF64;
  dispatchTable.ArrayNegF64 := @SSE2ArrayNegF64;
  dispatchTable.ArraySqrtF64 := @SSE2ArraySqrtF64;
  dispatchTable.ArrayMulScalarF64 := @SSE2ArrayMulScalarF64;
  dispatchTable.ArrayAddScalarF64 := @SSE2ArrayAddScalarF64;
  dispatchTable.ArrayClampF64 := @SSE2ArrayClampF64;
  dispatchTable.ArrayLinearF64 := @SSE2ArrayLinearF64;

  // F64 batch arithmetic
  dispatchTable.ArrayAddF64 := @SSE2ArrayAddF64;
  dispatchTable.ArraySubF64 := @SSE2ArraySubF64;
  dispatchTable.ArrayMulF64 := @SSE2ArrayMulF64;
  dispatchTable.ArrayDivF64 := @SSE2ArrayDivF64;

  // Integer batch
  dispatchTable.ArrayAddI32 := @SSE2ArrayAddI32;
  dispatchTable.ArraySubI32 := @SSE2ArraySubI32;
  dispatchTable.ArrayMulI16 := @SSE2ArrayMulI16;
  dispatchTable.ArrayAndI32 := @SSE2ArrayAndI32;
  dispatchTable.ArrayOrI32 := @SSE2ArrayOrI32;
  dispatchTable.ArrayXorI32 := @SSE2ArrayXorI32;
  dispatchTable.ArrayShlI32 := @SSE2ArrayShlI32;
  dispatchTable.ArrayShrI32 := @SSE2ArrayShrI32;

  // Type conversion
  dispatchTable.ArrayF32toI32 := @SSE2ArrayF32toI32;
  dispatchTable.ArrayI32toF32 := @SSE2ArrayI32toF32;

  // F64 reductions
  dispatchTable.ReduceSumF64 := @SSE2ReduceSumF64;
  dispatchTable.ReduceDotF64 := @SSE2ReduceDotF64;

  // F32 reductions
  dispatchTable.ReduceMinF32 := @SSE2ReduceMinF32;

  // F64 reductions
  dispatchTable.ReduceMinF64 := @SSE2ReduceMinF64;

  // PackSat + NR Refine
  dispatchTable.ArrayPackSatI32toI16 := @SSE2ArrayPackSatI32toI16;
  dispatchTable.ArrayRcpRefineF32 := @SSE2ArrayRcpRefineF32;
  dispatchTable.ArrayRsqrtRefineF32 := @SSE2ArrayRsqrtRefineF32;

  // Transcendental
  dispatchTable.ArrayExpF32 := @SSE2ArrayExpF32;
  dispatchTable.ArrayLogF32 := @SSE2ArrayLogF32;
  dispatchTable.ArraySinF32 := @SSE2ArraySinF32;
  dispatchTable.ArrayCosF32 := @SSE2ArrayCosF32;
  dispatchTable.ArrayPowF32 := @SSE2ArrayPowF32;

  // Fused
  dispatchTable.ArrayLinearF32 := @SSE2ArrayLinearF32;
  dispatchTable.ArrayAbsDiffF32 := @SSE2ArrayAbsDiffF32;
  dispatchTable.ArrayReLUF32 := @SSE2ArrayReLUF32;
  dispatchTable.ArrayNormF32 := @SSE2ArrayNormF32;
  dispatchTable.ArrayLinearReLUF32 := @SSE2ArrayLinearReLUF32;

  // Register the backend
  RegisterBackend(sbSSE2, dispatchTable);
end;

initialization
  RegisterSSE2Backend;
  // Register rebuilder callback for VectorAsmEnabled changes
  RegisterBackendRebuilder(sbSSE2, @RegisterSSE2Backend);
