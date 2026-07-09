{
  nextpas.core.simd.static.batch.inc

  Static dispatch implementations for SIMD batch operations.
  When SIMD_STATIC_BACKEND is defined, these implementations directly call
  backend-specific functions, eliminating runtime dispatch overhead.

  This file is included by nextpas.core.simd.pas when SIMD_STATIC_BACKEND is defined.
}

{$IFDEF SIMD_STATIC_BACKEND}

// === F32 Batch Operations ===

procedure ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArrayAddF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArraySubF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArrayMulF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArrayDivF32(aSrc1, aSrc2, aDst, aCount);
end;

// === U32 Batch Operations ===

procedure ArrayAddU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArrayAddU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArraySubU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArraySubU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMulU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  SIMD_STATIC_ArrayMulU32(aSrc1, aSrc2, aDst, aCount);
end;

// === Memory Operations ===

function MemEqual(a, b: Pointer; len: SizeUInt): LongBool; inline;
begin
  Result := SIMD_STATIC_MemEqual(a, b, len);
end;

function MemFindByte(a: Pointer; aValue: Byte; aLen: SizeUInt): Pointer; inline;
begin
  Result := SIMD_STATIC_MemFindByte(a, aValue, aLen);
end;

// === F32 Reduce Operations ===

function ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := SIMD_STATIC_ReduceMinF32(aSrc, aCount);
end;

function ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := SIMD_STATIC_ReduceMaxF32(aSrc, aCount);
end;

function ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := SIMD_STATIC_ReduceSumF32(aSrc, aCount);
end;

// === F64 Reduce Operations ===

function ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := SIMD_STATIC_ReduceMinF64(aSrc, aCount);
end;

function ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := SIMD_STATIC_ReduceMaxF64(aSrc, aCount);
end;

function ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := SIMD_STATIC_ReduceSumF64(aSrc, aCount);
end;

{$ENDIF} // SIMD_STATIC_BACKEND
