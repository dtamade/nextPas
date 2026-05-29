unit nextpas.core.simd.linalg.gemm.neon;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{$IFDEF CPUAARCH64}
uses
  nextpas.core.simd.alloc;

const
  GEMM_MR_NEON = 4;
  GEMM_NR_NEON = 8;

// C[4,8] = A[4,K] * B_packed[K,8], NEON FMLA microkernel
procedure GemmMicro4x8F32_NEON_Zero(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt);

procedure GemmBlockedF32_NEON(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
{$ENDIF}

implementation

{$IFDEF CPUAARCH64}
uses
  nextpas.core.simd;

// 4x8 NEON microkernel: 8 accumulators (v0-v7), 4 rows x 2 NEON quads
procedure GemmMicro4x8F32_NEON_Zero(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  // x0=A, x1=B_packed, x2=C, x3=K, x4=A_stride, x5=C_stride
  // Zero accumulators
  movi v0.4s, #0
  movi v1.4s, #0
  movi v2.4s, #0
  movi v3.4s, #0
  movi v4.4s, #0
  movi v5.4s, #0
  movi v6.4s, #0
  movi v7.4s, #0

  // Row pointers
  mov x6, x0            // row0
  add x7, x0, x4        // row1
  add x8, x7, x4        // row2
  add x9, x8, x4        // row3

  cbz x3, .Lstore_neon

.Lk_loop_neon:
  // Load B[k, 0..7]
  ld1 {v16.4s, v17.4s}, [x1], #32

  // Row 0: broadcast A[0,k]
  ld1r {v18.4s}, [x6], #4
  fmla v0.4s, v18.4s, v16.4s
  fmla v1.4s, v18.4s, v17.4s

  // Row 1
  ld1r {v18.4s}, [x7], #4
  fmla v2.4s, v18.4s, v16.4s
  fmla v3.4s, v18.4s, v17.4s

  // Row 2
  ld1r {v18.4s}, [x8], #4
  fmla v4.4s, v18.4s, v16.4s
  fmla v5.4s, v18.4s, v17.4s

  // Row 3
  ld1r {v18.4s}, [x9], #4
  fmla v6.4s, v18.4s, v16.4s
  fmla v7.4s, v18.4s, v17.4s

  subs x3, x3, #1
  bne .Lk_loop_neon

.Lstore_neon:
  st1 {v0.4s, v1.4s}, [x2], x5
  st1 {v2.4s, v3.4s}, [x2], x5
  st1 {v4.4s, v5.4s}, [x2], x5
  st1 {v6.4s, v7.4s}, [x2]
end;

procedure GemmBlockedF32_NEON(AA, AB, AC: PSingle;
  AM, AN, AK, ALdA, ALdB, ALdC: SizeUInt);
begin
  // Placeholder: will implement full blocked tiling using NEON microkernel
  // For now, fall back to scalar
  // TODO: implement with PackA/PackB + GemmMicro4x8F32_NEON_Zero
end;
{$ENDIF}

end.
