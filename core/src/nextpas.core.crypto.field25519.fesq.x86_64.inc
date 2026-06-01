{ nextpas.core.crypto.field25519.fesq.x86_64.inc
  Full x86_64 ASM implementation of FeSq for GF(2^255-19)
  10-limb radix-25.5 representation (squaring specialization)

  Calling convention (SysV AMD64):
    rdi = @H (output, TFe25519 = array[0..9] of Int64, 80 bytes)
    rsi = @F (input, same type)

  Donna squaring formulas — cross-terms doubled, reduction via *19/*38.
}

procedure FeSqASM(out H: TFe25519; const F: TFe25519); assembler; nostackframe;
asm
  push %rbx
  push %r12
  push %r13
  push %r14
  push %r15
  push %rbp

  movq %rdi, %r15    // r15 = @H

  // Stack: 160 bytes (9*8 precomputed + 8 pad + 80 H temp)
  //   rsp+0..71:  precomputed (f1_38, f2_19, f3_38, f4_19, f5_38, f6_19, f7_38, f8_19, f9_38)
  //   rsp+72..79: padding
  //   rsp+80..159: H[0..9] temp
  sub $160, %rsp

  // Precompute reduced multipliers
  movq 8(%rsi), %rax;  imulq $38, %rax, %rax; movq %rax, 0(%rsp)   // f1_38
  movq 16(%rsi), %rax; imulq $19, %rax, %rax; movq %rax, 8(%rsp)   // f2_19
  movq 24(%rsi), %rax; imulq $38, %rax, %rax; movq %rax, 16(%rsp)  // f3_38
  movq 32(%rsi), %rax; imulq $19, %rax, %rax; movq %rax, 24(%rsp)  // f4_19
  movq 40(%rsi), %rax; imulq $38, %rax, %rax; movq %rax, 32(%rsp)  // f5_38
  movq 48(%rsi), %rax; imulq $19, %rax, %rax; movq %rax, 40(%rsp)  // f6_19
  movq 56(%rsi), %rax; imulq $38, %rax, %rax; movq %rax, 48(%rsp)  // f7_38
  movq 64(%rsi), %rax; imulq $19, %rax, %rax; movq %rax, 56(%rsp)  // f8_19
  movq 72(%rsi), %rax; imulq $38, %rax, %rax; movq %rax, 64(%rsp)  // f9_38

  // Notation:
  //   f[i] = (%rsi + i*8)          — raw limb
  //   fi_38 = 38*f[i] on stack     — for odd i (reduction factor 2*19)
  //   fi_19 = 19*f[i] on stack     — for even i (reduction factor 19)
  //   _2 prefix = doubled via leaq — for cross-term doubling

  // === H[0] = f0*f0 + f1_2*f9_38 + f2_2*f8_19 + f3_2*f7_38 + f4_2*f6_19 + f5*f5_38
  movq 0(%rsi), %rax
  imulq %rax, %rax
  movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; addq %rax, %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 48(%rsp), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; addq %rax, %rax; imulq 40(%rsp), %rax; addq %rax, %r8
  movq 40(%rsi), %rax; imulq 32(%rsp), %rax; addq %rax, %r8

  // === H[1] = f0_2*f1 + f2*f9_38 + f3_2*f8_19 + f4*f7_38 + f5_2*f6_19
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 8(%rsi), %rax; movq %rax, %r9
  movq 16(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r9
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 56(%rsp), %rax; addq %rax, %r9
  movq 32(%rsi), %rax; imulq 48(%rsp), %rax; addq %rax, %r9
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 40(%rsp), %rax; addq %rax, %r9

  // === H[2] = f0_2*f2 + f1_2*f1 + f3_2*f9_38 + f4_2*f8_19 + f5_2*f7_38 + f6*f6_19
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 16(%rsi), %rax; movq %rax, %r10
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 8(%rsi), %rax; addq %rax, %r10
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r10
  movq 32(%rsi), %rax; addq %rax, %rax; imulq 56(%rsp), %rax; addq %rax, %r10
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 48(%rsp), %rax; addq %rax, %r10
  movq 48(%rsi), %rax; imulq 40(%rsp), %rax; addq %rax, %r10

  // === H[3] = f0_2*f3 + f1_2*f2 + f4*f9_38 + f5_2*f8_19 + f6*f7_38
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 24(%rsi), %rax; movq %rax, %r11
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 16(%rsi), %rax; addq %rax, %r11
  movq 32(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r11
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 56(%rsp), %rax; addq %rax, %r11
  movq 48(%rsi), %rax; imulq 48(%rsp), %rax; addq %rax, %r11

  // === H[4] = f0_2*f4 + f1_2*f3_2 + f2*f2 + f5_2*f9_38 + f6_2*f8_19 + f7*f7_38
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 32(%rsi), %rax; movq %rax, %r12
  movq 8(%rsi), %rax; addq %rax, %rax
  movq %rax, %rcx
  movq 24(%rsi), %rax; addq %rax, %rax; imulq %rax, %rcx; addq %rcx, %r12
  movq 16(%rsi), %rax; imulq %rax, %rax; addq %rax, %r12
  movq 40(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r12
  movq 48(%rsi), %rax; addq %rax, %rax; imulq 56(%rsp), %rax; addq %rax, %r12
  movq 56(%rsi), %rax; imulq 48(%rsp), %rax; addq %rax, %r12

  // Store H[0..4] to temp
  movq %r8, 80(%rsp)
  movq %r9, 88(%rsp)
  movq %r10, 96(%rsp)
  movq %r11, 104(%rsp)
  movq %r12, 112(%rsp)

  // === H[5] = f0_2*f5 + f1_2*f4 + f2_2*f3 + f6*f9_38 + f7_2*f8_19
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 40(%rsi), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 32(%rsi), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; addq %rax, %rax; imulq 24(%rsi), %rax; addq %rax, %r8
  movq 48(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq %r8, 120(%rsp)

  // === H[6] = f0_2*f6 + f1_2*f5_2 + f2_2*f4 + f3_2*f3 + f7_2*f9_38 + f8*f8_19
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 48(%rsi), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax
  movq %rax, %rcx
  movq 40(%rsi), %rax; addq %rax, %rax; imulq %rax, %rcx; addq %rcx, %r8
  movq 16(%rsi), %rax; addq %rax, %rax; imulq 32(%rsi), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 24(%rsi), %rax; addq %rax, %r8
  movq 56(%rsi), %rax; addq %rax, %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 56(%rsp), %rax; addq %rax, %r8
  movq %r8, 128(%rsp)

  // === H[7] = f0_2*f7 + f1_2*f6 + f2_2*f5 + f3_2*f4 + f8*f9_38
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 56(%rsi), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 48(%rsi), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; addq %rax, %rax; imulq 40(%rsi), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 32(%rsi), %rax; addq %rax, %r8
  movq 64(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq %r8, 136(%rsp)

  // === H[8] = f0_2*f8 + f1_2*f7_2 + f2_2*f6 + f3_2*f5_2 + f4*f4 + f9*f9_38
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 64(%rsi), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax
  movq %rax, %rcx
  movq 56(%rsi), %rax; addq %rax, %rax; imulq %rax, %rcx; addq %rcx, %r8
  movq 16(%rsi), %rax; addq %rax, %rax; imulq 48(%rsi), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax
  movq %rax, %rcx
  movq 40(%rsi), %rax; addq %rax, %rax; imulq %rax, %rcx; addq %rcx, %r8
  movq 32(%rsi), %rax; imulq %rax, %rax; addq %rax, %r8
  movq 72(%rsi), %rax; imulq 64(%rsp), %rax; addq %rax, %r8
  movq %r8, 144(%rsp)

  // === H[9] = f0_2*f9 + f1_2*f8 + f2_2*f7 + f3_2*f6 + f4_2*f5
  movq 0(%rsi), %rax; addq %rax, %rax; imulq 72(%rsi), %rax; movq %rax, %r8
  movq 8(%rsi), %rax; addq %rax, %rax; imulq 64(%rsi), %rax; addq %rax, %r8
  movq 16(%rsi), %rax; addq %rax, %rax; imulq 56(%rsi), %rax; addq %rax, %r8
  movq 24(%rsi), %rax; addq %rax, %rax; imulq 48(%rsi), %rax; addq %rax, %r8
  movq 32(%rsi), %rax; addq %rax, %rax; imulq 40(%rsi), %rax; addq %rax, %r8
  movq %r8, 152(%rsp)

  // === Carry chain ===
  // Load H[0..9] from temp stack into registers
  movq 80(%rsp), %r8       // H0
  movq 88(%rsp), %r9       // H1
  movq 96(%rsp), %r10      // H2
  movq 104(%rsp), %r11     // H3
  movq 112(%rsp), %r12     // H4
  movq 120(%rsp), %r13     // H5
  movq 128(%rsp), %r14     // H6
  movq 136(%rsp), %rbx     // H7
  movq 144(%rsp), %rcx     // H8
  movq 152(%rsp), %rbp     // H9

  // c = Sar(H0 + (1<<25), 26); H1 += c; H0 -= c<<26
  movq %r8, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %r9
  shlq $26, %rax
  subq %rax, %r8

  // c = Sar(H4 + (1<<25), 26); H5 += c; H4 -= c<<26
  movq %r12, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %r13
  shlq $26, %rax
  subq %rax, %r12

  // c = Sar(H1 + (1<<24), 25); H2 += c; H1 -= c<<25
  movq %r9, %rax
  addq $16777216, %rax
  sarq $25, %rax
  addq %rax, %r10
  shlq $25, %rax
  subq %rax, %r9

  // c = Sar(H5 + (1<<24), 25); H6 += c; H5 -= c<<25
  movq %r13, %rax
  addq $16777216, %rax
  sarq $25, %rax
  addq %rax, %r14
  shlq $25, %rax
  subq %rax, %r13

  // c = Sar(H2 + (1<<25), 26); H3 += c; H2 -= c<<26
  movq %r10, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %r11
  shlq $26, %rax
  subq %rax, %r10

  // c = Sar(H6 + (1<<25), 26); H7 += c; H6 -= c<<26
  movq %r14, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %rbx
  shlq $26, %rax
  subq %rax, %r14

  // c = Sar(H3 + (1<<24), 25); H4 += c; H3 -= c<<25
  movq %r11, %rax
  addq $16777216, %rax
  sarq $25, %rax
  addq %rax, %r12
  shlq $25, %rax
  subq %rax, %r11

  // c = Sar(H7 + (1<<24), 25); H8 += c; H7 -= c<<25
  movq %rbx, %rax
  addq $16777216, %rax
  sarq $25, %rax
  addq %rax, %rcx
  shlq $25, %rax
  subq %rax, %rbx

  // c = Sar(H4 + (1<<25), 26); H5 += c; H4 -= c<<26
  movq %r12, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %r13
  shlq $26, %rax
  subq %rax, %r12

  // c = Sar(H8 + (1<<25), 26); H9 += c; H8 -= c<<26
  movq %rcx, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %rbp
  shlq $26, %rax
  subq %rax, %rcx

  // c = Sar(H9 + (1<<24), 25); H0 += c*19; H9 -= c<<25
  movq %rbp, %rax
  addq $16777216, %rax
  sarq $25, %rax
  imulq $19, %rax, %rdi
  addq %rdi, %r8
  shlq $25, %rax
  subq %rax, %rbp

  // c = Sar(H0 + (1<<25), 26); H1 += c; H0 -= c<<26
  movq %r8, %rax
  addq $33554432, %rax
  sarq $26, %rax
  addq %rax, %r9
  shlq $26, %rax
  subq %rax, %r8

  // === Store final result to output ===
  movq %r8, 0(%r15)
  movq %r9, 8(%r15)
  movq %r10, 16(%r15)
  movq %r11, 24(%r15)
  movq %r12, 32(%r15)
  movq %r13, 40(%r15)
  movq %r14, 48(%r15)
  movq %rbx, 56(%r15)
  movq %rcx, 64(%r15)
  movq %rbp, 72(%r15)

  add $160, %rsp
  pop %rbp
  pop %r15
  pop %r14
  pop %r13
  pop %r12
  pop %rbx
end;
