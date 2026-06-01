{===============================================================================
  nextpas.core.hash.sha1.ssse3.inc — SHA-1 block compression (SSSE3 vectorized)

  Strategy (two-phase):
    Phase 1: SSSE3 vectorized W expansion
      - Load W[0..15] with pshufb byte-swap (4 dwords at once)
      - Expand W[16..79] using 128-bit XOR + palignr + ROL1
      - Store all 80 W values to stack (320 bytes)
    Phase 2: Scalar 80-round compression
      - Identical to x64.inc: 4 loops of 20 rounds, reading W[i] from stack

  Register allocation (Phase 2):
    eax = A, ebx = B, ecx = C, edx = D, r8d = E
    r9d, r10d = temporaries
    r11 = W pointer (walks through W array on stack)
    r12 = loop counter
    r15 = state pointer (AH)

  XMM usage (Phase 1):
    xmm0..xmm3 = W[i-16..i-1] sliding window (4 dwords each)
    xmm4, xmm5, xmm6 = temporaries for expansion
    xmm7 = BSWAP mask

  Callee-saved: rbx, r12, r15, rbp (pushed/popped)
  Parameters (SysV AMD64):
    rdi = ABlock (PByte, 64 bytes)
    rsi = AH pointer (5 x UInt32)
    rdx = High(AH) — unused
===============================================================================}

procedure SHA1ProcessBlockSSSE3(ABlock: PByte; var AH: array of UInt32);
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
  subq $328, %rsp

  // ===== Phase 1: SSSE3 vectorized W load + expansion =====

  // Jump past embedded data
  jmp .Lssse3_start

  .align 16
.Lssse3_bswap_mask:
  .byte 3,2,1,0, 7,6,5,4, 11,10,9,8, 15,14,13,12

.Lssse3_start:
  // Load BSWAP mask
  leaq .Lssse3_bswap_mask(%rip), %r9
  movdqu (%r9), %xmm7

  // Load W[0..15] from block and byte-swap (4 dwords per vector)
  movdqu  0(%rdi), %xmm0
  pshufb %xmm7, %xmm0
  movdqa %xmm0, 0(%rsp)

  movdqu 16(%rdi), %xmm1
  pshufb %xmm7, %xmm1
  movdqa %xmm1, 16(%rsp)

  movdqu 32(%rdi), %xmm2
  pshufb %xmm7, %xmm2
  movdqa %xmm2, 32(%rsp)

  movdqu 48(%rdi), %xmm3
  pshufb %xmm7, %xmm3
  movdqa %xmm3, 48(%rsp)

  // ===== W expansion: W[16..79] in groups of 4 =====
  // Sliding window: xmm0=W[i-16..i-13], xmm1=W[i-12..i-9],
  //                 xmm2=W[i-8..i-5],   xmm3=W[i-4..i-1]
  // Output: xmm4=W[i..i+3]

  leaq 64(%rsp), %r11
  movq $16, %r12              // 16 groups x 4 = 64 words

.Lssse3_expand:
  // xmm4 = W[i-16..i-13]
  movdqa %xmm0, %xmm4

  // XOR W[i-14..i-11] = palignr(xmm1, xmm0, 8)
  movdqa %xmm1, %xmm5
  palignr $8, %xmm0, %xmm5
  pxor %xmm5, %xmm4

  // XOR W[i-8..i-5]
  pxor %xmm2, %xmm4

  // XOR W[i-3..i-1, 0] = psrldq(xmm3, 4)
  movdqa %xmm3, %xmm5
  psrldq $4, %xmm5
  pxor %xmm5, %xmm4

  // ROL1 (all 4 dwords)
  movdqa %xmm4, %xmm5
  pslld $1, %xmm4
  psrld $31, %xmm5
  por %xmm5, %xmm4

  // Fix W[i+3]: it missed XOR with W[i] before ROL1
  // W[i] is in xmm4 dword[0]; isolate to dword[3], ROL1, XOR back
  movdqa %xmm4, %xmm5
  pslldq $12, %xmm5            // shift W[i] from dword[0] to dword[3]
  movdqa %xmm5, %xmm6
  pslld $1, %xmm5
  psrld $31, %xmm6
  por %xmm6, %xmm5             // ROL1(W[i]) in dword[3]
  pxor %xmm5, %xmm4            // W[i+3] ^= ROL1(W[i])

  // Store expanded W[i..i+3]
  movdqa %xmm4, (%r11)

  // Rotate sliding window
  movdqa %xmm1, %xmm0
  movdqa %xmm2, %xmm1
  movdqa %xmm3, %xmm2
  movdqa %xmm4, %xmm3

  addq $16, %r11
  decq %r12
  jnz .Lssse3_expand

  // ===== Phase 2: Scalar 80-round compression =====

  // Load initial hash state
  movl  0(%r15), %eax
  movl  4(%r15), %ebx
  movl  8(%r15), %ecx
  movl 12(%r15), %edx
  movl 16(%r15), %r8d

  // ===== Rounds 0-19: F = Ch(B,C,D), K = 0x5A827999 =====
  leaq 0(%rsp), %r11
  movq $20, %r12
