// === Backend Registration ===

procedure RegisterSSE2i386Backend;
var
  dispatchTable: TSimdDispatchTable;
  LUseVectorAsm: Boolean;
begin
  // Only register if SSE2 is available
  if not HasSSE2 then
    Exit;

  LUseVectorAsm := IsVectorAsmEnabled;

  // Fill with base scalar implementations
  dispatchTable := Default(TSimdDispatchTable);
  FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbSSE2;
  dispatchTable.BackendInfo.Backend := sbSSE2;
  dispatchTable.BackendInfo.Name := 'SSE2-i386';
  dispatchTable.BackendInfo.Description := 'i386 SSE2 SIMD implementation (128-bit)';
  dispatchTable.BackendInfo.Capabilities := [scBasicArithmetic, scComparison, scMathFunctions,
                                             scReduction, scLoadStore];
  if LUseVectorAsm then
    Include(dispatchTable.BackendInfo.Capabilities, scShuffle);
  if LUseVectorAsm then
    Include(dispatchTable.BackendInfo.Capabilities, scIntegerOps);
  dispatchTable.BackendInfo.Available := LUseVectorAsm;
  dispatchTable.BackendInfo.Priority := GetSimdBackendPriorityValue(sbSSE2);

  // Override facade functions with SSE2-accelerated versions
  dispatchTable.MemEqual := @MemEqual_SSE2_i386;
  dispatchTable.MemFindByte := @MemFindByte_SSE2_i386;
  dispatchTable.SumBytes := @SumBytes_SSE2_i386;
  dispatchTable.CountByte := @CountByte_SSE2_i386;
  dispatchTable.BitsetPopCount := @BitsetPopCount_SSE2_i386;

  // Override vector operations with SSE2-accelerated versions
  if LUseVectorAsm then
  begin
    dispatchTable.AddF32x4 := @SSE2AddF32x4_i386;
    dispatchTable.SubF32x4 := @SSE2SubF32x4_i386;
    dispatchTable.MulF32x4 := @SSE2MulF32x4_i386;
    dispatchTable.DivF32x4 := @SSE2DivF32x4_i386;
    dispatchTable.AddI32x4 := @SSE2AddI32x4_i386;
    dispatchTable.SubI32x4 := @SSE2SubI32x4_i386;
    dispatchTable.MulI32x4 := @SSE2MulI32x4_i386;
    dispatchTable.AddF64x2 := @SSE2AddF64x2_i386;
    dispatchTable.SubF64x2 := @SSE2SubF64x2_i386;
    dispatchTable.MulF64x2 := @SSE2MulF64x2_i386;
    dispatchTable.DivF64x2 := @SSE2DivF64x2_i386;
  end;

  // Register the backend
  RegisterBackend(sbSSE2, dispatchTable);
end;

initialization
  RegisterSSE2i386Backend;
  RegisterBackendRebuilder(sbSSE2, @RegisterSSE2i386Backend);
