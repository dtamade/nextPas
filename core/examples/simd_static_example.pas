{
  nextpas.core.simd.static.example.pas

  Example: Using compile-time static dispatch for SIMD operations.

  This example demonstrates how to use the static dispatch macros
  to eliminate runtime overhead and enable compiler inlining.
}

program nextpas.core.simd.static.example;

{$mode ObjFPC}{$H+}

{
  Step 1: Define the static backend BEFORE including the SIMD module.

  This tells the compiler to use compile-time dispatch instead of
  runtime dispatch. The compiler will directly call backend-specific
  implementations, eliminating function pointer overhead.

  Supported backends:
    - SIMD_STATIC_SSE2: Force SSE2 backend (x86_64)
    - SIMD_STATIC_AVX2: Force AVX2 backend (x86_64)
    - SIMD_STATIC_AVX512: Force AVX-512 backend (x86_64)
    - SIMD_STATIC_NEON: Force NEON backend (AArch64)
    - SIMD_STATIC_SCALAR: Force scalar fallback (any platform)
}
{$DEFINE SIMD_STATIC_SSE2}

uses
  nextpas.core.simd;

var
  A, B, C: TVecF32x4;
  Dot: Single;
  MemA, MemB: array[0..15] of Byte;
begin
  {
    Step 2: Use SIMD operations as normal.

    When static dispatch is enabled, these calls are compiled to
    direct function calls to the backend implementation, with no
    runtime dispatch overhead.

    Performance comparison:
      - Runtime dispatch: ~15-20 cycles per call (atomic_load + function pointer)
      - Static dispatch: ~0 cycles overhead (direct call, can be inlined)
  }

  // Vector operations
  A := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);

  // This call is compiled to SSE2AddF32x4 directly
  C := VecF32x4Add(A, B);

  // This call is compiled to SSE2DotF32x4 directly
  Dot := VecF32x4Dot(A, B);

  WriteLn('C = ', C.f[0]:0:0, ', ', C.f[1]:0:0, ', ', C.f[2]:0:0, ', ', C.f[3]:0:0);
  WriteLn('Dot = ', Dot:0:0);

  // Memory operations
  FillChar(MemA, 16, $AA);
  FillChar(MemB, 16, $AA);

  // This call is compiled to SSE2MemEqual directly
  if MemEqual(@MemA, @MemB, 16) then
    WriteLn('Memory equal');

  WriteLn('Done');
end.
