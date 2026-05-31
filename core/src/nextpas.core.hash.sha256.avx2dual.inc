{
  nextpas.core.hash.sha256.avx2dual.inc — AVX2 dual-block SHA-256
  Message schedule interleaved with block 0 rounds for full overlap.
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

  leaq DUAL_FLIP(%rip), %rax
  vmovdqu (%rax), %ymm12
  leaq DUAL_00BA(%rip), %rax
  vmovdqu (%rax), %ymm13
  leaq DUAL_DC00(%rip), %rax
  vmovdqu (%rax), %ymm14
  leaq K(%rip), %rbp

  vmovdqu (%r14), %ymm0
  vmovdqu 32(%r14), %ymm1
  vmovdqu 64(%r14), %ymm2
  vmovdqu 96(%r14), %ymm3
  vpshufb %ymm12, %ymm0, %ymm0
  vpshufb %ymm12, %ymm1, %ymm1
  vpshufb %ymm12, %ymm2, %ymm2
  vpshufb %ymm12, %ymm3, %ymm3
  vperm2i128 $0x20, %ymm2, %ymm0, %ymm4
  vperm2i128 $0x31, %ymm2, %ymm0, %ymm5
  vperm2i128 $0x20, %ymm3, %ymm1, %ymm6
  vperm2i128 $0x31, %ymm3, %ymm1, %ymm7

  // Store W[0..15]+K
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

  // Block 0: rounds + interleaved msg schedule for W[16..63]
  movl 0(%r15), %eax
  movl 4(%r15), %ebx
  movl 8(%r15), %ecx
  movl 12(%r15), %edx
  movl 16(%r15), %r8d
  movl 20(%r15), %r9d
  movl 24(%r15), %r10d
  movl 28(%r15), %r11d
  {$I nextpas.core.hash.sha256.avx2dual.b0rounds.inc}
  addl %eax, 0(%r15)
  addl %ebx, 4(%r15)
  addl %ecx, 8(%r15)
  addl %edx, 12(%r15)
  addl %r8d, 16(%r15)
  addl %r9d, 20(%r15)
  addl %r10d, 24(%r15)
  addl %r11d, 28(%r15)

  // Block 1: rounds only (W+K at offset 256)
  movl 0(%r15), %eax
  movl 4(%r15), %ebx
  movl 8(%r15), %ecx
  movl 12(%r15), %edx
  movl 16(%r15), %r8d
  movl 20(%r15), %r9d
  movl 24(%r15), %r10d
  movl 28(%r15), %r11d
  addq $256, %rsp
  {$I nextpas.core.hash.sha256.avx2dual.b1rounds.inc}
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
