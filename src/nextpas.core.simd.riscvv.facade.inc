// =============================================================
// Facade Function Implementations
// =============================================================
// Legacy dead facade wrappers removed: dispatch now reuses the canonical
// base scalar slots directly for mem/text/bitset helpers.

{$IFNDEF RISCVV_ASSEMBLY}

// =============================================================
// Scalar Fallback Implementations
// =============================================================
// Used when RISC-V V extension is not available

// =============================================================
// F32x4 Operations (128-bit, 4x Single)
// =============================================================

// =============================================================
// F64x2 Operations (128-bit, 2x Double)
// =============================================================

// =============================================================
// Common Implementations (both assembly and scalar paths)
// =============================================================

// =============================================================
// F32x4 Extended Math Operations
// =============================================================

// =============================================================
// F32x4 Comparison Operations
// =============================================================

function RISCVVCmpEqF32x4(const a, b: TVecF32x4): TMask4;
begin
  Result := ScalarCmpEqF32x4(a, b);
end;

function RISCVVCmpLtF32x4(const a, b: TVecF32x4): TMask4;
begin
  Result := ScalarCmpLtF32x4(a, b);
end;

function RISCVVCmpLeF32x4(const a, b: TVecF32x4): TMask4;
begin
  Result := ScalarCmpLeF32x4(a, b);
end;

function RISCVVCmpGtF32x4(const a, b: TVecF32x4): TMask4;
begin
  Result := ScalarCmpGtF32x4(a, b);
end;

function RISCVVCmpGeF32x4(const a, b: TVecF32x4): TMask4;
begin
  Result := ScalarCmpGeF32x4(a, b);
end;

function RISCVVCmpNeF32x4(const a, b: TVecF32x4): TMask4;
begin
  Result := ScalarCmpNeF32x4(a, b);
end;

// =============================================================
// F32x4 Vector Math Operations
// =============================================================

function RISCVVDotF32x4(const a, b: TVecF32x4): Single;
begin
  Result := ScalarDotF32x4(a, b);
end;

function RISCVVDotF32x3(const a, b: TVecF32x4): Single;
begin
  Result := ScalarDotF32x3(a, b);
end;

function RISCVVLengthF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarLengthF32x4(a);
end;

function RISCVVLengthF32x3(const a: TVecF32x4): Single;
begin
  Result := ScalarLengthF32x3(a);
end;

// =============================================================
// F32x4 Reduction Operations
// =============================================================

function RISCVVReduceAddF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarReduceAddF32x4(a);
end;

function RISCVVReduceMinF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarReduceMinF32x4(a);
end;

function RISCVVReduceMaxF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarReduceMaxF32x4(a);
end;

function RISCVVReduceMulF32x4(const a: TVecF32x4): Single;
begin
  Result := ScalarReduceMulF32x4(a);
end;

// =============================================================
// F32x4 Memory Operations
// =============================================================

procedure RISCVVStoreF32x4(p: PSingle; const a: TVecF32x4);
begin
  ScalarStoreF32x4(p, a);
end;

procedure RISCVVStoreF32x4Aligned(p: PSingle; const a: TVecF32x4);
begin
  ScalarStoreF32x4Aligned(p, a);
end;

// =============================================================
// F32x4 Utility Operations
// =============================================================

function RISCVVExtractF32x4(const a: TVecF32x4; index: Integer): Single;
begin
  Result := ScalarExtractF32x4(a, index);
end;

// =============================================================
// F32x8 Operations (256-bit, 8x Single)
// =============================================================

function RISCVVAddF32x8(const a, b: TVecF32x8): TVecF32x8;
begin
  Result := ScalarAddF32x8(a, b);
end;

function RISCVVSubF32x8(const a, b: TVecF32x8): TVecF32x8;
begin
  Result := ScalarSubF32x8(a, b);
end;

function RISCVVMulF32x8(const a, b: TVecF32x8): TVecF32x8;
begin
  Result := ScalarMulF32x8(a, b);
end;

function RISCVVDivF32x8(const a, b: TVecF32x8): TVecF32x8;
begin
  Result := ScalarDivF32x8(a, b);
end;

// =============================================================
// F64x4 Operations (256-bit, 4x Double)
// =============================================================

function RISCVVAddF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result := ScalarAddF64x4(a, b);
end;

function RISCVVSubF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result := ScalarSubF64x4(a, b);
end;

function RISCVVMulF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result := ScalarMulF64x4(a, b);
end;

function RISCVVDivF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result := ScalarDivF64x4(a, b);
end;

// =============================================================
// I32x8 Operations (256-bit, 8x Int32)
// =============================================================
// Non-asm builds still expose these backend-owned symbols so register.inc can
// keep stable slot ownership without lying about scalar-reuse families.

function RISCVVAddI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarAddI32x8(a, b);
end;

function RISCVVSubI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarSubI32x8(a, b);
end;

function RISCVVMulI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarMulI32x8(a, b);
end;

function RISCVVAndI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarAndI32x8(a, b);
end;

function RISCVVOrI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarOrI32x8(a, b);
end;

