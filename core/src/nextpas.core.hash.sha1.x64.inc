{===============================================================================
  nextpas.core.hash.sha1.x64.inc — SHA-1 block compression (x86_64 ASM)

  Strategy:
    - W[0..15]: load from block with BSWAP (unrolled)
    - W[16..79]: expansion loop
    - Rounds 0-79: 4 loops of 20 rounds each (different F functions)

  Register allocation:
    eax = A, ebx = B, ecx = C, edx = D, r8d = E
    r9d, r10d = temporaries for F and ROL5(A)+F+E+K+W[i]
    r11 = W pointer (walks through W array on stack)
    r12 = loop counter
    r15 = state pointer (AH)
    rsp = W[0..79] array base

  Callee-saved: rbx, r12, r15, rbp (pushed/popped)
  Parameters (SysV AMD64):
    rdi = ABlock (PByte)
    rsi = AH pointer (first element)
    rdx = High(AH) — unused, we know it is 4
===============================================================================}

procedure SHA1ProcessBlockX64(ABlock: PByte; var AH: array of UInt32);
  assembler; nostackframe;
asm
  // Save callee-saved registers
  pushq %rbp
  pushq %rbx
  pushq %r12
  pushq %r15

  // Save state pointer
  movq %rsi, %r15

  // Allocate W[80] on stack (320 bytes, 16-byte aligned)
  subq $320, %rsp

  // ===== Load W[0..15] from block (big-endian to little-endian) =====
  movl  0(%rdi), %eax
  bswapl %eax
  movl %eax, 0(%rsp)

  movl  4(%rdi), %eax
  bswapl %eax
  movl %eax, 4(%rsp)

  movl  8(%rdi), %eax
  bswapl %eax
  movl %eax, 8(%rsp)

  movl 12(%rdi), %eax
  bswapl %eax
  movl %eax, 12(%rsp)

  movl 16(%rdi), %eax
  bswapl %eax
  movl %eax, 16(%rsp)

  movl 20(%rdi), %eax
  bswapl %eax
  movl %eax, 20(%rsp)

  movl 24(%rdi), %eax
  bswapl %eax
  movl %eax, 24(%rsp)

  movl 28(%rdi), %eax
  bswapl %eax
  movl %eax, 28(%rsp)

  movl 32(%rdi), %eax
  bswapl %eax
  movl %eax, 32(%rsp)

  movl 36(%rdi), %eax
  bswapl %eax
  movl %eax, 36(%rsp)

  movl 40(%rdi), %eax
  bswapl %eax
  movl %eax, 40(%rsp)

  movl 44(%rdi), %eax
  bswapl %eax
  movl %eax, 44(%rsp)

  movl 48(%rdi), %eax
  bswapl %eax
  movl %eax, 48(%rsp)

  movl 52(%rdi), %eax
  bswapl %eax
  movl %eax, 52(%rsp)

  movl 56(%rdi), %eax
  bswapl %eax
  movl %eax, 56(%rsp)

  movl 60(%rdi), %eax
  bswapl %eax
  movl %eax, 60(%rsp)

  // ===== W expansion: W[16..79] = ROL1(W[i-3] ^ W[i-8] ^ W[i-14] ^ W[i-16]) =====
  leaq 64(%rsp), %r11    // r11 = &W[16]
  movq $64, %r12         // 64 iterations (i=16..79)
.Lsha1_expand:
  movl -12(%r11), %r9d   // W[i-3]
  xorl -32(%r11), %r9d   // ^ W[i-8]
  xorl -56(%r11), %r9d   // ^ W[i-14]
  xorl -64(%r11), %r9d   // ^ W[i-16]
  roll $1, %r9d
  movl %r9d, (%r11)
  addq $4, %r11
  decq %r12
  jnz .Lsha1_expand

  // ===== Load initial hash state into registers =====
  movl  0(%r15), %eax    // A = H0
  movl  4(%r15), %ebx    // B = H1
  movl  8(%r15), %ecx    // C = H2
  movl 12(%r15), %edx    // D = H3
  movl 16(%r15), %r8d    // E = H4

  // ===== Rounds 0-19: F = (B & C) | (~B & D), K = 0x5A827999 =====
  leaq 0(%rsp), %r11     // r11 = &W[0]
  movq $20, %r12
