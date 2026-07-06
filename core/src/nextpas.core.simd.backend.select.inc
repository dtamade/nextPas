{
  nextpas.core.simd.backend.select.inc

  Compile-time backend selection macros.

  This file provides compile-time constants for backend selection,
  enabling the compiler to optimize backend-specific code paths.

  Usage:
    {$I nextpas.core.simd.backend.select.inc}
    {$IFDEF SIMD_BACKEND_SSE2}
      // SSE2-specific code
    {$ENDIF}

  Backend detection:
    - SIMD_BACKEND_SSE2: x86_64 with SSE2
    - SIMD_BACKEND_AVX2: x86_64 with AVX2
    - SIMD_BACKEND_AVX512: x86_64 with AVX-512
    - SIMD_BACKEND_NEON: AArch64 with NEON
    - SIMD_BACKEND_SCALAR: Fallback
}

{
  Backend availability detection based on CPU target.
  These are compile-time constants that enable backend-specific code paths.
}

{$IFDEF CPUX86_64}
  {$DEFINE SIMD_BACKEND_X86}
  {$DEFINE SIMD_BACKEND_SSE2}

  {
    AVX2 and AVX-512 detection requires runtime CPUID checks.
    At compile-time, we can only detect the base SSE2 support.
    The runtime dispatch will handle AVX2/AVX-512 selection.

    For compile-time optimization, users can define:
      {$DEFINE SIMD_STATIC_AVX2}
    to force AVX2 backend selection.
  }
{$ENDIF}

{$IFDEF CPUI386}
  {$DEFINE SIMD_BACKEND_X86}
  {$DEFINE SIMD_BACKEND_SSE2}
{$ENDIF}

{$IFDEF CPUAARCH64}
  {$DEFINE SIMD_BACKEND_ARM}
  {$DEFINE SIMD_BACKEND_NEON}
{$ENDIF}

{$IFDEF CPUARM}
  {$DEFINE SIMD_BACKEND_ARM}
  {$DEFINE SIMD_BACKEND_NEON}
{$ENDIF}

{$IFDEF CPURISCV64}
  {$DEFINE SIMD_BACKEND_RISCV}
  {$DEFINE SIMD_BACKEND_RVV}
{$ENDIF}

{$IFDEF CPULOONGARCH64}
  {$DEFINE SIMD_BACKEND_LOONGARCH}
  {$DEFINE SIMD_BACKEND_LASX}
{$ENDIF}

{
  Default backend selection.
  This is used when no static backend is defined.
}

{$IF NOT DEFINED(SIMD_STATIC_SSE2) AND NOT DEFINED(SIMD_STATIC_AVX2) AND NOT DEFINED(SIMD_STATIC_AVX512) AND NOT DEFINED(SIMD_STATIC_NEON) AND NOT DEFINED(SIMD_STATIC_SCALAR)}
  {$DEFINE SIMD_DYNAMIC_DISPATCH}
{$ENDIF}

{
  Backend-specific optimization hints.
  These can be used to enable backend-specific optimizations.
}

{$IFDEF SIMD_BACKEND_SSE2}
  {$DEFINE SIMD_HAS_128BIT}
  {$DEFINE SIMD_HAS_SSE}
{$ENDIF}

{$IFDEF SIMD_BACKEND_AVX2}
  {$DEFINE SIMD_HAS_256BIT}
  {$DEFINE SIMD_HAS_SSE}
  {$DEFINE SIMD_HAS_AVX}
{$ENDIF}

{$IFDEF SIMD_BACKEND_AVX512}
  {$DEFINE SIMD_HAS_512BIT}
  {$DEFINE SIMD_HAS_SSE}
  {$DEFINE SIMD_HAS_AVX}
  {$DEFINE SIMD_HAS_AVX512}
{$ENDIF}

{$IFDEF SIMD_BACKEND_NEON}
  {$DEFINE SIMD_HAS_128BIT}
  {$DEFINE SIMD_HAS_NEON}
{$ENDIF}

{$IFDEF SIMD_BACKEND_RVV}
  {$DEFINE SIMD_HAS_VARIABLE_LENGTH}
  {$DEFINE SIMD_HAS_RVV}
{$ENDIF}

{$IFDEF SIMD_BACKEND_LASX}
  {$DEFINE SIMD_HAS_256BIT}
  {$DEFINE SIMD_HAS_LASX}
{$ENDIF}

{
  Vector width constants.
  These can be used for loop unrolling and alignment checks.
}

{$IFDEF SIMD_HAS_128BIT}
  {$DEFINE SIMD_VECTOR_BYTES := 16}
  {$DEFINE SIMD_VECTOR_BITS := 128}
{$ENDIF}

{$IFDEF SIMD_HAS_256BIT}
  {$DEFINE SIMD_VECTOR_BYTES := 32}
  {$DEFINE SIMD_VECTOR_BITS := 256}
{$ENDIF}

{$IFDEF SIMD_HAS_512BIT}
  {$DEFINE SIMD_VECTOR_BYTES := 64}
  {$DEFINE SIMD_VECTOR_BITS := 512}
{$ENDIF}

{
  Alignment constants.
  These can be used for memory alignment checks.
}

{$IFDEF SIMD_HAS_128BIT}
  {$DEFINE SIMD_ALIGNMENT := 16}
{$ENDIF}

{$IFDEF SIMD_HAS_256BIT}
  {$DEFINE SIMD_ALIGNMENT := 32}
{$ENDIF}

{$IFDEF SIMD_HAS_512BIT}
  {$DEFINE SIMD_ALIGNMENT := 64}
{$ENDIF}
