procedure RegisterNEONBackend;
var
  table: TSimdDispatchTable;
  LCapabilities: TSimdCapabilities;
  LAsmCapable: Boolean;
  LUseVectorAsm: Boolean;
begin
  // Fill with base scalar implementations (provides fallback for unimplemented operations)
  table := Default(TSimdDispatchTable);
  FillBaseDispatchTable(table);

  LAsmCapable := False;
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  LAsmCapable := True;
  {$ENDIF}
  LUseVectorAsm := False;
  if LAsmCapable then
    LUseVectorAsm := IsVectorAsmEnabled;

  // Backend info
  table.Backend := sbNEON;
  table.BackendInfo.Backend := sbNEON;
  table.BackendInfo.Available := (not LAsmCapable) or LUseVectorAsm;
  table.BackendInfo.Name := 'NEON';
  table.BackendInfo.Description := 'ARM NEON 128-bit SIMD';
  // Mask helpers own SharedMask* (portable Pascal / x86 BSF leaves) on every
  // host. They are not NEON-asm gated, matching the SSE2 always-on Mask model.
  LCapabilities := [scBasicArithmetic, scComparison, scMathFunctions,
                    scReduction, scLoadStore, scMaskedOps];
  if LUseVectorAsm then
    Include(LCapabilities, scIntegerOps);
  if LUseVectorAsm then
    Include(LCapabilities, scFMA);
  if LUseVectorAsm then
    Include(LCapabilities, scShuffle);
  table.BackendInfo.Capabilities := LCapabilities;
  table.BackendInfo.Priority := GetSimdBackendPriorityValue(sbNEON);

  // Portable shared mask helpers. Do not invent NEONMask* scalar forwarders.
  table.Mask.Mask2All := @SharedMask2All;
  table.Mask.Mask2Any := @SharedMask2Any;
  table.Mask.Mask2None := @SharedMask2None;
  table.Mask.Mask2PopCount := @SharedMask2PopCount;
  table.Mask.Mask2FirstSet := @SharedMask2FirstSet;
  table.Mask.Mask4All := @SharedMask4All;
  table.Mask.Mask4Any := @SharedMask4Any;
  table.Mask.Mask4None := @SharedMask4None;
  table.Mask.Mask4PopCount := @SharedMask4PopCount;
  table.Mask.Mask4FirstSet := @SharedMask4FirstSet;
  table.Mask.Mask8All := @SharedMask8All;
  table.Mask.Mask8Any := @SharedMask8Any;
  table.Mask.Mask8None := @SharedMask8None;
  table.Mask.Mask8PopCount := @SharedMask8PopCount;
  table.Mask.Mask8FirstSet := @SharedMask8FirstSet;
  table.Mask.Mask16All := @SharedMask16All;
  table.Mask.Mask16Any := @SharedMask16Any;
  table.Mask.Mask16None := @SharedMask16None;
  table.Mask.Mask16PopCount := @SharedMask16PopCount;
  table.Mask.Mask16FirstSet := @SharedMask16FirstSet;

  if LAsmCapable and (not LUseVectorAsm) then
  begin
    RegisterBackend(sbNEON, table);
    Exit;
  end;

  // Override with NEON-accelerated operations
  // Arithmetic operations - F32x4
  table.CoreVectors.AddF32x4 := @NEONAddF32x4;
  table.CoreVectors.SubF32x4 := @NEONSubF32x4;
  table.CoreVectors.MulF32x4 := @NEONMulF32x4;
  table.CoreVectors.DivF32x4 := @NEONDivF32x4;

  // Arithmetic operations - F32x8 (emulated via 2x F32x4)
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.AddF32x8 := @NEONAddF32x8;
  table.CoreVectors.SubF32x8 := @NEONSubF32x8;
  table.CoreVectors.MulF32x8 := @NEONMulF32x8;
  table.CoreVectors.DivF32x8 := @NEONDivF32x8;
  {$ENDIF}

  // Arithmetic operations - F64x2
  table.CoreVectors.AddF64x2 := @NEONAddF64x2;
  table.CoreVectors.SubF64x2 := @NEONSubF64x2;
  table.CoreVectors.MulF64x2 := @NEONMulF64x2;
  table.CoreVectors.DivF64x2 := @NEONDivF64x2;

  // Comparison operations
  table.CoreVectors.CmpEqF32x4 := @NEONCmpEqF32x4;
  table.CoreVectors.CmpLtF32x4 := @NEONCmpLtF32x4;
  table.CoreVectors.CmpLeF32x4 := @NEONCmpLeF32x4;
  table.CoreVectors.CmpGtF32x4 := @NEONCmpGtF32x4;
  table.CoreVectors.CmpGeF32x4 := @NEONCmpGeF32x4;
  table.CoreVectors.CmpNeF32x4 := @NEONCmpNeF32x4;

  // Math functions
  table.CoreVectors.AbsF32x4 := @NEONAbsF32x4;
  table.CoreVectors.SqrtF32x4 := @NEONSqrtF32x4;
  table.CoreVectors.MinF32x4 := @NEONMinF32x4;
  table.CoreVectors.MaxF32x4 := @NEONMaxF32x4;

  // Extended math functions
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.FmaF32x4 := @NEONFmaF32x4;
  table.CoreVectors.RcpF32x4 := @NEONRcpF32x4;
  table.CoreVectors.RsqrtF32x4 := @NEONRsqrtF32x4;
  {$ENDIF}
  table.CoreVectors.FloorF32x4 := @NEONFloorF32x4;
  table.CoreVectors.CeilF32x4 := @NEONCeilF32x4;
  table.CoreVectors.RoundF32x4 := @NEONRoundF32x4;
  table.CoreVectors.TruncF32x4 := @NEONTruncF32x4;
  table.CoreVectors.ClampF32x4 := @NEONClampF32x4;

  // 3D/4D Vector math
  table.CoreVectors.DotF32x4 := @NEONDotF32x4;
  table.CoreVectors.DotF32x3 := @NEONDotF32x3;
  table.CoreVectors.CrossF32x3 := @NEONCrossF32x3;
  table.CoreVectors.LengthF32x4 := @NEONLengthF32x4;
  table.CoreVectors.LengthF32x3 := @NEONLengthF32x3;
  table.CoreVectors.NormalizeF32x4 := @NEONNormalizeF32x4;

  table.CoreVectors.NormalizeF32x3 := @NEONNormalizeF32x3;

  // Reduction operations
  table.CoreVectors.ReduceAddF32x4 := @NEONReduceAddF32x4;
  table.CoreVectors.ReduceMinF32x4 := @NEONReduceMinF32x4;
  table.CoreVectors.ReduceMaxF32x4 := @NEONReduceMaxF32x4;
  table.CoreVectors.ReduceMulF32x4 := @NEONReduceMulF32x4;

  // Memory operations
  table.CoreVectors.LoadF32x4 := @NEONLoadF32x4;
  table.CoreVectors.LoadF32x4Aligned := @NEONLoadF32x4Aligned;
  table.CoreVectors.StoreF32x4 := @NEONStoreF32x4;
  table.CoreVectors.StoreF32x4Aligned := @NEONStoreF32x4Aligned;

  // Utility operations
  table.CoreVectors.SplatF32x4 := @NEONSplatF32x4;
  table.CoreVectors.ZeroF32x4 := @NEONZeroF32x4;
  // Keep SelectF32x4 on the base scalar table even in asm-enabled builds.
  // The local asm-branch source remains a Pascal lane loop, so only the real
  // Extract/Insert asm leaves justify backend-owned shuffle slots.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ExtractF32x4 := @NEONExtractF32x4;
  table.CoreVectors.InsertF32x4 := @NEONInsertF32x4;
  {$ENDIF}

  // Facade functions
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.Memory.Equal := @MemEqual_NEON;
  table.Memory.FindByte := @MemFindByte_NEON;
  table.Memory.DiffRange := @MemDiffRange_NEON;
  table.Memory.Copy := @MemCopy_NEON;
  table.Memory.Fill := @MemSet_NEON;
  table.Memory.Reverse := @MemReverse_NEON;
  table.Memory.BytesIndexOf := @BytesIndexOf_NEON;
  table.Memory.Utf8Validate := @Utf8Validate_NEON;
  table.Memory.SumBytes := @SumBytes_NEON;
  table.Memory.MinMaxBytes := @MinMaxBytes_NEON;
  table.Memory.CountByte := @CountByte_NEON;
  table.Memory.AsciiIEqual := @AsciiIEqual_NEON;
  table.Memory.ToLowerAscii := @ToLowerAscii_NEON;
  table.Memory.ToUpperAscii := @ToUpperAscii_NEON;
  table.Memory.BitsetPopCount := @BitsetPopCount_NEON;
  // Phase 23a/23b: BatchF32 high-frequency leaves (register only under ASM).
  table.BatchF32.ArrayAdd := @NEONArrayAddF32;
  table.BatchF32.ArraySub := @NEONArraySubF32;
  table.BatchF32.ArrayMul := @NEONArrayMulF32;
  table.BatchF32.ArrayMin := @NEONArrayMinF32;
  table.BatchF32.ArrayMax := @NEONArrayMaxF32;
  table.BatchF32.ArrayAbs := @NEONArrayAbsF32;
  table.BatchF32.ArrayNeg := @NEONArrayNegF32;
  {$ENDIF}

  // Keep permanently-scalar platform facade helpers on the base scalar slots.
  // Backend-local wrappers add no runtime value and make slot ownership harder to audit.
  // Wide dot fallback-only helpers follow the same rule until NEON owns a real implementation.
  // Phase 22b closed Memory (15/15 under ASM). Phase 23a/23b own BatchF32
  // Add/Sub/Mul/Min/Max/Abs/Neg; remaining BatchF32 / BatchF64 / BatchInteger
  // slots still inherit FillBase scalar.

  // Saturating arithmetic is backend-owned only when NEON asm is compiled.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.I8x16SatAdd := @NEONI8x16SatAdd;
  table.CoreVectors.I8x16SatSub := @NEONI8x16SatSub;
  table.CoreVectors.I16x8SatAdd := @NEONI16x8SatAdd;
  table.CoreVectors.I16x8SatSub := @NEONI16x8SatSub;
  table.CoreVectors.U8x16SatAdd := @NEONU8x16SatAdd;
  table.CoreVectors.U8x16SatSub := @NEONU8x16SatSub;
  table.CoreVectors.U16x8SatAdd := @NEONU16x8SatAdd;
  table.CoreVectors.U16x8SatSub := @NEONU16x8SatSub;
  {$ENDIF}

  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SelectF64x2 := @NEONSelectF64x2;
  {$ENDIF}

  // Integer-family slots are backend-owned only when a real NEON asm body
  // exists. Otherwise RegisterNEONBackend inherits the published scalar slots
  // from FillBaseDispatchTable.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.AddI32x4 := @NEONAddI32x4;
  table.CoreVectors.SubI32x4 := @NEONSubI32x4;
  table.CoreVectors.MulI32x4 := @NEONMulI32x4;
  table.CoreVectors.AndI32x4 := @NEONAndI32x4;
  table.CoreVectors.OrI32x4 := @NEONOrI32x4;
  table.CoreVectors.XorI32x4 := @NEONXorI32x4;
  table.CoreVectors.NotI32x4 := @NEONNotI32x4;
  table.CoreVectors.AndNotI32x4 := @NEONAndNotI32x4;
  table.CoreVectors.ShiftLeftI32x4 := @NEONShiftLeftI32x4;
  table.CoreVectors.ShiftRightI32x4 := @NEONShiftRightI32x4;
  table.CoreVectors.ShiftRightArithI32x4 := @NEONShiftRightArithI32x4;
  table.CoreVectors.CmpEqI32x4 := @NEONCmpEqI32x4;
  table.CoreVectors.CmpLtI32x4 := @NEONCmpLtI32x4;
  table.CoreVectors.CmpGtI32x4 := @NEONCmpGtI32x4;
  table.CoreVectors.CmpLeI32x4 := @NEONCmpLeI32x4;
  table.CoreVectors.CmpGeI32x4 := @NEONCmpGeI32x4;
  table.CoreVectors.CmpNeI32x4 := @NEONCmpNeI32x4;

  table.CoreVectors.AddU32x4 := @NEONAddU32x4;
  table.CoreVectors.SubU32x4 := @NEONSubU32x4;
  table.CoreVectors.AndU32x4 := @NEONAndU32x4;
  table.CoreVectors.OrU32x4 := @NEONOrU32x4;
  table.CoreVectors.XorU32x4 := @NEONXorU32x4;
  table.CoreVectors.NotU32x4 := @NEONNotU32x4;
  table.CoreVectors.AndNotU32x4 := @NEONAndNotU32x4;
  table.CoreVectors.ShiftLeftU32x4 := @NEONShiftLeftU32x4;
  table.CoreVectors.ShiftRightU32x4 := @NEONShiftRightU32x4;
  table.CoreVectors.CmpEqU32x4 := @NEONCmpEqU32x4;
  table.CoreVectors.CmpLtU32x4 := @NEONCmpLtU32x4;
  table.CoreVectors.CmpGtU32x4 := @NEONCmpGtU32x4;
  table.CoreVectors.CmpLeU32x4 := @NEONCmpLeU32x4;
  table.CoreVectors.CmpGeU32x4 := @NEONCmpGeU32x4;
  table.CoreVectors.MinU32x4 := @NEONMinU32x4;
  table.CoreVectors.MaxU32x4 := @NEONMaxU32x4;

  table.CoreVectors.AddI16x8 := @NEONAddI16x8;
  table.CoreVectors.SubI16x8 := @NEONSubI16x8;
  table.CoreVectors.MulI16x8 := @NEONMulI16x8;
  table.CoreVectors.AndI16x8 := @NEONAndI16x8;
  table.CoreVectors.OrI16x8 := @NEONOrI16x8;
  table.CoreVectors.XorI16x8 := @NEONXorI16x8;
  table.CoreVectors.NotI16x8 := @NEONNotI16x8;
  table.CoreVectors.AndNotI16x8 := @NEONAndNotI16x8;
  table.CoreVectors.MinI16x8 := @NEONMinI16x8;
  table.CoreVectors.MaxI16x8 := @NEONMaxI16x8;
  table.CoreVectors.CmpEqI16x8 := @NEONCmpEqI16x8;
  table.CoreVectors.CmpLtI16x8 := @NEONCmpLtI16x8;
  table.CoreVectors.CmpGtI16x8 := @NEONCmpGtI16x8;
  table.CoreVectors.CmpLeI16x8 := @NEONCmpLeI16x8;
  table.CoreVectors.CmpGeI16x8 := @NEONCmpGeI16x8;
  table.CoreVectors.CmpNeI16x8 := @NEONCmpNeI16x8;

  table.CoreVectors.AddI8x16 := @NEONAddI8x16;
  table.CoreVectors.SubI8x16 := @NEONSubI8x16;
  table.CoreVectors.AndI8x16 := @NEONAndI8x16;
  table.CoreVectors.OrI8x16 := @NEONOrI8x16;
  table.CoreVectors.XorI8x16 := @NEONXorI8x16;
  table.CoreVectors.NotI8x16 := @NEONNotI8x16;
  table.CoreVectors.MinI8x16 := @NEONMinI8x16;
  table.CoreVectors.MaxI8x16 := @NEONMaxI8x16;
  table.CoreVectors.CmpEqI8x16 := @NEONCmpEqI8x16;
  table.CoreVectors.CmpLtI8x16 := @NEONCmpLtI8x16;
  table.CoreVectors.CmpGtI8x16 := @NEONCmpGtI8x16;
  table.CoreVectors.CmpLeI8x16 := @NEONCmpLeI8x16;
  table.CoreVectors.CmpGeI8x16 := @NEONCmpGeI8x16;
  table.CoreVectors.CmpNeI8x16 := @NEONCmpNeI8x16;

  table.CoreVectors.AddU16x8 := @NEONAddU16x8;
  table.CoreVectors.SubU16x8 := @NEONSubU16x8;
  table.CoreVectors.MulU16x8 := @NEONMulU16x8;
  table.CoreVectors.AndU16x8 := @NEONAndU16x8;
  table.CoreVectors.OrU16x8 := @NEONOrU16x8;
  table.CoreVectors.XorU16x8 := @NEONXorU16x8;
  table.CoreVectors.NotU16x8 := @NEONNotU16x8;
  table.CoreVectors.MinU16x8 := @NEONMinU16x8;
  table.CoreVectors.MaxU16x8 := @NEONMaxU16x8;
  table.CoreVectors.CmpEqU16x8 := @NEONCmpEqU16x8;
  table.CoreVectors.CmpLtU16x8 := @NEONCmpLtU16x8;
  table.CoreVectors.CmpGtU16x8 := @NEONCmpGtU16x8;
  table.CoreVectors.CmpLeU16x8 := @NEONCmpLeU16x8;
  table.CoreVectors.CmpGeU16x8 := @NEONCmpGeU16x8;
  table.CoreVectors.CmpNeU16x8 := @NEONCmpNeU16x8;

  table.CoreVectors.AddU8x16 := @NEONAddU8x16;
  table.CoreVectors.SubU8x16 := @NEONSubU8x16;
  table.CoreVectors.AndU8x16 := @NEONAndU8x16;
  table.CoreVectors.OrU8x16 := @NEONOrU8x16;
  table.CoreVectors.XorU8x16 := @NEONXorU8x16;
  table.CoreVectors.NotU8x16 := @NEONNotU8x16;
  table.CoreVectors.MinU8x16 := @NEONMinU8x16;
  table.CoreVectors.MaxU8x16 := @NEONMaxU8x16;
  table.CoreVectors.CmpEqU8x16 := @NEONCmpEqU8x16;
  table.CoreVectors.CmpLtU8x16 := @NEONCmpLtU8x16;
  table.CoreVectors.CmpGtU8x16 := @NEONCmpGtU8x16;
  table.CoreVectors.CmpLeU8x16 := @NEONCmpLeU8x16;
  table.CoreVectors.CmpGeU8x16 := @NEONCmpGeU8x16;
  table.CoreVectors.CmpNeU8x16 := @NEONCmpNeU8x16;

  table.CoreVectors.AddI64x2 := @NEONAddI64x2;
  table.CoreVectors.SubI64x2 := @NEONSubI64x2;
  table.CoreVectors.AndI64x2 := @NEONAndI64x2;
  table.CoreVectors.OrI64x2 := @NEONOrI64x2;
  table.CoreVectors.XorI64x2 := @NEONXorI64x2;
  table.CoreVectors.NotI64x2 := @NEONNotI64x2;
  table.CoreVectors.CmpEqI64x2 := @NEONCmpEqI64x2;
  table.CoreVectors.CmpLtI64x2 := @NEONCmpLtI64x2;
  table.CoreVectors.CmpGtI64x2 := @NEONCmpGtI64x2;
  table.CoreVectors.CmpLeI64x2 := @NEONCmpLeI64x2;
  table.CoreVectors.CmpGeI64x2 := @NEONCmpGeI64x2;
  table.CoreVectors.CmpNeI64x2 := @NEONCmpNeI64x2;

  // Wider integer arithmetic/bitwise/memory families are backend-owned
  // only when a real NEON asm body exists. The wide compare families are
  // registered below in both asm/no-asm builds because they now compose
  // narrower NEON helpers instead of reusing the base scalar slot.
  table.CoreVectors.AddI32x8 := @NEONAddI32x8;
  table.CoreVectors.AddU32x8 := @NEONAddU32x8;
  table.CoreVectors.AddU64x4 := @NEONAddU64x4;
  table.CoreVectors.AndI32x8 := @NEONAndI32x8;
  table.CoreVectors.AndI64x4 := @NEONAndI64x4;
  table.CoreVectors.AndNotI32x8 := @NEONAndNotI32x8;
  table.CoreVectors.AndNotI64x4 := @NEONAndNotI64x4;
  table.CoreVectors.AndNotU32x8 := @NEONAndNotU32x8;
  table.CoreVectors.AndU32x8 := @NEONAndU32x8;
  table.CoreVectors.AndU64x4 := @NEONAndU64x4;
  table.CoreVectors.MaxU32x8 := @NEONMaxU32x8;
  table.CoreVectors.MinU32x8 := @NEONMinU32x8;
  table.CoreVectors.MulI32x8 := @NEONMulI32x8;
  table.CoreVectors.NotI32x8 := @NEONNotI32x8;
  table.CoreVectors.NotI64x4 := @NEONNotI64x4;
  table.CoreVectors.NotU32x8 := @NEONNotU32x8;
  table.CoreVectors.NotU64x4 := @NEONNotU64x4;
  table.CoreVectors.OrI32x8 := @NEONOrI32x8;
  table.CoreVectors.OrI64x4 := @NEONOrI64x4;
  table.CoreVectors.OrU32x8 := @NEONOrU32x8;
  table.CoreVectors.OrU64x4 := @NEONOrU64x4;
  table.CoreVectors.ShiftLeftI32x16 := @NEONShiftLeftI32x16;
  table.CoreVectors.ShiftLeftI32x8 := @NEONShiftLeftI32x8;
  table.CoreVectors.ShiftLeftI64x4 := @NEONShiftLeftI64x4;
  table.CoreVectors.ShiftLeftU32x8 := @NEONShiftLeftU32x8;
  table.CoreVectors.ShiftLeftU64x4 := @NEONShiftLeftU64x4;
  table.CoreVectors.ShiftRightArithI32x16 := @NEONShiftRightArithI32x16;
  table.CoreVectors.ShiftRightArithI32x8 := @NEONShiftRightArithI32x8;
  table.CoreVectors.ShiftRightI32x16 := @NEONShiftRightI32x16;
  table.CoreVectors.ShiftRightI32x8 := @NEONShiftRightI32x8;
  table.CoreVectors.ShiftRightI64x4 := @NEONShiftRightI64x4;
  table.CoreVectors.ShiftRightArithI64x4 := @NEONShiftRightArithI64x4;
  table.CoreVectors.ShiftRightU32x8 := @NEONShiftRightU32x8;
  table.CoreVectors.ShiftRightU64x4 := @NEONShiftRightU64x4;
  table.CoreVectors.SubI32x8 := @NEONSubI32x8;
  table.CoreVectors.SubU32x8 := @NEONSubU32x8;
  table.CoreVectors.SubU64x4 := @NEONSubU64x4;
  table.CoreVectors.XorI32x8 := @NEONXorI32x8;
  table.CoreVectors.XorI64x4 := @NEONXorI64x4;
  table.CoreVectors.XorU32x8 := @NEONXorU32x8;
  table.CoreVectors.XorU64x4 := @NEONXorU64x4;
  table.CoreVectors.LoadI64x4 := @NEONLoadI64x4_ASM;
  table.CoreVectors.SplatI64x4 := @NEONSplatI64x4_ASM;
  table.CoreVectors.StoreI64x4 := @NEONStoreI64x4_ASM;
  table.CoreVectors.ZeroI64x4 := @NEONZeroI64x4_ASM;

  // Wide float memory/utility slots should use the real NEON helper path when
  // asm is compiled. The scalar companion wrappers remain for no-asm builds,
  // but they must not shadow the native helper on arm64.
  table.CoreVectors.LoadF32x8 := @NEONLoadF32x8_ASM;
  table.CoreVectors.LoadF32x16 := @NEONLoadF32x16_ASM;
  table.CoreVectors.LoadF64x4 := @NEONLoadF64x4_ASM;
  table.CoreVectors.LoadF64x8 := @NEONLoadF64x8_ASM;
  table.CoreVectors.SplatF32x8 := @NEONSplatF32x8_ASM;
  table.CoreVectors.SplatF32x16 := @NEONSplatF32x16_ASM;
  table.CoreVectors.SplatF64x4 := @NEONSplatF64x4_ASM;
  table.CoreVectors.SplatF64x8 := @NEONSplatF64x8_ASM;
  table.CoreVectors.StoreF32x8 := @NEONStoreF32x8_ASM;
  table.CoreVectors.StoreF32x16 := @NEONStoreF32x16_ASM;
  table.CoreVectors.StoreF64x4 := @NEONStoreF64x4_ASM;
  table.CoreVectors.StoreF64x8 := @NEONStoreF64x8_ASM;
  table.CoreVectors.ZeroF32x8 := @NEONZeroF32x8_ASM;
  table.CoreVectors.ZeroF32x16 := @NEONZeroF32x16_ASM;
  table.CoreVectors.ZeroF64x4 := @NEONZeroF64x4_ASM;
  table.CoreVectors.ZeroF64x8 := @NEONZeroF64x8_ASM;
  {$ENDIF}

  // Wide integer compare wrappers remain as Pascal source companions so wider
  // fallback graphs can compose narrower helpers, but published NEON slot
  // ownership is only truthful when asm is actually compiled.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.CmpEqI32x16 := @NEONCmpEqI32x16;
  table.CoreVectors.CmpEqI32x8 := @NEONCmpEqI32x8;
  table.CoreVectors.CmpEqI64x4 := @NEONCmpEqI64x4;
  table.CoreVectors.CmpEqI64x8 := @NEONCmpEqI64x8;
  table.CoreVectors.CmpEqU32x8 := @NEONCmpEqU32x8;
  table.CoreVectors.CmpEqU64x4 := @NEONCmpEqU64x4;
  table.CoreVectors.CmpGeI32x16 := @NEONCmpGeI32x16;
  table.CoreVectors.CmpGeI32x8 := @NEONCmpGeI32x8;
  table.CoreVectors.CmpGeI64x4 := @NEONCmpGeI64x4;
  table.CoreVectors.CmpGeI64x8 := @NEONCmpGeI64x8;
  table.CoreVectors.CmpGeU32x8 := @NEONCmpGeU32x8;
  table.CoreVectors.CmpGeU64x4 := @NEONCmpGeU64x4;
  table.CoreVectors.CmpGtI32x16 := @NEONCmpGtI32x16;
  table.CoreVectors.CmpGtI32x8 := @NEONCmpGtI32x8;
  table.CoreVectors.CmpGtI64x4 := @NEONCmpGtI64x4;
  table.CoreVectors.CmpGtI64x8 := @NEONCmpGtI64x8;
  table.CoreVectors.CmpGtU32x8 := @NEONCmpGtU32x8;
  table.CoreVectors.CmpGtU64x4 := @NEONCmpGtU64x4;
  table.CoreVectors.CmpLeI32x16 := @NEONCmpLeI32x16;
  table.CoreVectors.CmpLeI32x8 := @NEONCmpLeI32x8;
  table.CoreVectors.CmpLeI64x4 := @NEONCmpLeI64x4;
  table.CoreVectors.CmpLeI64x8 := @NEONCmpLeI64x8;
  table.CoreVectors.CmpLeU32x8 := @NEONCmpLeU32x8;
  table.CoreVectors.CmpLeU64x4 := @NEONCmpLeU64x4;
  table.CoreVectors.CmpLtI32x16 := @NEONCmpLtI32x16;
  table.CoreVectors.CmpLtI32x8 := @NEONCmpLtI32x8;
  table.CoreVectors.CmpLtI64x4 := @NEONCmpLtI64x4;
  table.CoreVectors.CmpLtI64x8 := @NEONCmpLtI64x8;
  table.CoreVectors.CmpLtU32x8 := @NEONCmpLtU32x8;
  table.CoreVectors.CmpLtU64x4 := @NEONCmpLtU64x4;
  table.CoreVectors.CmpNeI32x16 := @NEONCmpNeI32x16;
  table.CoreVectors.CmpNeI32x8 := @NEONCmpNeI32x8;
  table.CoreVectors.CmpNeI64x4 := @NEONCmpNeI64x4;
  table.CoreVectors.CmpNeI64x8 := @NEONCmpNeI64x8;
  table.CoreVectors.CmpNeU32x8 := @NEONCmpNeU32x8;
  table.CoreVectors.CmpNeU64x4 := @NEONCmpNeU64x4;
  {$ENDIF}

  {$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  // Keep no-asm integer arithmetic/bitwise/memory slots on the published
  // scalar table. The Pascal fallback wrappers remain as source companions,
  // but they should not become NEON-owned dispatch slots when NEON asm is absent.

  // === Auto-generated Registration for 100% Coverage ===
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.AddF32x16 := @NEONAddF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.AddF64x4 := @NEONAddF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.AddF64x8 := @NEONAddF64x8;
  {$ENDIF}
  // Wide integer arithmetic/bitwise families intentionally inherit
  // FillBaseDispatchTable in no-asm builds; shared wide compare wrappers are
  // registered above and should stay backend-owned.
  // Keep no-asm wide Abs/Floor/Ceil slots on the published scalar table when
  // the NEON wrappers only forward to Scalar*. The narrow F64x2 Floor/Ceil
  // wrappers no longer own any local fallback behavior, so they should only be
  // published when the real asm leaf is available.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.CeilF64x2 := @NEONCeilF64x2;
  {$ENDIF}
  // Keep no-asm wide Clamp slots on the published scalar table only when the
  // wrapper is a pure F32x4 scalar-equivalent forwarder. The F64x2 Clamp loop
  // still carries local NaN/signed-zero fallback behavior, so the F64x2/F64x4/
  // F64x8 Clamp chain remains backend-owned until that behavior is retired on
  // purpose.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ClampF32x16 := @NEONClampF32x16;
  table.CoreVectors.ClampF32x8 := @NEONClampF32x8;
  {$ENDIF}
  // F64 clamp keeps backend ownership only when a real NEON asm leaf exists.
  // The no-asm wrappers stay as source companions but should inherit base scalar slots.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ClampF64x2 := @NEONClampF64x2;
  table.CoreVectors.ClampF64x4 := @NEONClampF64x4;
  table.CoreVectors.ClampF64x8 := @NEONClampF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.CmpEqF64x2 := @NEONCmpEqF64x2;
  table.CoreVectors.CmpGeF64x2 := @NEONCmpGeF64x2;
  table.CoreVectors.CmpGtF64x2 := @NEONCmpGtF64x2;
  table.CoreVectors.CmpLeF64x2 := @NEONCmpLeF64x2;
  table.CoreVectors.CmpLtF64x2 := @NEONCmpLtF64x2;
  table.CoreVectors.CmpNeF64x2 := @NEONCmpNeF64x2;
  {$ENDIF}
  // Keep no-asm wide float compare slots on the published scalar table when
  // the NEON wrappers are only scalar forwarders. The local F64x2 loops above
  // remain backend-owned because they still carry real backend-local behavior.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.DivF32x16 := @NEONDivF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.DivF64x4 := @NEONDivF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.DivF64x8 := @NEONDivF64x8;
  {$ENDIF}
  // Keep exact Scalar* extract/insert wrappers on the published scalar table
  // even in asm builds. These autowrap routines do not own backend-local behavior.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ExtractF64x2 := @NEONExtractF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.FloorF64x2 := @NEONFloorF64x2;
  {$ENDIF}
  // Keep FMA slots on the published scalar table when NEON asm is absent.
  // The no-asm helpers are exact ScalarFma* forwarders, while the asm build
  // below still owns real backend-local implementations.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.FmaF32x16 := @NEONFmaF32x16;
  table.CoreVectors.FmaF32x8 := @NEONFmaF32x8;
  table.CoreVectors.FmaF64x2 := @NEONFmaF64x2;
  table.CoreVectors.FmaF64x4 := @NEONFmaF64x4;
  table.CoreVectors.FmaF64x8 := @NEONFmaF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.InsertF64x2 := @NEONInsertF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.LoadF64x2 := @NEONLoadF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MaxF32x16 := @NEONMaxF32x16;
  table.CoreVectors.MaxF32x8 := @NEONMaxF32x8;
  {$ENDIF}
  // Keep the narrow F64x2 Min/Max source companions for the F64x4/F64x8
  // no-asm fallback graph, but publish the base scalar slots whenever NEON
  // asm is absent because the no-asm wrappers now align exactly with Scalar*.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MaxF64x2 := @NEONMaxF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MaxF64x4 := @NEONMaxF64x4;
  table.CoreVectors.MaxF64x8 := @NEONMaxF64x8;
  table.CoreVectors.MinF32x16 := @NEONMinF32x16;
  table.CoreVectors.MinF32x8 := @NEONMinF32x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MinF64x2 := @NEONMinF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MinF64x4 := @NEONMinF64x4;
  table.CoreVectors.MinF64x8 := @NEONMinF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MulF32x16 := @NEONMulF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MulF64x4 := @NEONMulF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.MulF64x8 := @NEONMulF64x8;
  {$ENDIF}
  // Keep wide reciprocal/reduction slots on the published scalar table when
  // the NEON wrappers only forward to Scalar* helpers.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ReduceAddF64x2 := @NEONReduceAddF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ReduceMaxF64x2 := @NEONReduceMaxF64x2;
  table.CoreVectors.ReduceMinF64x2 := @NEONReduceMinF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ReduceMulF64x2 := @NEONReduceMulF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.RoundF32x16 := @NEONRoundF32x16;
  table.CoreVectors.RoundF32x8 := @NEONRoundF32x8;
  {$ENDIF}
  // The F64 Round/Trunc no-asm wrappers are fully dead now; only asm builds
  // should publish backend-owned bindings for these slots.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.RoundF64x2 := @NEONRoundF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.RoundF64x4 := @NEONRoundF64x4;
  table.CoreVectors.RoundF64x8 := @NEONRoundF64x8;
  {$ENDIF}
  // Keep exact Scalar* select wrappers on the published scalar table even when
  // NEON asm is compiled. They are not backend-local owners.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ShiftLeftI16x8 := @NEONShiftLeftI16x8;
  table.CoreVectors.ShiftLeftU16x8 := @NEONShiftLeftU16x8;
  table.CoreVectors.ShiftRightArithI16x8 := @NEONShiftRightArithI16x8;
  table.CoreVectors.ShiftRightI16x8 := @NEONShiftRightI16x8;
  table.CoreVectors.ShiftRightU16x8 := @NEONShiftRightU16x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SplatF64x2 := @NEONSplatF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SqrtF32x16 := @NEONSqrtF32x16;
  table.CoreVectors.SqrtF32x8 := @NEONSqrtF32x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SqrtF64x2 := @NEONSqrtF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SqrtF64x4 := @NEONSqrtF64x4;
  table.CoreVectors.SqrtF64x8 := @NEONSqrtF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.StoreF64x2 := @NEONStoreF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SubF32x16 := @NEONSubF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SubF64x4 := @NEONSubF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.SubF64x8 := @NEONSubF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.TruncF32x16 := @NEONTruncF32x16;
  table.CoreVectors.TruncF32x8 := @NEONTruncF32x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.TruncF64x2 := @NEONTruncF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.TruncF64x4 := @NEONTruncF64x4;
  table.CoreVectors.TruncF64x8 := @NEONTruncF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.ZeroF64x2 := @NEONZeroF64x2;
  {$ENDIF}
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CoreVectors.AndNotI8x16 := @NEONAndNotI8x16;
  table.CoreVectors.AndNotU16x8 := @NEONAndNotU16x8;
  table.CoreVectors.AndNotU8x16 := @NEONAndNotU8x16;
  {$ENDIF}

  // Register the backend
  RegisterBackend(sbNEON, table);
end;

initialization
  // Test-only opt-in path: allow non-native hosts to register NEON scalar-fallback
  // implementations so DispatchAPI/PublicAbi suites can verify metadata contracts.
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
    // Delayed to the test runner so list-only startup paths do not need to
    // execute non-native backend registration during unit initialization.
  {$ELSE}
  // Only register NEON backend when ASM is available.
  // FPC 3.2.2 does NOT support AArch64 NEON inline assembly (causes ICE).
  // Without ASM, the scalar fallback + dispatch overhead makes performance WORSE.
  // Users with FPC 3.2.2 should use the scalar backend directly.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
    {$IFDEF CPUAARCH64}
    RegisterNEONBackend;
    RegisterBackendRebuilder(sbNEON, @RegisterNEONBackend);
    {$ENDIF}
    {$IFDEF CPUARM}
    RegisterNEONBackend;
    RegisterBackendRebuilder(sbNEON, @RegisterNEONBackend);
    {$ENDIF}
  {$ENDIF}
  {$ENDIF}