function RISCVVXorI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarXorI32x8(a, b);
end;

function RISCVVNotI32x8(const a: TVecI32x8): TVecI32x8;
begin
  Result := ScalarNotI32x8(a);
end;

function RISCVVAndNotI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarAndNotI32x8(a, b);
end;

function RISCVVShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  Result := ScalarShiftLeftI32x8(a, count);
end;

function RISCVVShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  Result := ScalarShiftRightI32x8(a, count);
end;

function RISCVVShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  Result := ScalarShiftRightArithI32x8(a, count);
end;

function RISCVVCmpEqI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := ScalarCmpEqI32x8(a, b);
end;

function RISCVVCmpLtI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := ScalarCmpLtI32x8(a, b);
end;

function RISCVVCmpGtI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := ScalarCmpGtI32x8(a, b);
end;

function RISCVVCmpLeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := ScalarCmpLeI32x8(a, b);
end;

function RISCVVCmpGeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := ScalarCmpGeI32x8(a, b);
end;

function RISCVVCmpNeI32x8(const a, b: TVecI32x8): TMask8;
begin
  Result := ScalarCmpNeI32x8(a, b);
end;

function RISCVVMinI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarMinI32x8(a, b);
end;

function RISCVVMaxI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result := ScalarMaxI32x8(a, b);
end;

// =============================================================
// I32x16 Operations (512-bit, 16x Int32)
// =============================================================
// This facade block mirrors the backend-owned wide integer surface for
// non-asm builds only; it is not evidence that the 512-bit path is scalar-reuse.

function RISCVVAddI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarAddI32x16(a, b);
end;

function RISCVVSubI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarSubI32x16(a, b);
end;

function RISCVVMulI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarMulI32x16(a, b);
end;

function RISCVVAndI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarAndI32x16(a, b);
end;

function RISCVVOrI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarOrI32x16(a, b);
end;

function RISCVVXorI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarXorI32x16(a, b);
end;

function RISCVVNotI32x16(const a: TVecI32x16): TVecI32x16;
begin
  Result := ScalarNotI32x16(a);
end;

function RISCVVAndNotI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarAndNotI32x16(a, b);
end;

function RISCVVShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  Result := ScalarShiftLeftI32x16(a, count);
end;

function RISCVVShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  Result := ScalarShiftRightI32x16(a, count);
end;

function RISCVVShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  Result := ScalarShiftRightArithI32x16(a, count);
end;

function RISCVVCmpEqI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := ScalarCmpEqI32x16(a, b);
end;

function RISCVVCmpLtI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := ScalarCmpLtI32x16(a, b);
end;

function RISCVVCmpGtI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := ScalarCmpGtI32x16(a, b);
end;

function RISCVVCmpLeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := ScalarCmpLeI32x16(a, b);
end;

function RISCVVCmpGeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := ScalarCmpGeI32x16(a, b);
end;

function RISCVVCmpNeI32x16(const a, b: TVecI32x16): TMask16;
begin
  Result := ScalarCmpNeI32x16(a, b);
end;

function RISCVVMinI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarMinI32x16(a, b);
end;

function RISCVVMaxI32x16(const a, b: TVecI32x16): TVecI32x16;
begin
  Result := ScalarMaxI32x16(a, b);
end;

// =============================================================
// F32x16 Operations (512-bit, 16x Single)
// =============================================================

function RISCVVAddF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarAddF32x16(a, b);
end;

function RISCVVSubF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarSubF32x16(a, b);
end;

function RISCVVMulF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarMulF32x16(a, b);
end;

function RISCVVDivF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarDivF32x16(a, b);
end;

// =============================================================
// F64x8 Operations (512-bit, 8x Double)
// =============================================================

function RISCVVAddF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarAddF64x8(a, b);
end;

function RISCVVSubF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarSubF64x8(a, b);
end;

function RISCVVMulF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarMulF64x8(a, b);
end;

function RISCVVDivF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarDivF64x8(a, b);
end;

// =============================================================
// F32x8 Comparison Operations (256-bit, 8x Single)
// =============================================================

function RISCVVCmpEqF32x8(const a, b: TVecF32x8): TMask8;
begin
  Result := ScalarCmpEqF32x8(a, b);
end;

function RISCVVCmpLtF32x8(const a, b: TVecF32x8): TMask8;
begin
  Result := ScalarCmpLtF32x8(a, b);
end;

function RISCVVCmpLeF32x8(const a, b: TVecF32x8): TMask8;
begin
  Result := ScalarCmpLeF32x8(a, b);
end;

function RISCVVCmpGtF32x8(const a, b: TVecF32x8): TMask8;
begin
  Result := ScalarCmpGtF32x8(a, b);
end;

function RISCVVCmpGeF32x8(const a, b: TVecF32x8): TMask8;
begin
  Result := ScalarCmpGeF32x8(a, b);
end;

function RISCVVCmpNeF32x8(const a, b: TVecF32x8): TMask8;
begin
  Result := ScalarCmpNeF32x8(a, b);
end;

// =============================================================
// F64x4 Comparison Operations (256-bit, 4x Double)
// =============================================================

