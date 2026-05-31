  // --- Msg schedule W[16..19] ---
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
  addl 0(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 4(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 8(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 12(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  // --- Msg schedule W[20..23] ---
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
  addl 16(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 20(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 24(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 28(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  // --- Msg schedule W[24..27] ---
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
  addl 32(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 36(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 40(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 44(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  // --- Msg schedule W[28..31] ---
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
  addl 48(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 52(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 56(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 60(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  // --- Msg schedule W[32..35] ---
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
  addl 64(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 68(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 72(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 76(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  // --- Msg schedule W[36..39] ---
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
  addl 80(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 84(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 88(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 92(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  // --- Msg schedule W[40..43] ---
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
  addl 96(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 100(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 104(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 108(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  // --- Msg schedule W[44..47] ---
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
  addl 112(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 116(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 120(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 124(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  // --- Msg schedule W[48..51] ---
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
  addl 128(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 132(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 136(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 140(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  // --- Msg schedule W[52..55] ---
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
  addl 144(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 148(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 152(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 156(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  // --- Msg schedule W[56..59] ---
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
  addl 160(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 164(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 168(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 172(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  // --- Msg schedule W[60..63] ---
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
  addl 176(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 180(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 184(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 188(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  addl 192(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 196(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 200(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 204(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  addl 208(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 212(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 216(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 220(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
  addl 224(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r8d, %r12d
  xorl %r12d, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %r12d
  rorxl $13, %eax, %edi
  xorl %edi, %r12d
  rorxl $22, %eax, %edi
  xorl %edi, %r12d
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %r12d, %r11d
  addl %edi, %r11d
  addl 228(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %edx, %r12d
  xorl %r12d, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %r12d
  rorxl $13, %r11d, %edi
  xorl %edi, %r12d
  rorxl $22, %r11d, %edi
  xorl %edi, %r12d
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %r12d, %r10d
  addl %edi, %r10d
  addl 232(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ecx, %r12d
  xorl %r12d, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %r12d
  rorxl $13, %r10d, %edi
  xorl %edi, %r12d
  rorxl $22, %r10d, %edi
  xorl %edi, %r12d
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %r12d, %r9d
  addl %edi, %r9d
  addl 236(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %r12d
  xorl %r12d, %r13d
  rorxl $25, %ebx, %r12d
  xorl %r12d, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %r12d
  rorxl $13, %r9d, %edi
  xorl %edi, %r12d
  rorxl $22, %r9d, %edi
  xorl %edi, %r12d
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %r12d, %r8d
  addl %edi, %r8d
  addl 240(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %r12d
  xorl %r12d, %r13d
  rorxl $25, %eax, %r12d
  xorl %r12d, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %r12d
  rorxl $13, %r8d, %edi
  xorl %edi, %r12d
  rorxl $22, %r8d, %edi
  xorl %edi, %r12d
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %r12d, %edx
  addl %edi, %edx
  addl 244(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r11d, %r12d
  xorl %r12d, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %r12d
  rorxl $13, %edx, %edi
  xorl %edi, %r12d
  rorxl $22, %edx, %edi
  xorl %edi, %r12d
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %r12d, %ecx
  addl %edi, %ecx
  addl 248(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r10d, %r12d
  xorl %r12d, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %r12d
  rorxl $13, %ecx, %edi
  xorl %edi, %r12d
  rorxl $22, %ecx, %edi
  xorl %edi, %r12d
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %r12d, %ebx
  addl %edi, %ebx
  addl 252(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %r12d
  xorl %r12d, %r13d
  rorxl $25, %r9d, %r12d
  xorl %r12d, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %r12d
  rorxl $13, %ebx, %edi
  xorl %edi, %r12d
  rorxl $22, %ebx, %edi
  xorl %edi, %r12d
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %r12d, %eax
  addl %edi, %eax
