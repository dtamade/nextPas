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

{
  Static dispatch macros for batch operations.
  When SIMD_STATIC_BACKEND is defined, these macros resolve to backend-specific
  implementations, eliminating runtime dispatch overhead.

  Usage:
    {$DEFINE SIMD_STATIC_BACKEND}
    {$I nextpas.core.simd.backend.select.inc}
    // Now use SIMD_STATIC_ArrayAddF32 etc.
}

{$IFDEF SIMD_STATIC_BACKEND}

  {$IFDEF SIMD_STATIC_AVX512}
    // AVX-512 static dispatch macros
    {$DEFINE SIMD_STATIC_ArrayAddF32 := AVX512ArrayAddF32}
    {$DEFINE SIMD_STATIC_ArraySubF32 := AVX512ArraySubF32}
    {$DEFINE SIMD_STATIC_ArrayMulF32 := AVX512ArrayMulF32}
    {$DEFINE SIMD_STATIC_ArrayDivF32 := AVX512ArrayDivF32}
    {$DEFINE SIMD_STATIC_ArrayAddU32 := AVX512ArrayAddU32}
    {$DEFINE SIMD_STATIC_ArraySubU32 := AVX512ArraySubU32}
    {$DEFINE SIMD_STATIC_ArrayMulU32 := AVX512ArrayMulU32}
    {$DEFINE SIMD_STATIC_MemEqual := AVX512MemEqual}
    {$DEFINE SIMD_STATIC_MemFindByte := AVX512MemFindByte}
    {$DEFINE SIMD_STATIC_ReduceMinF32 := AVX512ReduceMinF32}
    {$DEFINE SIMD_STATIC_ReduceMaxF32 := AVX512ReduceMaxF32}
    {$DEFINE SIMD_STATIC_ReduceSumF32 := AVX512ReduceSumF32}
    {$DEFINE SIMD_STATIC_ReduceMinF64 := AVX512ReduceMinF64}
    {$DEFINE SIMD_STATIC_ReduceMaxF64 := AVX512ReduceMaxF64}
    {$DEFINE SIMD_STATIC_ReduceSumF64 := AVX512ReduceSumF64}
  {$ELSEIF SIMD_STATIC_AVX2}
    // AVX2 static dispatch macros
    {$DEFINE SIMD_STATIC_ArrayAddF32 := AVX2ArrayAddF32}
    {$DEFINE SIMD_STATIC_ArraySubF32 := AVX2ArraySubF32}
    {$DEFINE SIMD_STATIC_ArrayMulF32 := AVX2ArrayMulF32}
    {$DEFINE SIMD_STATIC_ArrayDivF32 := AVX2ArrayDivF32}
    {$DEFINE SIMD_STATIC_ArrayAddU32 := AVX2ArrayAddU32}
    {$DEFINE SIMD_STATIC_ArraySubU32 := AVX2ArraySubU32}
    {$DEFINE SIMD_STATIC_ArrayMulU32 := AVX2ArrayMulU32}
    {$DEFINE SIMD_STATIC_MemEqual := AVX2MemEqual}
    {$DEFINE SIMD_STATIC_MemFindByte := AVX2MemFindByte}
    {$DEFINE SIMD_STATIC_ReduceMinF32 := AVX2ReduceMinF32}
    {$DEFINE SIMD_STATIC_ReduceMaxF32 := AVX2ReduceMaxF32}
    {$DEFINE SIMD_STATIC_ReduceSumF32 := AVX2ReduceSumF32}
    {$DEFINE SIMD_STATIC_ReduceMinF64 := AVX2ReduceMinF64}
    {$DEFINE SIMD_STATIC_ReduceMaxF64 := AVX2ReduceMaxF64}
    {$DEFINE SIMD_STATIC_ReduceSumF64 := AVX2ReduceSumF64}
  {$ELSEIF SIMD_STATIC_SSE2}
    // SSE2 static dispatch macros
    {$DEFINE SIMD_STATIC_ArrayAddF32 := SSE2ArrayAddF32}
    {$DEFINE SIMD_STATIC_ArraySubF32 := SSE2ArraySubF32}
    {$DEFINE SIMD_STATIC_ArrayMulF32 := SSE2ArrayMulF32}
    {$DEFINE SIMD_STATIC_ArrayDivF32 := SSE2ArrayDivF32}
    {$DEFINE SIMD_STATIC_ArrayAddU32 := SSE2ArrayAddU32}
    {$DEFINE SIMD_STATIC_ArraySubU32 := SSE2ArraySubU32}
    {$DEFINE SIMD_STATIC_ArrayMulU32 := SSE2ArrayMulU32}
    {$DEFINE SIMD_STATIC_MemEqual := MemEqual_SSE2}
    {$DEFINE SIMD_STATIC_MemFindByte := MemFindByte_SSE2}
    {$DEFINE SIMD_STATIC_ReduceMinF32 := SSE2ReduceMinF32}
    {$DEFINE SIMD_STATIC_ReduceMaxF32 := SSE2ReduceMaxF32}
    {$DEFINE SIMD_STATIC_ReduceSumF32 := SSE2ReduceSumF32}
    {$DEFINE SIMD_STATIC_ReduceMinF64 := SSE2ReduceMinF64}
    {$DEFINE SIMD_STATIC_ReduceMaxF64 := SSE2ReduceMaxF64}
    {$DEFINE SIMD_STATIC_ReduceSumF64 := SSE2ReduceSumF64}
  {$ELSEIF SIMD_STATIC_NEON}
    // NEON static dispatch macros
    {$DEFINE SIMD_STATIC_ArrayAddF32 := NEONArrayAddF32}
    {$DEFINE SIMD_STATIC_ArraySubF32 := NEONArraySubF32}
    {$DEFINE SIMD_STATIC_ArrayMulF32 := NEONArrayMulF32}
    {$DEFINE SIMD_STATIC_ArrayDivF32 := NEONArrayDivF32}
    {$DEFINE SIMD_STATIC_ArrayAddU32 := NEONArrayAddU32}
    {$DEFINE SIMD_STATIC_ArraySubU32 := NEONArraySubU32}
    {$DEFINE SIMD_STATIC_ArrayMulU32 := NEONArrayMulU32}
    {$DEFINE SIMD_STATIC_MemEqual := NEONMemEqual}
    {$DEFINE SIMD_STATIC_MemFindByte := NEONMemFindByte}
    {$DEFINE SIMD_STATIC_ReduceMinF32 := NEONReduceMinF32}
    {$DEFINE SIMD_STATIC_ReduceMaxF32 := NEONReduceMaxF32}
    {$DEFINE SIMD_STATIC_ReduceSumF32 := NEONReduceSumF32}
    {$DEFINE SIMD_STATIC_ReduceMinF64 := NEONReduceMinF64}
    {$DEFINE SIMD_STATIC_ReduceMaxF64 := NEONReduceMaxF64}
    {$DEFINE SIMD_STATIC_ReduceSumF64 := NEONReduceSumF64}
  {$ELSE}
    // Scalar fallback static dispatch macros
    {$DEFINE SIMD_STATIC_ArrayAddF32 := ScalarArrayAddF32}
    {$DEFINE SIMD_STATIC_ArraySubF32 := ScalarArraySubF32}
    {$DEFINE SIMD_STATIC_ArrayMulF32 := ScalarArrayMulF32}
    {$DEFINE SIMD_STATIC_ArrayDivF32 := ScalarArrayDivF32}
    {$DEFINE SIMD_STATIC_ArrayAddU32 := ScalarArrayAddU32}
    {$DEFINE SIMD_STATIC_ArraySubU32 := ScalarArraySubU32}
    {$DEFINE SIMD_STATIC_ArrayMulU32 := ScalarArrayMulU32}
    {$DEFINE SIMD_STATIC_MemEqual := ScalarMemEqual}
    {$DEFINE SIMD_STATIC_MemFindByte := ScalarMemFindByte}
    {$DEFINE SIMD_STATIC_ReduceMinF32 := ScalarReduceMinF32}
    {$DEFINE SIMD_STATIC_ReduceMaxF32 := ScalarReduceMaxF32}
    {$DEFINE SIMD_STATIC_ReduceSumF32 := ScalarReduceSumF32}
    {$DEFINE SIMD_STATIC_ReduceMinF64 := ScalarReduceMinF64}
    {$DEFINE SIMD_STATIC_ReduceMaxF64 := ScalarReduceMaxF64}
    {$DEFINE SIMD_STATIC_ReduceSumF64 := ScalarReduceSumF64}
  {$ENDIF}