function RISCVVCmpEqF64x4(const a, b: TVecF64x4): TMask4;
begin
  Result := ScalarCmpEqF64x4(a, b);
end;

function RISCVVCmpLtF64x4(const a, b: TVecF64x4): TMask4;
begin
  Result := ScalarCmpLtF64x4(a, b);
end;

function RISCVVCmpLeF64x4(const a, b: TVecF64x4): TMask4;
begin
  Result := ScalarCmpLeF64x4(a, b);
end;

function RISCVVCmpGtF64x4(const a, b: TVecF64x4): TMask4;
begin
  Result := ScalarCmpGtF64x4(a, b);
end;

function RISCVVCmpGeF64x4(const a, b: TVecF64x4): TMask4;
begin
  Result := ScalarCmpGeF64x4(a, b);
end;

function RISCVVCmpNeF64x4(const a, b: TVecF64x4): TMask4;
begin
  Result := ScalarCmpNeF64x4(a, b);
end;

// =============================================================
// F64x8 Comparison Operations (512-bit, 8x Double)
// =============================================================

function RISCVVCmpEqF64x8(const a, b: TVecF64x8): TMask8;
begin
  Result := ScalarCmpEqF64x8(a, b);
end;

function RISCVVCmpLtF64x8(const a, b: TVecF64x8): TMask8;
begin
  Result := ScalarCmpLtF64x8(a, b);
end;

function RISCVVCmpLeF64x8(const a, b: TVecF64x8): TMask8;
begin
  Result := ScalarCmpLeF64x8(a, b);
end;

function RISCVVCmpGtF64x8(const a, b: TVecF64x8): TMask8;
begin
  Result := ScalarCmpGtF64x8(a, b);
end;

function RISCVVCmpGeF64x8(const a, b: TVecF64x8): TMask8;
begin
  Result := ScalarCmpGeF64x8(a, b);
end;

function RISCVVCmpNeF64x8(const a, b: TVecF64x8): TMask8;
begin
  Result := ScalarCmpNeF64x8(a, b);
end;

// =============================================================
// F32x16 Comparison Operations (512-bit, 16x Single)
// =============================================================

function RISCVVCmpEqF32x16(const a, b: TVecF32x16): TMask16;
begin
  Result := ScalarCmpEqF32x16(a, b);
end;

function RISCVVCmpLtF32x16(const a, b: TVecF32x16): TMask16;
begin
  Result := ScalarCmpLtF32x16(a, b);
end;

function RISCVVCmpLeF32x16(const a, b: TVecF32x16): TMask16;
begin
  Result := ScalarCmpLeF32x16(a, b);
end;

function RISCVVCmpGtF32x16(const a, b: TVecF32x16): TMask16;
begin
  Result := ScalarCmpGtF32x16(a, b);
end;

function RISCVVCmpGeF32x16(const a, b: TVecF32x16): TMask16;
begin
  Result := ScalarCmpGeF32x16(a, b);
end;

function RISCVVCmpNeF32x16(const a, b: TVecF32x16): TMask16;
begin
  Result := ScalarCmpNeF32x16(a, b);
end;

// =============================================================
// TMask4 Operations (4 有效位)
// =============================================================

function RISCVVMask4All(mask: TMask4): Boolean;
begin
  Result := ScalarMask4All(mask);
end;

function RISCVVMask4Any(mask: TMask4): Boolean;
begin
  Result := ScalarMask4Any(mask);
end;

function RISCVVMask4None(mask: TMask4): Boolean;
begin
  Result := ScalarMask4None(mask);
end;

function RISCVVMask4PopCount(mask: TMask4): Integer;
begin
  Result := ScalarMask4PopCount(mask);
end;

function RISCVVMask4FirstSet(mask: TMask4): Integer;
begin
  Result := ScalarMask4FirstSet(mask);
end;

// =============================================================
// TMask8 Operations (8 有效位)
// =============================================================

function RISCVVMask8All(mask: TMask8): Boolean;
begin
  Result := ScalarMask8All(mask);
end;

function RISCVVMask8Any(mask: TMask8): Boolean;
begin
  Result := ScalarMask8Any(mask);
end;

function RISCVVMask8None(mask: TMask8): Boolean;
begin
  Result := ScalarMask8None(mask);
end;

function RISCVVMask8PopCount(mask: TMask8): Integer;
begin
  Result := ScalarMask8PopCount(mask);
end;

function RISCVVMask8FirstSet(mask: TMask8): Integer;
begin
  Result := ScalarMask8FirstSet(mask);
end;

// =============================================================
// TMask16 Operations (16 有效位)
// =============================================================

function RISCVVMask16All(mask: TMask16): Boolean;
begin
  Result := ScalarMask16All(mask);
end;

function RISCVVMask16Any(mask: TMask16): Boolean;
begin
  Result := ScalarMask16Any(mask);
end;

function RISCVVMask16None(mask: TMask16): Boolean;
begin
  Result := ScalarMask16None(mask);
end;

function RISCVVMask16PopCount(mask: TMask16): Integer;
begin
  Result := ScalarMask16PopCount(mask);
