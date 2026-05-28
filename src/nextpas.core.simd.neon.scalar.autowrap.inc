// === Auto-generated NEON Wrapper Functions (Scalar Fallback) ===
// These wrappers delegate to scalar implementations for 100% coverage

function NEONAddF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result.lo.lo := NEONAddF32x4(a.lo.lo, b.lo.lo);
  Result.lo.hi := NEONAddF32x4(a.lo.hi, b.lo.hi);
  Result.hi.lo := NEONAddF32x4(a.hi.lo, b.hi.lo);
  Result.hi.hi := NEONAddF32x4(a.hi.hi, b.hi.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONAddF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONAddF64x2(a.lo, b.lo);
  Result.hi := NEONAddF64x2(a.hi, b.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONAddF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONAddF64x4(a.lo, b.lo);
  Result.hi := NEONAddF64x4(a.hi, b.hi);
end;

function NEONAddI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarAddI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONAddI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarAddI32x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONAddI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarAddI64x4(a, b);
end;

function NEONAddI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarAddI64x8(a, b);
end;

// Wide fallback-only integer families intentionally inherit the published
// scalar slots until NEON owns real implementations for these widths.

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONAddU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarAddU32x4(a, b);
end;

function NEONAddU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarAddU32x8(a, b);
end;

function NEONAddU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarAddU64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONAndI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarAndI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONAndI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarAndI32x4(a, b);
end;

function NEONAndI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarAndI32x8(a, b);
end;

function NEONAndI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarAndI64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONAndI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarAndI64x8(a, b);
end;

function NEONAndNotI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarAndNotI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONAndNotI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarAndNotI32x4(a, b);
end;

function NEONAndNotI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarAndNotI32x8(a, b);
end;

function NEONAndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarAndNotI64x4(a, b);
end;

function NEONAndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarAndNotU32x4(a, b);
end;

function NEONAndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarAndNotU32x8(a, b);
end;

function NEONAndU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarAndU32x4(a, b);
end;

function NEONAndU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarAndU32x8(a, b);
end;

function NEONAndU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarAndU64x4(a, b);
end;

function NEONClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
var i: Integer;
begin
  for i := 0 to 1 do
  begin
    if a.d[i] < minVal.d[i] then
      Result.d[i] := minVal.d[i]
    else if a.d[i] > maxVal.d[i] then
      Result.d[i] := maxVal.d[i]
    else
      Result.d[i] := a.d[i];
  end;
end;

function NEONClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONClampF64x2(a.lo, minVal.lo, maxVal.lo);
  Result.hi := NEONClampF64x2(a.hi, minVal.hi, maxVal.hi);
end;

function NEONClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONClampF64x4(a.lo, minVal.lo, maxVal.lo);
  Result.hi := NEONClampF64x4(a.hi, minVal.hi, maxVal.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCombineMask2To4(const aLo, aHi: TMask2): TMask4; inline;
begin
  Result := TMask4((Byte(aLo) and $03) or ((Byte(aHi) and $03) shl 2));
end;

function NEONCombineMask4To8(const aLo, aHi: TMask4): TMask8; inline;
begin
  Result := TMask8((Byte(aLo) and $0F) or ((Byte(aHi) and $0F) shl 4));
end;

function NEONCombineMask8To16(const aLo, aHi: TMask8): TMask16; inline;
begin
  Result := TMask16((Word(aLo) and $00FF) or ((Word(aHi) and $00FF) shl 8));
end;

function NEONCmpEqU32x4(const a, b: TVecU32x4): TMask4; forward;

function NEONCmpEqI32x8(const a, b: TVecI32x8): TMask8; forward;
function NEONCmpGeI32x8(const a, b: TVecI32x8): TMask8; forward;
function NEONCmpGtI32x8(const a, b: TVecI32x8): TMask8; forward;
function NEONCmpLeI32x8(const a, b: TVecI32x8): TMask8; forward;
function NEONCmpLtI32x8(const a, b: TVecI32x8): TMask8; forward;
function NEONCmpNeI32x8(const a, b: TVecI32x8): TMask8; forward;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpEqI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpEqI16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpEqI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := NEONCombineMask8To16(NEONCmpEqI32x8(a.lo, b.lo), NEONCmpEqI32x8(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpEqI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := ScalarCmpEqI32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpEqI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpEqI32x4(a.lo, b.lo), NEONCmpEqI32x4(a.hi, b.hi));
end;

function NEONCmpEqI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpEqI64x2(a.lo, b.lo), NEONCmpEqI64x2(a.hi, b.hi));
end;

function NEONCmpEqI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpEqI64x4(a.lo, b.lo), NEONCmpEqI64x4(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpEqI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpEqI8x16(a, b);
end;

function NEONCmpEqU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpEqU16x8(a, b);
end;

function NEONCmpEqU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpEqU32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpEqU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpEqU32x4(a.lo, b.lo), NEONCmpEqU32x4(a.hi, b.hi));
end;

function NEONCmpEqU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpEqU64x2(a.lo, b.lo), NEONCmpEqU64x2(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpEqU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpEqU8x16(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpGeI16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpGeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := NEONCombineMask8To16(NEONCmpGeI32x8(a.lo, b.lo), NEONCmpGeI32x8(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := ScalarCmpGeI32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpGeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpGeI32x4(a.lo, b.lo), NEONCmpGeI32x4(a.hi, b.hi));
end;

function NEONCmpGeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpGeI64x2(a.lo, b.lo), NEONCmpGeI64x2(a.hi, b.hi));
end;

function NEONCmpGeI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpGeI64x4(a.lo, b.lo), NEONCmpGeI64x4(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpGeI8x16(a, b);
end;

function NEONCmpGeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpGeU16x8(a, b);
end;

function NEONCmpGeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpGeU32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpGeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpGeU32x4(a.lo, b.lo), NEONCmpGeU32x4(a.hi, b.hi));
end;

function NEONCmpGeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := NEONCombineMask2To4(
    TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpLtU64x2(a.lo, b.lo))),
    TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpLtU64x2(a.hi, b.hi))));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpGeU8x16(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGtI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpGtI16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpGtI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := NEONCombineMask8To16(NEONCmpGtI32x8(a.lo, b.lo), NEONCmpGtI32x8(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGtI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := ScalarCmpGtI32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpGtI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpGtI32x4(a.lo, b.lo), NEONCmpGtI32x4(a.hi, b.hi));
end;

function NEONCmpGtI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpGtI64x2(a.lo, b.lo), NEONCmpGtI64x2(a.hi, b.hi));
end;

function NEONCmpGtI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpGtI64x4(a.lo, b.lo), NEONCmpGtI64x4(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGtI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpGtI8x16(a, b);
end;

function NEONCmpGtU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpGtU16x8(a, b);
end;

function NEONCmpGtU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpGtU32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpGtU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpGtU32x4(a.lo, b.lo), NEONCmpGtU32x4(a.hi, b.hi));
end;

function NEONCmpGtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpGtU64x2(a.lo, b.lo), NEONCmpGtU64x2(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpGtU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpGtU8x16(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpLeI16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpLeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := NEONCombineMask8To16(NEONCmpLeI32x8(a.lo, b.lo), NEONCmpLeI32x8(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := ScalarCmpLeI32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpLeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpLeI32x4(a.lo, b.lo), NEONCmpLeI32x4(a.hi, b.hi));
end;

function NEONCmpLeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpLeI64x2(a.lo, b.lo), NEONCmpLeI64x2(a.hi, b.hi));
end;

function NEONCmpLeI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpLeI64x4(a.lo, b.lo), NEONCmpLeI64x4(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpLeI8x16(a, b);
end;

function NEONCmpLeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpLeU16x8(a, b);
end;

function NEONCmpLeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpLeU32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpLeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpLeU32x4(a.lo, b.lo), NEONCmpLeU32x4(a.hi, b.hi));
end;

function NEONCmpLeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := NEONCombineMask2To4(
    TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpGtU64x2(a.lo, b.lo))),
    TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpGtU64x2(a.hi, b.hi))));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpLeU8x16(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLtI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpLtI16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpLtI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := NEONCombineMask8To16(NEONCmpLtI32x8(a.lo, b.lo), NEONCmpLtI32x8(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLtI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := ScalarCmpLtI32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpLtI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpLtI32x4(a.lo, b.lo), NEONCmpLtI32x4(a.hi, b.hi));
end;

function NEONCmpLtI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpLtI64x2(a.lo, b.lo), NEONCmpLtI64x2(a.hi, b.hi));
end;

function NEONCmpLtI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpLtI64x4(a.lo, b.lo), NEONCmpLtI64x4(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLtI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpLtI8x16(a, b);
end;

function NEONCmpLtU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpLtU16x8(a, b);
end;

function NEONCmpLtU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpLtU32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpLtU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpLtU32x4(a.lo, b.lo), NEONCmpLtU32x4(a.hi, b.hi));
end;

function NEONCmpLtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpLtU64x2(a.lo, b.lo), NEONCmpLtU64x2(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpLtU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpLtU8x16(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpNeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpNeI16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpNeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := NEONCombineMask8To16(NEONCmpNeI32x8(a.lo, b.lo), NEONCmpNeI32x8(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpNeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := ScalarCmpNeI32x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpNeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpNeI32x4(a.lo, b.lo), NEONCmpNeI32x4(a.hi, b.hi));
end;

function NEONCmpNeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := NEONCombineMask2To4(NEONCmpNeI64x2(a.lo, b.lo), NEONCmpNeI64x2(a.hi, b.hi));
end;

function NEONCmpNeI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := NEONCombineMask4To8(NEONCmpNeI64x4(a.lo, b.lo), NEONCmpNeI64x4(a.hi, b.hi));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpNeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpNeI8x16(a, b);
end;

function NEONCmpNeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpNeU16x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONCmpNeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := NEONCombineMask4To8(
    TMask4(Byte(MASK4_ALL_SET) xor Byte(NEONCmpEqU32x4(a.lo, b.lo))),
    TMask4(Byte(MASK4_ALL_SET) xor Byte(NEONCmpEqU32x4(a.hi, b.hi))));
end;

function NEONCmpNeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := NEONCombineMask2To4(
    TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpEqU64x2(a.lo, b.lo))),
    TMask2(Byte(MASK2_ALL_SET) xor Byte(NEONCmpEqU64x2(a.hi, b.hi))));
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONCmpNeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpNeU8x16(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONDivF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result.lo.lo := NEONDivF32x4(a.lo.lo, b.lo.lo);
  Result.lo.hi := NEONDivF32x4(a.lo.hi, b.lo.hi);
  Result.hi.lo := NEONDivF32x4(a.hi.lo, b.hi.lo);
  Result.hi.hi := NEONDivF32x4(a.hi.hi, b.hi.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONDivF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONDivF64x2(a.lo, b.lo);
  Result.hi := NEONDivF64x2(a.hi, b.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONDivF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONDivF64x4(a.lo, b.lo);
  Result.hi := NEONDivF64x4(a.hi, b.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONExtractF64x2(const a: TVecF64x2; index: Integer): Double;
begin
  Result := ScalarExtractF64x2(a, index);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
begin
  Result := ScalarExtractI32x16(a, index);
end;

function NEONExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
begin
  Result := ScalarExtractI32x8(a, index);
end;

function NEONExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
begin
  Result := ScalarExtractI64x4(a, index);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
begin
  Result := ScalarInsertF64x2(a, value, index);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONInsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
begin
  Result := ScalarInsertI32x16(a, value, index);
end;

function NEONInsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
begin
  Result := ScalarInsertI32x8(a, value, index);
end;

function NEONInsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
begin
  Result := ScalarInsertI64x4(a, value, index);
end;

function NEONLoadI64x4(p: PInt64): TVecI64x4;
begin
  Result := ScalarLoadI64x4(p);
end;

function NEONMaxF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result.lo.lo := NEONMaxF32x4(a.lo.lo, b.lo.lo);
  Result.lo.hi := NEONMaxF32x4(a.lo.hi, b.lo.hi);
  Result.hi.lo := NEONMaxF32x4(a.hi.lo, b.hi.lo);
  Result.hi.hi := NEONMaxF32x4(a.hi.hi, b.hi.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONMaxF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarMaxF64x2(a, b);
end;

function NEONMaxF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONMaxF64x2(a.lo, b.lo);
  Result.hi := NEONMaxF64x2(a.hi, b.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONMaxF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONMaxF64x4(a.lo, b.lo);
  Result.hi := NEONMaxF64x4(a.hi, b.hi);
end;

function NEONMaxI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarMaxI32x16(a, b);
end;

function NEONMaxI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarMaxI32x4(a, b);
end;

function NEONMaxI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarMaxI32x8(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONMaxU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarMaxU32x4(a, b);
end;

function NEONMaxU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarMaxU32x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONMinF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result.lo.lo := NEONMinF32x4(a.lo.lo, b.lo.lo);
  Result.lo.hi := NEONMinF32x4(a.lo.hi, b.lo.hi);
  Result.hi.lo := NEONMinF32x4(a.hi.lo, b.hi.lo);
  Result.hi.hi := NEONMinF32x4(a.hi.hi, b.hi.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONMinF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result := ScalarMinF64x2(a, b);
end;

function NEONMinF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONMinF64x2(a.lo, b.lo);
  Result.hi := NEONMinF64x2(a.hi, b.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONMinF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONMinF64x4(a.lo, b.lo);
  Result.hi := NEONMinF64x4(a.hi, b.hi);
end;

function NEONMinI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarMinI32x16(a, b);
end;

function NEONMinI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarMinI32x4(a, b);
end;

function NEONMinI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarMinI32x8(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONMinU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarMinU32x4(a, b);
end;

function NEONMinU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarMinU32x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONMulF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result.lo.lo := NEONMulF32x4(a.lo.lo, b.lo.lo);
  Result.lo.hi := NEONMulF32x4(a.lo.hi, b.lo.hi);
  Result.hi.lo := NEONMulF32x4(a.hi.lo, b.hi.lo);
  Result.hi.hi := NEONMulF32x4(a.hi.hi, b.hi.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONMulF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONMulF64x2(a.lo, b.lo);
  Result.hi := NEONMulF64x2(a.hi, b.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONMulF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONMulF64x4(a.lo, b.lo);
  Result.hi := NEONMulF64x4(a.hi, b.hi);
end;

function NEONMulI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarMulI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONMulI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarMulI32x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONMulU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarMulU32x4(a, b);
end;

function NEONMulU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarMulU32x8(a, b);
end;

function NEONNotI32x16(const a: TVecI32x16): TVecI32x16;
begin
  Result := ScalarNotI32x16(a);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONNotI32x4(const a: TVecI32x4): TVecI32x4;
begin
  Result := ScalarNotI32x4(a);
end;

function NEONNotI32x8(const a: TVecI32x8): TVecI32x8;
begin
  Result := ScalarNotI32x8(a);
end;

function NEONNotI64x4(const a: TVecI64x4): TVecI64x4;
begin
  Result := ScalarNotI64x4(a);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONNotI64x8(const a: TVecI64x8): TVecI64x8;
begin
  Result := ScalarNotI64x8(a);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONNotU32x4(const a: TVecU32x4): TVecU32x4;
begin
  Result := ScalarNotU32x4(a);
end;

function NEONNotU32x8(const a: TVecU32x8): TVecU32x8;
begin
  Result := ScalarNotU32x8(a);
end;

function NEONNotU64x4(const a: TVecU64x4): TVecU64x4;
begin
  Result := ScalarNotU64x4(a);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONOrI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarOrI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONOrI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarOrI32x4(a, b);
end;

function NEONOrI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarOrI32x8(a, b);
end;

function NEONOrI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarOrI64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONOrI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarOrI64x8(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONOrU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarOrU32x4(a, b);
end;

function NEONOrU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarOrU32x8(a, b);
end;

function NEONOrU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarOrU64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  Result := ScalarShiftLeftI32x16(a, count);
end;

function NEONShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  Result := ScalarShiftLeftI32x4(a, count);
end;

function NEONShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  Result := ScalarShiftLeftI32x8(a, count);
end;

function NEONShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  Result := ScalarShiftLeftI64x4(a, count);
end;

function NEONShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
begin
  Result := ScalarShiftLeftU32x4(a, count);
end;

function NEONShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  Result := ScalarShiftLeftU32x8(a, count);
end;

function NEONShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  Result := ScalarShiftLeftU64x4(a, count);
end;

function NEONShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  Result := ScalarShiftRightArithI32x16(a, count);
end;

function NEONShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  Result := ScalarShiftRightArithI32x4(a, count);
end;

function NEONShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  Result := ScalarShiftRightArithI32x8(a, count);
end;

function NEONShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  Result := ScalarShiftRightI32x16(a, count);
end;

function NEONShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  Result := ScalarShiftRightI32x4(a, count);
end;

function NEONShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  Result := ScalarShiftRightI32x8(a, count);
end;

function NEONShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  Result := ScalarShiftRightI64x4(a, count);
end;

function NEONShiftRightArithI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  Result := ScalarShiftRightArithI64x4(a, count);
end;

function NEONShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
begin
  Result := ScalarShiftRightU32x4(a, count);
end;

function NEONShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  Result := ScalarShiftRightU32x8(a, count);
end;

function NEONShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  Result := ScalarShiftRightU64x4(a, count);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONSplatI64x4(value: Int64): TVecI64x4;
begin
  Result := ScalarSplatI64x4(value);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}
{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

procedure NEONStoreI64x4(p: PInt64; const a: TVecI64x4);
begin
  ScalarStoreI64x4(p, a);
end;

function NEONSubF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result.lo.lo := NEONSubF32x4(a.lo.lo, b.lo.lo);
  Result.lo.hi := NEONSubF32x4(a.lo.hi, b.lo.hi);
  Result.hi.lo := NEONSubF32x4(a.hi.lo, b.hi.lo);
  Result.hi.hi := NEONSubF32x4(a.hi.hi, b.hi.hi);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONSubF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result.lo := NEONSubF64x2(a.lo, b.lo);
  Result.hi := NEONSubF64x2(a.hi, b.hi);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONSubF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result.lo := NEONSubF64x4(a.lo, b.lo);
  Result.hi := NEONSubF64x4(a.hi, b.hi);
end;

function NEONSubI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarSubI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONSubI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarSubI32x8(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONSubI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarSubI64x4(a, b);
end;

function NEONSubI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarSubI64x8(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONSubU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarSubU32x4(a, b);
end;

function NEONSubU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarSubU32x8(a, b);
end;

function NEONSubU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarSubU64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONXorI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarXorI32x16(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONXorI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  Result := ScalarXorI32x4(a, b);
end;

function NEONXorI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarXorI32x8(a, b);
end;

function NEONXorI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarXorI64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONXorI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarXorI64x8(a, b);
end;

{$IFNDEF NEXTPAS_SIMD_NEON_ASM_ENABLED}

function NEONXorU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarXorU32x4(a, b);
end;

function NEONXorU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarXorU32x8(a, b);
end;

function NEONXorU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarXorU64x4(a, b);
end;

{$ENDIF} // NEXTPAS_SIMD_NEON_ASM_ENABLED

function NEONZeroI64x4: TVecI64x4;
begin
  Result := ScalarZeroI64x4;
end;
