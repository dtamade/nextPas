procedure RegisterSSE3Backend;
var
  dispatchTable: TSimdDispatchTable;
  LUseVectorAsm: Boolean;
begin
  // Only register if SSE3 is available
  if not HasSSE3 then
    Exit;

  LUseVectorAsm := IsVectorAsmEnabled;

  // 使用 CloneDispatchTable 从 SSE2 继承实现
  // 这比从标量基线开始更高效
  dispatchTable := Default(TSimdDispatchTable);
  if not CloneDispatchTable(sbSSE2, dispatchTable) then
    FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbSSE3;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbSSE3;
    Name := 'SSE3';
    Description := 'x86-64 SSE3 SIMD implementation (horizontal ops, HADD)';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction,
                     scLoadStore];
    Include(Capabilities, scMaskedOps);
    Include(Capabilities, scIntegerOps);
    if LUseVectorAsm then
      Include(Capabilities, scShuffle);
    Available := LUseVectorAsm;
    Priority := GetSimdBackendPriorityValue(sbSSE3);
  end;

  // SSE3 improvements: faster reductions via HADD
  if LUseVectorAsm then
  begin
    // Override reduction operations with SSE3 HADD versions (faster)
    dispatchTable.ReduceAddF32x4 := @SSE3ReduceAddF32x4;
    dispatchTable.ReduceAddF64x2 := @SSE3ReduceAddF64x2;
    dispatchTable.ReduceMulF32x4 := @SSE3ReduceMulF32x4;
    dispatchTable.ReduceMulF64x2 := @SSE3ReduceMulF64x2;

    // Override dot product with SSE3 version (uses HADD)
    dispatchTable.DotF32x4 := @SSE3DotF32x4;
    dispatchTable.DotF32x3 := @SSE3DotF32x3;

    // Override length with SSE3 version
    dispatchTable.LengthF32x4 := @SSE3LengthF32x4;
    dispatchTable.LengthF32x3 := @SSE3LengthF32x3;

    // Override normalize with SSE3 version
    dispatchTable.NormalizeF32x4 := @SSE3NormalizeF32x4;
    dispatchTable.NormalizeF32x3 := @SSE3NormalizeF32x3;
  end;

  // Register the backend
  RegisterBackend(sbSSE3, dispatchTable);
end;

initialization
  RegisterSSE3Backend;
  RegisterBackendRebuilder(sbSSE3, @RegisterSSE3Backend);