end;

function RISCVVMask16FirstSet(mask: TMask16): Integer;
begin
  Result := ScalarMask16FirstSet(mask);
end;

// =============================================================
// Mask Logical Operations (TMask4)
// =============================================================

function RISCVVMask4And(a, b: TMask4): TMask4;
begin
  Result := (a and b) and $0F;
end;

function RISCVVMask4Or(a, b: TMask4): TMask4;
begin
  Result := (a or b) and $0F;
end;

function RISCVVMask4Xor(a, b: TMask4): TMask4;
begin
  Result := (a xor b) and $0F;
end;

function RISCVVMask4Not(a: TMask4): TMask4;
begin
  Result := (not a) and $0F;
end;

// =============================================================
// Mask Logical Operations (TMask8)
// =============================================================

function RISCVVMask8And(a, b: TMask8): TMask8;
begin
  Result := a and b;
end;

function RISCVVMask8Or(a, b: TMask8): TMask8;
begin
  Result := a or b;
end;

function RISCVVMask8Xor(a, b: TMask8): TMask8;
begin
  Result := a xor b;
end;

function RISCVVMask8Not(a: TMask8): TMask8;
begin
  Result := not a;
end;

// =============================================================
// Mask Logical Operations (TMask16)
// =============================================================

function RISCVVMask16And(a, b: TMask16): TMask16;
begin
  Result := a and b;
end;

function RISCVVMask16Or(a, b: TMask16): TMask16;
begin
  Result := a or b;
end;

function RISCVVMask16Xor(a, b: TMask16): TMask16;
begin
  Result := a xor b;
end;

function RISCVVMask16Not(a: TMask16): TMask16;
begin
  Result := not a;
end;

// =============================================================
// F32x16 Select Operation
// =============================================================

function RISCVVSelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarSelectF32x16(mask, a, b);
end;

// =============================================================
// F64x8 Select Operation
// =============================================================

function RISCVVSelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarSelectF64x8(mask, a, b);
end;

// =============================================================
// Additional Operations for 100% Coverage
// =============================================================
// Generated implementations for missing operations
// =============================================================

function RISCVVMask2All(mask: TMask2): Boolean;
begin
  Result := ScalarMask2All(mask);
end;

function RISCVVMask2Any(mask: TMask2): Boolean;
begin
  Result := ScalarMask2Any(mask);
end;

function RISCVVMask2None(mask: TMask2): Boolean;
begin
  Result := ScalarMask2None(mask);
end;

function RISCVVMask2PopCount(mask: TMask2): Integer;
begin
  Result := ScalarMask2PopCount(mask);
end;

function RISCVVMask2FirstSet(mask: TMask2): Integer;
begin
  Result := ScalarMask2FirstSet(mask);
end;

function RISCVVAbsF32x16(const a: TVecF32x16): TVecF32x16;
begin
  Result := ScalarAbsF32x16(a);
end;

function RISCVVAbsF32x8(const a: TVecF32x8): TVecF32x8;
begin
  Result := ScalarAbsF32x8(a);
end;

function RISCVVAbsF64x4(const a: TVecF64x4): TVecF64x4;
begin
  Result := ScalarAbsF64x4(a);
end;

function RISCVVAbsF64x8(const a: TVecF64x8): TVecF64x8;
begin
  Result := ScalarAbsF64x8(a);
end;

function RISCVVAddI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarAddI16x8(a, b);
end;

function RISCVVAddI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarAddI64x4(a, b);
end;

function RISCVVAddI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarAddI64x8(a, b);
end;

function RISCVVAddI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarAddI8x16(a, b);
end;

function RISCVVAddU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarAddU16x8(a, b);
end;

function RISCVVAddU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarAddU64x4(a, b);
end;

// U32x8 Operations (256-bit)
// Keep these facade entrypoints in sync with RegisterRISCVVBackend:
// - asm-enabled builds bind the same symbols to native RVV bodies
// - no-asm builds resolve here and must preserve the published scalar contract
// Only families deliberately removed from this file (for example
// U32x16/U64x8) are meant to reuse the base scalar slot directly.
function RISCVVAddU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarAddU32x8(a, b);
end;

function RISCVVSubU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarSubU32x8(a, b);
end;

function RISCVVMulU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarMulU32x8(a, b);
end;

function RISCVVAndU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarAndU32x8(a, b);
end;

function RISCVVOrU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarOrU32x8(a, b);
end;

function RISCVVXorU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarXorU32x8(a, b);
end;

function RISCVVNotU32x8(const a: TVecU32x8): TVecU32x8;
begin
  Result := ScalarNotU32x8(a);
end;

function RISCVVAndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarAndNotU32x8(a, b);
end;

function RISCVVShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  // Keep the symbol-level contract identical to the asm path while making the
  // no-asm behavior explicit and unsurprising.
  Result := ScalarShiftLeftU32x8(a, count);
end;

function RISCVVShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
begin
  // RegisterRISCVVBackend still binds this symbol so asm-enabled builds can
  // swap in the native RVV implementation without a second register branch.
  Result := ScalarShiftRightU32x8(a, count);
