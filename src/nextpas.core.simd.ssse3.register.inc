procedure RegisterSSSE3Backend;
var
  dispatchTable: TSimdDispatchTable;
  LUseVectorAsm: Boolean;
begin
  // Only register if SSSE3 is available
  if not HasSSSE3 then
    Exit;

  LUseVectorAsm := IsVectorAsmEnabled;

  // 使用 CloneDispatchTable 从 SSE3 继承实现
  dispatchTable := Default(TSimdDispatchTable);
  if not CloneDispatchTable(sbSSE3, dispatchTable) then
    if not CloneDispatchTable(sbSSE2, dispatchTable) then
      FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbSSSE3;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbSSSE3;
    Name := 'SSSE3';
    Description := 'x86-64 SSSE3 SIMD implementation (PSHUFB, PABS, PALIGNR)';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction,
                     scLoadStore];
    Include(Capabilities, scMaskedOps);
    Include(Capabilities, scIntegerOps);
    if LUseVectorAsm then
      Include(Capabilities, scShuffle);
    Available := LUseVectorAsm;
    Priority := GetSimdBackendPriorityValue(sbSSSE3);
  end;

  // SSSE3 adds direct helpers, but the dispatch-table Min/Max pair stays on
  // the inherited SSE3/SSE2 core slots because there is no better SSSE3-owned
  // override to bind here.

  // Register the backend
  RegisterBackend(sbSSSE3, dispatchTable);
end;

initialization
  RegisterSSSE3Backend;
  RegisterBackendRebuilder(sbSSSE3, @RegisterSSSE3Backend);
