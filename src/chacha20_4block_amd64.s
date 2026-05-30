# chacha20_4block_amd64.s
# Process 4 ChaCha20 blocks (256 bytes) simultaneously using AVX2
# Then XOR with plaintext → ciphertext
#
# void chacha20_4block_xor(
#   const uint32_t *state,   // rdi: 16×uint32 ChaCha20 state (counter set)
#   const uint8_t *input,    // rsi: 256 bytes plaintext
#   uint8_t *output          // rdx: 256 bytes ciphertext output
# )
#
# Processes blocks with counters: state[12], state[12]+1, state[12]+2, state[12]+3

.section .rodata
.align 32
.Lrot16: .byte 2,3,0,1, 6,7,4,5, 10,11,8,9, 14,15,12,13
         .byte 2,3,0,1, 6,7,4,5, 10,11,8,9, 14,15,12,13
.Lrot8:  .byte 3,0,1,2, 7,4,5,6, 11,8,9,10, 15,12,13,14
         .byte 3,0,1,2, 7,4,5,6, 11,8,9,10, 15,12,13,14
.Linc:   .long 0,0,0,0, 1,0,0,0
.Linc2:  .long 2,0,0,0, 3,0,0,0

.text
.globl chacha20_4block_xor
.type chacha20_4block_xor, @function
.align 32
chacha20_4block_xor:
    # rdi=state, rsi=input, rdx=output
    push %rbx

    # Load state rows into XMM, broadcast to YMM
    vmovdqu (%rdi), %xmm0          # row0
    vmovdqu 16(%rdi), %xmm1        # row1
    vmovdqu 32(%rdi), %xmm2        # row2
    vmovdqu 48(%rdi), %xmm3        # row3 (with base counter)

    # Set A: blocks 0,1 — row3 = [ctr+0 | ctr+1]
    vinserti128 $1, %xmm0, %ymm0, %ymm0
    vinserti128 $1, %xmm1, %ymm1, %ymm1
    vinserti128 $1, %xmm2, %ymm2, %ymm2
    vmovdqa %xmm3, %xmm4
    vpaddd .Linc(%rip), %ymm3, %ymm3    # ymm3 = [ctr+0 | ctr+1]

    # Set B: blocks 2,3 — row3 = [ctr+2 | ctr+3]
    vmovdqa %ymm0, %ymm4
    vmovdqa %ymm1, %ymm5
    vmovdqa %ymm2, %ymm6
    vmovdqu 48(%rdi), %xmm7
    vpaddd .Linc2(%rip), %ymm7, %ymm7   # ymm7 = [ctr+2 | ctr+3]

    # Save originals for final add
    vmovdqa %ymm0, %ymm8           # A row0
    vmovdqa %ymm1, %ymm9           # A row1
    vmovdqa %ymm2, %ymm10          # A row2
    vmovdqa %ymm3, %ymm11          # A row3
    # B originals: rows 0-2 same as A, row3 different
    # Save B row3 to stack
    sub $32, %rsp
    vmovdqu %ymm7, (%rsp)

    # Load rotation masks
    vmovdqa .Lrot16(%rip), %ymm12
    vmovdqa .Lrot8(%rip), %ymm13

    # 10 double-rounds for both sets
    mov $10, %ecx
