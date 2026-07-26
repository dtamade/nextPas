procedure RegisterRISCVVBackend;
var
  table: TSimdDispatchTable;
  LCapabilities: TSimdCapabilities;
  LAsmCapable: Boolean;
  LUseVectorAsm: Boolean;
begin
  // Seed the dispatch table from the canonical scalar baseline so every
  // unassigned slot keeps a valid fallback and a stable ownership origin.
  table := Default(TSimdDispatchTable);
  FillBaseDispatchTable(table);

  LAsmCapable := False;
  {$IFDEF RISCVV_ASSEMBLY}
  LAsmCapable := True;
  {$ENDIF}
  LUseVectorAsm := False;
  if LAsmCapable then
    LUseVectorAsm := IsVectorAsmEnabled;

  // Backend info
  table.Backend := sbRISCVV;
  table.BackendInfo.Backend := sbRISCVV;
  table.BackendInfo.Name := 'RISC-V V';
  table.BackendInfo.Description := 'RISC-V Vector Extension (RVV) (experimental opt-in)';
  table.BackendInfo.Available := (not LAsmCapable) or LUseVectorAsm;
  table.BackendInfo.Priority := GetSimdBackendPriorityValue(sbRISCVV);
  LCapabilities := [
    scBasicArithmetic,
    scComparison,
    scMathFunctions,
    scReduction,
    scLoadStore
  ];
  if LUseVectorAsm then
  begin
    Include(LCapabilities, scIntegerOps);
    Include(LCapabilities, scShuffle);
    Include(LCapabilities, scFMA);
    Include(LCapabilities, scMaskedOps);
  end;
  table.BackendInfo.Capabilities := LCapabilities;

  if LAsmCapable and (not LUseVectorAsm) then
  begin
    RegisterBackend(sbRISCVV, table);
    Exit;
  end;

  // === F32x4 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AddF32x4 := @RISCVVAddF32x4;
  table.CoreVectors.SubF32x4 := @RISCVVSubF32x4;
  table.CoreVectors.MulF32x4 := @RISCVVMulF32x4;
  table.CoreVectors.DivF32x4 := @RISCVVDivF32x4;

  // F32x4 Math
  table.CoreVectors.AbsF32x4 := @RISCVVAbsF32x4;
  table.CoreVectors.SqrtF32x4 := @RISCVVSqrtF32x4;
  table.CoreVectors.MinF32x4 := @RISCVVMinF32x4;
  table.CoreVectors.MaxF32x4 := @RISCVVMaxF32x4;
  table.CoreVectors.FmaF32x4 := @RISCVVFmaF32x4;
  table.CoreVectors.RcpF32x4 := @RISCVVRcpF32x4;
  table.CoreVectors.RsqrtF32x4 := @RISCVVRsqrtF32x4;
  table.CoreVectors.ClampF32x4 := @RISCVVClampF32x4;
  {$ENDIF}
  // Keep 128-bit IEEE-sensitive rounding on the canonical base scalar slots
  // until the RISCVV-specific semantics are validated end-to-end.

  // F32x4 Vector Math
  table.CoreVectors.DotF32x4 := @RISCVVDotF32x4;
  table.CoreVectors.DotF32x3 := @RISCVVDotF32x3;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.CrossF32x3 := @RISCVVCrossF32x3;
  {$ENDIF}
  table.CoreVectors.LengthF32x4 := @RISCVVLengthF32x4;
  table.CoreVectors.LengthF32x3 := @RISCVVLengthF32x3;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.NormalizeF32x4 := @RISCVVNormalizeF32x4;
  table.CoreVectors.NormalizeF32x3 := @RISCVVNormalizeF32x3;
  {$ENDIF}

  // F32x4 Reduction
  table.CoreVectors.ReduceAddF32x4 := @RISCVVReduceAddF32x4;
  table.CoreVectors.ReduceMinF32x4 := @RISCVVReduceMinF32x4;
  table.CoreVectors.ReduceMaxF32x4 := @RISCVVReduceMaxF32x4;
  table.CoreVectors.ReduceMulF32x4 := @RISCVVReduceMulF32x4;

  // F32x4 Comparison
  table.CoreVectors.CmpEqF32x4 := @RISCVVCmpEqF32x4;
  table.CoreVectors.CmpLtF32x4 := @RISCVVCmpLtF32x4;
  table.CoreVectors.CmpLeF32x4 := @RISCVVCmpLeF32x4;
  table.CoreVectors.CmpGtF32x4 := @RISCVVCmpGtF32x4;
  table.CoreVectors.CmpGeF32x4 := @RISCVVCmpGeF32x4;
  table.CoreVectors.CmpNeF32x4 := @RISCVVCmpNeF32x4;

  // F32x4 Memory
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.LoadF32x4 := @RISCVVLoadF32x4;
  table.CoreVectors.LoadF32x4Aligned := @RISCVVLoadF32x4Aligned;
  {$ENDIF}
  table.CoreVectors.StoreF32x4 := @RISCVVStoreF32x4;
  table.CoreVectors.StoreF32x4Aligned := @RISCVVStoreF32x4Aligned;

  // F32x4 Utility
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.SplatF32x4 := @RISCVVSplatF32x4;
  table.CoreVectors.ZeroF32x4 := @RISCVVZeroF32x4;
  table.CoreVectors.SelectF32x4 := @RISCVVSelectF32x4;
  table.CoreVectors.ExtractF32x4 := @RISCVVExtractF32x4;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.InsertF32x4 := @RISCVVInsertF32x4;
  {$ENDIF}

  // === F64x2 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AddF64x2 := @RISCVVAddF64x2;
  table.CoreVectors.SubF64x2 := @RISCVVSubF64x2;
  table.CoreVectors.MulF64x2 := @RISCVVMulF64x2;
  table.CoreVectors.DivF64x2 := @RISCVVDivF64x2;
  {$ENDIF}

  // === I32x4 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AddI32x4 := @RISCVVAddI32x4;
  table.CoreVectors.SubI32x4 := @RISCVVSubI32x4;
  table.CoreVectors.MulI32x4 := @RISCVVMulI32x4;

  // I32x4 Bitwise
  table.CoreVectors.AndI32x4 := @RISCVVAndI32x4;
  table.CoreVectors.OrI32x4 := @RISCVVOrI32x4;
  table.CoreVectors.XorI32x4 := @RISCVVXorI32x4;
  table.CoreVectors.NotI32x4 := @RISCVVNotI32x4;
  table.CoreVectors.AndNotI32x4 := @RISCVVAndNotI32x4;

  // I32x4 Shift
  table.CoreVectors.ShiftLeftI32x4 := @RISCVVShiftLeftI32x4;
  table.CoreVectors.ShiftRightI32x4 := @RISCVVShiftRightI32x4;
  table.CoreVectors.ShiftRightArithI32x4 := @RISCVVShiftRightArithI32x4;
  {$ENDIF}

  // I32x4 Comparison
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.CmpEqI32x4 := @RISCVVCmpEqI32x4;
  table.CoreVectors.CmpLtI32x4 := @RISCVVCmpLtI32x4;
  table.CoreVectors.CmpGtI32x4 := @RISCVVCmpGtI32x4;
  table.CoreVectors.CmpLeI32x4 := @RISCVVCmpLeI32x4;
  table.CoreVectors.CmpGeI32x4 := @RISCVVCmpGeI32x4;
  table.CoreVectors.CmpNeI32x4 := @RISCVVCmpNeI32x4;
  {$ENDIF}

  // I32x4 Min/Max
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.MinI32x4 := @RISCVVMinI32x4;
  table.CoreVectors.MaxI32x4 := @RISCVVMaxI32x4;
  {$ENDIF}

  // === I64x2 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AddI64x2 := @RISCVVAddI64x2;
  table.CoreVectors.SubI64x2 := @RISCVVSubI64x2;
  table.CoreVectors.AndI64x2 := @RISCVVAndI64x2;
  table.CoreVectors.OrI64x2 := @RISCVVOrI64x2;
  table.CoreVectors.XorI64x2 := @RISCVVXorI64x2;
  table.CoreVectors.NotI64x2 := @RISCVVNotI64x2;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.ShiftLeftI64x2 := @RISCVVShiftLeftI64x2;
  table.CoreVectors.ShiftRightI64x2 := @RISCVVShiftRightI64x2;
  table.CoreVectors.ShiftRightArithI64x2 := @RISCVVShiftRightArithI64x2;
  {$ENDIF}

  // === U64x2 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AddU64x2 := @RISCVVAddU64x2;
  table.CoreVectors.SubU64x2 := @RISCVVSubU64x2;
  table.CoreVectors.AndU64x2 := @RISCVVAndU64x2;
  table.CoreVectors.OrU64x2 := @RISCVVOrU64x2;
  table.CoreVectors.XorU64x2 := @RISCVVXorU64x2;
  table.CoreVectors.NotU64x2 := @RISCVVNotU64x2;
  {$ENDIF}
  // === F32x8 Operations ===
  table.CoreVectors.AddF32x8 := @RISCVVAddF32x8;
  table.CoreVectors.SubF32x8 := @RISCVVSubF32x8;
  table.CoreVectors.MulF32x8 := @RISCVVMulF32x8;
  table.CoreVectors.DivF32x8 := @RISCVVDivF32x8;

  // F32x8 Comparison
  table.CoreVectors.CmpEqF32x8 := @RISCVVCmpEqF32x8;
  table.CoreVectors.CmpLtF32x8 := @RISCVVCmpLtF32x8;
  table.CoreVectors.CmpLeF32x8 := @RISCVVCmpLeF32x8;
  table.CoreVectors.CmpGtF32x8 := @RISCVVCmpGtF32x8;
  table.CoreVectors.CmpGeF32x8 := @RISCVVCmpGeF32x8;
  table.CoreVectors.CmpNeF32x8 := @RISCVVCmpNeF32x8;

  // === F64x4 Operations ===
  table.CoreVectors.AddF64x4 := @RISCVVAddF64x4;
  table.CoreVectors.SubF64x4 := @RISCVVSubF64x4;
  table.CoreVectors.MulF64x4 := @RISCVVMulF64x4;
  table.CoreVectors.DivF64x4 := @RISCVVDivF64x4;

  // F64x4 Comparison
  table.CoreVectors.CmpEqF64x4 := @RISCVVCmpEqF64x4;
  table.CoreVectors.CmpLtF64x4 := @RISCVVCmpLtF64x4;
  table.CoreVectors.CmpLeF64x4 := @RISCVVCmpLeF64x4;
  table.CoreVectors.CmpGtF64x4 := @RISCVVCmpGtF64x4;
  table.CoreVectors.CmpGeF64x4 := @RISCVVCmpGeF64x4;
  table.CoreVectors.CmpNeF64x4 := @RISCVVCmpNeF64x4;

  // === I32x8 Operations ===
  // Keep these wide integer key slots bound to RISCVV symbols. Non-asm builds
  // still resolve through riscvv.facade.inc, so silently remapping them to
  // base scalar would make the published backend-ownership contract false.
  table.CoreVectors.AddI32x8 := @RISCVVAddI32x8;
  table.CoreVectors.SubI32x8 := @RISCVVSubI32x8;
  table.CoreVectors.MulI32x8 := @RISCVVMulI32x8;
  table.CoreVectors.AndI32x8 := @RISCVVAndI32x8;
  table.CoreVectors.OrI32x8 := @RISCVVOrI32x8;
  table.CoreVectors.XorI32x8 := @RISCVVXorI32x8;
  table.CoreVectors.NotI32x8 := @RISCVVNotI32x8;
  table.CoreVectors.AndNotI32x8 := @RISCVVAndNotI32x8;
  table.CoreVectors.ShiftLeftI32x8 := @RISCVVShiftLeftI32x8;
  table.CoreVectors.ShiftRightI32x8 := @RISCVVShiftRightI32x8;
  table.CoreVectors.ShiftRightArithI32x8 := @RISCVVShiftRightArithI32x8;
  table.CoreVectors.CmpEqI32x8 := @RISCVVCmpEqI32x8;
  table.CoreVectors.CmpLtI32x8 := @RISCVVCmpLtI32x8;
  table.CoreVectors.CmpGtI32x8 := @RISCVVCmpGtI32x8;
  table.CoreVectors.CmpLeI32x8 := @RISCVVCmpLeI32x8;
  table.CoreVectors.CmpGeI32x8 := @RISCVVCmpGeI32x8;
  table.CoreVectors.CmpNeI32x8 := @RISCVVCmpNeI32x8;
  table.CoreVectors.MinI32x8 := @RISCVVMinI32x8;
  table.CoreVectors.MaxI32x8 := @RISCVVMaxI32x8;

  // === I32x16 Operations ===
  table.CoreVectors.AddI32x16 := @RISCVVAddI32x16;
  table.CoreVectors.SubI32x16 := @RISCVVSubI32x16;
  table.CoreVectors.MulI32x16 := @RISCVVMulI32x16;
  table.CoreVectors.AndI32x16 := @RISCVVAndI32x16;
  table.CoreVectors.OrI32x16 := @RISCVVOrI32x16;
  table.CoreVectors.XorI32x16 := @RISCVVXorI32x16;
  table.CoreVectors.NotI32x16 := @RISCVVNotI32x16;
  table.CoreVectors.AndNotI32x16 := @RISCVVAndNotI32x16;
  table.CoreVectors.ShiftLeftI32x16 := @RISCVVShiftLeftI32x16;
  table.CoreVectors.ShiftRightI32x16 := @RISCVVShiftRightI32x16;
  table.CoreVectors.ShiftRightArithI32x16 := @RISCVVShiftRightArithI32x16;
  table.CoreVectors.CmpEqI32x16 := @RISCVVCmpEqI32x16;
  table.CoreVectors.CmpLtI32x16 := @RISCVVCmpLtI32x16;
  table.CoreVectors.CmpGtI32x16 := @RISCVVCmpGtI32x16;
  table.CoreVectors.CmpLeI32x16 := @RISCVVCmpLeI32x16;
  table.CoreVectors.CmpGeI32x16 := @RISCVVCmpGeI32x16;
  table.CoreVectors.CmpNeI32x16 := @RISCVVCmpNeI32x16;
  table.CoreVectors.MinI32x16 := @RISCVVMinI32x16;
  table.CoreVectors.MaxI32x16 := @RISCVVMaxI32x16;

  // === F32x16 Operations (512-bit, 16x Single) ===
  table.CoreVectors.AddF32x16 := @RISCVVAddF32x16;
  table.CoreVectors.SubF32x16 := @RISCVVSubF32x16;
  table.CoreVectors.MulF32x16 := @RISCVVMulF32x16;
  table.CoreVectors.DivF32x16 := @RISCVVDivF32x16;

  // F32x16 Comparison
  table.CoreVectors.CmpEqF32x16 := @RISCVVCmpEqF32x16;
  table.CoreVectors.CmpLtF32x16 := @RISCVVCmpLtF32x16;
  table.CoreVectors.CmpLeF32x16 := @RISCVVCmpLeF32x16;
  table.CoreVectors.CmpGtF32x16 := @RISCVVCmpGtF32x16;
  table.CoreVectors.CmpGeF32x16 := @RISCVVCmpGeF32x16;
  table.CoreVectors.CmpNeF32x16 := @RISCVVCmpNeF32x16;
  table.CoreVectors.SelectF32x16 := @RISCVVSelectF32x16;

  // === F64x8 Operations (512-bit, 8x Double) ===
  table.CoreVectors.AddF64x8 := @RISCVVAddF64x8;
  table.CoreVectors.SubF64x8 := @RISCVVSubF64x8;
  table.CoreVectors.MulF64x8 := @RISCVVMulF64x8;
  table.CoreVectors.DivF64x8 := @RISCVVDivF64x8;

  // F64x8 Comparison
  table.CoreVectors.CmpEqF64x8 := @RISCVVCmpEqF64x8;
  table.CoreVectors.CmpLtF64x8 := @RISCVVCmpLtF64x8;
  table.CoreVectors.CmpLeF64x8 := @RISCVVCmpLeF64x8;
  table.CoreVectors.CmpGtF64x8 := @RISCVVCmpGtF64x8;
  table.CoreVectors.CmpGeF64x8 := @RISCVVCmpGeF64x8;
  table.CoreVectors.CmpNeF64x8 := @RISCVVCmpNeF64x8;
  table.CoreVectors.SelectF64x8 := @RISCVVSelectF64x8;

  // === Mask Operations ===
  // TMask4 Operations
  table.Mask.Mask4All := @RISCVVMask4All;
  table.Mask.Mask4Any := @RISCVVMask4Any;
  table.Mask.Mask4None := @RISCVVMask4None;
  table.Mask.Mask4PopCount := @RISCVVMask4PopCount;
  table.Mask.Mask4FirstSet := @RISCVVMask4FirstSet;

  // TMask8 Operations
  table.Mask.Mask8All := @RISCVVMask8All;
  table.Mask.Mask8Any := @RISCVVMask8Any;
  table.Mask.Mask8None := @RISCVVMask8None;
  table.Mask.Mask8PopCount := @RISCVVMask8PopCount;
  table.Mask.Mask8FirstSet := @RISCVVMask8FirstSet;

  // TMask16 Operations
  table.Mask.Mask16All := @RISCVVMask16All;
  table.Mask.Mask16Any := @RISCVVMask16Any;
  table.Mask.Mask16None := @RISCVVMask16None;
  table.Mask.Mask16PopCount := @RISCVVMask16PopCount;
  table.Mask.Mask16FirstSet := @RISCVVMask16FirstSet;

  // =============================================================
  // Additional Operations Registration (100% Coverage)
  // =============================================================

  // TMask2 Operations
  table.Mask.Mask2All := @RISCVVMask2All;
  table.Mask.Mask2Any := @RISCVVMask2Any;
  table.Mask.Mask2None := @RISCVVMask2None;
  table.Mask.Mask2PopCount := @RISCVVMask2PopCount;
  table.Mask.Mask2FirstSet := @RISCVVMask2FirstSet;

  // Wide Float Operations (Abs, Sqrt, Min, Max, Clamp)
  table.CoreVectors.AbsF32x16 := @RISCVVAbsF32x16;
  table.CoreVectors.AbsF32x8 := @RISCVVAbsF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AbsF64x2 := @RISCVVAbsF64x2;
  {$ENDIF}
  table.CoreVectors.AbsF64x4 := @RISCVVAbsF64x4;
  table.CoreVectors.AbsF64x8 := @RISCVVAbsF64x8;
  table.CoreVectors.SqrtF32x16 := @RISCVVSqrtF32x16;
  table.CoreVectors.SqrtF32x8 := @RISCVVSqrtF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.SqrtF64x2 := @RISCVVSqrtF64x2;
  {$ENDIF}
  table.CoreVectors.SqrtF64x4 := @RISCVVSqrtF64x4;
  table.CoreVectors.SqrtF64x8 := @RISCVVSqrtF64x8;
  table.CoreVectors.MinF32x16 := @RISCVVMinF32x16;
  table.CoreVectors.MinF32x8 := @RISCVVMinF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.MinF64x2 := @RISCVVMinF64x2;
  {$ENDIF}
  table.CoreVectors.MinF64x4 := @RISCVVMinF64x4;
  table.CoreVectors.MinF64x8 := @RISCVVMinF64x8;
  table.CoreVectors.MaxF32x16 := @RISCVVMaxF32x16;
  table.CoreVectors.MaxF32x8 := @RISCVVMaxF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.MaxF64x2 := @RISCVVMaxF64x2;
  {$ENDIF}
  table.CoreVectors.MaxF64x4 := @RISCVVMaxF64x4;
  table.CoreVectors.MaxF64x8 := @RISCVVMaxF64x8;
  // Keep wide F32 Clamp on the canonical base scalar slots until RVV-specific
  // semantics are validated end-to-end.
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.ClampF64x2 := @RISCVVClampF64x2;
  {$ENDIF}
  table.CoreVectors.ClampF64x4 := @RISCVVClampF64x4;
  table.CoreVectors.ClampF64x8 := @RISCVVClampF64x8;

  // Keep wide Floor/Ceil/Round/Trunc on the canonical base scalar slots until
  // RISCVV-specific semantics are implemented and validated end-to-end. F64
  // Clamp remains backend-owned because its local NaN/signed-zero fallback is
  // still intentional.
  table.CoreVectors.FmaF32x16 := @RISCVVFmaF32x16;
  table.CoreVectors.FmaF32x8 := @RISCVVFmaF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.FmaF64x2 := @RISCVVFmaF64x2;
  {$ENDIF}
  table.CoreVectors.FmaF64x4 := @RISCVVFmaF64x4;
  table.CoreVectors.FmaF64x8 := @RISCVVFmaF64x8;

  // Wide Float Reduction
  table.CoreVectors.ReduceAddF32x16 := @RISCVVReduceAddF32x16;
  table.CoreVectors.ReduceAddF32x8 := @RISCVVReduceAddF32x8;
  table.CoreVectors.ReduceAddF64x2 := @RISCVVReduceAddF64x2;
  table.CoreVectors.ReduceAddF64x4 := @RISCVVReduceAddF64x4;
  table.CoreVectors.ReduceAddF64x8 := @RISCVVReduceAddF64x8;
  table.CoreVectors.ReduceMaxF32x16 := @RISCVVReduceMaxF32x16;
  table.CoreVectors.ReduceMaxF32x8 := @RISCVVReduceMaxF32x8;
  table.CoreVectors.ReduceMaxF64x2 := @RISCVVReduceMaxF64x2;
  table.CoreVectors.ReduceMaxF64x4 := @RISCVVReduceMaxF64x4;
  table.CoreVectors.ReduceMaxF64x8 := @RISCVVReduceMaxF64x8;
  table.CoreVectors.ReduceMinF32x16 := @RISCVVReduceMinF32x16;
  table.CoreVectors.ReduceMinF32x8 := @RISCVVReduceMinF32x8;
  table.CoreVectors.ReduceMinF64x2 := @RISCVVReduceMinF64x2;
  table.CoreVectors.ReduceMinF64x4 := @RISCVVReduceMinF64x4;
  table.CoreVectors.ReduceMinF64x8 := @RISCVVReduceMinF64x8;
  table.CoreVectors.ReduceMulF32x16 := @RISCVVReduceMulF32x16;
  table.CoreVectors.ReduceMulF32x8 := @RISCVVReduceMulF32x8;
  table.CoreVectors.ReduceMulF64x2 := @RISCVVReduceMulF64x2;
  table.CoreVectors.ReduceMulF64x4 := @RISCVVReduceMulF64x4;
  table.CoreVectors.ReduceMulF64x8 := @RISCVVReduceMulF64x8;

  // F64x2 Comparison
  table.CoreVectors.CmpEqF64x2 := @RISCVVCmpEqF64x2;
  table.CoreVectors.CmpLtF64x2 := @RISCVVCmpLtF64x2;
  table.CoreVectors.CmpLeF64x2 := @RISCVVCmpLeF64x2;
  table.CoreVectors.CmpGtF64x2 := @RISCVVCmpGtF64x2;
  table.CoreVectors.CmpGeF64x2 := @RISCVVCmpGeF64x2;
  table.CoreVectors.CmpNeF64x2 := @RISCVVCmpNeF64x2;

  // Wide Float Memory/Utility
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.LoadF32x16 := @RISCVVLoadF32x16;
  table.CoreVectors.LoadF32x8 := @RISCVVLoadF32x8;
  table.CoreVectors.LoadF64x2 := @RISCVVLoadF64x2;
  table.CoreVectors.LoadF64x4 := @RISCVVLoadF64x4;
  table.CoreVectors.LoadF64x8 := @RISCVVLoadF64x8;
  {$ENDIF}
  table.CoreVectors.StoreF32x16 := @RISCVVStoreF32x16;
  table.CoreVectors.StoreF32x8 := @RISCVVStoreF32x8;
  table.CoreVectors.StoreF64x2 := @RISCVVStoreF64x2;
  table.CoreVectors.StoreF64x4 := @RISCVVStoreF64x4;
  table.CoreVectors.StoreF64x8 := @RISCVVStoreF64x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.SplatF32x16 := @RISCVVSplatF32x16;
  table.CoreVectors.SplatF32x8 := @RISCVVSplatF32x8;
  table.CoreVectors.SplatF64x2 := @RISCVVSplatF64x2;
  table.CoreVectors.SplatF64x4 := @RISCVVSplatF64x4;
  table.CoreVectors.SplatF64x8 := @RISCVVSplatF64x8;
  table.CoreVectors.ZeroF32x16 := @RISCVVZeroF32x16;
  table.CoreVectors.ZeroF32x8 := @RISCVVZeroF32x8;
  table.CoreVectors.ZeroF64x2 := @RISCVVZeroF64x2;
  table.CoreVectors.ZeroF64x4 := @RISCVVZeroF64x4;
  table.CoreVectors.ZeroF64x8 := @RISCVVZeroF64x8;
  {$ENDIF}

  // Wide Float Extract/Insert
  // Keep Extract* genuinely asm-gated. On no-asm hosts these slots should
  // continue to reuse the FillBaseDispatchTable scalar truth instead of
  // publishing dead RISCVV-specific scalar forwarders.
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.ExtractF32x16 := @RISCVVExtractF32x16;
  table.CoreVectors.ExtractF32x8 := @RISCVVExtractF32x8;
  table.CoreVectors.ExtractF64x2 := @RISCVVExtractF64x2;
  table.CoreVectors.ExtractF64x4 := @RISCVVExtractF64x4;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.InsertF32x16 := @RISCVVInsertF32x16;
  table.CoreVectors.InsertF32x8 := @RISCVVInsertF32x8;
  table.CoreVectors.InsertF64x2 := @RISCVVInsertF64x2;
  table.CoreVectors.InsertF64x4 := @RISCVVInsertF64x4;
  {$ENDIF}

  // Wide Float Select
  {$IFDEF RISCVV_ASSEMBLY}
  // Keep the 128-bit representative shuffle leaf on RISCVV. The wider
  // SelectF32x8/F64x4/I32x4 variants do not currently provide distinct
  // non-scalar semantics, so they continue to reuse the seeded base scalar
  // slots until real RVV-specific implementations exist.
  table.CoreVectors.SelectF64x2 := @RISCVVSelectF64x2;
  table.CoreVectors.CmpEqI64x2 := @RISCVVCmpEqI64x2;
  table.CoreVectors.CmpLtI64x2 := @RISCVVCmpLtI64x2;
  table.CoreVectors.CmpLeI64x2 := @RISCVVCmpLeI64x2;
  table.CoreVectors.CmpGtI64x2 := @RISCVVCmpGtI64x2;
  table.CoreVectors.CmpGeI64x2 := @RISCVVCmpGeI64x2;
  table.CoreVectors.CmpNeI64x2 := @RISCVVCmpNeI64x2;
  {$ENDIF}

  // I64x4 Operations
  // Only Add/Sub are backend-owned in this family today. Mul/Min/Max are not
  // open dispatch slots yet, so do not "complete" the family here.
  table.CoreVectors.AddI64x4 := @RISCVVAddI64x4;
  table.CoreVectors.SubI64x4 := @RISCVVSubI64x4;
  table.CoreVectors.AndI64x4 := @RISCVVAndI64x4;
  table.CoreVectors.OrI64x4 := @RISCVVOrI64x4;
  table.CoreVectors.XorI64x4 := @RISCVVXorI64x4;
  table.CoreVectors.NotI64x4 := @RISCVVNotI64x4;
  table.CoreVectors.AndNotI64x4 := @RISCVVAndNotI64x4;
  table.CoreVectors.ShiftLeftI64x4 := @RISCVVShiftLeftI64x4;
  table.CoreVectors.ShiftRightI64x4 := @RISCVVShiftRightI64x4;
  table.CoreVectors.ShiftRightArithI64x4 := @RISCVVShiftRightArithI64x4;
  table.CoreVectors.CmpEqI64x4 := @RISCVVCmpEqI64x4;
  table.CoreVectors.CmpLtI64x4 := @RISCVVCmpLtI64x4;
  table.CoreVectors.CmpLeI64x4 := @RISCVVCmpLeI64x4;
  table.CoreVectors.CmpGtI64x4 := @RISCVVCmpGtI64x4;
  table.CoreVectors.CmpGeI64x4 := @RISCVVCmpGeI64x4;
  table.CoreVectors.CmpNeI64x4 := @RISCVVCmpNeI64x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.LoadI64x4 := @RISCVVLoadI64x4;
  {$ENDIF}
  table.CoreVectors.StoreI64x4 := @RISCVVStoreI64x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.SplatI64x4 := @RISCVVSplatI64x4;
  table.CoreVectors.ZeroI64x4 := @RISCVVZeroI64x4;
  {$ENDIF}
  // Keep ExtractI64x4 genuinely asm-gated. Non-asm hosts should reuse the
  // seeded base scalar slot rather than keeping a dead RISCVV scalar forwarder.
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.ExtractI64x4 := @RISCVVExtractI64x4;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.InsertI64x4 := @RISCVVInsertI64x4;
  {$ENDIF}

  // I64x8 Operations
  // Same boundary as I64x4: Add/Sub are backend-owned, while Mul/Min/Max are
  // intentionally absent from the current dispatch contract.
  table.CoreVectors.AddI64x8 := @RISCVVAddI64x8;
  table.CoreVectors.SubI64x8 := @RISCVVSubI64x8;
  table.CoreVectors.AndI64x8 := @RISCVVAndI64x8;
  table.CoreVectors.OrI64x8 := @RISCVVOrI64x8;
  table.CoreVectors.XorI64x8 := @RISCVVXorI64x8;
  table.CoreVectors.NotI64x8 := @RISCVVNotI64x8;
  table.CoreVectors.CmpEqI64x8 := @RISCVVCmpEqI64x8;
  table.CoreVectors.CmpLtI64x8 := @RISCVVCmpLtI64x8;
  table.CoreVectors.CmpLeI64x8 := @RISCVVCmpLeI64x8;
  table.CoreVectors.CmpGtI64x8 := @RISCVVCmpGtI64x8;
  table.CoreVectors.CmpGeI64x8 := @RISCVVCmpGeI64x8;
  table.CoreVectors.CmpNeI64x8 := @RISCVVCmpNeI64x8;

  // Keep base scalar wiring for non-asm Extract* helpers that would otherwise
  // degrade into dead RISCVV-specific scalar forwarders.

  // I32x4/I32x8/I32x16 Extract/Insert
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.ExtractI32x4 := @RISCVVExtractI32x4;
  table.CoreVectors.InsertI32x4 := @RISCVVInsertI32x4;
  table.CoreVectors.ExtractI32x8 := @RISCVVExtractI32x8;
  table.CoreVectors.InsertI32x8 := @RISCVVInsertI32x8;
  table.CoreVectors.ExtractI32x16 := @RISCVVExtractI32x16;
  table.CoreVectors.InsertI32x16 := @RISCVVInsertI32x16;
  table.CoreVectors.ExtractI64x2 := @RISCVVExtractI64x2;
  table.CoreVectors.InsertI64x2 := @RISCVVInsertI64x2;
  {$ENDIF}

  // Narrow Integer Types: I16x8
  table.CoreVectors.AddI16x8 := @RISCVVAddI16x8;
  table.CoreVectors.SubI16x8 := @RISCVVSubI16x8;
  table.CoreVectors.MulI16x8 := @RISCVVMulI16x8;
  table.CoreVectors.AndI16x8 := @RISCVVAndI16x8;
  table.CoreVectors.OrI16x8 := @RISCVVOrI16x8;
  table.CoreVectors.XorI16x8 := @RISCVVXorI16x8;
  table.CoreVectors.NotI16x8 := @RISCVVNotI16x8;
  table.CoreVectors.AndNotI16x8 := @RISCVVAndNotI16x8;
  table.CoreVectors.ShiftLeftI16x8 := @RISCVVShiftLeftI16x8;
  table.CoreVectors.ShiftRightI16x8 := @RISCVVShiftRightI16x8;
  table.CoreVectors.ShiftRightArithI16x8 := @RISCVVShiftRightArithI16x8;
  table.CoreVectors.CmpEqI16x8 := @RISCVVCmpEqI16x8;
  table.CoreVectors.CmpLtI16x8 := @RISCVVCmpLtI16x8;
  table.CoreVectors.CmpLeI16x8 := @RISCVVCmpLeI16x8;
  table.CoreVectors.CmpGtI16x8 := @RISCVVCmpGtI16x8;
  table.CoreVectors.CmpGeI16x8 := @RISCVVCmpGeI16x8;
  table.CoreVectors.CmpNeI16x8 := @RISCVVCmpNeI16x8;
  table.CoreVectors.MinI16x8 := @RISCVVMinI16x8;
  table.CoreVectors.MaxI16x8 := @RISCVVMaxI16x8;

  // Narrow Integer Types: I8x16
  table.CoreVectors.AddI8x16 := @RISCVVAddI8x16;
  table.CoreVectors.SubI8x16 := @RISCVVSubI8x16;
  table.CoreVectors.AndI8x16 := @RISCVVAndI8x16;
  table.CoreVectors.OrI8x16 := @RISCVVOrI8x16;
  table.CoreVectors.XorI8x16 := @RISCVVXorI8x16;
  table.CoreVectors.NotI8x16 := @RISCVVNotI8x16;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AndNotI8x16 := @RISCVVAndNotI8x16;
  {$ENDIF}
  table.CoreVectors.CmpEqI8x16 := @RISCVVCmpEqI8x16;
  table.CoreVectors.CmpLtI8x16 := @RISCVVCmpLtI8x16;
  table.CoreVectors.CmpLeI8x16 := @RISCVVCmpLeI8x16;
  table.CoreVectors.CmpGtI8x16 := @RISCVVCmpGtI8x16;
  table.CoreVectors.CmpGeI8x16 := @RISCVVCmpGeI8x16;
  table.CoreVectors.CmpNeI8x16 := @RISCVVCmpNeI8x16;
  table.CoreVectors.MinI8x16 := @RISCVVMinI8x16;
  table.CoreVectors.MaxI8x16 := @RISCVVMaxI8x16;

  // Unsigned Integer Types: U32x4
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AddU32x4 := @RISCVVAddU32x4;
  table.CoreVectors.SubU32x4 := @RISCVVSubU32x4;
  table.CoreVectors.MulU32x4 := @RISCVVMulU32x4;
  table.CoreVectors.AndU32x4 := @RISCVVAndU32x4;
  table.CoreVectors.OrU32x4 := @RISCVVOrU32x4;
  table.CoreVectors.XorU32x4 := @RISCVVXorU32x4;
  table.CoreVectors.NotU32x4 := @RISCVVNotU32x4;
  {$ENDIF}
  table.CoreVectors.AndNotU32x4 := @RISCVVAndNotU32x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.ShiftLeftU32x4 := @RISCVVShiftLeftU32x4;
  table.CoreVectors.ShiftRightU32x4 := @RISCVVShiftRightU32x4;
  {$ENDIF}
  table.CoreVectors.CmpEqU32x4 := @RISCVVCmpEqU32x4;
  table.CoreVectors.CmpLtU32x4 := @RISCVVCmpLtU32x4;
  table.CoreVectors.CmpLeU32x4 := @RISCVVCmpLeU32x4;
  table.CoreVectors.CmpGtU32x4 := @RISCVVCmpGtU32x4;
  table.CoreVectors.CmpGeU32x4 := @RISCVVCmpGeU32x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.MinU32x4 := @RISCVVMinU32x4;
  table.CoreVectors.MaxU32x4 := @RISCVVMaxU32x4;
  {$ENDIF}

  // Unsigned Integer Types: U64x4
  table.CoreVectors.AddU64x4 := @RISCVVAddU64x4;
  table.CoreVectors.SubU64x4 := @RISCVVSubU64x4;
  table.CoreVectors.AndU64x4 := @RISCVVAndU64x4;
  table.CoreVectors.OrU64x4 := @RISCVVOrU64x4;
  table.CoreVectors.XorU64x4 := @RISCVVXorU64x4;
  table.CoreVectors.NotU64x4 := @RISCVVNotU64x4;
  table.CoreVectors.ShiftLeftU64x4 := @RISCVVShiftLeftU64x4;
  table.CoreVectors.ShiftRightU64x4 := @RISCVVShiftRightU64x4;
  table.CoreVectors.CmpEqU64x4 := @RISCVVCmpEqU64x4;
  table.CoreVectors.CmpLtU64x4 := @RISCVVCmpLtU64x4;
  table.CoreVectors.CmpLeU64x4 := @RISCVVCmpLeU64x4;
  table.CoreVectors.CmpGtU64x4 := @RISCVVCmpGtU64x4;
  table.CoreVectors.CmpGeU64x4 := @RISCVVCmpGeU64x4;
  table.CoreVectors.CmpNeU64x4 := @RISCVVCmpNeU64x4;

  // Unsigned Integer Types: U32x8 (256-bit)
  // Keep one assignment site for both modes:
  // - asm-enabled builds resolve these symbols to native RVV implementations
  // - no-asm builds resolve the same symbols to explicit scalar-passthrough
  //   facades, so the published shift semantics stay identical without a
  //   second register-only branch
  // Neighboring U32x16/U64x8 families intentionally fall through to
  // FillBaseDispatchTable instead.
  table.CoreVectors.AddU32x8 := @RISCVVAddU32x8;
  table.CoreVectors.SubU32x8 := @RISCVVSubU32x8;
  table.CoreVectors.MulU32x8 := @RISCVVMulU32x8;
  table.CoreVectors.AndU32x8 := @RISCVVAndU32x8;
  table.CoreVectors.OrU32x8 := @RISCVVOrU32x8;
  table.CoreVectors.XorU32x8 := @RISCVVXorU32x8;
  table.CoreVectors.NotU32x8 := @RISCVVNotU32x8;
  table.CoreVectors.AndNotU32x8 := @RISCVVAndNotU32x8;
  table.CoreVectors.ShiftLeftU32x8 := @RISCVVShiftLeftU32x8;
  table.CoreVectors.ShiftRightU32x8 := @RISCVVShiftRightU32x8;
  table.CoreVectors.CmpEqU32x8 := @RISCVVCmpEqU32x8;
  table.CoreVectors.CmpLtU32x8 := @RISCVVCmpLtU32x8;
  table.CoreVectors.CmpLeU32x8 := @RISCVVCmpLeU32x8;
  table.CoreVectors.CmpGtU32x8 := @RISCVVCmpGtU32x8;
  table.CoreVectors.CmpGeU32x8 := @RISCVVCmpGeU32x8;
  table.CoreVectors.CmpNeU32x8 := @RISCVVCmpNeU32x8;
  table.CoreVectors.MinU32x8 := @RISCVVMinU32x8;
  table.CoreVectors.MaxU32x8 := @RISCVVMaxU32x8;

  // F64x4 Reciprocal
  table.CoreVectors.RcpF64x4 := @RISCVVRcpF64x4;

  // Unsigned Integer Types: U16x8
  table.CoreVectors.AddU16x8 := @RISCVVAddU16x8;
  table.CoreVectors.SubU16x8 := @RISCVVSubU16x8;
  table.CoreVectors.MulU16x8 := @RISCVVMulU16x8;
  table.CoreVectors.AndU16x8 := @RISCVVAndU16x8;
  table.CoreVectors.OrU16x8 := @RISCVVOrU16x8;
  table.CoreVectors.XorU16x8 := @RISCVVXorU16x8;
  table.CoreVectors.NotU16x8 := @RISCVVNotU16x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AndNotU16x8 := @RISCVVAndNotU16x8;
  {$ENDIF}
  table.CoreVectors.ShiftLeftU16x8 := @RISCVVShiftLeftU16x8;
  table.CoreVectors.ShiftRightU16x8 := @RISCVVShiftRightU16x8;
  table.CoreVectors.CmpEqU16x8 := @RISCVVCmpEqU16x8;
  table.CoreVectors.CmpLtU16x8 := @RISCVVCmpLtU16x8;
  table.CoreVectors.CmpLeU16x8 := @RISCVVCmpLeU16x8;
  table.CoreVectors.CmpGtU16x8 := @RISCVVCmpGtU16x8;
  table.CoreVectors.CmpGeU16x8 := @RISCVVCmpGeU16x8;
  table.CoreVectors.CmpNeU16x8 := @RISCVVCmpNeU16x8;
  table.CoreVectors.MinU16x8 := @RISCVVMinU16x8;
  table.CoreVectors.MaxU16x8 := @RISCVVMaxU16x8;

  // Unsigned Integer Types: U8x16
  table.CoreVectors.AddU8x16 := @RISCVVAddU8x16;
  table.CoreVectors.SubU8x16 := @RISCVVSubU8x16;
  table.CoreVectors.AndU8x16 := @RISCVVAndU8x16;
  table.CoreVectors.OrU8x16 := @RISCVVOrU8x16;
  table.CoreVectors.XorU8x16 := @RISCVVXorU8x16;
  table.CoreVectors.NotU8x16 := @RISCVVNotU8x16;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CoreVectors.AndNotU8x16 := @RISCVVAndNotU8x16;
  {$ENDIF}
  table.CoreVectors.CmpEqU8x16 := @RISCVVCmpEqU8x16;
  table.CoreVectors.CmpLtU8x16 := @RISCVVCmpLtU8x16;
  table.CoreVectors.CmpLeU8x16 := @RISCVVCmpLeU8x16;
  table.CoreVectors.CmpGtU8x16 := @RISCVVCmpGtU8x16;
  table.CoreVectors.CmpGeU8x16 := @RISCVVCmpGeU8x16;
  table.CoreVectors.CmpNeU8x16 := @RISCVVCmpNeU8x16;
  table.CoreVectors.MinU8x16 := @RISCVVMinU8x16;
  table.CoreVectors.MaxU8x16 := @RISCVVMaxU8x16;

  // Saturating Arithmetic
  table.CoreVectors.I8x16SatAdd := @RISCVVSatAddI8x16;
  table.CoreVectors.I8x16SatSub := @RISCVVSatSubI8x16;
  table.CoreVectors.I16x8SatAdd := @RISCVVSatAddI16x8;
  table.CoreVectors.I16x8SatSub := @RISCVVSatSubI16x8;
  table.CoreVectors.U8x16SatAdd := @RISCVVSatAddU8x16;
  table.CoreVectors.U8x16SatSub := @RISCVVSatSubU8x16;
  table.CoreVectors.U16x8SatAdd := @RISCVVSatAddU16x8;
  table.CoreVectors.U16x8SatSub := @RISCVVSatSubU16x8;

  // === Facade Functions ===
  // Keep scalar-pass-through facade helpers on the base scalar slots.
  // Backend-local wrappers add no runtime value and hide the actual slot ownership.

  // === Memory / Batch honesty (Phase 24a / S24a) ===
  // Intentionally leave table.Memory and table.BatchF32/F64/Integer on the
  // FillBaseDispatchTable scalar baseline. Do not bind Mem*_RISCVV or
  // RISCVVArray* dead wrappers. Real RVV Memory/Batch leaves require S24b
  // (hardware or approved QEMU evidence). Source+runtime contracts lock this
  // in Test_RISCVV_MemoryBatch_Intentionally_Scalar_Until_RealLeaf.

  // Register the backend
  RegisterBackend(sbRISCVV, table);
end;

// =============================================================
// Initialization
// =============================================================
// Auto-register on RISC-V platforms with V extension

initialization
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  // Test-only opt-in path: allow non-native hosts to register RVV scalar/common
  // implementations so DispatchAPI/PublicAbi suites can verify metadata contracts.
  // Delayed to the test runner so list-only startup paths do not need to
  // execute non-native backend registration during unit initialization.
  {$ELSE}
  {$IFDEF CPURISCV64}
  // On RISC-V 64-bit, attempt to register
  // In practice, runtime detection of V extension would be needed
  RegisterRISCVVBackend;
  // Keep the registry in sync when VectorAsmEnabled changes.
  RegisterBackendRebuilder(sbRISCVV, @RegisterRISCVVBackend);
  {$ENDIF}
  {$IFDEF CPURISCV32}
  RegisterRISCVVBackend;
  // Keep the registry in sync when VectorAsmEnabled changes.
  RegisterBackendRebuilder(sbRISCVV, @RegisterRISCVVBackend);
  {$ENDIF}
  {$ENDIF}
