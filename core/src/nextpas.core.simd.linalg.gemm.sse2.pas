unit nextpas.core.simd.linalg.gemm.sse2;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{$IFDEF SIMD_X86_AVAILABLE}
uses
  nextpas.core.simd.alloc;

const
  GEMM_MR_SSE2 = 4;
  GEMM_NR_SSE2 = 4;
  GEMM_MR_F64_SSE2 = 2;
  GEMM_NR_F64_SSE2 = 2;

procedure GemmMicro4x4F32_SSE2(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt);

procedure GemmMicro4x4F32_SSE2_Zero(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt);

procedure GemmMicro2x2F64_SSE2(AA, AB, AC: PDouble;
  AK, AAStride, ACStride: SizeUInt);

procedure GemmMicro2x2F64_SSE2_Zero(AA, AB, AC: PDouble;
  AK, AAStride, ACStride: SizeUInt);
{$ENDIF}

implementation

{$IFDEF SIMD_X86_AVAILABLE}
uses
  nextpas.core.simd;

// === SSE2 F32 4×4 Microkernel ===
// C[4,4] += A[4,K] * B_packed[K,4]
// Uses 4 XMM accumulators, broadcasts A elements manually
procedure GemmMicro4x4F32_SSE2(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  {$IFNDEF UNIX}
  mov rdi, rcx
  mov rsi, rdx
  mov rdx, r8
  mov rcx, r9
  // AAStride on stack, ACStride on stack
  {$ENDIF}
  // RDI=A, RSI=B_packed, RDX=C, RCX=K
  // R8=A_stride(bytes), R9=C_stride(bytes)

  // Load existing C[4,4] into accumulators
  mov rax, rdx
  movups xmm0, [rdx]        // C[0, 0..3]
  add rdx, r9
  movups xmm1, [rdx]        // C[1, 0..3]
  add rdx, r9
  movups xmm2, [rdx]        // C[2, 0..3]
  add rdx, r9
  movups xmm3, [rdx]        // C[3, 0..3]
  mov rdx, rax

  // Set up row pointers
  mov rax, rdi               // A row 0
  lea r10, [rdi + r8]        // A row 1
  lea r11, [r10 + r8]        // A row 2
  push rbx
  lea rbx, [r11 + r8]        // A row 3

  test rcx, rcx
  jz @store_sse2

@k_loop_sse2:
  // Load B_packed[k, 0..3]
  movups xmm4, [rsi]

  // Broadcast A[row0, k] and accumulate
  movss xmm5, [rax]
  shufps xmm5, xmm5, 0      // broadcast
  movaps xmm6, xmm4
  mulps xmm6, xmm5
  addps xmm0, xmm6

  // Broadcast A[row1, k] and accumulate
  movss xmm5, [r10]
  shufps xmm5, xmm5, 0
  movaps xmm6, xmm4
  mulps xmm6, xmm5
  addps xmm1, xmm6

  // Broadcast A[row2, k] and accumulate
  movss xmm5, [r11]
  shufps xmm5, xmm5, 0
  movaps xmm6, xmm4
  mulps xmm6, xmm5
  addps xmm2, xmm6

  // Broadcast A[row3, k] and accumulate
  movss xmm5, [rbx]
  shufps xmm5, xmm5, 0
  movaps xmm6, xmm4
  mulps xmm6, xmm5
  addps xmm3, xmm6

  // Advance pointers
  add rax, 4
  add r10, 4
  add r11, 4
  add rbx, 4
  add rsi, 16               // 4 floats = 16 bytes

  dec rcx
  jnz @k_loop_sse2

@store_sse2:
  // Store C[4,4]
  movups [rdx], xmm0
  add rdx, r9
  movups [rdx], xmm1
  add rdx, r9
  movups [rdx], xmm2
  add rdx, r9
  movups [rdx], xmm3

  pop rbx
end;

// Zero-init version: C[4,4] = A[4,K] * B_packed[K,4]
procedure GemmMicro4x4F32_SSE2_Zero(AA, AB, AC: PSingle;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  {$IFNDEF UNIX}
  mov rdi, rcx
  mov rsi, rdx
  mov rdx, r8
  mov rcx, r9
  {$ENDIF}

  // Zero accumulators
  xorps xmm0, xmm0
  xorps xmm1, xmm1
  xorps xmm2, xmm2
  xorps xmm3, xmm3

  // Set up row pointers
  mov rax, rdi
  lea r10, [rdi + r8]
  lea r11, [r10 + r8]
  push rbx
  lea rbx, [r11 + r8]

  test rcx, rcx
  jz @store_sse2z

@k_loop_sse2z:
  movups xmm4, [rsi]

  movss xmm5, [rax]
  shufps xmm5, xmm5, 0
  mulps xmm5, xmm4
  addps xmm0, xmm5

  movss xmm5, [r10]
  shufps xmm5, xmm5, 0
  mulps xmm5, xmm4
  addps xmm1, xmm5

  movss xmm5, [r11]
  shufps xmm5, xmm5, 0
  mulps xmm5, xmm4
  addps xmm2, xmm5

  movss xmm5, [rbx]
  shufps xmm5, xmm5, 0
  mulps xmm5, xmm4
  addps xmm3, xmm5

  add rax, 4
  add r10, 4
  add r11, 4
  add rbx, 4
  add rsi, 16

  dec rcx
  jnz @k_loop_sse2z

@store_sse2z:
  movups [rdx], xmm0
  add rdx, r9
  movups [rdx], xmm1
  add rdx, r9
  movups [rdx], xmm2
  add rdx, r9
  movups [rdx], xmm3

  pop rbx
end;

// === SSE2 F64 2×2 Microkernel ===
// C[2,2] += A[2,K] * B_packed[K,2]
// Uses 2 XMM accumulators (each holds 2 doubles)
procedure GemmMicro2x2F64_SSE2(AA, AB, AC: PDouble;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  {$IFNDEF UNIX}
  mov rdi, rcx
  mov rsi, rdx
  mov rdx, r8
  mov rcx, r9
  {$ENDIF}

  // Load existing C[2,2]
  mov rax, rdx
  movupd xmm0, [rdx]        // C[0, 0..1]
  add rdx, r9
  movupd xmm1, [rdx]        // C[1, 0..1]
  mov rdx, rax

  // Set up row pointers
  mov rax, rdi               // A row 0
  lea r10, [rdi + r8]        // A row 1

  test rcx, rcx
  jz @store_f64s

@k_loop_f64s:
  // Load B_packed[k, 0..1]
  movupd xmm2, [rsi]

  // Broadcast A[row0, k]
  movsd xmm3, [rax]
  movlhps xmm3, xmm3        // [a0k, a0k]
  mulpd xmm3, xmm2
  addpd xmm0, xmm3

  // Broadcast A[row1, k]
  movsd xmm3, [r10]
  movlhps xmm3, xmm3
  mulpd xmm3, xmm2
  addpd xmm1, xmm3

  add rax, 8
  add r10, 8
  add rsi, 16               // 2 doubles = 16 bytes

  dec rcx
  jnz @k_loop_f64s

@store_f64s:
  movupd [rdx], xmm0
  add rdx, r9
  movupd [rdx], xmm1
end;

// Zero-init version
procedure GemmMicro2x2F64_SSE2_Zero(AA, AB, AC: PDouble;
  AK, AAStride, ACStride: SizeUInt); assembler; nostackframe;
asm
  {$IFNDEF UNIX}
  mov rdi, rcx
  mov rsi, rdx
  mov rdx, r8
  mov rcx, r9
  {$ENDIF}

  xorpd xmm0, xmm0
  xorpd xmm1, xmm1

  mov rax, rdi
  lea r10, [rdi + r8]

  test rcx, rcx
  jz @store_f64sz

@k_loop_f64sz:
  movupd xmm2, [rsi]

  movsd xmm3, [rax]
  movlhps xmm3, xmm3
  mulpd xmm3, xmm2
  addpd xmm0, xmm3

  movsd xmm3, [r10]
  movlhps xmm3, xmm3
  mulpd xmm3, xmm2
  addpd xmm1, xmm3

  add rax, 8
  add r10, 8
  add rsi, 16

  dec rcx
  jnz @k_loop_f64sz

@store_f64sz:
  movupd [rdx], xmm0
  add rdx, r9
  movupd [rdx], xmm1
end;

{$ENDIF} // SIMD_X86_AVAILABLE

end.
