procedure RegisterSSE41Backend;
var
  dispatchTable: TSimdDispatchTable;
  LUseVectorAsm: Boolean;
begin
  // Only register if SSE4.1 is available
  if not HasSSE41 then
    Exit;

  LUseVectorAsm := IsVectorAsmEnabled;

  // 使用 CloneDispatchTable 从 SSSE3 继承实现
  dispatchTable := Default(TSimdDispatchTable);
  if not CloneDispatchTable(sbSSSE3, dispatchTable) then
    if not CloneDispatchTable(sbSSE3, dispatchTable) then
      if not CloneDispatchTable(sbSSE2, dispatchTable) then
        FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbSSE41;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbSSE41;
    Name := 'SSE4.1';
    Description := 'x86-64 SSE4.1 SIMD (PMULLD, ROUNDPS, DPPS, PMINSD/PMAXSD)';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction,
                     scLoadStore];
    Include(Capabilities, scMaskedOps);
    Include(Capabilities, scIntegerOps);
    if LUseVectorAsm then
      Include(Capabilities, scShuffle);
    Available := LUseVectorAsm;
    Priority := GetSimdBackendPriorityValue(sbSSE41);
  end;

  // SSE4.1 provides major improvements
  if LUseVectorAsm then
  begin
    // CRITICAL: Override 32-bit integer multiply with PMULLD
    // This is a huge improvement over SSE2's workaround!
    dispatchTable.MulI32x4 := @SSE41MulI32x4;
    dispatchTable.MulU32x4 := @SSE41MulU32x4;

    // Override 32-bit integer min/max (PMINSD/PMAXSD)
    dispatchTable.MinI32x4 := @SSE41MinI32x4;
    dispatchTable.MaxI32x4 := @SSE41MaxI32x4;

    // Override 32-bit unsigned min/max (PMINUD/PMAXUD)
    dispatchTable.MinU32x4 := @SSE41MinU32x4;
    dispatchTable.MaxU32x4 := @SSE41MaxU32x4;

    // Override 8-bit signed min/max (PMINSB/PMAXSB)
    dispatchTable.MinI8x16 := @SSE41MinI8x16;
    dispatchTable.MaxI8x16 := @SSE41MaxI8x16;

    // Override 16-bit unsigned min/max (PMINUW/PMAXUW)
    dispatchTable.MinU16x8 := @SSE41MinU16x8;
    dispatchTable.MaxU16x8 := @SSE41MaxU16x8;

    // Override dot product with single-instruction DPPS
    dispatchTable.DotF32x4 := @SSE41DotF32x4;
    dispatchTable.DotF32x3 := @SSE41DotF32x3;

    // Override rounding operations with hardware ROUNDPS/ROUNDPD
    dispatchTable.RoundF32x4 := @SSE41RoundF32x4;
    dispatchTable.FloorF32x4 := @SSE41FloorF32x4;
    dispatchTable.CeilF32x4 := @SSE41CeilF32x4;
    dispatchTable.TruncF32x4 := @SSE41TruncF32x4;

    dispatchTable.RoundF64x2 := @SSE41RoundF64x2;
    dispatchTable.FloorF64x2 := @SSE41FloorF64x2;
    dispatchTable.CeilF64x2 := @SSE41CeilF64x2;
    dispatchTable.TruncF64x2 := @SSE41TruncF64x2;

    // Override length with DPPS-based version
    dispatchTable.LengthF32x4 := @SSE41LengthF32x4;
    dispatchTable.LengthF32x3 := @SSE41LengthF32x3;

    // Override normalize with DPPS-based version
    dispatchTable.NormalizeF32x4 := @SSE41NormalizeF32x4;
    dispatchTable.NormalizeF32x3 := @SSE41NormalizeF32x3;

    // Override insert/extract
    dispatchTable.InsertF32x4 := @SSE41InsertF32x4;
    dispatchTable.ExtractF32x4 := @SSE41ExtractF32x4;

    // Override 64-bit comparison
    dispatchTable.CmpEqI64x2 := @SSE41CmpEqI64x2;

    // Override select with BLENDVPS
    dispatchTable.SelectF32x4 := @SSE41SelectF32x4;
  end;

  // Register the backend
  RegisterBackend(sbSSE41, dispatchTable);
end;

initialization
  RegisterSSE41Backend;
  RegisterBackendRebuilder(sbSSE41, @RegisterSSE41Backend);
