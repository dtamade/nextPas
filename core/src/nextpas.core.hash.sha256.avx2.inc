{
  nextpas.core.hash.sha256.avx2.inc — Pure SIMD message schedule
  Uses vpsrlq trick for sigma1 (no scalar extraction)
  Requires: AVX + SSSE3 + BMI2
}

{$ASMMODE ATT}

const
  SHUF_FLIP: array[0..15] of Byte = (
    3,2,1,0, 7,6,5,4, 11,10,9,8, 15,14,13,12);
  SHUF_00BA: array[0..15] of Byte = (
    $00,$01,$02,$03, $08,$09,$0A,$0B, $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF);
  SHUF_DC00: array[0..15] of Byte = (
    $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF, $00,$01,$02,$03, $08,$09,$0A,$0B);

procedure ProcessBlockAVX2(ABlock: PByte; AState: PUInt32); assembler; nostackframe;
asm
  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15
  pushq %rbp
  movq %rdi, %r14
  movq %rsi, %r15
  subq $272, %rsp

  // Load masks
  leaq SHUF_FLIP(%rip), %rax
  vmovdqu (%rax), %xmm12
  leaq SHUF_00BA(%rip), %rax
  vmovdqu (%rax), %xmm13
  leaq SHUF_DC00(%rip), %rax
  vmovdqu (%rax), %xmm14
  leaq K(%rip), %rbp

  // Load and byte-swap W[0..15]
  vmovdqu (%r14), %xmm4
  vpshufb %xmm12, %xmm4, %xmm4
  vmovdqu 16(%r14), %xmm5
  vpshufb %xmm12, %xmm5, %xmm5
  vmovdqu 32(%r14), %xmm6
  vpshufb %xmm12, %xmm6, %xmm6
  vmovdqu 48(%r14), %xmm7
  vpshufb %xmm12, %xmm7, %xmm7

  // Store W[0..15]+K to stack
  vpaddd (%rbp), %xmm4, %xmm0
  vmovdqu %xmm0, (%rsp)
  vpaddd 16(%rbp), %xmm5, %xmm0
  vmovdqu %xmm0, 16(%rsp)
  vpaddd 32(%rbp), %xmm6, %xmm0
  vmovdqu %xmm0, 32(%rsp)
  vpaddd 48(%rbp), %xmm7, %xmm0
  vmovdqu %xmm0, 48(%rsp)

  // W[16..19] — pure SIMD
  vpalignr $4, %xmm4, %xmm5, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm6, %xmm7, %xmm2
  vpaddd %xmm4, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm7, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm4
  vpaddd 64(%rbp), %xmm4, %xmm0
  vmovdqu %xmm0, 64(%rsp)

  // W[20..23] — pure SIMD
  vpalignr $4, %xmm5, %xmm6, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm7, %xmm4, %xmm2
  vpaddd %xmm5, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm4, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm5
  vpaddd 80(%rbp), %xmm5, %xmm0
  vmovdqu %xmm0, 80(%rsp)

  // W[24..27] — pure SIMD
  vpalignr $4, %xmm6, %xmm7, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm4, %xmm5, %xmm2
  vpaddd %xmm6, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm5, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm6
  vpaddd 96(%rbp), %xmm6, %xmm0
  vmovdqu %xmm0, 96(%rsp)

  // W[28..31] — pure SIMD
  vpalignr $4, %xmm7, %xmm4, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm5, %xmm6, %xmm2
  vpaddd %xmm7, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm6, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm7
  vpaddd 112(%rbp), %xmm7, %xmm0
  vmovdqu %xmm0, 112(%rsp)

  // W[32..35] — pure SIMD
  vpalignr $4, %xmm4, %xmm5, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm6, %xmm7, %xmm2
  vpaddd %xmm4, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm7, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm4
  vpaddd 128(%rbp), %xmm4, %xmm0
  vmovdqu %xmm0, 128(%rsp)

  // W[36..39] — pure SIMD
  vpalignr $4, %xmm5, %xmm6, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm7, %xmm4, %xmm2
  vpaddd %xmm5, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm4, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm5
  vpaddd 144(%rbp), %xmm5, %xmm0
  vmovdqu %xmm0, 144(%rsp)

  // W[40..43] — pure SIMD
  vpalignr $4, %xmm6, %xmm7, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm4, %xmm5, %xmm2
  vpaddd %xmm6, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm5, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm6
  vpaddd 160(%rbp), %xmm6, %xmm0
  vmovdqu %xmm0, 160(%rsp)

  // W[44..47] — pure SIMD
  vpalignr $4, %xmm7, %xmm4, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm5, %xmm6, %xmm2
  vpaddd %xmm7, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm6, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm7
  vpaddd 176(%rbp), %xmm7, %xmm0
  vmovdqu %xmm0, 176(%rsp)

  // W[48..51] — pure SIMD
  vpalignr $4, %xmm4, %xmm5, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm6, %xmm7, %xmm2
  vpaddd %xmm4, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm7, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm4
  vpaddd 192(%rbp), %xmm4, %xmm0
  vmovdqu %xmm0, 192(%rsp)

  // W[52..55] — pure SIMD
  vpalignr $4, %xmm5, %xmm6, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm7, %xmm4, %xmm2
  vpaddd %xmm5, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm4, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm5
  vpaddd 208(%rbp), %xmm5, %xmm0
  vmovdqu %xmm0, 208(%rsp)

  // W[56..59] — pure SIMD
  vpalignr $4, %xmm6, %xmm7, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm4, %xmm5, %xmm2
  vpaddd %xmm6, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm5, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm6
  vpaddd 224(%rbp), %xmm6, %xmm0
  vmovdqu %xmm0, 224(%rsp)

  // W[60..63] — pure SIMD
  vpalignr $4, %xmm7, %xmm4, %xmm0
  vpsrld $7, %xmm0, %xmm1
  vpslld $25, %xmm0, %xmm2
  vpor %xmm2, %xmm1, %xmm1
  vpsrld $18, %xmm0, %xmm2
  vpslld $14, %xmm0, %xmm3
  vpor %xmm3, %xmm2, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpsrld $3, %xmm0, %xmm2
  vpxor %xmm2, %xmm1, %xmm1
  vpalignr $4, %xmm5, %xmm6, %xmm2
  vpaddd %xmm7, %xmm1, %xmm0
  vpaddd %xmm2, %xmm0, %xmm0
  vpshufd $0xFA, %xmm6, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm13, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm0
  vpshufd $0x50, %xmm0, %xmm2
  vpsrld $10, %xmm2, %xmm8
  vpsrlq $17, %xmm2, %xmm3
  vpsrlq $19, %xmm2, %xmm2
  vpxor %xmm2, %xmm3, %xmm3
  vpxor %xmm8, %xmm3, %xmm3
  vpshufb %xmm14, %xmm3, %xmm3
  vpaddd %xmm3, %xmm0, %xmm7
  vpaddd 240(%rbp), %xmm7, %xmm0
  vmovdqu %xmm0, 240(%rsp)

  // Load state and do 64 rounds
  movl 0(%r15), %eax
  movl 4(%r15), %ebx
  movl 8(%r15), %ecx
  movl 12(%r15), %edx
  movl 16(%r15), %r8d
  movl 20(%r15), %r9d
  movl 24(%r15), %r10d
  movl 28(%r15), %r11d

  {$I nextpas.core.hash.sha256.avx2.rounds.inc}

  addl %eax, 0(%r15)
  addl %ebx, 4(%r15)
  addl %ecx, 8(%r15)
  addl %edx, 12(%r15)
  addl %r8d, 16(%r15)
  addl %r9d, 20(%r15)
  addl %r10d, 24(%r15)
  addl %r11d, 28(%r15)

  addq $272, %rsp
  popq %rbp
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  vzeroupper
end;
