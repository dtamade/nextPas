procedure RegisterSSE42Backend;
var
  dispatchTable: TSimdDispatchTable;
  LUseVectorAsm: Boolean;
begin
  // Only register if SSE4.2 is available
  if not HasSSE42 then
    Exit;

  LUseVectorAsm := IsVectorAsmEnabled;

  dispatchTable := Default(TSimdDispatchTable);

  // SSE4.2 is an incremental extension over SSE4.1 and must retain the
  // higher-level dispatch wiring from prior x86 backends.
  if not CloneDispatchTable(sbSSE41, dispatchTable) then
    if not CloneDispatchTable(sbSSSE3, dispatchTable) then
      if not CloneDispatchTable(sbSSE3, dispatchTable) then
        if not CloneDispatchTable(sbSSE2, dispatchTable) then
          FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbSSE42;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbSSE42;
    Name := 'SSE4.2';
    Description := 'x86-64 SSE4.2 SIMD implementation (CRC32, string ops)';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction,
                     scLoadStore];
    Include(Capabilities, scMaskedOps);
    Include(Capabilities, scIntegerOps);
    if LUseVectorAsm then
      Include(Capabilities, scShuffle);
    Available := LUseVectorAsm;
    Priority := GetSimdBackendPriorityValue(sbSSE42);
  end;

  // SSE4.2 provides string operations and CRC32
  if LUseVectorAsm then
  begin
    // Override 64-bit comparison with PCMPGTQ
    dispatchTable.CmpGtI64x2 := @SSE42CmpGtI64x2;

    // SSE4.2 pcmpestri substring search
    dispatchTable.BytesIndexOf := @BytesIndexOf_SSE42;
  end;

  // Register the backend
  RegisterBackend(sbSSE42, dispatchTable);
end;

initialization
  RegisterSSE42Backend;
  RegisterBackendRebuilder(sbSSE42, @RegisterSSE42Backend);
