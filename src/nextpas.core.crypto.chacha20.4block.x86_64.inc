{ 4-block AVX2 ChaCha20 XOR — inline ASM for x86_64
  Processes 256 bytes: XOR plaintext directly in ASM, store to Result.
  Requires LBlock to be at least 64 UInt32 (256 bytes) for temp storage.
}

// 4-block path: 256 bytes at a time
while LOffset + 256 <= Length(AInput) do
begin
  LState[12] := ACounter;
  asm
    movdqu LState+0, %xmm0
    movdqu LState+16, %xmm1
    movdqu LState+32, %xmm2
    movdqu LState+48, %xmm3
    // Set A: [ctr | ctr+1]
    movdqa %xmm3, %xmm4
    movq $1, %rax
    movd %eax, %xmm5
    paddd %xmm5, %xmm4
    vinserti128 $1, %xmm0, %ymm0, %ymm0
    vinserti128 $1, %xmm1, %ymm1, %ymm1
    vinserti128 $1, %xmm2, %ymm2, %ymm2
    vinserti128 $1, %xmm4, %ymm3, %ymm3
    // Set B: [ctr+2 | ctr+3]
    vmovdqa %ymm0, %ymm4
    vmovdqa %ymm1, %ymm5
    vmovdqa %ymm2, %ymm6
    movdqu LState+48, %xmm7
    movq $2, %rax; movd %eax, %xmm14; paddd %xmm14, %xmm7
    movdqa %xmm7, %xmm14
    movq $1, %rax; movd %eax, %xmm15; paddd %xmm15, %xmm14
    vinserti128 $1, %xmm14, %ymm7, %ymm7
    // Save
    vmovdqa %ymm0, %ymm8
    vmovdqa %ymm1, %ymm9
    vmovdqa %ymm2, %ymm10
    vmovdqa %ymm3, %ymm11
    sub $32, %rsp
    vmovdqu %ymm7, (%rsp)
    vbroadcasti128 ROT16_MASK, %ymm12
    vbroadcasti128 ROT8_MASK, %ymm13
    movq $10, %rcx
  .L4b_round_inc:
    // A col
    vpaddd %ymm1,%ymm0,%ymm0; vpxor %ymm0,%ymm3,%ymm3; vpshufb %ymm12,%ymm3,%ymm3
    vpaddd %ymm3,%ymm2,%ymm2; vpxor %ymm2,%ymm1,%ymm1
    vpslld $12,%ymm1,%ymm14; vpsrld $20,%ymm1,%ymm1; vpor %ymm14,%ymm1,%ymm1
    vpaddd %ymm1,%ymm0,%ymm0; vpxor %ymm0,%ymm3,%ymm3; vpshufb %ymm13,%ymm3,%ymm3
    vpaddd %ymm3,%ymm2,%ymm2; vpxor %ymm2,%ymm1,%ymm1
    vpslld $7,%ymm1,%ymm14; vpsrld $25,%ymm1,%ymm1; vpor %ymm14,%ymm1,%ymm1
    // B col
    vpaddd %ymm5,%ymm4,%ymm4; vpxor %ymm4,%ymm7,%ymm7; vpshufb %ymm12,%ymm7,%ymm7
    vpaddd %ymm7,%ymm6,%ymm6; vpxor %ymm6,%ymm5,%ymm5
    vpslld $12,%ymm5,%ymm14; vpsrld $20,%ymm5,%ymm5; vpor %ymm14,%ymm5,%ymm5
    vpaddd %ymm5,%ymm4,%ymm4; vpxor %ymm4,%ymm7,%ymm7; vpshufb %ymm13,%ymm7,%ymm7
    vpaddd %ymm7,%ymm6,%ymm6; vpxor %ymm6,%ymm5,%ymm5
    vpslld $7,%ymm5,%ymm14; vpsrld $25,%ymm5,%ymm5; vpor %ymm14,%ymm5,%ymm5
    // A diag
    vpshufd $0x39,%ymm1,%ymm1; vpshufd $0x4E,%ymm2,%ymm2; vpshufd $0x93,%ymm3,%ymm3
    vpaddd %ymm1,%ymm0,%ymm0; vpxor %ymm0,%ymm3,%ymm3; vpshufb %ymm12,%ymm3,%ymm3
    vpaddd %ymm3,%ymm2,%ymm2; vpxor %ymm2,%ymm1,%ymm1
    vpslld $12,%ymm1,%ymm14; vpsrld $20,%ymm1,%ymm1; vpor %ymm14,%ymm1,%ymm1
    vpaddd %ymm1,%ymm0,%ymm0; vpxor %ymm0,%ymm3,%ymm3; vpshufb %ymm13,%ymm3,%ymm3
    vpaddd %ymm3,%ymm2,%ymm2; vpxor %ymm2,%ymm1,%ymm1
    vpslld $7,%ymm1,%ymm14; vpsrld $25,%ymm1,%ymm1; vpor %ymm14,%ymm1,%ymm1
    vpshufd $0x93,%ymm1,%ymm1; vpshufd $0x4E,%ymm2,%ymm2; vpshufd $0x39,%ymm3,%ymm3
    // B diag
    vpshufd $0x39,%ymm5,%ymm5; vpshufd $0x4E,%ymm6,%ymm6; vpshufd $0x93,%ymm7,%ymm7
    vpaddd %ymm5,%ymm4,%ymm4; vpxor %ymm4,%ymm7,%ymm7; vpshufb %ymm12,%ymm7,%ymm7
    vpaddd %ymm7,%ymm6,%ymm6; vpxor %ymm6,%ymm5,%ymm5
    vpslld $12,%ymm5,%ymm14; vpsrld $20,%ymm5,%ymm5; vpor %ymm14,%ymm5,%ymm5
    vpaddd %ymm5,%ymm4,%ymm4; vpxor %ymm4,%ymm7,%ymm7; vpshufb %ymm13,%ymm7,%ymm7
    vpaddd %ymm7,%ymm6,%ymm6; vpxor %ymm6,%ymm5,%ymm5
    vpslld $7,%ymm5,%ymm14; vpsrld $25,%ymm5,%ymm5; vpor %ymm14,%ymm5,%ymm5
    vpshufd $0x93,%ymm5,%ymm5; vpshufd $0x4E,%ymm6,%ymm6; vpshufd $0x39,%ymm7,%ymm7
    decq %rcx
    jnz .L4b_round_inc
    // Add state
    vpaddd %ymm8,%ymm0,%ymm0; vpaddd %ymm9,%ymm1,%ymm1
    vpaddd %ymm10,%ymm2,%ymm2; vpaddd %ymm11,%ymm3,%ymm3
    vpaddd %ymm8,%ymm4,%ymm4; vpaddd %ymm9,%ymm5,%ymm5
    vpaddd %ymm10,%ymm6,%ymm6
    vmovdqu (%rsp),%ymm14; vpaddd %ymm14,%ymm7,%ymm7
    add $32, %rsp
    // XOR with plaintext and store to Result (all 256 bytes)
    // Load AInput pointer and Result pointer
    leaq AInput, %rsi
    movq (%rsi), %rsi
    movslq LOffset, %rax
    addq %rax, %rsi      // + offset
    leaq Result, %rdi
    movq (%rdi), %rdi
    movslq LOffset, %rax
    addq %rax, %rdi
    // XOR Set A (128 bytes)
    vpxor (%rsi), %ymm0, %ymm0; vmovdqu %ymm0, (%rdi)
    vpxor 32(%rsi), %ymm1, %ymm1; vmovdqu %ymm1, 32(%rdi)
    vpxor 64(%rsi), %ymm2, %ymm2; vmovdqu %ymm2, 64(%rdi)
    vpxor 96(%rsi), %ymm3, %ymm3; vmovdqu %ymm3, 96(%rdi)
    // XOR Set B (128 bytes)
    vpxor 128(%rsi), %ymm4, %ymm4; vmovdqu %ymm4, 128(%rdi)
    vpxor 160(%rsi), %ymm5, %ymm5; vmovdqu %ymm5, 160(%rdi)
    vpxor 192(%rsi), %ymm6, %ymm6; vmovdqu %ymm6, 192(%rdi)
    vpxor 224(%rsi), %ymm7, %ymm7; vmovdqu %ymm7, 224(%rdi)
    vzeroupper
  end ['rax','rcx','rsi','rdi',
    'ymm0','ymm1','ymm2','ymm3','ymm4','ymm5','ymm6','ymm7',
    'ymm8','ymm9','ymm10','ymm11','ymm12','ymm13','ymm14','ymm15'];

  Inc(ACounter, 4);
  Inc(LOffset, 256);
end;
