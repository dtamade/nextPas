  // Round 0
  addl 0(%r14), %r11d
  addl 0(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 1
  addl 4(%r14), %r10d
  addl 4(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 2
  addl 8(%r14), %r9d
  addl 8(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 3
  addl 12(%r14), %r8d
  addl 12(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 4
  addl 16(%r14), %edx
  addl 16(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 5
  addl 20(%r14), %ecx
  addl 20(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 6
  addl 24(%r14), %ebx
  addl 24(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 7
  addl 28(%r14), %eax
  addl 28(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 8
  addl 32(%r14), %r11d
  addl 32(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 9
  addl 36(%r14), %r10d
  addl 36(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 10
  addl 40(%r14), %r9d
  addl 40(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 11
  addl 44(%r14), %r8d
  addl 44(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 12
  addl 48(%r14), %edx
  addl 48(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 13
  addl 52(%r14), %ecx
  addl 52(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 14
  addl 56(%r14), %ebx
  addl 56(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 15
  addl 60(%r14), %eax
  addl 60(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 16
  addl 64(%r14), %r11d
  addl 64(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 17
  addl 68(%r14), %r10d
  addl 68(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 18
  addl 72(%r14), %r9d
  addl 72(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 19
  addl 76(%r14), %r8d
  addl 76(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 20
  addl 80(%r14), %edx
  addl 80(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 21
  addl 84(%r14), %ecx
  addl 84(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 22
  addl 88(%r14), %ebx
  addl 88(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 23
  addl 92(%r14), %eax
  addl 92(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 24
  addl 96(%r14), %r11d
  addl 96(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 25
  addl 100(%r14), %r10d
  addl 100(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 26
  addl 104(%r14), %r9d
  addl 104(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 27
  addl 108(%r14), %r8d
  addl 108(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 28
  addl 112(%r14), %edx
  addl 112(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 29
  addl 116(%r14), %ecx
  addl 116(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 30
  addl 120(%r14), %ebx
  addl 120(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 31
  addl 124(%r14), %eax
  addl 124(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 32
  addl 128(%r14), %r11d
  addl 128(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 33
  addl 132(%r14), %r10d
  addl 132(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 34
  addl 136(%r14), %r9d
  addl 136(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 35
  addl 140(%r14), %r8d
  addl 140(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 36
  addl 144(%r14), %edx
  addl 144(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 37
  addl 148(%r14), %ecx
  addl 148(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 38
  addl 152(%r14), %ebx
  addl 152(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 39
  addl 156(%r14), %eax
  addl 156(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 40
  addl 160(%r14), %r11d
  addl 160(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 41
  addl 164(%r14), %r10d
  addl 164(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 42
  addl 168(%r14), %r9d
  addl 168(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 43
  addl 172(%r14), %r8d
  addl 172(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 44
  addl 176(%r14), %edx
  addl 176(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 45
  addl 180(%r14), %ecx
  addl 180(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 46
  addl 184(%r14), %ebx
  addl 184(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 47
  addl 188(%r14), %eax
  addl 188(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 48
  addl 192(%r14), %r11d
  addl 192(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 49
  addl 196(%r14), %r10d
  addl 196(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 50
  addl 200(%r14), %r9d
  addl 200(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 51
  addl 204(%r14), %r8d
  addl 204(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 52
  addl 208(%r14), %edx
  addl 208(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 53
  addl 212(%r14), %ecx
  addl 212(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 54
  addl 216(%r14), %ebx
  addl 216(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 55
  addl 220(%r14), %eax
  addl 220(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

  // Round 56
  addl 224(%r14), %r11d
  addl 224(%rsp), %r11d
  addl %r11d, %edx
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %r12d
  xorl %r10d, %r12d
  andl %r8d, %r12d
  xorl %r10d, %r12d
  addl %r12d, %r13d
  addl %r13d, %edx
  addl %r13d, %r11d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  orl %ecx, %edi
  andl %ebx, %edi
  movl %eax, %r12d
  andl %ecx, %r12d
  orl %r12d, %edi
  addl %ebp, %r11d
  addl %edi, %r11d

  // Round 57
  addl 228(%r14), %r10d
  addl 228(%rsp), %r10d
  addl %r10d, %ecx
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %r12d
  xorl %r9d, %r12d
  andl %edx, %r12d
  xorl %r9d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ecx
  addl %r13d, %r10d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  orl %ebx, %edi
  andl %eax, %edi
  movl %r11d, %r12d
  andl %ebx, %r12d
  orl %r12d, %edi
  addl %ebp, %r10d
  addl %edi, %r10d

  // Round 58
  addl 232(%r14), %r9d
  addl 232(%rsp), %r9d
  addl %r9d, %ebx
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %r12d
  xorl %r8d, %r12d
  andl %ecx, %r12d
  xorl %r8d, %r12d
  addl %r12d, %r13d
  addl %r13d, %ebx
  addl %r13d, %r9d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  orl %eax, %edi
  andl %r11d, %edi
  movl %r10d, %r12d
  andl %eax, %r12d
  orl %r12d, %edi
  addl %ebp, %r9d
  addl %edi, %r9d

  // Round 59
  addl 236(%r14), %r8d
  addl 236(%rsp), %r8d
  addl %r8d, %eax
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %r12d
  xorl %edx, %r12d
  andl %ebx, %r12d
  xorl %edx, %r12d
  addl %r12d, %r13d
  addl %r13d, %eax
  addl %r13d, %r8d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  orl %r11d, %edi
  andl %r10d, %edi
  movl %r9d, %r12d
  andl %r11d, %r12d
  orl %r12d, %edi
  addl %ebp, %r8d
  addl %edi, %r8d

  // Round 60
  addl 240(%r14), %edx
  addl 240(%rsp), %edx
  addl %edx, %r11d
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %r12d
  xorl %ecx, %r12d
  andl %eax, %r12d
  xorl %ecx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r11d
  addl %r13d, %edx
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  orl %r10d, %edi
  andl %r9d, %edi
  movl %r8d, %r12d
  andl %r10d, %r12d
  orl %r12d, %edi
  addl %ebp, %edx
  addl %edi, %edx

  // Round 61
  addl 244(%r14), %ecx
  addl 244(%rsp), %ecx
  addl %ecx, %r10d
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %r12d
  xorl %ebx, %r12d
  andl %r11d, %r12d
  xorl %ebx, %r12d
  addl %r12d, %r13d
  addl %r13d, %r10d
  addl %r13d, %ecx
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  orl %r9d, %edi
  andl %r8d, %edi
  movl %edx, %r12d
  andl %r9d, %r12d
  orl %r12d, %edi
  addl %ebp, %ecx
  addl %edi, %ecx

  // Round 62
  addl 248(%r14), %ebx
  addl 248(%rsp), %ebx
  addl %ebx, %r9d
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %r12d
  xorl %eax, %r12d
  andl %r10d, %r12d
  xorl %eax, %r12d
  addl %r12d, %r13d
  addl %r13d, %r9d
  addl %r13d, %ebx
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  orl %r8d, %edi
  andl %edx, %edi
  movl %ecx, %r12d
  andl %r8d, %r12d
  orl %r12d, %edi
  addl %ebp, %ebx
  addl %edi, %ebx

  // Round 63
  addl 252(%r14), %eax
  addl 252(%rsp), %eax
  addl %eax, %r8d
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %r12d
  xorl %r11d, %r12d
  andl %r9d, %r12d
  xorl %r11d, %r12d
  addl %r12d, %r13d
  addl %r13d, %r8d
  addl %r13d, %eax
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  orl %edx, %edi
  andl %ecx, %edi
  movl %ebx, %r12d
  andl %edx, %r12d
  orl %r12d, %edi
  addl %ebp, %eax
  addl %edi, %eax

