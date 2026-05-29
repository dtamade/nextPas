  // Round 0
  addl 0(%r14), %r11d
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

  // Round 1
  addl 4(%r14), %r10d
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

  // Round 2
  addl 8(%r14), %r9d
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

  // Round 3
  addl 12(%r14), %r8d
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

  // Round 4
  addl 16(%r14), %edx
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

  // Round 5
  addl 20(%r14), %ecx
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

  // Round 6
  addl 24(%r14), %ebx
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

  // Round 7
  addl 28(%r14), %eax
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

  // Round 8
  addl 32(%r14), %r11d
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

  // Round 9
  addl 36(%r14), %r10d
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

  // Round 10
  addl 40(%r14), %r9d
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

  // Round 11
  addl 44(%r14), %r8d
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

  // Round 12
  addl 48(%r14), %edx
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

  // Round 13
  addl 52(%r14), %ecx
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

  // Round 14
  addl 56(%r14), %ebx
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

  // Round 15
  addl 60(%r14), %eax
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

  // W[16] = sigma1(W[14]) + W[9] + sigma0(W[1]) + W[0]
  movl 56(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 36(%rsp), %edi
  movl 4(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 0(%rsp), %edi
  movl %edi, 64(%rsp)
  // Round 16
  addl 64(%r14), %r11d
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

  // W[17] = sigma1(W[15]) + W[10] + sigma0(W[2]) + W[1]
  movl 60(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 40(%rsp), %edi
  movl 8(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 4(%rsp), %edi
  movl %edi, 68(%rsp)
  // Round 17
  addl 68(%r14), %r10d
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

  // W[18] = sigma1(W[16]) + W[11] + sigma0(W[3]) + W[2]
  movl 64(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 44(%rsp), %edi
  movl 12(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 8(%rsp), %edi
  movl %edi, 72(%rsp)
  // Round 18
  addl 72(%r14), %r9d
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

  // W[19] = sigma1(W[17]) + W[12] + sigma0(W[4]) + W[3]
  movl 68(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 48(%rsp), %edi
  movl 16(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 12(%rsp), %edi
  movl %edi, 76(%rsp)
  // Round 19
  addl 76(%r14), %r8d
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

  // W[20] = sigma1(W[18]) + W[13] + sigma0(W[5]) + W[4]
  movl 72(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 52(%rsp), %edi
  movl 20(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 16(%rsp), %edi
  movl %edi, 80(%rsp)
  // Round 20
  addl 80(%r14), %edx
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

  // W[21] = sigma1(W[19]) + W[14] + sigma0(W[6]) + W[5]
  movl 76(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 56(%rsp), %edi
  movl 24(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 20(%rsp), %edi
  movl %edi, 84(%rsp)
  // Round 21
  addl 84(%r14), %ecx
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

  // W[22] = sigma1(W[20]) + W[15] + sigma0(W[7]) + W[6]
  movl 80(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 60(%rsp), %edi
  movl 28(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 24(%rsp), %edi
  movl %edi, 88(%rsp)
  // Round 22
  addl 88(%r14), %ebx
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

  // W[23] = sigma1(W[21]) + W[16] + sigma0(W[8]) + W[7]
  movl 84(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 64(%rsp), %edi
  movl 32(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 28(%rsp), %edi
  movl %edi, 92(%rsp)
  // Round 23
  addl 92(%r14), %eax
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

  // W[24] = sigma1(W[22]) + W[17] + sigma0(W[9]) + W[8]
  movl 88(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 68(%rsp), %edi
  movl 36(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 32(%rsp), %edi
  movl %edi, 96(%rsp)
  // Round 24
  addl 96(%r14), %r11d
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

  // W[25] = sigma1(W[23]) + W[18] + sigma0(W[10]) + W[9]
  movl 92(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 72(%rsp), %edi
  movl 40(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 36(%rsp), %edi
  movl %edi, 100(%rsp)
  // Round 25
  addl 100(%r14), %r10d
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

  // W[26] = sigma1(W[24]) + W[19] + sigma0(W[11]) + W[10]
  movl 96(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 76(%rsp), %edi
  movl 44(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 40(%rsp), %edi
  movl %edi, 104(%rsp)
  // Round 26
  addl 104(%r14), %r9d
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

  // W[27] = sigma1(W[25]) + W[20] + sigma0(W[12]) + W[11]
  movl 100(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 80(%rsp), %edi
  movl 48(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 44(%rsp), %edi
  movl %edi, 108(%rsp)
  // Round 27
  addl 108(%r14), %r8d
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

  // W[28] = sigma1(W[26]) + W[21] + sigma0(W[13]) + W[12]
  movl 104(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 84(%rsp), %edi
  movl 52(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 48(%rsp), %edi
  movl %edi, 112(%rsp)
  // Round 28
  addl 112(%r14), %edx
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

  // W[29] = sigma1(W[27]) + W[22] + sigma0(W[14]) + W[13]
  movl 108(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 88(%rsp), %edi
  movl 56(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 52(%rsp), %edi
  movl %edi, 116(%rsp)
  // Round 29
  addl 116(%r14), %ecx
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

  // W[30] = sigma1(W[28]) + W[23] + sigma0(W[15]) + W[14]
  movl 112(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 92(%rsp), %edi
  movl 60(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 56(%rsp), %edi
  movl %edi, 120(%rsp)
  // Round 30
  addl 120(%r14), %ebx
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

  // W[31] = sigma1(W[29]) + W[24] + sigma0(W[16]) + W[15]
  movl 116(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 96(%rsp), %edi
  movl 64(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 60(%rsp), %edi
  movl %edi, 124(%rsp)
  // Round 31
  addl 124(%r14), %eax
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

  // W[32] = sigma1(W[30]) + W[25] + sigma0(W[17]) + W[16]
  movl 120(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 100(%rsp), %edi
  movl 68(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 64(%rsp), %edi
  movl %edi, 128(%rsp)
  // Round 32
  addl 128(%r14), %r11d
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

  // W[33] = sigma1(W[31]) + W[26] + sigma0(W[18]) + W[17]
  movl 124(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 104(%rsp), %edi
  movl 72(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 68(%rsp), %edi
  movl %edi, 132(%rsp)
  // Round 33
  addl 132(%r14), %r10d
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

  // W[34] = sigma1(W[32]) + W[27] + sigma0(W[19]) + W[18]
  movl 128(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 108(%rsp), %edi
  movl 76(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 72(%rsp), %edi
  movl %edi, 136(%rsp)
  // Round 34
  addl 136(%r14), %r9d
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

  // W[35] = sigma1(W[33]) + W[28] + sigma0(W[20]) + W[19]
  movl 132(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 112(%rsp), %edi
  movl 80(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 76(%rsp), %edi
  movl %edi, 140(%rsp)
  // Round 35
  addl 140(%r14), %r8d
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

  // W[36] = sigma1(W[34]) + W[29] + sigma0(W[21]) + W[20]
  movl 136(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 116(%rsp), %edi
  movl 84(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 80(%rsp), %edi
  movl %edi, 144(%rsp)
  // Round 36
  addl 144(%r14), %edx
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

  // W[37] = sigma1(W[35]) + W[30] + sigma0(W[22]) + W[21]
  movl 140(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 120(%rsp), %edi
  movl 88(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 84(%rsp), %edi
  movl %edi, 148(%rsp)
  // Round 37
  addl 148(%r14), %ecx
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

  // W[38] = sigma1(W[36]) + W[31] + sigma0(W[23]) + W[22]
  movl 144(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 124(%rsp), %edi
  movl 92(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 88(%rsp), %edi
  movl %edi, 152(%rsp)
  // Round 38
  addl 152(%r14), %ebx
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

  // W[39] = sigma1(W[37]) + W[32] + sigma0(W[24]) + W[23]
  movl 148(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 128(%rsp), %edi
  movl 96(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 92(%rsp), %edi
  movl %edi, 156(%rsp)
  // Round 39
  addl 156(%r14), %eax
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

  // W[40] = sigma1(W[38]) + W[33] + sigma0(W[25]) + W[24]
  movl 152(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 132(%rsp), %edi
  movl 100(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 96(%rsp), %edi
  movl %edi, 160(%rsp)
  // Round 40
  addl 160(%r14), %r11d
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

  // W[41] = sigma1(W[39]) + W[34] + sigma0(W[26]) + W[25]
  movl 156(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 136(%rsp), %edi
  movl 104(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 100(%rsp), %edi
  movl %edi, 164(%rsp)
  // Round 41
  addl 164(%r14), %r10d
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

  // W[42] = sigma1(W[40]) + W[35] + sigma0(W[27]) + W[26]
  movl 160(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 140(%rsp), %edi
  movl 108(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 104(%rsp), %edi
  movl %edi, 168(%rsp)
  // Round 42
  addl 168(%r14), %r9d
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

  // W[43] = sigma1(W[41]) + W[36] + sigma0(W[28]) + W[27]
  movl 164(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 144(%rsp), %edi
  movl 112(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 108(%rsp), %edi
  movl %edi, 172(%rsp)
  // Round 43
  addl 172(%r14), %r8d
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

  // W[44] = sigma1(W[42]) + W[37] + sigma0(W[29]) + W[28]
  movl 168(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 148(%rsp), %edi
  movl 116(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 112(%rsp), %edi
  movl %edi, 176(%rsp)
  // Round 44
  addl 176(%r14), %edx
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

  // W[45] = sigma1(W[43]) + W[38] + sigma0(W[30]) + W[29]
  movl 172(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 152(%rsp), %edi
  movl 120(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 116(%rsp), %edi
  movl %edi, 180(%rsp)
  // Round 45
  addl 180(%r14), %ecx
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

  // W[46] = sigma1(W[44]) + W[39] + sigma0(W[31]) + W[30]
  movl 176(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 156(%rsp), %edi
  movl 124(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 120(%rsp), %edi
  movl %edi, 184(%rsp)
  // Round 46
  addl 184(%r14), %ebx
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

  // W[47] = sigma1(W[45]) + W[40] + sigma0(W[32]) + W[31]
  movl 180(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 160(%rsp), %edi
  movl 128(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 124(%rsp), %edi
  movl %edi, 188(%rsp)
  // Round 47
  addl 188(%r14), %eax
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

  // W[48] = sigma1(W[46]) + W[41] + sigma0(W[33]) + W[32]
  movl 184(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 164(%rsp), %edi
  movl 132(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 128(%rsp), %edi
  movl %edi, 192(%rsp)
  // Round 48
  addl 192(%r14), %r11d
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

  // W[49] = sigma1(W[47]) + W[42] + sigma0(W[34]) + W[33]
  movl 188(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 168(%rsp), %edi
  movl 136(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 132(%rsp), %edi
  movl %edi, 196(%rsp)
  // Round 49
  addl 196(%r14), %r10d
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

  // W[50] = sigma1(W[48]) + W[43] + sigma0(W[35]) + W[34]
  movl 192(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 172(%rsp), %edi
  movl 140(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 136(%rsp), %edi
  movl %edi, 200(%rsp)
  // Round 50
  addl 200(%r14), %r9d
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

  // W[51] = sigma1(W[49]) + W[44] + sigma0(W[36]) + W[35]
  movl 196(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 176(%rsp), %edi
  movl 144(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 140(%rsp), %edi
  movl %edi, 204(%rsp)
  // Round 51
  addl 204(%r14), %r8d
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

  // W[52] = sigma1(W[50]) + W[45] + sigma0(W[37]) + W[36]
  movl 200(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 180(%rsp), %edi
  movl 148(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 144(%rsp), %edi
  movl %edi, 208(%rsp)
  // Round 52
  addl 208(%r14), %edx
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

  // W[53] = sigma1(W[51]) + W[46] + sigma0(W[38]) + W[37]
  movl 204(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 184(%rsp), %edi
  movl 152(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 148(%rsp), %edi
  movl %edi, 212(%rsp)
  // Round 53
  addl 212(%r14), %ecx
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

  // W[54] = sigma1(W[52]) + W[47] + sigma0(W[39]) + W[38]
  movl 208(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 188(%rsp), %edi
  movl 156(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 152(%rsp), %edi
  movl %edi, 216(%rsp)
  // Round 54
  addl 216(%r14), %ebx
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

  // W[55] = sigma1(W[53]) + W[48] + sigma0(W[40]) + W[39]
  movl 212(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 192(%rsp), %edi
  movl 160(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 156(%rsp), %edi
  movl %edi, 220(%rsp)
  // Round 55
  addl 220(%r14), %eax
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

  // W[56] = sigma1(W[54]) + W[49] + sigma0(W[41]) + W[40]
  movl 216(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 196(%rsp), %edi
  movl 164(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 160(%rsp), %edi
  movl %edi, 224(%rsp)
  // Round 56
  addl 224(%r14), %r11d
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

  // W[57] = sigma1(W[55]) + W[50] + sigma0(W[42]) + W[41]
  movl 220(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 200(%rsp), %edi
  movl 168(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 164(%rsp), %edi
  movl %edi, 228(%rsp)
  // Round 57
  addl 228(%r14), %r10d
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

  // W[58] = sigma1(W[56]) + W[51] + sigma0(W[43]) + W[42]
  movl 224(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 204(%rsp), %edi
  movl 172(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 168(%rsp), %edi
  movl %edi, 232(%rsp)
  // Round 58
  addl 232(%r14), %r9d
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

  // W[59] = sigma1(W[57]) + W[52] + sigma0(W[44]) + W[43]
  movl 228(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 208(%rsp), %edi
  movl 176(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 172(%rsp), %edi
  movl %edi, 236(%rsp)
  // Round 59
  addl 236(%r14), %r8d
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

  // W[60] = sigma1(W[58]) + W[53] + sigma0(W[45]) + W[44]
  movl 232(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 212(%rsp), %edi
  movl 180(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 176(%rsp), %edi
  movl %edi, 240(%rsp)
  // Round 60
  addl 240(%r14), %edx
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

  // W[61] = sigma1(W[59]) + W[54] + sigma0(W[46]) + W[45]
  movl 236(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 216(%rsp), %edi
  movl 184(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 180(%rsp), %edi
  movl %edi, 244(%rsp)
  // Round 61
  addl 244(%r14), %ecx
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

  // W[62] = sigma1(W[60]) + W[55] + sigma0(W[47]) + W[46]
  movl 240(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 220(%rsp), %edi
  movl 188(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 184(%rsp), %edi
  movl %edi, 248(%rsp)
  // Round 62
  addl 248(%r14), %ebx
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

  // W[63] = sigma1(W[61]) + W[56] + sigma0(W[48]) + W[47]
  movl 244(%rsp), %esi
  rorxl $17, %esi, %edi
  rorxl $19, %esi, %ebp
  xorl %ebp, %edi
  shrl $10, %esi
  xorl %esi, %edi
  addl 224(%rsp), %edi
  movl 192(%rsp), %esi
  rorxl $7, %esi, %ebp
  rorxl $18, %esi, %r12d
  xorl %r12d, %ebp
  shrl $3, %esi
  xorl %esi, %ebp
  addl %ebp, %edi
  addl 188(%rsp), %edi
  movl %edi, 252(%rsp)
  // Round 63
  addl 252(%r14), %eax
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