end;

function RISCVVCmpEqU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := ScalarCmpEqU32x8(a, b);
end;

function RISCVVCmpLtU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := ScalarCmpLtU32x8(a, b);
end;

function RISCVVCmpLeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := ScalarCmpLeU32x8(a, b);
end;

function RISCVVCmpGtU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := ScalarCmpGtU32x8(a, b);
end;

function RISCVVCmpGeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := ScalarCmpGeU32x8(a, b);
end;

function RISCVVCmpNeU32x8(const a, b: TVecU32x8): TMask8;
begin
  Result := ScalarCmpNeU32x8(a, b);
end;

function RISCVVMinU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarMinU32x8(a, b);
end;

function RISCVVMaxU32x8(const a, b: TVecU32x8): TVecU32x8;
begin
  Result := ScalarMaxU32x8(a, b);
end;

// F64x4 Reciprocal
function RISCVVRcpF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if a.d[i] <> 0.0 then
      Result.d[i] := 1.0 / a.d[i]
    else
      Result.d[i] := 0.0;
end;

function RISCVVAddU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarAddU8x16(a, b);
end;

function RISCVVAndI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarAndI16x8(a, b);
end;

function RISCVVAndI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarAndI64x4(a, b);
end;

function RISCVVAndI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarAndI64x8(a, b);
end;

function RISCVVAndI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarAndI8x16(a, b);
end;

function RISCVVAndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarAndNotI16x8(a, b);
end;

function RISCVVAndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarAndNotI64x4(a, b);
end;

function RISCVVAndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  Result := ScalarAndNotU32x4(a, b);
end;

function RISCVVAndU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarAndU16x8(a, b);
end;

function RISCVVAndU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarAndU64x4(a, b);
end;

function RISCVVAndU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarAndU8x16(a, b);
end;

function RISCVVClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if a.d[i] < minVal.d[i] then
      Result.d[i] := minVal.d[i]
    else if a.d[i] > maxVal.d[i] then
      Result.d[i] := maxVal.d[i]
    else
      Result.d[i] := a.d[i];
  end;
end;

function RISCVVClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
  begin
    if a.d[i] < minVal.d[i] then
      Result.d[i] := minVal.d[i]
    else if a.d[i] > maxVal.d[i] then
      Result.d[i] := maxVal.d[i]
    else
      Result.d[i] := a.d[i];
  end;
end;

function RISCVVCmpEqF64x2(const a, b: TVecF64x2): TMask2;
begin
  Result := ScalarCmpEqF64x2(a, b);
end;

function RISCVVCmpEqI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpEqI16x8(a, b);
end;

function RISCVVCmpEqI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := ScalarCmpEqI64x4(a, b);
end;

function RISCVVCmpEqI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := ScalarCmpEqI64x8(a, b);
end;

function RISCVVCmpEqI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpEqI8x16(a, b);
end;

function RISCVVCmpEqU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpEqU16x8(a, b);
end;

function RISCVVCmpEqU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpEqU32x4(a, b);
end;

function RISCVVCmpEqU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := ScalarCmpEqU64x4(a, b);
end;

function RISCVVCmpEqU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpEqU8x16(a, b);
end;

function RISCVVCmpGeF64x2(const a, b: TVecF64x2): TMask2;
begin
  Result := ScalarCmpGeF64x2(a, b);
end;

function RISCVVCmpGeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpGeI16x8(a, b);
end;

function RISCVVCmpGeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := ScalarCmpGeI64x4(a, b);
end;

function RISCVVCmpGeI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := ScalarCmpGeI64x8(a, b);
end;

function RISCVVCmpGeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpGeI8x16(a, b);
end;

function RISCVVCmpGeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpGeU16x8(a, b);
end;

function RISCVVCmpGeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpGeU32x4(a, b);
end;

function RISCVVCmpGeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := ScalarCmpGeU64x4(a, b);
end;

function RISCVVCmpGeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpGeU8x16(a, b);
end;

function RISCVVCmpGtF64x2(const a, b: TVecF64x2): TMask2;
begin
  Result := ScalarCmpGtF64x2(a, b);
end;

function RISCVVCmpGtI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpGtI16x8(a, b);
end;

function RISCVVCmpGtI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := ScalarCmpGtI64x4(a, b);
end;

function RISCVVCmpGtI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := ScalarCmpGtI64x8(a, b);
end;

function RISCVVCmpGtI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpGtI8x16(a, b);
end;

function RISCVVCmpGtU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpGtU16x8(a, b);
end;

function RISCVVCmpGtU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpGtU32x4(a, b);
end;

function RISCVVCmpGtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := ScalarCmpGtU64x4(a, b);
end;

function RISCVVCmpGtU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpGtU8x16(a, b);
end;

function RISCVVCmpLeF64x2(const a, b: TVecF64x2): TMask2;
begin
  Result := ScalarCmpLeF64x2(a, b);
end;

function RISCVVCmpLeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpLeI16x8(a, b);
end;

function RISCVVCmpLeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := ScalarCmpLeI64x4(a, b);
end;

