{
  nextpas.core.hash.sha256.x64.inc — x86_64 汇编优化 SHA-256 ProcessBlock
  FPC AT&T 语法。用 BSWAP 做字节序转换，寄存器保存 a-h 状态。
}

{$ASMMODE ATT}

procedure ProcessBlockX64(ABlock: PByte; AState: PUInt32); assembler; nostackframe;
asm
  pushq %rbx
  pushq %r12
  pushq %r13
  pushq %r14
  pushq %r15
  pushq %rbp

  movq %rdi, %r14       // r14 = block pointer
  movq %rsi, %r15       // r15 = state pointer

  // 在栈上分配 W[0..63] = 256 bytes
  subq $256, %rsp

  // 加载 W[0..15] 用 BSWAP (big-endian -> little-endian)
  xorl %ecx, %ecx
.Lload_w:
  movl (%r14, %rcx, 4), %eax
  bswapl %eax
  movl %eax, (%rsp, %rcx, 4)
  incl %ecx
  cmpl $16, %ecx
  jl .Lload_w

  // 展开 W[16..63]: W[i] = sigma1(W[i-2]) + W[i-7] + sigma0(W[i-15]) + W[i-16]
  movl $16, %ecx
.Lexpand_w:
  // sigma1(W[i-2]) = RR17(x) ^ RR19(x) ^ SHR10(x)
  movl -8(%rsp, %rcx, 4), %eax
  movl %eax, %edx
  rorl $17, %edx
  movl %eax, %ebx
  rorl $19, %ebx
  xorl %ebx, %edx
  shrl $10, %eax
  xorl %eax, %edx

  // + W[i-7]
  addl -28(%rsp, %rcx, 4), %edx

  // sigma0(W[i-15]) = RR7(x) ^ RR18(x) ^ SHR3(x)
  movl -60(%rsp, %rcx, 4), %eax
  movl %eax, %ebx
  rorl $7, %ebx
  movl %eax, %ebp
  rorl $18, %ebp
  xorl %ebp, %ebx
  shrl $3, %eax
  xorl %eax, %ebx
  addl %ebx, %edx

  // + W[i-16]
  addl -64(%rsp, %rcx, 4), %edx

  movl %edx, (%rsp, %rcx, 4)
  incl %ecx
  cmpl $64, %ecx
  jl .Lexpand_w

  // 加载 state: a=eax b=ebx c=ecx d=edx e=r8d f=r9d g=r10d h=r11d
  movl 0(%r15), %eax
  movl 4(%r15), %ebx
  movl 8(%r15), %ecx
  movl 12(%r15), %edx
  movl 16(%r15), %r8d
  movl 20(%r15), %r9d
  movl 24(%r15), %r10d
  movl 28(%r15), %r11d

  // K 常量表地址
  leaq K(%rip), %r14

  // 64 轮压缩
  xorl %r12d, %r12d
.Lround:
  // T1 = h + Sigma1(e) + Ch(e,f,g) + K[i] + W[i]
  // Sigma1(e) = RR6 ^ RR11 ^ RR25
  movl %r8d, %r13d
  rorl $6, %r13d
  movl %r8d, %ebp
  rorl $11, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  rorl $25, %ebp
  xorl %ebp, %r13d

  // Ch(e,f,g) = (e & f) ^ (~e & g)
  movl %r8d, %ebp
  andl %r9d, %ebp
  movl %r8d, %edi
  notl %edi
  andl %r10d, %edi
  xorl %edi, %ebp

  addl %r11d, %r13d       // + h
  addl %ebp, %r13d        // + Ch
  addl (%r14, %r12, 4), %r13d  // + K[i]
  addl (%rsp, %r12, 4), %r13d  // + W[i]

  // T2 = Sigma0(a) + Maj(a,b,c)
  // Sigma0(a) = RR2 ^ RR13 ^ RR22
  movl %eax, %ebp
  rorl $2, %ebp
  movl %eax, %edi
  rorl $13, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  rorl $22, %edi
  xorl %edi, %ebp

  // Maj(a,b,c) = (a & b) ^ (a & c) ^ (b & c)
  movl %eax, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  xorl %esi, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  xorl %esi, %edi

  addl %edi, %ebp         // T2 = Sigma0 + Maj

  // 状态轮转
  movl %r10d, %r11d       // h = g
  movl %r9d, %r10d        // g = f
  movl %r8d, %r9d         // f = e
  movl %edx, %r8d         // e = d
  addl %r13d, %r8d        // e += T1
  movl %ecx, %edx         // d = c
  movl %ebx, %ecx         // c = b
  movl %eax, %ebx         // b = a
  movl %r13d, %eax        // a = T1
  addl %ebp, %eax         // a += T2

  incl %r12d
  cmpl $64, %r12d
  jl .Lround

  // 加回原始 state
  addl %eax, 0(%r15)
  addl %ebx, 4(%r15)
  addl %ecx, 8(%r15)
  addl %edx, 12(%r15)
  addl %r8d, 16(%r15)
  addl %r9d, 20(%r15)
  addl %r10d, 24(%r15)
  addl %r11d, 28(%r15)

  addq $256, %rsp

  popq %rbp
  popq %r15
  popq %r14
  popq %r13
  popq %r12
  popq %rbx
end;
