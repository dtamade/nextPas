  // Round 0
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 0(%r14), %r13d
  addl 0(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 1
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 4(%r14), %r13d
  addl 4(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 2
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 8(%r14), %r13d
  addl 8(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 3
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 12(%r14), %r13d
  addl 12(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 4
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 16(%r14), %r13d
  addl 16(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 5
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 20(%r14), %r13d
  addl 20(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 6
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 24(%r14), %r13d
  addl 24(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 7
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 28(%r14), %r13d
  addl 28(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 8
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 32(%r14), %r13d
  addl 32(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 9
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 36(%r14), %r13d
  addl 36(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 10
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 40(%r14), %r13d
  addl 40(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 11
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 44(%r14), %r13d
  addl 44(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 12
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 48(%r14), %r13d
  addl 48(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 13
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 52(%r14), %r13d
  addl 52(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 14
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 56(%r14), %r13d
  addl 56(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 15
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 60(%r14), %r13d
  addl 60(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 16
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 64(%r14), %r13d
  addl 64(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 17
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 68(%r14), %r13d
  addl 68(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 18
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 72(%r14), %r13d
  addl 72(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 19
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 76(%r14), %r13d
  addl 76(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 20
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 80(%r14), %r13d
  addl 80(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 21
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 84(%r14), %r13d
  addl 84(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 22
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 88(%r14), %r13d
  addl 88(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 23
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 92(%r14), %r13d
  addl 92(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 24
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 96(%r14), %r13d
  addl 96(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 25
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 100(%r14), %r13d
  addl 100(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 26
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 104(%r14), %r13d
  addl 104(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 27
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 108(%r14), %r13d
  addl 108(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 28
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 112(%r14), %r13d
  addl 112(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 29
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 116(%r14), %r13d
  addl 116(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 30
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 120(%r14), %r13d
  addl 120(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 31
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 124(%r14), %r13d
  addl 124(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 32
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 128(%r14), %r13d
  addl 128(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 33
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 132(%r14), %r13d
  addl 132(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 34
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 136(%r14), %r13d
  addl 136(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 35
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 140(%r14), %r13d
  addl 140(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 36
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 144(%r14), %r13d
  addl 144(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 37
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 148(%r14), %r13d
  addl 148(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 38
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 152(%r14), %r13d
  addl 152(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 39
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 156(%r14), %r13d
  addl 156(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 40
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 160(%r14), %r13d
  addl 160(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 41
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 164(%r14), %r13d
  addl 164(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 42
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 168(%r14), %r13d
  addl 168(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 43
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 172(%r14), %r13d
  addl 172(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 44
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 176(%r14), %r13d
  addl 176(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 45
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 180(%r14), %r13d
  addl 180(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 46
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 184(%r14), %r13d
  addl 184(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 47
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 188(%r14), %r13d
  addl 188(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 48
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 192(%r14), %r13d
  addl 192(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 49
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 196(%r14), %r13d
  addl 196(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 50
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 200(%r14), %r13d
  addl 200(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 51
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 204(%r14), %r13d
  addl 204(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 52
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 208(%r14), %r13d
  addl 208(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 53
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 212(%r14), %r13d
  addl 212(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 54
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 216(%r14), %r13d
  addl 216(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 55
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 220(%r14), %r13d
  addl 220(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

  // Round 56
  rorxl $6, %r8d, %r13d
  rorxl $11, %r8d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r8d, %ebp
  xorl %ebp, %r13d
  movl %r9d, %ebp
  xorl %r10d, %ebp
  andl %r8d, %ebp
  xorl %r10d, %ebp
  addl %r11d, %r13d
  addl %ebp, %r13d
  addl 224(%r14), %r13d
  addl 224(%rsp), %r13d
  rorxl $2, %eax, %ebp
  rorxl $13, %eax, %edi
  xorl %edi, %ebp
  rorxl $22, %eax, %edi
  xorl %edi, %ebp
  movl %eax, %edi
  xorl %ebx, %edi
  andl %ecx, %edi
  movl %eax, %esi
  andl %ebx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %edx
  addl %ebp, %r13d
  movl %r13d, %r11d

  // Round 57
  rorxl $6, %edx, %r13d
  rorxl $11, %edx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %edx, %ebp
  xorl %ebp, %r13d
  movl %r8d, %ebp
  xorl %r9d, %ebp
  andl %edx, %ebp
  xorl %r9d, %ebp
  addl %r10d, %r13d
  addl %ebp, %r13d
  addl 228(%r14), %r13d
  addl 228(%rsp), %r13d
  rorxl $2, %r11d, %ebp
  rorxl $13, %r11d, %edi
  xorl %edi, %ebp
  rorxl $22, %r11d, %edi
  xorl %edi, %ebp
  movl %r11d, %edi
  xorl %eax, %edi
  andl %ebx, %edi
  movl %r11d, %esi
  andl %eax, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ecx
  addl %ebp, %r13d
  movl %r13d, %r10d

  // Round 58
  rorxl $6, %ecx, %r13d
  rorxl $11, %ecx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ecx, %ebp
  xorl %ebp, %r13d
  movl %edx, %ebp
  xorl %r8d, %ebp
  andl %ecx, %ebp
  xorl %r8d, %ebp
  addl %r9d, %r13d
  addl %ebp, %r13d
  addl 232(%r14), %r13d
  addl 232(%rsp), %r13d
  rorxl $2, %r10d, %ebp
  rorxl $13, %r10d, %edi
  xorl %edi, %ebp
  rorxl $22, %r10d, %edi
  xorl %edi, %ebp
  movl %r10d, %edi
  xorl %r11d, %edi
  andl %eax, %edi
  movl %r10d, %esi
  andl %r11d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %ebx
  addl %ebp, %r13d
  movl %r13d, %r9d

  // Round 59
  rorxl $6, %ebx, %r13d
  rorxl $11, %ebx, %ebp
  xorl %ebp, %r13d
  rorxl $25, %ebx, %ebp
  xorl %ebp, %r13d
  movl %ecx, %ebp
  xorl %edx, %ebp
  andl %ebx, %ebp
  xorl %edx, %ebp
  addl %r8d, %r13d
  addl %ebp, %r13d
  addl 236(%r14), %r13d
  addl 236(%rsp), %r13d
  rorxl $2, %r9d, %ebp
  rorxl $13, %r9d, %edi
  xorl %edi, %ebp
  rorxl $22, %r9d, %edi
  xorl %edi, %ebp
  movl %r9d, %edi
  xorl %r10d, %edi
  andl %r11d, %edi
  movl %r9d, %esi
  andl %r10d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %eax
  addl %ebp, %r13d
  movl %r13d, %r8d

  // Round 60
  rorxl $6, %eax, %r13d
  rorxl $11, %eax, %ebp
  xorl %ebp, %r13d
  rorxl $25, %eax, %ebp
  xorl %ebp, %r13d
  movl %ebx, %ebp
  xorl %ecx, %ebp
  andl %eax, %ebp
  xorl %ecx, %ebp
  addl %edx, %r13d
  addl %ebp, %r13d
  addl 240(%r14), %r13d
  addl 240(%rsp), %r13d
  rorxl $2, %r8d, %ebp
  rorxl $13, %r8d, %edi
  xorl %edi, %ebp
  rorxl $22, %r8d, %edi
  xorl %edi, %ebp
  movl %r8d, %edi
  xorl %r9d, %edi
  andl %r10d, %edi
  movl %r8d, %esi
  andl %r9d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r11d
  addl %ebp, %r13d
  movl %r13d, %edx

  // Round 61
  rorxl $6, %r11d, %r13d
  rorxl $11, %r11d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r11d, %ebp
  xorl %ebp, %r13d
  movl %eax, %ebp
  xorl %ebx, %ebp
  andl %r11d, %ebp
  xorl %ebx, %ebp
  addl %ecx, %r13d
  addl %ebp, %r13d
  addl 244(%r14), %r13d
  addl 244(%rsp), %r13d
  rorxl $2, %edx, %ebp
  rorxl $13, %edx, %edi
  xorl %edi, %ebp
  rorxl $22, %edx, %edi
  xorl %edi, %ebp
  movl %edx, %edi
  xorl %r8d, %edi
  andl %r9d, %edi
  movl %edx, %esi
  andl %r8d, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r10d
  addl %ebp, %r13d
  movl %r13d, %ecx

  // Round 62
  rorxl $6, %r10d, %r13d
  rorxl $11, %r10d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r10d, %ebp
  xorl %ebp, %r13d
  movl %r11d, %ebp
  xorl %eax, %ebp
  andl %r10d, %ebp
  xorl %eax, %ebp
  addl %ebx, %r13d
  addl %ebp, %r13d
  addl 248(%r14), %r13d
  addl 248(%rsp), %r13d
  rorxl $2, %ecx, %ebp
  rorxl $13, %ecx, %edi
  xorl %edi, %ebp
  rorxl $22, %ecx, %edi
  xorl %edi, %ebp
  movl %ecx, %edi
  xorl %edx, %edi
  andl %r8d, %edi
  movl %ecx, %esi
  andl %edx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r9d
  addl %ebp, %r13d
  movl %r13d, %ebx

  // Round 63
  rorxl $6, %r9d, %r13d
  rorxl $11, %r9d, %ebp
  xorl %ebp, %r13d
  rorxl $25, %r9d, %ebp
  xorl %ebp, %r13d
  movl %r10d, %ebp
  xorl %r11d, %ebp
  andl %r9d, %ebp
  xorl %r11d, %ebp
  addl %eax, %r13d
  addl %ebp, %r13d
  addl 252(%r14), %r13d
  addl 252(%rsp), %r13d
  rorxl $2, %ebx, %ebp
  rorxl $13, %ebx, %edi
  xorl %edi, %ebp
  rorxl $22, %ebx, %edi
  xorl %edi, %ebp
  movl %ebx, %edi
  xorl %ecx, %edi
  andl %edx, %edi
  movl %ebx, %esi
  andl %ecx, %esi
  orl %esi, %edi
  addl %edi, %ebp
  addl %r13d, %r8d
  addl %ebp, %r13d
  movl %r13d, %eax