function RISCVVCmpLeI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := ScalarCmpLeI64x8(a, b);
end;

function RISCVVCmpLeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpLeI8x16(a, b);
end;

function RISCVVCmpLeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpLeU16x8(a, b);
end;

function RISCVVCmpLeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpLeU32x4(a, b);
end;

function RISCVVCmpLeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := ScalarCmpLeU64x4(a, b);
end;

function RISCVVCmpLeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpLeU8x16(a, b);
end;

function RISCVVCmpLtF64x2(const a, b: TVecF64x2): TMask2;
begin
  Result := ScalarCmpLtF64x2(a, b);
end;

function RISCVVCmpLtI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpLtI16x8(a, b);
end;

function RISCVVCmpLtI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := ScalarCmpLtI64x4(a, b);
end;

function RISCVVCmpLtI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := ScalarCmpLtI64x8(a, b);
end;

function RISCVVCmpLtI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpLtI8x16(a, b);
end;

function RISCVVCmpLtU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpLtU16x8(a, b);
end;

function RISCVVCmpLtU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := ScalarCmpLtU32x4(a, b);
end;

function RISCVVCmpLtU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := ScalarCmpLtU64x4(a, b);
end;

function RISCVVCmpLtU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpLtU8x16(a, b);
end;

function RISCVVCmpNeF64x2(const a, b: TVecF64x2): TMask2;
begin
  Result := ScalarCmpNeF64x2(a, b);
end;

function RISCVVCmpNeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := ScalarCmpNeI16x8(a, b);
end;

function RISCVVCmpNeI64x4(const a, b: TVecI64x4): TMask4;
begin
  Result := ScalarCmpNeI64x4(a, b);
end;

function RISCVVCmpNeI64x8(const a, b: TVecI64x8): TMask8;
begin
  Result := ScalarCmpNeI64x8(a, b);
end;

function RISCVVCmpNeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := ScalarCmpNeI8x16(a, b);
end;

function RISCVVCmpNeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := ScalarCmpNeU16x8(a, b);
end;

function RISCVVCmpNeU64x4(const a, b: TVecU64x4): TMask4;
begin
  Result := ScalarCmpNeU64x4(a, b);
end;

function RISCVVCmpNeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := ScalarCmpNeU8x16(a, b);
end;

function RISCVVFmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
begin
  Result := ScalarFmaF32x16(a, b, c);
end;

function RISCVVFmaF32x8(const a, b, c: TVecF32x8): TVecF32x8;
begin
  Result := ScalarFmaF32x8(a, b, c);
end;

function RISCVVFmaF64x4(const a, b, c: TVecF64x4): TVecF64x4;
begin
  Result := ScalarFmaF64x4(a, b, c);
end;

function RISCVVFmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
begin
  Result := ScalarFmaF64x8(a, b, c);
end;

function RISCVVSatAddI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarI8x16SatAdd(a, b);
end;

function RISCVVSatSubI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarI8x16SatSub(a, b);
end;

function RISCVVSatAddI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarI16x8SatAdd(a, b);
end;

function RISCVVSatSubI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarI16x8SatSub(a, b);
end;

function RISCVVSatAddU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarU8x16SatAdd(a, b);
end;

function RISCVVSatSubU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarU8x16SatSub(a, b);
end;

function RISCVVSatAddU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarU16x8SatAdd(a, b);
end;

function RISCVVSatSubU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarU16x8SatSub(a, b);
end;

function RISCVVInsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
begin
  Result := ScalarInsertF32x16(a, value, index);
end;

function RISCVVInsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
begin
  Result := ScalarInsertF32x8(a, value, index);
end;

function RISCVVInsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
begin
  Result := ScalarInsertF64x4(a, value, index);
end;

function RISCVVInsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
begin
  Result := ScalarInsertI32x16(a, value, index);
end;

function RISCVVInsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
begin
  Result := ScalarInsertI32x4(a, value, index);
end;

function RISCVVInsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
begin
  Result := ScalarInsertI32x8(a, value, index);
end;

function RISCVVInsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
begin
  Result := ScalarInsertI64x2(a, value, index);
end;

function RISCVVInsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
begin
  Result := ScalarInsertI64x4(a, value, index);
end;

function RISCVVLoadI64x4(p: PInt64): TVecI64x4;
begin
  Result := ScalarLoadI64x4(p);
end;

function RISCVVMaxF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarMaxF32x16(a, b);
end;

function RISCVVMaxF32x8(const a, b: TVecF32x8): TVecF32x8;
begin
  Result := ScalarMaxF32x8(a, b);
end;

function RISCVVMaxF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result := ScalarMaxF64x4(a, b);
end;

function RISCVVMaxF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarMaxF64x8(a, b);
end;

function RISCVVMaxI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarMaxI16x8(a, b);
end;

function RISCVVMaxI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarMaxI8x16(a, b);
end;

function RISCVVMaxU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarMaxU16x8(a, b);
end;

function RISCVVMaxU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarMaxU8x16(a, b);
end;

