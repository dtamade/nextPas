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
    dispatchTable.CoreVectors.AddF32x4 := @SSE2AddF32x4;
    dispatchTable.CoreVectors.SubF32x4 := @SSE2SubF32x4;
    dispatchTable.CoreVectors.MulF32x4 := @SSE2MulF32x4;
    dispatchTable.CoreVectors.DivF32x4 := @SSE2DivF32x4;

    dispatchTable.CoreVectors.AddF32x8 := @SSE2AddF32x8;
    dispatchTable.CoreVectors.SubF32x8 := @SSE2SubF32x8;
    dispatchTable.CoreVectors.MulF32x8 := @SSE2MulF32x8;
    dispatchTable.CoreVectors.DivF32x8 := @SSE2DivF32x8;

    // F32x8 扩展函数 (2026-02-05)
    dispatchTable.CoreVectors.FmaF32x8 := @SSE2FmaF32x8;
    dispatchTable.CoreVectors.FloorF32x8 := @SSE2FloorF32x8;
    dispatchTable.CoreVectors.CeilF32x8 := @SSE2CeilF32x8;
    dispatchTable.CoreVectors.RoundF32x8 := @SSE2RoundF32x8;
    dispatchTable.CoreVectors.TruncF32x8 := @SSE2TruncF32x8;
    dispatchTable.CoreVectors.AbsF32x8 := @SSE2AbsF32x8;
    dispatchTable.CoreVectors.SqrtF32x8 := @SSE2SqrtF32x8;
    dispatchTable.CoreVectors.MinF32x8 := @SSE2MinF32x8;
    dispatchTable.CoreVectors.MaxF32x8 := @SSE2MaxF32x8;
    dispatchTable.CoreVectors.ClampF32x8 := @SSE2ClampF32x8;
    dispatchTable.CoreVectors.ReduceAddF32x8 := @SSE2ReduceAddF32x8;
    dispatchTable.CoreVectors.ReduceMinF32x8 := @SSE2ReduceMinF32x8;
    dispatchTable.CoreVectors.ReduceMaxF32x8 := @SSE2ReduceMaxF32x8;
    dispatchTable.CoreVectors.ReduceMulF32x8 := @SSE2ReduceMulF32x8;
    dispatchTable.CoreVectors.LoadF32x8 := @SSE2LoadF32x8;
    dispatchTable.CoreVectors.StoreF32x8 := @SSE2StoreF32x8;
    dispatchTable.CoreVectors.SplatF32x8 := @SSE2SplatF32x8;
    dispatchTable.CoreVectors.ZeroF32x8 := @SSE2ZeroF32x8;

    // F32x8 comparison operations (2x F32x4)
    dispatchTable.CoreVectors.CmpEqF32x8 := @SSE2CmpEqF32x8;
    dispatchTable.CoreVectors.CmpLtF32x8 := @SSE2CmpLtF32x8;
    dispatchTable.CoreVectors.CmpLeF32x8 := @SSE2CmpLeF32x8;
    dispatchTable.CoreVectors.CmpGtF32x8 := @SSE2CmpGtF32x8;
    dispatchTable.CoreVectors.CmpGeF32x8 := @SSE2CmpGeF32x8;
    dispatchTable.CoreVectors.CmpNeF32x8 := @SSE2CmpNeF32x8;

    dispatchTable.CoreVectors.AddF64x2 := @SSE2AddF64x2;
    dispatchTable.CoreVectors.SubF64x2 := @SSE2SubF64x2;
    dispatchTable.CoreVectors.MulF64x2 := @SSE2MulF64x2;
    dispatchTable.CoreVectors.DivF64x2 := @SSE2DivF64x2;

    // F64x2 math operations
    dispatchTable.CoreVectors.SqrtF64x2 := @SSE2SqrtF64x2;
    dispatchTable.CoreVectors.MinF64x2 := @SSE2MinF64x2;
    dispatchTable.CoreVectors.MaxF64x2 := @SSE2MaxF64x2;
    dispatchTable.CoreVectors.AbsF64x2 := @SSE2AbsF64x2;

    // F64x2 comparison operations
    dispatchTable.CoreVectors.CmpEqF64x2 := @SSE2CmpEqF64x2;
    dispatchTable.CoreVectors.CmpLtF64x2 := @SSE2CmpLtF64x2;
    dispatchTable.CoreVectors.CmpLeF64x2 := @SSE2CmpLeF64x2;
    dispatchTable.CoreVectors.CmpGtF64x2 := @SSE2CmpGtF64x2;
    dispatchTable.CoreVectors.CmpGeF64x2 := @SSE2CmpGeF64x2;
    dispatchTable.CoreVectors.CmpNeF64x2 := @SSE2CmpNeF64x2;

    // F64x2 utility operations
    dispatchTable.CoreVectors.LoadF64x2 := @SSE2LoadF64x2;
    dispatchTable.CoreVectors.StoreF64x2 := @SSE2StoreF64x2;
    dispatchTable.CoreVectors.SplatF64x2 := @SSE2SplatF64x2;
    dispatchTable.CoreVectors.ZeroF64x2 := @SSE2ZeroF64x2;

    // F64x2 扩展函数 (2026-02-05)
    dispatchTable.CoreVectors.FloorF64x2 := @SSE2FloorF64x2;
    dispatchTable.CoreVectors.CeilF64x2 := @SSE2CeilF64x2;
    dispatchTable.CoreVectors.RoundF64x2 := @SSE2RoundF64x2;
    dispatchTable.CoreVectors.TruncF64x2 := @SSE2TruncF64x2;
    dispatchTable.CoreVectors.FmaF64x2 := @SSE2FmaF64x2;
    dispatchTable.CoreVectors.ClampF64x2 := @SSE2ClampF64x2;
    dispatchTable.CoreVectors.ReduceAddF64x2 := @SSE2ReduceAddF64x2;
    dispatchTable.CoreVectors.ReduceMinF64x2 := @SSE2ReduceMinF64x2;
    dispatchTable.CoreVectors.ReduceMaxF64x2 := @SSE2ReduceMaxF64x2;
    dispatchTable.CoreVectors.ReduceMulF64x2 := @SSE2ReduceMulF64x2;

    // F64x4 分解实现 (2026-02-05) - 使用 2x F64x2
    dispatchTable.CoreVectors.AddF64x4 := @SSE2AddF64x4;
    dispatchTable.CoreVectors.SubF64x4 := @SSE2SubF64x4;
    dispatchTable.CoreVectors.MulF64x4 := @SSE2MulF64x4;
    dispatchTable.CoreVectors.DivF64x4 := @SSE2DivF64x4;
    dispatchTable.CoreVectors.FmaF64x4 := @SSE2FmaF64x4;
    dispatchTable.CoreVectors.RcpF64x4 := @SSE2RcpF64x4;
    dispatchTable.CoreVectors.FloorF64x4 := @SSE2FloorF64x4;
    dispatchTable.CoreVectors.CeilF64x4 := @SSE2CeilF64x4;
    dispatchTable.CoreVectors.RoundF64x4 := @SSE2RoundF64x4;
    dispatchTable.CoreVectors.TruncF64x4 := @SSE2TruncF64x4;
    dispatchTable.CoreVectors.AbsF64x4 := @SSE2AbsF64x4;
    dispatchTable.CoreVectors.SqrtF64x4 := @SSE2SqrtF64x4;
    dispatchTable.CoreVectors.MinF64x4 := @SSE2MinF64x4;
    dispatchTable.CoreVectors.MaxF64x4 := @SSE2MaxF64x4;
    dispatchTable.CoreVectors.ClampF64x4 := @SSE2ClampF64x4;
    dispatchTable.CoreVectors.ReduceAddF64x4 := @SSE2ReduceAddF64x4;
    dispatchTable.CoreVectors.ReduceMinF64x4 := @SSE2ReduceMinF64x4;
    dispatchTable.CoreVectors.ReduceMaxF64x4 := @SSE2ReduceMaxF64x4;
    dispatchTable.CoreVectors.ReduceMulF64x4 := @SSE2ReduceMulF64x4;
    dispatchTable.CoreVectors.LoadF64x4 := @SSE2LoadF64x4;
    dispatchTable.CoreVectors.StoreF64x4 := @SSE2StoreF64x4;
    dispatchTable.CoreVectors.SplatF64x4 := @SSE2SplatF64x4;
    dispatchTable.CoreVectors.ZeroF64x4 := @SSE2ZeroF64x4;

    // F64x4 comparison operations (2x F64x2)
    dispatchTable.CoreVectors.CmpEqF64x4 := @SSE2CmpEqF64x4;
    dispatchTable.CoreVectors.CmpLtF64x4 := @SSE2CmpLtF64x4;
    dispatchTable.CoreVectors.CmpLeF64x4 := @SSE2CmpLeF64x4;
    dispatchTable.CoreVectors.CmpGtF64x4 := @SSE2CmpGtF64x4;
    dispatchTable.CoreVectors.CmpGeF64x4 := @SSE2CmpGeF64x4;
    dispatchTable.CoreVectors.CmpNeF64x4 := @SSE2CmpNeF64x4;

    dispatchTable.CoreVectors.AddI32x4 := @SSE2AddI32x4;
    dispatchTable.CoreVectors.SubI32x4 := @SSE2SubI32x4;
    dispatchTable.CoreVectors.MulI32x4 := @SSE2MulI32x4;

    // I32x4 bitwise operations
    dispatchTable.CoreVectors.AndI32x4 := @SSE2AndI32x4;
    dispatchTable.CoreVectors.OrI32x4 := @SSE2OrI32x4;
    dispatchTable.CoreVectors.XorI32x4 := @SSE2XorI32x4;
    dispatchTable.CoreVectors.NotI32x4 := @SSE2NotI32x4;
    dispatchTable.CoreVectors.AndNotI32x4 := @SSE2AndNotI32x4;

    // I32x4 shift operations
    dispatchTable.CoreVectors.ShiftLeftI32x4 := @SSE2ShiftLeftI32x4;
    dispatchTable.CoreVectors.ShiftRightI32x4 := @SSE2ShiftRightI32x4;
    dispatchTable.CoreVectors.ShiftRightArithI32x4 := @SSE2ShiftRightArithI32x4;

    // I32x4 comparison operations
    dispatchTable.CoreVectors.CmpEqI32x4 := @SSE2CmpEqI32x4;
    dispatchTable.CoreVectors.CmpLtI32x4 := @SSE2CmpLtI32x4;
    dispatchTable.CoreVectors.CmpGtI32x4 := @SSE2CmpGtI32x4;
    dispatchTable.CoreVectors.CmpLeI32x4 := @SSE2CmpLeI32x4;
    dispatchTable.CoreVectors.CmpGeI32x4 := @SSE2CmpGeI32x4;
    dispatchTable.CoreVectors.CmpNeI32x4 := @SSE2CmpNeI32x4;

    // I32x4 min/max operations
    dispatchTable.CoreVectors.MinI32x4 := @SSE2MinI32x4;
    dispatchTable.CoreVectors.MaxI32x4 := @SSE2MaxI32x4;

    // I32x8 分解实现 (2026-02-05) - 使用 2x I32x4
    dispatchTable.CoreVectors.AddI32x8 := @SSE2AddI32x8;
    dispatchTable.CoreVectors.SubI32x8 := @SSE2SubI32x8;
    dispatchTable.CoreVectors.MulI32x8 := @SSE2MulI32x8;
    dispatchTable.CoreVectors.AndI32x8 := @SSE2AndI32x8;
    dispatchTable.CoreVectors.OrI32x8 := @SSE2OrI32x8;
    dispatchTable.CoreVectors.XorI32x8 := @SSE2XorI32x8;
    dispatchTable.CoreVectors.NotI32x8 := @SSE2NotI32x8;
    dispatchTable.CoreVectors.AndNotI32x8 := @SSE2AndNotI32x8;
    dispatchTable.CoreVectors.ShiftLeftI32x8 := @SSE2ShiftLeftI32x8;
    dispatchTable.CoreVectors.ShiftRightI32x8 := @SSE2ShiftRightI32x8;
    dispatchTable.CoreVectors.ShiftRightArithI32x8 := @SSE2ShiftRightArithI32x8;
    dispatchTable.CoreVectors.CmpEqI32x8 := @SSE2CmpEqI32x8;
    dispatchTable.CoreVectors.CmpLtI32x8 := @SSE2CmpLtI32x8;
    dispatchTable.CoreVectors.CmpGtI32x8 := @SSE2CmpGtI32x8;
    dispatchTable.CoreVectors.CmpLeI32x8 := @SSE2CmpLeI32x8;
    dispatchTable.CoreVectors.CmpGeI32x8 := @SSE2CmpGeI32x8;
    dispatchTable.CoreVectors.CmpNeI32x8 := @SSE2CmpNeI32x8;
    dispatchTable.CoreVectors.MinI32x8 := @SSE2MinI32x8;
    dispatchTable.CoreVectors.MaxI32x8 := @SSE2MaxI32x8;

    // 512-bit 向量的 SSE2 渐进降级实现 (2026-02-05)

    // F32x16 (16×Float32)
    dispatchTable.CoreVectors.AddF32x16 := @SSE2AddF32x16;
    dispatchTable.CoreVectors.SubF32x16 := @SSE2SubF32x16;
    dispatchTable.CoreVectors.MulF32x16 := @SSE2MulF32x16;
    dispatchTable.CoreVectors.DivF32x16 := @SSE2DivF32x16;
    dispatchTable.CoreVectors.AbsF32x16 := @SSE2AbsF32x16;
    dispatchTable.CoreVectors.SqrtF32x16 := @SSE2SqrtF32x16;
    dispatchTable.CoreVectors.MinF32x16 := @SSE2MinF32x16;
    dispatchTable.CoreVectors.MaxF32x16 := @SSE2MaxF32x16;
    dispatchTable.CoreVectors.FmaF32x16 := @SSE2FmaF32x16;
    dispatchTable.CoreVectors.FloorF32x16 := @SSE2FloorF32x16;
    dispatchTable.CoreVectors.CeilF32x16 := @SSE2CeilF32x16;
    dispatchTable.CoreVectors.RoundF32x16 := @SSE2RoundF32x16;
    dispatchTable.CoreVectors.TruncF32x16 := @SSE2TruncF32x16;
    dispatchTable.CoreVectors.ClampF32x16 := @SSE2ClampF32x16;
    dispatchTable.CoreVectors.ReduceAddF32x16 := @SSE2ReduceAddF32x16;
    dispatchTable.CoreVectors.ReduceMinF32x16 := @SSE2ReduceMinF32x16;
    dispatchTable.CoreVectors.ReduceMaxF32x16 := @SSE2ReduceMaxF32x16;
    dispatchTable.CoreVectors.ReduceMulF32x16 := @SSE2ReduceMulF32x16;
    dispatchTable.CoreVectors.LoadF32x16 := @SSE2LoadF32x16;
    dispatchTable.CoreVectors.StoreF32x16 := @SSE2StoreF32x16;
    dispatchTable.CoreVectors.SplatF32x16 := @SSE2SplatF32x16;
    dispatchTable.CoreVectors.ZeroF32x16 := @SSE2ZeroF32x16;
    dispatchTable.CoreVectors.CmpEqF32x16 := @SSE2CmpEqF32x16;
    dispatchTable.CoreVectors.CmpLtF32x16 := @SSE2CmpLtF32x16;
    dispatchTable.CoreVectors.CmpLeF32x16 := @SSE2CmpLeF32x16;
    dispatchTable.CoreVectors.CmpGtF32x16 := @SSE2CmpGtF32x16;
    dispatchTable.CoreVectors.CmpGeF32x16 := @SSE2CmpGeF32x16;
    dispatchTable.CoreVectors.CmpNeF32x16 := @SSE2CmpNeF32x16;
    dispatchTable.CoreVectors.SelectF32x16 := @SSE2SelectF32x16;

    // F64x8 (8×Float64)
    dispatchTable.CoreVectors.AddF64x8 := @SSE2AddF64x8;
    dispatchTable.CoreVectors.SubF64x8 := @SSE2SubF64x8;
    dispatchTable.CoreVectors.MulF64x8 := @SSE2MulF64x8;
    dispatchTable.CoreVectors.DivF64x8 := @SSE2DivF64x8;
    dispatchTable.CoreVectors.AbsF64x8 := @SSE2AbsF64x8;
    dispatchTable.CoreVectors.SqrtF64x8 := @SSE2SqrtF64x8;
    dispatchTable.CoreVectors.MinF64x8 := @SSE2MinF64x8;
    dispatchTable.CoreVectors.MaxF64x8 := @SSE2MaxF64x8;
    dispatchTable.CoreVectors.FmaF64x8 := @SSE2FmaF64x8;
    dispatchTable.CoreVectors.FloorF64x8 := @SSE2FloorF64x8;
    dispatchTable.CoreVectors.CeilF64x8 := @SSE2CeilF64x8;
    dispatchTable.CoreVectors.RoundF64x8 := @SSE2RoundF64x8;
    dispatchTable.CoreVectors.TruncF64x8 := @SSE2TruncF64x8;
    dispatchTable.CoreVectors.ClampF64x8 := @SSE2ClampF64x8;
    dispatchTable.CoreVectors.ReduceAddF64x8 := @SSE2ReduceAddF64x8;
    dispatchTable.CoreVectors.ReduceMinF64x8 := @SSE2ReduceMinF64x8;
    dispatchTable.CoreVectors.ReduceMaxF64x8 := @SSE2ReduceMaxF64x8;
    dispatchTable.CoreVectors.ReduceMulF64x8 := @SSE2ReduceMulF64x8;
    dispatchTable.CoreVectors.LoadF64x8 := @SSE2LoadF64x8;
    dispatchTable.CoreVectors.StoreF64x8 := @SSE2StoreF64x8;
    dispatchTable.CoreVectors.SplatF64x8 := @SSE2SplatF64x8;
    dispatchTable.CoreVectors.ZeroF64x8 := @SSE2ZeroF64x8;
    dispatchTable.CoreVectors.CmpEqF64x8 := @SSE2CmpEqF64x8;
    dispatchTable.CoreVectors.CmpLtF64x8 := @SSE2CmpLtF64x8;
    dispatchTable.CoreVectors.CmpLeF64x8 := @SSE2CmpLeF64x8;
    dispatchTable.CoreVectors.CmpGtF64x8 := @SSE2CmpGtF64x8;
    dispatchTable.CoreVectors.CmpGeF64x8 := @SSE2CmpGeF64x8;
    dispatchTable.CoreVectors.CmpNeF64x8 := @SSE2CmpNeF64x8;
    dispatchTable.CoreVectors.SelectF64x8 := @SSE2SelectF64x8;

    // I32x16 (16×Int32)
    dispatchTable.CoreVectors.AddI32x16 := @SSE2AddI32x16;
    dispatchTable.CoreVectors.SubI32x16 := @SSE2SubI32x16;
    dispatchTable.CoreVectors.MulI32x16 := @SSE2MulI32x16;
    dispatchTable.CoreVectors.AndI32x16 := @SSE2AndI32x16;
    dispatchTable.CoreVectors.OrI32x16 := @SSE2OrI32x16;
    dispatchTable.CoreVectors.XorI32x16 := @SSE2XorI32x16;
    dispatchTable.CoreVectors.NotI32x16 := @SSE2NotI32x16;
    dispatchTable.CoreVectors.AndNotI32x16 := @SSE2AndNotI32x16;
    dispatchTable.CoreVectors.ShiftLeftI32x16 := @SSE2ShiftLeftI32x16;
    dispatchTable.CoreVectors.ShiftRightI32x16 := @SSE2ShiftRightI32x16;
    dispatchTable.CoreVectors.ShiftRightArithI32x16 := @SSE2ShiftRightArithI32x16;
    dispatchTable.CoreVectors.CmpEqI32x16 := @SSE2CmpEqI32x16;
    dispatchTable.CoreVectors.CmpLtI32x16 := @SSE2CmpLtI32x16;
    dispatchTable.CoreVectors.CmpGtI32x16 := @SSE2CmpGtI32x16;
    dispatchTable.CoreVectors.CmpLeI32x16 := @SSE2CmpLeI32x16;
    dispatchTable.CoreVectors.CmpGeI32x16 := @SSE2CmpGeI32x16;
    dispatchTable.CoreVectors.CmpNeI32x16 := @SSE2CmpNeI32x16;
    dispatchTable.CoreVectors.MinI32x16 := @SSE2MinI32x16;
    dispatchTable.CoreVectors.MaxI32x16 := @SSE2MaxI32x16;

    // I64x2 arithmetic and bitwise
    dispatchTable.CoreVectors.AddI64x2 := @SSE2AddI64x2;
    dispatchTable.CoreVectors.SubI64x2 := @SSE2SubI64x2;
    dispatchTable.CoreVectors.AndI64x2 := @SSE2AndI64x2;
    dispatchTable.CoreVectors.OrI64x2 := @SSE2OrI64x2;
    dispatchTable.CoreVectors.XorI64x2 := @SSE2XorI64x2;
    dispatchTable.CoreVectors.NotI64x2 := @SSE2NotI64x2;
    dispatchTable.CoreVectors.AndNotI64x2 := @SSE2AndNotI64x2;

    // I64x2 comparison operations (SSE2 emulation)
    // SSE2 没有原生 64 位整数比较指令（PCMPGTQ 是 SSE4.2）
    // 使用 32 位比较的组合逻辑来模拟 64 位比较
    dispatchTable.CoreVectors.CmpEqI64x2 := @SSE2CmpEqI64x2;
    dispatchTable.CoreVectors.CmpNeI64x2 := @SSE2CmpNeI64x2;
    dispatchTable.CoreVectors.CmpGtI64x2 := @SSE2CmpGtI64x2;
    dispatchTable.CoreVectors.CmpLtI64x2 := @SSE2CmpLtI64x2;
    dispatchTable.CoreVectors.CmpGeI64x2 := @SSE2CmpGeI64x2;
    dispatchTable.CoreVectors.CmpLeI64x2 := @SSE2CmpLeI64x2;

    // Override with SSE2 comparison operations
    dispatchTable.CoreVectors.CmpEqF32x4 := @SSE2CmpEqF32x4;
    dispatchTable.CoreVectors.CmpLtF32x4 := @SSE2CmpLtF32x4;
    dispatchTable.CoreVectors.CmpLeF32x4 := @SSE2CmpLeF32x4;
    dispatchTable.CoreVectors.CmpGtF32x4 := @SSE2CmpGtF32x4;
    dispatchTable.CoreVectors.CmpGeF32x4 := @SSE2CmpGeF32x4;
    dispatchTable.CoreVectors.CmpNeF32x4 := @SSE2CmpNeF32x4;

    // Override with SSE2 math functions
    dispatchTable.CoreVectors.AbsF32x4 := @SSE2AbsF32x4;
    dispatchTable.CoreVectors.SqrtF32x4 := @SSE2SqrtF32x4;
    dispatchTable.CoreVectors.MinF32x4 := @SSE2MinF32x4;
    dispatchTable.CoreVectors.MaxF32x4 := @SSE2MaxF32x4;

    // Override with SSE2 extended math functions
    dispatchTable.CoreVectors.FmaF32x4 := @SSE2FmaF32x4;
    dispatchTable.CoreVectors.RcpF32x4 := @SSE2RcpF32x4;
    dispatchTable.CoreVectors.RsqrtF32x4 := @SSE2RsqrtF32x4;
    dispatchTable.CoreVectors.FloorF32x4 := @SSE2FloorF32x4;
    dispatchTable.CoreVectors.CeilF32x4 := @SSE2CeilF32x4;
    dispatchTable.CoreVectors.RoundF32x4 := @SSE2RoundF32x4;
    dispatchTable.CoreVectors.TruncF32x4 := @SSE2TruncF32x4;
    dispatchTable.CoreVectors.ClampF32x4 := @SSE2ClampF32x4;

    // Override with SSE2 vector math functions
    dispatchTable.CoreVectors.DotF32x4 := @SSE2DotF32x4;
    dispatchTable.CoreVectors.DotF32x3 := @SSE2DotF32x3;
    dispatchTable.CoreVectors.CrossF32x3 := @SSE2CrossF32x3;
    dispatchTable.CoreVectors.LengthF32x4 := @SSE2LengthF32x4;
    dispatchTable.CoreVectors.LengthF32x3 := @SSE2LengthF32x3;
    dispatchTable.CoreVectors.NormalizeF32x4 := @SSE2NormalizeF32x4;
    dispatchTable.CoreVectors.NormalizeF32x3 := @SSE2NormalizeF32x3;

    // Override with SSE2 reduction operations
    dispatchTable.CoreVectors.ReduceAddF32x4 := @SSE2ReduceAddF32x4;
    dispatchTable.CoreVectors.ReduceMinF32x4 := @SSE2ReduceMinF32x4;
    dispatchTable.CoreVectors.ReduceMaxF32x4 := @SSE2ReduceMaxF32x4;
    dispatchTable.CoreVectors.ReduceMulF32x4 := @SSE2ReduceMulF32x4;

    // Override with SSE2 memory operations
    dispatchTable.CoreVectors.LoadF32x4 := @SSE2LoadF32x4;
    dispatchTable.CoreVectors.LoadF32x4Aligned := @SSE2LoadF32x4Aligned;
    dispatchTable.CoreVectors.StoreF32x4 := @SSE2StoreF32x4;
    dispatchTable.CoreVectors.StoreF32x4Aligned := @SSE2StoreF32x4Aligned;

    // Override with SSE2 utility operations
    dispatchTable.CoreVectors.SplatF32x4 := @SSE2SplatF32x4;
    dispatchTable.CoreVectors.ZeroF32x4 := @SSE2ZeroF32x4;
    dispatchTable.CoreVectors.SelectF32x4 := @SSE2SelectF32x4;
    dispatchTable.CoreVectors.ExtractF32x4 := @SSE2ExtractF32x4;
    dispatchTable.CoreVectors.InsertF32x4 := @SSE2InsertF32x4;

    // SelectF64x2
    dispatchTable.CoreVectors.SelectF64x2 := @SSE2SelectF64x2;

    // 缺失的 Select 操作
    dispatchTable.CoreVectors.SelectI32x4 := @SSE2SelectI32x4;
    dispatchTable.CoreVectors.SelectF32x8 := @SSE2SelectF32x8;
    dispatchTable.CoreVectors.SelectF64x4 := @SSE2SelectF64x4;
  end;
  // else: keep scalar implementations from FillBaseDispatchTable

  // Override facade functions with SSE2-accelerated versions
  dispatchTable.Memory.Equal := @MemEqual_SSE2;
  dispatchTable.Memory.FindByte := @MemFindByte_SSE2;
  dispatchTable.Memory.SumBytes := @SumBytes_SSE2;
  dispatchTable.Memory.CountByte := @CountByte_SSE2;
  dispatchTable.Memory.MinMaxBytes := @MinMaxBytes_SSE2;
  dispatchTable.Memory.BitsetPopCount := @BitsetPopCount_SSE2;
  // Register SSE2 memory operations
  dispatchTable.Memory.Copy := @MemCopy_SSE2;
  dispatchTable.Memory.Fill := @MemSet_SSE2;
  // Wide/helper facade overrides are applied below to keep SSE2-owned implementations active.

  // Override with SSE2 saturating arithmetic (always enabled, stable ops)
  dispatchTable.CoreVectors.I8x16SatAdd := @SSE2I8x16SatAdd;
  dispatchTable.CoreVectors.I8x16SatSub := @SSE2I8x16SatSub;
  dispatchTable.CoreVectors.I16x8SatAdd := @SSE2I16x8SatAdd;
  dispatchTable.CoreVectors.I16x8SatSub := @SSE2I16x8SatSub;
  dispatchTable.CoreVectors.U8x16SatAdd := @SSE2U8x16SatAdd;
  dispatchTable.CoreVectors.U8x16SatSub := @SSE2U8x16SatSub;
  dispatchTable.CoreVectors.U16x8SatAdd := @SSE2U16x8SatAdd;
  dispatchTable.CoreVectors.U16x8SatSub := @SSE2U16x8SatSub;

  // I16x8 operations (SSE2)
  dispatchTable.CoreVectors.AddI16x8 := @SSE2AddI16x8;
  dispatchTable.CoreVectors.SubI16x8 := @SSE2SubI16x8;
  dispatchTable.CoreVectors.MulI16x8 := @SSE2MulI16x8;
  dispatchTable.CoreVectors.AndI16x8 := @SSE2AndI16x8;
  dispatchTable.CoreVectors.OrI16x8 := @SSE2OrI16x8;
  dispatchTable.CoreVectors.XorI16x8 := @SSE2XorI16x8;
  dispatchTable.CoreVectors.NotI16x8 := @SSE2NotI16x8;
  dispatchTable.CoreVectors.AndNotI16x8 := @SSE2AndNotI16x8;
  dispatchTable.CoreVectors.ShiftLeftI16x8 := @SSE2ShiftLeftI16x8;
  dispatchTable.CoreVectors.ShiftRightI16x8 := @SSE2ShiftRightI16x8;
  dispatchTable.CoreVectors.ShiftRightArithI16x8 := @SSE2ShiftRightArithI16x8;
  dispatchTable.CoreVectors.CmpEqI16x8 := @SSE2CmpEqI16x8;
  dispatchTable.CoreVectors.CmpLtI16x8 := @SSE2CmpLtI16x8;
  dispatchTable.CoreVectors.CmpGtI16x8 := @SSE2CmpGtI16x8;
  dispatchTable.CoreVectors.CmpLeI16x8 := @SSE2CmpLeI16x8;
  dispatchTable.CoreVectors.CmpGeI16x8 := @SSE2CmpGeI16x8;
  dispatchTable.CoreVectors.CmpNeI16x8 := @SSE2CmpNeI16x8;
  dispatchTable.CoreVectors.MinI16x8 := @SSE2MinI16x8;
  dispatchTable.CoreVectors.MaxI16x8 := @SSE2MaxI16x8;

  // I8x16 operations (SSE2)
  dispatchTable.CoreVectors.AddI8x16 := @SSE2AddI8x16;
  dispatchTable.CoreVectors.SubI8x16 := @SSE2SubI8x16;
  dispatchTable.CoreVectors.AndI8x16 := @SSE2AndI8x16;
  dispatchTable.CoreVectors.OrI8x16 := @SSE2OrI8x16;
  dispatchTable.CoreVectors.XorI8x16 := @SSE2XorI8x16;
  dispatchTable.CoreVectors.NotI8x16 := @SSE2NotI8x16;
  dispatchTable.CoreVectors.CmpEqI8x16 := @SSE2CmpEqI8x16;
  dispatchTable.CoreVectors.CmpLtI8x16 := @SSE2CmpLtI8x16;
  dispatchTable.CoreVectors.CmpGtI8x16 := @SSE2CmpGtI8x16;
  dispatchTable.CoreVectors.CmpLeI8x16 := @SSE2CmpLeI8x16;
  dispatchTable.CoreVectors.CmpGeI8x16 := @SSE2CmpGeI8x16;
  dispatchTable.CoreVectors.CmpNeI8x16 := @SSE2CmpNeI8x16;
  dispatchTable.CoreVectors.MinI8x16 := @SSE2MinI8x16;
  dispatchTable.CoreVectors.MaxI8x16 := @SSE2MaxI8x16;

  // U32x4 operations (SSE2)
  dispatchTable.CoreVectors.AddU32x4 := @SSE2AddU32x4;
  dispatchTable.CoreVectors.SubU32x4 := @SSE2SubU32x4;
  dispatchTable.CoreVectors.MulU32x4 := @SSE2MulU32x4;
  dispatchTable.CoreVectors.AndU32x4 := @SSE2AndU32x4;
  dispatchTable.CoreVectors.OrU32x4 := @SSE2OrU32x4;
  dispatchTable.CoreVectors.XorU32x4 := @SSE2XorU32x4;
  dispatchTable.CoreVectors.NotU32x4 := @SSE2NotU32x4;
  dispatchTable.CoreVectors.AndNotU32x4 := @SSE2AndNotU32x4;
  dispatchTable.CoreVectors.ShiftLeftU32x4 := @SSE2ShiftLeftU32x4;
  dispatchTable.CoreVectors.ShiftRightU32x4 := @SSE2ShiftRightU32x4;
  dispatchTable.CoreVectors.CmpEqU32x4 := @SSE2CmpEqU32x4;
  dispatchTable.CoreVectors.CmpLtU32x4 := @SSE2CmpLtU32x4;
  dispatchTable.CoreVectors.CmpGtU32x4 := @SSE2CmpGtU32x4;
  dispatchTable.CoreVectors.CmpLeU32x4 := @SSE2CmpLeU32x4;
  dispatchTable.CoreVectors.CmpGeU32x4 := @SSE2CmpGeU32x4;
  dispatchTable.CoreVectors.CmpNeU32x4 := @SSE2CmpNeU32x4;
  dispatchTable.CoreVectors.MinU32x4 := @SSE2MinU32x4;
  dispatchTable.CoreVectors.MaxU32x4 := @SSE2MaxU32x4;

  // U16x8 operations (SSE2)
  dispatchTable.CoreVectors.AddU16x8 := @SSE2AddU16x8;
  dispatchTable.CoreVectors.SubU16x8 := @SSE2SubU16x8;
  dispatchTable.CoreVectors.MulU16x8 := @SSE2MulU16x8;
  dispatchTable.CoreVectors.AndU16x8 := @SSE2AndU16x8;
  dispatchTable.CoreVectors.OrU16x8 := @SSE2OrU16x8;
  dispatchTable.CoreVectors.XorU16x8 := @SSE2XorU16x8;
  dispatchTable.CoreVectors.NotU16x8 := @SSE2NotU16x8;
  dispatchTable.CoreVectors.ShiftLeftU16x8 := @SSE2ShiftLeftU16x8;
  dispatchTable.CoreVectors.ShiftRightU16x8 := @SSE2ShiftRightU16x8;
  dispatchTable.CoreVectors.CmpEqU16x8 := @SSE2CmpEqU16x8;
  dispatchTable.CoreVectors.CmpLtU16x8 := @SSE2CmpLtU16x8;
  dispatchTable.CoreVectors.CmpGtU16x8 := @SSE2CmpGtU16x8;
  dispatchTable.CoreVectors.CmpLeU16x8 := @SSE2CmpLeU16x8;
  dispatchTable.CoreVectors.CmpGeU16x8 := @SSE2CmpGeU16x8;
  dispatchTable.CoreVectors.CmpNeU16x8 := @SSE2CmpNeU16x8;
  dispatchTable.CoreVectors.MinU16x8 := @SSE2MinU16x8;
  dispatchTable.CoreVectors.MaxU16x8 := @SSE2MaxU16x8;

  // U8x16 operations (SSE2)
  dispatchTable.CoreVectors.AddU8x16 := @SSE2AddU8x16;
  dispatchTable.CoreVectors.SubU8x16 := @SSE2SubU8x16;
  dispatchTable.CoreVectors.AndU8x16 := @SSE2AndU8x16;
  dispatchTable.CoreVectors.OrU8x16 := @SSE2OrU8x16;
  dispatchTable.CoreVectors.XorU8x16 := @SSE2XorU8x16;
  dispatchTable.CoreVectors.NotU8x16 := @SSE2NotU8x16;
  dispatchTable.CoreVectors.CmpEqU8x16 := @SSE2CmpEqU8x16;
  dispatchTable.CoreVectors.CmpLtU8x16 := @SSE2CmpLtU8x16;
  dispatchTable.CoreVectors.CmpGtU8x16 := @SSE2CmpGtU8x16;
  dispatchTable.CoreVectors.CmpLeU8x16 := @SSE2CmpLeU8x16;
  dispatchTable.CoreVectors.CmpGeU8x16 := @SSE2CmpGeU8x16;
  dispatchTable.CoreVectors.CmpNeU8x16 := @SSE2CmpNeU8x16;
  dispatchTable.CoreVectors.MinU8x16 := @SSE2MinU8x16;
  dispatchTable.CoreVectors.MaxU8x16 := @SSE2MaxU8x16;

  // ============================================================================
  // I64x4 操作注册 (256-bit，使用 2×I64x2 仿真)
  // ============================================================================
  dispatchTable.CoreVectors.AddI64x4 := @SSE2AddI64x4;
  dispatchTable.CoreVectors.SubI64x4 := @SSE2SubI64x4;
  dispatchTable.CoreVectors.AndI64x4 := @SSE2AndI64x4;
  dispatchTable.CoreVectors.OrI64x4 := @SSE2OrI64x4;
  dispatchTable.CoreVectors.XorI64x4 := @SSE2XorI64x4;
  dispatchTable.CoreVectors.NotI64x4 := @SSE2NotI64x4;
  dispatchTable.CoreVectors.AndNotI64x4 := @SSE2AndNotI64x4;
  dispatchTable.CoreVectors.ShiftLeftI64x4 := @SSE2ShiftLeftI64x4;
  dispatchTable.CoreVectors.ShiftRightI64x4 := @SSE2ShiftRightI64x4;
  dispatchTable.CoreVectors.CmpEqI64x4 := @SSE2CmpEqI64x4;
  dispatchTable.CoreVectors.CmpLtI64x4 := @SSE2CmpLtI64x4;
  dispatchTable.CoreVectors.CmpGtI64x4 := @SSE2CmpGtI64x4;
  dispatchTable.CoreVectors.CmpLeI64x4 := @SSE2CmpLeI64x4;
  dispatchTable.CoreVectors.CmpGeI64x4 := @SSE2CmpGeI64x4;
  dispatchTable.CoreVectors.CmpNeI64x4 := @SSE2CmpNeI64x4;
  dispatchTable.CoreVectors.LoadI64x4 := @SSE2LoadI64x4;
  dispatchTable.CoreVectors.StoreI64x4 := @SSE2StoreI64x4;
  dispatchTable.CoreVectors.SplatI64x4 := @SSE2SplatI64x4;
  dispatchTable.CoreVectors.ZeroI64x4 := @SSE2ZeroI64x4;

  // ============================================================================
  // U32x8 操作注册 (256-bit，使用 2×U32x4 仿真)
  // ============================================================================
  dispatchTable.CoreVectors.AddU32x8 := @SSE2AddU32x8;
  dispatchTable.CoreVectors.SubU32x8 := @SSE2SubU32x8;
  dispatchTable.CoreVectors.MulU32x8 := @SSE2MulU32x8;
  dispatchTable.CoreVectors.AndU32x8 := @SSE2AndU32x8;
  dispatchTable.CoreVectors.OrU32x8 := @SSE2OrU32x8;
  dispatchTable.CoreVectors.XorU32x8 := @SSE2XorU32x8;
  dispatchTable.CoreVectors.NotU32x8 := @SSE2NotU32x8;
  dispatchTable.CoreVectors.AndNotU32x8 := @SSE2AndNotU32x8;
  dispatchTable.CoreVectors.ShiftLeftU32x8 := @SSE2ShiftLeftU32x8;
  dispatchTable.CoreVectors.ShiftRightU32x8 := @SSE2ShiftRightU32x8;
  dispatchTable.CoreVectors.CmpEqU32x8 := @SSE2CmpEqU32x8;
  dispatchTable.CoreVectors.CmpLtU32x8 := @SSE2CmpLtU32x8;
  dispatchTable.CoreVectors.CmpGtU32x8 := @SSE2CmpGtU32x8;
  dispatchTable.CoreVectors.CmpLeU32x8 := @SSE2CmpLeU32x8;
  dispatchTable.CoreVectors.CmpGeU32x8 := @SSE2CmpGeU32x8;
  dispatchTable.CoreVectors.CmpNeU32x8 := @SSE2CmpNeU32x8;
  dispatchTable.CoreVectors.MinU32x8 := @SSE2MinU32x8;
  dispatchTable.CoreVectors.MaxU32x8 := @SSE2MaxU32x8;

  // ============================================================================
  // U64x4 操作注册 (256-bit，使用纯标量仿真)
  // ============================================================================
  dispatchTable.CoreVectors.AddU64x4 := @SSE2AddU64x4;
  dispatchTable.CoreVectors.SubU64x4 := @SSE2SubU64x4;
  dispatchTable.CoreVectors.AndU64x4 := @SSE2AndU64x4;
  dispatchTable.CoreVectors.OrU64x4 := @SSE2OrU64x4;
  dispatchTable.CoreVectors.XorU64x4 := @SSE2XorU64x4;
  dispatchTable.CoreVectors.NotU64x4 := @SSE2NotU64x4;
  dispatchTable.CoreVectors.ShiftLeftU64x4 := @SSE2ShiftLeftU64x4;
  dispatchTable.CoreVectors.ShiftRightU64x4 := @SSE2ShiftRightU64x4;
  dispatchTable.CoreVectors.CmpEqU64x4 := @SSE2CmpEqU64x4;
  dispatchTable.CoreVectors.CmpLtU64x4 := @SSE2CmpLtU64x4;
  dispatchTable.CoreVectors.CmpGtU64x4 := @SSE2CmpGtU64x4;
  dispatchTable.CoreVectors.CmpLeU64x4 := @SSE2CmpLeU64x4;
  dispatchTable.CoreVectors.CmpGeU64x4 := @SSE2CmpGeU64x4;
  dispatchTable.CoreVectors.CmpNeU64x4 := @SSE2CmpNeU64x4;

  // ============================================================================
  // I64x8 操作注册 (512-bit，使用 2×I64x4 仿真)
  // ============================================================================
  dispatchTable.CoreVectors.AddI64x8 := @SSE2AddI64x8;
  dispatchTable.CoreVectors.SubI64x8 := @SSE2SubI64x8;
  dispatchTable.CoreVectors.AndI64x8 := @SSE2AndI64x8;
  dispatchTable.CoreVectors.OrI64x8 := @SSE2OrI64x8;
  dispatchTable.CoreVectors.XorI64x8 := @SSE2XorI64x8;
  dispatchTable.CoreVectors.NotI64x8 := @SSE2NotI64x8;
  dispatchTable.CoreVectors.CmpEqI64x8 := @SSE2CmpEqI64x8;
  dispatchTable.CoreVectors.CmpLtI64x8 := @SSE2CmpLtI64x8;
  dispatchTable.CoreVectors.CmpGtI64x8 := @SSE2CmpGtI64x8;
  dispatchTable.CoreVectors.CmpLeI64x8 := @SSE2CmpLeI64x8;
  dispatchTable.CoreVectors.CmpGeI64x8 := @SSE2CmpGeI64x8;
  dispatchTable.CoreVectors.CmpNeI64x8 := @SSE2CmpNeI64x8;

  // ============================================================================
  // Extract/Insert 操作注册
  // ============================================================================
  dispatchTable.CoreVectors.ExtractF64x2 := @SSE2ExtractF64x2;
  dispatchTable.CoreVectors.InsertF64x2 := @SSE2InsertF64x2;
  dispatchTable.CoreVectors.ExtractI32x4 := @SSE2ExtractI32x4;
  dispatchTable.CoreVectors.InsertI32x4 := @SSE2InsertI32x4;
  dispatchTable.CoreVectors.ExtractI64x2 := @SSE2ExtractI64x2;
  dispatchTable.CoreVectors.InsertI64x2 := @SSE2InsertI64x2;
  dispatchTable.CoreVectors.ExtractF32x8 := @SSE2ExtractF32x8;
  dispatchTable.CoreVectors.InsertF32x8 := @SSE2InsertF32x8;
  dispatchTable.CoreVectors.ExtractF64x4 := @SSE2ExtractF64x4;
  dispatchTable.CoreVectors.InsertF64x4 := @SSE2InsertF64x4;
  dispatchTable.CoreVectors.ExtractI32x8 := @SSE2ExtractI32x8;
  dispatchTable.CoreVectors.InsertI32x8 := @SSE2InsertI32x8;
  dispatchTable.CoreVectors.ExtractI64x4 := @SSE2ExtractI64x4;
  dispatchTable.CoreVectors.InsertI64x4 := @SSE2InsertI64x4;
  dispatchTable.CoreVectors.ExtractF32x16 := @SSE2ExtractF32x16;
  dispatchTable.CoreVectors.InsertF32x16 := @SSE2InsertF32x16;
  dispatchTable.CoreVectors.ExtractI32x16 := @SSE2ExtractI32x16;
  dispatchTable.CoreVectors.InsertI32x16 := @SSE2InsertI32x16;

  // ============================================================================
  // Facade 函数注册
  // ============================================================================
  dispatchTable.Memory.DiffRange := @MemDiffRange_SSE2;
  dispatchTable.Memory.Reverse := @MemReverse_SSE2;
  dispatchTable.Memory.ToLowerAscii := @ToLowerAscii_SSE2;
  dispatchTable.Memory.ToUpperAscii := @ToUpperAscii_SSE2;
  dispatchTable.Memory.AsciiIEqual := @AsciiIEqual_SSE2;
  dispatchTable.Memory.BytesIndexOf := @BytesIndexOf_SSE2;
  dispatchTable.Memory.Utf8Validate := @Utf8Validate_SSE2;

  // Mask operations (bsf + SWAR popcount, always enabled)
  dispatchTable.Mask.Mask2All := @SharedMask2All;
  dispatchTable.Mask.Mask2Any := @SharedMask2Any;
  dispatchTable.Mask.Mask2None := @SharedMask2None;
  dispatchTable.Mask.Mask2PopCount := @SSE2Mask2PopCount;
  dispatchTable.Mask.Mask2FirstSet := @SharedMask2FirstSet;
  dispatchTable.Mask.Mask4All := @SharedMask4All;
  dispatchTable.Mask.Mask4Any := @SharedMask4Any;
  dispatchTable.Mask.Mask4None := @SharedMask4None;
  dispatchTable.Mask.Mask4PopCount := @SSE2Mask4PopCount;
  dispatchTable.Mask.Mask4FirstSet := @SharedMask4FirstSet;
  dispatchTable.Mask.Mask8All := @SharedMask8All;
  dispatchTable.Mask.Mask8Any := @SharedMask8Any;
  dispatchTable.Mask.Mask8None := @SharedMask8None;
  dispatchTable.Mask.Mask8PopCount := @SSE2Mask8PopCount;
  dispatchTable.Mask.Mask8FirstSet := @SharedMask8FirstSet;
  dispatchTable.Mask.Mask16All := @SharedMask16All;
  dispatchTable.Mask.Mask16Any := @SharedMask16Any;
  dispatchTable.Mask.Mask16None := @SharedMask16None;
  dispatchTable.Mask.Mask16PopCount := @SSE2Mask16PopCount;
  dispatchTable.Mask.Mask16FirstSet := @SharedMask16FirstSet;

  // ============================================================================
  // Batch Array Operations (SSE2 SIMD loops)
  // ============================================================================
  dispatchTable.BatchF32.ArrayAdd := @SSE2ArrayAddF32;
  dispatchTable.BatchF32.ArraySub := @SSE2ArraySubF32;
  dispatchTable.BatchF32.ArrayMul := @SSE2ArrayMulF32;
  dispatchTable.BatchF32.ArrayDiv := @SSE2ArrayDivF32;
  dispatchTable.BatchF32.ArrayMin := @SSE2ArrayMinF32;
  dispatchTable.BatchF32.ArrayMax := @SSE2ArrayMaxF32;
  dispatchTable.BatchF32.ArrayAbs := @SSE2ArrayAbsF32;
  dispatchTable.BatchF32.ArrayNeg := @SSE2ArrayNegF32;
  dispatchTable.BatchF32.ArraySqrt := @SSE2ArraySqrtF32;
  dispatchTable.BatchF32.ArrayRcp := @SSE2ArrayRcpF32;
  dispatchTable.BatchF32.ArrayRsqrt := @SSE2ArrayRsqrtF32;
  dispatchTable.BatchF32.ArrayAddScalar := @SSE2ArrayAddScalarF32;
  dispatchTable.BatchF32.ArrayMulScalar := @SSE2ArrayMulScalarF32;
  dispatchTable.BatchF32.ArrayClamp := @SSE2ArrayClampF32;
  dispatchTable.BatchF32.ArrayFma := @SSE2ArrayFmaF32;
  dispatchTable.BatchF32.ArrayAxpy := @SSE2ArrayAxpyF32;
  dispatchTable.BatchF32.ReduceSum := @SSE2ReduceSumF32;
  dispatchTable.BatchF32.ReduceDot := @SSE2ReduceDotF32;

  // F64 batch unary
  dispatchTable.BatchF64.ArrayAbs := @SSE2ArrayAbsF64;
  dispatchTable.BatchF64.ArrayNeg := @SSE2ArrayNegF64;
  dispatchTable.BatchF64.ArraySqrt := @SSE2ArraySqrtF64;
  dispatchTable.BatchF64.ArrayMulScalar := @SSE2ArrayMulScalarF64;
  dispatchTable.BatchF64.ArrayAddScalar := @SSE2ArrayAddScalarF64;
  dispatchTable.BatchF64.ArrayClamp := @SSE2ArrayClampF64;
  dispatchTable.BatchF64.ArrayLinear := @SSE2ArrayLinearF64;

  // F64 batch arithmetic
  dispatchTable.BatchF64.ArrayAdd := @SSE2ArrayAddF64;
  dispatchTable.BatchF64.ArraySub := @SSE2ArraySubF64;
  dispatchTable.BatchF64.ArrayMul := @SSE2ArrayMulF64;
  dispatchTable.BatchF64.ArrayDiv := @SSE2ArrayDivF64;

  // F64 extended batch operations
  dispatchTable.BatchF64.ArrayAxpy := @SSE2ArrayAxpyF64;
  dispatchTable.BatchF64.ArrayRcp := @SSE2ArrayRcpF64;
  dispatchTable.BatchF64.ArrayRsqrt := @SSE2ArrayRsqrtF64;
  dispatchTable.BatchF64.ArrayRcpRefine := @ScalarArrayRcpRefineF64;
  dispatchTable.BatchF64.ArrayRsqrtRefine := @ScalarArrayRsqrtRefineF64;
  dispatchTable.BatchF64.ArrayTan := @SSE2ArrayTanF64;
  dispatchTable.BatchF64.ArraySign := @SSE2ArraySignF64;
  dispatchTable.BatchF64.ArrayFract := @SSE2ArrayFractF64;
  dispatchTable.BatchF64.ArrayMod := @SSE2ArrayModF64;
  dispatchTable.BatchF64.ArrayPow := @SSE2ArrayPowF64;
  dispatchTable.BatchF64.ArrayLerp := @SSE2ArrayLerpF64;
  dispatchTable.BatchF64.ArrayReLU := @SSE2ArrayReLUF64;
  dispatchTable.BatchF64.ArrayAbsDiff := @SSE2ArrayAbsDiffF64;
  dispatchTable.BatchF64.ArrayNorm := @SSE2ArrayNormF64;
  dispatchTable.BatchF64.ArrayLinearReLU := @SSE2ArrayLinearReLUF64;
  dispatchTable.BatchF64.ArrayStep := @SSE2ArrayStepF64;
  dispatchTable.BatchF64.ArraySmoothstep := @SSE2ArraySmoothstepF64;
  dispatchTable.BatchF64.ArrayAtan2 := @SSE2ArrayAtan2F64;
  dispatchTable.BatchF64.ArrayHypot := @SSE2ArrayHypotF64;

  // Integer batch
  dispatchTable.BatchInteger.ArrayAddI32 := @SSE2ArrayAddI32;
  dispatchTable.BatchInteger.ArraySubI32 := @SSE2ArraySubI32;
  dispatchTable.BatchInteger.ArrayMulI16 := @SSE2ArrayMulI16;
  dispatchTable.BatchInteger.ArrayAndI32 := @SSE2ArrayAndI32;
  dispatchTable.BatchInteger.ArrayOrI32 := @SSE2ArrayOrI32;
  dispatchTable.BatchInteger.ArrayXorI32 := @SSE2ArrayXorI32;
  dispatchTable.BatchInteger.ArrayShlI32 := @SSE2ArrayShlI32;
  dispatchTable.BatchInteger.ArrayShrI32 := @SSE2ArrayShrI32;

  // U32 batch
  dispatchTable.BatchInteger.ArrayAddU32 := @SSE2ArrayAddU32;
  dispatchTable.BatchInteger.ArraySubU32 := @SSE2ArraySubU32;
  dispatchTable.BatchInteger.ArrayMulU32 := @SSE2ArrayMulU32;
  dispatchTable.BatchInteger.ArrayAndU32 := @SSE2ArrayAndU32;
  dispatchTable.BatchInteger.ArrayOrU32 := @SSE2ArrayOrU32;
  dispatchTable.BatchInteger.ArrayXorU32 := @SSE2ArrayXorU32;

  // Type conversion
  dispatchTable.BatchInteger.ArrayF32toI32 := @SSE2ArrayF32toI32;
  dispatchTable.BatchInteger.ArrayI32toF32 := @SSE2ArrayI32toF32;

  // F64 reductions
  dispatchTable.BatchF64.ReduceSum := @SSE2ReduceSumF64;
  dispatchTable.BatchF64.ReduceDot := @SSE2ReduceDotF64;

  // F32 reductions
  dispatchTable.BatchF32.ReduceMin := @SSE2ReduceMinF32;
  dispatchTable.BatchF32.ReduceMax := @SSE2ReduceMaxF32;

  // F64 reductions
  dispatchTable.BatchF64.ReduceMin := @SSE2ReduceMinF64;
  dispatchTable.BatchF64.ReduceMax := @SSE2ReduceMaxF64;

  // PackSat + NR Refine
  dispatchTable.BatchInteger.ArrayPackSatI32toI16 := @SSE2ArrayPackSatI32toI16;
  dispatchTable.BatchF32.ArrayRcpRefine := @SSE2ArrayRcpRefineF32;
  dispatchTable.BatchF32.ArrayRsqrtRefine := @SSE2ArrayRsqrtRefineF32;

  // Transcendental
  dispatchTable.BatchF32.ArrayExp := @SSE2ArrayExpF32;
  dispatchTable.BatchF32.ArrayLog := @SSE2ArrayLogF32;
  dispatchTable.BatchF32.ArraySin := @SSE2ArraySinF32;
  dispatchTable.BatchF32.ArrayCos := @SSE2ArrayCosF32;
  dispatchTable.BatchF32.ArrayPow := @SSE2ArrayPowF32;
  dispatchTable.BatchF32.ArrayTan := @SSE2ArrayTanF32;
  dispatchTable.BatchF32.ArraySinCos := @SSE2ArraySinCosF32;
  dispatchTable.BatchF32.ArrayLog2 := @SSE2ArrayLog2F32;
  dispatchTable.BatchF32.ArrayLog10 := @SSE2ArrayLog10F32;
  dispatchTable.BatchF32.ArrayAtan2 := @SSE2ArrayAtan2F32;
  dispatchTable.BatchF32.ArrayHypot := @SSE2ArrayHypotF32;

  // Rounding - SSE4.1 roundps 指令，纯 SSE2 CPU 使用标量回退
  if HasSSE41 then
  begin
    dispatchTable.BatchF32.ArrayCeil := @SSE2ArrayCeilF32;
    dispatchTable.BatchF32.ArrayFloor := @SSE2ArrayFloorF32;
    dispatchTable.BatchF32.ArrayRound := @SSE2ArrayRoundF32;
    dispatchTable.BatchF32.ArrayTrunc := @SSE2ArrayTruncF32;
    dispatchTable.BatchF32.ArrayFract := @SSE2ArrayFractF32;
  end
  else
  begin
    dispatchTable.BatchF32.ArrayCeil := @ScalarArrayCeilF32;
    dispatchTable.BatchF32.ArrayFloor := @ScalarArrayFloorF32;
    dispatchTable.BatchF32.ArrayRound := @ScalarArrayRoundF32;
    dispatchTable.BatchF32.ArrayTrunc := @ScalarArrayTruncF32;
    dispatchTable.BatchF32.ArrayFract := @ScalarArrayFractF32;
  end;

  // Interpolation
  dispatchTable.BatchF32.ArrayLerp := @SSE2ArrayLerpF32;

  // Utility — ArrayModF32 uses roundps (SSE4.1), gate with scalar fallback
  if HasSSE41 then
    dispatchTable.BatchF32.ArrayMod := @SSE2ArrayModF32
  else
    dispatchTable.BatchF32.ArrayMod := @ScalarArrayModF32;
  dispatchTable.BatchF32.ArraySign := @SSE2ArraySignF32;
  dispatchTable.BatchF32.ArrayStep := @SSE2ArrayStepF32;
  dispatchTable.BatchF32.ArraySmoothstep := @SSE2ArraySmoothstepF32;

  // Fused
  dispatchTable.BatchF32.ArrayLinear := @SSE2ArrayLinearF32;
  dispatchTable.BatchF32.ArrayAbsDiff := @SSE2ArrayAbsDiffF32;
  dispatchTable.BatchF32.ArrayReLU := @SSE2ArrayReLUF32;
  dispatchTable.BatchF32.ArrayNorm := @SSE2ArrayNormF32;
  dispatchTable.BatchF32.ArrayLinearReLU := @SSE2ArrayLinearReLUF32;

  // F64 Transcendental (SSE2 with loop unrolling)
  dispatchTable.BatchF64.ArraySin := @SSE2ArraySinF64;
  dispatchTable.BatchF64.ArrayCos := @SSE2ArrayCosF64;
  dispatchTable.BatchF64.ArrayExp := @SSE2ArrayExpF64;
  dispatchTable.BatchF64.ArrayLog := @SSE2ArrayLogF64;
  dispatchTable.BatchF64.ArrayLog2 := @SSE2ArrayLog2F64;
  dispatchTable.BatchF64.ArrayLog10 := @SSE2ArrayLog10F64;

  // F64 Rounding (SSE4.1 roundpd)
  if HasSSE41 then
  begin
    dispatchTable.BatchF64.ArrayCeil := @SSE2ArrayCeilF64;
    dispatchTable.BatchF64.ArrayFloor := @SSE2ArrayFloorF64;
    dispatchTable.BatchF64.ArrayRound := @SSE2ArrayRoundF64;
    dispatchTable.BatchF64.ArrayTrunc := @SSE2ArrayTruncF64;
  end
  else
  begin
    dispatchTable.BatchF64.ArrayCeil := @ScalarArrayCeilF64;
    dispatchTable.BatchF64.ArrayFloor := @ScalarArrayFloorF64;
    dispatchTable.BatchF64.ArrayRound := @ScalarArrayRoundF64;
    dispatchTable.BatchF64.ArrayTrunc := @ScalarArrayTruncF64;
  end;

  // Register the backend
  RegisterBackend(sbSSE2, dispatchTable);
end;

initialization
  RegisterSSE2Backend;
  // Register rebuilder callback for VectorAsmEnabled changes
  RegisterBackendRebuilder(sbSSE2, @RegisterSSE2Backend);