.L4b_round:
    # === Set A column round ===
    vpaddd %ymm1, %ymm0, %ymm0
    vpxor %ymm0, %ymm3, %ymm3
    vpshufb %ymm12, %ymm3, %ymm3
    vpaddd %ymm3, %ymm2, %ymm2
    vpxor %ymm2, %ymm1, %ymm1
    vpslld $12, %ymm1, %ymm14
    vpsrld $20, %ymm1, %ymm1
    vpor %ymm14, %ymm1, %ymm1
    vpaddd %ymm1, %ymm0, %ymm0
    vpxor %ymm0, %ymm3, %ymm3
    vpshufb %ymm13, %ymm3, %ymm3
    vpaddd %ymm3, %ymm2, %ymm2
    vpxor %ymm2, %ymm1, %ymm1
    vpslld $7, %ymm1, %ymm14
    vpsrld $25, %ymm1, %ymm1
    vpor %ymm14, %ymm1, %ymm1

    # === Set B column round ===
    vpaddd %ymm5, %ymm4, %ymm4
    vpxor %ymm4, %ymm7, %ymm7
    vpshufb %ymm12, %ymm7, %ymm7
    vpaddd %ymm7, %ymm6, %ymm6
    vpxor %ymm6, %ymm5, %ymm5
    vpslld $12, %ymm5, %ymm14
    vpsrld $20, %ymm5, %ymm5
    vpor %ymm14, %ymm5, %ymm5
    vpaddd %ymm5, %ymm4, %ymm4
    vpxor %ymm4, %ymm7, %ymm7
    vpshufb %ymm13, %ymm7, %ymm7
    vpaddd %ymm7, %ymm6, %ymm6
    vpxor %ymm6, %ymm5, %ymm5
    vpslld $7, %ymm5, %ymm14
    vpsrld $25, %ymm5, %ymm5
    vpor %ymm14, %ymm5, %ymm5

    # === Set A diagonal ===
    vpshufd $0x39, %ymm1, %ymm1
    vpshufd $0x4e, %ymm2, %ymm2
    vpshufd $0x93, %ymm3, %ymm3
    vpaddd %ymm1, %ymm0, %ymm0
    vpxor %ymm0, %ymm3, %ymm3
    vpshufb %ymm12, %ymm3, %ymm3
    vpaddd %ymm3, %ymm2, %ymm2
    vpxor %ymm2, %ymm1, %ymm1
    vpslld $12, %ymm1, %ymm14
    vpsrld $20, %ymm1, %ymm1
    vpor %ymm14, %ymm1, %ymm1
    vpaddd %ymm1, %ymm0, %ymm0
    vpxor %ymm0, %ymm3, %ymm3
    vpshufb %ymm13, %ymm3, %ymm3
    vpaddd %ymm3, %ymm2, %ymm2
    vpxor %ymm2, %ymm1, %ymm1
    vpslld $7, %ymm1, %ymm14
    vpsrld $25, %ymm1, %ymm1
    vpor %ymm14, %ymm1, %ymm1
    vpshufd $0x93, %ymm1, %ymm1
    vpshufd $0x4e, %ymm2, %ymm2
    vpshufd $0x39, %ymm3, %ymm3

    # === Set B diagonal ===
    vpshufd $0x39, %ymm5, %ymm5
    vpshufd $0x4e, %ymm6, %ymm6
    vpshufd $0x93, %ymm7, %ymm7
    vpaddd %ymm5, %ymm4, %ymm4
    vpxor %ymm4, %ymm7, %ymm7
    vpshufb %ymm12, %ymm7, %ymm7
    vpaddd %ymm7, %ymm6, %ymm6
    vpxor %ymm6, %ymm5, %ymm5
    vpslld $12, %ymm5, %ymm14
    vpsrld $20, %ymm5, %ymm5
    vpor %ymm14, %ymm5, %ymm5
    vpaddd %ymm5, %ymm4, %ymm4
    vpxor %ymm4, %ymm7, %ymm7
    vpshufb %ymm13, %ymm7, %ymm7
    vpaddd %ymm7, %ymm6, %ymm6
    vpxor %ymm6, %ymm5, %ymm5
    vpslld $7, %ymm5, %ymm14
    vpsrld $25, %ymm5, %ymm5
    vpor %ymm14, %ymm5, %ymm5
    vpshufd $0x93, %ymm5, %ymm5
    vpshufd $0x4e, %ymm6, %ymm6
    vpshufd $0x39, %ymm7, %ymm7

    dec %ecx
    jnz .L4b_round

    # Add original state
    vpaddd %ymm8, %ymm0, %ymm0
    vpaddd %ymm9, %ymm1, %ymm1
    vpaddd %ymm10, %ymm2, %ymm2
    vpaddd %ymm11, %ymm3, %ymm3
    vpaddd %ymm8, %ymm4, %ymm4
    vpaddd %ymm9, %ymm5, %ymm5
    vpaddd %ymm10, %ymm6, %ymm6
    vmovdqu (%rsp), %ymm14
    vpaddd %ymm14, %ymm7, %ymm7
    add $32, %rsp

    # XOR with plaintext and store ciphertext
    # Set A: blocks 0,1 (128 bytes)
    vpxor (%rsi), %ymm0, %ymm0
    vmovdqu %ymm0, (%rdx)
    vpxor 32(%rsi), %ymm1, %ymm1
    vmovdqu %ymm1, 32(%rdx)
    vpxor 64(%rsi), %ymm2, %ymm2
    vmovdqu %ymm2, 64(%rdx)
    vpxor 96(%rsi), %ymm3, %ymm3
    vmovdqu %ymm3, 96(%rdx)
    # Set B: blocks 2,3 (128 bytes)
    vpxor 128(%rsi), %ymm4, %ymm4
    vmovdqu %ymm4, 128(%rdx)
    vpxor 160(%rsi), %ymm5, %ymm5
    vmovdqu %ymm5, 160(%rdx)
    vpxor 192(%rsi), %ymm6, %ymm6
    vmovdqu %ymm6, 192(%rdx)
    vpxor 224(%rsi), %ymm7, %ymm7
    vmovdqu %ymm7, 224(%rdx)

    vzeroupper
    pop %rbx
    ret

.size chacha20_4block_xor, .-chacha20_4block_xor
