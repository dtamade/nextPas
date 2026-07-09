{
  nextpas.core.simd.vectorize.hints.inc

  Compile-time hints for automatic vectorization.
  These macros provide hints to the compiler for better vectorization.

  Usage:
    {$I nextpas.core.simd.vectorize.hints.inc}
    for i := 0 to count - 1 do
    begin
      SIMD_VECTORIZE_LOOP
      dst[i] := src1[i] + src2[i];
    end;
}

{
  Loop alignment hint.
  Ensures the loop body is aligned to SIMD vector width.
}
{$IFDEF SIMD_HAS_128BIT}
  {$DEFINE SIMD_ALIGN_LOOP := {$ALIGN 16}}
{$ENDIF}
{$IFDEF SIMD_HAS_256BIT}
  {$DEFINE SIMD_ALIGN_LOOP := {$ALIGN 32}}
{$ENDIF}
{$IFDEF SIMD_HAS_512BIT}
  {$DEFINE SIMD_ALIGN_LOOP := {$ALIGN 64}}
{$ENDIF}

{
  Data alignment hint.
  Asserts that a pointer is aligned to SIMD vector width.
}
{$IFDEF SIMD_HAS_128BIT}
  {$DEFINE SIMD_ASSUME_ALIGNED(p) := Assert(NativeUInt(p) and 15 = 0)}
{$ENDIF}
{$IFDEF SIMD_HAS_256BIT}
  {$DEFINE SIMD_ASSUME_ALIGNED(p) := Assert(NativeUInt(p) and 31 = 0)}
{$ENDIF}
{$IFDEF SIMD_HAS_512BIT}
  {$DEFINE SIMD_ASSUME_ALIGNED(p) := Assert(NativeUInt(p) and 63 = 0)}
{$ENDIF}

{
  Prefetch hint.
  Prefetches data for read (PREFETCH_READ) or write (PREFETCH_WRITE).
}
{$IFDEF CPUX86_64}
  {$DEFINE SIMD_PREFETCH_READ(addr) := asm prefetchnta [addr] end}
  {$DEFINE SIMD_PREFETCH_WRITE(addr) := asm prefetchw [addr] end}
{$ELSEIF CPUAARCH64}
  {$DEFINE SIMD_PREFETCH_READ(addr) := asm prfm pldl1strm, [addr] end}
  {$DEFINE SIMD_PREFETCH_WRITE(addr) := asm prfm pstl1strm, [addr] end}
{$ELSE}
  {$DEFINE SIMD_PREFETCH_READ(addr) := }
  {$DEFINE SIMD_PREFETCH_WRITE(addr) := }
{$ENDIF}

{
  No-alias hint.
  Asserts that two pointers do not overlap.
}
{$DEFINE SIMD_NO_ALIAS(a, b, len) := Assert(not Overlaps(a, b, len))}

{
  Vectorization loop hint.
  Place this at the beginning of a loop body to hint the compiler
  that the loop can be vectorized.
}
{$DEFINE SIMD_VECTORIZE_LOOP := }

{
  Unroll hint.
  Suggests loop unrolling to the compiler.
}
{$IFDEF SIMD_HAS_128BIT}
  {$DEFINE SIMD_UNROLL_4 := {$UNROLL 4}}
  {$DEFINE SIMD_UNROLL_8 := {$UNROLL 8}}
{$ENDIF}
{$IFDEF SIMD_HAS_256BIT}
  {$DEFINE SIMD_UNROLL_4 := {$UNROLL 4}}
  {$DEFINE SIMD_UNROLL_8 := {$UNROLL 8}}
  {$DEFINE SIMD_UNROLL_16 := {$UNROLL 16}}
{$ENDIF}
{$IFDEF SIMD_HAS_512BIT}
  {$DEFINE SIMD_UNROLL_4 := {$UNROLL 4}}
  {$DEFINE SIMD_UNROLL_8 := {$UNROLL 8}}
  {$DEFINE SIMD_UNROLL_16 := {$UNROLL 16}}
  {$DEFINE SIMD_UNROLL_32 := {$UNROLL 32}}
{$ENDIF}

{
  Helper function for overlap detection.
}
function Overlaps(a, b: Pointer; len: SizeUInt): Boolean; inline;
var
  aStart, aEnd, bStart, bEnd: NativeUInt;
begin
  aStart := NativeUInt(a);
  aEnd := aStart + len;
  bStart := NativeUInt(b);
  bEnd := bStart + len;
  Result := (aStart < bEnd) and (bStart < aEnd);
end;