.Lsha1_round0:
  // F = Ch(B, C, D) = (B & C) | (~B & D)
  movl %ebx, %r9d
  andl %ecx, %r9d        // B & C
  movl %ebx, %r10d
  notl %r10d
  andl %edx, %r10d       // ~B & D
  orl  %r10d, %r9d       // F

  // Tmp = ROL5(A) + F + E + K + W[i]
  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d       // + F
  addl %r8d, %r10d       // + E
  addl $0x5A827999, %r10d // + K
  addl (%r11), %r10d     // + W[i]

  // Rotate state
  movl %edx, %r8d        // E = D
  movl %ecx, %edx        // D = C
  movl %ebx, %ecx
  roll $30, %ecx         // C = ROL30(B)
  movl %eax, %ebx        // B = A
  movl %r10d, %eax       // A = Tmp

  addq $4, %r11
  decq %r12
  jnz .Lsha1_round0

  // ===== Rounds 20-39: F = B ^ C ^ D, K = 0x6ED9EBA1 =====
  movq $20, %r12
.Lsha1_round20:
  // F = Parity(B, C, D) = B ^ C ^ D
  movl %ebx, %r9d
  xorl %ecx, %r9d
  xorl %edx, %r9d        // F

  // Tmp = ROL5(A) + F + E + K + W[i]
  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d       // + F
  addl %r8d, %r10d       // + E
  addl $0x6ED9EBA1, %r10d // + K
  addl (%r11), %r10d     // + W[i]

  // Rotate state
  movl %edx, %r8d        // E = D
  movl %ecx, %edx        // D = C
  movl %ebx, %ecx
  roll $30, %ecx         // C = ROL30(B)
  movl %eax, %ebx        // B = A
  movl %r10d, %eax       // A = Tmp

  addq $4, %r11
  decq %r12
  jnz .Lsha1_round20

  // ===== Rounds 40-59: F = (B & C) | (B & D) | (C & D), K = 0x8F1BBCDC =====
  movq $20, %r12
.Lsha1_round40:
  // F = Maj(B, C, D) = (B & C) | (B & D) | (C & D)
  // Optimized: (B & C) | (D & (B | C))
  movl %ebx, %r9d
  orl  %ecx, %r9d        // B | C
  andl %edx, %r9d        // D & (B | C)
  movl %ebx, %r10d
  andl %ecx, %r10d       // B & C
  orl  %r10d, %r9d       // F

  // Tmp = ROL5(A) + F + E + K + W[i]
  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d       // + F
  addl %r8d, %r10d       // + E
  addl $0x8F1BBCDC, %r10d // + K
  addl (%r11), %r10d     // + W[i]

  // Rotate state
  movl %edx, %r8d        // E = D
  movl %ecx, %edx        // D = C
  movl %ebx, %ecx
  roll $30, %ecx         // C = ROL30(B)
  movl %eax, %ebx        // B = A
  movl %r10d, %eax       // A = Tmp

  addq $4, %r11
  decq %r12
  jnz .Lsha1_round40

  // ===== Rounds 60-79: F = B ^ C ^ D, K = 0xCA62C1D6 =====
  movq $20, %r12
.Lsha1_round60:
  // F = Parity(B, C, D) = B ^ C ^ D
  movl %ebx, %r9d
  xorl %ecx, %r9d
  xorl %edx, %r9d        // F

  // Tmp = ROL5(A) + F + E + K + W[i]
  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d       // + F
  addl %r8d, %r10d       // + E
  addl $0xCA62C1D6, %r10d // + K
  addl (%r11), %r10d     // + W[i]

  // Rotate state
  movl %edx, %r8d        // E = D
  movl %ecx, %edx        // D = C
  movl %ebx, %ecx
  roll $30, %ecx         // C = ROL30(B)
  movl %eax, %ebx        // B = A
  movl %r10d, %eax       // A = Tmp

  addq $4, %r11
  decq %r12
  jnz .Lsha1_round60

  // ===== Add back to state =====
  addl %eax,  0(%r15)    // H0 += A
  addl %ebx,  4(%r15)    // H1 += B
  addl %ecx,  8(%r15)    // H2 += C
  addl %edx, 12(%r15)    // H3 += D
  addl %r8d, 16(%r15)    // H4 += E

  // Deallocate W array
  addq $320, %rsp

  // Restore callee-saved registers
  popq %r15
  popq %r12
  popq %rbx
  popq %rbp
end;
