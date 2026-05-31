{
  MD5 block compression — x86-64, fully unrolled 64 rounds.
  FPC inline assembly, AT&T syntax.

  Register allocation:
    eax  = A
    ebx  = B
    r9d  = C
    r10d = D
    r11d = temp (F computation)
    r12d = temp (F computation)
    rdi  = ABlock pointer (preserved)

  Stack layout (48 bytes):
     0(%rsp) = ptr to AA (original %rsi)
     8(%rsp) = ptr to AB (original %rdx)
    16(%rsp) = ptr to AC (original %rcx)
    24(%rsp) = ptr to AD (original %r8)
    32(%rsp) = orig A (UInt32)
    36(%rsp) = orig B (UInt32)
    40(%rsp) = orig C (UInt32)
    44(%rsp) = orig D (UInt32)
}
procedure MD5ProcessBlockX64(ABlock: PByte; var AA, AB, AC, AD: UInt32);
  assembler; nostackframe;
asm
  // Save callee-saved registers
  pushq %rbx
  pushq %r12

  // Allocate stack frame
  subq $48, %rsp

  // Save state pointers
  movq %rsi, 0(%rsp)
  movq %rdx, 8(%rsp)
  movq %rcx, 16(%rsp)
  movq %r8, 24(%rsp)

  // Load initial state
  movl (%rsi), %eax        // A
  movl (%rdx), %ebx        // B
  movl (%rcx), %r9d        // C
  movl (%r8), %r10d        // D

  // Save original state for final addition
  movl %eax, 32(%rsp)
  movl %ebx, 36(%rsp)
  movl %r9d, 40(%rsp)
  movl %r10d, 44(%rsp)

  // Round 0 [F]: F=(B and C) or (not B and D), G=0, K=0xd76aa478, S=7
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xd76aa478, %r11d
  addl 0(%rdi), %r11d
  roll $7, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 1 [F]: F=(B and C) or (not B and D), G=1, K=0xe8c7b756, S=12
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xe8c7b756, %r11d
  addl 4(%rdi), %r11d
  roll $12, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 2 [F]: F=(B and C) or (not B and D), G=2, K=0x242070db, S=17
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x242070db, %r11d
  addl 8(%rdi), %r11d
  roll $17, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 3 [F]: F=(B and C) or (not B and D), G=3, K=0xc1bdceee, S=22
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xc1bdceee, %r11d
  addl 12(%rdi), %r11d
  roll $22, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 4 [F]: F=(B and C) or (not B and D), G=4, K=0xf57c0faf, S=7
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xf57c0faf, %r11d
  addl 16(%rdi), %r11d
  roll $7, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 5 [F]: F=(B and C) or (not B and D), G=5, K=0x4787c62a, S=12
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x4787c62a, %r11d
  addl 20(%rdi), %r11d
  roll $12, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 6 [F]: F=(B and C) or (not B and D), G=6, K=0xa8304613, S=17
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xa8304613, %r11d
  addl 24(%rdi), %r11d
  roll $17, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 7 [F]: F=(B and C) or (not B and D), G=7, K=0xfd469501, S=22
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xfd469501, %r11d
  addl 28(%rdi), %r11d
  roll $22, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 8 [F]: F=(B and C) or (not B and D), G=8, K=0x698098d8, S=7
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x698098d8, %r11d
  addl 32(%rdi), %r11d
  roll $7, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 9 [F]: F=(B and C) or (not B and D), G=9, K=0x8b44f7af, S=12
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x8b44f7af, %r11d
  addl 36(%rdi), %r11d
  roll $12, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 10 [F]: F=(B and C) or (not B and D), G=10, K=0xffff5bb1, S=17
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xffff5bb1, %r11d
  addl 40(%rdi), %r11d
  roll $17, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 11 [F]: F=(B and C) or (not B and D), G=11, K=0x895cd7be, S=22
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x895cd7be, %r11d
  addl 44(%rdi), %r11d
  roll $22, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 12 [F]: F=(B and C) or (not B and D), G=12, K=0x6b901122, S=7
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x6b901122, %r11d
  addl 48(%rdi), %r11d
  roll $7, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 13 [F]: F=(B and C) or (not B and D), G=13, K=0xfd987193, S=12
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xfd987193, %r11d
  addl 52(%rdi), %r11d
  roll $12, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 14 [F]: F=(B and C) or (not B and D), G=14, K=0xa679438e, S=17
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xa679438e, %r11d
  addl 56(%rdi), %r11d
  roll $17, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 15 [F]: F=(B and C) or (not B and D), G=15, K=0x49b40821, S=22
  movl %ebx, %r11d
  andl %r9d, %r11d
  movl %ebx, %r12d
  notl %r12d
  andl %r10d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x49b40821, %r11d
  addl 60(%rdi), %r11d
  roll $22, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 16 [G]: F=(D and B) or (not D and C), G=1, K=0xf61e2562, S=5
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xf61e2562, %r11d
  addl 4(%rdi), %r11d
  roll $5, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 17 [G]: F=(D and B) or (not D and C), G=6, K=0xc040b340, S=9
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xc040b340, %r11d
  addl 24(%rdi), %r11d
  roll $9, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 18 [G]: F=(D and B) or (not D and C), G=11, K=0x265e5a51, S=14
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x265e5a51, %r11d
  addl 44(%rdi), %r11d
  roll $14, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 19 [G]: F=(D and B) or (not D and C), G=0, K=0xe9b6c7aa, S=20
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xe9b6c7aa, %r11d
  addl 0(%rdi), %r11d
  roll $20, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 20 [G]: F=(D and B) or (not D and C), G=5, K=0xd62f105d, S=5
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xd62f105d, %r11d
  addl 20(%rdi), %r11d
  roll $5, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 21 [G]: F=(D and B) or (not D and C), G=10, K=0x02441453, S=9
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x02441453, %r11d
  addl 40(%rdi), %r11d
  roll $9, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 22 [G]: F=(D and B) or (not D and C), G=15, K=0xd8a1e681, S=14
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xd8a1e681, %r11d
  addl 60(%rdi), %r11d
  roll $14, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 23 [G]: F=(D and B) or (not D and C), G=4, K=0xe7d3fbc8, S=20
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xe7d3fbc8, %r11d
  addl 16(%rdi), %r11d
  roll $20, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 24 [G]: F=(D and B) or (not D and C), G=9, K=0x21e1cde6, S=5
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x21e1cde6, %r11d
  addl 36(%rdi), %r11d
  roll $5, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 25 [G]: F=(D and B) or (not D and C), G=14, K=0xc33707d6, S=9
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xc33707d6, %r11d
  addl 56(%rdi), %r11d
  roll $9, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 26 [G]: F=(D and B) or (not D and C), G=3, K=0xf4d50d87, S=14
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xf4d50d87, %r11d
  addl 12(%rdi), %r11d
  roll $14, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 27 [G]: F=(D and B) or (not D and C), G=8, K=0x455a14ed, S=20
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x455a14ed, %r11d
  addl 32(%rdi), %r11d
  roll $20, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 28 [G]: F=(D and B) or (not D and C), G=13, K=0xa9e3e905, S=5
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xa9e3e905, %r11d
  addl 52(%rdi), %r11d
  roll $5, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 29 [G]: F=(D and B) or (not D and C), G=2, K=0xfcefa3f8, S=9
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0xfcefa3f8, %r11d
  addl 8(%rdi), %r11d
  roll $9, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 30 [G]: F=(D and B) or (not D and C), G=7, K=0x676f02d9, S=14
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x676f02d9, %r11d
  addl 28(%rdi), %r11d
  roll $14, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 31 [G]: F=(D and B) or (not D and C), G=12, K=0x8d2a4c8a, S=20
  movl %r10d, %r11d
  andl %ebx, %r11d
  movl %r10d, %r12d
  notl %r12d
  andl %r9d, %r12d
  orl %r12d, %r11d
  addl %eax, %r11d
  addl $0x8d2a4c8a, %r11d
  addl 48(%rdi), %r11d
  roll $20, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 32 [H]: F=B xor C xor D, G=5, K=0xfffa3942, S=4
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xfffa3942, %r11d
  addl 20(%rdi), %r11d
  roll $4, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 33 [H]: F=B xor C xor D, G=8, K=0x8771f681, S=11
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0x8771f681, %r11d
  addl 32(%rdi), %r11d
  roll $11, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 34 [H]: F=B xor C xor D, G=11, K=0x6d9d6122, S=16
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0x6d9d6122, %r11d
  addl 44(%rdi), %r11d
  roll $16, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 35 [H]: F=B xor C xor D, G=14, K=0xfde5380c, S=23
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xfde5380c, %r11d
  addl 56(%rdi), %r11d
  roll $23, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 36 [H]: F=B xor C xor D, G=1, K=0xa4beea44, S=4
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xa4beea44, %r11d
  addl 4(%rdi), %r11d
  roll $4, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 37 [H]: F=B xor C xor D, G=4, K=0x4bdecfa9, S=11
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0x4bdecfa9, %r11d
  addl 16(%rdi), %r11d
  roll $11, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 38 [H]: F=B xor C xor D, G=7, K=0xf6bb4b60, S=16
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xf6bb4b60, %r11d
  addl 28(%rdi), %r11d
  roll $16, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 39 [H]: F=B xor C xor D, G=10, K=0xbebfbc70, S=23
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xbebfbc70, %r11d
  addl 40(%rdi), %r11d
  roll $23, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 40 [H]: F=B xor C xor D, G=13, K=0x289b7ec6, S=4
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0x289b7ec6, %r11d
  addl 52(%rdi), %r11d
  roll $4, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 41 [H]: F=B xor C xor D, G=0, K=0xeaa127fa, S=11
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xeaa127fa, %r11d
  addl 0(%rdi), %r11d
  roll $11, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 42 [H]: F=B xor C xor D, G=3, K=0xd4ef3085, S=16
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xd4ef3085, %r11d
  addl 12(%rdi), %r11d
  roll $16, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 43 [H]: F=B xor C xor D, G=6, K=0x04881d05, S=23
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0x04881d05, %r11d
  addl 24(%rdi), %r11d
  roll $23, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 44 [H]: F=B xor C xor D, G=9, K=0xd9d4d039, S=4
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xd9d4d039, %r11d
  addl 36(%rdi), %r11d
  roll $4, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 45 [H]: F=B xor C xor D, G=12, K=0xe6db99e5, S=11
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xe6db99e5, %r11d
  addl 48(%rdi), %r11d
  roll $11, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 46 [H]: F=B xor C xor D, G=15, K=0x1fa27cf8, S=16
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0x1fa27cf8, %r11d
  addl 60(%rdi), %r11d
  roll $16, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 47 [H]: F=B xor C xor D, G=2, K=0xc4ac5665, S=23
  movl %ebx, %r11d
  xorl %r9d, %r11d
  xorl %r10d, %r11d
  addl %eax, %r11d
  addl $0xc4ac5665, %r11d
  addl 8(%rdi), %r11d
  roll $23, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 48 [I]: F=C xor (B or not D), G=0, K=0xf4292244, S=6
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xf4292244, %r11d
  addl 0(%rdi), %r11d
  roll $6, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 49 [I]: F=C xor (B or not D), G=7, K=0x432aff97, S=10
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x432aff97, %r11d
  addl 28(%rdi), %r11d
  roll $10, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 50 [I]: F=C xor (B or not D), G=14, K=0xab9423a7, S=15
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xab9423a7, %r11d
  addl 56(%rdi), %r11d
  roll $15, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 51 [I]: F=C xor (B or not D), G=5, K=0xfc93a039, S=21
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xfc93a039, %r11d
  addl 20(%rdi), %r11d
  roll $21, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 52 [I]: F=C xor (B or not D), G=12, K=0x655b59c3, S=6
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x655b59c3, %r11d
  addl 48(%rdi), %r11d
  roll $6, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 53 [I]: F=C xor (B or not D), G=3, K=0x8f0ccc92, S=10
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x8f0ccc92, %r11d
  addl 12(%rdi), %r11d
  roll $10, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 54 [I]: F=C xor (B or not D), G=10, K=0xffeff47d, S=15
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xffeff47d, %r11d
  addl 40(%rdi), %r11d
  roll $15, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 55 [I]: F=C xor (B or not D), G=1, K=0x85845dd1, S=21
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x85845dd1, %r11d
  addl 4(%rdi), %r11d
  roll $21, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 56 [I]: F=C xor (B or not D), G=8, K=0x6fa87e4f, S=6
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x6fa87e4f, %r11d
  addl 32(%rdi), %r11d
  roll $6, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 57 [I]: F=C xor (B or not D), G=15, K=0xfe2ce6e0, S=10
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xfe2ce6e0, %r11d
  addl 60(%rdi), %r11d
  roll $10, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 58 [I]: F=C xor (B or not D), G=6, K=0xa3014314, S=15
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xa3014314, %r11d
  addl 24(%rdi), %r11d
  roll $15, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 59 [I]: F=C xor (B or not D), G=13, K=0x4e0811a1, S=21
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x4e0811a1, %r11d
  addl 52(%rdi), %r11d
  roll $21, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 60 [I]: F=C xor (B or not D), G=4, K=0xf7537e82, S=6
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xf7537e82, %r11d
  addl 16(%rdi), %r11d
  roll $6, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 61 [I]: F=C xor (B or not D), G=11, K=0xbd3af235, S=10
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xbd3af235, %r11d
  addl 44(%rdi), %r11d
  roll $10, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 62 [I]: F=C xor (B or not D), G=2, K=0x2ad7d2bb, S=15
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0x2ad7d2bb, %r11d
  addl 8(%rdi), %r11d
  roll $15, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Round 63 [I]: F=C xor (B or not D), G=9, K=0xeb86d391, S=21
  movl %r10d, %r11d
  notl %r11d
  orl %ebx, %r11d
  xorl %r9d, %r11d
  addl %eax, %r11d
  addl $0xeb86d391, %r11d
  addl 36(%rdi), %r11d
  roll $21, %r11d
  addl %ebx, %r11d
  movl %r10d, %eax
  movl %r9d, %r10d
  movl %ebx, %r9d
  movl %r11d, %ebx

  // Add original state back (MD5 Merkle-Damgard)
  addl 32(%rsp), %eax
  addl 36(%rsp), %ebx
  addl 40(%rsp), %r9d
  addl 44(%rsp), %r10d

  // Write results back through saved pointers
  movq 0(%rsp), %rsi
  movl %eax, (%rsi)
  movq 8(%rsp), %rdx
  movl %ebx, (%rdx)
  movq 16(%rsp), %rcx
  movl %r9d, (%rcx)
  movq 24(%rsp), %r8
  movl %r10d, (%r8)

  // Restore stack and callee-saved registers
  addq $48, %rsp
  popq %r12
  popq %rbx
end;