{$ENDIF} // SIMD_STATIC_BACKEND

{
  Backend priority configuration.

  Users can define SIMD_BACKEND_PRIORITY to specify the preferred backend order.
  Example:
    {$DEFINE SIMD_BACKEND_PRIORITY := 'AVX512,AVX2,SSE2,NEON,RVV,Scalar'}

  Default priority: AVX-512 > AVX2 > SSE2 > NEON > RVV > Scalar
}

{$IF NOT DEFINED(SIMD_BACKEND_PRIORITY)}
  {$IFDEF SIMD_BACKEND_AVX512}
    {$DEFINE SIMD_BACKEND_PRIORITY := 'AVX512'}
  {$ELSEIF SIMD_BACKEND_AVX2}
    {$DEFINE SIMD_BACKEND_PRIORITY := 'AVX2'}
  {$ELSEIF SIMD_BACKEND_SSE2}
    {$DEFINE SIMD_BACKEND_PRIORITY := 'SSE2'}
  {$ELSEIF SIMD_BACKEND_NEON}
    {$DEFINE SIMD_BACKEND_PRIORITY := 'NEON'}
  {$ELSEIF SIMD_BACKEND_RVV}
    {$DEFINE SIMD_BACKEND_PRIORITY := 'RVV'}
  {$ELSE}
    {$DEFINE SIMD_BACKEND_PRIORITY := 'Scalar'}
  {$ENDIF}
{$ENDIF}
