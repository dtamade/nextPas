{
  nextpas.core.hash.sha256.shani.inc — SHA-NI 硬件加速 SHA-256 ProcessBlock
  使用 Intel SHA Extensions: sha256rnds2, sha256msg1, sha256msg2
  要求: SSE4.1 + SHA-NI (CPUID.7.0:EBX bit 29)
}

{$ASMMODE ATT}

const
  SHANI_K256: array[0..63] of UInt32 = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5,
    $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3,
    $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc,
    $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7,
    $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13,
    $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3,
    $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5,
    $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208,
    $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

  SHANI_BSWAP_MASK: array[0..15] of Byte = (
    3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12
  );

procedure ProcessBlockSHANI(ABlock: PByte; AState: PUInt32); assembler; nostackframe;
asm
  leaq    SHANI_BSWAP_MASK(%rip), %rax
  movdqu  (%rax), %xmm9

  movdqu  (%rsi), %xmm1
  movdqu  16(%rsi), %xmm2

  pshufd  $0x1B, %xmm1, %xmm10
  pshufd  $0x1B, %xmm2, %xmm2
  movdqa  %xmm2, %xmm1
  punpckhqdq %xmm10, %xmm1
  punpcklqdq %xmm10, %xmm2

  movdqa  %xmm1, %xmm7
  movdqa  %xmm2, %xmm8

  leaq    SHANI_K256(%rip), %rax

  movdqu  (%rdi), %xmm3
  pshufb  %xmm9, %xmm3
  movdqu  16(%rdi), %xmm4
  pshufb  %xmm9, %xmm4
  movdqu  32(%rdi), %xmm5
  pshufb  %xmm9, %xmm5
  movdqu  48(%rdi), %xmm6
  pshufb  %xmm9, %xmm6
  // Rounds 0-3
  movdqa  (%rax), %xmm0
  paddd   %xmm3, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2

  // Rounds 4-7
  movdqa  16(%rax), %xmm0
  paddd   %xmm4, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  sha256msg1 %xmm4, %xmm3

  // Rounds 8-11
  movdqa  32(%rax), %xmm0
  paddd   %xmm5, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  sha256msg1 %xmm5, %xmm4

  // Rounds 12-15
  movdqa  48(%rax), %xmm0
  paddd   %xmm6, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm6, %xmm10
  palignr $4, %xmm5, %xmm10
  paddd   %xmm10, %xmm3
  sha256msg2 %xmm6, %xmm3
  sha256msg1 %xmm6, %xmm5

  // Rounds 16-19
  movdqa  64(%rax), %xmm0
  paddd   %xmm3, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm3, %xmm10
  palignr $4, %xmm6, %xmm10
  paddd   %xmm10, %xmm4
  sha256msg2 %xmm3, %xmm4
  sha256msg1 %xmm3, %xmm6

  // Rounds 20-23
  movdqa  80(%rax), %xmm0
  paddd   %xmm4, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm4, %xmm10
  palignr $4, %xmm3, %xmm10
  paddd   %xmm10, %xmm5
  sha256msg2 %xmm4, %xmm5
  sha256msg1 %xmm4, %xmm3

  // Rounds 24-27
  movdqa  96(%rax), %xmm0
  paddd   %xmm5, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm5, %xmm10
  palignr $4, %xmm4, %xmm10
  paddd   %xmm10, %xmm6
  sha256msg2 %xmm5, %xmm6
  sha256msg1 %xmm5, %xmm4
  // Rounds 28-31
  movdqa  112(%rax), %xmm0
  paddd   %xmm6, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm6, %xmm10
  palignr $4, %xmm5, %xmm10
  paddd   %xmm10, %xmm3
  sha256msg2 %xmm6, %xmm3
  sha256msg1 %xmm6, %xmm5

  // Rounds 32-35
  movdqa  128(%rax), %xmm0
  paddd   %xmm3, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm3, %xmm10
  palignr $4, %xmm6, %xmm10
  paddd   %xmm10, %xmm4
  sha256msg2 %xmm3, %xmm4
  sha256msg1 %xmm3, %xmm6

  // Rounds 36-39
  movdqa  144(%rax), %xmm0
  paddd   %xmm4, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm4, %xmm10
  palignr $4, %xmm3, %xmm10
  paddd   %xmm10, %xmm5
  sha256msg2 %xmm4, %xmm5
  sha256msg1 %xmm4, %xmm3

  // Rounds 40-43
  movdqa  160(%rax), %xmm0
  paddd   %xmm5, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm5, %xmm10
  palignr $4, %xmm4, %xmm10
  paddd   %xmm10, %xmm6
  sha256msg2 %xmm5, %xmm6
  sha256msg1 %xmm5, %xmm4

  // Rounds 44-47
  movdqa  176(%rax), %xmm0
  paddd   %xmm6, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm6, %xmm10
  palignr $4, %xmm5, %xmm10
  paddd   %xmm10, %xmm3
  sha256msg2 %xmm6, %xmm3
  sha256msg1 %xmm6, %xmm5

  // Rounds 48-51
  movdqa  192(%rax), %xmm0
  paddd   %xmm3, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm3, %xmm10
  palignr $4, %xmm6, %xmm10
  paddd   %xmm10, %xmm4
  sha256msg2 %xmm3, %xmm4

  // Rounds 52-55
  movdqa  208(%rax), %xmm0
  paddd   %xmm4, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2
  movdqa  %xmm4, %xmm10
  palignr $4, %xmm3, %xmm10
  paddd   %xmm10, %xmm5
  sha256msg2 %xmm4, %xmm5

  // Rounds 56-59
  movdqa  224(%rax), %xmm0
  paddd   %xmm5, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2

  // Rounds 60-63
  movdqa  240(%rax), %xmm0
  paddd   %xmm6, %xmm0
  sha256rnds2 %xmm2, %xmm1
  pshufd  $0x0E, %xmm0, %xmm0
  sha256rnds2 %xmm1, %xmm2

  // Add back saved state
  paddd   %xmm7, %xmm1
  paddd   %xmm8, %xmm2

  // Convert back to memory layout
  movdqa  %xmm1, %xmm10
  punpckhqdq %xmm2, %xmm1
  punpcklqdq %xmm2, %xmm10
  pshufd  $0xB1, %xmm1, %xmm1
  pshufd  $0xB1, %xmm10, %xmm10

  movdqu  %xmm1, (%rsi)
  movdqu  %xmm10, 16(%rsi)
end;