function RISCVVMinF32x16(const a, b: TVecF32x16): TVecF32x16;
begin
  Result := ScalarMinF32x16(a, b);
end;

function RISCVVMinF32x8(const a, b: TVecF32x8): TVecF32x8;
begin
  Result := ScalarMinF32x8(a, b);
end;

function RISCVVMinF64x4(const a, b: TVecF64x4): TVecF64x4;
begin
  Result := ScalarMinF64x4(a, b);
end;

function RISCVVMinF64x8(const a, b: TVecF64x8): TVecF64x8;
begin
  Result := ScalarMinF64x8(a, b);
end;

function RISCVVMinI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarMinI16x8(a, b);
end;

function RISCVVMinI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarMinI8x16(a, b);
end;

function RISCVVMinU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarMinU16x8(a, b);
end;

function RISCVVMinU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarMinU8x16(a, b);
end;

function RISCVVMulI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarMulI16x8(a, b);
end;

function RISCVVMulU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarMulU16x8(a, b);
end;

function RISCVVNotI16x8(const a: TVecI16x8): TVecI16x8;
begin
  Result := ScalarNotI16x8(a);
end;

function RISCVVNotI64x4(const a: TVecI64x4): TVecI64x4;
begin
  Result := ScalarNotI64x4(a);
end;

function RISCVVNotI64x8(const a: TVecI64x8): TVecI64x8;
begin
  Result := ScalarNotI64x8(a);
end;

function RISCVVNotI8x16(const a: TVecI8x16): TVecI8x16;
begin
  Result := ScalarNotI8x16(a);
end;

function RISCVVNotU16x8(const a: TVecU16x8): TVecU16x8;
begin
  Result := ScalarNotU16x8(a);
end;

function RISCVVNotU64x4(const a: TVecU64x4): TVecU64x4;
begin
  Result := ScalarNotU64x4(a);
end;

function RISCVVNotU8x16(const a: TVecU8x16): TVecU8x16;
begin
  Result := ScalarNotU8x16(a);
end;

function RISCVVOrI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarOrI16x8(a, b);
end;

function RISCVVOrI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarOrI64x4(a, b);
end;

function RISCVVOrI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarOrI64x8(a, b);
end;

function RISCVVOrI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarOrI8x16(a, b);
end;

function RISCVVOrU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarOrU16x8(a, b);
end;

function RISCVVOrU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarOrU64x4(a, b);
end;

function RISCVVOrU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarOrU8x16(a, b);
end;

function RISCVVReduceAddF32x16(const a: TVecF32x16): Single;
begin
  Result := ScalarReduceAddF32x16(a);
end;

function RISCVVReduceAddF32x8(const a: TVecF32x8): Single;
begin
  Result := ScalarReduceAddF32x8(a);
end;

function RISCVVReduceAddF64x2(const a: TVecF64x2): Double;
begin
  Result := ScalarReduceAddF64x2(a);
end;

function RISCVVReduceAddF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 3 do
    Result := Result + a.d[i];
end;

function RISCVVReduceAddF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 7 do
    Result := Result + a.d[i];
end;

function RISCVVReduceMaxF32x16(const a: TVecF32x16): Single;
begin
  Result := ScalarReduceMaxF32x16(a);
end;

function RISCVVReduceMaxF32x8(const a: TVecF32x8): Single;
begin
  Result := ScalarReduceMaxF32x8(a);
end;

function RISCVVReduceMaxF64x2(const a: TVecF64x2): Double;
begin
  Result := ScalarReduceMaxF64x2(a);
end;

function RISCVVReduceMaxF64x4(const a: TVecF64x4): Double;
begin
  Result := ScalarReduceMaxF64x4(a);
end;

function RISCVVReduceMaxF64x8(const a: TVecF64x8): Double;
begin
  Result := ScalarReduceMaxF64x8(a);
end;

function RISCVVReduceMinF32x16(const a: TVecF32x16): Single;
begin
  Result := ScalarReduceMinF32x16(a);
end;

function RISCVVReduceMinF32x8(const a: TVecF32x8): Single;
begin
  Result := ScalarReduceMinF32x8(a);
end;

function RISCVVReduceMinF64x2(const a: TVecF64x2): Double;
begin
  Result := ScalarReduceMinF64x2(a);
end;

function RISCVVReduceMinF64x4(const a: TVecF64x4): Double;
begin
  Result := ScalarReduceMinF64x4(a);
end;

function RISCVVReduceMinF64x8(const a: TVecF64x8): Double;
begin
  Result := ScalarReduceMinF64x8(a);
end;

function RISCVVReduceMulF32x16(const a: TVecF32x16): Single;
begin
  Result := ScalarReduceMulF32x16(a);
end;

function RISCVVReduceMulF32x8(const a: TVecF32x8): Single;
begin
  Result := ScalarReduceMulF32x8(a);
end;

function RISCVVReduceMulF64x2(const a: TVecF64x2): Double;
begin
  Result := ScalarReduceMulF64x2(a);
end;

function RISCVVReduceMulF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 3 do
    Result := Result * a.d[i];
end;