.Lssse3_round0:
  movl %ebx, %r9d
  andl %ecx, %r9d
  movl %ebx, %r10d
  notl %r10d
  andl %edx, %r10d
  orl  %r10d, %r9d

  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d
  addl %r8d, %r10d
  addl $0x5A827999, %r10d
  addl (%r11), %r10d

  movl %edx, %r8d
  movl %ecx, %edx
  movl %ebx, %ecx
  roll $30, %ecx
  movl %eax, %ebx
  movl %r10d, %eax

  addq $4, %r11
  decq %r12
  jnz .Lssse3_round0

  // ===== Rounds 20-39: F = Parity(B,C,D), K = 0x6ED9EBA1 =====
  movq $20, %r12
.Lssse3_round20:
  movl %ebx, %r9d
  xorl %ecx, %r9d
  xorl %edx, %r9d

  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d
  addl %r8d, %r10d
  addl $0x6ED9EBA1, %r10d
  addl (%r11), %r10d

  movl %edx, %r8d
  movl %ecx, %edx
  movl %ebx, %ecx
  roll $30, %ecx
  movl %eax, %ebx
  movl %r10d, %eax

  addq $4, %r11
  decq %r12
  jnz .Lssse3_round20

  // ===== Rounds 40-59: F = Maj(B,C,D), K = 0x8F1BBCDC =====
  movq $20, %r12
.Lssse3_round40:
  movl %ebx, %r9d
  orl  %ecx, %r9d
  andl %edx, %r9d
  movl %ebx, %r10d
  andl %ecx, %r10d
  orl  %r10d, %r9d

  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d
  addl %r8d, %r10d
  addl $0x8F1BBCDC, %r10d
  addl (%r11), %r10d

  movl %edx, %r8d
  movl %ecx, %edx
  movl %ebx, %ecx
  roll $30, %ecx
  movl %eax, %ebx
  movl %r10d, %eax

  addq $4, %r11
  decq %r12
  jnz .Lssse3_round40

  // ===== Rounds 60-79: F = Parity(B,C,D), K = 0xCA62C1D6 =====
  movq $20, %r12
.Lssse3_round60:
  movl %ebx, %r9d
  xorl %ecx, %r9d
  xorl %edx, %r9d

  movl %eax, %r10d
  roll $5, %r10d
  addl %r9d, %r10d
  addl %r8d, %r10d
  addl $0xCA62C1D6, %r10d
  addl (%r11), %r10d

  movl %edx, %r8d
  movl %ecx, %edx
  movl %ebx, %ecx
  roll $30, %ecx
  movl %eax, %ebx
  movl %r10d, %eax

  addq $4, %r11
  decq %r12
  jnz .Lssse3_round60

  // ===== Add back to state =====
  addl %eax,  0(%r15)
  addl %ebx,  4(%r15)
  addl %ecx,  8(%r15)
  addl %edx, 12(%r15)
  addl %r8d, 16(%r15)

  // Deallocate W array
  addq $328, %rsp

  // Restore callee-saved registers
  popq %r15
  popq %r12
  popq %rbx
  popq %rbp
end;
