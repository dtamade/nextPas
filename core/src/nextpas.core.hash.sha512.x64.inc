{
  nextpas.core.hash.sha512.x64.inc — x86_64 汇编优化 SHA-512 ProcessBlock
  FPC AT&T 语法。用 BSWAPQ 做字节序转换，寄存器保存 A-H 状态。
  80 轮循环实现，W 扩展用循环，W 加载展开 16 次。
}

{$ASMMODE ATT}

procedure ProcessBlockX64_512(ABlock: PByte; var AState: array of UInt64);
  assembler; nostackframe;
asm
  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15
  pushq %rbp

  movq %rdi, %r14       // r14 = block pointer
  movq %rsi, %r15       // r15 = state pointer (first element)

  // 在栈上分配 W[0..79] = 640 bytes
  subq $640, %rsp

  // --- 加载 W[0..15]: 16 个 big-endian UInt64 用 BSWAPQ ---
  movq 0(%r14), %rax
  bswapq %rax
  movq %rax, 0(%rsp)

  movq 8(%r14), %rax
  bswapq %rax
  movq %rax, 8(%rsp)

  movq 16(%r14), %rax
  bswapq %rax
  movq %rax, 16(%rsp)

  movq 24(%r14), %rax
  bswapq %rax
  movq %rax, 24(%rsp)

  movq 32(%r14), %rax
  bswapq %rax
  movq %rax, 32(%rsp)

  movq 40(%r14), %rax
  bswapq %rax
  movq %rax, 40(%rsp)

  movq 48(%r14), %rax
  bswapq %rax
  movq %rax, 48(%rsp)

  movq 56(%r14), %rax
  bswapq %rax
  movq %rax, 56(%rsp)

  movq 64(%r14), %rax
  bswapq %rax
  movq %rax, 64(%rsp)

  movq 72(%r14), %rax
  bswapq %rax
  movq %rax, 72(%rsp)

  movq 80(%r14), %rax
  bswapq %rax
  movq %rax, 80(%rsp)

  movq 88(%r14), %rax
  bswapq %rax
  movq %rax, 88(%rsp)

  movq 96(%r14), %rax
  bswapq %rax
  movq %rax, 96(%rsp)

  movq 104(%r14), %rax
  bswapq %rax
  movq %rax, 104(%rsp)

  movq 112(%r14), %rax
  bswapq %rax
  movq %rax, 112(%rsp)

  movq 120(%r14), %rax
  bswapq %rax
  movq %rax, 120(%rsp)

  // --- W 扩展: W[16..79] ---
  // sigma0(x) = ROR(x,1) ^ ROR(x,8) ^ (x >> 7)
  // sigma1(x) = ROR(x,19) ^ ROR(x,61) ^ (x >> 6)
  // W[i] = sigma1(W[i-2]) + W[i-7] + sigma0(W[i-15]) + W[i-16]
  movl $16, %ecx
.Lexpand_w512:
  // sigma1(W[i-2])
  movq -16(%rsp, %rcx, 8), %rax
  movq %rax, %rdx
  rorq $19, %rdx
  movq %rax, %rbx
  rorq $61, %rbx
  xorq %rbx, %rdx
  shrq $6, %rax
  xorq %rax, %rdx

  // + W[i-7]
  addq -56(%rsp, %rcx, 8), %rdx

  // sigma0(W[i-15])
  movq -120(%rsp, %rcx, 8), %rax
  movq %rax, %rbx
  rorq $1, %rbx
  movq %rax, %rbp
  rorq $8, %rbp
  xorq %rbp, %rbx
  shrq $7, %rax
  xorq %rax, %rbx
  addq %rbx, %rdx

  // + W[i-16]
  addq -128(%rsp, %rcx, 8), %rdx

  movq %rdx, (%rsp, %rcx, 8)
  incl %ecx
  cmpl $80, %ecx
  jl .Lexpand_w512

  // --- 加载初始状态 A-H ---
  // A=rax B=rbx C=rcx D=rdx E=r8 F=r9 G=r10 H=r11
  movq 0(%r15), %rax
  movq 8(%r15), %rbx
  movq 16(%r15), %rcx
  movq 24(%r15), %rdx
  movq 32(%r15), %r8
  movq 40(%r15), %r9
  movq 48(%r15), %r10
  movq 56(%r15), %r11

  // K 常量表地址
  leaq K(%rip), %r14

  // --- 80 轮压缩 ---
  xorq %r12, %r12       // r12 = round counter
.Lround512:
  // T1 = H + Sigma1(E) + Ch(E,F,G) + K[i] + W[i]
  // Sigma1(E) = ROR(E,14) ^ ROR(E,18) ^ ROR(E,41)
  movq %r8, %r13
  rorq $14, %r13
  movq %r8, %rbp
  rorq $18, %rbp
  xorq %rbp, %r13
  movq %r8, %rbp
  rorq $41, %rbp
  xorq %rbp, %r13

  // Ch(E,F,G) = (E & F) ^ (~E & G)
  movq %r8, %rbp
  andq %r9, %rbp
  movq %r8, %rdi
  notq %rdi
  andq %r10, %rdi
  xorq %rdi, %rbp

  addq %r11, %r13       // + H
  addq %rbp, %r13       // + Ch
  addq (%r14, %r12, 8), %r13  // + K[i]
  addq (%rsp, %r12, 8), %r13  // + W[i]

  // T2 = Sigma0(A) + Maj(A,B,C)
  // Sigma0(A) = ROR(A,28) ^ ROR(A,34) ^ ROR(A,39)
  movq %rax, %rbp
  rorq $28, %rbp
  movq %rax, %rdi
  rorq $34, %rdi
  xorq %rdi, %rbp
  movq %rax, %rdi
  rorq $39, %rdi
  xorq %rdi, %rbp

  // Maj(A,B,C) = (A & B) ^ (A & C) ^ (B & C)
  movq %rax, %rdi
  andq %rbx, %rdi
  movq %rax, %rsi
  andq %rcx, %rsi
  xorq %rsi, %rdi
  movq %rbx, %rsi
  andq %rcx, %rsi
  xorq %rsi, %rdi

  addq %rdi, %rbp       // T2 = Sigma0 + Maj

  // 状态轮转: H=G; G=F; F=E; E=D+T1; D=C; C=B; B=A; A=T1+T2
  movq %r10, %r11       // H = G
  movq %r9, %r10        // G = F
  movq %r8, %r9         // F = E
  movq %rdx, %r8        // E = D
  addq %r13, %r8        // E += T1
  movq %rcx, %rdx       // D = C
  movq %rbx, %rcx       // C = B
  movq %rax, %rbx       // B = A
  leaq (%r13, %rbp), %rax  // A = T1 + T2

  incq %r12
  cmpq $80, %r12
  jl .Lround512

  // --- 加回原始 state ---
  addq %rax, 0(%r15)
  addq %rbx, 8(%r15)
  addq %rcx, 16(%r15)
  addq %rdx, 24(%r15)
  addq %r8, 32(%r15)
  addq %r9, 40(%r15)
  addq %r10, 48(%r15)
  addq %r11, 56(%r15)

  addq $640, %rsp

  popq %rbp
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
end;