function RISCVVReduceMulF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 7 do
    Result := Result * a.d[i];
end;

function RISCVVShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
begin
  Result := ScalarShiftLeftI16x8(a, count);
end;

function RISCVVShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  Result := ScalarShiftLeftI64x4(a, count);
end;

function RISCVVShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
begin
  Result := ScalarShiftLeftU16x8(a, count);
end;

function RISCVVShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  Result := ScalarShiftLeftU64x4(a, count);
end;

function RISCVVShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
begin
  Result := ScalarShiftRightArithI16x8(a, count);
end;

function RISCVVShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
begin
  Result := ScalarShiftRightI16x8(a, count);
end;

function RISCVVShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  Result := ScalarShiftRightI64x4(a, count);
end;

function RISCVVShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
begin
  Result := ScalarShiftRightU16x8(a, count);
end;

function RISCVVShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
begin
  Result := ScalarShiftRightU64x4(a, count);
end;

function RISCVVSplatF32x16(value: Single): TVecF32x16;
begin
  Result := ScalarSplatF32x16(value);
end;

function RISCVVSplatF32x8(value: Single): TVecF32x8;
begin
  Result := ScalarSplatF32x8(value);
end;

function RISCVVSplatF64x4(value: Double): TVecF64x4;
begin
  Result := ScalarSplatF64x4(value);
end;

function RISCVVSplatF64x8(value: Double): TVecF64x8;
begin
  Result := ScalarSplatF64x8(value);
end;

function RISCVVSplatI64x4(value: Int64): TVecI64x4;
begin
  Result := ScalarSplatI64x4(value);
end;

function RISCVVSqrtF32x16(const a: TVecF32x16): TVecF32x16;
begin
  Result := ScalarSqrtF32x16(a);
end;

function RISCVVSqrtF32x8(const a: TVecF32x8): TVecF32x8;
begin
  Result := ScalarSqrtF32x8(a);
end;

function RISCVVSqrtF64x4(const a: TVecF64x4): TVecF64x4;
begin
  Result := ScalarSqrtF64x4(a);
end;

function RISCVVSqrtF64x8(const a: TVecF64x8): TVecF64x8;
begin
  Result := ScalarSqrtF64x8(a);
end;

procedure RISCVVStoreF32x16(p: PSingle; const a: TVecF32x16);
begin
  ScalarStoreF32x16(p, a);
end;

procedure RISCVVStoreF32x8(p: PSingle; const a: TVecF32x8);
begin
  ScalarStoreF32x8(p, a);
end;

procedure RISCVVStoreF64x2(p: PDouble; const a: TVecF64x2);
begin
  ScalarStoreF64x2(p, a);
end;

procedure RISCVVStoreF64x4(p: PDouble; const a: TVecF64x4);
begin
  ScalarStoreF64x4(p, a);
end;

procedure RISCVVStoreF64x8(p: PDouble; const a: TVecF64x8);
begin
  ScalarStoreF64x8(p, a);
end;

procedure RISCVVStoreI64x4(p: PInt64; const a: TVecI64x4);
begin
  ScalarStoreI64x4(p, a);
end;

function RISCVVSubI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarSubI16x8(a, b);
end;

function RISCVVSubI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarSubI64x4(a, b);
end;

function RISCVVSubI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarSubI64x8(a, b);
end;

function RISCVVSubI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarSubI8x16(a, b);
end;

function RISCVVSubU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarSubU16x8(a, b);
end;

function RISCVVSubU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarSubU64x4(a, b);
end;

function RISCVVSubU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarSubU8x16(a, b);
end;

function RISCVVXorI16x8(const a, b: TVecI16x8): TVecI16x8;
begin
  Result := ScalarXorI16x8(a, b);
end;

function RISCVVXorI64x4(const a, b: TVecI64x4): TVecI64x4;
begin
  Result := ScalarXorI64x4(a, b);
end;

function RISCVVXorI64x8(const a, b: TVecI64x8): TVecI64x8;
begin
  Result := ScalarXorI64x8(a, b);
end;

function RISCVVXorI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := ScalarXorI8x16(a, b);
end;

function RISCVVXorU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := ScalarXorU16x8(a, b);
end;

function RISCVVXorU64x4(const a, b: TVecU64x4): TVecU64x4;
begin
  Result := ScalarXorU64x4(a, b);
end;

function RISCVVXorU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := ScalarXorU8x16(a, b);
end;

function RISCVVZeroF32x16: TVecF32x16;
begin
  Result := ScalarZeroF32x16();
end;

function RISCVVZeroF32x8: TVecF32x8;
begin
  Result := ScalarZeroF32x8();
end;

function RISCVVZeroF64x4: TVecF64x4;
begin
  Result := ScalarZeroF64x4();
end;

function RISCVVZeroF64x8: TVecF64x8;
begin
  Result := ScalarZeroF64x8();
end;

function RISCVVZeroI64x4: TVecI64x4;
begin
  Result := ScalarZeroI64x4();
end;

// =============================================================
// Facade Function Implementations
// =============================================================

{$ENDIF} // not RISCVV_ASSEMBLY
