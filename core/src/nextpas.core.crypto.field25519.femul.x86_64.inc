{ nextpas.core.crypto.field25519.femul.x86_64.inc
  Full x86_64 ASM implementation of FeMul for GF(2^255-19)
  10-limb radix-25.5 representation

  Calling convention (SysV AMD64):
    rdi = @H (output)
    rsi = @F (input 1)
    rdx = @G (input 2)
}

procedure FeMulASM(out H: TFe25519; const F, G: TFe25519); assembler; nostackframe;
asm
  push %rbx
  push %r12
  push %r13
  push %r14
  push %r15
  push %rbp

  movq %rdi, %r15    // r15 = @H
  movq %rdx, %rbp    // rbp = @G

  // Precompute g[i]*19 for i=1..9, store on stack (72 bytes)
  sub $80, %rsp       // 9*8 + 8 padding for alignment
  movq 8(%rbp), %rax;  imulq $19, %rax, %rax; movq %rax, 0(%rsp)
  movq 16(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 8(%rsp)
  movq 24(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 16(%rsp)
  movq 32(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 24(%rsp)
  movq 40(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 32(%rsp)
  movq 48(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 40(%rsp)
  movq 56(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 48(%rsp)
  movq 64(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 56(%rsp)
  movq 72(%rbp), %rax; imulq $19, %rax, %rax; movq %rax, 64(%rsp)

  // Notation: f[i] = (%rsi + i*8), g[i] = (%rbp + i*8), g[i]_19 = (%rsp + (i-1)*8)
  // H[i] uses f1_2=2*f[1], f3_2=2*f[3], f5_2=2*f[5], f7_2=2*f[7], f9_2=2*f[9]

  // === H[0] = f0*g0 + f1_2*g9_19 + f2*g8_19 + f3_2*g7_19 + f4*g6_19
  //          + f5_2*g5_19 + f6*g4_19 + f7_2*g3_19 + f8*g2_19 + f9_2*g1_19
  movq 0(%rsi), %rax; imulq 0(%rbp), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 48(%rsp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 32(%rsp), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 24(%rsp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 16(%rsp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 8(%rsp), %rax; addq %rax, %r8
  movq 72(%rsi), %rax; addq %rax, %rax; imulq 0(%rsp), %rax; addq %rax, %r8
  // r8 = H[0]

  // === H[1] = f0*g1 + f1*g0 + f2*g9_19 + f3*g8_19 + f4*g7_19
  //          + f5*g6_19 + f6*g5_19 + f7*g4_19 + f8*g3_19 + f9*g2_19
  movq 0(%rsi), %rax; imulq 8(%rbp), %rax; movq %rax, %r9
  movq 8(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r9
  movq 16(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r9
  movq 24(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r9
  movq 32(%rsi), %rax; imulq 48(%rsp), %rax; addq %rax, %r9
  movq 40(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r9
  movq 48(%rsi), %rax; imulq 32(%rsp), %rax; addq %rax, %r9
  movq 56(%rsi), %rax; imulq 24(%rsp), %rax; addq %rax, %r9
  movq 64(%rsi), %rax; imulq 16(%rsp), %rax; addq %rax, %r9
  movq 72(%rsi), %rax; imulq 8(%rsp), %rax; addq %rax, %r9
  // r9 = H[1]

  // === H[2] = f0*g2 + f1_2*g1 + f2*g0 + f3_2*g9_19 + f4*g8_19
  //          + f5_2*g7_19 + f6*g6_19 + f7_2*g5_19 + f8*g4_19 + f9_2*g3_19
  movq 0(%rsi), %rax; imulq 16(%rbp), %rax; movq %rax, %r10
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 8(%rbp), %rax; addq %rax, %r10
  movq 16(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r10
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r10
  movq 32(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r10
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 48(%rsp), %rax; addq %rax, %r10
  movq 48(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r10
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 32(%rsp), %rax; addq %rax, %r10
  movq 64(%rsi), %rax; imulq 24(%rsp), %rax; addq %rax, %r10
  movq 72(%rsi), %rax; addq %rax, %rax; imulq 16(%rsp), %rax; addq %rax, %r10
  // r10 = H[2]

  // === H[3] = f0*g3 + f1*g2 + f2*g1 + f3*g0 + f4*g9_19
  //          + f5*g8_19 + f6*g7_19 + f7*g6_19 + f8*g5_19 + f9*g4_19
  movq 0(%rsi), %rax; imulq 24(%rbp), %rax; movq %rax, %r11
  movq 8(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r11
  movq 16(%rsi), %rax; imulq 8(%rbp), %rax; addq %rax, %r11
  movq 24(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r11
  movq 32(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r11
  movq 40(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r11
  movq 48(%rsi), %rax; imulq 48(%rsp), %rax; addq %rax, %r11
  movq 56(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r11
  movq 64(%rsi), %rax; imulq 32(%rsp), %rax; addq %rax, %r11
  movq 72(%rsi), %rax; imulq 24(%rsp), %rax; addq %rax, %r11
  // r11 = H[3]

  // === H[4] = f0*g4 + f1_2*g3 + f2*g2 + f3_2*g1 + f4*g0
  //          + f5_2*g9_19 + f6*g8_19 + f7_2*g7_19 + f8*g6_19 + f9_2*g5_19
  movq 0(%rsi), %rax; imulq 32(%rbp), %rax; movq %rax, %r12
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 24(%rbp), %rax; addq %rax, %r12
  movq 16(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r12
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 8(%rbp), %rax; addq %rax, %r12
  movq 32(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r12
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r12
  movq 48(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r12
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 48(%rsp), %rax; addq %rax, %r12
  movq 64(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r12
  movq 72(%rsi), %rax; addq %rax, %rax; imulq 32(%rsp), %rax; addq %rax, %r12
  // r12 = H[4]

  // Store H[0..4] to output, free registers for H[5..9]
  movq %r8, 0(%r15)
  movq %r9, 8(%r15)
  movq %r10, 16(%r15)
  movq %r11, 24(%r15)
  movq %r12, 32(%r15)

  // === H[5] through H[9] — same pattern, store directly ===

  // H[5] = f0*g5 + f1*g4 + f2*g3 + f3*g2 + f4*g1 + f5*g0
  //       + f6*g9_19 + f7*g8_19 + f8*g7_19 + f9*g6_19
  movq 0(%rsi), %rax; imulq 40(%rbp), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; imulq 32(%rbp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; imulq 24(%rbp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; imulq 8(%rbp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 48(%rsp), %rax; addq %rax, %r8
  movq 72(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r8
  movq %r8, 40(%r15)

  // H[6] = f0*g6 + f1_2*g5 + f2*g4 + f3_2*g3 + f4*g2 + f5_2*g1 + f6*g0
  //       + f7_2*g9_19 + f8*g8_19 + f9_2*g7_19
  movq 0(%rsi), %rax; imulq 48(%rbp), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 40(%rbp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; imulq 32(%rbp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 24(%rbp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 8(%rbp), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq 72(%rsi), %rax; addq %rax, %rax; imulq 48(%rsp), %rax; addq %rax, %r8
  movq %r8, 48(%r15)

  // H[7] = f0*g7 + f1*g6 + f2*g5 + f3*g4 + f4*g3 + f5*g2 + f6*g1 + f7*g0
  //       + f8*g9_19 + f9*g8_19
  movq 0(%rsi), %rax; imulq 56(%rbp), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; imulq 48(%rbp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; imulq 40(%rbp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; imulq 32(%rbp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; imulq 24(%rbp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 8(%rbp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 72(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq %r8, 56(%r15)

  // H[8] = f0*g8 + f1_2*g7 + f2*g6 + f3_2*g5 + f4*g4 + f5_2*g3 + f6*g2
  //       + f7_2*g1 + f8*g0 + f9_2*g9_19
  movq 0(%rsi), %rax; imulq 64(%rbp), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 56(%rbp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; imulq 48(%rbp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 40(%rbp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; imulq 32(%rbp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 24(%rbp), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 8(%rbp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r8
  movq 72(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq %r8, 64(%r15)

  // H[9] = f0*g9 + f1*g8 + f2*g7 + f3*g6 + f4*g5 + f5*g4 + f6*g3
  //       + f7*g2 + f8*g1 + f9*g0
  movq 0(%rsi), %rax; imulq 72(%rbp), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; imulq 64(%rbp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; imulq 56(%rbp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; imulq 48(%rbp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; imulq 40(%rbp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; imulq 32(%rbp), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 24(%rbp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; imulq 16(%rbp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 8(%rbp), %rax; addq %rax, %r8
  movq 72(%rsi), %rax; imulq 0(%rbp), %rax; addq %rax, %r8
  movq %r8, 72(%r15)

  // === Carry chain ===
  // Load H[0..9] from output
  movq 0(%r15), %r8
  movq 8(%r15), %r9
  movq 16(%r15), %r10
  movq 24(%r15), %r11
  movq 32(%r15), %r12
  movq 40(%r15), %r13
  movq 48(%r15), %r14
  movq 56(%r15), %rbx
  movq 64(%r15), %rcx
  movq 72(%r15), %rdi

  // c = (H0 + 2^25) >> 26; H1 += c; H0 -= c << 26
  movq %r8, %rax; addq $33554432, %rax; sarq $26, %rax  // c
  addq %rax, %r9; shlq $26, %rax; subq %rax, %r8

  // c = (H4 + 2^25) >> 26; H5 += c; H4 -= c << 26
  movq %r12, %rax; addq $33554432, %rax; sarq $26, %rax
  addq %rax, %r13; shlq $26, %rax; subq %rax, %r12

  // c = (H1 + 2^24) >> 25; H2 += c; H1 -= c << 25
  movq %r9, %rax; addq $16777216, %rax; sarq $25, %rax
  addq %rax, %r10; shlq $25, %rax; subq %rax, %r9

  // c = (H5 + 2^24) >> 25; H6 += c; H5 -= c << 25
  movq %r13, %rax; addq $16777216, %rax; sarq $25, %rax
  addq %rax, %r14; shlq $25, %rax; subq %rax, %r13

  // c = (H2 + 2^25) >> 26; H3 += c; H2 -= c << 26
  movq %r10, %rax; addq $33554432, %rax; sarq $26, %rax
  addq %rax, %r11; shlq $26, %rax; subq %rax, %r10

  // c = (H6 + 2^25) >> 26; H7 += c; H6 -= c << 26
  movq %r14, %rax; addq $33554432, %rax; sarq $26, %rax
  addq %rax, %rbx; shlq $26, %rax; subq %rax, %r14

  // c = (H3 + 2^24) >> 25; H4 += c; H3 -= c << 25
  movq %r11, %rax; addq $16777216, %rax; sarq $25, %rax
  addq %rax, %r12; shlq $25, %rax; subq %rax, %r11

  // c = (H7 + 2^24) >> 25; H8 += c; H7 -= c << 25
  movq %rbx, %rax; addq $16777216, %rax; sarq $25, %rax
  addq %rax, %rcx; shlq $25, %rax; subq %rax, %rbx

  // c = (H4 + 2^25) >> 26; H5 += c; H4 -= c << 26
  movq %r12, %rax; addq $33554432, %rax; sarq $26, %rax
  addq %rax, %r13; shlq $26, %rax; subq %rax, %r12

  // c = (H8 + 2^25) >> 26; H9 += c; H8 -= c << 26
  movq %rcx, %rax; addq $33554432, %rax; sarq $26, %rax
  addq %rax, %rdi; shlq $26, %rax; subq %rax, %rcx

  // c = (H9 + 2^24) >> 25; H0 += c*19; H9 -= c << 25
  movq %rdi, %rax; addq $16777216, %rax; sarq $25, %rax
  imulq $19, %rax, %rdx; addq %rdx, %r8; shlq $25, %rax; subq %rax, %rdi

  // c = (H0 + 2^25) >> 26; H1 += c; H0 -= c << 26
  movq %r8, %rax; addq $33554432, %rax; sarq $26, %rax
  addq %rax, %r9; shlq $26, %rax; subq %rax, %r8

  // Store final H[0..9]
  movq %r8, 0(%r15)
  movq %r9, 8(%r15)
  movq %r10, 16(%r15)
  movq %r11, 24(%r15)
  movq %r12, 32(%r15)
  movq %r13, 40(%r15)
  movq %r14, 48(%r15)
  movq %rbx, 56(%r15)
  movq %rcx, 64(%r15)
  movq %rdi, 72(%r15)

  add $80, %rsp
  pop %rbp
  pop %r15
  pop %r14
  pop %r13
  pop %r12
  pop %rbx
end;
