// === Scalar Fallback ===
// Used when:
// - not CPUAARCH64, or
// - CPUAARCH64 but NEXTPAS_SIMD_NEON_ASM is not enabled, or
// - SIMD_VECTOR_ASM_DISABLED is defined.

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONAddF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarAddF32x4(a, b);
end;

function NEONSubF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarSubF32x4(a, b);
end;

function NEONMulF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarMulF32x4(a, b);
end;

function NEONDivF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarDivF32x4(a, b);
end;

function NEONAddF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarAddF64x2(a, b);
end;

function NEONSubF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarSubF64x2(a, b);
end;

function NEONMulF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarMulF64x2(a, b);
end;

function NEONDivF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarDivF64x2(a, b);
end;

// Integer SIMD operations must wrap on overflow (hardware semantics).
{$PUSH}{$R-}{$Q-}
function NEONAddI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarAddI32x4(a, b);
end;

function NEONSubI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarSubI32x4(a, b);
end;

function NEONMulI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarMulI32x4(a, b);
end;
{$POP}

{$I nextpas.core.simd.neon.scalar.compare.inc}

{$I nextpas.core.simd.neon.scalar.math.inc}

{$I nextpas.core.simd.neon.scalar.ext_math.inc}

{$I nextpas.core.simd.neon.scalar.vector_math.inc}

{$I nextpas.core.simd.neon.scalar.reduction.inc}

{$I nextpas.core.simd.neon.scalar.memory.inc}

{$I nextpas.core.simd.neon.scalar.utility.inc}

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED
