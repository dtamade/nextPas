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
  LCapabilities := [scBasicArithmetic, scComparison, scMathFunctions,
                    scReduction, scLoadStore];
  if LUseVectorAsm then
    Include(LCapabilities, scIntegerOps);
  if LUseVectorAsm then
    Include(LCapabilities, scFMA);
  if LUseVectorAsm then
    Include(LCapabilities, scShuffle);
  table.BackendInfo.Capabilities := LCapabilities;
  table.BackendInfo.Priority := GetSimdBackendPriorityValue(sbNEON);

  if LAsmCapable and (not LUseVectorAsm) then
  begin
    RegisterBackend(sbNEON, table);
    Exit;
  end;

  // Override with NEON-accelerated operations
  // Arithmetic operations - F32x4
  table.AddF32x4 := @NEONAddF32x4;
  table.SubF32x4 := @NEONSubF32x4;
  table.MulF32x4 := @NEONMulF32x4;
  table.DivF32x4 := @NEONDivF32x4;

  // Arithmetic operations - F32x8 (emulated via 2x F32x4)
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.AddF32x8 := @NEONAddF32x8;
  table.SubF32x8 := @NEONSubF32x8;
  table.MulF32x8 := @NEONMulF32x8;
  table.DivF32x8 := @NEONDivF32x8;
  {$ENDIF}

  // Arithmetic operations - F64x2
  table.AddF64x2 := @NEONAddF64x2;
  table.SubF64x2 := @NEONSubF64x2;
  table.MulF64x2 := @NEONMulF64x2;
  table.DivF64x2 := @NEONDivF64x2;

  // Comparison operations
  table.CmpEqF32x4 := @NEONCmpEqF32x4;
  table.CmpLtF32x4 := @NEONCmpLtF32x4;
  table.CmpLeF32x4 := @NEONCmpLeF32x4;
  table.CmpGtF32x4 := @NEONCmpGtF32x4;
  table.CmpGeF32x4 := @NEONCmpGeF32x4;
  table.CmpNeF32x4 := @NEONCmpNeF32x4;

  // Math functions
  table.AbsF32x4 := @NEONAbsF32x4;
  table.SqrtF32x4 := @NEONSqrtF32x4;
  table.MinF32x4 := @NEONMinF32x4;
  table.MaxF32x4 := @NEONMaxF32x4;

  // Extended math functions
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.FmaF32x4 := @NEONFmaF32x4;
  table.RcpF32x4 := @NEONRcpF32x4;
  table.RsqrtF32x4 := @NEONRsqrtF32x4;
  {$ENDIF}
  table.FloorF32x4 := @NEONFloorF32x4;
  table.CeilF32x4 := @NEONCeilF32x4;
  table.RoundF32x4 := @NEONRoundF32x4;
  table.TruncF32x4 := @NEONTruncF32x4;
  table.ClampF32x4 := @NEONClampF32x4;

  // 3D/4D Vector math
  table.DotF32x4 := @NEONDotF32x4;
  table.DotF32x3 := @NEONDotF32x3;
  table.CrossF32x3 := @NEONCrossF32x3;
  table.LengthF32x4 := @NEONLengthF32x4;
  table.LengthF32x3 := @NEONLengthF32x3;
  table.NormalizeF32x4 := @NEONNormalizeF32x4;

  table.NormalizeF32x3 := @NEONNormalizeF32x3;

  // Reduction operations
  table.ReduceAddF32x4 := @NEONReduceAddF32x4;
  table.ReduceMinF32x4 := @NEONReduceMinF32x4;
  table.ReduceMaxF32x4 := @NEONReduceMaxF32x4;
  table.ReduceMulF32x4 := @NEONReduceMulF32x4;

  // Memory operations
  table.LoadF32x4 := @NEONLoadF32x4;
  table.LoadF32x4Aligned := @NEONLoadF32x4Aligned;
  table.StoreF32x4 := @NEONStoreF32x4;
  table.StoreF32x4Aligned := @NEONStoreF32x4Aligned;

  // Utility operations
  table.SplatF32x4 := @NEONSplatF32x4;
  table.ZeroF32x4 := @NEONZeroF32x4;
  // Keep SelectF32x4 on the base scalar table even in asm-enabled builds.
  // The local asm-branch source remains a Pascal lane loop, so only the real
  // Extract/Insert asm leaves justify backend-owned shuffle slots.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ExtractF32x4 := @NEONExtractF32x4;
  table.InsertF32x4 := @NEONInsertF32x4;
  {$ENDIF}

  // Facade functions
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MemEqual := @MemEqual_NEON;
  table.MemFindByte := @MemFindByte_NEON;
  table.SumBytes := @SumBytes_NEON;
  table.MinMaxBytes := @MinMaxBytes_NEON;
  table.CountByte := @CountByte_NEON;
  table.AsciiIEqual := @AsciiIEqual_NEON;
  table.ToLowerAscii := @ToLowerAscii_NEON;
  table.ToUpperAscii := @ToUpperAscii_NEON;
  table.BitsetPopCount := @BitsetPopCount_NEON;
  {$ENDIF}

  // Keep permanently-scalar platform facade helpers on the base scalar slots.
  // Backend-local wrappers add no runtime value and make slot ownership harder to audit.
  // Wide dot fallback-only helpers follow the same rule until NEON owns a real implementation.

  // Saturating arithmetic is backend-owned only when NEON asm is compiled.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.I8x16SatAdd := @NEONI8x16SatAdd;
  table.I8x16SatSub := @NEONI8x16SatSub;
  table.I16x8SatAdd := @NEONI16x8SatAdd;
  table.I16x8SatSub := @NEONI16x8SatSub;
  table.U8x16SatAdd := @NEONU8x16SatAdd;
  table.U8x16SatSub := @NEONU8x16SatSub;
  table.U16x8SatAdd := @NEONU16x8SatAdd;
  table.U16x8SatSub := @NEONU16x8SatSub;
  {$ENDIF}

  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SelectF64x2 := @NEONSelectF64x2;
  {$ENDIF}

  // Integer-family slots are backend-owned only when a real NEON asm body
  // exists. Otherwise RegisterNEONBackend inherits the published scalar slots
  // from FillBaseDispatchTable.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.AddI32x4 := @NEONAddI32x4;
  table.SubI32x4 := @NEONSubI32x4;
  table.MulI32x4 := @NEONMulI32x4;
  table.AndI32x4 := @NEONAndI32x4;
  table.OrI32x4 := @NEONOrI32x4;
  table.XorI32x4 := @NEONXorI32x4;
  table.NotI32x4 := @NEONNotI32x4;
  table.AndNotI32x4 := @NEONAndNotI32x4;
  table.ShiftLeftI32x4 := @NEONShiftLeftI32x4;
  table.ShiftRightI32x4 := @NEONShiftRightI32x4;
  table.ShiftRightArithI32x4 := @NEONShiftRightArithI32x4;
  table.CmpEqI32x4 := @NEONCmpEqI32x4;
  table.CmpLtI32x4 := @NEONCmpLtI32x4;
  table.CmpGtI32x4 := @NEONCmpGtI32x4;
  table.CmpLeI32x4 := @NEONCmpLeI32x4;
  table.CmpGeI32x4 := @NEONCmpGeI32x4;
  table.CmpNeI32x4 := @NEONCmpNeI32x4;

  table.AddU32x4 := @NEONAddU32x4;
  table.SubU32x4 := @NEONSubU32x4;
  table.AndU32x4 := @NEONAndU32x4;
  table.OrU32x4 := @NEONOrU32x4;
  table.XorU32x4 := @NEONXorU32x4;
  table.NotU32x4 := @NEONNotU32x4;
  table.AndNotU32x4 := @NEONAndNotU32x4;
  table.ShiftLeftU32x4 := @NEONShiftLeftU32x4;
  table.ShiftRightU32x4 := @NEONShiftRightU32x4;
  table.CmpEqU32x4 := @NEONCmpEqU32x4;
  table.CmpLtU32x4 := @NEONCmpLtU32x4;
  table.CmpGtU32x4 := @NEONCmpGtU32x4;
  table.CmpLeU32x4 := @NEONCmpLeU32x4;
  table.CmpGeU32x4 := @NEONCmpGeU32x4;
  table.MinU32x4 := @NEONMinU32x4;
  table.MaxU32x4 := @NEONMaxU32x4;

  table.AddI16x8 := @NEONAddI16x8;
  table.SubI16x8 := @NEONSubI16x8;
  table.MulI16x8 := @NEONMulI16x8;
  table.AndI16x8 := @NEONAndI16x8;
  table.OrI16x8 := @NEONOrI16x8;
  table.XorI16x8 := @NEONXorI16x8;
  table.NotI16x8 := @NEONNotI16x8;
  table.AndNotI16x8 := @NEONAndNotI16x8;
  table.MinI16x8 := @NEONMinI16x8;
  table.MaxI16x8 := @NEONMaxI16x8;
  table.CmpEqI16x8 := @NEONCmpEqI16x8;
  table.CmpLtI16x8 := @NEONCmpLtI16x8;
  table.CmpGtI16x8 := @NEONCmpGtI16x8;
  table.CmpLeI16x8 := @NEONCmpLeI16x8;
  table.CmpGeI16x8 := @NEONCmpGeI16x8;
  table.CmpNeI16x8 := @NEONCmpNeI16x8;

  table.AddI8x16 := @NEONAddI8x16;
  table.SubI8x16 := @NEONSubI8x16;
  table.AndI8x16 := @NEONAndI8x16;
  table.OrI8x16 := @NEONOrI8x16;
  table.XorI8x16 := @NEONXorI8x16;
  table.NotI8x16 := @NEONNotI8x16;
  table.MinI8x16 := @NEONMinI8x16;
  table.MaxI8x16 := @NEONMaxI8x16;
  table.CmpEqI8x16 := @NEONCmpEqI8x16;
  table.CmpLtI8x16 := @NEONCmpLtI8x16;
  table.CmpGtI8x16 := @NEONCmpGtI8x16;
  table.CmpLeI8x16 := @NEONCmpLeI8x16;
  table.CmpGeI8x16 := @NEONCmpGeI8x16;
  table.CmpNeI8x16 := @NEONCmpNeI8x16;

  table.AddU16x8 := @NEONAddU16x8;
  table.SubU16x8 := @NEONSubU16x8;
  table.MulU16x8 := @NEONMulU16x8;
  table.AndU16x8 := @NEONAndU16x8;
  table.OrU16x8 := @NEONOrU16x8;
  table.XorU16x8 := @NEONXorU16x8;
  table.NotU16x8 := @NEONNotU16x8;
  table.MinU16x8 := @NEONMinU16x8;
  table.MaxU16x8 := @NEONMaxU16x8;
  table.CmpEqU16x8 := @NEONCmpEqU16x8;
  table.CmpLtU16x8 := @NEONCmpLtU16x8;
  table.CmpGtU16x8 := @NEONCmpGtU16x8;
  table.CmpLeU16x8 := @NEONCmpLeU16x8;
  table.CmpGeU16x8 := @NEONCmpGeU16x8;
  table.CmpNeU16x8 := @NEONCmpNeU16x8;

  table.AddU8x16 := @NEONAddU8x16;
  table.SubU8x16 := @NEONSubU8x16;
  table.AndU8x16 := @NEONAndU8x16;
  table.OrU8x16 := @NEONOrU8x16;
  table.XorU8x16 := @NEONXorU8x16;
  table.NotU8x16 := @NEONNotU8x16;
  table.MinU8x16 := @NEONMinU8x16;
  table.MaxU8x16 := @NEONMaxU8x16;
  table.CmpEqU8x16 := @NEONCmpEqU8x16;
  table.CmpLtU8x16 := @NEONCmpLtU8x16;
  table.CmpGtU8x16 := @NEONCmpGtU8x16;
  table.CmpLeU8x16 := @NEONCmpLeU8x16;
  table.CmpGeU8x16 := @NEONCmpGeU8x16;
  table.CmpNeU8x16 := @NEONCmpNeU8x16;

  table.AddI64x2 := @NEONAddI64x2;
  table.SubI64x2 := @NEONSubI64x2;
  table.AndI64x2 := @NEONAndI64x2;
  table.OrI64x2 := @NEONOrI64x2;
  table.XorI64x2 := @NEONXorI64x2;
  table.NotI64x2 := @NEONNotI64x2;
  table.CmpEqI64x2 := @NEONCmpEqI64x2;
  table.CmpLtI64x2 := @NEONCmpLtI64x2;
  table.CmpGtI64x2 := @NEONCmpGtI64x2;
  table.CmpLeI64x2 := @NEONCmpLeI64x2;
  table.CmpGeI64x2 := @NEONCmpGeI64x2;
  table.CmpNeI64x2 := @NEONCmpNeI64x2;

  // Wider integer arithmetic/bitwise/memory families are backend-owned
  // only when a real NEON asm body exists. The wide compare families are
  // registered below in both asm/no-asm builds because they now compose
  // narrower NEON helpers instead of reusing the base scalar slot.
  table.AddI32x8 := @NEONAddI32x8;
  table.AddU32x8 := @NEONAddU32x8;
  table.AddU64x4 := @NEONAddU64x4;
  table.AndI32x8 := @NEONAndI32x8;
  table.AndI64x4 := @NEONAndI64x4;
  table.AndNotI32x8 := @NEONAndNotI32x8;
  table.AndNotI64x4 := @NEONAndNotI64x4;
  table.AndNotU32x8 := @NEONAndNotU32x8;
  table.AndU32x8 := @NEONAndU32x8;
  table.AndU64x4 := @NEONAndU64x4;
  table.MaxU32x8 := @NEONMaxU32x8;
  table.MinU32x8 := @NEONMinU32x8;
  table.MulI32x8 := @NEONMulI32x8;
  table.NotI32x8 := @NEONNotI32x8;
  table.NotI64x4 := @NEONNotI64x4;
  table.NotU32x8 := @NEONNotU32x8;
  table.NotU64x4 := @NEONNotU64x4;
  table.OrI32x8 := @NEONOrI32x8;
  table.OrI64x4 := @NEONOrI64x4;
  table.OrU32x8 := @NEONOrU32x8;
  table.OrU64x4 := @NEONOrU64x4;
  table.ShiftLeftI32x16 := @NEONShiftLeftI32x16;
  table.ShiftLeftI32x8 := @NEONShiftLeftI32x8;
  table.ShiftLeftI64x4 := @NEONShiftLeftI64x4;
  table.ShiftLeftU32x8 := @NEONShiftLeftU32x8;
  table.ShiftLeftU64x4 := @NEONShiftLeftU64x4;
  table.ShiftRightArithI32x16 := @NEONShiftRightArithI32x16;
  table.ShiftRightArithI32x8 := @NEONShiftRightArithI32x8;
  table.ShiftRightI32x16 := @NEONShiftRightI32x16;
  table.ShiftRightI32x8 := @NEONShiftRightI32x8;
  table.ShiftRightI64x4 := @NEONShiftRightI64x4;
  table.ShiftRightArithI64x4 := @NEONShiftRightArithI64x4;
  table.ShiftRightU32x8 := @NEONShiftRightU32x8;
  table.ShiftRightU64x4 := @NEONShiftRightU64x4;
  table.SubI32x8 := @NEONSubI32x8;
  table.SubU32x8 := @NEONSubU32x8;
  table.SubU64x4 := @NEONSubU64x4;
  table.XorI32x8 := @NEONXorI32x8;
  table.XorI64x4 := @NEONXorI64x4;
  table.XorU32x8 := @NEONXorU32x8;
  table.XorU64x4 := @NEONXorU64x4;
  table.LoadI64x4 := @NEONLoadI64x4_ASM;
  table.SplatI64x4 := @NEONSplatI64x4_ASM;
  table.StoreI64x4 := @NEONStoreI64x4_ASM;
  table.ZeroI64x4 := @NEONZeroI64x4_ASM;

  // Wide float memory/utility slots should use the real NEON helper path when
  // asm is compiled. The scalar companion wrappers remain for no-asm builds,
  // but they must not shadow the native helper on arm64.
  table.LoadF32x8 := @NEONLoadF32x8_ASM;
  table.LoadF32x16 := @NEONLoadF32x16_ASM;
  table.LoadF64x4 := @NEONLoadF64x4_ASM;
  table.LoadF64x8 := @NEONLoadF64x8_ASM;
  table.SplatF32x8 := @NEONSplatF32x8_ASM;
  table.SplatF32x16 := @NEONSplatF32x16_ASM;
  table.SplatF64x4 := @NEONSplatF64x4_ASM;
  table.SplatF64x8 := @NEONSplatF64x8_ASM;
  table.StoreF32x8 := @NEONStoreF32x8_ASM;
  table.StoreF32x16 := @NEONStoreF32x16_ASM;
  table.StoreF64x4 := @NEONStoreF64x4_ASM;
  table.StoreF64x8 := @NEONStoreF64x8_ASM;
  table.ZeroF32x8 := @NEONZeroF32x8_ASM;
  table.ZeroF32x16 := @NEONZeroF32x16_ASM;
  table.ZeroF64x4 := @NEONZeroF64x4_ASM;
  table.ZeroF64x8 := @NEONZeroF64x8_ASM;
  {$ENDIF}

  // Wide integer compare wrappers remain as Pascal source companions so wider
  // fallback graphs can compose narrower helpers, but published NEON slot
  // ownership is only truthful when asm is actually compiled.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CmpEqI32x16 := @NEONCmpEqI32x16;
  table.CmpEqI32x8 := @NEONCmpEqI32x8;
  table.CmpEqI64x4 := @NEONCmpEqI64x4;
  table.CmpEqI64x8 := @NEONCmpEqI64x8;
  table.CmpEqU32x8 := @NEONCmpEqU32x8;
  table.CmpEqU64x4 := @NEONCmpEqU64x4;
  table.CmpGeI32x16 := @NEONCmpGeI32x16;
  table.CmpGeI32x8 := @NEONCmpGeI32x8;
  table.CmpGeI64x4 := @NEONCmpGeI64x4;
  table.CmpGeI64x8 := @NEONCmpGeI64x8;
  table.CmpGeU32x8 := @NEONCmpGeU32x8;
  table.CmpGeU64x4 := @NEONCmpGeU64x4;
  table.CmpGtI32x16 := @NEONCmpGtI32x16;
  table.CmpGtI32x8 := @NEONCmpGtI32x8;
  table.CmpGtI64x4 := @NEONCmpGtI64x4;
  table.CmpGtI64x8 := @NEONCmpGtI64x8;
  table.CmpGtU32x8 := @NEONCmpGtU32x8;
  table.CmpGtU64x4 := @NEONCmpGtU64x4;
  table.CmpLeI32x16 := @NEONCmpLeI32x16;
  table.CmpLeI32x8 := @NEONCmpLeI32x8;
  table.CmpLeI64x4 := @NEONCmpLeI64x4;
  table.CmpLeI64x8 := @NEONCmpLeI64x8;
  table.CmpLeU32x8 := @NEONCmpLeU32x8;
  table.CmpLeU64x4 := @NEONCmpLeU64x4;
  table.CmpLtI32x16 := @NEONCmpLtI32x16;
  table.CmpLtI32x8 := @NEONCmpLtI32x8;
  table.CmpLtI64x4 := @NEONCmpLtI64x4;
  table.CmpLtI64x8 := @NEONCmpLtI64x8;
  table.CmpLtU32x8 := @NEONCmpLtU32x8;
  table.CmpLtU64x4 := @NEONCmpLtU64x4;
  table.CmpNeI32x16 := @NEONCmpNeI32x16;
  table.CmpNeI32x8 := @NEONCmpNeI32x8;
  table.CmpNeI64x4 := @NEONCmpNeI64x4;
  table.CmpNeI64x8 := @NEONCmpNeI64x8;
  table.CmpNeU32x8 := @NEONCmpNeU32x8;
  table.CmpNeU64x4 := @NEONCmpNeU64x4;
  {$ENDIF}

  {$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  // Keep no-asm integer arithmetic/bitwise/memory slots on the published
  // scalar table. The Pascal fallback wrappers remain as source companions,
  // but they should not become NEON-owned dispatch slots when NEON asm is absent.

  // === Auto-generated Registration for 100% Coverage ===
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.AddF32x16 := @NEONAddF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.AddF64x4 := @NEONAddF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.AddF64x8 := @NEONAddF64x8;
  {$ENDIF}
  // Wide integer arithmetic/bitwise families intentionally inherit
  // FillBaseDispatchTable in no-asm builds; shared wide compare wrappers are
  // registered above and should stay backend-owned.
  // Keep no-asm wide Abs/Floor/Ceil slots on the published scalar table when
  // the NEON wrappers only forward to Scalar*. The narrow F64x2 Floor/Ceil
  // wrappers no longer own any local fallback behavior, so they should only be
  // published when the real asm leaf is available.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CeilF64x2 := @NEONCeilF64x2;
  {$ENDIF}
  // Keep no-asm wide Clamp slots on the published scalar table only when the
  // wrapper is a pure F32x4 scalar-equivalent forwarder. The F64x2 Clamp loop
  // still carries local NaN/signed-zero fallback behavior, so the F64x2/F64x4/
  // F64x8 Clamp chain remains backend-owned until that behavior is retired on
  // purpose.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ClampF32x16 := @NEONClampF32x16;
  table.ClampF32x8 := @NEONClampF32x8;
  {$ENDIF}
  // F64 clamp keeps backend ownership only when a real NEON asm leaf exists.
  // The no-asm wrappers stay as source companions but should inherit base scalar slots.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ClampF64x2 := @NEONClampF64x2;
  table.ClampF64x4 := @NEONClampF64x4;
  table.ClampF64x8 := @NEONClampF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.CmpEqF64x2 := @NEONCmpEqF64x2;
  table.CmpGeF64x2 := @NEONCmpGeF64x2;
  table.CmpGtF64x2 := @NEONCmpGtF64x2;
  table.CmpLeF64x2 := @NEONCmpLeF64x2;
  table.CmpLtF64x2 := @NEONCmpLtF64x2;
  table.CmpNeF64x2 := @NEONCmpNeF64x2;
  {$ENDIF}
  // Keep no-asm wide float compare slots on the published scalar table when
  // the NEON wrappers are only scalar forwarders. The local F64x2 loops above
  // remain backend-owned because they still carry real backend-local behavior.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.DivF32x16 := @NEONDivF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.DivF64x4 := @NEONDivF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.DivF64x8 := @NEONDivF64x8;
  {$ENDIF}
  // Keep exact Scalar* extract/insert wrappers on the published scalar table
  // even in asm builds. These autowrap routines do not own backend-local behavior.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ExtractF64x2 := @NEONExtractF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.FloorF64x2 := @NEONFloorF64x2;
  {$ENDIF}
  // Keep FMA slots on the published scalar table when NEON asm is absent.
  // The no-asm helpers are exact ScalarFma* forwarders, while the asm build
  // below still owns real backend-local implementations.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.FmaF32x16 := @NEONFmaF32x16;
  table.FmaF32x8 := @NEONFmaF32x8;
  table.FmaF64x2 := @NEONFmaF64x2;
  table.FmaF64x4 := @NEONFmaF64x4;
  table.FmaF64x8 := @NEONFmaF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.InsertF64x2 := @NEONInsertF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.LoadF64x2 := @NEONLoadF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MaxF32x16 := @NEONMaxF32x16;
  table.MaxF32x8 := @NEONMaxF32x8;
  {$ENDIF}
  // Keep the narrow F64x2 Min/Max source companions for the F64x4/F64x8
  // no-asm fallback graph, but publish the base scalar slots whenever NEON
  // asm is absent because the no-asm wrappers now align exactly with Scalar*.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MaxF64x2 := @NEONMaxF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MaxF64x4 := @NEONMaxF64x4;
  table.MaxF64x8 := @NEONMaxF64x8;
  table.MinF32x16 := @NEONMinF32x16;
  table.MinF32x8 := @NEONMinF32x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MinF64x2 := @NEONMinF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MinF64x4 := @NEONMinF64x4;
  table.MinF64x8 := @NEONMinF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MulF32x16 := @NEONMulF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MulF64x4 := @NEONMulF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.MulF64x8 := @NEONMulF64x8;
  {$ENDIF}
  // Keep wide reciprocal/reduction slots on the published scalar table when
  // the NEON wrappers only forward to Scalar* helpers.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ReduceAddF64x2 := @NEONReduceAddF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ReduceMaxF64x2 := @NEONReduceMaxF64x2;
  table.ReduceMinF64x2 := @NEONReduceMinF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ReduceMulF64x2 := @NEONReduceMulF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.RoundF32x16 := @NEONRoundF32x16;
  table.RoundF32x8 := @NEONRoundF32x8;
  {$ENDIF}
  // The F64 Round/Trunc no-asm wrappers are fully dead now; only asm builds
  // should publish backend-owned bindings for these slots.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.RoundF64x2 := @NEONRoundF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.RoundF64x4 := @NEONRoundF64x4;
  table.RoundF64x8 := @NEONRoundF64x8;
  {$ENDIF}
  // Keep exact Scalar* select wrappers on the published scalar table even when
  // NEON asm is compiled. They are not backend-local owners.
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ShiftLeftI16x8 := @NEONShiftLeftI16x8;
  table.ShiftLeftU16x8 := @NEONShiftLeftU16x8;
  table.ShiftRightArithI16x8 := @NEONShiftRightArithI16x8;
  table.ShiftRightI16x8 := @NEONShiftRightI16x8;
  table.ShiftRightU16x8 := @NEONShiftRightU16x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SplatF64x2 := @NEONSplatF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SqrtF32x16 := @NEONSqrtF32x16;
  table.SqrtF32x8 := @NEONSqrtF32x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SqrtF64x2 := @NEONSqrtF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SqrtF64x4 := @NEONSqrtF64x4;
  table.SqrtF64x8 := @NEONSqrtF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.StoreF64x2 := @NEONStoreF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SubF32x16 := @NEONSubF32x16;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SubF64x4 := @NEONSubF64x4;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.SubF64x8 := @NEONSubF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.TruncF32x16 := @NEONTruncF32x16;
  table.TruncF32x8 := @NEONTruncF32x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.TruncF64x2 := @NEONTruncF64x2;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.TruncF64x4 := @NEONTruncF64x4;
  table.TruncF64x8 := @NEONTruncF64x8;
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.ZeroF64x2 := @NEONZeroF64x2;
  {$ENDIF}
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
  table.AndNotI8x16 := @NEONAndNotI8x16;
  table.AndNotU16x8 := @NEONAndNotU16x8;
  table.AndNotU8x16 := @NEONAndNotU8x16;
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
