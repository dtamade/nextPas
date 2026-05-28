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
  table.BackendInfo.Description := 'RISC-V Vector Extension (RVV)';
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
  table.AddF32x4 := @RISCVVAddF32x4;
  table.SubF32x4 := @RISCVVSubF32x4;
  table.MulF32x4 := @RISCVVMulF32x4;
  table.DivF32x4 := @RISCVVDivF32x4;

  // F32x4 Math
  table.AbsF32x4 := @RISCVVAbsF32x4;
  table.SqrtF32x4 := @RISCVVSqrtF32x4;
  table.MinF32x4 := @RISCVVMinF32x4;
  table.MaxF32x4 := @RISCVVMaxF32x4;
  table.FmaF32x4 := @RISCVVFmaF32x4;
  table.RcpF32x4 := @RISCVVRcpF32x4;
  table.RsqrtF32x4 := @RISCVVRsqrtF32x4;
  table.ClampF32x4 := @RISCVVClampF32x4;
  {$ENDIF}
  // Keep 128-bit IEEE-sensitive rounding on the canonical base scalar slots
  // until the RISCVV-specific semantics are validated end-to-end.

  // F32x4 Vector Math
  table.DotF32x4 := @RISCVVDotF32x4;
  table.DotF32x3 := @RISCVVDotF32x3;
  {$IFDEF RISCVV_ASSEMBLY}
  table.CrossF32x3 := @RISCVVCrossF32x3;
  {$ENDIF}
  table.LengthF32x4 := @RISCVVLengthF32x4;
  table.LengthF32x3 := @RISCVVLengthF32x3;
  {$IFDEF RISCVV_ASSEMBLY}
  table.NormalizeF32x4 := @RISCVVNormalizeF32x4;
  table.NormalizeF32x3 := @RISCVVNormalizeF32x3;
  {$ENDIF}

  // F32x4 Reduction
  table.ReduceAddF32x4 := @RISCVVReduceAddF32x4;
  table.ReduceMinF32x4 := @RISCVVReduceMinF32x4;
  table.ReduceMaxF32x4 := @RISCVVReduceMaxF32x4;
  table.ReduceMulF32x4 := @RISCVVReduceMulF32x4;

  // F32x4 Comparison
  table.CmpEqF32x4 := @RISCVVCmpEqF32x4;
  table.CmpLtF32x4 := @RISCVVCmpLtF32x4;
  table.CmpLeF32x4 := @RISCVVCmpLeF32x4;
  table.CmpGtF32x4 := @RISCVVCmpGtF32x4;
  table.CmpGeF32x4 := @RISCVVCmpGeF32x4;
  table.CmpNeF32x4 := @RISCVVCmpNeF32x4;

  // F32x4 Memory
  {$IFDEF RISCVV_ASSEMBLY}
  table.LoadF32x4 := @RISCVVLoadF32x4;
  table.LoadF32x4Aligned := @RISCVVLoadF32x4Aligned;
  {$ENDIF}
  table.StoreF32x4 := @RISCVVStoreF32x4;
  table.StoreF32x4Aligned := @RISCVVStoreF32x4Aligned;

  // F32x4 Utility
  {$IFDEF RISCVV_ASSEMBLY}
  table.SplatF32x4 := @RISCVVSplatF32x4;
  table.ZeroF32x4 := @RISCVVZeroF32x4;
  table.SelectF32x4 := @RISCVVSelectF32x4;
  table.ExtractF32x4 := @RISCVVExtractF32x4;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.InsertF32x4 := @RISCVVInsertF32x4;
  {$ENDIF}

  // === F64x2 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.AddF64x2 := @RISCVVAddF64x2;
  table.SubF64x2 := @RISCVVSubF64x2;
  table.MulF64x2 := @RISCVVMulF64x2;
  table.DivF64x2 := @RISCVVDivF64x2;
  {$ENDIF}

  // === I32x4 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.AddI32x4 := @RISCVVAddI32x4;
  table.SubI32x4 := @RISCVVSubI32x4;
  table.MulI32x4 := @RISCVVMulI32x4;

  // I32x4 Bitwise
  table.AndI32x4 := @RISCVVAndI32x4;
  table.OrI32x4 := @RISCVVOrI32x4;
  table.XorI32x4 := @RISCVVXorI32x4;
  table.NotI32x4 := @RISCVVNotI32x4;
  table.AndNotI32x4 := @RISCVVAndNotI32x4;

  // I32x4 Shift
  table.ShiftLeftI32x4 := @RISCVVShiftLeftI32x4;
  table.ShiftRightI32x4 := @RISCVVShiftRightI32x4;
  table.ShiftRightArithI32x4 := @RISCVVShiftRightArithI32x4;
  {$ENDIF}

  // I32x4 Comparison
  {$IFDEF RISCVV_ASSEMBLY}
  table.CmpEqI32x4 := @RISCVVCmpEqI32x4;
  table.CmpLtI32x4 := @RISCVVCmpLtI32x4;
  table.CmpGtI32x4 := @RISCVVCmpGtI32x4;
  table.CmpLeI32x4 := @RISCVVCmpLeI32x4;
  table.CmpGeI32x4 := @RISCVVCmpGeI32x4;
  table.CmpNeI32x4 := @RISCVVCmpNeI32x4;
  {$ENDIF}

  // I32x4 Min/Max
  {$IFDEF RISCVV_ASSEMBLY}
  table.MinI32x4 := @RISCVVMinI32x4;
  table.MaxI32x4 := @RISCVVMaxI32x4;
  {$ENDIF}

  // === I64x2 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.AddI64x2 := @RISCVVAddI64x2;
  table.SubI64x2 := @RISCVVSubI64x2;
  table.AndI64x2 := @RISCVVAndI64x2;
  table.OrI64x2 := @RISCVVOrI64x2;
  table.XorI64x2 := @RISCVVXorI64x2;
  table.NotI64x2 := @RISCVVNotI64x2;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.ShiftLeftI64x2 := @RISCVVShiftLeftI64x2;
  table.ShiftRightI64x2 := @RISCVVShiftRightI64x2;
  table.ShiftRightArithI64x2 := @RISCVVShiftRightArithI64x2;
  {$ENDIF}

  // === U64x2 Operations ===
  {$IFDEF RISCVV_ASSEMBLY}
  table.AddU64x2 := @RISCVVAddU64x2;
  table.SubU64x2 := @RISCVVSubU64x2;
  table.AndU64x2 := @RISCVVAndU64x2;
  table.OrU64x2 := @RISCVVOrU64x2;
  table.XorU64x2 := @RISCVVXorU64x2;
  table.NotU64x2 := @RISCVVNotU64x2;
  {$ENDIF}
  // === F32x8 Operations ===
  table.AddF32x8 := @RISCVVAddF32x8;
  table.SubF32x8 := @RISCVVSubF32x8;
  table.MulF32x8 := @RISCVVMulF32x8;
  table.DivF32x8 := @RISCVVDivF32x8;

  // F32x8 Comparison
  table.CmpEqF32x8 := @RISCVVCmpEqF32x8;
  table.CmpLtF32x8 := @RISCVVCmpLtF32x8;
  table.CmpLeF32x8 := @RISCVVCmpLeF32x8;
  table.CmpGtF32x8 := @RISCVVCmpGtF32x8;
  table.CmpGeF32x8 := @RISCVVCmpGeF32x8;
  table.CmpNeF32x8 := @RISCVVCmpNeF32x8;

  // === F64x4 Operations ===
  table.AddF64x4 := @RISCVVAddF64x4;
  table.SubF64x4 := @RISCVVSubF64x4;
  table.MulF64x4 := @RISCVVMulF64x4;
  table.DivF64x4 := @RISCVVDivF64x4;

  // F64x4 Comparison
  table.CmpEqF64x4 := @RISCVVCmpEqF64x4;
  table.CmpLtF64x4 := @RISCVVCmpLtF64x4;
  table.CmpLeF64x4 := @RISCVVCmpLeF64x4;
  table.CmpGtF64x4 := @RISCVVCmpGtF64x4;
  table.CmpGeF64x4 := @RISCVVCmpGeF64x4;
  table.CmpNeF64x4 := @RISCVVCmpNeF64x4;

  // === I32x8 Operations ===
  // Keep these wide integer key slots bound to RISCVV symbols. Non-asm builds
  // still resolve through riscvv.facade.inc, so silently remapping them to
  // base scalar would make the published backend-ownership contract false.
  table.AddI32x8 := @RISCVVAddI32x8;
  table.SubI32x8 := @RISCVVSubI32x8;
  table.MulI32x8 := @RISCVVMulI32x8;
  table.AndI32x8 := @RISCVVAndI32x8;
  table.OrI32x8 := @RISCVVOrI32x8;
  table.XorI32x8 := @RISCVVXorI32x8;
  table.NotI32x8 := @RISCVVNotI32x8;
  table.AndNotI32x8 := @RISCVVAndNotI32x8;
  table.ShiftLeftI32x8 := @RISCVVShiftLeftI32x8;
  table.ShiftRightI32x8 := @RISCVVShiftRightI32x8;
  table.ShiftRightArithI32x8 := @RISCVVShiftRightArithI32x8;
  table.CmpEqI32x8 := @RISCVVCmpEqI32x8;
  table.CmpLtI32x8 := @RISCVVCmpLtI32x8;
  table.CmpGtI32x8 := @RISCVVCmpGtI32x8;
  table.CmpLeI32x8 := @RISCVVCmpLeI32x8;
  table.CmpGeI32x8 := @RISCVVCmpGeI32x8;
  table.CmpNeI32x8 := @RISCVVCmpNeI32x8;
  table.MinI32x8 := @RISCVVMinI32x8;
  table.MaxI32x8 := @RISCVVMaxI32x8;

  // === I32x16 Operations ===
  table.AddI32x16 := @RISCVVAddI32x16;
  table.SubI32x16 := @RISCVVSubI32x16;
  table.MulI32x16 := @RISCVVMulI32x16;
  table.AndI32x16 := @RISCVVAndI32x16;
  table.OrI32x16 := @RISCVVOrI32x16;
  table.XorI32x16 := @RISCVVXorI32x16;
  table.NotI32x16 := @RISCVVNotI32x16;
  table.AndNotI32x16 := @RISCVVAndNotI32x16;
  table.ShiftLeftI32x16 := @RISCVVShiftLeftI32x16;
  table.ShiftRightI32x16 := @RISCVVShiftRightI32x16;
  table.ShiftRightArithI32x16 := @RISCVVShiftRightArithI32x16;
  table.CmpEqI32x16 := @RISCVVCmpEqI32x16;
  table.CmpLtI32x16 := @RISCVVCmpLtI32x16;
  table.CmpGtI32x16 := @RISCVVCmpGtI32x16;
  table.CmpLeI32x16 := @RISCVVCmpLeI32x16;
  table.CmpGeI32x16 := @RISCVVCmpGeI32x16;
  table.CmpNeI32x16 := @RISCVVCmpNeI32x16;
  table.MinI32x16 := @RISCVVMinI32x16;
  table.MaxI32x16 := @RISCVVMaxI32x16;

  // === F32x16 Operations (512-bit, 16x Single) ===
  table.AddF32x16 := @RISCVVAddF32x16;
  table.SubF32x16 := @RISCVVSubF32x16;
  table.MulF32x16 := @RISCVVMulF32x16;
  table.DivF32x16 := @RISCVVDivF32x16;

  // F32x16 Comparison
  table.CmpEqF32x16 := @RISCVVCmpEqF32x16;
  table.CmpLtF32x16 := @RISCVVCmpLtF32x16;
  table.CmpLeF32x16 := @RISCVVCmpLeF32x16;
  table.CmpGtF32x16 := @RISCVVCmpGtF32x16;
  table.CmpGeF32x16 := @RISCVVCmpGeF32x16;
  table.CmpNeF32x16 := @RISCVVCmpNeF32x16;
  table.SelectF32x16 := @RISCVVSelectF32x16;

  // === F64x8 Operations (512-bit, 8x Double) ===
  table.AddF64x8 := @RISCVVAddF64x8;
  table.SubF64x8 := @RISCVVSubF64x8;
  table.MulF64x8 := @RISCVVMulF64x8;
  table.DivF64x8 := @RISCVVDivF64x8;

  // F64x8 Comparison
  table.CmpEqF64x8 := @RISCVVCmpEqF64x8;
  table.CmpLtF64x8 := @RISCVVCmpLtF64x8;
  table.CmpLeF64x8 := @RISCVVCmpLeF64x8;
  table.CmpGtF64x8 := @RISCVVCmpGtF64x8;
  table.CmpGeF64x8 := @RISCVVCmpGeF64x8;
  table.CmpNeF64x8 := @RISCVVCmpNeF64x8;
  table.SelectF64x8 := @RISCVVSelectF64x8;

  // === Mask Operations ===
  // TMask4 Operations
  table.Mask4All := @RISCVVMask4All;
  table.Mask4Any := @RISCVVMask4Any;
  table.Mask4None := @RISCVVMask4None;
  table.Mask4PopCount := @RISCVVMask4PopCount;
  table.Mask4FirstSet := @RISCVVMask4FirstSet;

  // TMask8 Operations
  table.Mask8All := @RISCVVMask8All;
  table.Mask8Any := @RISCVVMask8Any;
  table.Mask8None := @RISCVVMask8None;
  table.Mask8PopCount := @RISCVVMask8PopCount;
  table.Mask8FirstSet := @RISCVVMask8FirstSet;

  // TMask16 Operations
  table.Mask16All := @RISCVVMask16All;
  table.Mask16Any := @RISCVVMask16Any;
  table.Mask16None := @RISCVVMask16None;
  table.Mask16PopCount := @RISCVVMask16PopCount;
  table.Mask16FirstSet := @RISCVVMask16FirstSet;

  // =============================================================
  // Additional Operations Registration (100% Coverage)
  // =============================================================

  // TMask2 Operations
  table.Mask2All := @RISCVVMask2All;
  table.Mask2Any := @RISCVVMask2Any;
  table.Mask2None := @RISCVVMask2None;
  table.Mask2PopCount := @RISCVVMask2PopCount;
  table.Mask2FirstSet := @RISCVVMask2FirstSet;

  // Wide Float Operations (Abs, Sqrt, Min, Max, Clamp)
  table.AbsF32x16 := @RISCVVAbsF32x16;
  table.AbsF32x8 := @RISCVVAbsF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.AbsF64x2 := @RISCVVAbsF64x2;
  {$ENDIF}
  table.AbsF64x4 := @RISCVVAbsF64x4;
  table.AbsF64x8 := @RISCVVAbsF64x8;
  table.SqrtF32x16 := @RISCVVSqrtF32x16;
  table.SqrtF32x8 := @RISCVVSqrtF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.SqrtF64x2 := @RISCVVSqrtF64x2;
  {$ENDIF}
  table.SqrtF64x4 := @RISCVVSqrtF64x4;
  table.SqrtF64x8 := @RISCVVSqrtF64x8;
  table.MinF32x16 := @RISCVVMinF32x16;
  table.MinF32x8 := @RISCVVMinF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.MinF64x2 := @RISCVVMinF64x2;
  {$ENDIF}
  table.MinF64x4 := @RISCVVMinF64x4;
  table.MinF64x8 := @RISCVVMinF64x8;
  table.MaxF32x16 := @RISCVVMaxF32x16;
  table.MaxF32x8 := @RISCVVMaxF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.MaxF64x2 := @RISCVVMaxF64x2;
  {$ENDIF}
  table.MaxF64x4 := @RISCVVMaxF64x4;
  table.MaxF64x8 := @RISCVVMaxF64x8;
  // Keep wide F32 Clamp on the canonical base scalar slots until RVV-specific
  // semantics are validated end-to-end.
  {$IFDEF RISCVV_ASSEMBLY}
  table.ClampF64x2 := @RISCVVClampF64x2;
  {$ENDIF}
  table.ClampF64x4 := @RISCVVClampF64x4;
  table.ClampF64x8 := @RISCVVClampF64x8;

  // Keep wide Floor/Ceil/Round/Trunc on the canonical base scalar slots until
  // RISCVV-specific semantics are implemented and validated end-to-end. F64
  // Clamp remains backend-owned because its local NaN/signed-zero fallback is
  // still intentional.
  table.FmaF32x16 := @RISCVVFmaF32x16;
  table.FmaF32x8 := @RISCVVFmaF32x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.FmaF64x2 := @RISCVVFmaF64x2;
  {$ENDIF}
  table.FmaF64x4 := @RISCVVFmaF64x4;
  table.FmaF64x8 := @RISCVVFmaF64x8;

  // Wide Float Reduction
  table.ReduceAddF32x16 := @RISCVVReduceAddF32x16;
  table.ReduceAddF32x8 := @RISCVVReduceAddF32x8;
  table.ReduceAddF64x2 := @RISCVVReduceAddF64x2;
  table.ReduceAddF64x4 := @RISCVVReduceAddF64x4;
  table.ReduceAddF64x8 := @RISCVVReduceAddF64x8;
  table.ReduceMaxF32x16 := @RISCVVReduceMaxF32x16;
  table.ReduceMaxF32x8 := @RISCVVReduceMaxF32x8;
  table.ReduceMaxF64x2 := @RISCVVReduceMaxF64x2;
  table.ReduceMaxF64x4 := @RISCVVReduceMaxF64x4;
  table.ReduceMaxF64x8 := @RISCVVReduceMaxF64x8;
  table.ReduceMinF32x16 := @RISCVVReduceMinF32x16;
  table.ReduceMinF32x8 := @RISCVVReduceMinF32x8;
  table.ReduceMinF64x2 := @RISCVVReduceMinF64x2;
  table.ReduceMinF64x4 := @RISCVVReduceMinF64x4;
  table.ReduceMinF64x8 := @RISCVVReduceMinF64x8;
  table.ReduceMulF32x16 := @RISCVVReduceMulF32x16;
  table.ReduceMulF32x8 := @RISCVVReduceMulF32x8;
  table.ReduceMulF64x2 := @RISCVVReduceMulF64x2;
  table.ReduceMulF64x4 := @RISCVVReduceMulF64x4;
  table.ReduceMulF64x8 := @RISCVVReduceMulF64x8;

  // F64x2 Comparison
  table.CmpEqF64x2 := @RISCVVCmpEqF64x2;
  table.CmpLtF64x2 := @RISCVVCmpLtF64x2;
  table.CmpLeF64x2 := @RISCVVCmpLeF64x2;
  table.CmpGtF64x2 := @RISCVVCmpGtF64x2;
  table.CmpGeF64x2 := @RISCVVCmpGeF64x2;
  table.CmpNeF64x2 := @RISCVVCmpNeF64x2;

  // Wide Float Memory/Utility
  {$IFDEF RISCVV_ASSEMBLY}
  table.LoadF32x16 := @RISCVVLoadF32x16;
  table.LoadF32x8 := @RISCVVLoadF32x8;
  table.LoadF64x2 := @RISCVVLoadF64x2;
  table.LoadF64x4 := @RISCVVLoadF64x4;
  table.LoadF64x8 := @RISCVVLoadF64x8;
  {$ENDIF}
  table.StoreF32x16 := @RISCVVStoreF32x16;
  table.StoreF32x8 := @RISCVVStoreF32x8;
  table.StoreF64x2 := @RISCVVStoreF64x2;
  table.StoreF64x4 := @RISCVVStoreF64x4;
  table.StoreF64x8 := @RISCVVStoreF64x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.SplatF32x16 := @RISCVVSplatF32x16;
  table.SplatF32x8 := @RISCVVSplatF32x8;
  table.SplatF64x2 := @RISCVVSplatF64x2;
  table.SplatF64x4 := @RISCVVSplatF64x4;
  table.SplatF64x8 := @RISCVVSplatF64x8;
  table.ZeroF32x16 := @RISCVVZeroF32x16;
  table.ZeroF32x8 := @RISCVVZeroF32x8;
  table.ZeroF64x2 := @RISCVVZeroF64x2;
  table.ZeroF64x4 := @RISCVVZeroF64x4;
  table.ZeroF64x8 := @RISCVVZeroF64x8;
  {$ENDIF}

  // Wide Float Extract/Insert
  // Keep Extract* genuinely asm-gated. On no-asm hosts these slots should
  // continue to reuse the FillBaseDispatchTable scalar truth instead of
  // publishing dead RISCVV-specific scalar forwarders.
  {$IFDEF RISCVV_ASSEMBLY}
  table.ExtractF32x16 := @RISCVVExtractF32x16;
  table.ExtractF32x8 := @RISCVVExtractF32x8;
  table.ExtractF64x2 := @RISCVVExtractF64x2;
  table.ExtractF64x4 := @RISCVVExtractF64x4;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.InsertF32x16 := @RISCVVInsertF32x16;
  table.InsertF32x8 := @RISCVVInsertF32x8;
  table.InsertF64x2 := @RISCVVInsertF64x2;
  table.InsertF64x4 := @RISCVVInsertF64x4;
  {$ENDIF}

  // Wide Float Select
  {$IFDEF RISCVV_ASSEMBLY}
  // Keep the 128-bit representative shuffle leaf on RISCVV. The wider
  // SelectF32x8/F64x4/I32x4 variants do not currently provide distinct
  // non-scalar semantics, so they continue to reuse the seeded base scalar
  // slots until real RVV-specific implementations exist.
  table.SelectF64x2 := @RISCVVSelectF64x2;
  table.CmpEqI64x2 := @RISCVVCmpEqI64x2;
  table.CmpLtI64x2 := @RISCVVCmpLtI64x2;
  table.CmpLeI64x2 := @RISCVVCmpLeI64x2;
  table.CmpGtI64x2 := @RISCVVCmpGtI64x2;
  table.CmpGeI64x2 := @RISCVVCmpGeI64x2;
  table.CmpNeI64x2 := @RISCVVCmpNeI64x2;
  {$ENDIF}

  // I64x4 Operations
  // Only Add/Sub are backend-owned in this family today. Mul/Min/Max are not
  // open dispatch slots yet, so do not "complete" the family here.
  table.AddI64x4 := @RISCVVAddI64x4;
  table.SubI64x4 := @RISCVVSubI64x4;
  table.AndI64x4 := @RISCVVAndI64x4;
  table.OrI64x4 := @RISCVVOrI64x4;
  table.XorI64x4 := @RISCVVXorI64x4;
  table.NotI64x4 := @RISCVVNotI64x4;
  table.AndNotI64x4 := @RISCVVAndNotI64x4;
  table.ShiftLeftI64x4 := @RISCVVShiftLeftI64x4;
  table.ShiftRightI64x4 := @RISCVVShiftRightI64x4;
  table.ShiftRightArithI64x4 := @RISCVVShiftRightArithI64x4;
  table.CmpEqI64x4 := @RISCVVCmpEqI64x4;
  table.CmpLtI64x4 := @RISCVVCmpLtI64x4;
  table.CmpLeI64x4 := @RISCVVCmpLeI64x4;
  table.CmpGtI64x4 := @RISCVVCmpGtI64x4;
  table.CmpGeI64x4 := @RISCVVCmpGeI64x4;
  table.CmpNeI64x4 := @RISCVVCmpNeI64x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.LoadI64x4 := @RISCVVLoadI64x4;
  {$ENDIF}
  table.StoreI64x4 := @RISCVVStoreI64x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.SplatI64x4 := @RISCVVSplatI64x4;
  table.ZeroI64x4 := @RISCVVZeroI64x4;
  {$ENDIF}
  // Keep ExtractI64x4 genuinely asm-gated. Non-asm hosts should reuse the
  // seeded base scalar slot rather than keeping a dead RISCVV scalar forwarder.
  {$IFDEF RISCVV_ASSEMBLY}
  table.ExtractI64x4 := @RISCVVExtractI64x4;
  {$ENDIF}
  {$IFDEF RISCVV_ASSEMBLY}
  table.InsertI64x4 := @RISCVVInsertI64x4;
  {$ENDIF}

  // I64x8 Operations
  // Same boundary as I64x4: Add/Sub are backend-owned, while Mul/Min/Max are
  // intentionally absent from the current dispatch contract.
  table.AddI64x8 := @RISCVVAddI64x8;
  table.SubI64x8 := @RISCVVSubI64x8;
  table.AndI64x8 := @RISCVVAndI64x8;
  table.OrI64x8 := @RISCVVOrI64x8;
  table.XorI64x8 := @RISCVVXorI64x8;
  table.NotI64x8 := @RISCVVNotI64x8;
  table.CmpEqI64x8 := @RISCVVCmpEqI64x8;
  table.CmpLtI64x8 := @RISCVVCmpLtI64x8;
  table.CmpLeI64x8 := @RISCVVCmpLeI64x8;
  table.CmpGtI64x8 := @RISCVVCmpGtI64x8;
  table.CmpGeI64x8 := @RISCVVCmpGeI64x8;
  table.CmpNeI64x8 := @RISCVVCmpNeI64x8;

  // Keep base scalar wiring for non-asm Extract* helpers that would otherwise
  // degrade into dead RISCVV-specific scalar forwarders.

  // I32x4/I32x8/I32x16 Extract/Insert
  {$IFDEF RISCVV_ASSEMBLY}
  table.ExtractI32x4 := @RISCVVExtractI32x4;
  table.InsertI32x4 := @RISCVVInsertI32x4;
  table.ExtractI32x8 := @RISCVVExtractI32x8;
  table.InsertI32x8 := @RISCVVInsertI32x8;
  table.ExtractI32x16 := @RISCVVExtractI32x16;
  table.InsertI32x16 := @RISCVVInsertI32x16;
  table.ExtractI64x2 := @RISCVVExtractI64x2;
  table.InsertI64x2 := @RISCVVInsertI64x2;
  {$ENDIF}

  // Narrow Integer Types: I16x8
  table.AddI16x8 := @RISCVVAddI16x8;
  table.SubI16x8 := @RISCVVSubI16x8;
  table.MulI16x8 := @RISCVVMulI16x8;
  table.AndI16x8 := @RISCVVAndI16x8;
  table.OrI16x8 := @RISCVVOrI16x8;
  table.XorI16x8 := @RISCVVXorI16x8;
  table.NotI16x8 := @RISCVVNotI16x8;
  table.AndNotI16x8 := @RISCVVAndNotI16x8;
  table.ShiftLeftI16x8 := @RISCVVShiftLeftI16x8;
  table.ShiftRightI16x8 := @RISCVVShiftRightI16x8;
  table.ShiftRightArithI16x8 := @RISCVVShiftRightArithI16x8;
  table.CmpEqI16x8 := @RISCVVCmpEqI16x8;
  table.CmpLtI16x8 := @RISCVVCmpLtI16x8;
  table.CmpLeI16x8 := @RISCVVCmpLeI16x8;
  table.CmpGtI16x8 := @RISCVVCmpGtI16x8;
  table.CmpGeI16x8 := @RISCVVCmpGeI16x8;
  table.CmpNeI16x8 := @RISCVVCmpNeI16x8;
  table.MinI16x8 := @RISCVVMinI16x8;
  table.MaxI16x8 := @RISCVVMaxI16x8;

  // Narrow Integer Types: I8x16
  table.AddI8x16 := @RISCVVAddI8x16;
  table.SubI8x16 := @RISCVVSubI8x16;
  table.AndI8x16 := @RISCVVAndI8x16;
  table.OrI8x16 := @RISCVVOrI8x16;
  table.XorI8x16 := @RISCVVXorI8x16;
  table.NotI8x16 := @RISCVVNotI8x16;
  {$IFDEF RISCVV_ASSEMBLY}
  table.AndNotI8x16 := @RISCVVAndNotI8x16;
  {$ENDIF}
  table.CmpEqI8x16 := @RISCVVCmpEqI8x16;
  table.CmpLtI8x16 := @RISCVVCmpLtI8x16;
  table.CmpLeI8x16 := @RISCVVCmpLeI8x16;
  table.CmpGtI8x16 := @RISCVVCmpGtI8x16;
  table.CmpGeI8x16 := @RISCVVCmpGeI8x16;
  table.CmpNeI8x16 := @RISCVVCmpNeI8x16;
  table.MinI8x16 := @RISCVVMinI8x16;
  table.MaxI8x16 := @RISCVVMaxI8x16;

  // Unsigned Integer Types: U32x4
  {$IFDEF RISCVV_ASSEMBLY}
  table.AddU32x4 := @RISCVVAddU32x4;
  table.SubU32x4 := @RISCVVSubU32x4;
  table.MulU32x4 := @RISCVVMulU32x4;
  table.AndU32x4 := @RISCVVAndU32x4;
  table.OrU32x4 := @RISCVVOrU32x4;
  table.XorU32x4 := @RISCVVXorU32x4;
  table.NotU32x4 := @RISCVVNotU32x4;
  {$ENDIF}
  table.AndNotU32x4 := @RISCVVAndNotU32x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.ShiftLeftU32x4 := @RISCVVShiftLeftU32x4;
  table.ShiftRightU32x4 := @RISCVVShiftRightU32x4;
  {$ENDIF}
  table.CmpEqU32x4 := @RISCVVCmpEqU32x4;
  table.CmpLtU32x4 := @RISCVVCmpLtU32x4;
  table.CmpLeU32x4 := @RISCVVCmpLeU32x4;
  table.CmpGtU32x4 := @RISCVVCmpGtU32x4;
  table.CmpGeU32x4 := @RISCVVCmpGeU32x4;
  {$IFDEF RISCVV_ASSEMBLY}
  table.MinU32x4 := @RISCVVMinU32x4;
  table.MaxU32x4 := @RISCVVMaxU32x4;
  {$ENDIF}

  // Unsigned Integer Types: U64x4
  table.AddU64x4 := @RISCVVAddU64x4;
  table.SubU64x4 := @RISCVVSubU64x4;
  table.AndU64x4 := @RISCVVAndU64x4;
  table.OrU64x4 := @RISCVVOrU64x4;
  table.XorU64x4 := @RISCVVXorU64x4;
  table.NotU64x4 := @RISCVVNotU64x4;
  table.ShiftLeftU64x4 := @RISCVVShiftLeftU64x4;
  table.ShiftRightU64x4 := @RISCVVShiftRightU64x4;
  table.CmpEqU64x4 := @RISCVVCmpEqU64x4;
  table.CmpLtU64x4 := @RISCVVCmpLtU64x4;
  table.CmpLeU64x4 := @RISCVVCmpLeU64x4;
  table.CmpGtU64x4 := @RISCVVCmpGtU64x4;
  table.CmpGeU64x4 := @RISCVVCmpGeU64x4;
  table.CmpNeU64x4 := @RISCVVCmpNeU64x4;

  // Unsigned Integer Types: U32x8 (256-bit)
  // Keep one assignment site for both modes:
  // - asm-enabled builds resolve these symbols to native RVV implementations
  // - no-asm builds resolve the same symbols to explicit scalar-passthrough
  //   facades, so the published shift semantics stay identical without a
  //   second register-only branch
  // Neighboring U32x16/U64x8 families intentionally fall through to
  // FillBaseDispatchTable instead.
  table.AddU32x8 := @RISCVVAddU32x8;
  table.SubU32x8 := @RISCVVSubU32x8;
  table.MulU32x8 := @RISCVVMulU32x8;
  table.AndU32x8 := @RISCVVAndU32x8;
  table.OrU32x8 := @RISCVVOrU32x8;
  table.XorU32x8 := @RISCVVXorU32x8;
  table.NotU32x8 := @RISCVVNotU32x8;
  table.AndNotU32x8 := @RISCVVAndNotU32x8;
  table.ShiftLeftU32x8 := @RISCVVShiftLeftU32x8;
  table.ShiftRightU32x8 := @RISCVVShiftRightU32x8;
  table.CmpEqU32x8 := @RISCVVCmpEqU32x8;
  table.CmpLtU32x8 := @RISCVVCmpLtU32x8;
  table.CmpLeU32x8 := @RISCVVCmpLeU32x8;
  table.CmpGtU32x8 := @RISCVVCmpGtU32x8;
  table.CmpGeU32x8 := @RISCVVCmpGeU32x8;
  table.CmpNeU32x8 := @RISCVVCmpNeU32x8;
  table.MinU32x8 := @RISCVVMinU32x8;
  table.MaxU32x8 := @RISCVVMaxU32x8;

  // F64x4 Reciprocal
  table.RcpF64x4 := @RISCVVRcpF64x4;

  // Unsigned Integer Types: U16x8
  table.AddU16x8 := @RISCVVAddU16x8;
  table.SubU16x8 := @RISCVVSubU16x8;
  table.MulU16x8 := @RISCVVMulU16x8;
  table.AndU16x8 := @RISCVVAndU16x8;
  table.OrU16x8 := @RISCVVOrU16x8;
  table.XorU16x8 := @RISCVVXorU16x8;
  table.NotU16x8 := @RISCVVNotU16x8;
  {$IFDEF RISCVV_ASSEMBLY}
  table.AndNotU16x8 := @RISCVVAndNotU16x8;
  {$ENDIF}
  table.ShiftLeftU16x8 := @RISCVVShiftLeftU16x8;
  table.ShiftRightU16x8 := @RISCVVShiftRightU16x8;
  table.CmpEqU16x8 := @RISCVVCmpEqU16x8;
  table.CmpLtU16x8 := @RISCVVCmpLtU16x8;
  table.CmpLeU16x8 := @RISCVVCmpLeU16x8;
  table.CmpGtU16x8 := @RISCVVCmpGtU16x8;
  table.CmpGeU16x8 := @RISCVVCmpGeU16x8;
  table.CmpNeU16x8 := @RISCVVCmpNeU16x8;
  table.MinU16x8 := @RISCVVMinU16x8;
  table.MaxU16x8 := @RISCVVMaxU16x8;

  // Unsigned Integer Types: U8x16
  table.AddU8x16 := @RISCVVAddU8x16;
  table.SubU8x16 := @RISCVVSubU8x16;
  table.AndU8x16 := @RISCVVAndU8x16;
  table.OrU8x16 := @RISCVVOrU8x16;
  table.XorU8x16 := @RISCVVXorU8x16;
  table.NotU8x16 := @RISCVVNotU8x16;
  {$IFDEF RISCVV_ASSEMBLY}
  table.AndNotU8x16 := @RISCVVAndNotU8x16;
  {$ENDIF}
  table.CmpEqU8x16 := @RISCVVCmpEqU8x16;
  table.CmpLtU8x16 := @RISCVVCmpLtU8x16;
  table.CmpLeU8x16 := @RISCVVCmpLeU8x16;
  table.CmpGtU8x16 := @RISCVVCmpGtU8x16;
  table.CmpGeU8x16 := @RISCVVCmpGeU8x16;
  table.CmpNeU8x16 := @RISCVVCmpNeU8x16;
  table.MinU8x16 := @RISCVVMinU8x16;
  table.MaxU8x16 := @RISCVVMaxU8x16;

  // Saturating Arithmetic
  table.I8x16SatAdd := @RISCVVSatAddI8x16;
  table.I8x16SatSub := @RISCVVSatSubI8x16;
  table.I16x8SatAdd := @RISCVVSatAddI16x8;
  table.I16x8SatSub := @RISCVVSatSubI16x8;
  table.U8x16SatAdd := @RISCVVSatAddU8x16;
  table.U8x16SatSub := @RISCVVSatSubU8x16;
  table.U16x8SatAdd := @RISCVVSatAddU16x8;
  table.U16x8SatSub := @RISCVVSatSubU16x8;

  // === Facade Functions ===
  // Keep scalar-pass-through facade helpers on the base scalar slots.
  // Backend-local wrappers add no runtime value and hide the actual slot ownership.

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
