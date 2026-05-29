{
  nextpas.core.hash.sha256.avx2dual.inc — AVX2 dual-block SHA-256
  256-bit message schedule processes 2 blocks simultaneously.
  Requires: AVX2 + BMI2 + SSSE3
}

{$ASMMODE ATT}

const
  DUAL_FLIP: array[0..31] of Byte = (
    3,2,1,0, 7,6,5,4, 11,10,9,8, 15,14,13,12,
    3,2,1,0, 7,6,5,4, 11,10,9,8, 15,14,13,12);
  DUAL_00BA: array[0..31] of Byte = (
    $00,$01,$02,$03, $08,$09,$0A,$0B, $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF,
    $00,$01,$02,$03, $08,$09,$0A,$0B, $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF);
  DUAL_DC00: array[0..31] of Byte = (
    $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF, $00,$01,$02,$03, $08,$09,$0A,$0B,
    $FF,$FF,$FF,$FF, $FF,$FF,$FF,$FF, $00,$01,$02,$03, $08,$09,$0A,$0B);

procedure ProcessBlocks2AVX2(ABlocks: PByte; AState: PUInt32); assembler; nostackframe;
{ Process 2 consecutive 64-byte blocks. ABlocks=%rdi, AState=%rsi }
asm
  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15
  pushq %rbp
  movq %rdi, %r14
  movq %rsi, %r15
  subq $528, %rsp

  // Load masks
  leaq DUAL_FLIP(%rip), %rax
  vmovdqu (%rax), %ymm12
  leaq DUAL_00BA(%rip), %rax
  vmovdqu (%rax), %ymm13
  leaq DUAL_DC00(%rip), %rax
  vmovdqu (%rax), %ymm14
  leaq K(%rip), %rbp

  // Load 2 blocks (128 bytes), byte-swap, transpose
  vmovdqu (%r14), %ymm0
  vmovdqu 32(%r14), %ymm1
  vmovdqu 64(%r14), %ymm2
  vmovdqu 96(%r14), %ymm3
  vpshufb %ymm12, %ymm0, %ymm0
  vpshufb %ymm12, %ymm1, %ymm1
  vpshufb %ymm12, %ymm2, %ymm2
  vpshufb %ymm12, %ymm3, %ymm3
  // Transpose: each YMM = [block0_W[i..i+3], block1_W[i..i+3]]
  vperm2i128 $0x20, %ymm2, %ymm0, %ymm4
  vperm2i128 $0x31, %ymm2, %ymm0, %ymm5
  vperm2i128 $0x20, %ymm3, %ymm1, %ymm6
  vperm2i128 $0x31, %ymm3, %ymm1, %ymm7

  // Store W[0..15]+K for both blocks
  // Low 128 bits → block0 (offset 0), high 128 bits → block1 (offset 256)
  vbroadcasti128 (%rbp), %ymm9
  vpaddd %ymm9, %ymm4, %ymm0
  vmovdqu %xmm0, (%rsp)
  vextracti128 $1, %ymm0, 256(%rsp)
  vbroadcasti128 16(%rbp), %ymm9
  vpaddd %ymm9, %ymm5, %ymm0
  vmovdqu %xmm0, 16(%rsp)
  vextracti128 $1, %ymm0, 272(%rsp)
  vbroadcasti128 32(%rbp), %ymm9
  vpaddd %ymm9, %ymm6, %ymm0
  vmovdqu %xmm0, 32(%rsp)
  vextracti128 $1, %ymm0, 288(%rsp)
  vbroadcasti128 48(%rbp), %ymm9
  vpaddd %ymm9, %ymm7, %ymm0
  vmovdqu %xmm0, 48(%rsp)
  vextracti128 $1, %ymm0, 304(%rsp)

  // W[16..19] dual-block
  vpalignr $4, %ymm4, %ymm5, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm6, %ymm7, %ymm2
  vpaddd %ymm4, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm7, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm4
  vbroadcasti128 64(%rbp), %ymm9
  vpaddd %ymm9, %ymm4, %ymm0
  vmovdqu %xmm0, 64(%rsp)
  vextracti128 $1, %ymm0, 320(%rsp)

  // W[20..23] dual-block
  vpalignr $4, %ymm5, %ymm6, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm7, %ymm4, %ymm2
  vpaddd %ymm5, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm4, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm5
  vbroadcasti128 80(%rbp), %ymm9
  vpaddd %ymm9, %ymm5, %ymm0
  vmovdqu %xmm0, 80(%rsp)
  vextracti128 $1, %ymm0, 336(%rsp)

  // W[24..27] dual-block
  vpalignr $4, %ymm6, %ymm7, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm4, %ymm5, %ymm2
  vpaddd %ymm6, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm5, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm6
  vbroadcasti128 96(%rbp), %ymm9
  vpaddd %ymm9, %ymm6, %ymm0
  vmovdqu %xmm0, 96(%rsp)
  vextracti128 $1, %ymm0, 352(%rsp)

  // W[28..31] dual-block
  vpalignr $4, %ymm7, %ymm4, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm5, %ymm6, %ymm2
  vpaddd %ymm7, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm6, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm7
  vbroadcasti128 112(%rbp), %ymm9
  vpaddd %ymm9, %ymm7, %ymm0
  vmovdqu %xmm0, 112(%rsp)
  vextracti128 $1, %ymm0, 368(%rsp)

  // W[32..35] dual-block
  vpalignr $4, %ymm4, %ymm5, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm6, %ymm7, %ymm2
  vpaddd %ymm4, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm7, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm4
  vbroadcasti128 128(%rbp), %ymm9
  vpaddd %ymm9, %ymm4, %ymm0
  vmovdqu %xmm0, 128(%rsp)
  vextracti128 $1, %ymm0, 384(%rsp)

  // W[36..39] dual-block
  vpalignr $4, %ymm5, %ymm6, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm7, %ymm4, %ymm2
  vpaddd %ymm5, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm4, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm5
  vbroadcasti128 144(%rbp), %ymm9
  vpaddd %ymm9, %ymm5, %ymm0
  vmovdqu %xmm0, 144(%rsp)
  vextracti128 $1, %ymm0, 400(%rsp)

  // W[40..43] dual-block
  vpalignr $4, %ymm6, %ymm7, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm4, %ymm5, %ymm2
  vpaddd %ymm6, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm5, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm6
  vbroadcasti128 160(%rbp), %ymm9
  vpaddd %ymm9, %ymm6, %ymm0
  vmovdqu %xmm0, 160(%rsp)
  vextracti128 $1, %ymm0, 416(%rsp)

  // W[44..47] dual-block
  vpalignr $4, %ymm7, %ymm4, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm5, %ymm6, %ymm2
  vpaddd %ymm7, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm6, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm7
  vbroadcasti128 176(%rbp), %ymm9
  vpaddd %ymm9, %ymm7, %ymm0
  vmovdqu %xmm0, 176(%rsp)
  vextracti128 $1, %ymm0, 432(%rsp)

  // W[48..51] dual-block
  vpalignr $4, %ymm4, %ymm5, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm6, %ymm7, %ymm2
  vpaddd %ymm4, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm7, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm4
  vbroadcasti128 192(%rbp), %ymm9
  vpaddd %ymm9, %ymm4, %ymm0
  vmovdqu %xmm0, 192(%rsp)
  vextracti128 $1, %ymm0, 448(%rsp)

  // W[52..55] dual-block
  vpalignr $4, %ymm5, %ymm6, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm7, %ymm4, %ymm2
  vpaddd %ymm5, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm4, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm5
  vbroadcasti128 208(%rbp), %ymm9
  vpaddd %ymm9, %ymm5, %ymm0
  vmovdqu %xmm0, 208(%rsp)
  vextracti128 $1, %ymm0, 464(%rsp)

  // W[56..59] dual-block
  vpalignr $4, %ymm6, %ymm7, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm4, %ymm5, %ymm2
  vpaddd %ymm6, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm5, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm6
  vbroadcasti128 224(%rbp), %ymm9
  vpaddd %ymm9, %ymm6, %ymm0
  vmovdqu %xmm0, 224(%rsp)
  vextracti128 $1, %ymm0, 480(%rsp)

  // W[60..63] dual-block
  vpalignr $4, %ymm7, %ymm4, %ymm0
  vpsrld $7, %ymm0, %ymm1
  vpslld $25, %ymm0, %ymm2
  vpor %ymm2, %ymm1, %ymm1
  vpsrld $18, %ymm0, %ymm2
  vpslld $14, %ymm0, %ymm3
  vpor %ymm3, %ymm2, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpsrld $3, %ymm0, %ymm2
  vpxor %ymm2, %ymm1, %ymm1
  vpalignr $4, %ymm5, %ymm6, %ymm2
  vpaddd %ymm7, %ymm1, %ymm0
  vpaddd %ymm2, %ymm0, %ymm0
  vpshufd $0xFA, %ymm6, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm13, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm0
  vpshufd $0x50, %ymm0, %ymm2
  vpsrld $10, %ymm2, %ymm8
  vpsrlq $17, %ymm2, %ymm3
  vpsrlq $19, %ymm2, %ymm2
  vpxor %ymm2, %ymm3, %ymm3
  vpxor %ymm8, %ymm3, %ymm3
  vpshufb %ymm14, %ymm3, %ymm3
  vpaddd %ymm3, %ymm0, %ymm7
  vbroadcasti128 240(%rbp), %ymm9
  vpaddd %ymm9, %ymm7, %ymm0
  vmovdqu %xmm0, 240(%rsp)
  vextracti128 $1, %ymm0, 496(%rsp)

  // === Block 0: 64 rounds ===
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

  // === Block 1: 64 rounds ===
  movl 0(%r15), %eax
  movl 4(%r15), %ebx
  movl 8(%r15), %ecx
  movl 12(%r15), %edx
  movl 16(%r15), %r8d
  movl 20(%r15), %r9d
  movl 24(%r15), %r10d
  movl 28(%r15), %r11d
  addq $256, %rsp

  {$I nextpas.core.hash.sha256.avx2.rounds.inc}

  subq $256, %rsp
  addl %eax, 0(%r15)
  addl %ebx, 4(%r15)
  addl %ecx, 8(%r15)
  addl %edx, 12(%r15)
  addl %r8d, 16(%r15)
  addl %r9d, 20(%r15)
  addl %r10d, 24(%r15)
  addl %r11d, 28(%r15)

  addq $528, %rsp
  popq %rbp
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
  vzeroupper
end;
